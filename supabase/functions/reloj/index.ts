// Reloj de la nube: lo llama la propia base de datos (pg_cron + pg_net, migración 066), no la app.
//   - siempre: despierta la fábrica de RunPod si hay trabajos en cola (un aviso perdido no deja nada parado);
//   - cada 6 horas (seis_horas): reembolsos de Google Play y que la fábrica aprenda de las partidas.
// Antes lo hacía el Reloj de GitHub cada 15 minutos y se comió los minutos gratis de Actions (12 nov).
//
// Seguridad: solo vale la cabecera x-reloj con la clave aleatoria guardada en la tabla privada
// reloj_privado (la app no la puede leer).

import { adminClient, reply } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "method" });
  const admin = adminClient();
  const { data: priv } = await admin.from("reloj_privado").select("clave").maybeSingle();
  const clave = (priv as { clave?: string } | null)?.clave ?? "";
  if (!clave || req.headers.get("x-reloj") !== clave) return reply(401, { error: "unauthorized" });
  let seis = false;
  try { seis = Boolean(((await req.json()) as { seis_horas?: boolean }).seis_horas); } catch { /* sin cuerpo */ }
  const hecho: Record<string, unknown> = {};

  const { count } = await admin.from("jobs").select("id", { count: "exact", head: true }).eq("status", "queued");
  hecho.cola = count ?? 0;
  if ((count ?? 0) > 0) hecho.despertar = await despertarFabrica("reloj");

  if (seis) {
    const url = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
    const servicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    try {
      const r = await fetch(`${url}/functions/v1/play-voided`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${servicio}`, "Content-Type": "application/json" },
        body: "{}",
        signal: AbortSignal.timeout(15000),
      });
      hecho.reembolsos = r.status;
    } catch (e) {
      hecho.reembolsos = String(e).slice(0, 120);
    }
    // Aprender: un trabajo corto en la fábrica que recalibra la dificultad con las partidas.
    const endpoint = Deno.env.get("RUNPOD_FABRICA_ENDPOINT") ?? "";
    const runpod = Deno.env.get("RUNPOD_API_KEY") ?? "";
    if (endpoint && runpod) {
      const api = (Deno.env.get("ORQ_RUNPOD_API") ?? "https://api.runpod.ai/v2").replace(/\/$/, "");
      try {
        const r = await fetch(`${api}/${endpoint}/run`, {
          method: "POST",
          headers: { "Authorization": `Bearer ${runpod}`, "Content-Type": "application/json", "User-Agent": "Orquestador/1.0" },
          body: JSON.stringify({ input: { tarea: "aprender" } }),
          signal: AbortSignal.timeout(8000),
        });
        hecho.aprender = r.status;
      } catch (e) {
        hecho.aprender = String(e).slice(0, 120);
      }
    }
  }
  return reply(200, hecho);
});
