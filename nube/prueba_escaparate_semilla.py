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

I = s.IDEAS
J = lambda st, i, err="": {"status": st, "detail": {"idea": I[i]}, "error": err}  # noqa: E731
check("nada en marcha: la primera idea", s.siguiente([], 10) == I[0])
check("uno en cola: espera", s.siguiente([J("queued", 0)], 10) is None)
check("uno en marcha: espera", s.siguiente([J("done", 0), J("running", 1)], 10) is None)
check("terminado: el siguiente", s.siguiente([J("done", 0)], 10) == I[1])
check("objetivo cumplido: nada", s.siguiente([J("done", 0), J("done", 1)], 2) is None)
check("un fallo: se reintenta la misma", s.siguiente([J("failed", 0, "x")], 10) == I[0])
check("dos fallos de una idea: se salta", s.siguiente([J("failed", 0, "x"), J("failed", 0, "x")], 10) == I[1])
check("cancelados no cuentan como fallo", s.siguiente([J("failed", 0, "cancelado")] * 5, 10) == I[0])
check("muchos fallos seguidos: para de gastar", s.siguiente([J("failed", 0, "x"), J("failed", 0, "x"), J("failed", 1, "y")], 4) is None)

F = lambda i, arte, cuando="2026-12-01T00:00:00Z": {"status": "failed", "detail": {"idea": I[i]}, "error": "x", "created_at": cuando,  # noqa: E731
	"result": {"diseno": {"titulo": "T%d" % i}}, "progress": [{"paso": "arte", "estado": "ok"}] if arte else []}
check("reintento: recupera el diseno con el arte ya pagado", (s.diseno_con_arte([F(1, True), F(1, False)], I[1]) or {}).get("titulo") == "T1")
check("sin arte dibujado: diseno nuevo", s.diseno_con_arte([F(1, False)], I[1]) is None)
check("arte de antes del arreglo: no se reusa", s.diseno_con_arte([F(1, True, "2026-11-11T10:00:00Z")], I[1]) is None)
check("el de otra idea no vale", s.diseno_con_arte([F(2, True)], I[1]) is None)

print("== %d fallos ==" % len(fallos))
sys.exit(1 if fallos else 0)
