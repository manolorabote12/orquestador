"""Fondos ilustrados del juego (Z-Image en la GPU de RunPod): la pantalla de titulo y la ficha.

	vertical   864x1536  -> pantalla de titulo del juego (el heroe y la moneda van encima, animados)
	horizontal 1536x768  -> grafico destacado de Google Play (ficha.py pone encima heroe, titulo y lema)
	nivel      864x1536  -> detras de los niveles: mas suave y con el centro despejado (se juega encima)

Solo escenario, sin personajes ni textos: asi el heroe de verdad (el de los sprites) es el que sale.
Control de calidad: ni el fondo croma, ni una imagen plana. Si falla, el juego sigue con el fondo
de color de siempre.
"""

from pathlib import Path

import numpy as np
from PIL import Image

from . import runpod

TAMANOS = {"vertical": (864, 1536), "horizontal": (1536, 768), "nivel": (864, 1536)}


def prompt(biblia: dict) -> str:
	estilo = biblia["estilo"]["descripcion"]
	escenario = (biblia.get("escenarios") or [{}])[0].get("descripcion", "")
	return (f"{estilo}, {escenario}, beautiful scenic video game background art for a title screen, "
		"atmospheric lighting, depth and parallax layers, rich detail, empty scene without any characters, "
		"no people, no creatures, no text, no letters, no logo, no watermark, no frame, no user interface")


def prompt_nivel(biblia: dict) -> str:
	"""Fondo para jugar encima: lejano, suave y sin nada en el centro que se confunda con el juego."""
	estilo = biblia["estilo"]["descripcion"]
	escenario = (biblia.get("escenarios") or [{}])[0].get("descripcion", "")
	return (f"{estilo}, {escenario}, distant background layer for a mobile game level, far away scenery, "
		"soft gentle lighting, calm low contrast colors, simple shapes, open empty sky in the middle, "
		"atmospheric perspective, no foreground objects, no platforms, no characters, no creatures, no text, "
		"no letters, no logo, no user interface")


def revisar(img: Image.Image) -> list[str]:
	a = np.asarray(img.convert("RGB"), dtype=np.float32)
	problemas = []
	if float(a.std()) < 12.0:
		problemas.append("imagen plana")
	magenta = (a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200)
	if float(magenta.mean()) > 0.2:
		problemas.append("fondo croma")
	if float(a.mean()) < 18.0:
		problemas.append("demasiado oscura")
	return problemas


def generar(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, intentos: int = 2) -> tuple[dict[str, Path], dict]:
	import io

	carpeta.mkdir(parents=True, exist_ok=True)
	salida: dict[str, Path] = {}
	informe: dict = {"fondos": {}, "fallidos": {}, "generaciones": 0}
	for i, (nombre, (w, h)) in enumerate(TAMANOS.items()):
		texto = prompt_nivel(biblia) if nombre == "nivel" else prompt(biblia)
		ultimo: list[str] = []
		for intento in range(intentos):
			if intento and runpod.en_ahorro():
				break  # tope suave de GPU: lo que no salga a la primera se queda sin repetir
			try:
				datos = cliente.generar(flujo, {"PROMPT": texto, "SEED": semilla + 101 * i + 7919 * intento, "ANCHO": w, "ALTO": h})[0]
			except Exception as e:  # noqa: BLE001 - sin fondo el juego funciona igual
				ultimo = [str(e)[:120]]
				break
			informe["generaciones"] += 1
			img = Image.open(io.BytesIO(datos)).convert("RGB")
			if img.size != (w, h):
				img = img.resize((w, h), Image.LANCZOS)
			ultimo = revisar(img)
			if not ultimo:
				ruta = carpeta / f"fondo_{nombre}.png"
				img.save(ruta)
				salida[nombre] = ruta
				informe["fondos"][nombre] = {"intentos": intento + 1}
				break
		if nombre not in salida:
			informe["fallidos"][nombre] = ultimo
	return salida, informe
