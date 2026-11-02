"""Historias de reserva para el genero aventura (directora simulada y respaldo si la IA falla).

Capitulos ramificados con valor, amistad, oro y objetos, escritos para cualquier tema: los nombres
y el lugar se rellenan con lo de la idea. Todos cumplen las reglas del analizador
(kit/tale/tale_map.gd): ids unicos, destinos validos, sin callejones y final bueno alcanzable
empezando a cero.
"""

_CAPITULOS = [
	{
		"titulo": "El robo de {tesoro}",
		"escenas": [
			{"id": "a", "quien": "narrador", "texto": "{lugar} amanece en calma... hasta que corre la voz: alguien ha robado {tesoro}. {heroe} sabe que nadie más se atreverá a buscarlo.",
				"opciones": [{"texto": "Seguir las huellas", "va_a": "b", "efecto": {"valor": 1}},
					{"texto": "Vender tu vieja capa y preguntar en el mercado", "va_a": "c", "efecto": {"oro": 6}}]},
			{"id": "b", "quien": "heroe", "texto": "Las huellas se pierden en el bosque. Entre las raíces, un zorrito atrapado gime asustado.",
				"opciones": [{"texto": "Liberarlo con cuidado", "va_a": "d", "efecto": {"amistad": 2}},
					{"texto": "No hay tiempo: seguir adelante", "va_a": "e", "efecto": {"valor": 1}}]},
			{"id": "c", "quien": "aliado", "texto": "Una vendedora susurra: «Vi a {rival} con un saco que brillaba. Tengo un mapa del camino secreto... por 5 monedas».",
				"opciones": [{"texto": "Comprar el mapa", "va_a": "f", "efecto": {"oro": -5, "objeto": "mapa"}, "requiere": {"stat": "oro", "min": 5}},
					{"texto": "Darle las gracias e ir al bosque", "va_a": "b", "efecto": {"amistad": 1}}]},
			{"id": "d", "quien": "narrador", "texto": "El zorrito te sigue. Al rato tira de tu manga hacia un sendero escondido que tú nunca habrías visto.",
				"opciones": [{"texto": "Seguir al zorrito", "va_a": "f", "efecto": {"objeto": "amigo zorro"}}]},
			{"id": "e", "quien": "rival", "texto": "{rival} aparece entre la niebla: «Vaya, vaya... el héroe de {lugar}. Vuelve a casa antes de que te hagas daño».",
				"opciones": [{"texto": "Plantarle cara", "va_a": "g", "efecto": {"valor": 1}, "requiere": {"stat": "valor", "min": 2}},
					{"texto": "Retirarte y buscar otro camino", "va_a": "b"}]},
			{"id": "f", "quien": "narrador", "texto": "El camino secreto lleva a la guarida de {rival}. {tesoro} está ahí, sobre una mesa, sin vigilancia.",
				"opciones": [{"texto": "Recuperarlo en silencio", "va_a": "FIN_BUENO", "efecto": {"amistad": 1}},
					{"texto": "Esperar a {rival} para darle una lección", "va_a": "g", "efecto": {"valor": 1}}]},
			{"id": "g", "quien": "rival", "texto": "«Está bien, está bien... Te lo devuelvo. Pero esto no ha acabado».",
				"opciones": [{"texto": "Ofrecerle tu mano", "va_a": "FIN_BUENO", "efecto": {"amistad": 1}, "requiere": {"stat": "amistad", "min": 2}},
					{"texto": "Quitárselo de un tirón", "va_a": "FIN_REGULAR", "efecto": {"valor": 1}},
					{"texto": "Dejarle escapar con él", "va_a": "FIN_MALO"}]},
		],
		"finales": {"bueno": "{tesoro} vuelve a {lugar} y todo el mundo celebra. Algunos dicen que hasta {rival} sonrió un poco.",
			"regular": "Recuperas {tesoro}, pero {rival} jura venganza. Habrá que estar atentos.",
			"malo": "{rival} escapa con {tesoro}. {lugar} queda triste... pero {heroe} no se rinde."},
	},
	{
		"titulo": "El puente roto",
		"escenas": [
			{"id": "a", "quien": "narrador", "texto": "El único puente hacia las montañas se ha derrumbado. Al otro lado está la pista que busca {heroe}.",
				"opciones": [{"texto": "Buscar madera para repararlo", "va_a": "b", "efecto": {"valor": 1}},
					{"texto": "Pedir ayuda en la aldea", "va_a": "c", "efecto": {"amistad": 1}}]},
			{"id": "b", "quien": "heroe", "texto": "Cerca hay un leñador que no quiere vender ni una tabla... a menos que alguien le ayude con su carro atascado.",
				"opciones": [{"texto": "Empujar el carro con todas tus fuerzas", "va_a": "d", "efecto": {"valor": 1, "objeto": "tablas"}},
					{"texto": "Pagarle con lo que tengas", "va_a": "d", "efecto": {"oro": -3, "objeto": "tablas"}, "requiere": {"stat": "oro", "min": 3}}]},
			{"id": "c", "quien": "aliado", "texto": "{aliado} se ofrece a ayudar: «Si reunimos a todos, el puente estará listo al atardecer».",
				"opciones": [{"texto": "Organizar a la aldea", "va_a": "e", "efecto": {"amistad": 2}},
					{"texto": "Mejor ir por tu cuenta", "va_a": "b"}]},
			{"id": "d", "quien": "narrador", "texto": "Con las tablas al hombro llegas al barranco. El viento sopla fuerte y el abismo da vértigo.",
				"opciones": [{"texto": "Construir el puente tú solo", "va_a": "f", "efecto": {"valor": 1}, "requiere": {"objeto": "tablas"}},
					{"texto": "Volver a la aldea a por ayuda", "va_a": "c"}]},
			{"id": "e", "quien": "narrador", "texto": "Media aldea trabaja codo con codo. Al caer la tarde, un puente nuevo cruza el barranco.",
				"opciones": [{"texto": "Cruzar el primero", "va_a": "g", "efecto": {"valor": 1}}]},
			{"id": "f", "quien": "heroe", "texto": "El puente cruje... pero aguanta. Al otro lado, unas pisadas recientes van hacia la cueva.",
				"opciones": [{"texto": "Entrar en la cueva", "va_a": "g"}, {"texto": "Esperar a que amanezca", "va_a": "FIN_REGULAR"}]},
			{"id": "g", "quien": "rival", "texto": "{rival} sale de la cueva sorprendido: «¿Cómo habéis cruzado? ¡Ese puente era mi defensa!».",
				"opciones": [{"texto": "Convencerle de que se rinda", "va_a": "FIN_BUENO", "requiere": {"stat": "amistad", "min": 2}},
					{"texto": "Perseguirle hasta el fondo", "va_a": "FIN_BUENO", "requiere": {"stat": "valor", "min": 3}},
					{"texto": "Dejarle huir", "va_a": "FIN_MALO"}]},
		],
		"finales": {"bueno": "El puente une de nuevo la aldea con las montañas y {rival} tiene un plan menos. Gran día.",
			"regular": "Esperas demasiado: la cueva está vacía por la mañana. Al menos el puente queda en pie.",
			"malo": "{rival} se esfuma entre las rocas. Habrá que empezar de nuevo."},
	},
	{
		"titulo": "La torre de {rival}",
		"escenas": [
			{"id": "a", "quien": "narrador", "texto": "Por fin: la torre de {rival}. Dos guardias vigilan la puerta y una ventana alta queda abierta.",
				"opciones": [{"texto": "Trepar hasta la ventana", "va_a": "b", "efecto": {"valor": 1}},
					{"texto": "Distraer a los guardias con monedas", "va_a": "c", "efecto": {"oro": -2}, "requiere": {"stat": "oro", "min": 2}},
					{"texto": "Rodear la torre buscando otra entrada", "va_a": "d"}]},
			{"id": "b", "quien": "heroe", "texto": "Las piedras resbalan. A mitad de camino, una lechuza te mira fijamente.",
				"opciones": [{"texto": "Seguir subiendo sin mirar abajo", "va_a": "e", "efecto": {"valor": 1}},
					{"texto": "Hablarle a la lechuza", "va_a": "e", "efecto": {"amistad": 1, "objeto": "pluma mágica"}}]},
			{"id": "c", "quien": "narrador", "texto": "Los guardias corren tras las monedas y la puerta queda libre.",
				"opciones": [{"texto": "Entrar", "va_a": "e"}]},
			{"id": "d", "quien": "aliado", "texto": "Detrás de la torre encuentras a {aliado}: «Conozco un pasadizo, pero necesito que confíes en mí».",
				"opciones": [{"texto": "Confiar", "va_a": "e", "efecto": {"amistad": 2}},
					{"texto": "Desconfiar y volver a la entrada", "va_a": "a"}]},
			{"id": "e", "quien": "rival", "texto": "{rival} te espera en lo alto: «Has llegado lejos, pero de aquí no pasas».",
				"opciones": [{"texto": "Luchar con todo tu valor", "va_a": "FIN_BUENO", "requiere": {"stat": "valor", "min": 2}},
					{"texto": "Llamar a tus amigos", "va_a": "FIN_BUENO", "requiere": {"stat": "amistad", "min": 2}},
					{"texto": "Intentarlo sin un plan", "va_a": "f"}]},
			{"id": "f", "quien": "narrador", "texto": "La pelea está igualada. {rival} sonríe: le queda un truco...",
				"opciones": [{"texto": "Aguantar hasta el final", "va_a": "FIN_REGULAR", "efecto": {"valor": 1}},
					{"texto": "Huir por la ventana", "va_a": "FIN_MALO"}]},
		],
		"finales": {"bueno": "{rival} cae derrotado y {lugar} vuelve a ser libre. Todo el mundo canta el nombre de {heroe}.",
			"regular": "Ganas por los pelos, pero {rival} escapa malherido. La paz durará... un tiempo.",
			"malo": "Escapas por los pelos. {rival} sigue en su torre, más fuerte que nunca."},
	},
	{
		"titulo": "La gran fiesta",
		"escenas": [
			{"id": "a", "quien": "narrador", "texto": "{lugar} prepara la gran fiesta. Pero el cocinero está enfermo y faltan ingredientes.",
				"opciones": [{"texto": "Ir a buscar los ingredientes", "va_a": "b", "efecto": {"valor": 1}},
					{"texto": "Cocinar tú mismo", "va_a": "c", "efecto": {"amistad": 1}}]},
			{"id": "b", "quien": "aliado", "texto": "{aliado} sabe dónde crecen las setas doradas... en el claro de los lobos.",
				"opciones": [{"texto": "Ir al claro", "va_a": "d", "efecto": {"valor": 1}},
					{"texto": "Comprar setas normales en el mercado", "va_a": "c", "efecto": {"oro": -2}, "requiere": {"stat": "oro", "min": 2}},
					{"texto": "Volver y ayudar en la cocina", "va_a": "c"}]},
			{"id": "c", "quien": "heroe", "texto": "La cocina es un caos de ollas y harina. Huele... raro.",
				"opciones": [{"texto": "Pedir ayuda a todo el mundo", "va_a": "e", "efecto": {"amistad": 2}},
					{"texto": "Seguir tu instinto", "va_a": "e"}]},
			{"id": "d", "quien": "narrador", "texto": "En el claro, los lobos duermen. Las setas doradas brillan a su lado.",
				"opciones": [{"texto": "Cogerlas sin hacer ruido", "va_a": "e", "efecto": {"objeto": "setas doradas"}},
					{"texto": "Despertar a los lobos sin querer", "va_a": "e", "efecto": {"valor": 1}}]},
			{"id": "e", "quien": "narrador", "texto": "Llega la noche de la fiesta. Todos esperan el banquete... y {rival} se cuela entre los invitados.",
				"opciones": [{"texto": "Servir el plato estrella", "va_a": "FIN_BUENO", "requiere": {"objeto": "setas doradas"}},
					{"texto": "Invitar a {rival} a la mesa", "va_a": "FIN_BUENO", "requiere": {"stat": "amistad", "min": 2}},
					{"texto": "Servir lo que hay", "va_a": "FIN_REGULAR"}]},
		],
		"finales": {"bueno": "El banquete es legendario. Hasta {rival} pide repetir... y quizá haga las paces.",
			"regular": "La comida no es gran cosa, pero la música salva la noche.",
			"malo": "La fiesta acaba antes de empezar."},
	},
]


