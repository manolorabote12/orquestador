// Plan de 7 días para redes: qué publicar cada día para dar a conocer un juego recién hecho.
// Se escribe con los datos del juego (sin IA y sin coste): título, tipo, giros, enlaces. Cada día
// tiene un objetivo distinto (enseñar, retar, contar cómo se hizo, pedir opinión, lanzar), que es
// lo que funciona en TikTok, Reels y Shorts: variar el gancho y repetir el enlace.

export interface DatosRedes {
  titulo: string;
  genero?: string;
  generoNombre?: string;
  giros?: string[];
  /** Enlace para jugar en el navegador (escaparate), si está compartido. */
  jugar?: string | null;
  /** Ficha de Google Play, si ya está publicado. */
  tienda?: string | null;
  niveles?: number;
  /** Idioma de los textos (por defecto español). */
  idioma?: "es" | "en";
}

export interface Publicacion {
  dia: number;
  objetivo: string;
  /** Qué grabar o enseñar (para la persona, no se publica). */
  idea: string;
  /** Texto listo para pegar. */
  texto: string;
}

const ETIQUETAS: Record<string, string[]> = {
  plataformas: ["#plataformas", "#pixelart"], runner: ["#runner", "#endlessrunner"], volador: ["#arcade", "#onetap"],
  horda: ["#survivor", "#roguelite"], puzle: ["#match3", "#puzzle"], torres: ["#towerdefense", "#estrategia"],
  carreras: ["#carreras", "#racing"], naves: ["#shootemup", "#arcade"], rompebloques: ["#breakout", "#arcade"],
  bloques: ["#blockpuzzle", "#puzzle"], cajas: ["#sokoban", "#puzzle"], serpiente: ["#snake", "#retro"],
  memoria: ["#memoria", "#juegosparaniños"], preguntas: ["#trivia", "#quiz"], apilar: ["#stack", "#hypercasual"],
  topos: ["#whackamole", "#arcade"], corredor: ["#runner3d", "#subway"], arena: ["#battle", "#online"],
  aldea: ["#estrategia", "#clanes"], ritmo: ["#ritmo", "#musica"], clicker: ["#idle", "#clicker"],
  cartas: ["#solitario", "#cartas"], rpg: ["#rpg", "#turnos"], laberinto: ["#laberinto", "#puzzle"],
  golf: ["#minigolf", "#relax"], pesca: ["#pesca", "#relax"], fusion: ["#merge", "#2048"], tubos: ["#watersort", "#puzzle"], burbujas: ["#bubbleshooter", "#arcade"], imperio: ["#estrategia", "#rts"], minas: ["#idle", "#idleminer"], mazmorras: ["#rpg", "#roguelike"], granja: ["#cozygames", "#farming"], mazo: ["#deckbuilder", "#cardgame"], aventura: ["#visualnovel", "#historias"], cocina: ["#cookinggame", "#juegosdecocina"], mahjong: ["#mahjong", "#puzzle"], aparcamiento: ["#parkingjam", "#puzzle"], sopa: ["#wordsearch", "#sopadeletras"], sudoku: ["#sudoku", "#puzzle"], nonograma: ["#nonogram", "#picross"], cortar: ["#fruitninja", "#arcade"], penaltis: ["#penalty", "#football"], agujero: ["#holeio", "#arcade"], ciudad: ["#citybuilder", "#simulation"], espiral: ["#helixjump", "#arcade"], canasta: ["#basketball", "#sports"], buscaminas: ["#minesweeper", "#puzzle"], conecta: ["#connect4", "#boardgames"], damas: ["#checkers", "#boardgames"], billar: ["#8ballpool", "#billiards"], solitario: ["#solitaire", "#cardgames"], parchis: ["#ludo", "#boardgames"], caida: ["#blockpuzzle", "#retrogaming"], bolos: ["#bowling", "#sports"], mundo: ["#sandbox", "#survivalgame"], royale: ["#battleroyale", "#mobilegaming"], arco: ["#archery", "#sportsgame"], cubos: ["#voxel", "#sandbox3d"], parkour: ["#obby", "#parkour"], tienda: ["#supermarketsimulator", "#idlegame"], futbol: ["#football", "#futbol"], terror: ["#horrorgame", "#scary"], conduccion: ["#drivinggame", "#delivery"], zombis: ["#zombiegame", "#fpsgame"], baloncesto: ["#streetball", "#basketball"], tenis: ["#tennis", "#tenis"], karts: ["#kartracing", "#drift"], cruzar: ["#crossyroad", "#arcade"], saltos: ["#doodlejump", "#arcade"],
};

