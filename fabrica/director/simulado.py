"""Directora simulada: disenos deterministas a partir de palabras clave de la idea.

Sirve para probar la cadena entera sin clave de API ni coste. No pretende ser creativa:
la directora real es Claude (llm.py). Mismo formato de salida, mismas validaciones.
"""

import hashlib

import generos

TEMAS = [
	{
		"claves": ["gato", "gata", "michi", "cat"],
		"titulo": "Bigotes Veloces", "lema": "Salta tejados, caza estrellas",
		"heroe": ("Mishi", "small orange tabby cat with big green eyes, white paws and a red scarf"),
		"coleccionable": ("Pez", "Peces", "small shiny silver fish snack with a golden glint"),
		"escenario": "warm terracotta rooftop tiles with mortar lines",
		"enemigos": [
			("walker", "Ratobot", "grey mechanical mouse robot with round wheels and a long antenna tail"),
			("spiky", "Erizo Gruñón", "grumpy dark brown hedgehog with tall sharp spikes on its back pointing up"),
			("flyer", "Paloma Pesada", "chubby purple pigeon with flapping wings and an annoyed face"),
		],
		"paleta": ["#1a1530", "#2b2450", "#4a3f7a", "#b5543c", "#d9774a", "#8a3b2a", "#f2c14e", "#ff5a4e", "#7ed6a0", "#f7f1e8"],
		"niveles": ["Tejado tranquilo", "Chimeneas", "Noche de luna", "La gran antena"],
		"musica": ("playful jazzy night, mischievous and light", ["upright bass", "brushed drums", "clarinet"], 112),
	},
	{
		"claves": ["espacio", "astronauta", "planeta", "nave", "galaxia", "space"],
		"titulo": "Órbita Saltarina", "lema": "Un pequeño salto por planeta",
		"heroe": ("Lumi", "small astronaut in a round white suit with a big cyan visor and a tiny jetpack"),
		"coleccionable": ("Estrella", "Estrellas", "glowing five pointed yellow star crystal"),
		"escenario": "purple alien rock with glowing crystal veins",
		"enemigos": [
			("walker", "Glopi", "green one-eyed slime alien blob with tiny legs"),
			("spiky", "Púas Lunar", "dark blue crystal crab with sharp crystal spikes pointing up on its shell"),
			("flyer", "Zumbón", "small red flying saucer drone with a single blinking light"),
		],
		"paleta": ["#0b0b1e", "#151538", "#2d2a6b", "#5b3f9c", "#8a6bd1", "#36c5d6", "#ffd84a", "#ff4f6d", "#5cf0a8", "#eef2ff"],
		"niveles": ["Despegue", "Luna menguante", "Cinturón de rocas", "Nebulosa", "Planeta final"],
		"musica": ("dreamy space adventure, hopeful", ["analog synth", "arpeggiator", "soft drums"], 118),
	},
	{
		"claves": ["bosque", "hada", "seta", "duende", "forest", "elfo"],
		"titulo": "Raíces del Bosque", "lema": "El bosque necesita un héroe",
		"heroe": ("Bruma", "little forest sprite with a leaf hood, acorn backpack and rosy cheeks"),
		"coleccionable": ("Bellota", "Bellotas", "golden acorn with a little shine"),
		"escenario": "mossy earth with roots and small stones",
		"enemigos": [
			("walker", "Escarabajo", "shiny dark green beetle with a big horn"),
			("spiky", "Cardo", "angry thistle plant monster with purple spikes on top"),
			("flyer", "Polilla", "big dusty grey moth with round wing spots"),
		],
		"paleta": ["#0e1a14", "#16301f", "#244a2c", "#3e7a4a", "#6aa84f", "#8a5a2b", "#e8c25a", "#e5533d", "#a8e6a3", "#f3f0dc"],
		"niveles": ["Claro del alba", "Raíces enredadas", "Pantano", "Árbol abuelo"],
		"musica": ("whimsical forest adventure", ["flute", "harp", "light percussion"], 100),
	},
	{
		"claves": [],
		"titulo": "Remache al Rescate", "lema": "Tuercas, saltos y chatarra",
		"heroe": ("Remache", "small round brass robot with one big glowing eye and a short antenna"),
		"coleccionable": ("Tuerca", "Tuercas", "shiny brass hex nut with golden highlights"),
		"escenario": "night city rooftop bricks, blue slate tiles",
		"enemigos": [
			("walker", "Chatarrilla", "rusty scrap beetle robot with red glowing eyes"),
			("spiky", "Pinchotrón", "squat steel robot with sharp spikes on top of its head"),
			("flyer", "Dron Zumbador", "small propeller drone with a red lens"),
		],
		"paleta": ["#0b0f1a", "#16233a", "#24395c", "#3e5c84", "#6b8db8", "#e8b04b", "#f6cf7a", "#d9774a", "#ff6b5b", "#3e7a4a", "#8fe3a5", "#e8f0fa"],
		"niveles": ["Primeros saltos", "Fábrica oxidada", "Tejados de noche", "La torre"],
		"musica": ("adventurous night, playful", ["chiptune lead", "square bass", "noise drums"], 118),
	},
]


