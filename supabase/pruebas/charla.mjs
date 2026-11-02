// Charla con personajes: validacion, filtros, personajes del diseno y prompt.
import { esquiva, limpiar, moderar, personajes, respaldo, sistema, usuario, validar } from "./.charla.mjs";

let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : "  " + d)); if (!ok) fallos++; };
const J = "0f8fad5b-d9cb-469f-a165-70867728950e";
const ok = { juego: J, sesion: "aaaaaaaaaaaaaaa1", personaje: "heroe", mensaje: "¿Qué truco hay en el nivel 2?", historial: [] };

check("peticion buena", typeof validar(ok) === "object");
check("juego raro", validar({ ...ok, juego: "x" }) === "bad_game");
check("sesion rara", validar({ ...ok, sesion: "corta" }) === "bad_session");
check("personaje inventado", validar({ ...ok, personaje: "narrador" }) === "bad_character");
check("mensaje vacio o largo", validar({ ...ok, mensaje: "  " }) === "bad_message" && validar({ ...ok, mensaje: "a".repeat(201) }) === "bad_message");
const h = validar({ ...ok, historial: Array.from({ length: 10 }, (_, i) => ({ de: i % 2 ? "personaje" : "jugador", texto: "m" + i })).concat([{ de: "sistema", texto: "x" }]) });
check("historial: solo los ultimos y bien formados", h.historial.length === 5 && h.historial[0].texto === "m5", JSON.stringify(h.historial));

check("palabrotas fuera (tambien con numeros)", moderar("eres un p0ll4s") !== "" && moderar("CABRONAZO") !== "");
check("palabras inocentes pasan", moderar("el sexto nivel de la disputa en la drogueria") === "" && moderar("¿conoces al jefe?") === "");
check("enlaces, correos y telefonos fuera", moderar("mira www.algo.com") === "enlace" && moderar("escribe a yo@x.com") === "correo" && moderar("llama al 600 123 456") === "telefono");
check("datos personales fuera", moderar("¿Dónde vives?") === "datos");

const spec = { titulo: "Bigotes", resumen: "Un gato ninja salta tejados", escenario: { descripcion: "roof tiles" },
  heroe: { nombre: "Bigotes", descripcion: "a ninja cat" }, enemigos: [{ tipo: "walker", nombre: "Chatarrilla", descripcion: "a robot" }] };
const r = personajes(spec);
check("personajes del diseno: heroe y rival (sin jefe si no hay)", r.heroe?.nombre === "Bigotes" && r.rival?.nombre === "Chatarrilla" && !r.jefe);
const s = sistema(r.heroe, spec, "Bigotes");
check("el prompt fija el papel y las reglas", s.includes("Eres Bigotes") && s.includes("datos personales") && s.includes("todas las edades") && s.includes("Un gato ninja"));
const u = usuario({ ...ok, historial: [{ de: "jugador", texto: "hola" }, { de: "personaje", texto: "¡miau!" }] });
check("el mensaje va marcado como datos", u.includes("<mensaje>") && u.includes("Jugador: hola") && u.includes("Tú: ¡miau!"));

check("respuesta limpia", limpiar('  "¡Salta en la tercera chimenea!"  ') === "¡Salta en la tercera chimenea!");
check("respuesta con enlace o palabrota: fuera", limpiar("visita https://x.com") === "" && limpiar("qué mierda") === "");
const larga = limpiar("Frase uno muy larga. ".repeat(30));
check("respuesta larga se corta en una frase", larga.length <= 280 && larga.endsWith("."), larga);
check("respaldo y esquiva con personalidad", respaldo("rival", 1).length > 5 && esquiva("jefe") !== esquiva("heroe") && respaldo("raro", 0).length > 5);

console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
