"""Agente que crea un GENERO NUEVO a partir de una descripcion: Claude escribe las reglas, el
analizador, el bot y el generador de niveles sobre la plantilla, y la fabrica lo prueba de verdad
(un juego entero fabricado y superado por su bot). Si falla, le devuelve los errores y lo corrige.

	python -m agente_genero "sokoban: empujas cajas hasta sus huecos sin quedarte atascado" sokoban sokoban
	python -m agente_genero "..." laberinto maze --simulado      (sin IA: usa la plantilla tal cual)

Es una HERRAMIENTA DE DESARROLLO (la usa quien mantiene Orquestador), no algo que se exponga a los
usuarios: ejecuta en el PC codigo escrito por una IA. Por eso, antes de ejecutar nada:
	- se rechaza el codigo que intente usar el sistema, la red, ficheros fuera de user:// o cargar
	  scripts de fuera (lista NEGRA de abajo);
	- se exigen las reglas del kit: tabulaciones, ASCII en el codigo y tipos explicitos.
Lo que sale hay que revisarlo y calibrarlo por lotes antes de activarlo para todos (GENEROS-LEEME.md).
"""

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
sys.path.insert(0, str(RAIZ))

import nuevo_genero  # noqa: E402
from director import llm  # noqa: E402

NEGRA_GD = [r"\bOS\.(execute|create_process|shell_open|kill|create_instance|move_to_trash)", r"\bDirAccess\b",
	r"\bHTTPRequest\b", r"\bHTTPClient\b", r"\bStreamPeer", r"\bPacketPeer", r"\bTCPServer\b", r"\bUDPServer\b",
	r"\bWebSocket", r"\bJavaScriptBridge\b", r"\bJSON\.parse_string\(\s*FileAccess", r"FileAccess\.open\(\s*\"(?!user://)",
	r"\bProjectSettings\.save", r"\bResourceSaver\b", r"\bEngine\.get_singleton\b", r"\bClassDB\.instantiate\b",
	r"\bload\(\s*\"(?!res://(kit|qa|scenes)/)", r"\bpreload\(\s*\"(?!res://(kit|qa|scenes)/)", r"\bExpression\b"]
NEGRA_PY = [r"\bimport\s+(os|sys|subprocess|socket|shutil|pathlib|urllib|requests|http|ctypes|importlib)\b",
	r"\bfrom\s+(os|sys|subprocess|socket|shutil|pathlib|urllib|requests|http|ctypes|importlib)\b", r"\b__import__\b",
	r"\b(eval|exec|compile|open|globals|locals|getattr|setattr|delattr)\s*\(", r"\bbuiltins\b"]

HERRAMIENTA = {
	"name": "escribir_genero",
	"description": "Entrega los 4 archivos del genero nuevo, completos.",
	"input_schema": {
		"type": "object", "additionalProperties": False,
		"required": ["juego_gd", "mapa_gd", "bot_gd", "generador_py", "notas"],
		"properties": {
			"juego_gd": {"type": "string", "description": "kit/<kit>/<kit>_game.gd completo"},
			"mapa_gd": {"type": "string", "description": "kit/<kit>/<kit>_map.gd completo (static analyze(level))"},
			"bot_gd": {"type": "string", "description": "qa/<kit>_bot.gd completo (static run(tree, game, max_frames))"},
			"generador_py": {"type": "string", "description": "La funcion generar_<es>(...) completa en Python"},
			"notas": {"type": "string", "maxLength": 600, "description": "Que has cambiado y por que (en espanol)"},
		},
	},
}