def _contiene(texto: str, claves: list[str]) -> bool:
	return any(c in texto for c in claves)


PULLAS = ["¡Ja! No pasarás de aquí.", "Este camino está lleno de trampas, ¿lo sabías?", "¡Otra vez tú! Qué pesadez.",
	"Te estábamos esperando...", "Ni con alas llegarías a la meta."]
ANIMOS = ["¡Esto se pone interesante!", "Paso a paso, que no cunda el pánico.", "¡Ya casi lo tengo!",
	"Huele a aventura por aquí.", "¡Nadie me para hoy!"]


def _corta(t: str, n: int = 90) -> str:
	return t if len(t) <= n else t[: n - 1].rstrip() + "..."


def historia(d: dict) -> dict:
	"""Mini aventura de plantilla (sin IA): presentacion, tension y gran final."""
	niveles = d["niveles"]
	n = len(niveles)
	plural = d["coleccionable"]["nombre_plural"]
	con_rival = bool(d.get("enemigos")) and generos.GENEROS.get(d.get("genero", "plataformas"), {}).get("enemigos", True)
	out = []
	for i, nombre in enumerate(niveles):
		if i == 0:
			intro = [{"quien": "narrador", "texto": _corta(f"Así empieza la aventura de {d['heroe']['nombre']}: \"{nombre}\".")},
				{"quien": "heroe", "texto": _corta(f"¡Que empiece la caza de {plural.lower()}!")}]
			if con_rival:
				intro.append({"quien": "rival", "texto": PULLAS[0]})
			out.append({"intro": intro})
		elif i == n - 1:
			intro = [{"quien": "narrador", "texto": _corta(f"Último desafío: \"{nombre}\".")}]
			if d.get("jefe"):
				intro.append({"quien": "jefe", "texto": "¿Has llegado hasta aquí? ¡Ahora te toca conmigo!"})
			intro.append({"quien": "heroe", "texto": "¡Vamos allá, por última vez!"})
			out.append({"intro": intro, "fin": [{"quien": "heroe", "texto": "¡Lo conseguí! Gracias por jugar conmigo."},
				{"quien": "narrador", "texto": _corta(f"Y así {d['heroe']['nombre']} se convirtió en leyenda.")}]})
		else:
			intro = [{"quien": "heroe", "texto": _corta(f"\"{nombre}\"... {ANIMOS[i % len(ANIMOS)]}")}]
			if con_rival:
				intro.append({"quien": "rival", "texto": PULLAS[i % len(PULLAS)]})
			out.append({"intro": intro})
	return {"niveles": out}


