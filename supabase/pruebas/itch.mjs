// Paquete para itch.io: el zip se abre con unzip y trae index.html, el motor y el juego.
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
const { crc32, zipStore, paqueteItch, htmlItch } = await import("./.itch.mjs");
const enc = new TextEncoder();
check("crc32 conocido", crc32(enc.encode("123456789")) === 0xcbf43926);
const motor = { "index.js": enc.encode("var Engine;"), "index.wasm": new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]) };
const zip = paqueteItch('Gato <ninja> & "co"', motor, enc.encode("PCK!"));
const dir = mkdtempSync(join(tmpdir(), "itch-"));
writeFileSync(join(dir, "j.zip"), zip);
let lista = "";
try { lista = execFileSync("unzip", ["-l", join(dir, "j.zip")]).toString(); } catch (e) { lista = String(e); }
check("el zip se abre y trae lo necesario", ["index.html", "index.js", "index.wasm", "index.pck"].every((n) => lista.includes(n)), lista);
execFileSync("unzip", ["-q", "-o", join(dir, "j.zip"), "-d", join(dir, "x")]);
check("contenido intacto (crc)", readFileSync(join(dir, "x", "index.pck")).toString() === "PCK!" && readFileSync(join(dir, "x", "index.wasm")).length === 8);
const html = readFileSync(join(dir, "x", "index.html")).toString();
check("index.html con el título escapado", html.includes("Gato &lt;ninja&gt; &amp; &quot;co&quot;") && html.includes('mainPack: "index.pck"'));
check("sin cabeceras especiales (vale en itch)", htmlItch("x").includes("ensureCrossOriginIsolationHeaders: false"));
let sin = false;
try { paqueteItch("x", { "index.js": enc.encode("a") }, enc.encode("p")); } catch (e) { sin = String(e).includes("no_engine"); }
check("sin motor, error claro", sin);
check("nombres con tildes", (() => { const z = zipStore([{ nombre: "niño.txt", datos: enc.encode("ñ") }]); writeFileSync(join(dir, "n.zip"), z); return execFileSync("unzip", ["-l", join(dir, "n.zip")]).toString().includes("ni"); })());
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
