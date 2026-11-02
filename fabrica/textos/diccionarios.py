"""Diccionarios de los juegos de palabras (orqkit/kit/words/dicts/<idioma>.txt).

Herramienta para quien mantiene Orquestador (no se usa al fabricar): sale de las listas de
frecuencia de wordfreq (datos CC BY-SA 4.0, Robyn Speer y colaboradores) y de los diccionarios
hunspell de LibreOffice (solo como filtro: no se copian). Se ejecuta una vez y los .txt se guardan
con el kit.

	python -m textos.diccionarios --wordfreq <carpeta con wordfreq> --hunspell <carpeta con dictionary-xx>

1 - Palabras de 3 a 8 letras, en mayusculas y sin tildes (la Ñ se queda), ordenadas de mas a
    menos usadas; sin repetidas al quitar tildes.
2 - Fuera nombres propios: si hunspell solo la tiene con mayuscula (Paraguay, Vittorio), no vale
    (salvo en aleman, donde todos los sustantivos van con mayuscula).
3 - Fuera palabrotas e insultos (lista propia por idioma, abajo).
4 - Una «*» al final marca las que pueden ser solucion (comunes y en el diccionario tal cual);
    las demas solo valen como intento (plurales, verbos conjugados...).
"""

import argparse
import sys
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SALIDA = RAIZ / "orqkit" / "kit" / "words" / "dicts"
IDIOMAS = {"es": "dictionary-es", "en": "dictionary-en", "pt": "dictionary-pt", "fr": "dictionary-fr", "de": "dictionary-de", "it": "dictionary-it"}
LETRAS = {"es": "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"}
TOTAL = 60000
SOLUCIONES = 9000

## Palabras que nunca salen (ni como solucion ni como intento valido). Se comparan ya limpias.
BLOQUEO = {
	"es": "PUTA PUTO PUTAS PUTOS JODER JODIDO JODIDA COÑO COJONES CABRON CABRONA MIERDA POLLA POLLAS CULO CULOS MARICON MARICA ZORRA "
		"ZORRAS GILIPOLLAS PENDEJO PENDEJA PUÑETA CHINGAR CHINGADA VERGA PERRA PERRAS MAMADA PAJA PAJAS FOLLAR FOLLA TETAS TETA "
		"NAZI NAZIS NEGRATA SUDACA PUTITA COCA DROGA DROGAS VIOLAR VIOLADOR",
	"en": "FUCK FUCKS FUCKED FUCKER SHIT SHITS BITCH BITCHES CUNT CUNTS DICK DICKS COCK COCKS PUSSY WHORE WHORES SLUT SLUTS FAG FAGS "
		"FAGGOT NIGGER NIGGA RETARD BASTARD ASS ARSE ASSHOLE TWAT WANK WANKER PISS PORN PORNO NAZI NAZIS RAPE RAPED RAPIST BOOBS TITS "
		"COCAINE HEROIN DILDO HORNY SEXY",
	"pt": "PUTA PUTAS PUTO CARALHO PORRA MERDA FODA FODER FODIDO CU BUCETA CACETE VIADO BICHA PIROCA PICA ARROMBADO CORNO PUNHETA "
		"XOXOTA BOSTA NAZI NAZIS ESTUPRO DROGA",
	"fr": "PUTE PUTES PUTAIN MERDE CONNARD CONNASSE CON CONS SALOPE SALOPES ENCULE ENCULER BITE BITES CHATTE NIQUE NIQUER PEDE "
		"PEDES BRANLE BRANLER FOUTRE COUILLE COUILLES NAZI NAZIS VIOL VIOLER DROGUE PORNO",
	"de": "SCHEISSE SCHEISS FICKEN FICK FOTZE HURE HUREN ARSCH ARSCHLOCH WICHSER SCHWANZ TITTEN MISTSTUCK SCHLAMPE NUTTE NAZI "
		"NAZIS NEGER SCHWUCHTEL PORNO VERGEWALTIGUNG KOKAIN ANTIFA",
	"it": "CAZZO CAZZI MERDA FIGA PUTTANA PUTTANE TROIA TROIE STRONZO STRONZA VAFFANCULO CULO CULI FROCIO MINCHIA COGLIONE "
		"COGLIONI BASTARDO PORCO NAZI NAZISTA STUPRO DROGA PORNO",
}


