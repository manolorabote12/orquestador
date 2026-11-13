"""Arte de la app (13 nov 2026): portadas ilustradas de los tipos de juego y carteles del taller.

Las tarjetas de los tipos de juego eran capturas de partida con arte simulado (cuadritos y formas):
la app parecia basica. Aqui se genera una portada ilustrada por genero con Z-Image en la GPU de
RunPod (el mismo endpoint de imagenes de la fabrica), todas con el mismo estilo de casa para que
el catalogo se vea como un conjunto.

	python arte_app.py generos [id1,id2...]   -> app/public/generos_arte/<id>.webp (360x640)
	python arte_app.py carteles                -> app/public/carteles/<id>.webp (720x400 / 720x1280)

Necesita RUNPOD_API_KEY y ORQ_COMFY=runpod://<endpoint de imagenes>. Tope: ORQ_ARTE_APP_USD
(por defecto 2 $): al llegar se para y deja lo que ya tenga. Lo corre el workflow «Arte de la app».
"""

import io
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from PIL import Image  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
FLUJO = Path(__file__).parent / "plantillas" / "runpod" / "crear_zimage.json"

ESTILO = ("polished stylized 3D cartoon mobile game key art, vibrant saturated colors, soft global illumination, "
	"rim light, cinematic composition, high detail, cute appealing characters with big expressive eyes, "
	"vertical poster composition, clear focal point in the center, depth of field background, "
	"original character designs, no famous characters, no brands, no car logos, no signs, no text, no letters, no words, "
	"no writing, no logo, no watermark, no user interface, no frame, no border")

