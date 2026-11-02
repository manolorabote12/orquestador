"""Promocion diaria del propio Orquestador (la ejecuta .github/workflows/promocion.yml una vez al dia).

1 - Publica UNA cosa al dia en las redes de Orquestador que esten conectadas (Bluesky, Mastodon,
    Telegram, Discord, X, Reddit en los subreddits apuntados), alternando:
      lunes/jueves: el juego de la comunidad mas jugado de la semana (con su pagina para jugar);
      martes/viernes: un tipo de juego que se puede crear (su pagina «crea este juego sin programar»);
      miercoles/sabado: un consejo para crear y publicar juegos; domingo: nada (descanso, sin spam).
    El difusor pone los limites (por red y dia, nunca el mismo texto) y lo apunta todo.
2 - Busca conversaciones donde Orquestador ayuda y manda los borradores de respuesta al Telegram
    privado del responsable (ORQ_TELEGRAM_ADMIN): se revisan y se publican a mano. Nunca solas.

Claves (secretos de GitHub, ninguna obligatoria: sin claves, esa red no se usa):
	ORQ_BSKY_USUARIO, ORQ_BSKY_CLAVE_APP · ORQ_MASTODON_INSTANCIA, ORQ_MASTODON_TOKEN · ORQ_TELEGRAM_TOKEN,
	ORQ_TELEGRAM_CANAL, ORQ_TELEGRAM_ADMIN · ORQ_DISCORD_WEBHOOK · ORQ_X_TOKEN · ORQ_REDDIT_CLIENTE,
	ORQ_REDDIT_SECRETO, ORQ_REDDIT_REFRESH, ORQ_REDDIT_SUBS (separados por comas) · ORQ_WEB (la web publica)
	SUPABASE_URL y SUPABASE_ANON_KEY (para el escaparate). --simulado no publica nada.
"""

import argparse
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import generos  # noqa: E402
from marketing import comunidad, difusor  # noqa: E402

CONSEJOS = [
	"Consejo: un buen juego de móvil se entiende en 3 segundos. Si tienes que explicarlo, simplifícalo.",
	"Consejo: para publicar en Google Play necesitas 12 probadores durante 14 días. En la Lanzadera de Orquestador os ayudáis entre creadores.",
	"Consejo: los anuncios con premio (ver un vídeo a cambio de algo) dan más dinero y molestan menos que los intersticiales.",
	"Consejo: el primer nivel tiene que ganarse sí o sí. La primera victoria es la que hace volver al jugador.",
	"Consejo: sube un vídeo vertical de 15 segundos cada día durante una semana. Lo que funciona en TikTok suele funcionar en Shorts.",
	"Consejo: cambia una sola cosa por versión y mira las estadísticas. Si no sabes qué ha funcionado, no has aprendido nada.",
]


def cuentas() -> dict[str, dict]:
	env = os.environ.get
	c: dict[str, dict] = {}
	if env("ORQ_BSKY_USUARIO") and env("ORQ_BSKY_CLAVE_APP"):
		c["bluesky"] = {"usuario": env("ORQ_BSKY_USUARIO"), "clave_app": env("ORQ_BSKY_CLAVE_APP")}
	if env("ORQ_MASTODON_TOKEN"):
		c["mastodon"] = {"token": env("ORQ_MASTODON_TOKEN"), "instancia": env("ORQ_MASTODON_INSTANCIA", "")}
	if env("ORQ_TELEGRAM_TOKEN") and env("ORQ_TELEGRAM_CANAL"):
		c["telegram"] = {"token": env("ORQ_TELEGRAM_TOKEN"), "canal": env("ORQ_TELEGRAM_CANAL")}
	if env("ORQ_DISCORD_WEBHOOK"):
		c["discord"] = {"webhook": env("ORQ_DISCORD_WEBHOOK")}
	if env("ORQ_X_TOKEN"):
		c["x"] = {"token": env("ORQ_X_TOKEN")}
	if env("ORQ_REDDIT_REFRESH") and env("ORQ_REDDIT_SUBS"):
		c["reddit"] = {"cliente": env("ORQ_REDDIT_CLIENTE", ""), "secreto": env("ORQ_REDDIT_SECRETO", ""), "refresh": env("ORQ_REDDIT_REFRESH"),
			"subreddits": [s.strip() for s in env("ORQ_REDDIT_SUBS", "").split(",") if s.strip()]}
	return c