/** Los 7 días. Los textos no pasan de 300 caracteres (caben en cualquier red). */
export function planRedes(d: DatosRedes): Publicacion[] {
  const t = d.titulo.trim();
  const tipo = (d.generoNombre ?? d.genero ?? "juego").toLowerCase();
  const enlace = d.tienda ?? d.jugar ?? "";
  const donde = d.tienda ? "Gratis en Google Play" : d.jugar ? "Juégalo gratis en el navegador" : "Muy pronto en Google Play";
  const cierre = enlace ? `${donde}: ${enlace}` : donde;
  const tags = ["#indiegame", "#gamedev", ...(ETIQUETAS[d.genero ?? ""] ?? ["#juegosmoviles"])].join(" ");
  const giro = d.giros?.length ? d.giros[0] : "";
  const niveles = d.niveles && d.niveles > 1 ? `${d.niveles} niveles` : "niveles";
  const recortar = (s: string) => (s.length <= 300 ? s : s.slice(0, 297).replace(/\s+\S*$/, "") + "…");
  const dias: Publicacion[] = [
    { dia: 1, objetivo: "Presentarlo", idea: "El clip vertical de 15 s (pestaña Compartir → Hacer vídeos).",
      texto: `Os presento «${t}», mi nuevo ${tipo} 🎮 ${giro ? `Con un giro: ${giro.toLowerCase()}. ` : ""}${cierre} ${tags}` },
    { dia: 2, objetivo: "Enseñar cómo se juega", idea: "Graba la pantalla jugando el primer nivel, sin cortes.",
      texto: `Así se juega a «${t}»: lo aprendes en 5 segundos y luego no hay quien pare 😅 ${cierre} ${tags}` },
    { dia: 3, objetivo: "Retar", idea: "Graba tu mejor partida del nivel más difícil y para justo antes del final.",
      texto: `Reto: ¿quién se pasa el último nivel de «${t}» a la primera? Yo no pude 🙃 Deja tu récord en comentarios. ${cierre} ${tags}` },
    { dia: 4, objetivo: "Contar cómo lo hiciste", idea: "Muestra la app Orquestador escribiendo la idea y el juego saliendo.",
      texto: `Hice «${t}» describiendo la idea con mis palabras y en minutos tenía ${niveles} probados. ¿Qué juego harías tú? ${tags} #ia` },
    { dia: 5, objetivo: "Momento épico", idea: "El instante más difícil o divertido: un salto al límite, un combo, un fallo absurdo.",
      texto: `Ese momento en «${t}» en el que todo sale bien… o todo sale mal 😂 ${cierre} ${tags}` },
    { dia: 6, objetivo: "Pedir opinión", idea: "Una captura del juego y una pregunta directa.",
      texto: `Estoy mejorando «${t}»: ¿qué le añadirías? Leo todos los comentarios y lo mejor entra en la próxima versión 🙌 ${tags}` },
    { dia: 7, objetivo: "Lanzamiento", idea: "Repite el clip del día 1 con el resultado de la semana (partidas, comentarios).",
      texto: `Una semana de «${t}» y gracias a vosotros ya tiene mejoras. Si aún no lo has probado, es ahora 👇 ${cierre} ${tags}` },
  ];
  if (d.idioma === "en") return planEn(d, t, enlace, tags.replace("#juegosmoviles", "#mobilegames"), giro, recortar);
  return dias.map((x) => ({ ...x, texto: recortar(x.texto) }));
}

/** Los mismos 7 días en inglés. */
function planEn(d: DatosRedes, t: string, enlace: string, tags: string, giro: string, recortar: (s: string) => string): Publicacion[] {
  const donde = d.tienda ? "Free on Google Play" : d.jugar ? "Play it free in your browser" : "Coming soon to Google Play";
  const cierre = enlace ? `${donde}: ${enlace}` : donde;
  const niveles = d.niveles && d.niveles > 1 ? `${d.niveles} levels` : "levels";
  const dias: Publicacion[] = [
    { dia: 1, objetivo: "Introduce it", idea: "The 15-second vertical clip (Share tab → Make videos).",
      texto: `Meet «${t}», my new game 🎮 ${giro ? `With a twist: ${giro.toLowerCase()}. ` : ""}${cierre} ${tags}` },
    { dia: 2, objetivo: "Show how to play", idea: "Record the screen playing the first level, no cuts.",
      texto: `This is how you play «${t}»: you learn it in 5 seconds and then you can't stop 😅 ${cierre} ${tags}` },
    { dia: 3, objetivo: "Challenge", idea: "Record your best run of the hardest level and stop just before the end.",
      texto: `Challenge: who can beat the last level of «${t}» on the first try? I couldn't 🙃 Drop your record in the comments. ${cierre} ${tags}` },
    { dia: 4, objetivo: "Tell how you made it", idea: "Show the Orquestador app writing the idea and the game coming out.",
      texto: `I made «${t}» by describing the idea in my own words and minutes later I had ${niveles} tested. What game would you make? ${tags} #ai` },
    { dia: 5, objetivo: "Epic moment", idea: "The hardest or funniest moment: a last-second jump, a combo, a silly fail.",
      texto: `That moment in «${t}» when everything goes right… or everything goes wrong 😂 ${cierre} ${tags}` },
    { dia: 6, objetivo: "Ask for feedback", idea: "A screenshot of the game and a direct question.",
      texto: `I'm improving «${t}»: what would you add? I read every comment and the best ideas make the next version 🙌 ${tags}` },
    { dia: 7, objetivo: "Launch", idea: "Repeat the day-1 clip with the week's results (plays, comments).",
      texto: `One week of «${t}» and thanks to you it already has improvements. If you haven't tried it yet, now's the time 👇 ${cierre} ${tags}` },
  ];
  return dias.map((x) => ({ ...x, texto: recortar(x.texto) }));
}
