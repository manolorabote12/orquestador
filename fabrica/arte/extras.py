"""Arte de GPU para lo que antes era codigo (14 nov, «se nota que los menus y efectos son de codigo»).

	iconos   mas iconos de interfaz en el estilo del juego (calavera, cubo, gema, espada, cofre,
	         balon, escudo, rayo): el kit los usa en todos sus botones y marcadores (UiIcon).
	efectos  proyectiles, impacto, explosion, fogonazo, humo y onda de energia: la arena y los
	         generos de accion los dibujan en vez de circulos y lineas.
	eventos  ilustraciones de cada modo de la arena (tarjetas de Eventos), con su escena.
	props    rocas, arbustos, cajas y cubos de poder de la arena con el material del escenario.

Todo se pide sobre el fondo croma (menos las ilustraciones), se recorta y se comprueba; lo que no pase
el control se queda con el dibujo de siempre (el juego nunca sale roto). ~17 imagenes por juego.
"""

import io
from pathlib import Path

import numpy as np
from PIL import Image

from . import iconos, post, prompts, runpod

ICONOS = {
	"skull": "a single cartoon skull, front view",
	"cube": "a single glowing purple power cube gem seen in three quarter view",
	"gem": "a single faceted shiny gemstone",
	"sword": "a single sword pointing up diagonally",
	"chest": "a single closed treasure chest with metal bands and a lock",
	"ball": "a single round sports ball",
	"shield": "a single round shield with a metal rim",
	"bolt": "a single lightning bolt",
}
## Los que no tienen por que ser simetricos.
LIBRES = {"sword", "ball", "bolt", "cube", "chest"}

EFECTOS = {
	"proyectil": "a single glowing round energy orb projectile with a bright white core and a short comet tail, seen from above",
	"proyectil_largo": "a single long glowing energy bolt projectile, horizontal, bright white core, seen from above",
	"perdigon": "a single small glowing pellet projectile with a bright core, seen from above",
	"impacto": "a single cartoon hit impact burst, star shaped spark explosion with bright core",
	"explosion": "a single big cartoon explosion cloud with orange fire and yellow core and dark smoke edges",
	"fogonazo": "a single cartoon muzzle flash burst, bright yellow and white, star shaped",
	"humo": "a single round cartoon puff of white smoke cloud",
	"onda": "a single glowing circular energy shockwave ring, thin bright ring, empty center",
}

## Decorado de la arena dibujado por la GPU (antes rectangulos y circulos de codigo): con el material del
## escenario de cada juego (rocas de coral en el mar, piedra en el castillo...).
PROPS = {
	"roca": "a single chunky square rock block obstacle seen from a three quarter top-down view, flat top, made of {mat}",
	"arbusto": "a single dense round leafy bush clump seen from a three quarter top-down view, made of plants from {mat}",
	"caja": "a single wooden supply crate with metal corners seen from a three quarter top-down view",
	"cubo": "a single glowing purple power cube crystal, three quarter view",
}

MODOS = {
	"showdown": "a free for all battle where small heroes fight among bushes and rocks while a storm closes in",
	"ball": "a 3 versus 3 sports match where small heroes kick a ball towards a goal",
	"survival": "small heroes defending together against waves of incoming monsters",
	"turrets": "a 3 versus 3 siege where small heroes attack a big enemy turret tower",
}


def _prompt_pieza(biblia: dict, que: str) -> str:
	est = biblia["estilo"]
	chroma = est["fondo_chroma"].upper()
	nombre = {"#FF00FF": "pure magenta", "#00FF00": "pure green"}.get(chroma, chroma)
	return (f"{prompts.estilo_dibujo(est)}. Mobile game asset: {que}, bold readable shape, thick dark outline, centered, "
		f"fills most of the image, plain solid flat {nombre} background ({chroma}), no text, no letters, no characters, no shadow")


