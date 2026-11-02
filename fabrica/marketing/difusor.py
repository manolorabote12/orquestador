"""Difusor: publica en las redes del usuario (o de Orquestador) con sus APIs oficiales.

Redes: Bluesky, Mastodon, Telegram (canal), Discord (webhook), Reddit (perfil y subreddits que lo
permiten) y X. Cada una con su adaptador: texto al largo de la red, etiquetas y la imagen o el
video del juego. Las claves las pone el usuario (o Orquestador para su propia cuenta) y viven solo
en el servidor; aqui llegan como un diccionario.

NADA de spam (las redes cierran cuentas por eso y la marca se quema):
1 - Solo publicaciones propias en cuentas propias: nunca respuestas automaticas a otras personas
    (las respuestas las redacta comunidad.py y las aprueba una persona).
2 - Limites por red y dia, intervalo minimo entre publicaciones y nunca el mismo texto dos veces.
3 - En Reddit solo en los subreddits que la persona apunta (y que permiten promocion propia) y como
   mucho una vez por semana en cada uno.
4 - Todo se apunta en un registro (fabrica/datos/difusor.json o el que se pase) para poder revisarlo.

Las direcciones se pueden cambiar con variables ORQ_*_URL (las pruebas usan un servidor falso).
"""

import hashlib
import json
import mimetypes
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass, field
from pathlib import Path

REGISTRO = Path(__file__).resolve().parents[1] / "datos" / "difusor.json"

## Largo maximo del texto, publicaciones al dia, minutos minimos entre dos y si admite video.
REDES: dict[str, dict] = {
	"bluesky": {"largo": 300, "dia": 4, "minutos": 90, "video": False},
	"mastodon": {"largo": 500, "dia": 4, "minutos": 90, "video": True},
	"telegram": {"largo": 1000, "dia": 6, "minutos": 60, "video": True},
	"discord": {"largo": 1900, "dia": 6, "minutos": 60, "video": True},
	"reddit": {"largo": 300, "dia": 2, "minutos": 600, "video": False},
	"x": {"largo": 280, "dia": 4, "minutos": 90, "video": False},
}
REDDIT_DIAS_POR_SUB = 7


class ErrorDifusor(Exception):
	pass


@dataclass
class Publicacion:
	texto: str
	enlace: str = ""
	titulo: str = ""
	imagen: str = ""
	video: str = ""
	etiquetas: list[str] = field(default_factory=list)


def _url(clave: str, defecto: str) -> str:
	return os.environ.get(clave, defecto)


def _http(url: str, datos: bytes | None = None, cabeceras: dict | None = None, metodo: str = "POST") -> dict:
	req = urllib.request.Request(url, data=datos, method=metodo, headers=cabeceras or {})
	try:
		with urllib.request.urlopen(req, timeout=90) as r:
			cuerpo = r.read()
	except urllib.error.HTTPError as e:
		raise ErrorDifusor(f"HTTP {e.code} en {urllib.parse.urlsplit(url).netloc}: {e.read().decode('utf-8', 'replace')[:200]}") from e
	except urllib.error.URLError as e:
		raise ErrorDifusor(f"Sin conexion con {urllib.parse.urlsplit(url).netloc}: {e.reason}") from e
	try:
		return json.loads(cuerpo or b"{}")
	except ValueError:
		return {"texto": cuerpo.decode("utf-8", "replace")[:500]}


def _json(url: str, cuerpo: dict, cabeceras: dict | None = None) -> dict:
	return _http(url, json.dumps(cuerpo).encode(), {"Content-Type": "application/json", **(cabeceras or {})})


