// Modo experto: Chispa dentro del editor de Godot (addons/chispa) y subir el proyecto cambiado a mano.
// El plugin no tiene la sesion de la app: usa el codigo de enlace del juego (experto_enlaces).
//
// POST { accion: "enlazar", project_id }                     (con sesion: la app)       -> { codigo }
// POST { accion: "preguntar", codigo, pregunta, archivo?, texto? }  (plugin)            -> { texto }
// POST { accion: "subir_url", codigo | project_id }          (plugin o app)             -> { url, ruta }
// POST { accion: "subir", codigo | project_id, ruta }        (plugin o app)             -> { job_id, credits, cost }
//
// La subida va por URL firmada al bucket privado «experto» (<user>/<proyecto>/<marca>.zip). Al
// encargarla se cobra 'game_expert' y la fabrica la revisa (fabrica/experto.py) antes de usarla.

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { askModel, llmConfigured } from "../_shared/llm.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORES: Record<string, { status: number; message: string }> = {
  bad_code: { status: 401, message: "El código de enlace no vale o ha caducado. Crea uno nuevo en la app (Mis juegos > tu juego > Modo experto)." },
  project_not_found: { status: 404, message: "Ese juego no existe." },
  project_busy: { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  insufficient_credits: { status: 402, message: "No tienes tuercas suficientes." },
  daily_limit: { status: 429, message: "Has llegado al límite de hoy. Mañana más." },
  rate_limited: { status: 429, message: "Vas muy rápido. Espera un momento." },
  budget_exceeded: { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde." },
  not_uploaded: { status: 400, message: "No ha llegado el proyecto. Vuelve a subirlo." },
  bad_path: { status: 400, message: "Ruta de subida no válida." },
};

function error(e: { message?: string } | null, porDefecto: string): Response {
  const m = e?.message ?? "";
  const code = Object.keys(ERRORES).find((k) => m.includes(k));
  if (code) return reply(ERRORES[code].status, { error: code, message: ERRORES[code].message });
  console.error("experto", m);
  return reply(500, { error: "failed", message: porDefecto });
}

const SISTEMA = `Eres Chispa, la ayudante de Orquestador, dentro del editor de Godot 4.6. El autor ha bajado su juego
(hecho por la fábrica de Orquestador con el kit «orqkit») y lo está cambiando a mano. Contesta en español, claro y
breve (máximo 12 líneas de texto más el código). Si das código, GDScript 4 con tabulaciones y tipos estáticos.

Cómo es el proyecto:
- game.json: configuración del juego (título, paleta, jugador, enemigos, niveles en «levels», textos).
- kit/: el motor del juego por géneros (kit/<genero>/...). Se puede tocar, pero «Poner al día» lo reemplaza.
- mods/: el sitio bueno para lo propio: scripts que el kit carga solos (game.json «mods»). Una regla de juego
  hereda de "res://kit/rule_base.gd".
- scenes/ y assets/: escenas y arte (sprites en assets/<personaje>/<animacion>.png, manifest en assets/manifest.json).
- addons/, qa/, project.godot y export_presets.cfg NO se suben: la fábrica usa los suyos.
- Prohibido en lo que se sube: @tool y scripts de editor (EditorPlugin...). La fábrica lo rechaza.

Para publicar: botón «Subir a la fábrica» del panel de Chispa. La fábrica lo prueba con bots (si un bot no puede
con un nivel, no se publica y dice cuál), hace el APK y una versión nueva (se puede volver atrás en la app).`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const accion = String(b.accion ?? "");
  const admin = adminClient();

  // Quien pide: la app (sesion + project_id) o el plugin (codigo).
  async function quien(pregunta = false): Promise<{ user: string; project: string } | Response> {
    if (typeof b.codigo === "string" && b.codigo.trim()) {
      const { data, error: e } = await admin.rpc("experto_codigo", { p_code: b.codigo, p_pregunta: pregunta });
      if (e) return error(e, "No se pudo comprobar el código.");
      const row = Array.isArray(data) ? data[0] : data;
      return { user: row.user_id, project: row.project_id };
    }
    const u = await sessionUser(req);
    if (!u) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
    const p = typeof b.project_id === "string" ? b.project_id : "";
    if (!/^[0-9a-f-]{36}$/i.test(p)) return reply(400, { error: "bad_project" });
    const { data } = await admin.from("projects").select("id").eq("id", p).eq("user_id", u.id).maybeSingle();
    if (!data) return reply(404, { error: "project_not_found", message: ERRORES.project_not_found.message });
    return { user: u.id, project: p };
  }

  if (accion === "enlazar") {
    const u = await sessionUser(req);
    if (!u) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
    const { data, error: e } = await admin.rpc("experto_enlazar", { p_user: u.id, p_project: String(b.project_id ?? "") });
    if (e) return error(e, "No se pudo crear el código.");
    return reply(200, { codigo: data });
  }

  if (accion === "preguntar") {
    const q = await quien(true);
    if (q instanceof Response) return q;
    const pregunta = String(b.pregunta ?? "").trim().slice(0, 1500);
    if (pregunta.length < 3) return reply(400, { error: "bad_question", message: "Escribe tu pregunta." });
    if (!llmConfigured()) return reply(503, { error: "no_llm", message: "Chispa no está disponible ahora mismo." });
    const { data: p } = await admin.from("projects").select("title, spec").eq("id", q.project).maybeSingle();
    const spec = (p?.spec ?? {}) as Record<string, unknown>;
    const archivo = String(b.archivo ?? "").slice(0, 200);
    const texto = String(b.texto ?? "").slice(0, 12000);
    const usuario = `Juego: «${p?.title ?? ""}» (género ${String(spec.genero ?? "?")}).\n` +
      (archivo ? `Archivo abierto: ${archivo}\n` : "") + (texto ? `Su contenido:\n\`\`\`\n${texto}\n\`\`\`\n` : "") +
      `Pregunta: ${pregunta}`;
    try {
      const r = await askModel(SISTEMA, usuario, 900);
      return reply(200, { texto: r.text.trim() });
    } catch (e) {
      console.error("experto preguntar", (e as Error).message);
      return reply(502, { error: "llm", message: "Chispa no ha podido contestar. Prueba otra vez." });
    }
  }

  if (accion === "subir_url") {
    const q = await quien();
    if (q instanceof Response) return q;
    const ruta = `${q.user}/${q.project}/${Date.now()}.zip`;
    const { data, error: e } = await admin.storage.from("experto").createSignedUploadUrl(ruta);
    if (e || !data) return error(e, "No se pudo preparar la subida.");
    return reply(200, { url: data.signedUrl, ruta });
  }

  if (accion === "subir") {
    const q = await quien();
    if (q instanceof Response) return q;
    const { data, error: e } = await admin.rpc("queue_expert", { p_user: q.user, p_project: q.project, p_path: String(b.ruta ?? "") });
    if (e) return error(e, "No se pudo encargar la versión.");
    const row = Array.isArray(data) ? data[0] : data;
    await despertarFabrica("experto");
    return reply(200, { job_id: row.job_id, credits: row.credits_left, cost: row.cost });
  }

  return reply(400, { error: "bad_action" });
});
