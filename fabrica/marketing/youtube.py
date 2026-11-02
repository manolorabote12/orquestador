"""Sube videos al canal de YouTube del usuario (YouTube Data API v3, subida reanudable).

El permiso lo da el usuario en la app (funcion youtube del servidor); aqui se usa su refresh token
con el cliente OAuth de Orquestador (GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET, solo en
el servidor). Los Shorts se suben con #Shorts; el trailer como video normal.
Se declara contenido sintetico (voz y musica generadas con IA) y que NO es para ninos.
"""

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TOKEN_URL = os.environ.get("ORQ_GOOGLE_TOKEN_URL", "https://oauth2.googleapis.com/token")
SUBIDA_URL = os.environ.get("ORQ_YOUTUBE_UPLOAD_URL", "https://www.googleapis.com/upload/youtube/v3/videos")
PRIVACIDAD = {"oculto": "unlisted", "publico": "public"}


class ErrorYoutube(Exception):
	pass


def acceso(refresh: str) -> str:
	cliente = os.environ.get("GOOGLE_OAUTH_CLIENT_ID", "")
	secreto = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET", "")
	if not cliente or not secreto:
		raise ErrorYoutube("Falta el cliente OAuth de Google (GOOGLE_OAUTH_CLIENT_ID/SECRET)")
	datos = urllib.parse.urlencode({"client_id": cliente, "client_secret": secreto, "refresh_token": refresh,
		"grant_type": "refresh_token"}).encode()
	try:
		with urllib.request.urlopen(urllib.request.Request(TOKEN_URL, data=datos, method="POST"), timeout=60) as r:
			return json.loads(r.read())["access_token"]
	except urllib.error.HTTPError as e:
		cuerpo = e.read().decode("utf-8", "replace")[:200]
		if "invalid_grant" in cuerpo:
			raise ErrorYoutube("El permiso de YouTube se ha retirado: vuelve a conectar tu canal") from e
		raise ErrorYoutube(f"Google: HTTP {e.code} {cuerpo}") from e


def subir(token: str, video: Path, titulo: str, descripcion: str, etiquetas: list[str], privacidad: str) -> str:
	"""Devuelve el id del video en YouTube."""
	meta = {
		"snippet": {"title": titulo[:100], "description": descripcion[:4900], "tags": [t.lstrip("#")[:30] for t in etiquetas][:15],
			"categoryId": "20", "defaultLanguage": "es"},
		"status": {"privacyStatus": PRIVACIDAD.get(privacidad, "unlisted"), "selfDeclaredMadeForKids": False,
			"containsSyntheticMedia": True},
	}
	tam = video.stat().st_size
	req = urllib.request.Request(f"{SUBIDA_URL}?uploadType=resumable&part=snippet,status", method="POST",
		data=json.dumps(meta).encode(), headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=UTF-8",
			"X-Upload-Content-Type": "video/mp4", "X-Upload-Content-Length": str(tam)})
	try:
		with urllib.request.urlopen(req, timeout=60) as r:
			destino = r.headers["Location"]
		with urllib.request.urlopen(urllib.request.Request(destino, data=video.read_bytes(), method="PUT",
				headers={"Content-Type": "video/mp4", "Content-Length": str(tam)}), timeout=600) as r:
			return json.loads(r.read())["id"]
	except urllib.error.HTTPError as e:
		cuerpo = e.read().decode("utf-8", "replace")[:300]
		if "quotaExceeded" in cuerpo or "uploadLimitExceeded" in cuerpo:
			raise ErrorYoutube("YouTube ha llegado al limite de subidas de hoy; prueba manana") from e
		raise ErrorYoutube(f"YouTube: HTTP {e.code} {cuerpo}") from e

