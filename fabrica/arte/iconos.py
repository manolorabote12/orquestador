"""Iconos de interfaz dibujados por la IA en el estilo de cada juego.

	heart    vidas (lleno; el vacio es el mismo apagado)
	star     estrellas de nivel y de resultado
	trophy   trofeos y clasificacion

La moneda ya es arte del juego (el objeto "moneda"). Los iconos de mando (pausa, atras, jugar,
cerrar, ajustes) siguen siendo vectoriales: tienen que entenderse a la primera en cualquier juego.
Se pide cada icono sobre el fondo croma, se recorta, se comprueba que es una silueta clara,
simetrica y que llena su caja, y se guarda cuadrado. Si un icono no pasa, el juego usa el de
siempre para ese icono (nunca sale roto).
"""

import io
from pathlib import Path

import numpy as np
from PIL import Image

from . import post, prompts, runpod

QUE = {
	"heart": "a single plump glossy heart symbol",
	"star": "a single bold five-pointed star",
	"trophy": "a single trophy cup with two handles on a small base",
}
TAMANO = (768, 768)
SALIDA = 128


def prompt(biblia: dict, icono: str) -> str:
	est = biblia["estilo"]
	chroma = est["fondo_chroma"].upper()
	nombre = {"#FF00FF": "pure magenta", "#00FF00": "pure green"}.get(chroma, chroma)
	return (f"{prompts.estilo_dibujo(est)}. Mobile game user interface icon: {QUE[icono]}, bold readable silhouette, "
		f"thick dark outline, perfectly symmetric, front view, centered, fills most of the image, "
		f"plain solid flat {nombre} background ({chroma}), no text, no letters, no numbers, no characters, no shadow")


def revisar(img: Image.Image) -> list[str]:
	"""Recortado y sin fondo: una silueta solida que llena su caja y es simetrica."""
	a = np.asarray(img).astype(np.float32)
	problemas = []
	alpha = a[..., 3]
	lleno = float((alpha > 200).mean())
	if lleno < 0.3:
		problemas.append("silueta muy fina o con huecos")
	if lleno > 0.97:
		problemas.append("es un cuadrado, no un icono")
	h, w = alpha.shape
	if min(h, w) < 0.45 * max(h, w):
		problemas.append("demasiado alargado")
	espejo = a[:, ::-1, :]
	if float(np.abs(alpha - espejo[..., 3]).mean()) > 45.0:
		problemas.append("no es simetrico")
	return problemas


def cuadrar(img: Image.Image, lado: int = SALIDA) -> Image.Image:
	"""Centra la silueta en un cuadrado transparente (con un poco de aire) sin deformarla."""
	w, h = img.size
	k = (lado * 0.9) / max(w, h)
	pieza = img.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
	lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
	lienzo.paste(pieza, ((lado - pieza.width) // 2, (lado - pieza.height) // 2), pieza)
	return lienzo


def _hex_rgb(h: str) -> tuple[int, int, int]:
	h = h.lstrip("#")
	return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def generar(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, intentos: int = 2) -> tuple[dict, dict]:
	"""Devuelve ({heart|star|trophy: ruta png} con los que pasan el control, informe)."""
	carpeta.mkdir(parents=True, exist_ok=True)
	chroma = _hex_rgb(biblia["estilo"]["fondo_chroma"])
	informe: dict = {"iconos": {}, "fallidos": {}, "generaciones": 0}
	salida: dict = {}
	for i, icono in enumerate(QUE):
		ultimo: list[str] = []
		for intento in range(intentos):
			if intento and runpod.en_ahorro():
				break  # tope suave de GPU: lo que no salga a la primera se queda sin repetir
			try:
				datos = cliente.generar(flujo, {"PROMPT": prompt(biblia, icono), "SEED": semilla + 211 * i + 7919 * intento,
					"ANCHO": TAMANO[0], "ALTO": TAMANO[1]})[0]
			except Exception as e:  # noqa: BLE001 - sin icono el juego usa el de siempre
				ultimo = [str(e)[:120]]
				break
			informe["generaciones"] += 1
			img = post.quitar_fondo_seguro(Image.open(io.BytesIO(datos)).convert("RGBA"), chroma)
			bb = post.caja(img)
			if bb is None:
				ultimo = ["vacio"]
				continue
			img = img.crop(bb)
			ultimo = revisar(img)
			if not ultimo:
				ruta = carpeta / f"{icono}.png"
				cuadrar(img).save(ruta)
				salida[icono] = ruta
				informe["iconos"][icono] = {"intentos": intento + 1}
				break
		if icono not in salida:
			informe["fallidos"][icono] = ultimo
	return salida, informe
