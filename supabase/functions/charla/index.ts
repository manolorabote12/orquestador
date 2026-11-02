// Charla en directo con un personaje del juego. La llama el juego (clave anon, sin sesion).
// Peticion (POST): { juego, sesion, personaje: "heroe"|"rival"|"jefe", mensaje, historial: [{de, texto}] }
// Respuesta: { texto, nombre, offline? }   offline=true -> frase de respaldo (sin cupo, sin IA o filtrada).
// El cupo lo paga el autor del juego con tuercas (charla_activar). La clave de la IA solo vive aqui.

import { adminClient, CORS, reply } from "../_shared/http.ts";
import { askModel, llmConfigured } from "../_shared/llm.ts";
import { esquiva, limpiar, moderar, personajes, respaldo, sistema, usuario, validar } from "../_shared/charla.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  let b: unknown;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const pt = validar(b);
  if (typeof pt === "string") return reply(400, { error: pt });
  const n = Date.now() % 997;
  // 1 - Filtro antes de gastar nada.
  if (moderar(pt.mensaje) !== "") return reply(200, { texto: esquiva(pt.personaje), offline: true });
  const admin = adminClient();
  const { data, error } = await admin.rpc("charla_reservar", { p_juego: pt.juego, p_sesion: pt.sesion });
  if (error) {
    const m = error.message ?? "";
    if (m.includes("rate_limited")) {
      return reply(429, { error: "rate_limited", texto: "¡Uf, cuánto hablamos! Sigamos mañana, ahora a jugar.", offline: true });
    }
    // Sin cupo, juego desconocido...: el personaje contesta con sus frases de siempre.
    return reply(200, { texto: respaldo(pt.personaje, n), offline: true });
  }
  const spec = (data?.spec ?? {}) as Record<string, unknown>;
  const reparto = personajes(spec);
  const p = reparto[pt.personaje];
  const envio = Number(data?.envio ?? 0);
  if (!p || !llmConfigured()) {
    await admin.rpc("charla_coste", { p_envio: envio, p_cost_usd: 0, p_ok: false });
    return reply(200, { texto: respaldo(pt.personaje, n), offline: true });
  }
  // 2 - La IA, con el personaje del diseno guardado (nunca del juego).
  try {
    const r = await askModel(sistema(p, spec, String(data?.title ?? spec.titulo ?? "")), usuario(pt), 160);
    const texto = limpiar(r.text);
    await admin.rpc("charla_coste", { p_envio: envio, p_cost_usd: r.costUsd, p_ok: texto !== "" });
    if (!texto) return reply(200, { texto: esquiva(pt.personaje), nombre: p.nombre, offline: true });
    return reply(200, { texto, nombre: p.nombre });
  } catch (e) {
    console.error("charla", (e as Error).message);
    await admin.rpc("charla_coste", { p_envio: envio, p_cost_usd: 0, p_ok: false });
    return reply(200, { texto: respaldo(pt.personaje, n), nombre: p.nombre, offline: true });
  }
});
