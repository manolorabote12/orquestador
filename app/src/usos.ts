// ¿Para qué es el juego? Cambia la pista al escribir la idea y el siguiente paso al terminar
// (premio del negocio, dedicatoria del regalo o la clase del profe).

export type Uso = "publicar" | "negocio" | "regalo" | "clase";

export interface InfoUso {
  id: Uso;
  nombre: string;
  /** Ejemplo en el cuadro de la idea. */
  ejemplo: string;
  /** Lo que dice Chispa al elegirlo. */
  chispa: string;
  /** Al terminar: el consejo, el botón y a qué parte de la ficha lleva. */
  consejo: string;
  boton: string;
  pestana: "publicar" | "compartir" | "jugadores";
  seccion: string;
}

export const USOS: InfoUso[] = [
  { id: "publicar", nombre: "Para publicar", ejemplo: "Ej.: un gato ninja rápido que salta por tejados de noche y aplasta ratas robot",
    chispa: "¡Hola! Soy Chispa. Cuéntame tu juego: quién es el héroe, dónde salta y contra qué.",
    consejo: "¿Y ahora? Pruébalo y, cuando te guste, en su ficha tienes el camino a Google Play paso a paso: anuncios, subida, probadores y producción.",
    boton: "Ver el camino a Google Play", pestana: "publicar", seccion: "" },
  { id: "negocio", nombre: "Para mi negocio", ejemplo: "Ej.: un panadero que atrapa barras de pan al vuelo en una panadería de pueblo, con los colores de mi tienda",
    chispa: "Un juego para tu negocio: cuéntame qué vendes y cómo es tu tienda. Al acabar, pones un premio real para quien supere un nivel.",
    consejo: "¿Y ahora? Ponle un premio de verdad (un descuento, un café gratis) para quien supere un nivel: cada jugador recibe su código para canjearlo en tu tienda.",
    boton: "Poner el premio de mi negocio", pestana: "jugadores", seccion: "premio" },
  { id: "regalo", nombre: "Para regalar", ejemplo: "Ej.: Lucía, que adora los gatos y la playa, recoge conchas esquivando cangrejos",
    chispa: "Un juego regalo: cuéntame para quién es y qué le gusta. Al acabar, escribes tu mensaje secreto y se lo mandas con un enlace privado.",
    consejo: "¿Y ahora? Escribe tu mensaje secreto (aparece al superar el nivel que elijas) y mándale el enlace privado.",
    boton: "Escribir la dedicatoria", pestana: "compartir", seccion: "regalo" },
  { id: "clase", nombre: "Para mi clase", ejemplo: "Ej.: preguntas de las tablas de multiplicar con un cohete que sube a la Luna en cada acierto",
    chispa: "Un juego para tu clase: cuéntame qué tienen que aprender (tablas, vocabulario, capitales...). Al acabar, creas la clase y ves cómo va cada alumno.",
    consejo: "¿Y ahora? Crea la clase y dicta el código: cada alumno lo escribe en el juego y tú ves sus niveles, estrellas y minutos.",
    boton: "Crear la clase", pestana: "jugadores", seccion: "clase" },
];

export function infoUso(id: string | null | undefined): InfoUso {
  return USOS.find((u) => u.id === id) ?? USOS[0];
}
