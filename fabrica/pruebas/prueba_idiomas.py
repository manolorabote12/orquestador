"""Idiomas de los juegos: catalogo completo y coherente, traduccion propia comprobada y guardada.

	python -m pruebas.prueba_idiomas
"""

import json
import re
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))

from director import director  # noqa: E402
import generos  # noqa: E402
from textos import traducir  # noqa: E402

fallos = 0


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + ("" if ok else "  " + detalle))
	fallos += 0 if ok else 1


def marcas(t: str) -> list[str]:
	return sorted(re.findall(r"\{\w+\}|%d|%s", t))


def main() -> int:
	cat = traducir.CATALOGO
	langs = cat["idiomas"][1:]
	claves = set(cat["textos"]["en"])
	check("todos los idiomas tienen las mismas claves", all(set(cat["textos"][l]) == claves for l in langs))
	## 1 - Cubre todo lo que el kit escribe con Kit.text (salvo lo propio de cada juego).
	kit: dict[str, str] = {}
	for f in (RAIZ.parent / "orqkit" / "kit").rglob("*.gd"):
		for m in re.finditer(r'Kit\.text\(\s*"([^"]+)"\s*,\s*"((?:[^"\\]|\\.)*)"', f.read_text(encoding="utf-8")):
			kit.setdefault(m.group(1), m.group(2))
	base = dict(director.TEXTOS_BASE)
	for g in generos.GENEROS.values():
		base.update(g["textos"])
	todas = dict(kit, **base)
	faltan = sorted(k for k in todas if k not in claves and k not in ("tagline", "coins", "title"))
	check("el catalogo cubre todos los textos del kit y de los generos", not faltan, str(faltan))
	## 2 - Mismos marcadores ({n}, %d) que el original.
	malos = [f"{l}:{k}" for l in langs for k, v in cat["textos"][l].items() if k in todas and marcas(v) != marcas(todas[k].encode().decode("unicode_escape") if "\\u" in todas[k] else todas[k])]
	check("las traducciones conservan {marcas} y %d", not malos, str(malos[:6]))
	check("ningun texto vacio", all(str(v).strip() for l in langs for v in cat["textos"][l].values()))
	## 3 - Lo propio del juego: fuente, comprobacion y aplicacion.
	game = {"texts": {"coins": "Tuercas", "tagline": "Salta"}, "levels": [{"name": "Uno"}, {"name": "Dos",
		"questions": [{"q": "¿2+2?", "a": ["1", "2", "3", "4"], "ok": 3, "why": "suma"}]}],
		"story": {"levels": [{"intro": [{"who": "heroe", "text": "Hola", "voice": "d0_0"}], "outro": []},
			{"intro": [], "outro": [{"who": "rival", "text": "Adiós"}]}]}}
	src = traducir.fuente(game)
	check("fuente: coleccionable, lema, niveles, frases y preguntas", src["niveles"] == ["Uno", "Dos"] and src["frases"] == ["Hola", "Adiós"] and len(src["preguntas"]) == 1)
	buena = {"coins": "Nuts", "tagline": "Jump", "niveles": ["One", "Two"], "frases": ["Hi", "Bye"],
		"preguntas": [{"q": "2+2?", "a": ["1", "2", "3", "4"], "why": "sum"}]}
	check("traduccion completa aceptada", traducir.comprobar(src, buena) == [])
	corta = dict(buena, frases=["Hi"])
	check("traduccion con frases de menos rechazada", any("frases" in e for e in traducir.comprobar(src, corta)))
	vacia = dict(buena, niveles=["One", " "])
	check("traduccion con textos vacios rechazada", traducir.comprobar(src, vacia) != [])
	ap = traducir.aplicar(game, buena)
	check("aplicar: nivel, pregunta (con su respuesta) e historia sin voz",
		ap["_levels"][1]["name"] == "Two" and ap["_levels"][1]["questions"][0]["ok"] == 3 and ap["_levels"][1]["questions"][0]["q"] == "2+2?"
		and ap["_story"][0]["intro"][0] == {"who": "heroe", "text": "Hi"} and ap["coins"] == "Nuts")
	## 4 - Sin IA: interfaz traducida y lo propio en el original.
	sin = traducir.i18n(game, None, None)
	check("sin IA: cinco idiomas con la interfaz", sorted(sin) == sorted(langs) and sin["en"]["play"] == "Play" and "_levels" not in sin["en"])
	## 5 - Con IA (simulada): una llamada por idioma la primera vez; la segunda sale de la cache.
	llamadas = []
	original = traducir.traducir_ia
	traducir.traducir_ia = lambda s, l, g: (llamadas.append(l), buena)[1]
	try:
		with tempfile.TemporaryDirectory() as tmp:
			cache = Path(tmp) / "traducciones.json"
			uno = traducir.i18n(game, cache, None)
			n1 = len(llamadas)
			dos = traducir.i18n(game, cache, None)
			check("con IA: una llamada por idioma", n1 == len(langs), str(n1))
			check("segunda vez: de la cache, sin pagar", len(llamadas) == n1 and dos == uno)
			game["texts"]["tagline"] = "Salta mucho"
			traducir.i18n(game, cache, None)
			check("si cambia un texto, se vuelve a traducir", len(llamadas) == 2 * n1)
			check("la traduccion propia entra en el juego", uno["fr"]["coins"] == "Nuts" and uno["de"]["_levels"][0]["name"] == "One")
	finally:
		traducir.traducir_ia = original
	## 6 - Ficha de la tienda en los 6 idiomas, dentro de los limites de Google, en todos los generos.
	import ficha
	malos = []
	for g in generos.ORDEN:
		d = {"genero": g, "titulo": "Remache al Rescate", "lema": "Tuercas y chatarra", "heroe": {"nombre": "Remache"},
			"coleccionable": {"nombre_plural": "tuercas"}, "enemigos": [{"nombre": "Chatarrilla"}], "niveles": ["a", "b"],
			"jefe": {"nombre": "Rey Rata"}, "poderes": True}
		tx = ficha.textos(d, 8)
		if sorted(tx) != sorted(traducir.IDIOMAS):
			malos.append(f"{g}: idiomas {sorted(tx)}")
		for l, v in tx.items():
			if not (0 < len(v["titulo"]) <= 30 and 0 < len(v["corta"]) <= 80 and 0 < len(v["larga"]) <= 4000) or v["corta"].endswith("…"):
				malos.append(f"{g}/{l}: {v['corta']}")
	check("ficha en 6 idiomas dentro de los limites (todos los generos)", not malos, str(malos[:4]))
	check("cada genero tiene su frase traducida", all(set(traducir.CATALOGO["generos"].get(g, {})) == {"pt", "fr", "de", "it"} for g in generos.ORDEN))
	## 7 - Cualquier idioma: japones, arabe... (registro, idea, taller e interfaz del kit traducida una vez).
	from textos import idiomas
	from director import cambios as cambios_mod, director as director_mod
	check("mas de 30 idiomas con su ficha de Google Play", len(idiomas.LENGUAS) >= 30 and all(v["play"] for v in idiomas.LENGUAS.values()))
	check("la idea pide idiomas", idiomas.de_la_idea("un runner de un zorro en japones y en coreano") == ["ja", "ko"]
		and len(idiomas.de_la_idea("en todos los idiomas")) >= 25)
	d0, _ = director_mod.disenar("un juego de plataformas de un gato ninja en ruso", True, None)
	check("el diseno guarda los idiomas pedidos", d0.get("idiomas") == ["ru"])
	pl = cambios_mod.plan_simulado("traducelo al japones y al arabe", d0)
	check("el taller traduce a mas idiomas (sin quitar los que habia)", pl["operaciones"] == [{"op": "idiomas", "idiomas": ["ar", "ja", "ru"]}]
		and cambios_mod.validar_plan(pl, d0) == [], str(pl["operaciones"]))
	g2 = {"texts": {"coins": "tuercas", "tagline": "Salta"}, "levels": [{"name": "Uno"}], "langs": ["ja", "xx"]}
	sin_ia = traducir.i18n(g2, None, None)
	check("sin IA: el idioma nuevo sale con la interfaz en ingles y su nombre", "ja" in sin_ia and "xx" not in sin_ia
		and sin_ia["ja"]["_name"] == "日本語" and sin_ia["ja"]["play"] == traducir.CATALOGO["textos"]["en"]["play"])
	orig_cat = traducir.traducir_catalogo_ia
	tmp_extra = Path(tempfile.mkdtemp())
	orig_extra = traducir.EXTRA
	traducir.EXTRA = tmp_extra
	try:
		def falsa_cat(lang, textos, gasto):
			## Una traduccion que pierde un marcador no se acepta (se queda la inglesa).
			out = {k: "JA " + v for k, v in textos.items()}
			if "level_n" in out:
				out["level_n"] = "レベル"
			return {k: v for k, v in out.items() if traducir._marcas(v) == traducir._marcas(textos[k])}
		traducir.traducir_catalogo_ia = falsa_cat
		cat = traducir.catalogo("ja", None)
		check("la interfaz del kit se traduce y se guarda para todos los juegos", cat["play"].startswith("JA ") and (tmp_extra / "ja.json").exists())
		check("si se pierde un marcador (%d), se queda el texto ingles", cat["level_n"] == traducir.CATALOGO["textos"]["en"]["level_n"])
		traducir.traducir_catalogo_ia = lambda *a: (_ for _ in ()).throw(AssertionError("no debia llamar"))
		check("la segunda vez sale del archivo, sin pagar", traducir.catalogo("ja", None)["play"].startswith("JA "))
	finally:
		traducir.traducir_catalogo_ia = orig_cat
		traducir.EXTRA = orig_extra
	## 8 - Ficha de Google Play en los idiomas extra (la IA traduce; lo que no cabe no se usa).
	import ficha as ficha_mod
	base_tx = ficha_mod.textos({"genero": "runner", "titulo": "Zorro Veloz", "lema": "Corre", "heroe": {"nombre": "Zorro"},
		"coleccionable": {"nombre_plural": "bayas"}, "enemigos": [{"nombre": "Lobo"}], "niveles": ["a"]}, 5)
	orig_f = ficha_mod._traducir_ficha_ia
	try:
		ficha_mod._traducir_ficha_ia = lambda en, l, g: {"corta": "JA " + en["corta"][:60], "larga": "JA " + en["larga"]} if l == "ja" else {"corta": "x" * 200, "larga": "y"}
		extra_tx = ficha_mod.textos_otros_idiomas(base_tx, ["ja", "ko"], None)
		check("ficha en idiomas extra: se traduce y la que no cabe no se usa", list(extra_tx) == ["ja"] and extra_tx["ja"]["titulo"] == "Zorro Veloz"
			and extra_tx["ja"]["corta"].startswith("JA "))
	finally:
		ficha_mod._traducir_ficha_ia = orig_f
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
