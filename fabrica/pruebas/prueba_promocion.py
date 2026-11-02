"""Marketing que promociona solo: difusor (redes con sus APIs, limites anti-spam), agente de comunidad
(borradores, nunca publica), creadores, campanas de Google Ads, paginas SEO y la promocion diaria.
Todo contra un servidor falso local (las redes de verdad no se tocan)."""

import json
import os
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / "nube"))

fallos = 0
LLAMADAS: list[tuple[str, str, bytes]] = []


def check(nombre: str, ok: bool, extra: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({extra})" if extra else ""))
	if not ok:
		fallos += 1


class Falso(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def _responder(self, cuerpo: dict, codigo: int = 200) -> None:
		datos = json.dumps(cuerpo).encode()
		self.send_response(codigo)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(datos)))
		self.end_headers()
		self.wfile.write(datos)

	def do_GET(self):
		LLAMADAS.append(("GET", self.path, b""))
		if "searchPosts" in self.path:
			hoy = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
			return self._responder({"posts": [
				{"uri": "at://did:x/app.bsky.feed.post/1", "author": {"handle": "ana.bsky.social"}, "record": {"text": "¿Alguna app para crear un juego sin programar? Quiero publicarlo en Google Play", "createdAt": hoy}},
				{"uri": "at://did:x/app.bsky.feed.post/2", "author": {"handle": "promo.bsky.social"}, "record": {"text": "Descarga mi juego ya, mira mi promo", "createdAt": hoy}},
				{"uri": "at://did:x/app.bsky.feed.post/3", "author": {"handle": "viejo.bsky.social"}, "record": {"text": "¿Cómo hago un juego sin programar?", "createdAt": "2020-01-01T00:00:00Z"}}]})
		if "/search?" in self.path and "youtube" not in self.path:
			return self._responder({"data": {"children": [{"data": {"name": "t3_a", "title": "How do I make a mobile game without coding?", "selftext": "any app?",
				"author": "bob", "permalink": "/r/AppIdeas/comments/a", "created_utc": time.time(), "subreddit": "AppIdeas"}},
				{"data": {"name": "t3_b", "title": "How to make a game without coding?", "selftext": "", "author": "c", "permalink": "/r/gamedev/b",
				"created_utc": time.time(), "subreddit": "gamedev"}}]}})
		if "/youtube/search" in self.path:
			hoy = time.strftime("%Y-%m-%dT00:00:00Z", time.gmtime())
			return self._responder({"items": [{"id": {"videoId": "v1"}, "snippet": {"channelId": "C1", "title": "Top 10 juegos android", "publishedAt": hoy}},
				{"id": {"videoId": "v2"}, "snippet": {"channelId": "C2", "title": "Big channel", "publishedAt": hoy}},
				{"id": {"videoId": "v3"}, "snippet": {"channelId": "C3", "title": "Sin correo", "publishedAt": hoy}}]})
		if "/youtube/channels" in self.path:
			return self._responder({"items": [
				{"id": "C1", "snippet": {"title": "JuegosTop", "description": "Contacto: juegostop@example.com"}, "statistics": {"subscriberCount": "12000"}},
				{"id": "C2", "snippet": {"title": "Gigante", "description": "biz@example.com"}, "statistics": {"subscriberCount": "5000000"}},
				{"id": "C3", "snippet": {"title": "Callado", "description": "sin correo"}, "statistics": {"subscriberCount": "8000"}}]})
		return self._responder({}, 404)

	def do_POST(self):
		n = int(self.headers.get("Content-Length", "0") or 0)
		cuerpo = self.rfile.read(n)
		LLAMADAS.append(("POST", self.path, cuerpo))
		p = self.path
		if p.endswith("createSession"):
			return self._responder({"accessJwt": "jwt", "did": "did:plc:orq"})
		if p.endswith("uploadBlob"):
			return self._responder({"blob": {"$type": "blob", "ref": {"$link": "x"}, "mimeType": "image/png", "size": len(cuerpo)}})
		if p.endswith("createRecord"):
			return self._responder({"uri": "at://did:plc:orq/app.bsky.feed.post/xyz"})
		if p.endswith("/api/v2/media"):
			return self._responder({"id": "m1"})
		if p.endswith("/api/v1/statuses"):
			return self._responder({"url": "https://mastodon.example/@orq/1"})
		if "/bottok/" in p:
			return self._responder({"ok": True, "result": {"message_id": 7}})
		if p.startswith("/webhook"):
			return self._responder({"id": "d1"})
		if p.endswith("access_token"):
			return self._responder({"access_token": "rt"})
		if p.endswith("/api/submit"):
			return self._responder({"json": {"errors": [], "data": {"url": "https://reddit.com/r/AppIdeas/x"}}})
		if p.endswith("/2/tweets"):
			return self._responder({"data": {"id": "123"}})
		return self._responder({}, 404)


