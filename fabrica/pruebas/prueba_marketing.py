"""Pruebas del estudio de marketing (guion, eleccion de momentos y montaje de los 3 videos).

	python -m pruebas.prueba_marketing            (rapida: sin grabar)
	python -m pruebas.prueba_marketing --completa (fabrica un juego y monta los 3 videos; ~3 min)
"""

import argparse
import copy
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import cadena
from director import director, llm
from marketing import estudio, guion, montaje, voz

IDEAS = ["un gato ninja que salta por tejados", "un runner que huye sin parar", "un pajaro que vuela de un toque",
	"sobrevive a hordas de zombis", "un puzle de combinar gemas", "defiende tu castillo de oleadas", "carreras de coches"]


def main() -> int:
	p = argparse.ArgumentParser()
	p.add_argument("--completa", action="store_true")
	a = p.parse_args()
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	print("== Guion ==")
	disenos = [director.disenar(i, True, llm.Gasto())[0] for i in IDEAS]
	for d in disenos:
		g, _ = guion.escribir(d, ["seg. 4: derrota al jefe"], True, llm.Gasto())
		check(f"guion simulado valido ({d['genero']})", not guion.validar(g), str(guion.validar(g)[:2]))
	base, _ = guion.escribir(disenos[0], [], True, llm.Gasto())

	def roto(cambio) -> list[str]:
		g = copy.deepcopy(base)
		cambio(g)
		return guion.validar(g)

	check("rechaza dos variantes del mismo estilo", bool(roto(lambda g: g["variantes"][1].update(estilo="reto"))))
	check("rechaza subtitulos que se solapan", bool(roto(lambda g: g["variantes"][0]["subtitulos"][1].update(desde=1.0))))
	check("rechaza subtitulos demasiado cortos", bool(roto(lambda g: g["variantes"][0]["subtitulos"][0].update(hasta=0.6))))
	check("rechaza marcas de otros", bool(roto(lambda g: g["variantes"][2].update(gancho="Mejor que Mario"))))
	check("rechaza promesas falsas", bool(roto(lambda g: g["publicacion"]["es"].update(texto="El juego número 1 de Android, pruébalo ya"))))
	check("rechaza emojis en la voz", bool(roto(lambda g: g["variantes"][0].update(voz=g["variantes"][0]["voz"] + " \U0001F525"))))
	check("rechaza una voz demasiado larga", bool(roto(lambda g: g["variantes"][0].update(voz=("ya " * 45).strip()))))

	print("== Momentos ==")
	datos = {"saltar": 0.5, "seconds": 40.0, "moments": [{"t": 3.0, "event": "coin"}, {"t": 5.0, "event": "checkpoint"},
		{"t": 24.0, "event": "boss_hit"}, {"t": 26.0, "event": "boss_hit"}, {"t": 28.5, "event": "boss_defeated"},
		{"t": 30.0, "event": "level_complete"}]}
	ini = montaje.mejor_ventana(datos)
	check("elige la ventana del jefe", 17.5 <= ini <= 23.5, str(ini))
	textos = montaje.momentos_texto(datos, ini, disenos[0])
	check("cuenta los momentos a la guionista", any("jefe" in t for t in textos), str(textos))
	check("ventana valida sin momentos", montaje.mejor_ventana({"saltar": 6.0, "seconds": 36.0, "moments": []}) == 6.0)

	print("== Redes y voz ==")
	r = estudio.textos_redes(base["publicacion"])
	check("Shorts lleva #Shorts y cabe en 100", r["es"]["shorts_titulo"].endswith("#Shorts") and len(r["es"]["shorts_titulo"]) <= 100)
	check("TikTok lleva texto y hashtags", base["publicacion"]["es"]["hashtags"][0] in r["es"]["tiktok"])
	if shutil.which("ffmpeg"):
		with tempfile.TemporaryDirectory() as t:
			w = voz.generar("una prueba de voz con siete palabras", Path(t) / "v.wav", "simulado")
			check("voz simulada con el ritmo de las palabras", w is not None and 2.0 < voz.duracion(w) < 3.0)
	check("sin voz configurada no se inventa ninguna", voz.generar("hola", Path("/tmp/no_existe.wav"), "ninguna") is None)

	if a.completa and shutil.which("ffmpeg"):
		print("== Montaje completo ==")
		sal = Path(tempfile.mkdtemp(prefix="orq_mkt_prueba_"))
		args = argparse.Namespace(idea="un gato ninja que salta por tejados de noche", salida=str(sal), simulado=True,
			arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=7, apk=False, capturas=False)
		inf = cadena.fabricar(args)
		res = estudio.generar(Path(inf["proyecto"]), True, llm.Gasto(), "simulado", 24.0)
		check("3 videos", len(res["videos"]) == 3)
		for v in res["videos"]:
			info = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_type,width,height", "-show_entries",
				"format=duration", "-of", "json", v["mp4"]], capture_output=True, text=True).stdout
			j = json.loads(info)
			tipos = sorted(s["codec_type"] for s in j["streams"])
			video = next(s for s in j["streams"] if s["codec_type"] == "video")
			dur = float(j["format"]["duration"])
			check(f"{v['estilo']}: 1080x1920, 15 s, con audio", (video["width"], video["height"]) == (1080, 1920)
				and abs(dur - 15.0) < 0.3 and tipos == ["audio", "video"], f"{video['width']}x{video['height']} {dur} {tipos}")
		check("textos y zip", Path(res["zip"]).exists() and (Path(res["zip"]).parent / "publicacion.json").exists())
		j = json.loads(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_type,width,height", "-show_entries",
			"format=duration", "-of", "json", res["trailer"]], capture_output=True, text=True).stdout)
		vid = next(s for s in j["streams"] if s["codec_type"] == "video")
		check("trailer horizontal 1920x1080 con audio", (vid["width"], vid["height"]) == (1920, 1080)
			and any(s["codec_type"] == "audio" for s in j["streams"]), f"{vid['width']}x{vid['height']}")
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "3", "-i", res["trailer"], "-frames:v", "1", "/tmp/claude-0/trailer.png"])
		shutil.rmtree(sal, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
