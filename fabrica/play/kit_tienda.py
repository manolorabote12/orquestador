"""Kit de tienda automatico (23 nov 2026, recetas de los 4 juegos del estudio): de las fotos que saca la prueba
«recorrer» salen las capturas de Google Play con titular, y de la portada (o la primera foto) el grafico
destacado 1024x500. Lo usa el trabajador al acabar un juego a medida; el creador lo baja desde la app.

	generar(proyecto, titulo, tienda, salida) -> {"capturas": [Path...], "destacada": Path | None}
	tienda = {"lema": "...", "titulares": ["...", ...]}  (lo rellena el Agente Estudio al terminar)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FUENTES = Path(__file__).resolve().parent / "fuentes"
COLOR = (255, 232, 190)


def _fuente(nombre: str, tam: int) -> ImageFont.FreeTypeFont:
	try:
		return ImageFont.truetype(str(FUENTES / nombre), tam)
	except OSError:
		return ImageFont.load_default()


def _envolver(d: ImageDraw.ImageDraw, txt: str, f, ancho: float) -> list[str]:
	lineas, cur = [], ""
	for p in txt.split():
		t = (cur + " " + p).strip()
		if d.textlength(t, font=f) <= ancho or not cur:
			cur = t
		else:
			lineas.append(cur)
			cur = p
	return lineas + [cur]


def captura(src: Path, titular: str, dst: Path) -> Path:
	"""Fondo desenfocado de la propia captura, titular arriba y la captura enmarcada con sombra."""
	shot = Image.open(src).convert("RGB")
	apaisada = shot.width > shot.height
	W, H = (1920, 1080) if apaisada else (1080, 1920)
	fondo = Image.blend(shot.resize((W, H)).filter(ImageFilter.GaussianBlur(28)), Image.new("RGB", (W, H), (8, 6, 12)), 0.55)
	cab = 200 if apaisada else 330
	esc = min((W * 0.86) / shot.width, (H - cab - (40 if apaisada else 70)) / shot.height)
	sw, sh = int(shot.width * esc), int(shot.height * esc)
	x, y = (W - sw) // 2, cab
	lienzo = fondo.convert("RGBA")
	sombra = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(sombra).rounded_rectangle((x + 6, y + 14, x + sw + 6, y + sh + 14), 34, fill=(0, 0, 0, 170))
	lienzo.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(18)))
	marco = Image.new("RGBA", (sw + 12, sh + 12), (0, 0, 0, 0))
	ImageDraw.Draw(marco).rounded_rectangle((0, 0, sw + 11, sh + 11), 38, fill=(200, 160, 90, 255))
	lienzo.alpha_composite(marco, (x - 6, y - 6))
	mascara = Image.new("L", (sw, sh), 0)
	ImageDraw.Draw(mascara).rounded_rectangle((0, 0, sw - 1, sh - 1), 32, fill=255)
	lienzo.paste(shot.resize((sw, sh), Image.LANCZOS), (x, y), mascara)
	d = ImageDraw.Draw(lienzo)
	tam = 78 if apaisada else 84
	f = _fuente("cinzel700.ttf", tam)
	lineas = _envolver(d, titular, f, W * 0.9)
	while len(lineas) > 2 and tam > 50:
		tam -= 6
		f = _fuente("cinzel700.ttf", tam)
		lineas = _envolver(d, titular, f, W * 0.9)
	alto = tam * 1.15
	y0 = (cab - alto * len(lineas)) / 2 - 6
	for i, l in enumerate(lineas):
		d.text(((W - d.textlength(l, font=f)) / 2, y0 + i * alto), l, font=f, fill=COLOR, stroke_width=4, stroke_fill=(10, 6, 4))
	dst.parent.mkdir(parents=True, exist_ok=True)
	lienzo.convert("RGB").save(dst, quality=92)
	return dst


def destacada(portada: Path, titulo: str, lema: str, dst: Path) -> Path:
	"""1024x500: la ilustracion recortada, degradado oscuro a la izquierda, titulo y lema."""
	im = Image.open(portada).convert("RGB")
	esc = max(1024 / im.width, 500 / im.height)
	im = im.resize((int(im.width * esc) + 1, int(im.height * esc) + 1), Image.LANCZOS)
	x, y = (im.width - 1024) // 2, max(0, int(im.height * 0.45 - 250))
	base = im.crop((x, min(y, im.height - 500), x + 1024, min(y, im.height - 500) + 500)).convert("RGBA")
	capa = Image.new("RGBA", (1024, 500), (0, 0, 0, 0))
	dc = ImageDraw.Draw(capa)
	for i in range(560):
		dc.line([(i, 0), (i, 500)], fill=(5, 3, 8, int(175 * max(0.0, 1 - i / 560))))
	base.alpha_composite(capa)
	d = ImageDraw.Draw(base)
	f1 = _fuente("cinzel700.ttf", 70 if len(titulo) < 16 else 54)
	while d.textlength(titulo, font=f1) > 900 and f1.size > 34:
		f1 = _fuente("cinzel700.ttf", f1.size - 4)
	f2 = _fuente("nunito600.ttf", 30)
	d.text((48, 170), titulo, font=f1, fill=COLOR, stroke_width=4, stroke_fill=(10, 6, 4))
	if lema:
		d.text((52, 180 + f1.size * 1.3), lema[:60], font=f2, fill=(240, 235, 225), stroke_width=3, stroke_fill=(10, 6, 4))
	dst.parent.mkdir(parents=True, exist_ok=True)
	base.convert("RGB").save(dst)
	return dst


def _portada(proyecto: Path, fotos: list[Path]) -> Path | None:
	"""La ilustracion apaisada mas grande del juego (portada, escenas) o, si no hay, la primera foto."""
	mejores = []
	for f in (proyecto / "assets" / "libre").glob("*.png"):
		try:
			with Image.open(f) as im:
				if im.width >= 900 and im.width >= im.height * 1.3 and im.mode in ("RGB", "P", "RGBA"):
					mejores.append((im.width * im.height, f))
		except OSError:
			continue
	if mejores:
		return max(mejores)[1]
	return fotos[0] if fotos else None


def _vale(f: Path) -> bool:
	"""Fuera las fotos vacias (un fotograma de carga gris o negro)."""
	from PIL import ImageStat
	try:
		with Image.open(f) as im:
			return max(ImageStat.Stat(im.convert("L").resize((90, 160))).stddev) > 14
	except OSError:
		return False


def generar(proyecto: Path, titulo: str, tienda: dict | None, salida: Path) -> dict:
	tienda = tienda or {}
	## Los titulares van en el orden de las fotos de recorrer (las que vio el agente); las vacias se saltan.
	todas = sorted((proyecto / "build" / "libre_fotos").glob("*.png"))[:12]
	titulares = [str(t)[:60] for t in (tienda.get("titulares") or [])]
	fotos = [f for f in todas if _vale(f)]
	hechas: list[Path] = []
	for i, f in enumerate(todas):
		texto = (titulares[i].strip() if i < len(titulares) else "") or (titulo if not hechas else "")
		if not texto or f not in fotos or len(hechas) >= 6:
			continue
		try:
			hechas.append(captura(f, texto, salida / f"captura_{len(hechas) + 1:02d}.jpg"))
		except OSError:
			continue
	des = None
	portada = _portada(proyecto, fotos)
	if portada is not None:
		try:
			des = destacada(portada, titulo, str(tienda.get("lema") or ""), salida / "destacada_1024x500.png")
		except OSError:
			des = None
	return {"capturas": hechas, "destacada": des}
