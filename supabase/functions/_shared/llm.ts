// Llamada a la IA de texto con coste real calculado a partir del uso que devuelve la API.

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
export const LLM_MODEL = Deno.env.get("LLM_MODEL") ?? "claude-haiku-4-5-20251001";

// Precio en USD por millón de tokens (entrada, salida). Revísalo si cambias de modelo:
// https://platform.claude.com/docs/en/about-claude/pricing
const PRICES: Record<string, { in: number; out: number }> = {
  "claude-haiku-4-5-20251001": { in: 1, out: 5 },
  "claude-sonnet-5-5": { in: 2, out: 10 },
};
// Si el modelo no está en la tabla, se asume un precio alto para no infravalorar el coste.
const FALLBACK_PRICE = { in: 5, out: 25 };

export class LlmError extends Error {
  constructor(message: string, public costUsd: number) { super(message); }
}

export interface LlmResult { text: string; tokensIn: number; tokensOut: number; costUsd: number }

export function llmConfigured(): boolean {
  return ANTHROPIC_API_KEY.length > 0;
}

export async function askModel(system: string, user: string, maxTokens = 2000): Promise<LlmResult> {
  let res: Response;
  try {
    res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: LLM_MODEL,
        max_tokens: maxTokens,
        // Marca el prompt fijo como cacheable. Mientras sea más corto que el mínimo que admite
        // el modelo no se cachea ni cuesta más; cuando crezca, se abarata solo.
        system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
        messages: [{ role: "user", content: user }],
      }),
      signal: AbortSignal.timeout(60_000),
    });
  } catch (e) {
    throw new LlmError("No se pudo contactar con la IA: " + (e as Error).message, 0);
  }

  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw new LlmError(`La IA respondió ${res.status}: ${detail.slice(0, 200)}`, 0);
  }

  const data = await res.json();
  const u = data.usage ?? {};
  const p = PRICES[LLM_MODEL] ?? FALLBACK_PRICE;
  const tokensIn = (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0);
  const tokensOut = u.output_tokens ?? 0;
  const costUsd =
    ((u.input_tokens ?? 0) * p.in +
      (u.cache_creation_input_tokens ?? 0) * p.in * 1.25 +
      (u.cache_read_input_tokens ?? 0) * p.in * 0.1 +
      tokensOut * p.out) / 1e6;

  const text = (data.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("");
  if (!text) throw new LlmError("La IA no devolvió texto", costUsd);

  return { text, tokensIn, tokensOut, costUsd };
}

/** Pregunta con una imagen (revisar dibujos). Misma tabla de precios que askModel. */
export async function askModelImage(system: string, user: string, image: Uint8Array, mediaType: string, maxTokens = 400): Promise<LlmResult> {
  let b64 = "";
  for (let i = 0; i < image.length; i += 0x8000) b64 += String.fromCharCode(...image.subarray(i, i + 0x8000));
  b64 = btoa(b64);
  let res: Response;
  try {
    res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": ANTHROPIC_API_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: LLM_MODEL, max_tokens: maxTokens, system,
        messages: [{ role: "user", content: [
          { type: "image", source: { type: "base64", media_type: mediaType, data: b64 } },
          { type: "text", text: user },
        ] }],
      }),
      signal: AbortSignal.timeout(60_000),
    });
  } catch (e) {
    throw new LlmError("No se pudo contactar con la IA: " + (e as Error).message, 0);
  }
  if (!res.ok) throw new LlmError(`La IA respondió ${res.status}: ${(await res.text().catch(() => "")).slice(0, 200)}`, 0);
  const data = await res.json();
  const u = data.usage ?? {};
  const p = PRICES[LLM_MODEL] ?? FALLBACK_PRICE;
  const costUsd = ((u.input_tokens ?? 0) * p.in + (u.output_tokens ?? 0) * p.out) / 1e6;
  const text = (data.content ?? []).filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join("");
  return { text, tokensIn: u.input_tokens ?? 0, tokensOut: u.output_tokens ?? 0, costUsd };
}

// ---------------------------------------------------------------------------------------------
// Salida estructurada (herramienta forzada) con router: modelo barato -> corrección con los
// errores -> modelo superior. Mismo comportamiento que fabrica/director/llm.py.