## Lo que sale en cada portada (en ingles, el modelo lo entiende mejor). Personajes genericos y
## originales: nada de marcas ni personajes conocidos.
SUJETOS = {
	"plataformas": "a brave little fox hero leaping between floating grassy platforms over a sunny valley, golden coins in the air",
	"runner": "a cheerful kid running at full speed along a rooftop path at sunset, coins trailing, motion blur",
	"volador": "a tiny round bird flapping through a gap between green pipes in a bright sky with clouds",
	"horda": "a young wizard surrounded by a swarm of cute bats and slimes, glowing magic circle and orbiting fireballs, night meadow",
	"puzle": "a board of shiny colorful gems and candies exploding in a sparkling combo, magical glow",
	"torres": "cute cannon and crystal towers defending a winding path against a line of goofy goblins, fantasy valley",
	"carreras": "aerial view of open-wheel formula race cars speeding around a curve of a colorful track, tire smoke, crowd stands, realistic vehicles without eyes",
	"naves": "a small heroic spaceship firing lasers at colorful alien invaders, nebula and stars",
	"rompebloques": "a glowing ball smashing a wall of neon bricks, sparks and particles, retro arcade",
	"bloques": "colorful falling block pieces clearing a line with a bright flash, clean neon grid",
	"corredor": "a hero running down a three-lane jungle temple road jumping over a log, coins ahead",
	"serpiente": "a long friendly green snake slithering across a checkered garden lawn toward glowing red apples",
	"memoria": "rows of face-down cards with a few flipped showing cute animal pairs, magical table",
	"cajas": "a little warehouse robot pushing wooden crates onto glowing target tiles, cozy puzzle room",
	"preguntas": "a cheerful quiz show stage with big colorful answer buttons and confetti, spotlight",
	"apilar": "a tall tower of perfectly stacked colorful blocks reaching the clouds, one block swinging above",
	"topos": "cute moles popping out of holes in a lush garden, a wooden mallet mid-swing",
	"saltos": "a bouncy jelly creature jumping upward on floating platforms into the sky",
	"arena": "four cartoon brawlers clashing in a colorful circular arena, energetic action poses",
	"aldea": "a lively fortified village with walls and towers under attack by cartoon barbarians, isometric view",
	"ritmo": "glowing musical notes flying down neon lanes toward a stage, concert lights",
	"clicker": "a giant shiny golden cookie surrounded by coins and upgrades, sparkles, warm light",
	"cartas": "playing cards fanned on a green felt table, golden glow, cozy lamp",
	"rpg": "a young knight and a mage facing a big friendly-scary dragon in a turn-based battle, fantasy ruins",
	"laberinto": "a tiny explorer with a lantern in a stone maze, keys and doors, glowing coins",
	"golf": "a golf ball flying toward a flag on a floating island green, bright blue sky",
	"pesca": "a kid in a little boat casting a fishing line into a sparkling lake full of colorful fish",
	"fusion": "cute round creatures of growing sizes merging together in a glass jar with a burst of light",
	"tubos": "glass test tubes filled with layers of bright colored liquids being sorted, sparkling lab",
	"burbujas": "a cannon shooting colorful bubbles at a cluster of bubbles popping in a chain, fantasy forest",
	"imperio": "a miniature landscape where stone huts on the left turn into castles and then a modern city on the right, tilt-shift isometric view",
	"minas": "cute dwarf miners digging tunnels full of gems and gold, mine carts, cross-section view",
	"mazmorras": "a hero with a sword and shield entering a torchlit dungeon full of treasure chests and skeletons",
	"granja": "a cozy farm with crops, chickens, cows and a red barn, sunny morning",
	"mazo": "magical battle cards glowing above a wooden table with a hero card in front, fantasy duel",
	"aventura": "a young explorer at a crossroads in an enchanted forest, two glowing paths, storybook mood",
	"cocina": "a busy cartoon diner kitchen with a chef flipping burgers and happy customers waiting",
	"mahjong": "stacked ivory mahjong tiles with colorful symbols in a calm zen garden",
	"aparcamiento": "a cramped parking lot with colorful toy cars trying to get out, top-down view",
	"sopa": "a letter grid with highlighted hidden words glowing, cozy desk with a magnifying glass",
	"sudoku": "an elegant number grid on old paper with a pencil and a warm cup of tea",
	"nonograma": "a pixel picture of a cat being revealed on a grid with number clues, cozy",
	"cortar": "juicy fruits flying in the air being sliced by a blade swipe, splash of juice",
	"penaltis": "a soccer player taking a penalty kick, goalkeeper diving, stadium lights",
	"agujero": "a giant black hole in a toy city swallowing cars, trees and buildings",
	"ciudad": "a growing cartoon city with skyscrapers, parks and cranes, isometric",
	"canasta": "a basketball swishing through a hoop with sparkles, outdoor court at sunset",
	"espiral": "a bouncing ball falling down a twisting colorful helix tower",
	"buscaminas": "a grid field with numbered tiles and a cute flag, a hidden mine glowing",
	"conecta": "a vertical board with red and yellow discs about to connect four in a row",
	"damas": "close-up of a draughts board with flat round red and black discs stacked as kings, no chess pieces, warm lamp light",
	"billar": "a pool table with colorful balls breaking from the triangle, dramatic overhead lamp",
	"solitario": "solitaire cards cascading on a green table with a golden victory sparkle",
	"parchis": "a colorful ludo board with tokens racing home and dice rolling",
	"caida": "colorful pieces falling into a well and fitting perfectly, clean bright puzzle",
	"bolos": "a bowling ball striking pins that explode in all directions, neon alley",
	"mundo": "a blocky voxel world with a hero chopping trees and building a house at dawn",
	"royale": "cute rubber-duck heroes parachuting onto a tropical island battleground, storm circle in the distance",
	"cruzar": "a chicken hopping across roads with cars, rivers with logs and train tracks, voxel style",
	"arco": "an archer aiming at a distant target with flags showing wind, golden hour",
	"cubos": "a first-person view of hands building with colorful cubes in a voxel landscape",
	"parkour": "a runner leaping between rooftops and floating platforms high in the sky",
	"tienda": "a cozy little grocery store interior with fruit shelves, a cash register and a smiling shopkeeper",
	"futbol": "two cartoon soccer teams playing in a bright stadium, ball in the air",
	"terror": "a spooky but friendly haunted mansion hallway lit by a flashlight beam, cute ghost peeking from a doorway",
	"conduccion": "a small rounded generic delivery van with plain panels driving through colorful toy city streets, parcels on the roof",
	"zombis": "a first-person view of a hero with a toy blaster facing silly green cartoon zombies at night",
	"baloncesto": "a street basketball game on an urban court, player dunking, graffiti walls",
	"tenis": "a tennis player hitting a powerful forehand on a blue court, ball with motion trail",
	"karts": "cute characters racing go-karts on a colorful circuit with ramps and item boxes",
	"supervivencia": "a castaway building a campfire shelter on a tropical island at dusk, crafting tools",
	"triple": "colorful 3D tiles stacked in a pile with a tray of matched triples below, cozy",
	"tornillos": "a wooden board with colorful screws being unscrewed and metal plates falling",
	"hexas": "stacks of colorful hexagon tiles merging on a honeycomb board, satisfying",
	"autobus": "colorful buses waiting as matching colored passengers queue to board, top-down",
	"duelo": "two castles facing each other with cute troops charging across a river bridge, card battle",
	"escalada": "a small plain off-road buggy without face climbing a steep grassy hill with fuel cans, bumpy terrain",
	"tirachinas": "round birds launched from a slingshot toward a wobbly wooden tower with pigs, sunny",
	"plantas": "cheerful plants defending a garden lawn in lanes against goofy cartoon zombies",
	"palabra": "a grid of letter tiles turning green and yellow as a word is guessed, clean",
	"letras": "a wheel of letters connecting to fill a crossword, warm scenic background",
	"tycoon": "a cheerful businessman in a suit standing on top of a pile of gold coins in front of a row of colorful shops",
	"tragaperras": "a colorful slot machine spinning with coins bursting out and a tiny village behind",
	"reino": "a fantasy kingdom city with castle, farms and walls, armies marching out to conquer, isometric",
	"multitud": "a huge crowd of little blue people running through multiplier gates toward a giant boss",
	"pedidos": "a merge board of food items with customers placing orders, cozy cafe",
	"poder": "a small hero absorbing power from defeated monsters and growing bigger, tower of enemies",
	"diferencias": "two almost identical colorful pictures side by side with a circle on a difference",
	"rompecabezas": "jigsaw puzzle pieces of a mountain lake landscape almost complete on a wooden table, last pieces floating, no characters",
	"pintar": "a pixel art picture being colored by numbers, palette of paints, cozy",
	"cuchillos": "knives stuck in a spinning wooden log target, one knife flying toward it",
	"arquero": "a hooded archer hero shooting arrows at waves of monsters in a dungeon room",
	"flechas": "a grid of colorful arrows sliding out one by one, clean minimal puzzle",
	"numeros": "sliding number tiles merging into a glowing 2048 tile, clean pastel colors",
	"cartas_locas": "colorful crazy cards with numbers and wild cards flying out of a deck",
	"domino": "domino tiles laid in a winding line on a wooden table",
	"bloques_colores": "colored blocks sliding to doors of matching colors on a board",
	"tuberias": "pipes rotated to connect and water flowing through them, sparkling",
	"ajedrez": "a dramatic chessboard with a king in checkmate under a spotlight",
	"reversi": "a reversi board with black and white discs flipping in a wave",
	"buscar": "a cluttered magical attic full of hidden objects with a magnifying glass",
	"deslizar": "a sliding tile puzzle of a beautiful picture almost solved",
	"ahorcado": "a cute owl teacher pointing at a green chalkboard with blank lines and colorful chalk pieces",
	"flota": "a naval grid with little battleships and splashes from hits",
	"simon": "four big glowing colored buttons lighting up in sequence",
	"estrategia": "a tactical map with little armies on hex tiles, castles and banners",
	"autobatalla": "a chessboard arena where cute units fight automatically, merge stars glowing",
	"gemas": "heroes attacking a monster with bursts of matched gems below them",
	"coleccionables": "a fan of three glowing fantasy cards seen from behind with ornate golden backs, magic sparks, a small dragon creature flying above them, enchanted table",
	"roguelike": "a small adventurer with a torch exploring a stone dungeon corridor with treasure chests and spike traps, purple glow",
	"bombas": "a little bomber hero in a maze of crates with a bomb exploding",
	"artilleria": "cartoon tanks on hills firing arcing shells with wind flags",
	"comecocos": "a round hungry character in a neon maze chased by cute ghosts",
	"cadena": "a chain of colorful balls rolling along a spiral track toward a skull hole, shooter frog",
	"lucha": "two cartoon martial artists in dynamic fighting stances on a temple courtyard at sunset",
	"sandia": "cute fruits of growing sizes stacked in a box merging into a big watermelon",
	"pinball": "a neon pinball table seen from above with flippers, round bumpers and a shiny silver ball, no characters",
	"metroidvania": "a lone explorer in a vast underground world of ruins and glowing crystals",
	"sigilo": "a sneaky ninja hiding in the shadows as guards with lanterns patrol, top-down",
}

