"""Paginas para buscadores (SEO) de la web publica de Orquestador, que crecen solas cada dia.

	python3 nube/seo.py --salida web [--supabase URL --anon CLAVE_PUBLICA] [--web https://...]

1 - Una pagina por genero en espanol y en ingles: «Crea tu imperio de negocios: crea este juego sin
    programar» / «Build your business empire: make this game without coding»: que se hace, su captura real, ideas de arranque y los
    mejores juegos de la comunidad de ese genero. Es lo que busca la gente («crear juego tipo
    coin master», «make a game like wordle»).
2 - Una pagina por cada juego del escaparate (con datos estructurados VideoGame para Google):
    titulo, de que va, autor, jugadas, boton de jugar en el navegador y «crea el tuyo».
3 - sitemap.xml, robots.txt y un indice de generos. La web se vuelve a publicar cada dia
   (web.yml), asi que cada juego nuevo del escaparate suma una pagina.
Sin red (o sin claves) se hacen solo las paginas de genero: nunca falla la publicacion de la web.
"""

import argparse
import html
import json
import shutil
import sys
import time
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "fabrica"))

import generos  # noqa: E402
import plantillas  # noqa: E402

TXT = {
	"es": {"titulo": "{g}: crea este juego sin programar", "desc": "{frase}. Descríbelo con palabras y Orquestador lo hace: niveles probados por bots, arte, música y listo para Google Play.",
		"crear": "Crear mi juego", "ideas": "Ideas para empezar", "comunidad": "Juegos de la comunidad", "jugar": "Jugar", "todos": "Todos los tipos de juego",
		"hub": "Crea cualquier tipo de juego para móvil", "hub_desc": "Elige el tipo de juego que quieres crear: Orquestador lo programa, lo dibuja y lo prueba por ti.",
		"de": "de", "jugadas": "jugadas", "crea_tuyo": "Crea el tuyo", "como": "Cómo funciona",
		"pasos": ["Escribe tu idea en una frase.", "Chispa diseña los niveles, dibuja los personajes y compone la música.", "Bots juegan cada nivel antes de dártelo.", "Publícalo en Google Play con anuncios de AdMob."]},
	"en": {"titulo": "{g}: make this game without coding", "desc": "{frase}. Describe it in words and Orquestador builds it: levels tested by bots, art, music and ready for Google Play.",
		"crear": "Make my game", "ideas": "Ideas to start", "comunidad": "Community games", "jugar": "Play", "todos": "All game types",
		"hub": "Make any kind of mobile game", "hub_desc": "Pick the type of game you want: Orquestador codes it, draws it and tests it for you.",
		"de": "by", "jugadas": "plays", "crea_tuyo": "Make yours", "como": "How it works",
		"pasos": ["Write your idea in one sentence.", "Chispa designs the levels, draws the characters and composes the music.", "Bots play every level before you get it.", "Publish it on Google Play with AdMob ads."]},
}
CARPETA = {"es": "crear", "en": "en/create"}


def e(t: str) -> str:
	return html.escape(str(t), quote=True)


def pagina(lang: str, titulo: str, desc: str, cuerpo: str, ruta: str, web: str, extra_head: str = "", alternos: dict | None = None) -> str:
	prof = "../" * ruta.count("/")
	canon = f"{web}/{ruta}" if web else ""
	alt = "".join(f'<link rel="alternate" hreflang="{l}" href="{web}/{r}">' for l, r in (alternos or {}).items()) if web else ""
	return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(titulo)} · Orquestador</title>
