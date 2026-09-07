// Edge Function: extraer-reporte-pago
//
// Recibe un PDF o imagen de un reporte de comisiones (extracto de la
// aseguradora con varias pólizas) y le pide a Gemini que extraiga la lista
// completa de líneas para revisar/cargar como abonos. La API key de Google
// vive solo acá (secret de Supabase) — nunca llega al cliente Flutter.
//
// Algunos reportes vienen protegidos con contraseña (PDF cifrado). Cuando
// eso pasa, se intenta desproteger automáticamente con la contraseña
// estándar con la que la aseguradora los envía, antes de mandarlo a Gemini.

import qpdfInit from "npm:@neslinesli93/qpdf-wasm@0.3.0";
import * as XLSX from "npm:xlsx@0.18.5";
import officeCrypto from "npm:officecrypto-tool@0.0.7";
import { QPDF_WASM_BASE64 } from "./qpdf_wasm_base64.ts";

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_API_KEY");
const GEMINI_MODEL = "gemini-3.6-flash";

// Contraseña estándar de estos reportes (la misma para todos, según Rueda
// Serrano) — solo se usa si el archivo efectivamente viene protegido.
const PASSWORD_CONOCIDA = "63362817";

/// btoa(String.fromCharCode(...bytes)) revienta el call stack con archivos
/// grandes (spread de miles de argumentos) — arma el string en trozos.
function bytesABase64(bytes: Uint8Array): string {
  const CHUNK = 8192;
  let bin = "";
  for (let i = 0; i < bytes.length; i += CHUNK) {
    bin += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(bin);
}

function base64ABytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

// `supabase functions deploy` solo sube el módulo TS (no otros archivos
// sueltos del directorio, como un .wasm) — por eso el binario de qpdf va
// embebido como base64 en qpdf_wasm_base64.ts, importado como módulo, en
// vez de leerlo de un archivo aparte con locateFile.
const QPDF_WASM_BYTES = base64ABytes(QPDF_WASM_BASE64);

/// Un PDF cifrado tiene un diccionario /Encrypt en su estructura — buscarlo
/// como texto es más liviano que invocar qpdf solo para "preguntar".
function pdfEstaProtegido(bytes: Uint8Array): boolean {
  const texto = new TextDecoder("latin1").decode(bytes);
  return texto.includes("/Encrypt");
}

/// Quita la contraseña de un PDF cifrado usando qpdf compilado a WASM.
/// Si algo falla (contraseña incorrecta, wasm no disponible, etc.) tira,
/// para que el llamador decida cómo avisarle al usuario.
/// Convierte cualquier cosa que se pueda "throw" (Error, ExitStatus de
/// Emscripten, string, lo que sea) en un mensaje legible.
function describirError(e: unknown): string {
  if (e instanceof Error) return `${e.name}: ${e.message}`;
  if (e && typeof e === "object") {
    const o = e as Record<string, unknown>;
    const props = ["name", "message", "status", "code"]
      .filter((k) => k in o)
      .map((k) => `${k}=${o[k]}`)
      .join(", ");
    return props || Object.prototype.toString.call(e);
  }
  return String(e);
}

async function desprotegerPdf(bytes: Uint8Array): Promise<Uint8Array> {
  let salida = "";
  // Nombres únicos por llamada: si el runtime reutiliza el isolate (y con
  // él, algún estado global del módulo wasm) entre invocaciones, un
  // /input.pdf o /output.pdf fijo puede chocar con restos de una llamada
  // anterior — de ahí el "ErrnoError" intermitente.
  const sufijo = crypto.randomUUID();
  const rutaIn = `/input-${sufijo}.pdf`;
  const rutaOut = `/output-${sufijo}.pdf`;
  try {
    const qpdf = await qpdfInit({
      wasmBinary: QPDF_WASM_BYTES,
      print: (s: string) => { salida += s + "\n"; },
      printErr: (s: string) => { salida += s + "\n"; },
    });
    qpdf.FS.writeFile(rutaIn, bytes);
    qpdf.callMain([
      `--password=${PASSWORD_CONOCIDA}`,
      "--decrypt",
      rutaIn,
      rutaOut,
    ]);
    return qpdf.FS.readFile(rutaOut) as Uint8Array;
  } catch (e) {
    throw new Error(`qpdf falló (${describirError(e)}): ${salida || "(sin salida)"}`);
  }
}

const MIME_XLSX =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

/// Desprotege (si hace falta) y convierte un XLSX a texto plano (una tabla
/// CSV por hoja) para mandárselo a Gemini como texto en vez de inlineData
/// — Gemini no entiende el binario de un Excel, pero sí una tabla en texto.
async function leerXlsxComoTexto(bytesOriginales: Uint8Array): Promise<string> {
  let bytes = bytesOriginales;
  if (officeCrypto.isEncrypted(bytes)) {
    bytes = await officeCrypto.decrypt(bytes, { password: PASSWORD_CONOCIDA });
  }

  const libro = XLSX.read(bytes, { type: "buffer" });
  return libro.SheetNames.map((nombre) => {
    const csv = XLSX.utils.sheet_to_csv(libro.Sheets[nombre]);
    return `--- Hoja: ${nombre} ---\n${csv}`;
  }).join("\n\n");
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const LINEA_SCHEMA = {
  type: "OBJECT",
  properties: {
    nro_poliza: {
      type: "STRING",
      nullable: true,
      description:
        "Número de póliza COMPLETO de esa línea, tal cual aparece (con sus guiones u " +
        "otros separadores originales). Si además aparece un número de ANEXO REAL para " +
        "esa póliza (1, 2, 3... — no cuenta un anexo en '0', vacío o 'N/A'), incluilo al " +
        "final del número completo, separado por un espacio y sin guiones " +
        "(ej: '400 97 994000000046 6').",
    },
    nombre_cliente: { type: "STRING", nullable: true, description: "Nombre del asegurado/tomador" },
    vlrprima_poliza: { type: "NUMBER", nullable: true, description: "Valor de la prima de esa póliza, número plano" },
    vlrabono_prima: { type: "NUMBER", nullable: true, description: "Valor abonado/pagado de la prima en este corte, número plano" },
    porccomision: { type: "NUMBER", nullable: true, description: "Porcentaje de comisión aplicado" },
    vlrcomision: { type: "NUMBER", nullable: true, description: "Valor de la comisión, número plano" },
    porccomad: { type: "NUMBER", nullable: true, description: "Porcentaje de comisión adicional, si aplica" },
    vlrcomad: { type: "NUMBER", nullable: true, description: "Valor de comisión adicional, número plano" },
    num_factura: { type: "STRING", nullable: true, description: "Número de factura, si aparece" },
    fecha_pago: { type: "STRING", nullable: true, description: "Fecha del pago/abono, formato YYYY-MM-DD" },
  },
};

const CABECERA_SCHEMA = {
  type: "OBJECT",
  properties: {
    nombre_aseguradora: { type: "STRING", nullable: true, description: "Nombre de la compañía aseguradora que emite el reporte" },
    fecha_reporte: { type: "STRING", nullable: true, description: "Fecha del reporte/corte, formato YYYY-MM-DD" },
    fecha_inicio_periodo: { type: "STRING", nullable: true, description: "Fecha de inicio del período que cubre el reporte, formato YYYY-MM-DD" },
    fecha_fin_periodo: { type: "STRING", nullable: true, description: "Fecha de fin del período que cubre el reporte, formato YYYY-MM-DD" },
  },
};

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    cabecera: CABECERA_SCHEMA,
    lineas: { type: "ARRAY", items: LINEA_SCHEMA },
  },
  required: ["cabecera", "lineas"],
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonError("Método no permitido.", 405);
  }

  if (!GOOGLE_API_KEY) {
    return jsonError("Falta configurar GOOGLE_API_KEY en los secrets de Supabase.", 500);
  }

  let body: { fileBase64?: string; mimeType?: string };
  try {
    body = await req.json();
  } catch {
    return jsonError("Body inválido, se esperaba JSON.", 400);
  }

  const { fileBase64, mimeType } = body;
  if (!fileBase64 || !mimeType) {
    return jsonError("Faltan fileBase64 y/o mimeType.", 400);
  }

  const tiposValidos = ["application/pdf", MIME_XLSX, "image/jpeg", "image/png", "image/webp"];
  if (!tiposValidos.includes(mimeType)) {
    return jsonError(`Tipo de archivo no soportado: ${mimeType}. Usá PDF, XLSX, JPG, PNG o WEBP.`, 400);
  }

  const instruccion =
    "Este es un reporte/extracto de comisiones emitido por una aseguradora colombiana a un " +
    "intermediario de seguros. Contiene una cabecera (aseguradora, fechas del corte/período) y " +
    "una tabla con varias pólizas y sus pagos de ese corte. Extraé la cabecera y TODAS las " +
    "líneas/filas de la tabla, una por póliza, según el schema. Si un dato no aparece, dejalo " +
    "en null — no inventes valores. No omitas ninguna fila de la tabla aunque falten algunos " +
    "datos en ella.";

  // Arma las "parts" del pedido a Gemini: PDF/imagen van como inlineData
  // (Gemini los interpreta visualmente); un XLSX no es algo que Gemini
  // pueda "ver", así que se manda como texto (CSV) ya extraído acá.
  let parts: Record<string, unknown>[];
  try {
    if (mimeType === MIME_XLSX) {
      const bytes = Uint8Array.from(atob(fileBase64), (c) => c.charCodeAt(0));
      const textoTabla = await leerXlsxComoTexto(bytes);
      parts = [{ text: `${instruccion}\n\nContenido del archivo Excel:\n\n${textoTabla}` }];
    } else if (mimeType === "application/pdf") {
      let dataParaGemini = fileBase64;
      const bytes = Uint8Array.from(atob(fileBase64), (c) => c.charCodeAt(0));
      if (pdfEstaProtegido(bytes)) {
        const bytesLimpios = await desprotegerPdf(bytes);
        dataParaGemini = bytesABase64(bytesLimpios);
      }
      parts = [{ inlineData: { mimeType, data: dataParaGemini } }, { text: instruccion }];
    } else {
      parts = [{ inlineData: { mimeType, data: fileBase64 } }, { text: instruccion }];
    }
  } catch (e) {
    return jsonError(
      `No se pudo leer el archivo (¿contraseña incorrecta o formato no soportado?): ${e}`,
      400,
    );
  }

  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent` +
      `?key=${GOOGLE_API_KEY}`;

    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
          maxOutputTokens: 65536,
        },
      }),
    });

    if (!res.ok) {
      const detalle = await res.text();
      return jsonError(`Error de Gemini (${res.status}): ${detalle}`, 502);
    }

    const data = await res.json();
    const finishReason = data.candidates?.[0]?.finishReason;
    const textoJson = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!textoJson) {
      return jsonError(
        `Gemini no devolvió datos estructurados (finishReason: ${finishReason}). Probá con otro archivo o más nítido.`,
        502,
      );
    }

    let extraido: unknown;
    try {
      extraido = JSON.parse(textoJson);
    } catch {
      return jsonError(
        `La respuesta de Gemini no fue un JSON válido (finishReason: ${finishReason}, largo: ${textoJson.length}).`,
        502,
      );
    }

    // Diagnóstico temporal: si no se detectaron líneas pese a que el doc
    // debería tenerlas, esto ayuda a ver si Gemini cortó la respuesta.
    const lineasCount = (extraido as { lineas?: unknown[] })?.lineas?.length ?? 0;
    if (lineasCount === 0) {
      console.log(`extraer-reporte-pago: 0 líneas, finishReason=${finishReason}, largo=${textoJson.length}`);
    }

    return new Response(JSON.stringify(extraido), {
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (e) {
    return jsonError(`Error inesperado: ${e}`, 500);
  }
});

function jsonError(mensaje: string, status: number): Response {
  return new Response(JSON.stringify({ error: mensaje }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
