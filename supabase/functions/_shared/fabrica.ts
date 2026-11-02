// Despierta la fábrica en RunPod (CPU serverless, se paga por segundo y a cero cuando no hay
// trabajo). Se llama justo después de meter un trabajo en la cola.
//
// Secretos del servidor (nunca en la app):
//   RUNPOD_API_KEY            clave de RunPod
//   RUNPOD_FABRICA_ENDPOINT   id del endpoint de la fábrica (lo crea desplegar.py)
//
// Sin esos secretos no hace nada: entonces la cola la vacía un trabajador propio
// (python -m trabajador). Un aviso perdido no pierde el trabajo: GitHub Actions despierta
// la fábrica cada 15 minutos si queda algo en cola, y expire_stuck_jobs devuelve lo caducado.

export async function despertarFabrica(motivo: string): Promise<boolean> {
  const endpoint = Deno.env.get("RUNPOD_FABRICA_ENDPOINT") ?? "";
  const clave = Deno.env.get("RUNPOD_API_KEY") ?? "";
  if (!endpoint || !clave) return false;
  const api = (Deno.env.get("ORQ_RUNPOD_API") ?? "https://api.runpod.ai/v2").replace(/\/$/, "");
  try {
    const r = await fetch(`${api}/${endpoint}/run`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${clave}`, "Content-Type": "application/json" },
      body: JSON.stringify({ input: { despertar: motivo } }),
      signal: AbortSignal.timeout(5000),
    });
    if (!r.ok) console.error("despertarFabrica", r.status, (await r.text()).slice(0, 200));
    return r.ok;
  } catch (e) {
    console.error("despertarFabrica", String(e));
    return false;
  }
}
