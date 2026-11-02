"""Respuestas preparadas para lo que Google Play SOLO deja hacer a mano en Play Console, y la
politica de privacidad de cada juego (Google la exige para cualquier app con anuncios).

Las respuestas salen de lo que el juego tiene de verdad:
	anuncios   El juego muestra anuncios reales de AdMob (solo si el autor puso sus ids; ver play/anuncios.py).
	telemetria El juego envia datos anonimos de partida para mejorarlo (aprendizaje con jugadores).
Lo que declara el SDK de anuncios de Google esta en su guia oficial:
https://developers.google.com/admob/android/privacy/play-data-disclosure
El usuario es el responsable final de lo que envia: la app se lo dice en cada paso.
"""

import html
import json
from datetime import date

import generos


def violencia(diseno: dict) -> str:
	g = diseno.get("genero", "plataformas")
	if g in ("puzle", "carreras", "volador"):
		return "no"
	return "fantasia"


def guia(diseno: dict, paquete: str, correo: str, url_privacidad: str, anuncios: bool, telemetria: bool) -> dict:
	"""Pasos de la primera publicacion con cada dato listo para copiar."""
	titulo = diseno["titulo"]
	from director.director import funciones_efectivas
	f = funciones_efectivas(diseno)
	infantil = diseno.get("publico") == "infantil"
	## Casino social (tragaperras con monedas de mentira): Google pide declararlo y publico adulto.
	casino = bool(generos.de(diseno).get("adultos"))
	viol = violencia(diseno)
	datos: list[dict] = []
	if anuncios:
		datos += [
			{"tipo": "Ubicación aproximada (a partir de la IP)", "recogido": True, "compartido": True,
				"fines": ["Publicidad o marketing", "Analíticas", "Prevención de fraudes, seguridad y cumplimiento"]},
			{"tipo": "Actividad en apps: interacciones con la app", "recogido": True, "compartido": True,
				"fines": ["Publicidad o marketing", "Analíticas", "Prevención de fraudes, seguridad y cumplimiento"]},
			{"tipo": "Información y rendimiento de apps: diagnósticos", "recogido": True, "compartido": True,
				"fines": ["Publicidad o marketing", "Analíticas", "Prevención de fraudes, seguridad y cumplimiento"]},
			{"tipo": "Identificadores del dispositivo u otros (ID de publicidad)", "recogido": True, "compartido": True,
				"fines": ["Publicidad o marketing", "Analíticas", "Prevención de fraudes, seguridad y cumplimiento"]},
		]
	if telemetria:
		datos.append({"tipo": "Actividad en apps: interacciones con la app (niveles jugados, superados y abandonados)",
			"recogido": True, "compartido": False, "fines": ["Analíticas"], "nota": "Anónimo: sin cuenta, nombre ni ID de publicidad"})
		## Clasificacion online (kit/online.gd): opcional, solo si el jugador elige un apodo.
		datos.append({"tipo": "Información personal: otra información (apodo que elige el jugador para la clasificación)",
			"recogido": True, "compartido": False, "opcional": True, "fines": ["Funciones de la aplicación"],
			"nota": "Opcional: solo si el jugador entra en la clasificación; puede borrarlo en Ajustes"})
		datos.append({"tipo": "Identificadores del dispositivo u otros (número aleatorio del juego, no es el ID de publicidad)",
			"recogido": True, "compartido": False, "opcional": True, "fines": ["Funciones de la aplicación"],
			"nota": "Solo para guardar la mejor marca de cada dispositivo en la clasificación"})
	pasos = [
		{"id": "cuenta", "titulo": "Cuenta de desarrollador de Google Play",
			"texto": "Si aún no la tienes: play.google.com/console, pago único de 25 $ y verificación de identidad. Solo una vez en la vida.",
			"enlace": "https://play.google.com/console/signup"},
		{"id": "crear", "titulo": "Crea el juego en Play Console",
			"texto": "Inicio > Crear aplicación. Copia estos datos tal cual:",
			"campos": {"Nombre de la aplicación": titulo, "Idioma predeterminado": "Español (España) – es-ES",
				"Aplicación o juego": "Juego", "Gratis o de pago": "Gratis"},
			"enlace": "https://play.google.com/console"},
		{"id": "acceso", "titulo": "Da permiso a Orquestador",
			"texto": "Usuarios y permisos > Invitar a nuevos usuarios. Pega este correo, marca solo este juego y los permisos "
				"«Publicar en pistas de prueba» (o «Gestor de versiones») y «Responder a reseñas»"
				+ (" y «Ver información financiera» (para comprobar las compras dentro del juego)" if f["tienda"] else "")
				+ ". Así Orquestador sube versiones, textos e imágenes por ti y te deja contestar reseñas desde la app.",
			"campos": {"Correo": "{CUENTA_SERVICIO}"}},
		{"id": "primer_aab", "titulo": "Sube el primer .aab (solo esta vez)",
			"texto": "Google exige que la primera versión de un juego nuevo se suba a mano. Pruebas > Prueba interna > "
				"Crear versión > sube el archivo que te damos y guarda. Si te pregunta por la firma de apps de Google Play, acepta.",
			"campos": {"Nombre del paquete": paquete}},
		{"id": "contenido", "titulo": "Contenido de la aplicación (formularios)",
			"texto": "Política > Contenido de la aplicación. Respuestas para este juego:",
			"campos": {
				"Política de privacidad (URL)": url_privacidad,
				"Acceso a la aplicación": "Toda la funcionalidad está disponible sin restricciones",
				"Anuncios": "Sí, mi aplicación contiene anuncios" if anuncios else "No, mi aplicación no contiene anuncios",
				"Público objetivo": ("Solo 18 o más (simulación de apuestas: casino social con monedas de mentira)" if casino else
					"Menores de 13 (programa de Familias: el juego ya va sin compras, sin avisos ni nada online)"
					if infantil else "13-15, 16-17 y 18 o más (recomendado: así no entra en el programa de Familias)"),
				"¿Atrae a niños?": "Sí" if infantil else "No (si lo marcas, Google exige requisitos extra de Familias)",
				"Aplicación de noticias": "No",
				"Aplicaciones gubernamentales / financieras / salud": "No",
				"ID de publicidad": "Sí, para anuncios" if anuncios else "No",
			}},
		{"id": "clasificacion", "titulo": "Clasificación de contenido (cuestionario IARC)",
			"texto": "Categoría: Juego. Correo de contacto: el tuyo. Respuestas:",
			"campos": {
				"Correo": correo,
				"Violencia": "Sí: violencia de fantasía o de dibujos animados, sin sangre ni personas reales" if viol == "fantasia" else "No",
				"Miedo / terror": "No",
				"Sexualidad / desnudos": "No",
				"Lenguaje malsonante": "No",
				"Drogas, alcohol o tabaco": "No",
				"Apuestas o simulación de apuestas": ("Sí: simulación de apuestas (casino social). Las monedas no se compran, "
					"no tienen valor y no se cambian por dinero ni premios" if casino else "No"),
				"Interacción entre usuarios o chat": ("Sí: los jugadores ven apodos en clasificaciones, clanes y partidas online (sin chat entre jugadores)"
					if f["online"] else "No"),
				"Comparte la ubicación del usuario": "No",
				"Compras digitales": "Sí (monedas, pase y quitar anuncios)" if f["tienda"] else "No",
			}},
		{"id": "datos", "titulo": "Seguridad de los datos",
			"texto": ("El juego no recoge ni comparte datos." if not datos else
				"Marca que recoges datos y que van cifrados en tránsito. A «¿Pueden los usuarios pedir que se eliminen?» "
				"responde que no hay cuentas (el juego no identifica a nadie). Tipos de datos:"),
			"datos": datos},
		{"id": "ficha", "titulo": "Ficha de Play Store",
			"texto": "No tienes que hacer nada: Orquestador sube título, descripciones, icono, gráfico destacado y capturas "
				"en español e inglés al publicar."},
		{"id": "probadores", "titulo": "Prueba cerrada (cuentas personales nuevas)",
			"texto": "Para pasar a producción, Google pide 12 probadores durante 14 días seguidos en prueba cerrada. "
				"Orquestador sube cada versión a la pista de prueba cerrada; la Lanzadera te ayuda a conseguir los probadores."},
	]
	if anuncios:
		pasos.append({"id": "admob", "titulo": "AdMob: vincular la app y app-ads.txt",
			"texto": "En AdMob → Apps → tu juego → Configuración de la app: vincúlala con Google Play en cuanto esté publicada "
				"(prueba cerrada vale). Recomendado: AdMob te da una línea para un archivo app-ads.txt; súbelo a la raíz de tu web "
				"(la que pongas como sitio web del desarrollador en Play Console). Sin él, algunos anunciantes pujan menos."})
	return {"juego": titulo, "paquete": paquete, "violencia": viol, "anuncios": anuncios, "telemetria": telemetria,
		"pasos": pasos, "aviso": "Revisa cada respuesta antes de enviarla: en Play Console el responsable eres tú."}


