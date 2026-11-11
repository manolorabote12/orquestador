"""Postprocesado que FUERZA la coherencia, haga lo que haga el generador.

1 - Quitar el fondo de color plano (chroma) y su halo.
2 - Recortar y escalar todos los frames de un personaje con la MISMA escala
	(la de su ficha) y apoyados en los pies: nada cambia de tamano entre frames.
3 - Pixel art: reduccion por bloques y transparencia binaria.
4 - Paleta forzada: cada pixel opaco pasa al color de la paleta mas cercano.
5 - Contorno oscuro opcional de 1 px.
"""

import numpy as np
from PIL import Image


def a_rgba(img: Image.Image) -> np.ndarray:
	return np.asarray(img.convert("RGBA")).astype(np.int16)


def quitar_fondo(img: Image.Image, chroma: tuple[int, int, int], tol: float = 90.0) -> Image.Image:
	arr = a_rgba(img)
	rgb = arr[..., :3]
	dist = np.sqrt(((rgb - np.array(chroma)) ** 2).sum(axis=-1))
	alpha = arr[..., 3].copy()
	alpha[dist < tol] = 0
	# Halo: pixeles cercanos al chroma pierden el tinte (despill para magenta o verde).
	cerca = (dist < tol * 2.2) & (alpha > 0)
	r, g, b = rgb[..., 0].copy(), rgb[..., 1].copy(), rgb[..., 2].copy()
	if chroma[1] < 128:
		exceso = np.clip(np.minimum(r, b) - g, 0, None)
		r = np.where(cerca, r - exceso, r)
		b = np.where(cerca, b - exceso, b)
	else:
		exceso = np.clip(g - np.maximum(r, b), 0, None)
		g = np.where(cerca, g - exceso, g)
	out = np.stack([r, g, b, alpha], axis=-1).clip(0, 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def quitar_fondo_borde(img: Image.Image, tol: float = 46.0) -> Image.Image:
	"""Quita el fondo liso aunque NO sea del color pedido: toma el color del borde de la imagen y borra lo
	que se le parece y toca el borde (relleno desde las esquinas). Para piezas de interfaz: la IA a veces
	pinta el fondo granate o rosa palido en vez de magenta puro y el recorte por color no quitaba nada
	(11 nov: botones y paneles con un rectangulo granate alrededor)."""
	from PIL import ImageDraw
	arr = a_rgba(img)
	h, w = arr.shape[:2]
	g = max(2, min(h, w) // 40)
	borde = np.concatenate([arr[:g].reshape(-1, 4), arr[-g:].reshape(-1, 4), arr[:, :g].reshape(-1, 4), arr[:, -g:].reshape(-1, 4)])
	opacos = borde[borde[:, 3] > 200][:, :3]
	if len(opacos) < 0.5 * len(borde):
		return img  # el borde ya es transparente: no hay fondo que quitar
	color = np.median(opacos, axis=0)
	if float(np.sqrt(((opacos - color) ** 2).sum(-1)).mean()) > 30.0:
		return img  # el borde no es liso: no es un fondo, es dibujo
	cerca = (np.sqrt(((arr[..., :3] - color) ** 2).sum(-1)) < tol) & (arr[..., 3] > 0)
	mascara = Image.fromarray(np.where(cerca, 255, 0).astype(np.uint8), "L").copy()  # copia: fromarray puede ser de solo lectura
	paso = max(1, min(h, w) // 24)
	semillas = [(x, y) for x in range(0, w, paso) for y in (0, h - 1)] + [(x, y) for y in range(0, h, paso) for x in (0, w - 1)]
	for sx, sy in semillas:
		if mascara.getpixel((sx, sy)) == 255:
			ImageDraw.floodfill(mascara, (sx, sy), 128)
	fuera = np.asarray(mascara) == 128
	out = arr.copy()
	out[..., 3] = np.where(fuera, 0, out[..., 3])
	return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def caja(img: Image.Image) -> tuple[int, int, int, int] | None:
	a = np.asarray(img)[..., 3]
	ys, xs = np.nonzero(a > 16)
	if len(xs) == 0:
		return None
	return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def escala_de_referencia(ref: Image.Image, celda: tuple[int, int], margen: float = 0.9) -> float:
	b = caja(ref)
	if b is None:
		return 1.0
	w, h = b[2] - b[0], b[3] - b[1]
	return min(celda[0] * margen / w, celda[1] * margen / h)


def encajar(img: Image.Image, celda: tuple[int, int], escala: float, pixel_art: bool) -> Image.Image:
	"""Escala con la escala comun y apoya la figura abajo y centrada en la celda."""
	b = caja(img)
	lienzo = Image.new("RGBA", celda, (0, 0, 0, 0))
	if b is None:
		return lienzo
	recorte = img.crop(b)
	w = max(1, round(recorte.width * escala))
	h = max(1, round(recorte.height * escala))
	if w > celda[0] or h > celda[1]:
		k = min(celda[0] / w, celda[1] / h)
		w, h = max(1, int(w * k)), max(1, int(h * k))
	if pixel_art:
		pequeno = recorte.resize((w, h), Image.Resampling.BOX)
		arr = np.asarray(pequeno).copy()
		arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
		pequeno = Image.fromarray(arr, "RGBA")
	else:
		pequeno = recorte.resize((w, h), Image.Resampling.LANCZOS)
	x = (celda[0] - w) // 2
	y = celda[1] - h
	lienzo.alpha_composite(pequeno, (x, y))
	return lienzo


def forzar_paleta(img: Image.Image, paleta: list[tuple[int, int, int]]) -> tuple[Image.Image, float]:
	"""Devuelve la imagen con paleta forzada y la desviacion media antes de forzar (deriva de estilo)."""
	arr = np.asarray(img.convert("RGBA")).astype(np.float32)
	opaco = arr[..., 3] > 0
	if not opaco.any():
		return img, 0.0
	pal = np.array(paleta, dtype=np.float32)
	px = arr[opaco][:, :3]
	# Distancia "redmean": barata y mas cercana a la percepcion que el RGB plano.
	rm = (px[:, None, 0] + pal[None, :, 0]) / 2.0
	d = np.sqrt((2 + rm / 256) * (px[:, None, 0] - pal[None, :, 0]) ** 2
				+ 4 * (px[:, None, 1] - pal[None, :, 1]) ** 2
				+ (2 + (255 - rm) / 256) * (px[:, None, 2] - pal[None, :, 2]) ** 2)
	idx = d.argmin(axis=1)
	deriva = float(d.min(axis=1).mean() / 3.0)
	out = arr.copy()
	out[opaco, :3] = pal[idx]
	return Image.fromarray(out.astype(np.uint8), "RGBA"), deriva


def contorno(img: Image.Image, color: tuple[int, int, int]) -> Image.Image:
	arr = np.asarray(img).copy()
	a = arr[..., 3] > 0
	vecino = np.zeros_like(a)
	vecino[1:, :] |= a[:-1, :]
	vecino[:-1, :] |= a[1:, :]
	vecino[:, 1:] |= a[:, :-1]
	vecino[:, :-1] |= a[:, 1:]
	borde = vecino & ~a
	arr[borde] = [color[0], color[1], color[2], 255]
	return Image.fromarray(arr, "RGBA")


def color_mas_oscuro(paleta: list[tuple[int, int, int]]) -> tuple[int, int, int]:
	return min(paleta, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])


def procesar_animacion(frames: list[Image.Image], ficha: Image.Image, celda: tuple[int, int],
						biblia_estilo: dict, paleta: list[tuple[int, int, int]], chroma: tuple[int, int, int]) -> tuple[list[Image.Image], list[float]]:
	pixel_art = biblia_estilo["familia"] == "pixel_art"
	margen = 0.86 if biblia_estilo.get("contorno") == "oscuro_1px" else 0.92
	ficha_limpia = quitar_fondo(ficha, chroma)
	escala = escala_de_referencia(ficha_limpia, celda, margen)
	salida: list[Image.Image] = []
	derivas: list[float] = []
	for f in frames:
		limpio = quitar_fondo(f, chroma)
		enc = encajar(limpio, celda, escala, pixel_art)
		deriva = 0.0
		if biblia_estilo.get("forzar_paleta", True):
			enc, deriva = forzar_paleta(enc, paleta)
		if biblia_estilo.get("contorno") == "oscuro_1px":
			enc = contorno(enc, color_mas_oscuro(paleta))
		salida.append(enc)
		derivas.append(deriva)
	return salida, derivas


def costura(img: Image.Image) -> float:
	"""Cuanto se nota la union al repetir el tile (0 = perfecto)."""
	a = np.asarray(img.convert("RGB")).astype(np.float32)
	return float((np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0, :] - a[-1, :]).mean()) / 2.0)


