// Sonido del taller: efectos y música hechos con el sintetizador del navegador (Web Audio).
// Sin archivos: nada que descargar y nada con derechos de nadie.
//
// Carácter: un taller de latón. Toques secos como una llave de carraca, tuercas que tintinean,
// una fanfarria corta cuando el juego sale de la fábrica y una melodía tranquila mientras se fabrica.
//
// Ajustes (se guardan en el móvil): efectos sí/no y música sí/no. Nada suena hasta el primer toque
// (los navegadores no dejan) ni con la app en segundo plano.

const CLAVE_EFECTOS = "orq-sonido";
const CLAVE_MUSICA = "orq-musica";

type Onda = OscillatorType;

let ctx: AudioContext | null = null;
let salida: GainNode | null = null;
let busMusica: GainNode | null = null;
let efectos = leer(CLAVE_EFECTOS, true);
let musicaActiva = leer(CLAVE_MUSICA, true);
let musicaPedida = false;
let relojMusica: number | null = null;
let siguienteNota = 0;
let paso = 0;

function leer(clave: string, porDefecto: boolean): boolean {
  try {
    const v = localStorage.getItem(clave);
    return v === null ? porDefecto : v === "1";
  } catch {
    return porDefecto;
  }
}

function guardar(clave: string, v: boolean): void {
  try { localStorage.setItem(clave, v ? "1" : "0"); } catch { /* sin almacenamiento: vale para esta sesión */ }
}

function audio(): AudioContext | null {
  if (ctx) return ctx;
  const C = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!C) return null;
  try {
    ctx = new C();
    salida = ctx.createGain();
    salida.gain.value = 0.9;
    // Un compresor suave: varios efectos a la vez no saturan el altavoz del móvil.
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14;
    comp.ratio.value = 4;
    salida.connect(comp).connect(ctx.destination);
    busMusica = ctx.createGain();
    busMusica.gain.value = 0;
    const filtro = ctx.createBiquadFilter();
    filtro.type = "lowpass";
    filtro.frequency.value = 2200;
    busMusica.connect(filtro).connect(salida);
  } catch {
    ctx = null;
  }
  return ctx;
}

/** Una nota: onda, frecuencia (con deslizamiento opcional), cuándo, cuánto dura y a qué volumen. */
function nota(onda: Onda, hz: number, cuando: number, dura: number, vol: number, hasta?: number, destino?: AudioNode | null): void {
  const c = ctx;
  const d = destino ?? salida;
  if (!c || !d) return;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = onda;
  o.frequency.setValueAtTime(hz, cuando);
  if (hasta) o.frequency.exponentialRampToValueAtTime(hasta, cuando + dura);
  g.gain.setValueAtTime(0.0001, cuando);
  g.gain.exponentialRampToValueAtTime(vol, cuando + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, cuando + dura);
  o.connect(g).connect(d);
  o.start(cuando);
  o.stop(cuando + dura + 0.02);
}

/** Un chasquido de ruido filtrado: el «clac» metálico de una carraca. */
function chasquido(cuando: number, hz: number, vol: number): void {
  const c = ctx;
  if (!c || !salida) return;
  const n = Math.floor(c.sampleRate * 0.03);
  const buf = c.createBuffer(1, n, c.sampleRate);
  const datos = buf.getChannelData(0);
  for (let i = 0; i < n; i++) datos[i] = (Math.random() * 2 - 1) * (1 - i / n) ** 2;
  const fuente = c.createBufferSource();
  fuente.buffer = buf;
  const f = c.createBiquadFilter();
  f.type = "bandpass";
  f.frequency.value = hz;
  f.Q.value = 2.5;
  const g = c.createGain();
  g.gain.value = vol;
  fuente.connect(f).connect(g).connect(salida);
  fuente.start(cuando);
}

export type Efecto = "toque" | "paso" | "moneda" | "gasto" | "exito" | "error" | "aviso" | "abrir";

