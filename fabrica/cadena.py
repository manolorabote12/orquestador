"""Cadena completa de Orquestador: idea -> juego de Godot validado (y APK).

	python -m cadena "un gato ninja que salta por tejados" --simulado --arte-simulado --apk

Pasos (cada uno avisa de su progreso con una linea JSON que empieza por "@@ "):
	1 - diseno     La directora (Claude, o la simulada) convierte la idea en un diseno validado.
	2 - proyecto   Copia del kit OrqKit con la Biblia y el diseno guardados.
	3 - niveles    Generador por bloques + analizador de Godot; lo que falla se regenera.
	4 - arte       Cadena de arte (ComfyUI real o simulado), sonidos y manifest con la interfaz.
	5 - icono      Icono de la app a partir de la ficha del heroe.
	6 - validacion Bots jugando cada nivel, arte presente e interfaz auditada. Los niveles que
	               el bot no completa se regeneran y se vuelve a validar.
	7 - apk        (opcional) Exportacion para Android y firma.
	8 - capturas   (opcional) Titulo, niveles, juego y resultado para la galeria de la app.
Al final escribe informe.json con tiempos, costes y resultados.
"""

import argparse
import copy
import json
import math
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

from arte import biblia as bib
from arte import cli as arte_cli
from director import director, llm

import generos
import contenido
import giros
import originalidad
import versiones
from textos import traducir

RAIZ = Path(__file__).resolve().parent
KIT = RAIZ.parent / "orqkit"
## Estimacion de coste por imagen en RunPod serverless (GPU de 24 GB, ~4 s por imagen).
USD_POR_IMAGEN = float(os.environ.get("ORQ_USD_POR_IMAGEN", "0.002"))
FLUJOS_ARTE = {
	"crear": {"zimage": "crear_zimage.json"},
	"editar": {"klein": "editar_klein.json", "qwen": "editar_qwen.json"},
}


def flujo_arte(paso: str) -> str:
	"""Flujo de ComfyUI por defecto. ORQ_CREAR=zimage | ORQ_EDITAR=klein (rapido) o qwen (mas fiel)."""
	modelos = FLUJOS_ARTE[paso]
	defecto = next(iter(modelos))
	elegido = os.environ.get("ORQ_" + paso.upper(), defecto).strip().lower()
	return str(RAIZ / "plantillas" / "runpod" / modelos.get(elegido, modelos[defecto]))


def flujo_musica(comfy: str) -> str:
	"""Musica con IA (ACE-Step 1.5 XL) o procedural. ORQ_MUSICA=acestep | procedural | auto (por defecto:
	IA cuando el arte se dibuja en RunPod, procedural en pruebas y con un ComfyUI propio)."""
	modo = os.environ.get("ORQ_MUSICA", "auto").strip().lower()
	if modo == "procedural" or (modo == "auto" and not str(comfy).startswith("runpod://")):
		return ""
	return str(RAIZ / "plantillas" / "runpod" / "musica_acestep.json")


def destino_voces(comfy: str) -> str:
	"""Voz del heroe: runpod://<RUNPOD_VOZ_ENDPOINT> cuando el arte va a RunPod (ORQ_VOCES lo fuerza o 'no')."""
	forzado = os.environ.get("ORQ_VOCES", "").strip()
	if forzado:
		return "" if forzado.lower() in ("no", "0", "ninguna") else forzado
	ep = os.environ.get("RUNPOD_VOZ_ENDPOINT", "")
	return f"runpod://{ep}" if ep and str(comfy).startswith("runpod://") else ""


def flujo_sfx(comfy: str) -> str:
	"""Efectos con IA (Stable Audio 3). ORQ_SFX=ia | procedural | auto (IA cuando el arte va a RunPod)."""
	modo = os.environ.get("ORQ_SFX", "auto").strip().lower()
	if modo == "procedural" or (modo == "auto" and not str(comfy).startswith("runpod://")):
		return ""
	return str(RAIZ / "plantillas" / "runpod" / "sfx_stableaudio.json")
MAX_RONDAS_NIVELES = 8
MAX_RONDAS_BOTS = 4


class ErrorCadena(Exception):
	pass


## Quien quiera enterarse del progreso (el trabajador lo manda a la base de datos).
oyentes: list = []
## Imagenes de los fondos ilustrados, la interfaz dibujada y sus iconos (portada + piel + iconos).
from arte import iconos as _iconos, portada as _portada, skin as _skin  # noqa: E402
EXTRAS_FONDOS = len(_portada.TAMANOS) + len(_skin.TAMANOS) + len(_iconos.QUE)


def evento(paso: str, estado: str, mensaje: str, **extra: object) -> None:
	"""Progreso para la app (Chispa lo cuenta en vivo). Una linea JSON por evento."""
	d = {"paso": paso, "estado": estado, "mensaje": mensaje, "t": round(time.time(), 1)}
	d.update(extra)
	print("@@ " + json.dumps(d, ensure_ascii=False), flush=True)
	for o in oyentes:
		try:
			o(d)
		except Exception as e:  # noqa: BLE001 - un oyente roto no para la fabrica
			print(f"[cadena] oyente fallo: {e}", flush=True)
	## El servidor dio el trabajo por terminado (caducado): ni GPU ni CPU para algo que nadie recibe.
	from arte import runpod as _runpod
	if _runpod.GASTO["cancelado"]:
		raise ErrorCadena("El servidor dio este trabajo por terminado: la fabrica para aqui")


def godot_bin() -> str:
	return os.environ.get("GODOT", shutil.which("godot") or "godot")


