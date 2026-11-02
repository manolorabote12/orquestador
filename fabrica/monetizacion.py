"""Monetizacion de cada juego: el perfil de su tipo (lo mismo que orqkit/kit/monetize.gd, que es lo
que usa el juego) y un informe para el autor: que lleva, por que y que tiene que crear.
	perfil(genero_kit, infantil, propio) -> nombre del perfil
	informe(genero_kit, infantil, propio) -> dict para fabrica/monetizacion.json y la app
La prueba pruebas/prueba_monetizacion.py comprueba que esta tabla y la del kit dicen lo mismo."""

PERFILES = {
	"hipercasual": {"banner_menu": True, "banner_game": False, "inter_every": 1, "inter_cooldown": 45, "inter_max": 10, "app_open": False,
		"rewarded": ["revive", "double_reward", "skip_level"], "iap": ["sin_anuncios", "monedas_500"]},
	"puzle": {"banner_menu": True, "banner_game": True, "inter_every": 2, "inter_cooldown": 90, "inter_max": 6, "app_open": False,
		"rewarded": ["hint", "extra_moves", "double_reward", "skip_level"], "iap": ["sin_anuncios", "pack_inicio", "monedas_500", "monedas_3000"]},
	"arcade": {"banner_menu": True, "banner_game": False, "inter_every": 1, "inter_cooldown": 90, "inter_max": 6, "app_open": False,
		"rewarded": ["revive", "double_reward", "chest"], "iap": ["sin_anuncios", "monedas_500", "pase_temporada"]},
	"estrategia": {"banner_menu": False, "banner_game": False, "inter_every": 3, "inter_cooldown": 180, "inter_max": 3, "app_open": False,
		"rewarded": ["finish_build", "chest", "energy", "double_reward"], "iap": ["pack_inicio", "pase_temporada", "monedas_3000", "sin_anuncios"]},
	"idle": {"banner_menu": True, "banner_game": True, "inter_every": 3, "inter_cooldown": 180, "inter_max": 4, "app_open": True,
		"rewarded": ["offline_x2", "boost", "double_reward"], "iap": ["pase_temporada", "monedas_3000", "pack_inicio"]},
	"tablero": {"banner_menu": True, "banner_game": True, "inter_every": 1, "inter_cooldown": 120, "inter_max": 5, "app_open": False,
		"rewarded": ["hint", "double_reward"], "iap": ["sin_anuncios"]},
	"casino": {"banner_menu": True, "banner_game": False, "inter_every": 2, "inter_cooldown": 120, "inter_max": 5, "app_open": False,
		"rewarded": ["spins", "double_reward"], "iap": ["monedas_3000", "pack_inicio"]},
	"infantil": {"banner_menu": False, "banner_game": False, "inter_every": 0, "inter_cooldown": 9999, "inter_max": 0, "app_open": False,
		"rewarded": ["double_reward"], "iap": []},
}

NOMBRES = {"hipercasual": "Hipercasual", "puzle": "Puzle", "arcade": "Arcade y acción", "estrategia": "Estrategia y midcore",
	"idle": "Idle y gestión", "tablero": "Tablero y clásicos", "casino": "Casino", "infantil": "Infantil (familias)"}

POR_QUE = {
	"hipercasual": "Partidas de segundos: el dinero viene del volumen de intersticiales y de quien paga por quitarlos.",
	"puzle": "Ritmo tranquilo: el banner no molesta y las pistas o movimientos extra son el anuncio con premio que más se ve.",
	"arcade": "Acción: nada que tape la pantalla mientras juegas; segunda oportunidad y premio doble al acabar.",
	"estrategia": "Sesiones largas y jugadores que gastan: pocos intersticiales, acelerar y cofres con anuncio, y compras.",
	"idle": "Se vuelve muchas veces al día: anuncio al volver, doblar lo ganado y banner en la pantalla de juego.",
	"tablero": "Partidas pausadas: banner fijo, un intersticial al acabar cada partida y quitar anuncios como compra.",
	"casino": "Tiradas gratis con anuncio y paquetes de monedas.",
	"infantil": "Política de familias de Google: sin intersticiales ni banners; solo premios que pide el jugador.",
}