export const LLM_MODEL_UP = Deno.env.get("LLM_MODEL_UP") ?? "claude-sonnet-5-5";

export interface Tool { name: string; description: string; input_schema: unknown }
type Msg = { role: "user" | "assistant"; content: unknown };

function costOf(model: string, u: Record<string, number>): number {
  const p = PRICES[model] ?? FALLBACK_PRICE;
  return ((u.input_tokens ?? 0) * p.in + (u.cache_creation_input_tokens ?? 0) * p.in * 1.25 +
    (u.cache_read_input_tokens ?? 0) * p.in * 0.1 + (u.output_tokens ?? 0) * p.out) / 1e6;
}

// Modelos que rechazan tool_choice forzado: se piden con tool_choice "auto" y una instruccion.
const SIN_FORZAR = new Set<string>();

async function callTool(model: string, system: string, messages: Msg[], tool: Tool): Promise<{ input: unknown; costUsd: number }> {
  let res: Response;
  const pedir = (forzar: boolean) => fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": ANTHROPIC_API_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({
      model, max_tokens: 2000,
      system: [{ type: "text", text: forzar ? system : system + `\n\nResponde SIEMPRE llamando a la herramienta ${tool.name}, sin texto aparte.`,
        cache_control: { type: "ephemeral" } }],
      tools: [tool], tool_choice: forzar ? { type: "tool", name: tool.name } : { type: "auto" }, messages,
    }),
    signal: AbortSignal.timeout(60_000),
  });
  try {
    res = await pedir(!SIN_FORZAR.has(model));
    if (res.status === 400 && !SIN_FORZAR.has(model)) {
      const txt = await res.clone().text().catch(() => "");
      if (txt.includes("tool_choice")) {
        SIN_FORZAR.add(model);
        res = await pedir(false);
      }
    }
  } catch (e) {
    throw new LlmError("No se pudo contactar con la IA: " + (e as Error).message, 0);
  }
  if (!res.ok) throw new LlmError(`La IA respondió ${res.status}: ${(await res.text().catch(() => "")).slice(0, 200)}`, 0);
  const data = await res.json();
  const costUsd = costOf(model, data.usage ?? {});
  if (data.stop_reason === "refusal") throw new LlmError("La IA ha rechazado la petición", costUsd);
  const block = (data.content ?? []).find((b: { type: string; name?: string }) => b.type === "tool_use" && b.name === tool.name);
  if (!block) throw new LlmError("La IA no usó la herramienta", costUsd);
  return { input: block.input, costUsd };
}

export async function askToolWithRouter(
  system: string, user: string, tool: Tool, validate: (x: unknown) => string[],
): Promise<{ input: unknown; costUsd: number; model: string }> {
  let spent = 0;
  let last: string[] = [];
  for (const model of [LLM_MODEL, LLM_MODEL_UP]) {
    const messages: Msg[] = [{ role: "user", content: user }];
    let r: { input: unknown; costUsd: number };
    try {
      r = await callTool(model, system, messages, tool);
    } catch (e) {
      if (e instanceof LlmError) { spent += e.costUsd; last = [e.message]; continue; }
      throw e;
    }
    spent += r.costUsd;
    let errors = validate(r.input);
    if (!errors.length) return { input: r.input, costUsd: spent, model };
    messages.push(
      { role: "assistant", content: [{ type: "tool_use", id: "t1", name: tool.name, input: r.input }] },
      { role: "user", content: [{ type: "tool_result", tool_use_id: "t1", is_error: true,
        content: "No es válido. Corrige SOLO esto y vuelve a llamar a la herramienta:\n- " + errors.slice(0, 12).join("\n- ") }] },
    );
    try {
      r = await callTool(model, system, messages, tool);
    } catch (e) {
      if (e instanceof LlmError) { spent += e.costUsd; last = [e.message]; continue; }
      throw e;
    }
    spent += r.costUsd;
    errors = validate(r.input);
    if (!errors.length) return { input: r.input, costUsd: spent, model };
    last = errors;
  }
  throw new LlmError("La propuesta sigue sin ser válida: " + last.slice(0, 4).join("; "), spent);
}