def godot(proyecto: Path, *args: str, timeout: int = 1800, display: bool = False, xvfb: bool = False) -> subprocess.CompletedProcess:
	cmd = [godot_bin(), "--path", str(proyecto)]
	if not display:
		cmd.insert(1, "--headless")
	if display and sys.platform.startswith("linux"):
		## Con pantalla (capturas y clip) siempre X11: Godot probaba antes Wayland y, en el servidor
		## (xvfb, sin Wayland), fallaba al instante: juegos sin capturas, sin ficha y sin clip.
		cmd += ["--display-driver", "x11"]
	cmd += list(args)
	## xvfb=True: pantalla virtual propia aunque haya DISPLAY (en el servidor puede apuntar a una que no existe).
	if display and (xvfb or not os.environ.get("DISPLAY")):
		return _con_pantalla_virtual(cmd, timeout)
	return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def _con_pantalla_virtual(cmd: list, timeout: int) -> subprocess.CompletedProcess:
	"""Arranca Xvfb a mano, espera a que este listo y lanza Godot con ese DISPLAY.

	El 12 nov xvfb-run fallaba en el servidor sin decir nada ("X11 Display is not available"):
	asi, si la pantalla virtual no arranca, el aviso dice por que.
	"""
	xvfb = shutil.which("Xvfb")
	if not xvfb:
		if shutil.which("xvfb-run"):
			return subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 800x1400x24"] + cmd, capture_output=True, text=True, timeout=timeout)
		return subprocess.CompletedProcess(cmd, 1, "", "No hay Xvfb (pantalla virtual) instalado")
	os.makedirs("/tmp/.X11-unix", mode=0o1777, exist_ok=True)
	errores = []
	## 12 nov: con "+extension GLX +render" Xvfb a veces se caia al arrancar (Segmentation fault en
	## InitExtensions). Primero sin extras; si no arranca, con ellas; y al final xvfb-run.
	## Y si aun asi se cae (en algunas maquinas de RunPod Xvfb revienta al cargar GLX): Xvfb SIN GLX y
	## Godot con OpenGL ES por EGL, que no lo necesita (probado: mismas capturas).
	sin_glx = ["-extension", "GLX"]
	for extra, entorno_x in (([], {}), (["+extension", "GLX", "+render"], {}), (sin_glx, {})):
		orden = cmd
		if extra == sin_glx and "--rendering-driver" in cmd:
			k = cmd.index("--rendering-driver")
			orden = cmd[:k + 1] + ["opengl3_es"] + cmd[k + 2:]
		num = next((n for n in range(90, 140) if not os.path.exists(f"/tmp/.X11-unix/X{n}") and not os.path.exists(f"/tmp/.X{n}-lock")), 99)
		srv = subprocess.Popen([xvfb, f":{num}", "-screen", "0", "800x1400x24", "-nolisten", "tcp", "-ac", "-noreset", *extra],
			stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, env=dict(os.environ, **entorno_x))
		try:
			for _ in range(50):
				if os.path.exists(f"/tmp/.X11-unix/X{num}") or srv.poll() is not None:
					break
				time.sleep(0.1)
			if srv.poll() is not None:
				err = (srv.stderr.read() if srv.stderr else "")
				errores.append(f"Xvfb {' '.join(extra) or 'basico'} no arranco (codigo {srv.returncode}): " + err[-200:])
				continue
			env = dict(os.environ, DISPLAY=f":{num}", **entorno_x)
			env.pop("WAYLAND_DISPLAY", None)
			return subprocess.run(orden, capture_output=True, text=True, timeout=timeout, env=env)
		finally:
			if srv.poll() is None:
				srv.terminate()
				try:
					srv.wait(timeout=5)
				except subprocess.TimeoutExpired:
					srv.kill()
	if shutil.which("xvfb-run"):
		r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 800x1400x24"] + cmd, capture_output=True, text=True, timeout=timeout)
		if r.returncode == 0:
			return r
		errores.append("xvfb-run: " + (r.stderr or "")[-300:])
	return subprocess.CompletedProcess(cmd, 1, "", " | ".join(errores))


def validar_godot(proyecto: Path, solo_niveles: bool) -> dict:
	extra = ["--", "--solo-niveles"] if solo_niveles else []
	r = godot(proyecto, "res://qa/validar_juego.tscn", "--fixed-fps", "60", *extra)
	for linea in r.stdout.splitlines():
		if linea.startswith("[VALIDACION] "):
			return json.loads(linea[len("[VALIDACION] "):])
	raise ErrorCadena("El validador de Godot no respondio:\n" + (r.stdout + r.stderr)[-1500:])


def nivel_ok(n: dict, con_bot: bool) -> bool:
	ok = n["completable"] and not n["problemas"]
	return ok and (n.get("bot_completa", False) if con_bot else True)


def copiar_kit(destino: Path) -> None:
	if destino.exists():
		shutil.rmtree(destino)
	shutil.copytree(KIT, destino, ignore=shutil.ignore_patterns(".godot", "build", "assets", "*.apk", "*.idsig"))


def ajustar_proyecto(proyecto: Path, titulo: str, slug: str, version: int = 1) -> None:
	"""Nombre de la app y paquete de Android propios de este juego. El paquete no cambia nunca
	(asi cada version nueva se instala encima de la anterior); el codigo de version sube."""
	pg = proyecto / "project.godot"
	txt = pg.read_text(encoding="utf-8")
	txt = "\n".join(f'config/name="{titulo}"' if l.startswith("config/name=") else l for l in txt.splitlines()) + "\n"
	pg.write_text(txt, encoding="utf-8")
	ep = proyecto / "export_presets.cfg"
	cambios = {
		"package/unique_name": f'"com.orquestador.{slug.replace("_", "")}"',
		"package/name": f'"{titulo}"',
		"version/code": str(version),
		"version/name": f'"1.{version - 1}"',
		"export_path": f'"build/{slug}.apk"',
	}
	lineas = []
	seccion = ""
	for l in ep.read_text(encoding="utf-8").splitlines():
		if l.startswith("["):
			seccion = l
		clave = l.split("=", 1)[0]
		## 1 - Solo el preset de Android (preset.0); el Web conserva su ruta.
		propio = seccion in ("[preset.0]", "[preset.0.options]")
		lineas.append(f"{clave}={cambios[clave]}" if propio and clave in cambios else l)
	ep.write_text("\n".join(lineas) + "\n", encoding="utf-8")


