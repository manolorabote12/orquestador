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
import shutil
import subprocess
import sys
import time
from pathlib import Path

import cadena
import versiones
from arte import biblia as bib
from arte import cli as arte_cli
from arte import extras
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
	cadena.importar(proyecto)
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
	## Primero la version para jugar (segundos): se adelanta a la app para que el cambio se pueda
	## jugar ya, mientras se empaqueta el APK y se hacen las capturas y la ficha.
	web = None
	if getattr(args, "web", False):
		evento("web", "inicio", "Preparando la versión para jugar al instante...")
		web = str(cadena.exportar_web(proyecto))
		evento("web", "ok", "Lista para jugar en la app")
		adelantar = getattr(args, "adelanto", None)
		if callable(adelantar):
			try:
				evento("adelanto", "ok", "¡Ya puedes jugar el cambio! Termino el APK y la ficha mientras tanto", adelanto=adelantar(Path(web)))
			except Exception as e:  # noqa: BLE001 - es un extra: sin adelanto se espera al final como antes
				print(f"[cambio] sin adelanto: {str(e)[:120]}", flush=True)
	apk = None
	if args.apk:
		evento("apk", "inicio", "Empaquetando la nueva versión...")
		apk = str(cadena.exportar_apk(proyecto, slug))
		evento("apk", "ok", "APK lista")
	capturas: list[str] = []
	if args.capturas:
		out = proyecto / "fabrica" / "capturas"
		## 15 nov: en 3D sin tarjeta grafica las capturas pasaban de 300 s y el cambio entero fallaba
		## (con el APK ya hecho). Ahora se espera mas y, si aun asi no acaban, valen las que hayan salido.
		try:
			cadena.godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--fixed-fps", "60",
				"res://qa/capturas.tscn", "--", f"--out={out}", timeout=540, display=True)
		except subprocess.TimeoutExpired:
			evento("capturas", "aviso", "Las capturas tardan demasiado: me quedo con las que han salido")
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


def _sandbox_listo(proyecto: Path) -> str:
	"""Usuario sin privilegios para jugar codigo del autor (ORQ_SANDBOX, «orqsb» en la imagen). Le da la
	carpeta del proyecto. Sin ese usuario (en un PC) se juega como siempre."""
	import pwd
	nombre = os.environ.get("ORQ_SANDBOX", "orqsb")
	try:
		u = pwd.getpwnam(nombre)
	except KeyError:
		return ""
	os.chmod(proyecto.parent, 0o755)
	for raiz, dirs, archivos in os.walk(proyecto):
		for n in dirs + archivos:
			try:
				os.chown(os.path.join(raiz, n), u.pw_uid, u.pw_gid, follow_symlinks=False)
			except OSError:
				pass
	os.chown(proyecto, u.pw_uid, u.pw_gid)
	return nombre


def importar_experto(args: argparse.Namespace) -> dict:
	"""Modo experto: el proyecto cambiado a mano en Godot (args.zip) se pone encima de la version guardada
	(experto.py lo revisa) y pasa los bots, el APK y la version como cualquier cambio. Los niveles son
	los del autor: si un bot no puede con uno, no se rehace; el cambio falla y dice cual."""
	import experto

	t0 = time.time()
	proyecto = Path(args.proyecto).resolve()
	mem = versiones.memoria(proyecto)
	slug = args.slug or _slug_actual(proyecto)
	version_nueva = int(mem["version"]) + 1
	evento("experto", "inicio", "Revisando lo que has cambiado en Godot...")
	previo = _leer(proyecto / "game.json")
	try:
		r = experto.aplicar(proyecto, Path(args.zip))
	except experto.ErrorExperto as e:
		raise ErrorCadena(str(e)) from e
	txt = experto.resumen(r)
	evento("experto", "ok", txt)
	diseno = _leer(proyecto / "fabrica" / "diseno.json")
	autor = _leer(proyecto / "game.json")
	mapas = director.mapas_de(autor)
	## Lo cambiado a mano en game.json se guarda aparte y se pone encima siempre (cadena.escribir_game).
	if "game.json" in r["cambiados"] + r["nuevos"]:
		ruta_exp = proyecto / "fabrica" / "game_experto.json"
		dif = cadena.diferencia(previo, autor)
		if dif:
			antes = _leer(ruta_exp) if ruta_exp.exists() else {}
			_escribir(ruta_exp, cadena.mezclar(antes, dif))
	cadena.ajustar_proyecto(proyecto, diseno["titulo"], slug, version_nueva)
	cadena.SANDBOX = _sandbox_listo(proyecto)
	try:
		_, _, apk, capturas, web = _cerrar_version(args, proyecto, slug, diseno, mapas, args.semilla + version_nueva * 31, {}, {},
			set(range(len(mapas))))
	finally:
		cadena.SANDBOX = ""
	version = versiones.anotar(proyecto, "Cambios a mano en Godot", txt, [{"op": "experto", **{k: len(v) for k, v in r.items()}}], 0)
	evento("fin", "ok", f"Versión {version} lista", version=version)
	return {"ok": True, "version": version, "titulo": diseno["titulo"], "proyecto": str(proyecto), "apk": apk, "web": web,
		"capturas": capturas, "experto": r, "ficha": cadena.hacer_ficha(args, proyecto, capturas), "clip": cadena.hacer_clip(args, proyecto),
		"coste_usd": {"total": 0.0}, "total_s": round(time.time() - t0, 1)}


