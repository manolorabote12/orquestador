"""Reglas del vigilante sin red: python3 nube/prueba_vigilante.py"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import vigilante  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


u = vigilante.umbrales()
tranquilo = {"pausada": False, "hora_usd": 0.4, "dia_usd": 1.2, "presupuesto_dia_usd": 20, "en_marcha": 1, "en_cola": 0,
	"juegos_dia": 3, "fallidos_dia": 0, "caros": [], "fallos_recientes": []}
d = vigilante.decidir(tranquilo, {"currentSpendPerHr": 1.3, "clientBalance": 20}, u)
check("dia normal: ni alarmas ni parada", not d["alarmas"] and not d["pausar"], str(d))
d = vigilante.decidir(dict(tranquilo, hora_usd=5.2), None, u)
check("hora cara: para la fabrica", d["pausar"] and "5.20" in d["pausar"] and d["alarmas"], str(d["alarmas"]))
d = vigilante.decidir(tranquilo, {"currentSpendPerHr": 9.0}, u)
check("RunPod disparado: para la fabrica", d["pausar"] and "9.00" in d["pausar"])
d = vigilante.decidir(dict(tranquilo, pausada=True, hora_usd=9), {"currentSpendPerHr": 9.0}, u)
check("ya parada: no la vuelve a parar (ni correo cada 15 min)", not d["pausar"] and not d["alarmas"] and d["avisos"])
d = vigilante.decidir(dict(tranquilo, caros=[{"id": "x", "kind": "game", "usd": 1.4, "status": "done"}]), None, u)
check("juego caro: avisa sin parar", d["alarmas"] and not d["pausar"])
d = vigilante.decidir(dict(tranquilo, fallos_recientes=[{"kind": "game", "error": "a"}, {"kind": "game", "error": "b"}]), None, u)
check("dos fallos seguidos: avisa", len(d["alarmas"]) == 1)
d = vigilante.decidir(dict(tranquilo, en_marcha=0), {"currentSpendPerHr": 1.34}, u)
check("GPU encendida sin trabajos: avisa", any("sin ningun trabajo" in a for a in d["alarmas"]))
d = vigilante.decidir(dict(tranquilo, en_marcha=0), {"currentSpendPerHr": 0.01}, u)
check("el disco de modelos (0,01 $/h) no es una fuga", not d["alarmas"])
d = vigilante.decidir(tranquilo, {"currentSpendPerHr": 0, "clientBalance": 1.5}, u)
check("saldo bajo: aviso amarillo, sin correo", d["avisos"] and not d["alarmas"])
print(f"== {len(fallos)} fallos ==")
sys.exit(1 if fallos else 0)
