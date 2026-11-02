"""Banco de palabras para la sopa de letras cuando la directora no las escribe (modo sin IA).

Cada tema tiene palabras de 3 a 9 letras; se elige el tema por las palabras de la idea y, si no
encaja ninguno, se mezclan temas generales. Los niveles van de palabras cortas a largas.
"""
from __future__ import annotations

import random
import re
import unicodedata

TEMAS: dict[str, dict] = {
	"animales": {"claves": ["animal", "zoo", "selva", "granja", "mascota", "perro", "gato"],
		"palabras": ["GATO", "PERRO", "LEON", "TIGRE", "OSO", "LOBO", "ZORRO", "CEBRA", "JIRAFA", "MONO", "PATO", "VACA", "CABRA",
			"OVEJA", "CONEJO", "RATON", "BUHO", "AGUILA", "CABALLO", "ELEFANTE", "TORTUGA", "CANGURO", "PANDA", "KOALA"]},
	"mar": {"claves": ["mar", "oceano", "playa", "pirata", "barco", "isla", "pez", "sirena"],
		"palabras": ["MAR", "OLA", "PEZ", "ISLA", "BARCO", "PLAYA", "ARENA", "CONCHA", "DELFIN", "BALLENA", "PULPO", "MEDUSA",
			"CORAL", "ANCLA", "VELA", "FARO", "TIBURON", "CANGREJO", "ESTRELLA", "SIRENA", "TESORO", "MAREA"]},
	"espacio": {"claves": ["espacio", "planeta", "estrella", "astronauta", "cohete", "galaxia", "nave", "luna", "marte"],
		"palabras": ["SOL", "LUNA", "MARTE", "VENUS", "TIERRA", "COHETE", "COMETA", "ORBITA", "GALAXIA", "NEBULOSA", "SATURNO",
			"JUPITER", "ESTRELLA", "ASTRO", "NAVE", "CRATER", "ECLIPSE", "PLANETA", "METEORO", "SATELITE"]},
	"comida": {"claves": ["comida", "cocina", "fruta", "postre", "dulce", "pastel", "restaurante", "chef"],
		"palabras": ["PAN", "QUESO", "SOPA", "ARROZ", "PIZZA", "TARTA", "HUEVO", "MANZANA", "PERA", "UVA", "FRESA", "MELON",
			"PLATANO", "NARANJA", "LIMON", "GALLETA", "HELADO", "CHOCOLATE", "PASTA", "TOMATE", "PATATA", "MIEL"]},
	"magia": {"claves": ["magia", "mago", "bruja", "hechizo", "fantasia", "dragon", "castillo", "hada", "reino"],
		"palabras": ["MAGO", "HADA", "BRUJA", "DRAGON", "ELFO", "CASTILLO", "VARITA", "POCION", "HECHIZO", "CORONA", "ESPADA",
			"ESCUDO", "TROLL", "GIGANTE", "ORACULO", "RUNA", "AMULETO", "REINO", "PRINCESA", "CABALLERO"]},
	"deporte": {"claves": ["deporte", "futbol", "baloncesto", "tenis", "carrera", "olimpic", "pelota"],
		"palabras": ["GOL", "BALON", "RED", "TENIS", "GOLF", "RUGBY", "BOXEO", "KARATE", "ESQUI", "SURF", "NATACION", "CICLISMO",
			"PORTERIA", "ARBITRO", "EQUIPO", "MEDALLA", "TROFEO", "ESTADIO", "CARRERA", "SALTO"]},
	"naturaleza": {"claves": ["bosque", "naturaleza", "jardin", "flor", "arbol", "montana", "rio", "campo"],
		"palabras": ["ARBOL", "FLOR", "HOJA", "RAMA", "RIO", "LAGO", "MONTE", "BOSQUE", "SEMILLA", "ROSA", "MUSGO", "SETA",
			"PRADO", "VALLE", "CASCADA", "VOLCAN", "NUBE", "LLUVIA", "VIENTO", "ROCA", "PINO", "HELECHO"]},
	"ciudad": {"claves": ["ciudad", "coche", "tren", "calle", "edificio", "trafico", "aparcamiento"],
		"palabras": ["CALLE", "PARQUE", "COCHE", "TAXI", "TREN", "METRO", "PUENTE", "TORRE", "TIENDA", "MUSEO", "PLAZA",
			"ESCUELA", "HOSPITAL", "SEMAFORO", "AUTOBUS", "FAROLA", "CINE", "BANCO", "MERCADO", "ACERA"]},
	"musica": {"claves": ["musica", "ritmo", "cancion", "banda", "concierto", "piano", "guitarra"],
		"palabras": ["NOTA", "PIANO", "VIOLIN", "FLAUTA", "TAMBOR", "GUITARRA", "ARPA", "CORO", "RITMO", "BAILE", "CANCION",
			"MELODIA", "TROMPETA", "BAJO", "OPERA", "JAZZ", "ROCK", "ESCENARIO", "MICRO", "DISCO"]},
	"invierno": {"claves": ["invierno", "nieve", "navidad", "hielo", "frio", "pingüino", "pinguino"],
		"palabras": ["NIEVE", "HIELO", "FRIO", "TRINEO", "BUFANDA", "GORRO", "GUANTES", "PINGUINO", "IGLU", "COPO", "ABETO",
			"REGALO", "ESTUFA", "MANTA", "ESQUI", "PATINES", "RENO", "ESTRELLA", "VELA", "CHOCOLATE"]},
}


def _plano(s: str) -> str:
	return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


def tema_de(idea: str) -> str:
	t = _plano(idea or "")
	mejor, puntos = "", 0
	for nombre, d in TEMAS.items():
		p = sum(1 for k in d["claves"] if re.search(r"\b" + re.escape(_plano(k)), t))
		if p > puntos:
			mejor, puntos = nombre, p
	return mejor


def palabras(idea: str, i: int, n: int, semilla: int) -> list[str]:
	"""Palabras del nivel i: de 4 a 10, cada vez mas largas."""
	rng = random.Random(semilla * 131 + i * 17)
	tema = tema_de(idea)
	lista = list(TEMAS[tema]["palabras"]) if tema else [w for d in TEMAS.values() for w in d["palabras"]]
	cuantas = min(10, 4 + i // 1 if i < 3 else 6 + (i - 3) // 2)
	largo_max = min(9, 5 + i)
	buenas = [w for w in lista if len(w) <= largo_max]
	rng.shuffle(buenas)
	out = sorted(set(buenas[:cuantas]), key=len)
	return out if len(out) >= 3 else sorted(set(lista[:4]), key=len)