def privacidad_cuerpo(diseno: dict, correo: str, anuncios: bool, telemetria: bool) -> str:
	"""Cuerpo HTML (ya escapado) de la politica del juego en espanol e ingles."""
	t = html.escape(diseno["titulo"])
	c = html.escape(correo)
	hoy = date.today().isoformat()
	es_datos = []
	en_datos = []
	if anuncios:
		es_datos.append("<li><b>Anuncios (Google AdMob).</b> Para mostrar anuncios, Google recoge el identificador de publicidad del "
			"dispositivo, la dirección IP (ubicación aproximada), interacciones con los anuncios y datos de diagnóstico. "
			"Puedes reiniciar o eliminar el ID de publicidad en los ajustes de Android. Más información: "
			"<a href=\"https://policies.google.com/technologies/ads\">policies.google.com/technologies/ads</a>.</li>")
		en_datos.append("<li><b>Ads (Google AdMob).</b> To show ads, Google collects the device advertising ID, IP address "
			"(approximate location), ad interactions and diagnostics. You can reset or delete your advertising ID in Android "
			"settings. More: <a href=\"https://policies.google.com/technologies/ads\">policies.google.com/technologies/ads</a>.</li>")
	if telemetria:
		es_datos.append("<li><b>Datos anónimos de partida.</b> Qué niveles se juegan, se superan o se abandonan, para ajustar la "
			"dificultad. No incluyen tu nombre, cuenta ni identificador de publicidad.</li>")
		en_datos.append("<li><b>Anonymous gameplay data.</b> Which levels are played, completed or abandoned, to tune the "
			"difficulty. It never includes your name, account or advertising ID.</li>")
	from director.director import funciones_efectivas
	f = funciones_efectivas(diseno)
	infantil = diseno.get("publico") == "infantil"
	if f["online"]:
		es_datos.append("<li><b>Juego online (opcional).</b> Si eliges un apodo para la clasificación, la liga, los clanes, los "
			"amigos o las partidas online, guardamos ese apodo, tus puntuaciones y un número aleatorio del juego (no es el ID de "
			"publicidad). Los demás jugadores ven el apodo y las puntuaciones. No hay chat entre jugadores. Puedes apagar lo "
			"online en Ajustes, lo que borra el apodo del juego; para borrar tus datos del servidor, escríbenos.</li>")
		en_datos.append("<li><b>Online play (optional).</b> If you choose a nickname for the leaderboard, league, clans, friends or "
			"online matches, we store that nickname, your scores and a random in-game number (not the advertising ID). Other "
			"players see the nickname and scores. There is no chat between players. You can turn online play off in Settings, "
			"which removes the nickname from the game; to delete your data from the server, email us.</li>")
		es_datos.append("<li><b>Charla con los personajes.</b> Si hablas con un personaje, el texto que escribes se envía a un "
			"servicio de inteligencia artificial para responder y no se guarda.</li>")
		en_datos.append("<li><b>Chat with the characters.</b> If you talk to a character, what you type is sent to an AI service "
			"to answer and is not stored.</li>")
	if f["tienda"]:
		es_datos.append("<li><b>Compras dentro del juego.</b> Las gestiona Google Play: nosotros no vemos tu tarjeta ni tu cuenta. "
			"Solo recibimos el comprobante de la compra para comprobar que es válida.</li>")
		en_datos.append("<li><b>In-game purchases.</b> Handled by Google Play: we never see your card or account. We only receive "
			"the purchase receipt to check it is valid.</li>")
	if f["nube"]:
		es_datos.append("<li><b>Pasar a otro móvil (opcional).</b> Si lo usas, se guarda una copia de tu partida (niveles, monedas "
			"del juego) con un código y un PIN, y se borra a los 180 días sin uso.</li>")
		en_datos.append("<li><b>Move to another phone (optional).</b> If you use it, a copy of your game (levels, in-game coins) is "
			"stored with a code and PIN, and deleted after 180 days without use.</li>")
	if f["avisos"]:
		es_datos.append("<li><b>Avisos.</b> Los programa el propio juego en tu móvil (premio diario, eventos); no se envía nada. "
			"Puedes apagarlos en Ajustes.</li>")
		en_datos.append("<li><b>Notifications.</b> Scheduled by the game on your phone (daily reward, events); nothing is sent. "
			"You can turn them off in Settings.</li>")
	if not es_datos:
		es_datos.append("<li>El juego <b>no recoge ningún dato personal</b> y funciona sin conexión.</li>")
		en_datos.append("<li>The game <b>does not collect any personal data</b> and works offline.</li>")
	es_ninos = ("Es apto para niños: no tiene compras, avisos ni nada online, y los anuncios son aptos para menores."
		if infantil else "No está dirigido a menores de 13 años.")
	en_ninos = ("It is suitable for children: no purchases, notifications or online features, and ads are child-safe."
		if infantil else "The game is not directed at children under 13.")
	return f"""<h1>{t}: política de privacidad</h1><small>Actualizada el {hoy}</small>
<p>Esta política explica qué datos usa el juego <b>{t}</b>.</p>
<ul>{"".join(es_datos)}</ul>
<p>El juego guarda tu progreso (niveles, estrellas, monedas del juego) en tu dispositivo. No pedimos registro ni cuenta.
{es_ninos} Para cualquier pregunta: <a href="mailto:{c}">{c}</a>.</p>
<h2>{t}: privacy policy</h2><small>Updated {hoy}</small>
<p>This policy explains what data the game <b>{t}</b> uses.</p>
<ul>{"".join(en_datos)}</ul>
<p>Your progress (levels, stars, in-game coins) is stored on your device. No sign-up or account is required.
{en_ninos} Questions: <a href="mailto:{c}">{c}</a>.</p>
"""


