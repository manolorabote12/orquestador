// El Escaparate: compartir un juego con un enlace, quitarlo, o remezclar el de otra persona.
// Peticion (POST, con sesion): { accion: "publicar" | "retirar" | "remix" | "regalo" | "regalo_retirar", project_id, autor? }
// Respuestas: publicar -> { url }   retirar -> { ok }   remix -> { project_id }
//   regalo -> { url }: enlace privado de un juego regalo (los mismos archivos, sin salir en el escaparate).
//   regalo_retirar -> { ok }: borra los archivos si el juego tampoco esta en el escaparate.

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { type Almacen, copiarParaRemix, publicar, retirar } from "../_shared/escaparate.ts";

const ERRORES: Record<string, { status: number; message: string }> = {
  project_not_found: { status: 404, message: "Ese juego no existe." },
  not_found: { status: 404, message: "Ese juego ya no está en el escaparate." },
  no_web_build: { status: 409, message: "Este juego aún no tiene versión para jugar en el navegador. Haz cualquier cambio en el taller y vuelve a intentarlo." },
  own_game: { status: 409, message: "Ese juego ya es tuyo: cámbialo en el taller." },
  daily_limit: { status: 429, message: "Has hecho muchos remix hoy. Vuelve mañana." },
  no_gift: { status: 409, message: "Primero guarda para quién es el regalo y el mensaje." },
};

function error(e: unknown) {
  const m = e instanceof Error ? e.message : String((e as { message?: string })?.message ?? e);
  const code = Object.keys(ERRORES).find((k) => m.includes(k));
  if (code) return reply(ERRORES[code].status, { error: code, message: ERRORES[code].message });
  console.error("escaparate", m);
  return reply(500, { error: "failed", message: "No se pudo hacer. Inténtalo más tarde." });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const id = typeof b.project_id === "string" && /^[0-9a-f-]{36}$/i.test(b.project_id) ? b.project_id : "";
  if (!id) return reply(400, { error: "bad_project" });
  const admin = adminClient();
  const almacen: Almacen = {
    async bajar(bucket, ruta) {
      const { data, error } = await admin.storage.from(bucket).download(ruta);
      if (error || !data) throw new Error(`download ${bucket}/${ruta}`);
      return new Uint8Array(await data.arrayBuffer());
    },
    async subir(bucket, ruta, datos, tipo) {
      const { error } = await admin.storage.from(bucket).upload(ruta, datos, { contentType: tipo, upsert: true });
      if (error) throw new Error(`upload ${bucket}/${ruta}: ${error.message}`);
    },
    async borrar(bucket, rutas) {
      await admin.storage.from(bucket).remove(rutas);
    },
  };
  try {
    if (b.accion === "publicar") {
      const { data: p } = await admin.from("projects").select("id,title,spec,version,files").eq("id", id).eq("user_id", user.id).maybeSingle();
      if (!p) throw new Error("project_not_found");
      const autor = String(b.autor ?? "").trim().slice(0, 40);
      await publicar(almacen, p, autor);
      const { error: e } = await admin.rpc("escaparate_publicar", { p_user: user.id, p_project: id, p_autor: autor });
      if (e) throw e;
      const web = (Deno.env.get("ORQ_WEB") ?? "").replace(/\/$/, "");
      return reply(200, { url: web ? `${web}/jugar.html?j=${id}` : null });
    }
    if (b.accion === "retirar") {
      const { data: p } = await admin.from("escaparate").select("project_id").eq("project_id", id).eq("user_id", user.id).maybeSingle();
      if (p) {
        await admin.rpc("escaparate_retirar", { p_user: user.id, p_project: id });
        // Si tambien es un regalo, su enlace privado sigue funcionando.
        const { data: r } = await admin.from("juego_regalos").select("project_id").eq("project_id", id).maybeSingle();
        if (!r) await retirar(almacen, id);
      }
      return reply(200, { ok: true });
    }
    if (b.accion === "regalo") {
      const { data: p } = await admin.from("projects").select("id,title,spec,version,files").eq("id", id).eq("user_id", user.id).maybeSingle();
      if (!p) throw new Error("project_not_found");
      const { data: r } = await admin.from("juego_regalos").select("project_id").eq("project_id", id).maybeSingle();
      if (!r) throw new Error("no_gift");
      await publicar(almacen, p, "");
      const web = (Deno.env.get("ORQ_WEB") ?? "").replace(/\/$/, "");
      return reply(200, { url: web ? `${web}/jugar.html?j=${id}` : null });
    }
    if (b.accion === "regalo_retirar") {
      const { data: p } = await admin.from("projects").select("id").eq("id", id).eq("user_id", user.id).maybeSingle();
      if (!p) throw new Error("project_not_found");
      const { data: e } = await admin.from("escaparate").select("project_id").eq("project_id", id).maybeSingle();
      const { data: r } = await admin.from("juego_regalos").select("project_id").eq("project_id", id).maybeSingle();
      if (!e && !r) await retirar(almacen, id);
      return reply(200, { ok: true });
    }
    if (b.accion === "remix") {
      const { data: e } = await admin.from("escaparate").select("project_id,user_id,oculto").eq("project_id", id).maybeSingle();
      if (!e || e.oculto) throw new Error("not_found");
      if (e.user_id === user.id) throw new Error("own_game");
      // Antes de copiar nada: el limite diario (el SQL lo vuelve a comprobar).
      const ayer = new Date(Date.now() - 86400000).toISOString();
      const { count } = await admin.from("projects").select("id", { count: "exact", head: true })
        .eq("user_id", user.id).not("remix_de", "is", null).gt("created_at", ayer);
      if ((count ?? 0) >= 5) throw new Error("daily_limit");
      const { data: p } = await admin.from("projects").select("files,version").eq("id", id).maybeSingle();
      if (!p) throw new Error("not_found");
      const files = await copiarParaRemix(almacen, p.files ?? {}, user.id, `remix-${id.slice(0, 8)}-${Date.now()}/v${p.version}`);
      const { data: nuevo, error: e2 } = await admin.rpc("escaparate_remix", { p_user: user.id, p_origen: id, p_files: files });
      if (e2) throw e2;
      return reply(200, { project_id: nuevo });
    }
    return reply(400, { error: "bad_action" });
  } catch (e) {
    return error(e);
  }
});
