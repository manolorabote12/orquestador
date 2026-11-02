"""Descifra la clave .p8 de App Store Connect que guardo la funcion apple-setup (AES-256-GCM,
clave = SHA-256 de ORQ_LLAVES_SECRETO; formato: 12 bytes de IV + cifrado con etiqueta)."""

import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def descifrar(datos: bytes, secreto: str | None = None) -> str:
	secreto = secreto if secreto is not None else os.environ.get("ORQ_LLAVES_SECRETO", "")
	if len(secreto) < 24:
		raise ValueError("Falta ORQ_LLAVES_SECRETO")
	k = hashlib.sha256(secreto.encode("utf-8")).digest()
	return AESGCM(k).decrypt(datos[:12], datos[12:], None).decode("utf-8")
