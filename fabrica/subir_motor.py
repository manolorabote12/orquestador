"""Sube el motor web de Godot (comun a todos los juegos) al bucket publico "motor".

Se hace UNA vez por version de Godot. Cada juego solo sube su index.pck (~1 MB); la app carga
el motor desde aqui y el paquete del juego desde su URL firmada.

	export SUPABASE_URL=https://xxxx.supabase.co
	export SUPABASE_SERVICE_ROLE_KEY=...      (secreto: solo en tu PC)
	python -m subir_motor ../orqkit/build/web
	python -m subir_motor ../orqkit/build/web --solo-listar

La carpeta es la salida de: godot --headless --path orqkit --export-release "Web" build/web/index.html
"""

import argparse
import os
import sys
from pathlib import Path

from trabajador import Supabase

VERSION_GODOT = "4.6.3"
## Lo unico que necesita el navegador del motor; index.html y index.pck no (son de cada juego).
ARCHIVOS = ["index.js", "index.wasm", "index.audio.worklet.js", "index.audio.position.worklet.js"]


def archivos_motor(carpeta: Path) -> list[Path]:
	faltan = [n for n in ARCHIVOS[:2] if not (carpeta / n).exists()]
	if faltan:
		raise FileNotFoundError(f"Faltan {faltan} en {carpeta}: exporta antes el preset Web del kit")
	return [carpeta / n for n in ARCHIVOS if (carpeta / n).exists()]


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Sube el motor web de Godot al bucket 'motor'")
	p.add_argument("carpeta", help="Carpeta con index.js e index.wasm exportados")
	p.add_argument("--version", default=VERSION_GODOT)
	p.add_argument("--solo-listar", action="store_true")
	a = p.parse_args(argv)
	try:
		lista = archivos_motor(Path(a.carpeta))
	except FileNotFoundError as e:
		print(e, file=sys.stderr)
		return 1
	for f in lista:
		print(f"godot/{a.version}/{f.name}  {f.stat().st_size / 1e6:.1f} MB")
	if a.solo_listar:
		return 0
	url = os.environ.get("SUPABASE_URL", "")
	clave = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
	if not url or not clave:
		print("Faltan SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
		return 2
	sb = Supabase(url, clave)
	for f in lista:
		sb.subir(f"godot/{a.version}/{f.name}", f, bucket="motor")
	print(f"Motor listo. En la app: VITE_MOTOR_URL={url}/storage/v1/object/public/motor/godot/{a.version}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