def _multipart(campos: dict[str, str], archivos: dict[str, Path]) -> tuple[bytes, str]:
	limite = "orq" + uuid.uuid4().hex
	partes: list[bytes] = []
	for k, v in campos.items():
		partes.append(f'--{limite}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
	for k, ruta in archivos.items():
		tipo = mimetypes.guess_type(str(ruta))[0] or "application/octet-stream"
		partes.append(f'--{limite}\r\nContent-Disposition: form-data; name="{k}"; filename="{ruta.name}"\r\nContent-Type: {tipo}\r\n\r\n'.encode()
			+ ruta.read_bytes() + b"\r\n")
	partes.append(f"--{limite}--\r\n".encode())
	return b"".join(partes), f"multipart/form-data; boundary={limite}"


# ------------------------------------------------------------------ texto

def adaptar(p: Publicacion, red: str) -> str:
	"""Texto al largo de la red: frase, etiquetas que quepan y el enlace (que nunca se corta)."""
	largo = REDES[red]["largo"]
	enlace = ("\n" + p.enlace) if p.enlace and red not in ("reddit",) else ""
	etiquetas = ""
	if red not in ("reddit", "discord"):
		for e in p.etiquetas:
			e2 = " #" + "".join(ch for ch in e if ch.isalnum())
			if len(p.texto) + len(etiquetas) + len(e2) + len(enlace) <= largo:
				etiquetas += e2
	cuerpo = p.texto
	sobra = len(cuerpo) + len(etiquetas) + len(enlace) - largo
	if sobra > 0:
		cuerpo = cuerpo[:max(0, len(cuerpo) - sobra - 1)].rstrip() + "…"
	return cuerpo + etiquetas + enlace


# ------------------------------------------------------------------ registro y limites

def _leer(registro: Path) -> list[dict]:
	if registro.exists():
		try:
			return json.loads(registro.read_text(encoding="utf-8"))
		except ValueError:
			return []
	return []


def _firma(texto: str) -> str:
	return hashlib.sha256(" ".join(texto.lower().split()).encode()).hexdigest()[:16]


def puede(red: str, texto: str, registro: Path = REGISTRO, ahora: float | None = None, destino: str = "") -> str:
	"""Por que NO se puede publicar ahora ("" si se puede)."""
	if red not in REDES:
		return f"red desconocida: {red}"
	ahora = ahora or time.time()
	hechas = [r for r in _leer(registro) if r.get("red") == red and r.get("ok")]
	hoy = [r for r in hechas if ahora - r["t"] < 86400]
	if len(hoy) >= REDES[red]["dia"]:
		return f"{red}: ya van {len(hoy)} publicaciones hoy (maximo {REDES[red]['dia']})"
	if hechas and ahora - max(r["t"] for r in hechas) < REDES[red]["minutos"] * 60:
		return f"{red}: hay que esperar {REDES[red]['minutos']} minutos entre publicaciones"
	if any(r.get("firma") == _firma(texto) for r in hechas):
		return f"{red}: ese texto ya se publico (las redes lo ven como spam)"
	if red == "reddit" and destino:
		previas = [r for r in hechas if r.get("destino") == destino and ahora - r["t"] < REDDIT_DIAS_POR_SUB * 86400]
		if previas:
			return f"reddit: en r/{destino} como mucho una vez cada {REDDIT_DIAS_POR_SUB} dias"
	return ""


def _apuntar(registro: Path, fila: dict) -> None:
	registro.parent.mkdir(parents=True, exist_ok=True)
	filas = _leer(registro)[-2000:]
	filas.append(fila)
	registro.write_text(json.dumps(filas, ensure_ascii=False, indent=0), encoding="utf-8")


# ------------------------------------------------------------------ adaptadores

def _bluesky(p: Publicacion, texto: str, c: dict) -> str:
	base = _url("ORQ_BSKY_URL", "https://bsky.social")
	s = _json(f"{base}/xrpc/com.atproto.server.createSession", {"identifier": c["usuario"], "password": c["clave_app"]})
	auth = {"Authorization": f"Bearer {s['accessJwt']}"}
	registro: dict = {"$type": "app.bsky.feed.post", "text": texto, "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "langs": ["es"]}
	## El enlace, como enlace de verdad (si no, Bluesky lo deja como texto plano).
	if p.enlace and p.enlace in texto:
		ini = len(texto[:texto.index(p.enlace)].encode())
		registro["facets"] = [{"index": {"byteStart": ini, "byteEnd": ini + len(p.enlace.encode())},
			"features": [{"$type": "app.bsky.richtext.facet#link", "uri": p.enlace}]}]
	if p.imagen and Path(p.imagen).exists():
		img = Path(p.imagen)
		blob = _http(f"{base}/xrpc/com.atproto.repo.uploadBlob", img.read_bytes(),
			{**auth, "Content-Type": mimetypes.guess_type(str(img))[0] or "image/png"})
		registro["embed"] = {"$type": "app.bsky.embed.images", "images": [{"alt": p.titulo or "Captura del juego", "image": blob["blob"]}]}
	r = _json(f"{base}/xrpc/com.atproto.repo.createRecord", {"repo": s["did"], "collection": "app.bsky.feed.post", "record": registro}, auth)
	return str(r.get("uri", ""))


def _mastodon(p: Publicacion, texto: str, c: dict) -> str:
	base = c.get("instancia", "").rstrip("/") or _url("ORQ_MASTODON_URL", "https://mastodon.social")
	auth = {"Authorization": f"Bearer {c['token']}"}
	ids: list[str] = []
	medio = p.video if p.video and Path(p.video).exists() else (p.imagen if p.imagen and Path(p.imagen).exists() else "")
	if medio:
		cuerpo, tipo = _multipart({"description": p.titulo or "Juego"}, {"file": Path(medio)})
		ids.append(str(_http(f"{base}/api/v2/media", cuerpo, {**auth, "Content-Type": tipo})["id"]))
	campos = [("status", texto), ("visibility", "public")] + [("media_ids[]", i) for i in ids]
	r = _http(f"{base}/api/v1/statuses", urllib.parse.urlencode(campos).encode(),
		{**auth, "Content-Type": "application/x-www-form-urlencoded", "Idempotency-Key": _firma(texto)})
	return str(r.get("url", ""))


def _telegram(p: Publicacion, texto: str, c: dict) -> str:
	base = _url("ORQ_TELEGRAM_URL", "https://api.telegram.org") + f"/bot{c['token']}"
	if p.video and Path(p.video).exists():
		cuerpo, tipo = _multipart({"chat_id": c["canal"], "caption": texto}, {"video": Path(p.video)})
		r = _http(f"{base}/sendVideo", cuerpo, {"Content-Type": tipo})
	elif p.imagen and Path(p.imagen).exists():
		cuerpo, tipo = _multipart({"chat_id": c["canal"], "caption": texto}, {"photo": Path(p.imagen)})
		r = _http(f"{base}/sendPhoto", cuerpo, {"Content-Type": tipo})
	else:
		r = _json(f"{base}/sendMessage", {"chat_id": c["canal"], "text": texto})
	return str((r.get("result") or {}).get("message_id", ""))


def _discord(p: Publicacion, texto: str, c: dict) -> str:
	url = c["webhook"] + ("&" if "?" in c["webhook"] else "?") + "wait=true"
	medio = p.video if p.video and Path(p.video).exists() else (p.imagen if p.imagen and Path(p.imagen).exists() else "")
	carga = json.dumps({"content": texto, "allowed_mentions": {"parse": []}})
	if medio:
		cuerpo, tipo = _multipart({"payload_json": carga}, {"files[0]": Path(medio)})
		r = _http(url, cuerpo, {"Content-Type": tipo})
	else:
		r = _http(url, carga.encode(), {"Content-Type": "application/json"})
	return str(r.get("id", ""))


def _reddit(p: Publicacion, texto: str, c: dict, sub: str) -> str:
	base_auth = _url("ORQ_REDDIT_AUTH_URL", "https://www.reddit.com")
	base = _url("ORQ_REDDIT_URL", "https://oauth.reddit.com")
	ua = {"User-Agent": c.get("agente", "orquestador:difusor:1.0 (by u/" + c.get("usuario", "orquestador") + ")")}
	import base64
	basic = base64.b64encode(f"{c['cliente']}:{c['secreto']}".encode()).decode()
	tok = _http(f"{base_auth}/api/v1/access_token", urllib.parse.urlencode({"grant_type": "refresh_token", "refresh_token": c["refresh"]}).encode(),
		{**ua, "Authorization": f"Basic {basic}", "Content-Type": "application/x-www-form-urlencoded"})
	campos = {"sr": sub, "title": (p.titulo or p.texto)[:280], "api_type": "json", "resubmit": "false"}
	if p.enlace:
		campos.update({"kind": "link", "url": p.enlace})
	else:
		campos.update({"kind": "self", "text": texto})
	r = _http(f"{base}/api/submit", urllib.parse.urlencode(campos).encode(),
		{**ua, "Authorization": f"Bearer {tok['access_token']}", "Content-Type": "application/x-www-form-urlencoded"})
	errores = ((r.get("json") or {}).get("errors") or [])
	if errores:
		raise ErrorDifusor(f"reddit r/{sub}: {errores[0]}")
	return str(((r.get("json") or {}).get("data") or {}).get("url", ""))


def _x(p: Publicacion, texto: str, c: dict) -> str:
	"""X (API v2 con token OAuth 2.0 de usuario con permiso tweet.write)."""
	base = _url("ORQ_X_URL", "https://api.x.com")
	r = _json(f"{base}/2/tweets", {"text": texto}, {"Authorization": f"Bearer {c['token']}"})
	return str((r.get("data") or {}).get("id", ""))


def publicar(p: Publicacion, red: str, credenciales: dict, simulado: bool = False, registro: Path = REGISTRO,
		destino: str = "") -> dict:
	"""Publica en una red respetando los limites. {"ok", "red", "url" o "motivo"}."""
	texto = adaptar(p, red)
	if red == "reddit":
		subs = [s.strip().lower().removeprefix("r/") for s in credenciales.get("subreddits", []) if s.strip()]
		destino = destino.lower().removeprefix("r/") or (subs[0] if subs else "")
		if not destino or destino not in subs:
			return {"ok": False, "red": red, "motivo": "reddit: solo en los subreddits que tu has apuntado (y que permiten promocion propia)"}
	motivo = puede(red, texto, registro, destino=destino)
	if motivo:
		return {"ok": False, "red": red, "motivo": motivo}
	fila = {"t": time.time(), "red": red, "firma": _firma(texto), "texto": texto[:300], "destino": destino, "simulado": simulado}
	try:
		if simulado:
			url = f"simulado://{red}/{fila['firma']}"
		elif red == "bluesky":
			url = _bluesky(p, texto, credenciales)
		elif red == "mastodon":
			url = _mastodon(p, texto, credenciales)
		elif red == "telegram":
			url = _telegram(p, texto, credenciales)
		elif red == "discord":
			url = _discord(p, texto, credenciales)
		elif red == "reddit":
			url = _reddit(p, texto, credenciales, destino)
		else:
			url = _x(p, texto, credenciales)
	except (ErrorDifusor, KeyError) as e:
		_apuntar(registro, dict(fila, ok=False, error=str(e)[:300]))
		return {"ok": False, "red": red, "motivo": str(e) if isinstance(e, ErrorDifusor) else f"{red}: falta la clave {e}"}
	_apuntar(registro, dict(fila, ok=True, url=url))
	return {"ok": True, "red": red, "url": url}


def difundir(p: Publicacion, cuentas: dict[str, dict], simulado: bool = False, registro: Path = REGISTRO) -> list[dict]:
	"""Publica en todas las redes conectadas (las que tienen credenciales). Una que falle no para las demas."""
	return [publicar(p, red, cred, simulado, registro) for red, cred in cuentas.items() if red in REDES and cred]