def _rellenar(t: str, nombres: dict) -> str:
	for k, v in nombres.items():
		t = t.replace("{" + k + "}", v)
	return t


def capitulos(n: int, nombres: dict) -> list[dict]:
	"""n capitulos (se repiten los modelos con su numero) con los nombres del juego."""
	out = []
	for i in range(n):
		base = _CAPITULOS[i % len(_CAPITULOS)]
		cap = {"titulo": f"{i + 1}. " + _rellenar(base["titulo"], nombres), "escenas": [], "finales": {}}
		for e in base["escenas"]:
			cap["escenas"].append({"id": e["id"], "quien": e["quien"], "texto": _rellenar(e["texto"], nombres),
				"opciones": [dict(o, texto=_rellenar(o["texto"], nombres)) for o in e["opciones"]]})
		cap["finales"] = {k: _rellenar(v, nombres) for k, v in base["finales"].items()}
		out.append(cap)
	return out


def a_kit(cap: dict) -> dict:
	"""Capitulo del diseno (en espanol) -> nivel del kit (scenes / endings)."""
	escenas = []
	for e in cap.get("escenas", []):
		ops = []
		for o in e.get("opciones", []):
			op = {"text": o.get("texto", ""), "to": o.get("va_a", "")}
			if o.get("efecto"):
				op["fx"] = dict(o["efecto"])
			if o.get("requiere"):
				op["need"] = dict(o["requiere"])
			ops.append(op)
		escenas.append({"id": e.get("id", ""), "who": e.get("quien", "narrador"), "text": e.get("texto", ""), "options": ops})
	return {"title": cap.get("titulo", ""), "scenes": escenas, "endings": dict(cap.get("finales", {}))}


