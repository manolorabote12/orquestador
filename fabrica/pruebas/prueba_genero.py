"""Prueba del generador de generos: crea uno temporal, fabrica un juego con el y lo deshace.

	python -m pruebas.prueba_genero

Comprueba que la plantilla sigue encajando con el kit, la cadena, el taller y el servidor, y
que --quitar deja todo exactamente como estaba.
"""

import hashlib
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
KIT = RAIZ.parent / "orqkit"
TOCADOS = [RAIZ / "generos.py", RAIZ / "niveles" / "generador.py", RAIZ / "director" / "diseno.schema.json",
	RAIZ / "director" / "cambios.schema.json", KIT / "kit" / "genres.gd",
	RAIZ.parent / "supabase" / "functions" / "_shared" / "cambios-datos.ts"]


def huella() -> str:
	h = hashlib.sha256()
	for p in TOCADOS:
		h.update(p.read_bytes())
	return h.hexdigest()


def main() -> int:
	fallos = 0
	antes = huella()
	base = [sys.executable, "-m", "nuevo_genero", "rejillaprueba", "gridtest"]
	try:
		r = subprocess.run(base + ["--claves", "rejillaprueba", "--probar"], cwd=RAIZ, capture_output=True, text=True, timeout=1200)
		ok = r.returncode == 0 and "PRUEBA SUPERADA" in r.stdout
		print(("  ok  " if ok else "  FALLO ") + "genero nuevo creado, fabricado y superado por su bot")
		if not ok:
			print((r.stdout + r.stderr)[-2000:])
			fallos += 1
	finally:
		subprocess.run(base + ["--quitar"], cwd=RAIZ, capture_output=True, text=True)
	ok = huella() == antes and not (KIT / "kit" / "gridtest").exists() and not (KIT / "scenes" / "gridtest.tscn").exists()
	print(("  ok  " if ok else "  FALLO ") + "--quitar lo deja todo como estaba")
	fallos += 0 if ok else 1
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
