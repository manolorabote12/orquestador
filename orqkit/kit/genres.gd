class_name Genres
extends RefCounted
## Registro de generos del kit: UNICO sitio donde se dice que escena, analizador y reglas usa
## cada valor de game.json -> "genre". La fabrica tiene su gemelo en fabrica/generos.py (campo "kit").
## Para anadir uno: python -m nuevo_genero (en la fabrica) crea los archivos y anade su linea aqui.
## Campos:
## 1 - scene: escena de juego.
## 2 - analyzer: script con static analyze(level: Dictionary) -> Dictionary (los generos
##     antiguos usan su firma propia y se resuelven en analyze()).
## 3 - strict: el validador exige que el bot gane a la primera o a la segunda.
## 4 - enemy_art: el genero siempre necesita sprites de enemigo (aunque el mapa no tenga E/K/F).

const LIST: Dictionary = {
	"platformer": {"scene": "res://scenes/main.tscn", "analyzer": "", "strict": false, "enemy_art": false},
	"runner": {"scene": "res://scenes/main.tscn", "analyzer": "", "strict": false, "enemy_art": false},
	"flyer": {"scene": "res://scenes/main.tscn", "analyzer": "", "strict": false, "enemy_art": false},
	"horde": {"scene": "res://scenes/horde.tscn", "analyzer": "", "strict": false, "enemy_art": true},
	"match3": {"scene": "res://scenes/match3.tscn", "analyzer": "", "strict": true, "enemy_art": false},
	"tower": {"scene": "res://scenes/tower.tscn", "analyzer": "", "strict": true, "enemy_art": true},
	"race": {"scene": "res://scenes/race.tscn", "analyzer": "", "strict": true, "enemy_art": false},
	"shooter": {"scene": "res://scenes/shooter.tscn", "analyzer": "res://kit/shooter/shooter_map.gd", "strict": true, "enemy_art": true},
	"breakout": {"scene": "res://scenes/breakout.tscn", "analyzer": "res://kit/breakout/breakout_map.gd", "strict": true, "enemy_art": false},
	"blocks": {"scene": "res://scenes/blocks.tscn", "analyzer": "res://kit/blocks/blocks_map.gd", "strict": true, "enemy_art": false},
	"lanes": {"scene": "res://scenes/lanes.tscn", "analyzer": "res://kit/lanes/lanes_map.gd", "strict": true, "enemy_art": false},
	"snake": {"scene": "res://scenes/snake.tscn", "analyzer": "res://kit/snake/snake_map.gd", "strict": true, "enemy_art": false},
	"memory": {"scene": "res://scenes/memory.tscn", "analyzer": "res://kit/memory/memory_map.gd", "strict": true, "enemy_art": true},
	"sokoban": {"scene": "res://scenes/sokoban.tscn", "analyzer": "res://kit/sokoban/sokoban_map.gd", "strict": true, "enemy_art": false},
	"quiz": {"scene": "res://scenes/quiz.tscn", "analyzer": "res://kit/quiz/quiz_map.gd", "strict": true, "enemy_art": false},
	"stack": {"scene": "res://scenes/stack.tscn", "analyzer": "res://kit/stack/stack_map.gd", "strict": true, "enemy_art": false},
	"moles": {"scene": "res://scenes/moles.tscn", "analyzer": "res://kit/moles/moles_map.gd", "strict": true, "enemy_art": true},
	"jumper": {"scene": "res://scenes/jumper.tscn", "analyzer": "res://kit/jumper/jumper_map.gd", "strict": false, "enemy_art": true},
	"brawl": {"scene": "res://scenes/brawl.tscn", "analyzer": "res://kit/brawl/brawl_map.gd", "strict": true, "enemy_art": true},
	"village": {"scene": "res://scenes/village.tscn", "analyzer": "res://kit/village/village_map.gd", "strict": true, "enemy_art": true},
	"rhythm": {"scene": "res://scenes/rhythm.tscn", "analyzer": "res://kit/rhythm/rhythm_map.gd", "strict": true, "enemy_art": false},
	"idle": {"scene": "res://scenes/idle.tscn", "analyzer": "res://kit/idle/idle_map.gd", "strict": true, "enemy_art": false},
	"cards": {"scene": "res://scenes/cards.tscn", "analyzer": "res://kit/cards/cards_map.gd", "strict": true, "enemy_art": false},
	"turns": {"scene": "res://scenes/turns.tscn", "analyzer": "res://kit/turns/turns_map.gd", "strict": true, "enemy_art": true},
	"maze": {"scene": "res://scenes/maze.tscn", "analyzer": "res://kit/maze/maze_map.gd", "strict": true, "enemy_art": false},
	"golf": {"scene": "res://scenes/golf.tscn", "analyzer": "res://kit/golf/golf_map.gd", "strict": true, "enemy_art": false},
	"fishing": {"scene": "res://scenes/fishing.tscn", "analyzer": "res://kit/fishing/fishing_map.gd", "strict": true, "enemy_art": false},
	"merge": {"scene": "res://scenes/merge.tscn", "analyzer": "res://kit/merge/merge_map.gd", "strict": true, "enemy_art": false},
	"sort": {"scene": "res://scenes/sort.tscn", "analyzer": "res://kit/sort/sort_map.gd", "strict": true, "enemy_art": false},
	"bubble": {"scene": "res://scenes/bubble.tscn", "analyzer": "res://kit/bubble/bubble_map.gd", "strict": true, "enemy_art": false},
	"empire": {"scene": "res://scenes/empire.tscn", "analyzer": "res://kit/empire/empire_map.gd", "strict": true, "enemy_art": false},
	"mine": {"scene": "res://scenes/mine.tscn", "analyzer": "res://kit/mine/mine_map.gd", "strict": true, "enemy_art": false},
	"dungeon": {"scene": "res://scenes/dungeon.tscn", "analyzer": "res://kit/dungeon/dungeon_map.gd", "strict": true, "enemy_art": false},
	"farm": {"scene": "res://scenes/farm.tscn", "analyzer": "res://kit/farm/farm_map.gd", "strict": true, "enemy_art": false},
	"deck": {"scene": "res://scenes/deck.tscn", "analyzer": "res://kit/deck/deck_map.gd", "strict": true, "enemy_art": false},
	"tale": {"scene": "res://scenes/tale.tscn", "analyzer": "res://kit/tale/tale_map.gd", "strict": true, "enemy_art": false},
	"cook": {"scene": "res://scenes/cook.tscn", "analyzer": "res://kit/cook/cook_map.gd", "strict": true, "enemy_art": false},
	"mahjong": {"scene": "res://scenes/mahjong.tscn", "analyzer": "res://kit/mahjong/mahjong_map.gd", "strict": true, "enemy_art": false},
	"parking": {"scene": "res://scenes/parking.tscn", "analyzer": "res://kit/parking/parking_map.gd", "strict": true, "enemy_art": false},
	"words": {"scene": "res://scenes/words.tscn", "analyzer": "res://kit/words/words_map.gd", "strict": true, "enemy_art": false},
	"sudoku": {"scene": "res://scenes/sudoku.tscn", "analyzer": "res://kit/sudoku/sudoku_map.gd", "strict": true, "enemy_art": false},
	"nonogram": {"scene": "res://scenes/nonogram.tscn", "analyzer": "res://kit/nonogram/nonogram_map.gd", "strict": true, "enemy_art": false},
	"slice": {"scene": "res://scenes/slice.tscn", "analyzer": "res://kit/slice/slice_map.gd", "strict": true, "enemy_art": false},
	"penalty": {"scene": "res://scenes/penalty.tscn", "analyzer": "res://kit/penalty/penalty_map.gd", "strict": true, "enemy_art": false},
	"hole": {"scene": "res://scenes/hole.tscn", "analyzer": "res://kit/hole/hole_map.gd", "strict": true, "enemy_art": false},
	"city": {"scene": "res://scenes/city.tscn", "analyzer": "res://kit/city/city_map.gd", "strict": true, "enemy_art": false},
	"hoops": {"scene": "res://scenes/hoops.tscn", "analyzer": "res://kit/hoops/hoops_map.gd", "strict": true, "enemy_art": false},
	"helix": {"scene": "res://scenes/helix.tscn", "analyzer": "res://kit/helix/helix_map.gd", "strict": true, "enemy_art": false},
	"mines": {"scene": "res://scenes/mines.tscn", "analyzer": "res://kit/mines/mines_map.gd", "strict": true, "enemy_art": false},
	"connect": {"scene": "res://scenes/connect.tscn", "analyzer": "res://kit/connect/connect_map.gd", "strict": true, "enemy_art": false},
	"checkers": {"scene": "res://scenes/checkers.tscn", "analyzer": "res://kit/checkers/checkers_map.gd", "strict": true, "enemy_art": false},
	"pool": {"scene": "res://scenes/pool.tscn", "analyzer": "res://kit/pool/pool_map.gd", "strict": true, "enemy_art": false},
	"klondike": {"scene": "res://scenes/klondike.tscn", "analyzer": "res://kit/klondike/klondike_map.gd", "strict": true, "enemy_art": false},
	"ludo": {"scene": "res://scenes/ludo.tscn", "analyzer": "res://kit/ludo/ludo_map.gd", "strict": true, "enemy_art": false},
	"falling": {"scene": "res://scenes/falling.tscn", "analyzer": "res://kit/falling/falling_map.gd", "strict": true, "enemy_art": false},
	"bowling": {"scene": "res://scenes/bowling.tscn", "analyzer": "res://kit/bowling/bowling_map.gd", "strict": true, "enemy_art": false},
	"sandbox": {"scene": "res://scenes/sandbox.tscn", "analyzer": "res://kit/sandbox/sandbox_map.gd", "strict": true, "enemy_art": false},
	"royale": {"scene": "res://scenes/royale.tscn", "analyzer": "res://kit/royale/royale_map.gd", "strict": true, "enemy_art": false},
	"hopper": {"scene": "res://scenes/hopper.tscn", "analyzer": "res://kit/hopper/hopper_map.gd", "strict": true, "enemy_art": false},
	"archery": {"scene": "res://scenes/archery.tscn", "analyzer": "res://kit/archery/archery_map.gd", "strict": true, "enemy_art": false},
	"voxel": {"scene": "res://scenes/voxel.tscn", "analyzer": "res://kit/voxel/voxel_map.gd", "strict": true, "enemy_art": false},
	"obby": {"scene": "res://scenes/obby.tscn", "analyzer": "res://kit/obby/obby_map.gd", "strict": true, "enemy_art": false},
	"market": {"scene": "res://scenes/market.tscn", "analyzer": "res://kit/market/market_map.gd", "strict": true, "enemy_art": false},
	"soccer": {"scene": "res://scenes/soccer.tscn", "analyzer": "res://kit/soccer/soccer_map.gd", "strict": true, "enemy_art": false},
	"horror": {"scene": "res://scenes/horror.tscn", "analyzer": "res://kit/horror/horror_map.gd", "strict": true, "enemy_art": false},
	"drive": {"scene": "res://scenes/drive.tscn", "analyzer": "res://kit/drive/drive_map.gd", "strict": true, "enemy_art": false},
	"zombie": {"scene": "res://scenes/zombie.tscn", "analyzer": "res://kit/zombie/zombie_map.gd", "strict": true, "enemy_art": false},
	"basket": {"scene": "res://scenes/basket.tscn", "analyzer": "res://kit/basket/basket_map.gd", "strict": true, "enemy_art": false},
	"tennis": {"scene": "res://scenes/tennis.tscn", "analyzer": "res://kit/tennis/tennis_map.gd", "strict": true, "enemy_art": false},
	"kart": {"scene": "res://scenes/kart.tscn", "analyzer": "res://kit/kart/kart_map.gd", "strict": true, "enemy_art": false},
	"survival": {"scene": "res://scenes/survival.tscn", "analyzer": "res://kit/survival/survival_map.gd", "strict": true, "enemy_art": true},
	"triple": {"scene": "res://scenes/triple.tscn", "analyzer": "res://kit/triple/triple_map.gd", "strict": true, "enemy_art": false},
	"screw": {"scene": "res://scenes/screw.tscn", "analyzer": "res://kit/screw/screw_map.gd", "strict": true, "enemy_art": false},
	"hexa": {"scene": "res://scenes/hexa.tscn", "analyzer": "res://kit/hexa/hexa_map.gd", "strict": true, "enemy_art": false},
	"bus": {"scene": "res://scenes/bus.tscn", "analyzer": "res://kit/bus/bus_map.gd", "strict": true, "enemy_art": false},
	"clash": {"scene": "res://scenes/clash.tscn", "analyzer": "res://kit/clash/clash_map.gd", "strict": true, "enemy_art": false},
	"climb": {"scene": "res://scenes/climb.tscn", "analyzer": "res://kit/climb/climb_map.gd", "strict": true, "enemy_art": false},
	"sling": {"scene": "res://scenes/sling.tscn", "analyzer": "res://kit/sling/sling_map.gd", "strict": true, "enemy_art": false},
	"lawn": {"scene": "res://scenes/lawn.tscn", "analyzer": "res://kit/lawn/lawn_map.gd", "strict": true, "enemy_art": false},
	"wordle": {"scene": "res://scenes/wordle.tscn", "analyzer": "res://kit/wordle/wordle_map.gd", "strict": true, "enemy_art": false},
	"letters": {"scene": "res://scenes/letters.tscn", "analyzer": "res://kit/letters/letters_map.gd", "strict": true, "enemy_art": false},
	"tycoon": {"scene": "res://scenes/tycoon.tscn", "analyzer": "res://kit/tycoon/tycoon_map.gd", "strict": true, "enemy_art": false},
	"slots": {"scene": "res://scenes/slots.tscn", "analyzer": "res://kit/slots/slots_map.gd", "strict": true, "enemy_art": false},
	"realm": {"scene": "res://scenes/realm.tscn", "analyzer": "res://kit/realm/realm_map.gd", "strict": true, "enemy_art": false},
	"crowd": {"scene": "res://scenes/crowd.tscn", "analyzer": "res://kit/crowd/crowd_map.gd", "strict": true, "enemy_art": false},
	"mergeboard": {"scene": "res://scenes/mergeboard.tscn", "analyzer": "res://kit/mergeboard/mergeboard_map.gd", "strict": true, "enemy_art": false},
	"custom": {"scene": "res://scenes/custom.tscn", "analyzer": "res://kit/custom/custom_map.gd", "strict": true, "enemy_art": false},
	"powertower": {"scene": "res://scenes/powertower.tscn", "analyzer": "res://kit/powertower/powertower_map.gd", "strict": true, "enemy_art": false},
	"spotdiff": {"scene": "res://scenes/spotdiff.tscn", "analyzer": "res://kit/spotdiff/spotdiff_map.gd", "strict": true, "enemy_art": false},
	"jigsaw": {"scene": "res://scenes/jigsaw.tscn", "analyzer": "res://kit/jigsaw/jigsaw_map.gd", "strict": true, "enemy_art": false},
	"paintnum": {"scene": "res://scenes/paintnum.tscn", "analyzer": "res://kit/paintnum/paintnum_map.gd", "strict": true, "enemy_art": false},
	"knifehit": {"scene": "res://scenes/knifehit.tscn", "analyzer": "res://kit/knifehit/knifehit_map.gd", "strict": true, "enemy_art": false},
	"rogue": {"scene": "res://scenes/rogue.tscn", "analyzer": "res://kit/rogue/rogue_map.gd", "strict": true, "enemy_art": false},
	"arrows": {"scene": "res://scenes/arrows.tscn", "analyzer": "res://kit/arrows/arrows_map.gd", "strict": true, "enemy_art": false},
	"merge2048": {"scene": "res://scenes/merge2048.tscn", "analyzer": "res://kit/merge2048/merge2048_map.gd", "strict": true, "enemy_art": false},
	"crazy8": {"scene": "res://scenes/crazy8.tscn", "analyzer": "res://kit/crazy8/crazy8_map.gd", "strict": true, "enemy_art": false},
	"domino": {"scene": "res://scenes/domino.tscn", "analyzer": "res://kit/domino/domino_map.gd", "strict": true, "enemy_art": false},
	"blockjam": {"scene": "res://scenes/blockjam.tscn", "analyzer": "res://kit/blockjam/blockjam_map.gd", "strict": true, "enemy_art": false},
	"pipes": {"scene": "res://scenes/pipes.tscn", "analyzer": "res://kit/pipes/pipes_map.gd", "strict": true, "enemy_art": false},
	"chess": {"scene": "res://scenes/chess.tscn", "analyzer": "res://kit/chess/chess_map.gd", "strict": true, "enemy_art": false},
	"reversi": {"scene": "res://scenes/reversi.tscn", "analyzer": "res://kit/reversi/reversi_map.gd", "strict": true, "enemy_art": false},
	"hidden": {"scene": "res://scenes/hidden.tscn", "analyzer": "res://kit/hidden/hidden_map.gd", "strict": true, "enemy_art": false},
	"slide": {"scene": "res://scenes/slide.tscn", "analyzer": "res://kit/slide/slide_map.gd", "strict": true, "enemy_art": false},
	"hangman": {"scene": "res://scenes/hangman.tscn", "analyzer": "res://kit/hangman/hangman_map.gd", "strict": true, "enemy_art": false},
	"battle": {"scene": "res://scenes/battle.tscn", "analyzer": "res://kit/battle/battle_map.gd", "strict": true, "enemy_art": false},
	"simon": {"scene": "res://scenes/simon.tscn", "analyzer": "res://kit/simon/simon_map.gd", "strict": true, "enemy_art": false},
	"tactics": {"scene": "res://scenes/tactics.tscn", "analyzer": "res://kit/tactics/tactics_map.gd", "strict": true, "enemy_art": false},
	"autochess": {"scene": "res://scenes/autochess.tscn", "analyzer": "res://kit/autochess/autochess_map.gd", "strict": true, "enemy_art": false},
	"gemrpg": {"scene": "res://scenes/gemrpg.tscn", "analyzer": "res://kit/gemrpg/gemrpg_map.gd", "strict": true, "enemy_art": false},
	"ccg": {"scene": "res://scenes/ccg.tscn", "analyzer": "res://kit/ccg/ccg_map.gd", "strict": true, "enemy_art": false},
	"crawl": {"scene": "res://scenes/crawl.tscn", "analyzer": "res://kit/crawl/crawl_map.gd", "strict": true, "enemy_art": false},
	"bomber": {"scene": "res://scenes/bomber.tscn", "analyzer": "res://kit/bomber/bomber_map.gd", "strict": true, "enemy_art": false},
	"artillery": {"scene": "res://scenes/artillery.tscn", "analyzer": "res://kit/artillery/artillery_map.gd", "strict": true, "enemy_art": false},
	"chomp": {"scene": "res://scenes/chomp.tscn", "analyzer": "res://kit/chomp/chomp_map.gd", "strict": true, "enemy_art": false},
	"chain": {"scene": "res://scenes/chain.tscn", "analyzer": "res://kit/chain/chain_map.gd", "strict": true, "enemy_art": false},
	"fighter": {"scene": "res://scenes/fighter.tscn", "analyzer": "res://kit/fighter/fighter_map.gd", "strict": true, "enemy_art": true},
	"fruitmerge": {"scene": "res://scenes/fruitmerge.tscn", "analyzer": "res://kit/fruitmerge/fruitmerge_map.gd", "strict": true, "enemy_art": false},
	"pinball": {"scene": "res://scenes/pinball.tscn", "analyzer": "res://kit/pinball/pinball_map.gd", "strict": true, "enemy_art": false},
	"metroid": {"scene": "res://scenes/metroid.tscn", "analyzer": "res://kit/metroid/metroid_map.gd", "strict": true, "enemy_art": true},
	"stealth": {"scene": "res://scenes/stealth.tscn", "analyzer": "res://kit/stealth/stealth_map.gd", "strict": true, "enemy_art": true},
	## NUEVOS GENEROS (nuevo_genero.py escribe encima de esta linea)
}


static func current() -> String:
	return str(Kit.param("genre", "platformer"))


static func info(genre: String) -> Dictionary:
	return LIST.get(genre, LIST["platformer"])


static func scene(genre: String) -> String:
	return str(info(genre)["scene"])


static func strict(genre: String) -> bool:
	return bool(info(genre)["strict"])


static func enemy_art(genre: String) -> bool:
	return bool(info(genre)["enemy_art"])


## 5 - Analisis sin jugar de un nivel. Devuelve completable, issues, coins_total, enemies...
static func analyze(genre: String, level: Dictionary, tile: float, params: Dictionary) -> Dictionary:
	var lmap: Array = level.get("map", [])
	match genre:
		"horde":
			return HordeArena.analyze(lmap)
		"match3":
			return Match3Logic.analyze(lmap)
		"tower":
			return TowerMap.analyze(lmap)
		"race":
			return RaceTrack.analyze(level)
	var path: String = str(info(genre).get("analyzer", ""))
	if path != "" and LIST.has(genre):
		var s: GDScript = load(path)
		return s.call("analyze", level)
	return LevelAnalyzer.analyze(lmap, tile, params)