def poner_kit_nuevo(proyecto: Path) -> None:
	"""El codigo del juego al dia (kit, qa, escenas y autoloads) sin tocar su arte, su game.json, su
	nombre ni su paquete de Android."""
	for sub in ("kit", "qa", "scenes", "addons/chispa"):
		if (cadena.KIT / sub).exists():
			shutil.rmtree(proyecto / sub, ignore_errors=True)
			shutil.copytree(cadena.KIT / sub, proyecto / sub, ignore=shutil.ignore_patterns(".godot"))
	## Autoloads del kit nuevo (si se anadio alguno), el resto de project.godot se queda.
	import re
	nuevo = (cadena.KIT / "project.godot").read_text(encoding="utf-8")
	pg = proyecto / "project.godot"
	viejo = pg.read_text(encoding="utf-8")
	sec = re.search(r"^\[autoload\]\n(?:(?!^\[).*\n?)*", nuevo, flags=re.M)
	if sec and re.search(r"^\[autoload\]", viejo, flags=re.M):
		viejo = re.sub(r"^\[autoload\]\n(?:(?!^\[).*\n?)*", sec.group(0).rstrip("\n") + "\n\n", viejo, count=1, flags=re.M)
		pg.write_text(viejo, encoding="utf-8")


def sprites_cambiados(vieja: dict, nueva: dict) -> tuple[list[str], list[str]]:
	"""(ids que hay que dibujar, ids que sobran). Un sprite se conserva si tiene la misma descripcion,
	tamano y orientacion y ya tiene todas las animaciones que pide el kit (aunque con menos frames por
	el tope de imagenes de entonces): en ese caso su entrada vieja vuelve a la biblia nueva."""
	antes = {s["id"]: s for s in vieja.get("personajes", []) + vieja.get("objetos", [])}
	dibujar = []
	for lista in ("personajes", "objetos"):
		for k, s in enumerate(nueva.get(lista, [])):
			v = antes.get(s["id"])
			igual = v is not None and all(v.get(c) == s.get(c) for c in ("descripcion", "tamano", "mira_a", "rol")) \
				and set(s.get("animaciones", {})) <= set(v.get("animaciones", {}))
			if igual:
				nueva[lista][k] = v
			else:
				dibujar.append(s["id"])
	ahora = {s["id"] for s in nueva.get("personajes", []) + nueva.get("objetos", [])}
	return sorted(dibujar), sorted(i for i in antes if i not in ahora)


