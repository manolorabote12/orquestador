"""La fabrica aprende de los jugadores y de sus propias pruebas (aprendizaje.py).

	python -m pruebas.prueba_aprendizaje
"""

import os
import sys
import tempfile
from pathlib import Path


def main() -> int:
	tmp = tempfile.mkdtemp(prefix="orq_apr_")
	os.environ["ORQ_DATOS"] = tmp
	os.environ.pop("ORQ_APRENDER", None)
	import aprendizaje
	from director import director, llm
	from niveles import generador
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	jug = [
		{"genero": "plataformas", "dificultad": "normal", "tramo": 4, "juegos": 12, "intentos": 4000, "tasa_victoria": 0.22, "tasa_abandono": 0.5},
		{"genero": "plataformas", "dificultad": "normal", "tramo": 0, "juegos": 12, "intentos": 9000, "tasa_victoria": 0.99, "tasa_abandono": 0.01},
		{"genero": "plataformas", "dificultad": "normal", "tramo": 2, "juegos": 2, "intentos": 9000, "tasa_victoria": 0.1, "tasa_abandono": 0.6},
		{"genero": "carreras", "dificultad": "facil", "tramo": 1, "juegos": 5, "intentos": 150, "tasa_victoria": 0.1, "tasa_abandono": 0.6},
	]
	fab = [{"genero": "torres", "dificultad": "dificil", "tramo": 3, "rehecho": 2} for _ in range(12)]
	cal = aprendizaje.calcular(jug, fab)
	t4 = cal.get("plataformas|normal|4", {}).get("ajuste", 0)
	check("ultimos niveles: la gente se atasca y abandona -> mas faciles", -0.3 <= t4 < -0.15, str(t4))
	check("primeros niveles demasiado faciles -> un poco mas dificiles", 0 < cal.get("plataformas|normal|0", {}).get("ajuste", 0) <= 0.3)
	check("con pocos juegos no se aprende (evita que un juego raro lo tuerza)", "plataformas|normal|2" not in cal)
	check("con pocos intentos no se aprende", "carreras|facil|1" not in cal)
	check("el generador rehace mucho un tramo -> lo suaviza", cal.get("torres|dificil|3", {}).get("ajuste", 0) < 0)
	check("nunca mas de 0.3 arriba o abajo", all(abs(v["ajuste"]) <= 0.3 for v in cal.values()))

	aprendizaje.guardar(cal)
	d, _ = director.disenar("un gato ninja que salta por tejados de noche", True, llm.Gasto())
	d["dificultad"] = "normal"
	d["genero"] = "plataformas"
	n = len(d["niveles"])
	aj = aprendizaje.ajustes_para(d)
	check("cada nivel recibe el ajuste de su tramo", aj.get(n - 1) == t4 and aj.get(0, 0) > 0, str(aj))

	vistos: list[float] = []
	original = generador.generar

	def espia(i, n_, tipos, dif, semilla, ajuste=0.0, opciones=None):
		vistos.append(ajuste)
		return original(i, n_, tipos, dif, semilla, ajuste, opciones)

	generador.generar = espia
	try:
		director.generar_niveles(d, 7)
		check("el generador usa lo aprendido", vistos[-1] == t4 and vistos[0] > 0, str(vistos))
		vistos.clear()
		director.generar_niveles(d, 7, ajustes={n - 1: -0.3})
		check("lo pedido en el taller se suma a lo aprendido (con tope)", abs(vistos[-1] - max(-0.6, t4 - 0.3)) < 1e-9, str(vistos))
		os.environ["ORQ_APRENDER"] = "0"
		vistos.clear()
		director.generar_niveles(d, 7)
		check("ORQ_APRENDER=0 lo apaga", all(v == 0.0 for v in vistos), str(vistos))
		os.environ.pop("ORQ_APRENDER")
	finally:
		generador.generar = original

	aprendizaje.anotar_fabricacion(d, {0: 2}, [{"bot_muertes": 1}])
	filas = aprendizaje.leer_fabricacion()
	check("apunta cada nivel fabricado", len(filas) == n and filas[0]["rehecho"] == 2 and filas[0]["genero"] == "plataformas")
	check("informe legible", "plataformas" in aprendizaje.informe())
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
