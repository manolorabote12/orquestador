"""Montaje de los clips para redes con ffmpeg.

1 - grabar(): el bot juega ~30 s sin carteles (qa/clip.tscn --raw) y apunta los momentos.
2 - mejor_ventana(): elige los 12.5 s con mas accion (jefe, victorias, pisotones, monedas...).
3 - montar(): partida + gancho arriba + subtitulos grandes + voz en off con la musica del juego
    que baja cuando habla (ducking) + cartel final de 2.5 s -> MP4 1080x1920 H.264/AAC 30 fps.
Los textos se dibujan con Pillow (la fuente del juego, en negrita y con borde) y ffmpeg los
superpone: asi no depende de las fuentes instaladas en el sistema.
"""

import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import cadena
import generos

W, H = 1080, 1920
JUEGO = 12.5
CARTEL = 2.5
TOTAL = JUEGO + CARTEL
FUENTE_KIT = Path(__file__).resolve().parents[2] / "orqkit" / "kit" / "ui" / "fonts" / "Fredoka.ttf"

## Cuanto vale cada momento para elegir la ventana, y como se cuenta a la guionista.
PESOS = {
	"boss_defeated": 9.0, "boss_hit": 5.0, "level_complete": 6.0, "wave_clear": 4.0, "stomp": 3.0, "power": 3.0,
	"nitro": 3.0, "upgrade": 3.0, "defeat": 1.5, "crash": 2.0, "hit": 1.5, "hurt": 2.0, "death": 2.0, "coin": 1.0,
	"tower_build": 2.0, "checkpoint": 1.0, "boss_spawn": 4.0,
}
FRASES = {
	"boss_defeated": "derrota al jefe {jefe}", "boss_hit": "golpea al jefe {jefe}", "boss_spawn": "aparece el jefe {jefe}",
	"level_complete": "supera el nivel", "wave_clear": "supera una oleada", "stomp": "pisa a un enemigo",
	"power": "coge un poder", "nitro": "usa el turbo", "upgrade": "elige una mejora", "defeat": "acaba con enemigos",
	"crash": "choca con el trafico", "hit": "recibe un golpe", "hurt": "recibe un golpe", "death": "pierde una vida",
	"coin": "recoge {col}", "tower_build": "construye una torre", "checkpoint": "pasa un punto de control",
}


class ErrorMontaje(Exception):
	pass


def _ff(args: list[str]) -> None:
	r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, capture_output=True, text=True)
	if r.returncode != 0:
		raise ErrorMontaje("ffmpeg fallo: " + r.stderr[-900:])


## ------------------------------------------------------------------ 1 - grabar

def grabar(proyecto: Path, carpeta: Path, segundos: float = 30.0) -> tuple[Path, dict]:
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	saltar = float(generos.de(diseno).get("clip_saltar", 0.5))
	largo = saltar + segundos
	avi = carpeta / "partida.avi"
	ev = carpeta / "momentos.json"
	for f in (avi, ev):
		if f.exists():
			f.unlink()
	r = cadena.godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--write-movie", str(avi),
		"--fixed-fps", "30", "--quit-after", str(int((largo + 8.0) * 30)), "res://qa/clip.tscn", "--", "--raw", "--skip=0",
		f"--seconds={largo}", f"--events={ev}", timeout=400, display=True)
	if not avi.exists() or avi.stat().st_size < 10000 or "SCRIPT ERROR" in r.stdout + r.stderr:
		raise ErrorMontaje("Godot no grabo la partida: " + (r.stdout + r.stderr)[-800:])
	datos = json.loads(ev.read_text(encoding="utf-8")) if ev.exists() else {"seconds": largo, "moments": []}
	datos["saltar"] = saltar
	return avi, datos


## ------------------------------------------------------------------ 2 - mejor ventana

