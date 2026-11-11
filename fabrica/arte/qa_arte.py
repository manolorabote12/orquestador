"""QA automatico del arte: decide que frames se aceptan y cuales se regeneran.

Comprueba en cada animacion:
1 - Tamano exacto de celda y figura no vacia.
2 - Sin restos del color de fondo ni semitransparencias (pixel art).
3 - Deriva de estilo: cuanto se alejaba del estilo antes de forzar la paleta.
4 - Altura estable entre frames (el personaje no crece ni encoge).
5 - Silueta y colores parecidos a la ficha (es el mismo personaje).
"""

import numpy as np
from PIL import Image

UMBRAL_DERIVA = 38.0
UMBRAL_ALTURA = 0.22
UMBRAL_SILUETA = 0.30
UMBRAL_COLOR = 0.75


def _mascara(img: Image.Image) -> np.ndarray:
	return np.asarray(img)[..., 3] > 0


def _altura(m: np.ndarray) -> int:
	ys = np.nonzero(m.any(axis=1))[0]
	return int(ys.max() - ys.min() + 1) if len(ys) else 0


def _iou(a: np.ndarray, b: np.ndarray) -> float:
	u = np.logical_or(a, b).sum()
	return float(np.logical_and(a, b).sum() / u) if u else 0.0


def _histograma(img: Image.Image, paleta: list[tuple[int, int, int]]) -> np.ndarray:
	arr = np.asarray(img)
	opaco = arr[..., 3] > 0
	px = arr[opaco][:, :3].astype(np.int32)
	h = np.zeros(len(paleta), dtype=np.float64)
	if len(px) == 0:
		return h
	pal = np.array(paleta, dtype=np.int32)
	idx = ((px[:, None, :] - pal[None, :, :]) ** 2).sum(-1).argmin(1)
	np.add.at(h, idx, 1)
	return h / h.sum()


def revisar_animacion(frames: list[Image.Image], ficha_procesada: Image.Image, celda: tuple[int, int],
						derivas: list[float], paleta: list[tuple[int, int, int]], chroma: tuple[int, int, int],
						pixel_art: bool, es_objeto_giratorio: bool = False) -> dict:
	malos: dict[int, list[str]] = {}

	def anotar(i: int, motivo: str) -> None:
		malos.setdefault(i, []).append(motivo)

	ref_m = _mascara(ficha_procesada)
	ref_h = _altura(ref_m)
	ref_hist = _histograma(ficha_procesada, paleta)
	alturas = []
	for i, f in enumerate(frames):
		if f.size != tuple(celda):
			anotar(i, f"tamano {f.size} distinto de {tuple(celda)}")
			continue
		arr = np.asarray(f)
		m = arr[..., 3] > 0
		if m.sum() < 0.04 * celda[0] * celda[1]:
			anotar(i, "figura vacia o casi vacia")
			continue
		rgb = arr[..., :3].astype(np.int32)
		restos = (np.sqrt(((rgb - np.array(chroma)) ** 2).sum(-1)) < 60) & m
		if restos.sum() > 0:
			anotar(i, f"{int(restos.sum())} pixeles con color de fondo")
		if pixel_art and np.any((arr[..., 3] > 0) & (arr[..., 3] < 255)):
			anotar(i, "semitransparencias en pixel art")
		if i < len(derivas) and derivas[i] > UMBRAL_DERIVA:
			anotar(i, f"deriva de estilo {derivas[i]:.1f} > {UMBRAL_DERIVA}")
		alturas.append((i, _altura(m)))
		if not es_objeto_giratorio:
			iou = _iou(m, ref_m)
			if iou < UMBRAL_SILUETA:
				anotar(i, f"silueta distinta a la ficha (IoU {iou:.2f})")
		dist = float(np.abs(_histograma(f, paleta) - ref_hist).sum())
		if dist > UMBRAL_COLOR:
			anotar(i, f"colores distintos a la ficha ({dist:.2f})")

	if ref_h and not es_objeto_giratorio:
		for i, h in alturas:
			if abs(h - ref_h) / ref_h > UMBRAL_ALTURA:
				anotar(i, f"altura {h}px frente a {ref_h}px de la ficha")

	return {"ok": not malos, "malos": malos, "frames": len(frames)}


def fondo_libre(img: Image.Image, chroma: tuple[int, int, int]) -> float:
	"""Parte de la imagen en bruto que es fondo liso (color chroma). Un personaje bien pedido deja
	mucho fondo; si casi no hay, la IA ha dibujado un escenario dentro del sprite."""
	rgb = np.asarray(img.convert("RGB")).astype(np.int32)
	cerca = np.sqrt(((rgb - np.array(chroma)) ** 2).sum(-1)) < 90
	return float(cerca.mean())


UMBRAL_FONDO_LIBRE = 0.30


def revisar_tile(costura: float, deriva: float) -> dict:
	problemas = []
	if costura > 18.0:
		problemas.append(f"costura visible ({costura:.1f})")
	if deriva > UMBRAL_DERIVA:
		problemas.append(f"deriva de estilo {deriva:.1f}")
	return {"ok": not problemas, "problemas": problemas}
