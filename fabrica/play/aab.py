"""El .aab que pide Google Play: compilado con Gradle, apuntando a Android 16 (API 36, obligatorio
para apps nuevas y actualizaciones desde el 31 de agosto de 2026) y firmado con la llave de subida.

	python -m play.aab <proyecto> --paquete com.tuestudio.tujuego --version 3

Requisitos en el PC o el trabajador (una vez):
	- Plantillas de exportacion de Godot 4.6.3 completas (traen android_source.zip).
	- SDK de Android con la plataforma 36 y build-tools 36, y JDK 17 o mas.
	- Internet la primera vez: Gradle se descarga a si mismo y sus dependencias.

La contrasena de la llave va por variables de entorno (GODOT_ANDROID_KEYSTORE_RELEASE_*), nunca
se escribe en export_presets.cfg: el proyecto que se guarda en la nube no lleva secretos.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
if str(RAIZ) not in sys.path:
	sys.path.insert(0, str(RAIZ))

import cadena  # noqa: E402
import iconos  # noqa: E402

API_OBJETIVO = 36
API_MINIMA = 24
PAQUETE = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$")


class ErrorAab(Exception):
	pass


def paquete_valido(p: str) -> bool:
	"""Formato de Google: 3 partes o mas, minusculas, cada parte empieza por letra; sin 'com.example'."""
	return bool(PAQUETE.match(p)) and not p.startswith("com.example") and len(p) <= 150


def preparar(proyecto: Path, paquete: str, version: int, titulo: str) -> None:
	"""Plantilla de Gradle + opciones del preset de Android para un .aab de tienda."""
	if not paquete_valido(paquete):
		raise ErrorAab(f"Nombre de paquete no valido para Google Play: {paquete}")
	if not (proyecto / "android" / "build").exists():
		r = cadena.godot(proyecto, "--install-android-build-template", "--quit", timeout=600)
		if not (proyecto / "android" / "build").exists():
			raise ErrorAab("No se pudo instalar la plantilla de Android (faltan las plantillas completas de Godot "
				"con android_source.zip): " + (r.stdout + r.stderr)[-500:])
	iconos.poner_opciones_android(proyecto, {
		"gradle_build/use_gradle_build": True,
		"gradle_build/export_format": 1,
		"gradle_build/min_sdk": str(API_MINIMA),
		"gradle_build/target_sdk": str(API_OBJETIVO),
		"package/unique_name": paquete,
		"package/name": titulo,
		"package/signed": True,
		"version/code": int(version),
		"version/name": f"1.{max(0, int(version) - 1)}",
	})


def exportar(proyecto: Path, llave: dict, salida: Path) -> Path:
	salida.parent.mkdir(parents=True, exist_ok=True)
	if salida.exists():
		salida.unlink()
	env = dict(os.environ,
		GODOT_ANDROID_KEYSTORE_RELEASE_PATH=llave["ruta"],
		GODOT_ANDROID_KEYSTORE_RELEASE_USER=llave["alias"],
		GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=llave["clave"])
	cmd = [cadena.godot_bin(), "--headless", "--path", str(proyecto), "--export-release", "Android", str(salida)]
	r = subprocess.run(cmd, capture_output=True, text=True, timeout=2400, env=env)
	if not salida.exists():
		raise ErrorAab("Gradle no genero el .aab: " + (r.stdout + r.stderr)[-1500:])
	return salida


def generar(proyecto: Path, paquete: str, version: int, llave: dict) -> Path:
	import json
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	preparar(proyecto, paquete, version, diseno["titulo"])
	return exportar(proyecto, llave, proyecto / "build" / f"{cadena.director.slug(diseno)}.aab")


def main() -> int:
	from play import firma
	p = argparse.ArgumentParser(description=".aab firmado para Google Play")
	p.add_argument("proyecto")
	p.add_argument("--paquete", required=True)
	p.add_argument("--version", type=int, default=1)
	p.add_argument("--llave", help="Almacen .jks (si no, se crea uno nuevo en build/upload.jks)")
	p.add_argument("--clave", help="Contrasena del almacen")
	a = p.parse_args()
	proyecto = Path(a.proyecto)
	if a.llave:
		llave = {"ruta": a.llave, "alias": firma.ALIAS, "clave": a.clave or ""}
	else:
		llave = firma.crear(proyecto / "build" / "upload.jks", "Orquestador")
		print(f"Llave de subida nueva: {llave['ruta']}  contrasena: {llave['clave']}  (guardala)")
	try:
		print(generar(proyecto, a.paquete, a.version, llave))
	except ErrorAab as e:
		print("ERROR:", e)
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main())
