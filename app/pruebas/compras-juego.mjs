// Compras a medida (src/api/compras-juego.ts): las plantillas valen, los errores se explican y
// los codigos automaticos cumplen las reglas de Google Play.
import { PLANTILLAS_TIENDA, codigoCompra, euros, validarTiendaJuego, errorTienda } from "./.compras-juego.mjs";

let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FAIL ") + n + (d ? `  (${d})` : "")); if (!ok) fallos++; };
for (const [k, v] of Object.entries(PLANTILLAS_TIENDA)) check(`plantilla ${k} valida`, validarTiendaJuego(v.tienda) === null, String(validarTiendaJuego(v.tienda)));
const base = () => JSON.parse(JSON.stringify(PLANTILLAS_TIENDA.gemas.tienda));
let t = base(); t.moneda.nombre = "";
check("moneda sin nombre", /nombre a tu moneda/.test(validarTiendaJuego(t)));
t = base(); t.productos[0].precio_cent = 15000;
check("precio de mas de 99,99", /99,99/.test(validarTiendaJuego(t)));
t = base(); t.productos[1].id = t.productos[0].id;
check("codigo repetido", /dos productos/.test(validarTiendaJuego(t)));
t = base(); t.productos.push({ id: "vip_b", tipo: "vip", precio_cent: 199 }, { id: "vip_c", tipo: "vip", precio_cent: 299 });
check("3 VIP no", /2 suscripciones/.test(validarTiendaJuego(t)));
check("codigo automatico de un pack", codigoCompra({ id: "", tipo: "monedas", cantidad: 500, precio_cent: 99 }, "Rubíes Mágicos") === "rubies_magicos_500");
check("codigo automatico si la moneda empieza por numero", /^[a-z][a-z0-9_]{2,39}$/.test(codigoCompra({ id: "", tipo: "monedas", cantidad: 5, precio_cent: 99 }, "7 mares")));
check("euros", euros(499) === "4,99 €" && euros(10) === "0,10 €");
check("error del servidor en palabras", errorTienda("ERROR: bad_price") === "Los precios van de 0,10 € a 99,99 €.");
console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
