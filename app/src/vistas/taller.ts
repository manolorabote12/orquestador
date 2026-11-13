// Taller: escribes la idea, la fábrica la convierte en juego y Chispa cuenta cada paso en vivo.

import { avisarJuegoListo, cancelarAvisoEspera, pedirValoracion, prepararAvisos, programarAvisoEspera, vibrar } from "../comodidad";
import type { App } from "../main";
import { type Trabajo } from "../api";
import { seccionEscaparate, tarjetaBienvenida } from "./escaparate";
import { seccionReto } from "./reto";
import { abrirJugador } from "../jugador";
import { GENERO_NOMBRE, GIROS, PLANTILLAS, type Plantilla } from "../plantillas-datos";
import { ICONOS, abrir, aviso, crearChispa, h, svg, type VistaHecha, fotoGenero } from "../ui";
import { mensajeError } from "../errores";
import { encaja, nuevos, type Tipo } from "../catalogo";
import { USOS, infoUso, type Uso } from "../usos";
import { abrirSeccion } from "./juegos";
import { fanfarria, musica, sonar } from "../sonido";
import { chispas } from "../efectos";

// Dos engranajes de latón engranados (el pequeño gira al revés y más deprisa).
const DIENTES = (n: number, r: number) => Array.from({ length: n }, (_, i) =>
  `<rect x="-3.2" y="${-r - 5}" width="6.4" height="8" rx="1.4" transform="rotate(${(360 / n) * i})"/>`).join("");
const ENGRANAJES = `<svg viewBox="0 0 96 60" class="fab-gears"><g transform="translate(34 32)"><g class="gear g1" fill="#e8b04b" stroke="#9c6b1f" stroke-width="1.2">${DIENTES(10, 19)}<circle r="19"/><circle r="7" fill="#0a1e36"/></g></g><g transform="translate(70 19)"><g class="gear g2" fill="#f6cf7a" stroke="#9c6b1f" stroke-width="1.2">${DIENTES(7, 11)}<circle r="11"/><circle r="4.2" fill="#0a1e36"/></g></g></svg>`;

/** Celebración: una lluvia breve de tuercas de latón cuando el juego sale de la fábrica. */
function lluviaDeTuercas(): void {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const capa = h("div", { class: "lluvia", "aria-hidden": "true" });
  for (let i = 0; i < 26; i++) {
    const t = svg(ICONOS.tuerca);
    t.style.setProperty("--x", `${Math.round(Math.random() * 100)}vw`);
    t.style.setProperty("--giro", `${Math.round(Math.random() * 720 - 360)}deg`);
    t.style.setProperty("--tam", `${14 + Math.round(Math.random() * 16)}px`);
    t.style.animationDelay = `${Math.round(Math.random() * 500)}ms`;
    t.style.animationDuration = `${1300 + Math.round(Math.random() * 900)}ms`;
    capa.append(t);
  }
  document.body.append(capa);
  window.setTimeout(() => capa.remove(), 2900);
}

const EJEMPLOS = [
  "Un gato ninja rápido que salta por tejados de noche",
  "Un robot de plataformas en 3D low poly en una fábrica de juguetes",
  "Corre por tres carriles esquivando trenes en una ciudad de neón (3D)",
  "Carreras de coches en 3D por un desierto al atardecer",
  "Un matamarcianos: tu nave contra invasores de colores",
  "Rompe ladrillos con una pelota en un castillo de caramelo",
  "Encaja bloques en un tablero de un jardín japonés",
  "Una serpiente que come fresas en un huerto",
  "Un juego de memoria con animales de la granja para peques",
  "Un pingüino que empuja cajas de regalos hasta su sitio (sokoban)",
  "Un trivial de preguntas sobre los planetas para niños",
  "Apila bloques de tarta hasta el cielo de un toque",
  "Aplasta a los topos traviesos que asoman en el huerto",
  "Todos contra todos en una arena de robots chatarreros: el último en pie gana",
  "Asalta la aldea de los clanes piratas con tu ejército de gatos vikingos",
  "Una rana que sube saltando hacia arriba por nenúfares hasta la luna",
  "Sobrevive a hordas de zombis en un cementerio",
  "Un puzle de combinar gemas en un bosque mágico",
  "Defiende tu castillo de oleadas de monstruos con torres",
  "Un zorro que huye corriendo sin parar por un volcán (runner)",
  "Un pájaro de papel que vuela entre columnas de un toque",
  "Astronauta en pixel art saltando entre planetas, difícil",
  "Un juego de ritmo musical con tambores en una selva de neón",
  "Un clicker idle donde construyes un imperio de pasteles",
  "Un solitario de cartas en un casino pirata",
  "Un rpg por turnos de caballeros contra monstruos de la cueva",
];