def actualizar(args: argparse.Namespace) -> dict:
	"""Arreglar sin rehacer (14 nov): el mismo juego (diseno, niveles y arte) con el kit y la fabrica de
	hoy. Solo se dibuja lo nuevo o lo que cambio (p. ej. los heroes del RPG o la pose de ataque), sin
	volver a pensar el diseno: cuesta centimos en vez de un juego entero."""
	t0 = time.time()
	proyecto = Path(args.proyecto).resolve()
	mem = versiones.memoria(proyecto)
	ruta_diseno = proyecto / "fabrica" / "diseno.json"
	ruta_biblia = proyecto / "fabrica" / "biblia.json"
	diseno = _leer(ruta_diseno)
	mapas = director.mapas_de(_leer(proyecto / "game.json"))
	slug = args.slug or _slug_actual(proyecto)
	version_nueva = int(mem["version"]) + 1
	evento("actualizar", "inicio", "Poniendo tu juego al día (código nuevo, mismo arte)...")
	poner_kit_nuevo(proyecto)
	vieja = _leer(ruta_biblia) if ruta_biblia.exists() else {}
	## Rehacer personajes con otra descripcion (ORQ_REHACER = {"brawler_x": "nueva descripcion"}; 15 nov:
	## uno se parecia demasiado a un personaje famoso). Se cambia en el diseno para que no vuelva.
	rehacer = json.loads(os.environ.get("ORQ_REHACER") or "{}")
	for sid, desc in rehacer.items():
		for b in ((diseno.get("contenido") or {}).get("brawlers") or []) if sid.startswith("brawler_") else []:
			if b.get("id") == sid[len("brawler_"):]:
				b["desc"] = str(desc)[:200]
	if rehacer:
		_escribir(ruta_diseno, diseno)
	biblia = director.a_biblia(diseno)
	bib.validar(biblia)
	dibujar, sobran = sprites_cambiados(vieja, biblia)
	## Arte de GPU de lo que antes era codigo (iconos, efectos, eventos): si el juego aun no lo tiene.
	man = proyecto / "assets" / "manifest.json"
	ui_prev = (_leer(man).get("ui") or {}) if man.exists() else {}
	if man.exists() and (extras.faltan(_leer(man), biblia["juego"].get("genero") == "arena", biblia["juego"].get("genero") == "supervivencia") or os.environ.get("ORQ_REDIBUJAR")):
		dibujar.append("extras")
	## Marcos de panel y botones dibujados (menus que no parezcan de codigo), si no los tiene.
	if man.exists() and not ui_prev.get("skin"):
		dibujar.append("piel")
	## Personajes animados con video (Wan 2.2): solo si se pide (cuesta ~0,15 $ por personaje).
	if man.exists() and getattr(args, "animar", False) and biblia["juego"].get("genero") == "arena":
		sp = _leer(man).get("sprites") or {}
		if rehacer or any(not (sp.get(k) or {}).get("animado") for k in sp if k == "heroe" or k.startswith("brawler_")):
			dibujar.append("animar")
	## Locutor de la arena (Qwen3-TTS), si aun no lo tiene.
	if man.exists() and biblia["juego"].get("genero") == "arena" and "loc_victoria" not in (_leer(man).get("voces") or {}):
		dibujar.append("locutor")
	_escribir(ruta_biblia, biblia)
	cadena.ajustar_proyecto(proyecto, diseno["titulo"], slug, version_nueva)
	cadena.escribir_game(proyecto, diseno, mapas)
	usd_arte = 0.0
	if dibujar or sobran:
		evento("arte", "inicio", "Dibujando solo lo nuevo: " + (", ".join(dibujar) or "limpieza"))
		inf = _arte_parcial(args, proyecto, ruta_biblia, dibujar, sobran)
		usd_arte = round(inf["generaciones"] * (0.0 if args.arte_simulado else cadena.USD_POR_IMAGEN), 4)
		## Con RunPod el coste es el real (los videos cuestan mas que una imagen).
		if not args.arte_simulado and float(inf.get("usd") or 0.0) > usd_arte:
			usd_arte = round(float(inf["usd"]), 4)
		evento("arte", "ok", f"Arte nuevo: {inf['generaciones']} imágenes", imagenes=inf["generaciones"], usd=usd_arte)
	else:
		evento("arte", "ok", "El arte ya estaba: no se dibuja nada")
	_, mapas, apk, capturas, web = _cerrar_version(args, proyecto, slug, diseno, mapas, args.semilla + version_nueva * 31, {}, {})
	version = versiones.anotar(proyecto, "Actualizar al kit de hoy", "Mismo juego con el código y los arreglos nuevos.", [{"op": "actualizar"}], 0,
		{"usd": usd_arte})
	evento("fin", "ok", f"Versión {version} lista", version=version)
	return {"ok": True, "version": version, "titulo": diseno["titulo"], "slug": slug, "proyecto": str(proyecto), "apk": apk, "web": web,
		"capturas": capturas, "ficha": cadena.hacer_ficha(args, proyecto, capturas), "clip": cadena.hacer_clip(args, proyecto),
		"coste_usd": {"total": usd_arte, "arte_estimado": usd_arte}, "dibujados": dibujar, "total_s": round(time.time() - t0, 1)}


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