def juego_de_la_semana() -> dict | None:
	url, anon = os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_ANON_KEY", "")
	if not url or not anon:
		return None
	try:
		req = urllib.request.Request(f"{url}/rest/v1/rpc/escaparate_lista", data=json.dumps({"p_orden": "semana"}).encode(),
			headers={"apikey": anon, "Content-Type": "application/json"}, method="POST")
		with urllib.request.urlopen(req, timeout=30) as r:
			lista = json.loads(r.read())
		return lista[0] if lista else None
	except Exception:  # noqa: BLE001
		return None


def publicacion_del_dia(dia: int, web: str, juego: dict | None = None) -> difusor.Publicacion | None:
	"""dia: 0 = lunes ... 6 = domingo (descanso)."""
	if dia == 6:
		return None
	semana = int(time.time() // (7 * 86400))
	if dia in (0, 3) and juego:
		return difusor.Publicacion(
			texto=f"🎮 Juego de la semana: «{juego['titulo']}», de {juego.get('autor') or 'la comunidad'}. {str(juego.get('resumen') or '')[:140]} Creado con una frase en Orquestador.",
			enlace=f"{web}/juegos/{juego['project_id']}.html" if web else "", titulo=str(juego["titulo"]),
			etiquetas=["gamedev", "indiegame", "juegos", "IA"])
	if dia in (0, 1, 3, 4):
		ids = [g for g in generos.GENEROS if g != "a_medida"]
		gid = ids[(semana * 2 + (1 if dia in (1, 4) else 0)) % len(ids)]
		g = generos.GENEROS[gid]
		return difusor.Publicacion(texto=f"¿Te imaginas tu propio juego así? «{g['corto'][0]}»: {g['frase'][0]}. Lo describes con palabras y Orquestador lo crea, lo prueba y lo deja listo para Google Play.",
			enlace=f"{web}/crear/{gid}.html" if web else "", titulo=g["corto"][0], etiquetas=["gamedev", "nocode", "IA", "android"])
	return difusor.Publicacion(texto=CONSEJOS[(semana + dia) % len(CONSEJOS)], enlace=web, etiquetas=["gamedev", "indiedev"])


def avisar_admin(nuevos: list[dict], simulado: bool) -> int:
	tok, chat = os.environ.get("ORQ_TELEGRAM_TOKEN", ""), os.environ.get("ORQ_TELEGRAM_ADMIN", "")
	if not nuevos or not tok or not chat or simulado:
		return 0
	n = 0
	for c in nuevos[:8]:
		texto = f"💬 {c['red']} {c.get('donde', '')} ({c['puntos']})\n{c['url']}\n\n«{c['texto'][:300]}»\n\nBorrador:\n{c['borrador']}"
		try:
			difusor._json(os.environ.get("ORQ_TELEGRAM_URL", "https://api.telegram.org") + f"/bot{tok}/sendMessage",
				{"chat_id": chat, "text": texto[:3900], "disable_web_page_preview": True})
			n += 1
		except difusor.ErrorDifusor:
			pass
	return n


def main(argv: list[str] | None = None) -> int:
	a = argparse.ArgumentParser()
	a.add_argument("--simulado", action="store_true")
	a.add_argument("--dia", type=int, default=-1, help="0 lunes ... 6 domingo (por defecto, hoy)")
	a.add_argument("--registro", default=str(difusor.REGISTRO))
	x = a.parse_args(argv)
	dia = x.dia if x.dia >= 0 else time.gmtime().tm_wday
	web = os.environ.get("ORQ_WEB", "").rstrip("/")
	p = publicacion_del_dia(dia, web, juego_de_la_semana())
	resultados = difusor.difundir(p, cuentas(), x.simulado, Path(x.registro)) if p else []
	## Borradores con Claude si hay clave; si no, la plantilla honesta.
	nuevos = comunidad.ronda({"reddit_token": os.environ.get("ORQ_REDDIT_TOKEN", "")}, simulado=not os.environ.get("ANTHROPIC_API_KEY")) if not x.simulado else []
	avisos = avisar_admin(nuevos, x.simulado)
	print(json.dumps({"dia": dia, "publicacion": p.texto if p else None, "resultados": resultados, "conversaciones": len(nuevos), "avisos": avisos},
		ensure_ascii=False))
	return 0


if __name__ == "__main__":
	sys.exit(main())
