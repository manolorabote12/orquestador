// Validador del JSON del juego (game-spec v1).
// La IA puede equivocarse: nunca guardamos ni servimos su salida sin pasar por aquí.
// Mismo comportamiento que el validador de la prueba web: corrige lo que está fuera
// de rango y rechaza lo que no se puede arreglar.

export type MsgKind = "err" | "fix" | "ok";
export interface Msg { kind: MsgKind; text: string }

export interface FallingObject {
  name: string;
  sprite: string;
  size: number;
  speed: number;
  weight: number;
  points?: number;
}

export interface Level {
  name: string;
  target_score: number;
  spawn_every_ms: number;
  speed_mult: number;
}

export interface GameSpec {
  schema_version: 1;
  meta: { title: string; genre: "arcade"; mode: "dodge" | "catch" };
  theme: {
    palette: { background: string; accent: string; text: string };
    background_style: "starfield" | "bubbles" | "plain";
  };
  player: { name: string; sprite: string; size: number; speed: number; lives: number };
  hazards: FallingObject[];
  collectibles: FallingObject[];
  levels: Level[];
  scoring: { points_per_second: number; highscore: boolean };
  ads: { banner: boolean; interstitial_every_n_games: number; rewarded_revive: boolean };
  texts: { start: string; game_over: string; revive: string };
}

export interface ValidationResult { spec: GameSpec | null; msgs: Msg[] }

type Obj = Record<string, unknown>;

const HEX = /^#[0-9a-fA-F]{6}$/;
const STYLES = ["starfield", "bubbles", "plain"] as const;

const obj = (v: unknown): Obj =>
  v !== null && typeof v === "object" && !Array.isArray(v) ? (v as Obj) : {};

