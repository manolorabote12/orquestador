"""Estudio de marketing: de un juego fabricado a 3 clips listos para TikTok, Shorts y Reels.

	python -m marketing.estudio <proyecto> [--simulado] [--voz simulado|piper|elevenlabs|ninguna]

1 - El bot juega ~30 s y se apuntan los momentos (montaje.grabar).
2 - Se eligen los 12.5 s con mas accion (montaje.mejor_ventana).
3 - La IA escribe 3 guiones (reto, curiosidad, humor) sobre lo que pasa en esos segundos y el
    texto de publicacion en espanol e ingles (guion.escribir).
4 - Voz en off de cada guion (voz.generar) y montaje de los 3 MP4 (montaje.montar).
Resultado en <proyecto>/fabrica/marketing/: reto.mp4, curiosidad.mp4, humor.mp4 (+ portadas),
publicacion.json, redes_es.txt, redes_en.txt y marketing.zip con todo.
"""

import argparse
import json
import os
import shutil
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
if str(RAIZ) not in sys.path:
	sys.path.insert(0, str(RAIZ))

import cadena  # noqa: E402
from director import llm  # noqa: E402
from marketing import guion, montaje, voz  # noqa: E402


def textos_redes(pub: dict) -> dict:
	"""Lo que se pega en cada red, a partir del texto de publicacion de la IA."""
	out = {}
	for idioma, p in pub.items():
		tags = " ".join(p["hashtags"])
		out[idioma] = {
			"tiktok": f"{p['texto']}\n\n{tags}",
			"reels": f"{p['texto']}\n\n{tags}",
			"shorts_titulo": (p["titulo"] + " #Shorts")[:100],
			"shorts_descripcion": f"{p['texto']}\n\n{tags} #Shorts",
		}
	return out