CARTELES = {
	"bienvenida": (720, 1280, "a magical workshop where a little robot builds a video game world out of light: floating islands, "
		"characters and castles appearing from glowing blueprints, warm and inspiring"),
	"estudio": (720, 400, "a premium cinematic game studio scene: concept art boards, glowing screens and a dragon "
		"and hero coming to life from sketches, golden light"),
	"publicar": (720, 400, "a rocket launching from a phone screen into the sky with stars and trophies, celebration"),
	"vacio": (720, 400, "an empty cozy workbench with tools and a glowing blank cartridge waiting to be filled"),
	"comunidad": (720, 400, "a crowd of happy cartoon players holding phones and cheering around a stage with games"),
}


## Chispa, la mascota de la app (13 nov): la misma identidad que el dibujo de siempre (cabeza de latón
## con un ojo, antena con chispa, cuerpo naranja con una tuerca), pero en 3D de calidad.
MASCOTA = ("Chispa, an adorable heroic little robot mascot character: rounded golden brass head shaped like an old TV "
	"with one big glowing cyan eye on a dark screen face, a small antenna with a bright electric spark on top, compact "
	"orange body with a hexagonal golden nut emblem on the chest, short arms with round hands, short legs with tiny jet boots, "
	"friendly confident expression, premium polished 3D render like the mascot of a top mobile game, soft studio lighting, "
	"rim light, full body, centered, plain solid flat magenta background (#FF00FF), no shadow, no text, no logo")

