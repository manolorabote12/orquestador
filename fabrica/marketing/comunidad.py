"""Agente de comunidad: encuentra conversaciones donde Orquestador (o un juego) de verdad ayuda y
REDACTA una respuesta para que una persona la revise y la publique ella misma.

Por que asi: responder solo, en masa, es spam (Reddit, X y Bluesky lo castigan y la marca se quema).
Lo que funciona es estar donde se pregunta («¿como hago un juego sin saber programar?», «¿hay algo
como Coin Master para crear?») con una respuesta util, honesta y firmada.

1 - buscar(): Bluesky (busqueda publica) y Reddit (busqueda con la app de Orquestador) con las
    frases que usa la gente. Se puntua lo relevante y se descarta lo viejo, lo ya visto y los
    subreddits que no quieren promocion.
2 - redactar(): Claude escribe una respuesta corta que primero ayuda (aunque no usen Orquestador),
    dice que es del equipo y solo enlaza si encaja. Sin IA (simulado), una plantilla honesta.
3 - La cola queda en datos/comunidad.json (o en el servidor): la app la ensena en «Respuestas
    sugeridas» con un boton para abrir la conversacion y copiar el texto. Nunca se publica sola.
"""

import json
import os
import time
import urllib.parse
import urllib.request
from pathlib import Path

COLA = Path(__file__).resolve().parents[1] / "datos" / "comunidad.json"
BUSQUEDAS = {
	"es": ["crear un juego sin programar", "hacer mi propio juego movil", "app para crear videojuegos", "crear juego con ia",
		"como publicar un juego en google play", "juego tipo coin master crear"],
	"en": ["make a game without coding", "ai game maker", "create my own mobile game", "no code game engine",
		"how to publish a game on google play", "game maker app for android"],
}
## Palabras que hacen relevante (y que la persona pregunta, no que anuncia).
PREGUNTA = ("?", "¿", "how", "como", "cómo", "any app", "alguna app", "recommend", "recomiend", "help", "ayuda", "looking for", "busco")
## Subreddits donde nunca se sugiere responder con promocion (reglas estrictas) aunque salga en la busqueda.
SUB_NO = {"gamedev", "indiedev", "godot", "unity3d", "programming", "learnprogramming"}
MAX_DIAS = 10


def _get(url: str, cabeceras: dict | None = None) -> dict:
	with urllib.request.urlopen(urllib.request.Request(url, headers=cabeceras or {}), timeout=30) as r:
		return json.loads(r.read())


def buscar_bluesky(q: str, lang: str) -> list[dict]:
	base = os.environ.get("ORQ_BSKY_PUBLIC_URL", "https://public.api.bsky.app")
	d = _get(f"{base}/xrpc/app.bsky.feed.searchPosts?" + urllib.parse.urlencode({"q": q, "lang": lang, "limit": 25, "sort": "latest"}))
	out = []
	for p in d.get("posts", []):
		uri = str(p.get("uri", ""))
		rkey = uri.rsplit("/", 1)[-1]
		handle = (p.get("author") or {}).get("handle", "")
		out.append({"red": "bluesky", "id": uri, "texto": (p.get("record") or {}).get("text", ""), "autor": handle,
			"url": f"https://bsky.app/profile/{handle}/post/{rkey}", "fecha": (p.get("record") or {}).get("createdAt", ""), "donde": "bluesky"})
	return out


def buscar_reddit(q: str, token: str) -> list[dict]:
	base = os.environ.get("ORQ_REDDIT_URL", "https://oauth.reddit.com")
	d = _get(f"{base}/search?" + urllib.parse.urlencode({"q": q, "sort": "new", "t": "week", "limit": 25, "type": "link"}),
		{"Authorization": f"Bearer {token}", "User-Agent": "orquestador:comunidad:1.0"})
	out = []
	for c in (d.get("data") or {}).get("children", []):
		p = c.get("data") or {}
		out.append({"red": "reddit", "id": p.get("name", ""), "texto": (p.get("title", "") + "\n" + p.get("selftext", ""))[:1500],
			"autor": p.get("author", ""), "url": "https://www.reddit.com" + p.get("permalink", ""), "fecha": p.get("created_utc", 0),
			"donde": str(p.get("subreddit", "")).lower()})
	return out


