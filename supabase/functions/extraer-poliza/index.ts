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
    nro_poliza: {
      type: "STRING",
      nullable: true,
      description:
        "Número de póliza COMPLETO, en el formato exacto SEGMENTO1-SEGMENTO2-...-ANEXO " +
        "(todos los segmentos del número, uno detrás de otro, unidos con GUIONES, y el " +
        "número de ANEXO agregado SIEMPRE al final como un segmento más, incluso cuando " +
        "el anexo es '0' — el anexo va siempre, no solo cuando es mayor a 0). Los " +
        "segmentos pueden tener letras y números (ej: 'B', '400', '97', '994000000046'). " +
        "Si el documento separa los segmentos del número de póliza con espacios en vez " +
        "de guiones, igual los unís todos con guion en el resultado — NUNCA dejes " +
        "espacios en el resultado, solo guiones. Ejemplos: 'Póliza No' = '400-97-" +
        "994000000046', 'ANEXO' = '6' → resultado '400-97-994000000046-6'. " +
        "'No. PÓLIZA' = 'B-100071475', 'No. ANEXO' = '0' → resultado 'B-100071475-0' " +
        "(el anexo en 0 igual se agrega). Si el documento no tiene un campo ANEXO " +
        "separado (no aplica a esa aseguradora), no agregues nada al final y dejá el " +
        "número tal cual, con guiones en vez de espacios si tenía espacios.",
    },
    nombre_cliente: {
      type: "STRING",
      nullable: true,
      description:
        "Nombre del TOMADOR de la póliza (quien la contrata y paga la prima) — normalmente " +
        "es el cliente real del intermediario de seguros. Buscá específicamente la " +
        "sección/etiqueta 'TOMADOR' o 'DATOS DEL TOMADOR' del documento — normalmente es " +
        "un bloque propio, separado y antes de la sección 'ASEGURADO' o 'DATOS DEL " +
        "ASEGURADO Y BENEFICIARIO'. Esto es solo un candidato — quien decide cuál de los " +
        "candidatos (Tomador/Asegurado/Beneficiario) es el cliente real de verdad es la " +
        "app, comparando cada documento contra su base de clientes ya registrados, así " +
        "que no hace falta acertar perfecto acá: con que quede claro cuál bloque es cuál " +
        "alcanza. Solo usá el Asegurado si el documento no tiene ningún bloque TOMADOR " +
        "separado (son la misma persona/campo).",
    },
    doc_cliente: {
      type: "STRING",
      nullable: true,
      description:
        "Número de documento del TOMADOR (ver nombre_cliente), solo dígitos y letras " +
        "(sin puntos ni espacios, pero SÍ conservá el guion del dígito de verificación " +
        "de un NIT si lo tiene, ej. '901983472-9').",
    },
    nombre_asegurado: {
      type: "STRING",
      nullable: true,
      description:
        "Nombre del ASEGURADO de la póliza (bloque 'ASEGURADO' o 'DATOS DEL ASEGURADO'), " +
        "SOLO cuando es una persona/entidad distinta del Tomador. Es el segundo candidato " +
        "a cliente real — la app decide cuál de los dos (Tomador o Asegurado) coincide " +
        "con un cliente ya existente en su base. Si Tomador y Asegurado son la misma " +
        "persona/campo, dejá este campo vacío.",
    },
    doc_asegurado: {
      type: "STRING",
      nullable: true,
      description:
        "Número de documento del ASEGURADO (ver nombre_asegurado), mismo formato que " +
        "doc_cliente. Vacío si Tomador y Asegurado son la misma persona/campo.",
    },
    nombre_beneficiario: {
      type: "STRING",
      nullable: true,
      description:
        "Nombre del BENEFICIARIO de la póliza (bloque 'BENEFICIARIO'), SOLO cuando es una " +
        "persona/entidad distinta del Tomador y del Asegurado. Tercer candidato a cliente " +
        "real, mismo criterio que nombre_asegurado.",
    },
    doc_beneficiario: {
      type: "STRING",
      nullable: true,
      description:
        "Número de documento del BENEFICIARIO (ver nombre_beneficiario), mismo formato " +
        "que doc_cliente.",
    },
    nombre_aseguradora: { type: "STRING", nullable: true, description: "Nombre de la compañía aseguradora que emite la póliza" },
    nombre_ramo: {
      type: "STRING",
      nullable: true,
      description:
        "Ramo del seguro (ej: Autos, Vida, Hogar, Todo Riesgo, Accidentes Personales). " +
        "Muchos documentos NO tienen un campo 'Ramo' en texto plano (a veces solo un " +
        "código numérico junto a 'RAMO'), así que si no encontrás uno explícito dejalo " +
        "en null en vez de inventarlo — nombre_producto es más importante, el ramo se " +
        "puede terminar de resolver a partir de él.",
    },
    nombre_producto: {
      type: "STRING",
      nullable: true,
      description:
        "Nombre comercial del producto/plan. Si el documento no tiene un campo explícito " +
        "'Producto' o 'Plan', usá el título/encabezado que describe el tipo de póliza " +
        "(ej: si el título dice 'POLIZA SEGURO DE ACCIDENTES ESCOLARES', el producto es " +
        "'Accidentes Escolares' o 'Seguro de Accidentes Escolares') — ese texto es la " +
        "pista más confiable para identificar qué producto es, más que el campo 'Ramo'.",
    },
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
                  "Extraé los datos según el schema. Prestá especial atención a nro_poliza: seguí " +
                  "exactamente las instrucciones de su descripción sobre cómo armar el número completo " +
                  "cuando el documento tiene un ANEXO. Prestá especial atención también a distinguir " +
                  "bien los bloques Tomador/Asegurado/Beneficiario cuando el documento los separa — " +
                  "llenar nombre_asegurado/doc_asegurado (y beneficiario) cuando existan como bloques " +
                  "propios es tan importante como llenar nombre_cliente/doc_cliente. Si un dato no " +
                  "aparece en el documento, dejalo en null — no inventes valores.",
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