// Catálogo de géneros: nombre, qué se hace y una idea de arranque que se completa con el tema.
const CATALOGO: [string, string, string][] = [
  ["Plataformas", "Salta y pisa a tus enemigos", "Un juego de plataformas de "],
  ["Runner", "Corre sin parar y salta", "Un runner que corre sin parar de "],
  ["Volador", "Toca para volar", "Un juego de volar de un toque con "],
  ["Saltos", "Rebota hasta la cima", "Un juego de saltos hacia arriba de "],
  ["Corredor 3D", "Corre, salta y esquiva en 3D", "Corre por tres carriles esquivando trenes con "],
  ["Carreras", "Adelanta a tus rivales", "Carreras de "],
  ["Naves", "Dispara y esquiva oleadas", "Un matamarcianos con "],
  ["Hordas", "Sobrevive a las hordas", "Sobrevive a hordas de "],
  ["Torres", "Defiende tu base con torres", "Defiende tu castillo con torres de "],
  ["Rompebloques", "Rompe ladrillos con la pelota", "Rompe ladrillos con una pelota en "],
  ["Puzle de 3", "Combina 3 y crea especiales", "Un puzle de combinar gemas de "],
  ["Bloques", "Encaja piezas y limpia líneas", "Encaja bloques en un tablero de "],
  ["Cajas", "Empuja cada caja a su hueco", "Un sokoban de empujar cajas con "],
  ["Serpiente", "Come, crece y no choques", "Una serpiente que come "],
  ["Memoria", "Encuentra todas las parejas", "Un juego de memoria con "],
  ["Preguntas", "Responde y suma aciertos", "Un trivial de preguntas sobre "],
  ["Apilar", "Apila y sube hasta las nubes", "Apila bloques de "],
  ["Topos", "Aplasta a los que asoman", "Aplasta a los topos traviesos de "],
  ["Arena", "Todos contra todos: el último en pie gana", "Todos contra todos en una arena de "],
  ["Aldea", "Asalta bases con tu ejército", "Asalta la base enemiga de los clanes de "],
  ["Ritmo", "Toca las notas a tiempo", "Un juego de ritmo musical con "],
  ["Clicker", "Toca, contrata y crece", "Un clicker idle donde construyes un imperio de "],
  ["Cartas", "Solitario de una arriba o abajo", "Un solitario de cartas en "],
  ["RPG por turnos", "Ataca, cura y usa tu especial", "Un rpg por turnos de "],
  ["Laberinto", "Llaves, puertas y monedas", "Un laberinto de "],
  ["Minigolf", "Apunta y métela en pocos golpes", "Un minigolf de "],
  ["Pesca", "Lanza el anzuelo a tiempo", "Un juego de pesca de "],
  ["Fusión", "Junta iguales y crece", "Un juego de fusionar "],
  ["Tubos", "Ordena los colores", "Un puzle de ordenar colores en tubos de "],
  ["Burbujas", "Apunta y junta 3 iguales", "Un lanza burbujas de "],
  ["Imperio", "Recursos, edades y conquista", "Un juego de estrategia en tiempo real tipo Age of Empires de "],
  ["Minas", "Excava, mejora y hazte rico", "Un idle de minas tipo Idle Miner donde excavan "],
  ["Mazmorras", "RPG de acción con botín", "Un rpg de acción tipo Archero donde un héroe limpia mazmorras de "],
  ["Granja", "Cultiva, cría y cumple pedidos", "Un juego de granja cozy tipo Hay Day de "],
  ["Mazo", "Combates de cartas con estrategia", "Un deckbuilder de cartas de estrategia tipo Slay the Spire de "],
  ["Aventura", "Historia con decisiones y finales", "Una historia con decisiones por capítulos sobre "],
  ["Cocina", "Cocina y sirve antes de que se cansen", "Un juego de cocina tipo Cooking Fever en "],
  ["Mahjong", "Parejas de fichas en montones", "Un mahjong solitario de parejas de fichas en "],
  ["Aparcamiento", "Saca los coches sin chocar", "Un puzle de aparcamiento tipo Parking Jam en "],
  ["Sopa de letras", "Encuentra las palabras escondidas", "Una sopa de letras de "],
  ["Sudoku", "Números sin repetir, de 4x4 a 9x9", "Un sudoku con ambiente de "],
  ["Nonograma", "Pinta y descubre el dibujo", "Un nonograma tipo Picross con dibujos de "],
  ["Cortar fruta", "Corta en el aire, esquiva bombas", "Un juego de cortar fruta tipo Fruit Ninja con "],
  ["Penaltis", "Chuta y engaña al portero", "Una tanda de penaltis en "],
  ["Agujero", "Trágate la ciudad entera", "Un agujero que se lo traga todo tipo Hole.io en "],
  ["Ciudad", "Construye y haz crecer tu ciudad", "Un constructor de ciudades en "],
  ["Torre espiral", "Gira la torre y baja la bola", "Una torre en espiral tipo Helix Jump de "],
  ["Canasta", "Lanza y encesta", "Tiros a canasta en "],
  ["Buscaminas", "Lógica sin adivinar", "Un buscaminas en "],
  ["Conecta 4", "4 en raya contra la máquina", "Un conecta 4 contra la máquina con "],
  ["Damas", "Damas contra la máquina", "Unas damas contra la máquina con "],
  ["Billar", "Mete todas las bolas", "Retos de billar en "],
  ["Solitario", "El clásico de cartas", "El solitario clásico con cartas de "],
  ["Parchís", "Dado y fichas contra la máquina", "Un parchís contra "],
  ["Bloques que caen", "Gira y encaja piezas", "El clásico de bloques que caen en "],
  ["Bolos", "Lanza con efecto", "Una partida de bolos en "],
  ["Mundo abierto", "Pica, fabrica y sobrevive", "Un mundo abierto de bloques con "],
  ["Battle royale", "El último en pie gana", "Un battle royale desde arriba en "],
  ["Cruzar", "Salta carreteras y ríos", "Un juego de cruzar carreteras y ríos con "],
  ["Tiro con arco", "Viento y dianas", "Tiro con arco en "],
  ["Mundo de cubos 3D", "Pica y construye", "Un mundo de cubos en 3D de "],
  ["Parkour 3D", "Salta hasta la meta", "Un parkour 3D de saltos entre "],
  ["Tienda 3D", "Repone, cobra y crece", "Un simulador de supermercado 3D en "],
  ["Fútbol 3D", "Pasa, tira y gana", "Fútbol arcade en 3D de "],
  ["Terror 3D", "Escapa de la casa", "Terror en 3D en "],
  ["Conducción 3D", "Repartos por la ciudad", "Conducción 3D por "],
  ["Zombis 3D", "Shooter en primera persona", "Shooter 3D de zombis en "],
  ["Baloncesto 3D", "Partido callejero", "Baloncesto 3D en "],
  ["Tenis 3D", "Partido en la pista", "Tenis 3D en "],
  ["Karts 3D", "Carreras con derrapes", "Carreras de karts en 3D en "],
  ["Supervivencia", "Isla, hambre y noches", "Supervivencia en "],
  ["Triple de fichas", "Junta tres iguales", "Un triple de fichas de "],
  ["Tornillos", "Placas que caen", "Un puzle de tornillos de "],
  ["Hexa sort", "Torres de colores", "Un hexa sort de "],
  ["Bus jam", "Cada uno a su autobús", "Un bus jam de "],
  ["Duelo de cartas 3D", "Torres, elixir y cartas", "Un duelo de cartas en 3D de "],
  ["Escalada", "Colinas sin volcar", "Una escalada en coche por "],
  ["Tirachinas", "Derriba las torres", "Un tirachinas contra torres de "],
  ["Plantas contra zombis", "Defiende tu jardín", "Plantas contra zombis en "],
  ["Adivina la palabra", "Seis intentos", "Un wordle de "],
  ["Palabras con letras", "Rueda y crucigrama", "Un wordscapes de "],
  ["Tycoon", "Negocios y gerentes", "Un idle tycoon de "],
  ["Tragaperras y aldea", "Tira y construye (+18)", "Un coin master de "],
  ["Reino", "Ciudad, tropas y conquista", "Un reino tipo Kingshot de "],
  ["Multitud", "Puertas que suman", "Un count masters de "],
  ["Fusión con pedidos", "Junta y entrega", "Un merge de pedidos en "],
  ["Torre de poder", "Vence al más débil", "Una torre de poder de "],
  ["Diferencias", "Mira bien y encuentra", "Un encuentra las diferencias de "],
  ["Rompecabezas", "Completa el dibujo", "Un rompecabezas de "],
  ["Pintar por números", "Colorea sin prisa", "Un pintar por números de "],
  ["Lanza cuchillos", "Clava sin chocar", "Un lanza cuchillos de "],
  ["Arquero de salas", "Esquiva y mejora", "Un archero de "],
  ["Flechas", "Piensa el orden", "Un puzle de flechas que salen de "],
  ["2048", "Junta números", "Un 2048 de "],
  ["Cartas locas", "Color o número", "Un juego de cartas locas de "],
  ["Dominó", "Encaja las fichas", "Un dominó de "],
  ["Bloques de colores", "Cada uno a su puerta", "Un juego de sacar bloques de colores por su puerta en "],
  ["Tuberías", "Gira y conecta", "Un juego de girar tuberías en "],
  ["Ajedrez", "Jaque mate", "Un juego de ajedrez en "],
  ["Reversi", "Da la vuelta", "Un juego de reversi en "],
  ["Buscar objetos", "Encuentra la lista", "Un juego de buscar objetos en "],
  ["Deslizar", "Recompón el dibujo", "Un puzle de deslizar en "],
  ["Ahorcado", "Letra a letra", "Un juego del ahorcado en "],
  ["Hundir la flota", "Tocado y hundido", "Un juego de hundir la flota en "],
  ["Simón dice", "Repite la secuencia", "Un juego de Simón dice en "],
  ["Estrategia por turnos", "Mueve y conquista", "Un juego de estrategia por turnos en "],
  ["Batalla automática", "Compra, funde y lucha", "Un juego de batalla automática en "],
  ["Gemas y héroes", "Combina y ataca", "Un juego de gemas y héroes en "],
  ["Cartas coleccionables", "Esbirros y hechizos", "Un juego de cartas coleccionables en "],
  ["Roguelike por turnos", "Mazmorra casilla a casilla", "Un roguelike por turnos en "],
  ["Bombas", "Laberinto de cajas", "Un juego de bombas en "],
  ["Artillería", "Disparos por turnos con viento", "Una batalla de artillería por turnos en "],
  ["Comecocos", "Laberinto de puntos y fantasmas", "Un comecocos en "],
  ["Cadena de bolas", "Junta tres del mismo color", "Una cadena de bolas en "],
  ["Lucha", "Uno contra uno", "Un juego de lucha en "],
  ["Fusión de frutas", "Junta iguales en el tarro", "Una fusión de frutas en "],
  ["Pinball", "Palas, setas y dianas", "Un pinball en "],
  ["Metroidvania", "Explora y consigue habilidades", "Un metroidvania en "],
  ["Sigilo por turnos", "Esquiva a los guardias", "Un juego de sigilo por turnos en "],
];