## Poses (con la base como referencia: FLUX.2 klein edita manteniendo el personaje).
POSES = {
	"hola": "the same robot character waving hello with one hand, happy eye, full body",
	"pensando": "the same robot character thinking with a hand on its chin, a small glowing light bulb above its antenna, full body",
	"trabajando": "the same robot character holding a big wrench and a glowing blueprint, building something, sparks flying, full body",
	"celebrando": "the same robot character jumping with joy with both arms up, confetti and stars around, full body",
	"triste": "the same robot character looking a bit sad and apologetic, droopy antenna, full body",
	"jugando": "the same robot character holding a game controller excitedly, full body",
	"tuercas": "the same robot character hugging a big shiny golden hexagonal nut coin, full body",
	"cohete": "the same robot character flying upward with flames from its jet boots, one fist up, full body",
	"durmiendo": "the same robot character sitting and sleeping peacefully with a small Z bubble, eye closed, full body",
	"ganando": "the same robot character holding a golden trophy up proudly, full body",
}
POSE_FIN = (", keep exactly the same character design, colors and proportions, premium 3D render, plain solid flat "
	"magenta background (#FF00FF), no shadow, no text")

FONDOS = {
	"fondo_app": (720, 1280, "dark atmospheric background of a futuristic game creation workshop at night, deep navy and indigo "
		"tones, faint glowing blueprint lines and holographic game sketches floating in the distance, soft bokeh lights, "
		"warm golden accents, very low contrast, calm, mostly dark with empty space, no characters, no text, no logo"),
	"fondo_cabecera": (1024, 576, "wide dark banner of a magical game factory with conveyor belts carrying tiny glowing game worlds, "
		"deep navy blue and gold palette, cinematic, soft glow, darker at the edges, no characters, no text, no logo"),
}


def cliente():
	from arte import runpod
	return runpod.cliente(os.environ["ORQ_COMFY"])


def flujo() -> dict:
	return json.loads(FLUJO.read_text(encoding="utf-8"))


def generar(cli, prompt: str, w: int, h: int, semilla: int) -> Image.Image:
	datos = cli.generar(flujo(), {"PROMPT": prompt, "SEED": semilla, "ANCHO": w, "ALTO": h})[0]
	return Image.open(io.BytesIO(datos)).convert("RGB")


def guardar(img: Image.Image, ruta: Path, tam: tuple[int, int]) -> None:
	ruta.parent.mkdir(parents=True, exist_ok=True)
	img.resize(tam, Image.LANCZOS).save(ruta, "WEBP", quality=80, method=6)


def tope() -> float:
	return float(os.environ.get("ORQ_ARTE_APP_USD", "2") or 2)