def disenar(idea: str) -> dict:
	t = idea.lower()
	tema = next((x for x in TEMAS if x["claves"] and _contiene(t, x["claves"])), TEMAS[-1])
	if _contiene(t, ["pixel", "retro", "8 bit", "16 bit", "8-bit", "16-bit"]):
		familia = "pixel_art"
	elif _contiene(t, ["low poly", "low-poly", "3d", "poligon"]):
		familia = "low_poly"
	elif _contiene(t, ["realista", "realistic"]):
		familia = "realista"
	elif _contiene(t, ["pintado", "acuarela", "painted"]):
		familia = "pintado"
	else:
		familia = "cartoon"
	estilos = {
		"pixel_art": "16-bit pixel art, clean readable shapes, limited palette",
		"cartoon": "bold cartoon style, thick clean outlines, flat vibrant colors, friendly shapes",
		"low_poly": "low poly 3D render look, flat shaded facets, soft lighting, toy-like",
		"realista": "semi-realistic digital painting, detailed lighting, game asset",
		"pintado": "hand painted storybook illustration, soft brush strokes",
	}
	dificil = _contiene(t, ["dificil", "difícil", "reto", "hardcore", "competitivo"])
	facil = _contiene(t, ["niños", "ninos", "peques", "facil", "fácil", "relajado", "infantil", "mi hija", "mi hijo", "pequeños"])
	dificultad = "dificil" if dificil else ("facil" if facil else "normal")
	sensacion = "agil" if _contiene(t, ["rapido", "rápido", "veloz", "ninja", "agil", "ágil"]) else (
		"pesada" if _contiene(t, ["pesado", "lento", "tanque", "gigante"]) else "normal")
	n_enemigos = 1 if facil else 3
	h = int(hashlib.sha256(idea.encode("utf-8")).hexdigest()[:6], 16)
	niveles = list(tema["niveles"])
	if dificil and len(niveles) < 6:
		niveles = niveles + ["Desafío final"]
	jefes = {
		"Bigotes Veloces": ("Rey Rata", "giant fat grey rat king with a tin crown and a long whip tail"),
		"Órbita Saltarina": ("Gran Nebulón", "huge purple space octopus with glowing eyes and crystal armor"),
		"Raíces del Bosque": ("Tronco Gruñón", "giant angry tree stump monster with glowing red eyes and mossy arms"),
		"Remache al Rescate": ("Compactadora", "huge rusty trash compactor robot with crushing jaws and red warning lights"),
	}
	dispara = _contiene(t, ["dispar", "laser", "láser", "magia", "fuego", "nave", "pistola"])
	poderes = ["doble_salto", "estrella"] if facil else ["doble_salto", "estrella", "iman", "corazon" if dificil else "velocidad"]
	## Genero: el primero del registro (en su orden de prioridad) cuyas palabras aparecen en la idea.
	genero = next((g for g in generos.ORDEN if generos.GENEROS[g]["claves"] and _contiene(t, generos.GENEROS[g]["claves"])), "plataformas")
	runner = genero == "runner"
	volador = genero == "volador"
	if not generos.GENEROS[genero]["disparo"]:
		dispara = False
	if not generos.GENEROS[genero]["poderes"]:
		poderes = []
	if volador:
		runner = False
		dispara = False
		poderes = ["estrella", "iman", "corazon"]
	if runner:
		poderes = ["iman", "doble_salto", "estrella"]
	extra: dict = {}
	if not facil and generos.GENEROS[genero]["jefe"]:
		extra["jefe"] = {"nombre": jefes[tema["titulo"]][0], "descripcion": jefes[tema["titulo"]][1]}
	diseno = {
		**extra,
		"poderes": poderes,
		"disparo": dispara,
		"genero": genero,
		**({"vista": "2d" if _contiene(t, ["pixel", "retro", "desde arriba", "2d"]) else "3d"} if genero == "carreras" else {}),
		**({"vista": "3d" if _contiene(t, ["3d", "low poly", "lowpoly", "tres dimensiones"]) else "2d"}
			if genero in ("plataformas", "runner", "volador") else {}),
		"extras": {"puntos_control": True, "plataformas_moviles": not facil and genero == "plataformas"},
		"titulo": tema["titulo"],
		"lema": tema["lema"],
		"resumen": ("Juego de " + generos.GENEROS[genero]["etiqueta"].split(":")[0] + ": " + idea)[:300],
		"estilo": {"familia": familia, "descripcion": estilos[familia], "paleta": tema["paleta"]},
		"heroe": {"nombre": tema["heroe"][0], "descripcion": tema["heroe"][1]},
		"coleccionable": {"nombre": tema["coleccionable"][0], "nombre_plural": tema["coleccionable"][1], "descripcion": tema["coleccionable"][2]},
		"escenario": {"descripcion": tema["escenario"]},
		"enemigos": [{"tipo": e[0], "nombre": e[1], "descripcion": e[2]} for e in tema["enemigos"][:n_enemigos]],
		"sensacion": sensacion,
		"dificultad": dificultad,
		"niveles": niveles[: 3 + h % 2] if not dificil else niveles,
		"sonido": "retro" if familia == "pixel_art" else ("metalico" if "robot" in tema["heroe"][1] else "suave"),
		"musica": {"ambiente": tema["musica"][0], "instrumentos": tema["musica"][1], "tempo": tema["musica"][2]},
		"voz": {"inicio": "¡Allá voy!", "victoria": "¡Lo conseguí!", "derrota": "¡Uy, otra vez!"},
	}
	diseno["historia"] = historia(diseno)
	if genero == "aventura":
		from . import banco_aventuras
		diseno["aventura"] = banco_aventuras.capitulos(len(diseno["niveles"]), banco_aventuras.nombres_de(diseno))
	if genero == "sopa":
		from . import banco_palabras
		diseno["sopa"] = [banco_palabras.palabras(idea, i, len(diseno["niveles"]), len(idea)) for i in range(len(diseno["niveles"]))]
	if genero == "preguntas":
		from . import banco_preguntas
		banco = banco_preguntas.para(idea)
		diseno["preguntas"] = [{"pregunta": q, "opciones": o, "correcta": c, "explicacion": e} for q, o, c, e in banco]
		diseno["niveles"] = diseno["niveles"][:min(len(diseno["niveles"]), len(banco) // 4)]
		diseno["historia"] = historia(diseno)
	return diseno
