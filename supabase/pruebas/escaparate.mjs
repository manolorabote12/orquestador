// Escaparate: publicar, retirar y copiar para remix con un almacen falso en memoria.
import { copiarParaRemix, publicar, retirar, tipoDe } from "./.escaparate.mjs";

let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : "  " + d)); if (!ok) fallos++; };
const datos = new Map();
const a = {
  async bajar(b, r) { const k = `${b}/${r}`; if (!datos.has(k)) throw new Error("no existe " + k); return datos.get(k); },
  async subir(b, r, d) { datos.set(`${b}/${r}`, d); },
  async borrar(b, rs) { for (const r of rs) datos.delete(`${b}/${r}`); },
};
const B = (t) => new TextEncoder().encode(t);
for (const r of ["a/p/v2/web/index.pck", "a/p/v2/icono.png", "a/p/v2/capturas/1.png", "a/p/v2/capturas/2.png", "a/p/v2/p_godot.zip", "a/p/v2/juego.apk"]) datos.set("juegos/" + r, B(r));
const files = { web: "a/p/v2/web/index.pck", icono: "a/p/v2/icono.png", capturas: ["a/p/v2/capturas/1.png", "a/p/v2/capturas/2.png"],
  proyecto: "a/p/v2/p_godot.zip", apk: "a/p/v2/juego.apk", version: 2, guia: { pasos: [] }, privacidad_url: "x" };

await publicar(a, { id: "P", title: "Bigotes", spec: { resumen: "Gato", genero: "plataformas" }, version: 2, files }, "Daniel");
check("paquete web publico", new TextDecoder().decode(datos.get("escaparate/P/index.pck")) === "a/p/v2/web/index.pck");
check("icono y portada (primera captura)", datos.has("escaparate/P/icono.png") && new TextDecoder().decode(datos.get("escaparate/P/portada.png")).endsWith("1.png"));
const ficha = JSON.parse(new TextDecoder().decode(datos.get("escaparate/P/ficha.json")));
check("ficha sin datos privados", ficha.titulo === "Bigotes" && ficha.autor === "Daniel" && !JSON.stringify(ficha).includes("a/p/v2"), JSON.stringify(ficha));
let err = "";
try { await publicar(a, { id: "Q", title: "x", spec: {}, version: 1, files: {} }, ""); } catch (e) { err = e.message; }
check("sin version web no se publica", err === "no_web_build");

const nuevo = await copiarParaRemix(a, files, "b", "remix-P-1/v2");
check("remix copia a la carpeta del usuario", nuevo.proyecto === "b/remix-P-1/v2/p_godot.zip" && nuevo.web === "b/remix-P-1/v2/web/index.pck"
  && datos.has("juegos/b/remix-P-1/v2/p_godot.zip"), JSON.stringify(nuevo));
check("capturas copiadas y version", nuevo.capturas.length === 2 && nuevo.version === 2);
check("no copia datos de publicacion del autor", !("guia" in nuevo) && !("privacidad_url" in nuevo));
err = "";
try { await copiarParaRemix(a, { proyecto: "a/../../x" }, "b", "r"); } catch (e) { err = e.message; }
check("rutas con .. rechazadas", err === "bad_path");
await retirar(a, "P");
check("retirar borra lo publico", ![...datos.keys()].some((k) => k.startsWith("escaparate/P/")));
check("tipos", tipoDe("x.png") === "image/png" && tipoDe("x.pck") === "application/octet-stream");
console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