def mejor_ventana(datos: dict) -> float:
	"""Segundo de inicio de los 12.5 s con mas accion (lo importante, mejor hacia el final)."""
	saltar = float(datos.get("saltar", 0.5))
	total = float(datos.get("seconds", saltar + JUEGO + CARTEL))
	ultimo = max(saltar, total - TOTAL - 0.2)
	mejor, inicio = -1.0, saltar
	s = saltar
	while s <= ultimo + 1e-6:
		puntos = 0.0
		for m in datos.get("moments", []):
			dt = float(m["t"]) - s
			if 0.8 <= dt <= JUEGO:
				## Lo que pasa en la segunda mitad cuenta un poco mas: el clip va a mas.
				puntos += PESOS.get(m["event"], 0.0) * (1.0 + 0.3 * dt / JUEGO)
			if m["event"] == "level_start" and 1.5 <= dt <= JUEGO - 1.0:
				puntos -= 2.0
		if puntos > mejor + 1e-6:
			mejor, inicio = puntos, s
		s += 0.5
	return round(inicio, 2)


def momentos_texto(datos: dict, inicio: float, diseno: dict) -> list[str]:
	jefe = (diseno.get("jefe") or {}).get("nombre", "")
	col = diseno["coleccionable"]["nombre_plural"].lower()
	out: list[str] = []
	for m in datos.get("moments", []):
		dt = float(m["t"]) - inicio
		if 0.0 <= dt <= JUEGO and m["event"] in FRASES:
			frase = f"seg. {dt:.0f}: " + FRASES[m["event"]].format(jefe=jefe, col=col).replace("  ", " ").strip()
			if not out or out[-1].split(": ", 1)[1] != frase.split(": ", 1)[1]:
				out.append(frase)
	return out[:12] or ["el heroe avanza por el nivel"]


## ------------------------------------------------------------------ 3 - textos como imagenes

def _fuente(proyecto: Path, px: int, peso: int = 650) -> ImageFont.FreeTypeFont:
	for ruta in (proyecto / "kit" / "ui" / "fonts" / "Fredoka.ttf", FUENTE_KIT):
		if ruta.exists():
			f = ImageFont.truetype(str(ruta), px)
			try:
				f.set_variation_by_axes([peso])
			except (OSError, ValueError, AttributeError):
				pass
			return f
	return ImageFont.load_default(px)


def _lineas(d: ImageDraw.ImageDraw, t: str, f: ImageFont.FreeTypeFont, ancho: int) -> list[str]:
	out, cur = [], ""
	for p in t.split():
		prueba = (cur + " " + p).strip()
		if d.textlength(prueba, font=f) <= ancho or not cur:
			cur = prueba
		else:
			out.append(cur)
			cur = p
	if cur:
		out.append(cur)
	return out


def texto_png(proyecto: Path, texto: str, destino: Path, px: int, color: tuple, y: int, borde: int = 10) -> Path:
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	f = _fuente(proyecto, px, 700)
	lineas = _lineas(d, texto, f, W - 140)
	alto = int(px * 1.18)
	for i, ln in enumerate(lineas):
		x = (W - d.textlength(ln, font=f)) / 2
		d.text((x, y + i * alto + 6), ln, font=f, fill=(0, 0, 0, 150), stroke_width=borde, stroke_fill=(0, 0, 0, 150))
		d.text((x, y + i * alto), ln, font=f, fill=color + (255,), stroke_width=borde, stroke_fill=(12, 12, 18, 255))
	img.save(destino)
	return destino