export function validateSpec(input: unknown): ValidationResult {
  const msgs: Msg[] = [];
  const fail = (text: string): ValidationResult => ({ spec: null, msgs: [...msgs, { kind: "err", text }] });

  let raw: unknown = input;
  if (typeof input === "string") {
    try { raw = JSON.parse(input); } catch (e) { return fail("JSON mal formado: " + (e as Error).message); }
  }
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return fail("El JSON debe ser un objeto.");
  const r = raw as Obj;

  const num = (v: unknown, min: number, max: number, def: number, path: string): number => {
    if (typeof v !== "number" || Number.isNaN(v)) {
      if (v !== undefined) msgs.push({ kind: "fix", text: `${path}: no es un número, uso ${def}` });
      return def;
    }
    if (v < min || v > max) {
      const c = Math.min(max, Math.max(min, v));
      msgs.push({ kind: "fix", text: `${path}: ${v} fuera de rango, uso ${c}` });
      return c;
    }
    return v;
  };
  const str = (v: unknown, max: number, def: string): string =>
    typeof v === "string" && v.trim() ? v.trim().slice(0, max) : def;
  const color = (v: unknown, def: string, path: string): string => {
    if (typeof v === "string" && HEX.test(v)) return v;
    msgs.push({ kind: "fix", text: `${path}: color no válido, uso ${def}` });
    return def;
  };

  const meta = obj(r.meta), theme = obj(r.theme), pal = obj(theme.palette);
  const player = obj(r.player), scoring = obj(r.scoring), ads = obj(r.ads), texts = obj(r.texts);

  if (!player.sprite) return fail("Falta player.sprite: el juego necesita un protagonista.");

  const falling = (o: Obj, i: number, path: string, withPoints: boolean): FallingObject => {
    const f: FallingObject = {
      name: str(o.name, 30, `Objeto ${i + 1}`),
      sprite: str(o.sprite, 8, "●"),
      size: num(o.size, 16, 80, 36, `${path}.size`),
      speed: num(o.speed, 0.3, 3, 1, `${path}.speed`),
      weight: Math.round(num(o.weight, 1, 10, 1, `${path}.weight`)),
    };
    if (withPoints) f.points = Math.round(num(o.points, 1, 100, 10, `${path}.points`));
    return f;
  };

  const hazardsIn = Array.isArray(r.hazards) ? r.hazards.slice(0, 4) : [];
  if (!hazardsIn.length) return fail("hazards está vacío: añade al menos un peligro.");
  const levelsIn = Array.isArray(r.levels) ? r.levels.slice(0, 10) : [];
  if (!levelsIn.length) return fail("levels está vacío: añade al menos un nivel.");

  let lastTarget = 0;
  const levels: Level[] = levelsIn.map((lv, i) => {
    const l = obj(lv);
    let t = Math.round(num(l.target_score, 10, 100000, lastTarget + 100, `levels[${i}].target_score`));
    if (t <= lastTarget) {
      msgs.push({ kind: "fix", text: `levels[${i}].target_score debe crecer, uso ${lastTarget + 50}` });
      t = lastTarget + 50;
    }
    lastTarget = t;
    return {
      name: str(l.name, 30, `Nivel ${i + 1}`),
      target_score: t,
      spawn_every_ms: Math.round(num(l.spawn_every_ms, 250, 3000, 900, `levels[${i}].spawn_every_ms`)),
      speed_mult: num(l.speed_mult, 0.5, 3, 1, `levels[${i}].speed_mult`),
    };
  });

  const mode = meta.mode === "catch" ? "catch" : "dodge";
  const collectibles = (Array.isArray(r.collectibles) ? r.collectibles.slice(0, 4) : [])
    .map((c, i) => falling(obj(c), i, `collectibles[${i}]`, true));
  if (mode === "catch" && !collectibles.length) return fail("Modo catch sin collectibles: no hay nada que recoger.");

  let every = Math.round(num(ads.interstitial_every_n_games, 0, 10, 3, "ads.interstitial_every_n_games"));
  if (every === 1) {
    msgs.push({ kind: "fix", text: "ads.interstitial_every_n_games = 1 es abusivo (riesgo con AdMob), uso 2" });
    every = 2;
  }

  const style = STYLES.includes(theme.background_style as typeof STYLES[number])
    ? (theme.background_style as GameSpec["theme"]["background_style"])
    : "plain";

  const spec: GameSpec = {
    schema_version: 1,
    meta: { title: str(meta.title, 30, "Mi juego"), genre: "arcade", mode },
    theme: {
      palette: {
        background: color(pal.background, "#0b0820", "theme.palette.background"),
        accent: color(pal.accent, "#00e5ff", "theme.palette.accent"),
        text: color(pal.text, "#ffffff", "theme.palette.text"),
      },
      background_style: style,
    },
    player: {
      name: str(player.name, 30, "Jugador"),
      sprite: str(player.sprite, 8, "●"),
      size: num(player.size, 20, 80, 44, "player.size"),
      speed: num(player.speed, 0.5, 2, 1, "player.speed"),
      lives: Math.round(num(player.lives, 1, 5, 3, "player.lives")),
    },
    hazards: hazardsIn.map((h, i) => falling(obj(h), i, `hazards[${i}]`, false)),
    collectibles,
    levels,
    scoring: {
      points_per_second: num(scoring.points_per_second, 0, 20, 2, "scoring.points_per_second"),
      highscore: scoring.highscore !== false,
    },
    ads: {
      banner: ads.banner !== false,
      interstitial_every_n_games: every,
      rewarded_revive: ads.rewarded_revive !== false,
    },
    texts: {
      start: str(texts.start, 40, "Toca para empezar"),
      game_over: str(texts.game_over, 40, "Fin de la partida"),
      revive: str(texts.revive, 40, "Revivir con un anuncio"),
    },
  };

  if (!msgs.length) msgs.push({ kind: "ok", text: "JSON válido." });
  return { spec, msgs };
}

// Extrae el JSON de la respuesta del modelo: entera, dentro de un bloque ``` o del primer { al último }.
export function extractJson(text: string): unknown {
  const t = text.trim();
  try { return JSON.parse(t); } catch { /* sigue */ }
  const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) {
    try { return JSON.parse(fence[1]); } catch { /* sigue */ }
  }
  const a = t.indexOf("{"), b = t.lastIndexOf("}");
  if (a !== -1 && b > a) return JSON.parse(t.slice(a, b + 1));
  throw new Error("La respuesta no contiene JSON");
}
