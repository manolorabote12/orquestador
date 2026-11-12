"""Prueba del aprendizaje por experimentos (experimentos.py): python -m pruebas.prueba_experimentos"""

import random

import experimentos as X

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


check("genero sin mandos: nada", X.elegir("sudoku", []) == {})
e = X.elegir("plataformas", [], random.Random(1))
check("una opcion por mando", set(e) == {"zoom", "sprite", "piezas"} and all(e[k] in X.MANDOS["plataformas"][k] for k in e), str(e))
## Historial donde zoom 1.15 saca 9 y el resto 4: tras muchos sorteos, 1.15 gana casi siempre.
hist = [{"eleccion": {"zoom": z}, "nota": 9 if z == 1.15 else 4, "problemas": []} for z in [1.0, 0.9, 1.15] * 6]
rng = random.Random(7)
ganas = sum(1 for _ in range(400) if X.elegir("plataformas", hist, rng)["zoom"] == 1.15)
check("aprende la mejor opcion", ganas > 300, f"{ganas}/400")
check("pero sigue probando las otras", ganas < 400, f"{ganas}/400")
## Memoria de la critica: «personaje pequeno» repetido empuja el sprite grande sin datos.
hist2 = [{"eleccion": {}, "nota": 5, "problemas": ["personaje_pequeno"]}] * 3
rng = random.Random(3)
grandes = sum(1 for _ in range(400) if X.elegir("plataformas", hist2, rng)["sprite"] == 1.15)
check("la critica repetida empuja la opcion que lo corrige", grandes > 180, f"{grandes}/400")
## Sin servidor no se experimenta ni se apunta.
X.remoto_historial = None
check("sin servidor, sin experimento", X.para_juego("plataformas") == {})
apuntes = []
X.remoto_historial = lambda g: []
X.remoto_anotar = lambda *a: apuntes.append(a)
el = X.para_juego("runner")
X.anotar("runner", el, 8, ["fondo_vacio"])
check("con servidor elige y apunta", bool(el) and apuntes and apuntes[0][2] == 8, str(apuntes))
X.remoto_historial = lambda g: (_ for _ in ()).throw(RuntimeError("caido"))
check("servidor caido: elige igual", bool(X.para_juego("runner")))
check("resumen legible", any("zoom ->" in r for r in X.resumen(hist, "plataformas")), str(X.resumen(hist, "plataformas")))
print(f"== {len(fallos)} fallos ==")
raise SystemExit(1 if fallos else 0)