_FINES = {"FIN_BUENO": "bueno", "FIN_REGULAR": "regular", "FIN_MALO": "malo"}


def comprobar(cap_kit: dict) -> list[str]:
	"""Lo mismo que el analizador de Godot (tale_map.gd)."""
	esc = cap_kit.get("scenes", [])
	ids = [e.get("id") for e in esc]
	fallos = []
	if not 3 <= len(esc) <= 30:
		fallos.append("tale_scenes")
	if len(set(ids)) != len(ids):
		fallos.append("tale_ids")
	por_id = {e.get("id"): e for e in esc}
	for e in esc:
		ops = e.get("options", [])
		if not 1 <= len(ops) <= 3 or not str(e.get("text", "")).strip():
			fallos.append("tale_options")
			break
		if any(o.get("to") not in por_id and o.get("to") not in _FINES for o in ops):
			fallos.append("tale_target")
			break
	if any(not str(cap_kit.get("endings", {}).get(k, "")).strip() for k in ("bueno", "regular", "malo")):
		fallos.append("tale_endings")
	if fallos or not esc:
		return fallos
	visto = {ids[0]}
	pila = [ids[0]]
	while pila:
		for o in por_id[pila.pop()].get("options", []):
			t = o.get("to")
			if t in por_id and t not in visto:
				visto.add(t)
				pila.append(t)
	if len(visto) != len(ids):
		fallos.append("tale_unreachable")
	if not _camino_bueno(cap_kit):
		fallos.append("tale_no_good_end")
	return fallos


