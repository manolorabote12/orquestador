"""Preguntas de ejemplo para la directora simulada (sin IA). Con IA, la directora escribe las
preguntas sobre el tema de cada idea. Todas comprobables y para todas las edades."""

ESPACIO = [
	("¿Qué planeta está más cerca del Sol?", ["Mercurio", "Venus", "Marte", "Tierra"], 0, "Mercurio es el planeta más cercano al Sol."),
	("¿Cuál es el planeta más grande del sistema solar?", ["Júpiter", "Saturno", "Neptuno", "Tierra"], 0, "Júpiter es tan grande que dentro cabrían más de mil Tierras."),
	("¿Qué planeta es famoso por sus anillos?", ["Saturno", "Marte", "Mercurio", "Venus"], 0, "Saturno tiene anillos de hielo y roca."),
	("¿Cómo se llama el satélite natural de la Tierra?", ["La Luna", "Fobos", "Titán", "Europa"], 0, "La Luna gira alrededor de la Tierra."),
	("¿Qué planeta llamamos el planeta rojo?", ["Marte", "Júpiter", "Venus", "Urano"], 0, "El óxido de hierro del suelo hace que Marte se vea rojo."),
	("¿Cuántos planetas tiene el sistema solar?", ["Ocho", "Siete", "Nueve", "Diez"], 0, "Son ocho: Plutón es un planeta enano."),
	("¿Qué es el Sol?", ["Una estrella", "Un planeta", "Un cometa", "Una luna"], 0, "El Sol es la estrella más cercana a nosotros."),
	("¿Quién fue la primera persona en pisar la Luna?", ["Neil Armstrong", "Yuri Gagarin", "Buzz Aldrin", "Pedro Duque"], 0, "Neil Armstrong la pisó en 1969."),
	("¿Qué planeta gira tumbado de lado?", ["Urano", "Marte", "Mercurio", "Saturno"], 0, "El eje de Urano está muy inclinado."),
	("¿Cómo se llama nuestra galaxia?", ["Vía Láctea", "Andrómeda", "Orión", "Osa Mayor"], 0, "Vivimos en la Vía Láctea."),
	("¿Qué planeta es el más caliente?", ["Venus", "Mercurio", "Marte", "Júpiter"], 0, "Las nubes de Venus atrapan el calor como un invernadero."),
	("¿Cuánto tarda la Tierra en dar una vuelta al Sol?", ["Un año", "Un día", "Un mes", "Una semana"], 0, "Unos 365 días: eso es un año."),
	("¿Qué es un cometa?", ["Una bola de hielo y polvo", "Una estrella", "Un planeta", "Una nube"], 0, "Al acercarse al Sol, el hielo forma su cola."),
	("¿Qué planeta tiene la Gran Mancha Roja?", ["Júpiter", "Marte", "Saturno", "Neptuno"], 0, "Es una tormenta gigante que dura siglos."),
	("¿Qué usan los astronautas para respirar fuera de la nave?", ["Un traje espacial", "Una mascarilla", "Nada", "Un paraguas"], 0, "El traje lleva oxígeno y los protege."),
]

