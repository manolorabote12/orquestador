"""Generos hechos a medida para cada juego (capa 3 de «cualquier juego»).

Cuando la idea no encaja en ningun genero de la fabrica (o se pide «[a_medida]»), Claude escribe
las reglas del juego, su analizador, su bot y su generador de niveles SOLO PARA ESE JUEGO, dentro
de su proyecto (kit/custom), y la fabrica lo comprueba de verdad: niveles generados, analizados y
superados por el bot. Si algo falla, le devuelve los errores y lo corrige (hasta 3 rondas). Si no
lo consigue, el juego sale con la plantilla probada y un aviso (nunca un juego roto).

Todo el codigo es GDScript (nada de Python escrito por la IA) y pasa antes por la lista negra de
seguridad de agente_genero (sin sistema, red, archivos ni cargar scripts de fuera).
"""

import json
import re
import tempfile
from pathlib import Path

import agente_genero
import cadena
from director import llm

GENERO = "a_medida"
KIT = "custom"
RONDAS = 3
VARIANTES = 4

HERRAMIENTA = {
	"name": "escribir_genero",
	"description": "Entrega los 3 archivos del genero a medida, completos.",
	"input_schema": {
		"type": "object", "additionalProperties": False,
		"required": ["juego_gd", "mapa_gd", "bot_gd", "notas"],
		"properties": {
			"juego_gd": {"type": "string", "description": "kit/custom/custom_game.gd completo"},
			"mapa_gd": {"type": "string", "description": "kit/custom/custom_map.gd completo: static analyze(level), static generate(i, n, d, seed) y lo que use el bot"},
			"bot_gd": {"type": "string", "description": "qa/custom_bot.gd completo (static run(tree, game, max_frames))"},
			"notas": {"type": "string", "maxLength": 600, "description": "Que juego has hecho y como se juega (en espanol, para el usuario)"},
		},
	},
}

PROMPT = agente_genero.PROMPT.split("- El generador Python")[0] + """- El generador de niveles va en el MISMO custom_map.gd: static func generate(i: int, n: int, d: float,
  seed_value: int) -> Array devuelve las filas del mapa (Array de String, todas del mismo largo) del
  nivel i de n, con d = dificultad de 0 a 1 que sube con i. Usa RandomNumberGenerator con esa semilla
  (misma semilla, mismo nivel). Comprueba tu mismo con analyze() que el nivel vale y reintenta.
- custom_map.gd no puede usar Kit, UI, Save ni otros autoloads (se ejecuta tambien fuera del juego).
- Las rutas son fijas: res://kit/custom/custom_game.gd, res://kit/custom/custom_map.gd, res://qa/custom_bot.gd.

Reglas de codigo del kit (si no, se rechaza antes de ejecutar):
- Tabulaciones para sangrar, nunca espacios. ASCII en el codigo; en textos usa \\u00e1 etc.
- Tipos explicitos en variables y funciones de GDScript. Sin class_name.
- Prohibido: OS.execute y parecidos, red (HTTPRequest...), DirAccess, FileAccess fuera de user://,
  load/preload fuera de res://kit, res://qa o res://scenes, Expression, ResourceSaver.
- Textos de interfaz con Kit.text("clave", "valor por defecto") (solo en custom_game.gd).
- Rendimiento de movil: nada de bucles enormes por frame; dibuja con _draw o nodos sencillos.
- Que sea DIVERTIDO y se entienda en 5 segundos en un movil vertical: controles tactiles grandes.
"""


def archivos_actuales(proyecto: Path) -> dict[str, str]:
	return {
		"juego_gd": (proyecto / "kit" / KIT / f"{KIT}_game.gd").read_text(encoding="utf-8"),
		"mapa_gd": (proyecto / "kit" / KIT / f"{KIT}_map.gd").read_text(encoding="utf-8"),
		"bot_gd": (proyecto / "qa" / f"{KIT}_bot.gd").read_text(encoding="utf-8"),
	}


def revisar(archivos: dict[str, str]) -> list[str]:
	"""La revision de seguridad de agente_genero (sin la parte de Python) y lo minimo del contrato."""
	errores = [e for e in agente_genero.revisar(dict(archivos, generador_py="def generar_x(): pass")) if not e.startswith("generador_py")]
	if not re.search(r"static func generate\(", archivos.get("mapa_gd", "")):
		errores.append("mapa_gd: falta static func generate(i, n, d, seed_value) -> Array")
	if not re.search(r"static func analyze\(", archivos.get("mapa_gd", "")):
		errores.append("mapa_gd: falta static func analyze(level) -> Dictionary")
	if re.search(r"\b(Kit|UI|Save|Audio|Ads|QA)\.", archivos.get("mapa_gd", "")):
		errores.append("mapa_gd: no puede usar autoloads (Kit, UI, Save...): se ejecuta fuera del juego")
	return errores


def escribir(proyecto: Path, archivos: dict[str, str]) -> None:
	(proyecto / "kit" / KIT / f"{KIT}_game.gd").write_text(archivos["juego_gd"], encoding="utf-8")
	(proyecto / "kit" / KIT / f"{KIT}_map.gd").write_text(archivos["mapa_gd"], encoding="utf-8")
	(proyecto / "qa" / f"{KIT}_bot.gd").write_text(archivos["bot_gd"], encoding="utf-8")


