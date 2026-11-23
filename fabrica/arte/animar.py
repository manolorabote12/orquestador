"""Personajes animados con un modelo de video abierto (15 nov 2026, «que se vea como Brawl Stars»).

FLUX/Z-Image dibuja al personaje una vez (ficha nitida, fondo croma) y Wan 2.2 I2V 14B (Apache-2.0, en el
mismo endpoint de RunPod, 4 pasos con las LoRA lightx2v) lo anima: quieto, correr, disparar, super,
golpe, muerte y victoria. Cada video se recorta al fondo croma y se queda en una hoja de sprites con la
MISMA escala y apoyada en los pies (nada salta de tamano entre animaciones). Sirve para cualquier
criatura (cangrejos, pulpos...), cosa que no hace un esqueleto 3D de persona.

	python -m arte.animar <personaje.json> <carpeta_salida>     (ORQ_COMFY=runpod://<endpoint>)

personaje.json: {"id", "descripcion", "estilo": {...como en la Biblia...}, "animaciones"?: [nombres]}
Salida: ficha.png, <anim>.png (hoja), <anim>.gif (video entero para revisarlo), informe.json.
"""

import io
import json
import os
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from arte import post, prompts  # noqa: E402
from arte.runpod import TopeGPU, cliente as hacer_cliente  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
CELDA = 256
FPS = 16

## Movimiento que se le pide al video y cuantos fotogramas se quedan en la hoja (de 33, ~2 s).
ANIMACIONES: dict[str, dict] = {
	"idle": {"que": "breathes and bobs gently in place, claws sway a little, blinks, stays on the same spot", "frames": 12, "bucle": True},
	"run": {"que": "runs in place very fast toward the right, legs scuttling quickly, body bouncing, claws pumping, stays centered, looping run cycle",
		"frames": 8, "bucle": True, "desde": 8, "hasta": 24},
	"attack": {"que": "snaps its big claw forward to the right and fires a burst of water, strong recoil, then returns to its pose", "frames": 8, "bucle": False},
	"super": {"que": "jumps up, spins and slams down releasing a powerful glowing water wave all around it, energetic special attack",
		"frames": 12, "bucle": False, "hasta": 24},
	"hurt": {"que": "gets hit hard, flinches backward with a pained squint, shakes, then recovers", "frames": 6, "bucle": False, "hasta": 16},
	"death": {"que": "gets knocked out, spins, falls on its back with dizzy swirly eyes and stays lying still", "frames": 12, "bucle": False},
	"victory": {"que": "celebrates a victory, jumps happily raising both claws in the air, cheerful and proud", "frames": 12, "bucle": True},
}


MORADOS = ("purple", "violet", "magenta", "pink", "lilac", "lavender", "fuchsia", "mauve")


def _chroma(estilo: dict, descripcion: str = "") -> tuple[str, tuple[int, int, int]]:
	hexa = str(estilo.get("fondo_chroma") or "#FF00FF").upper()
	## Un personaje morado o rosa sobre fondo magenta se recortaria mal: para el, fondo verde.
	if hexa == "#FF00FF" and any(w in (descripcion or "").lower() for w in MORADOS):
		hexa = "#00FF00"
	nombre = {"#FF00FF": "pure magenta", "#00FF00": "pure green"}.get(hexa, hexa)
	return nombre, tuple(int(hexa[i:i + 2], 16) for i in (1, 3, 5))


def prompt_ficha(p: dict) -> str:
	nombre, _ = _chroma(p["estilo"], p["descripcion"])
	return (f"{prompts.estilo_dibujo(p['estilo'])}. Mobile game hero character: {p['descripcion']}. Full body, three quarter view "
		f"facing right, standing in a ready pose, clear readable face with eyes and mouth, centered, the character fills about 60% of the image, plain solid flat {nombre} "
		"background, no text, no shadow, no other characters, crisp clean outlines, high quality")


def _anims(p: dict) -> dict:
	"""Animaciones del personaje: las de serie o las suyas («movimientos»: {nombre: {que, frames, bucle...}})."""
	if p.get("movimientos"):
		return {k: {"frames": 10, "bucle": False, **v} for k, v in p["movimientos"].items()}
	return ANIMACIONES


def prompt_video(p: dict, anim: str) -> str:
	nombre, _ = _chroma(p["estilo"], p["descripcion"])
	que = _anims(p)[anim]["que"]
	tipo = p.get("tipo_video") or "A cartoon mobile game character"
	return (f"{tipo} ({p['descripcion'][:160]}) {que}. Smooth fluid animation, "
		f"the character keeps exactly the same design and colors, static camera, the plain flat {nombre} background never changes, "
		"no other objects, 2D game sprite animation")


