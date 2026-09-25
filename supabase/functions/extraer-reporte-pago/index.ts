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

import { decryptPDF, isEncrypted } from "npm:@pdfsmaller/pdf-decrypt";
import * as XLSX from "npm:xlsx@0.18.5";
import officeCrypto from "npm:officecrypto-tool@0.0.7";

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_API_KEY");
const GEMINI_MODEL = "gemini-3.6-flash";

// Contraseña estándar de estos reportes (la misma para todos, según Rueda
// Serrano) — solo se usa si el archivo efectivamente viene protegido. Vive
// como secret de Supabase, no en el código (ver README de deploy).
const PASSWORD_CONOCIDA = Deno.env.get("REPORTE_PDF_PASSWORD") ?? "";

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

/// Quita la contraseña de un PDF cifrado. Se probó primero con qpdf
/// compilado a WASM (@neslinesli93/qpdf-wasm) pero esa build fallaba
/// consistentemente con "can't find startxref" al leer el archivo de
/// vuelta del sistema de archivos virtual (bug de la librería/build, no
/// del archivo — el tamaño escrito coincidía exacto con el original) sin
/// dar más detalle util incluso revisando los logs del servidor. Esta
/// librería es JS puro (usa Web Crypto API de Deno, sin WASM ni sistema
/// de archivos virtual de por medio), mucho más simple y confiable.
async function desprotegerPdf(bytes: Uint8Array): Promise<Uint8Array> {
  return await decryptPDF(bytes, PASSWORD_CONOCIDA);
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
        "Número/código de póliza EXACTAMENTE como aparece en esa fila del reporte (columna " +
        "'Póliza', 'Poliza', o similar) — estos reportes casi nunca traen el número completo " +
        "con todos los segmentos que trae la póliza original, solo un núcleo numérico (ej. " +
        "'994000000193', '101011263', '105005925'). NO inventes segmentos ni armes el formato " +
        "completo con guiones — copiá tal cual el valor de esa columna. El matching contra la " +
        "póliza real lo hace el sistema por documento del cliente + este núcleo, no hace falta " +
        "reconstruir nada acá.",
    },
    doc_cliente: {
      type: "STRING",
      nullable: true,
      description:
        "Número de documento del cliente de esa línea (columna 'Docum', 'Doc. Tomador', " +
        "'Documento', o el número que acompañe al nombre del asegurado/tomador) — SOLO " +
        "dígitos, sin puntos. Es el dato MÁS IMPORTANTE de la línea: el sistema usa el " +
        "documento para encontrar con certeza a qué cliente/póliza corresponde, mucho más " +
        "confiable que el nombre o el número de póliza solos. Si la columna trae nombre y " +
        "documento juntos en el mismo texto, separalos: el documento va acá, el nombre en " +
        "nombre_cliente.",
    },
    nombre_cliente: { type: "STRING", nullable: true, description: "Nombre del asegurado/tomador de esa línea" },
    nombre_ramo: {
      type: "STRING",
      nullable: true,
      description: "Ramo de esa línea tal como aparece en el reporte (columna 'Ramo', 'Ramo Cial'), texto o código.",
    },
    vlrprima_poliza: { type: "NUMBER", nullable: true, description: "Valor de la prima cobrada/base de esa línea, número plano" },
    vlrabono_prima: { type: "NUMBER", nullable: true, description: "Valor abonado/pagado de la prima en este corte, número plano (mismo valor que vlrprima_poliza si el reporte no distingue ambos)" },
    porccomision: { type: "NUMBER", nullable: true, description: "Porcentaje de comisión aplicado (columna 'Pje', '% Comision')" },
    vlrcomision: { type: "NUMBER", nullable: true, description: "Valor de la comisión acreditada de esa línea, número plano" },
    porccomad: { type: "NUMBER", nullable: true, description: "Porcentaje de comisión adicional, si el reporte trae una columna separada para eso (poco común)" },
    vlrcomad: { type: "NUMBER", nullable: true, description: "Valor de comisión adicional, si aplica" },
    num_factura: { type: "STRING", nullable: true, description: "Número de recibo/factura/transacción de esa línea, si aparece (columna 'Recibo', 'Transaccion', 'Formulario')" },
    fecha_pago: { type: "STRING", nullable: true, description: "Fecha de esa línea (columna 'Fecha', 'Fecha Recibo', 'Fecha Recaudo'), formato YYYY-MM-DD" },
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
    "intermediario de seguros. Cada aseguradora usa su propio formato (a veces Excel con " +
    "encabezados de columna claros, a veces PDF con columnas visuales) — identificá las " +
    "columnas de esta tabla en particular por su encabezado o posición, no asumas un formato " +
    "fijo. Contiene una cabecera (aseguradora, fechas del corte/período) y una tabla con varias " +
    "líneas de pólizas y sus pagos de ese corte. Extraé la cabecera y TODAS las líneas/filas de " +
    "la tabla, una por cada movimiento (incluyendo reversiones/anulaciones, que son líneas " +
    "aparte con signo contrario — no las omitas ni las canceles entre sí, cada una es una fila " +
    "independiente). Si un dato no aparece, dejalo en null — no inventes valores. No omitas " +
    "ninguna fila de la tabla aunque falten algunos datos en ella.\n\n" +
    "IMPORTANTE sobre negativos: algunos reportes muestran los valores negativos (reversiones) " +
    "con signo '-' y otros con formato contable entre paréntesis, ej. '(168.093,5)' significa " +
    "-168093.5 — interpretá ambos formatos como negativos en los campos numéricos.";

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
      const info = await isEncrypted(bytes);
      if (info.encrypted) {
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
          // Un reporte con muchas pólizas genera una respuesta larga — con
          // el límite por defecto, Gemini cortaba la respuesta a mitad del
          // arreglo de líneas y volvía "lineas: []". No bajar este valor
          // sin volver a probar con un reporte de varias decenas de filas.
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

    // Si no se detectaron líneas, deja rastro en los logs de la función
    // (Dashboard → Edge Functions → Logs) con el finishReason, para poder
    // distinguir "el documento no tenía tabla" de "Gemini cortó la
    // respuesta" sin tener que reproducir el caso.
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