PREMIOS = {"revive": "Continuar tras perder", "double_reward": "Premio doble al acabar", "skip_level": "Saltar un nivel",
	"hint": "Pista", "extra_moves": "Movimientos extra", "chest": "Abrir cofre ya", "finish_build": "Acabar una obra ya",
	"energy": "Energía", "offline_x2": "Doblar lo ganado fuera", "boost": "Turbo un rato", "spins": "Tiradas gratis"}

COMPRAS = {"sin_anuncios": "Sin anuncios (2,99 €)", "pack_inicio": "Pack de inicio: 2000 monedas + sin anuncios (3,99 €)",
	"monedas_500": "500 monedas (0,99 €)", "monedas_3000": "3000 monedas (4,99 €)", "pase_temporada": "Pase premium (3,99 €)"}

KIT_PERFIL = {
	"hipercasual": ["helix", "hole", "hopper", "jumper", "knifehit", "lanes", "slice", "stack", "crowd", "climb", "obby",
		"bowling", "archery", "basket", "hoops", "penalty", "falling", "snake", "moles", "simon", "net"],
	"puzle": ["arrows", "blockjam", "blocks", "bubble", "bus", "chain", "fruitmerge", "hexa", "hidden", "jigsaw", "mahjong",
		"match3", "maze", "memory", "merge", "merge2048", "mergeboard", "nonogram", "paintnum", "parking", "pipes", "screw",
		"slide", "sokoban", "sort", "spotdiff", "sudoku", "triple", "letters", "words", "wordle", "hangman", "quiz", "mine",
		"mines", "gemrpg", "stealth", "cook", "tale"],
	"arcade": ["artillery", "bomber", "breakout", "chomp", "custom", "drive", "golf", "horror", "kart", "pinball", "platformer",
		"race", "rhythm", "rogue", "shooter", "sling", "soccer", "tennis", "fighter", "metroid", "horde", "zombie", "royale",
		"brawl", "pool", "fishing", "voxel", "sandbox"],
	"estrategia": ["autochess", "ccg", "clash", "crawl", "dungeon", "empire", "powertower", "realm", "survival", "tactics",
		"tower", "turns", "village", "lawn"],
	"idle": ["idle", "tycoon", "farm", "city", "market"],
	"tablero": ["cards", "checkers", "chess", "connect", "crazy8", "deck", "domino", "klondike", "ludo", "reversi", "battle"],
	"casino": ["slots"],
}


def perfil(kit: str, infantil: bool = False, propio: str = "") -> str:
	if infantil:
		return "infantil"
	if propio in PERFILES:
		return propio
	for p, kits in KIT_PERFIL.items():
		if kit in kits:
			return p
	return "arcade"


def informe(kit: str, infantil: bool = False, propio: str = "") -> dict:
	"""Lo que el autor tiene que saber y hacer para cobrar con este juego."""
	nombre = perfil(kit, infantil, propio)
	d = PERFILES[nombre]
	bloques = ["Intersticial", "Bonificado"] if d["inter_every"] else ["Bonificado"]
	if d["banner_menu"] or d["banner_game"]:
		bloques.append("Banner")
	if d["app_open"]:
		bloques.append("Apertura de app")
	banner = "en menús y partida" if d["banner_game"] and d["banner_menu"] else ("en partida" if d["banner_game"] else ("solo en menús" if d["banner_menu"] else "no"))
	return {
		"perfil": nombre, "nombre": NOMBRES[nombre], "por_que": POR_QUE[nombre],
		"banner": banner,
		"intersticial": ("cada nivel" if d["inter_every"] == 1 else f"cada {d['inter_every']} niveles") + f", como mucho {d['inter_max']} por sesión" if d["inter_every"] else "no",
		"anuncio_al_volver": d["app_open"],
		"premios": [PREMIOS.get(r, r) for r in d["rewarded"]],
		"compras": [COMPRAS.get(c, c) for c in d["iap"]],
		"bloques_admob": bloques,
	}