def _prompt_evento(biblia: dict, modo: str) -> str:
	est = biblia["estilo"]
	escenario = (biblia.get("escenarios") or [{}])[0].get("descripcion", "")
	return (f"{prompts.estilo_dibujo(est)}. Wide illustration banner for a mobile game mode: {MODOS[modo]}, set in {escenario}. "
		"Dynamic composition, vivid colors, lots of action, view from above at an angle, empty darker area on the right half "
		"for text, no text, no letters, no logos, no UI")


def _revisar_libre(img: Image.Image) -> list[str]:
	a = np.asarray(img).astype(np.float32)[..., 3]
	lleno = float((a > 200).mean())
	if lleno < 0.12:
		return ["muy fino o vacio"]
	if lleno > 0.97:
		return ["es un cuadrado"]
	return []


def _piezas(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, piezas: dict, libres: set, informe: dict, clave: str,
		lado: int) -> dict:
	carpeta.mkdir(parents=True, exist_ok=True)
	chroma = iconos._hex_rgb(biblia["estilo"]["fondo_chroma"])
	salida: dict = {}
	for i, (nombre, que) in enumerate(piezas.items()):
		ultimo: list[str] = []
		for intento in range(2):
			if intento and runpod.en_ahorro():
				break
			try:
				datos = cliente.generar(flujo, {"PROMPT": _prompt_pieza(biblia, que), "SEED": semilla + 307 * i + 7919 * intento,
					"ANCHO": 768, "ALTO": 768})[0]
			except Exception as e:  # noqa: BLE001 - sin la pieza el juego usa la de siempre
				ultimo = [str(e)[:120]]
				break
			informe["generaciones"] += 1
			img = post.quitar_fondo_seguro(Image.open(io.BytesIO(datos)).convert("RGBA"), chroma)
			bb = post.caja(img)
			if bb is None:
				ultimo = ["vacio"]
				continue
			img = img.crop(bb)
			ultimo = _revisar_libre(img) if nombre in libres else iconos.revisar(img)
			if not ultimo:
				ruta = carpeta / f"{nombre}.png"
				iconos.cuadrar(img, lado).save(ruta)
				salida[nombre] = ruta
				break
		if nombre not in salida:
			informe.setdefault("fallidos", {})[f"{clave}/{nombre}"] = ultimo
	return salida


def generar(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, arena: bool) -> tuple[dict, dict]:
	"""{"iconos": {nombre: png}, "efectos": {nombre: png}, "eventos": {modo: jpg}}, informe."""
	informe: dict = {"generaciones": 0}
	out: dict = {"iconos": _piezas(biblia, carpeta / "iconos", cliente, flujo, semilla, ICONOS, LIBRES, informe, "iconos", 128),
		"efectos": _piezas(biblia, carpeta / "efectos", cliente, flujo, semilla + 5000, EFECTOS, set(EFECTOS), informe, "efectos", 192),
		"eventos": {}}
	if arena:
		mat = (biblia.get("escenarios") or [{}])[0].get("descripcion", "the game world")[:160]
		props = {k: v.format(mat=mat) for k, v in PROPS.items()}
		out["efectos"].update(_piezas(biblia, carpeta / "props", cliente, flujo, semilla + 7000, props, set(props), informe, "props", 256))
		(carpeta / "eventos").mkdir(parents=True, exist_ok=True)
		for i, modo in enumerate(MODOS):
			try:
				datos = cliente.generar(flujo, {"PROMPT": _prompt_evento(biblia, modo), "SEED": semilla + 9000 + 31 * i, "ANCHO": 1024, "ALTO": 512})[0]
			except Exception as e:  # noqa: BLE001
				informe.setdefault("fallidos", {})[f"eventos/{modo}"] = [str(e)[:120]]
				continue
			informe["generaciones"] += 1
			img = Image.open(io.BytesIO(datos)).convert("RGB").resize((768, 384), Image.LANCZOS)
			ruta = carpeta / "eventos" / f"{modo}.jpg"
			img.save(ruta, quality=86, optimize=True)
			out["eventos"][modo] = ruta
	return out, informe
