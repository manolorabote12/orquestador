"""Reglas puras del reparto de la galeria: python3 nube/prueba_galeria.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import galeria as g  # noqa: E402

fallos = 0


def check(n: str, ok: bool) -> None:
	global fallos
	print(("  OK   " if ok else "  FAIL ") + n)
	fallos += 0 if ok else 1


check("mes valido", g.mes_valido("2026-11") == "2026-11-01")
for malo in ("2026-13", "26-11", "2026/11", ""):
	try:
		g.mes_valido(malo)
		check(f"mes {malo!r} rechazado", False)
	except ValueError:
		check(f"mes {malo!r} rechazado", True)
check("12,34 euros", g.centimos("12,34") == 1234)
check("12.3 euros", g.centimos("12.3") == 1230)
check("0 euros", g.centimos("0") == 0)
for malo in ("-3", "abc", "1,234", ""):
	try:
		g.centimos(malo)
		check(f"cantidad {malo!r} rechazada", False)
	except ValueError:
		check(f"cantidad {malo!r} rechazada", True)
print(f"== {fallos} fallos ==")
sys.exit(1 if fallos else 0)
