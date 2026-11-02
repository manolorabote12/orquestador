class_name Monetize
extends RefCounted
## Monetizacion por tipo de juego. Cada genero tiene un perfil con lo que mejor le funciona:
## banner (en menus y/o en partida), cada cuantos niveles un intersticial (con su espera), que
## anuncios con premio ofrece, si muestra anuncio al volver a la app y que compras destaca.
## 1 - El perfil sale del genero (KIT_PROFILE); los juegos para peques usan siempre "infantil".
## 2 - game.json -> "monetization": {"profile": "puzle", "banner_game": false, ...} cambia el
##     perfil o cualquier valor suelto (lo decide el autor o la fabrica).
## 3 - Ads (anuncios) y Store (compras) leen de aqui; "sin anuncios" apaga banner, intersticial y
##     anuncio de vuelta, nunca los anuncios con premio (los pide el jugador).

const PROFILES: Dictionary = {
	"hipercasual": {"banner_menu": true, "banner_game": false, "inter_every": 1, "inter_cooldown": 45.0, "inter_grace": 45.0,
		"inter_max": 10, "app_open": false, "rewarded": ["revive", "double_reward", "skip_level"], "iap": ["sin_anuncios", "monedas_500"],
		"why": "Partidas de segundos: el dinero viene del volumen de intersticiales y de quitar anuncios."},
	"puzle": {"banner_menu": true, "banner_game": true, "inter_every": 2, "inter_cooldown": 90.0, "inter_grace": 60.0,
		"inter_max": 6, "app_open": false, "rewarded": ["hint", "extra_moves", "double_reward", "skip_level"],
		"iap": ["sin_anuncios", "pack_inicio", "monedas_500", "monedas_3000"],
		"why": "Ritmo tranquilo: el banner no molesta y las pistas o movimientos extra son el anuncio con premio que mas se ve."},
	"arcade": {"banner_menu": true, "banner_game": false, "inter_every": 1, "inter_cooldown": 90.0, "inter_grace": 60.0,
		"inter_max": 6, "app_open": false, "rewarded": ["revive", "double_reward", "chest"],
		"iap": ["sin_anuncios", "monedas_500", "pase_temporada"],
		"why": "Accion: nada que tape la pantalla mientras juegas; segunda oportunidad y premio doble al acabar."},
	"estrategia": {"banner_menu": false, "banner_game": false, "inter_every": 3, "inter_cooldown": 180.0, "inter_grace": 120.0,
		"inter_max": 3, "app_open": false, "rewarded": ["finish_build", "chest", "energy", "double_reward"],
		"iap": ["pack_inicio", "pase_temporada", "monedas_3000", "sin_anuncios"],
		"why": "Jugadores de sesiones largas que gastan: pocos intersticiales, acelerar y cofres con anuncio, y compras."},
	"idle": {"banner_menu": true, "banner_game": true, "inter_every": 3, "inter_cooldown": 180.0, "inter_grace": 120.0,
		"inter_max": 4, "app_open": true, "rewarded": ["offline_x2", "boost", "double_reward"],
		"iap": ["pase_temporada", "monedas_3000", "pack_inicio"],
		"why": "Se vuelve muchas veces al dia: anuncio al volver, doblar lo ganado fuera y banner en la pantalla de juego."},
	"tablero": {"banner_menu": true, "banner_game": true, "inter_every": 1, "inter_cooldown": 120.0, "inter_grace": 60.0,
		"inter_max": 5, "app_open": false, "rewarded": ["hint", "double_reward"], "iap": ["sin_anuncios"],
		"why": "Partidas pausadas: banner fijo, un intersticial al acabar cada partida y quitar anuncios como compra."},
	"casino": {"banner_menu": true, "banner_game": false, "inter_every": 2, "inter_cooldown": 120.0, "inter_grace": 60.0,
		"inter_max": 5, "app_open": false, "rewarded": ["spins", "double_reward"], "iap": ["monedas_3000", "pack_inicio"],
		"why": "Tiradas gratis con anuncio y paquetes de monedas."},
	"infantil": {"banner_menu": false, "banner_game": false, "inter_every": 0, "inter_cooldown": 9999.0, "inter_grace": 9999.0,
		"inter_max": 0, "app_open": false, "rewarded": ["double_reward"], "iap": [],
		"why": "Politica de familias: sin intersticiales ni banners; solo premios que pide el jugador."},
}

const KIT_PROFILE: Dictionary = {
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


## Tipo de juego de un genero (sin contar lo que cambie el juego).
static func profile_of(kit: String) -> String:
	for p: Variant in KIT_PROFILE:
		if (KIT_PROFILE[p] as Array).has(kit):
			return str(p)
	return "arcade"


## Perfil de este juego: el suyo si lo trae, si no el de su genero; "infantil" para peques.
static func profile_name() -> String:
	if bool(Kit.param("ads", {}).get("child_directed", false)) or Kit.kids():
		return "infantil"
	var own: Variant = Kit.param("monetization", {})
	if own is Dictionary and PROFILES.has(str((own as Dictionary).get("profile", ""))):
		return str(own["profile"])
	return profile_of(Genres.current())


## Un valor del perfil (con lo que cambie el juego en game.json -> monetization).
static func p(key: String) -> Variant:
	var base: Dictionary = PROFILES[profile_name()]
	var own: Variant = Kit.param("monetization", {})
	if own is Dictionary and (own as Dictionary).has(key) and profile_name() != "infantil":
		return own[key]
	return base.get(key)


## Este anuncio con premio esta en el perfil? (los genericos de la portada siempre: cofres y premio doble)
static func rewarded_on(placement: String) -> bool:
	return (p("rewarded") as Array).has(placement) or placement in ["double_reward", "chest"]
