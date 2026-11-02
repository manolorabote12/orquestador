"""Originalidad: huellas, parecido y el giro que evita los copia y pega.

	python -m pruebas.prueba_originalidad
"""

import copy
import os
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))
os.environ["ORQ_DATOS"] = tempfile.mkdtemp()

import originalidad  # noqa: E402
from director import director, simulado  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


def main() -> int:
	d1 = director.normalizar(simulado.disenar("un juego de plataformas de un gato ninja por tejados"))
	d2 = copy.deepcopy(d1)
	d3 = director.normalizar(simulado.disenar("un tetris de bloques de colores"))
	h1, h2, h3 = originalidad.huella(d1), originalidad.huella(d2), originalidad.huella(d3)
	check("la huella no guarda el titulo", "titulo" not in h1 and d1["titulo"] not in str(h1))
	check("el mismo juego se parece del todo", originalidad.parecido(h1, h2) >= 0.95, str(originalidad.parecido(h1, h2)))
	check("otro genero no se parece nada", originalidad.parecido(h1, h3) == 0.0)
	r = originalidad.diferenciar(d2, [h1])
	check("un copia y pega recibe un giro nuevo", r["cambio"] != "" and r["cambio"] in d2.get("giros", []), str(r))
	check("y sube su originalidad", r["indice"] > 50 and d2["originalidad"] == r["indice"], str(r))
	check("el diseno con su indice sigue siendo valido", director.validar(d2) == [], str(director.validar(d2)))
	check("el aviso lo explica", "único" in r["mensaje"], r["mensaje"])
	d4 = copy.deepcopy(d1)
	r4 = originalidad.diferenciar(d4, [h1], fijo=True)
	check("si la persona eligio los giros, no se tocan", r4["cambio"] == "" and not d4.get("giros"), str(r4))
	d5 = director.normalizar(simulado.disenar("un juego de plataformas de una astronauta en marte con robots"))
	r5 = originalidad.diferenciar(d5, [h1])
	check("un juego distinto se deja como esta", r5["cambio"] == "" and r5["indice"] >= 80, str(r5))
	originalidad.anotar(d1)
	check("anotar guarda la huella", len(originalidad.huellas(d1["genero"])) == 1)
	enviados = []
	originalidad.remoto = lambda g, h: enviados.append((g, h))
	originalidad.anotar(d3)
	originalidad.remoto = None
	check("y la manda al servidor si hay", len(enviados) == 1 and enviados[0][0] == d3["genero"])
	originalidad.guardar_servidor([{**h3, "genero": d3["genero"]}])
	check("lee las huellas del servidor", len(originalidad.huellas(d3["genero"])) == 2)
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
