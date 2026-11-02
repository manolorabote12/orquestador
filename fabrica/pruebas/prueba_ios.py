"""App Store sin Mac: el script del Mac de GitHub con Godot real para abrir el juego y un xcodebuild
falso (comprueba firma automatica con la clave del usuario y la subida). Tambien comprueba que la
clave .p8 cifrada por el servidor (TypeScript) se descifra aqui (Python).

	python -m pruebas.prueba_ios
"""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


P8 = "-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgPRUEBA\n-----END PRIVATE KEY-----"
SECRETO = "s" * 40


def cifrar_con_typescript(texto: str) -> bytes:
	"""Cifra con el mismo codigo que la funcion apple-setup (esbuild + node)."""
	d = Path(tempfile.mkdtemp())
	esb = RAIZ.parent / "app" / "node_modules" / ".bin" / "esbuild"
	subprocess.run([str(esb), str(RAIZ.parent / "supabase" / "functions" / "_shared" / "cifrado.ts"), "--format=esm",
		f"--outfile={d / 'cifrado.mjs'}", "--log-level=error"], check=True)
	(d / "c.mjs").write_text("import { cifrar } from './cifrado.mjs';\n"
		f"const b = await cifrar({json.dumps(texto)}, {json.dumps(SECRETO)});\nprocess.stdout.write(Buffer.from(b).toString('base64'));\n")
	import base64
	return base64.b64decode(subprocess.run(["node", str(d / "c.mjs")], capture_output=True, text=True, check=True).stdout)


def main() -> int:
	from apple import llave
	print("== Clave .p8 cifrada ==")
	cifrada = cifrar_con_typescript(P8)
	check("TypeScript cifra -> Python descifra", llave.descifrar(cifrada, SECRETO) == P8)
	try:
		llave.descifrar(cifrada, "x" * 40)
		check("con otro secreto no se descifra", False)
	except Exception:
		check("con otro secreto no se descifra", True)

	print("== Mac de GitHub (xcodebuild simulado) ==")
	import cadena
	import trabajador
	from pruebas.prueba_trabajador import SupabaseFalso
	tmp = Path(tempfile.mkdtemp())
	inf = cadena.fabricar(__import__("argparse").Namespace(idea="un gato ninja que salta por tejados", salida=str(tmp / "f"),
		simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=3, apk=False, capturas=False))
	zipf = trabajador.comprimir_proyecto(Path(inf["proyecto"]), tmp / "bigotes_godot.zip")
	## Herramientas falsas: godot real salvo la exportacion iOS (sin plantillas aqui) y xcodebuild.
	bin_d = tmp / "bin"
	bin_d.mkdir()
	real = shutil.which("godot")
	(bin_d / "godot").write_text(f"""#!/bin/bash
if [[ "$*" == *"--export-release iOS"* ]]; then mkdir -p "${{@: -1}}"; echo "$@" > {tmp}/godot_ios.txt; exit 0; fi
exec {real} "$@"
""")
	(bin_d / "xcodebuild").write_text(f"""#!/bin/bash
echo "$@" >> {tmp}/xcodebuild.txt
for a in "$@"; do if [[ "$a" == *.xcarchive ]]; then mkdir -p "$a"; fi; done
if [[ "$*" == *"-exportOptionsPlist"* ]]; then cp "${{@: -7}}" {tmp}/opciones.plist 2>/dev/null; fi
exit 0
""")
	for f in bin_d.iterdir():
		f.chmod(f.stat().st_mode | stat.S_IEXEC)
	os.environ["PATH"] = f"{bin_d}:{os.environ['PATH']}"
	os.environ["GODOT"] = str(bin_d / "godot")
	os.environ["ORQ_LLAVES_SECRETO"] = SECRETO

	class SbIOS(SupabaseFalso):
		def rpc(self, funcion, **p):
			self.rpcs.append((funcion, p))
			if funcion == "claim_ios_job":
				return [{"job_id": p["p_job"], "user_id": "u1", "project_id": "p1", "project_version": 1, "titulo": "Bigotes",
					"project_files": {"proyecto": "u1/j/v1/bigotes_godot.zip"},
					"detail": {"equipo": "A1B2C3D4E5", "clave_id": "ABCDE12345", "emisor": "69a6de70-0000-47e3-e053-5b8c7c11a4d1",
						"clave_ruta": "apple/u1.bin", "bundle": "com.danielstudio.bigotes", "build": 7}}]
			return True

	sb = SbIOS()
	sb.archivos["juegos/u1/j/v1/bigotes_godot.zip"] = zipf.read_bytes()
	sb.archivos["llaves/apple/u1.bin"] = cifrada
	sys.path.insert(0, str(RAIZ.parent / "nube" / "ios"))
	import mac
	r = mac.main("job-ios-1", sb=sb)
	xc = (tmp / "xcodebuild.txt").read_text() if (tmp / "xcodebuild.txt").exists() else ""
	check("termina bien", r == 0)
	check("exporta el proyecto de Xcode con Godot", (tmp / "godot_ios.txt").exists())
	check("firma automatica con la clave del usuario", "-allowProvisioningUpdates" in xc and "-authenticationKeyID ABCDE12345" in xc
		and "DEVELOPMENT_TEAM=A1B2C3D4E5" in xc and "PRODUCT_BUNDLE_IDENTIFIER=com.danielstudio.bigotes" in xc)
	check("archive y exportArchive (subida)", " archive" in xc and "-exportArchive" in xc)
	fin = [p for f, p in sb.rpcs if f == "complete_ios_job"]
	check("anota la subida con su build", fin and fin[0]["p_ios"]["build"] == 7 and fin[0]["p_ios"]["estado"] == "subido")
	print(f"== {len(fallos)} fallos ==")
	shutil.rmtree(tmp, ignore_errors=True)
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