ANIMALES = [
	("¿Cuál es el animal terrestre más rápido?", ["El guepardo", "El león", "El caballo", "La gacela"], 0, "El guepardo supera los 100 km/h en carreras cortas."),
	("¿Qué animal es el más grande del mundo?", ["La ballena azul", "El elefante", "La jirafa", "El tiburón blanco"], 0, "La ballena azul puede medir unos 30 metros."),
	("¿Cuántas patas tiene una araña?", ["Ocho", "Seis", "Diez", "Cuatro"], 0, "Las arañas tienen ocho patas; los insectos, seis."),
	("¿Qué animal fabrica la miel?", ["La abeja", "La hormiga", "La mosca", "La mariposa"], 0, "Las abejas hacen miel con el néctar de las flores."),
	("¿Qué guarda el camello en su joroba?", ["Grasa", "Agua", "Arena", "Aire"], 0, "La joroba guarda grasa, no agua: así aguanta sin comer."),
	("¿Qué animal cambia de color para camuflarse?", ["El camaleón", "El perro", "El caballo", "La vaca"], 0, "El camaleón cambia de color con la luz y su estado."),
	("¿Cuál de estos es un mamífero?", ["El delfín", "El tiburón", "El atún", "El pulpo"], 0, "Los delfines respiran aire y amamantan a sus crías."),
	("¿Qué come principalmente el panda gigante?", ["Bambú", "Pescado", "Carne", "Frutas"], 0, "El panda pasa gran parte del día comiendo bambú."),
	("¿Qué ave no puede volar?", ["El pingüino", "La paloma", "El águila", "El loro"], 0, "Los pingüinos usan las alas para nadar."),
	("¿Cómo se llama la cría de la vaca?", ["Ternero", "Potro", "Cordero", "Cachorro"], 0, "La cría de la vaca es el ternero."),
	("¿Qué animal tiene el cuello más largo?", ["La jirafa", "El avestruz", "El caballo", "El elefante"], 0, "El cuello de una jirafa puede medir dos metros."),
	("¿Cuántos corazones tiene un pulpo?", ["Tres", "Uno", "Dos", "Ocho"], 0, "El pulpo tiene tres corazones."),
	("¿Qué animal duerme colgado boca abajo?", ["El murciélago", "El búho", "El mono", "La ardilla"], 0, "Los murciélagos descansan colgados de las patas."),
	("¿Qué insecto sale de una oruga?", ["La mariposa", "La abeja", "La hormiga", "El escarabajo"], 0, "La oruga hace un capullo y sale una mariposa."),
	("¿Qué animal es conocido como el rey de la selva?", ["El león", "El tigre", "El elefante", "El gorila"], 0, "Aunque vive en la sabana, al león lo llaman así."),
]

GENERAL = [
	("¿Cuántos días tiene una semana?", ["Siete", "Cinco", "Seis", "Diez"], 0, "De lunes a domingo, siete días."),
	("¿De qué color es el cielo en un día despejado?", ["Azul", "Verde", "Rojo", "Morado"], 0, "La luz azul se dispersa más en el aire."),
	("¿Cuántos continentes hay?", ["Seis", "Cuatro", "Diez", "Tres"], 0, "Se suelen contar seis: América, Europa, Asia, África, Oceanía y la Antártida."),
	("¿Qué instrumento tiene teclas blancas y negras?", ["El piano", "La guitarra", "El violín", "La flauta"], 0, "Un piano normal tiene 88 teclas."),
	("¿Cuál es el océano más grande?", ["El Pacífico", "El Atlántico", "El Índico", "El Ártico"], 0, "El Pacífico cubre casi un tercio de la Tierra."),
	("¿Cuántos lados tiene un triángulo?", ["Tres", "Cuatro", "Cinco", "Seis"], 0, "Tri significa tres."),
	("¿Qué necesitan las plantas para hacer su alimento?", ["Luz del sol", "Música", "Arena", "Sal"], 0, "Con la luz, el agua y el aire hacen la fotosíntesis."),
	("¿Cuánto es 7 por 8?", ["56", "54", "64", "48"], 0, "7 x 8 = 56."),
	("¿Qué país tiene forma de bota?", ["Italia", "Francia", "España", "Portugal"], 0, "En el mapa, Italia parece una bota."),
	("¿En qué estado está el agua cuando es hielo?", ["Sólido", "Líquido", "Gaseoso", "Plasma"], 0, "El hielo es agua en estado sólido."),
	("¿Cuál es el río más largo de España?", ["El Tajo", "El Ebro", "El Duero", "El Guadalquivir"], 0, "El Tajo recorre más de mil kilómetros."),
	("¿Cuántos minutos tiene una hora?", ["Sesenta", "Cien", "Treinta", "Cuarenta"], 0, "Una hora son 60 minutos."),
	("¿Qué gas respiramos para vivir?", ["Oxígeno", "Helio", "Dióxido de carbono", "Hidrógeno"], 0, "Nuestro cuerpo necesita oxígeno."),
	("¿Cuál es la montaña más alta del mundo?", ["El Everest", "El Teide", "El Kilimanjaro", "El Mont Blanc"], 0, "El Everest mide unos 8.849 metros."),
	("¿Qué número romano es la X?", ["Diez", "Cinco", "Cincuenta", "Uno"], 0, "En números romanos, X vale diez."),
]


def para(idea: str) -> list[tuple]:
	t = idea.lower()
	if any(w in t for w in ("planeta", "espacio", "astronauta", "estrella", "galaxia", "luna")):
		return ESPACIO
	if any(w in t for w in ("animal", "granja", "selva", "zoo", "bicho", "mascota")):
		return ANIMALES
	return GENERAL