PROMPT = """Eres programador senior de Godot 4.6 (GDScript) y Python en la fabrica de juegos Orquestador.
Vas a convertir una PLANTILLA de genero (un juego de cuadricula que ya funciona y pasa todas las
pruebas) en el genero que te describen. Llama SIEMPRE a la herramienta `escribir_genero`.

Contrato que NO puedes romper (lo usan el kit, el validador, las capturas y la tienda):
- La escena del juego expone: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
  bot_state() (con pos, deaths, coins, finished, failed, stomps), retry(), open_pause(); al ganar
  llama a Save.submit_best/submit_stars/unlock_level, QA.log_event("level_complete", {...level, stars}),
  ResultPanel.open(self, {stars, coins, coins_total, score, record}); al perder FailPanel.open(...).closed.connect(retry);
  al empezar QA.log_event("level_start", {"level": ...}); cada muerte QA.log_event("death", {...}).
- El analizador es un script con static func analyze(level: Dictionary) -> Dictionary que devuelve
  completable, issues (Array[String]), coins_total, enemies, enemy_problems. Comprueba SIN jugar que el
  nivel es justo: si dice completable, el bot tiene que poder ganarlo.
- El bot tiene static func run(tree: SceneTree, game: Node, max_frames: int) -> bool. Juega como una
  persona normal con las reglas reales (pone fast=true y auto_retry=true) y devuelve true si gana.
- El generador Python generar_<es>(i, n, enemigos, dificultad, semilla, ajuste=0.0, opciones=None) -> list[str]
  devuelve las filas del mapa (todas del mismo largo), con dificultad que sube con i y con 'dificultad'
  ('facil', 'normal', 'dificil') y con 'ajuste' (-0.6 a 0.6). Usa random.Random(semilla). Garantiza que
  el analizador lo acepta (comprueba tu mismo la jugabilidad y reintenta con otra semilla interna).
  Solo puede usar 'random' y 'math' (ya importados en el modulo) y la sintaxis basica de Python.

Reglas de codigo del kit (si no, se rechaza antes de ejecutar):
- Tabulaciones para sangrar, nunca espacios. ASCII en el codigo; en textos usa \\u00e1 etc.
- Tipos explicitos en variables y funciones de GDScript. Sin class_name.
- Prohibido: OS.execute y parecidos, red (HTTPRequest...), DirAccess, FileAccess fuera de user://,
  load/preload fuera de res://kit, res://qa o res://scenes, Expression, ResourceSaver.
- Textos de interfaz con Kit.text("clave", "valor por defecto").
- Rendimiento de movil: nada de bucles enormes por frame; dibuja con _draw o nodos sencillos.
"""


class ErrorAgente(Exception):
	pass


def revisar(archivos: dict[str, str]) -> list[str]:
	"""Seguridad y reglas del kit ANTES de escribir o ejecutar nada."""
	errores = []
	for nombre, codigo in archivos.items():
		es_gd = nombre.endswith("_gd")
		for patron in (NEGRA_GD if es_gd else NEGRA_PY):
			m = re.search(patron, codigo)
			if m:
				errores.append(f"{nombre}: no se permite '{m.group(0)}' (seguridad)")
		if es_gd:
			for n, linea in enumerate(codigo.splitlines(), 1):
				if linea.startswith(" "):
					errores.append(f"{nombre}:{n}: sangria con espacios; usa tabulaciones")
					break
			for n, linea in enumerate(codigo.splitlines(), 1):
				if any(ord(c) > 127 for c in linea):
					errores.append(f"{nombre}:{n}: caracteres no ASCII; usa \\u en los textos")
					break
			if re.search(r"^class_name\b", codigo, re.M):
				errores.append(f"{nombre}: sin class_name")
			if codigo.count("(") != codigo.count(")"):
				errores.append(f"{nombre}: parentesis desequilibrados")
	if "def generar_" not in archivos.get("generador_py", ""):
		errores.append("generador_py: falta la funcion generar_<es>")
	return errores


def plantilla(es: str, kit: str) -> dict[str, str]:
	p = nuevo_genero.PLANTILLA
	gen = (p / "generador.py.txt").read_text(encoding="utf-8")
	gen = gen[gen.index("def generar_"):gen.index("## << genero")]
	return {k: nuevo_genero._rellenar(v, es, kit) for k, v in {
		"juego_gd": (p / "kit" / "__ID___game.gd").read_text(encoding="utf-8"),
		"mapa_gd": (p / "kit" / "__ID___map.gd").read_text(encoding="utf-8"),
		"bot_gd": (p / "qa" / "__ID___bot.gd").read_text(encoding="utf-8"),
		"generador_py": gen,
	}.items()}


def escribir(es: str, kit: str, archivos: dict[str, str]) -> None:
	rutas = list(nuevo_genero._archivos(kit).values())
	rutas[0].write_text(archivos["juego_gd"], encoding="utf-8")
	rutas[1].write_text(archivos["mapa_gd"], encoding="utf-8")
	rutas[2].write_text(archivos["bot_gd"], encoding="utf-8")
	gen = RAIZ / "niveles" / "generador.py"
	t = gen.read_text(encoding="utf-8")
	ini = t.index(f"## >> genero {es}")
	fin = t.index(f"## << genero {es}")
	cuerpo = archivos["generador_py"].strip("\n")
	t = t[:ini] + f"## >> genero {es} (escrito por agente_genero.py)\n" + cuerpo + "\n" + t[fin:]
	gen.write_text(t, encoding="utf-8")