// Género de cada entrada del catálogo (mismo orden): su captura real está en public/generos/<id>.webp.
const CATALOGO_ID: string[] = ["plataformas", "runner", "volador", "saltos", "corredor", "carreras", "naves", "horda", "torres", "rompebloques", "puzle", "bloques", "cajas", "serpiente", "memoria", "preguntas", "apilar", "topos", "arena", "aldea", "ritmo", "clicker", "cartas", "rpg", "laberinto", "golf", "pesca", "fusion", "tubos", "burbujas", "imperio", "minas", "mazmorras", "granja", "mazo", "aventura", "cocina", "mahjong", "aparcamiento", "sopa", "sudoku", "nonograma", "cortar", "penaltis", "agujero", "ciudad", "espiral", "canasta", "buscaminas", "conecta", "damas", "billar", "solitario", "parchis", "caida", "bolos", "mundo", "royale", "cruzar", "arco", "cubos", "parkour", "tienda", "futbol", "terror", "conduccion", "zombis", "baloncesto", "tenis", "karts", "supervivencia", "triple", "tornillos", "hexas", "autobus", "duelo", "escalada", "tirachinas", "plantas", "palabra", "letras", "tycoon", "tragaperras", "reino", "multitud", "pedidos", "poder", "diferencias", "rompecabezas", "pintar", "cuchillos", "arquero", "flechas", "numeros", "cartas_locas", "domino", "bloques_colores", "tuberias", "ajedrez", "reversi", "buscar", "deslizar", "ahorcado", "flota", "simon", "estrategia", "autobatalla", "gemas", "coleccionables", "roguelike", "bombas", "artilleria", "comecocos", "cadena", "lucha", "sandia", "pinball", "metroidvania", "sigilo"];

// Carrusel de arriba del taller: los tipos que más se piden, en grande.
const DESTACADOS: [string, string][] = [["plataformas", "Plataformas"], ["rpg", "RPG de batallas"], ["reino", "Reino y conquista"],
  ["royale", "Battle royale"], ["supervivencia", "Supervivencia"], ["horda", "Hordas"], ["carreras", "Carreras"],
  ["puzle", "Puzle de combinar"], ["torres", "Defensa de torres"], ["tycoon", "Tycoon"], ["fusion", "Fusión"], ["runner", "Runner"]];

const PASOS: [string, string][] = [
  ["diseno", "Diseño del juego"],
  ["niveles", "Niveles"],
  ["arte", "Arte y sonido"],
  ["validacion", "Pruebas con bots"],
  ["apk", "APK para Android"],
  ["ficha", "Ficha de Google Play"],
  ["clip", "Clip para redes"],
  ["subida", "Guardar en la nube"],
];

