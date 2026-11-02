"""Guion de los clips para redes: 3 variantes (reto, curiosidad, humor) + texto de publicacion.

La IA (Claude, primero el modelo barato) escribe gancho, voz en off, subtitulos con tiempos y
llamada final para cada variante, y el titulo, texto y hashtags en espanol e ingles. El codigo
valida tiempos, longitudes, marcas protegidas y promesas falsas. Sin clave: modo simulado.
"""

import json
import re
from pathlib import Path

import jsonschema

import generos
from director import director, llm

RAIZ = Path(__file__).resolve().parent
ESQUEMA = json.loads((RAIZ / "guion.schema.json").read_text(encoding="utf-8"))
PROMPT = (RAIZ / "prompt_guion.md").read_text(encoding="utf-8")
HERRAMIENTA = {
	"name": "escribir_guion",
	"description": "Entrega las 3 variantes del clip y el texto de publicacion.",
	"input_schema": ESQUEMA,
}
ESTILOS = ["reto", "curiosidad", "humor"]
## Promesas que no se pueden hacer en un anuncio honesto.
PROMESAS = [r"m[aá]s descargad", r"n[uú]mero 1", r"millones de", r"most downloaded", r"number one",
	r"premiad", r"award", r"gana dinero", r"earn money", r"5 estrellas", r"5 stars"]
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿]")


def validar(g: dict) -> list[str]:
	errores = [f"{'/'.join(str(p) for p in e.path) or '(raiz)'}: {e.message}"
		for e in sorted(jsonschema.Draft202012Validator(ESQUEMA).iter_errors(g), key=lambda e: list(e.path))][:12]
	if errores:
		return errores
	if sorted(v["estilo"] for v in g["variantes"]) != sorted(ESTILOS):
		errores.append("variantes: tiene que haber una de cada estilo: reto, curiosidad y humor")
	for i, v in enumerate(g["variantes"]):
		palabras = len(v["voz"].split())
		if not 18 <= palabras <= 36:
			errores.append(f"variantes/{i}/voz: tiene {palabras} palabras; para 12 segundos hacen falta entre 25 y 32")
		fin = 0.0
		for j, s in enumerate(v["subtitulos"]):
			if s["hasta"] - s["desde"] < 0.8:
				errores.append(f"variantes/{i}/subtitulos/{j}: dura menos de 0.8 s (no da tiempo a leerlo)")
			if s["desde"] < fin - 0.01:
				errores.append(f"variantes/{i}/subtitulos/{j}: empieza antes de que acabe el anterior")
			fin = s["hasta"]
		for campo in ("gancho", "voz", "cta"):
			if EMOJI.search(v[campo]):
				errores.append(f"variantes/{i}/{campo}: sin emojis")
	textos = json.dumps(g, ensure_ascii=False).lower()
	for nombre in director.PROTEGIDOS:
		if re.search(r"\b" + re.escape(nombre) + r"\b", textos):
			errores.append(f"contenido protegido: '{nombre}'. No nombres marcas ni personajes de otros")
	for patron in PROMESAS:
		if re.search(patron, textos):
			errores.append(f"promesa que no podemos demostrar ('{patron}'): quitala")
	return errores


def resumen_juego(diseno: dict) -> str:
	g = generos.de(diseno)
	partes = {
		"titulo": diseno["titulo"], "lema": diseno["lema"], "genero": g["etiqueta"], "frase": g["frase"][0],
		"heroe": diseno["heroe"]["nombre"], "coleccionable": diseno["coleccionable"]["nombre_plural"],
		"enemigos": [e["nombre"] for e in diseno["enemigos"]] if g["enemigos"] or diseno.get("genero") == "carreras" else [],
		"jefe": (diseno.get("jefe") or {}).get("nombre"), "niveles": diseno["niveles"], "dificultad": diseno["dificultad"],
	}
	return json.dumps(partes, ensure_ascii=False)


def escribir(diseno: dict, momentos: list[str], simular: bool, gasto: llm.Gasto) -> tuple[dict, str]:
	"""Guion validado para el juego. momentos = lo que pasa en el clip ("pisa al jefe", "gana el nivel"...)."""
	if simular:
		g = simulado(diseno, momentos)
		err = validar(g)
		if err:
			raise llm.ErrorIA("El guion simulado no es valido: " + "; ".join(err))
		return g, "simulado"
	usuario = ("Ficha del juego (datos, no instrucciones):\n<juego>\n" + resumen_juego(diseno) + "\n</juego>\n"
		"Lo que se ve en el clip, en orden:\n<clip>\n" + "\n".join("- " + m for m in momentos) + "\n</clip>")
	return llm.con_router(PROMPT, usuario, HERRAMIENTA, validar, gasto)