<meta name="description" content="{e(desc)}">
<meta property="og:title" content="{e(titulo)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:type" content="website">
{f'<link rel="canonical" href="{e(canon)}">' if canon else ''}{alt}
<link rel="icon" href="{prof}icono.svg" type="image/svg+xml">
<link rel="stylesheet" href="{prof}estilo.css">
{extra_head}
</head>
<body>
<header class="top"><a href="{prof}index.html">ORQUESTADOR</a></header>
<main>
{cuerpo}
</main>
<footer><a href="{prof}{CARPETA[lang]}/index.html">{e(TXT[lang]['todos'])}</a><a href="{prof}escaparate.html">Escaparate</a><a href="{prof}privacidad.html">Privacidad</a></footer>
</body>
</html>
"""


def escaparate(supabase: str, anon: str) -> list[dict]:
	"""Juegos publicos (los mejores y los nuevos, sin repetir). [] sin red o sin claves."""
	if not supabase or not anon or supabase.startswith("__"):
		return []
	vistos: dict[str, dict] = {}
	for orden in ("top", "nuevos"):
		try:
			req = urllib.request.Request(f"{supabase}/rest/v1/rpc/escaparate_lista", data=json.dumps({"p_orden": orden}).encode(),
				headers={"apikey": anon, "Content-Type": "application/json"}, method="POST")
			with urllib.request.urlopen(req, timeout=30) as r:
				for f in json.loads(r.read()):
					vistos.setdefault(str(f["project_id"]), f)
		except Exception as ex:  # noqa: BLE001
			print("aviso: escaparate no disponible:", ex)
	return list(vistos.values())[:1000]


def generar(salida: Path, supabase: str = "", anon: str = "", web: str = "", juegos: list[dict] | None = None) -> dict:
	juegos = escaparate(supabase, anon) if juegos is None else juegos
	urls: list[str] = []
	hoy = time.strftime("%Y-%m-%d")
	imgs = salida / "crear" / "img"
	imgs.mkdir(parents=True, exist_ok=True)
	por_genero: dict[str, list[dict]] = {}
	for j in juegos:
		por_genero.setdefault(str(j.get("genero", "")), []).append(j)
	ideas: dict[str, list[str]] = {}
	for p in plantillas.PLANTILLAS.values() if hasattr(plantillas, "PLANTILLAS") else []:
		ideas.setdefault(p["genero"], []).append(p["idea"].replace("{tema}", p["tema"]))
	n_generos = 0
	for gid, g in generos.GENEROS.items():
		if gid == "a_medida":
			continue
		foto = RAIZ / "app" / "public" / "generos" / f"{gid}.webp"
		if foto.exists():
			shutil.copy(foto, imgs / foto.name)
		for lang in ("es", "en"):
			t = TXT[lang]
			corto = g.get("corto", ("", ""))[0 if lang == "es" else 1] or gid
			frase = g.get("frase", ("", ""))[0 if lang == "es" else 1] or corto
			titulo = t["titulo"].format(g=corto)
			desc = t["desc"].format(frase=frase.rstrip("."))
			ruta = f"{CARPETA[lang]}/{gid}.html"
			prof = "../" * ruta.count("/")
			lista_ideas = "".join(f"<li>{e(x)}</li>" for x in ideas.get(gid, [])[:4]) if lang == "es" else ""
			comunidad = "".join(
				f'<a href="{prof}juegos/{e(j["project_id"])}.html"><img loading="lazy" alt="" src="{e(supabase)}/storage/v1/object/public/escaparate/{e(j["project_id"])}/icono.png?v={e(j.get("version", 1))}"><b>{e(j["titulo"])}</b></a>'
				for j in sorted(por_genero.get(gid, []), key=lambda x: -int(x.get("jugadas", 0)))[:8]) if supabase else ""
			pasos = "".join(f"<li>{e(x)}</li>" for x in t["pasos"])
			cuerpo = (f'<h1>{e(titulo)}</h1><p class="dim">{e(desc)}</p>'
				+ (f'<p><img src="{prof}crear/img/{gid}.webp" width="180" height="320" alt="{e(corto)}" style="border-radius:14px"></p>' if foto.exists() else "")
				+ f'<p><a class="btn" href="{prof}app/">{e(t["crear"])}</a></p>'
				+ f'<h2>{e(t["como"])}</h2><ol>{pasos}</ol>'
				+ (f'<h2>{e(t["ideas"])}</h2><ul>{lista_ideas}</ul>' if lista_ideas else "")
				+ (f'<h2>{e(t["comunidad"])}</h2><div class="galeria">{comunidad}</div>' if comunidad else ""))
			ld = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Orquestador", "applicationCategory": "GameApplication",
				"operatingSystem": "Android", "description": desc, "offers": {"@type": "Offer", "price": "0", "priceCurrency": "EUR"}}
			alternos = {"es": f"crear/{gid}.html", "en": f"en/create/{gid}.html"}
			(salida / ruta).parent.mkdir(parents=True, exist_ok=True)
			(salida / ruta).write_text(pagina(lang, titulo, desc, cuerpo, ruta, web,
				f'<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>', alternos), encoding="utf-8")
			urls.append(ruta)
		n_generos += 1
	## Indices de generos
	for lang in ("es", "en"):
		t = TXT[lang]
		ruta = f"{CARPETA[lang]}/index.html"
		prof = "../" * ruta.count("/")
		items = "".join(
			f'<a href="{gid}.html"><img loading="lazy" alt="" src="{prof}crear/img/{gid}.webp"><b>{e(g.get("corto", ("", ""))[0 if lang == "es" else 1] or gid)}</b></a>'
			for gid, g in generos.GENEROS.items() if gid != "a_medida")
		(salida / ruta).write_text(pagina(lang, t["hub"], t["hub_desc"], f'<h1>{e(t["hub"])}</h1><p class="dim">{e(t["hub_desc"])}</p><div class="galeria">{items}</div>',
			ruta, web, alternos={"es": "crear/index.html", "en": "en/create/index.html"}), encoding="utf-8")
		urls.append(ruta)
	## Paginas de juegos del escaparate
	(salida / "juegos").mkdir(parents=True, exist_ok=True)
	for j in juegos:
		pid = str(j["project_id"])
		ruta = f"juegos/{pid}.html"
		img = f"{supabase}/storage/v1/object/public/escaparate/{pid}/icono.png?v={j.get('version', 1)}"
		desc = str(j.get("resumen") or "")[:300]
		ld = {"@context": "https://schema.org", "@type": "VideoGame", "name": j["titulo"], "description": desc, "image": img,
			"genre": j.get("genero", ""), "gamePlatform": ["Web browser", "Android"], "playMode": "SinglePlayer",
			"author": {"@type": "Person", "name": j.get("autor") or "Orquestador"},
			"interactionStatistic": {"@type": "InteractionCounter", "interactionType": "https://schema.org/PlayAction", "userInteractionCount": int(j.get("jugadas", 0))}}
		cuerpo = (f'<p><img src="{e(img)}" width="128" height="128" alt="" style="border-radius:24px"></p><h1>{e(j["titulo"])}</h1>'
			+ f'<p class="dim">{e(desc)}</p><p class="dim">{e(TXT["es"]["de"])} {e(j.get("autor") or "Orquestador")} · {int(j.get("jugadas", 0))} {e(TXT["es"]["jugadas"])}</p>'
			+ f'<p><a class="btn" href="../jugar.html?j={e(pid)}">{e(TXT["es"]["jugar"])}</a> '
			+ f'<a class="btn" style="background:transparent;color:var(--brass-hi);border:1px solid var(--brass)" href="../app/?remix={e(pid)}">Haz tu versión</a></p>'
			+ f'<p class="dim"><a href="../crear/{e(j.get("genero", "index"))}.html">{e(TXT["es"]["crea_tuyo"])}</a></p>')
		(salida / ruta).write_text(pagina("es", str(j["titulo"]), desc or str(j["titulo"]), cuerpo, ruta, web,
			f'<meta property="og:image" content="{e(img)}"><meta property="og:type" content="website"><meta name="twitter:card" content="summary"><meta name="twitter:image" content="{e(img)}"><script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>'), encoding="utf-8")
		urls.append(ruta)
	## sitemap y robots
	base = web.rstrip("/") if web else ""
	todas = ["index.html", "escaparate.html"] + urls
	if base:
		(salida / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
			+ "".join(f"<url><loc>{e(base)}/{e(u)}</loc><lastmod>{hoy}</lastmod></url>\n" for u in todas) + "</urlset>\n", encoding="utf-8")
		(salida / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n", encoding="utf-8")
	return {"generos": n_generos, "juegos": len(juegos), "paginas": len(urls)}


def main() -> int:
	a = argparse.ArgumentParser(description="Paginas SEO de la web publica")
	a.add_argument("--salida", default=str(RAIZ / "web"))
	a.add_argument("--supabase", default="")
	a.add_argument("--anon", default="")
	a.add_argument("--web", default="")
	x = a.parse_args()
	print(generar(Path(x.salida), x.supabase, x.anon, x.web))
	return 0


if __name__ == "__main__":
	sys.exit(main())