def privacidad_html(diseno: dict, correo: str, anuncios: bool, telemetria: bool) -> str:
	"""Pagina completa (para quien sirva HTML: dominio propio o la web de GitHub Pages)."""
	t = html.escape(diseno["titulo"])
	return f"""<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{t} · Privacidad / Privacy</title>
<style>body{{font:16px/1.6 system-ui,sans-serif;max-width:720px;margin:32px auto;padding:0 16px;color:#1b1b1f}}h1{{font-size:24px}}h2{{font-size:19px;margin-top:32px}}small{{color:#666}}</style>
</head><body>
{privacidad_cuerpo(diseno, correo, anuncios, telemetria)}</body></html>
"""


def privacidad_json(diseno: dict, correo: str, anuncios: bool, telemetria: bool) -> str:
	"""Lo que lee web/privacidad.html?j=<juego> (Supabase Storage sirve los .html como texto plano)."""
	return json.dumps({"titulo": diseno["titulo"], "cuerpo": privacidad_cuerpo(diseno, correo, anuncios, telemetria)}, ensure_ascii=False)


def paquete_para(estudio: str, diseno: dict) -> str:
	"""com.<estudio>.<juego> en el formato de Google (solo minusculas y numeros, empieza por letra)."""
	def limpio(t: str) -> str:
		t = t.lower()
		for a, b in zip("áéíóúüñ", "aeiouun"):
			t = t.replace(a, b)
		t = "".join(ch for ch in t if ch.isalnum())
		if not t or not t[0].isalpha():
			t = "j" + t
		return t[:30]
	return f"com.{limpio(estudio)}.{limpio(diseno['titulo'])}"


def resumen_genero(diseno: dict) -> str:
	return generos.de(diseno)["etiqueta"]
