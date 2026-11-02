"""Compilar y subir un juego a la App Store (lo ejecuta el Mac de GitHub Actions, ver nube/ios/mac.py).

	1 - preset "iOS" de Godot en el proyecto: identificador, version, equipo, solo proyecto de Xcode;
	2 - godot --export-release "iOS" -> proyecto de Xcode;
	3 - xcodebuild archive con firma automatica (clave de la API de App Store Connect del usuario);
	4 - xcodebuild -exportArchive con destination=upload: lo sube a App Store Connect (TestFlight).
La ficha de la tienda (textos, icono 1024 y capturas de 6,9") ya la genera ficha.py en appstore/.
"""

import plistlib
import re
import subprocess
from pathlib import Path

PRESET = """
[preset.{n}]

name="iOS"
platform="iOS"
runnable=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json, kit/words/dicts/*.txt"
exclude_filter="qa/*, addons/admob/assets/*, addons/admob/internal/editor/*, addons/admob/downloads/*"
export_path="build/ios/{nombre}.xcodeproj"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{n}.options]

application/app_store_team_id="{equipo}"
application/export_method_release=0
application/bundle_identifier="{bundle}"
application/short_version="{version}"
application/version="{build}"
application/min_ios_version="14.0"
application/targeted_device_family=2
application/export_project_only=true
"""


class ErrorIOS(Exception):
	pass


def nombre_xcode(titulo: str) -> str:
	n = re.sub(r"[^A-Za-z0-9]", "", titulo.title())[:30]
	return n or "Juego"


def poner_preset(proyecto: Path, equipo: str, bundle: str, version: str, build: int, nombre: str) -> None:
	ruta = proyecto / "export_presets.cfg"
	texto = ruta.read_text(encoding="utf-8") if ruta.exists() else ""
	## Quita un preset iOS anterior y anade el nuevo con el siguiente numero.
	bloques = re.split(r"(?=^\[preset\.\d+\]\s*$)", texto, flags=re.M)
	conservados = []
	for b in bloques:
		if not b.strip():
			continue
		if re.search(r'^platform="iOS"', b, flags=re.M):
			continue
		conservados.append(b)
	## Las opciones van en su propio bloque [preset.N.options]: se vuelven a numerar juntos.
	presets: list[tuple[str, str]] = []
	for b in conservados:
		m = re.match(r"\[preset\.(\d+)(\.options)?\]", b.strip())
		if not m:
			continue
		if m.group(2):
			presets[-1] = (presets[-1][0], b)
		else:
			presets.append((b, ""))
	out = []
	for i, (cab, opc) in enumerate(presets):
		out.append(re.sub(r"^\[preset\.\d+\]", f"[preset.{i}]", cab.strip(), count=1, flags=re.M))
		if opc:
			out.append(re.sub(r"^\[preset\.\d+\.options\]", f"[preset.{i}.options]", opc.strip(), count=1, flags=re.M))
	out.append(PRESET.format(n=len(presets), equipo=equipo, bundle=bundle, version=version, build=build, nombre=nombre).strip())
	ruta.write_text("\n\n".join(out) + "\n", encoding="utf-8")


def opciones_exportar(equipo: str, destino: Path) -> Path:
	destino.write_bytes(plistlib.dumps({
		"method": "app-store-connect", "destination": "upload", "teamID": equipo,
		"signingStyle": "automatic", "uploadSymbols": True, "manageAppVersionAndBuildNumber": False,
	}))
	return destino


def auth_args(clave_p8: Path, clave_id: str, emisor: str) -> list[str]:
	return ["-allowProvisioningUpdates", "-authenticationKeyPath", str(clave_p8),
		"-authenticationKeyID", clave_id, "-authenticationKeyIssuerID", emisor]


def compilar_y_subir(proyecto: Path, equipo: str, bundle: str, clave_p8: Path, clave_id: str, emisor: str, nombre: str,
		godot: str = "godot", aviso=print) -> dict:
	build = proyecto / "build" / "ios"
	build.mkdir(parents=True, exist_ok=True)
	aviso("Exportando el proyecto de Xcode...")
	r = subprocess.run([godot, "--headless", "--path", str(proyecto), "--export-release", "iOS", str(build / f"{nombre}.xcodeproj")],
		capture_output=True, text=True, timeout=1800)
	xcodeproj = build / f"{nombre}.xcodeproj"
	if not xcodeproj.exists():
		raise ErrorIOS("Godot no exporto el proyecto de Xcode: " + (r.stderr or r.stdout)[-600:])
	archivo = build / f"{nombre}.xcarchive"
	aviso("Compilando y firmando con tu cuenta de Apple...")
	r = subprocess.run(["xcodebuild", "-project", str(xcodeproj), "-scheme", nombre, "-configuration", "Release",
		"-destination", "generic/platform=iOS", "-archivePath", str(archivo), "archive",
		f"DEVELOPMENT_TEAM={equipo}", "CODE_SIGN_STYLE=Automatic", f"PRODUCT_BUNDLE_IDENTIFIER={bundle}"]
		+ auth_args(clave_p8, clave_id, emisor), capture_output=True, text=True, timeout=3600)
	if r.returncode != 0:
		raise ErrorIOS("xcodebuild archive fallo: " + _error_xcode(r.stdout + r.stderr))
	aviso("Subiendo a App Store Connect (TestFlight)...")
	r = subprocess.run(["xcodebuild", "-exportArchive", "-archivePath", str(archivo), "-exportPath", str(build / "export"),
		"-exportOptionsPlist", str(opciones_exportar(equipo, build / "ExportOptions.plist"))]
		+ auth_args(clave_p8, clave_id, emisor), capture_output=True, text=True, timeout=3600)
	if r.returncode != 0:
		raise ErrorIOS("La subida a App Store Connect fallo: " + _error_xcode(r.stdout + r.stderr))
	return {"subido": True}


def _error_xcode(salida: str) -> str:
	"""Las lineas de error de xcodebuild, traducidas cuando se conocen."""
	errores = [ln.strip() for ln in salida.splitlines() if "error:" in ln.lower()][-4:]
	texto = " | ".join(errores) or salida[-400:]
	if "No profiles for" in texto or "No Account for Team" in texto:
		texto += " (Revisa que la clave de la API tenga rol de Administrador o App Manager.)"
	if "bundle identifier" in texto.lower() and "not available" in texto.lower():
		texto += " (Crea la app en App Store Connect con ese identificador.)"
	return texto[:600]