def crear_icono(proyecto: Path, arte_dir: Path, game: dict) -> None:
	"""Icono del juego (icon.png 256) e iconos adaptativos de Android a medida (iconos.py).
	Si algo falla (proyecto antiguo sin preset), se queda el icono sencillo de siempre."""
	try:
		import iconos
		iconos.aplicar_a_proyecto(proyecto)
		return
	except Exception as e:  # noqa: BLE001 - el icono nunca para la fabrica
		print(f"[icono] adaptativo no disponible: {e}", file=sys.stderr)
	fichas = sorted(arte_dir.glob("heroe_ficha_*x*.png"))
	lado = 256
	fondo = bib.hex_a_rgb(game["palette"]["accent"])
	cielo = bib.hex_a_rgb(game["palette"]["sky"])
	img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.rounded_rectangle([0, 0, lado - 1, lado - 1], radius=56, fill=cielo + (255,))
	d.rounded_rectangle([14, 14, lado - 15, lado - 15], radius=46, fill=fondo + (255,))
	if fichas:
		h = Image.open(fichas[0]).convert("RGBA")
		caja = h.getbbox() or (0, 0, h.width, h.height)
		h = h.crop(caja)
		k = int(176 / max(h.width, h.height)) or 1
		h = h.resize((h.width * k, h.height * k), Image.NEAREST)
		img.alpha_composite(h, ((lado - h.width) // 2, (lado - h.height) // 2 + 6))
	img.save(proyecto / "icon.png")


def exportar_apk(proyecto: Path, slug: str) -> Path:
	"""Con ORQ_FIRMADOR (uber-apk-signer.jar) se exporta sin firmar y se firma aparte.
	Si no, Godot firma con la clave de depuracion configurada en el editor."""
	build = proyecto / "build"
	build.mkdir(exist_ok=True)
	firmador = os.environ.get("ORQ_FIRMADOR", "")
	destino = build / f"{slug}.apk"
	if firmador:
		sin_firmar = build / f"{slug}-sin-firmar.apk"
		r = godot(proyecto, "--export-release", "Android", str(sin_firmar), timeout=900)
		if not sin_firmar.exists():
			raise ErrorCadena("Fallo al exportar el APK: " + (r.stdout + r.stderr)[-800:])
		firmado = build / "firmado"
		shutil.rmtree(firmado, ignore_errors=True)
		r = subprocess.run(["java", "-jar", firmador, "-a", str(sin_firmar), "-o", str(firmado)], capture_output=True, text=True, timeout=300)
		apks = list(firmado.glob("*.apk"))
		if not apks:
			raise ErrorCadena("Fallo al firmar el APK: " + (r.stdout + r.stderr)[-800:])
		shutil.copy(apks[0], destino)
		sin_firmar.unlink(missing_ok=True)
	else:
		ep = proyecto / "export_presets.cfg"
		ep.write_text(ep.read_text(encoding="utf-8").replace("package/signed=false", "package/signed=true"), encoding="utf-8")
		r = godot(proyecto, "--export-debug", "Android", str(destino), timeout=900)
		if not destino.exists():
			raise ErrorCadena("Fallo al exportar el APK (revisa el SDK de Android y la clave de depuracion en Godot): " + (r.stdout + r.stderr)[-800:])
	return destino


def hacer_ficha(args, proyecto: Path, capturas: list) -> str | None:
	"""Ficha de Google Play (icono, grafico destacado, capturas con mensajes y textos). Necesita las capturas."""
	if not getattr(args, "ficha", False):
		return None
	if not capturas:
		evento("ficha", "aviso", "La ficha de la tienda necesita capturas; activa --capturas")
		return None
	import ficha
	evento("ficha", "inicio", "Preparando la ficha para Google Play...")
	r = ficha.generar(proyecto)
	evento("ficha", "ok", "Ficha de la tienda lista", capturas=r["capturas"])
	return r["zip"]


def hacer_clip(args, proyecto: Path) -> str | None:
	"""Clip vertical de 15 s para redes, jugado por el bot (clip.py)."""
	if not getattr(args, "clip", False):
		return None
	import clip
	evento("clip", "inicio", "Grabando un clip para TikTok, Shorts y Reels...")
	try:
		mp4 = clip.generar(proyecto)
	except clip.ErrorClip as e:
		evento("clip", "aviso", "No se pudo grabar el clip: " + str(e)[:200])
		return None
	evento("clip", "ok", "Clip vertical listo", mb=round(mp4.stat().st_size / 1e6, 1))
	return str(mp4)


def exportar_web(proyecto: Path) -> Path:
	"""Solo el paquete del juego (index.pck, ~1 MB). El motor web (wasm) es el mismo para todos
	los juegos y vive una sola vez en el bucket publico "motor" (ver subir_motor.py)."""
	destino = proyecto / "build" / "web" / "index.pck"
	destino.parent.mkdir(parents=True, exist_ok=True)
	destino.unlink(missing_ok=True)
	r = godot(proyecto, "--export-pack", "Web", str(destino), timeout=600)
	if not destino.exists():
		raise ErrorCadena("Fallo al exportar la version web: " + (r.stdout + r.stderr)[-800:])
	return destino


def escribir_game(proyecto: Path, diseno: dict, mapas: list) -> dict:
	game = director.a_game(diseno, mapas)
	## Monetizacion: el informe para el autor (perfil de su tipo de juego, que lleva y que crear).
	import monetizacion
	inf_mon = monetizacion.informe(generos.de(diseno.get("genero", "plataformas")).get("kit", ""), diseno.get("publico") == "infantil",
		str((game.get("monetization") or {}).get("profile", "")))
	(proyecto / "fabrica").mkdir(parents=True, exist_ok=True)
	(proyecto / "fabrica" / "monetizacion.json").write_text(json.dumps(inf_mon, indent=1, ensure_ascii=False), encoding="utf-8")
	## Tutorial con el tema del juego (textos del director; los pasos, del genero).
	if diseno.get("tutorial"):
		game["tutorial"] = [{"text": str(t).strip()[:120]} for t in diseno["tutorial"][:6] if str(t).strip()]
	## Datos anonimos de partida: el juego sabe a donde mandarlos (fabrica/telemetria.json) y su version.
	tel = proyecto / "fabrica" / "telemetria.json"
	if tel.exists():
		game["telemetry"] = dict(json.loads(tel.read_text(encoding="utf-8")),
			version=int(versiones.memoria(proyecto).get("version", 0)) + 1)
	## Enlace para los retos entre amigos (la ficha de la tienda, cuando el juego se publica).
	## Promocion cruzada: los otros juegos del mismo autor (los pone el trabajador en cruzada.json).
	cruzada = proyecto / "fabrica" / "cruzada.json"
	if cruzada.exists():
		game["cross"] = [g for g in json.loads(cruzada.read_text(encoding="utf-8")) if str(g.get("url", "")).startswith("https://")][:6]
	enlace = proyecto / "fabrica" / "compartir.json"
	if enlace.exists():
		game["share_url"] = json.loads(enlace.read_text(encoding="utf-8")).get("url", "")
	## Mods del agente programador: los que haya en mods/ (sobreviven a los cambios del taller).
	## Idiomas: interfaz traducida siempre; lo propio del juego, con la IA (y guardado para no repetir).
	## Reto del dia con niveles nuevos (niveles_reto), si los hay.
	reto = proyecto / "fabrica" / "reto.json"
	if reto.exists():
		game["daily_levels"] = json.loads(reto.read_text(encoding="utf-8"))
	muestra = proyecto / "fabrica" / "muestra.json"
	if muestra.exists():
		game["muestra"] = str(json.loads(muestra.read_text(encoding="utf-8")).get("nombre", ""))[:40]
	game["lang"] = "es"
	## Idiomas extra (japones, arabe...): los de la idea o el taller, ademas de los 6 de siempre.
	if diseno.get("idiomas"):
		game["langs"] = list(diseno["idiomas"])
	game["i18n"] = traducir.i18n(game, proyecto / "fabrica" / "traducciones.json", llm.Gasto())
	## Mods y reglas: un archivo de mods/ es regla si hereda de rule_base.gd (cambia la mecanica).
	archivos = sorted((proyecto / "mods").glob("*.gd")) if (proyecto / "mods").exists() else []
	reglas = [f"res://mods/{m.name}" for m in archivos if m.read_text(encoding="utf-8").startswith('extends "res://kit/rule_base.gd"')]
	mods = [f"res://mods/{m.name}" for m in archivos if f"res://mods/{m.name}" not in reglas]
	if mods:
		game["mods"] = mods
	if reglas:
		game["rules"] = reglas
	(proyecto / "game.json").write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")
	return game


def fijar_enlace(proyecto: Path, url: str) -> None:
	"""Guarda el enlace de los retos y lo pone ya en game.json (lo usa kit/online.gd)."""
	(proyecto / "fabrica").mkdir(parents=True, exist_ok=True)
	(proyecto / "fabrica" / "compartir.json").write_text(json.dumps({"url": url}), encoding="utf-8")
	gp = proyecto / "game.json"
	if gp.exists():
		game = json.loads(gp.read_text(encoding="utf-8"))
		game["share_url"] = url
		gp.write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")


def configurar_telemetria(proyecto: Path, juego_id: str) -> bool:
	"""Apunta a donde manda el juego sus datos anonimos (Supabase del trabajador, clave publica anon).
	Sin ORQ_TELEMETRIA_URL / ORQ_TELEMETRIA_CLAVE el juego no envia nada."""
	url = os.environ.get("ORQ_TELEMETRIA_URL", "")
	clave = os.environ.get("ORQ_TELEMETRIA_CLAVE", "")
	if not (url and clave and juego_id):
		return False
	(proyecto / "fabrica").mkdir(parents=True, exist_ok=True)
	(proyecto / "fabrica" / "telemetria.json").write_text(json.dumps({"url": url, "key": clave, "game": juego_id}), encoding="utf-8")
	return True


## Lo que dice el analizador, en palabras de la persona (niveles hechos a mano).
PROBLEMAS_NIVEL = {
	"goal_unreachable": "el héroe no puede llegar a la meta",
	"no_goal": "falta la meta", "no_spawn": "falta el punto de salida del héroe",
	"spawn_falls_out": "el héroe empieza en el aire y se cae",
	"coins_unreachable": "hay monedas a las que no se puede llegar",
	"enemy_floating": "hay un enemigo que anda flotando (ponle suelo debajo)",
	"enemy_near_spawn": "hay un enemigo demasiado cerca de la salida",
	"enemy_unavoidable": "hay un enemigo imposible de esquivar",
	"boss_arena_small": "el jefe necesita una zona más ancha para pelear",
	"runner_wall": "hay un muro demasiado alto para saltarlo corriendo",
	"runner_boss": "en un runner no puede haber jefe",
	"runner_moving_platform": "en un runner no puede haber plataformas móviles",
	"flap_gap_small": "hay un hueco demasiado estrecho para pasar volando",
	"flap_gap_jump": "hay un cambio de altura demasiado brusco entre huecos",
	"breakout_unreachable": "hay ladrillos a los que la pelota no puede llegar",
	"breakout_few_bricks": "hacen falta al menos 12 ladrillos que se rompan",
	"breakout_steel_wall": "una fila entera de acero lo encierra todo",
	"brawl_player": "tiene que haber una sola salida tuya (P)",
	"brawl_rivals": "hacen falta de 1 a 6 rivales (R)",
	"brawl_rival_close": "hay un rival que sale demasiado cerca de ti",
	"brawl_unreachable": "hay un rival encerrado al que no se puede llegar",
	"brawl_box_closed": "hay una caja encerrada entre muros",
	"brawl_cramped": "la arena tiene demasiados muros (deja más suelo libre)",
	"brawl_size": "la arena tiene que medir de 9 a 25 de ancho y de 11 a 31 de alto",
	"village_hall": "tiene que haber un solo ayuntamiento (H)",
	"village_no_defense": "la base necesita al menos una defensa (C, A u O)",
	"village_overlap": "hay edificios encima de otros (cada uno ocupa su cuadrado)",
	"village_outside": "hay un edificio que se sale del mapa",
	"village_no_room": "deja libre el borde de la base para soltar las tropas",
	"village_small_army": "el ejército necesita al menos 5 tropas",
	"village_size": "la base tiene que medir de 14 a 24 casillas",
	"bot": "el robot de pruebas no consigue pasarlo: hazlo un poco más fácil",
}


def explicar_nivel(n: dict) -> str:
	partes = [PROBLEMAS_NIVEL.get(str(p).split(":")[0], str(p)) for p in n.get("problemas", [])]
	if not n.get("completable", True) and PROBLEMAS_NIVEL["goal_unreachable"] not in partes:
		partes.insert(0, PROBLEMAS_NIVEL["goal_unreachable"])
	if not partes:
		partes.append(PROBLEMAS_NIVEL["bot"])
	return "; ".join(dict.fromkeys(partes))


def _fijos_malos(val: dict, fijos: set[int], con_bot: bool) -> None:
	"""Un nivel hecho a mano no se rehace: si no vale, se le explica a la persona por que."""
	for n in val["niveles"]:
		if n["nivel"] in fijos and not nivel_ok(n, con_bot):
			raise ErrorCadena(f"Tu nivel {n['nivel'] + 1} no se puede jugar: {explicar_nivel(n)}. No se ha cobrado nada.")


def analizar_niveles(proyecto: Path, diseno: dict, mapas: list, semilla: int, intentos: dict[int, int],
		ajustes: dict[int, float] | None = None, fijos: set[int] | None = None) -> list:
	"""Analizador de Godot (rapido): los niveles que no pasan se regeneran con otra semilla."""
	fijos = fijos or set()
	for ronda in range(MAX_RONDAS_NIVELES):
		escribir_game(proyecto, diseno, mapas)
		val = validar_godot(proyecto, solo_niveles=True)
		_fijos_malos(val, fijos, False)
		malos = [n["nivel"] for n in val["niveles"] if not nivel_ok(n, False)]
		if not malos:
			return mapas
		if ronda == MAX_RONDAS_NIVELES - 1:
			raise ErrorCadena(f"Niveles sin arreglar tras {MAX_RONDAS_NIVELES} rondas: {malos}")
		for i in malos:
			intentos[i] = intentos.get(i, 0) + 1
		mapas = director.generar_niveles(diseno, semilla, {i: intentos[i] for i in malos}, mapas, ajustes)
	return mapas


def _quitar_giros(proyecto: Path, diseno: dict, semilla: int, intentos: dict[int, int], problema: str) -> list:
	"""Aprender de un error: apunta que el giro fallo en este genero, lo quita del diseno y rehace
	los niveles sin el. Devuelve los mapas nuevos ya pasados por el analizador."""
	quitados = list(diseno.get("giros") or [])
	giros.anotar(diseno.get("genero", "plataformas"), quitados, False, problema)
	evento("giros", "aviso", f"El giro {', '.join(quitados)} no encajaba en este juego: lo quito y sigo")
	diseno.pop("giros", None)
	(proyecto / "fabrica" / "diseno.json").write_text(json.dumps(diseno, indent=1, ensure_ascii=False), encoding="utf-8")
	intentos.clear()
	mapas = director.generar_niveles(diseno, semilla + 7)
	return analizar_niveles(proyecto, diseno, mapas, semilla + 7, intentos)


def _quitar_contenido(proyecto: Path, diseno: dict, semilla: int, intentos: dict[int, int], problema: str) -> list:
	"""El contenido inventado por la IA no deja niveles justos: se apunta la leccion, se quita y se
	rehacen los niveles con el estilo probado."""
	contenido.anotar(diseno.get("genero", ""), False, problema)
	evento("contenido", "aviso", "Lo que invente para este juego no salia justo: uso el estilo probado")
	diseno.pop("contenido", None)
	(proyecto / "fabrica" / "diseno.json").write_text(json.dumps(diseno, indent=1, ensure_ascii=False), encoding="utf-8")
	intentos.clear()
	mapas = director.generar_niveles(diseno, semilla + 11)
	return analizar_niveles(proyecto, diseno, mapas, semilla + 11, intentos)


def _rescatar(proyecto: Path, diseno: dict, semilla: int, intentos: dict[int, int], problema: str) -> list:
	"""Niveles que no salen: primero fuera el contenido inventado, despues los giros."""
	if diseno.get("contenido"):
		try:
			return _quitar_contenido(proyecto, diseno, semilla, intentos, problema)
		except ErrorCadena as e:
			problema = str(e)
	if diseno.get("giros"):
		return _quitar_giros(proyecto, diseno, semilla, intentos, problema)
	raise ErrorCadena(problema)


def limites_contrarreloj(proyecto: Path, diseno: dict, val: dict) -> None:
	"""Giro contrarreloj: el tiempo de cada nivel sale de lo que tardo el bot (x3 + 10 s)."""
	if "contrarreloj" not in (diseno.get("giros") or []):
		return
	gp = proyecto / "game.json"
	game = json.loads(gp.read_text(encoding="utf-8"))
	for n in val.get("niveles", []):
		i = int(n.get("nivel", -1))
		if 0 <= i < len(game["levels"]) and n.get("bot_segundos") is not None:
			game["levels"][i]["time_limit"] = float(math.ceil(float(n["bot_segundos"]) * 3.0 + 10.0))
	gp.write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")


def validar_con_bots(proyecto: Path, diseno: dict, mapas: list, semilla: int, intentos: dict[int, int],
		ajustes: dict[int, float] | None = None, fijos: set[int] | None = None) -> tuple[dict, list]:
	"""Bots jugando cada nivel + arte + interfaz. Lo que el bot no supera se rehace y se repite."""
	val: dict = {}
	fijos = fijos or set()
	for _ in range(MAX_RONDAS_BOTS):
		escribir_game(proyecto, diseno, mapas)
		val = validar_godot(proyecto, solo_niveles=False)
		_fijos_malos(val, fijos, True)
		malos = [n["nivel"] for n in val["niveles"] if not nivel_ok(n, True)]
		if val["ok"] or not malos:
			break
		evento("validacion", "aviso", f"Rehaciendo niveles que el bot no supera: {[m + 1 for m in malos]}")
		for i in malos:
			intentos[i] = intentos.get(i, 0) + 1
		mapas = director.generar_niveles(diseno, semilla, {i: intentos[i] for i in malos}, mapas, ajustes)
		mapas = analizar_niveles(proyecto, diseno, mapas, semilla, intentos, ajustes, fijos)
	## Un texto un poco largo (rotulo de 120 px en 112) no tumba un juego que los bots ya superan:
	## se entrega con aviso. Botones diminutos o fuera de la pantalla siguen siendo un fallo.
	if not val.get("ok") and texto_cortado_solo(val):
		evento("validacion", "aviso", "Textos algo largos en la interfaz: " + "; ".join(val.get("interfaz", []))[:200])
		val["ok"] = True
	if val.get("ok"):
		limites_contrarreloj(proyecto, diseno, val)
	return val, mapas


def texto_cortado_solo(val: dict) -> bool:
	"""Pura: el unico problema es algun texto cortado (niveles, arte y QA bien)."""
	interfaz = [str(x) for x in val.get("interfaz") or []]
	arte = val.get("arte") or {}
	return (bool(interfaz) and all("texto cortado" in x for x in interfaz)
		and all(nivel_ok(n, True) for n in val.get("niveles") or [])
		and not val.get("fallos_qa") and all(v for k, v in arte.items() if k != "sonidos_que_faltan")
		and not arte.get("sonidos_que_faltan"))


## Reto del dia: niveles nuevos (mas dificiles que el principio de la campana) para cuando el
## jugador ya ha pasado el primero. Uno distinto cada dia (kit/twist.gd).
RETO_NIVELES = 7


def niveles_reto(proyecto: Path, diseno: dict, semilla: int) -> int:
	"""Genera RETO_NIVELES niveles extra, los juega con los bots (mismo validador que la campana) y
	guarda en fabrica/reto.json solo los que superan. Devuelve cuantos quedan (0 si no hay reto)."""
	ruta = proyecto / "fabrica" / "reto.json"
	game_p = proyecto / "game.json"
	original = game_p.read_text(encoding="utf-8")
	d2 = dict(diseno)
	d2.pop("prueba_ab", None)
	base = list(diseno.get("niveles") or [])
	if not base:
		return 0
	## Uno de mas: el primero de cada genero suele ser especial (tutorial, tablero liso) y se tira.
	d2["niveles"] = [copy.deepcopy(base[(len(base) // 3 + k) % len(base)]) for k in range(RETO_NIVELES + 1)]
	try:
		mapas = director.generar_niveles(d2, semilla + 7777, ajustes={i: 0.2 for i in range(RETO_NIVELES + 1)})
		campana = [{k: v for k, v in lv.items() if k != "name"} for lv in json.loads(original).get("levels", [])]
		niveles = [lv for lv in director.a_game(d2, mapas)["levels"][1:] if {k: v for k, v in lv.items() if k != "name"} not in campana]
		prueba = json.loads(original)
		prueba["levels"] = niveles
		prueba.pop("ab", None)
		prueba.pop("daily_levels", None)
		game_p.write_text(json.dumps(prueba, indent=1, ensure_ascii=False), encoding="utf-8")
		val = validar_godot(proyecto, solo_niveles=False)
		buenos = []
		for nv in val.get("niveles", []):
			if nivel_ok(nv, True) and 0 <= int(nv["nivel"]) < len(niveles):
				lv = niveles[nv["nivel"]]
				## Giro contrarreloj: su tiempo, como en la campana (lo que tardo el bot x3 + 10 s).
				if "contrarreloj" in (diseno.get("giros") or []) and nv.get("bot_segundos") is not None:
					lv["time_limit"] = float(math.ceil(float(nv["bot_segundos"]) * 3.0 + 10.0))
				buenos.append(lv)
	finally:
		game_p.write_text(original, encoding="utf-8")
	for lv in buenos:
		lv.pop("variant_b", None)
	if len(buenos) >= 3:
		ruta.write_text(json.dumps(buenos, indent=1, ensure_ascii=False), encoding="utf-8")
	elif ruta.exists():
		ruta.unlink()
	return len(buenos) if len(buenos) >= 3 else 0


def poner_reto(proyecto: Path) -> None:
	"""Pone (o quita) los niveles del reto en el game.json ya validado, sin rehacerlo (asi no se
	pierde nada de lo que se ajusto despues de los bots, como el tiempo del contrarreloj)."""
	gp = proyecto / "game.json"
	game = json.loads(gp.read_text(encoding="utf-8"))
	reto = proyecto / "fabrica" / "reto.json"
	if reto.exists():
		game["daily_levels"] = json.loads(reto.read_text(encoding="utf-8"))
	else:
		game.pop("daily_levels", None)
	gp.write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")


## Cache del arte: el arte (lo caro: GPU) se guarda con una clave que sale de la biblia. Si el juego
## falla despues de dibujar y se reintenta con el mismo diseno, se recupera en vez de volver a pagarlo.
ARTE_VERSION = "1"


def clave_arte(biblia: dict, lado: int, fondos: bool) -> str:
	import hashlib
	base = json.dumps(biblia, sort_keys=True, ensure_ascii=False) + f"|{lado}|{int(bool(fondos))}|{ARTE_VERSION}"
	return hashlib.sha256(base.encode("utf-8")).hexdigest()[:32]


def empaquetar_arte(proyecto: Path, destino: Path) -> Path:
	"""assets/ (lo que lee Godot) + fabrica/arte/ (fichas, informe, musica, voces, fondos)."""
	import zipfile
	with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED) as z:
		for carpeta in (proyecto / "assets", proyecto / "fabrica" / "arte"):
			for f in sorted(carpeta.rglob("*")):
				if f.is_file() and not f.name.endswith(".import"):
					z.write(f, f.relative_to(proyecto).as_posix())
	return destino


def restaurar_arte(zipf: Path, proyecto: Path) -> dict:
	import zipfile
	with zipfile.ZipFile(zipf) as z:
		for n in z.namelist():
			if not (n.startswith("assets/") or n.startswith("fabrica/arte/")) or ".." in n:
				raise ErrorCadena(f"Cache de arte rara: {n}")
		z.extractall(proyecto)
	return json.loads((proyecto / "fabrica" / "arte" / "informe.json").read_text(encoding="utf-8"))


def disenar_previa(idea: str, simulado: bool, gasto: "llm.Gasto") -> tuple[dict, str]:
	"""Vista previa gratis: solo el diseno (con su toque de originalidad), sin niveles ni arte.
	Luego fabricar() lo usa tal cual si el jugador lo aprueba (args.diseno)."""
	diseno, modelo = director.disenar(idea, simulado, gasto)
	if not simulado or os.environ.get("ORQ_ORIGINALIDAD") == "1":
		originalidad.diferenciar(diseno, fijo="[gancho:" in idea)
	return diseno, modelo


def fabricar(args: argparse.Namespace) -> dict:
	t0 = time.time()
	tiempos: dict[str, float] = {}
	gasto = getattr(args, "gasto", None) or llm.Gasto()
	informe: dict = {"idea": args.idea, "ok": False}

	def cronometro(paso: str, desde: float) -> None:
		tiempos[paso] = round(time.time() - desde, 1)

	## 1 - Diseno
	t = time.time()
	previa = getattr(args, "diseno", None)
	if previa:
		## Vista previa ya aprobada por el jugador: se fabrica ESE diseno, sin volver a pensarlo.
		evento("diseno", "inicio", "Usando el diseño que aprobaste...")
		diseno, modelo = copy.deepcopy(previa), "vista_previa"
	else:
		evento("diseno", "inicio", "Pensando tu juego...")
		diseno, modelo = director.disenar(args.idea, args.simulado, gasto)
	slug = director.slug(diseno)
	cronometro("diseno", t)
	genero = generos.de(diseno)["etiqueta"]
	rival = "" if not generos.de(diseno)["enemigos"] and diseno.get("genero") != "carreras" else f" contra {len(diseno['enemigos'])} tipos de enemigo"
	evento("diseno", "ok", f"«{diseno['titulo']}» ({genero}): {diseno['heroe']['nombre']}{rival}",
		titulo=diseno["titulo"], modelo=modelo, usd=gasto.usd)
	## Que no sea un copia y pega de otro juego de la fabrica (con la directora simulada, la de las
	## pruebas, solo si se pide: asi las pruebas no dependen de lo fabricado antes).
	activa = not args.simulado or os.environ.get("ORQ_ORIGINALIDAD") == "1"
	## La vista previa ya paso por aqui (diseno["originalidad"]): no se le cambia nada a lo aprobado.
	ya = previa and "originalidad" in diseno
	dif = originalidad.diferenciar(diseno, fijo="[gancho:" in args.idea) if activa and not ya else {"mensaje": ""}
	if dif["mensaje"]:
		evento("originalidad", "ok", dif["mensaje"], indice=dif["indice"])

	## 2 - Proyecto
	t = time.time()
	proyecto = Path(args.salida).resolve() / slug
	copiar_kit(proyecto)
	if getattr(args, "cruzada", None):
		(proyecto / "fabrica").mkdir(exist_ok=True)
		(proyecto / "fabrica" / "cruzada.json").write_text(json.dumps(args.cruzada, ensure_ascii=False), encoding="utf-8")
	if getattr(args, "muestra", None):
		## Partida de muestra para «Probar» en el taller (muestras.py): empieza a jugar sola.
		(proyecto / "fabrica").mkdir(exist_ok=True)
		(proyecto / "fabrica" / "muestra.json").write_text(json.dumps({"nombre": args.muestra}, ensure_ascii=False), encoding="utf-8")
	biblia = director.a_biblia(diseno)
	## Limite de imagenes por juego (la GPU se paga por imagen): ORQ_MAX_IMAGENES, 36 por defecto.
	## Juego ligero (canario de prueba): los menos dibujos posibles y sin fondos ilustrados.
	ligero = bool(getattr(args, "ligero", False))
	fondos = not ligero and (str(args.comfy).startswith("runpod://") or os.environ.get("ORQ_FONDOS") == "1")
	maximo = 10 if ligero else int(os.environ.get("ORQ_MAX_IMAGENES") or "36")
	ahorradas = bib.recortar(biblia, maximo, EXTRAS_FONDOS if fondos else 0)
	if ahorradas:
		print(f"[cadena] {ahorradas} imagenes menos para no pasar del limite ({bib.imagenes(biblia, EXTRAS_FONDOS if fondos else 0)})", flush=True)
	bib.validar(biblia)
	(proyecto / "fabrica").mkdir(exist_ok=True)
	(proyecto / "fabrica" / "diseno.json").write_text(json.dumps(diseno, indent=1, ensure_ascii=False), encoding="utf-8")
	ruta_biblia = proyecto / "fabrica" / "biblia.json"
	ruta_biblia.write_text(json.dumps(biblia, indent=1, ensure_ascii=False), encoding="utf-8")
	ajustar_proyecto(proyecto, diseno["titulo"], slug)
	cronometro("proyecto", t)
	evento("proyecto", "ok", "Proyecto creado", carpeta=str(proyecto))

	## 2b - Genero hecho a medida (capa 3): Claude programa las reglas de ESTE juego y se prueban.
	if diseno.get("genero") == "a_medida":
		t = time.time()
		import genero_usuario
		evento("a_medida", "inicio", "Programando un género nuevo solo para tu juego...")
		r_am = genero_usuario.crear(proyecto, diseno, args.semilla, args.simulado, gasto)
		(proyecto / "fabrica" / "diseno.json").write_text(json.dumps(diseno, indent=1, ensure_ascii=False), encoding="utf-8")
		cronometro("a_medida", t)
		if r_am["ok"]:
			evento("a_medida", "ok", "Género nuevo listo y superado por el bot" + (": " + r_am["notas"] if r_am.get("notas") else ""), rondas=r_am["rondas"])
		else:
			evento("a_medida", "aviso", "No salió a la primera: tu juego usa la plantilla probada y puedes pedir cambios en el taller", rondas=r_am["rondas"])

	## 3 - Niveles (analizador)
	t = time.time()
	evento("niveles", "inicio", f"Construyendo {len(diseno['niveles'])} niveles...")
	mapas = director.generar_niveles(diseno, args.semilla)
	intentos: dict[int, int] = {}
	configurar_telemetria(proyecto, getattr(args, "telemetria_id", ""))
	game = escribir_game(proyecto, diseno, mapas)
	godot(proyecto, "--import", timeout=600)
	antes = sum(intentos.values())
	try:
		mapas = analizar_niveles(proyecto, diseno, mapas, args.semilla, intentos)
	except ErrorCadena as e:
		## Contenido propio o giro que no deja hacer niveles justos: se quita, se apunta la leccion y se sigue.
		if not diseno.get("giros") and not diseno.get("contenido"):
			raise
		mapas = _rescatar(proyecto, diseno, args.semilla, intentos, str(e))
	regenerados = sum(intentos.values()) - antes
	cronometro("niveles", t)
	evento("niveles", "ok", f"Niveles listos ({regenerados} rehechos por el analizador)", regenerados=regenerados)

	## 3b - Boceto jugable: con el arte provisional del kit, para jugar mientras se dibuja el de verdad.
	subir_boceto = getattr(args, "boceto", None)
	ruta_boceto = None
	if getattr(args, "web", False) and callable(subir_boceto):
		t = time.time()
		try:
			pck = proyecto / "build" / "boceto" / "index.pck"
			pck.parent.mkdir(parents=True, exist_ok=True)
			godot(proyecto, "--export-pack", "Web", str(pck), timeout=300)
			if pck.exists():
				ruta = ruta_boceto = subir_boceto(pck)
				evento("boceto", "ok", "¡Ya puedes jugar un boceto mientras dibujo el arte!", boceto=ruta)
		except Exception as e:  # noqa: BLE001 - el boceto es un extra: si falla, se sigue sin el
			evento("boceto", "aviso", f"Sin boceto esta vez ({str(e)[:80]})")
		cronometro("boceto", t)
	## Vista previa jugable (gratis): hasta aqui. Diseno + niveles + boceto, sin tarjeta grafica.
	if getattr(args, "solo_boceto", False):
		return {"solo_boceto": True, "diseno": diseno, "boceto": ruta_boceto, "titulo": diseno.get("titulo"),
			"coste_usd": round(gasto.usd, 4), "tiempos": tiempos}

	## 3c - Fallar barato: los bots juegan YA, con el arte provisional del kit. Si el juego no se puede
	## superar se arregla (o se para) ANTES de pagar la tarjeta grafica, que es lo caro.
	if os.environ.get("ORQ_BOTS_ANTES", "1") == "1":
		t = time.time()
		evento("prueba_bots", "inicio", "Comprobando que se puede jugar antes de dibujar...")
		val0, mapas = validar_con_bots(proyecto, diseno, mapas, args.semilla, intentos)
		malos0 = [n for n in val0.get("niveles", []) if not nivel_ok(n, True)]
		if malos0 and (diseno.get("giros") or diseno.get("contenido")):
			mapas = _rescatar(proyecto, diseno, args.semilla, intentos, "los bots no lo superan: " + json.dumps(malos0, ensure_ascii=False)[:200])
			val0, mapas = validar_con_bots(proyecto, diseno, mapas, args.semilla, intentos)
			malos0 = [n for n in val0.get("niveles", []) if not nivel_ok(n, True)]
		cronometro("bots_antes", t)
		if malos0:
			raise ErrorCadena("Los bots no pueden superar el juego ni rehaciendo niveles (parado antes de dibujar: sin gasto de arte): "
				+ json.dumps(malos0, ensure_ascii=False)[:600])
		evento("prueba_bots", "ok", "Se puede jugar de principio a fin")

	## 4 - Arte y sonido
	t = time.time()
	evento("arte", "inicio", "Dibujando personajes, objetos y escenario...")
	srv = None
	comfy = args.comfy
	crear, editar = args.crear, args.editar
	if args.arte_simulado:
		from pruebas import comfy_simulado
		puerto = 8200 + os.getpid() % 500
		srv = comfy_simulado.arrancar(puerto)
		comfy = f"http://127.0.0.1:{puerto}"
		crear = str(RAIZ / "plantillas" / "simulado_crear.json")
		editar = str(RAIZ / "plantillas" / "simulado_editar.json")
	arte_dir = proyecto / "fabrica" / "arte"
	cache = getattr(args, "cache_arte", None)
	clave = clave_arte(biblia, args.lado, fondos)
	informe["clave_arte"] = clave
	inf_arte = None
	if cache is not None:
		try:
			zc = Path(args.salida).resolve() / f"arte_{clave}.zip"
			if cache.bajar(clave, zc):
				inf_arte = restaurar_arte(zc, proyecto)
				## Ya estaba pagado: este juego no vuelve a gastar GPU en el arte.
				inf_arte.update({"usd": 0.0, "desde_cache": True, "avisos": list(inf_arte.get("avisos") or [])})
				evento("arte", "aviso", "Recupero el arte que ya estaba dibujado para este diseño (no se vuelve a pagar)")
		except Exception as e:  # noqa: BLE001 - sin cache se dibuja como siempre
			print(f"[cadena] cache de arte no disponible: {e}", flush=True)
			inf_arte = None
	try:
		if inf_arte is None:
			inf_arte = arte_cli.fabricar(argparse.Namespace(
				biblia=str(ruta_biblia), comfy=comfy, crear=crear, editar=editar,
				salida=str(arte_dir), godot=str(proyecto), lado=args.lado, musica=flujo_musica(comfy), sfx=flujo_sfx(comfy), voces=destino_voces(comfy),
				fondos=fondos,
				revision=gasto if (not args.simulado and not args.arte_simulado and llm.clave()) else None))
			if cache is not None:
				## Guardado por si algo falla despues: un reintento con este diseno no vuelve a pagar el arte.
				try:
					cache.subir(clave, empaquetar_arte(proyecto, Path(args.salida).resolve() / f"arte_{clave}.zip"))
				except Exception as e:  # noqa: BLE001
					print(f"[cadena] no se pudo guardar la cache de arte: {e}", flush=True)
	finally:
		if srv is not None:
			srv.shutdown()
	cronometro("arte", t)
	if args.arte_simulado or inf_arte.get("desde_cache"):
		usd_arte = 0.0
	elif inf_arte.get("motor") == "runpod":
		usd_arte = round(float(inf_arte.get("usd", 0.0)), 4)
	else:
		usd_arte = round(inf_arte["generaciones"] * USD_POR_IMAGEN, 4)
	musica_txt = " y música compuesta con IA" if inf_arte.get("musica_ia") else ""
	if inf_arte.get("sfx_ia", {}).get("efectos"):
		musica_txt += ", efectos de sonido con IA"
	evento("arte", "ok", f"Arte listo: {inf_arte['generaciones']} imagenes ({inf_arte['regeneradas']} rehechas por el control de calidad){musica_txt}",
		imagenes=inf_arte["generaciones"], avisos=inf_arte["avisos"], usd=usd_arte,
		## Para medir el coste real (el diagnostico los ensena): GPU, arranques en frio y s por imagen.
		gpu_s=inf_arte.get("segundos_gpu"), arranque_s=inf_arte.get("segundos_arranque"), seg_img=inf_arte.get("seg_por_imagen"),
		tope=bool(inf_arte.get("tope_gpu")))

	## 5 - Icono
	crear_icono(proyecto, arte_dir, game)
	evento("icono", "ok", "Icono creado")

	## 6 - Validacion con bots (y regeneracion de lo que no completan)
	t = time.time()
	evento("validacion", "inicio", "Probando el juego con bots...")
	godot(proyecto, "--import", timeout=600)
	val, mapas = validar_con_bots(proyecto, diseno, mapas, args.semilla, intentos)
	if not val.get("ok") and (diseno.get("giros") or diseno.get("contenido")):
		## Con el giro o el contenido propio los bots no pueden: fuera (nunca se entrega un juego roto).
		problema = json.dumps([n for n in val.get("niveles", []) if not nivel_ok(n, True)], ensure_ascii=False)[:200]
		mapas = _rescatar(proyecto, diseno, args.semilla, intentos, "los bots no lo superan: " + problema)
		val, mapas = validar_con_bots(proyecto, diseno, mapas, args.semilla, intentos)
	elif val.get("ok") and diseno.get("giros"):
		giros.anotar(diseno.get("genero", "plataformas"), diseno["giros"], True)
	if val.get("ok") and diseno.get("contenido"):
		contenido.anotar(diseno.get("genero", ""), True)
	if val.get("ok") and activa:
		originalidad.anotar(diseno)
	game = director.a_game(diseno, mapas)
	cronometro("validacion", t)
	if not val.get("ok"):
		informe.update({"validacion": val, "tiempos": tiempos})
		(proyecto / "fabrica" / "informe.json").write_text(json.dumps(informe, indent=1, ensure_ascii=False), encoding="utf-8")
		raise ErrorCadena("El juego no supera la validacion: " + json.dumps(
			{"interfaz": val.get("interfaz"), "arte": val.get("arte"), "fallos": val.get("fallos_qa"),
			"niveles": [n for n in val.get("niveles", []) if not nivel_ok(n, True)]}, ensure_ascii=False)[:1500])
	evento("validacion", "ok", "Los bots han superado todos los niveles",
		niveles=[{k: n.get(k) for k in ("nivel", "bot_muertes", "bot_monedas", "bot_pisotones", "bot_segundos")} for n in val["niveles"]])

	## 6b - Reto del dia: niveles nuevos para cuando se acaba la campana (un extra: si falla, se sigue).
	if not getattr(args, "muestra", None):
		t = time.time()
		try:
			n_reto = niveles_reto(proyecto, diseno, args.semilla)
			poner_reto(proyecto)
			if n_reto:
				evento("reto", "ok", f"Reto del día: {n_reto} niveles nuevos probados por los bots", niveles=n_reto)
		except Exception as e:  # noqa: BLE001 - el reto es un extra
			evento("reto", "aviso", f"Sin reto del día esta vez ({str(e)[:80]})")
		cronometro("reto", t)

	## 7 - APK
	apk = None
	if args.apk:
		t = time.time()
		evento("apk", "inicio", "Empaquetando para Android...")
		apk = exportar_apk(proyecto, slug)
		cronometro("apk", t)
		evento("apk", "ok", "APK lista", ruta=str(apk), mb=round(apk.stat().st_size / 1e6, 1))

	## 7b - Version web para jugar dentro de la app
	web = None
	if getattr(args, "web", False):
		t = time.time()
		evento("web", "inicio", "Preparando la versión para jugar al instante...")
		web = exportar_web(proyecto)
		cronometro("web", t)
		evento("web", "ok", "Lista para jugar en la app", mb=round(web.stat().st_size / 1e6, 1))

	## 8 - Capturas
	capturas = []
	if args.capturas:
		t = time.time()
		out = proyecto / "fabrica" / "capturas"
		## Las capturas son para la galeria: si tardan demasiado (3D sin tarjeta grafica) se usan las
		## que hayan salido y el juego se entrega igual.
		salida = ""
		## Si no sale ninguna, otra vez con pantalla virtual propia (el 11 nov salian 0 en 0,6 s en el servidor).
		for intento in (False, True):
			try:
				r = godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--fixed-fps", "60",
					"res://qa/capturas.tscn", "--", f"--out={out}", timeout=540, display=True, xvfb=intento)
				todo = r.stdout + r.stderr
				salida = todo if len(todo) <= 900 else todo[:450] + " [...] " + todo[-450:]
			except subprocess.TimeoutExpired:
				evento("capturas", "aviso", "Las capturas tardan demasiado: me quedo con las que han salido")
			except OSError as e:
				salida = str(e)
			if any(out.glob("*.png")):
				break
		capturas = sorted(str(p) for p in out.glob("*.png"))
		cronometro("capturas", t)
		evento("capturas", "ok" if capturas else "aviso", f"{len(capturas)} capturas" + ("" if capturas else ": " + salida.replace("\n", " / ")), rutas=capturas)
	## 8b - Critica visual: la IA mira las capturas reales y pone nota. No frena la entrega; queda en el
	## informe, en el progreso y en el aprendizaje (lo que se repite es lo siguiente que hay que arreglar).
	critica_v = None
	if capturas and not args.simulado and not args.arte_simulado:
		from arte import critica
		critica_v = critica.criticar(capturas, diseno["titulo"], str(diseno.get("genero", "")), gasto)
		if critica_v:
			evento("critica", "ok" if critica_v["nota"] >= 7 else "aviso", critica.resumen(critica_v), nota=critica_v["nota"])
	ficha_zip = hacer_ficha(args, proyecto, capturas)
	clip_mp4 = hacer_clip(args, proyecto)
	marketing = None
	if getattr(args, "marketing", False):
		from marketing import estudio
		marketing = estudio.generar(proyecto, args.simulado, gasto)["zip"]

	import aprendizaje
	aprendizaje.anotar_fabricacion(diseno, intentos, val.get("niveles", []))
	version = versiones.anotar(proyecto, args.idea, f"Primera versión: «{diseno['titulo']}»", [], 0,
		{"usd": round(gasto.usd + usd_arte, 4)})
	informe.update({
		"ok": True, "version": version, "titulo": diseno["titulo"], "slug": slug, "proyecto": str(proyecto),
		"apk": str(apk) if apk else None, "web": str(web) if web else None, "capturas": capturas, "ficha": ficha_zip, "clip": clip_mp4, "marketing": marketing, "modelo_diseno": modelo,
		"coste_usd": {"diseno": gasto.usd, "arte_estimado": usd_arte, "total": round(gasto.usd + usd_arte, 4)},
		"llamadas_ia": gasto.llamadas, "imagenes": inf_arte["generaciones"], "niveles_rehechos": sum(intentos.values()),
		"tiempos_s": tiempos, "total_s": round(time.time() - t0, 1),
		"validacion": {"niveles": val["niveles"], "interfaz": val["interfaz"], "arte": val["arte"]},
		"critica_visual": critica_v,
	})
	(proyecto / "fabrica" / "informe.json").write_text(json.dumps(informe, indent=1, ensure_ascii=False), encoding="utf-8")
	evento("fin", "ok", f"«{diseno['titulo']}» esta listo", total_s=informe["total_s"], usd=informe["coste_usd"]["total"])
	return informe


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Orquestador: de una idea a un juego validado")
	p.add_argument("idea")
	p.add_argument("--salida", default=str(RAIZ.parent / "proyectos"))
	p.add_argument("--simulado", action="store_true", help="Directora simulada (sin API ni coste)")
	p.add_argument("--arte-simulado", action="store_true", help="ComfyUI simulado (sin GPU)")
	p.add_argument("--comfy", default=os.environ.get("ORQ_COMFY", "http://127.0.0.1:8188"),
		help="runpod://<endpoint> (GPU alquilada por segundos) o http://... (ComfyUI propio)")
	p.add_argument("--crear", default=flujo_arte("crear"))
	p.add_argument("--editar", default=flujo_arte("editar"))
	p.add_argument("--lado", type=int, default=1024)
	p.add_argument("--semilla", type=int, default=7)
	p.add_argument("--apk", action="store_true")
	p.add_argument("--capturas", action="store_true")
	p.add_argument("--web", action="store_true", help="Exporta el paquete web para jugar en la app")
	p.add_argument("--ficha", action="store_true", help="Genera la ficha de Google Play (necesita --capturas)")
	p.add_argument("--clip", action="store_true", help="Graba un clip vertical de 15 s para redes (necesita ffmpeg)")
	p.add_argument("--marketing", action="store_true", help="Estudio de marketing con IA: 3 clips con guion, subtitulos y voz")
	args = p.parse_args(argv)
	try:
		fabricar(args)
		return 0
	except (ErrorCadena, llm.ErrorIA, bib.BibliaInvalida) as e:
		evento("fin", "error", str(e))
		return 1


if __name__ == "__main__":
	sys.exit(main())
