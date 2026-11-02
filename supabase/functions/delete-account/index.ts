// Borrar la cuenta (Google Play exige poder hacerlo desde la app). Irreversible.
// Peticion (POST, con sesion): { confirmar: "BORRAR" }   Respuesta: { ok: true, premium_activo }
//
// Orden: preparar_borrado (comprueba que no haya nada fabricandose, guarda los pedidos sin datos
// personales y devuelve sus juegos) -> permiso de YouTube revocado en Google -> archivos (juegos,
// politicas, llaves) -> usuario. Al borrar el usuario se va todo lo demas en cascada.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";

const ERRORES: Record<string, { status: number; message: string }> = {
  job_running: { status: 409, message: "Tienes algo fabricándose. Espera a que termine y vuelve a intentarlo." },
  user_not_found: { status: 404, message: "Esa cuenta ya no existe." },
};

/** 1 - Borra todo lo que hay debajo de una carpeta del almacen (el listado no es recursivo). */
async function borrarCarpeta(admin: SupabaseClient, bucket: string, carpeta: string): Promise<number> {
  let total = 0;
  for (let vuelta = 0; vuelta < 50; vuelta++) {
    const { data, error } = await admin.storage.from(bucket).list(carpeta, { limit: 1000 });
    if (error || !data?.length) break;
    const archivos = data.filter((x) => x.id).map((x) => `${carpeta}/${x.name}`);
    for (const sub of data.filter((x) => !x.id)) total += await borrarCarpeta(admin, bucket, `${carpeta}/${sub.name}`);
    if (!archivos.length) break;
    const { error: e2 } = await admin.storage.from(bucket).remove(archivos);
    if (e2) throw new Error(`storage ${bucket}: ${e2.message}`);
    total += archivos.length;
  }
  return total;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  if (b.confirmar !== "BORRAR") return reply(400, { error: "not_confirmed", message: "Escribe BORRAR para confirmar." });

  const admin = adminClient();
  const { data: refresh } = await admin.rpc("youtube_token", { p_user: user.id });
  const { data, error } = await admin.rpc("preparar_borrado", { p_user: user.id });
  if (error) {
    const code = Object.keys(ERRORES).find((k) => error.message.includes(k));
    if (code) return reply(ERRORES[code].status, { error: code, message: ERRORES[code].message });
    return reply(500, { error: "prepare_failed", message: "No se pudo borrar la cuenta. Inténtalo más tarde." });
  }
  const info = data as { juegos: string[]; premium_activo: boolean };

  // 2 - Permiso de YouTube: se revoca en Google (si falla, el token muere igual con la fila).
  if (typeof refresh === "string" && refresh) {
    try {
      await fetch("https://oauth2.googleapis.com/revoke", { method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ token: refresh }) });
    } catch { /* sin red: seguimos */ }
  }

  // 3 - Archivos: juegos y videos, politicas publicas de sus juegos, llaves de firma y de Apple.
  try {
    await borrarCarpeta(admin, "juegos", user.id);
    for (const p of info.juegos ?? []) {
      await borrarCarpeta(admin, "legal", p);
      await borrarCarpeta(admin, "escaparate", p);
    }
    await admin.storage.from("llaves").remove([`${user.id}.llave`, `apple/${user.id}.bin`]);
  } catch (e) {
    console.error("delete-account storage", e);
    return reply(500, { error: "storage_failed", message: "No se pudieron borrar todos tus archivos. Inténtalo de nuevo." });
  }

  // 4 - El usuario: perfil, juegos, versiones, trabajos, compras, Lanzadera... en cascada.
  const { error: e3 } = await admin.auth.admin.deleteUser(user.id);
  if (e3) return reply(500, { error: "delete_failed", message: "No se pudo borrar la cuenta. Inténtalo más tarde." });
  return reply(200, { ok: true, premium_activo: !!info.premium_activo });
});