def generar(proyecto: Path, simular: bool, gasto: llm.Gasto, quien_voz: str = "", segundos: float = 30.0) -> dict:
	proyecto = Path(proyecto)
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	carpeta = proyecto / "fabrica" / "marketing"
	if carpeta.exists():
		shutil.rmtree(carpeta)
	carpeta.mkdir(parents=True)
	tmp = carpeta / "_tmp"
	tmp.mkdir(parents=True)
	cadena.evento("grabar", "inicio", "El bot está jugando para grabar los mejores momentos...")
	partida, datos = montaje.grabar(proyecto, tmp, segundos)
	inicio = montaje.mejor_ventana(datos)
	momentos = montaje.momentos_texto(datos, inicio, diseno)
	cadena.evento("grabar", "ok", f"Partida grabada: elijo los 15 s con más acción ({len(momentos)} momentos)")
	cadena.evento("guion", "inicio", "Escribiendo 3 guiones: reto, curiosidad y humor...")
	g, modelo = guion.escribir(diseno, momentos, simular, gasto)
	cadena.evento("guion", "ok", "Guiones listos: " + " / ".join(v["gancho"] for v in g["variantes"]))
	quien = quien_voz or voz.proveedor()
	usd_voz = 0.0
	videos = []
	for v in g["variantes"]:
		wav = None
		cadena.evento("montaje", "inicio", f"Montando el vídeo «{v['gancho']}»...")
		try:
			wav = voz.generar(v["voz"], tmp / f"voz_{v['estilo']}.wav", quien, voz.EMOCION.get(v["estilo"], 0.5))
			usd_voz += voz.ULTIMO_USD if wav is not None else 0.0
		except voz.ErrorVoz as e:
			## La voz de IA fallo: se intenta con Piper (va dentro de la fabrica) antes de dejarlo sin voz.
			if quien != "piper" and os.environ.get("ORQ_PIPER_VOZ") and Path(os.environ["ORQ_PIPER_VOZ"]).exists():
				try:
					wav = voz.generar(v["voz"], tmp / f"voz_{v['estilo']}.wav", "piper")
					cadena.evento("montaje", "aviso", f"Voz de respaldo en «{v['gancho']}» ({str(e)[:100]})")
				except voz.ErrorVoz as e2:
					cadena.evento("montaje", "aviso", f"Sin voz en «{v['gancho']}»: {str(e2)[:160]}")
			else:
				cadena.evento("montaje", "aviso", f"Sin voz en «{v['gancho']}»: {str(e)[:160]}")
		mp4 = montaje.montar(proyecto, partida, inicio, v, diseno["titulo"], wav, carpeta / f"{v['estilo']}.mp4", tmp / v["estilo"])
		portada = carpeta / f"{v['estilo']}.jpg"
		montaje._ff(["-ss", "1.2", "-i", str(mp4), "-frames:v", "1", "-q:v", "3", str(portada)])
		videos.append({"estilo": v["estilo"], "gancho": v["gancho"], "voz": v["voz"], "mp4": str(mp4), "portada": str(portada)})
		cadena.evento("montaje", "ok", f"Vídeo «{v['gancho']}» listo")
	## Trailer horizontal (16:9) a partir del primer video: para la ficha de Google Play y YouTube.
	trailer = None
	if videos:
		cadena.evento("montaje", "inicio", "Montando el tráiler horizontal para Google Play y YouTube...")
		trailer = montaje.horizontal(proyecto, Path(videos[0]["mp4"]), diseno["titulo"], diseno.get("lema", ""),
			"¡Gratis en Google Play!", carpeta / "trailer_16x9.mp4")
		cadena.evento("montaje", "ok", "Tráiler horizontal listo")
	redes = textos_redes(g["publicacion"])
	(carpeta / "guion.json").write_text(json.dumps(g, indent=1, ensure_ascii=False), encoding="utf-8")
	(carpeta / "publicacion.json").write_text(json.dumps({"publicacion": g["publicacion"], "redes": redes}, indent=1,
		ensure_ascii=False), encoding="utf-8")
	for idioma, r in redes.items():
		(carpeta / f"redes_{idioma}.txt").write_text(
			f"TIKTOK\n{r['tiktok']}\n\nINSTAGRAM REELS\n{r['reels']}\n\nYOUTUBE SHORTS\nTitulo: {r['shorts_titulo']}\n"
			f"Descripcion:\n{r['shorts_descripcion']}\n", encoding="utf-8")
	zipf = carpeta / "marketing.zip"
	with zipfile.ZipFile(zipf, "w", zipfile.ZIP_DEFLATED) as z:
		for f in sorted(carpeta.iterdir()):
			if f.is_file() and f != zipf:
				z.write(f, f.name)
	shutil.rmtree(tmp, ignore_errors=True)
	return {"videos": videos, "trailer": str(trailer) if trailer else None, "publicacion": g["publicacion"], "redes": redes, "zip": str(zipf), "voz": quien,
		"modelo": modelo, "inicio": inicio, "momentos": momentos, "usd": gasto.usd, "usd_voz": round(usd_voz, 4)}


def main() -> int:
	p = argparse.ArgumentParser(description="3 clips para redes con guion, subtitulos y voz en off hechos por IA")
	p.add_argument("proyecto")
	p.add_argument("--simulado", action="store_true", help="Guion sin IA (sin clave ni coste)")
	p.add_argument("--voz", default="", help="simulado, piper, elevenlabs o ninguna (por defecto: automatico)")
	p.add_argument("--segundos", type=float, default=30.0, help="Segundos de partida grabados para elegir")
	a = p.parse_args()
	gasto = llm.Gasto()
	try:
		r = generar(Path(a.proyecto), a.simulado, gasto, a.voz, a.segundos)
	except (montaje.ErrorMontaje, llm.ErrorIA) as e:
		print("ERROR:", e)
		return 1
	print(json.dumps({k: r[k] for k in ("videos", "zip", "voz", "modelo", "inicio", "momentos", "usd")}, indent=1, ensure_ascii=False))
	return 0


if __name__ == "__main__":
	sys.exit(main())
