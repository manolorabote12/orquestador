"""Interfaz dibujada por la IA (marcos de panel y botones en el estilo de cada juego).

	panel           marco decorado con el centro liso (ventanas de resultado, pausa, ajustes...)
	boton           boton normal
	boton_primario  el mismo boton con el centro del color de acento (la accion principal)

Se pide sobre el fondo croma, se recorta, se comprueba y se ARREGLA EL CENTRO: se funde con el
color de panel (o de acento) que ya tiene el contraste comprobado con el texto. Asi el marco es
arte de verdad y el texto se sigue leyendo igual de bien que con la interfaz de siempre.
Si algo no pasa el control, el juego usa la interfaz de siempre (nunca sale roto).
"""

import io
from pathlib import Path

import numpy as np
from PIL import Image

from . import interfaz, post, runpod

TAMANOS = {"panel": (1024, 1024), "boton": (1024, 512)}
SALIDA = {"panel": (384, 384), "boton": (384, 192)}
## Parte del borde que es marco (lo que no se estira) en cada pieza.
MARGEN = {"panel": 0.2, "boton": 0.24}


def prompt(biblia: dict, pieza: str) -> str:
	est = biblia["estilo"]
	chroma = est["fondo_chroma"].upper()
	nombre = {"#FF00FF": "pure magenta", "#00FF00": "pure green"}.get(chroma, chroma)
	escenario = (biblia.get("escenarios") or [{}])[0].get("descripcion", "")
	que = ("an empty rectangular dialog window panel with a thick decorative border frame and a plain flat center"
		if pieza == "panel" else
		"a single wide rounded rectangular game button, thick border, glossy bevel, plain flat center")
	return (f"{est['descripcion']}. Mobile game user interface asset: {que}, made of materials that match "
		f"{escenario}, perfectly symmetric, front view, centered, fills most of the image, "
		f"plain solid flat {nombre} background ({chroma}), no text, no letters, no icons, no characters, no shadow")


def revisar(img: Image.Image) -> list[str]:
	"""Recortado y sin fondo: tiene que ser solido, simetrico y con el centro tranquilo."""
	a = np.asarray(img).astype(np.float32)
	problemas = []
	alpha = a[..., 3]
	if float((alpha > 200).mean()) < 0.82:
		problemas.append("tiene huecos")
	espejo = a[:, ::-1, :3]
	if float(np.abs(a[..., :3] - espejo).mean()) > 38.0:
		problemas.append("no es simetrico")
	h, w = alpha.shape
	centro = a[int(h * 0.35):int(h * 0.65), int(w * 0.3):int(w * 0.7), :3]
	if centro.size == 0 or float(centro.std()) > 70.0:
		problemas.append("el centro esta muy recargado")
	return problemas


def arreglar_centro(img: Image.Image, color: tuple[int, int, int], margen: float, mezcla: float = 0.72) -> Image.Image:
	"""Funde el centro (dentro del marco) con el color de la interfaz, con un borde suave."""
	a = np.asarray(img).astype(np.float32)
	h, w = a.shape[:2]
	my, mx = int(h * margen), int(w * margen if w <= h else h * margen)
	yy, xx = np.mgrid[0:h, 0:w]
	dist = np.minimum.reduce([xx - mx, (w - 1 - mx) - xx, yy - my, (h - 1 - my) - yy]).astype(np.float32)
	peso = np.clip(dist / 10.0, 0.0, 1.0) * mezcla
	objetivo = np.array(color, dtype=np.float32)
	a[..., :3] = a[..., :3] * (1.0 - peso[..., None]) + objetivo * peso[..., None]
	return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def _hex_rgb(h: str) -> tuple[int, int, int]:
	h = h.lstrip("#")
	return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def generar(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, intentos: int = 2) -> tuple[dict, dict]:
	"""Devuelve ({panel, boton, boton_primario: ruta png, margen_panel, margen_boton}, informe)."""
	carpeta.mkdir(parents=True, exist_ok=True)
	ui = interfaz.derivar(biblia)
	col = ui["colores"]
	chroma = _hex_rgb(biblia["estilo"]["fondo_chroma"])
	informe: dict = {"piezas": {}, "fallidas": {}, "generaciones": 0}
	piezas: dict[str, Image.Image] = {}
	for i, (pieza, (w, h)) in enumerate(TAMANOS.items()):
		ultimo: list[str] = []
		for intento in range(intentos):
			if intento and runpod.en_ahorro():
				break  # tope suave de GPU: lo que no salga a la primera se queda sin repetir
			try:
				datos = cliente.generar(flujo, {"PROMPT": prompt(biblia, pieza), "SEED": semilla + 131 * i + 7919 * intento,
					"ANCHO": w, "ALTO": h})[0]
			except Exception as e:  # noqa: BLE001 - sin piel el juego usa la interfaz de siempre
				ultimo = [str(e)[:120]]
				break
			informe["generaciones"] += 1
			img = post.quitar_fondo(Image.open(io.BytesIO(datos)).convert("RGBA"), chroma)
			bb = post.caja(img)
			if bb is None:
				ultimo = ["vacia"]
				continue
			img = img.crop(bb).resize(SALIDA[pieza], Image.LANCZOS)
			ultimo = revisar(img)
			if not ultimo:
				piezas[pieza] = img
				informe["piezas"][pieza] = {"intentos": intento + 1}
				break
		if pieza not in piezas:
			informe["fallidas"][pieza] = ultimo
	if len(piezas) < 2:
		return {}, informe
	salida: dict = {
		"panel": carpeta / "panel.png", "boton": carpeta / "boton.png", "boton_primario": carpeta / "boton_primario.png",
		"margen_panel": int(SALIDA["panel"][0] * MARGEN["panel"]), "margen_boton": int(SALIDA["boton"][1] * MARGEN["boton"]),
	}
	arreglar_centro(piezas["panel"], _hex_rgb(col["panel"]), MARGEN["panel"]).save(salida["panel"])
	arreglar_centro(piezas["boton"], _hex_rgb(col["panel_hi"]), MARGEN["boton"]).save(salida["boton"])
	arreglar_centro(piezas["boton"], _hex_rgb(col["acento"]), MARGEN["boton"], 0.85).save(salida["boton_primario"])
	return salida, informe
