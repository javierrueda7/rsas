// Edge Function: extraer-reporte-pago
//
// Recibe un PDF o imagen de un reporte de comisiones (extracto de la
// aseguradora con varias pólizas) y le pide a Gemini que extraiga la lista
// completa de líneas para revisar/cargar como abonos. La API key de Google
// vive solo acá (secret de Supabase) — nunca llega al cliente Flutter.

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_API_KEY");
const GEMINI_MODEL = "gemini-3.6-flash";

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
        "Número de póliza COMPLETO de esa línea. Si en la tabla o en la fila aparece " +
        "también un número de ANEXO para esa póliza, incluilo al final del número, " +
        "separado por un espacio (ej: '400 97 994000000046 6'), igual que el número de " +
        "póliza completo se guarda en el sistema — no lo dejes afuera.",
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

  const tiposValidos = ["application/pdf", "image/jpeg", "image/png", "image/webp"];
  if (!tiposValidos.includes(mimeType)) {
    return jsonError(`Tipo de archivo no soportado: ${mimeType}. Usá PDF, JPG, PNG o WEBP.`, 400);
  }

  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent` +
      `?key=${GOOGLE_API_KEY}`;

    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { inlineData: { mimeType, data: fileBase64 } },
              {
                text:
                  "Este es un reporte/extracto de comisiones emitido por una aseguradora colombiana a un " +
                  "intermediario de seguros. Contiene una cabecera (aseguradora, fechas del corte/período) y " +
                  "una tabla con varias pólizas y sus pagos de ese corte. Extraé la cabecera y TODAS las " +
                  "líneas/filas de la tabla, una por póliza, según el schema. Si un dato no aparece, dejalo " +
                  "en null — no inventes valores. No omitas ninguna fila de la tabla aunque falten algunos " +
                  "datos en ella.",
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
        },
      }),
    });

    if (!res.ok) {
      const detalle = await res.text();
      return jsonError(`Error de Gemini (${res.status}): ${detalle}`, 502);
    }

    const data = await res.json();
    const textoJson = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!textoJson) {
      return jsonError("Gemini no devolvió datos estructurados. Probá con otro archivo o más nítido.", 502);
    }

    let extraido: unknown;
    try {
      extraido = JSON.parse(textoJson);
    } catch {
      return jsonError("La respuesta de Gemini no fue un JSON válido.", 502);
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