/** Suena un efecto (si están encendidos y ya hubo un primer toque). */
export function sonar(e: Efecto): void {
  if (!efectos || document.hidden) return;
  const c = audio();
  if (!c || c.state !== "running") return;
  const t = c.currentTime + 0.005;
  switch (e) {
    case "toque":
      chasquido(t, 2600, 0.22);
      nota("triangle", 520, t, 0.05, 0.05, 380);
      break;
    case "abrir":
      nota("sine", 392, t, 0.09, 0.07, 587);
      break;
    case "aviso":
      nota("triangle", 880, t, 0.09, 0.07);
      nota("triangle", 1175, t + 0.07, 0.12, 0.06);
      break;
    case "paso":
      // Carraca y campanilla: un paso de la fábrica terminado.
      chasquido(t, 3200, 0.2);
      chasquido(t + 0.05, 3600, 0.16);
      nota("triangle", 784, t + 0.08, 0.16, 0.09);
      nota("sine", 1568, t + 0.08, 0.22, 0.04);
      break;
    case "moneda":
      // Tuerca de latón que cae en la caja: dos parciales brillantes.
      nota("sine", 1319, t, 0.28, 0.1);
      nota("sine", 1976, t + 0.045, 0.34, 0.08);
      nota("triangle", 2637, t + 0.045, 0.2, 0.03);
      break;
    case "gasto":
      nota("triangle", 660, t, 0.1, 0.08, 440);
      chasquido(t + 0.02, 1800, 0.14);
      break;
    case "exito": {
      // Fanfarria corta de latón: do, mi, sol, do.
      const notas = [523.25, 659.25, 783.99, 1046.5];
      notas.forEach((hz, i) => {
        nota("sawtooth", hz, t + i * 0.11, i === 3 ? 0.55 : 0.16, 0.05);
        nota("triangle", hz, t + i * 0.11, i === 3 ? 0.6 : 0.18, 0.1);
      });
      nota("sine", 2093, t + 0.33, 0.7, 0.04);
      break;
    }
    case "error":
      nota("sawtooth", 196, t, 0.2, 0.08, 110);
      nota("square", 98, t, 0.22, 0.04);
      break;
  }
}

// ---------------------------------------------------------------- música mientras se fabrica

// Pentatónica de do mayor: no hay nota que suene mal. Bucle de 32 pasos a 92 pulsos por minuto.
const ESCALA = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25];
const MELODIA = [0, 2, 4, 2, 3, 5, 4, -1, 2, 4, 5, 7, 5, 4, 2, -1, 0, 2, 3, 2, 4, 5, 7, -1, 5, 4, 3, 2, 3, 2, 0, -1];
const BAJO = [130.81, 130.81, 98.0, 98.0, 110.0, 110.0, 87.31, 98.0];
const SEG_PASO = 60 / 92 / 2;

function programar(): void {
  const c = ctx;
  if (!c || !busMusica) return;
  while (siguienteNota < c.currentTime + 0.25) {
    const m = MELODIA[paso % MELODIA.length];
    if (m >= 0) {
      nota("triangle", ESCALA[m], siguienteNota, SEG_PASO * 1.7, 0.16, undefined, busMusica);
      nota("sine", ESCALA[m] * 2, siguienteNota, SEG_PASO * 0.9, 0.04, undefined, busMusica);
    }
    if (paso % 4 === 0) nota("sine", BAJO[Math.floor(paso / 4) % BAJO.length], siguienteNota, SEG_PASO * 3.6, 0.22, undefined, busMusica);
    if (paso % 2 === 1) nota("sine", ESCALA[(paso * 3) % 5] / 2, siguienteNota, SEG_PASO * 0.6, 0.05, undefined, busMusica);
    siguienteNota += SEG_PASO;
    paso++;
  }
}

// ---------------------------------------------------------------- música de verdad (13 nov)
// Pistas hechas con IA (ACE-Step en RunPod: fabrica/arte_app.py musica): el tema de los menús suena
// bajito por toda la app, la de la fábrica mientras se fabrica y la fanfarria al terminar. Si los
// archivos no cargan, queda la melodía del sintetizador de siempre (solo mientras se fabrica).
type Pista = "menu" | "fabrica";
const VOLUMEN: Record<Pista, number> = { menu: 0.32, fabrica: 0.42 };
const pistas: Partial<Record<Pista, HTMLAudioElement>> = {};
let pistaSonando: Pista | null = null;
let archivosMal = false;
let jugando = false;
let primerToque = false;

function pista(p: Pista): HTMLAudioElement {
  let a = pistas[p];
  if (!a) {
    a = new Audio(`musica/${p}.mp3`);
    a.loop = true;
    a.preload = "auto";
    a.volume = 0;
    a.addEventListener("error", () => { archivosMal = true; ponerMusica(); }, { once: true });
    pistas[p] = a;
  }
  return a;
}