def limpiar(w: str, idioma: str) -> str:
	"""Como clean() del kit (kit/words/words_map.gd): mayusculas, sin tildes, la Ñ se queda, ß -> SS."""
	s = w.strip().upper().replace("ß", "SS")
	out = []
	for ch in s:
		if ch == "Ñ":
			out.append(ch)
			continue
		base = unicodedata.normalize("NFD", ch)[0]
		out.append(base)
	return "".join(out)


def valida(w: str, idioma: str) -> bool:
	letras = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" + ("Ñ" if idioma == "es" else "")
	return 3 <= len(w) <= 8 and all(c in letras for c in w)


def leer_hunspell(ruta: Path) -> tuple[set[str], set[str]]:
	"""(palabras en minuscula, palabras que solo estan con mayuscula) del .dic."""
	minus, mayus = set(), set()
	texto = ruta.read_text(encoding="utf-8", errors="ignore").splitlines()
	for linea in texto[1:]:
		p = linea.split("/")[0].split("\t")[0].strip()
		if not p or " " in p:
			continue
		if p[0].isupper():
			mayus.add(p.lower())
		else:
			minus.add(p)
	return minus, mayus - minus


def construir(idioma: str, hunspell: Path) -> list[str]:
	from wordfreq import top_n_list
	minus, propios = leer_hunspell(hunspell / IDIOMAS[idioma] / "package" / "index.dic")
	## En aleman todos los sustantivos van con mayuscula: ahi un nombre propio es el que tambien
	## es nombre propio en los diccionarios de los otros idiomas (Anita, Tina, Iran...).
	if idioma == "de":
		otros: set[str] = set()
		for l2, carpeta in IDIOMAS.items():
			if l2 != "de":
				otros |= leer_hunspell(hunspell / carpeta / "package" / "index.dic")[1]
		minus = minus | (propios - otros)
		propios = propios & otros
	bloqueo = set(BLOQUEO[idioma].split())
	vistas: set[str] = set()
	out: list[str] = []
	soluciones = 0
	for w in top_n_list(idioma, TOTAL):
		if not w.isalpha() or w in propios:
			continue
		c = limpiar(w, idioma)
		if not valida(c, idioma) or c in vistas or c in bloqueo:
			continue
		vistas.add(c)
		sol = w in minus and soluciones < SOLUCIONES
		if sol:
			soluciones += 1
		out.append(c + ("*" if sol else ""))
	return out


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--wordfreq", required=True, help="carpeta donde esta instalado wordfreq")
	ap.add_argument("--hunspell", required=True, help="carpeta con dictionary-es-X/, dictionary-en-X/... (de npm)")
	a = ap.parse_args()
	sys.path.insert(0, a.wordfreq)
	carpetas = {p.name.rsplit("-", 1)[0]: p for p in Path(a.hunspell).iterdir() if p.is_dir()}
	SALIDA.mkdir(parents=True, exist_ok=True)
	## La carpeta de npm lleva la version (dictionary-es-4.0.0): se busca por prefijo.
	base = Path(a.hunspell)
	for idioma in list(IDIOMAS):
		IDIOMAS[idioma] = carpetas[IDIOMAS[idioma]].name
	for idioma in IDIOMAS:
		lista = construir(idioma, base)
		cab = (f"# Diccionario de juegos de palabras ({idioma}): {len(lista)} palabras de 3 a 8 letras, de mas a menos usadas.\n"
			"# '*' = puede ser solucion. Datos: wordfreq (CC BY-SA 4.0, Robyn Speer y colaboradores); filtro de nombres propios\n"
			"# con los diccionarios hunspell de LibreOffice. Esta lista se publica con la misma licencia CC BY-SA 4.0.\n")
		(SALIDA / f"{idioma}.txt").write_text(cab + "\n".join(lista) + "\n", encoding="utf-8")
		print(idioma, len(lista), sum(1 for x in lista if x.endswith("*")))
	return 0


if __name__ == "__main__":
	sys.exit(main())