def generar_mapas(proyecto: Path, n: int, dificultad: float) -> tuple[list[list], list[str], str]:
	"""Variantes de cada nivel desde el generador GDScript del proyecto. (variantes, errores, log)."""
	out = Path(tempfile.mkdtemp()) / "niveles.json"
	r = cadena.godot(proyecto, "-s", "res://qa/generar_custom.gd", "--", f"--n={n}", f"--d={dificultad}",
		f"--variantes={VARIANTES}", f"--out={out}", timeout=600)
	log = (r.stdout or "") + (r.stderr or "")
	if not out.exists():
		return [], ["el generador no ha escrito los niveles (¿error al cargar los scripts?)"], log
	datos = json.loads(out.read_text(encoding="utf-8"))
	return datos.get("levels", []), datos.get("errors", []), log


def probar(proyecto: Path, diseno: dict, semilla: int) -> tuple[bool, str]:
	"""Niveles del generador del proyecto, analizador y bots jugando el juego entero."""
	import director.director as director
	dif = {"facil": 0.2, "normal": 0.5, "dificil": 0.8}.get(diseno.get("dificultad", "normal"), 0.5)
	n = len(diseno["niveles"])
	variantes, errores, log = generar_mapas(proyecto, n, dif)
	vacios = [i + 1 for i, v in enumerate(variantes) if not v]
	if errores and (not variantes or vacios):
		return False, "Generador/analizador:\n" + "\n".join(errores[:20]) + "\n" + agente_genero.resumen_errores(log)
	diseno["a_medida_mapas"] = variantes
	mapas = director.generar_niveles(diseno, semilla)
	try:
		val, _ = cadena.validar_con_bots(proyecto, diseno, mapas, semilla, {})
	except Exception as e:  # noqa: BLE001
		return False, f"Validacion: {e}"
	if val.get("ok"):
		return True, ""
	malos = [n2 for n2 in val.get("niveles", []) if not cadena.nivel_ok(n2, True)]
	return False, "El bot no supera estos niveles (o el juego da errores):\n" + json.dumps(malos[:4], ensure_ascii=False)[:2500] + \
		"\n" + str(val.get("fallos_qa", ""))[:1500]


def crear(proyecto: Path, diseno: dict, semilla: int, simulado: bool, gasto: llm.Gasto) -> dict:
	"""Escribe y comprueba el genero a medida del juego. {"ok", "rondas", "notas"}."""
	descripcion = str((diseno.get("a_medida") or {}).get("descripcion") or diseno.get("resumen", ""))[:1200]
	actuales = archivos_actuales(proyecto)
	historial: list[dict] = []
	for ronda in range(1, RONDAS + 1):
		if simulado:
			nuevos = dict(actuales, notas="(simulado) la plantilla tal cual")
		else:
			usuario = ("Juego que hay que hacer: <descripcion>" + descripcion + "</descripcion>\nTitulo: " + diseno.get("titulo", "")
				+ "\nArchivos actuales (la plantilla o tu version anterior):\n" + json.dumps(actuales, ensure_ascii=False)
				+ ("\n\nLa prueba anterior fallo con esto. Corrige SOLO lo necesario:\n" + historial[-1]["errores"] if historial else ""))
			try:
				nuevos = llm.llamar_herramienta(llm.MODELOS[-1], PROMPT, [{"role": "user", "content": usuario}], HERRAMIENTA,
					gasto, f"a medida ronda {ronda}", max_tokens=16000)
			except llm.ErrorIA as e:
				historial.append({"ronda": ronda, "errores": f"IA: {e}"})
				break
		archivos = {k: nuevos[k] for k in ("juego_gd", "mapa_gd", "bot_gd")}
		problemas = revisar(archivos)
		if problemas:
			historial.append({"ronda": ronda, "errores": "\n".join(problemas)})
			cadena.evento("a_medida", "aviso", f"Ronda {ronda}: el código no pasa la revisión, lo corrijo")
			continue
		escribir(proyecto, archivos)
		cadena.godot(proyecto, "--import", timeout=600)
		bien, errores = probar(proyecto, diseno, semilla)
		historial.append({"ronda": ronda, "ok": bien, "errores": errores, "notas": nuevos.get("notas", "")})
		actuales = archivos
		if bien:
			return {"ok": True, "rondas": ronda, "notas": nuevos.get("notas", "")}
		cadena.evento("a_medida", "aviso", f"Ronda {ronda}: el bot aún no lo supera, lo corrijo")
	## No ha salido: la plantilla probada (y sus niveles) para no entregar nunca un juego roto.
	escribir(proyecto, archivos_actuales(cadena.KIT))
	cadena.godot(proyecto, "--import", timeout=600)
	probar(proyecto, diseno, semilla)
	return {"ok": False, "rondas": len(historial), "notas": "", "errores": historial[-1]["errores"][:500] if historial else ""}