def _hex(h: str) -> tuple:
	h = h.lstrip("#")
	return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def cartel_png(proyecto: Path, titulo: str, cta: str, destino: Path) -> Path:
	game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	pal = game.get("palette", {})
	cielo = _hex(pal.get("sky", "#1b2a41"))
	acento = _hex(pal.get("accent", "#e8b04b"))
	arriba = tuple(min(255, c + 45) for c in cielo)
	img = Image.new("RGB", (W, H))
	d = ImageDraw.Draw(img)
	for y in range(H):
		k = y / (H - 1)
		d.line([(0, y), (W, y)], fill=tuple(int(arriba[i] + (cielo[i] - arriba[i]) * k) for i in range(3)))
	halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(halo).ellipse([190, 330, 890, 1030], fill=acento + (120,))
	halo = halo.filter(ImageFilter.GaussianBlur(80))
	img.paste(halo, (0, 0), halo)
	idle = proyecto / "assets" / "heroe" / "idle.png"
	if idle.exists():
		tira = Image.open(idle).convert("RGBA")
		h = tira.crop((0, 0, min(tira.width, tira.height), tira.height))
		caja = h.getbbox()
		if caja:
			h = h.crop(caja)
		k = 560 / max(h.width, h.height)
		h = h.resize((max(1, int(h.width * k)), max(1, int(h.height * k))), Image.NEAREST)
		img.paste(h, ((W - h.width) // 2, 680 - h.height // 2), h)
	d = ImageDraw.Draw(img)
	f_t = _fuente(proyecto, 116, 700)
	y = 1080
	for ln in _lineas(d, titulo, f_t, W - 120)[:2]:
		x = (W - d.textlength(ln, font=f_t)) / 2
		d.text((x, y), ln, font=f_t, fill=(255, 255, 255), stroke_width=8, stroke_fill=(10, 10, 16))
		y += 132
	f_c = _fuente(proyecto, 66, 700)
	ancho = d.textlength(cta, font=f_c) + 110
	caja = [(W - ancho) / 2, y + 60, (W + ancho) / 2, y + 60 + 120]
	d.rounded_rectangle(caja, radius=60, fill=acento)
	d.text(((W - d.textlength(cta, font=f_c)) / 2, caja[1] + 22), cta, font=f_c, fill=(20, 16, 8))
	img.save(destino)
	return destino


## ------------------------------------------------------------------ 4 - montaje

def montar(proyecto: Path, partida: Path, inicio: float, variante: dict, titulo: str, voz_wav: Path | None,
		destino: Path, tmp: Path) -> Path:
	tmp.mkdir(parents=True, exist_ok=True)
	game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	acento = _hex(game.get("palette", {}).get("accent", "#e8b04b"))
	capas: list[tuple[Path, float, float]] = []
	capas.append((texto_png(proyecto, variante["gancho"], tmp / "gancho.png", 100, acento, 250, 12), 0.0, 2.9))
	for i, s in enumerate(variante["subtitulos"]):
		capas.append((texto_png(proyecto, s["texto"], tmp / f"sub{i}.png", 80, (255, 255, 255), 1180), float(s["desde"]), float(s["hasta"])))
	cartel = cartel_png(proyecto, titulo, variante["cta"], tmp / "cartel.png")
	entradas = ["-ss", f"{inicio:.2f}", "-t", f"{TOTAL:.2f}", "-i", str(partida), "-loop", "1", "-t", f"{CARTEL + 0.4:.2f}", "-i", str(cartel)]
	for png, _, _ in capas:
		entradas += ["-loop", "1", "-t", f"{TOTAL:.2f}", "-i", str(png)]
	n_voz = None
	if voz_wav is not None:
		n_voz = 2 + len(capas)
		entradas += ["-i", str(voz_wav)]
	f: list[str] = [
		f"[0:v]trim=0:{JUEGO + 0.3:.2f},setpts=PTS-STARTPTS,scale={W}:{H}:flags=lanczos,fps=30,format=yuv420p,settb=AVTB[g]",
		f"[1:v]scale={W}:{H},fps=30,format=yuv420p,settb=AVTB[c]",
		f"[g][c]xfade=transition=fade:duration=0.3:offset={JUEGO:.2f}[v0]",
	]
	ultimo = "v0"
	for i, (_, a, b) in enumerate(capas):
		k = 2 + i
		f.append(f"[{k}:v]format=rgba,fade=t=in:st={a:.2f}:d=0.15:alpha=1,fade=t=out:st={max(a, b - 0.15):.2f}:d=0.15:alpha=1[t{i}]")
		f.append(f"[{ultimo}][t{i}]overlay=0:0:enable='between(t,{a:.2f},{b:.2f})'[v{i + 1}]")
		ultimo = f"v{i + 1}"
	f.append(f"[0:a]atrim=0:{TOTAL:.2f},asetpts=PTS-STARTPTS,aformat=sample_rates=44100:channel_layouts=stereo,"
		f"volume=0.85,afade=t=out:st={TOTAL - 1.2:.2f}:d=1.2[ga]")
	if n_voz is not None:
		from marketing import voz as vz
		dur = vz.duracion(voz_wav)
		tempo = min(1.3, max(1.0, dur / (JUEGO - 0.5)))
		f.append(f"[{n_voz}:a]aformat=sample_rates=44100:channel_layouts=stereo,atempo={tempo:.3f},adelay=350|350,"
			f"atrim=0:{JUEGO:.2f},volume=1.6,apad=whole_dur={TOTAL:.2f},asplit=2[vo1][vo2]")
		f.append("[ga][vo1]sidechaincompress=threshold=0.02:ratio=10:attack=15:release=350[duck]")
		f.append("[duck][vo2]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5:LRA=11[a]")
	else:
		f.append("[ga]loudnorm=I=-14:TP=-1.5:LRA=11[a]")
	cmd = entradas + ["-filter_complex", ";".join(f), "-map", f"[{ultimo}]", "-map", "[a]", "-t", f"{TOTAL:.2f}",
		"-r", "30", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-profile:v", "high", "-pix_fmt", "yuv420p",
		"-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-movflags", "+faststart", str(destino)]
	_ff(cmd)
	return destino


## ------------------------------------------------------------------ 6 - trailer horizontal (16:9)

def horizontal(proyecto: Path, vertical: Path, titulo: str, lema: str, cta: str, destino: Path) -> Path:
	"""Trailer 1920x1080 para la ficha de Google Play (video de YouTube) y YouTube normal.
	El juego es vertical: va en el centro, con el mismo video desenfocado de fondo, el titulo a la
	izquierda y la llamada a la accion a la derecha. Mismo sonido (musica y voz) que el vertical."""
	game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	acento = _hex(game.get("palette", {}).get("accent", "#e8b04b"))
	capa = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
	d = ImageDraw.Draw(capa)
	f_t = _fuente(proyecto, 92, 700)
	f_l = _fuente(proyecto, 44, 600)
	y = 360
	for ln in _lineas(d, titulo, f_t, 560)[:3]:
		d.text((70, y), ln, font=f_t, fill=(255, 255, 255, 255), stroke_width=8, stroke_fill=(12, 12, 18, 255))
		y += 108
	for ln in _lineas(d, lema, f_l, 560)[:2]:
		d.text((74, y + 16), ln, font=f_l, fill=acento + (255,), stroke_width=5, stroke_fill=(12, 12, 18, 255))
		y += 56
	for i, ln in enumerate(_lineas(d, cta, f_t, 520)[:3]):
		x = 1920 - 70 - d.textlength(ln, font=f_t)
		d.text((x, 420 + i * 108), ln, font=f_t, fill=acento + (255,), stroke_width=8, stroke_fill=(12, 12, 18, 255))
	png = destino.with_suffix(".capa.png")
	capa.save(png)
	filtro = ("[0:v]split=2[a][b];"
		"[a]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=28:4,eq=brightness=-0.18[fondo];"
		"[b]scale=-2:1080[juego];[fondo][juego]overlay=(W-w)/2:0[v1];[v1][1:v]overlay=0:0,format=yuv420p[v]")
	_ff(["-i", str(vertical), "-i", str(png), "-filter_complex", filtro, "-map", "[v]", "-map", "0:a?",
		"-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(destino)])
	png.unlink(missing_ok=True)
	return destino
