"""Claves de texto del kit: una misma clave no puede significar cosas distintas en dos generos.
(Si pasa, en los otros idiomas uno de los dos juegos ensena el texto del otro: le paso a flechas
con artilleria.) Compara los textos por defecto de Kit.text("clave", "texto") de cada kit."""
import collections, re, sys, unicodedata
from pathlib import Path

KIT = Path(__file__).resolve().parents[2] / "orqkit" / "kit"
## Claves que comparten varios generos a proposito con textos casi iguales.
PERMITIDAS = {"liga_error", "liga_not_saved"}
fallos = 0


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FAIL ") + nombre + ("" if ok else "  (" + detalle + ")"))
	if not ok:
		fallos += 1


def normal(t: str) -> str:
	t = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), t)
	t = "".join(c for c in unicodedata.normalize("NFD", t.lower()) if unicodedata.category(c) != "Mn")
	return re.sub(r"[^a-z0-9{}]+", " ", t).strip()


usos: dict[str, dict[str, set]] = collections.defaultdict(lambda: collections.defaultdict(set))
for f in KIT.rglob("*.gd"):
	partes = f.relative_to(KIT).parts
	dueno = partes[0] if len(partes) > 1 and partes[0] != "ui" else "comun"
	for k, v in re.findall(r'Kit\.text\("([a-z0-9_]+)",\s*"((?:[^"\\]|\\.)*)"', f.read_text(encoding="utf-8")):
		usos[k][normal(v)].add(dueno)
choques = []
for k, textos in usos.items():
	if k in PERMITIDAS or len(textos) < 2:
		continue
	duenos = set().union(*textos.values())
	if len(duenos - {"comun"}) >= 2 or (len(duenos) >= 2 and len(textos) >= 2):
		choques.append(f"{k}: " + " | ".join(f"{sorted(d)}={t[:40]}" for t, d in textos.items()))
check("ninguna clave significa dos cosas en dos generos", not choques, "; ".join(choques[:6]))
print(f"== {fallos} fallos ==")
sys.exit(1 if fallos else 0)