def probar(es: str, kit: str) -> tuple[bool, str]:
	r = subprocess.run([sys.executable, "-m", "nuevo_genero", es, kit, "--probar"], cwd=RAIZ, capture_output=True, text=True, timeout=1800)
	log = r.stdout + r.stderr
	return ("PRUEBA SUPERADA" in log and r.returncode == 0), log


def resumen_errores(log: str) -> str:
	utiles = [l for l in log.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|ERROR|Traceback|Error|fallo|no supera|issues|problemas", l)]
	return "\n".join(utiles[-40:])[-4000:] or log[-3000:]


def main() -> int:
	p = argparse.ArgumentParser(description="Un agente de IA crea un genero nuevo y lo prueba hasta que funciona")
	p.add_argument("descripcion")
	p.add_argument("es")
	p.add_argument("kit")
	p.add_argument("--claves", default="")
	p.add_argument("--rondas", type=int, default=4)
	p.add_argument("--simulado", action="store_true", help="Sin IA: la plantilla tal cual (prueba el circuito)")
	p.add_argument("--conservar", action="store_true", help="No deshacer el genero si falla (para depurar)")
	a = p.parse_args()
	gasto = llm.Gasto()
	r = subprocess.run([sys.executable, "-m", "nuevo_genero", a.es, a.kit, "--claves", a.claves or a.es,
		"--etiqueta", a.descripcion.split(":")[0][:40], "--frase-es", a.descripcion[:78]], cwd=RAIZ, capture_output=True, text=True)
	if r.returncode != 0 and "Ya existe" not in r.stdout + r.stderr:
		print(r.stdout + r.stderr)
		return 1
	actuales = plantilla(a.es, a.kit)
	historial: list[dict] = []
	ok = False
	for ronda in range(1, a.rondas + 1):
		if a.simulado:
			nuevos = dict(actuales, notas="simulado: plantilla sin cambios")
		else:
			usuario = (f"Genero nuevo: <descripcion>{a.descripcion}</descripcion>\nNombre en la fabrica: {a.es}; en el kit: {a.kit}.\n"
				"Archivos actuales (la plantilla o tu version anterior):\n" + json.dumps(actuales, ensure_ascii=False)
				+ ("\n\nLa prueba anterior fallo con esto. Corrige SOLO lo necesario:\n" + historial[-1]["errores"] if historial else ""))
			try:
				nuevos = llm.llamar_herramienta(llm.MODELOS[-1], PROMPT, [{"role": "user", "content": usuario}], HERRAMIENTA,
					gasto, f"genero ronda {ronda}", max_tokens=16000)
			except llm.ErrorIA as e:
				print("ERROR de la IA:", e)
				break
		archivos = {k: nuevos[k] for k in ("juego_gd", "mapa_gd", "bot_gd", "generador_py")}
		problemas = revisar(archivos)
		if problemas:
			historial.append({"ronda": ronda, "fase": "revision", "errores": "\n".join(problemas), "notas": nuevos.get("notas", "")})
			print(f"[agente] ronda {ronda}: rechazado antes de ejecutar ({len(problemas)} problemas)")
			continue
		escribir(a.es, a.kit, archivos)
		bien, log = probar(a.es, a.kit)
		historial.append({"ronda": ronda, "fase": "prueba", "ok": bien, "errores": "" if bien else resumen_errores(log),
			"notas": nuevos.get("notas", "")})
		print(f"[agente] ronda {ronda}: {'PRUEBA SUPERADA' if bien else 'falla'}")
		actuales = archivos
		if bien:
			ok = True
			break
	informe = {"genero": a.es, "kit": a.kit, "descripcion": a.descripcion, "ok": ok, "rondas": historial, "usd": gasto.usd,
		"fecha": time.strftime("%Y-%m-%d %H:%M")}
	carpeta = RAIZ / "datos" / "agente"
	carpeta.mkdir(parents=True, exist_ok=True)
	(carpeta / f"{a.es}.json").write_text(json.dumps(informe, indent=1, ensure_ascii=False), encoding="utf-8")
	if not ok and not a.conservar:
		subprocess.run([sys.executable, "-m", "nuevo_genero", a.es, a.kit, "--quitar"], cwd=RAIZ, capture_output=True)
		print("[agente] no lo ha conseguido: genero deshecho. Informe en datos/agente/")
		return 1
	print(f"[agente] genero '{a.es}' listo en {len(historial)} ronda(s), {gasto.usd} $. Revisalo y calibralo por lotes antes de activarlo.")
	return 0


if __name__ == "__main__":
	sys.exit(main())
