"""Llave de subida (upload key) de cada usuario.

Google Play firma las apps con su propia llave (Play App Signing); nosotros solo firmamos con
una LLAVE DE SUBIDA. Una por usuario sirve para todos sus juegos. Si se perdiera, Google deja
cambiarla desde Play Console, asi que no es el desastre de perder la llave de firma de antes.

La llave se guarda CIFRADA (AES, Fernet) con ORQ_LLAVES_SECRETO, que solo tiene el trabajador.
El usuario puede bajarse una copia desde la app (lleva su contrasena aparte).
"""

import base64
import hashlib
import json
import os
import secrets
import subprocess
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken

ALIAS = "upload"


class ErrorFirma(Exception):
	pass


def _fernet() -> Fernet:
	secreto = os.environ.get("ORQ_LLAVES_SECRETO", "")
	if len(secreto) < 24:
		raise ErrorFirma("Falta ORQ_LLAVES_SECRETO (24 caracteres o mas) en el trabajador")
	return Fernet(base64.urlsafe_b64encode(hashlib.sha256(secreto.encode("utf-8")).digest()))


def crear(destino: Path, nombre: str) -> dict:
	"""Crea un almacen .jks con la llave de subida. Devuelve {ruta, alias, clave, huella_sha256}."""
	destino.parent.mkdir(parents=True, exist_ok=True)
	if destino.exists():
		destino.unlink()
	clave = secrets.token_urlsafe(18)
	cn = "".join(c for c in nombre if c.isalnum() or c in " -_")[:40] or "Orquestador"
	r = subprocess.run(["keytool", "-genkeypair", "-keystore", str(destino), "-storetype", "PKCS12", "-alias", ALIAS,
		"-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-storepass", clave, "-keypass", clave,
		"-dname", f"CN={cn}, O=Orquestador, C=ES"], capture_output=True, text=True)
	if r.returncode != 0 or not destino.exists():
		raise ErrorFirma("keytool no pudo crear la llave: " + (r.stdout + r.stderr)[-400:])
	return {"ruta": str(destino), "alias": ALIAS, "clave": clave, "huella_sha256": huella(destino, clave)}


def huella(jks: Path, clave: str) -> str:
	"""SHA-256 del certificado (Play Console la ensena para comprobar que la llave es la buena)."""
	r = subprocess.run(["keytool", "-list", "-v", "-keystore", str(jks), "-alias", ALIAS, "-storepass", clave],
		capture_output=True, text=True)
	for linea in r.stdout.splitlines():
		if "SHA256:" in linea:
			return linea.split("SHA256:", 1)[1].strip()
	raise ErrorFirma("No se pudo leer la huella de la llave")


def cifrar(info: dict) -> bytes:
	"""Llave + contrasena en un solo paquete cifrado para guardarlo en el almacen privado."""
	datos = {"alias": info["alias"], "clave": info["clave"], "huella_sha256": info["huella_sha256"],
		"jks": base64.b64encode(Path(info["ruta"]).read_bytes()).decode("ascii")}
	return _fernet().encrypt(json.dumps(datos).encode("utf-8"))


def descifrar(paquete: bytes, destino: Path) -> dict:
	try:
		datos = json.loads(_fernet().decrypt(paquete).decode("utf-8"))
	except InvalidToken as e:
		raise ErrorFirma("La llave no se puede abrir con este ORQ_LLAVES_SECRETO") from e
	destino.parent.mkdir(parents=True, exist_ok=True)
	destino.write_bytes(base64.b64decode(datos["jks"]))
	return {"ruta": str(destino), "alias": datos["alias"], "clave": datos["clave"], "huella_sha256": datos["huella_sha256"]}