def puntuar(c: dict, ahora: float | None = None) -> float:
	"""0 a 1: pregunta de verdad, reciente y sobre crear juegos (no un anuncio de otro)."""
	t = c["texto"].lower()
	if c.get("donde") in SUB_NO:
		return 0.0
	s = 0.0
	s += 0.4 if any(p in t for p in PREGUNTA) else 0.0
	s += 0.3 if any(k in t for k in ("juego", "game", "videojuego", "app")) else 0.0
	s += 0.2 if any(k in t for k in ("sin programar", "without coding", "no code", "no-code", "ia", " ai ", "google play")) else 0.0
	s -= 0.5 if any(k in t for k in ("check out my", "mira mi", "download my", "descarga mi", "promo", "sale")) else 0.0
	fecha = c.get("fecha")
	edad_dias = 0.0
	if isinstance(fecha, (int, float)) and fecha:
		edad_dias = ((ahora or time.time()) - float(fecha)) / 86400
	elif isinstance(fecha, str) and len(fecha) >= 10:
		try:
			edad_dias = ((ahora or time.time()) - time.mktime(time.strptime(fecha[:10], "%Y-%m-%d"))) / 86400
		except ValueError:
			edad_dias = 0.0
	if edad_dias > MAX_DIAS:
		return 0.0
	s += 0.1 * max(0.0, 1.0 - edad_dias / MAX_DIAS)
	return round(max(0.0, min(1.0, s)), 2)


PROMPT = """Eres parte del equipo de Orquestador, una app de movil que crea juegos completos a partir de
una frase (diseno, arte, musica, niveles probados por bots y publicacion en Google Play con AdMob).
Te paso una conversacion publica. Escribe UNA respuesta corta (maximo 600 caracteres), en el idioma
de la conversacion, que:
- ayude primero de verdad a esa persona aunque no use Orquestador (consejos concretos);
- diga con naturalidad que eres del equipo de Orquestador si lo mencionas ("soy del equipo de...");
- mencione Orquestador solo si encaja con lo que pide, sin exagerar ni inventar funciones;
- no ponga enlaces salvo que la persona pida una herramienta; nada de mayusculas ni emojis de anuncio;
- respete el tono del sitio (Reddit: directo y humilde).
Si la conversacion no tiene que ver o responder seria spam, devuelve exactamente: NO_RESPONDER"""


def redactar(c: dict, simulado: bool = True, gasto=None) -> str:
	if simulado:
		es = any(ch in c["texto"] for ch in "¿ñáéíóú") or " juego" in c["texto"].lower()
		if es:
			return ("Si quieres empezar sin programar, piensa primero en una mecánica sencilla y pruébala con amigos antes de dibujar nada. "
				"Para publicar en Google Play necesitas la cuenta de desarrollador (25 $) y 12 probadores durante 14 días. "
				"Soy del equipo de Orquestador, una app que hace justo eso a partir de una frase, por si te sirve.")
		return ("Start with one simple mechanic and test it with friends before worrying about art. "
			"To publish on Google Play you need a developer account ($25) and 12 testers for 14 days. "
			"I'm on the Orquestador team (an app that builds a game from one sentence), in case it helps.")
	from director import llm
	herramienta = {"name": "responder", "description": "La respuesta propuesta (o NO_RESPONDER).",
		"input_schema": {"type": "object", "additionalProperties": False, "required": ["respuesta"],
			"properties": {"respuesta": {"type": "string", "maxLength": 700}}}}
	r = llm.llamar_herramienta(llm.MODELOS[0], PROMPT, [{"role": "user", "content": f"Sitio: {c['red']} {c.get('donde', '')}\n<conversacion>\n{c['texto'][:1500]}\n</conversacion>"}],
		herramienta, gasto or llm.Gasto(), "comunidad", max_tokens=500)
	return str(r.get("respuesta", "")).strip()[:600]


def ronda(credenciales: dict | None = None, simulado: bool = True, cola: Path = COLA, minimo: float = 0.6, maximo: int = 10,
		encontrados: list[dict] | None = None) -> list[dict]:
	"""Busca, puntua y deja en la cola las mejores sin repetir. Devuelve lo anadido."""
	credenciales = credenciales or {}
	vistos = {f["id"] for f in (json.loads(cola.read_text(encoding="utf-8")) if cola.exists() else [])}
	todos: list[dict] = list(encontrados or [])
	if encontrados is None:
		for lang, qs in BUSQUEDAS.items():
			for q in qs:
				try:
					todos += buscar_bluesky(q, lang)
				except Exception:  # noqa: BLE001
					pass
				if credenciales.get("reddit_token"):
					try:
						todos += buscar_reddit(q, credenciales["reddit_token"])
					except Exception:  # noqa: BLE001
						pass
	nuevos = []
	for c in sorted(todos, key=lambda x: -puntuar(x)):
		if c["id"] in vistos or puntuar(c) < minimo:
			continue
		vistos.add(c["id"])
		borrador = redactar(c, simulado)
		if borrador.strip() == "NO_RESPONDER":
			continue
		nuevos.append(dict(c, puntos=puntuar(c), borrador=borrador, estado="pendiente", t=time.time()))
		if len(nuevos) >= maximo:
			break
	if nuevos:
		cola.parent.mkdir(parents=True, exist_ok=True)
		filas = (json.loads(cola.read_text(encoding="utf-8")) if cola.exists() else [])[-500:] + nuevos
		cola.write_text(json.dumps(filas, ensure_ascii=False, indent=1), encoding="utf-8")
	return nuevos
