// Edge Function: extraer-poliza
//
// Recibe un PDF o imagen de una póliza (base64) y le pide a Gemini (Google
// AI Studio, nivel gratuito) que extraiga los datos estructurados para
// pre-llenar el formulario de "Nueva póliza" en la app. La API key de
// Google vive solo acá (secret de Supabase) — nunca llega al cliente
// Flutter.

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_API_KEY");
const GEMINI_MODEL = "gemini-3.6-flash";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    nro_poliza: { type: "STRING", nullable: true, description: "Número de póliza" },
    nombre_cliente: { type: "STRING", nullable: true, description: "Nombre del asegurado/tomador" },
    doc_cliente: { type: "STRING", nullable: true, description: "Número de documento del asegurado (cédula, NIT, etc.), solo dígitos" },
    nombre_aseguradora: { type: "STRING", nullable: true, description: "Nombre de la compañía aseguradora que emite la póliza" },
    nombre_ramo: { type: "STRING", nullable: true, description: "Ramo del seguro (ej: Autos, Vida, Hogar, Todo Riesgo)" },
    nombre_producto: { type: "STRING", nullable: true, description: "Nombre comercial del producto/plan" },
    fecha_inicio: { type: "STRING", nullable: true, description: "Fecha de inicio de vigencia, formato YYYY-MM-DD" },
    fecha_fin: { type: "STRING", nullable: true, description: "Fecha de fin de vigencia, formato YYYY-MM-DD" },
    fecha_expedicion: { type: "STRING", nullable: true, description: "Fecha de expedición/emisión, formato YYYY-MM-DD" },
    prima: { type: "NUMBER", nullable: true, description: "Valor de la prima, número plano sin separadores de miles ni símbolo de moneda" },
    valor_asegurado: { type: "NUMBER", nullable: true, description: "Valor asegurado, número plano" },
    valor_poliza: { type: "NUMBER", nullable: true, description: "Valor total de la póliza, número plano" },
    bien_asegurado: { type: "STRING", nullable: true, description: "Descripción del bien o riesgo asegurado (ej: placa del vehículo, dirección del inmueble)" },
  },
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
                  "Este es un documento de póliza de seguros emitido por una aseguradora colombiana. " +
                  "Extraé los datos según el schema. Si un dato no aparece en el documento, dejalo en " +
                  "null — no inventes valores.",
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
