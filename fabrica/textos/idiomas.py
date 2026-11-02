"""Idiomas a los que se puede traducir un juego (ademas de los 6 de siempre, traducidos a mano).

Cada uno: nombre en ingles (para la IA), nombre en su idioma (para el selector del juego),
idioma de la ficha de Google Play y escritura (las no latinas usan las fuentes del movil).
"""

LENGUAS: dict[str, dict] = {
	"es": {"en": "Spanish", "nativo": "Español", "play": "es-ES", "escritura": "latina", "claves": ["espanol", "castellano"]},
	"en": {"en": "English", "nativo": "English", "play": "en-US", "escritura": "latina", "claves": ["ingles", "english"]},
	"pt": {"en": "Brazilian Portuguese", "nativo": "Português", "play": "pt-BR", "escritura": "latina", "claves": ["portugues", "brasileno"]},
	"fr": {"en": "French", "nativo": "Français", "play": "fr-FR", "escritura": "latina", "claves": ["frances"]},
	"de": {"en": "German", "nativo": "Deutsch", "play": "de-DE", "escritura": "latina", "claves": ["aleman"]},
	"it": {"en": "Italian", "nativo": "Italiano", "play": "it-IT", "escritura": "latina", "claves": ["italiano"]},
	"ja": {"en": "Japanese", "nativo": "日本語", "play": "ja-JP", "escritura": "cjk", "claves": ["japones"]},
	"ko": {"en": "Korean", "nativo": "한국어", "play": "ko-KR", "escritura": "cjk", "claves": ["coreano"]},
	"zh": {"en": "Simplified Chinese", "nativo": "简体中文", "play": "zh-CN", "escritura": "cjk", "claves": ["chino", "mandarin"]},
	"ru": {"en": "Russian", "nativo": "Русский", "play": "ru-RU", "escritura": "cirilica", "claves": ["ruso"]},
	"uk": {"en": "Ukrainian", "nativo": "Українська", "play": "uk", "escritura": "cirilica", "claves": ["ucraniano"]},
	"pl": {"en": "Polish", "nativo": "Polski", "play": "pl-PL", "escritura": "latina", "claves": ["polaco"]},
	"nl": {"en": "Dutch", "nativo": "Nederlands", "play": "nl-NL", "escritura": "latina", "claves": ["holandes", "neerlandes"]},
	"sv": {"en": "Swedish", "nativo": "Svenska", "play": "sv-SE", "escritura": "latina", "claves": ["sueco"]},
	"da": {"en": "Danish", "nativo": "Dansk", "play": "da-DK", "escritura": "latina", "claves": ["danes"]},
	"no": {"en": "Norwegian", "nativo": "Norsk", "play": "no-NO", "escritura": "latina", "claves": ["noruego"]},
	"fi": {"en": "Finnish", "nativo": "Suomi", "play": "fi-FI", "escritura": "latina", "claves": ["finlandes"]},
	"cs": {"en": "Czech", "nativo": "Čeština", "play": "cs-CZ", "escritura": "latina", "claves": ["checo"]},
	"ro": {"en": "Romanian", "nativo": "Română", "play": "ro", "escritura": "latina", "claves": ["rumano"]},
	"hu": {"en": "Hungarian", "nativo": "Magyar", "play": "hu-HU", "escritura": "latina", "claves": ["hungaro"]},
	"el": {"en": "Greek", "nativo": "Ελληνικά", "play": "el-GR", "escritura": "griega", "claves": ["griego"]},
	"tr": {"en": "Turkish", "nativo": "Türkçe", "play": "tr-TR", "escritura": "latina", "claves": ["turco"]},
	"ar": {"en": "Arabic", "nativo": "العربية", "play": "ar", "escritura": "arabe", "claves": ["arabe"]},
	"he": {"en": "Hebrew", "nativo": "עברית", "play": "iw-IL", "escritura": "hebrea", "claves": ["hebreo"]},
	"hi": {"en": "Hindi", "nativo": "हिन्दी", "play": "hi-IN", "escritura": "devanagari", "claves": ["hindi"]},
	"bn": {"en": "Bengali", "nativo": "বাংলা", "play": "bn-BD", "escritura": "bengali", "claves": ["bengali"]},
	"id": {"en": "Indonesian", "nativo": "Bahasa Indonesia", "play": "id", "escritura": "latina", "claves": ["indonesio"]},
	"ms": {"en": "Malay", "nativo": "Bahasa Melayu", "play": "ms", "escritura": "latina", "claves": ["malayo"]},
	"vi": {"en": "Vietnamese", "nativo": "Tiếng Việt", "play": "vi", "escritura": "latina", "claves": ["vietnamita"]},
	"th": {"en": "Thai", "nativo": "ไทย", "play": "th", "escritura": "tailandesa", "claves": ["tailandes"]},
	"fil": {"en": "Filipino", "nativo": "Filipino", "play": "fil", "escritura": "latina", "claves": ["filipino", "tagalo"]},
	"ca": {"en": "Catalan", "nativo": "Català", "play": "ca", "escritura": "latina", "claves": ["catalan"]},
	"eu": {"en": "Basque", "nativo": "Euskara", "play": "eu-ES", "escritura": "latina", "claves": ["euskera", "vasco"]},
	"gl": {"en": "Galician", "nativo": "Galego", "play": "gl-ES", "escritura": "latina", "claves": ["gallego"]},
}
## Los que llevan todos los juegos (traducidos a mano en catalogo.json).
SIEMPRE = ["es", "en", "pt", "fr", "de", "it"]
## Atajos: «a todos los idiomas» o «a los idiomas de Asia».
GRUPOS = {
	"todos": [k for k in LENGUAS if k not in SIEMPRE],
	"asia": ["ja", "ko", "zh", "hi", "id", "vi", "th", "fil"],
	"europa": ["ru", "pl", "nl", "sv", "tr", "cs", "ro", "el", "uk"],
}


NOMBRE_ES = {'es': 'español', 'en': 'inglés', 'pt': 'portugués', 'fr': 'francés', 'de': 'alemán', 'it': 'italiano', 'ja': 'japonés', 'ko': 'coreano', 'zh': 'chino', 'ru': 'ruso', 'uk': 'ucraniano', 'pl': 'polaco', 'nl': 'neerlandés', 'sv': 'sueco', 'da': 'danés', 'no': 'noruego', 'fi': 'finlandés', 'cs': 'checo', 'ro': 'rumano', 'hu': 'húngaro', 'el': 'griego', 'tr': 'turco', 'ar': 'árabe', 'he': 'hebreo', 'hi': 'hindi', 'bn': 'bengalí', 'id': 'indonesio', 'ms': 'malayo', 'vi': 'vietnamita', 'th': 'tailandés', 'fil': 'filipino', 'ca': 'catalán', 'eu': 'euskera', 'gl': 'gallego'}


def nombre(code: str) -> str:
	return LENGUAS.get(code, {}).get("en", code)


def de_la_idea(idea: str) -> list[str]:
	"""Idiomas que pide una idea con palabras («en japones y coreano», «en todos los idiomas»)."""
	import unicodedata
	t = "".join(c for c in unicodedata.normalize("NFKD", idea.lower()) if not unicodedata.combining(c))
	if "todos los idiomas" in t or "cualquier idioma" in t:
		return list(GRUPOS["todos"])
	out = []
	for code, d in LENGUAS.items():
		if code in SIEMPRE:
			continue
		if any(f"en {k}" in t or f"al {k}" in t or f"y {k}" in t or f", {k}" in t for k in d["claves"]):
			out.append(code)
	return out