def main(argv: list[str]) -> int:
	que = argv[0] if argv else "generos"
	cli = cliente()
	hechos, fallos = [], []
	if que == "generos":
		ids = argv[1].split(",") if len(argv) > 1 and argv[1] else list(SUJETOS)
		destino = RAIZ / "app" / "public" / "generos_arte"
		for k, g in enumerate(ids):
			if g not in SUJETOS:
				fallos.append(f"{g}: no tiene sujeto")
				continue
			if getattr(cli, "usd", 0.0) >= tope():
				fallos.append(f"{g}: tope de {tope():.2f} $")
				continue
			try:
				img = generar(cli, f"{SUJETOS[g]}, {ESTILO}", 576, 1024, 1300 + k * 7)
				guardar(img, destino / f"{g}.webp", (360, 640))
				hechos.append(g)
				print(f"ok {g} ({getattr(cli, 'usd', 0.0):.3f} $)", flush=True)
			except Exception as e:  # noqa: BLE001 - uno que falle no para el resto
				fallos.append(f"{g}: {str(e)[:120]}")
				print(f"::warning::{g}: {str(e)[:160]}", flush=True)
	elif que == "carteles":
		destino = RAIZ / "app" / "public" / "carteles"
		for k, (cid, (w, h, sujeto)) in enumerate(CARTELES.items()):
			try:
				gw, gh = (576, 1024) if h > w else (1024, 576)
				img = generar(cli, f"{sujeto}, {ESTILO.replace('vertical poster composition', 'wide banner composition' if w > h else 'vertical poster composition')}", gw, gh, 2600 + k * 11)
				guardar(img, destino / f"{cid}.webp", (w, h))
				hechos.append(cid)
				print(f"ok {cid} ({getattr(cli, 'usd', 0.0):.3f} $)", flush=True)
			except Exception as e:  # noqa: BLE001
				fallos.append(f"{cid}: {str(e)[:120]}")
	elif que == "mascota":
		destino = RAIZ / "app" / "public" / "mascota" / "candidatos"
		for k in range(int(argv[1]) if len(argv) > 1 and argv[1].isdigit() else 6):
			try:
				img = generar(cli, MASCOTA, 1024, 1024, 4100 + k * 13)
				guardar(img, destino / f"c{k}.webp", (512, 512))
				hechos.append(f"c{k}")
			except Exception as e:  # noqa: BLE001
				fallos.append(f"c{k}: {str(e)[:120]}")
	elif que == "poses":
		from arte import post
		base = RAIZ / "app" / "public" / "mascota" / "base.png"
		cli.subir_imagen("chispa_base.png", base.read_bytes())
		wf = json.loads((Path(__file__).parent / "plantillas" / "runpod" / "editar_klein.json").read_text(encoding="utf-8"))
		destino = RAIZ / "app" / "public" / "mascota"
		ids = argv[1].split(",") if len(argv) > 1 and argv[1] else list(POSES)
		for k, pid in enumerate(ids):
			if getattr(cli, "usd", 0.0) >= tope():
				break
			try:
				datos = cli.generar(wf, {"PROMPT": POSES[pid] + POSE_FIN, "SEED": 5200 + k * 17, "REF1": "chispa_base.png"})[0]
				img = post.quitar_fondo_seguro(Image.open(io.BytesIO(datos)).convert("RGBA"), (255, 0, 255))
				caja = img.getbbox()
				if caja:
					img = img.crop(caja)
				img.thumbnail((512, 512), Image.LANCZOS)
				destino.mkdir(parents=True, exist_ok=True)
				img.save(destino / f"{pid}.webp", "WEBP", quality=85, method=6)
				hechos.append(pid)
			except Exception as e:  # noqa: BLE001
				fallos.append(f"{pid}: {str(e)[:120]}")
	elif que == "fondos":
		destino = RAIZ / "app" / "public" / "fondos"
		for k, (fid, (w, h, sujeto)) in enumerate(FONDOS.items()):
			try:
				gw, gh = (576, 1024) if h > w else (1024, 576)
				for v in range(2):
					img = generar(cli, sujeto, gw, gh, 7300 + k * 19 + v * 101)
					guardar(img, destino / f"{fid}_{v}.webp", (w, h))
					hechos.append(f"{fid}_{v}")
			except Exception as e:  # noqa: BLE001
				fallos.append(f"{fid}: {str(e)[:120]}")
	print(f"::notice::Arte de la app ({que}): {len(hechos)} hechos, {len(fallos)} fallos, {getattr(cli, 'usd', 0.0):.2f} $")
	for f in fallos[:20]:
		print("  FALLO", f)
	return 0 if hechos else 1


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
