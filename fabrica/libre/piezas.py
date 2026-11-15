"""Catalogo de piezas del kit para el Agente Estudio (libre/agente.py): lo que ya existe, probado, y se
puede usar desde un juego libre en vez de escribirlo otra vez (guardar, sonar, anuncios, temblores...).
Se saca del codigo real del kit (comentarios ## y firmas), asi nunca miente sobre lo que hay.
"""

import re
from pathlib import Path

KIT = Path(__file__).resolve().parents[2] / "orqkit"
AUTOLOADS = ["Save", "Audio", "Juice", "Ads", "UI", "Kit", "Store", "Notify"]
FIRMA = re.compile(r"^(static )?func ([a-z][a-z0-9_]*)\((.*?)\)( -> [^:]+)?:")


def _autoloads() -> dict[str, Path]:
	out: dict[str, Path] = {}
	txt = (KIT / "project.godot").read_text(encoding="utf-8")
	for m in re.finditer(r'^(\w+)="\*res://(.+?)"', txt, re.M):
		out[m.group(1)] = KIT / m.group(2)
	return out


def resumen_script(ruta: Path, max_funcs: int = 60) -> str:
	"""Cabecera (## del principio) y funciones publicas con su comentario de encima."""
	lineas = ruta.read_text(encoding="utf-8", errors="replace").splitlines()
	cab: list[str] = []
	for l in lineas[:40]:
		if l.startswith("##"):
			cab.append(l[2:].strip())
		elif l.startswith(("extends", "class_name")) or not l.strip():
			continue
		elif cab:
			break
	out = [" ".join(cab)[:600]] if cab else []
	doc: list[str] = []
	n = 0
	for l in lineas:
		if l.startswith("##"):
			doc.append(l[2:].strip())
			continue
		m = FIRMA.match(l)
		if m and not m.group(2).startswith("_"):
			n += 1
			if n > max_funcs:
				break
			out.append(f"- {'static ' if m.group(1) else ''}{m.group(2)}({m.group(3)}){m.group(4) or ''}" + (f"  # {' '.join(doc)[:140]}" if doc else ""))
		if not l.startswith("##"):
			doc = []
	return "\n".join(out)


def indice() -> str:
	"""Lo que el agente ve primero: autoloads con sus funciones y la lista de sistemas del kit."""
	partes = ["# Autoloads (siempre disponibles, por su nombre)"]
	al = _autoloads()
	for nombre in AUTOLOADS:
		if nombre in al and al[nombre].exists():
			partes.append(f"\n## {nombre}  ({al[nombre].relative_to(KIT)})\n" + resumen_script(al[nombre], 40))
	partes.append("\n# Sistemas del kit (carpetas; piezas(tema='kit/<carpeta>') para ver sus archivos y funciones)")
	for d in sorted(p for p in (KIT / "kit").iterdir() if p.is_dir()):
		primero = next((f for f in sorted(d.glob("*.gd"))), None)
		cab = resumen_script(primero, 0).split("\n")[0][:160] if primero else ""
		partes.append(f"- kit/{d.name}: {cab}")
	return "\n".join(partes)


def tema(t: str) -> str:
	t = t.strip().strip("/").removeprefix("res://")
	if not t:
		return indice()
	ruta = (KIT / t).resolve()
	if not str(ruta).startswith(str(KIT)):
		return "Ruta fuera del kit"
	if ruta.is_dir():
		return "\n\n".join(f"## {f.relative_to(KIT)}\n" + resumen_script(f) for f in sorted(ruta.glob("*.gd")))[:14000]
	if ruta.suffix == ".gd" and ruta.exists():
		return resumen_script(ruta, 120)
	return "No existe: " + t