def main() -> int:
	print("== Marketing que promociona solo ==")
	os.environ["NO_PROXY"] = os.environ["no_proxy"] = "127.0.0.1,localhost"
	srv = ThreadingHTTPServer(("127.0.0.1", 0), Falso)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	base = f"http://127.0.0.1:{srv.server_port}"
	for k in ("ORQ_BSKY_URL", "ORQ_BSKY_PUBLIC_URL", "ORQ_MASTODON_URL", "ORQ_TELEGRAM_URL", "ORQ_REDDIT_AUTH_URL", "ORQ_REDDIT_URL", "ORQ_X_URL"):
		os.environ[k] = base
	os.environ["ORQ_YOUTUBE_API_URL"] = base + "/youtube"
	from marketing import campanas, comunidad, creadores, difusor, promo_orquestador
	tmp = Path(tempfile.mkdtemp())
	reg = tmp / "difusor.json"
	img = tmp / "captura.png"
	img.write_bytes(b"\x89PNG\r\n\x1a\n" + b"0" * 64)

	## Texto adaptado a cada red
	p = difusor.Publicacion(texto="Imperio Dulce: compra pastelerías y hazte rico mientras tus gerentes trabajan. " * 5,
		enlace="https://orq.example/juegos/abc.html", titulo="Imperio Dulce", imagen=str(img), etiquetas=["gamedev", "indie game", "IA"])
	for red in difusor.REDES:
		t = difusor.adaptar(p, red)
		check(f"texto para {red}: cabe y el enlace no se corta", len(t) <= difusor.REDES[red]["largo"] and (red == "reddit" or t.endswith(p.enlace)), str(len(t)))

	## Publicar en cada red con su API (servidor falso)
	cred = {"bluesky": {"usuario": "orq.bsky.social", "clave_app": "x"}, "mastodon": {"token": "t", "instancia": base},
		"telegram": {"token": "tok", "canal": "@orq"}, "discord": {"webhook": base + "/webhook/1/a"}, "x": {"token": "xt"},
		"reddit": {"cliente": "c", "secreto": "s", "refresh": "r", "subreddits": ["AppIdeas"]}}
	res = difusor.difundir(p, cred, False, reg)
	check("publica en las 6 redes conectadas", all(r["ok"] for r in res) and len(res) == 6, str([(r["red"], r.get("motivo", "")) for r in res if not r["ok"]]))
	bs = [c for c in LLAMADAS if c[1].endswith("createRecord")]
	rec = json.loads(bs[-1][2])["record"] if bs else {}
	check("bluesky: con imagen y el enlace como enlace de verdad", rec.get("embed", {}).get("$type") == "app.bsky.embed.images" and rec.get("facets"))
	check("discord: sin menciones (@everyone no avisa a nadie)", any(c[1].startswith("/webhook") and b'"parse": []' in c[2] for c in LLAMADAS))
	## Limites anti-spam
	again = difusor.publicar(p, "bluesky", cred["bluesky"], False, reg)
	check("no publica dos veces seguidas en la misma red", not again["ok"] and "esperar" in again["motivo"], again.get("motivo", ""))
	check("nunca el mismo texto dos veces", "ya se publico" in difusor.puede("bluesky", difusor.adaptar(p, "bluesky"), reg, time.time() + 3 * 86400))
	otra = difusor.Publicacion(texto="Otro texto distinto para reddit", titulo="Hola")
	r_sub = difusor.publicar(otra, "reddit", dict(cred["reddit"]), False, reg, destino="gaming")
	check("reddit: solo en los subreddits apuntados", not r_sub["ok"] and "apuntado" in r_sub["motivo"])
	check("reddit: una vez por semana en cada subreddit", "semana" in difusor.puede("reddit", "texto nuevo", reg, time.time() + 2 * 86400, "appideas")
		or "dias" in difusor.puede("reddit", "texto nuevo", reg, time.time() + 2 * 86400, "appideas"))
	sim = difusor.publicar(difusor.Publicacion(texto="simulado 1"), "telegram", {"token": "x", "canal": "y"}, True, tmp / "sim.json")
	check("en simulado no llama a la red", sim["ok"] and sim["url"].startswith("simulado://"))
	falta = difusor.publicar(difusor.Publicacion(texto="sin claves"), "mastodon", {}, False, tmp / "f.json")
	check("una red sin claves falla con un mensaje claro", not falta["ok"] and "falta" in falta["motivo"])

	## Agente de comunidad: encuentra, puntua y redacta (no publica)
	n0 = len([c for c in LLAMADAS if c[0] == "POST"])
	cola = tmp / "comunidad.json"
	nuevos = comunidad.ronda({"reddit_token": "t"}, simulado=True, cola=cola)
	ids = {c["id"] for c in nuevos}
	check("comunidad: encuentra preguntas de verdad (bluesky y reddit)", "at://did:x/app.bsky.feed.post/1" in ids and "t3_a" in ids, str(ids))
	check("comunidad: descarta anuncios, lo viejo y los subreddits que no quieren promocion",
		not ids & {"at://did:x/app.bsky.feed.post/2", "at://did:x/app.bsky.feed.post/3", "t3_b"})
	check("comunidad: cada una con su borrador honesto (dice que es del equipo)", all("Orquestador" in c["borrador"] and c["estado"] == "pendiente" for c in nuevos))
	check("comunidad: nunca publica nada", len([c for c in LLAMADAS if c[0] == "POST"]) == n0)
	check("comunidad: no repite conversaciones", comunidad.ronda({"reddit_token": "t"}, simulado=True, cola=cola) == [])

	## Creadores
	juego = {"titulo": "Imperio Dulce", "corto": "un idle tycoon de pastelerías", "url": "https://play.google.com/store/apps/details?id=x"}
	cr = creadores.preparar(juego, "tycoon", tmp / "creadores.json")
	check("creadores: solo canales medianos, activos y con correo publico", [c["id"] for c in cr] == ["C1"], str([c["id"] for c in cr]))
	check("creadores: mensaje personal con su video y la opcion de no volver a escribir", cr and "Top 10 juegos android" in cr[0]["cuerpo"]
		and "no volveré" in cr[0]["cuerpo"] and cr[0]["mailto"].startswith("mailto:juegostop@example.com"))
	check("creadores: no escribe dos veces al mismo canal", creadores.preparar(juego, "tycoon", tmp / "creadores.json") == [])

	## Campanas de Google Ads
	pl = campanas.plan({"titulo": "Imperio Dulce de las Pastelerías Mágicas", "corto": "Compra pastelerías y hazte rico", "paquete": "com.x.dulce"},
		presupuesto_dia=6, tope_total=60)
	check("campana: titulares de 30 y descripciones de 90 como pide Google", all(len(t) <= 30 for t in pl["titulares"]) and all(len(d) <= 90 for d in pl["descripciones"])
		and 3 <= len(pl["titulares"]) <= 5)
	check("campana: presupuesto repartido y con tope", abs(sum(g["presupuesto_dia"] for g in pl["grupos"]) - 6) < 0.05 and pl["dias_hasta_tope"] == 10)
	csvt = campanas.editor_csv(pl)
	check("campana: CSV para Google Ads Editor", csvt.startswith("Campaign,Campaign Type") and "com.x.dulce" in csvt)

	## Paginas SEO
	import seo
	web = tmp / "web"
	(web).mkdir()
	r_seo = seo.generar(web, "https://x.supabase.co", "k", "https://orq.example",
		[{"project_id": "abc", "titulo": "Imperio Dulce", "genero": "tycoon", "resumen": "Compra pastelerías", "autor": "Dani", "version": 1, "jugadas": 9}])
	pag = (web / "crear" / "tycoon.html").read_text(encoding="utf-8")
	check("seo: una pagina por tipo de juego en espanol e ingles", (web / "en" / "create" / "tycoon.html").exists() and "<title>" in pag and 'hreflang="en"' in pag)
	check("seo: pagina del juego con datos para Google (VideoGame)", '"@type": "VideoGame"' in (web / "juegos" / "abc.html").read_text(encoding="utf-8"))
	check("seo: el juego sale en la pagina de su tipo", "juegos/abc.html" in pag)
	mapa = (web / "sitemap.xml").read_text(encoding="utf-8")
	check("seo: sitemap y robots", "https://orq.example/crear/tycoon.html" in mapa and (web / "robots.txt").exists() and r_seo["generos"] >= 80)

	## Promocion diaria del propio Orquestador
	pubs = [promo_orquestador.publicacion_del_dia(d, "https://orq.example", {"project_id": "abc", "titulo": "Imperio Dulce", "autor": "Dani", "resumen": "x"}) for d in range(7)]
	check("promocion: una al dia y el domingo descanso", pubs[6] is None and all(pubs[:6]))
	check("promocion: juego de la semana, tipos de juego y consejos", "Imperio Dulce" in pubs[0].texto and "/crear/" in pubs[1].enlace and pubs[2].texto.startswith("Consejo"))
	os.environ.update({"ORQ_BSKY_USUARIO": "orq", "ORQ_BSKY_CLAVE_APP": "x"})
	salida = promo_orquestador.main(["--simulado", "--dia", "1", "--registro", str(tmp / "promo.json")])
	check("promocion: en simulado no toca las redes", salida == 0 and json.loads((tmp / "promo.json").read_text())[0]["simulado"])
	srv.shutdown()
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
