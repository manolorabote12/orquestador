"""Memoria y versiones de un juego fabricado.

fabrica/memoria.json   historial de instrucciones (lo que la IA lee para no olvidar el contexto)
fabrica/versiones/vN/  copia de lo que define la version N: game.json, icono, diseno, Biblia y assets
Volver a una version copia su instantanea y la registra como version nueva (nada se pierde).
"""

import json
import shutil
import time
from pathlib import Path

ARCHIVOS = ["game.json", "icon.png", "fabrica/diseno.json", "fabrica/biblia.json"]
CARPETAS = ["assets", "mods"]


def _ruta_memoria(proyecto: Path) -> Path:
	return proyecto / "fabrica" / "memoria.json"


def memoria(proyecto: Path) -> dict:
	p = _ruta_memoria(proyecto)
	if p.exists():
		return json.loads(p.read_text(encoding="utf-8"))
	return {"version": 0, "historial": []}


def _guardar_memoria(proyecto: Path, mem: dict) -> None:
	_ruta_memoria(proyecto).write_text(json.dumps(mem, indent=1, ensure_ascii=False), encoding="utf-8")


def instantanea(proyecto: Path, n: int) -> Path:
	destino = proyecto / "fabrica" / "versiones" / f"v{n}"
	if destino.exists():
		shutil.rmtree(destino)
	destino.mkdir(parents=True)
	for a in ARCHIVOS:
		if (proyecto / a).exists():
			(destino / a).parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(proyecto / a, destino / a)
	for c in CARPETAS:
		if (proyecto / c).exists():
			shutil.copytree(proyecto / c, destino / c)
	return destino


def anotar(proyecto: Path, instruccion: str, resumen: str, operaciones: list, coste: int, extra: dict | None = None) -> int:
	"""Registra la version nueva (ya aplicada en el proyecto) y guarda su instantanea."""
	mem = memoria(proyecto)
	n = int(mem["version"]) + 1
	entrada = {"version": n, "instruccion": instruccion, "resumen": resumen, "operaciones": operaciones,
		"coste": coste, "fecha": time.strftime("%Y-%m-%d %H:%M")}
	entrada.update(extra or {})
	mem["version"] = n
	mem["historial"].append(entrada)
	_guardar_memoria(proyecto, mem)
	instantanea(proyecto, n)
	return n


def restaurar(proyecto: Path, n: int) -> None:
	"""Copia la instantanea de la version n sobre el proyecto (sin registrar nada)."""
	origen = proyecto / "fabrica" / "versiones" / f"v{n}"
	if not origen.exists():
		raise FileNotFoundError(f"No existe la version {n}")
	for c in CARPETAS:
		if (proyecto / c).exists():
			shutil.rmtree(proyecto / c)
		if (origen / c).exists():
			shutil.copytree(origen / c, proyecto / c)
	for a in ARCHIVOS:
		if (origen / a).exists():
			shutil.copy2(origen / a, proyecto / a)
