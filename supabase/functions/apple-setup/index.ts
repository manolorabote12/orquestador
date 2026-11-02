// Datos de Apple del usuario (una vez): equipo, id de clave, emisor y la clave .p8 de la API de
// App Store Connect. La .p8 se guarda CIFRADA en el almacen privado 'llaves'; la app nunca la vuelve a ver.
// Peticion (POST, con sesion): { equipo, clave_id, emisor, p8 }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { cifrar, esClaveP8 } from "../_shared/cifrado.ts";

const ERRORES: Record<string, string> = {
  bad_team: "El ID de equipo tiene 10 letras y números (Apple Developer → Membership).",
  bad_key_id: "El ID de la clave tiene 10 letras y números (App Store Connect → Usuarios y acceso → Integraciones).",
  bad_issuer: "El emisor (Issuer ID) tiene la forma 69a6de70-0000-47e3-e053-5b8c7c11a4d1.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const equipo = String(b.equipo ?? "").trim().toUpperCase();
  const claveId = String(b.clave_id ?? "").trim().toUpperCase();
  const emisor = String(b.emisor ?? "").trim().toLowerCase();
  const p8 = String(b.p8 ?? "");
  if (!esClaveP8(p8)) return reply(400, { error: "bad_p8", message: "El archivo no parece una clave .p8 de App Store Connect." });
  const secreto = Deno.env.get("ORQ_LLAVES_SECRETO") ?? "";
  if (secreto.length < 24) return reply(503, { error: "not_configured", message: "La publicación en Apple aún no está configurada." });
  const admin = adminClient();
  const ruta = `apple/${user.id}.bin`;
  const { error: e1 } = await admin.storage.from("llaves").upload(ruta, await cifrar(p8.trim(), secreto),
    { contentType: "application/octet-stream", upsert: true });
  if (e1) return reply(500, { error: "upload_failed", message: "No se pudo guardar la clave." });
  const { error } = await admin.rpc("save_apple_account", { p_user: user.id, p_equipo: equipo, p_clave_id: claveId, p_emisor: emisor, p_ruta: ruta });
  if (error) {
    const code = Object.keys(ERRORES).find((k) => error.message.includes(k));
    return reply(400, { error: code ?? "save_failed", message: code ? ERRORES[code] : "No se pudieron guardar tus datos de Apple." });
  }
  return reply(200, { ok: true });
});
