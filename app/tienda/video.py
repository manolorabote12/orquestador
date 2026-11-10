"""Video promocional de Orquestador (vertical 1080x1920, ~25 s), grabado de la demo de verdad.

	npm run build:demo && python3 tienda/video.py          -> tienda/video/promo_es.mp4 y promo_en.mp4

Sirve para el video de la ficha de Google Play (subido a YouTube), TikTok, Shorts y Reels.
1 - Playwright recorre la demo: escribe una idea, pide el diseno gratis, lo fabrica y lo termina.
2 - ffmpeg monta el telefono en el centro con un titular por tramo (la fabricacion va a x2,5) y un
    cierre con la marca. Musica de fondo procedural de la fabrica (sin derechos de nadie).
Necesita: playwright (Python), ffmpeg, Pillow y fontTools+brotli (para la letra de la marca).
"""
import asyncio
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from playwright.async_api import async_playwright

APP = Path(__file__).resolve().parents[1]
SALIDA = APP / "tienda" / "video"
FABRICA = APP.parent / "fabrica"
W, H = 1080, 1920
TEL_W, TEL_H = 640, 1385
TEL_X, TEL_Y = (W - TEL_W) // 2, 470
FONDO = (15, 42, 74)
LATON = (246, 207, 122)
CLARO = (232, 240, 250)

TEXTOS = {
	"es": {
		"idea": "una gata ninja muy rápida que salta por los tejados de noche y esquiva ratas robot",
		"tramos": [("Escribe tu idea", "Con tus palabras, sin programar"),
			("Mira el diseño gratis", "Antes de gastar nada"),
			("La IA lo fabrica", "Niveles, arte, música y bots que lo prueban"),
			("Tu juego, listo", "Juégalo y publícalo en Google Play")],
		"cierre": ("Orquestador", "Creador de juegos con IA"),
		"locale": "es-ES",
	},
	"en": {
		"idea": "a super fast ninja cat jumping across rooftops at night, dodging robot rats",
		"tramos": [("Write your idea", "In your own words, no coding"),
			("See the design for free", "Before you spend anything"),
			("AI makes the game", "Levels, art, music and bots that test it"),
			("Your game is ready", "Play it and publish it on Google Play")],
		"cierre": ("Orquestador", "AI game maker"),
		"locale": "en-US",
	},
}


def fuente(px: int) -> ImageFont.FreeTypeFont:
	ttf = Path(tempfile.gettempdir()) / "orq_marca.ttf"
	if not ttf.exists():
		try:
			from fontTools.ttLib import TTFont
			f = TTFont(APP / "marca" / "big-shoulders-800.woff2")
			f.flavor = None
			f.save(ttf)
		except Exception:  # noqa: BLE001 - sin fontTools, la letra redonda del kit
			return ImageFont.truetype(str(APP.parent / "orqkit" / "kit" / "ui" / "fonts" / "Fredoka.ttf"), px)
	return ImageFont.truetype(str(ttf), px)


def fuente_sub(px: int) -> ImageFont.FreeTypeFont:
	return ImageFont.truetype(str(APP.parent / "orqkit" / "kit" / "ui" / "fonts" / "Fredoka.ttf"), px)


def fondo(destino: Path) -> Path:
	"""Fondo azul con la cuadricula de la marca y el marco del telefono."""
	img = Image.new("RGB", (W, H), FONDO)
	d = ImageDraw.Draw(img)
	for x in range(0, W, 54):
		d.line([(x, 0), (x, H)], fill=(30, 56, 88), width=2)
	for y in range(0, H, 54):
		d.line([(0, y), (W, y)], fill=(30, 56, 88), width=2)
	d.rounded_rectangle([TEL_X - 16, TEL_Y - 16, TEL_X + TEL_W + 16, TEL_Y + TEL_H + 16], 56, fill=(6, 20, 39))
	img.save(destino)
	return destino