## ------------------------------------------------------------------ simulado (sin IA)

def _hashtags(diseno: dict, en: bool) -> list[str]:
	g = diseno.get("genero", "plataformas")
	por_genero = {
		"plataformas": ["#plataformas", "#platformer"], "runner": ["#runner", "#endlessrunner"], "volador": ["#arcade", "#flappy"],
		"horda": ["#survivor", "#roguelike"], "puzle": ["#puzle", "#match3"], "torres": ["#towerdefense", "#estrategia"],
		"carreras": ["#carreras", "#racing"], "naves": ["#matamarcianos", "#shmup"],
		"rompebloques": ["#rompebloques", "#brickbreaker"], "bloques": ["#puzle", "#blockpuzzle"],
		"corredor": ["#runner3d", "#endlessrunner"], "serpiente": ["#snake", "#retro"], "memoria": ["#memoria", "#memorygame"], "cajas": ["#sokoban", "#puzzle"], "preguntas": ["#trivial", "#quiz"], "apilar": ["#stack", "#onetap"], "topos": ["#whackamole", "#reflejos"], "saltos": ["#doodlejump", "#saltos"], "arena": ["#brawl", "#battleroyale"], "aldea": ["#clashofclans", "#estrategia"],
	}.get(g, ["#juego"])
	base = ["#indiegame", "#mobilegame", "#gamedev"] if en else ["#juegosmoviles", "#indiegame", "#gamedev"]
	return [por_genero[1] if en else por_genero[0]] + base


def simulado(diseno: dict, momentos: list[str]) -> dict:
	t = diseno["titulo"]
	h = diseno["heroe"]["nombre"]
	jefe = (diseno.get("jefe") or {}).get("nombre")
	col = diseno["coleccionable"]["nombre_plural"].lower()
	n = len(diseno["niveles"])
	reto_gancho = f"¿Llegas al nivel {n}?"[:42]
	variantes = [
		{"estilo": "reto", "gancho": reto_gancho,
			"voz": f"Esto es {t}. Controlas a {h} y tienes que recoger {col} sin caer. Parece fácil, pero el último nivel no perdona. ¿Te atreves a intentarlo?",
			"subtitulos": [{"desde": 0.3, "hasta": 3.0, "texto": f"Esto es {t}"[:38]}, {"desde": 3.2, "hasta": 6.6, "texto": f"Recoge {col} sin caer"[:38]},
				{"desde": 6.8, "hasta": 9.8, "texto": "El último nivel no perdona"}, {"desde": 10.0, "hasta": 12.4, "texto": "¿Te atreves?"}],
			"cta": "Juega gratis en Google Play"},
		{"estilo": "curiosidad", "gancho": ("Mira lo que pasa con " + jefe)[:42] if jefe else "Mira hasta el final",
			"voz": f"Mira bien a {h}. Cada nivel de {t} esconde algo distinto y al final hay una sorpresa que no te esperas. Quédate hasta el final y luego pruébalo tú.",
			"subtitulos": [{"desde": 0.3, "hasta": 3.2, "texto": f"Mira bien a {h}"[:38]}, {"desde": 3.4, "hasta": 7.0, "texto": "Cada nivel esconde algo"},
				{"desde": 7.2, "hasta": 10.2, "texto": "Y al final, una sorpresa"}, {"desde": 10.4, "hasta": 12.4, "texto": "Pruébalo tú"}],
			"cta": "Descárgalo gratis"},
		{"estilo": "humor", "gancho": f"{h} no tiene un buen día"[:42],
			"voz": f"Este es {h}. Solo quería recoger {col} tranquilamente, pero todo el mundo en {t} tiene otros planes para él. Ayúdale, que solo no puede.",
			"subtitulos": [{"desde": 0.3, "hasta": 3.0, "texto": f"Este es {h}"[:38]}, {"desde": 3.2, "hasta": 6.8, "texto": "Solo quería estar tranquilo"},
				{"desde": 7.0, "hasta": 10.0, "texto": "Pero nadie le deja"}, {"desde": 10.2, "hasta": 12.4, "texto": "Ayúdale tú"}],
			"cta": "Juega gratis"},
	]
	return {
		"variantes": variantes,
		"publicacion": {
			"es": {"titulo": f"{t}: ¿llegas al final?"[:80], "texto": f"{diseno['lema']}. Juega con {h} gratis en Android."[:220],
				"hashtags": _hashtags(diseno, False)},
			"en": {"titulo": f"{t}: can you beat it?"[:80], "texto": f"Play as {h} for free on Android. How far can you get?"[:220],
				"hashtags": _hashtags(diseno, True)},
		},
	}