function fundir(a: HTMLAudioElement, hasta: number, ms: number, alAcabar?: () => void): void {
  const desde = a.volume;
  const t0 = performance.now();
  const paso = (t: number) => {
    const k = Math.min(1, (t - t0) / ms);
    a.volume = Math.max(0, Math.min(1, desde + (hasta - desde) * k));
    if (k < 1) requestAnimationFrame(paso);
    else alAcabar?.();
  };
  requestAnimationFrame(paso);
}

function ponerPistas(): void {
  const quiere: Pista | null = !musicaActiva || document.hidden || jugando || !primerToque ? null : musicaPedida ? "fabrica" : "menu";
  if (quiere === pistaSonando) return;
  if (pistaSonando) {
    const vieja = pista(pistaSonando);
    fundir(vieja, 0, 700, () => vieja.pause());
  }
  pistaSonando = quiere;
  if (quiere) {
    const a = pista(quiere);
    void a.play().then(() => fundir(a, VOLUMEN[quiere], 1200)).catch(() => { pistaSonando = null; });
  }
}

/** Un juego abierto dentro de la app tiene su propia música: la de la app se calla mientras tanto. */
export function silencioPorJuego(on: boolean): void {
  jugando = on;
  ponerMusica();
}

/** Fanfarria de verdad al terminar un juego (si los archivos están; si no, la del sintetizador). */
export function fanfarria(): void {
  if (!efectos || document.hidden) return;
  if (archivosMal) { sonar("exito"); return; }
  const a = new Audio("musica/victoria.mp3");
  a.volume = 0.6;
  void a.play().catch(() => sonar("exito"));
}

function ponerMusica(): void {
  if (!archivosMal) {
    ponerPistas();
    return;
  }
  const c = audio();
  const debe = musicaPedida && musicaActiva && !document.hidden && !jugando;
  if (!c || !busMusica) return;
  if (debe && relojMusica === null && c.state === "running") {
    siguienteNota = c.currentTime + 0.1;
    paso = 0;
    busMusica.gain.cancelScheduledValues(c.currentTime);
    busMusica.gain.setValueAtTime(busMusica.gain.value, c.currentTime);
    busMusica.gain.linearRampToValueAtTime(0.5, c.currentTime + 1.2);
    relojMusica = window.setInterval(programar, 80);
    programar();
  } else if (!debe && relojMusica !== null) {
    window.clearInterval(relojMusica);
    relojMusica = null;
    busMusica.gain.cancelScheduledValues(c.currentTime);
    busMusica.gain.setValueAtTime(busMusica.gain.value, c.currentTime);
    busMusica.gain.linearRampToValueAtTime(0, c.currentTime + 0.6);
  }
}

/** La música del taller suena mientras se fabrica algo (si el usuario la tiene encendida). */
export function musica(encendida: boolean): void {
  musicaPedida = encendida;
  ponerMusica();
}

export function efectosEncendidos(): boolean { return efectos; }
export function musicaEncendida(): boolean { return musicaActiva; }

export function ponerEfectos(v: boolean): void {
  efectos = v;
  guardar(CLAVE_EFECTOS, v);
  if (v) sonar("aviso");
}

export function ponerMusicaActiva(v: boolean): void {
  musicaActiva = v;
  guardar(CLAVE_MUSICA, v);
  ponerMusica();
}

/** Engancha el sonido a la app: despierta el audio con el primer toque y da un «clic» a cada botón. */
export function activarSonido(): void {
  const despertar = () => {
    const c = audio();
    if (!primerToque) { primerToque = true; ponerMusica(); }
    if (c && c.state === "suspended") void c.resume().then(ponerMusica).catch(() => undefined);
  };
  document.addEventListener("pointerdown", (ev) => {
    despertar();
    const el = (ev.target as HTMLElement | null)?.closest?.("button, a.btn, .tab, .chip, summary");
    if (el && !(el as HTMLButtonElement).disabled && !el.hasAttribute("data-mudo")) sonar("toque");
  }, { passive: true });
  document.addEventListener("keydown", despertar, { passive: true });
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) ponerMusica();
    else despertar();
  });
}
