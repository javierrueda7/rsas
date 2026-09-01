// Edge Function: login
//
// Verifica apodo+clave contra la función `autenticar_usuario` (que ya existía
// y sigue comparando el hash bcrypt server-side, ver migracion_hash_claves.sql)
// y, si son válidos, firma un JWT propio de Supabase (HS256, con el "Legacy
// JWT secret" del proyecto). Ese token es lo que le permite al cliente Flutter
// hacer consultas como rol `authenticated` una vez habilitada la RLS — ver
// lib/fix_rls_seguridad.sql. El secret nunca sale de acá.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const JWT_SECRET = Deno.env.get("LOGIN_JWT_SECRET");

// Duración de la sesión: 12 horas (una jornada). No hay refresh token —
// pasado ese tiempo, la próxima consulta falla y hay que loguearse de nuevo.
const EXPIRACION_SEGUNDOS = 12 * 60 * 60;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonError("Método no permitido.", 405);
  }
  if (!JWT_SECRET) {
    return jsonError("Falta configurar LOGIN_JWT_SECRET en los secrets de Supabase.", 500);
  }

  let body: { apodo?: string; clave?: string };
  try {
    body = await req.json();
  } catch {
    return jsonError("Body inválido, se esperaba JSON.", 400);
  }

  const apodo = (body.apodo ?? "").trim();
  const clave = body.clave ?? "";
  if (!apodo || !clave) {
    return jsonError("Faltan apodo y/o clave.", 400);
  }

  try {
    const rpcRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/autenticar_usuario`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "apikey": SUPABASE_ANON_KEY,
        "authorization": `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({ p_apodo: apodo, p_clave: clave }),
    });

    if (!rpcRes.ok) {
      const detalle = await rpcRes.text();
      return jsonError(`Error al verificar credenciales: ${detalle}`, 502);
    }

    const filas = await rpcRes.json();
    if (!Array.isArray(filas) || filas.length === 0) {
      return jsonError("Usuario o contraseña incorrectos.", 401);
    }

    const usuario = filas[0];
    const ahora = Math.floor(Date.now() / 1000);
    const payload = {
      aud: "authenticated",
      role: "authenticated",
      sub: String(usuario.id),
      iat: ahora,
      exp: ahora + EXPIRACION_SEGUNDOS,
      apodo_usuario: usuario.apodo_usuario,
      rol_app: usuario.rol,
    };

    const accessToken = await firmarJwtHS256(payload, JWT_SECRET);

    return new Response(
      JSON.stringify({ usuario, accessToken, expiresAt: payload.exp }),
      { headers: { ...CORS_HEADERS, "content-type": "application/json" } },
    );
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

// ── Firma JWT HS256 sin dependencias externas (Web Crypto API) ─────────────

function base64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}

async function firmarJwtHS256(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const data = `${base64urlJson(header)}.${base64urlJson(payload)}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(data),
  );

  return `${data}.${base64url(new Uint8Array(signature))}`;
}
