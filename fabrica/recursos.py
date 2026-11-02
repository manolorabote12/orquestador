"""Comprueba que las imagenes y textos de la ficha cumplen las reglas de cada tienda ANTES de subirlos.

Reglas (revisadas en octubre de 2026; si una tienda las cambia, se cambian aqui):
	Google Play  icono 512x512 PNG 32 bits (RGBA); grafico destacado 1024x500 JPEG o PNG de 24 bits
	             sin alfa; capturas de movil 2 a 8, PNG/JPEG sin alfa, lados entre 320 y 3840 px y
	             proporcion entre 1:1 y 2:1; titulo <=30, descripcion breve <=80, completa <=4000.
	App Store    icono 1024x1024 PNG sin alfa; capturas iPhone 6,9" 1320x2868, 1290x2796 o 1260x2736
	             (1 a 10, sin alfa); nombre <=30, subtitulo <=30, promocional <=170, descripcion
	             <=4000, palabras clave <=100.

	python -m recursos <carpeta de la ficha>
"""

import json
import sys
from pathlib import Path

from PIL import Image

IPHONE_69 = {(1320, 2868), (1290, 2796), (1260, 2736)}


def _sin_alfa(im: Image.Image) -> bool:
	return im.mode in ("RGB", "L", "P") and "transparency" not in im.info


def _capturas_play(carpeta: Path, problemas: list[str], nombre: str) -> None:
	fotos = sorted(carpeta.glob("*.png")) + sorted(carpeta.glob("*.jpg"))
	if not 2 <= len(fotos) <= 8:
		problemas.append(f"{nombre}: Google Play pide de 2 a 8 capturas (hay {len(fotos)})")
	for f in fotos:
		im = Image.open(f)
		w, h = im.size
		if not (320 <= w <= 3840 and 320 <= h <= 3840):
			problemas.append(f"{f.name}: cada lado entre 320 y 3840 px (tiene {w}x{h})")
		if max(w, h) / min(w, h) > 2.0 + 1e-6:
			problemas.append(f"{f.name}: proporcion mayor de 2:1 ({w}x{h})")
		if not _sin_alfa(im):
			problemas.append(f"{f.name}: sin canal alfa")


def validar(carpeta: Path) -> list[str]:
	carpeta = Path(carpeta)
	p: list[str] = []
	ic = carpeta / "icono_512.png"
	if not ic.exists():
		p.append("falta icono_512.png")
	else:
		im = Image.open(ic)
		if im.size != (512, 512) or im.mode != "RGBA" or im.format != "PNG":
			p.append(f"icono_512.png: Google pide 512x512 PNG de 32 bits (tiene {im.size} {im.mode})")
		elif im.getchannel("A").getextrema()[0] < 255:
			p.append("icono_512.png: tiene zonas transparentes; Google redondea y sombrea el icono el solo")
		if ic.stat().st_size > 1024 * 1024:
			p.append("icono_512.png: pesa mas de 1 MB")
	de = carpeta / "destacado_1024x500.png"
	if not de.exists():
		p.append("falta destacado_1024x500.png")
	else:
		im = Image.open(de)
		if im.size != (1024, 500) or not _sin_alfa(im):
			p.append(f"destacado: 1024x500 sin alfa (tiene {im.size} {im.mode})")
	for sub in ("capturas", "capturas_en", "capturas_pt", "capturas_fr", "capturas_de", "capturas_it"):
		if (carpeta / sub).exists():
			_capturas_play(carpeta / sub, p, sub)
	tx = carpeta / "textos.json"
	if tx.exists():
		t = json.loads(tx.read_text(encoding="utf-8"))
		for idioma, v in t.items():
			for campo, maximo in (("titulo", 30), ("corta", 80), ("larga", 4000)):
				if not 0 < len(v.get(campo, "")) <= maximo:
					p.append(f"textos {idioma}/{campo}: entre 1 y {maximo} caracteres (tiene {len(v.get(campo, ''))})")
	ios = carpeta / "appstore"
	if ios.exists():
		ic = ios / "icono_1024.png"
		if not ic.exists():
			p.append("appstore: falta icono_1024.png")
		else:
			im = Image.open(ic)
			if im.size != (1024, 1024) or not _sin_alfa(im):
				p.append(f"appstore icono: 1024x1024 sin alfa (tiene {im.size} {im.mode})")
		for sub in ("capturas_es", "capturas_en"):
			fotos = sorted((ios / sub).glob("*.png")) if (ios / sub).exists() else []
			if not 1 <= len(fotos) <= 10:
				p.append(f"appstore {sub}: de 1 a 10 capturas (hay {len(fotos)})")
			for f in fotos:
				im = Image.open(f)
				if im.size not in IPHONE_69 or not _sin_alfa(im):
					p.append(f"appstore {f.name}: iPhone de 6,9 pulgadas sin alfa (tiene {im.size} {im.mode})")
		txi = ios / "textos.json"
		if txi.exists():
			for idioma, v in json.loads(txi.read_text(encoding="utf-8")).items():
				for campo, maximo in (("nombre", 30), ("subtitulo", 30), ("promocional", 170), ("descripcion", 4000), ("palabras_clave", 100)):
					if not 0 < len(v.get(campo, "")) <= maximo:
						p.append(f"appstore textos {idioma}/{campo}: entre 1 y {maximo} caracteres")
	return p


if __name__ == "__main__":
	problemas = validar(Path(sys.argv[1]))
	print("\n".join(problemas) or "Todo cumple las reglas de Google Play y App Store")
	sys.exit(1 if problemas else 0)
