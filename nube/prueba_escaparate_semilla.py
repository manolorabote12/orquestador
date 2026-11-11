"""Reglas del Escaparate de muestra sin red: python3 nube/prueba_escaparate_semilla.py"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import escaparate_semilla as s  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


check("sin saldo conocido no se encarga nada", s.cuantos_caben(10, None, 3) == 0)
check("con 9,67 $ y reserva 3 caben 19", s.cuantos_caben(25, 9.67, 3) == 19, str(s.cuantos_caben(25, 9.67, 3)))
check("se respeta lo pedido", s.cuantos_caben(10, 9.67, 3) == 10)
check("saldo bajo la reserva: nada", s.cuantos_caben(10, 2.5, 3) == 0)
check("nunca mas del maximo", s.cuantos_caben(500, 1000, 3) == s.MAXIMO)
check("pedido negativo: nada", s.cuantos_caben(-4, 50, 3) == 0)
check("hay ideas para el maximo", len(s.IDEAS) >= s.MAXIMO and len(set(s.IDEAS)) == len(s.IDEAS))
check("ideas validas para la fabrica (15-700 letras)", all(15 <= len(i) <= 700 for i in s.IDEAS))
check("no repite ideas ya encargadas", s.elegir(3, {s.IDEAS[0], s.IDEAS[2]}) == [s.IDEAS[1], s.IDEAS[3], s.IDEAS[4]])
check("elige en orden", s.elegir(2, set()) == s.IDEAS[:2])

print("== %d fallos ==" % len(fallos))
sys.exit(1 if fallos else 0)
