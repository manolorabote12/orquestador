"""La fabrica prueba variantes y se queda con las que mejor puntuan (aprendizaje por experimentos).

Cada juego nuevo de un genero con ajustes elige una opcion de cada mando (cuanto acerca la camara,
el tamano de los personajes, cuantas piezas especiales llevan los niveles). Al final, la critica
visual pone nota al juego y esa nota se apunta junto con lo elegido. La siguiente vez cada mando se
elige con muestreo de Thompson: cada opcion tiene una distribucion Beta con sus aciertos (nota/10)
y fallos (1 - nota/10); se saca un numero de cada una y gana el mas alto. Las opciones que puntuan
mejor salen cada vez mas, pero las otras se siguen probando de vez en cuando (por si cambia algo).

Mas adelante la senal sera la de los jugadores (tiempo jugado, abandonos); hoy, la critica.

Los datos viven en el servidor (tabla experimentos) para que aprendan todas las maquinas a la vez:
el trabajador conecta remoto_historial y remoto_anotar. Sin servidor (pruebas locales) no se
experimenta: se usa la opcion por defecto y no se apunta nada.
"""

import random

## Mandos por genero: nombre -> opciones (la primera es la de siempre).
MANDOS: dict[str, dict[str, list[float]]] = {
	"plataformas": {"zoom": [1.0, 0.9, 1.15], "sprite": [1.0, 0.9, 1.15], "piezas": [1.0, 0.5, 1.6]},
	"runner": {"zoom": [1.0, 0.9, 1.15], "sprite": [1.0, 0.9, 1.15], "piezas": [1.0, 0.5, 1.6]},
	"horda": {"zoom": [1.0, 0.9, 1.12], "sprite": [1.0, 0.9, 1.15]},
	"naves": {"sprite": [1.0, 0.9, 1.15]},
}
## Problemas de la critica que empujan un mando (memoria de la critica): si se repiten, la opcion
## que lo corrige sale con ventaja hasta que haya datos de sobra.
EMPUJES: dict[str, tuple[str, int]] = {
	"personaje_pequeno": ("sprite", 2),
	"nivel_vacio": ("piezas", 2),
}

remoto_historial = None  # (genero) -> [{"eleccion": {...}, "nota": int, "problemas": [...]}]
remoto_anotar = None     # (genero, eleccion, nota, problemas) -> None


def mandos(genero: str) -> dict[str, list[float]]:
	return MANDOS.get(genero, {})


def elegir(genero: str, historial: list[dict] | None = None, rng: random.Random | None = None) -> dict:
	"""Pura (con rng): una opcion por mando. Sin mandos para el genero, {}."""
	ms = mandos(genero)
	if not ms:
		return {}
	rng = rng or random.Random()
	hist = historial or []
	## Memoria de la critica: problemas repetidos en los ultimos juegos del genero.
	recientes = [p for h in hist[-8:] for p in (h.get("problemas") or [])]
	empuje = {m: ms[m][k] for p, (m, k) in EMPUJES.items() if m in ms and recientes.count(p) >= 2}
	eleccion: dict = {}
	for nombre, opciones in ms.items():
		mejor, valor = opciones[0], -1.0
		for op in opciones:
			a, b = 1.0, 1.0
			for h in hist:
				if (h.get("eleccion") or {}).get(nombre) == op and isinstance(h.get("nota"), (int, float)):
					x = max(0.0, min(1.0, float(h["nota"]) / 10.0))
					a += x
					b += 1.0 - x
			## La opcion que corrige un problema repetido arranca con dos «aciertos» de ventaja.
			if empuje.get(nombre) == op:
				a += 2.0
			v = rng.betavariate(a, b)
			if v > valor:
				mejor, valor = op, v
		eleccion[nombre] = mejor
	return eleccion


def para_juego(genero: str) -> dict:
	"""Lo que usa la cadena: historial del servidor (si lo hay) y eleccion. Sin servidor, {}."""
	if remoto_historial is None or not mandos(genero):
		return {}
	try:
		hist = remoto_historial(genero) or []
	except Exception:  # noqa: BLE001 - sin datos se elige igual (todo empieza parejo)
		hist = []
	return elegir(genero, hist)


def anotar(genero: str, eleccion: dict, nota: int, problemas: list[str]) -> None:
	if remoto_anotar is None or not eleccion:
		return
	try:
		remoto_anotar(genero, eleccion, int(nota), [str(p)[:30] for p in problemas][:6])
	except Exception:  # noqa: BLE001 - aprender nunca para un juego
		pass


def resumen(historial: list[dict], genero: str) -> list[str]:
	"""Pura: nota media de cada opcion de cada mando (para los informes)."""
	out = []
	for nombre, opciones in mandos(genero).items():
		partes = []
		for op in opciones:
			notas = [h["nota"] for h in historial if (h.get("eleccion") or {}).get(nombre) == op and isinstance(h.get("nota"), (int, float))]
			partes.append(f"{op}: {sum(notas) / len(notas):.1f} ({len(notas)})" if notas else f"{op}: -")
		out.append(f"{nombre} -> " + ", ".join(partes))
	return out
