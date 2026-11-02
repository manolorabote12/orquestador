"""Taller por instrucciones: aplica UNA instruccion a un juego ya fabricado.

	python -m cambio proyectos/bigotes_veloces "haz al gato negro" --simulado --arte-simulado --apk
	python -m cambio proyectos/bigotes_veloces "haz al gato negro" --solo-plan     (ver plan y coste)
	python -m cambio proyectos/bigotes_veloces --volver 2                          (volver a la v2)

Pasos: plan (Chispa dice que hara y cuanto cuesta) -> nuevo diseno -> solo lo afectado:
arte de esos personajes, niveles tocados, icono si cambia el heroe -> analizador -> bots ->
APK con codigo de version nuevo (se instala encima del anterior) -> capturas -> version anotada.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import cadena
import versiones
from arte import biblia as bib
from arte import cli as arte_cli
from cadena import ErrorCadena, evento
from director import cambios, director, llm


def _leer(p: Path) -> dict:
	return json.loads(p.read_text(encoding="utf-8"))


def _escribir(p: Path, datos: dict) -> None:
	p.write_text(json.dumps(datos, indent=1, ensure_ascii=False), encoding="utf-8")


def _arte_parcial(args: argparse.Namespace, proyecto: Path, ruta_biblia: Path, solo: list[str] | None, quitar: list[str]) -> dict:
	srv = None
	comfy, crear, editar = args.comfy, args.crear, args.editar
	if args.arte_simulado:
		from pruebas import comfy_simulado
		puerto = 8700 + os.getpid() % 500
		srv = comfy_simulado.arrancar(puerto)
		comfy = f"http://127.0.0.1:{puerto}"
		crear = str(cadena.RAIZ / "plantillas" / "simulado_crear.json")
		editar = str(cadena.RAIZ / "plantillas" / "simulado_editar.json")
	try:
		refs = {p.stem: str(p) for p in sorted((proyecto / "fabrica" / "referencias").glob("*.png"))}
		return arte_cli.fabricar(argparse.Namespace(
			biblia=str(ruta_biblia), comfy=comfy, crear=crear, editar=editar,
			salida=str(proyecto / "fabrica" / "arte"), godot=str(proyecto), lado=args.lado, solo=solo, quitar=quitar, referencias=refs,
			musica=cadena.flujo_musica(comfy), sfx=cadena.flujo_sfx(comfy),
			voces=cadena.destino_voces(comfy)))
	finally:
		if srv is not None:
			srv.shutdown()


def _cerrar_version(args: argparse.Namespace, proyecto: Path, slug: str, diseno: dict, mapas: list, semilla: int,
		ajustes: dict[int, float], intentos: dict[int, int], fijos: set[int] | None = None) -> tuple[dict, list, str | None, list[str], str | None]:
	"""Analizador + bots + APK + web + capturas, comun a cambios y a volver atras. fijos: niveles
	hechos a mano (no se rehacen; si no valen, el cambio falla con la explicacion)."""
	cadena.godot(proyecto, "--import", timeout=600)
	mapas = cadena.analizar_niveles(proyecto, diseno, mapas, semilla, intentos, ajustes, fijos)
	evento("validacion", "inicio", "Probando la nueva versión con bots...")
	val, mapas = cadena.validar_con_bots(proyecto, diseno, mapas, semilla, intentos, ajustes, fijos)
	if not val.get("ok"):
		raise ErrorCadena("La nueva versión no supera la validación: " + json.dumps(
			{"interfaz": val.get("interfaz"), "arte": val.get("arte"), "fallos": val.get("fallos_qa"),
			"niveles": [n for n in val.get("niveles", []) if not cadena.nivel_ok(n, True)]}, ensure_ascii=False)[:1200])
	evento("validacion", "ok", "Los bots han superado todos los niveles")
	## Reto del dia rehecho con la version nueva (sus niveles tambien tienen que seguir siendo ganables).
	try:
		cadena.niveles_reto(proyecto, diseno, semilla)
	except Exception as e:  # noqa: BLE001 - el reto es un extra
		evento("reto", "aviso", f"Sin reto del día esta vez ({str(e)[:80]})")
		(proyecto / "fabrica" / "reto.json").unlink(missing_ok=True)
	cadena.poner_reto(proyecto)
	apk = None
	if args.apk:
		evento("apk", "inicio", "Empaquetando la nueva versión...")
		apk = str(cadena.exportar_apk(proyecto, slug))
		evento("apk", "ok", "APK lista")
	web = None
	if getattr(args, "web", False):
		evento("web", "inicio", "Preparando la versión para jugar al instante...")
		web = str(cadena.exportar_web(proyecto))
		evento("web", "ok", "Lista para jugar en la app")
	capturas: list[str] = []
	if args.capturas:
		out = proyecto / "fabrica" / "capturas"
		cadena.godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--fixed-fps", "60",
			"res://qa/capturas.tscn", "--", f"--out={out}", timeout=300, display=True)
		capturas = sorted(str(p) for p in out.glob("*.png"))
	return val, mapas, apk, capturas, web


def cambiar(args: argparse.Namespace) -> dict:
	t0 = time.time()
	proyecto = Path(args.proyecto).resolve()
	gasto = getattr(args, "gasto", None) or llm.Gasto()
	mem = versiones.memoria(proyecto)
	ruta_diseno = proyecto / "fabrica" / "diseno.json"
	ruta_biblia = proyecto / "fabrica" / "biblia.json"
	diseno = _leer(ruta_diseno)
	game = _leer(proyecto / "game.json")
	mapas = director.mapas_de(game)
	slug = args.slug or _slug_actual(proyecto)
	version_nueva = int(mem["version"]) + 1
	semilla = args.semilla + version_nueva * 31

	## 1 - Plan
	if args.plan:
		texto = args.plan.strip()
		plan = json.loads(texto) if texto.startswith("{") else json.loads(Path(texto).read_text(encoding="utf-8"))
		err = cambios.validar_plan({k: v for k, v in plan.items() if k != "coste"}, diseno)
		if err:
			raise ErrorCadena("El plan ya no encaja con el juego: " + "; ".join(err))
		plan["coste"] = cambios.coste(plan)
	else:
		evento("plan", "inicio", "Pensando el cambio...")
		plan = cambios.planificar(args.instruccion, diseno, mem["historial"], args.simulado, gasto)
	evento("plan", "ok", plan["resumen"], coste=plan["coste"], operaciones=[o["op"] for o in plan["operaciones"]],
		pregunta=plan.get("pregunta"), no_puedo=plan.get("no_puedo"), usd=gasto.usd)
	if args.solo_plan or not plan["operaciones"]:
		return {"ok": True, "plan": plan, "aplicado": False, "coste_usd": {"plan": gasto.usd}}

	## 2 - Nuevo diseno y lo que hay que rehacer
	nuevo, ef = cambios.aplicar_diseno(diseno, mapas, plan)
	biblia = director.a_biblia(nuevo)
	bib.validar(biblia)
	_escribir(ruta_diseno, nuevo)
	_escribir(ruta_biblia, biblia)
	cadena.ajustar_proyecto(proyecto, nuevo["titulo"], slug, version_nueva)
	intentos: dict[int, int] = {}
	mapas = director.generar_niveles(nuevo, semilla, {i: 0 for i in ef["niveles"]}, ef["mapas"], ef["ajustes_nivel"])
	if ef["niveles"]:
		evento("niveles", "ok", f"Niveles rehechos: {sorted(i + 1 for i in ef['niveles'])}")
	cadena.escribir_game(proyecto, nuevo, mapas)

	## 3 - Arte solo de lo afectado. El dibujo del autor (fabrica/referencias/heroe.png) lo deja el
	## trabajador antes de empezar; si el heroe se redibuja sin el, se olvida.
	refs = proyecto / "fabrica" / "referencias"
	if ef.get("referencia") == "usar" and not (refs / "heroe.png").exists():
		raise ErrorCadena("Falta tu dibujo para el protagonista. Súbelo otra vez.")
	if ef.get("referencia") == "quitar":
		(refs / "heroe.png").unlink(missing_ok=True)
	usd_arte = 0.0
	if ef["arte"] or ef["quitar_sprites"]:
		solo = None if "*" in ef["arte"] else sorted(ef["arte"])
		que = "todo el arte" if solo is None else ", ".join(solo) if solo else "limpieza"
		evento("arte", "inicio", f"Redibujando: {que}...")
		inf = _arte_parcial(args, proyecto, ruta_biblia, solo, sorted(ef["quitar_sprites"]))
		usd_arte = round(inf["generaciones"] * (0.0 if args.arte_simulado else cadena.USD_POR_IMAGEN), 4)
		evento("arte", "ok", f"Arte listo: {inf['generaciones']} imágenes", imagenes=inf["generaciones"], usd=usd_arte)
	if ef["icono"]:
		cadena.crear_icono(proyecto, proyecto / "fabrica" / "arte", director.a_game(nuevo, mapas))

	## 4 - Validacion, APK, capturas y version (los giros nuevos se apuntan: la fabrica aprende)
	import giros
	giros_nuevos = [g for g in (nuevo.get("giros") or []) if g not in (diseno.get("giros") or [])]
	try:
		val, mapas, apk, capturas, web = _cerrar_version(args, proyecto, slug, nuevo, mapas, semilla, ef["ajustes_nivel"], intentos, ef.get("fijos"))
	except ErrorCadena as e:
		giros.anotar(nuevo.get("genero", "plataformas"), giros_nuevos, False, str(e)[:200])
		raise
	giros.anotar(nuevo.get("genero", "plataformas"), giros_nuevos, True)
	usd = round(gasto.usd + usd_arte, 4)
	version = versiones.anotar(proyecto, args.instruccion, plan["resumen"], plan["operaciones"], plan["coste"], {"usd": usd})
	evento("fin", "ok", f"Versión {version} lista", version=version)
	return {"ok": True, "aplicado": True, "version": version, "plan": plan, "titulo": nuevo["titulo"], "slug": slug,
		"proyecto": str(proyecto), "apk": apk, "web": web, "capturas": capturas,
		"ficha": cadena.hacer_ficha(args, proyecto, capturas), "clip": cadena.hacer_clip(args, proyecto), "coste_usd": {"total": usd, "arte_estimado": usd_arte},
		"niveles_rehechos": sorted(ef["niveles"]), "total_s": round(time.time() - t0, 1),
		"validacion": {"niveles": val["niveles"]}}


def volver(args: argparse.Namespace) -> dict:
	"""Vuelve a una version anterior. Se registra como version nueva: nada se pierde."""
	proyecto = Path(args.proyecto).resolve()
	mem = versiones.memoria(proyecto)
	n = int(args.volver)
	if not any(h["version"] == n for h in mem["historial"]):
		raise ErrorCadena(f"No existe la versión {n}")
	evento("volver", "inicio", f"Volviendo a la versión {n}...")
	versiones.restaurar(proyecto, n)
	diseno = _leer(proyecto / "fabrica" / "diseno.json")
	mapas = director.mapas_de(_leer(proyecto / "game.json"))
	version_nueva = int(mem["version"]) + 1
	slug = args.slug or _slug_actual(proyecto)
	cadena.ajustar_proyecto(proyecto, diseno["titulo"], slug, version_nueva)
	_, _, apk, capturas, web = _cerrar_version(args, proyecto, slug, diseno, mapas, args.semilla + version_nueva * 31, {}, {})
	version = versiones.anotar(proyecto, f"Volver a la versión {n}", f"He recuperado la versión {n}.", [], 0)
	evento("fin", "ok", f"Versión {version} lista (copia de la {n})", version=version)
	return {"ok": True, "version": version, "titulo": diseno["titulo"], "proyecto": str(proyecto), "apk": apk, "web": web, "capturas": capturas,
		"ficha": cadena.hacer_ficha(args, proyecto, capturas), "clip": cadena.hacer_clip(args, proyecto)}


def programar(args: argparse.Namespace) -> dict:
	"""Cambio que el taller no sabe hacer con operaciones: el agente programador lo escribe como mod
	probado (lista negra + compilacion + humo) y despues pasa los bots como cualquier version."""
	import agente_mods

	t0 = time.time()
	proyecto = Path(args.proyecto).resolve()
	gasto = getattr(args, "gasto", None) or llm.Gasto()
	mem = versiones.memoria(proyecto)
	diseno = _leer(proyecto / "fabrica" / "diseno.json")
	mapas = director.mapas_de(_leer(proyecto / "game.json"))
	slug = args.slug or _slug_actual(proyecto)
	version_nueva = int(mem["version"]) + 1
	mod = agente_mods.programar(proyecto, args.instruccion, args.simulado, gasto)
	cadena.ajustar_proyecto(proyecto, diseno["titulo"], slug, version_nueva)
	_, _, apk, capturas, web = _cerrar_version(args, proyecto, slug, diseno, mapas, args.semilla + version_nueva * 31, {}, {})
	usd = round(gasto.usd, 4)
	version = versiones.anotar(proyecto, args.instruccion, mod["resumen"], [{"op": "mod", "nombre": mod["nombre"]}], 0, {"usd": usd})
	evento("fin", "ok", f"Versión {version} lista", version=version)
	return {"ok": True, "version": version, "titulo": diseno["titulo"], "proyecto": str(proyecto), "apk": apk, "web": web,
		"capturas": capturas, "mod": mod, "ficha": cadena.hacer_ficha(args, proyecto, capturas), "clip": cadena.hacer_clip(args, proyecto),
		"coste_usd": {"total": usd}, "total_s": round(time.time() - t0, 1)}


def _slug_actual(proyecto: Path) -> str:
	for linea in (proyecto / "export_presets.cfg").read_text(encoding="utf-8").splitlines():
		if linea.startswith("export_path="):
			return Path(linea.split("=", 1)[1].strip('"')).stem
	return proyecto.name


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Taller por instrucciones de Orquestador")
	p.add_argument("proyecto")
	p.add_argument("instruccion", nargs="?", default="")
	p.add_argument("--volver", type=int, default=0, help="Volver a esta version")
	p.add_argument("--solo-plan", action="store_true", help="Solo muestra el plan y su coste")
	p.add_argument("--plan", default="", help="Aplicar un plan ya aprobado (JSON o ruta) sin volver a llamar a la IA")
	p.add_argument("--simulado", action="store_true")
	p.add_argument("--arte-simulado", action="store_true")
	p.add_argument("--comfy", default="http://127.0.0.1:8188")
	p.add_argument("--crear", default=str(cadena.RAIZ / "plantillas" / "crear.json"))
	p.add_argument("--editar", default=str(cadena.RAIZ / "plantillas" / "editar.json"))
	p.add_argument("--lado", type=int, default=1024)
	p.add_argument("--semilla", type=int, default=7)
	p.add_argument("--slug", default="")
	p.add_argument("--apk", action="store_true")
	p.add_argument("--capturas", action="store_true")
	p.add_argument("--web", action="store_true")
	p.add_argument("--ficha", action="store_true")
	p.add_argument("--clip", action="store_true")
	a = p.parse_args(argv)
	try:
		if a.volver:
			volver(a)
		else:
			if not a.instruccion and not a.plan:
				p.error("Falta la instruccion")
			cambiar(a)
		return 0
	except (ErrorCadena, llm.ErrorIA, bib.BibliaInvalida, ValueError, FileNotFoundError) as e:
		evento("fin", "error", str(e))
		return 1


if __name__ == "__main__":
	sys.exit(main())
