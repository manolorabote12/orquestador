// Centro de lanzamiento: los pasos que llevan un juego de «recién fabricado» a «en producción en
// Google Play», en orden, con cuál toca ahora y a dónde lleva su botón. Sin red: sale del estado del
// juego (Publicar) y de su campaña de la Lanzadera.

export type AccionPaso = "jugar" | "publicar" | "preparar" | "anuncios" | "lanzadera";

export interface DatosLanzamiento {
  /** El autor ya lo ha jugado en la app. */
  jugado: boolean;
  anuncios: boolean;
  infantil: boolean;
  /** Estado en Google Play: null (sin preparar), "primer_aab", "borrador", "subido"... */
  play: string | null;
  pista: string | null;
  /** Campaña de la Lanzadera: null (sin campaña), "abierta" o "lista". */
  campana: "abierta" | "lista" | null;
}

export interface PasoLanzamiento {
  id: string;
  titulo: string;
  ayuda: string;
  hecho: boolean;
  boton: string;
  accion: AccionPaso;
}

export function pasosLanzamiento(d: DatosLanzamiento): PasoLanzamiento[] {
  const enPlay = d.play !== null && d.play !== "primer_aab";
  const produccion = enPlay && d.pista === "production";
  const cerrada = enPlay && (d.pista === "alpha" || d.pista === "beta" || produccion);
  return [
    { id: "jugar", titulo: "Juégalo tú", ayuda: "Pruébalo entero antes de enseñarlo: si algo no te gusta, pídeselo a Chispa.",
      hecho: d.jugado, boton: "Jugar ya", accion: "jugar" },
    { id: "anuncios", titulo: d.infantil ? "Anuncios para familias" : "Activa los anuncios",
      ayuda: "Pega tus ids de AdMob para que el juego gane dinero desde el primer día (sin ellos se publica sin anuncios).",
      hecho: d.anuncios, boton: "Poner anuncios", accion: "anuncios" },
    { id: "preparar", titulo: "Prepáralo para Google Play", ayuda: "Chispa hace el .aab firmado, las imágenes, los textos y las respuestas de cada formulario.",
      hecho: d.play !== null, boton: "Preparar", accion: "preparar" },
    { id: "subir", titulo: "Súbelo a la prueba cerrada", ayuda: "Crea el juego en Play Console siguiendo la guía y pulsa «subir a prueba cerrada».",
      hecho: cerrada, boton: "Ir a publicar", accion: "publicar" },
    { id: "probadores", titulo: "Pide probadores en la Lanzadera", ayuda: "Google pide 12 probadores durante 14 días a las cuentas nuevas: la comunidad te ayuda.",
      hecho: d.campana !== null || produccion, boton: "Ir a la Lanzadera", accion: "lanzadera" },
    { id: "catorce", titulo: "12 probadores, 14 días", ayuda: "Mientras tanto, mejora el juego con sus opiniones: cada versión se sube sola.",
      hecho: d.campana === "lista" || produccion, boton: "Ver la campaña", accion: "lanzadera" },
    { id: "produccion", titulo: "Pide producción y publícalo", ayuda: "En la Lanzadera tienes las respuestas para Google ya escritas con los datos de tu prueba.",
      hecho: produccion, boton: d.campana === "lista" ? "Ver respuestas" : "Ir a publicar", accion: d.campana === "lista" ? "lanzadera" : "publicar" },
  ];
}

/** El primer paso sin hacer (o null si está todo). */
export function siguientePaso(pasos: PasoLanzamiento[]): PasoLanzamiento | null {
  return pasos.find((p) => !p.hecho) ?? null;
}