def rotulo(titulo: str, sub: str, destino: Path) -> Path:
	img = Image.new("RGBA", (W, 460), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	f, fs = fuente(112), fuente_sub(46)
	for px in (112, 100, 88, 76):
		f = fuente(px)
		if d.textlength(titulo.upper(), font=f) <= W - 80:
			break
	tw = d.textlength(titulo.upper(), font=f)
	d.text(((W - tw) / 2, 120), titulo.upper(), font=f, fill=CLARO)
	sw = d.textlength(sub, font=fs)
	d.text(((W - sw) / 2, 120 + f.size + 26), sub, font=fs, fill=LATON)
	img.save(destino)
	return destino


def cierre(titulo: str, sub: str, destino: Path) -> Path:
	img = Image.new("RGB", (W, H), FONDO)
	d = ImageDraw.Draw(img)
	logo = APP / "assets" / "play" / "icono-512.png"
	if logo.exists():
		ico = Image.open(logo).convert("RGBA").resize((360, 360))
		img.paste(ico, ((W - 360) // 2, 560), ico)
	f, fs = fuente(150), fuente_sub(54)
	tw = d.textlength(titulo.upper(), font=f)
	d.text(((W - tw) / 2, 980), titulo.upper(), font=f, fill=CLARO)
	sw = d.textlength(sub, font=fs)
	d.text(((W - sw) / 2, 1160), sub, font=fs, fill=LATON)
	gp = "Google Play"
	gw = d.textlength(gp, font=fs)
	d.rounded_rectangle([(W - gw) / 2 - 40, 1290, (W + gw) / 2 + 40, 1390], 30, outline=LATON, width=4)
	d.text(((W - gw) / 2, 1310), gp, font=fs, fill=LATON)
	img.save(destino)
	return destino


async def grabar(idioma: str, carpeta: Path) -> tuple[Path, dict]:
	t = TEXTOS[idioma]
	marcas: dict[str, float] = {}
	async with async_playwright() as p:
		b = await p.chromium.launch()
		## El video de Playwright graba en pixeles CSS: pantalla de 780 con zoom x2 = movil de 390 nitido.
		ctx = await b.new_context(viewport={"width": 780, "height": 1688}, device_scale_factor=1, locale=t["locale"],
			record_video_dir=str(carpeta), record_video_size={"width": 780, "height": 1688})
		await ctx.add_init_script("document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.zoom = '2'; });")
		pg = await ctx.new_page()
		t0 = time.monotonic()
		marca = lambda k: marcas.__setitem__(k, time.monotonic() - t0)  # noqa: E731
		await pg.goto((APP / "dist-demo" / "index.html").as_uri())
		await pg.add_style_tag(content=".demo-band,.toast{display:none!important}")
		await pg.wait_for_timeout(800)
		await pg.fill("input[type=email]", "demo@demo.com")
		await pg.locator("button.btn-brass").first.click()
		await pg.wait_for_timeout(700)
		await pg.fill("input.code-input", "123456")
		await pg.keyboard.press("Enter")
		await pg.wait_for_timeout(1500)
		otro = pg.locator("button.btn-brass")
		if await pg.locator("textarea").count() == 0 and await otro.count():
			await otro.first.click()
			await pg.wait_for_timeout(800)
		await pg.add_style_tag(content=".demo-band,.toast{display:none!important}")
		caja = pg.locator("textarea").first
		await caja.scroll_into_view_if_needed()
		await pg.evaluate("window.scrollBy(0, -120)")
		await pg.wait_for_timeout(400)
		marca("idea")
		await caja.click()
		await caja.type(t["idea"], delay=38)
		await pg.wait_for_timeout(600)
		marca("previa")
		await pg.locator(".btn-row button.btn-line").first.click()
		await pg.wait_for_timeout(2600)
		marca("fabricar")
		await pg.locator(".previa button.btn-brass").first.click()
		await pg.locator("button:visible", has_text="APK").first.wait_for(state="visible", timeout=90000)
		marca("listo")
		await pg.wait_for_timeout(3200)
		marca("fin")
		video = await pg.video.path()
		await ctx.close()
		await b.close()
	return Path(video), marcas


def musica(carpeta: Path) -> Path | None:
	try:
		sys.path.insert(0, str(FABRICA))
		from arte import musica as mus
		biblia = json.loads((FABRICA / "ejemplos" / "biblia_salto.json").read_text(encoding="utf-8"))
		pistas = mus.generar(biblia, carpeta / "musica", 7)
		return Path(pistas.get("nivel") or next(iter(pistas.values())))
	except Exception as e:  # noqa: BLE001 - sin musica tambien vale
		print("sin musica:", e)
		return None


def montar(idioma: str, video: Path, m: dict, carpeta: Path, destino: Path) -> Path:
	t = TEXTOS[idioma]
	fnd = fondo(carpeta / "fondo.png")
	rot = [rotulo(a, b, carpeta / f"rotulo_{i}.png") for i, (a, b) in enumerate(t["tramos"])]
	fin = cierre(*t["cierre"], carpeta / "cierre.png")
	## Tramos del video original: (inicio, fin, velocidad)
	tramos = [(m["idea"], m["previa"], 1.0), (m["previa"], m["fabricar"], 1.0), (m["fabricar"], m["listo"], 2.5), (m["listo"], m["fin"], 1.0)]
	partes, filtros, t_sal = [], [], 0.0
	for i, (a, b, v) in enumerate(tramos):
		dur = (b - a) / v
		filtros.append(f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)/{v},scale={TEL_W}:{TEL_H},fps=30[s{i}]")
		partes.append((t_sal, t_sal + dur))
		t_sal += dur
	cad = "".join(f"[s{i}]" for i in range(len(tramos)))
	filtros.append(f"{cad}concat=n={len(tramos)}:v=1:a=0[tel]")
	filtros.append(f"[1:v][tel]overlay={TEL_X}:{TEL_Y}[b0]")
	ult = "b0"
	for i, (a, b) in enumerate(partes):
		filtros.append(f"[{ult}][{2 + i}:v]overlay=0:0:enable='between(t,{a:.3f},{b:.3f})'[b{i + 1}]")
		ult = f"b{i + 1}"
	filtros.append(f"[{ult}]trim=duration={t_sal:.3f},setpts=PTS-STARTPTS[cuerpo]")
	filtros.append(f"[{2 + len(rot)}:v]trim=duration=2.6,setpts=PTS-STARTPTS,fps=30[fin]")
	filtros.append("[cuerpo][fin]concat=n=2:v=1:a=0,format=yuv420p[v]")
	total = t_sal + 2.6
	cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(video), "-loop", "1", "-i", str(fnd)]
	for r in rot:
		cmd += ["-loop", "1", "-i", str(r)]
	cmd += ["-loop", "1", "-i", str(fin)]
	pista = musica(carpeta)
	if pista:
		cmd += ["-stream_loop", "-1", "-i", str(pista)]
		filtros.append(f"[{3 + len(rot)}:a]atrim=duration={total:.3f},afade=t=out:st={total - 1.5:.3f}:d=1.5,volume=0.6[a]")
	cmd += ["-filter_complex", ";".join(filtros), "-map", "[v]"]
	if pista:
		cmd += ["-map", "[a]", "-c:a", "aac", "-b:a", "128k"]
	cmd += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-r", "30", "-t", f"{total:.3f}", "-movflags", "+faststart", str(destino)]
	subprocess.run(cmd, check=True)
	return destino


def main() -> int:
	if not (APP / "dist-demo" / "index.html").exists():
		print("Primero: npm run build:demo")
		return 1
	SALIDA.mkdir(parents=True, exist_ok=True)
	for idioma in ("es", "en"):
		tmp = Path(tempfile.mkdtemp(prefix="orq_video_"))
		video, m = asyncio.run(grabar(idioma, tmp))
		destino = montar(idioma, video, m, tmp, SALIDA / f"promo_{idioma}.mp4")
		print(destino, {k: round(v, 1) for k, v in m.items()})
		shutil.rmtree(tmp, ignore_errors=True)
	return 0


if __name__ == "__main__":
	sys.exit(main())
