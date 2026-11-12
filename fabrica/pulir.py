"""Bucle de pulido (modo estudio, 13 nov 2026): critica -> arreglo -> otra critica, hasta la nota.

Despues de validar el juego, la fabrica le hace capturas, la critica visual pone nota y nombra los
problemas, y la IA arregla lo que se puede arreglar sin tocar las reglas:
	- vida y efectos (efectos_pobres, poca_vida, nivel_vacio...): un mod cosmetico (agente_mods) con
	  particulas, temblores, destellos y textos en los momentos clave de la partida;
	- en un genero a medida (kit custom): Claude mejora el dibujo y el «jugo» de custom_game.gd viendo
	  las capturas (sin tocar el generador ni el bot), y el bot vuelve a jugarlo entero.
Cada cambio se queda solo si el juego sigue pasando todas las pruebas Y la nueva critica no baja la
nota; si no, se deshace. Para al llegar a OBJETIVO, al acabar las rondas o al tope de gasto.

	ORQ_PULIR_RONDAS (0 = apagado; el modo estudio pone 3), ORQ_PULIR_USD (tope, por defecto 2 $).
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

import cadena
from cadena import ErrorCadena, evento
from director import llm

OBJETIVO = 8
## Problemas de la critica que arregla un mod cosmetico (lo demas es arte o interfaz: otra fase).
CON_MOD = ("efectos_pobres", "poca_vida", "nivel_vacio", "fondo_vacio", "interfaz_sosa")

INSTRUCCION_MOD = (
	"PULIDO COSMETICO (no cambies las reglas, la dificultad, las monedas ni nada que afecte a ganar o perder): "
	"anade vida y efectos a la partida para que se sienta como un juego de exito de Google Play. En los momentos clave "
	"(empezar nivel, coger el coleccionable, golpear o derrotar enemigos, combos, ganar) usa burst de particulas con los "
	"colores del juego, shake suave, flash_screen corto y toast con frases cortas y animadas en espanol. Nada de spam: "
	"que cada efecto marque un momento. Lo que dijo la critica:\n")

PROMPT_CODIGO = """Eres programador senior de Godot 4.6 (GDScript) y director de arte de juegos de movil.
Te paso custom_game.gd (las reglas y la pantalla de un juego hecho a medida), capturas REALES de la
partida y la critica de un director de arte. Mejora el ASPECTO y el JUGO del juego: dibujo mas rico
(sombras, brillos, bordes, degradados, animaciones con tween o en _process), particulas o destellos
al conseguir cosas, temblor suave en los golpes, numeros que saltan, transiciones, y una interfaz
limpia con botones grandes. Usa la paleta y las texturas que ya carga el juego.