export function vistaTaller(app: App): VistaHecha {
  const chispa = crearChispa("¡Hola! Soy Chispa. Cuéntame tu juego: quién es el héroe, dónde salta y contra qué.");
  const raiz = h("div", { class: "wrap-inner" }, chispa.el);
  let dejarDeSeguir: (() => void) | null = null;
  let reloj: number | null = null;

  // ------------------------------------------------------------ formulario
  const idea = h("textarea", { maxlength: "600", placeholder: "Ej.: un gato ninja rápido que salta por tejados de noche y aplasta ratas robot", "aria-label": "Tu idea" });
  const cuenta = h("span", { class: "tag" }, "0/600");
  // 0 - ¿Para qué es? Cambia el ejemplo, lo que dice Chispa y el paso siguiente al terminar.
  let uso: Uso = "publicar";
  const usos = h("div", { class: "chips desliza usos", role: "group", "aria-label": "Para qué es el juego" });
  const botonesUso: HTMLButtonElement[] = [];
  for (const u of USOS) {
    const b = h("button", { class: "chip", type: "button", "aria-pressed": String(u.id === uso), "data-uso": u.id }, u.nombre) as HTMLButtonElement;
    b.addEventListener("click", () => {
      uso = u.id;
      for (const x of botonesUso) x.setAttribute("aria-pressed", String(x.dataset.uso === uso));
      idea.setAttribute("placeholder", u.ejemplo);
      chispa.decir(u.chispa, "happy");
      // Para clase: a mano las plantillas de repaso (tablas, capitales, vocabulario...).
      if (u.id === "clase") {
        filtrar("aula");
        plantillas.open = true;
      }
    });
    botonesUso.push(b);
    usos.append(b);
  }
  const chips = h("div", { class: "chips desliza", role: "list", "aria-label": "Ideas de ejemplo" });
  for (const ej of EJEMPLOS) {
    chips.append(h("button", { class: "chip", type: "button", onclick: () => { idea.value = ej; soltarPlantilla(); actualizar(); } }, ej));
  }
  // 1 - Catálogo: un tipo de juego deja la frase empezada; tú pones el tema. «Probar» abre al
  // instante una partida de muestra de ese género (fabrica/muestras.py), antes de gastar tuercas.
  const catalogo = h("div", { class: "catalogo", role: "list", "aria-label": "Tipos de juego" });
  const botonesProbar = new Map<string, HTMLButtonElement>();
  // Con más de cien tipos, un buscador (sin tildes y por familias: «cartas», «coches», «niños»...).
  const cajas: [HTMLElement, Tipo][] = [];
  const recientes = nuevos(CATALOGO_ID);
  CATALOGO.forEach(([nombre, que, arranque], i) => {
    const id = CATALOGO_ID[i];
    const foto = id ? fotoGenero(id, { class: "genero-foto", width: "90", height: "160" }) : "";
    const elegir = h("button", { class: "genero con-foto", type: "button", onclick: () => {
      idea.value = arranque;
      soltarPlantilla();
      actualizar();
      idea.focus();
      idea.setSelectionRange(idea.value.length, idea.value.length);
    } }, foto, h("strong", {}, nombre), h("span", {}, que), id && recientes.has(id) ? h("em", { class: "nuevo" }, "Nuevo") : "");
    const caja = h("div", { class: "genero-caja", role: "listitem" }, elegir);
    cajas.push([caja, { id: id ?? "", nombre, que }]);
    if (id) {
      const probar = h("button", { class: "probar-genero", type: "button", hidden: true, "aria-label": `Probar una partida de ${nombre}`,
        onclick: () => probarGenero(id, nombre) }, svg(ICONOS.jugar), " Probar") as HTMLButtonElement;
      botonesProbar.set(id, probar);
      caja.append(probar);
    }
    catalogo.append(caja);
  });
  const sinTipos = h("p", { class: "nota", hidden: true }, "Ningún tipo encaja: prueba con otra palabra o descríbelo tal cual arriba, que Chispa lo entiende.");
  const buscador = h("input", { class: "buscar-tipos", type: "search", placeholder: "Busca: cartas, coches, puzle, niños...",
    "aria-label": "Buscar un tipo de juego", oninput: () => {
      let vistos = 0;
      for (const [el, tipo] of cajas) {
        el.hidden = !encaja(tipo, buscador.value);
        if (!el.hidden) vistos++;
      }
      sinTipos.hidden = vistos > 0;
    } }) as HTMLInputElement;
  const tipos = h("details", { class: "tipos" }, h("summary", {}, `O elige un tipo de juego (${CATALOGO.length})`), buscador, sinTipos, catalogo);
  // Las muestras publicadas se miran al abrir el catálogo (una vez): solo esos géneros enseñan «Probar».
  let muestras: Record<string, { v?: string }> | null = null;
  tipos.addEventListener("toggle", () => {
    if (tipos.open && muestras === null) void cargarMuestras();
  });
  async function cargarMuestras(): Promise<void> {
    const base = baseMuestras();
    muestras = {};
    if (!base) {
      // Sin motor (modo demostración): «Probar» enseña cómo sería, en todos.
      for (const b of botonesProbar.values()) b.hidden = false;
      return;
    }
    try {
      const r = await fetch(`${base}/indice.json`, { cache: "no-cache" });
      if (r.ok) muestras = (await r.json()) as Record<string, { v?: string }>;
    } catch { /* sin red: sin «Probar» */ }
    for (const [id, b] of botonesProbar) b.hidden = !muestras[id];
  }
  function baseMuestras(): string | null {
    // Las muestras pueden vivir en otro sitio que el motor (el motor va en GitHub Pages; las muestras, en Supabase).
    const propia = import.meta.env.VITE_MUESTRAS_URL as string | undefined;
    if (propia && !propia.includes("TU_REF")) return propia.replace(/\/+$/, "");
    const motor = app.api.motor();
    return motor ? motor.replace(/\/godot\/[^/]+\/?$/, "") + "/muestras" : null;
  }
  function probarGenero(id: string, nombre: string): void {
    const base = baseMuestras();
    const v = muestras?.[id]?.v ?? "";
    abrirJugador({ motor: app.api.motor(), pck: base ? `${base}/${id}.pck${v ? `?v=${v}` : ""}` : null,
      titulo: `Muestra: ${nombre}`, portada: `generos/${id}.webp` });
  }
  // 2 - Plantillas de éxito: juegos ya probados; tú solo cambias el tema. La marca
  // «[plantilla:id]» no se ve en el cuadro: se añade al encargar mientras no cambies de idea.
  let elegida: Plantilla | null = null;
  // Gancho original elegido («[gancho:genero:giros]»): igual que la plantilla, no se ve en el cuadro.
  let gancho: string | null = null;
  const marca = h("p", { class: "plantilla-marca", hidden: true });
  function soltarPlantilla() { elegida = null; gancho = null; marca.hidden = true; }
  const galeria = h("div", { class: "plantillas", role: "list", "aria-label": "Plantillas de éxito" });
  // 1 - Filtro por tipo: con medio centenar de plantillas, se elige primero qué te apetece.
  const CATEGORIAS: [Plantilla["categoria"] | "todas", string][] = [["todas", "Todas"], ["unicas", "Únicas"], ["accion", "Acción"],
    ["puzle", "Puzle"], ["estrategia", "Estrategia"], ["relax", "Relax"], ["ninos", "Para niños"], ["aula", "Para clase"]];
  const tarjetasPl = new Map<HTMLElement, Plantilla>();
  const filtro = h("div", { class: "chips desliza filtro-plantillas", role: "group", "aria-label": "Tipo de plantilla" });
  const botonesFiltro: HTMLButtonElement[] = [];
  function filtrar(cat: Plantilla["categoria"] | "todas") {
    for (const [el, p] of tarjetasPl) el.hidden = cat !== "todas" && p.categoria !== cat;
    for (const b of botonesFiltro) b.setAttribute("aria-pressed", String(b.dataset.cat === cat));
  }
  for (const [id, nombre] of CATEGORIAS) {
    const n = id === "todas" ? PLANTILLAS.length : PLANTILLAS.filter((p) => p.categoria === id).length;
    const b = h("button", { class: "chip", type: "button", "data-cat": id, "aria-pressed": "false" }, `${nombre} ${n}`) as HTMLButtonElement;
    b.addEventListener("click", () => filtrar(id));
    botonesFiltro.push(b);
    filtro.append(b);
  }
  for (const p of PLANTILLAS) {
    const tema = h("input", { type: "text", value: p.tema, maxlength: "60", "aria-label": `Tu tema para ${p.nombre}` });
    const usar = h("button", { class: "chip", type: "button", onclick: () => {
      const t = tema.value.trim() || p.tema;
      idea.value = p.idea.replace("{tema}", t);
      elegida = p;
      marca.hidden = false;
      marca.replaceChildren(`Plantilla «${p.nombre}»: se mantiene lo que la hace funcionar. `,
        h("button", { class: "chip", type: "button", onclick: () => { soltarPlantilla(); idea.focus(); } }, "Quitar"));
      actualizar();
      idea.scrollIntoView({ behavior: "smooth", block: "center" });
    } }, "Usar");
    const nombresGiros = p.giros.map((g) => GIROS.find((x) => x.id === g)?.nombre ?? g);
    const tarjeta = h("div", { class: "plantilla" + (p.giros.length ? " con-giro" : ""), role: "listitem" },
      h("div", { class: "plantilla-cab" }, h("strong", {}, p.nombre), h("span", { class: "tag" }, p.infantil ? "Para niños" : (GENERO_NOMBRE[p.genero] ?? p.genero))),
      nombresGiros.length ? h("div", { class: "game-giros" }, ...nombresGiros.map((g) => h("span", { class: "giro-chip" }, g))) : "",
      h("p", {}, p.por_que),
      h("label", { class: "plantilla-tema" }, h("span", {}, "Tu tema"), tema, usar));
    tarjetasPl.set(tarjeta, p);
    galeria.append(tarjeta);
  }
  filtrar("todas");
  const plantillas = h("details", { class: "tipos" }, h("summary", {}, `Empieza con una plantilla de éxito (${PLANTILLAS.length})`), filtro, galeria);
  // 3 - Ganchos originales: la IA propone 3 juegos distintos para tu idea (género + giros).
  const ganchosLista = h("div", { class: "plantillas", role: "list", "aria-label": "Ganchos originales", "aria-live": "polite" });
  const pedirGanchos = h("button", { class: "btn btn-line btn-small", type: "button" }, "Proponme 3 ideas originales") as HTMLButtonElement;
  pedirGanchos.addEventListener("click", async () => {
    const texto = idea.value.trim();
    if (texto.length < 3) {
      aviso("Escribe antes un tema o una idea (por ejemplo: un gato pirata).");
      idea.focus();
      return;
    }
    pedirGanchos.disabled = true;
    pedirGanchos.textContent = "Chispa está pensando...";
    try {
      const gs = await app.api.ganchos(texto.replace(/^\[[^\]]*\]\s*/, ""));
      ganchosLista.replaceChildren(...gs.map((g) => h("div", { class: "plantilla gancho", role: "listitem" },
        h("div", { class: "plantilla-cab" }, h("strong", {}, g.titulo), h("span", { class: "tag" }, g.genero)),
        g.giros.length ? h("p", { class: "giros-tags" }, ...g.giros.map((id) => h("span", { class: "tag" }, GIROS.find((x) => x.id === id)?.nombre ?? id))) : "",
        h("p", {}, g.idea), h("p", { class: "muted small" }, g.por_que),
        h("button", { class: "chip", type: "button", onclick: () => {
          idea.value = g.idea;
          elegida = null;
          gancho = g.marca.match(/^\[gancho:[^\]]*\]/)?.[0] ?? null;
          marca.hidden = false;
          marca.replaceChildren(`Gancho «${g.titulo}»: ${g.genero}${g.giros.length ? " con " + g.giros.join(" y ") : ""}. `,
            h("button", { class: "chip", type: "button", onclick: () => { soltarPlantilla(); idea.focus(); } }, "Quitar"));
          actualizar();
          idea.scrollIntoView({ behavior: "smooth", block: "center" });
        } }, "Elegir este"))));
    } catch (e) {
      aviso(mensajeError(e, "Chispa no ha podido proponer ideas ahora."));
    }
    pedirGanchos.disabled = false;
    pedirGanchos.textContent = "Proponme otras 3";
  });
  const ganchos = h("div", { class: "ganchos" }, pedirGanchos, ganchosLista);
  const precio = h("span", { class: "price" }, svg(ICONOS.tuerca), String(app.precio));
  const fabricar = h("button", { class: "btn btn-brass" }, "Fabricar", precio);
  // Vista previa gratis: Chispa piensa el diseño (un minuto) y lo enseña ANTES de cobrar nada.
  const verPrevia = h("button", { class: "btn btn-line", type: "button" }, "Probar gratis") as HTMLButtonElement;
  const previaCaja = h("div", { class: "plantilla previa", hidden: true, role: "region", "aria-live": "polite" });
  let previa: { id: string; texto: string } | null = null;
  let dejarPrevia: (() => void) | null = null;
  const estado = h("p", { class: "status", role: "status" });
  const nota = h("p", { class: "muted small" }, "Se cobra al empezar. Si la fábrica falla, te devolvemos las tuercas.");
  // Capa 3: si la idea no encaja en ningún género, Chispa programa uno nuevo solo para este juego.
  const aMedida = h("input", { type: "checkbox", id: "a-medida" }) as HTMLInputElement;
  const aMedidaFila = h("label", { class: "check-row", for: "a-medida" }, aMedida,
    h("span", {}, "Inventar un género nuevo solo para este juego (beta: tarda más)"));
  // Tipos más usados a la vista, con su captura: se elige de un toque (el catálogo entero, debajo).
  const rapidos = h("div", { class: "tipos-rapidos", role: "list", "aria-label": "Tipos de juego más usados" });
  CATALOGO.slice(0, 12).forEach(([nombre, , arranque], i) => {
    const id = CATALOGO_ID[i];
    rapidos.append(h("button", { class: "tipo-rapido", type: "button", role: "listitem", onclick: () => {
      idea.value = arranque;
      soltarPlantilla();
      actualizar();
      idea.focus();
      idea.setSelectionRange(idea.value.length, idea.value.length);
      idea.scrollIntoView({ behavior: "smooth", block: "center" });
    } }, fotoGenero(id, { width: "84", height: "112" }), h("span", {}, nombre)));
  });
  // Carrusel grande: «Haz un juego como...» con las portadas ilustradas; un toque deja la frase empezada.
  const carrusel = h("div", { class: "carrusel", role: "list", "aria-label": "Tipos de juego destacados" });
  for (const [id, titulo] of DESTACADOS) {
    const i = CATALOGO_ID.indexOf(id);
    if (i < 0) continue;
    const [, que, arranque] = CATALOGO[i];
    carrusel.append(h("button", { class: "carrusel-item", type: "button", role: "listitem", onclick: () => {
      idea.value = arranque;
      soltarPlantilla();
      actualizar();
      idea.focus();
      idea.setSelectionRange(idea.value.length, idea.value.length);
      idea.scrollIntoView({ behavior: "smooth", block: "center" });
    } }, fotoGenero(id, { width: "180", height: "320" }), h("span", { class: "carrusel-texto" }, h("strong", {}, titulo), h("small", {}, que))));
  }
  const destacados = h("section", { class: "destacados" }, h("h2", { class: "destacados-titulo" }, "Haz un juego como…"), carrusel);
  (tipos.querySelector("summary") as HTMLElement).textContent = `Ver los ${CATALOGO.length} tipos de juego`;
  const mas = h("details", { class: "tipos mas-formas" }, h("summary", {}, "Más formas de empezar: plantillas, ideas originales, género nuevo"),
    ganchos, plantillas, aMedidaFila);
  // Compositor: la idea es lo primero y los botones van pegados a ella (como en los creadores de juegos con IA).
  const form = h("section", { class: "sheet plano composer" },
    h("div", { class: "sheet-head" }, h("h2", {}, "¿Qué juego fabricamos?"), cuenta),
    usos, idea, marca,
    h("div", { class: "btn-row composer-acciones" }, verPrevia, fabricar), previaCaja, estado, nota,
    h("h3", { class: "composer-sub" }, "Ideas para empezar"), chips,
    h("h3", { class: "composer-sub" }, "O elige un tipo"), rapidos, tipos, mas);

  function actualizar() {
    const n = idea.value.trim().length;
    cuenta.textContent = `${idea.value.length}/600`;
    const falta = app.precio - app.tuercas;
    fabricar.disabled = n < 15 || falta > 0;
    verPrevia.disabled = n < 15 || dejarPrevia !== null;
    estado.className = "status";
    if (falta > 0) {
      estado.className = "status err";
      estado.textContent = `Te faltan ${falta} tuercas. Consíguelas en la pestaña Tuercas.`;
    } else if (n > 0 && n < 15) {
      estado.textContent = "Cuéntame un poco más (mínimo 15 letras).";
    } else {
      estado.textContent = "";
    }
  }
  idea.addEventListener("input", () => {
    // La vista previa vale para la idea que se pensó: si la cambias, se pide otra.
    if (previa && ideaMarcada() !== previa.texto) quitarPrevia();
    actualizar();
  });

  /** La idea tal cual va a la fábrica: con su plantilla, gancho o género a medida delante. */
  function ideaMarcada(): string {
    const texto = idea.value.trim();
    return aMedida.checked ? `[a_medida] ${texto}` : elegida ? `[plantilla:${elegida.id}] ${texto}` : gancho ? `${gancho} ${texto}` : texto;
  }

  function quitarPrevia() {
    dejarPrevia?.();
    dejarPrevia = null;
    previa = null;
    previaCaja.hidden = true;
    previaCaja.replaceChildren();
  }

  interface DisenoPrevia {
    titulo?: string; genero?: string; resumen?: string;
    heroe?: { nombre?: string; descripcion?: string };
    enemigos?: { nombre?: string }[]; jefe?: { nombre?: string } | null; niveles?: unknown[];
    estilo?: { descripcion?: string };
  }

  function pintarPrevia(id: string, texto: string, d: DisenoPrevia, boceto?: string) {
    previa = { id, texto };
    const genero = d.genero ? (GENERO_NOMBRE[d.genero] ?? d.genero) : "";
    const enemigos = (d.enemigos ?? []).map((e) => e.nombre).filter(Boolean).join(", ");
    const precioPrevia = h("span", { class: "price" }, svg(ICONOS.tuerca), String(app.precio));
    const hacer = h("button", { class: "btn btn-brass", type: "button" }, "Fabricar este juego", precioPrevia) as HTMLButtonElement;
    hacer.disabled = app.precio > app.tuercas;
    hacer.addEventListener("click", () => void encargarJuego(id));
    const otra = h("button", { class: "btn btn-line btn-small", type: "button" }, "Cambiar la idea");
    otra.addEventListener("click", () => { quitarPrevia(); actualizar(); idea.focus(); });
    // Boceto jugable: los niveles de verdad con dibujos provisionales. Se juega antes de pagar nada.
    const probar = h("button", { class: "btn btn-brass", type: "button" }, svg(ICONOS.jugar), " Jugar el boceto") as HTMLButtonElement;
    probar.addEventListener("click", async () => {
      const motor = app.api.motor();
      try {
        const pck = motor && boceto ? await app.api.url(boceto) : null;
        abrirJugador({ motor, pck, titulo: d.titulo ?? "Boceto", portada: undefined });
      } catch (e) {
        aviso(mensajeError(e, "No se pudo abrir el boceto."));
      }
    });
    // Guardar gratis: el boceto pasa a Mis juegos como borrador (se juega; el arte y el APK, al fabricarlo).
    const guardar = h("button", { class: "btn btn-line", type: "button" }, "Guardar gratis") as HTMLButtonElement;
    guardar.addEventListener("click", async () => {
      guardar.disabled = true;
      try {
        const r = await app.api.guardarBoceto(id);
        aviso("Guardado en Mis juegos. Cuando quieras, lo fabricas con su arte");
        app.ir("juegos", r.project_id);
      } catch (e) {
        aviso(mensajeError(e, "No se pudo guardar el boceto."));
        guardar.disabled = false;
      }
    });
    previaCaja.replaceChildren(
      h("div", { class: "plantilla-cab" }, h("strong", {}, d.titulo ?? "Tu juego"), genero ? h("span", { class: "tag" }, genero) : ""),
      d.resumen ? h("p", {}, d.resumen) : "",
      d.heroe?.nombre ? h("p", { class: "small" }, h("strong", {}, "Protagonista: "), d.heroe.nombre + (d.heroe.descripcion ? ` (${d.heroe.descripcion})` : "")) : "",
      enemigos ? h("p", { class: "small" }, h("strong", {}, "Rivales: "), enemigos + (d.jefe?.nombre ? ` y el jefe final ${d.jefe.nombre}` : "")) : "",
      d.niveles?.length ? h("p", { class: "small" }, h("strong", {}, "Niveles: "), String(d.niveles.length)) : "",
      d.estilo?.descripcion ? h("p", { class: "muted small" }, "Estilo: " + d.estilo.descripcion) : "",
      boceto ? h("div", { class: "btn-row", style: "margin:10px 0" }, probar, guardar) : "",
      h("p", { class: "muted small" }, boceto
        ? "Juega el boceto: son los niveles de verdad con dibujos provisionales. Al fabricarlo le pongo su arte, su música y su APK."
        : "Esto es lo que voy a fabricar. Si te gusta, adelante; si no, cambia la idea y pide otro (gratis)."),
      h("div", { class: "btn-row" }, hacer, otra));
    previaCaja.hidden = false;
    previaCaja.scrollIntoView({ behavior: "smooth", block: "center" });
  }

  verPrevia.addEventListener("click", async () => {
    const texto = ideaMarcada();
    quitarPrevia();
    verPrevia.disabled = true;
    estado.className = "status";
    estado.textContent = "Chispa está pensando tu juego y montando un boceto jugable (un minuto, gratis)...";
    chispa.decir("Déjame pensarlo: te enseño el diseño antes de gastar nada.", "thinking");
    try {
      const r = await app.api.vistaPrevia(texto);
      dejarPrevia = app.api.seguir(r.job_id, (t) => {
        if (t.status === "done") {
          dejarPrevia = null;
          const res = t.result as unknown as { diseno?: DisenoPrevia; boceto?: string } | null;
          const d = res?.diseno;
          if (d) {
            estado.textContent = "";
            chispa.decir(res?.boceto ? `Mira: «${d.titulo ?? "tu juego"}». ¡Ya puedes jugar un boceto!` : `Mira: «${d.titulo ?? "tu juego"}». ¿Lo fabrico?`, "happy");
            pintarPrevia(t.id, texto, d, res?.boceto);
          } else {
            estado.className = "status err";
            estado.textContent = "No he podido enseñarte el diseño. Prueba otra vez o fabrícalo directamente.";
          }
          actualizar();
        } else if (t.status === "failed") {
          dejarPrevia = null;
          estado.className = "status err";
          estado.textContent = "No he podido pensar el diseño. Prueba otra vez o fabrícalo directamente.";
          chispa.decir("Uy, se me ha atascado la idea.", "error");
          actualizar();
        } else if (t.status === "queued") {
          estado.textContent = "En la cola de la fábrica: enseguida lo pienso...";
        }
      });
    } catch (e) {
      estado.className = "status err";
      estado.textContent = mensajeError(e, "No se pudo pedir la vista previa.");
      actualizar();
    }
  });

  fabricar.addEventListener("click", () => void encargarJuego(previa && previa.texto === ideaMarcada() ? previa.id : undefined));

  async function encargarJuego(previaId?: string) {
    fabricar.disabled = true;
    estado.className = "status";
    estado.textContent = "Encargando a la fábrica...";
    chispa.decir("¡Allá vamos! Llevo tu idea a la fábrica.", "thinking");
    try {
      void prepararAvisos();
      const r = await app.api.encargar(previa && previaId ? previa.texto : ideaMarcada(), previaId);
      quitarPrevia();
      aMedida.checked = false;
      app.ponerTuercas(r.credits);
      idea.value = "";
      soltarPlantilla();
      try { localStorage.setItem(`orq_uso_${r.job_id}`, uso); } catch { /* sin almacenamiento: vale el de ahora */ }
      // Aviso de respaldo en el móvil por si el sistema cierra la app mientras se fabrica.
      void programarAvisoEspera(r.job_id);
      seguir(r.job_id);
    } catch (e) {
      estado.className = "status err";
      estado.textContent = mensajeError(e, "No se pudo encargar el juego.");
      chispa.decir("Uy, no he podido llevarlo a la fábrica.", "error");
      actualizar();
    }
  }

  // ------------------------------------------------------------ banco de pruebas
  const pasos = h("ul", { class: "steps" });
  const filas = new Map<string, HTMLLIElement>();
  for (const [id, nombre] of PASOS) {
    const li = h("li", { class: "step" }, h("span", { class: "dot" }), h("span", {}, nombre), h("span", { class: "time" }));
    filas.set(id, li);
    pasos.append(li);
  }
  const tiempo = h("span", { class: "tag" }, "0:00");
  const registro = h("div", { class: "log", "aria-live": "off" });
  const titulo = h("h2", {}, "Fabricando");
  // 1 - Boceto jugable: aparece en cuanto hay niveles, mientras el arte se dibuja.
  const jugarBoceto = h("button", { class: "btn btn-brass", hidden: true }, svg(ICONOS.jugar), " Jugar el boceto");
  let rutaBoceto = "";
  jugarBoceto.addEventListener("click", async () => {
    const motor = app.api.motor();
    try {
      const pck = motor ? await app.api.url(rutaBoceto) : null;
      abrirJugador({ motor, pck, titulo: "Boceto", portada: undefined });
    } catch (e) {
      aviso(mensajeError(e, "No se pudo abrir el boceto."));
    }
  });
  // La fábrica en marcha: dos engranajes que giran y una barra que avanza con cada paso terminado.
  const barra = h("div", { class: "fab-bar" }, h("i", {}));
  const porcentaje = h("span", { class: "fab-pct" }, "0 %");
  const maquina = h("div", { class: "fab", "aria-hidden": "true" },
    svg(ENGRANAJES), h("div", { class: "fab-info" }, barra, porcentaje));
  let hechosAntes = -1;
  const banco = h("section", { class: "sheet", hidden: true },
    h("div", { class: "sheet-head" }, titulo, tiempo), maquina, pasos, jugarBoceto, registro);

  // ------------------------------------------------------------ resultado
  const resultado = h("section", { class: "sheet", hidden: true });

  function pintar(t: Trabajo) {
    form.hidden = true;
    destacados.hidden = true;
    banco.hidden = false;
    titulo.textContent = t.titulo ? t.titulo : "Fabricando";
    const hechos = new Set(t.progress.filter((e) => e.estado === "ok").map((e) => e.paso));
    const empezados = new Set(t.progress.map((e) => e.paso));
    const avisos = new Set(t.progress.filter((e) => e.estado === "aviso").map((e) => e.paso));
    let activoPuesto = false;
    for (const [id] of PASOS) {
      const li = filas.get(id)!;
      li.className = "step";
      if (hechos.has(id) || (t.status === "done")) li.classList.add("done");
      else if (empezados.has(id) && t.status === "running" && !activoPuesto) {
        li.classList.add("active");
        if (avisos.has(id)) li.classList.add("warn");
        activoPuesto = true;
      }
    }
    // Avance: cada paso terminado empuja la barra y suena la carraca (solo los nuevos).
    const nHechos = t.status === "done" ? PASOS.length : PASOS.filter(([id]) => hechos.has(id)).length;
    const pct = Math.round((nHechos / PASOS.length) * 100);
    (barra.firstElementChild as HTMLElement).style.width = `${pct}%`;
    porcentaje.textContent = `${pct} %`;
    maquina.classList.toggle("parada", t.status !== "running" && t.status !== "queued");
    if (hechosAntes >= 0 && nHechos > hechosAntes && t.status === "running") sonar("paso");
    hechosAntes = nHechos;
    musica(t.status === "running" || t.status === "queued");
    const boceto = t.progress.find((e) => e.boceto)?.boceto;
    if (boceto) rutaBoceto = boceto;
    jugarBoceto.hidden = !boceto || t.status !== "running";
    registro.replaceChildren(...t.progress.map((e) => h("div", { class: e.estado === "aviso" ? "aviso" : "" }, "› " + e.mensaje)));
    registro.scrollTop = registro.scrollHeight;
    const ultimo = t.progress[t.progress.length - 1];
    if (t.status === "queued") chispa.decir("Tu juego está en la cola de la fábrica. Enseguida empieza.", "thinking");
    else if (t.status === "running" && ultimo) chispa.decir(ultimo.mensaje, "thinking");
    else if (t.status === "done") terminado(t);
    else if (t.status === "failed") fallido(t);
  }

  function terminado(t: Trabajo) {
    pararReloj();
    musica(false);
    fanfarria();
    chispas(window.innerWidth / 2, window.innerHeight / 3, 40);
    lluviaDeTuercas();
    void cancelarAvisoEspera(t.id);
    vibrar("exito");
    void avisarJuegoListo(t.titulo ?? "Tu juego");
    // Despues de ver el juego un momento, la ventanita de valorar en Google Play (una sola vez).
    setTimeout(() => void pedirValoracion(), 4000);
    chispa.decir(`¡Listo! «${t.titulo ?? "Tu juego"}» ha superado todas las pruebas. Descárgalo y juega.`, "happy");
    void app.refrescarTuercas();
    const galeria = h("div", { class: "gallery" });
    const icono = h("img", { class: "game-icon", alt: "" });
    const descargar = h("button", { class: "btn btn-brass" }, svg(ICONOS.descarga), "Descargar APK");
    const otro = h("button", { class: "btn btn-line" }, "Fabricar otro");
    const ver = h("button", { class: "btn btn-line" }, "Cambiarlo con Chispa");
    let guardado: string | null = null;
    try { guardado = localStorage.getItem(`orq_uso_${t.id}`); } catch { /* nada */ }
    const siguiente = infoUso(guardado ?? uso);
    resultado.replaceChildren(
      h("div", { class: "detail-head" }, icono, h("div", {}, h("h2", {}, t.titulo ?? "Tu juego"), h("p", { class: "muted small" }, t.idea))),
      h("div", { style: "height:14px" }), galeria, h("div", { style: "height:14px" }), descargar,
      h("div", { style: "height:10px" }), h("div", { class: "btn-row" }, ver, otro),
      // Primer uso guiado: lo siguiente es llevarlo a Google Play (la ficha tiene el camino paso a paso).
      h("p", { class: "consejo" }, siguiente.consejo),
      h("button", { class: "btn btn-line", style: "width:100%", onclick: () => {
        abrirSeccion(siguiente.pestana, siguiente.seccion);
        app.ir("juegos", t.project_id ?? undefined);
      } }, siguiente.boton));
    resultado.hidden = false;
    banco.hidden = true;
    const r = t.result;
    if (r?.icono) void app.api.url(r.icono).then((u) => { icono.src = u; }).catch(() => undefined);
    for (const c of r?.capturas ?? []) {
      const img = h("img", { alt: "Captura del juego", loading: "lazy" });
      galeria.append(img);
      void app.api.url(c).then((u) => { img.src = u; }).catch(() => img.remove());
    }
    descargar.addEventListener("click", async () => {
      if (!r?.apk) return aviso("Este juego no tiene APK.");
      try {
        await abrir(await app.api.url(r.apk));
      } catch (e) {
        aviso(mensajeError(e, "No se pudo descargar."));
      }
    });
    otro.addEventListener("click", reiniciar);
    ver.addEventListener("click", () => app.ir("juegos", t.project_id ?? undefined));
  }

  function fallido(t: Trabajo) {
    pararReloj();
    musica(false);
    sonar("error");
    void cancelarAvisoEspera(t.id);
    vibrar("error");
    chispa.decir(t.refunded ? "Algo se ha roto en la fábrica. Te he devuelto las tuercas; prueba otra vez." :
      "Algo se ha roto en la fábrica, lo siento. Prueba otra vez en un rato.", "error");
    void app.refrescarTuercas();
    // Con su diseño guardado, el reintento fabrica el mismo juego y recupera el arte ya dibujado.
    const conDiseno = !!(t.result as unknown as { diseno?: unknown } | null)?.diseno && t.idea.trim().length >= 15;
    const reintentar = h("button", { class: "btn btn-brass" }, "Reintentar este mismo juego", h("span", { class: "price" }, svg(ICONOS.tuerca), String(app.precio))) as HTMLButtonElement;
    reintentar.disabled = app.precio > app.tuercas;
    reintentar.addEventListener("click", async () => {
      reintentar.disabled = true;
      chispa.decir("Lo intento otra vez con el mismo diseño. Lo que ya estaba dibujado no se vuelve a pagar.", "thinking");
      try {
        const r = await app.api.encargar(t.idea, t.id);
        app.ponerTuercas(r.credits);
        void programarAvisoEspera(r.job_id);
        seguir(r.job_id);
      } catch (e) {
        aviso(mensajeError(e, "No se pudo reintentar."));
        reintentar.disabled = false;
      }
    });
    const otro = h("button", { class: conDiseno ? "btn btn-line" : "btn btn-brass" }, conDiseno ? "Probar otra idea" : "Intentarlo de nuevo");
    otro.addEventListener("click", reiniciar);
    resultado.replaceChildren(h("h2", {}, "No ha salido"), h("p", { class: "muted", style: "margin:8px 0 14px" }, t.idea),
      ...(conDiseno ? [reintentar, h("div", { style: "height:10px" })] : []), otro);
    resultado.hidden = false;
  }

  function seguir(id: string) {
    dejarDeSeguir?.();
    form.hidden = true;
    destacados.hidden = true;
    banco.hidden = false;
    resultado.hidden = true;
    const inicio = Date.now();
    pararReloj();
    reloj = window.setInterval(() => {
      const s = Math.floor((Date.now() - inicio) / 1000);
      tiempo.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }, 1000);
    dejarDeSeguir = app.api.seguir(id, pintar);
  }

  function pararReloj() {
    if (reloj !== null) window.clearInterval(reloj);
    reloj = null;
  }

  function reiniciar() {
    dejarDeSeguir?.();
    dejarDeSeguir = null;
    hechosAntes = -1;
    musica(false);
    resultado.hidden = true;
    banco.hidden = true;
    form.hidden = false;
    destacados.hidden = false;
    chispa.decir("¿Qué fabricamos ahora?");
    actualizar();
    idea.focus();
  }

  // 1 - Inspiración: juegos de la comunidad (solo mientras se escribe la idea).
  const comunidad = seccionEscaparate(app);
  // 3 - Reto de la semana: un tema para todos y premio para los 3 primeros.
  const reto = seccionReto(app, (tema) => {
    soltarPlantilla();
    idea.value = `Un juego de ${tema.toLowerCase()}: `;
    actualizar();
    idea.focus();
    idea.scrollIntoView({ behavior: "smooth", block: "center" });
  });
  raiz.append(destacados, form, banco, resultado, reto, comunidad);
  actualizar();
  // 2 - Primera vez (sin juegos): un juego de la comunidad para jugar ya, antes de la idea.
  void app.api.juegos().then(async (js) => {
    if (js.length) return;
    const b = await tarjetaBienvenida(app);
    // Después del compositor: la idea manda; el juego para probar queda justo debajo.
    if (b && form.isConnected) form.after(b);
  }).catch(() => undefined);

  // Si hay un juego a medias (la app se cerró mientras se fabricaba), lo retomamos.
  void app.api.trabajos().then((lista) => {
    const enCurso = lista.find((t) => t.kind === "game" && (t.status === "queued" || t.status === "running"));
    if (enCurso) seguir(enCurso.id);
  }).catch(() => undefined);

  return {
    el: raiz,
    limpiar() {
      dejarDeSeguir?.();
      dejarPrevia?.();
      pararReloj();
      musica(false);
    },
  };
}