def procesar_tile(img: Image.Image, lado: int, biblia_estilo: dict, paleta: list[tuple[int, int, int]]) -> tuple[Image.Image, float, float]:
	"""Tile repetible: reduce, suaviza la costura cruzando bordes y fuerza la paleta."""
	base = img.convert("RGB").resize((lado * 4, lado * 4), Image.Resampling.LANCZOS)
	arr = np.asarray(base).astype(np.float32)
	n = arr.shape[0]
	banda = max(2, n // 8)
	# Mezcla cada borde con el opuesto para que encajen al repetir.
	izq, der = arr[:, :banda].copy(), arr[:, -banda:].copy()
	mezcla = (izq + der[:, ::-1]) / 2.0
	arr[:, :banda] = mezcla
	arr[:, -banda:] = mezcla[:, ::-1]
	arriba, abajo = arr[:banda, :].copy(), arr[-banda:, :].copy()
	mezcla_v = (arriba + abajo[::-1, :]) / 2.0
	arr[:banda, :] = mezcla_v
	arr[-banda:, :] = mezcla_v[::-1, :]
	img2 = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")
	metodo = Image.Resampling.BOX if biblia_estilo["familia"] == "pixel_art" else Image.Resampling.LANCZOS
	tile = img2.resize((lado, lado), metodo).convert("RGBA")
	deriva = 0.0
	if biblia_estilo.get("forzar_paleta", True):
		tile, deriva = forzar_paleta(tile, paleta)
	return tile, costura(tile), deriva


def hoja(frames: list[Image.Image]) -> Image.Image:
	w, h = frames[0].size
	out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
	for i, f in enumerate(frames):
		out.alpha_composite(f, (i * w, 0))
	return out