def _camino_bueno(cap_kit: dict) -> bool:
	por_id = {e.get("id"): e for e in cap_kit["scenes"]}
	inicio = cap_kit["scenes"][0]["id"]
	cola = [(inicio, (0, 0, 0), frozenset())]
	vistos = {cola[0]}
	while cola:
		i, (va, am, oro), objs = cola.pop(0)
		for o in por_id[i].get("options", []):
			n = o.get("need") or {}
			if "objeto" in n and n["objeto"] not in objs:
				continue
			if "stat" in n and {"valor": va, "amistad": am, "oro": oro}.get(n["stat"], 0) < int(n.get("min", 0)):
				continue
			fx = o.get("fx") or {}
			st = (va + int(fx.get("valor", 0)), am + int(fx.get("amistad", 0)), min(50, oro + int(fx.get("oro", 0))))
			ob = objs | ({fx["objeto"]} if fx.get("objeto") else set())
			t = o.get("to")
			if t == "FIN_BUENO":
				return True
			if t in por_id and (t, st, ob) not in vistos and len(vistos) < 20000:
				vistos.add((t, st, ob))
				cola.append((t, st, ob))
	return False


def nombres_de(d: dict) -> dict:
	"""Nombres para rellenar los capitulos con lo que ya trae el diseno."""
	enem = d.get("enemigos") or []
	rival = (d.get("jefe") or {}).get("nombre") or (enem[0]["nombre"] if enem else "la Sombra")
	aliado = enem[1]["nombre"] if len(enem) > 1 else "Pip"
	return {"heroe": (d.get("heroe") or {}).get("nombre", "nuestra heroina"), "rival": rival, "aliado": aliado,
		"lugar": d.get("titulo", "el reino"), "tesoro": "la " + (d.get("coleccionable") or {}).get("nombre", "joya").lower()}
