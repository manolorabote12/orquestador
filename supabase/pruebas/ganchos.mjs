import { girosValidos, marca, respaldo, sistema, validar } from "./.ganchos.mjs";
let fallos = 0;
const ok = (n, c) => { console.log((c ? "  OK   " : "  FALLO ") + n); if (!c) fallos++; };
const ia = JSON.stringify({ ganchos: [
  { titulo: "Pirámide serpiente", genero: "laberinto", giros: ["cola", "monstruos", "oscuridad"], idea: "Un gato explorador en una pirámide donde su rastro se cierra", por_que: "Pensar cada paso" },
  { titulo: "Hacker", genero: "hackeo", giros: [], idea: "Un juego que no existe en la fabrica", por_que: "x" },
  { titulo: "Golf de momias", genero: "golf", giros: ["monstruos"], idea: "Minigolf en una tumba derribando momias", por_que: "Combos" },
  { titulo: "Repetido", genero: "golf", giros: ["monstruos"], idea: "Otro minigolf con monstruos igual que el anterior", por_que: "x" },
] });
const g = validar("Aquí tienes: " + ia, "un gato en una piramide");
ok("siempre 3 ganchos", g.length === 3);
ok("giros de otro genero fuera y como mucho 2", JSON.stringify(g[0].giros) === JSON.stringify(["cola", "oscuridad"]));
ok("genero inventado fuera", !g.some((x) => x.genero === "hackeo"));
ok("sin repetidos", new Set(g.map((x) => x.genero + x.giros.join())).size === 3);
ok("respuesta rota: 3 de respaldo", validar("no sé", "un dragón").length === 3);
const fiab = [{ genero: "laberinto", giro: "cola", usos: 10, ok: 2 }];
ok("lo que falla mucho no se propone", !girosValidos("laberinto", fiab).includes("cola") && girosValidos("laberinto").includes("cola"));
ok("con cola poco fiable, el laberinto sale sin cola", !validar(ia, "x", fiab).some((x) => x.genero === "laberinto" && x.giros.includes("cola")));
ok("marca para la fabrica", marca({ genero: "golf", giros: ["monstruos"], idea: "Minigolf", titulo: "x", por_que: "" }) === "[gancho:golf:monstruos] Minigolf");
ok("respaldo con el tema", respaldo("un pulpo")[0].idea.includes("un pulpo"));
ok("el prompt lista generos y giros", sistema().includes("laberinto") && sistema().includes("monstruos"));
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
process.exit(fallos ? 1 : 0);