PROHIBIDO cambiar las reglas, el formato de los niveles, las senales o funciones que usa el bot, los
nombres de nodos que busca el bot ni la dificultad: el bot tiene que seguir ganando todos los niveles.
Mismas reglas de codigo del kit: tabulaciones, ASCII (textos con \\u00e1...), tipos explicitos, sin
class_name, sin red ni archivos ni load fuera de res://kit, res://qa o res://scenes.
Devuelve el archivo COMPLETO con la herramienta `pulir_codigo`."""

HERRAMIENTA_CODIGO = {
	"name": "pulir_codigo",
	"description": "custom_game.gd completo y mejorado.",
	"input_schema": {"type": "object", "additionalProperties": False, "required": ["juego_gd", "cambios"],
		"properties": {"juego_gd": {"type": "string"},
			"cambios": {"type": "string", "maxLength": 400, "description": "Que has mejorado (en espanol, para el usuario)"}}},
}


def rondas() -> int:
	try:
		return max(0, min(6, int(os.environ.get("ORQ_PULIR_RONDAS", "0") or 0)))
	except ValueError:
		return 0


def tope() -> float:
	try:
		return float(os.environ.get("ORQ_PULIR_USD", "2") or 2)
	except ValueError:
		return 2.0


def capturar(proyecto: Path, out: Path) -> list[str]:
	"""Capturas de la partida (como el paso 8 de la cadena) en una carpeta aparte."""
	if out.exists():
		shutil.rmtree(out)
	for xvfb in (False, True):
		try:
			cadena.godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--fixed-fps", "60",
				"res://qa/capturas.tscn", "--", f"--out={out}", timeout=540, display=True, xvfb=xvfb)
		except (subprocess.TimeoutExpired, OSError):
			pass
		if any(out.glob("*.png")):
			break
	return sorted(str(p) for p in out.glob("*.png"))


def instruccion_mod(c: dict) -> str | None:
	"""Pura: la instruccion del mod cosmetico si la critica pide vida o efectos; None si no."""
	ps = [p for p in c.get("problemas", []) if p.get("tipo") in CON_MOD]
	if not ps:
		return None
	return INSTRUCCION_MOD + "\n".join(f"- {p['tipo']}: {p['detalle']}" for p in ps)


def mejor(nueva: dict | None, vieja: dict) -> bool:
	"""Pura: el cambio se queda si la critica no baja la nota."""
	return bool(nueva) and nueva["nota"] >= vieja["nota"]


class Copia:
	"""Lo que un arreglo puede tocar (mods, game.json, custom_game.gd), para deshacerlo."""

	def __init__(self, proyecto: Path):
		self.p = proyecto
		self.game = (proyecto / "game.json").read_text(encoding="utf-8")
		self.mods = {m.name: m.read_text(encoding="utf-8") for m in (proyecto / "mods").glob("*.gd")} if (proyecto / "mods").exists() else {}
		jg = proyecto / "kit" / "custom" / "custom_game.gd"
		self.juego = jg.read_text(encoding="utf-8") if jg.exists() else None

	def restaurar(self) -> None:
		(self.p / "game.json").write_text(self.game, encoding="utf-8")
		mods = self.p / "mods"
		if mods.exists():
			for m in mods.glob("*.gd"):
				if m.name not in self.mods:
					m.unlink()
		for n, t in self.mods.items():
			(mods / n).write_text(t, encoding="utf-8")
		if self.juego is not None:
			(self.p / "kit" / "custom" / "custom_game.gd").write_text(self.juego, encoding="utf-8")
		cadena.godot(self.p, "--import", timeout=600)


def arreglar_codigo(proyecto: Path, diseno: dict, semilla: int, c: dict, capturas: list[str], gasto: llm.Gasto) -> str:
	"""Genero a medida: Claude mejora custom_game.gd viendo las capturas. Lanza ErrorCadena si no pasa."""
	import genero_usuario
	from arte import critica
	actual = genero_usuario.archivos_actuales(proyecto)
	contenido: list[dict] = [{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": critica._png(x)}}
		for x in critica.elegir(capturas)[:3]]
	contenido.append({"type": "text", "text": "Critica del director de arte:\n" + critica.resumen(c)
		+ "\n\ncustom_game.gd actual:\n" + actual["juego_gd"]})
	modelo = os.environ.get("ORQ_MODELO_PROGRAMADOR") or llm.MODELOS[-1]
	r = llm.llamar_herramienta(modelo, PROMPT_CODIGO, [{"role": "user", "content": contenido}], HERRAMIENTA_CODIGO, gasto,
		"pulir_codigo", max_tokens=16000)
	nuevos = dict(actual, juego_gd=str(r.get("juego_gd", "")))
	problemas = genero_usuario.revisar(nuevos)
	if problemas:
		raise ErrorCadena("el codigo pulido no pasa la revision: " + "; ".join(problemas[:3]))
	genero_usuario.escribir(proyecto, nuevos)
	cadena.godot(proyecto, "--import", timeout=600)
	bien, errores = genero_usuario.probar(proyecto, diseno, semilla)
	if not bien:
		raise ErrorCadena("el bot ya no supera el juego pulido: " + errores[:300])
	return str(r.get("cambios", ""))


def pulir(proyecto: Path, diseno: dict, semilla: int, gasto: llm.Gasto) -> dict | None:
	"""El bucle. Devuelve {"nota_inicial", "nota", "rondas", "cambios"} o None si esta apagado o no se pudo."""
	n = rondas()
	if n <= 0:
		return None
	from arte import critica
	inicio = gasto.usd
	import tempfile
	carpeta = Path(tempfile.mkdtemp(prefix="pulido_"))
	caps = capturar(proyecto, carpeta / "r0")
	c = critica.criticar(caps, diseno["titulo"], str(diseno.get("genero", "")), gasto) if caps else None
	if not c:
		evento("pulido", "aviso", "Sin capturas o sin crítica: me salto el pulido")
		return None
	res = {"nota_inicial": c["nota"], "nota": c["nota"], "rondas": 0, "cambios": []}
	evento("pulido", "inicio", f"Pulido: nota {c['nota']}/10, objetivo {OBJETIVO}", nota=c["nota"])
	a_medida = diseno.get("genero") == "a_medida"
	for r in range(1, n + 1):
		if c["nota"] >= OBJETIVO or gasto.usd - inicio >= tope():
			break
		copia = Copia(proyecto)
		try:
			if a_medida:
				que = arreglar_codigo(proyecto, diseno, semilla, c, caps, gasto)
			else:
				instr = instruccion_mod(c)
				if not instr:
					break
				import agente_mods
				que = agente_mods.programar(proyecto, instr, False, gasto, rondas=2).get("resumen", "efectos")
		except (ErrorCadena, llm.ErrorIA) as e:
			copia.restaurar()
			evento("pulido", "aviso", f"Ronda {r}: no salió ({str(e)[:120]}); lo dejo como estaba")
			continue
		res["rondas"] = r
		caps2 = capturar(proyecto, carpeta / f"r{r}")
		c2 = critica.criticar(caps2, diseno["titulo"], str(diseno.get("genero", "")), gasto) if caps2 else None
		if mejor(c2, c):
			res["cambios"].append(que)
			c, caps = c2, caps2
			res["nota"] = c["nota"]
			evento("pulido", "ok", f"Ronda {r}: {que[:120]} (nota {c['nota']}/10)", nota=c["nota"])
		else:
			copia.restaurar()
			evento("pulido", "aviso", f"Ronda {r}: la crítica no mejora ({c2['nota'] if c2 else '?'}/10); lo deshago")
	(proyecto / "fabrica" / "pulido.json").write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
	return res
