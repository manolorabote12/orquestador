class_name HowTo
extends RefCounted
## "Como se juega" de los generos mas complejos: tres reglas cortas.
## 1 - Sale sola la primera vez que juegas ese genero (cuando no hay dialogo de historia delante).
## 2 - Despues, en el menu de pausa: "Como se juega".
## 3 - Textos: claves howto_<kit>_<n> (traducidas en el catalogo de la fabrica).

## Las pruebas del kit lo apagan (los juegos no deben quedarse en pausa por la ventana).
static var enabled: bool = true

const RULES: Dictionary = {
	"tactics": ["Toca una unidad tuya: en azul, ad\u00f3nde puede ir; en rojo, a qui\u00e9n puede atacar.", "Toca un rival para ver su zona de peligro; antes de atacar ver\u00e1s el da\u00f1o y el contraataque.", "Ganas capturando su cuartel con infanter\u00eda o acabando con sus unidades."],
	"empire": ["Toca un recurso arriba para mandar un aldeano m\u00e1s a ese trabajo.", "En Construir levanta casas, granjas y cuarteles; luego sube de edad.", "Lancero gana a jinete, jinete a arquero y arquero a lancero. \u00abAtacar\u00bb manda a tu ej\u00e9rcito."],
	"realm": ["Sube los edificios: dan recursos y entrenan tropas solos.", "Abajo ver\u00e1s si ganar\u00edas al siguiente campamento y cu\u00e1ntas tropas perder\u00edas.", "Conquista los campamentos uno a uno hasta vencer al jefe."],
	"village": ["Elige una tropa abajo y toca fuera de la base para soltarla.", "Las tropas van solas al edificio m\u00e1s cercano y rompen los muros que les cortan el paso.", "Con el 50 % destruido ganas una estrella; el ayuntamiento y el 100 % dan las otras."],
	"ccg": ["Cada turno tienes m\u00e1s man\u00e1: juega cartas de tu mano toc\u00e1ndolas.", "Tus esbirros atacan desde el turno siguiente; a los de Provocar hay que atacarles antes.", "Deja al h\u00e9roe rival a 0. En la portada, \u00abMazo\u00bb te deja montar el tuyo."],
	"autochess": ["Compra unidades en la tienda y col\u00f3calas en tu mitad del tablero.", "Tres iguales se funden en una m\u00e1s fuerte; dos del mismo tipo dan sinergia.", "Pulsa Luchar y pelean solas. Pierdes una vida por cada ronda perdida."],
	"fighter": ["Mu\u00e9vete con las flechas; pu\u00f1etazo (r\u00e1pido), patada (larga) y cubrirse.", "Si un golpe conecta, pulsa enseguida uno m\u00e1s fuerte: \u00a1combo!", "Gana dos asaltos. Con media barra, el especial lanza una bola de energ\u00eda."],
	"metroid": ["Explora las salas: el doble salto, el impulso y el martillo abren caminos nuevos.", "Las llaves abren puertas y el martillo rompe los bloques agrietados.", "El bot\u00f3n de mapa ense\u00f1a lo visitado. Llega a la meta."],
	"crawl": ["Toca una casilla para andar hasta ella; chocar con un monstruo es atacarle.", "\u00abExplorar\u00bb anda solo hasta que aparece un monstruo.", "Recoge armas, armaduras y pociones y baja por la escalera."],
	"dungeon": ["Arrastra para moverte; al soltar, tu h\u00e9roe dispara solo.", "Al subir de nivel eliges una habilidad; los cofres dan equipo.", "Limpia las salas y vence al jefe de la planta."],
	"tower": ["Toca una casilla libre y elige torre: rayo, ca\u00f1\u00f3n o hielo.", "Toca una torre para mejorarla, venderla o elegir a qui\u00e9n dispara.", "Lanza la oleada cuando est\u00e9s listo: que no lleguen a tu base."],
	"survival": ["Arrastra para moverte y pulsa Usar junto a \u00e1rboles, rocas, arbustos o agua.", "Fabrica hacha, lanza y hoguera con los botones de abajo.", "De noche qu\u00e9date junto al fuego: los lobos no se acercan a la luz."],
	"clash": ["Arrastra una carta de tu mano a tu mitad de la arena; cuesta elixir.", "Las tropas van solas por su carril a por las torres rivales.", "Tira la torre del rey o ten m\u00e1s coronas al acabar el tiempo."],
	"stealth": ["Toca un punto unido al tuyo para moverte; los guardias se mueven despu\u00e9s de ti.", "No acabes en una casilla vigilada (en rojo); por detr\u00e1s o de lado, los eliminas.", "Llega a la salida; con el malet\u00edn ganas m\u00e1s estrellas. Puedes deshacer."],
	"turns": ["En tu turno: Atacar, Especial (a todos), Poci\u00f3n o Defender.", "Defender reduce el da\u00f1o y te da energ\u00eda para el Especial.", "Cuando el jefe avise de un golpe fuerte, defi\u00e9ndete."],
	"tycoon": ["Compra negocios y s\u00fabelos de nivel para ganar m\u00e1s dinero.", "Contrata gerentes: trabajan solos aunque no est\u00e9s.", "Junta el dinero de la meta para pasar de nivel."],
	"deck": ["Toca una carta de la mano para jugarla si te llega la energ\u00eda; \u00abTerminar turno\u00bb pasa al enemigo.", "Encima del enemigo ves qu\u00e9 har\u00e1: espada = ataca, escudo = se protege, calavera = veneno.", "Tras cada combate eliges una carta nueva para tu mazo. Gana todos los combates."],
	"city": ["Elige abajo qu\u00e9 construir y toca un solar: todo debe tocar una carretera unida al ayuntamiento.", "Casas dan habitantes; tiendas y f\u00e1bricas, trabajo; parques, felicidad. Las f\u00e1bricas molestan a las casas de al lado.", "Las casas felices suben a pisos. Llega a la meta de habitantes antes de que acabe el tiempo."],
	"farm": ["Elige una semilla abajo y toca parcelas vac\u00edas para sembrar; toca las maduras para cosechar.", "Toca los corrales para recoger y dar pienso, y las m\u00e1quinas para fabricar con sus recetas.", "Entrega los pedidos del tabl\u00f3n cuando tengas todo: as\u00ed se gana el nivel."],
	"gemrpg": ["Cambia dos gemas vecinas para hacer l\u00edneas de 3 o m\u00e1s.", "Cada color hace atacar a tu h\u00e9roe de ese color; los corazones curan.", "Cuando un h\u00e9roe brilla, toca su retrato para su especial. Ojo con la cuenta atr\u00e1s de los monstruos."],
	"powertower": ["Toca las salas en buen orden: solo vences a quien tiene menos poder que t\u00fa.", "Cada victoria y cada premio suman a tu poder; esquiva las trampas.", "Llega con poder suficiente al jefe de arriba."],
}


static func has(kit: String) -> bool:
	return RULES.has(kit)


static func lines(kit: String) -> Array[String]:
	var out: Array[String] = []
	var base: Array = RULES.get(kit, [])
	for i: int in base.size():
		out.append(Kit.text("howto_%s_%d" % [kit, i + 1], str(base[i])))
	return out


static func seen(kit: String) -> bool:
	return bool(Save.get_setting("howto_" + kit, false))


## La primera vez de cada genero: espera a que no haya nada en pausa delante (historia) y la abre.
static func maybe_show(game: Node) -> void:
	var kit: String = Genres.current()
	if not enabled or not has(kit) or seen(kit) or UI.test_mode or QA.enabled or Kit.is_extra():
		return
	Save.set_setting("howto_" + kit, true)
	for i: int in 60:
		if not is_instance_valid(game) or not game.is_inside_tree():
			return
		if not game.get_tree().paused:
			break
		await game.get_tree().create_timer(0.3, true, false, true).timeout
	if is_instance_valid(game) and game.is_inside_tree() and not game.get_tree().paused:
		HowToPanel.open(game)