def frames_webp(datos: bytes) -> list[Image.Image]:
	img = Image.open(io.BytesIO(datos))
	out = []
	for i in range(getattr(img, "n_frames", 1)):
		img.seek(i)
		out.append(img.convert("RGB"))
	return out


def elegir(frames: list, n: int, desde: int = 0, hasta: int | None = None) -> list:
	tramo = frames[desde:hasta] or frames
	if len(tramo) <= n:
		return list(tramo)
	return [tramo[round(i * (len(tramo) - 1) / max(n - 1, 1))] for i in range(n)]


def recortar_fondo(img: Image.Image) -> Image.Image:
	"""Fondo y sombra fuera, conservando el contorno: el color del fondo se mide en el borde (el modelo no
	siempre pinta el croma puro) y se quita todo pixel que sea ese color o una version mas oscura de el
	(la sombra en el suelo). Mismo «color direccion» = fondo; asi el contorno negro y la piel se quedan."""
	a = np.asarray(img.convert("RGBA")).astype(np.float32)
	rgb = a[..., :3]
	borde = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
	fondo = np.median(borde, axis=0)
	nf = float(np.linalg.norm(fondo)) or 1.0
	n = np.linalg.norm(rgb, axis=-1)
	cos = (rgb @ fondo) / np.maximum(n * nf, 1e-5)
	k = n / nf
	es_fondo = (cos > 0.985) & (k > 0.3)
	## Borde suave: medio transparente lo que casi es fondo (halo del antialias).
	casi = (cos > 0.965) & (k > 0.3) & ~es_fondo
	alfa = np.where(es_fondo, 0.0, np.where(casi, 110.0, a[..., 3]))
	a[..., 3] = alfa
	return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def recortar(frames: list[Image.Image], chroma: tuple[int, int, int], ref_alto: int | None = None) -> tuple[list[Image.Image], int]:
	"""Quita el fondo y encaja todos los fotogramas en la misma celda, con la misma escala y los pies
	abajo. ref_alto: alto del personaje en la ficha (la escala comun de todas las animaciones)."""
	limpios = [recortar_fondo(f) for f in frames]
	cajas = [post.caja(f) for f in limpios]
	cajas = [c for c in cajas if c]
	if not cajas:
		return [], ref_alto or 1
	x0 = min(c[0] for c in cajas)
	y0 = min(c[1] for c in cajas)
	x1 = max(c[2] for c in cajas)
	y1 = max(c[3] for c in cajas)
	alto = ref_alto or (y1 - y0)
	escala = (CELDA * 0.72) / max(alto, 1)
	## Cuerpos anchos (lobos, dragones, arietes): que quepan a lo ancho en vez de cortarse por los lados.
	escala = min(escala, (CELDA * 0.97) / max(x1 - x0, 1))
	out = []
	for f in limpios:
		tramo = f.crop((x0, y0, x1, y1))
		w, h = max(1, round(tramo.width * escala)), max(1, round(tramo.height * escala))
		tramo = tramo.resize((w, h), Image.LANCZOS)
		celda = Image.new("RGBA", (CELDA, CELDA), (0, 0, 0, 0))
		celda.alpha_composite(tramo, ((CELDA - w) // 2, max(0, CELDA - h - 8)) if h < CELDA else ((CELDA - w) // 2, 0))
		out.append(celda)
	return out, alto


def gif(frames: list[Image.Image], ruta: Path, fondo=(232, 201, 135)) -> None:
	"""Vista previa sobre arena (como en la partida)."""
	cuadros = []
	for f in frames:
		b = Image.new("RGBA", f.size, fondo + (255,))
		b.alpha_composite(f)
		cuadros.append(b.convert("P", palette=Image.ADAPTIVE, colors=255))
	cuadros[0].save(ruta, save_all=True, append_images=cuadros[1:], duration=int(1000 / FPS), loop=0, disposal=2)


def animar(p: dict, carpeta: Path, cli) -> dict:
	carpeta.mkdir(parents=True, exist_ok=True)
	_, chroma = _chroma(p["estilo"], p["descripcion"])
	informe: dict = {"personaje": p["id"], "animaciones": {}, "errores": {}}
	t0 = time.time()
	crear = json.loads((RAIZ / "plantillas" / "runpod" / "crear_zimage.json").read_text(encoding="utf-8"))
	wan = json.loads((RAIZ / "plantillas" / "runpod" / "animar_wan.json").read_text(encoding="utf-8"))
	semilla = int(p.get("semilla", 4242))
	## 1 - Ficha nitida del personaje (la que se anima): o se dibuja, o se usa la del juego («ficha»: PNG recortado).
	if p.get("ficha"):
		ficha = _ficha_propia(RAIZ.parent / p["ficha"], chroma)
	else:
		datos = cli.generar(crear, {"PROMPT": prompt_ficha(p), "SEED": semilla, "ANCHO": 1024, "ALTO": 1024})[0]
		ficha = Image.open(io.BytesIO(datos)).convert("RGB")
	ficha.save(carpeta / "ficha_croma.png")
	limpia = recortar_fondo(ficha)
	bb = post.caja(limpia)
	## Alto del personaje en la ficha, medido a la escala del video (480 px).
	ref_alto = round((bb[3] - bb[1]) * 480 / ficha.height) if bb else None
	limpia.save(carpeta / "ficha.png")
	## Entrada del video: la ficha a 480 x 480 con su fondo croma.
	cli.subir_imagen("ref.png", _png(ficha.resize((480, 480), Image.LANCZOS)))
	for i, (anim, cfg) in enumerate(_anims(p).items()):
		if p.get("animaciones") and anim not in p["animaciones"]:
			continue
		try:
			vid = cli.generar(wan, {"PROMPT": prompt_video(p, anim), "SEED": semilla + 101 * (i + 1), "REF1": "ref.png",
				"ANCHO": {"width": 480, "height": 480, "length": 33}})[0]
		except TopeGPU as e:
			informe["errores"][anim] = str(e)
			break
		except Exception as e:  # noqa: BLE001 - una animacion que falla no para las demas
			informe["errores"][anim] = str(e)[:300]
			continue
		todos = frames_webp(vid)
		(carpeta / f"{anim}_video.webp").write_bytes(vid)
		completos, _ = recortar(todos, chroma, ref_alto)
		if not completos:
			informe["errores"][anim] = "video vacio"
			continue
		gif(completos, carpeta / f"{anim}.gif")
		elegidos = elegir(completos, int(cfg["frames"]), int(cfg.get("desde", 0)), cfg.get("hasta"))
		post.hoja(elegidos).save(carpeta / f"{anim}.png")
		informe["animaciones"][anim] = {"frames": len(elegidos), "video_frames": len(todos), "fps": 12 if anim == "run" else 10,
			"bucle": bool(cfg["bucle"])}
		print(f"[animar] {anim}: {len(todos)} fotogramas -> {len(elegidos)} en la hoja", flush=True)
	informe["segundos"] = round(time.time() - t0, 1)
	informe["usd"] = round(float(getattr(cli, "usd", 0.0)), 4)
	informe["segundos_gpu"] = round(float(getattr(cli, "segundos_gpu", 0.0)), 1)
	(carpeta / "informe.json").write_text(json.dumps(informe, indent=1, ensure_ascii=False), encoding="utf-8")
	return informe


def _ficha_propia(ruta: Path, chroma: tuple[int, int, int]) -> Image.Image:
	"""Un sprite ya recortado del juego, centrado sobre el croma (ocupa ~62% del alto, pies abajo)."""
	spr = Image.open(ruta).convert("RGBA")
	bb = spr.getbbox()
	if bb:
		spr = spr.crop(bb)
	lado = 1024
	esc = min(lado * 0.62 / spr.height, lado * 0.8 / spr.width)
	spr = spr.resize((max(1, round(spr.width * esc)), max(1, round(spr.height * esc))), Image.LANCZOS)
	fondo = Image.new("RGBA", (lado, lado), chroma + (255,))
	fondo.alpha_composite(spr, ((lado - spr.width) // 2, round(lado * 0.86) - spr.height))
	return fondo.convert("RGB")


def _png(img: Image.Image) -> bytes:
	b = io.BytesIO()
	img.save(b, "PNG")
	return b.getvalue()


def main() -> int:
	p = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
	cli = hacer_cliente(os.environ.get("ORQ_COMFY", ""))
	if hasattr(cli, "timeout"):
		cli.timeout = 900.0
	## Lote: {"personajes": [ficha, ficha...], "estilo"?, "tipo_video"?} -> una carpeta por personaje.
	if p.get("personajes"):
		hechos = 0
		for q in p["personajes"]:
			q = {"estilo": p.get("estilo", {}), "tipo_video": p.get("tipo_video"), **q}
			try:
				inf = animar(q, Path(sys.argv[2]) / q["id"], cli)
			except TopeGPU as e:
				print(f"[animar] tope de gasto: {e}", flush=True)
				break
			print(json.dumps(inf, ensure_ascii=False), flush=True)
			hechos += bool(inf["animaciones"])
		return 0 if hechos else 1
	inf = animar(p, Path(sys.argv[2]), cli)
	print(json.dumps(inf, ensure_ascii=False))
	return 0 if inf["animaciones"] else 1


if __name__ == "__main__":
	sys.exit(main())
