"""Creadores y streamers: encuentra canales de YouTube que reseñan juegos de movil (o que hablan de
crear juegos) y prepara un mensaje personal para cada uno. Lo envia la persona, no la maquina.

1 - buscar(): YouTube Data API (clave publica de la API, ORQ_YOUTUBE_API_KEY) con busquedas por
    genero e idioma. Se quedan los canales pequenos y medianos (de 1.000 a 300.000 suscriptores:
    contestan mas y su publico confia en ellos), activos (video en el ultimo mes) y con correo de
    contacto PUBLICO en su descripcion (si no lo ponen ahi, no se busca por otros sitios).
2 - mensaje(): correo corto y personal (nombre del canal, un video suyo, por que encaja), con el
    enlace del juego, y siempre la opcion de no volver a escribir. Sin IA, una plantilla honesta.
3 - La lista se guarda (datos/creadores.json) para no escribir dos veces al mismo canal.
"""

import json
import os
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

LISTA = Path(__file__).resolve().parents[1] / "datos" / "creadores.json"
CORREO = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
MIN_SUBS = 1000
MAX_SUBS = 300000
BUSQUEDAS = {
	"es": ["juegos de movil gratis android", "mejores juegos android {genero}", "juegos indie movil reseña"],
	"en": ["best mobile games android", "{genero} mobile game review", "indie mobile games"],
}


def _get(ruta: str, params: dict) -> dict:
	base = os.environ.get("ORQ_YOUTUBE_API_URL", "https://www.googleapis.com/youtube/v3")
	params = dict(params, key=os.environ.get("ORQ_YOUTUBE_API_KEY", ""))
	with urllib.request.urlopen(f"{base}/{ruta}?" + urllib.parse.urlencode(params), timeout=30) as r:
		return json.loads(r.read())


def buscar(genero: str = "", idiomas: tuple = ("es", "en"), maximo: int = 30, ahora: float | None = None) -> list[dict]:
	ahora = ahora or time.time()
	canales: dict[str, dict] = {}
	for lang in idiomas:
		for q in BUSQUEDAS[lang]:
			d = _get("search", {"part": "snippet", "q": q.format(genero=genero).strip(), "type": "video", "maxResults": 25,
				"relevanceLanguage": lang, "order": "date"})
			for it in d.get("items", []):
				cid = (it.get("snippet") or {}).get("channelId", "")
				if cid and cid not in canales:
					canales[cid] = {"video": (it.get("id") or {}).get("videoId", ""), "video_titulo": (it.get("snippet") or {}).get("title", ""),
						"publicado": (it.get("snippet") or {}).get("publishedAt", ""), "idioma": lang}
	out: list[dict] = []
	ids = list(canales)
	for i in range(0, len(ids), 50):
		d = _get("channels", {"part": "snippet,statistics", "id": ",".join(ids[i:i + 50])})
		for c in d.get("items", []):
			subs = int((c.get("statistics") or {}).get("subscriberCount", 0) or 0)
			desc = (c.get("snippet") or {}).get("description", "")
			correo = CORREO.search(desc)
			info = canales[c["id"]]
			try:
				dias = (ahora - time.mktime(time.strptime(info["publicado"][:10], "%Y-%m-%d"))) / 86400
			except ValueError:
				dias = 999
			if MIN_SUBS <= subs <= MAX_SUBS and correo and dias <= 31:
				out.append({"canal": (c.get("snippet") or {}).get("title", ""), "id": c["id"], "suscriptores": subs, "correo": correo.group(0),
					"video": info["video"], "video_titulo": info["video_titulo"], "idioma": info["idioma"],
					"url": f"https://www.youtube.com/channel/{c['id']}"})
	out.sort(key=lambda x: x["suscriptores"])
	return out[:maximo]


def mensaje(c: dict, juego: dict) -> dict:
	"""Asunto y cuerpo del correo (plantilla honesta, en el idioma del canal)."""
	t = juego.get("titulo", "mi juego")
	url = juego.get("url", "")
	if c.get("idioma") == "en":
		asunto = f"{t}: a small mobile game for your channel?"
		cuerpo = (f"Hi {c['canal']},\n\nI watched \"{c.get('video_titulo', '')}\" and thought {t} could fit your channel: "
			f"{juego.get('corto', '')}.\n\nIt's free on Google Play: {url}\nHappy to send anything you need (codes, clips, info). "
			"If it's not for you, no worries and I won't write again.\n\nThanks!")
	else:
		asunto = f"{t}: ¿un juego de móvil para tu canal?"
		cuerpo = (f"Hola, {c['canal']}:\n\nVi «{c.get('video_titulo', '')}» y creo que {t} encaja con tu canal: {juego.get('corto', '')}.\n\n"
			f"Es gratis en Google Play: {url}\nSi te sirve algo (clips, información...), te lo paso. Si no es para ti, sin problema: "
			"no volveré a escribirte.\n\n¡Gracias!")
	return {"para": c["correo"], "asunto": asunto, "cuerpo": cuerpo,
		"mailto": "mailto:" + c["correo"] + "?" + urllib.parse.urlencode({"subject": asunto, "body": cuerpo}, quote_via=urllib.parse.quote)}


def preparar(juego: dict, genero: str = "", lista: Path = LISTA, encontrados: list[dict] | None = None) -> list[dict]:
	"""Canales nuevos (no contactados antes) con su mensaje listo."""
	ya = {f["id"] for f in (json.loads(lista.read_text(encoding="utf-8")) if lista.exists() else [])}
	canales = encontrados if encontrados is not None else buscar(genero)
	nuevos = [dict(c, **mensaje(c, juego), estado="por_enviar", t=time.time()) for c in canales if c["id"] not in ya]
	if nuevos:
		lista.parent.mkdir(parents=True, exist_ok=True)
		filas = (json.loads(lista.read_text(encoding="utf-8")) if lista.exists() else []) + nuevos
		lista.write_text(json.dumps(filas, ensure_ascii=False, indent=1), encoding="utf-8")
	return nuevos
