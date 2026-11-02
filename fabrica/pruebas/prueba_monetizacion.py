"""La tabla de monetizacion de la fabrica (monetizacion.py) y la del juego (orqkit/kit/monetize.gd)
dicen lo mismo: que perfil tiene cada genero y que lleva cada perfil."""
import re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import monetizacion as M  # noqa: E402

GD = (Path(__file__).resolve().parents[2] / "orqkit" / "kit" / "monetize.gd").read_text(encoding="utf-8")
fallos = 0


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FAIL ") + nombre + ("" if ok else "  (" + detalle + ")"))
	fallos += 0 if ok else 1


bloque = GD[GD.index("const KIT_PROFILE"):]
for p, kits in M.KIT_PERFIL.items():
	m = re.search(r'"%s": \[(.*?)\]' % p, bloque, re.S)
	gd_kits = re.findall(r'"([a-z0-9]+)"', m.group(1)) if m else []
	check(f"mismos generos en el perfil {p}", sorted(gd_kits) == sorted(kits), str(set(gd_kits) ^ set(kits)))
perfiles = GD[GD.index("const PROFILES"):GD.index("const KIT_PROFILE")]
for p, d in M.PERFILES.items():
	ini = perfiles.index('"%s": {' % p)
	trozo = perfiles[ini:perfiles.index('"why"', ini)]
	for k, v in d.items():
		if isinstance(v, bool):
			ok = f'"{k}": {"true" if v else "false"}' in trozo
		elif isinstance(v, list):
			m = re.search(r'"%s": \[(.*?)\]' % k, trozo, re.S)
			ok = m is not None and re.findall(r'"([a-z0-9_]+)"', m.group(1)) == v
		else:
			m = re.search(r'"%s": ([0-9.]+)' % k, trozo)
			ok = m is not None and float(m.group(1)) == float(v)
		check(f"{p}.{k} igual en el juego y en la fabrica", ok)
inf = M.informe("tower")
check("informe: torres es estrategia, sin banner y con pack de inicio", inf["perfil"] == "estrategia" and inf["banner"] == "no" and any("Pack" in c for c in inf["compras"]))
check("informe: los peques no llevan intersticial ni banner", M.informe("match3", infantil=True)["intersticial"] == "no" and "Banner" not in M.informe("match3", infantil=True)["bloques_admob"])
check("informe: idle pide el bloque de apertura de app", "Apertura de app" in M.informe("tycoon")["bloques_admob"])
check("informe: el autor puede cambiar el perfil", M.perfil("tower", propio="puzle") == "puzle")
print(f"== {fallos} fallos ==")
sys.exit(1 if fallos else 0)
