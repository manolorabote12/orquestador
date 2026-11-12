"""Generador de niveles de plataformas por bloques probados.

La IA no dibuja mapas (se equivoca con las cuadriculas). Este generador encadena bloques
que ya sabemos jugables, con una curva de dificultad, y el resultado se valida despues con el
analizador y los bots de OrqKit. Lo que no pasa se regenera con otra semilla.

Leyenda del mapa: # bloque, P salida, G meta, C moneda, ^ pinchos, E patrulla, K pinchudo,
F volador, . vacio.

Reglas de seguridad de los bloques:
1 - Los enemigos que andan van siempre entre dos bordillos (bloque de 1 de alto): no salen de
    su zona, nunca llegan a la salida y encima de su ruta no hay plataformas (se pueden saltar).
2 - Los huecos miden como mucho 3 casillas y los escalones suben como mucho 2.
3 - Las plataformas flotan a 3 casillas del suelo (alcanzables con cualquier sensacion de salto).
4 - Nunca hay un enemigo en el bloque que sigue a la salida.
5 - Un muro a cada lado del mundo: no se puede salir andando del nivel.
6 - Los voladores van sobre suelo firme, nunca sobre huecos.
7 - Tras una bajada no viene un hueco ni pinchos (seria un "salto de fe").
8 - Tras cualquier salto obligado (bordillo, hueco) hay al menos 2 casillas para aterrizar,
    y tras un hueco nunca vienen pinchos.
10 - Runner (generar_runner): se corre solo y no se puede frenar. Tras cada obstaculo hay
    al menos 5 casillas de respiro (el salto a toda velocidad recorre unas 5), sin muros de mas de
    2, sin plataformas moviles ni jefe; monedas en fila a ras de suelo y en arco sobre los saltos.
9 - Piezas opcionales segun el diseno: poderes (H J M V I), punto de control (R) hacia la
    mitad de los niveles largos, puentes con plataforma movil (=) y arena del jefe (B) al final
    del ultimo nivel, con un punto de control justo antes.
"""

import functools
import math
import random
from dataclasses import dataclass, field

ALTO = 16
SUELO_BASE = 13
SUELO_MIN = 9
SUELO_MAX = 14

CURVA = {"facil": (0.0, 0.5), "normal": (0.1, 0.75), "dificil": (0.25, 0.85)}


@dataclass
class Columna:
	suelo: int | None
	cosas: dict[int, str] = field(default_factory=dict)


class Nivel:
	def __init__(self, rng: random.Random, d: float, enemigos: list[str], opciones: dict | None = None):
		self.rng = rng
		self.d = d
		self.enemigos = enemigos
		self.op = opciones or {}
		self.poderes_puestos = 0
		self.cols: list[Columna] = []
		self.suelo = SUELO_BASE
		self.monedas = 0
		self.bajada = False

	## Utilidades -----------------------------------------------------------------
	def llano(self, n: int) -> int:
		inicio = len(self.cols)
		for _ in range(n):
			self.cols.append(Columna(self.suelo))
		return inicio

	def poner(self, x: int, fila: int, ch: str) -> None:
		if ch == "C":
			self.monedas += 1
		self.cols[x].cosas[fila] = ch

	def bordillo(self, cierra: bool = False) -> None:
		x = self.llano(1)
		self.poner(x, self.suelo - 1, "#")
		## Tras saltar un bordillo siempre hay sitio para aterrizar.
		if cierra:
			self.llano(2)

	## Bloques ----------------------------------------------------------------------
	def muro(self) -> None:
		self.cols.append(Columna(0))

	def b_inicio(self) -> None:
		self.muro()
		x = self.llano(5)
		self.poner(x + 2, self.suelo - 1, "P")

	def b_llano(self) -> None:
		n = self.rng.randint(3, 6)
		x = self.llano(n)
		if self.rng.random() < 0.5:
			self.poner(x + n // 2, self.suelo - 1 - self.rng.randint(0, 1), "C")

	def b_escalon(self) -> None:
		cambio = self.rng.choice([-2, -1, -1, 1, 1, 2])
		antes = self.suelo
		self.suelo = max(SUELO_MIN, min(SUELO_MAX, self.suelo + cambio))
		self.bajada = self.suelo > antes
		x = self.llano(4 if self.bajada else 3)
		if self.rng.random() < 0.3:
			self.poner(x + 1, self.suelo - 1, "C")

	def b_hueco(self) -> None:
		ancho = 2 if self.d < 0.35 else self.rng.choice([2, 3, 3])
		self.llano(2)
		x = len(self.cols)
		for _ in range(ancho):
			self.cols.append(Columna(None))
		if self.rng.random() < 0.6:
			self.poner(x + ancho // 2, self.suelo - 3, "C")
		cambio = self.rng.choice([0, 0, -1, 1]) if self.d > 0.3 else 0
		self.suelo = max(SUELO_MIN, min(SUELO_MAX, self.suelo + cambio))
		self.llano(2)

	def b_pinchos(self) -> None:
		n = 1 if self.d < 0.3 else (2 if self.d < 0.75 else self.rng.choice([2, 3]))
		self.llano(2)
		x = self.llano(n)
		for i in range(n):
			self.poner(x + i, self.suelo - 1, "^")
		if self.rng.random() < 0.4:
			self.poner(x + n // 2, self.suelo - 3, "C")
		self.llano(2)

	def b_plataforma(self) -> None:
		x = self.llano(6)
		for i in range(2, 5):
			self.poner(x + i, self.suelo - 3, "#")
		self.poner(x + 3, self.suelo - 4, "C")

	def b_patrulla(self) -> None:
		self.bordillo()
		n = self.rng.randint(6, 8)
		x = self.llano(n)
		self.poner(x + n // 2, self.suelo - 1, "E")
		if self.rng.random() < 0.5:
			self.poner(x + n // 2, self.suelo - 3, "C")
		self.bordillo(cierra=True)

	def b_pinchudo(self) -> None:
		self.bordillo()
		n = self.rng.randint(7, 8)
		x = self.llano(n)
		self.poner(x + n // 2, self.suelo - 1, "K")
		if self.rng.random() < 0.6:
			self.poner(x + n // 2, self.suelo - 3, "C")
		self.bordillo(cierra=True)

	def b_volador(self) -> None:
		## Vuela sobre suelo firme a media altura: se puede pasar por debajo o pisarlo saltando.
		## Nunca encima de un hueco: un golpe ahi tiraria al jugador al vacio.
		self.bordillo()
		x = self.llano(8)
		self.poner(x + 4, self.suelo - 3, "F")
		self.bordillo(cierra=True)

	def b_combo(self) -> None:
		self.bordillo()
		x = self.llano(10)
		self.poner(x + 3, self.suelo - 1, "E")
		self.poner(x + 7, self.suelo - 1, "E")
		self.poner(x + 5, self.suelo - 4, "C")
		self.bordillo(cierra=True)

	def b_poder(self) -> None:
		## Un poder de los del diseno, a veces a ras de suelo y a veces en una plataforma.
		letras = {"corazon": "H", "doble_salto": "J", "iman": "M", "velocidad": "V", "estrella": "I"}
		disponibles = [letras[p] for p in self.op.get("poderes", []) if p in letras]
		if not disponibles:
			self.b_llano()
			return
		letra = self.rng.choice(disponibles)
		if self.rng.random() < 0.5:
			x = self.llano(5)
			self.poner(x + 2, self.suelo - 1, letra)
		else:
			x = self.llano(6)
			for i in range(2, 5):
				self.poner(x + i, self.suelo - 3, "#")
			self.cols[x + 3].cosas[self.suelo - 4] = letra
		self.poderes_puestos += 1

	def b_control(self) -> None:
		x = self.llano(4)
		self.poner(x + 1, self.suelo - 1, "R")

	def b_puente(self) -> None:
		## Hueco de 8 con una plataforma movil de 2 en el centro: va y viene de borde a borde.
		self.llano(2)
		x = len(self.cols)
		for k in range(8):
			col = Columna(None)
			if k in (3, 4):
				col.cosas[self.suelo] = "="
			self.cols.append(col)
		if self.rng.random() < 0.5:
			self.poner(x + 4, self.suelo - 3, "C")
		self.llano(3)

	## Piezas con mas idea (12 nov: los niveles se parecian mucho entre si) --------------------
	def b_escalera(self) -> None:
		## Tres plataformas en escalera con monedas: subir y volver a bajar (juego en vertical).
		x = self.llano(10)
		altura = 3
		for k, dx in enumerate((1, 4, 7)):
			fila = self.suelo - altura - 2 * k
			if fila < 2:
				break
			for j in range(2):
				self.poner(x + dx + j, fila, "#")
			self.poner(x + dx, fila - 1, "C")
		self.llano(2)

	def b_arco(self) -> None:
		## Arco de 5 monedas sobre un llano: invita a saltar y se recoge de una vez (recompensa).
		x = self.llano(9)
		for k, alto in enumerate((1, 3, 4, 3, 1)):
			self.poner(x + 2 + k, self.suelo - 1 - alto, "C")

	def b_atajo(self) -> None:
		## Dos caminos: abajo pinchos con un hueco limpio; arriba una plataforma larga con monedas.
		## Por arriba es mas seguro y paga mas; por abajo, mas rapido.
		self.llano(2)
		x = self.llano(9)
		for k in (3, 6):
			self.poner(x + k, self.suelo - 1, "^")
		for j in range(1, 9):
			self.poner(x + j, self.suelo - 4, "#")
		for j in (2, 4, 6):
			self.poner(x + j, self.suelo - 5, "C")
		self.llano(2)

	def b_emboscada(self) -> None:
		## Un enemigo de suelo y un volador a la vez, con una plataforma para escapar por encima.
		self.bordillo()
		x = self.llano(11)
		self.poner(x + 6, self.suelo - 1, "E")
		if "flyer" in self.enemigos:
			self.poner(x + 3, self.suelo - 3, "F")
		for j in range(4, 9):
			self.poner(x + j, self.suelo - 4, "#")
		self.poner(x + 6, self.suelo - 5, "C")
		self.bordillo(cierra=True)

	def b_jefe(self) -> None:
		## Arena plana de 12 entre bordillos, sin nada encima, con punto de control antes.
		self.llano(2)
		self.b_control()
		self.bordillo()
		x = self.llano(12)
		self.poner(x + 7, self.suelo - 1, "B")
		self.bordillo(cierra=True)

	def b_final(self) -> None:
		x = self.llano(6)
		self.poner(x + 3, self.suelo - 1, "G")
		self.muro()

	## Mapa -------------------------------------------------------------------------
	def mapa(self) -> list[str]:
		filas = []
		for y in range(ALTO):
			fila = []
			for c in self.cols:
				if y in c.cosas:
					fila.append(c.cosas[y])
				elif c.suelo is not None and y >= c.suelo:
					fila.append("#")
				else:
					fila.append(".")
			filas.append("".join(fila))
		return filas


def _pesos(nv: Nivel, i: int, n: int) -> dict[str, float]:
	d = nv.d
	p = {"llano": 1.6, "escalon": 1.4, "hueco": 1.0 + 1.6 * d, "pinchos": 0.5 + 1.8 * d, "plataforma": 1.2}
	## 5 - Los enemigos entran poco a poco: patrulla desde el nivel 2 (o el 1 si es dificil);
	## pinchudo y volador un nivel despues (en juegos de 3 niveles, desde el 2).
	inicio_e = 0 if d >= 0.25 else 1
	tarde = 1 if n <= 3 else 2
	if "walker" in nv.enemigos and i >= inicio_e:
		p["patrulla"] = 1.3 + 0.6 * d
		if d > 0.45:
			p["combo"] = 0.9 * d
	if "spiky" in nv.enemigos and i >= max(inicio_e, tarde):
		p["pinchudo"] = 0.9 + 0.8 * d
	if "flyer" in nv.enemigos and i >= max(inicio_e, tarde):
		p["volador"] = 0.7 + 0.9 * d
	if nv.op.get("poderes") and nv.poderes_puestos < 2:
		p["poder"] = 0.8
	if nv.op.get("plataformas_moviles") and i >= 1:
		p["puente"] = 0.6 + 0.6 * d
	## Piezas especiales: aparecen a partir del segundo nivel (el primero ensena lo basico). Cuantas,
	## lo decide el experimento del genero (opcion «piezas»).
	if i >= 1:
		f = float(nv.op.get("piezas", 1.0))
		p["escalera"] = 0.5 * f
		p["arco"] = 0.6 * f
		p["atajo"] = (0.4 + 0.5 * d) * f
		if "walker" in nv.enemigos and d > 0.4:
			p["emboscada"] = 0.5 * d * f
	return p


def generar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Nivel i (0..n-1) de un juego de n niveles. ajuste sube o baja la dificultad de ese nivel.
	opciones: poderes, jefe, puntos_control y plataformas_moviles del diseno."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	op = opciones or {}
	nv = Nivel(rng, d, enemigos, op)
	largo = min(90, 34 + 10 * i + rng.randint(0, 6))
	nv.b_inicio()
	nv.b_llano()
	ultimo = "llano"
	enemigos_puestos = 0
	control_puesto = False
	while len(nv.cols) < largo:
		if op.get("puntos_control", False) and not control_puesto and largo >= 44 and len(nv.cols) >= largo // 2:
			nv.b_control()
			control_puesto = True
			ultimo = "control"
			continue
		pesos = _pesos(nv, i, n)
		pesos.pop(ultimo, None)
		## 7 - Tras una bajada no hay hueco ni pinchos: quien salta al bajar no cae en una trampa.
		if ultimo == "escalon" and nv.bajada:
			for trampa in ("hueco", "pinchos"):
				pesos.pop(trampa, None)
		## 7b - Tras un hueco no vienen pinchos: se aterriza con inercia y no da tiempo a reaccionar.
		if ultimo in ("hueco", "puente"):
			pesos.pop("pinchos", None)
		nombres = list(pesos)
		elegido = rng.choices(nombres, weights=[pesos[x] for x in nombres])[0]
		getattr(nv, "b_" + elegido)()
		ultimo = elegido
		if elegido in ("patrulla", "pinchudo", "volador", "combo", "emboscada"):
			enemigos_puestos += 1
	## 6 - Si tocaba enemigo y el azar no lo puso, se pone uno antes de la meta.
	if enemigos_puestos == 0 and "walker" in enemigos and i >= 1:
		nv.b_patrulla()
	while nv.monedas < 3:
		nv.b_plataforma()
	if op.get("jefe") and i == n - 1:
		nv.b_jefe()
	nv.b_final()
	return nv.mapa()


## Runner -------------------------------------------------------------------------------

def _r_respiro(nv: Nivel) -> None:
	n = nv.rng.randint(5, 7)
	x = nv.llano(n)
	if nv.rng.random() < 0.35:
		for k in range(1, min(4, n - 1)):
			nv.poner(x + k, nv.suelo - 1, "C")


def _r_hueco(nv: Nivel) -> None:
	ancho = 2 if nv.d < 0.4 else nv.rng.choice([2, 3])
	x = len(nv.cols)
	for _ in range(ancho):
		nv.cols.append(Columna(None))
	## Arco de monedas siguiendo el salto.
	if nv.rng.random() < 0.6:
		nv.poner(x, nv.suelo - 2, "C")
		nv.poner(x + ancho // 2, nv.suelo - 3, "C")
		nv.poner(x + ancho - 1, nv.suelo - 2, "C")


def _r_pinchos(nv: Nivel) -> None:
	n = 1 if nv.d < 0.45 else nv.rng.choice([1, 2])
	x = nv.llano(n)
	for i in range(n):
		nv.poner(x + i, nv.suelo - 1, "^")
	if nv.rng.random() < 0.4:
		nv.poner(x, nv.suelo - 3, "C")


def _r_escalon(nv: Nivel) -> None:
	## Sube 1 o 2 (se salta) o baja 1 o 2 (se cae andando). Nunca un muro de 3.
	cambio = nv.rng.choice([-2, -1, -1, 1, 1, 2])
	nv.suelo = max(SUELO_MIN, min(SUELO_MAX, nv.suelo + cambio))
	nv.bajada = cambio > 0
	nv.llano(1)


def _r_plataforma(nv: Nivel) -> None:
	## Camino de arriba opcional con monedas: si no subes, pasas por debajo sin problema.
	x = nv.llano(7)
	for i in range(2, 6):
		nv.poner(x + i, nv.suelo - 3, "#")
	for i in range(2, 6):
		nv.poner(x + i, nv.suelo - 4, "C")


def _r_enemigo(nv: Nivel, letra: str, fila: int) -> None:
	## Entre dos bordillos (como en plataformas): el enemigo no sale de su zona ni se mete
	## bajo una plataforma; el bordillo de entrada da ritmo y hay 5 casillas antes de el.
	nv.llano(1)
	nv.bordillo()
	x = nv.llano(9)
	nv.poner(x + 6, nv.suelo - fila, letra)
	nv.bordillo()


def _r_patrulla(nv: Nivel) -> None:
	_r_enemigo(nv, "E", 1)


def _r_pinchudo(nv: Nivel) -> None:
	_r_enemigo(nv, "K", 1)


def _r_volador(nv: Nivel) -> None:
	_r_enemigo(nv, "F", 3)


def _r_poder(nv: Nivel) -> None:
	letras = {"corazon": "H", "doble_salto": "J", "iman": "M", "velocidad": "V", "estrella": "I"}
	disponibles = [letras[p] for p in nv.op.get("poderes", []) if p in letras]
	x = nv.llano(4)
	if disponibles:
		nv.poner(x + 2, nv.suelo - 1, nv.rng.choice(disponibles))
		nv.poderes_puestos += 1


def _r_escalera(nv: Nivel) -> None:
	## Tres plataformas cortas que suben con monedas: premio para quien encadena saltos. Por abajo
	## se pasa corriendo sin problema (12 nov: el corredor era siempre lo mismo).
	x = nv.llano(11)
	for k, (dx, alto) in enumerate(((1, 3), (4, 4), (7, 5))):
		fila = nv.suelo - alto
		if fila < 2:
			break
		for j in range(2):
			nv.poner(x + dx + j, fila, "#")
		nv.poner(x + dx + 1, fila - 1, "C")


def _r_doble_hueco(nv: Nivel) -> None:
	## Dos huecos seguidos con una isla de 3: ritmo salto-salto.
	for _ in range(2):
		x = len(nv.cols)
		for _ in range(2):
			nv.cols.append(Columna(None))
		nv.poner(x + 1, nv.suelo - 3, "C")
		nv.llano(3)


def _r_carril(nv: Nivel) -> None:
	## Carril alto sobre un campo de pinchos: arriba se corre seguro y con monedas; abajo hay que
	## saltar cada pincho. El suelo de despues esta limpio (luego viene un respiro).
	x = nv.llano(11)
	for j in range(1, 10):
		nv.poner(x + j, nv.suelo - 3, "#")
	for j in (2, 5, 8):
		nv.poner(x + j, nv.suelo - 1, "^")
	for j in (3, 5, 7):
		nv.poner(x + j, nv.suelo - 4, "C")


## La plataforma tambien: saltar justo al salir de debajo de ella daria con la cabeza en su borde.
OBSTACULOS_R = {"hueco", "pinchos", "escalon", "plataforma", "patrulla", "pinchudo", "volador", "escalera", "doble_hueco", "carril"}


def generar_runner(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Nivel i de un runner: largo, recto, con ritmo obstaculo-respiro y cada vez mas denso."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	op = opciones or {}
	nv = Nivel(rng, d, enemigos, op)
	largo = min(150, 70 + 18 * i + rng.randint(0, 10))
	nv.b_inicio()
	nv.llano(4)
	control = False
	ultimo = ""
	while len(nv.cols) < largo:
		if op.get("puntos_control", False) and not control and len(nv.cols) >= largo // 2:
			nv.b_control()
			nv.llano(3)
			control = True
			continue
		pesos = {"hueco": 1.2 + 1.4 * d, "pinchos": 0.8 + 1.4 * d, "escalon": 1.0, "plataforma": 0.9}
		if "walker" in enemigos and i >= (0 if d >= 0.25 else 1):
			pesos["patrulla"] = 0.9 + 0.6 * d
		if "spiky" in enemigos and i >= 1:
			pesos["pinchudo"] = 0.6 + 0.6 * d
		if "flyer" in enemigos and i >= 1:
			pesos["volador"] = 0.5 + 0.6 * d
		if op.get("poderes") and nv.poderes_puestos < 2:
			pesos["poder"] = 0.5
		## Piezas con mas idea desde el segundo nivel.
		if i >= 1:
			f = float(op.get("piezas", 1.0))
			pesos["escalera"] = 0.5 * f
			pesos["carril"] = (0.3 + 0.5 * d) * f
			if d > 0.4:
				pesos["doble_hueco"] = 0.6 * d * f
		pesos.pop(ultimo, None)
		nombres = list(pesos)
		elegido = rng.choices(nombres, weights=[pesos[x] for x in nombres])[0]
		{"hueco": _r_hueco, "pinchos": _r_pinchos, "escalon": _r_escalon, "plataforma": _r_plataforma,
			"patrulla": _r_patrulla, "pinchudo": _r_pinchudo, "volador": _r_volador, "poder": _r_poder,
			"escalera": _r_escalera, "doble_hueco": _r_doble_hueco, "carril": _r_carril}[elegido](nv)
		ultimo = elegido
		## 10 - Respiro tras cada obstaculo (con mas dificultad, un poco mas corto).
		if elegido in OBSTACULOS_R:
			_r_respiro(nv)
	while nv.monedas < 5:
		_r_plataforma(nv)
		_r_respiro(nv)
	nv.b_final()
	return nv.mapa()


## Volador (arcade de un toque) -------------------------------------------------------------

def generar_volador(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Nivel i de un arcade de volar: tuberias de 2 de ancho con un hueco que sube y baja.
	Reglas: hueco de 5 (4 en dificil), separacion de 6 a 9 columnas, el hueco no cambia de altura
	mas de lo que se puede subir o bajar volando en esa distancia, monedas en el centro de los huecos.
	Los enemigos no se usan (tocar una tuberia ya es perder)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	op = opciones or {}
	alto = ALTO
	suelo = alto - 2
	tuberias = min(22, 9 + 3 * i + rng.randint(0, 2))
	columnas: list[list[str]] = []

	def libre() -> list[str]:
		return ["."] * suelo + ["#", "#"]

	def muro() -> list[str]:
		return ["#"] * alto

	columnas.append(muro())
	for _ in range(9):
		columnas.append(libre())
	columnas[3][7] = "P"
	centro = 7.0
	poderes = [{"corazon": "H", "iman": "M", "estrella": "I"}[p] for p in op.get("poderes", []) if p in ("corazon", "iman", "estrella")]
	puestos = 0
	control = not op.get("puntos_control", True)
	for t in range(tuberias):
		hueco = 5 if d < 0.6 else rng.choice([4, 5])
		sep = max(6, 9 - int(round(3 * d)) + rng.randint(-1, 1))
		## Cambio de altura limitado por la distancia: subir cuesta mas que bajar.
		sube = int(0.4 * sep)
		baja = int(0.6 * sep)
		nuevo = centro + rng.randint(-sube, min(baja, sube + 1))
		nuevo = max(1.0 + hueco / 2.0, min(suelo - 1.0 - hueco / 2.0, nuevo))
		arriba = int(round(nuevo - hueco / 2.0))
		for _ in range(sep - 2):
			columnas.append(libre())
		hueco_entre = columnas[-((sep - 2) // 2) - 1]
		## Entre tuberias: a veces un poder, a veces una moneda a media altura.
		medio = int(round((centro + nuevo) / 2.0))
		if poderes and puestos < 2 and rng.random() < 0.15:
			hueco_entre[medio] = rng.choice(poderes)
			puestos += 1
		elif rng.random() < 0.35:
			hueco_entre[medio] = "C"
		if not control and t == tuberias // 2:
			hueco_entre[medio] = "R"
			control = True
		for c in range(2):
			col = libre()
			for y in range(suelo):
				if not (arriba <= y < arriba + hueco):
					col[y] = "#"
			if c == 0:
				col[arriba + hueco // 2] = "C"
			columnas.append(col)
		centro = nuevo
	for _ in range(7):
		columnas.append(libre())
	columnas[-4][int(round(centro))] = "G"
	columnas.append(muro())
	return ["".join(col[y] for col in columnas) for y in range(alto)]


## Hordas (vista desde arriba) ----------------------------------------------------------------

def parametros_horda(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Duracion y densidad de oleadas del nivel i: cada nivel dura mas y aprieta mas."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"seconds": float(min(150, 60 + 20 * i)), "density": round(0.25 + 0.6 * d, 3)}


def generar_horda(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Arena cerrada con rocas sueltas: claro de 7x7 en la salida, rocas <= 12 %, todo conectado
	(si una roca encierra un hueco, se quita) y cada nivel un poco mas grande."""
	rng = random.Random(semilla)
	w = 24 + 2 * min(i, 3)
	h = 30 + 2 * min(i, 3)
	g = [["#" if x in (0, w - 1) or y in (0, h - 1) else "." for x in range(w)] for y in range(h)]
	cx, cy = w // 2, h // 2
	formas = [[(0, 0)], [(0, 0), (1, 0)], [(0, 0), (0, 1)], [(0, 0), (1, 0), (0, 1), (1, 1)],
		[(0, 0), (1, 0), (2, 0)], [(0, 0), (0, 1), (1, 1)]]
	limite = int(0.12 * (w - 2) * (h - 2))
	puestas = 0
	intentos = 0
	while puestas < 8 + 3 * i and intentos < 400:
		intentos += 1
		forma = rng.choice(formas)
		ox, oy = rng.randint(2, w - 4), rng.randint(2, h - 4)
		celdas = [(ox + dx, oy + dy) for dx, dy in forma]
		if any(abs(x - cx) <= 3 and abs(y - cy) <= 3 for x, y in celdas):
			continue
		if any(g[y][x] != "." for x, y in celdas):
			continue
		rocas = sum(row.count("#") for row in g) - 2 * (w + h) + 4
		if rocas + len(celdas) > limite:
			break
		for x, y in celdas:
			g[y][x] = "#"
		if not _conectada(g, cx, cy):
			for x, y in celdas:
				g[y][x] = "."
			continue
		puestas += 1
	g[cy][cx] = "P"
	return ["".join(r) for r in g]


def _conectada(g: list[list[str]], cx: int, cy: int) -> bool:
	libres = sum(1 for row in g for c in row if c != "#")
	vistos = {(cx, cy)}
	pila = [(cx, cy)]
	while pila:
		x, y = pila.pop()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			nx, ny = x + dx, y + dy
			if (nx, ny) not in vistos and g[ny][nx] != "#":
				vistos.add((nx, ny))
				pila.append((nx, ny))
	return len(vistos) == libres


## Puzle de combinar 3 ----------------------------------------------------------------------

def parametros_puzle(i: int, n: int, dificultad: str, ajuste: float = 0.0, hielo: bool = False) -> dict:
	"""Movimientos, colores y exigencia del objetivo del nivel i (el kit calcula los puntos)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"moves": int(22 - round(4 * d) + (3 if hielo else 0)), "colors": 5 if d < 0.55 else 6,
		"goal_factor": round(0.55 + 0.4 * d, 3)}


FORMAS_PUZLE = [
	["......."] * 9,
	["##...##", "#.....#"] + ["......."] * 7,
	["......."] * 7 + ["#.....#", "##...##"],
	["#.....#"] + ["......."] * 7 + ["#.....#"],
	["..#.#.."] + ["......."] * 8,
	["........"] * 9,
	["##....##"] + ["........"] * 7 + ["##....##"],
]


def generar_puzle(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero de 7-8 x 9 con huecos solo en los bordes de las columnas y, desde el segundo nivel,
	hielo en el centro (mas cuanto mas dificil)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	forma = [list(f) for f in (FORMAS_PUZLE[0] if i == 0 else rng.choice(FORMAS_PUZLE))]
	if i >= 1:
		h, w = len(forma), len(forma[0])
		cuantos = int(4 + 10 * d)
		libres = [(x, y) for y in range(2, h - 2) for x in range(1, w - 1) if forma[y][x] == "."]
		rng.shuffle(libres)
		for x, y in libres[:cuantos]:
			forma[y][x] = "I"
	return ["".join(f) for f in forma]


## Torres (tower defense) -------------------------------------------------------------------

def parametros_torres(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Oleadas, densidad, oro inicial y vidas del nivel i."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"waves": min(9, 5 + i), "density": round(0.3 + 0.45 * d, 3),
		"gold": 180 if dificultad == "facil" else 150, "lives": 15 if dificultad == "facil" else 10}


def generar_torres(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Mapa de 9x13 con un camino en zigzag de arriba (S) a abajo (B): tramos horizontales
	separados por al menos una fila libre (sitio para torres entre ellos) y algunas rocas."""
	rng = random.Random(semilla)
	for _ in range(40):
		mapa = _mapa_torres(rng)
		## Camino largo (26 casillas o mas): da tiempo a las torres; uno corto es injusto.
		if sum(f.count("=") for f in mapa) + 2 >= 26:
			return mapa
	return mapa


def _mapa_torres(rng: random.Random) -> list[str]:
	w, h = 9, 13
	g = [["."] * w for _ in range(h)]
	x = rng.randint(1, w - 2)
	y = 0
	puntos = [(x, 0)]
	y = rng.randint(1, 2)
	puntos.append((x, y))
	lado = rng.choice([-1, 1])
	while y < h - 4:
		## Tramo horizontal hacia un lado y bajada de 2 o 3 filas.
		nx = rng.randint(6, w - 2) if lado > 0 else rng.randint(1, 2)
		if nx == x:
			nx = w - 2 if lado > 0 else 1
		puntos.append((nx, y))
		x = nx
		y = min(y + rng.choice([2, 3, 3]), h - 2)
		puntos.append((x, y))
		lado = -lado
	bx = rng.randint(2, w - 3)
	puntos.append((bx, y))
	puntos.append((bx, h - 1))
	celdas = []
	for (x0, y0), (x1, y1) in zip(puntos, puntos[1:]):
		dx = (x1 > x0) - (x1 < x0)
		dy = (y1 > y0) - (y1 < y0)
		cx, cy = x0, y0
		while (cx, cy) != (x1, y1):
			celdas.append((cx, cy))
			cx += dx
			cy += dy
	celdas.append(puntos[-1])
	for cx, cy in celdas:
		g[cy][cx] = "="
	sx, sy = celdas[0]
	g[sy][sx] = "S"
	ex, ey = celdas[-1]
	g[ey][ex] = "B"
	libres = [(cx, cy) for cy in range(h) for cx in range(w) if g[cy][cx] == "."]
	for cx, cy in rng.sample(libres, min(len(libres), rng.randint(2, 4))):
		g[cy][cx] = "#"
	return ["".join(r) for r in g]


def parametros_carreras(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Velocidad de los rivales (fraccion de la punta del jugador) segun nivel y dificultad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"rival_speed": round(0.85 + 0.08 * d, 3)}


def generar_carreras(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Pista de 160 + 40 x nivel tramos: curvas por tramos, conos y coches lentos (nunca un muro:
	siempre queda paso cambiando un carril por tramo), filas de monedas y alguna placa de turbo.
	Las 8 primeras filas, limpias."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	largo = 160 + 40 * min(i, 5)
	curvas = []
	while len(curvas) < largo:
		tramo = rng.randint(10, 30)
		curvas += [rng.choice("|||<>")] * tramo
	carriles = [["."] * 4 for _ in range(largo)]
	prob = 0.12 + 0.18 * d
	monedas_carril = -1
	monedas_quedan = 0
	ultimo_obst = -9
	for y in range(8, largo - 2):
		## Monedas en filas de 4-6 seguidas en un carril.
		if monedas_quedan <= 0 and rng.random() < 0.06:
			monedas_carril = rng.randint(0, 3)
			monedas_quedan = rng.randint(4, 6)
		if monedas_quedan > 0:
			carriles[y][monedas_carril] = "C"
			monedas_quedan -= 1
		if rng.random() < 0.015:
			carriles[y][rng.randint(0, 3)] = "N"
		## Obstaculo: como mucho 2 por fila y separados al menos 2 tramos (tiempo para reaccionar).
		if y - ultimo_obst >= 2 and rng.random() < prob:
			cuantos = 2 if rng.random() < 0.25 + 0.3 * d else 1
			for l in rng.sample(range(4), cuantos):
				carriles[y][l] = rng.choice("OOT")
			ultimo_obst = y
	filas = [curvas[y] + "".join(carriles[y]) for y in range(largo)]
	return filas


## >> genero naves
def parametros_naves(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Ritmo de las oleadas, velocidad de los enemigos y cadencia de sus disparos."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"row_time": round(0.95 - 0.25 * d, 3), "enemy_speed": round(0.85 + 0.35 * d, 3), "fire_rate": round(0.7 + 0.5 * d, 3)}


def generar_naves(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Oleadas de un matamarcianos vertical: 7 columnas, una fila por oleada.
	E caza (walker), Z zigzag (flyer), T tanque (spiky), A roca, C moneda, W mejora de arma, B jefe.
	Reglas de justicia (las mismas que comprueba kit/shooter/shooter_map.gd):
	1 - 2 filas de calma al empezar y 2-3 filas vacias entre oleadas (respirar).
	2 - Nunca mas de 5 amenazas ni 4 rocas en una fila; como mucho 5 tiradores en 3 filas.
	3 - Mejora de arma pronto (fila 3) y otra a mitad; monedas en lineas entre oleadas.
	4 - El jefe, si lo hay, al final del ultimo nivel."""
	op = opciones or {}
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	tipos = {"walker": "E", "flyer": "Z", "spiky": "T"}
	disponibles = [tipos[t] for t in enemigos if t in tipos] or ["E", "Z"]
	filas: list[str] = [".......", "......."]
	filas.append("...W...")
	oleadas = 7 + 2 * min(i, 4) + int(3 * d)
	formas = ["linea", "v", "columnas", "zigzag", "rocas", "monedas"]
	for o in range(oleadas):
		forma = rng.choice(formas if o > 0 else ["linea", "v"])
		if forma == "monedas":
			c = rng.randint(1, 5)
			for _ in range(rng.randint(3, 5)):
				filas.append("." * c + "C" + "." * (6 - c))
		elif forma == "rocas":
			cols = rng.sample(range(7), rng.randint(1, 2 + int(2 * d)))
			filas.append("".join("A" if x in cols else "." for x in range(7)))
		else:
			bicho = rng.choice(disponibles)
			cuantos = 2 + int(3 * d * rng.random()) + (1 if i >= 2 else 0)
			cuantos = max(1, min(cuantos, 5))
			if forma == "linea":
				ini = rng.randint(0, 7 - cuantos)
				filas.append("." * ini + bicho * cuantos + "." * (7 - ini - cuantos))
			elif forma == "v":
				filas.append("." * 3 + bicho + "." * 3)
				filas.append(".." + bicho + "." + bicho + "..")
			elif forma == "columnas":
				cols = rng.sample(range(7), min(cuantos, 3))
				for _ in range(2):
					filas.append("".join(bicho if x in cols else "." for x in range(7)))
			else:
				for x in rng.sample(range(7), min(cuantos, 3)):
					filas.append("." * x + "Z" + "." * (6 - x))
		## Respiro entre oleadas (mas corto con mas dificultad).
		for _ in range(3 - int(round(d))):
			filas.append(".......")
		if o == oleadas // 2:
			filas.append("..W....")
	## Tiradores: como mucho 5 en cualquier ventana de 3 filas (se convierten en zigzag).
	for y in range(len(filas)):
		ventana = sum(f.count("E") + f.count("T") for f in filas[max(0, y - 2):y + 1])
		if ventana > 5:
			filas[y] = filas[y].replace("E", "Z").replace("T", "Z")
	filas += [".......", "......."]
	if op.get("jefe") and i == n - 1:
		filas.append("...B...")
	return filas

## << genero naves


## >> genero rompebloques
def parametros_rompebloques(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Velocidad de la pelota segun nivel y dificultad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"ball_speed": round(0.9 + 0.3 * d, 3)}


def generar_rompebloques(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Muro de ladrillos de 9 columnas con una forma (filas, piramide, rombo, ajedrez, columnas,
	corazon) y mas filas, ladrillos duros y acero segun avanza el juego.
	Reglas de justicia (las mismas que comprueba kit/breakout/breakout_map.gd):
	1 - Al menos 12 ladrillos que se rompen; nunca una fila entera de acero.
	2 - Todo lo que se rompe es alcanzable desde abajo (el acero solo hace de obstaculo).
	3 - Monedas y mejoras (L pala ancha, M pelota extra) repartidas."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	alto = 5 + min(i, 3) + int(2 * d)
	formas = ["filas", "piramide", "rombo", "ajedrez", "columnas", "corazon"]
	forma = formas[(i + rng.randint(0, 5)) % len(formas)]
	for _ in range(60):
		g = [["." for _ in range(9)] for _ in range(alto)]
		for y in range(alto):
			for x in range(9):
				dentro = {
					"filas": True,
					"piramide": abs(x - 4) <= y * 4 // max(1, alto - 1),
					"rombo": abs(x - 4) + abs(y - alto // 2) * 2 <= 5,
					"ajedrez": (x + y) % 2 == 0,
					"columnas": x % 2 == 0,
					"corazon": (abs(x - 2) + y <= 3 or abs(x - 6) + y <= 3) if y < 3 else abs(x - 4) <= (alto - y) * 4 // max(1, alto - 2),
				}[forma]
				if not dentro:
					continue
				dureza = 1
				if rng.random() < 0.15 + 0.35 * d:
					dureza = 2
				if rng.random() < 0.04 + 0.12 * d and y < alto // 2:
					dureza = 3
				g[y][x] = str(dureza)
		## Acero: unos pocos, nunca en la fila de abajo del muro ni una fila entera.
		for _ in range(int(1 + 4 * d) if i > 0 else 0):
			y, x = rng.randrange(0, max(1, alto - 1)), rng.randrange(9)
			if g[y][x] != ".":
				g[y][x] = "#"
		ladrillos = [(y, x) for y in range(alto) for x in range(9) if g[y][x] in "123"]
		rng.shuffle(ladrillos)
		for (y, x) in ladrillos[:3 + min(i, 3)]:
			g[y][x] = "C"
		for (y, x), extra in zip(ladrillos[6:8], ["L", "M"]):
			g[y][x] = extra
		filas = ["".join(f) for f in g]
		if sum(f.count(c) for f in filas for c in "123CLM") >= 12 and not any(f == "#" * 9 for f in filas) and _rompebloques_alcanzable(filas):
			return filas
	return ["111111111"] * 4


def _rompebloques_alcanzable(filas: list[str]) -> bool:
	h = len(filas)
	abierto = {(h, x) for x in range(9)}
	cambio = True
	while cambio:
		cambio = False
		for y in range(h - 1, -1, -1):
			for x in range(9):
				if (y, x) in abierto or filas[y][x] == "#":
					continue
				if any((y + dy, x + dx) in abierto for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))):
					abierto.add((y, x))
					cambio = True
	return all((y, x) in abierto for y in range(h) for x in range(9) if filas[y][x] not in ".#")

## << genero rompebloques


## >> genero bloques
def parametros_bloques(i: int, n: int, dificultad: str, ajuste: float = 0.0, semilla: int = 0) -> dict:
	"""Semilla de las piezas, objetivo de lineas, par de piezas y cuantas piezas grandes salen."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	lineas = 6 + 2 * min(i, 6)
	return {"seed": 1000 + 7919 * i + 31 * int(d * 100) + semilla % 997, "lines": lineas,
		"par": int(8 + 3 * (3 + min(i, 7))) if i % 2 == 1 else int(2.6 * lineas) + 4, "big": round(0.12 + 0.2 * d, 3)}


def generar_bloques(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero de 8x8. Niveles pares: limpiar N lineas con algunos bloques puestos.
	Niveles impares: limpiar las gemas G (3 + nivel, hasta 10).
	Reglas de justicia (las mismas que comprueba kit/blocks/blocks_map.gd):
	1 - Como mucho un 40 % ocupado y ninguna fila o columna llena al empezar.
	2 - Las gemas nunca en esquinas encerradas: siempre con una linea con hueco."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	for _ in range(80):
		g = [["." for _ in range(8)] for _ in range(8)]
		bloques = rng.randint(2, 5) + int(4 * d) + min(i, 3) - (2 if i % 2 == 1 else 0)
		celdas = [(y, x) for y in range(8) for x in range(8)]
		rng.shuffle(celdas)
		for y, x in celdas[:bloques]:
			g[y][x] = "#"
		if i % 2 == 1:
			gemas = min(10, 3 + i)
			for y, x in celdas[bloques:bloques + gemas]:
				g[y][x] = "G"
		filas = ["".join(f) for f in g]
		llenas = any("." not in f for f in filas) or any(all(filas[y][x] != "." for y in range(8)) for x in range(8))
		if not llenas and sum(f.count(".") for f in filas) >= 64 * 0.6:
			return filas
	return ["........"] * 8

## << genero bloques


## >> genero corredor
def parametros_corredor(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Velocidad de salida (m/s) y cuanto acelera hasta la meta."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"speed": round(10.0 + 4.0 * d, 2), "ramp": round(0.15 + 0.2 * d, 3)}


def generar_corredor(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Via de 3 carriles: una fila cada 6 m. Trenes (W), vallas bajas (B), barras altas (H) y
	lineas de monedas (C).
	Reglas de justicia (las mismas que comprueba kit/lanes/lanes_map.gd):
	1 - 4 filas de calma al salir y nunca dos filas con obstaculos seguidas.
	2 - Nunca 3 trenes en una fila; siempre queda un carril libre a un cambio de distancia.
	3 - Mas obstaculos y menos hueco entre ellos con nivel y dificultad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	largo = 80 + 20 * min(i, 5)
	filas = [["."] * 3 for _ in range(largo)]
	libre = 1
	y = 5
	while y < largo - 3:
		tipo = rng.random()
		if tipo < 0.35 + 0.2 * d:
			## Trenes: 1 o 2 carriles; el libre esta a un cambio del anterior.
			nuevo = max(0, min(2, libre + rng.choice([-1, 0, 1])))
			trenes = [c for c in range(3) if c != nuevo]
			if rng.random() > 0.35 + 0.4 * d:
				trenes = [rng.choice(trenes)]
			for c in trenes:
				filas[y][c] = "W"
			libre = nuevo
		elif tipo < 0.7:
			c = rng.randint(0, 2)
			filas[y][c] = rng.choice("BBH")
			if rng.random() < 0.3 + 0.4 * d:
				otra = rng.choice([x for x in range(3) if x != c])
				filas[y][otra] = rng.choice("BH")
		else:
			## Linea de monedas por un carril (a veces sobre una valla: premio por saltar).
			c = rng.randint(0, 2)
			for k2 in range(rng.randint(3, 5)):
				if y + k2 < largo and filas[y + k2][c] == ".":
					filas[y + k2][c] = "C"
			y += 3
		## Hueco hasta el siguiente obstaculo (al menos una fila libre).
		y += 2 + (1 if rng.random() > d else 0) + (1 if rng.random() < 0.3 else 0)
	return ["".join(f) for f in filas]

## << genero corredor


## >> genero serpiente
def parametros_serpiente(i: int, n: int, dificultad: str, ajuste: float = 0.0, semilla: int = 0, tuneles: bool = False) -> dict:
	"""Frutas del objetivo, segundos por casilla, par de tiempo y semilla de las frutas (y wrap con
	el giro tuneles)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	meta = 8 + 3 * min(i, 6)
	paso = round(0.2 - 0.07 * d, 3)
	out = {"goal": meta, "step": paso, "par": round(meta * 7 * paso * 1.35 + 3.0, 1), "seed": 500 + 97 * i + semilla % 991}
	if tuneles:
		out["wrap"] = True
	return out


def serpiente_paso(y: int, x: int, dy: int, dx: int, h: int, w: int, tuneles: bool) -> tuple:
	"""Casilla siguiente (como step() de kit/snake/snake_map.gd): con tuneles, da la vuelta."""
	ny, nx = y + dy, x + dx
	if tuneles:
		ny, nx = ny % h, nx % w
	return ny, nx


def generar_serpiente(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero de 11x15 con borde de pared y obstaculos interiores (pilares, tabiques con hueco).
	Reglas de justicia (las mismas que comprueba kit/snake/snake_map.gd):
	1 - Todo el suelo conectado y la columna de salida libre.
	2 - Mas obstaculos con nivel y dificultad, pero siempre mucho sitio para crecer.
	3 - Unas monedas sueltas por el tablero.
	Giro tuneles (opciones["tuneles"]): huecos en el borde, por parejas enfrentadas."""
	tuneles = bool((opciones or {}).get("tuneles"))
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	w, h = 11, 15
	sx, sy = w // 2, h - 4
	for _ in range(80):
		g = [["#" if x in (0, w - 1) or y in (0, h - 1) else "." for x in range(w)] for y in range(h)]
		piezas = min(i, 3) + int(3 * d)
		for _ in range(piezas):
			if rng.random() < 0.5:
				x, y = rng.randint(2, w - 4), rng.randint(2, h - 6)
				for dy in (0, 1):
					for dx in (0, 1):
						g[y + dy][x + dx] = "#"
			else:
				y = rng.randint(3, h - 7)
				x0 = rng.randint(1, 3)
				x1 = rng.randint(w - 4, w - 2)
				hueco = rng.randint(x0 + 1, x1 - 1)
				for x in range(x0, x1 + 1):
					if abs(x - hueco) > 0:
						g[y][x] = "#"
		if tuneles:
			for y in rng.sample(range(2, h - 2), 2):
				g[y][0] = g[y][w - 1] = "."
				g[y][1] = g[y][w - 2] = "."
			for x in rng.sample([c for c in range(2, w - 2) if c != sx], 1):
				g[0][x] = g[h - 1][x] = "."
				g[1][x] = g[h - 2][x] = "."
		for dy in range(-2, 3):
			g[sy + dy][sx] = "."
		g[sy][sx] = "S"
		libres = [(y, x) for y in range(h) for x in range(w) if g[y][x] == "." and x != sx]
		rng.shuffle(libres)
		for y, x in libres[:3 + min(i, 3)]:
			g[y][x] = "C"
		filas = ["".join(f) for f in g]
		suelo = [(y, x) for y in range(h) for x in range(w) if filas[y][x] != "#"]
		visto = {suelo[0]}
		cola = [suelo[0]]
		while cola:
			y, x = cola.pop()
			for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				ny, nx = serpiente_paso(y, x, dy, dx, h, w, tuneles)
				if 0 <= ny < h and 0 <= nx < w and filas[ny][nx] != "#" and (ny, nx) not in visto:
					visto.add((ny, nx))
					cola.append((ny, nx))
		def abierta(y, x, dy, dx):
			ny, nx = serpiente_paso(y, x, dy, dx, h, w, tuneles)
			return 0 <= ny < h and 0 <= nx < w and filas[ny][nx] != "#"
		callejon = any(sum(1 for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)) if abierta(y, x, dy, dx)) <= 1 for y, x in suelo)
		if len(visto) == len(suelo) and not callejon:
			return filas
	return ["#" * w] + ["#" + "." * (w - 2) + "#" for _ in range(h - 2)] + ["#" * w]

## << genero serpiente


## >> genero memoria
def parametros_memoria(i: int, n: int, dificultad: str, ajuste: float = 0.0, semilla: int = 0, parejas: int = 8,
		barajar: bool = False) -> dict:
	"""Semilla del barajado, par de intentos (3 estrellas) y limite de intentos. Con el giro barajar
	(cartas que se cambian de sitio cada 2 fallos) hay mas margen de intentos."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	extra = 1.3 if barajar else 1.0
	out = {"seed": 300 + 131 * i + semilla % 997, "par": int(parejas * (1.75 - 0.15 * d) * extra + 0.999),
		"limit": int(parejas * (2.6 - 0.3 * d) * extra + 2.999)}
	if barajar:
		out["shuffle"] = True
	return out


def generar_memoria(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero de cartas: de 4x3 (6 parejas) a 6x6 (18) segun nivel y dificultad, a veces con
	huecos que dibujan una forma (siempre un numero par de cartas)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rng = random.Random(semilla)
	tallas = [(3, 4), (4, 4), (4, 5), (5, 4), (6, 4), (5, 6), (6, 6)]
	t = min(len(tallas) - 1, i + int(round(2 * d)))
	cols, filas = tallas[t]
	g = [["." for _ in range(cols)] for _ in range(filas)]
	## Formas: quitar esquinas a pares (sigue habiendo un numero par).
	if cols * filas >= 24 and rng.random() < 0.6:
		for (y, x) in [(0, 0), (0, cols - 1), (filas - 1, 0), (filas - 1, cols - 1)]:
			g[y][x] = "#"
	return ["".join(f) for f in g]

## << genero memoria


## >> genero cajas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- cajas (sokoban)
## Mapa: # muro, . suelo, P heroe, B caja, O hueco, Q caja ya en su hueco (y R heroe sobre hueco).

_DIRS4 = ((0, 1), (0, -1), (1, 0), (-1, 0))


def _sokoban_leer(mapa: list[str]) -> tuple[set, set, set, tuple]:
	muros, cajas, huecos, heroe = set(), set(), set(), (0, 0)
	for y, f in enumerate(mapa):
		for x, c in enumerate(f):
			if c == "#":
				muros.add((y, x))
			if c in "BQ":
				cajas.add((y, x))
			if c in "OQR":
				huecos.add((y, x))
			if c in "PR":
				heroe = (y, x)
	return muros, cajas, huecos, heroe


def _sokoban_zona(muros: set, cajas: frozenset, desde: tuple) -> set:
	vis = {desde}
	pila = [desde]
	while pila:
		y, x = pila.pop()
		for dy, dx in _DIRS4:
			n = (y + dy, x + dx)
			if n not in vis and n not in muros and n not in cajas:
				vis.add(n)
				pila.append(n)
	return vis


def _sokoban_muerta(muros: set, huecos: set) -> set:
	"""Casillas donde una caja ya no puede llegar a ningun hueco (se calcula tirando desde los huecos)."""
	vivas = set(huecos)
	pila = list(huecos)
	while pila:
		y, x = pila.pop()
		for dy, dx in _DIRS4:
			b = (y + dy, x + dx)          # la caja venia de aqui
			j = (y + 2 * dy, x + 2 * dx)  # y el heroe empujaba desde aqui
			if b not in vivas and b not in muros and j not in muros:
				vivas.add(b)
				pila.append(b)
	return vivas


def _cajas_fin(muros: set, cajas, b: tuple, d: tuple, hielo: bool) -> tuple:
	"""Donde acaba una caja empujada desde b hacia d (como slide_end de sokoban_map.gd): sin hielo una
	casilla; con hielo sigue hasta que lo siguiente sea muro o caja ('cajas' sin la que se mueve)."""
	e = (b[0] + d[0], b[1] + d[1])
	if not hielo:
		return e
	while True:
		n = (e[0] + d[0], e[1] + d[1])
		if n in muros or n in cajas or n[0] < 0 or n[1] < 0 or n[0] > 64 or n[1] > 64:
			return e
		e = n


def _cajas_rincon(muros: set, c: tuple) -> bool:
	y, x = c
	return (((y, x + 1) in muros or (y, x - 1) in muros) and ((y + 1, x) in muros or (y - 1, x) in muros))


def resolver_cajas(mapa: list[str], limite: int = 60000, hielo: bool = False) -> int | None:
	"""Empujes minimos para resolverlo (busqueda en anchura por empujes) o None si no tiene solucion.
	Con hielo (giro), las cajas resbalan hasta chocar (las mismas reglas que sokoban_map.gd)."""
	muros, cajas, huecos, heroe = _sokoban_leer(mapa)
	if not cajas or len(cajas) != len(huecos):
		return None
	if hielo:
		vivas = {c for c in _sokoban_zona(muros, frozenset(), heroe) if c in huecos or not _cajas_rincon(muros, c)}
	else:
		vivas = _sokoban_muerta(muros, huecos)
	if any(c not in vivas and c not in huecos for c in cajas):
		return None
	inicio = frozenset(cajas)
	zona = _sokoban_zona(muros, inicio, heroe)
	clave = (inicio, min(zona))
	vistos = {clave}
	frontera = [(inicio, zona)]
	empujes = 0
	while frontera and len(vistos) < limite:
		if any(cj == frozenset(huecos) for cj, _ in frontera):
			return empujes
		sig = []
		for cj, zn in frontera:
			for (by, bx) in cj:
				for dy, dx in _DIRS4:
					desde = (by - dy, bx - dx)
					uno = (by + dy, bx + dx)
					if desde not in zn or uno in muros or uno in cj:
						continue
					resto = cj - {(by, bx)}
					dest = _cajas_fin(muros, resto, (by, bx), (dy, dx), hielo)
					if dest not in vivas:
						continue
					nc = frozenset(resto | {dest})
					nz = _sokoban_zona(muros, nc, (by, bx))
					k = (nc, min(nz))
					if k not in vistos:
						vistos.add(k)
						sig.append((nc, nz))
		frontera = sig
		empujes += 1
	return None


def generar_cajas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Almacen con muros, cajas y huecos, hecho AL REVES: las cajas empiezan en sus huecos y el heroe
	las va arrastrando; asi siempre tiene solucion. Reglas (las mismas que kit/sokoban/sokoban_map.gd):
	1 - Tantas cajas como huecos (2 a 4), un heroe, todo rodeado de muro.
	2 - Tiene solucion y pide un minimo de empujes que sube con el nivel y la dificultad.
	3 - Ninguna caja empieza en su hueco ni en un sitio sin salida.
	Giro hielo (opciones["hielo"]): las cajas resbalan; se deshacen deslizamientos al reves y se
	comprueba con resolver_cajas(hielo=True)."""
	if (opciones or {}).get("hielo"):
		return _generar_cajas_hielo(i, n, dificultad, semilla, ajuste)
	rnd = random.Random(semilla)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	n_cajas = 2 + (1 if d > 0.35 else 0) + (1 if d > 0.75 else 0)
	ancho, alto = 7 + (1 if d > 0.5 else 0), 8 + (1 if d > 0.3 else 0)
	minimo = int(4 + 10 * d)
	mejor = None
	for _ in range(300):
		muros = {(y, x) for y in range(alto) for x in range(ancho) if y in (0, alto - 1) or x in (0, ancho - 1)}
		libres = [(y, x) for y in range(1, alto - 1) for x in range(1, ancho - 1)]
		for c in rnd.sample(libres, int(len(libres) * (0.1 + 0.08 * d))):
			muros.add(c)
		suelo = [c for c in libres if c not in muros]
		if len(suelo) < n_cajas * 4:
			continue
		if len(_sokoban_zona(muros, frozenset(), suelo[0])) != len(suelo):
			continue
		huecos = set(rnd.sample(suelo, n_cajas))
		cajas = set(huecos)
		heroe = rnd.choice([c for c in suelo if c not in cajas])
		for _paso in range(400 + int(400 * d)):
			dy, dx = rnd.choice(_DIRS4)
			sig = (heroe[0] + dy, heroe[1] + dx)
			if sig in muros or sig in cajas:
				continue
			detras = (heroe[0] - dy, heroe[1] - dx)
			if detras in cajas and rnd.random() < 0.7:
				cajas.discard(detras)
				cajas.add(heroe)
			heroe = sig
		if cajas & huecos:
			continue
		g = [["#" if (y, x) in muros else "." for x in range(ancho)] for y in range(alto)]
		for y, x in huecos:
			g[y][x] = "O"
		for y, x in cajas:
			g[y][x] = "B"
		g[heroe[0]][heroe[1]] = "R" if heroe in huecos else "P"
		mapa = ["".join(f) for f in g]
		pasos = resolver_cajas(mapa)
		if pasos is None:
			continue
		if pasos >= minimo:
			return mapa
		if mejor is None or pasos > mejor[0]:
			mejor = (pasos, mapa)
	if mejor:
		return mejor[1]
	return ["#######", "#.....#", "#.P...#", "#..B..#", "#..O..#", "#.B.O.#", "#.....#", "#######"]


def _generar_cajas_hielo(i: int, n: int, dificultad: str, semilla: int, ajuste: float = 0.0) -> list[str]:
	rnd = random.Random(semilla * 7 + 3)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	n_cajas = 1 + (1 if d > 0.25 else 0) + (1 if d > 0.7 else 0)
	ancho, alto = 7 + (1 if d > 0.5 else 0), 8 + (1 if d > 0.3 else 0)
	minimo = int(2 + 5 * d)
	mejor = None
	for _ in range(400):
		muros = {(y, x) for y in range(alto) for x in range(ancho) if y in (0, alto - 1) or x in (0, ancho - 1)}
		libres = [(y, x) for y in range(1, alto - 1) for x in range(1, ancho - 1)]
		for c in rnd.sample(libres, int(len(libres) * (0.12 + 0.08 * d))):
			muros.add(c)
		suelo = [c for c in libres if c not in muros]
		if len(suelo) < n_cajas * 5 or len(_sokoban_zona(muros, frozenset(), suelo[0])) != len(suelo):
			continue
		## Huecos donde una caja que resbala puede pararse (algo detras en alguna direccion).
		paradas = [c for c in suelo if any((c[0] + dy, c[1] + dx) in muros for dy, dx in _DIRS4) and not _cajas_rincon(muros, c)]
		if len(paradas) < n_cajas:
			continue
		huecos = set(rnd.sample(paradas, n_cajas))
		cajas = set(huecos)
		heroe = rnd.choice([c for c in suelo if c not in cajas])
		for _paso in range(60 + int(60 * d)):
			zona = _sokoban_zona(muros, frozenset(cajas), heroe)
			e = rnd.choice(sorted(cajas))
			dy, dx = rnd.choice(_DIRS4)
			if (e[0] + dy, e[1] + dx) not in muros and (e[0] + dy, e[1] + dx) not in cajas:
				continue
			## La caja vino resbalando desde b = e - k*d; el heroe empujo desde b - d.
			opciones_b = []
			b = (e[0] - dy, e[1] - dx)
			while b not in muros and b not in cajas:
				p = (b[0] - dy, b[1] - dx)
				if b in zona and p not in muros and p not in cajas and not _cajas_rincon(muros, b):
					opciones_b.append((b, p))
				b = (b[0] - dy, b[1] - dx)
			if not opciones_b:
				continue
			b, p = rnd.choice(opciones_b)
			cajas.discard(e)
			cajas.add(b)
			heroe = p
		if cajas & huecos:
			continue
		g = [["#" if (y, x) in muros else "." for x in range(ancho)] for y in range(alto)]
		for y, x in huecos:
			g[y][x] = "O"
		for y, x in cajas:
			g[y][x] = "B"
		g[heroe[0]][heroe[1]] = "R" if heroe in huecos else "P"
		mapa = ["".join(f) for f in g]
		pasos = resolver_cajas(mapa, hielo=True)
		if pasos is None:
			continue
		if pasos >= minimo:
			return mapa
		if mejor is None or pasos > mejor[0]:
			mejor = (pasos, mapa)
	if mejor:
		return mejor[1]
	return ["#######", "#.....#", "#.P...#", "#.....#", "#.B..O#", "#.....#", "#.....#", "#######"]


def parametros_cajas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0, hielo: bool = False) -> dict:
	"""Empujes de la mejor solucion (para las estrellas). Con el giro hielo, ice y su par con hielo."""
	par = resolver_cajas(mapa, hielo=hielo) if mapa else None
	out = {"par": int(par or 0)}
	if hielo:
		out["ice"] = True
	return out


## >> genero preguntas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- preguntas (quiz)

def reparto_preguntas(total: int, n: int) -> list[tuple[int, int]]:
	"""Trozos seguidos [desde, hasta) de la lista de preguntas para cada nivel (de facil a dificil)."""
	n = max(1, n)
	base, resto = divmod(total, n)
	out, k = [], 0
	for i in range(n):
		t = base + (1 if i < resto else 0)
		out.append((k, k + t))
		k += t
	return out


def generar_preguntas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""El 'mapa' de un nivel de preguntas es una fila con una Q por pregunta: las preguntas van en
	los parametros del nivel (parametros_preguntas), que las saca del diseno."""
	total = int((opciones or {}).get("n_preguntas", 0)) or 5 * n
	desde, hasta = reparto_preguntas(total, n)[i]
	return ["Q" * max(1, hasta - desde)]


def parametros_preguntas(i: int, n: int, dificultad: str, preguntas: list | None = None, semilla: int = 0, ajuste: float = 0.0) -> dict:
	"""Preguntas del nivel (respuestas barajadas siempre igual), tiempo por pregunta y aciertos para pasar."""
	rnd = random.Random(semilla + i * 101)
	qs = []
	for p in preguntas or []:
		orden = list(range(4))
		rnd.shuffle(orden)
		qs.append({"q": p["pregunta"], "a": [p["opciones"][k] for k in orden], "ok": orden.index(int(p["correcta"])),
			"why": p.get("explicacion", "")})
	base = {"facil": 26.0, "normal": 19.0, "dificil": 14.0}.get(dificultad, 19.0)
	tiempo = round(max(9.0, base - 1.5 * i / max(1, n - 1) * 2 - ajuste * 4.0), 1)
	return {"questions": qs, "time": tiempo, "pass": max(1, -(-len(qs) * 6 // 10))}


## >> genero apilar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- apilar (torre de bloques)

def _apilar(i: int, n: int, dificultad: str, ajuste: float) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	target = int(round(8 + 14 * d))
	speed = round(200 + 170 * d)
	ramp = round(0.012 + 0.02 * d, 3)
	while speed * (1 + ramp * target) > 800:
		ramp = round(ramp - 0.002, 3)
	return {"target": target, "speed": float(speed), "ramp": max(ramp, 0.0), "width": float(round(380 - 120 * d)),
		"perfect": round(12.0 - 6.0 * d, 1)}


def generar_apilar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""El 'mapa' es una fila con una S por bloque que hay que apilar (la altura del nivel)."""
	return ["S" * _apilar(i, n, dificultad, ajuste)["target"]]


def parametros_apilar(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Altura, velocidad (y cuanto sube por piso), ancho del primer bloque y margen de perfecto."""
	return _apilar(i, n, dificultad, ajuste)


## >> genero topos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- topos

FORMAS_TOPOS = [
	["ooo", "o.o", "ooo"],
	["ooo", "ooo"],
	["ooo", "ooo", "ooo"],
	[".o.", "ooo", ".o.", "ooo"],
	["ooo", "ooo", "ooo", "ooo"],
	["o.o", "ooo", "o.o", "ooo"],
]


def _topos(i: int, n: int, dificultad: str, ajuste: float) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	duracion = 35.0 + 10.0 * d
	intervalo = round(1.0 - 0.42 * d, 2)
	amigo = round(0.08 + 0.12 * d, 2)
	esperado = duracion / intervalo * (1.0 - amigo) * 0.9
	return {"duration": duracion, "interval": intervalo, "pop": round(1.55 - 0.7 * d, 2), "max_up": 1 + int(d * 2.2),
		"friend": amigo, "target": int(esperado / 1.6)}


def generar_topos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Campo de agujeros ("o"): mas agujeros segun avanza el juego (mas sitios donde mirar)."""
	rnd = random.Random(semilla)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	tope = 2 + int(d * (len(FORMAS_TOPOS) - 2))
	return list(FORMAS_TOPOS[rnd.randint(max(0, tope - 2), min(tope, len(FORMAS_TOPOS) - 1))])


def parametros_topos(i: int, n: int, dificultad: str, ajuste: float = 0.0, dorado: bool = False) -> dict:
	"""Tiempo, cada cuanto asoman, cuanto se quedan, cuantos a la vez, cuanto asoma el heroe y golpes para ganar.
	Giro dorado: a veces asoma un bicho de oro que vale 3 golpes (golden)."""
	out = _topos(i, n, dificultad, ajuste)
	if dorado:
		out["golden"] = True
	return out


## >> genero saltos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- saltos (salto vertical)

def _saltos_cfg(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def generar_saltos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Torre de 9 columnas que se sube rebotando. Se construye de abajo arriba un camino seguro:
	cada plataforma del camino esta a 1-3 filas de la anterior y a 3 columnas como mucho (los lados
	se tocan). Encima del camino: monedas; alrededor: plataformas de adorno (algunas se rompen),
	moviles, muelles y enemigos solo fuera del camino. Reglas en kit/jumper/jumper_map.gd."""
	rnd = random.Random(semilla)
	d = _saltos_cfg(i, n, dificultad, ajuste)
	alto = int(32 + 22 * d)
	g = [["." for _ in range(9)] for _ in range(alto)]
	fila = lambda r: alto - 1 - r  # noqa: E731 - r = filas desde abajo
	col = 4
	g[fila(0)][col] = "P"
	camino = {(0, col)}
	r = 0
	while True:
		hueco = rnd.randint(1, 2 if d < 0.4 else 3)
		if r + hueco >= alto - 2:
			break
		r += hueco
		col = (col + rnd.randint(-3, 3)) % 9
		tipo = "="
		x = rnd.random()
		if x < 0.15 + 0.2 * d:
			tipo = "~"
		elif x < 0.2 + 0.3 * d:
			tipo = "x"
		elif x < 0.24 + 0.32 * d and r + 9 < alto - 2:
			tipo = "^"
		g[fila(r)][col] = tipo
		camino.add((r, col))
		if tipo == "^":
			r += rnd.randint(4, 7)
			col = (col + rnd.randint(-2, 2)) % 9
			g[fila(r)][col] = "="
			camino.add((r, col))
		if rnd.random() < 0.45 and r + 1 < alto - 2 and g[fila(r + 1)][col] == ".":
			g[fila(r + 1)][col] = "C"
	## Meta: fila de arriba, al alcance del ultimo escalon.
	if (alto - 1) - r > 3:
		r2 = alto - 4
		g[fila(r2)][col] = "="
	g[0] = list("....G....")
	## Adornos: plataformas extra, algunas rompibles, y enemigos lejos del camino.
	for rr in range(2, alto - 2):
		if rnd.random() < 0.35 - 0.15 * d:
			c = rnd.randrange(9)
			bajo_enemigo = any(g[fila(rr + k)][(c + dc) % 9] == "E" for k in (1, 2, 3) if rr + k < alto for dc in (-1, 0, 1))
			if not bajo_enemigo and g[fila(rr)][c] == "." and all(g[fila(rr + k)][c] == "." for k in (-1, 1)):
				g[fila(rr)][c] = "x" if rnd.random() < 0.3 + 0.3 * d else "="
		if rnd.random() < 0.06 + 0.1 * d and rr > 4:
			c = rnd.randrange(9)
			lejos = all(min(abs(c - cc), 9 - abs(c - cc)) >= 3 for (r3, cc) in camino if abs(r3 - rr) <= 2)
			## Nada que se pueda pisar justo debajo (el rebote siguiente se lo comeria).
			debajo = all(g[fila(rr - k)][(c + dc) % 9] == "." for k in (1, 2, 3) if rr - k >= 0 for dc in (-1, 0, 1))
			if lejos and debajo and g[fila(rr)][c] == "." and g[fila(rr + 1)][c] == ".":
				g[fila(rr)][c] = "E"
	return ["".join(f) for f in g]


## >> genero arena (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- arena (todos contra todos)

def _arena_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def _arena_rivales(d: float) -> int:
	return min(5, 2 + int(d * 3.2))


def generar_arena(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Arena simetrica vista desde arriba: # muro, * arbusto, B caja, P tu salida (abajo en el centro),
	R rivales (arriba y a los lados). Reglas de justicia (las de kit/brawl/brawl_map.gd):
	1 - Se llega andando a todos los rivales y a todas las cajas (las cajas cuentan como muro).
	2 - Las salidas tienen sus vecinas libres y ningun rival sale a menos de 4 casillas de ti.
	3 - Al menos la mitad de la arena es suelo libre; mas muros, cajas y rivales segun avanza."""
	rnd = random.Random(semilla)
	d = _arena_d(i, n, dificultad, ajuste)
	ancho = 13 + 2 * int(d * 2.0)
	alto = 19 + 2 * int(d * 3.0)
	mitad = ancho // 2
	rivales = _arena_rivales(d)
	salida = (alto - 2, mitad)
	puestos = [(1, mitad), (2, 1), (2, ancho - 2), (alto // 2 - 1, 1), (alto // 2 - 1, ancho - 2)][:rivales]
	reservado = set()
	for (y, x) in [salida] + puestos:
		for dy in (-1, 0, 1):
			for dx in (-1, 0, 1):
				reservado.add((y + dy, x + dx))
	formas = [[(0, 0), (0, 1)], [(0, 0), (1, 0)], [(0, 0), (0, 1), (1, 0), (1, 1)], [(0, 0), (1, 0), (2, 0)],
		[(0, 0), (0, 1), (0, 2)], [(0, 0), (1, 0), (1, 1)]]
	for _ in range(300):
		g = [["." for _ in range(ancho)] for _ in range(alto)]

		def poner(y: int, x: int, ch: str) -> bool:
			"""Pone ch en (y, x) y en su espejo; no pisa lo reservado ni lo ya puesto."""
			for (yy, xx) in {(y, x), (y, ancho - 1 - x)}:
				if not (0 <= yy < alto and 0 <= xx < ancho) or (yy, xx) in reservado or g[yy][xx] != ".":
					return False
			g[y][x] = ch
			g[y][ancho - 1 - x] = ch
			return True

		for _m in range(int(4 + 4 * d + i % 3)):
			f = rnd.choice(formas)
			y0, x0 = rnd.randint(2, alto - 4), rnd.randint(0, mitad - 1)
			if all(0 <= y0 + dy < alto and 0 <= x0 + dx <= mitad - 1 and (y0 + dy, x0 + dx) not in reservado
					and g[y0 + dy][x0 + dx] == "." for dy, dx in f):
				for dy, dx in f:
					poner(y0 + dy, x0 + dx, "#")
		for _a in range(3 + int(2 * d)):
			y0, x0 = rnd.randint(1, alto - 3), rnd.randint(0, mitad - 1)
			for dy in range(rnd.randint(1, 2) + 1):
				for dx in range(2):
					if x0 + dx <= mitad:
						poner(y0 + dy, min(x0 + dx, mitad), "*")
		cajas = 0
		for _c in range(40):
			if cajas >= 2 + int(3 * d):
				break
			y0, x0 = rnd.randint(3, alto - 5), rnd.randint(1, mitad - 1)
			if poner(y0, x0, "B"):
				cajas += 1
		g[salida[0]][salida[1]] = "P"
		for (y, x) in puestos:
			g[y][x] = "R"
		filas = ["".join(f) for f in g]
		## Alcance desde la salida (muros y cajas cortan el paso).
		visto = {salida}
		cola = [salida]
		while cola:
			y, x = cola.pop()
			for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				ny, nx = y + dy, x + dx
				if 0 <= ny < alto and 0 <= nx < ancho and (ny, nx) not in visto and filas[ny][nx] not in "#B":
					visto.add((ny, nx))
					cola.append((ny, nx))
		cajas_ok = all(any((y + dy, x + dx) in visto for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)))
			for y in range(alto) for x in range(ancho) if filas[y][x] == "B")
		if all(p in visto for p in puestos) and cajas_ok and len(visto) >= ancho * alto * 0.5:
			return filas
	filas = ["." * ancho for _ in range(alto)]
	filas[salida[0]] = "." * mitad + "P" + "." * (ancho - mitad - 1)
	for (y, x) in puestos:
		filas[y] = filas[y][:x] + "R" + filas[y][x + 1:]
	return filas


def parametros_arena(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Vida, dano, punteria y reflejos de los rivales; cuando llega el gas y en cuanto se cierra."""
	d = _arena_d(i, n, dificultad, ajuste)
	rivales = _arena_rivales(d)
	return {"rival_hp": int(round((2000 + 1500 * d) / 100.0)) * 100, "rival_dmg": round(0.55 + 0.35 * d, 2),
		"aim": round(0.32 - 0.18 * d, 2), "reaction": round(0.7 - 0.3 * d, 2),
		"gas_start": round(45.0 - 12.0 * d), "gas_time": round(40.0 - 10.0 * d), "par": 10 * rivales + 15}
## << genero arena


## >> genero aldea (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- aldea (asalto a una base)

def _aldea_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


TAM_ALDEA = {"H": 3, "G": 2, "E": 2, "M": 2, "K": 2, "C": 2, "A": 2, "O": 2}


def generar_aldea(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Base enemiga vista desde arriba (las reglas en kit/village/village_map.gd):
	1 - Ayuntamiento (H, 3x3) en el centro; almacenes (G oro, E elixir) cerca; defensas (C canon,
	    A torre arquera, O mortero) alrededor; minas (M) y casas (K) por fuera. Todo 2x2.
	2 - Siempre una casilla libre entre edificios (las tropas pasan) y 3 de borde para desplegar.
	3 - Con mas dificultad: mas defensas, mortero y una muralla alrededor del centro (con huecos
	    al principio, cerrada al final)."""
	rnd = random.Random(semilla)
	d = _aldea_d(i, n, dificultad, ajuste)
	lado = 16 + 2 * int(d * 2.0)
	c = lado // 2
	for _ in range(200):
		g = [["." for _ in range(lado)] for _ in range(lado)]
		huella: dict[tuple[int, int], str] = {}

		def libre(x: int, y: int, s: int, hueco: int = 1) -> bool:
			if x < 3 or y < 3 or x + s > lado - 3 or y + s > lado - 3:
				return False
			return all((xx, yy) not in huella for yy in range(y - hueco, y + s + hueco) for xx in range(x - hueco, x + s + hueco))

		def poner(letra: str, x: int, y: int) -> None:
			s = TAM_ALDEA[letra]
			g[y][x] = letra
			for yy in range(y, y + s):
				for xx in range(x, x + s):
					huella[(xx, yy)] = letra

		def colocar(letra: str, r0: float, r1: float) -> bool:
			s = TAM_ALDEA[letra]
			sitios = [(x, y) for y in range(3, lado - 3 - s + 1) for x in range(3, lado - 3 - s + 1)
				if r0 <= ((x + s / 2 - c) ** 2 + (y + s / 2 - c) ** 2) ** 0.5 <= r1 and libre(x, y, s)]
			if not sitios:
				return False
			x, y = rnd.choice(sitios)
			poner(letra, x, y)
			return True

		poner("H", c - 1, c - 1)
		ok = colocar("G", 2.5, 4.5) and colocar("E", 2.5, 4.5)
		defensas = ["C", "A"] + (["O"] if d > 0.35 else []) + ["C", "A", "C", "O", "A"]
		for letra in defensas[:3 + int(d * 4.0)]:
			ok = ok and colocar(letra, 3.0, 6.0)
		for letra in ["M"] + (["M"] if d > 0.5 else []) + ["K"] * (1 + int(d * 2)):
			colocar(letra, 4.5, 8.0)
		if not ok:
			continue
		## Muralla alrededor del centro (ayuntamiento y almacenes).
		if d > 0.25:
			nucleo = [(x, y) for (x, y), l in huella.items() if l in "HGE"]
			x0 = min(x for x, _ in nucleo) - 1
			x1 = max(x for x, _ in nucleo) + 1
			y0 = min(y for _, y in nucleo) - 1
			y1 = max(y for _, y in nucleo) + 1
			borde = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if x in (x0, x1) or y in (y0, y1)]
			huecos = 0 if d > 0.6 else 2
			for (x, y) in borde:
				if (x, y) not in huella and 3 <= x < lado - 3 and 3 <= y < lado - 3:
					g[y][x] = "#"
			cerca = [(x, y) for (x, y) in borde if g[y][x] == "#"]
			rnd.shuffle(cerca)
			for (x, y) in cerca[:huecos]:
				g[y][x] = "."
		return ["".join(f) for f in g]
	filas = ["." * lado for _ in range(lado)]
	filas[c - 1] = "." * (c - 1) + "H" + "." * (lado - c)
	filas[3] = "...C" + "." * (lado - 4)
	return filas


def parametros_aldea(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Ejercito para el asalto, vida de los edificios, dano de las defensas y tiempo."""
	d = _aldea_d(i, n, dificultad, ajuste)
	ejercito = {"guerrero": 9 + int(5 * d), "arquera": 6 + int(5 * d)}
	if d > 0.25:
		ejercito["gigante"] = 1 + int(d * 3)
	return {"army": ejercito, "seconds": 150, "base_hp": round(0.9 + 0.4 * d, 2), "def_dmg": round(0.9 + 0.4 * d, 2)}
## << genero aldea


## >> genero ritmo (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- ritmo (notas en 4 carriles)

def _ritmo_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def parametros_ritmo(i: int, n: int, dificultad: str, ajuste: float = 0.0, invisibles: bool = False) -> dict:
	"""Tempo, velocidad de caida, aciertos para pasar y energia (cada fallo quita 2). Con el giro
	invisibles (las notas se apagan antes de la linea) se pide algo menos y hay mas energia."""
	d = _ritmo_d(i, n, dificultad, ajuste)
	out = {"bpm": int(92 + 48 * d), "speed": int(720 + 520 * d), "target": round(0.6 + 0.2 * d, 2), "energy": 12 - int(4 * d)}
	if invisibles:
		out.update(hidden=True, target=round(max(0.5, out["target"] - 0.08), 2), energy=out["energy"] + 2)
	return out


def generar_ritmo(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Cancion en corcheas: una fila por paso, 4 carriles ("x" nota). Se compone por frases de 8
	pasos que se repiten con variaciones (asi suena a musica y se aprende). Reglas de justicia (las
	mismas que comprueba kit/rhythm/rhythm_map.gd): 2 notas a la vez como mucho, al menos 0,2 s
	entre notas del mismo carril, entre 16 y 400 notas. Mas densa y con mas acordes al subir."""
	rnd = random.Random(semilla)
	d = _ritmo_d(i, n, dificultad, ajuste)
	bpm = parametros_ritmo(i, n, dificultad, ajuste)["bpm"]
	paso = 30.0 / bpm
	minimo = max(1, math.ceil(0.2 / paso))
	frases = 10 + int(8 * d)
	filas: list[str] = ["...."] * 4
	ultimo = [-99] * 4

	def frase() -> list[list[int]]:
		f = []
		for k in range(8):
			negra = k % 2 == 0
			p_nota = (0.75 if negra else 0.12 + 0.45 * d)
			if rnd.random() < p_nota:
				carriles = [rnd.randrange(4)]
				if negra and rnd.random() < 0.08 + 0.3 * d:
					carriles.append(rnd.randrange(4))
				f.append(sorted(set(carriles)))
			else:
				f.append([])
		return f

	motivo = frase()
	for k in range(frases):
		if k % 2 == 1 and rnd.random() < 0.7:
			actual = [list(x) for x in motivo]
			## Variacion: se desplaza de carril una nota de la frase.
			j = rnd.randrange(8)
			if actual[j]:
				actual[j] = [(actual[j][0] + rnd.choice([1, 3])) % 4]
		else:
			motivo = frase()
			actual = motivo
		for notas in actual:
			fila = ["."] * 4
			for c in notas:
				## Mismo carril demasiado pronto: se mueve a otro libre o se quita.
				if len(filas) - ultimo[c] < minimo:
					libres = [x for x in range(4) if len(filas) - ultimo[x] >= minimo and fila[x] == "."]
					if not libres:
						continue
					c = rnd.choice(libres)
				fila[c] = "x"
				ultimo[c] = len(filas)
			filas.append("".join(fila))
	filas += ["...."] * 4
	return filas
## << genero ritmo


## >> genero clicker (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- clicker (toca y contrata ayudantes)

def _clicker_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def _clicker_ayudantes(i: int, n: int, dificultad: str, ajuste: float) -> list[tuple[float, float]]:
	d = _clicker_d(i, n, dificultad, ajuste)
	tipos = 3 + int(round(2 * d)) + (1 if i >= 3 else 0)
	return [(float(round(15 * 5 ** k)), float(round(1 * 4.5 ** k, 1))) for k in range(min(tipos, 6))]


def simular_clicker(ayudantes: list[tuple[float, float]], toque: float, limite: float) -> list[float]:
	"""La misma estrategia que kit/idle/idle_map.gd (4 toques/s, compra lo que mas renta).
	Devuelve lo ganado en cada cuarto de segundo hasta el limite."""
	hs = [{"cost": c, "cps": g, "owned": 0} for c, g in ayudantes]
	bank = earned = 0.0
	tapv, nivel, t, dt = toque, 0, 0.0, 0.25
	curva = []
	while t < limite:
		rate = tapv * 4.0 + sum(h["cps"] * h["owned"] for h in hs)
		bank += rate * dt
		earned += rate * dt
		t += dt
		curva.append(earned)
		best, ratio = -2, 0.0
		for k, h in enumerate(hs):
			coste = math.ceil(h["cost"] * 1.15 ** h["owned"])
			if coste <= bank and h["cps"] / coste > ratio:
				best, ratio = k, h["cps"] / coste
		coste_toque = math.ceil(40.0 * toque * 2.5 ** nivel)
		if coste_toque <= bank and tapv * 4.0 / coste_toque > ratio:
			best = -1
		if best == -1:
			bank -= coste_toque
			nivel += 1
			tapv = toque * 2 ** nivel
		elif best >= 0:
			bank -= math.ceil(hs[best]["cost"] * 1.15 ** hs[best]["owned"])
			hs[best]["owned"] += 1
	return curva


def parametros_clicker(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Tiempo y meta: la meta es lo que junta una persona normal (4 toques/s) en el 70 % del
	tiempo (el analizador exige que llegue antes del 80 %)."""
	d = _clicker_d(i, n, dificultad, ajuste)
	duracion = float(int(60 + 40 * d + 10 * min(i, 4)))
	curva = simular_clicker(_clicker_ayudantes(i, n, dificultad, ajuste), 1.0, duracion)
	meta = curva[int(len(curva) * 0.7) - 1]
	## Redondeo bonito hacia abajo (asi nunca pide mas que la simulacion).
	escala = 10 ** max(0, len(str(int(meta))) - 2)
	return {"duration": duracion, "tap": 1.0, "target": float(int(meta // escala * escala))}


def generar_clicker(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Una fila por ayudante, "coste:ganancia por segundo": cada uno 5 veces mas caro y 4,5 veces
	mas rentable que el anterior (los caros salen a cuenta pero tardan en llegar). Mas tipos de
	ayudante segun avanza el juego. Reglas en kit/idle/idle_map.gd."""
	return ["%d:%s" % (int(c), ("%g" % g)) for c, g in _clicker_ayudantes(i, n, dificultad, ajuste)]
## << genero clicker


## >> genero cartas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- cartas (solitario Golf)

RANGOS_CARTAS = "A23456789TJQK"


def _cartas_vecinas(a: int, b: int) -> bool:
	d = abs(a - b)
	return d == 1 or d == 12


def resolver_cartas(cols: list[list[int]], mazo: list[int], max_nodos: int = 60000) -> list[int] | None:
	"""El mismo buscador que kit/cards/cards_logic.gd (columnas mas altas primero; -1 = mazo)."""
	alturas = [len(c) for c in cols]
	visto: set = set()
	camino: list[int] = []
	nodos = [0]

	def dfs(sig: int, arriba: int) -> bool:
		if sum(alturas) == 0:
			return True
		nodos[0] += 1
		if nodos[0] > max_nodos:
			return False
		clave = (tuple(alturas), sig, arriba)
		if clave in visto:
			return False
		visto.add(clave)
		for k in sorted(range(len(alturas)), key=lambda x: -alturas[x]):
			if alturas[k] and _cartas_vecinas(cols[k][alturas[k] - 1], arriba):
				carta = cols[k][alturas[k] - 1]
				alturas[k] -= 1
				camino.append(k)
				if dfs(sig, carta):
					return True
				camino.pop()
				alturas[k] += 1
		if sig < len(mazo):
			camino.append(-1)
			if dfs(sig + 1, mazo[sig]):
				return True
			camino.pop()
		return False

	return list(camino) if dfs(1, mazo[0]) else None


def _cartas_avariciosa(cols: list[list[int]], mazo: list[int]) -> bool:
	alturas = [len(c) for c in cols]
	arriba, sig = mazo[0], 1
	while True:
		for k in range(len(alturas)):
			if alturas[k] and _cartas_vecinas(cols[k][alturas[k] - 1], arriba):
				alturas[k] -= 1
				arriba = cols[k][alturas[k]]
				break
		else:
			if sig >= len(mazo):
				break
			arriba, sig = mazo[sig], sig + 1
	return sum(alturas) == 0


def generar_cartas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Reparto de una baraja de 52: 7 columnas (4 cartas al principio, 5 despues) y el resto al
	mazo; cuanto mas dificil, menos cartas en el mazo. Se buscan repartos CON solucion que no salgan
	jugando a ciegas (mismas reglas que kit/cards/cards_map.gd)."""
	rnd = random.Random(semilla)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	alto = 4 if d < 0.3 else 5
	mazo_max = 52 - 7 * alto
	recorte = int(round(6 * d))
	ultimo = None
	for _ in range(400):
		baraja = [r for r in range(1, 14) for _ in range(4)]
		rnd.shuffle(baraja)
		cols = [baraja[x * alto:(x + 1) * alto] for x in range(7)]
		mazo = baraja[7 * alto:7 * alto + mazo_max - recorte]
		ultimo = (cols, mazo)
		if _cartas_avariciosa(cols, mazo):
			continue
		if resolver_cartas(cols, mazo) is not None:
			break
	cols, mazo = ultimo
	filas = ["".join(RANGOS_CARTAS[cols[x][y] - 1] for x in range(7)) for y in range(alto)]
	return filas + ["S" + "".join(RANGOS_CARTAS[r - 1] for r in mazo)]
## << genero cartas


## >> genero rpg (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- rpg (combates por turnos)

ENEMIGOS_RPG = {"W": (40.0, 8.0, 0.0), "S": (34.0, 6.0, 4.0), "F": (24.0, 11.0, 0.0), "B": (120.0, 9.0, 0.0)}


def simular_rpg(oleadas: list[str], vida: float, ataque: float, pociones: int, mult: float,
		pesimista: bool = False) -> tuple[bool, float]:
	"""Misma partida que TurnsLogic.simulate (kit/turns/turns_logic.gd): politica sensata y dano
	medio (o mala suerte: tu pegas un 10 % menos y ellos un 10 % mas). Devuelve (gana, vida en
	proporcion)."""
	hp, energia, pots, guard = vida, 0, pociones, False
	ataque = ataque * (0.9 if pesimista else 1.0)
	refuerzo = 1.1 if pesimista else 1.0
	for w, fila in enumerate(oleadas):
		if w > 0:
			hp = min(vida, hp + vida * 0.1)
		en = [{"k": c, "hp": ENEMIGOS_RPG[c][0] * mult, "atk": ENEMIGOS_RPG[c][1] * mult, "th": ENEMIGOS_RPG[c][2], "carga": 0}
			for c in fila]
		turnos = 0
		while any(e["hp"] > 0 for e in en):
			turnos += 1
			if turnos > 200:
				return False, 0.0
			vivos = [e for e in en if e["hp"] > 0]
			pesado = any(e["k"] == "B" and e["carga"] % 3 == 2 for e in vivos)
			guard = False
			if hp < vida * 0.35 and pots > 0 and hp < vida:
				pots -= 1
				hp = min(vida, hp + vida * 0.4)
			elif pesado:
				energia = min(energia + 1, 3)
				guard = True
			elif len(vivos) >= 2 and energia >= 2:
				energia -= 2
				for e in vivos:
					e["hp"] -= ataque * 0.7
			else:
				t = min(vivos, key=lambda e: e["hp"])
				energia = min(energia + 1, 3)
				t["hp"] -= ataque
				hp -= t["th"]
			if hp <= 0:
				return False, 0.0
			if not any(e["hp"] > 0 for e in en):
				break
			for e in en:
				if e["hp"] <= 0:
					continue
				d = e["atk"] * refuerzo
				if e["k"] == "B":
					e["carga"] += 1
					if e["carga"] % 3 == 0:
						d *= 2
				hp -= d * (0.5 if guard else 1.0)
			if hp <= 0:
				return False, 0.0
	return True, hp / vida


def _rpg_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def parametros_rpg(i: int, n: int, dificultad: str, ajuste: float = 0.0, estilos: list[str] | None = None) -> dict:
	"""Vida y ataque del heroe, pociones y fuerza de los enemigos (sube con el nivel). Con estilo
	(giros equipo o criaturas) va en modo equipo: "rpg" con el preset del kit (TurnsParty), el
	equipo sube de nivel con el juego y los enemigos un poco mas segun la dificultad."""
	d = _rpg_d(i, n, dificultad, ajuste)
	out = {"hero_hp": 100.0, "hero_atk": 20.0, "potions": 3 - int(round(1.5 * d)), "mult": round(0.85 + 0.2 * d + 0.03 * i, 2)}
	presets = [ESTILO_RPG[e] for e in (estilos or []) if e in ESTILO_RPG]
	if presets:
		out["rpg"] = {"preset": presets[:1]}
		out["hero_level"] = 1 + i
		## Con cuatro heroes (equipo) los enemigos van mas fuertes.
		out["mult"] = round((0.9 + 0.25 * d + 0.06 * i) * (1.4 if "equipo" in presets else 1.0), 2)
		out["potions"] = 2 if d < 0.6 else 1
	return out


## Giro de la fabrica -> estilo del kit (PRESETS en kit/turns/turns_party.gd).
ESTILO_RPG = {"equipo": "equipo", "criaturas": "criaturas"}


def _rpg_equipo(i: int, n: int, dificultad: str, semilla: int, ajuste: float, estilos: list[str],
		contenido: dict | None = None) -> list[str]:
	"""Oleadas del modo equipo: con criaturas (uno contra uno), equipos rivales de 1 a 3; si no,
	grupos de 1 a 4 que crecen, chamanes y espinosos mas adelante y el jefe con escolta al final.
	El analizador del kit (TurnsParty.analyze) juega cada nivel con la misma cabeza."""
	rnd = random.Random(semilla)
	d = _rpg_d(i, n, dificultad, ajuste)
	criaturas = "criaturas" in estilos
	if criaturas:
		n_olas = 2 + min(2, i // 2)
		tipos = ["W", "F", "S", "M"][:2 + min(2, i)]
		olas = ["".join(rnd.choice(tipos) for _ in range(1 + (1 if w >= 1 and (i >= 2 or d > 0.5) else 0))) for w in range(n_olas)]
	else:
		n_olas = min(5, 2 + min(2, i // 2) + (1 if d > 0.6 else 0))
		tipos = ["W", "F"] + (["S"] if i >= 1 else []) + (["M"] if i >= 2 else []) + (["N", "L"] if "equipo" in estilos and i >= 3 else [])
		grande = 2 + (1 if d > 0.4 else 0) + (1 if "equipo" in estilos and i >= 3 else 0)
		olas = []
		for w in range(n_olas):
			tam = max(1, min(grande, 1 + int((w + 1) / n_olas * grande) + rnd.randint(-1, 0)))
			olas.append("".join(rnd.choice(tipos) for _ in range(tam)))
	if i == n - 1 or (n >= 4 and i == n // 2):
		olas[-1] = "B" if (d < 0.5 or criaturas) else "B" + rnd.choice(tipos)
	## Justo y con chicha: se juega con la misma simulacion que el analizador; demasiado duro,
	## fuera un enemigo; demasiado facil, uno mas (o uno mas fuerte). Vida que queda al acabar:
	## del 75 % en lo facil al 35 % en lo dificil.
	from niveles import rpg_equipo
	p = parametros_rpg(i, n, dificultad, ajuste, estilos)
	if contenido:
		## Lo inventado por la IA encima del estilo: se juega con eso.
		p["rpg"] = {**contenido, "preset": p["rpg"]["preset"]}
	alto = 0.8 - 0.4 * d
	bajo = max(0.27, alto - 0.3)
	maximo = 2 if criaturas else (4 if "equipo" in estilos else 3)
	fuertes = [t for t in ("M", "S", "F") if t in tipos]
	bueno = None
	for _ in range(40):
		lv = {**p, "map": olas}
		r = rpg_equipo.simular(lv)
		malo = rpg_equipo.simular(lv, True)
		if r["won"] and malo["won"] and r["hp_left"] >= bajo:
			bueno = list(olas)
			if r["hp_left"] <= alto:
				break
			## Facil de mas: un enemigo mas en la oleada mas pequena (o uno mas fuerte).
			k = min(range(len(olas)), key=lambda x: (len(olas[x].replace("B", "BBB")), x))
			if len(olas[k]) < maximo and "B" not in olas[k]:
				olas[k] += rnd.choice(tipos)
			elif "W" in "".join(olas) and fuertes:
				k2 = next(x for x in range(len(olas)) if "W" in olas[x])
				olas[k2] = olas[k2].replace("W", rnd.choice(fuertes), 1)
			elif len(olas) < (4 if criaturas else 5):
				olas.insert(len(olas) - 1, rnd.choice(tipos))
			else:
				break
			continue
		k = max(range(len(olas)), key=lambda x: (len(olas[x]), x))
		if len(olas[k]) > 1:
			olas[k] = olas[k][:-1] if olas[k][-1] != "B" else olas[k][1:]
		elif len(olas) > 2:
			olas.pop(0 if olas[0] != "B" else 1)
		elif "B" in olas:
			olas[olas.index("B")] = "W"
		else:
			break
		## Ya hubo uno bueno y al subir se paso: se queda el bueno.
		if bueno is not None:
			break
	return bueno if bueno is not None else olas


def generar_rpg(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Oleadas de 1 a 3 enemigos (W normal, S pinchos, F rapido) que crecen; el jefe (B) en la
	ultima oleada del ultimo nivel y en algun nivel intermedio. Se comprueba con la misma
	simulacion que el analizador (kit/turns/turns_map.gd): ganar con al menos un 25 % de vida;
	si no, se quita un enemigo de la oleada mas dura."""
	estilos = [e for e in ((opciones or {}).get("estilos_rpg") or []) if e in ESTILO_RPG]
	if estilos:
		return _rpg_equipo(i, n, dificultad, semilla, ajuste, estilos, (opciones or {}).get("contenido_rpg"))
	rnd = random.Random(semilla)
	d = _rpg_d(i, n, dificultad, ajuste)
	p = parametros_rpg(i, n, dificultad, ajuste)
	n_olas = min(7, 2 + int(round(2 * d)) + min(i, 2))
	tipos = ["W"] + (["F"] if i >= 1 or d > 0.3 else []) + (["S"] if i >= 2 or d > 0.5 else [])
	olas = []
	for w in range(n_olas):
		tam = max(1, min(3, 1 + int((w + 1) / n_olas * (1.5 + 1.5 * d)) + rnd.randint(-1, 0)))
		olas.append("".join(rnd.choice(tipos) for _ in range(tam)))
	jefe = i == n - 1 or (n >= 4 and i == n // 2)
	if jefe:
		olas[-1] = "B" if d < 0.5 else "B" + rnd.choice(tipos)
	for _ in range(30):
		gana, queda = simular_rpg(olas, p["hero_hp"], p["hero_atk"], p["potions"], p["mult"])
		gana_mal, _ = simular_rpg(olas, p["hero_hp"], p["hero_atk"], p["potions"], p["mult"], True)
		if gana and queda >= 0.25 and gana_mal:
			break
		## Lo mas facil de arreglar: quitar el ultimo enemigo de la oleada mas grande que no sea el jefe solo.
		k = max(range(len(olas)), key=lambda x: (len(olas[x]), x))
		if len(olas[k]) > 1:
			olas[k] = olas[k][:-1]
		elif len(olas) > 2:
			olas.pop(0 if olas[0] != "B" else 1)
		elif "B" in olas:
			## Ultimo recurso: el jefe deja paso a dos normales (el nivel tiene que ser justo).
			olas[olas.index("B")] = "WW"
		else:
			break
	return olas
## << genero rpg


## >> genero laberinto (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_laberinto(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Laberinto de pasillos visto desde arriba: # roca, . suelo, P salida, C moneda, X pinchos,
	L llave, D puerta. Reglas de justicia (las mismas que kit/maze/maze_map.gd):
	1 - Pasillos tallados (busqueda en profundidad) con algunos atajos; salida abajo.
	2 - Desde el nivel 2 (o antes si es dificil) una puerta corta el laberinto en dos: la llave
	    esta en la parte abierta y hay monedas detras de la puerta.
	3 - Los pinchos nunca cortan el camino: todas las monedas se alcanzan sin pisarlos."""
	rnd = random.Random(semilla)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho = 7 if i < 2 else 9
	alto = 11 if i < 3 else 13
	for _ in range(300):
		g = [["#"] * ancho for _ in range(alto)]
		celdas = [(y, x) for y in range(1, alto - 1, 2) for x in range(1, ancho - 1, 2)]
		ini = celdas[-1]
		pila = [ini]
		g[ini[0]][ini[1]] = "."
		while pila:
			y, x = pila[-1]
			vec = [(y + dy, x + dx, dy // 2, dx // 2) for dy, dx in ((2, 0), (-2, 0), (0, 2), (0, -2))
				if 0 < y + dy < alto - 1 and 0 < x + dx < ancho - 1 and g[y + dy][x + dx] == "#"]
			if not vec:
				pila.pop()
				continue
			ny, nx, my, mx = rnd.choice(vec)
			g[y + my][x + mx] = "."
			g[ny][nx] = "."
			pila.append((ny, nx))
		## Atajos: mas cuanto mas facil (menos callejones sin salida).
		muros = [(y, x) for y in range(1, alto - 1) for x in range(1, ancho - 1) if g[y][x] == "#"
			and ((g[y - 1][x] == "." and g[y + 1][x] == ".") or (g[y][x - 1] == "." and g[y][x + 1] == "."))]
		rnd.shuffle(muros)
		cola_modo = bool((opciones or {}).get("cola"))
		## Con cola (mezcla con la serpiente) el laberinto es perfecto: sin atajos ni puertas.
		for y, x in ([] if cola_modo else muros[:max(1, int(len(muros) * (0.22 - 0.05 * max(dif, 0.0))))]):
			g[y][x] = "."
		salida = (alto - 1, ini[1])
		g[salida[0]][salida[1]] = "P"
		if cola_modo:
			filas = _laberinto_cola(g, salida, i, dif, rnd)
			if filas and analizar_laberinto(filas, cola=True):
				return filas
			continue
		suelo = [(y, x) for y in range(alto) for x in range(ancho) if g[y][x] == "."]

		def alcance(desde, prohibido):
			visto = {desde}
			cola = [desde]
			while cola:
				y, x = cola.pop()
				for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					c = (y + dy, x + dx)
					if 0 <= c[0] < alto and 0 <= c[1] < ancho and c not in visto and g[c[0]][c[1]] not in "#X" and c not in prohibido:
						visto.add(c)
						cola.append(c)
			return visto

		total = alcance(salida, set())
		con_puerta = i >= 1 and (i >= 2 or dif >= 1.5)
		puerta = None
		abierta = total
		if con_puerta:
			candidatas = [c for c in suelo if c not in ((salida[0] - 1, salida[1]),)]
			rnd.shuffle(candidatas)
			for c in candidatas:
				r = alcance(salida, {c})
				if 0.35 * len(total) <= len(r) <= 0.7 * len(total):
					puerta, abierta = c, r
					break
			if puerta is None:
				continue
			g[puerta[0]][puerta[1]] = "D"
		libres = [c for c in suelo if c != puerta and c[0] < alto - 2]
		rnd.shuffle(libres)
		n_monedas = 5 + min(i, 4)
		detras = [c for c in libres if c not in abierta]
		delante = [c for c in libres if c in abierta]
		if con_puerta and (len(detras) < 2 or len(delante) < 3):
			continue
		monedas = (detras[:max(2, n_monedas // 2)] + delante[:n_monedas])[:n_monedas] if con_puerta else libres[:n_monedas]
		usados = set(monedas)
		if con_puerta:
			## La llave, lejos de la salida dentro de la parte abierta.
			lejos = sorted((c for c in delante if c not in usados), key=lambda c: -(abs(c[0] - salida[0]) + abs(c[1] - salida[1])))
			if not lejos:
				continue
			llave = lejos[0]
			g[llave[0]][llave[1]] = "L"
			usados.add(llave)
		for y, x in monedas:
			g[y][x] = "C"
		## Pinchos en pasillos que no cortan nada.
		n_pinchos = max(0, int(i * 0.8 + dif * 1.5))
		for c in [c for c in libres if c not in usados]:
			if n_pinchos <= 0:
				break
			g[c[0]][c[1]] = "X"
			objetivos = [m for m in monedas] + ([llave] if con_puerta else [])
			if not all(o in alcance(salida, set()) for o in objetivos):
				g[c[0]][c[1]] = "."
				continue
			n_pinchos -= 1
		filas = ["".join(f) for f in g]
		if analizar_laberinto(filas):
			return filas
	filas = ["#" * ancho] + ["#" + "." * (ancho - 2) + "#" for _ in range(alto - 2)] + ["#" * (ancho // 2) + "P" + "#" * (ancho - ancho // 2 - 1)]
	filas[1] = "#" + "C" * (ancho - 2) + "#"
	return filas


def _laberinto_cola(g: list[list[str]], salida: tuple, i: int, dif: float, rnd: random.Random) -> list[str] | None:
	"""Monedas a lo largo del camino hasta la casilla mas lejana (sin repetir casillas se puede
	recoger todo); pinchos en los callejones de los lados."""
	alto, ancho = len(g), len(g[0])
	padre = {salida: None}
	cola = [salida]
	k = 0
	while k < len(cola):
		y, x = cola[k]
		k += 1
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			c = (y + dy, x + dx)
			if 0 <= c[0] < alto and 0 <= c[1] < ancho and c not in padre and g[c[0]][c[1]] == ".":
				padre[c] = (y, x)
				cola.append(c)
	lejos = cola[-1]
	camino = []
	c = lejos
	while c is not None and c != salida:
		camino.append(c)
		c = padre[c]
	camino.reverse()
	if len(camino) < 6:
		return None
	n_monedas = min(len(camino) // 2, 5 + min(i, 4))
	paso = len(camino) / n_monedas
	monedas = {camino[min(len(camino) - 1, int(paso * (j + 1)) - 1)] for j in range(n_monedas)}
	for y, x in monedas:
		g[y][x] = "C"
	fuera = [c for c in padre if c not in set(camino) and c != salida]
	rnd.shuffle(fuera)
	for y, x in fuera[:max(0, int(i * 0.6 + dif))]:
		g[y][x] = "X"
	return ["".join(f) for f in g]


def laberinto_cola_camino(filas: list[str], tope: int = 60000) -> list[tuple] | None:
	"""Copia de maze_map.gd cola_path(): camino que recoge todo sin repetir casillas (o None)."""
	alto, ancho = len(filas), len(filas[0])
	pos = {ch: [(x, y) for y, f in enumerate(filas) for x, c in enumerate(f) if c == ch] for ch in "PCL"}
	if len(pos["P"]) != 1:
		return None
	monedas = set(pos["C"])
	llave = pos["L"][0] if pos["L"] else None
	inicio = pos["P"][0]
	pasos = [tope]

	def pisable(x, y, con_llave):
		if not (0 <= y < alto and 0 <= x < ancho):
			return False
		ch = filas[y][x]
		return ch not in "#X" and (con_llave or ch != "D")

	def libres(desde, usado):
		visto = {desde}
		cola = [desde]
		while cola:
			x, y = cola.pop()
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				c = (x + dx, y + dy)
				if c not in visto and c not in usado and pisable(c[0], c[1], True):
					visto.add(c)
					cola.append(c)
		return visto

	camino = [inicio]
	usado = {inicio}

	def dfs(en, quedan, con_llave):
		if quedan == 0:
			return True
		pasos[0] -= 1
		if pasos[0] <= 0:
			return False
		lib = libres(en, usado)
		if any(m not in usado and m not in lib for m in monedas):
			return False
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			c = (en[0] + dx, en[1] + dy)
			if c in usado or not pisable(c[0], c[1], con_llave):
				continue
			usado.add(c)
			camino.append(c)
			if dfs(c, quedan - (1 if c in monedas else 0), con_llave or c == llave):
				return True
			camino.pop()
			usado.discard(c)
		return False

	return list(camino) if dfs(inicio, len(monedas), llave is None) else None


def analizar_laberinto(filas: list[str], cola: bool = False) -> bool:
	"""Copia en Python de kit/maze/maze_map.gd: salida, monedas, llave alcanzable y todo con la llave."""
	if not filas or any(len(f) != len(filas[0]) for f in filas):
		return False
	pos = {ch: [(y, x) for y, f in enumerate(filas) for x, c in enumerate(f) if c == ch] for ch in "PCLD"}
	if len(pos["P"]) != 1 or not pos["C"] or len(pos["L"]) > 1 or (pos["D"] and not pos["L"]):
		return False

	def alcance(con_llave):
		visto = {pos["P"][0]}
		cola = [pos["P"][0]]
		while cola:
			y, x = cola.pop()
			for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				ny, nx = y + dy, x + dx
				if 0 <= ny < len(filas) and 0 <= nx < len(filas[0]) and (ny, nx) not in visto:
					ch = filas[ny][nx]
					if ch in "#X" or (ch == "D" and not con_llave):
						continue
					visto.add((ny, nx))
					cola.append((ny, nx))
		return visto

	llave = not pos["L"] or pos["L"][0] in alcance(False)
	visto = alcance(llave)
	if not (llave and all(c in visto for c in pos["C"])):
		return False
	return not cola or laberinto_cola_camino(filas) is not None


## << genero laberinto


## >> genero golf (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
GOLF_DT = 1.0 / 60.0
GOLF_MAX = 14.0
GOLF_R = 0.18
GOLF_HOYO = 0.3
GOLF_ENTRA = 6.5
GOLF_REBOTE = 0.75
GOLF_ANGULOS = 40
GOLF_FUERZAS = (0.18, 0.3, 0.42, 0.55, 0.7, 0.85, 1.0)


def _golf_casilla(filas, x, y):
	cx, cy = math.floor(x), math.floor(y)
	if cy < 0 or cy >= len(filas) or cx < 0 or cx >= len(filas[cy]):
		return "#"
	return filas[cy][cx]


def _golf_muro(filas, x, y):
	r = GOLF_R
	return "#" in (_golf_casilla(filas, x + r, y), _golf_casilla(filas, x - r, y), _golf_casilla(filas, x, y + r), _golf_casilla(filas, x, y - r))


GOLF_MONSTRUO = 0.42


def golf_tiro(filas, x, y, vx, vy, hx, hy, monstruos=(), viento=(0.0, 0.0)):
	"""Copia en Python de golf_map.gd simulate(): (x, y, estado, monstruos derribados). Con
	monstruos vivos el hoyo esta cerrado."""
	vivos = list(monstruos)
	tocados = []
	for _ in range(600):
		vx += viento[0] * GOLF_DT
		vy += viento[1] * GOLF_DT
		if _golf_muro(filas, x + vx * GOLF_DT, y):
			vx = -vx * GOLF_REBOTE
		else:
			x += vx * GOLF_DT
		if _golf_muro(filas, x, y + vy * GOLF_DT):
			vy = -vy * GOLF_REBOTE
		else:
			y += vy * GOLF_DT
		arena = _golf_casilla(filas, x, y) == "S"
		v = math.hypot(vx, vy)
		frena = (4.5 + 3.2 * v) if arena else (1.4 + 0.75 * v)
		nv = max(0.0, v - frena * GOLF_DT)
		if v > 0:
			vx, vy = vx / v * nv, vy / v * nv
		abierto = not vivos
		if abierto and math.hypot(x - hx, y - hy) < GOLF_HOYO and nv < GOLF_ENTRA:
			return x, y, "hoyo", tocados
		if _golf_casilla(filas, x, y) == "W":
			return x, y, "agua", tocados
		for m in list(vivos):
			if math.hypot(x - m[0], y - m[1]) < GOLF_MONSTRUO:
				vivos.remove(m)
				tocados.append(m)
		if nv < 0.06:
			return x, y, "parada", tocados
	return x, y, "parada", tocados


def _golf_distancias(filas, hx, hy, metas=None):
	cola = [(int(my), int(mx)) for mx, my in (metas or [(hx, hy)])]
	dist = {c: 0 for c in cola}
	k = 0
	while k < len(cola):
		cy, cx = cola[k]
		k += 1
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			ny, nx = cy + dy, cx + dx
			if (ny, nx) in dist or not (0 <= ny < len(filas) and 0 <= nx < len(filas[0])) or filas[ny][nx] in "#W":
				continue
			dist[(ny, nx)] = dist[(cy, cx)] + 1
			cola.append((ny, nx))
	return dist


def _golf_buscar(filas, ch):
	for y, f in enumerate(filas):
		if ch in f:
			return f.index(ch) + 0.5, y + 0.5
	return -1.0, -1.0


@functools.lru_cache(maxsize=256)
def golf_golpes(filas: tuple, limite: int = 7, viento: tuple = (0.0, 0.0)) -> int:
	"""Golpes que necesita el plan del bot (copia de golf_map.gd strokes_needed); 0 = no la mete."""
	filas = list(filas)
	bx, by = _golf_buscar(filas, "B")
	hx, hy = _golf_buscar(filas, "H")
	if bx < 0 or hx < 0:
		return 0
	dist = _golf_distancias(filas, hx, hy)
	vivos = [(x + 0.5, y + 0.5) for y, f in enumerate(filas) for x, c in enumerate(f) if c == "M"]
	x, y = bx, by
	for s in range(limite):
		mejor, puntos, mejor_t = None, math.inf, []
		a_monstruos = _golf_distancias(filas, hx, hy, vivos) if vivos else dist
		for a in range(GOLF_ANGULOS):
			ang = 2 * math.pi * a / GOLF_ANGULOS
			for pw in GOLF_FUERZAS:
				vx, vy = math.cos(ang) * pw * GOLF_MAX, math.sin(ang) * pw * GOLF_MAX
				ex, ey, estado, tocados = golf_tiro(filas, x, y, vx, vy, hx, hy, vivos, viento)
				if estado == "hoyo":
					return s + 1
				quedan = len(tocados) < len(vivos)
				tabla = a_monstruos if quedan else dist
				if estado == "agua" or (int(ey), int(ex)) not in tabla:
					continue
				p = tabla[(int(ey), int(ex))] - len(tocados) * 1000 + pw * 0.01
				if not quedan:
					p += math.hypot(ex - hx, ey - hy) * 0.3
				if p < puntos:
					puntos, mejor, mejor_t = p, (ex, ey), tocados
		if mejor is None:
			return 0
		x, y = mejor
		vivos = [m for m in vivos if m not in mejor_t]
	return 0


def generar_golf(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Hoyo de minigolf visto desde arriba: # muro, . cesped, B bola, H hoyo, W agua, S arena.
	Reglas de justicia (las mismas que comprueba kit/golf/golf_map.gd):
	1 - Un recorrido de pasillos de 3 casillas desde la bola (abajo) al hoyo (arriba), con mas
	    curvas segun avanza el juego.
	2 - Agua y arena sin cortar el camino; muros sueltos en los niveles altos.
	3 - El plan del bot mete la bola en 1 a 4 golpes (el par sale de ahi: parametros_golf)."""
	rnd = random.Random(semilla)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho = 9
	alto = 13 + min(i, 2)
	for _ in range(80):
		g = [["#"] * ancho for _ in range(alto)]
		curvas = min(3, (i + 1) // 2 + (1 if dif >= 1.5 else 0))
		ys = sorted(rnd.sample(range(3, alto - 3), curvas)) if curvas else []
		puntos = [(alto - 2, rnd.choice((2, 4, 6)))] + [(y, rnd.choice((2, 6) if k % 2 == 0 else (4, 6, 2))) for k, y in enumerate(reversed(ys))] + [(1 + 1, rnd.choice((2, 4, 6)))]
		def tallar(y0, x0, y1, x1):
			for y in range(min(y0, y1) - 1, max(y0, y1) + 2):
				for x in range(min(x0, x1) - 1, max(x0, x1) + 2):
					if 0 < y < alto - 1 and 0 < x < ancho - 1:
						g[y][x] = "."
		for (y0, x0), (y1, x1) in zip(puntos, puntos[1:]):
			tallar(y0, x0, y0, x1)
			tallar(y0, x1, y1, x1)
		by, bx = puntos[0]
		hy, hx = puntos[-1]
		g[by][bx] = "B"
		g[hy][hx] = "H"
		libres = [(y, x) for y in range(alto) for x in range(ancho) if g[y][x] == "." and abs(y - by) + abs(x - bx) > 1 and abs(y - hy) + abs(x - hx) > 1]
		rnd.shuffle(libres)
		n_agua = min(4, int(i * 0.7 + dif))
		n_arena = min(4, 1 + i // 2)
		n_muro = min(3, max(0, i - 2 + int(dif)))
		n_monstruos = (1 + min(i // 2, 2)) if (opciones or {}).get("monstruos") else 0
		for ch, cuantos in (("M", n_monstruos), ("W", n_agua), ("S", n_arena), ("#", n_muro)):
			for y, x in libres[:cuantos]:
				g[y][x] = ch
			libres = libres[cuantos:]
		filas = ["".join(f) for f in g]
		dist = _golf_distancias(filas, hx + 0.5, hy + 0.5)
		if (by, bx) not in dist:
			continue
		golpes = golf_golpes(tuple(filas), 7, viento_de(filas) if (opciones or {}).get("viento") else (0.0, 0.0))
		if 1 <= golpes <= 4 and (i == 0 or golpes >= 2):
			return filas
	filas = ["#" * ancho] + ["#" + "." * (ancho - 2) + "#" for _ in range(alto - 2)] + ["#" * ancho]
	filas[2] = "#" + "..." + "H" + "..." + "#"
	filas[-2] = "#" + "..." + "B" + "..." + "#"
	return filas


def viento_de(mapa: list[str]) -> tuple:
	"""Giro viento: direccion (8 posibles) y fuerza (0.45 a 0.9) deterministas desde el mapa."""
	h = sum((k + 1) * ord(ch) for k, ch in enumerate("".join(mapa)))
	ang = (h % 8) * math.pi / 4.0
	fuerza = 0.45 + (h // 8 % 10) * 0.05
	return (round(math.cos(ang) * fuerza, 3), round(math.sin(ang) * fuerza, 3))


def parametros_golf(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0, viento: bool = False) -> dict:
	"""Par del hoyo: los golpes del plan del bot (+1 en facil, para que las 3 estrellas lleguen).
	Con el giro viento, el viento del hoyo (y el par contando con el)."""
	w = viento_de(mapa or []) if viento else (0.0, 0.0)
	golpes = golf_golpes(tuple(mapa or []), 7, w) or 3
	out = {"par": max(2, golpes) + (1 if dificultad == "facil" else 0)}
	if viento:
		out["wind"] = list(w)
	return out


## << genero golf


## >> genero pesca (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
PESCA_BAJA = 5.0
PESCA_SUBE = 8.0
PESCA_MEDIO = 0.38


def _pesca_bajo(filas, velocidades, fila, t, cogidos, tormenta=0.0):
	w = len(filas[fila])
	hx = w * 0.5
	hay = ("", -1)
	for x, ch in enumerate(filas[fila]):
		if ch == "." or (x, fila) in cogidos:
			continue
		p = (x + velocidades[fila] * (t + tormenta * t * t)) % w
		d = (hx - p) % w
		if d < 1.0 + PESCA_MEDIO or d > w - PESCA_MEDIO:
			if ch == "X":
				return ("X", x)
			hay = ("F", x)
	return hay


def pesca_tiempo_bot(filas: list[str], velocidades: list[float], meta: int, limite: float, tormenta: float = 0.0) -> float:
	"""Copia en Python de fishing_map.gd bot_time(): segundos para pescar 'meta' peces (inf si no)."""
	cogidos: set = set()
	t = 0.0
	pescados = 0
	while t < limite:
		res = None
		for fila in range(len(filas)):
			tl = t + (fila + 0.5) / PESCA_BAJA
			u = _pesca_bajo(filas, velocidades, fila, tl, cogidos, tormenta)
			if u[0]:
				res = (u[0], fila, u[1], tl)
				break
		if res and res[0] == "F":
			cogidos.add((res[2], res[1]))
			pescados += 1
			t = res[3] + (res[1] + 0.5) / PESCA_SUBE
			if pescados >= meta:
				return t
		else:
			t += 1.0 / 60.0
	return math.inf


def _pesca_parametros(i: int, dificultad: str, filas: list[str], semilla: int, tormenta: float = 0.0) -> dict:
	rnd = random.Random(semilla * 7 + 3)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0)
	base = 1.2 + 0.2 * min(i, 5) + 0.3 * dif
	vel = [round((base + 0.35 * k + rnd.uniform(-0.2, 0.2)) * (1 if k % 2 == 0 else -1), 2) for k in range(len(filas))]
	peces = "".join(filas).count("F")
	meta = max(3, min(peces - 2, 5 + min(i, 4)))
	## Tiempo: lo que tarda el bot (perfecto) por un margen para personas, menos en dificil.
	bot = pesca_tiempo_bot(filas, vel, meta, 300.0, tormenta)
	margen = {"facil": 3.2, "normal": 2.6, "dificil": 2.1}.get(dificultad, 2.6)
	tiempo = float(min(90, max(20, round(bot * margen + 8.0))))
	out = {"speeds": vel, "goal": meta, "time": tiempo}
	if tormenta:
		out["storm"] = tormenta
	return out


def generar_pesca(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Franjas de agua de arriba abajo: . agua, F pez, X medusa. Las velocidades, la meta y el
	tiempo salen de parametros_pesca (con la misma semilla que se guarda en el mapa).
	Reglas de justicia (las mismas que comprueba kit/fishing/fishing_map.gd):
	1 - Mas franjas, peces mas rapidos y mas medusas segun avanza el juego.
	2 - Pescando como el bot se llega a la meta con al menos un 20 % del tiempo de sobra."""
	rnd = random.Random(semilla)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho = 10
	n_filas = 4 + min(i // 2, 2)
	for intento in range(200):
		filas = []
		for k in range(n_filas):
			f = ["."] * ancho
			sitios = rnd.sample(range(ancho), ancho)
			peces = 2 if k < n_filas - 1 else 3
			for x in sitios[:peces]:
				f[x] = "F"
			if k > 0 and rnd.random() < 0.25 + 0.12 * i + 0.15 * dif:
				libres = [x for x in sitios[peces:] if f[(x - 1) % ancho] == "." and f[(x + 1) % ancho] == "."]
				if libres:
					f[libres[0]] = "X"
			filas.append("".join(f))
		## Velocidades, meta y tiempo se recalculan igual desde el mapa (parametros_pesca).
		p = parametros_pesca(i, n, dificultad, filas, tormenta=bool((opciones or {}).get("tormenta")))
		if pesca_tiempo_bot(filas, p["speeds"], p["goal"], p["time"], p.get("storm", 0.0)) <= p["time"] * 0.7:
			return filas
	return ["F" * 2 + "." * (ancho - 2) for _ in range(n_filas)]


def parametros_pesca(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0, tormenta: bool = False) -> dict:
	"""Velocidades, meta y tiempo del nivel (deterministas a partir del mapa). Con el giro tormenta
	las franjas aceleran (storm) y el tiempo se calcula con la tormenta."""
	filas = mapa or ["F" * 2 + "." * 8] * 4
	semilla = sum((k + 1) * ord(ch) for k, ch in enumerate("".join(filas)))
	return _pesca_parametros(i, dificultad, filas, semilla, round(0.004 + 0.001 * min(i, 4), 4) if tormenta else 0.0)


## << genero pesca


## >> genero fusion (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def _fusion_gravedad(b, w, h, foco):
	for x in range(w):
		esc = h - 1
		for y in range(h - 1, -1, -1):
			v = b[y * w + x]
			if v == 0:
				continue
			if esc != y:
				b[esc * w + x] = v
				b[y * w + x] = 0
				if foco == y * w + x:
					foco = esc * w + x
			esc -= 1
	return foco


def _fusion_libre(b, w, h, col):
	for y in range(h - 1, -1, -1):
		if b[y * w + col] == 0:
			return y
	return -1


def fusion_soltar(b, w, h, col, valor):
	"""Copia exacta de merge_map.gd drop(): (tablero, fusiones, casilla) o None si no cabe."""
	y0 = _fusion_libre(b, w, h, col)
	if y0 < 0:
		return None
	b = list(b)
	foco = y0 * w + col
	b[foco] = valor
	fusiones = 0
	for _ in range(64):
		fx, fy = foco % w, foco // w
		comidas = 0
		for dx, dy in ((-1, 0), (1, 0), (0, 1), (0, -1)):
			nx, ny = fx + dx, fy + dy
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			if b[ny * w + nx] == b[foco] and b[foco] > 0:
				b[ny * w + nx] = 0
				comidas += 1
		if comidas:
			b[foco] += comidas
			fusiones += comidas
			foco = _fusion_gravedad(b, w, h, foco)
			rotas = 0
			for dx, dy in ((-1, 0), (1, 0), (0, 1), (0, -1)):
				sx, sy = foco % w + dx, foco // w + dy
				if 0 <= sx < w and 0 <= sy < h and b[sy * w + sx] == -1:
					b[sy * w + sx] = 0
					rotas += 1
			if rotas:
				foco = _fusion_gravedad(b, w, h, foco)
			continue
		hallado = -1
		for y in range(h - 1, -1, -1):
			for x in range(w):
				v = b[y * w + x]
				if v <= 0:
					continue
				if (x + 1 < w and b[y * w + x + 1] == v) or (y > 0 and b[(y - 1) * w + x] == v):
					hallado = y * w + x
					break
			if hallado >= 0:
				break
		if hallado < 0:
			break
		foco = hallado
	return b, fusiones, foco


def _fusion_puntos(b, w, h):
	vacias = piedras = rugoso = alto = 0
	for x in range(w):
		altura = 0
		for y in range(h):
			v = b[y * w + x]
			if v == -1:
				piedras += 1
			if v == 0:
				vacias += 1
			else:
				altura = max(altura, h - y)
				if x + 1 < w and b[y * w + x + 1] > 0 and abs(b[y * w + x + 1] - v) >= 3:
					rugoso += 1
				if y + 1 < h and b[(y + 1) * w + x] > 0 and b[(y + 1) * w + x] < v:
					rugoso += 1
		alto = max(alto, altura)
	return max(max(b), 0) * 1000 + vacias * 20 - rugoso * 12 - alto * 6 - piedras * 25


def fusion_columna(b, w, h, ahora, siguiente):
	"""Copia exacta de merge_map.gd best_column()."""
	mejor, mejor_p = -1, -1000000000
	for c1 in range(w):
		r1 = fusion_soltar(b, w, h, c1, ahora)
		if r1 is None:
			continue
		p = -500000 + _fusion_puntos(r1[0], w, h)
		for c2 in range(w):
			r2 = fusion_soltar(r1[0], w, h, c2, siguiente)
			if r2 is not None:
				p = max(p, _fusion_puntos(r2[0], w, h))
		if p > mejor_p:
			mejor_p, mejor = p, c1
	return mejor


def fusion_partida(b, w, h, sec, maximo=400):
	"""El bot juega: devuelve {valor: jugada en que lo consigue por primera vez}."""
	b = list(b)
	logros = {}
	for m in range(maximo):
		mv = max(b)
		if mv not in logros:
			for v in range(1, mv + 1):
				logros.setdefault(v, m)
		ahora, sig = sec[m % len(sec)], sec[(m + 1) % len(sec)]
		c = fusion_columna(b, w, h, ahora, sig)
		if c < 0:
			break
		b = fusion_soltar(b, w, h, c, ahora)[0]
	return logros


def generar_fusion(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero inicial de la fusion (. vacia, 1-9 pieza de valor 2^v). La secuencia de piezas, la
	meta y las jugadas del bot salen de parametros_fusion (deterministas desde el mapa).
	Reglas de justicia (las mismas que comprueba kit/merge/merge_map.gd):
	1 - Desde el nivel 3, algunas piezas sueltas abajo que estorban un poco.
	2 - Jugando como el bot se llega a la meta (32 en el primer nivel, hasta 512)."""
	rnd = random.Random(semilla)
	w, h = 5, 7
	for _ in range(40):
		g = [["."] * w for _ in range(h)]
		if i >= 2:
			for x in rnd.sample(range(w), min(w, i - 1)):
				g[h - 1][x] = str(rnd.choice((1, 2, 3, 4)))
		if (opciones or {}).get("piedras"):
			## Giro piedras: estorban abajo hasta que una fusion al lado las rompe.
			for x in rnd.sample(range(w), min(w - 1, 2 + i // 2)):
				g[h - 1][x] = "#"
		filas = ["".join(f) for f in g]
		p = parametros_fusion(i, n, dificultad, filas)
		if p["par_moves"] > 0:
			return filas
	return ["." * w] * h


@functools.lru_cache(maxsize=256)
def _fusion_calculo(i: int, dificultad: str, filas: tuple) -> tuple:
	w, h = len(filas[0]), len(filas)
	b = [-1 if ch == "#" else (int(ch) if ch.isdigit() else 0) for f in filas for ch in f]
	semilla = sum((k + 1) * ord(ch) for k, ch in enumerate("".join(filas))) + i * 97
	rnd = random.Random(semilla)
	pesos = (5, 4, 2, 1) if dificultad != "facil" else (6, 4, 2, 0)
	sec = [rnd.choices((1, 2, 3, 4), weights=pesos)[0] for _ in range(64)]
	dif = {"facil": 0, "normal": 1, "dificil": 2}.get(dificultad, 1)
	logros = fusion_partida(b, w, h, sec)
	deseo = 5 + min(i, 4) + (1 if dif == 2 and i >= 2 else 0)
	## Partidas cortas para el movil: la meta es lo mas alto que el bot consigue en pocas jugadas.
	presupuesto = min(90, 25 + 15 * i)
	alcanzables = [v for v, m in logros.items() if v <= deseo and m <= presupuesto]
	meta = max(alcanzables) if alcanzables else 0
	return tuple(sec), meta, logros.get(meta, 0)


def parametros_fusion(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Secuencia de piezas, meta y jugadas del bot (la meta baja si el bot no llega a la deseada)."""
	filas = tuple(mapa or ["....."] * 7)
	sec, meta, jugadas = _fusion_calculo(i, dificultad, filas)
	return {"seq": list(sec), "goal": max(meta, 3), "par_moves": jugadas}


## << genero fusion


## >> genero tubos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- tubos (ordenar colores)
## Mapa: un texto por tubo de abajo arriba (letras a..i = colores, "." tubo vacio). Mismas reglas y
## mismo solucionador que kit/sort/sort_map.gd.

_TUBOS_COLORES = "abcdefghi"


def _tubos_arriba(t: str) -> int:
	if not t:
		return 0
	c, n = t[-1], 0
	for ch in reversed(t):
		if ch != c:
			break
		n += 1
	return n


def tubos_verter(tubos: tuple, a: int, b: int, cap: int) -> tuple | None:
	"""Resultado de verter de a en b, o None si no se puede (regla 1 de sort_map.gd)."""
	ta, tb = tubos[a], tubos[b]
	if a == b or not ta or len(tb) >= cap or (tb and tb[-1] != ta[-1]):
		return None
	k = min(_tubos_arriba(ta), cap - len(tb))
	out = list(tubos)
	out[a], out[b] = ta[:-k], tb + ta[-1] * k
	return tuple(out)


def tubos_resuelto(tubos: tuple, cap: int) -> bool:
	return all(not t or (len(t) == cap and _tubos_arriba(t) == cap) for t in tubos)


def resolver_tubos(tubos: list[str], cap: int = 4, limite: int = 60000) -> int | None:
	"""Movimientos de la mejor solucion (busqueda en anchura) o None si no tiene / ya esta resuelto."""
	ini = tuple(t.replace(".", "") for t in tubos)
	if tubos_resuelto(ini, cap):
		return None
	vistos = {tuple(sorted(ini))}
	frontera, pasos = [ini], 0
	while frontera and len(vistos) < limite:
		pasos += 1
		sig = []
		for t in frontera:
			for a in range(len(t)):
				for b in range(len(t)):
					if not t[b] and t[a] and _tubos_arriba(t[a]) == len(t[a]):
						continue  # pasar un tubo de un solo color a uno vacio no sirve de nada
					nt = tubos_verter(t, a, b, cap)
					if nt is None:
						continue
					k = tuple(sorted(nt))
					if k in vistos:
						continue
					if tubos_resuelto(nt, cap):
						return pasos
					vistos.add(k)
					sig.append(nt)
		frontera = sig
	return None


def generar_tubos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tubos con los colores mezclados y 2 vacios (1 en los niveles mas dificiles).
	Reglas de justicia (las mismas que comprueba kit/sort/sort_map.gd):
	1 - Cada color tiene exactamente cap porciones (4) y hay como mucho 9 colores.
	2 - Tiene solucion y no empieza resuelto; el par sale de la mejor solucion.
	3 - Mas colores y soluciones mas largas segun avanza el juego y la dificultad."""
	rnd = random.Random(semilla)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	cap = 4
	colores = 3 + int(round(d * 4))          # de 3 a 7 colores
	vacios = 2 if d < 0.85 or colores < 6 else 1
	minimo = int(colores * 1.5 + d * 6)
	mejor = None
	for _ in range(60):
		porciones = [c for c in _TUBOS_COLORES[:colores] for _ in range(cap)]
		rnd.shuffle(porciones)
		tubos = ["".join(porciones[t * cap:(t + 1) * cap]) for t in range(colores)] + ["."] * vacios
		## Que ningun tubo empiece ya hecho (de un solo color).
		if any(len(t) == cap and _tubos_arriba(t) == cap for t in tubos):
			continue
		pasos = resolver_tubos(tubos, cap, 40000)
		if pasos is None:
			continue
		if pasos >= minimo:
			return tubos
		if mejor is None or pasos > mejor[0]:
			mejor = (pasos, tubos)
	if mejor:
		return mejor[1]
	return ["abab", "baba", "ccdd", "ddcc", ".", "."]


def parametros_tubos(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Porciones por tubo y el par (movimientos de la mejor solucion, para las estrellas)."""
	par = resolver_tubos(mapa or [], 4) if mapa else None
	return {"cap": 4, "par": int(par or 0)}


## << genero tubos


## >> genero burbujas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- burbujas (bubble shooter)
## Mapa: filas de arriba abajo, de 8 y 7 burbujas alternadas (hexagonal), "." hueco y a..f colores.
## La fisica y el bot estan en kit/bubble/bubble_map.gd: el analizador de Godot juega cada nivel
## con el bot y, si no lo vacia con los disparos dados, la fabrica lo rehace con otra semilla.

_BURBUJAS_ANCHO = 8


def generar_burbujas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero con manchas de color (las burbujas iguales se agrupan, como en los juegos buenos).
	1 - Mas filas y colores segun avanza el juego y la dificultad (de 4 a 8 filas, de 3 a 6 colores).
	2 - La fila de arriba siempre llena (todo cuelga de algo).
	3 - Algun hueco suelto en las filas de abajo para que no sea un muro."""
	rnd = random.Random(semilla)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	filas = 4 + int(round(d * 4))
	colores = "abcdef"[:3 + int(round(d * 3))]
	g: list[list[str]] = []
	for r in range(filas):
		ancho = _BURBUJAS_ANCHO if r % 2 == 0 else _BURBUJAS_ANCHO - 1
		fila = []
		for c in range(ancho):
			## Copia el color de un vecino (arriba o a la izquierda) a menudo: salen manchas.
			vecinos = []
			if c > 0:
				vecinos.append(fila[c - 1])
			if r > 0:
				arriba = g[r - 1]
				for cc in ((c - 1, c) if r % 2 == 0 else (c, c + 1)):
					if 0 <= cc < len(arriba) and arriba[cc] != ".":
						vecinos.append(arriba[cc])
			vecinos = [v for v in vecinos if v != "."]
			if vecinos and rnd.random() < 0.45:
				fila.append(rnd.choice(vecinos))
			else:
				fila.append(rnd.choice(colores))
		if r >= filas - 2 and r > 0:
			for c in rnd.sample(range(ancho), max(1, ancho // 4)):
				fila[c] = "."
		g.append(fila)
	return ["".join(f) for f in g]


def parametros_burbujas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Disparos (generosos al principio, mas justos al final), fila de perder y semilla de colores."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	burbujas = sum(1 for f in (mapa or []) for ch in f if ch != ".")
	disparos = int(burbujas * (0.62 - 0.17 * d)) + 8
	semilla = sum((k2 + 1) * ord(ch) for k2, ch in enumerate("".join(mapa or []))) % 9973
	return {"shots": disparos, "lose_row": 12, "seed": semilla}


## << genero burbujas


## >> genero imperio (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- imperio (estrategia en tiempo real)
## Mapa visto desde arriba (ver kit/empire/empire_map.gd): tu centro abajo y el rival arriba, con
## los recursos repartidos en espejo (girando el mapa 180 grados) para que sea justo. Lo que
## cambia con el avance es el rival: mas edificios (y por tanto mas tipos de tropas), torres,
## empalizadas, mas ingresos y oleadas antes.

_IMP_W = 20
_IMP_H = 28
_IMP_P = (8, 22)
_IMP_TAM = {"E": 3, "P": 3, "c": 2, "q": 2, "l": 2, "w": 2, "h": 2, "t": 1, "#": 1}
_IMP_BLOQUEA = set("~^TBO")
_DIR8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]


def _imp_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def _imp_mancha(rnd: random.Random, cx: int, cy: int, n: int, libre) -> list[tuple[int, int]]:
	"""Mancha compacta de n casillas alrededor de (cx, cy) solo sobre casillas libres."""
	out = []
	borde = [(cx, cy)]
	vistos = set()
	while borde and len(out) < n:
		k = rnd.randrange(len(borde))
		x, y = borde.pop(k)
		if (x, y) in vistos:
			continue
		vistos.add((x, y))
		if not libre(x, y):
			continue
		out.append((x, y))
		for dx, dy in _DIR8[:4]:
			borde.append((x + dx, y + dy))
	return out


def _imp_ocupado(g: list[list[str]]) -> dict:
	"""Casillas de cada edificio (por su esquina)."""
	occ = {}
	for y, fila in enumerate(g):
		for x, ch in enumerate(fila):
			s = _IMP_TAM.get(ch)
			if s:
				for dy in range(s):
					for dx in range(s):
						occ[(x + dx, y + dy)] = (x, y)
	return occ


def _imp_campo(g: list[list[str]], metas: list[tuple[int, int]]) -> dict:
	"""Distancias (8 direcciones, sin cortar esquinas) hasta pegarse a alguna meta."""
	alto, ancho = len(g), len(g[0])
	occ = _imp_ocupado(g)
	bloq = lambda x, y: not (0 <= x < ancho and 0 <= y < alto) or g[y][x] in _IMP_BLOQUEA or (x, y) in occ
	dist = {}
	cola = []
	for mx, my in metas:
		for dx, dy in _DIR8 + [(0, 0)]:
			c = (mx + dx, my + dy)
			if not bloq(*c) and c not in dist:
				dist[c] = 0
				cola.append(c)
	k = 0
	while k < len(cola):
		x, y = cola[k]
		k += 1
		for dx, dy in _DIR8:
			n = (x + dx, y + dy)
			if n in dist or bloq(*n):
				continue
			if dx and dy and (bloq(x + dx, y) or bloq(x, y + dy)):
				continue
			dist[n] = dist[(x, y)] + 1
			cola.append(n)
	return dist


def comprobar_imperio(mapa: list[str]) -> list[str]:
	"""Lo mismo que el analizador de Godot (empire_map.gd), para no mandar mapas malos."""
	g = [list(f) for f in mapa]
	alto, ancho = len(g), len(g[0])
	fallos = []
	casas = [(x, y) for y in range(alto) for x in range(ancho) if g[y][x] == "P"]
	rivales = [(x, y) for y in range(alto) for x in range(ancho) if g[y][x] == "E"]
	if len(casas) != 1 or not rivales:
		return ["empire_one_player" if len(casas) != 1 else "empire_no_enemy"]
	px, py = casas[0]
	desde = _imp_campo(g, [(px + dx, py + dy) for dy in range(3) for dx in range(3)])
	for ex, ey in rivales:
		d = [desde[(ex + dx, ey + dy)] for dy in range(-1, 4) for dx in range(-1, 4) if (ex + dx, ey + dy) in desde]
		if not d:
			fallos.append("empire_unreachable")
		elif min(d) < 10:
			fallos.append("empire_close")
	cant = {"T": 80, "B": 120, "O": 160}
	cerca = {"T": 0, "B": 0, "O": 0}
	for y in range(alto):
		for x in range(ancho):
			ch = g[y][x]
			if ch in cant and any(desde.get((x + dx, y + dy), 99) <= 9 for dx, dy in _DIR8):
				cerca[ch] += cant[ch]
	if cerca["T"] < 800:
		fallos.append("empire_few_wood")
	if cerca["B"] < 360:
		fallos.append("empire_few_food")
	if cerca["O"] < 480:
		fallos.append("empire_few_gold")
	return fallos


def generar_imperio(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""1 - Tu centro abajo; bayas y oro cerca, bosques a los lados (en espejo para el rival).
	2 - En medio, un rio con vados, rocas o un bosque con huecos (cambia con la semilla).
	3 - Base rival segun el avance: cuartel siempre; arqueria, establo, taller, casas, torres y
	    empalizada cuanto mas dificil. Siempre se llega andando a su centro."""
	rnd = random.Random(semilla)
	d = _imp_d(i, n, dificultad, ajuste)
	W, H = _IMP_W, _IMP_H
	for _ in range(300):
		g = [["." for _ in range(W)] for _ in range(H)]
		px, py = _IMP_P
		reservado = {(px + dx, py + dy) for dy in range(-2, 5) for dx in range(-2, 5)}

		def libre(x, y, g=g, reservado=reservado):
			return 0 <= x < W and H // 2 + 1 <= y < H and g[y][x] == "." and (x, y) not in reservado

		lado = rnd.choice([-1, 1])
		bayas = _imp_mancha(rnd, px + 1 + lado * 5, py + rnd.randint(-1, 2), 5, libre)
		oro = _imp_mancha(rnd, px + 1 - lado * 5, py + rnd.randint(-2, 1), 5, libre)
		for x, y in bayas:
			g[y][x] = "B"
		for x, y in oro:
			g[y][x] = "O"
		## Una segunda mina de oro mas lejos (para la Edad II: hay que poner un almacen al lado).
		oro2 = _imp_mancha(rnd, rnd.choice([4, W - 5]), rnd.randint(17, 18), 5, libre)
		if len(oro2) < 4:
			continue
		for x, y in oro2:
			g[y][x] = "O"
		## Y una tercera en el centro del mapa, mas expuesta (merece la pena controlarla).
		for x, y in _imp_mancha(rnd, rnd.randint(6, W - 7), 16, 4, libre):
			g[y][x] = "O"
		bx = 1 if lado > 0 else W - 2
		for cx, cy, k in ((bx, rnd.randint(17, 24), 18), (W - 1 - bx, rnd.randint(16, 20), 12)):
			for x, y in _imp_mancha(rnd, cx, cy, k, libre):
				g[y][x] = "T"
		## Centro del mapa: rio con vados, rocas o bosque (solo la mitad de abajo; luego espejo).
		medio = rnd.choice(["rio", "rocas", "bosque"])
		if medio == "rio":
			vados = sorted(rnd.sample(range(2, W - 3), 2))
			for x in range(W):
				if all(abs(x - v) > 1 for v in vados) and x not in (W // 2, W // 2 - 1):
					g[14][x] = "~"
		elif medio == "rocas":
			for _k in range(4):
				for x, y in _imp_mancha(rnd, rnd.randint(1, W - 2), rnd.randint(14, 16), 3, lambda x, y: 0 <= x < W and 14 <= y < 17 and g[y][x] == "."):
					g[y][x] = "^"
		else:
			huecos = set(rnd.sample(range(1, W - 1), 5))
			for x in range(W):
				if x not in huecos and abs(x - W // 2) > 1:
					g[15 if x % 3 else 14][x] = "T"
		## Espejo (girar 180 grados): la mitad de arriba es la de abajo del reves.
		for y in range(H // 2, H):
			for x in range(W):
				g[H - 1 - y][W - 1 - x] = g[y][x]
		g[py][px] = "P"
		ex, ey = W - 3 - px, H - 3 - py
		for y in range(H):
			for x in range(W):
				if g[y][x] == "P" and (x, y) != (px, py):
					g[y][x] = "."
		g[ey][ex] = "E"
		## Base rival.
		piezas = ["c"]
		if d > 0.2:
			piezas.append("q")
		if d > 0.45:
			piezas.append("l")
		if d > 0.75:
			piezas.append("w")
		piezas += ["h"] * (1 + int(d * 2))
		piezas += ["t"] * int(round(d * 3))
		ocupado = _imp_ocupado(g)
		ok = True
		for pz in piezas:
			s = _IMP_TAM[pz]
			hueco = []
			for y in range(1, H // 2 - 2):
				for x in range(0, W - s + 1):
					celdas = [(x + dx, y + dy) for dy in range(s) for dx in range(s)]
					if any(g[cy][cx] != "." or (cx, cy) in ocupado for cx, cy in celdas):
						continue
					## Un hueco de una casilla alrededor (menos las torres).
					if s > 1 and any((x + dx, y + dy) in ocupado for dy in range(-1, s + 1) for dx in range(-1, s + 1)):
						continue
					cx, cy = x + s / 2, y + s / 2
					dist = math.hypot(cx - (ex + 1.5), cy - (ey + 1.5))
					if 2.5 <= dist <= (6.5 if pz != "t" else 5.0):
						hueco.append((x, y))
			if not hueco:
				ok = False
				break
			x, y = rnd.choice(hueco)
			g[y][x] = pz
			ocupado = _imp_ocupado(g)
		if not ok:
			continue
		## Empalizada con huecos delante de la base rival en los niveles dificiles.
		if d > 0.6:
			fila = ey + 6
			for x in range(2, W - 2):
				if g[fila][x] == "." and (x, fila) not in ocupado and x % 4 != 1:
					g[fila][x] = "#"
		mapa = ["".join(f) for f in g]
		if not comprobar_imperio(mapa):
			return mapa
	raise RuntimeError("no sale un mapa de imperio justo")


def parametros_imperio(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Lo que tienes al empezar y como juega el rival (ingresos, oleadas y edades)."""
	d = _imp_d(i, n, dificultad, ajuste)
	extra = 100 if d < 0.2 else 0
	return {
		"start": {"comida": 200 + extra, "madera": 220 + extra, "oro": 100 + extra // 2},
		"villagers": 4 if d < 0.3 else 3,
		"ai": {"income": round(0.55 + 0.7 * d, 2), "first_wave": int(300 - 110 * d), "wave_every": int(140 - 50 * d),
			"wave_size": 3 + int(3 * d), "wave_grow": 1 + int(2 * d), "age2_at": int(330 - 100 * d), "age3_at": int(660 - 160 * d),
			"max_army": 12 + int(16 * d)},
		"par": int(600 + 120 * d),
		"seconds": 0,
	}


## << genero imperio


## >> genero minas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- minas (idle de excavar)
## Mapa: un mineral por pozo de arriba abajo (c carbon ... d diamante; ver kit/mine/mine_map.gd).
## La meta de dinero crece x2,4 por nivel; el analizador de Godot juega cada nivel con el bot y
## comprueba que se llega (entre 45 s y 20 min de juego).

_MINAS_ORES = "chbpored"
_MINAS_FACTOR = {"facil": 0.6, "normal": 1.0, "dificil": 1.5}


def generar_minas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""4 pozos al principio y uno mas cada dos niveles (hasta 8). A veces el ultimo mineral se
	cambia por uno mas raro para que cada mina tenga su joya."""
	rnd = random.Random(semilla)
	pozos = min(8, 4 + i // 2)
	mapa = list(_MINAS_ORES[:pozos])
	if pozos < 8 and rnd.random() < 0.5:
		mapa[-1] = rnd.choice(_MINAS_ORES[pozos:])
	return mapa


def parametros_minas(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Meta de dinero, dinero inicial y el par (segundos que tarda una buena partida)."""
	meta = 3000.0 * (2.4 ** i) * _MINAS_FACTOR.get(dificultad, 1.0) * (1.0 + ajuste)
	par = int(max(90.0, 110.0 + 60.0 * math.log(max(meta, 2000.0) / 2000.0, 5.0)))
	return {"goal": int(meta), "start": 0, "par": par}


## << genero minas


## >> genero mazmorras (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- mazmorras (RPG de accion)
## Mapa: la planta, una letra por sala (S salida, M monstruos, E elite, T tesoro, B jefe, # nada).
## Las salas por dentro y los monstruos salen de la semilla en el kit (kit/dungeon/dungeon_map.gd).

def _maz_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def _maz_dist(salas: dict, desde: tuple) -> dict:
	d = {desde: 0}
	cola = [desde]
	for c in cola:
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			v = (c[0] + dx, c[1] + dy)
			if v in salas and v not in d:
				d[v] = d[c] + 1
				cola.append(v)
	return d


def generar_mazmorras(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""1 - Camino de la salida (abajo) al jefe: mas largo segun avanza el juego.
	2 - Ramas con tesoros (1 o 2) y salas de monstruos; salas elite cuanto mas dificil.
	3 - Entre 5 y 16 salas en una planta de 5x6 como mucho."""
	rnd = random.Random(semilla)
	d = _maz_d(i, n, dificultad, ajuste)
	ancho, alto = 5, 6
	largo = 3 + min(4, i // 2) + (1 if d > 0.6 else 0)
	for _ in range(400):
		salida = (rnd.randint(1, ancho - 2), alto - 1)
		camino = [salida]
		ok = True
		while len(camino) < largo + 1:
			x, y = camino[-1]
			opciones_ = [(x + dx, y + dy) for dx, dy in ((0, -1), (0, -1), (1, 0), (-1, 0))
				if 0 <= x + dx < ancho and 0 <= y + dy < alto and (x + dx, y + dy) not in camino]
			if not opciones_:
				ok = False
				break
			camino.append(rnd.choice(opciones_))
		if not ok:
			continue
		salas = {c: "M" for c in camino}
		salas[salida] = "S"
		salas[camino[-1]] = "B"
		## Ramas: tesoros y salas extra pegadas al camino (nunca al jefe).
		extras = 1 + (1 if i >= 3 else 0) + int(d * 2)
		tesoros = 1 + (1 if i >= 5 else 0)
		for k in range(extras + tesoros):
			bordes = [(x + dx, y + dy) for (x, y), t in salas.items() if t not in ("B",) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
				if 0 <= x + dx < ancho and 0 <= y + dy < alto and (x + dx, y + dy) not in salas
				and not any((x + dx + ex, y + dy + ey) in salas and salas[(x + dx + ex, y + dy + ey)] == "B" for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
			if not bordes:
				break
			salas[rnd.choice(bordes)] = "T" if k < tesoros else "M"
		## Salas elite en el camino (no la primera despues de la salida).
		elites = int(round(d * 2.0)) + (1 if i >= 6 else 0)
		medio = [c for c in camino[2:-1] if salas[c] == "M"]
		rnd.shuffle(medio)
		for c in medio[:elites]:
			salas[c] = "E"
		if not (5 <= len(salas) <= 16) or _maz_dist(salas, salida).get(camino[-1], 0) < 3:
			continue
		xs = [c[0] for c in salas]
		ys = [c[1] for c in salas]
		filas = []
		for y in range(min(ys), max(ys) + 1):
			filas.append("".join(salas.get((x, y), "#") for x in range(min(xs), max(xs) + 1)))
		return filas
	return ["#TB", "MEM", "#S#"]


def parametros_mazmorras(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Fuerza de los monstruos, semilla de las salas y el par (segundos)."""
	d = _maz_d(i, n, dificultad, ajuste)
	salas = sum(1 for f in (mapa or []) for ch in f if ch != "#")
	semilla = sum((k + 1) * ord(ch) for k, ch in enumerate("".join(mapa or []))) % 9973 + i
	return {"power": round(0.7 + 0.45 * d, 2), "seed": semilla, "par": 25 * max(salas, 4) + 60}


## << genero mazmorras


## >> genero granja (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- granja cozy (estilo Hay Day)
## Mapa: parcelas "." arriba, corrales y maquinas abajo, casa, arboles y estanque de adorno
## (ver kit/farm/farm_map.gd). Cada nivel desbloquea algo nuevo (gallinas y molino, panaderia,
## vacas y queseria, fresas y pasteleria, ovejas y telar); el analizador juega con el bot.

_GRANJA_DESBLOQUEOS = [
	(["trigo", "maiz"], ""),
	(["trigo", "maiz"], "GM"),
	(["trigo", "maiz", "zanahoria"], "GMP"),
	(["trigo", "maiz", "zanahoria"], "GMPVQ"),
	(["trigo", "maiz", "zanahoria", "fresa"], "GMPVQT"),
	(["trigo", "maiz", "zanahoria", "fresa", "calabaza"], "GMPVQTOJ"),
]
_GRANJA_FACTOR = {"facil": 0.8, "normal": 1.0, "dificil": 1.25}


def _granja_etapa(i: int, n: int) -> int:
	"""Etapa de desbloqueo: se reparte a lo largo del juego (con 10 niveles, una cada nivel y medio)."""
	return min(len(_GRANJA_DESBLOQUEOS) - 1, int(i * len(_GRANJA_DESBLOQUEOS) / max(n, 1) + (1 if i > 0 else 0)))


def generar_granja(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Granja de 8 de ancho: 2-3 filas de parcelas, una fila de edificios y adornos alrededor."""
	rnd = random.Random(semilla)
	_, edificios = _GRANJA_DESBLOQUEOS[_granja_etapa(i, n)]
	ancho = 8
	parcelas = 6 + min(6, i)
	g = [["," for _ in range(ancho)] for _ in range(6)]
	## Parcelas en bloque arriba, centradas.
	filas = 2 if parcelas <= 8 else 3
	por_fila = (parcelas + filas - 1) // filas
	x0 = (ancho - por_fila) // 2
	puestas = 0
	for y in range(filas):
		for x in range(x0, x0 + por_fila):
			if puestas < parcelas:
				g[y][x] = "."
				puestas += 1
	## Edificios en las dos filas de abajo, en orden, y la casa.
	huecos = [(x, y) for y in (4, 5) for x in range(ancho)]
	rnd.shuffle(huecos)
	huecos.sort(key=lambda c: (c[1] != 5, rnd.random()))
	for ch in "h" + edificios:
		x, y = huecos.pop(0)
		g[y][x] = ch
	## Adornos: arboles y un estanque donde quede sitio.
	libres = [(x, y) for y in range(6) for x in range(ancho) if g[y][x] == ","]
	rnd.shuffle(libres)
	for x, y in libres[:3]:
		g[y][x] = "t"
	if len(libres) > 3:
		x, y = libres[3]
		g[y][x] = "~"
	return ["".join(f) for f in g]


def parametros_granja(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Pedidos a cumplir, cultivos, monedas al empezar, semilla de los pedidos y el par."""
	cultivos, _ = _GRANJA_DESBLOQUEOS[_granja_etapa(i, n)]
	meta = max(3, int(round((3 + i * 0.6) * _GRANJA_FACTOR.get(dificultad, 1.0) * (1.0 + ajuste))))
	return {"goal": meta, "crops": list(cultivos), "coins": 25, "seed": 17 + i * 31, "par": 45 * meta}


## << genero granja


## >> genero mazo (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- mazo (cartas de estrategia)
## Mapa: un enemigo por combate (kit/deck/deck_map.gd). Los primeros niveles son cortos y con
## enemigos sencillos; luego entran bruja, caballero y golem, y los ultimos acaban con el dragon.
## El analizador juega cada nivel con el bot (mismo azar) y devuelve los turnos como par.

_MAZO_FACILES = ["slime", "bandido"]
_MAZO_MEDIOS = ["bandido", "bruja", "caballero"]
_MAZO_DUROS = ["caballero", "golem", "bruja"]


def _mazo_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def generar_mazmo_lista(i: int, n: int, rnd: random.Random) -> list[str]:
	combates = min(5, 2 + i // 2)
	lista = []
	for k in range(combates):
		etapa = (i + k) / max(1, n)
		pool = _MAZO_FACILES if etapa < 0.35 else (_MAZO_MEDIOS if etapa < 0.7 else _MAZO_DUROS)
		lista.append(rnd.choice(pool))
	if i == n - 1 or (i >= 6 and i % 3 == 0):
		lista[-1] = "dragon"
	return lista


def generar_mazo(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""2 combates al principio y uno mas cada dos niveles (hasta 5); el dragon cierra el juego."""
	return generar_mazmo_lista(i, n, random.Random(semilla))


def parametros_mazo(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Fuerza de los enemigos, tu vida, la semilla del azar (barajas y premios) y un par orientativo."""
	d = _mazo_d(i, n, dificultad, ajuste)
	semilla = sum((k + 1) * ord(ch) for k, ch in enumerate("".join(mapa or []))) % 9973 + i * 7
	return {"power": round(0.8 + 0.25 * d, 2), "hp": 70, "seed": semilla, "par": 5 * len(mapa or [1, 1])}


## << genero mazo


## >> genero aventura (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- aventura (historia con decisiones)
## Cada nivel es un capitulo que escribe la directora (diseno -> "aventura"). El mapa no se usa
## (es solo "historia"); las escenas van en los parametros. Si un capitulo no cumple las reglas
## del analizador (kit/tale/tale_map.gd), se usa uno de reserva (director/banco_aventuras.py).

def generar_aventura(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return ["historia"]


def parametros_aventura(i: int, n: int, dificultad: str, capitulo: dict | None = None, nombres: dict | None = None,
		ajuste: float = 0.0) -> dict:
	"""Escenas, finales y nombres del capitulo i (el de la directora o uno de reserva)."""
	from director import banco_aventuras
	nivel = banco_aventuras.a_kit(capitulo) if capitulo else {}
	if not nivel or banco_aventuras.comprobar(nivel):
		reserva = banco_aventuras.capitulos(i + 1, nombres or {"heroe": "nuestra heroina", "rival": "la Sombra", "aliado": "Pip",
			"lugar": "el reino", "tesoro": "la joya"})[i]
		nivel = banco_aventuras.a_kit(reserva)
	nivel["name"] = str(nivel.get("title", ""))[:40]
	if nombres:
		nivel["cast"] = {"heroe": nombres.get("heroe", ""), "rival": nombres.get("rival", ""), "aliado": nombres.get("aliado", "")}
	return nivel


## << genero aventura


## >> genero cocina (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- cocina (gestion de tiempo)
## Mapa: el menu del nivel, un plato por fila (kit/cook/cook_map.gd). Cada nivel anade un plato;
## mas clientes, menos paciencia y meta mas alta segun avanza. El analizador juega con el bot.

_COCINA_MENUS = [["hamburguesa"], ["hamburguesa", "refresco"], ["hamburguesa", "refresco", "patatas"],
	["hamburguesa", "perrito", "patatas", "refresco"], ["hamburguesa", "hamburguesa_queso", "perrito", "patatas", "refresco"],
	["hamburguesa", "hamburguesa_queso", "perrito", "patatas", "refresco", "tarta"]]
_COCINA_PRECIOS = {"hamburguesa": 12, "hamburguesa_queso": 16, "patatas": 6, "perrito": 10, "refresco": 4, "tarta": 9}


def _cocina_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def generar_cocina(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return list(_COCINA_MENUS[min(i, len(_COCINA_MENUS) - 1)])


def parametros_cocina(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Clientes, paciencia, duracion del dia y meta (un 60-75 % de lo que saca una buena partida)."""
	d = _cocina_d(i, n, dificultad, ajuste)
	menu = mapa or ["hamburguesa"]
	clientes = 12 + 2 * min(i, 8)
	media = sum(_COCINA_PRECIOS.get(p, 8) for p in menu) / len(menu)
	meta = int(media * 1.35 * clientes * (0.6 + 0.15 * d))
	semilla = sum((k + 1) * ord(ch) for k, ch in enumerate("".join(menu))) % 9973 + i
	return {"goal": meta, "customers": clientes, "patience": round(32 - 10 * d, 1), "seconds": int(24 + 3.8 * clientes),
		"seed": semilla, "par": int(2.6 * clientes)}


## << genero cocina


## >> genero mahjong (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- mahjong solitario
## Mapa: filas de digitos con la altura de cada pila (kit/mahjong/mahjong_map.gd). Formas que
## crecen con el nivel (piramide, rombo, cruz, torres, anillo); siempre un numero par de fichas.
## El reparto de dibujos lo hace el juego desde una solucion, asi que siempre se puede ganar.

def _mj_forma(forma: str, w: int, h: int, alto: int, rng: random.Random) -> list[list[int]]:
	g = [[0] * w for _ in range(h)]
	cx, cy = (w - 1) / 2, (h - 1) / 2
	for y in range(h):
		for x in range(w):
			borde = min(x, y, w - 1 - x, h - 1 - y)
			if forma == "piramide":
				v = 1 + borde
			elif forma == "rombo":
				d = abs(x - cx) / max(1, cx) + abs(y - cy) / max(1, cy)
				v = 0 if d > 1.05 else 1 + int((1.05 - d) * alto)
			elif forma == "cruz":
				dentro = abs(x - cx) <= max(1, w // 4) or abs(y - cy) <= max(1, h // 4)
				v = (1 + min(borde, 2)) if dentro else 0
			elif forma == "torres":
				v = 1 + (2 if (x in (1, w - 2) and y in (1, h - 2)) else 0) + (1 if borde >= 2 else 0)
			else:  ## anillo
				v = 2 if borde == 0 else (1 if borde == 1 else 0)
			g[y][x] = max(0, min(alto, v))
	return g


def generar_mahjong(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 977 + i * 31)
	d = _mj_d(i, n, dificultad, ajuste)
	formas = ["piramide", "rombo", "cruz", "torres", "anillo"]
	forma = "piramide" if i == 0 else formas[(i + semilla) % len(formas)]
	w = min(8, 4 + i // 2 + (1 if d > 0.6 else 0) + (2 if forma in ("rombo", "cruz") else 0))
	h = min(8, 4 + (i + 1) // 2 + (2 if forma in ("rombo", "cruz") else 0))
	alto = min(4, 2 + i // 3)
	g = _mj_forma(forma, w, h, alto, rng)
	total = sum(map(sum, g))
	if total < 12:
		g = _mj_forma("piramide", w, h, alto, rng)
		total = sum(map(sum, g))
	if total % 2:
		## Quita una ficha de la pila mas alta del centro.
		y, x = max(((y, x) for y in range(h) for x in range(w)), key=lambda p: (g[p[0]][p[1]], -abs(p[0] - h / 2) - abs(p[1] - w / 2)))
		g[y][x] -= 1
	filas = ["".join(str(v) if v else "." for v in fila) for fila in g]
	filas = [f for f in filas if f.strip(".")]
	izq = min(len(f) - len(f.lstrip(".")) for f in filas)
	der = max(len(f.rstrip(".")) for f in filas)
	return [f[izq:der] for f in filas]


def _mj_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def parametros_mahjong(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Dibujos distintos (mas = mas dificil de ver), barajadas y segundos para 3 estrellas."""
	d = _mj_d(i, n, dificultad, ajuste)
	fichas = sum(int(c) for fila in (mapa or []) for c in fila if c.isdigit())
	return {"kinds": int(min(24, max(6, fichas // 2 * 0.6), 6 + 2 * i + 6 * d)), "shuffles": 3 if d < 0.35 else 2,
		"seed": 11 + i * 7 + fichas, "par": int(fichas / 2 * 3.2) + 10}


## << genero mahjong


## >> genero aparcamiento (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- aparcamiento (Parking Jam)
## Mapa: "." asfalto, "#" obstaculo y coches de 2-3 casillas (MAYUSCULA = morro, minusculas =
## resto; kit/parking/parking_map.gd). Se colocan coches al azar sin crear atascos sin salida y
## se elige, entre varios intentos, el que mas rondas necesita (mas enredado) segun el nivel.

_PK_DIRS = {"R": (1, 0), "L": (-1, 0), "D": (0, 1), "U": (0, -1)}


def _pk_rondas(w: int, h: int, coches: list[dict], muros: set) -> int:
	"""Rondas para sacar todos los coches (-1 si se atascan)."""
	vivos = list(range(len(coches)))
	rondas = 0
	while vivos:
		ocup = {c: k for k in vivos for c in coches[k]["celdas"]}
		libres = []
		for k in vivos:
			dx, dy = _PK_DIRS[coches[k]["dir"]]
			x, y = coches[k]["morro"]
			x, y = x + dx, y + dy
			ok = True
			while 0 <= x < w and 0 <= y < h:
				if (x, y) in muros or (x, y) in ocup:
					ok = False
					break
				x, y = x + dx, y + dy
			if ok:
				libres.append(k)
		if not libres:
			return -1
		vivos = [k for k in vivos if k not in libres]
		rondas += 1
	return rondas


def _pk_intento(w: int, h: int, n_coches: int, n_muros: int, rng: random.Random) -> tuple[list[dict], set]:
	coches: list[dict] = []
	ocupado: set = set()
	muros: set = set()
	for _ in range(n_muros):
		c = (rng.randrange(w), rng.randrange(h))
		muros.add(c)
		ocupado.add(c)
	for _ in range(n_coches * 12):
		if len(coches) >= n_coches:
			break
		largo = 3 if rng.random() < 0.3 else 2
		d = rng.choice("RLUD")
		if d in "RL":
			x, y = rng.randrange(w - largo + 1), rng.randrange(h)
			celdas = [(x + k, y) for k in range(largo)]
		else:
			x, y = rng.randrange(w), rng.randrange(h - largo + 1)
			celdas = [(x, y + k) for k in range(largo)]
		if any(c in ocupado for c in celdas):
			continue
		morro = celdas[-1] if d in "RD" else celdas[0]
		coche = {"celdas": celdas, "dir": d, "morro": morro}
		coches.append(coche)
		if _pk_rondas(w, h, coches, muros) < 0:
			coches.pop()
			continue
		ocupado.update(celdas)
	return coches, muros


def generar_aparcamiento(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 7331 + i * 97)
	d = _pk_d(i, n, dificultad, ajuste)
	w = min(7, 5 + i // 3)
	h = min(9, 6 + i // 2)
	n_coches = int(min(22, 4 + i * 1.6 + d * 4))
	n_muros = 0 if i < 3 else min(3, 1 + i // 4)
	objetivo = 2 + i * 0.5 + d * 2.0
	mejor = None
	for _ in range(24):
		coches, muros = _pk_intento(w, h, n_coches, n_muros, rng)
		r = _pk_rondas(w, h, coches, muros)
		if len(coches) < 2 or r < 0:
			continue
		nota = -abs(r - objetivo) + len(coches) * 0.15
		if mejor is None or nota > mejor[0]:
			mejor = (nota, coches, muros)
	_, coches, muros = mejor
	g = [["." for _ in range(w)] for _ in range(h)]
	for (x, y) in muros:
		g[y][x] = "#"
	for k, c in enumerate(coches):
		letra = chr(65 + k)
		for (x, y) in c["celdas"]:
			g[y][x] = letra.lower()
		mx, my = c["morro"]
		g[my][mx] = letra
	return ["".join(f) for f in g]


def _pk_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def parametros_aparcamiento(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Vidas (golpes que se aguantan) y par = numero de coches."""
	d = _pk_d(i, n, dificultad, ajuste)
	coches = len({c.upper() for fila in (mapa or []) for c in fila if c.isalpha()})
	return {"lives": 3 if d < 0.7 else 2, "par": coches}


## << genero aparcamiento


## >> genero sopa (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- sopa de letras
## Mapa: ["sopa"]; las palabras van aparte ("words") y la cuadricula la monta el juego con la
## semilla (kit/words/words_map.gd), asi se puede traducir. Las palabras las escribe la
## directora (diseno["sopa"], una lista por nivel) o salen del banco por el tema de la idea.

def generar_sopa(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return ["sopa"]


def parametros_sopa(i: int, n: int, dificultad: str, palabras: list[str] | None = None, tema: str = "", ajuste: float = 0.0) -> dict:
	"""Palabras, lado de la cuadricula y direcciones (derecha/abajo, + diagonales, + al reves)."""
	from director import banco_palabras
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	ws = [str(w).strip() for w in (palabras or []) if 2 <= len(str(w).strip()) <= 12]
	if len(ws) < 3:
		ws = banco_palabras.palabras(tema, i, n, len(tema) + 7)
	ws = list(dict.fromkeys(ws))[:12]
	largo = max(len(w) for w in ws)
	lado = max(largo, min(10, 6 + i // 2 + (1 if d > 0.6 else 0)))
	return {"words": ws, "size": lado, "dirs": 1 if d < 0.25 and i < 2 else (2 if d < 0.6 else 3),
		"seed": 5 + i * 13 + len("".join(ws)), "par": 8 + len(ws) * 7}


## << genero sopa


## >> genero sudoku (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- sudoku
## Mapa: filas de digitos con "." en los huecos (kit/sudoku/sudoku_map.gd). Se hace una solucion
## al azar y se quitan numeros mientras la solucion siga siendo unica. Tamano 4 -> 6 -> 9 y cada
## vez menos pistas.

_SDK_CAJA = {4: (2, 2), 6: (3, 2), 9: (3, 3)}


def _sdk_ok(g: list[list[int]], n: int, x: int, y: int, v: int) -> bool:
	bw, bh = _SDK_CAJA[n]
	if any(g[y][k] == v for k in range(n)) or any(g[k][x] == v for k in range(n)):
		return False
	bx, by = x // bw * bw, y // bh * bh
	return not any(g[yy][xx] == v for yy in range(by, by + bh) for xx in range(bx, bx + bw))


def _sdk_cuenta(g: list[list[int]], n: int, limite: int = 2) -> int:
	mejor = None
	for y in range(n):
		for x in range(n):
			if g[y][x] == 0:
				ops = [v for v in range(1, n + 1) if _sdk_ok(g, n, x, y, v)]
				if not ops:
					return 0
				if mejor is None or len(ops) < len(mejor[2]):
					mejor = (x, y, ops)
	if mejor is None:
		return 1
	x, y, ops = mejor
	total = 0
	for v in ops:
		g[y][x] = v
		total += _sdk_cuenta(g, n, limite - total)
		g[y][x] = 0
		if total >= limite:
			break
	return total


def _sdk_lleno(n: int, rng: random.Random) -> list[list[int]]:
	g = [[0] * n for _ in range(n)]

	def rellena(k: int) -> bool:
		if k == n * n:
			return True
		x, y = k % n, k // n
		vs = list(range(1, n + 1))
		rng.shuffle(vs)
		for v in vs:
			if _sdk_ok(g, n, x, y, v):
				g[y][x] = v
				if rellena(k + 1):
					return True
				g[y][x] = 0
		return False
	rellena(0)
	return g


def generar_sudoku(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 4421 + i * 61)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	lado = 4 if i < 2 and d < 0.5 else (6 if i < 5 or d < 0.3 else 9)
	g = _sdk_lleno(lado, rng)
	## Huecos objetivo: de pocos a muchos (un 9x9 facil deja ~38 pistas, uno dificil ~28).
	quitar = int(lado * lado * (0.42 + 0.25 * d))
	celdas = [(x, y) for y in range(lado) for x in range(lado)]
	rng.shuffle(celdas)
	quitadas = 0
	for (x, y) in celdas:
		if quitadas >= quitar:
			break
		v = g[y][x]
		g[y][x] = 0
		if _sdk_cuenta([fila[:] for fila in g], lado) != 1:
			g[y][x] = v
		else:
			quitadas += 1
	return ["".join(str(v) if v else "." for v in fila) for fila in g]


def parametros_sudoku(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Vidas (fallos permitidos) y segundos para 3 estrellas segun los huecos."""
	huecos = sum(fila.count(".") for fila in (mapa or []))
	lado = len(mapa or []) or 9
	return {"lives": 3, "par": 10 + huecos * (3 if lado <= 4 else (5 if lado <= 6 else 8))}


## << genero sudoku


## >> genero nonograma (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- nonograma (Picross)
## Mapa: el dibujo escondido, "#" pintada y "." vacia (kit/nonogram/nonogram_map.gd). Dibujos de
## una coleccion de pixel art (corazon, gato, cohete...) que crecen de 5x5 a 12x12, o, si no
## quedan, simetricos al azar. Solo se aceptan los que se resuelven con logica de lineas.

_NONO_DIBUJOS = {
	5: [[".#.#.", "#####", "#####", ".###.", "..#.."], ["..#..", ".###.", "#####", "..#..", "..#.."], ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
		[".###.", "#.#.#", "#####", ".#.#.", ".#.#."], ["..#..", ".###.", "##.##", ".###.", "..#.."]],
	7: [["..###..", ".#####.", "##.#.##", "#######", "#.###.#", ".#...#.", "..###.."], ["...#...", "..###..", ".#####.", "#######", "...#...", "...#...", "..###.."],
		["#.....#", "##...##", "#.#.#.#", "#..#..#", "#.....#", "#.....#", "#.....#"], ["..#.#..", ".#####.", "#.###.#", "#######", ".#####.", ".#...#.", "##...##"]],
	8: [["...##...", "..####..", ".######.", "##.##.##", "########", "..#..#..", ".#.##.#.", "#.#..#.#"], ["#......#", "##....##", "########", "#.####.#", "########", ".######.", "..#..#..", ".##..##."],
		["...##...", "..#..#..", "..#..#..", ".######.", "##.##.##", "########", "########", ".##..##."], ["..####..", ".#....#.", "#.#..#.#", "#......#", "#.#..#.#", "#..##..#", ".#....#.", "..####.."]],
	10: [["....##....", "...####...", "...#..#...", "...####...", "..######..", "..##..##..", "..######..", ".########.", "##..##..##", "#...##...#"],
		["..##..##..", ".########.", "##########", "##########", "##########", ".########.", "..######..", "...####...", "....##....", ".........."],
		["#........#", "##......##", "#.#....#.#", "#..####..#", "#.#.##.#.#", "#..####..#", ".#......#.", "..######..", "...#..#...", "..##..##.."]],
}


def _nono_pistas(linea: list[int]) -> list[int]:
	out, k = [], 0
	for v in linea:
		if v:
			k += 1
		elif k:
			out.append(k)
			k = 0
	if k:
		out.append(k)
	return out


def _nono_linea(sabido: list[int], pista: list[int]) -> list[int] | None:
	n = len(sabido)
	comun: list[int] | None = None

	def coloca(ci: int, ini: int, cur: list[int]):
		nonlocal comun
		if ci == len(pista):
			full = cur + [0] * (n - len(cur))
			if any(sabido[i] == 1 for i in range(len(cur), n)):
				return
			comun = full[:] if comun is None else [a if a == b else -1 for a, b in zip(comun, full)]
			return
		largo = pista[ci]
		resto = sum(pista[ci + 1:]) + len(pista) - ci - 1
		for s in range(ini, n - largo - resto + 1):
			if any(sabido[i] == 1 for i in range(ini, s)):
				break
			if any(sabido[i] == 0 for i in range(s, s + largo)):
				continue
			if s + largo < n and sabido[s + largo] == 1:
				continue
			nuevo = cur + [0] * (s - ini) + [1] * largo + ([0] if s + largo < n else [])
			coloca(ci + 1, len(nuevo), nuevo)
	coloca(0, 0, [])
	return comun


def _nono_logico(dibujo: list[str]) -> bool:
	h, w = len(dibujo), len(dibujo[0])
	sol = [[1 if c == "#" else 0 for c in f] for f in dibujo]
	filas = [_nono_pistas(f) for f in sol]
	cols = [_nono_pistas([sol[y][x] for y in range(h)]) for x in range(w)]
	g = [[-1] * w for _ in range(h)]
	cambio = True
	while cambio:
		cambio = False
		for y in range(h):
			r = _nono_linea(g[y], filas[y])
			if r is None:
				return False
			for x in range(w):
				if g[y][x] == -1 and r[x] != -1:
					g[y][x] = r[x]
					cambio = True
		for x in range(w):
			c = _nono_linea([g[y][x] for y in range(h)], cols[x])
			if c is None:
				return False
			for y in range(h):
				if g[y][x] == -1 and c[y] != -1:
					g[y][x] = c[y]
					cambio = True
	return g == sol


def _nono_azar(w: int, h: int, rng: random.Random) -> list[str]:
	for _ in range(400):
		mitad = (w + 1) // 2
		filas = []
		for y in range(h):
			izq = ["#" if rng.random() < 0.55 else "." for _ in range(mitad)]
			filas.append("".join(izq + izq[: w - mitad][::-1]))
		if _nono_logico(filas) and 0 < sum(f.count("#") for f in filas) < w * h:
			return filas
	return ["#" * w] + ["#" + "." * (w - 2) + "#"] * (h - 2) + ["#" * w]


def generar_nonograma(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 613 + i * 7)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	lado = 5 if i < 2 else (7 if i < 4 else (8 if i < 6 else 10))
	if d > 0.7 and lado < 10:
		lado += 1 if lado == 7 else (2 if lado == 8 else 2)
	lista = [p for p in _NONO_DIBUJOS.get(lado, []) if _nono_logico(p)]
	inicio = {5: 0, 6: 0, 7: 2, 8: 4, 9: 4, 10: 6}.get(lado, 0)
	j = i - inicio
	if lista and 0 <= j < len(lista):
		return list(lista[(j + semilla) % len(lista)])
	return _nono_azar(lado, lado, rng)


def parametros_nonograma(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Vidas (fallos permitidos) y segundos para 3 estrellas."""
	m = mapa or ["....."]
	return {"lives": 3, "par": 10 + len(m) * len(m[0])}


## << genero nonograma


## >> genero cortar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- cortar fruta (Fruit Ninja)
## Mapa: una oleada por fila (kit/slice/slice_map.gd): F fruta, G dorada, B bomba. Oleadas mas
## grandes, mas bombas y mas velocidad segun avanza. El analizador juega con el bot.

def generar_cortar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 389 + i * 23)
	d = _cortar_d(i, n, dificultad, ajuste)
	oleadas = 8 + i * 2
	out = []
	for k in range(oleadas):
		tam = min(6, 1 + int((k / max(1, oleadas - 1)) * (2 + d * 3)) + rng.randint(0, 1))
		bombas = 0 if k < 2 or i == 0 else min(2, int(rng.random() < 0.25 + 0.4 * d) + int(rng.random() < 0.2 * d))
		fila = ["F"] * tam
		if rng.random() < 0.15:
			fila[rng.randrange(tam)] = "G"
		for _ in range(bombas):
			fila.insert(rng.randint(0, len(fila)), "B")
		out.append("".join(fila[:7]))
	return out


def _cortar_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def parametros_cortar(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Velocidad, segundos entre oleadas, vidas y semilla."""
	d = _cortar_d(i, n, dificultad, ajuste)
	return {"speed": round(1.0 + 0.4 * d, 2), "gap": round(1.6 - 0.6 * d, 2), "lives": 3, "seed": 7 + i * 11,
		"par": int(len(mapa or []) * 2.6)}


## << genero cortar


## >> genero penaltis (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- penaltis
## Mapa: una letra por tiro (kit/penalty/penalty_map.gd): "." normal, "W" barrera, "T" diana
## dorada. Mas tiros, mas barreras y un portero que engana mas segun avanza. Goles necesarios
## por debajo de lo que saca el bot (el analizador lo comprueba).

def generar_penaltis(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 211 + i * 19)
	d = _pen_d(i, n, dificultad, ajuste)
	tiros = min(10, 5 + i // 2)
	fila = []
	for k in range(tiros):
		r = rng.random()
		fila.append("W" if (i >= 2 and r < 0.15 + 0.2 * d) else ("T" if (i >= 1 and r > 0.8 - 0.1 * d) else "."))
	return ["".join(fila)]


def _pen_d(i: int, n: int, dificultad: str, ajuste: float) -> float:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	return max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))


def parametros_penaltis(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Goles necesarios (mas de la mitad de los tiros), cuanto engana el portero y semilla."""
	d = _pen_d(i, n, dificultad, ajuste)
	tiros = len("".join(mapa or ["....."]))
	return {"goal": max(2, int(tiros * (0.5 + 0.15 * d))), "bluff": round(0.1 + 0.2 * d, 2), "seed": 3 + i * 17, "par": tiros}


## << genero penaltis


## >> genero agujero (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- agujero (Hole.io)
## Mapa: ciudad vista desde arriba, una letra por casilla (kit/hole/hole_map.gd). Calles cada 4
## casillas con coches, conos y gente; aceras con bancos, farolas y arboles; manzanas con
## kioscos, casas y edificios. Ciudad mas grande, meta mas alta y menos tiempo segun avanza.

def generar_agujero(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 977 + i * 41)
	w = min(14, 10 + i // 2)
	h = min(32, 16 + i * 2)
	g = [["." for _ in range(w)] for _ in range(h)]
	for y in range(h):
		for x in range(w):
			calle = x % 5 == 0 or y % 5 == 0
			acera = (x % 5 in (1, 4) or y % 5 in (1, 4)) and not calle
			r = rng.random()
			if calle:
				g[y][x] = "a" if r < 0.18 else ("c" if r < 0.3 else ("p" if r < 0.45 else "."))
			elif acera:
				g[y][x] = "b" if r < 0.15 else ("f" if r < 0.3 else ("t" if r < 0.5 else ("p" if r < 0.65 else ".")))
			else:
				g[y][x] = "E" if r < 0.12 + 0.02 * i else ("h" if r < 0.45 else ("k" if r < 0.65 else "t"))
	## Empieza en un cruce cerca del centro, rodeado de cosas pequenas.
	sx, sy = (w // 2) // 5 * 5, (h // 2) // 5 * 5
	g[sy][sx] = "S"
	for dy in (-1, 0, 1):
		for dx in (-1, 0, 1):
			yy, xx = sy + dy, sx + dx
			if 0 <= yy < h and 0 <= xx < w and (dx or dy):
				g[yy][xx] = rng.choice("cpc")
	return ["".join(f) for f in g]


def parametros_agujero(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Parte de la ciudad que hay que tragar y segundos."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	celdas = len(mapa or []) * len((mapa or [""])[0])
	return {"goal": round(0.45 + 0.3 * d, 2), "seconds": int(30 + celdas * 0.18), "par": int(20 + celdas * 0.1)}


## << genero agujero


## >> genero ciudad (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- ciudad (constructor)
## Mapa: solares ".", agua "~", bosque "^", carretera "=" y ayuntamiento "T"
## (kit/city/city_map.gd). Un rio o un lago, manchas de bosque y el ayuntamiento con un trozo de
## carretera. La meta de habitantes la pone lo que consigue el bot (un 70 %).

def generar_ciudad(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 1291 + i * 37)
	w = min(11, 8 + i // 3)
	h = min(16, 11 + i // 2)
	g = [["." for _ in range(w)] for _ in range(h)]
	## Rio por un lado (o lago) que no corta el mapa.
	if rng.random() < 0.5:
		x = rng.choice([0, w - 1])
		for y in range(h):
			g[y][x] = "~"
			if rng.random() < 0.4:
				x2 = x + (1 if x == 0 else -1)
				g[y][x2] = "~"
	else:
		cx, cy = rng.randrange(1, w - 2), rng.randrange(1, 4)
		for y in range(cy, cy + 2):
			for x in range(cx, cx + 2):
				g[y][x] = "~"
	for _ in range(3 + i // 2):
		bx, by = rng.randrange(w), rng.randrange(h)
		for _ in range(4):
			xx, yy = bx + rng.randint(-1, 1), by + rng.randint(-1, 1)
			if 0 <= xx < w and 0 <= yy < h and g[yy][xx] == ".":
				g[yy][xx] = "^"
	tx, ty = w // 2, h - 3
	g[ty][tx] = "T"
	for y in range(ty - 3, ty):
		g[y][tx] = "="
	for x in range(max(0, tx - 2), min(w, tx + 3)):
		if g[ty - 2][x] in ".^":
			g[ty - 2][x] = "="
	return ["".join(f) for f in g]


def parametros_ciudad(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Habitantes que hay que alcanzar, segundos y dinero de salida."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	segundos = 190 + 36 * min(i, 6)
	return {"goal": int(40 + 22 * i + 30 * d), "seconds": segundos, "money": 400, "par": int(segundos * 0.6)}


## << genero ciudad



## >> genero canasta (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- canasta (lanzamientos)
## Mapa: una letra por tiro (kit/hoops/hoops_map.gd): "." aro quieto, "m" aro que se mueve, "f"
## desde la esquina (triple), "w" con viento. Mas tiros dificiles y mas canastas pedidas segun
## avanza; el analizador lanza con el bot (con error de mano de persona).

def generar_canasta(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 733 + i * 53)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	tiros = min(10, 5 + i // 2)
	tipos = ["."] + (["f"] if i >= 1 else []) + (["m"] if i >= 2 else []) + (["w"] if i >= 4 else [])
	fila = []
	for t in range(tiros):
		fila.append("." if t == 0 or rng.random() > 0.35 + 0.4 * d else rng.choice(tipos))
	return ["".join(fila)]


def parametros_canasta(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Canastas necesarias, semilla y viento."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	tiros = len("".join(mapa or ["....."]))
	return {"goal": max(2, int(tiros * (0.45 + 0.2 * d) + 0.5)), "seed": 5 + i * 13, "wind": 220 + int(120 * d), "par": tiros}


## << genero canasta


## >> genero espiral (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- torre en espiral (Helix Jump)
## Mapa: una fila por piso con 12 casillas alrededor (kit/helix/helix_map.gd): "." suelo, "o"
## hueco, "x" rojo. Cada piso con un hueco; mas pisos, huecos mas estrechos y mas rojo (tambien
## junto al hueco) segun avanza. El analizador juega con el bot (giro y reflejos de persona).

def generar_espiral(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 1543 + i * 29)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	pisos = 12 + i * 3
	filas = []
	hueco = rng.randrange(12)
	for p in range(pisos):
		fila = ["."] * 12
		ancho = 3 if d < 0.3 else (2 if rng.random() < 0.3 + 0.5 * d else 3)
		## El hueco siguiente cerca del anterior (a 1-4 casillas), como en el original.
		hueco = (hueco + rng.choice([-4, -3, -2, 2, 3, 4])) % 12
		for q in range(ancho):
			fila[(hueco + q) % 12] = "o"
		rojos = 0 if p < 2 else min(5, int(rng.random() * (1 + 4 * d)) + (1 if i >= 2 else 0))
		## Donde cae la bola desde el hueco de arriba nunca hay rojo.
		cae = [q for q in range(12) if filas and filas[-1][q] == "o"]
		libres = [q for q in range(12) if fila[q] == "." and q not in cae]
		rng.shuffle(libres)
		for q in libres[:rojos]:
			fila[q] = "x"
		filas.append("".join(fila))
	return filas


def parametros_espiral(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Segundos de bote (mas rapido segun avanza) y giro maximo de una persona."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"bounce": round(0.62 - 0.12 * d, 2), "spin": 5.0, "par": int(len(mapa or []) * 0.7)}


## << genero espiral


## >> genero buscaminas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- buscaminas (sin adivinar)
## Mapa: "*" mina, "." casilla y "S" salida (kit/mines/mines_map.gd). Se colocan minas al azar
## lejos de la salida y solo se acepta el tablero si un resolutor logico (vecinos y
## subconjuntos, como el del kit) lo abre entero sin adivinar.

_BM_N8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]


def _bm_resoluble(w: int, h: int, minas: set, salida: tuple) -> bool:
	def cuenta(c):
		return sum((c[0] + dx, c[1] + dy) in minas for dx, dy in _BM_N8)

	def dentro(c):
		return 0 <= c[0] < w and 0 <= c[1] < h
	abiertas: set = set()
	marcadas: set = set()

	def abrir(c):
		pila = [c]
		abiertas.add(c)
		while pila:
			p = pila.pop()
			if cuenta(p):
				continue
			for dx, dy in _BM_N8:
				n = (p[0] + dx, p[1] + dy)
				if dentro(n) and n not in abiertas and n not in minas:
					abiertas.add(n)
					pila.append(n)
	abrir(salida)
	total = w * h - len(minas)
	while len(abiertas) < total:
		cons = []
		for c in abiertas:
			n = cuenta(c)
			if not n:
				continue
			desc = [(c[0] + dx, c[1] + dy) for dx, dy in _BM_N8 if dentro((c[0] + dx, c[1] + dy)) and (c[0] + dx, c[1] + dy) not in abiertas]
			m = n - sum(1 for u in desc if u in marcadas)
			desc = [u for u in desc if u not in marcadas]
			if desc:
				cons.append((frozenset(desc), m))
		seguras, minas_n = set(), set()
		for u, m in cons:
			if m == 0:
				seguras |= u
			elif m == len(u):
				minas_n |= u
		if not seguras and not minas_n:
			for a, ma in cons:
				for b, mb in cons:
					if a < b:
						d = b - a
						if mb - ma == 0:
							seguras |= d
						elif mb - ma == len(d):
							minas_n |= d
		if not seguras and not minas_n:
			return False
		marcadas |= minas_n
		for s in seguras:
			if s not in abiertas:
				abrir(s)
	return True


def generar_buscaminas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 557 + i * 71)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	w = min(10, 6 + i // 2)
	h = min(14, 8 + i // 2 + i // 3)
	densidad = 0.11 + 0.07 * d + 0.006 * i
	sx, sy = w // 2, h // 2
	for intento in range(400):
		cerca = {(sx + dx, sy + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
		libres = [(x, y) for y in range(h) for x in range(w) if (x, y) not in cerca]
		rng.shuffle(libres)
		minas = set(libres[: int(w * h * densidad)])
		if _bm_resoluble(w, h, minas, (sx, sy)):
			break
		if intento % 40 == 39:
			densidad *= 0.92
	g = [["*" if (x, y) in minas else "." for x in range(w)] for y in range(h)]
	g[sy][sx] = "S"
	return ["".join(f) for f in g]


def parametros_buscaminas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Vidas (minas que se perdonan) y segundos para 3 estrellas."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	celdas = len(mapa or []) * len((mapa or [""])[0])
	return {"lives": 2 if d < 0.5 else 1, "par": 15 + celdas // 2}


## << genero buscaminas


## >> genero conecta (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- conecta 4 contra la maquina
## Mapa: tablero de 6x7 (kit/connect/connect_map.gd): "." vacio, "#" tapada, "R"/"Y" fichas ya
## puestas. Rival que piensa mas y se equivoca menos segun avanza; algunas casillas tapadas
## cambian el tablero. El analizador juega la partida entera con el bot.

def generar_conecta(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 389 + i * 101 + int(ajuste * 1000))
	g = [["."] * 7 for _ in range(6)]
	## Apertura: una ficha de cada uno abajo (cambia con la semilla; asi rehacer el nivel lo cambia).
	xr, xy = rng.sample([1, 2, 3, 4, 5], 2)
	g[5][xr] = "R"
	g[5][xy] = "Y"
	for _ in range(0 if i < 3 else rng.randint(1, 2)):
		x = rng.choice([0, 6])
		y = rng.randint(3, 5)
		for yy in range(y, 6):
			g[yy][x] = "#"
	return ["".join(f) for f in g]


def parametros_conecta(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Lo que piensa el rival, cuanto se equivoca y quien empieza."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"depth": 1 if d < 0.3 else (2 if d < 0.75 else 3), "mistake": round(0.45 - 0.3 * d, 2),
		"first": "player" if i % 2 == 0 else "ai", "seed": 3 + i * 7 + sum((k + 1) * ord(c) for k, c in enumerate("".join(mapa or []))) % 997,
		"par": 21}


## << genero conecta


## >> genero damas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- damas contra la maquina
## Mapa: tablero 8x8 (kit/checkers/checkers_map.gd): "w"/"W" tus fichas y damas, "b"/"B" las del
## rival. Primero partidas cortas con pocas fichas, luego el tablero entero con un rival que
## piensa mas. El analizador juega la partida con el bot.

def generar_damas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 613 + i * 47 + int(ajuste * 1000))
	g = [["."] * 8 for _ in range(8)]
	if i >= 4:
		for y in range(8):
			for x in range(8):
				if (x + y) % 2 == 1:
					if y < 3:
						g[y][x] = "b"
					elif y > 4:
						g[y][x] = "w"
		## Apertura: un primer movimiento de cada uno (cambia con la semilla).
		for fila, destino, ficha in ((5, 4, "w"), (2, 3, "b")):
			op = [(x, nx) for x in range(8) if g[fila][x] == ficha for nx in (x - 1, x + 1) if 0 <= nx < 8 and g[destino][nx] == "."]
			x, nx = rng.choice(op)
			g[fila][x] = "."
			g[destino][nx] = ficha
		return ["".join(f) for f in g]
	fichas = 3 + i
	oscuras_b = [(x, y) for y in range(0, 4) for x in range(8) if (x + y) % 2 == 1]
	oscuras_w = [(x, y) for y in range(4, 8) for x in range(8) if (x + y) % 2 == 1]
	rng.shuffle(oscuras_b)
	rng.shuffle(oscuras_w)
	for (x, y) in oscuras_b[:fichas]:
		g[y][x] = "b"
	for (x, y) in oscuras_w[:fichas + (1 if i < 2 else 0)]:
		g[y][x] = "w"
	return ["".join(f) for f in g]


def parametros_damas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Lo que piensa el rival y cuanto se equivoca."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"depth": 1 if d < 0.35 else (2 if d < 0.8 else 3), "mistake": round(0.4 - 0.25 * d, 2),
		"seed": 5 + i * 11 + sum((k + 1) * ord(c) for k, c in enumerate("".join(mapa or []))) % 997, "par": 40}


## << genero damas


## >> genero billar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- billar (reto en solitario)
## Mapa: mesa en rejilla de 9x15 (kit/pool/pool_map.gd): "C" blanca, "o" bolas. Mas bolas y
## menos tiros de sobra segun avanza; algunas cerca de troneras, otras en el centro. El analizador
## juega con el bot (bola fantasma y simulacion).

def generar_billar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 991 + i * 59 + int(ajuste * 1000))
	g = [["."] * 9 for _ in range(15)]
	g[12][4] = "C"
	bolas = min(9, 2 + i)
	sitios = [(x, y) for y in range(1, 11) for x in range(1, 8) if (x, y) not in ((4, 7),)]
	rng.shuffle(sitios)
	puestas = 0
	for (x, y) in sitios:
		if puestas >= bolas:
			break
		if any(g[yy][xx] == "o" for yy in range(y - 1, y + 2) for xx in range(x - 1, x + 2) if 0 <= yy < 15 and 0 <= xx < 9):
			continue
		g[y][x] = "o"
		puestas += 1
	return ["".join(f) for f in g]


def parametros_billar(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Tiros: las bolas y un margen que baja con la dificultad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	bolas = sum(f.count("o") for f in (mapa or []))
	return {"shots": bolas + max(3, int(bolas * (1.4 - 0.5 * d))), "par": bolas + 2}


## << genero billar


## >> genero solitario (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- solitario clasico (Klondike)
## Mapa: ["klondike:<semilla>"]; el reparto sale de la semilla (kit/klondike/klondike_map.gd). Solo se usan
## semillas que el buscador de soluciones del kit ha resuelto (lista de abajo, con su par).

_SOLITARIO_SEMILLAS = [2, 3, 5, 6, 8, 9, 10, 13, 17, 19, 27, 33, 34, 38, 39, 40, 41, 50, 52, 53, 54, 58, 59, 64, 65, 66, 67, 68, 69, 78,
	79, 80, 81, 82, 84, 85, 86, 89, 93, 94, 95, 96, 98, 100, 102, 103, 104, 107, 108, 111, 112, 113, 114, 123, 124, 127, 128, 129, 133,
	134, 139, 140, 142, 143, 145, 147, 149, 151, 154]


def generar_solitario(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	## El reparto va en el mapa ("klondike:<semilla>") para que al rehacer el nivel cambie.
	k = (i * 7 + semilla * 13) % len(_SOLITARIO_SEMILLAS)
	return [f"klondike:{_SOLITARIO_SEMILLAS[k]}"]


def parametros_solitario(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Semilla del reparto (la del mapa) y segundos para 3 estrellas."""
	fila = (mapa or ["klondike:2"])[0]
	semilla = int(fila.split(":")[1]) if ":" in fila and fila.split(":")[1].isdigit() else _SOLITARIO_SEMILLAS[i % len(_SOLITARIO_SEMILLAS)]
	return {"seed": semilla, "passes": 0, "par": 330}


## << genero solitario


## >> genero parchis (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- parchis (Ludo)
## Mapa: ["ludo:<semilla>"]; las tiradas salen de la semilla (kit/ludo/ludo_map.gd). Mas rivales, mas fichas
## y rivales mas listos segun avanza; el analizador juega la partida con el bot y, si no gana,
## la fabrica prueba otra semilla.

def generar_parchis(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	## La semilla del dado va en el mapa ("ludo:<semilla>") para que al rehacer el nivel cambie.
	return [f"ludo:{(semilla * 31 + i * 101) % 100000}"]


def parametros_parchis(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Rivales, fichas, lo bien que juegan y la semilla del dado."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	fila = (mapa or ["ludo:11"])[0]
	semilla = int(fila.split(":")[1]) if ":" in fila and fila.split(":")[1].isdigit() else 11 + i * 101
	return {"rivals": 1 if i < 2 else (2 if i < 5 else 3), "tokens": 2 if i < 3 else (3 if i < 6 else 4), "skill": round(0.2 + 0.6 * d, 2),
		"seed": semilla, "par": 40 + 12 * i}


## << genero parchis


## >> genero caida (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- bloques que caen
## Mapa: filas de basura de abajo del pozo de 10 (kit/falling/falling_map.gd), con un hueco por
## fila. Mas filas que borrar, mas velocidad y mas basura segun avanza. El analizador juega con el bot.

def generar_caida(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 173 + i * 61)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	filas = 0 if i < 2 else min(9, i - 1 + int(3 * d))
	out = []
	for _ in range(filas):
		f = ["#"] * 10
		f[rng.randrange(10)] = "."
		if rng.random() < 0.3:
			f[rng.randrange(10)] = "."
		out.append("".join(f))
	return out or ["." * 10]


def parametros_caida(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Filas que borrar, velocidad de caida y semilla de las piezas."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"lines": min(40, 6 + 3 * i), "speed": round(min(8.0, 1.0 + 0.45 * i + 1.5 * d), 2),
		"seed": 7 + i * 13 + sum((k2 + 1) * ord(c) for k2, c in enumerate("".join(mapa or []))) % 997, "par": 30 + 9 * i}


## << genero caida


## >> genero bolos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- bolos
## Mapa: una tirada por fila (kit/bowling/bowling_map.gd): "." normal, "o" pista con aceite (la
## bola se tuerce mas), "b" barrera delante del bolo central. Mas tiradas y retos segun avanza; la
## meta de bolos la pone lo que tira una persona normal (menos que el bot).

def generar_bolos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 457 + i * 89)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	tiradas = min(10, 3 + i // 2)
	retos = [] + (["o"] if i >= 1 else []) + (["b"] if i >= 3 else [])
	return ["." if (not retos or rng.random() > 0.25 + 0.4 * d) else rng.choice(retos) for _ in range(tiradas)]


def parametros_bolos(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Bolos que hay que tirar entre todas las tiradas y la semilla del pulso del bot."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	tiradas = len(mapa or ["."] * 3)
	return {"goal": int(tiradas * (5.5 + 2.0 * d)), "seed": 3 + i * 7, "par": tiradas * 9}


## << genero bolos


## >> genero mundo (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- mundo abierto
## Mapa: los biomas de izquierda a derecha (kit/sandbox/sandbox_map.gd), una letra por trozo de 32
## columnas, y una fila "#semilla". Todos los niveles comparten mundo (sale de la semilla del juego,
## no del nivel), asi el mundo, el inventario y la hora se guardan de un nivel al siguiente. Cada
## nivel es una meta de la cadena de fabricacion: mesa, picos, horno, hierro, oro... y la corona.

ESCALERA_MUNDO = [("mesa", 1), ("pico_madera", 1), ("tronco", 10), ("pico_piedra", 1), ("horno", 1), ("antorcha", 8),
	("monstruo", 2), ("lingote_hierro", 3), ("pico_hierro", 1), ("espada_hierro", 1), ("lingote_oro", 4), ("cristal", 4),
	("corona", 1)]
EXTRA_MUNDO = [("cristal", 3), ("monstruo", 2), ("lingote_oro", 3), ("oro", 4), ("lingote_hierro", 4)]


def generar_mundo(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 977 + 31)
	largo = rng.randint(4, 6)
	biomas = [rng.choice("bbllm")]
	while len(biomas) < largo:
		b = rng.choice("blmd")
		## Sin dos desiertos seguidos y con bosque cerca del centro (alli se empieza).
		if b == "d" and biomas[-1] == "d":
			continue
		biomas.append(b)
	centro = largo // 2
	if biomas[centro] not in "bl":
		biomas[centro] = "b"
	return ["".join(biomas), "#%d" % (semilla % 100000)]


def parametros_mundo(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Meta del nivel (la escalera de fabricacion), noche y monstruos. La semilla sale del mapa."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	if i < len(ESCALERA_MUNDO):
		meta, cuantos = ESCALERA_MUNDO[i]
	else:
		vuelta = i - len(ESCALERA_MUNDO)
		meta, cuantos = EXTRA_MUNDO[vuelta % len(EXTRA_MUNDO)]
		cuantos += vuelta // len(EXTRA_MUNDO)
	semilla = 1
	for fila in mapa or []:
		if str(fila).startswith("#") and str(fila)[1:].isdigit():
			semilla = int(str(fila)[1:])
	return {"goal_item": meta, "goal_n": cuantos, "seed": semilla, "day": 180, "night": int(50 + 40 * d),
		"mobs": 1 + int(3 * d), "par": 60 + 25 * i}


## << genero mundo


## >> genero royale (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- battle royale
## Mapa: una isla (kit/royale/royale_map.gd) con playa, pueblos de casas con puertas, bosques y
## rocas. Mas rivales, mejor punteria y menos plazas de victoria segun avanza (del top 5 al ultimo
## en pie). El analizador juega 3 partidas con el bot y pide ganar 2.

def generar_royale(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 7919 + i * 104729)
	S = min(56, 40 + 2 * i)
	g = [["~"] * S for _ in range(S)]
	fases = [rng.random() * 6.28 for _ in range(3)]
	c = (S - 1) / 2
	for y in range(S):
		for x in range(S):
			dx, dy = (x - c) / c, (y - c) / c
			ang = math.atan2(dy, dx)
			borde = 0.8 + 0.08 * math.sin(ang * 3 + fases[0]) + 0.05 * math.sin(ang * 5 + fases[1]) + 0.04 * math.sin(ang * 8 + fases[2])
			d = math.hypot(dx, dy)
			if d < borde:
				g[y][x] = "," if d > borde - 0.09 else "."
	## Pueblos: casas con muro, suelo y una o dos puertas.
	casas = []
	todas_puertas = []
	quiero = rng.randint(6, 9) + S // 12
	for _ in range(400):
		if len(casas) >= quiero:
			break
		w, h = rng.randint(4, 7), rng.randint(4, 6)
		x0, y0 = rng.randint(2, S - w - 3), rng.randint(2, S - h - 3)
		if any(g[y][x] != "." for y in range(y0 - 1, y0 + h + 1) for x in range(x0 - 1, x0 + w + 1)):
			continue
		if any(abs(x0 - a) < 7 and abs(y0 - b) < 6 for a, b in casas):
			continue
		casas.append((x0, y0))
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				borde = y in (y0, y0 + h - 1) or x in (x0, x0 + w - 1)
				g[y][x] = "#" if borde else "_"
		puertas = [(x0 + w // 2, y0 + h - 1), (x0, y0 + h // 2)] if rng.random() < 0.6 else [(x0 + w // 2, y0)]
		for (px, py) in puertas:
			g[py][px] = "_"
			todas_puertas.append((px, py))
	## Bosques y rocas (lejos de las puertas).
	for _ in range(S // 6):
		fx, fy, rad = rng.randint(3, S - 4), rng.randint(3, S - 4), rng.randint(2, 4)
		for y in range(fy - rad, fy + rad + 1):
			for x in range(fx - rad, fx + rad + 1):
				if 0 <= x < S and 0 <= y < S and g[y][x] == "." and rng.random() < 0.32 and (x - fx) ** 2 + (y - fy) ** 2 <= rad * rad:
					g[y][x] = "t"
	for y in range(S):
		for x in range(S):
			if g[y][x] == "." and rng.random() < 0.012:
				g[y][x] = "r"
	## Delante de cada puerta, paso libre (los arboles y rocas se ponen despues de las casas).
	for (px, py) in todas_puertas:
		for (qx, qy) in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
			if g[qy][qx] in "tr":
				g[qy][qx] = "."
	## Todo lo pisable conectado con el centro; lo que quede aislado se hace roca.
	pasa = lambda ch: ch not in "~#tr"
	cx = cy = S // 2
	while not pasa(g[cy][cx]):
		cx += 1
	vistos = {(cx, cy)}
	pila = [(cx, cy)]
	while pila:
		x, y = pila.pop()
		for (nx, ny) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if 0 <= nx < S and 0 <= ny < S and (nx, ny) not in vistos and pasa(g[ny][nx]):
				vistos.add((nx, ny))
				pila.append((nx, ny))
	for y in range(S):
		for x in range(S):
			if pasa(g[y][x]) and (x, y) not in vistos:
				g[y][x] = "r" if g[y][x] != "," else "~"
	return ["".join(f) for f in g]


def parametros_royale(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Rivales, punteria, plazas de victoria y semilla (sale del mapa: al rehacerlo cambia)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 11 + sum((k2 + 3) * ord(ch) for k2, ch in enumerate("".join(mapa or [])[::7])) % 99991
	top = [5, 5, 4, 4, 3, 3, 2, 2][i] if i < 8 else (3 if i % 3 == 1 else 1)
	return {"bots": min(33, 9 + 2 * i + i // 3 * 2), "skill": round(min(0.5, 0.12 + 0.4 * d), 2), "top": top, "seed": semilla, "par": 150 + 10 * i}


## << genero royale


## >> genero cruzar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- cruzar
## Mapa: carriles de abajo a arriba (kit/hopper/hopper_map.gd): hierba con arboles y monedas,
## carreteras con coches y camiones, rios con troncos y vias de tren. Mas carriles, mas rapidos y
## mas seguidos segun avanza. El analizador busca un camino con el bot (simula el futuro).

def generar_cruzar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 613 + i * 2027)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	filas = ["g:" + "".join("c" if rng.random() < 0.08 else "." for _ in range(9))]
	filas[0] = filas[0][:6] + "." + filas[0][7:]
	carriles = 10 + 3 * i + int(6 * d)
	seguidos = 0
	while len(filas) < carriles:
		if seguidos >= 2 + int(2 * d) or rng.random() < 0.28 - 0.1 * d:
			pat = ["t" if rng.random() < 0.18 else ("c" if rng.random() < 0.1 else ".") for _ in range(9)]
			pat[rng.randrange(9)] = "."
			filas.append("g:" + "".join(pat))
			seguidos = 0
			continue
		tipo = rng.random()
		sentido = rng.choice("<>")
		if tipo < 0.55 or i < 1:
			largo = rng.randint(12, 18)
			pat = ["."] * largo
			for _ in range(rng.randint(2, 3 + int(2 * d))):
				x = rng.randrange(largo)
				if rng.random() < 0.3 and x + 1 < largo:
					pat[x] = pat[x + 1] = "T"
				else:
					pat[x] = "c"
			vel = round(rng.uniform(1.2, 2.2) + 1.8 * d, 1)
			filas.append(f"r{sentido}{vel}:" + "".join(pat))
		elif tipo < 0.85 or i < 3:
			largo = rng.randint(12, 16)
			pat = ["."] * largo
			x = 0
			while x < largo:
				t = rng.randint(2, 4)
				for j in range(t):
					if x + j < largo:
						pat[x + j] = "L"
				x += t + rng.randint(1, 2 + int(d))
			vel = round(rng.uniform(0.8, 1.5) + 0.8 * d, 1)
			filas.append(f"w{sentido}{vel}:" + "".join(pat))
		else:
			filas.append(f"t{sentido}{rng.randint(16, 22)}:{rng.randint(5, 9)}")
		seguidos += 1
	filas.append("g:" + "".join("c" if rng.random() < 0.15 else "." for _ in range(9)))
	filas.append("F")
	return filas


def parametros_cruzar(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	return {"par": 25 + 6 * i}


## << genero cruzar


## >> genero arco (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- tiro con arco
## Mapa: dianas, globos y viento (kit/archery/archery_map.gd), en metros desde el arquero. Mas
## lejos, mas pequenas, que se mueven y con mas viento segun avanza. Flechas y meta en parametros.

def generar_arco(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 389 + i * 1543)
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	out = []
	dianas = 1 if i < 2 else rng.randint(1, 3)
	for j in range(dianas):
		x = round(min(85.0, 18 + 3.5 * i + rng.uniform(0, 12) + 10 * j), 1)
		y = round(rng.uniform(0.8, 2.5) + (rng.uniform(0, 8) if i >= 4 and rng.random() < 0.4 else 0), 1)
		r = round(max(0.35, 0.95 - 0.04 * i - 0.2 * d + rng.uniform(-0.05, 0.05)), 2)
		amp = round(rng.uniform(0.5, 1.6) * d, 1) if i >= 3 and rng.random() < 0.6 else 0
		spd = round(rng.uniform(0.15, 0.4), 2) if amp else 0
		out.append(f"t:{x},{y},{r},{amp},{spd}")
	if i >= 2:
		out.append(f"w:{round(rng.uniform(-1, 1) * (0.6 + 2.2 * d), 1)}")
	if rng.random() < 0.4:
		out.append(f"g:{round(rng.uniform(15, 50), 1)},{round(rng.uniform(4, 12), 1)}")
	## Semilla del pulso del bot (cambia al rehacer el nivel).
	out.append(f"#{rng.randint(1, 99999)}")
	return out


def parametros_arco(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	flechas = 5 if i < 3 else 6 + (i % 3)
	semilla = 1
	for f in mapa or []:
		if str(f).startswith("#") and str(f)[1:].isdigit():
			semilla = int(str(f)[1:])
	return {"arrows": flechas, "goal": int(flechas * (5.0 + 2.5 * d)), "seed": semilla, "par": 0}


## << genero arco


## >> genero cubos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- mundo de cubos 3D
## Mapa: los biomas por cuartos del mundo (kit/voxel/voxel_map.gd), una letra cada uno, y una fila
## "#semilla". Todos los niveles comparten mundo (sale de la semilla del juego), asi lo picado, lo
## construido y el inventario siguen de un nivel al siguiente. Cada nivel es una meta de la cadena
## de fabricacion (las mismas recetas que el mundo abierto 2D), sin monstruos.

ESCALERA_CUBOS = [("mesa", 1), ("pico_madera", 1), ("tablas", 12), ("pico_piedra", 1), ("horno", 1), ("antorcha", 6),
	("lingote_hierro", 3), ("pico_hierro", 1), ("espada_hierro", 1), ("lingote_oro", 3), ("cristal", 3), ("corona", 1)]
EXTRA_CUBOS = [("cristal", 3), ("lingote_oro", 3), ("oro", 4), ("lingote_hierro", 4), ("piedra", 30)]


def generar_cubos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rng = random.Random(semilla * 613 + 17)
	biomas = [rng.choice("bbllm") for _ in range(4)]
	## Sin dos desiertos y con bosque en un cuarto por lo menos (madera para empezar).
	if "b" not in biomas:
		biomas[rng.randrange(4)] = "b"
	if biomas.count("d") > 1:
		biomas = [b if b != "d" else "l" for b in biomas]
	return ["".join(biomas), "#%d" % (semilla % 100000)]


def parametros_cubos(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Meta del nivel (la escalera de fabricacion). La semilla sale del mapa."""
	if i < len(ESCALERA_CUBOS):
		meta, cuantos = ESCALERA_CUBOS[i]
	else:
		vuelta = i - len(ESCALERA_CUBOS)
		meta, cuantos = EXTRA_CUBOS[vuelta % len(EXTRA_CUBOS)]
		cuantos += vuelta // len(EXTRA_CUBOS)
	semilla = 1
	for fila in mapa or []:
		if str(fila).startswith("#") and str(fila)[1:].isdigit():
			semilla = int(str(fila)[1:])
	return {"goal_item": meta, "goal_n": cuantos, "seed": semilla, "par": 60 + 30 * i}


## << genero cubos


## >> genero parkour (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- parkour 3D (obby)
## Mapa: una pieza por fila (kit/obby/obby_map.gd): P plataforma, M movil, F fugaz, C control,
## J cama elastica, G meta, L lava, S barra que gira, O moneda. El recorrido avanza por tramos
## (saltos, plataformas moviles, fugaces, barras, lava, camas elasticas y vigas estrechas) con
## giros de vez en cuando; los saltos nunca pasan de lo que alcanza el muneco (unos 4,5 de largo
## y 1,2 de alto). El analizador juega cada nivel con el bot.

TRAMOS_PARKOUR = ["salto", "salto", "movil", "fugaz", "barra", "lava", "cama", "viga", "escalera"]


def _pk_num(v: float) -> str:
	t = ("%.2f" % v).rstrip("0").rstrip(".")
	return "0" if t in ("-0", "") else t


def generar_parkour(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rnd = random.Random(semilla * 7919 + i * 131 + 3)
	dif = {"facil": 0.0, "normal": 0.5, "dificil": 1.0}.get(dificultad, 0.5)
	d = max(0.0, min(1.0, dif * 0.6 + (i / max(1, n - 1)) * 0.5 + ajuste))
	filas: list[str] = []
	x, y, z = 0.0, 0.0, 0.0
	dx, dz = 0.0, -1.0

	def pieza(k: str, cx: float, cy: float, cz: float, largo: float, ancho: float, alto: float, extra: list[float] | None = None) -> None:
		sx, sz = (ancho, largo) if dx == 0 else (largo, ancho)
		vals = [cx, cy - alto / 2.0, cz, sx, alto, sz] + (extra or [])
		filas.append(k + " " + " ".join(_pk_num(v) for v in vals))

	def avanzar(dist: float) -> tuple[float, float]:
		return x + dx * dist, z + dz * dist

	## Salida amplia.
	pieza("P", x, y, z, 5.0, 5.0, 1.0)
	borde = 2.5
	tramos = 6 + min(i, 6) + int(d * 4)
	disponibles = TRAMOS_PARKOUR[:3 + min(len(TRAMOS_PARKOUR) - 3, i + int(d * 4))]
	ultimo = ""
	for t in range(tramos):
		## Punto de control cada 4 tramos.
		if t > 0 and t % 4 == 0:
			gap = 1.5
			x, z = avanzar(borde + gap + 1.5)
			pieza("C", x, y, z, 3.0, 3.0, 1.0)
			borde = 1.5
			## Giro despues del punto de control.
			if rnd.random() < 0.6:
				dx, dz = (rnd.choice([-1.0, 1.0]), 0.0) if dx == 0 else (0.0, -1.0)
		tipo = rnd.choice([tt for tt in disponibles if tt != ultimo] or disponibles)
		ultimo = tipo
		if tipo == "salto":
			gap = 1.4 + rnd.random() * (1.0 + 1.4 * d)
			sube = rnd.choice([0.0, 0.0, 0.6, 1.0, -0.8]) if d > 0.2 else 0.0
			tam = 2.6 - 1.0 * d * rnd.random()
			x, z = avanzar(borde + gap + tam / 2.0)
			y += sube
			pieza("P", x, y, z, tam, tam, 1.0)
			if rnd.random() < 0.5:
				cx, cz = x - dx * (tam / 2.0 + gap / 2.0), z - dz * (tam / 2.0 + gap / 2.0)
				filas.append("O %s %s %s" % (_pk_num(cx), _pk_num(y + 1.6), _pk_num(cz)))
			borde = tam / 2.0
		elif tipo == "movil":
			gap = 1.6 + rnd.random() * 0.8
			x, z = avanzar(borde + gap + 1.25)
			amp = 1.5 + 1.2 * d
			per = 3.6 - 1.0 * d
			ax, az = (amp, 0.0) if dx == 0 else (0.0, amp)
			pieza("M", x, y, z, 2.5, 2.5, 0.6, [ax, 0.0, az, per, rnd.random()])
			x, z = avanzar(1.25 + gap + 1.25)
			pieza("P", x, y, z, 2.5, 2.5, 1.0)
			borde = 1.25
		elif tipo == "fugaz":
			for k in range(2 + int(d * 2)):
				gap = 1.3 + rnd.random() * 0.6
				x, z = avanzar(borde + gap + 1.1)
				pieza("F", x, y, z, 2.2, 2.2, 0.6, [3.0 - 0.6 * d, (k * 0.28) % 1.0])
				borde = 1.1
			gap = 1.4
			x, z = avanzar(borde + gap + 1.25)
			pieza("P", x, y, z, 2.5, 2.5, 1.0)
			borde = 1.25
		elif tipo == "barra":
			gap = 1.5
			largo = 8.0
			x, z = avanzar(borde + gap + largo / 2.0)
			pieza("P", x, y, z, largo, 3.0, 1.0)
			filas.append("S %s %s %s %s %s" % (_pk_num(x), _pk_num(y + 0.55), _pk_num(z), "2.8", _pk_num(1.4 + 1.2 * d)))
			if rnd.random() < 0.6:
				filas.append("O %s %s %s" % (_pk_num(x), _pk_num(y + 2.3), _pk_num(z)))
			borde = largo / 2.0
		elif tipo == "lava":
			gap = 1.5
			largo = 9.0
			x, z = avanzar(borde + gap + largo / 2.0)
			pieza("P", x, y, z, largo, 3.4, 1.0)
			for k in (-1, 1):
				lx, lz = x + dx * k * 2.0, z + dz * k * 2.0
				sx, sz = (3.4, 0.9) if dx == 0 else (0.9, 3.4)
				filas.append("L %s %s %s %s 0.3 %s" % (_pk_num(lx), _pk_num(y + 0.15), _pk_num(lz), _pk_num(sx), _pk_num(sz)))
			borde = largo / 2.0
		elif tipo == "cama":
			gap = 1.5
			x, z = avanzar(borde + gap + 1.25)
			pieza("J", x, y, z, 2.5, 2.5, 0.6)
			gap = 2.0 + rnd.random() * 1.0
			x, z = avanzar(1.25 + gap + 1.5)
			y += 3.5 + rnd.random()
			pieza("P", x, y, z, 3.0, 3.0, 1.0)
			filas.append("O %s %s %s" % (_pk_num(x - dx * 2.5), _pk_num(y + 1.0), _pk_num(z - dz * 2.5)))
			borde = 1.5
		elif tipo == "viga":
			gap = 1.4
			largo = 6.0 + 2.0 * d
			x, z = avanzar(borde + gap + largo / 2.0)
			pieza("P", x, y, z, largo, 1.1 - 0.3 * d, 0.5)
			borde = largo / 2.0
		elif tipo == "escalera":
			for k in range(3):
				gap = 1.2 + rnd.random() * 0.6
				lado = rnd.choice([-1.2, 1.2])
				x, z = avanzar(borde + gap + 0.9)
				y += 0.9
				ox, oz = (lado, 0.0) if dx == 0 else (0.0, lado)
				pieza("P", x + ox, y, z + oz, 1.8, 1.8, 0.8)
				x, z = x + ox, z + oz
				borde = 0.9
	gap = 1.6
	x, z = avanzar(borde + gap + 2.5)
	pieza("G", x, y, z, 5.0, 5.0, 1.0)
	return filas


def parametros_parkour(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""El par lo pone el analizador (con el bot); aqui un valor de reserva por largo del recorrido."""
	piezas = len([f for f in (mapa or []) if f[:1] in "PMFCJG"])
	return {"par": 20 + 6 * piezas}


## << genero parkour


## >> genero tienda (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- tienda 3D (idle arcade)
## Mapa: la tienda vista desde arriba (kit/market/market_map.gd). "#" pared, "." suelo, "1"-"4"
## cajas de producto, "a"-"d" sus estanterias, "R" caja registradora, "E" puerta, "S" reponedor,
## "K" cajero, "U" mejora. Todos los niveles son la misma tienda (sale de la semilla del juego),
## asi lo abierto y el dinero siguen de un nivel al siguiente; cada nivel pide vender mas.


def _plano_tienda(semilla: int) -> list[str]:
	rnd = random.Random(semilla * 389 + 11)
	n = rnd.choice([3, 4, 4])
	ancho = 2 * n + 1
	filas = [["#"] * ancho] + [["#"] + ["."] * (ancho - 2) + ["#"] for _ in range(12)] + [["#"] * ancho]
	orden = list(range(n))
	rnd.shuffle(orden)
	for col, prod in enumerate(orden):
		x = 1 + 2 * col
		filas[1][x] = str(prod + 1)
		filas[4][x] = "abcd"[prod]
	izquierda = rnd.random() < 0.5
	rx = 1 if izquierda else ancho - 2
	filas[10][rx] = "R"
	mid = ancho // 2
	filas[13][mid] = "E"
	libres = [x for x in range(2, ancho - 2) if x != rx and abs(x - rx) > 1]
	rnd.shuffle(libres)
	## Reponedor y cajero separados (sus carteles no se pisan).
	filas[8][libres[0]] = "S"
	lejos = [x for x in libres[1:] if abs(x - libres[0]) >= 3]
	if lejos:
		filas[8][lejos[0]] = "K"
	else:
		filas[12][libres[0]] = "K"
	filas[6][ancho - 2 if izquierda else 1] = "U"
	return ["".join(f) for f in filas]


def generar_tienda(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return _plano_tienda(semilla) + ["#%d" % (semilla % 100000)]


def parametros_tienda(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Lo que hay que vender en el nivel, precios de abrir y de contratar, y cada cuanto entra gente."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 1
	for fila in mapa or []:
		if str(fila).startswith("#") and str(fila)[1:].isdigit():
			semilla = int(str(fila)[1:])
	return {"goal": int(70 + 70 * i + 60 * d), "products": 1, "costs": [0, 40, 120, 260], "hire": [150, 240], "upgrade": 60,
		"spawn": round(max(4.0, 6.0 - 0.15 * i), 2), "seed": semilla + i, "par": 120 + 40 * i}


## << genero tienda


## >> genero futbol (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- futbol 3D (arcade)
## Mapa: solo la fila "#semilla" (el campo es siempre igual: kit/soccer/soccer_map.gd). Cada nivel
## es un partido contra un rival mejor: mas destreza ("skill"), y desde la mitad del juego 4 por
## equipo. El analizador juega 3 partidos con el bot y pide ganar 2.


def generar_futbol(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return ["campo", "#%d" % ((semilla * 31 + i * 7) % 100000)]


def parametros_futbol(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Rival cada vez mejor, partidos algo mas largos y mas jugadores al final."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"players": 3 if i < max(2, n // 2) else 4, "skill": round(0.12 + 0.55 * d, 2), "mates": round(0.6 + 0.1 * d, 2),
		"time": 90 + 10 * min(i, 3), "need": 1, "par": 90}


## << genero futbol


## >> genero terror (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- terror 3D (escapa de la casa)
## Mapa: casillas de 2 m (kit/horror/horror_map.gd): "#" pared, "." suelo, "P" entrada, "X" puerta
## de salida, "k" llaves, "M" monstruo, "H" armarios. La casa es un laberinto con atajos (para
## poder dar la vuelta al monstruo) y algunas salas; las llaves lejos de la entrada y los
## armarios en los rincones. El analizador juega la casa con el bot.


def generar_terror(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rnd = random.Random(semilla * 7331 + i * 97 + 5)
	dif = {"facil": 0.0, "normal": 0.5, "dificil": 1.0}.get(dificultad, 0.5)
	d = max(0.0, min(1.0, dif * 0.5 + (i / max(1, n - 1)) * 0.6 + ajuste))
	cw = 5 + min(3, i // 2)
	ch = 6 + min(3, (i + 1) // 2)
	w, h = cw * 2 + 1, ch * 2 + 1
	g = [["#"] * w for _ in range(h)]
	## 1 - Laberinto (busqueda en profundidad).
	vis = set()
	pila = [(0, 0)]
	vis.add((0, 0))
	g[1][1] = "."
	while pila:
		cx, cy = pila[-1]
		vec = [(cx + dx, cy + dy, dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
			if 0 <= cx + dx < cw and 0 <= cy + dy < ch and (cx + dx, cy + dy) not in vis]
		if not vec:
			pila.pop()
			continue
		nx, ny, dx, dy = rnd.choice(vec)
		g[cy * 2 + 1 + dy][cx * 2 + 1 + dx] = "."
		g[ny * 2 + 1][nx * 2 + 1] = "."
		vis.add((nx, ny))
		pila.append((nx, ny))
	## 2 - Atajos: se tiran paredes para que haya vueltas (menos en dificil).
	muros = [(x, y) for y in range(1, h - 1) for x in range(1, w - 1) if g[y][x] == "#" and (x % 2) != (y % 2)]
	rnd.shuffle(muros)
	for x, y in muros[:int(len(muros) * (0.32 - 0.12 * d))]:
		g[y][x] = "."
	## 3 - Un par de salas.
	for _ in range(2):
		rx, ry = rnd.randrange(1, w - 4), rnd.randrange(1, h - 4)
		for yy in range(ry, ry + 3):
			for xx in range(rx, rx + 3):
				g[yy][xx] = "."
	## 4 - Entrada abajo a la izquierda y salida arriba (puerta en la pared de fuera).
	g[h - 2][1] = "P"
	sx = rnd.randrange(1, cw) * 2 + 1
	g[0][sx] = "X"
	g[1][sx] = "." if g[1][sx] == "#" else g[1][sx]
	## Distancias desde la entrada.
	from collections import deque
	dist = {(1, h - 2): 0}
	q = deque([(1, h - 2)])
	while q:
		x, y = q.popleft()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			nx, ny = x + dx, y + dy
			if 0 < nx < w - 1 and 0 < ny < h - 1 and g[ny][nx] != "#" and (nx, ny) not in dist:
				dist[(nx, ny)] = dist[(x, y)] + 1
				q.append((nx, ny))
	libres = [c for c in dist if g[c[1]][c[0]] == "."]
	## 5 - Llaves: lejos de la entrada y separadas entre si.
	nllaves = 2 + min(2, i // 3) + (1 if d > 0.7 else 0)
	orden = sorted(libres, key=lambda c: -dist[c])
	llaves = []
	for c in orden:
		if len(llaves) >= nllaves:
			break
		if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) > 6 for o in llaves):
			llaves.append(c)
	for x, y in llaves:
		g[y][x] = "k"
	## 6 - Armarios en rincones (casillas con tres paredes alrededor), repartidos.
	rincones = [c for c in libres if g[c[1]][c[0]] == "." and sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g[c[1] + dy][c[0] + dx] == "#") == 3]
	rnd.shuffle(rincones)
	narm = 4 + cw // 2 - int(d * 2)
	puestos = []
	for c in rincones:
		if len(puestos) >= narm:
			break
		if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) > 4 for o in puestos) and dist[c] > 2:
			puestos.append(c)
	for x, y in puestos:
		g[y][x] = "H"
	## 7 - Monstruo: en el centro, lejos de la entrada.
	cand = [c for c in libres if g[c[1]][c[0]] == "." and dist[c] > 8]
	cand.sort(key=lambda c: abs(c[0] - w // 2) + abs(c[1] - h // 2))
	mx, my = cand[0] if cand else orden[len(orden) // 2]
	g[my][mx] = "M"
	return ["".join(f) for f in g] + ["#%d" % ((semilla * 13 + i) % 100000)]


def parametros_terror(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Monstruo mas rapido y que ve mas lejos segun avanza el juego."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"lives": 3, "speed": round(0.2 + 0.7 * d, 2), "sight": round(6.0 + 4.0 * d, 1), "par": 90 + 20 * i}


## << genero terror


## >> genero conduccion (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- conduccion 3D (repartos)
## Mapa: la ciudad en casillas de 10 m (kit/drive/drive_map.gd): "." calle, "#" edificios, "p"
## parque, "S" salida. Calles en cuadricula con algun tramo cortado y manzanas grandes; los
## repartos (recoger y entregar) lejos entre si. El tiempo por reparto sale del camino mas largo
## a la velocidad de una persona normal; el analizador lo conduce con el bot.


def _calles_conduccion(rnd: "random.Random", w: int, h: int) -> list[list[str]]:
	g = [["#"] * w for _ in range(h)]
	for y in range(h):
		for x in range(w):
			if x % 4 == 0 or y % 4 == 0:
				g[y][x] = "."
	## Bordes de la ciudad: solo calle por dentro.
	for y in range(h):
		g[y][0] = "." if g[y][0] == "." else "#"
	## Algunos tramos cortados (manzanas mas grandes), sin dejar callejones sin salida.
	tramos = [(x, y) for y in range(1, h - 1) for x in range(1, w - 1) if g[y][x] == "." and (x % 4 == 0) != (y % 4 == 0)]
	rnd.shuffle(tramos)
	for x, y in tramos[:len(tramos) // 7]:
		g[y][x] = "#"
		if not _conectada(g, w, h) or _callejones(g, w, h):
			g[y][x] = "."
	## Parques en alguna manzana.
	for by in range(0, h // 4):
		for bx in range(0, w // 4):
			if rnd.random() < 0.18:
				for yy in range(by * 4 + 1, min(h, by * 4 + 4)):
					for xx in range(bx * 4 + 1, min(w, bx * 4 + 4)):
						if g[yy][xx] == "#":
							g[yy][xx] = "p"
	return g


def _conectada(g, w, h) -> bool:
	calles = [(x, y) for y in range(h) for x in range(w) if g[y][x] == "."]
	if not calles:
		return False
	vis = {calles[0]}
	pila = [calles[0]]
	while pila:
		x, y = pila.pop()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			n = (x + dx, y + dy)
			if 0 <= n[0] < w and 0 <= n[1] < h and n not in vis and g[n[1]][n[0]] == ".":
				vis.add(n)
				pila.append(n)
	return len(vis) == len(calles)


def _callejones(g, w, h) -> bool:
	for y in range(h):
		for x in range(w):
			if g[y][x] == "." and sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
					if 0 <= x + dx < w and 0 <= y + dy < h and g[y + dy][x + dx] == ".") <= 1:
				return True
	return False


def _dist_conduccion(g, w, h, a):
	from collections import deque
	dist = {a: 0}
	q = deque([a])
	while q:
		x, y = q.popleft()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			n = (x + dx, y + dy)
			if 0 <= n[0] < w and 0 <= n[1] < h and n not in dist and g[n[1]][n[0]] in ".S":
				dist[n] = dist[(x, y)] + 1
				q.append(n)
	return dist


def generar_conduccion(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rnd = random.Random(semilla * 4241 + 9)
	w, h = 13, 17
	g = _calles_conduccion(rnd, w, h)
	g[h - 1][0] = "S"
	return ["".join(f) for f in g] + ["#%d" % ((semilla * 7 + i * 13) % 100000)]


def parametros_conduccion(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Repartos del nivel, tiempo por reparto (por el camino mas largo) y trafico."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	filas = [f for f in (mapa or []) if not (str(f).startswith("#") and str(f)[1:].isdigit())]
	semilla = 1
	for f in mapa or []:
		if str(f).startswith("#") and str(f)[1:].isdigit():
			semilla = int(str(f)[1:])
	rnd = random.Random(semilla * 31 + i)
	h = len(filas)
	w = len(filas[0]) if filas else 0
	g = [list(f) for f in filas]
	calles = [(x, y) for y in range(h) for x in range(w) if g[y][x] == "."]
	inicio = next(((x, y) for y in range(h) for x in range(w) if g[y][x] == "S"), (0, h - 1))
	njobs = 2 + min(3, i // 2)
	jobs = []
	pos = inicio
	peor = 0
	for _ in range(njobs):
		dpos = _dist_conduccion(g, w, h, pos)
		lejos = [c for c in calles if dpos.get(c, 0) >= 6] or calles
		a = rnd.choice(lejos)
		da = _dist_conduccion(g, w, h, a)
		lejos2 = [c for c in calles if da.get(c, 0) >= 7] or calles
		b = rnd.choice(lejos2)
		peor = max(peor, dpos.get(a, 10) + da.get(b, 10))
		jobs.append([a[0], a[1], b[0], b[1]])
		pos = b
	tiempo = peor * 10.0 / 8.5 * (1.9 - 0.55 * d) + 10.0
	return {"jobs": jobs, "time": round(tiempo, 1), "traffic": 4 + int(8 * d), "speed": round(0.3 + 0.5 * d, 2), "par": int(njobs * tiempo * 0.6)}


## << genero conduccion


## >> genero zombis (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- zombis 3D (shooter por oleadas)
## Mapa: casillas de 2 m (kit/zombie/zombie_map.gd): "#" muro, "c" cajas, "." suelo, "P" salida,
## "Z" por donde entran los zombis, "S" escopeta, "R" fusil, "+" botiquin. Arena cerrada con
## muretes y montones de cajas (para cubrirse y dar vueltas), entradas de zombis repartidas por
## el borde y las armas lejos de la salida. El analizador juega todas las oleadas con el bot.


def _conectado_zombis(g, w, h) -> bool:
	libres = [(x, y) for y in range(h) for x in range(w) if g[y][x] not in "#c"]
	if not libres:
		return False
	vis = {libres[0]}
	pila = [libres[0]]
	while pila:
		x, y = pila.pop()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			n = (x + dx, y + dy)
			if 0 <= n[0] < w and 0 <= n[1] < h and n not in vis and g[n[1]][n[0]] not in "#c":
				vis.add(n)
				pila.append(n)
	return len(vis) == len(libres)


def generar_zombis(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	rnd = random.Random(semilla * 6151 + i * 71 + 3)
	w = 15 + 2 * min(2, i // 3)
	h = 15 + 2 * min(3, i // 2)
	g = [["#" if x in (0, w - 1) or y in (0, h - 1) else "." for x in range(w)] for y in range(h)]
	cx, cy = w // 2, h // 2
	## 1 - Muretes cortos y montones de cajas, sin cerrar zonas ni tapar el centro.
	piezas = 6 + rnd.randrange(4) + i // 2
	for _ in range(piezas * 3):
		if piezas <= 0:
			break
		x, y = rnd.randrange(2, w - 2), rnd.randrange(2, h - 2)
		if abs(x - cx) <= 1 and abs(y - cy) <= 1:
			continue
		if rnd.random() < 0.45:
			largo = rnd.randrange(2, 4)
			horiz = rnd.random() < 0.5
			celdas = [(x + k, y) if horiz else (x, y + k) for k in range(largo)]
			c = "#"
		else:
			celdas = [(x, y)] + ([(x + 1, y)] if rnd.random() < 0.5 else [])
			c = "c"
		if any(not (2 <= a < w - 2 and 2 <= b < h - 2) or g[b][a] != "." or (abs(a - cx) <= 1 and abs(b - cy) <= 1) for a, b in celdas):
			continue
		viejo = [g[b][a] for a, b in celdas]
		for a, b in celdas:
			g[b][a] = c
		if not _conectado_zombis(g, w, h):
			for (a, b), v in zip(celdas, viejo):
				g[b][a] = v
			continue
		piezas -= 1
	## 2 - Entradas de zombis en el borde (por dentro), repartidas por los cuatro lados.
	bordes = [(x, 1) for x in range(2, w - 2)] + [(x, h - 2) for x in range(2, w - 2)] + \
		[(1, y) for y in range(2, h - 2)] + [(w - 2, y) for y in range(2, h - 2)]
	rnd.shuffle(bordes)
	nz = 4 + min(4, i // 2)
	puestos = []
	for b in bordes:
		if len(puestos) >= nz:
			break
		if g[b[1]][b[0]] == "." and all(abs(b[0] - p[0]) + abs(b[1] - p[1]) >= 5 for p in puestos):
			puestos.append(b)
	for x, y in puestos:
		g[y][x] = "Z"
	g[cy][cx] = "P"
	## 3 - Armas y botiquines lejos del centro (hay que ir a por ellos).
	libres = [(x, y) for y in range(2, h - 2) for x in range(2, w - 2) if g[y][x] == "." and abs(x - cx) + abs(y - cy) >= 4]
	rnd.shuffle(libres)
	cosas = (["S"] if i >= 1 else []) + (["R"] if i >= 3 else []) + ["+", "+"]
	for c in cosas:
		if libres:
			x, y = libres.pop()
			g[y][x] = c
	return ["".join(f) for f in g] + ["#%d" % ((semilla * 11 + i * 17) % 100000)]


def parametros_zombis(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Oleadas, zombis por oleada, su velocidad y desde que oleada salen corredores y brutos."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	oleadas = 3 + min(5, i // 2)
	cuenta = 4 + int(4 * d)
	crece = 2 + int(2 * d)
	tipos = [max(2, 3 - i // 4), max(3, 5 - i // 3)]
	total = sum(cuenta + crece * w for w in range(oleadas))
	return {"waves": oleadas, "count": cuenta, "grow": crece, "speed": round(0.25 + 0.6 * d, 2), "hp": 100,
		"types": tipos, "par": int(total * 3.2 + oleadas * 6)}


## << genero zombis


## >> genero baloncesto (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- baloncesto 3D (partido callejero)
## La pista es siempre la misma (media pista, kit/basket/basket_map.gd); el mapa solo lleva la
## semilla del partido. Primero 1 contra 1, luego 2 contra 2 y al final 3 contra 3, con el rival
## cada vez mejor. El analizador juega tres partidos con el bot y pide ganar dos.


def generar_baloncesto(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return ["pista", "#%d" % ((semilla * 53 + i * 11) % 100000)]


def parametros_baloncesto(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Mas jugadores por equipo y rival mejor segun avanza; partidos a 11 (los ultimos a 15)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	jugadores = 1 if i < 2 else (2 if i < max(4, n * 2 // 3) else 3)
	puntos = 11 if i < n - 2 else 15
	return {"players": jugadores, "skill": round(0.15 + 0.6 * d, 2), "mates": round(0.55 + 0.15 * d, 2),
		"points": puntos, "time": 150 + 30 * (puntos > 11), "par": 120}


## << genero baloncesto


## >> genero tenis (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- tenis 3D (partido individual)
## La pista es siempre la misma (kit/tennis/tennis_map.gd); el mapa solo lleva la semilla del
## partido. Primero partidos a 1 juego, luego a 2 y a 3, con el rival mejor y la pelota mas
## rapida. El analizador juega tres partidos con el bot y pide ganar dos.


def generar_tenis(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	return ["pista", "#%d" % ((semilla * 59 + i * 13) % 100000)]


def parametros_tenis(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Rival cada vez mejor, pelota mas rapida y partidos mas largos al final."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	juegos = 1 if i < 2 else (2 if i < max(4, n * 2 // 3) else 3)
	return {"skill": round(0.25 + 0.55 * d, 2), "games": juegos, "speed": round(0.25 + 0.5 * d, 2), "par": 60 + 70 * juegos}


## << genero tenis


## >> genero karts (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## ---------------------------------------------------------------- karts 3D (carreras en circuito)
## Mapa: los puntos de control del circuito (kit/kart/kart_map.gd), uno por fila "x,y" en metros,
## en orden y cerrado; "B,k" pone una placa de turbo en el punto k; "#semilla". El circuito sale
## de una vuelta alrededor del centro con el radio cambiando (curvas abiertas, horquillas y
## rectas); se descartan los que se cruzan consigo mismos o tienen curvas imposibles. El
## analizador corre tres carreras con el bot.


def _suave_karts(pts, w):
	"""Distancia minima entre tramos no vecinos (para que la pista no se pise)."""
	import math
	n = len(pts)
	dens = []
	for k in range(n):
		a, b = pts[k], pts[(k + 1) % n]
		pasos = max(2, int(math.dist(a, b) / 3))
		for s in range(pasos):
			t = s / pasos
			dens.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
	m = len(dens)
	acum = [0.0]
	for i in range(1, m):
		acum.append(acum[-1] + math.dist(dens[i - 1], dens[i]))
	total = acum[-1] + math.dist(dens[-1], dens[0])
	peor = 1e9
	for i in range(0, m, 2):
		for j in range(i + 1, m, 2):
			da = abs(acum[i] - acum[j])
			da = min(da, total - da)
			if da > w * 4:
				peor = min(peor, math.dist(dens[i], dens[j]))
	return peor, total


def generar_karts(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	import math
	rnd = random.Random(semilla * 9173 + i * 131 + 7)
	ancho = 12.0
	mejor = None
	for intento in range(200):
		npts = rnd.randrange(9, 14)
		radio = 55 + 10 * min(i, 4) + rnd.uniform(-5, 10)
		estira = rnd.uniform(0.75, 1.35)
		pts = []
		for k in range(npts):
			a = 2 * math.pi * k / npts + rnd.uniform(-0.18, 0.18)
			r = radio * rnd.uniform(0.55, 1.15)
			pts.append((math.cos(a) * r * estira, math.sin(a) * r / estira))
		## Angulos: ninguna esquina demasiado cerrada (horquilla de mas de 140 grados).
		ok = True
		for k in range(npts):
			p0, p1, p2 = pts[k - 1], pts[k], pts[(k + 1) % npts]
			v1 = (p1[0] - p0[0], p1[1] - p0[1])
			v2 = (p2[0] - p1[0], p2[1] - p1[1])
			c = (v1[0] * v2[0] + v1[1] * v2[1]) / max(1e-6, math.hypot(*v1) * math.hypot(*v2))
			if c < -0.35 or math.hypot(*v1) < 14:
				ok = False
				break
		if not ok:
			continue
		peor, total = _suave_karts(pts, ancho)
		if peor < ancho + 8 or total < 300:
			continue
		mejor = pts
		break
	if mejor is None:
		mejor = [(math.cos(2 * math.pi * k / 10) * 70, math.sin(2 * math.pi * k / 10) * 45) for k in range(10)]
	filas = ["%.1f,%.1f" % p for p in mejor]
	## Turbos en las rectas (los tramos mas largos), no en la meta.
	largos = sorted(range(1, len(mejor)), key=lambda k: -math.dist(mejor[k], mejor[(k + 1) % len(mejor)]))
	for k in largos[: 2 + (i >= 3)]:
		filas.append("B,%d" % k)
	return filas + ["#%d" % ((semilla * 13 + i * 29) % 100000)]


def parametros_karts(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Rivales mejores, mas vueltas y, al final, solo vale ganar."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	necesita = 3 if i < max(1, n // 4) else (2 if i < max(2, n // 2) else 1)
	vueltas = 2 if i < 3 else 3
	return {"laps": vueltas, "skill": round(0.15 + 0.5 * d, 2), "need": necesita, "rivals": 5, "width": 12, "par": 40 * vueltas}


## << genero karts


## >> genero supervivencia (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_supervivencia(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Isla vista desde arriba (kit/survival/survival_map.gd): "~" mar, "." hierba, "," arena,
	"T" arbol, "R" roca, "G" hierba alta, "B" bayas, "W" charca, "D" guarida, "X" restos, "P" salida.
	Reglas de justicia (las mismas que comprueba map_issues en el kit):
	1 - Agua dulce y al menos 2 arbustos de bayas al alcance; la charca cerca de la salida.
	2 - Madera, piedra y fibra de sobra para herramientas, hogueras y (si toca) la balsa.
	3 - Las guaridas lejos de la salida (7 casillas o mas), en la otra punta de la isla.
	4 - Mas grande, con mas guaridas y menos bayas segun avanza el juego y la dificultad.
	Estilos (opciones["estilos_superv"], los giros apocalipsis, invierno y caza; ver PRESETS en el kit):
	apocalipsis: guaridas de zombis "Z", casas "H" y coches "C" que saquear y ciervos "A";
	invierno: ciervos "A" (carne y piel para el abrigo); caza: ciervos "A" y jabalies "J"."""
	estilos = list((opciones or {}).get("estilos_superv") or [])
	rnd = random.Random(semilla * 7919 + i * 104729 + 17)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	lado = 20 + 2 * min(i, 5)
	for _ in range(300):
		g = [["~"] * lado for _ in range(lado)]
		c = (lado - 1) / 2.0
		blobs = [(c + rnd.uniform(-lado * 0.18, lado * 0.18), c + rnd.uniform(-lado * 0.18, lado * 0.18), lado * rnd.uniform(0.2, 0.32))
			for _ in range(4 + rnd.randrange(3))]
		blobs.append((c, c, lado * 0.3))
		for y in range(2, lado - 2):
			for x in range(2, lado - 2):
				if any((x - bx) ** 2 + (y - by) ** 2 <= r * r for bx, by, r in blobs):
					g[y][x] = "."
		# Solo la isla mas grande.
		tierra = [(y, x) for y in range(lado) for x in range(lado) if g[y][x] == "."]
		if not tierra:
			continue
		trozos, visto = [], set()
		for t in tierra:
			if t in visto:
				continue
			grupo, cola = [], [t]
			visto.add(t)
			while cola:
				a = cola.pop()
				grupo.append(a)
				for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					b = (a[0] + dy, a[1] + dx)
					if b not in visto and g[b[0]][b[1]] == ".":
						visto.add(b)
						cola.append(b)
			trozos.append(grupo)
		isla = set(max(trozos, key=len))
		for y, x in tierra:
			if (y, x) not in isla:
				g[y][x] = "~"
		for y, x in isla:
			if any(g[y + dy][x + dx] == "~" for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))):
				g[y][x] = ","
		interior = [t for t in isla if g[t[0]][t[1]] == "."]
		if len(interior) < 120:
			continue
		# Salida: tierra en la mitad de abajo, cerca del centro.
		salida = min(interior, key=lambda t: abs(t[1] - c) + abs(t[0] - (c + lado * 0.12)) + rnd.random())
		libres = {salida} | {(salida[0] + dy, salida[1] + dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)}
		# Charca de 2x2 a 4-7 casillas, en hierba (no pegada al mar).
		def poner_charca(dmin, dmax):
			cand = [(y, x) for y, x in interior if dmin <= abs(y - salida[0]) + abs(x - salida[1]) <= dmax
				and all((y + a, x + b) in isla and g[y + a][x + b] == "." and (y + a, x + b) not in libres for a in (0, 1) for b in (0, 1))
				and all(g[y + a][x + b] != "~" and g[y + a][x + b] != "," for a in (-1, 0, 1, 2) for b in (-1, 0, 1, 2))]
			if not cand:
				return False
			y, x = rnd.choice(cand)
			for a in (0, 1):
				for b in (0, 1):
					g[y + a][x + b] = "W"
					libres.add((y + a, x + b))
			# Alrededor de la charca, paso libre.
			for a in (-1, 0, 1, 2):
				for b in (-1, 0, 1, 2):
					libres.add((y + a, x + b))
			return True
		if not poner_charca(4, 7):
			continue
		if i >= 3 and not poner_charca(9, 16):
			pass
		# Guaridas: lejos de la salida, hacia el borde.
		n_dens = 1 + (1 if i >= 2 else 0) + (1 if dif >= 2.0 and i >= 4 else 0)
		lejos = sorted([t for t in isla if g[t[0]][t[1]] in ".," and abs(t[0] - salida[0]) + abs(t[1] - salida[1]) >= 9],
			key=lambda t: -(abs(t[0] - salida[0]) + abs(t[1] - salida[1])) + rnd.random() * 6)
		dens = []
		for t in lejos:
			if len(dens) >= n_dens:
				break
			if all(abs(t[0] - d[0]) + abs(t[1] - d[1]) >= 8 for d in dens) and t not in libres:
				dens.append(t)
		if len(dens) < n_dens:
			continue
		for y, x in dens:
			g[y][x] = "D"
			for a in (-1, 0, 1):
				for b in (-1, 0, 1):
					libres.add((y + a, x + b))
		# Recursos.
		huecos = [t for t in isla if g[t[0]][t[1]] in ".," and t not in libres]
		rnd.shuffle(huecos)
		n_land = len(isla)
		cuantos = {"T": int(n_land * 0.13), "R": int(n_land * 0.05), "G": int(n_land * 0.06),
			"B": max(3, int(7 - dif - i * 0.4))}
		pos = 0
		cerca_b = [t for t in huecos if abs(t[0] - salida[0]) + abs(t[1] - salida[1]) <= 7]
		bayas = cerca_b[:2] + [t for t in huecos if t not in cerca_b[:2]][: max(0, cuantos["B"] - 2)]
		for y, x in bayas:
			g[y][x] = "B"
		resto = [t for t in huecos if t not in bayas]
		for k in ("T", "R", "G"):
			for y, x in resto[pos:pos + cuantos[k]]:
				# Rocas y hierba alta en hierba; los arboles tambien en la arena (palmeras).
				g[y][x] = k if (g[y][x] == "." or k == "T") else g[y][x]
			pos += cuantos[k]
		if i < 3 or dificultad == "facil":
			cerca = [t for t in resto[pos:] if 2 <= abs(t[0] - salida[0]) + abs(t[1] - salida[1]) <= 4]
			if cerca:
				g[cerca[0][0]][cerca[0][1]] = "X"
		## Estilos: guaridas de otro bicho, casas y coches que saquear y prados con ciervos.
		libres_est = [t for t in resto[pos + 1:] if g[t[0]][t[1]] in ".," and abs(t[0] - salida[0]) + abs(t[1] - salida[1]) >= 3]
		if "apocalipsis" in estilos:
			for y, x in dens:
				g[y][x] = "Z"
			for k, ch in enumerate(["H"] * (3 + min(i, 3)) + ["C"] * 2):
				if k < len(libres_est):
					y, x = libres_est[k]
					g[y][x] = ch
			libres_est = libres_est[3 + min(i, 3) + 2:]
		elif "caza" in estilos:
			for y, x in dens:
				g[y][x] = "J"
		if any(e in estilos for e in ("apocalipsis", "invierno", "caza")):
			prados = [t for t in libres_est if g[t[0]][t[1]] == "." and abs(t[0] - salida[0]) + abs(t[1] - salida[1]) >= 5]
			for y, x in prados[:2 + (1 if "apocalipsis" not in estilos else 0)]:
				g[y][x] = "A"
		g[salida[0]][salida[1]] = "P"
		if not _superv_justo(g, salida, estilos):
			continue
		return ["".join(f) for f in g] + ["#%d" % ((semilla * 31 + i * 7) % 100000)]
	return ["~~~~~~~~~~~~~~", "~,,,,,,,,,,,,~", "~,.T..R..T..,~", "~,.G..B..G..,~", "~,..T.WW.B..,~", "~,.R..WW..T.,~",
		"~,..B....P..,~", "~,.T..G...R.,~", "~,..T..T..T.,~", "~,.G..R..B..,~", "~,T........D,~", "~,,,,,,,,,,,,~", "~~~~~~~~~~~~~~"]


def _superv_justo(g: list[list[str]], salida: tuple[int, int], estilos: list[str] | None = None) -> bool:
	"""Lo mismo que map_issues: agua y comida al alcance y madera, piedra y fibra suficientes
	(y en el apocalipsis, chatarra y tela para el machete, las vendas y la radio)."""
	alto, ancho = len(g), len(g[0])
	visto, cola = {salida}, [salida]
	while cola:
		y, x = cola.pop()
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			b = (y + dy, x + dx)
			if 0 <= b[0] < alto and 0 <= b[1] < ancho and b not in visto and g[b[0]][b[1]] in ".,GPA":
				visto.add(b)
				cola.append(b)
	def al_alcance(y, x):
		return any((y + a, x + b) in visto for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b)
	cuenta = {"W": 0, "B": 0, "T": 0, "R": 0, "G": 0, "H": 0, "C": 0, "A": 0}
	for y in range(alto):
		for x in range(ancho):
			k = g[y][x]
			if k in cuenta and al_alcance(y, x):
				cuenta[k] += 1
	cuenta["A"] = sum(1 for y in range(alto) for x in range(ancho) if g[y][x] == "A" and (y, x) in visto)
	if "apocalipsis" in (estilos or []) and (cuenta["H"] * 3 + cuenta["C"] * 4 < 9 or cuenta["H"] * 3 + cuenta["C"] * 2 < 6):
		return False
	return cuenta["W"] > 0 and cuenta["B"] + cuenta["A"] >= 2 and cuenta["T"] * 4 >= 34 and cuenta["R"] * 3 >= 9 and cuenta["G"] * 2 >= 16 and len(visto) >= 60


def parametros_supervivencia(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0,
		estilos: list[str] | None = None) -> dict:
	"""Noches mas largas, mas lobos y mas hambre y sed; cada tercer nivel, escapar en balsa (en el
	apocalipsis, arreglar la radio). Los estilos van en "survival": {"preset": [...]} (los del kit)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	balsa = i % 3 == 2
	noches = 1 + min(3, i // 2)
	dia = round(70 - 15 * d)
	noche = round(28 + 14 * d)
	lobos = 0 if (i == 0 and dificultad == "facil") else 1 + int(d * 1.8)
	par = (dia + noche) * (noches if not balsa else 2) + 20
	out = {"goal": "balsa" if balsa else "noches", "nights": noches, "day": dia, "night": noche, "wolves": lobos,
		"hunger": round(0.45 + 0.25 * d, 2), "thirst": round(0.7 + 0.3 * d, 2),
		"raft": [10 + int(4 * d), 6 + int(4 * d)], "par": par}
	presets = [ESTILO_SUPERV[e] for e in (estilos or []) if e in ESTILO_SUPERV]
	if presets:
		out["survival"] = {"preset": presets}
		if "zombis" in presets:
			## Zombis: uno por guarida al empezar y otro cada noche (no se van al amanecer).
			out["wolves"] = 1
			if balsa:
				out["goal"] = "receta"
	return out


## Giro de la fabrica -> estilo del kit (PRESETS en kit/survival/survival_map.gd).
ESTILO_SUPERV = {"apocalipsis": "zombis", "invierno": "invierno", "caza": "caza"}


## << genero supervivencia


## >> genero triple (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_triple(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Monton de fichas por capas (kit/triple/triple_map.gd): capas separadas por "=", "X" ficha;
	las capas impares van media ficha desplazadas. Reglas:
	1 - Simetrico de izquierda a derecha (se ve ordenado, como en las tiendas).
	2 - Cada capa cabe encima de la de abajo (las de arriba, mas pequenas).
	3 - Siempre un numero de fichas multiplo de 3 (se quitan sobrantes de la capa mas alta).
	4 - Mas capas y mas fichas segun avanza el juego y la dificultad."""
	rnd = random.Random(semilla * 6151 + i * 409 + 3)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	cols = 5 + min(2, i // 3)
	filas = 6 + min(2, i // 2)
	capas = max(2, min(5, 2 + i // 2 + (1 if dif >= 2.0 and i >= 3 else 0)))
	salida = []
	total = 0
	mascaras = []
	for z in range(capas):
		## Cada capa, una ficha menos que la de abajo: con media ficha de desplazamiento (impares)
		## o una de sangria cada dos capas queda centrada.
		c = cols - z
		f = filas - z
		if c < 2 or f < 2:
			break
		m = [[True] * c for _ in range(f)]
		hueco = 0.12 + 0.08 * z
		for y in range(f):
			for x in range((c + 1) // 2):
				if rnd.random() < hueco:
					m[y][x] = False
					m[y][c - 1 - x] = False
		mascaras.append(m)
		total += sum(sum(1 for v in r if v) for r in m)
	# Multiplo de 3: quita fichas de la capa mas alta (por parejas simetricas si se puede).
	z = len(mascaras) - 1
	while total % 3 != 0 and z >= 0:
		m = mascaras[z]
		hecho = False
		for y in range(len(m) - 1, -1, -1):
			for x in range(len(m[0])):
				if m[y][x]:
					m[y][x] = False
					total -= 1
					hecho = True
					break
			if hecho:
				break
		if not hecho:
			z -= 1
	for z, m in enumerate(mascaras):
		salida.append("=%d" % z)
		pre = "." * (z // 2)
		for y, fila in enumerate(m):
			salida.append(pre + "".join("X" if v else "." for v in fila))
	return salida + ["#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_triple(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Mas dibujos distintos (cuesta mas juntar tres) y menos ayudas segun avanza."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	fichas = sum(f.count("X") for f in (mapa or []) if not f.startswith(("=", "#")))
	return {"kinds": 5 + int(round(5 * d)), "tray": 7, "undo": 2 if d < 0.6 else 1, "shuffle": 1,
		"par": int(fichas * 1.6) + 10}


## << genero triple


## >> genero tornillos
def generar_tornillos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Placas atornilladas de abajo arriba (kit/screw/screw_map.gd): "x,y,w,h:sx,sy;sx,sy" en un
	tablero de 7x9 casillas y "#semilla" al final. Reglas:
	1 - Simetrico de izquierda a derecha: las placas van por parejas reflejadas y alguna central.
	2 - Cada placa lleva sus tornillos en las puntas (barras) o en las esquinas, sin repetir casilla.
	3 - Siempre un numero de tornillos multiplo de 3 (se quitan o anaden en placas de arriba).
	4 - Mas placas, mas solapadas y con mas tornillos segun avanza el juego y la dificultad."""
	rnd = random.Random(semilla * 7919 + i * 613 + 5)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho, alto = 7, 9
	parejas = max(1, min(5, 1 + i // 2 + (1 if dif >= 2.0 else 0)))
	placas = []

	def puntos(x, y, w, h):
		if w == 1 or h == 1:
			ext = [(x, y), (x + w - 1, y + h - 1)]
			if max(w, h) >= 5:
				ext.append((x + (w - 1) // 2, y + (h - 1) // 2))
			return ext
		return [(x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)]

	## Base: una placa ancha centrada abajo (o arriba) para que todo se apoye en algo.
	yb = rnd.choice([1, 4, 6])
	placas.append((1, yb, 5, 2, puntos(1, yb, 5, 2)))
	for k in range(parejas):
		if rnd.random() < 0.5:
			w, h = 1, rnd.choice([3, 4, 5])
		else:
			w, h = rnd.choice([2, 3]), rnd.choice([1, 2, 3])
		x = rnd.randint(0, max(0, ancho // 2 - w))
		y = rnd.randint(0, alto - h)
		pts = puntos(x, y, w, h)
		xs = ancho - x - w
		espejo = [(ancho - 1 - px, py) for px, py in pts]
		placas.append((x, y, w, h, pts))
		if xs != x:
			placas.append((xs, y, w, h, espejo))
		## A veces, una central encima que tapa a las dos.
		if rnd.random() < 0.35 + 0.15 * dif:
			cw = rnd.choice([3, 5])
			cy = rnd.randint(0, alto - 2)
			placas.append(((ancho - cw) // 2, cy, cw, 1, puntos((ancho - cw) // 2, cy, cw, 1)))
	## Sin casillas repetidas: un tornillo por casilla (gana el de la placa de abajo).
	usado = set()
	limpias = []
	for x, y, w, h, pts in placas:
		mios = [p for p in pts if p not in usado]
		usado.update(mios)
		if mios:
			limpias.append([x, y, w, h, mios])
	total = sum(len(p[4]) for p in limpias)
	## Multiplo de 3: quita de las de arriba que tengan mas de uno; si no, anade en una central.
	z = len(limpias) - 1
	while total % 3 != 0 and z >= 0:
		if len(limpias[z][4]) > 1:
			limpias[z][4].pop()
			total -= 1
		else:
			z -= 1
	while total % 3 != 0:
		limpias.append([0, alto - 1, ancho, 1, [(0, alto - 1), (ancho - 1, alto - 1), (3, alto - 1)][:3 - total % 3 if total % 3 else 3]])
		total = sum(len(p[4]) for p in limpias)
	salida = []
	for x, y, w, h, pts in limpias:
		salida.append("%d,%d,%d,%d:%s" % (x, y, w, h, ";".join("%d,%d" % p for p in pts)))
	return salida + ["#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_tornillos(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Mas colores (cuesta mas llenar cajas) y menos huecos de espera segun avanza."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	tornillos = sum(len(f.split(":", 1)[1].split(";")) for f in (mapa or []) if ":" in f)
	return {"kinds": 3 + int(round(4 * d)), "boxes": 2, "hold": 5 if d < 0.7 else 4, "extra": 1,
		"par": int(tornillos * 2.2) + 10}


## << genero tornillos


## >> genero hexas
def generar_hexas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tablero de casillas hexagonales (kit/hexa/hexa_map.gd): "." libre, "#" piedra, " " fuera y
	"a".."h" una pila ya puesta; las filas impares van media casilla a la derecha. Reglas:
	1 - Rectangulo de 5-7 x 6-8 con las esquinas recortadas a veces (se ve como un panal).
	2 - Piedras y pilas puestas con simetria de izquierda a derecha, nunca mas de un tercio.
	3 - Mas casillas, mas piedras y mas pilas puestas segun avanza el juego y la dificultad."""
	rnd = random.Random(semilla * 4241 + i * 271 + 9)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho = 5 + min(2, i // 3)
	alto = 6 + min(2, i // 2)
	g = [["."] * ancho for _ in range(alto)]
	if rnd.random() < 0.6:
		for y in (0, alto - 1):
			g[y][0] = " "
			g[y][ancho - 1] = " "
	libres = [(y, x) for y in range(alto) for x in range((ancho + 1) // 2) if g[y][x] == "."]
	rnd.shuffle(libres)
	piedras = min(4, int(dif) + i // 3)
	puestas = min(3, (i + 1) // 3 + (1 if dif >= 2.0 else 0))
	k = 0
	for _ in range(piedras):
		if k >= len(libres):
			break
		y, x = libres[k]
		k += 1
		g[y][x] = "#"
		g[y][ancho - 1 - x] = "#"
	for j in range(puestas):
		if k >= len(libres):
			break
		y, x = libres[k]
		k += 1
		g[y][x] = "abcdefgh"[(j * 2) % 4]
		if ancho - 1 - x != x:
			g[y][ancho - 1 - x] = "abcdefgh"[(j * 2 + 1) % 4]
	return ["".join(f) for f in g] + ["#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_hexas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Mas colores y una meta mas alta segun avanza (la meta cabe holgada en lo que limpia el bot)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	casillas = sum(f.count(".") + sum(f.count(c) for c in "abcdefgh") for f in (mapa or []) if not f.startswith("#"))
	colores = 3 + int(round(3 * d))
	meta = 10 * int(round(6 + 16 * d + casillas / 8.0))
	return {"kinds": colores, "goal": meta, "hammer": 1, "par": meta * 2 + 30}


## << genero hexas


## >> genero autobus
def _bus_sale_todo(g: list[list[str]]) -> bool:
	"""Sacando a los que tienen camino a la fila de arriba, se vacia todo (nadie encerrado)."""
	alto, ancho = len(g), len(g[0])
	gente = {(y, x) for y in range(alto) for x in range(ancho) if g[y][x] == "P"}
	while gente:
		## Huecos alcanzables desde arriba (y la fila de arriba entera cuenta como salida).
		visto = set()
		cola = [(0, x) for x in range(ancho) if g[0][x] != "#" and (0, x) not in gente]
		visto.update(cola)
		while cola:
			y, x = cola.pop()
			for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				ny, nx = y + dy, x + dx
				if 0 <= ny < alto and 0 <= nx < ancho and (ny, nx) not in visto and g[ny][nx] != "#" and (ny, nx) not in gente:
					visto.add((ny, nx))
					cola.append((ny, nx))
		salen = {(y, x) for (y, x) in gente if y == 0 or any((y + dy, x + dx) in visto for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
		if not salen:
			return False
		gente -= salen
	return True


def generar_autobus(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Estacion vista desde arriba (kit/bus/bus_map.gd): "P" pasajero, "." hueco, "#" pared; la
	salida es el borde de arriba. Reglas (las mismas que comprueba el analizador):
	1 - Casi llena de pasajeros, con algun hueco arriba para empezar.
	2 - Paredes por parejas en espejo, nunca encerrando a nadie para siempre.
	3 - Siempre un numero de pasajeros multiplo de 3 (sobran los de abajo).
	4 - Mas grande, mas llena y con mas paredes segun avanza el juego y la dificultad."""
	rnd = random.Random(semilla * 5303 + i * 389 + 13)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho = 6 + min(2, i // 3)
	alto = 7 + min(3, i // 2)
	for _ in range(60):
		g = [["P"] * ancho for _ in range(alto)]
		huecos = 0.2 - 0.04 * dif - 0.01 * i
		for y in range(alto):
			for x in range((ancho + 1) // 2):
				if rnd.random() < max(0.06, huecos) + (0.25 if y == 0 else 0.0):
					g[y][x] = "."
					g[y][ancho - 1 - x] = "."
		for _ in range(min(4, int(dif) + i // 3)):
			y, x = rnd.randint(1, alto - 1), rnd.randint(0, (ancho - 1) // 2)
			g[y][x] = "#"
			g[y][ancho - 1 - x] = "#"
		total = sum(f.count("P") for f in g)
		for y in range(alto - 1, -1, -1):
			for x in range(ancho):
				if total % 3 and g[y][x] == "P":
					g[y][x] = "."
					total -= 1
		if total >= 12 and _bus_sale_todo(g):
			return ["".join(f) for f in g] + ["#%d" % ((semilla * 37 + i * 11) % 100000)]
	return ["." * ancho] + ["P" * ancho for _ in range(3)] + ["#%d" % semilla]


def parametros_autobus(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Mas colores (cuesta mas llenar autobuses) y menos parada segun avanza."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	gente = sum(f.count("P") for f in (mapa or []) if not f.startswith("#"))
	return {"kinds": 3 + int(round(4 * d)), "buses": 1, "hold": 5 if d < 0.7 else 4, "vip": 1, "par": int(gente * 2.0) + 10}


## << genero autobus


## >> genero duelo
CARTAS_DUELO = ["knight", "archers", "giant", "minions", "musketeer", "skeletons", "arrows", "fireball"]
## Cartas que se van desbloqueando (cada una sustituye a una de las de inicio).
DESBLOQUEO_DUELO = [("hog", "skeletons"), ("valkyrie", "knight"), ("babydragon", "minions"), ("cannon", "arrows")]
RIVALES_DUELO = ["knight", "archers", "giant", "minions", "musketeer", "skeletons", "arrows", "fireball", "hog", "valkyrie",
	"babydragon", "cannon"]


def generar_duelo(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Duelo de cartas (kit/clash/clash_map.gd): la arena es siempre la misma (18 x 32, rio y dos
	puentes); el nivel cambia por las cartas y el rival (parametros_duelo). El mapa solo lleva la
	semilla, que decide el orden del mazo y el ritmo del rival."""
	return ["arena", "#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_duelo(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Tu mazo gana cartas nuevas cada nivel; el rival juega con mas elixir, tropas mas fuertes y
	piensa mas rapido segun avanza (calibrado: el bot gana al rival mas duro 4 de cada 5)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	mazo = list(CARTAS_DUELO)
	for nueva, vieja in DESBLOQUEO_DUELO[:min(len(DESBLOQUEO_DUELO), i // 2 + (1 if i else 0))]:
		mazo[mazo.index(vieja)] = nueva
	semilla = int((mapa or ["", "#1"])[-1].lstrip("#") or 1)
	rnd = random.Random(semilla * 13 + i)
	rival = list(RIVALES_DUELO)
	rnd.shuffle(rival)
	## El rival siempre lleva al menos un tanque y algo contra el aire.
	rival = rival[:6]
	if not any(c in rival for c in ("giant", "hog", "knight", "valkyrie")):
		rival[0] = "giant"
	if not any(c in rival for c in ("archers", "musketeer", "minions", "babydragon")):
		rival[1] = "musketeer"
	rival += [c for c in ("arrows", "fireball") if c not in rival][:8 - len(rival)]
	for c in RIVALES_DUELO:
		if len(rival) >= 8:
			break
		if c not in rival:
			rival.append(c)
	return {"deck": mazo, "ai_deck": rival[:8], "ai_elixir": round(0.72 + 0.14 * d, 3), "ai_level": round(0.84 + 0.08 * d, 3),
		"ai_react": round(1.6 - 0.4 * d, 3), "time": 120 if i == 0 else 180, "par": 120 if i == 0 else 180}


## << genero duelo


## >> genero escalada
def generar_escalada(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Colinas para el coche (kit/climb/climb_map.gd): "T:" alturas cada 4 m, "F:" bidones de
	gasolina, "C:" monedas y "#semilla". Reglas (las mismas que comprueba el analizador):
	1 - Arranque llano y colinas que crecen poco a poco en los primeros 100 m.
	2 - Pendiente maxima y cambio de pendiente limitados (sin muros ni esquinas que atasquen o
	    lancen el coche); el kit dibuja el suelo con una curva suave por esos puntos.
	3 - Bidones cada 260-380 m y monedas en grupos de 5.
	4 - Mas largo, colinas mas altas y empinadas y bidones mas separados segun avanza."""
	rnd = random.Random(semilla * 7717 + i * 503 + 21)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	largo = 500 + 120 * min(i, 6) + int(60 * dif)
	paso = 4.0
	npts = int(largo / paso) + 12
	amp = 3.5 + 1.6 * dif + 0.7 * i
	ondas = [(rnd.uniform(0.012, 0.03), rnd.uniform(0, 6.3), 1.0), (rnd.uniform(0.04, 0.07), rnd.uniform(0, 6.3), 0.45 + 0.08 * dif),
		(rnd.uniform(0.09, 0.14), rnd.uniform(0, 6.3), 0.12 + 0.06 * dif + 0.02 * i)]
	hs = []
	for k in range(npts):
		x = k * paso
		rampa = max(0.0, min(1.0, (x - 30.0) / 100.0))
		base = sum(math.sin(30.0 * f + ph) * a for f, ph, a in ondas) * amp
		h = (sum(math.sin(x * f + ph) * a for f, ph, a in ondas) * amp - base) * rampa
		h += max(0.0, x - 30.0) * (0.02 + 0.01 * dif)
		hs.append(h)
	lim = 0.55 + 0.12 * dif
	curva = 0.12 + 0.04 * dif
	pend = 0.0
	alturas = [0.0]
	for k in range(1, npts):
		quiere = max(-lim, min(lim, (hs[k] - hs[k - 1]) / paso))
		pend += max(-curva, min(curva, quiere - pend))
		alturas.append(round(alturas[-1] + pend * paso, 2))
	bidones = []
	x = 160.0 + rnd.uniform(-20, 20)
	while x < largo - 30:
		bidones.append(round(x, 1))
		x += 260.0 + 60.0 * dif + rnd.uniform(-30, 30)
	monedas = []
	x = 40.0
	while x < largo - 20:
		for j in range(5):
			monedas.append(round(x + j * 2.2, 1))
		x += rnd.uniform(35, 70)
	filas = ["T:" + ",".join("%g" % v for v in alturas[k:k + 40]) for k in range(0, len(alturas), 40)]
	filas.append("F:" + ",".join("%g" % v for v in bidones))
	filas.append("C:" + ",".join("%g" % v for v in monedas))
	return filas + ["#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_escalada(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Meta al final del camino y algo mas de gasto de gasolina segun la dificultad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	puntos = sum(len(f[2:].split(",")) for f in (mapa or []) if f.startswith("T:"))
	largo = max(60, int((puntos - 12) * 4))
	return {"goal": largo, "fuel_rate": round(1.35 + 0.6 * d, 2), "par": int(largo / 9.0) + 10}


## << genero escalada


## >> genero tirachinas
def _tirachinas_modulo(rnd, tipo: str, mat: str, dif: float) -> list[str]:
	"""Estructuras que se sostienen solas (cada pieza apoyada; tablones sobre postes)."""
	m2 = rnd.choice(["W", "I", "S"]) if dif >= 1 else rnd.choice(["W", "I"])
	if tipo == "casita":
		return [".P.", "===", "|P|", mat * 3]
	if tipo == "torre":
		return ["P.", mat + m2, m2 + mat, mat * 2]
	if tipo == "bunker":
		return ["SWS" if dif >= 1 else "WWW", "%sP%s" % (mat, mat), mat * 3]
	if tipo == "piramide":
		return ["..P..", ".WTW." if rnd.random() < 0.3 else ".WWW.", m2 * 5]
	return [".K.", mat * 3, "###"]


def generar_tirachinas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Estructuras para el tirachinas (kit/sling/sling_map.gd), de arriba abajo y apoyadas en el
	suelo: W madera, S piedra, I hielo, = tablon, | poste, P cerdo, K cerdo rey, T TNT, # roca.
	1 - De 1 a 3 construcciones (casita con tablon, torre, bunker, piramide, pedestal del rey)
	    separadas por una columna y como mucho 9 de ancho.
	2 - Todo apoyado (lo comprueba el analizador); mas piedra y mas construcciones al avanzar."""
	rnd = random.Random(semilla * 9137 + i * 431 + 7)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	tipos = ["casita", "torre", "piramide"] + (["bunker"] if dif + i / 3 >= 1 else []) + (["pedestal"] if i >= 4 else [])
	cuantas = 1 + (1 if i >= 1 else 0) + (1 if i >= 4 and dif >= 1 else 0)
	mods = []
	ancho = 0
	for k in range(cuantas):
		t = rnd.choice(tipos)
		mat = rnd.choice(["W", "W", "I", "S"] if dif >= 1 else ["W", "W", "I"])
		m = _tirachinas_modulo(rnd, t, mat, dif)
		w = len(m[0])
		if ancho + w + (1 if mods else 0) > 9:
			break
		mods.append(m)
		ancho += w + (1 if len(mods) > 1 else 0)
	alto = max(len(m) for m in mods)
	filas = [""] * alto
	for idx, m in enumerate(mods):
		pad = ["." * len(m[0])] * (alto - len(m)) + m
		for r in range(alto):
			filas[r] += ("." if idx else "") + pad[r]
	return filas + ["#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_tirachinas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Un pajaro mas que cerdos (uno menos en dificil con muchos cerdos); el negro si hay piedra,
	el azul si hay hielo. Par = puntos de 3 estrellas."""
	filas = [f for f in (mapa or []) if not f.startswith("#")]
	rnd = random.Random(len("".join(filas)) * 31 + i)
	cerdos = sum(f.count("P") + f.count("K") for f in filas)
	piedra = sum(f.count("S") + f.count("K") for f in filas)
	hielo = sum(f.count("I") for f in filas)
	pajaros = ["red"]
	extra = max(1, cerdos + 1 - (1 if dificultad == "dificil" and cerdos > 2 else 0))
	for k in range(extra):
		if piedra and k % 2 == 0:
			pajaros.append("black")
		elif hielo and k % 3 == 1:
			pajaros.append("blue")
		else:
			pajaros.append(rnd.choice(["red", "yellow"]))
	bloques = sum(sum(1 for ch in f if ch in "WSIT=|") for f in filas)
	return {"birds": pajaros, "par": cerdos * 5000 + bloques * 250 + 10000}


## << genero tirachinas


## >> genero plantas
PLANTAS_TODAS = ["sunflower", "peashooter", "wallnut", "potatomine", "snowpea", "cherrybomb", "repeater"]


def generar_plantas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Defensa por carriles (kit/lawn/lawn_map.gd): el jardin es siempre de 5 x 9; el nivel cambia por
	las oleadas y las plantas (parametros_plantas). El mapa solo lleva la semilla (carriles de los zombis)."""
	return ["jardin", "#%d" % ((semilla * 37 + i * 11) % 100000)]


def parametros_plantas(i: int, n: int, dificultad: str, mapa: list[str] | None = None, ajuste: float = 0.0) -> dict:
	"""Oleadas cada vez mas grandes (la ultima, la gorda), zombis con cono, corredores y cubos segun
	avanza, y una planta nueva por nivel. Calibrado: el bot gana 71 de 72 niveles de prueba."""
	semilla = int((mapa or ["", "#1"])[-1].lstrip("#") or 1)
	rnd = random.Random(semilla * 6007 + i * 211 + 3)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	n_olas = 5 + min(4, i) + int(dif)
	olas = []
	t = 22.0
	for k in range(n_olas):
		ultima = k == n_olas - 1
		cuantos = 1 + k // 3 + int(dif * 0.4 + i * 0.15) + (2 + int(dif) if ultima else 0)
		tipos = ["normal"]
		if i >= 1 or dif >= 1:
			tipos.append("cone")
		if i >= 3 or dif >= 2:
			tipos.append("runner")
		if i >= 5 or (i >= 4 and dif >= 1):
			tipos.append("bucket")
		olas.append({"t": round(t, 1), "z": [rnd.choice(tipos) if rnd.random() < 0.35 + 0.1 * dif else "normal" for _ in range(cuantos)]})
		t += 18.0 - min(4.0, i * 0.5) + (8.0 if k == n_olas - 2 else 0.0)
	return {"waves": olas, "plants": PLANTAS_TODAS[:min(len(PLANTAS_TODAS), 3 + i)], "sun": 150, "sky": 9.0, "par": int(t) + 30}


## << genero plantas


## >> genero palabra (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_palabra(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Adivina la palabra (kit/wordle/wordle_map.gd): la palabra la elige el kit con el diccionario
	del idioma del jugador; el mapa solo lleva la semilla (asi un nivel vale en todos los idiomas).
	El analizador comprueba en los 6 idiomas que hay palabra y que el bot la acierta."""
	return ["palabra", "#%d" % ((semilla * 31 + i * 7919) % 1000003)]


def parametros_palabra(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Largo (4 a 7 letras), intentos, lo rara que es la palabra y modo dificil al final."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	largo = 4 if i == 0 and d < 0.4 else (5 if d < 0.55 or i < 3 else (6 if d < 0.85 else 7))
	return {"len": largo, "tries": 6 if largo <= 5 else 7, "rank": round(min(1.0, 0.05 + 0.6 * d), 2), "hard": d > 0.8 and i >= n - 2}


## << genero palabra


## >> genero letras (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_letras(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Palabras con letras (kit/letters/letters_map.gd): la rueda y el crucigrama los monta el kit con
	el diccionario del idioma del jugador; el mapa solo lleva la semilla. El analizador comprueba
	que el crucigrama sale en los 6 idiomas con todas sus palabras."""
	return ["letras", "#%d" % ((semilla * 37 + i * 6007) % 1000003)]


def parametros_letras(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Letras de la rueda (4 a 7), palabras del crucigrama (3 a 9) y lo raras que son."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	largo = min(7, 4 + (1 if i >= 1 else 0) + (1 if i >= 3 or d > 0.5 else 0) + (1 if d > 0.75 and i >= 4 else 0))
	palabras = min(9, max(3, largo - 1 + int(round(2 * d)) + min(i, 3) // 2))
	return {"len": largo, "words": palabras, "rank": round(min(1.0, 0.05 + 0.5 * d), 2)}


## << genero letras


## >> genero tycoon (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_tycoon(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tycoon (kit/tycoon): no hay mapa; los negocios salen del catalogo y la meta de dinero la
	calibra la directora con la copia de la simulacion (niveles/tycoon.py -> calibrar)."""
	return ["tycoon"]


def parametros_tycoon(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Negocios (o pozos) del nivel, de 3 a 6-8, y lo que dura (par): de minuto y medio a cinco.
	Cuanto mas dificil, menos margen (la meta se calibra para el 80 % del par)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	abiertos = min(8, 3 + i // 2 + (1 if d > 0.6 else 0))
	par = int(round((80 + 25 * i + 60 * d) / 10.0)) * 10
	return {"open": abiertos, "par": min(330, par), "start": 15 if i == 0 else 0}


## << genero tycoon


## >> genero tragaperras (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_tragaperras(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tragaperras con aldea (kit/slots): no hay mapa; la aldea sale del catalogo y su escala la
	calibra la directora con el valor medio de las tiradas (niveles/tragaperras.py)."""
	return ["tragaperras"]


def parametros_tragaperras(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Tiradas al empezar, recarga y lo que dura (par): de 2 a 6 minutos. Mas dificil: menos tiradas."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"spins": int(round(45 - 15 * d)), "regen": int(round(10 + 8 * d)), "par": min(360, 120 + 30 * i + int(60 * d)),
		"seed": 1 + i * 7919 + int(d * 100)}


## << genero tragaperras


## >> genero reino (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
HEROES_REINO = ["amadea", "jabel", "saul"]


def generar_reino(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Reino (kit/realm): no hay mapa de casillas; la ciudad sale del catalogo y los campamentos
	de parametros_reino (el kit los mide contra el ejercito que tendria el bot en ese momento)."""
	return ["reino"]


def parametros_reino(i: int, n: int, dificultad: str, ajuste: float = 0.0) -> dict:
	"""Campamentos de 2 a 6 en orden (el ultimo es el jefe), cada uno con su momento ("at", parte
	del tiempo de 3 estrellas), su fuerza frente a tu ejercito de entonces y su mezcla de tropas
	(asi hay que entrenar de todo). Heroes en los primeros. Partidas de 3 a 7 minutos."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	cuantos = min(6, 2 + (i + 1) // 2 + (1 if d > 0.7 else 0))
	mezclas = [[1, 0, 0], [1, 1, 0], [0, 1, 1], [1, 0, 1], [1, 1, 1], [2, 1, 1], [1, 2, 1], [1, 1, 2]]
	campos = []
	for c in range(cuantos):
		f = (c + 1) / cuantos
		campo = {"at": round(0.12 + 0.68 * f, 2), "str": round(0.5 + (0.25 + 0.25 * d) * f, 2),
			"mix": mezclas[(c + i) % len(mezclas)] if c else [1, 0, 0], "reward": 1.0}
		if c < len(HEROES_REINO) and c % 2 == 0 and i < 3:
			campo["hero"] = HEROES_REINO[(i + c // 2) % len(HEROES_REINO)]
		campos.append(campo)
	return {"par": min(420, 180 + 30 * i + int(60 * d)), "cap": min(10, 4 + i // 2), "camps": campos}


## << genero reino


## >> genero multitud (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def _op_multitud(n: int, op: str) -> int:
	"""Como apply() del kit (kit/crowd/crowd_map.gd)."""
	k = int(op[1:])
	if op[0] == "+":
		return min(999, n + k)
	if op[0] == "-":
		return max(0, n - k)
	if op[0] == "x":
		return min(999, n * max(1, k))
	return n // max(1, k)


def generar_multitud(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Multitud (kit/crowd): la pista va en los parametros (parametros_multitud); el mapa solo
	lleva la semilla para rehacerla igual."""
	return ["multitud", "#%d" % ((semilla * 131 + i * 7919) % 1000003)]


def parametros_multitud(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Pista con puertas (una buena y una mala, cada vez mas jugosas), trampas en un carril y grupos
	enemigos (un tercio de lo que llevarias por el mejor camino); el jefe pide un 60-85 % de lo mejor
	posible: hay que elegir bien casi todas, pero no hace falta ser perfecto."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str((mapa or ["", "#1"])[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 977 + i)
	buenas = ["+5", "+10", "+15", "+20", "x2", "x3"]
	malas = ["-5", "-10", "/2", "-15", "+2"]
	cosas = 6 + i + int(4 * d)
	dist = 12.0
	mejor = peor = start = 2
	track = []
	for c in range(cosas):
		r = rnd.random()
		if c < 2 or r < 0.55 or mejor < 15:
			b = rnd.choice(buenas[:4 + min(2, i)])
			m = rnd.choice(malas if c > 0 else ["+1", "+2"])
			lado = rnd.random() < 0.5
			track.append({"d": round(dist, 1), "t": "gate", "l": b if lado else m, "r": m if lado else b})
			mejor = max(_op_multitud(mejor, b), _op_multitud(mejor, m))
			peor = min(_op_multitud(peor, b), _op_multitud(peor, m))
		elif r < 0.8 or mejor < 12:
			kk = 3 + i + rnd.randint(0, 6)
			track.append({"d": round(dist, 1), "t": "trap", "lane": rnd.choice("lr"), "k": kk})
			peor = max(0, peor - kk)
		else:
			e = max(3, int(mejor * 0.3))
			track.append({"d": round(dist, 1), "t": "enemy", "n": e})
			mejor -= e
			peor = max(0, peor - e)
		dist += 9.0 + rnd.random() * 4.0
	jefe = max(peor + 1, int(mejor * (0.6 + 0.25 * d)))
	track.append({"d": round(dist + 6.0, 1), "t": "boss", "n": jefe})
	return {"start": start, "speed": round(7.0 + min(3.0, i * 0.4), 1), "track": track}


## << genero multitud


## >> genero pedidos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
CADENAS_PEDIDOS = ["bread", "tea", "flower", "tool"]


def generar_pedidos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Fusion con pedidos (kit/mergeboard): los pedidos y la energia van en los parametros; el
	mapa solo lleva la semilla."""
	return ["pedidos", "#%d" % ((semilla * 173 + i * 7919) % 1000003)]


def parametros_pedidos(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Pedidos de 1 o 2 objetos de nivel 2 a 6 (cada vez mas), de 2 a 4 generadores, y la energia
	justa: la mitad al empezar y el resto llega con el tiempo hacia el 75 % del tiempo de 3 estrellas
	(un objeto de nivel L sale de 2^(L-1) toques)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 31 + i)
	cadenas = CADENAS_PEDIDOS[:min(4, 2 + i // 3)]
	tope = min(6, 3 + i // 2 + (1 if d > 0.6 else 0))
	personas = ["Abuela Rosa", "Marta", "Capitán Leo", "Nico", "Doña Pilar", "Tomás"]
	pedidos = []
	energia = 0
	for p in range(4 + i):
		necesita = []
		for _ in range(1 if p < 2 or rnd.random() < 0.5 else 2):
			nivel = rnd.randint(2, max(3, min(tope, 2 + p // 2 + rnd.randint(0, 1))))
			necesita.append([rnd.choice(cadenas), nivel])
			energia += 1 << (nivel - 1)
		pedidos.append({"who": personas[p % len(personas)], "need": necesita, "reward": 10 * sum(1 << (x[1] - 1) for x in necesita)})
	par = min(420, 150 + 30 * i + int(40 * d))
	inicio = max(4, energia // 2)
	regen = max(2.0, round(0.75 * par / max(1, energia - inicio + 1), 1))
	return {"chains": cadenas, "orders": pedidos, "energy": inicio, "regen": regen, "par": par}


## << genero pedidos


## >> genero a_medida (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_a_medida(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Cuadricula vista desde arriba: # roca, . suelo, P salida, C moneda, X pinchos.
	Reglas de justicia (las mismas que comprueba kit/custom/custom_map.gd):
	1 - Una sola salida abajo en el centro, con sus 4 vecinas libres.
	2 - Todas las monedas se alcanzan sin pisar pinchos ni rocas.
	3 - Mas rocas, pinchos y monedas segun avanza el juego y la dificultad."""
	mapas = (opciones or {}).get("a_medida_mapas") or []
	if i < len(mapas) and mapas[i]:
		## Genero hecho a medida: sus niveles salen de su generador GDScript (genero_usuario.py), con
		## varias variantes por nivel; cada intento de rehacer el nivel usa otra.
		return list(mapas[i][semilla % len(mapas[i])])
	rnd = random.Random(semilla)
	dif = {"facil": 0.0, "normal": 1.0, "dificil": 2.0}.get(dificultad, 1.0) + ajuste * 2.0
	ancho = 7
	alto = 9 + min(i, 4)
	salida = (alto - 1, ancho // 2)
	libres_salida = {salida, (alto - 2, ancho // 2), (alto - 1, ancho // 2 - 1), (alto - 1, ancho // 2 + 1)}
	for _ in range(400):
		g = [["." for _ in range(ancho)] for _ in range(alto)]
		g[salida[0]][salida[1]] = "P"
		celdas = [(y, x) for y in range(alto) for x in range(ancho) if (y, x) not in libres_salida]
		rnd.shuffle(celdas)
		n_rocas = int(ancho * alto * (0.12 + 0.03 * max(dif, 0.0)))
		n_pinchos = max(1, int(1 + i + dif * 1.5))
		n_monedas = 5 + 2 * min(i, 4)
		for y, x in celdas[:n_rocas]:
			g[y][x] = "#"
		for y, x in celdas[n_rocas:n_rocas + n_pinchos]:
			g[y][x] = "X"
		monedas = celdas[n_rocas + n_pinchos:n_rocas + n_pinchos + n_monedas]
		for y, x in monedas:
			g[y][x] = "C"
		visto = {salida}
		cola = [salida]
		while cola:
			y, x = cola.pop()
			for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				ny, nx = y + dy, x + dx
				if 0 <= ny < alto and 0 <= nx < ancho and (ny, nx) not in visto and g[ny][nx] not in "#X":
					visto.add((ny, nx))
					cola.append((ny, nx))
		if all(m in visto for m in monedas):
			return ["".join(f) for f in g]
	filas = ["." * ancho for _ in range(alto)]
	filas[0] = "C" * ancho
	filas[-1] = "." * (ancho // 2) + "P" + "." * (ancho - ancho // 2 - 1)
	return filas
## << genero a_medida


## >> genero poder (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def _op_poder(p: int, op: str) -> int:
	"""Como apply() del kit (kit/powertower/powertower_map.gd)."""
	k = int(op[1:])
	return {"+": min(999999, p + k), "-": max(0, p - k), "x": min(999999, p * max(1, k)), "/": p // max(1, k)}[op[0]]


def _jugar_poder(start: int, towers: list) -> tuple[bool, int]:
	"""El bot del kit (bot_move): sumas primero, el enemigo mas debil que puede, multiplicar si se atasca."""
	t = [[dict(r, done=False) for r in tw] for tw in towers]
	p = start

	def abierta() -> int:
		for i, tw in enumerate(t):
			if any(not r["done"] and r["t"] in ("enemy", "boss") for r in tw):
				return i
		return -1
	for _ in range(200):
		a = abierta()
		if a < 0:
			return True, p
		salas = [(i, j, r) for i in range(a + 1) for j, r in enumerate(t[i]) if not r["done"]]
		suma = [x for x in salas if x[2]["t"] == "bonus" and x[2]["op"][0] == "+"]
		if suma:
			suma[0][2]["done"] = True
			p = _op_poder(p, suma[0][2]["op"])
			continue
		vivos = [x for x in salas if x[2]["t"] in ("enemy", "boss") and p > x[2]["p"]]
		def peso(x):
			quedan = sum(1 for r in t[x[0]] if not r["done"] and r["t"] in ("enemy", "boss"))
			return x[2]["p"] + (999999 if x[2]["t"] == "boss" and quedan > 1 else 0)
		if vivos:
			x = min(vivos, key=peso)
			x[2]["done"] = True
			p = min(999999, p + x[2]["p"])
			if x[2]["t"] == "boss":
				return True, p
			continue
		mult = [x for x in salas if x[2]["t"] == "bonus" and x[2]["op"][0] == "x"]
		if not mult:
			return False, p
		x = max(mult, key=lambda y: int(y[2]["op"][1:]))
		x[2]["done"] = True
		p = _op_poder(p, x[2]["op"])
	return False, p


def _ingenuo_poder(start: int, towers: list) -> bool:
	"""De abajo arriba sin pensar (como _naive_wins del kit)."""
	p = start
	for tw in towers:
		for r in tw:
			if r["t"] in ("enemy", "boss"):
				if p <= r["p"]:
					return False
				p += r["p"]
				if r["t"] == "boss":
					return True
			else:
				p = _op_poder(p, r["op"])
	return True


def generar_poder(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Torre de poder (kit/powertower): las torres van en los parametros; el mapa lleva la semilla."""
	return ["poder", "#%d" % ((semilla * 211 + i * 7919) % 1000003)]


def parametros_poder(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Torres que crecen (2 a 5, de 3 a 6 salas): enemigos un poco mas debiles que tu poder en ese
	momento pero desordenados (abajo suele haber uno que aun no puedes), sumas, alguna trampa y
	un multiplicador que hace falta en su momento. El jefe, arriba del todo de la ultima torre.
	Se comprueba con la misma cabeza que el bot: el bot gana y subir sin pensar pierde."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 53 + i)
	start = 5 + rnd.randint(0, 5)
	for _ in range(300):
		torres = []
		p = start
		n_torres = min(5, 2 + i // 2)
		for tw in range(n_torres):
			salas = []
			n_salas = min(6, 3 + (i + tw) // 2)
			for s in range(n_salas):
				r = rnd.random()
				if r < 0.15 and s > 0:
					salas.append({"t": "trap", "op": rnd.choice(["-3", "-5", "/2"])})
				elif r < 0.3:
					op = rnd.choice(["+3", "+5", "+8"]) if rnd.random() < 0.7 or tw == 0 else "x2"
					salas.append({"t": "bonus", "op": op})
					p = _op_poder(p, op) if op[0] == "+" else p
				else:
					e = max(1, int(p * (0.35 + 0.55 * rnd.random())))
					salas.append({"t": "enemy", "p": e})
					p += e
			rnd.shuffle(salas)
			torres.append(salas)
		## Que haga falta pensar: abajo de la primera torre, uno que al principio aun no se puede.
		fuerte = start + rnd.randint(1, 4)
		torres[0].insert(0, {"t": "enemy", "p": fuerte})
		ok, final = _jugar_poder(start, torres)
		if not ok:
			continue
		jefe = max(start + 1, int(final * (0.55 + 0.3 * d)))
		torres[-1].append({"t": "boss", "p": jefe})
		ok2, _ = _jugar_poder(start, torres)
		if ok2 and not _ingenuo_poder(start, torres):
			return {"start": start, "towers": torres}
	return {"start": 10, "towers": [[{"t": "enemy", "p": 12}, {"t": "enemy", "p": 4}, {"t": "bonus", "op": "+5"}], [{"t": "enemy", "p": 9}, {"t": "boss", "p": 30}]]}


## << genero poder


## >> genero diferencias (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
TEMAS_DIFERENCIAS = {
	"parque": {"bg": "#cfe8ff", "ground": "#7ccf6a", "k": ["tree", "flower", "bush", "cloud", "sun", "bird", "house", "balloon", "rock", "mushroom", "kite"]},
	"mar": {"bg": "#8fd3ff", "ground": "#f2d49b", "k": ["fish", "boat", "sun", "cloud", "bird", "rock", "star", "heart", "balloon"]},
	"espacio": {"bg": "#1b1f3b", "k": ["star", "moon", "circle", "tri", "kite", "heart", "square"]},
	"cocina": {"bg": "#fff3e0", "ground": "#c9a77c", "k": ["cake", "cup", "lamp", "gift", "heart", "circle", "square", "flower"]},
	"ciudad": {"bg": "#dfe9f5", "ground": "#9aa4b5", "k": ["house", "car", "tree", "cloud", "sun", "lamp", "bird", "balloon"]},
}
COLORES_DIFERENCIAS = ["#e74c3c", "#3498db", "#2ecc71", "#f1c40f", "#9b59b6", "#e67e22", "#1abc9c", "#ff6fa8", "#ffffff", "#34495e", "#8e5a3c"]
ASIMETRICAS = {"fish", "car", "house", "boat", "cup", "moon", "kite", "tri", "balloon"}


def generar_diferencias(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Encuentra las diferencias (kit/spotdiff): el dibujo va en los parametros; el mapa, la semilla."""
	return ["diferencias", "#%d" % ((semilla * 167 + i * 7919) % 1000003)]


def parametros_diferencias(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Escena tematica (parque, mar, espacio, cocina, ciudad) de 10 a 24 figuras sin pisarse y de 3 a
	8 diferencias separadas: color, que falte, tamano, que se mueva o se de la vuelta (solo en
	figuras que no son simetricas). Mas figuras, mas pequenas y mas diferencias segun avanza."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 71 + i)
	tema = list(TEMAS_DIFERENCIAS)[(semilla + i) % len(TEMAS_DIFERENCIAS)]
	t = TEMAS_DIFERENCIAS[tema]
	lado = 4 + min(3, i // 2 + int(2 * d))
	celdas = [(x, y) for y in range(lado) for x in range(lado)]
	rnd.shuffle(celdas)
	n_fig = min(len(celdas), 10 + i * 2 + int(6 * d))
	escena = []
	for (cx, cy) in celdas[:n_fig]:
		tam = round((0.5 / lado) * (0.75 + 0.35 * rnd.random()), 3)
		escena.append({"k": rnd.choice(t["k"]), "x": round((cx + 0.5 + rnd.uniform(-0.18, 0.18)) / lado, 3),
			"y": round((cy + 0.5 + rnd.uniform(-0.18, 0.18)) / lado, 3), "s": max(0.06, tam), "c": rnd.choice(COLORES_DIFERENCIAS),
			"f": rnd.random() < 0.5})
	n_dif = min(8, 3 + i // 2 + int(2 * d))
	elegidas: list[int] = []
	diffs = []
	for idx in rnd.sample(range(len(escena)), len(escena)):
		sh = escena[idx]
		if not (0.12 < sh["x"] < 0.88 and 0.12 < sh["y"] < 0.88):
			continue
		if any(((sh["x"] - escena[j]["x"]) ** 2 + (sh["y"] - escena[j]["y"]) ** 2) ** 0.5 < 0.2 for j in elegidas):
			continue
		formas = ["color", "gone", "size", "move"] + (["flip"] if sh["k"] in ASIMETRICAS else [])
		como = rnd.choice(formas)
		if como == "color":
			v = rnd.choice([c for c in COLORES_DIFERENCIAS if c != sh["c"]])
		elif como == "size":
			v = 1.6 if sh["s"] < 0.09 or rnd.random() < 0.5 else 0.6
		elif como == "move":
			v = [round(rnd.choice([-1, 1]) * rnd.uniform(0.05, 0.07), 3), round(rnd.choice([-1, 1]) * rnd.uniform(0.04, 0.06), 3)]
		else:
			v = None
		dd = {"i": idx, "how": como}
		if v is not None:
			dd["v"] = v
		diffs.append(dd)
		elegidas.append(idx)
		if len(diffs) >= n_dif:
			break
	out = {"scene": escena, "diffs": diffs, "bg": t["bg"], "mistakes": max(3, 6 - int(3 * d)), "tema": tema}
	if "ground" in t:
		out["ground"] = t["ground"]
	return out


## << genero diferencias


## >> genero rompecabezas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_rompecabezas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Rompecabezas (kit/jigsaw): el dibujo y el desorden van en los parametros; el mapa, la semilla."""
	return ["rompecabezas", "#%d" % ((semilla * 131 + i * 6151) % 1000003)]


def _minimo_cambios(orden: list[int]) -> int:
	"""Cambios minimos para ordenar una permutacion: piezas fuera de sitio menos ciclos."""
	visto = set()
	total = 0
	for k in range(len(orden)):
		if k in visto or orden[k] == k:
			continue
		j, largo = k, 0
		while j not in visto:
			visto.add(j)
			j = orden[j]
			largo += 1
		total += largo - 1
	return total


def parametros_rompecabezas(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Dibujo tematico con una figura distinta en cada pieza (asi ninguna pieza es igual a otra) y el
	heroe del juego en medio; de 3x3 a 6x6 piezas, desordenadas sin dejar mas de una de cada cuatro
	en su sitio. Desde la mitad, con limite de cambios (el minimo y un margen que se estrecha)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 53 + i)
	tema = list(TEMAS_DIFERENCIAS)[(semilla + i) % len(TEMAS_DIFERENCIAS)]
	t = TEMAS_DIFERENCIAS[tema]
	lado = min(6, 3 + i // 3 + int(1.5 * d))
	combos = [(f, c) for f in t["k"] for c in COLORES_DIFERENCIAS if c != t["bg"]]
	rnd.shuffle(combos)
	escena = []
	for celda in range(lado * lado):
		cx, cy = celda % lado, celda // lado
		f, c = combos[celda % len(combos)]
		escena.append({"k": f, "c": c, "x": round((cx + 0.5 + rnd.uniform(-0.1, 0.1)) / lado, 3),
			"y": round((cy + 0.5 + rnd.uniform(-0.1, 0.1)) / lado, 3), "s": round((0.62 + 0.12 * rnd.random()) / lado, 3),
			"f": rnd.random() < 0.5})
	piezas = lado * lado
	orden = list(range(piezas))
	for _ in range(200):
		rnd.shuffle(orden)
		en_sitio = sum(1 for a, b in enumerate(orden) if a == b)
		if en_sitio * 4 <= piezas and _minimo_cambios(orden) >= 3:
			break
	minimo = _minimo_cambios(orden)
	cambios = 0
	if i >= n // 2 and dificultad != "facil":
		cambios = minimo + max(2, int(round(minimo * (0.6 - 0.35 * d))))
	out = {"size": lado, "order": orden, "moves": cambios, "scene": escena, "bg": t["bg"], "hero": True, "tema": tema}
	if "ground" in t:
		out["ground"] = t["ground"]
	return out


## << genero rompecabezas


## >> genero pintar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## Dibujos de pixeles para pintar por numeros: filas de letras; "." es fondo (no se pinta) y cada
## letra un color de COLORES_PINTAR. Todos de 12 a 16 de lado.
COLORES_PINTAR = {"r": "#e74c3c", "o": "#e67e22", "y": "#f1c40f", "g": "#2ecc71", "G": "#1e8449", "b": "#3498db", "B": "#1f4e79",
	"p": "#9b59b6", "k": "#2c3e50", "w": "#ffffff", "n": "#8e5a3c", "N": "#5d3a1a", "s": "#f5cba7", "l": "#aed6f1", "P": "#ff8fb1", "e": "#95a5a6"}
DIBUJOS_PINTAR = {
	"corazon": [
		"............",
		"..rrr..rrr..",
		".rrwrrrrrrr.",
		".rwrrrrrrrr.",
		".rrrrrrrrrr.",
		".rrrrrrrrrr.",
		"..rrrrrrrr..",
		"...rrrrrr...",
		"....rrrr....",
		".....rr.....",
		"............",
	],
	"estrella": [
		"......y......",
		".....yyy.....",
		".....yyy.....",
		"yyyyyyoyyyyyy",
		".yyyyoooyyyy.",
		"..yyyyoyyyy..",
		"...yyyyyyy...",
		"...yyy.yyy...",
		"..yyy...yyy..",
		"..yy.....yy..",
		".y.........y.",
	],
	"seta": [
		"....rrrrrr....",
		"..rrwwrrrrrr..",
		".rrwwwrrrwwrr.",
		"rrrrwrrrrwwwrr",
		"rrrrrrrrrrwrrr",
		"rwwrrrrrrrrrrr",
		"rwwrrrrwwrrrrr",
		".rrrrrrwwrrrr.",
		"....ssssss....",
		"....skssks....",
		"....ssssss....",
		"....ssssss....",
		".....ssss.....",
	],
	"casa": [
		"......rr......",
		".....rrrr.....",
		"....rrrrrr....",
		"...rrrrrrrr...",
		"..rrrrrrrrrr..",
		".rrrrrrrrrrrr.",
		"..ywwwwwwwwy..",
		"..wbbwwwwbbw..",
		"..wbbwwwwbbw..",
		"..wwwwnnwwww..",
		"..wwwwnnwwww..",
		"..wwwwnnwwww..",
		"GGGGGGGGGGGGGG",
	],
	"pez": [
		"..............",
		"......bb......",
		".....bbbb.....",
		"..bbbbbbbbb..o",
		".bbwkbbbbbbbooo",
		"bbbkkbbbbbbbbo.",
		"bbbbbbbbbbbboo.",
		".bbbbbbbbbbbooo",
		"..bbbbbbbbb..o.",
		"....lbbbbl.....",
		"......bb.......",
	],
	"arbol": [
		".....GG.....",
		"...GGGGGG...",
		"..GGgGGGGG..",
		".GgggGGGrGG.",
		".GGgGGGGGGG.",
		"GGGGGrGGGgGG",
		"GGgGGGGGgggG",
		".GGGGGGGGgG.",
		"..GGGrGGGG..",
		"....nNNn....",
		"....nNNn....",
		"....nNNn....",
		"..GgGNNGgG..",
	],
	"gato": [
		".k........k.",
		".kk......kk.",
		".kok....kok.",
		".kkkkkkkkkk.",
		"kkkkkkkkkkkk",
		"kkygkkkkygkk",
		"kkggkkkkggkk",
		"kkkkkPPkkkkk",
		"wkkkkkkkkkkw",
		".kkwkkkkwkk.",
		"..kkkkkkkk..",
		"...kkkkkk...",
	],
	"cohete": [
		"......rr......",
		".....rrrr.....",
		".....wwww.....",
		"....wwwwww....",
		"....wwbbww....",
		"....wbllbw....",
		"....wwbbww....",
		"....wwwwww....",
		"...rwwwwwwr...",
		"..rrwwwwwwrr..",
		"..rr.eeee.rr..",
		".....oyyo.....",
		"......oo......",
	],
	"helado": [
		"....PPPP....",
		"..PPPPPPPP..",
		".PPrPPPPPPP.",
		".PPPPPPrPPP.",
		".wwwwwwwwww.",
		".wwwwrwwwww.",
		"..oyoyoyoy..",
		"..yoyoyoyo..",
		"...oyoyoy...",
		"...yoyoyo...",
		"....oyoy....",
		".....oy.....",
	],
	"sol": [
		"y.....y.....y",
		".y....y....y.",
		"..y..ooo..y..",
		"....ooooo....",
		"...oyyyyyo...",
		"yy.okyyyko.yy",
		"...oyyyyyo...",
		"...oyrrryo...",
		"....ooooo....",
		"..y..ooo..y..",
		".y....y....y.",
		"y.....y.....y",
	],
	"barco": [
		"......w......",
		"......ww.....",
		"......www....",
		"......wwww...",
		"......wwwww..",
		"......n......",
		"nnnnnnnnnnnnn",
		".nNNNNNNNNNn.",
		"..nnnnnnnnn..",
		"bbbbbbbbbbbbb",
		"lbbblbbbblbbb",
		"bbbbbbbbbbbbb",
	],
	"flor": [
		"....PP.PP....",
		"...PPPPPPP...",
		"..PPPyyyPPP..",
		"..PPyyoyyPP..",
		"...PPyyyPP...",
		"....PPPPP....",
		"......g......",
		"..gg..g......",
		"...ggggg.gg..",
		"......ggggg..",
		"......g......",
		"GGGGGGGGGGGGG",
	],
}


def generar_pintar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Pintar por numeros (kit/paintnum): el dibujo va en los parametros; el mapa, la semilla."""
	return ["pintar", "#%d" % ((semilla * 197 + i * 4421) % 1000003)]


def _dibujo_a_numeros(filas: list[str]) -> tuple[list[str], list[str]]:
	"""Letras de color -> numeros (el 1, el color que mas sale) y su paleta."""
	ancho = max(len(f) for f in filas)
	filas = [f.ljust(ancho, ".") for f in filas]
	cuenta: dict[str, int] = {}
	for f in filas:
		for ch in f:
			if ch != ".":
				cuenta[ch] = cuenta.get(ch, 0) + 1
	orden = sorted(cuenta, key=lambda c: (-cuenta[c], c))[:9]
	num = {c: str(k + 1) for k, c in enumerate(orden)}
	celdas = ["".join(num.get(ch, ".") for ch in f) for f in filas]
	return celdas, [COLORES_PINTAR[c] for c in orden]


def parametros_pintar(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Un dibujo de la coleccion por nivel (de los de menos colores a los de mas) y, cada tres
	niveles, el heroe del juego hecho cuadritos (si no hay arte, se queda el dibujo de la coleccion).
	Cubos: 2 al principio y 1 despues."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	nombres = sorted(DIBUJOS_PINTAR, key=lambda c: (len({ch for f in DIBUJOS_PINTAR[c] for ch in f}), c))
	tramo = max(1, len(nombres) // 3)
	nivel = min(2, int(3 * (i / max(1, n))))
	grupo = nombres[nivel * tramo:(nivel + 1) * tramo] or nombres
	nombre = grupo[(semilla + i) % len(grupo)]
	celdas, paleta = _dibujo_a_numeros(DIBUJOS_PINTAR[nombre])
	out = {"cells": celdas, "palette": paleta, "fills": 2 if i < n // 2 else 1, "dibujo": nombre}
	if i % 3 == 2:
		out.update({"from_art": True, "art_size": 14 + min(6, int(6 * d)), "art_colors": 5 + int(2 * d)})
	return out


## << genero pintar


## >> genero cuchillos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_cuchillos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Lanza cuchillos (kit/knifehit): el tronco va en los parametros; el mapa, la semilla."""
	return ["cuchillos", "#%d" % ((semilla * 211 + i * 3881) % 1000003)]


def parametros_cuchillos(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Cuchillos que lanzar (6 a 12), clavados de salida (0 a 4, separados), manzanas (0 a 2) y giro:
	constante al principio, luego con cambios de velocidad y de sentido. Cada quinto nivel, un jefe:
	mas cuchillos y giro traicionero. Todo cabe con holgura (el analizador del kit lo comprueba con
	el bot)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 37 + i)
	jefe = i % 5 == 4
	cuchillos = 6 + int(4 * d) + (2 if jefe else 0) + rnd.randint(0, 1)
	n_clavados = min(4, int(4 * d) + rnd.randint(0, 1)) if i > 0 else 0
	clavados: list[float] = []
	while len(clavados) < n_clavados:
		a = round(rnd.uniform(0, 360), 1)
		if all(min(abs(a - b) % 360, 360 - abs(a - b) % 360) >= 40 for b in clavados):
			clavados.append(a)
	manzanas: list[float] = []
	for _ in range(min(2, i // 2)):
		a = round(rnd.uniform(0, 360), 1)
		if all(min(abs(a - b) % 360, 360 - abs(a - b) % 360) >= 25 for b in clavados + manzanas):
			manzanas.append(a)
	v = 90 + 110 * d + rnd.uniform(-10, 10)
	sentido = rnd.choice([-1, 1])
	if i < 2 and not jefe:
		giro = [{"v": round(sentido * v, 1), "d": 2.0}]
	elif jefe or d > 0.6:
		giro = [{"v": round(sentido * v * 1.5, 1), "d": round(rnd.uniform(0.6, 1.0), 2)}, {"v": 0.0, "d": 0.35},
			{"v": round(-sentido * v * 0.8, 1), "d": round(rnd.uniform(0.8, 1.4), 2)}, {"v": round(sentido * v * 0.4, 1), "d": 0.6}]
	else:
		giro = [{"v": round(sentido * v, 1), "d": round(rnd.uniform(1.2, 2.0), 2)}, {"v": round(sentido * v * 0.45, 1), "d": round(rnd.uniform(0.6, 1.0), 2)}]
	return {"knives": cuchillos, "stuck": clavados, "apples": manzanas, "spin": giro, "boss": jefe}


## << genero cuchillos


## >> genero arquero (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_arquero(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Arquero (kit/rogue): las salas van en los parametros; el mapa, la semilla."""
	return ["arquero", "#%d" % ((semilla * 151 + i * 5003) % 1000003)]


def parametros_arquero(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""De 2 a 6 salas por nivel con mas enemigos segun avanza: babosas que persiguen desde el
	principio, arqueros que disparan desde el segundo nivel y murcielagos rapidos desde el tercero.
	Cada cuarto nivel acaba con un jefe que dispara en abanico. Nadie aparece cerca de la entrada."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 29 + i)
	tipos = ["slime"] + (["archer"] if i >= 1 else []) + (["bat"] if i >= 2 else [])
	n_salas = min(6, 2 + i // 2)
	jefe = i % 4 == 3
	salas = []
	for s in range(n_salas):
		ultimo = s == n_salas - 1
		cuantos = 2 + int(round((s / max(1, n_salas - 1)) * (1 + 3 * d))) + rnd.randint(0, 1)
		if ultimo and jefe:
			cuantos = 1 + int(1.5 * d)
		enemigos_sala = []
		if ultimo and jefe:
			enemigos_sala.append({"k": "boss", "x": 4.5, "y": 3.5})
		usados: list[tuple[float, float]] = [(4.5, 3.5)] if ultimo and jefe else []
		intentos = 0
		while len(enemigos_sala) < cuantos + (1 if ultimo and jefe else 0) and intentos < 200:
			intentos += 1
			x, y = round(rnd.uniform(1.0, 8.0), 2), round(rnd.uniform(1.0, 8.2), 2)
			if any((x - a) ** 2 + (y - b) ** 2 < 1.6 ** 2 for a, b in usados):
				continue
			usados.append((x, y))
			enemigos_sala.append({"k": rnd.choice(tipos), "x": x, "y": y})
		salas.append({"enemies": enemigos_sala})
	return {"rooms": salas, "seed": semilla % 100000 + i, "boss": jefe, "power": round((0.9 + 0.1 * i + 0.5 * d) * (0.8 if jefe else 1.0), 2)}


## << genero arquero


## >> genero flechas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_flechas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Flechas (kit/arrows): el tablero va en los parametros; el mapa, la semilla."""
	return ["flechas", "#%d" % ((semilla * 173 + i * 2741) % 1000003)]


_DIRS_FLECHAS = {"u": (0, -1), "d": (0, 1), "l": (-1, 0), "r": (1, 0)}


def _celdas_flecha(x: int, y: int, d: str, largo: int) -> list[tuple[int, int]]:
	dx, dy = _DIRS_FLECHAS[d]
	return [(x - dx * k, y - dy * k) for k in range(largo)]


def _libres_flechas(w: int, h: int, flechas: list[dict]) -> int:
	"""Cuantas flechas pueden salir ya (camino hasta el borde sin otras)."""
	ocupa = {}
	for k, f in enumerate(flechas):
		for c in _celdas_flecha(f["x"], f["y"], f["d"], f["n"]):
			ocupa[c] = k
	libres = 0
	for k, f in enumerate(flechas):
		dx, dy = _DIRS_FLECHAS[f["d"]]
		x, y = f["x"] + dx, f["y"] + dy
		bloqueada = False
		while 0 <= x < w and 0 <= y < h:
			if ocupa.get((x, y), k) != k:
				bloqueada = True
				break
			x, y = x + dx, y + dy
		libres += 0 if bloqueada else 1
	return libres


def parametros_flechas(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Tablero de 5x6 a 9x12 lleno de flechas rectas de 1 a 4 casillas. Siempre tiene solucion: cada
	flecha nueva se pone con su camino libre respecto a las que ya hay, asi que quitarlas en orden
	inverso funciona (y quitar las libres una a una tambien). Pocas libres al empezar: hay que
	pensar el orden."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	mejor = None
	for intento in range(12):
		rnd = random.Random(semilla * 61 + i * 7 + intento * 1009)
		w = 5 + min(4, i // 2 + int(2 * d))
		h = 6 + min(6, i // 2 + int(3 * d))
		ocupadas: set[tuple[int, int]] = set()
		flechas: list[dict] = []
		objetivo = int(w * h * (0.55 + 0.25 * d))
		fallos = 0
		while sum(f["n"] for f in flechas) < objetivo and fallos < 600:
			## Casi siempre se pone en el camino de salida de una flecha ya puesta: asi la tapa y
			## hay que pensar el orden.
			caminos = []
			if flechas and rnd.random() < 0.8:
				for f in flechas:
					fx, fy = _DIRS_FLECHAS[f["d"]]
					qx, qy = f["x"] + fx, f["y"] + fy
					while 0 <= qx < w and 0 <= qy < h:
						if (qx, qy) not in ocupadas:
							caminos.append((qx, qy))
						qx, qy = qx + fx, qy + fy
			x, y = rnd.choice(caminos) if caminos else (rnd.randrange(w), rnd.randrange(h))
			dd = rnd.choice("udlr")
			largo = rnd.choice([1, 2, 2, 3, 3, 4])
			celdas = _celdas_flecha(x, y, dd, largo)
			if any(not (0 <= cx < w and 0 <= cy < h) or (cx, cy) in ocupadas for cx, cy in celdas):
				fallos += 1
				continue
			dx, dy = _DIRS_FLECHAS[dd]
			px, py = x + dx, y + dy
			libre = True
			while 0 <= px < w and 0 <= py < h:
				if (px, py) in ocupadas:
					libre = False
					break
				px, py = px + dx, py + dy
			if not libre:
				fallos += 1
				continue
			flechas.append({"x": x, "y": y, "d": dd, "n": largo})
			ocupadas.update(celdas)
		libres = _libres_flechas(w, h, flechas)
		nota = libres / max(1, len(flechas))
		if mejor is None or nota < mejor[0]:
			mejor = (nota, {"w": w, "h": h, "arrows": flechas, "lives": 3 if d < 0.7 else 2})
		if nota <= 0.35 and len(flechas) >= 6:
			break
	return mejor[1]


## << genero flechas


## >> genero numeros (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_numeros(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""2048 (kit/merge2048): el tablero va en los parametros; el mapa, la semilla."""
	return ["numeros", "#%d" % ((semilla * 223 + i * 6007) % 1000003)]


def parametros_numeros(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Objetivo que sube de 64 a 512 (partidas de 1 a 5 minutos); tableros de 4x4 y, desde la mitad,
	de 5x5 con rocas que cortan las filas. Dos deshacer por nivel."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 43 + i)
	exp = min(9, 6 + i // 2 + int(round(1.5 * d)))
	lado = 4
	rocas: list[list[int]] = []
	if i >= n // 2:
		lado = 5
		for _ in range(1 + int(2 * d)):
			x, y = rnd.randrange(lado), rnd.randrange(lado)
			if [x, y] not in rocas and (x, y) not in ((0, 0), (lado - 1, 0), (0, lado - 1), (lado - 1, lado - 1)):
				rocas.append([x, y])
	return {"size": lado, "target": 2 ** exp, "rocks": rocas, "seed": semilla % 100000 + i * 13, "undo": 2}


## << genero numeros


## >> genero cartas_locas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## Espejo exacto de orqkit/kit/crazy8/crazy8_map.gd (reparto, jugadas del bot y de los rivales): asi
## la fabrica elige mazos con los que tu bot gana y el analizador del kit lo confirma.
COLORES_C8 = ["r", "g", "b", "y"]


def _mazo_c8() -> list[str]:
	out = []
	for c in COLORES_C8:
		out.append(c + "0")
		for _ in range(2):
			for v in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "S", "R", "D"]:
				out.append(c + v)
	for _ in range(4):
		out += ["W", "F"]
	return out


def _comodin_c8(c: str) -> bool:
	return c in ("W", "F")


def _valor_c8(c: str) -> str:
	return c if _comodin_c8(c) else c[1:]


class _PartidaC8:
	def __init__(self, mazo: list[str], jugadores: int, mano: int):
		self.n = jugadores
		self.robo = list(reversed(mazo))
		self.manos: list[list[str]] = [[] for _ in range(jugadores)]
		for _ in range(mano):
			for p in range(jugadores):
				if self.robo:
					self.manos[p].append(self.robo.pop())
		vueltas = 0
		while self.robo and _comodin_c8(self.robo[-1]) and vueltas < 20:
			self.robo.insert(0, self.robo.pop())
			vueltas += 1
		arriba = self.robo.pop() if self.robo else "r0"
		self.mesa = [arriba]
		self.color = arriba[0]
		self.turno, self.sentido, self.robada, self.ganador, self.turnos = 0, 1, "", -1, 0

	def jugable(self, c: str) -> bool:
		if _comodin_c8(c) or c[0] == self.color:
			return True
		t = self.mesa[-1]
		return not _comodin_c8(t) and _valor_c8(c) == _valor_c8(t)

	def siguiente(self, pasos: int = 1) -> int:
		return (self.turno + self.sentido * pasos) % self.n

	def _coger(self, p: int) -> str:
		if not self.robo:
			guarda = self.mesa.pop()
			self.robo = list(reversed(self.mesa))
			self.mesa = [guarda]
		if not self.robo:
			return ""
		c = self.robo.pop()
		self.manos[p].append(c)
		return c

	def pasar(self):
		self.robada = ""
		self.turno = self.siguiente()
		self.turnos += 1

	def robar(self):
		c = self._coger(self.turno)
		self.robada = c if c else "-"
		if not c or not self.jugable(c):
			self.pasar()

	@staticmethod
	def mejor_color(mano: list[str]) -> str:
		mejor, bn = "r", -1
		for c in COLORES_C8:
			k = sum(1 for h in mano if h[0] == c and not _comodin_c8(h))
			if k > bn:
				mejor, bn = c, k
		return mejor

	def jugar(self, idx: int, color: str):
		p = self.turno
		mano = self.manos[p]
		c = mano.pop(idx)
		self.mesa.append(c)
		self.color = (color if color in COLORES_C8 else self.mejor_color(mano)) if _comodin_c8(c) else c[0]
		self.robada = ""
		if not mano:
			self.ganador = p
			return
		v = _valor_c8(c)
		salto = 1
		if v == "R":
			self.sentido = -self.sentido
			if self.n == 2:
				salto = 2
		elif v == "S":
			salto = 2
		elif v in ("D", "F"):
			victima = self.siguiente()
			for _ in range(2 if v == "D" else 4):
				self._coger(victima)
			salto = 2
		self.turno = self.siguiente(salto)
		self.turnos += 1

	def rival(self) -> int:
		mano = self.manos[self.turno]
		if self.robada not in ("", "-"):
			return len(mano) - 1
		for i, c in enumerate(mano):
			if self.jugable(c):
				return i
		return -1

	def bot(self) -> int:
		mano = self.manos[self.turno]
		if self.robada not in ("", "-"):
			return len(mano) - 1
		sig = len(self.manos[self.siguiente()])
		mejor, bs = -1, float("-inf")
		for i, c in enumerate(mano):
			if not self.jugable(c):
				continue
			v = _valor_c8(c)
			if _comodin_c8(c):
				s = -20.0 + (30.0 if sig <= 2 and c == "F" else 0.0)
			elif v in ("D", "S", "R"):
				s = 5.0 + (25.0 if sig <= 2 else 0.0)
			else:
				s = float(int(v))
			s += sum(1 for h in mano if h[0] == c[0]) * 0.5
			if s > bs:
				mejor, bs = i, s
		return mejor

	def turno_auto(self, listo: bool):
		i = self.bot() if listo else self.rival()
		if i >= 0:
			self.jugar(i, self.mejor_color(self.manos[self.turno]))
		elif self.robada == "":
			self.robar()
		else:
			self.pasar()

	def partida(self, tu_listo: bool = True, max_turnos: int = 600) -> int:
		while self.ganador < 0 and self.turnos < max_turnos:
			self.turno_auto(tu_listo if self.turno == 0 else False)
		return self.ganador


def generar_cartas_locas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Cartas locas (kit/crazy8): el mazo va en los parametros; el mapa, la semilla."""
	return ["cartas_locas", "#%d" % ((semilla * 239 + i * 4993) % 1000003)]


def parametros_cartas_locas(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""De 1 a 3 rivales segun avanza. Se barajan mazos hasta uno con el que tu bot gana (y, desde
	el tercer nivel, uno con el que jugar sin pensar, la primera carta que valga, no gana: hay que
	usar bien los +2, los saltos y los comodines)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	jugadores = 2 + min(2, i // 3 + int(round(d)))
	mano = 7
	exigente = i >= 2
	elegido = None
	for intento in range(200):
		rnd = random.Random(semilla * 97 + i * 13 + intento * 7919)
		mazo = _mazo_c8()
		rnd.shuffle(mazo)
		if _PartidaC8(mazo, jugadores, mano).partida(True) != 0:
			continue
		if elegido is None:
			elegido = mazo
		if not exigente or _PartidaC8(mazo, jugadores, mano).partida(False) != 0:
			elegido = mazo
			break
	return {"players": jugadores, "hand": mano, "deck": elegido or _mazo_c8()}


## << genero cartas_locas


## >> genero domino (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## Espejo exacto de orqkit/kit/domino/domino_map.gd (reparto, salida, jugadas del bot y de los
## rivales): la fabrica elige mazos con los que tu bot gana y el analizador del kit lo confirma.
def _fichas_domino() -> list[list[int]]:
	return [[a, b] for a in range(7) for b in range(a, 7)]


class _PartidaDomino:
	def __init__(self, mazo: list[list[int]], jugadores: int, mano: int):
		self.n = jugadores
		self.pozo = [list(t) for t in reversed(mazo)]
		self.manos: list[list[list[int]]] = [[] for _ in range(jugadores)]
		for _ in range(mano):
			for p in range(jugadores):
				if self.pozo:
					self.manos[p].append(self.pozo.pop())
		self.cadena: list[list[int]] = []
		self.izq, self.der, self.pases, self.ganador, self.turnos = -1, -1, 0, -1, 0
		mejor, quien, idx = -1, 0, 0
		for p in range(jugadores):
			for i, t in enumerate(self.manos[p]):
				v = 100 + t[0] if t[0] == t[1] else t[0] + t[1]
				if v > mejor:
					mejor, quien, idx = v, p, i
		self.turno = quien
		self.jugar(idx, "r")

	def encaja(self, t: list[int]) -> list[str]:
		if not self.cadena:
			return ["r"]
		out = []
		if self.izq in (t[0], t[1]):
			out.append("l")
		if self.der in (t[0], t[1]):
			out.append("r")
		return out

	def puede(self, p: int) -> bool:
		return any(self.encaja(t) for t in self.manos[p])

	def jugar(self, idx: int, lado: str):
		p = self.turno
		t = self.manos[p].pop(idx)
		if not self.cadena:
			self.cadena.append(list(t))
			self.izq, self.der = t[0], t[1]
		elif lado == "l":
			o = t[1] if t[0] == self.izq else t[0]
			self.cadena.insert(0, [o, self.izq])
			self.izq = o
		else:
			o = t[1] if t[0] == self.der else t[0]
			self.cadena.append([self.der, o])
			self.der = o
		self.pases = 0
		if not self.manos[p]:
			self.ganador = p
			return
		self.turno = (self.turno + 1) % self.n
		self.turnos += 1

	def robar(self) -> bool:
		if self.puede(self.turno) or not self.pozo:
			return False
		self.manos[self.turno].append(self.pozo.pop())
		return True

	def pasar(self):
		self.pases += 1
		if self.pases >= self.n:
			sumas = [sum(a + b for a, b in m) for m in self.manos]
			self.ganador = sumas.index(min(sumas))
			return
		self.turno = (self.turno + 1) % self.n
		self.turnos += 1

	def rival(self):
		for i, t in enumerate(self.manos[self.turno]):
			f = self.encaja(t)
			if f:
				return [i, f[0]]
		return []

	def bot(self):
		mano = self.manos[self.turno]
		mejor, bs = [], -1.0
		for i, t in enumerate(mano):
			for lado in self.encaja(t):
				s = float(t[0] + t[1]) + (6.0 if t[0] == t[1] else 0.0)
				punta = self.izq if lado == "l" else self.der
				abierta = t[1] if t[0] == punta else t[0]
				for j, u in enumerate(mano):
					if j != i and abierta in (u[0], u[1]):
						s += 1.5
				if s > bs:
					mejor, bs = [i, lado], s
		return mejor

	def turno_auto(self, listo: bool):
		m = self.bot() if listo else self.rival()
		if m:
			self.jugar(m[0], m[1])
		elif not self.robar():
			self.pasar()

	def partida(self, tu_listo: bool = True) -> int:
		vueltas = 0
		while self.ganador < 0 and vueltas < 1600:
			vueltas += 1
			self.turno_auto(tu_listo if self.turno == 0 else False)
		return self.ganador


def generar_domino(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Domino (kit/domino): el mazo va en los parametros; el mapa, la semilla."""
	return ["domino", "#%d" % ((semilla * 251 + i * 3557) % 1000003)]


def parametros_domino(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""De 1 a 3 rivales segun avanza (con 4 jugadores no queda pozo). Se barajan mazos hasta uno con
	el que tu bot gana y, desde el tercer nivel, uno en el que jugar la primera ficha que case no gana."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	jugadores = 2 + min(2, i // 3 + int(round(d)))
	mano = 7
	exigente = i >= 2
	elegido = None
	for intento in range(300):
		rnd = random.Random(semilla * 89 + i * 17 + intento * 6007)
		mazo = _fichas_domino()
		rnd.shuffle(mazo)
		if _PartidaDomino(mazo, jugadores, mano).partida(True) != 0:
			continue
		if elegido is None:
			elegido = mazo
		if not exigente or _PartidaDomino(mazo, jugadores, mano).partida(False) != 0:
			elegido = mazo
			break
	return {"players": jugadores, "hand": mano, "deck": elegido or _fichas_domino()}


## << genero domino


## >> genero bloques_colores (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
## Espejo de orqkit/kit/blockjam/blockjam_map.gd (mover, salir por la puerta y camino mas corto):
## asi la fabrica solo entrega tableros que se pueden vaciar.
FORMAS_JAM = [[[0, 0]], [[0, 0], [1, 0]], [[0, 0], [0, 1]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [0, 1], [0, 2]],
	[[0, 0], [1, 0], [0, 1], [1, 1]], [[0, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [1, 1]], [[1, 0], [0, 1], [1, 1]]]
COLORES_JAM = ["#e74c3c", "#3498db", "#f1c40f", "#2ecc71", "#9b59b6", "#e67e22"]
_DIR_JAM = {"u": (0, -1), "d": (0, 1), "l": (-1, 0), "r": (1, 0)}
_SALIDA_JAM = {"t": "u", "b": "d", "l": "l", "r": "r"}


def _celdas_jam(b: dict, p: tuple[int, int]) -> list[tuple[int, int]]:
	return [(p[0] + c[0], p[1] + c[1]) for c in b["cells"]]


def _puerta_jam(t: dict, b: dict, p: tuple[int, int], d: str) -> bool:
	celdas = _celdas_jam(b, p)
	for door in t["doors"]:
		if _SALIDA_JAM[door["side"]] != d or door["c"] != b["c"]:
			continue
		a0, a1 = door["at"], door["at"] + door["len"]
		dentro = all(a0 <= (x if d in ("u", "d") else y) < a1 for x, y in celdas)
		toca = any((d == "u" and y == 0) or (d == "d" and y == t["h"] - 1) or (d == "l" and x == 0) or (d == "r" and x == t["w"] - 1) for x, y in celdas)
		if dentro and toca:
			return True
	return False


def _camino_jam(t: dict, bloques: list[dict], i: int) -> list[str]:
	b = bloques[i]
	ocupa = {c for j, o in enumerate(bloques) if j != i for c in _celdas_jam(o, (o["x"], o["y"]))}
	muros = {tuple(w) for w in t["walls"]}
	inicio = (b["x"], b["y"])
	previo: dict = {inicio: None}
	cola = [inicio]
	k = 0
	while k < len(cola):
		p = cola[k]
		k += 1
		for d in ("u", "d", "l", "r"):
			if _puerta_jam(t, b, p, d):
				out = [d]
				while previo[p] is not None:
					q, dd = previo[p]
					out.insert(0, dd)
					p = q
				return out
			np = (p[0] + _DIR_JAM[d][0], p[1] + _DIR_JAM[d][1])
			if np in previo:
				continue
			if all(0 <= x < t["w"] and 0 <= y < t["h"] and (x, y) not in muros and (x, y) not in ocupa for x, y in _celdas_jam(b, np)):
				previo[np] = (p, d)
				cola.append(np)
	return []


def _resolver_jam(t: dict) -> int:
	"""Pasos de la solucion del bot (sacar el primero que tenga camino, por orden); -1 si se atasca."""
	bloques = [dict(b) for b in t["blocks"]]
	pasos = 0
	while bloques:
		for i in range(len(bloques)):
			c = _camino_jam(t, bloques, i)
			if c:
				pasos += len(c)
				bloques.pop(i)
				break
		else:
			return -1
	return pasos


def generar_bloques_colores(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Bloques de colores (kit/blockjam): el tablero va en los parametros; el mapa, la semilla."""
	return ["bloques_colores", "#%d" % ((semilla * 263 + i * 4129) % 1000003)]


def parametros_bloques_colores(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Tablero de 5x6 a 8x10 lleno al 50-70 % de bloques (1 a 4 casillas) de 3 a 6 colores, con una
	o dos puertas por color en los bordes. Se prueban tableros hasta uno que se puede vaciar y en el
	que no todos los bloques tienen camino al empezar (hay que pensar el orden)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	mejor = None
	for intento in range(150):
		rnd = random.Random(semilla * 59 + i * 11 + intento * 7907)
		w = 5 + min(3, i // 3 + int(1.5 * d))
		h = 6 + min(4, i // 2 + int(2 * d))
		ncol = min(6, 3 + i // 3 + int(round(d)))
		t: dict = {"w": w, "h": h, "walls": [], "colors": COLORES_JAM[:ncol], "doors": [], "blocks": []}
		lados = ["t", "b", "l", "r"]
		for c in range(ncol):
			for _ in range(1 + (1 if rnd.random() < 0.35 - 0.2 * d else 0)):
				lado = rnd.choice(lados)
				largo_borde = w if lado in ("t", "b") else h
				ln = rnd.choice([1, 2, 2, 3])
				t["doors"].append({"side": lado, "at": rnd.randrange(0, largo_borde - ln + 1), "len": ln, "c": c})
		for _ in range(int(0.06 * w * h * d)):
			x, y = rnd.randrange(1, w - 1), rnd.randrange(1, h - 1)
			if [x, y] not in t["walls"]:
				t["walls"].append([x, y])
		ocupadas = {tuple(w2) for w2 in t["walls"]}
		objetivo = int(w * h * (0.5 + 0.2 * d))
		fallos = 0
		while sum(len(b["cells"]) for b in t["blocks"]) < objetivo and fallos < 300:
			forma = rnd.choice(FORMAS_JAM)
			x, y = rnd.randrange(w), rnd.randrange(h)
			celdas = [(x + a, y + b) for a, b in forma]
			if any(not (0 <= cx < w and 0 <= cy < h) or (cx, cy) in ocupadas for cx, cy in celdas):
				fallos += 1
				continue
			## Solo colores con alguna puerta por la que quepa esta forma.
			ancho = max(a for a, _ in forma) + 1
			alto = max(b for _, b in forma) + 1
			validos = sorted({dr["c"] for dr in t["doors"] if dr["len"] >= (ancho if dr["side"] in ("t", "b") else alto)})
			if not validos:
				fallos += 1
				continue
			t["blocks"].append({"c": rnd.choice(validos), "x": x, "y": y, "cells": [list(c) for c in forma]})
			ocupadas.update(celdas)
		if len(t["blocks"]) < 4:
			continue
		pasos = _resolver_jam(t)
		if pasos < 0:
			continue
		libres = sum(1 for k2 in range(len(t["blocks"])) if _camino_jam(t, t["blocks"], k2))
		nota = libres / len(t["blocks"])
		if mejor is None or nota < mejor[0]:
			mejor = (nota, t, pasos)
		if nota <= 0.5:
			break
	if mejor is None:
		t = {"w": 5, "h": 6, "walls": [], "colors": COLORES_JAM[:3], "doors": [{"side": "t", "at": 0, "len": 5, "c": c} for c in range(3)],
			"blocks": [{"c": c, "x": c, "y": 2, "cells": [[0, 0]]} for c in range(3)]}
		mejor = (1.0, t, _resolver_jam(t))
	t, pasos = mejor[1], mejor[2]
	t["moves"] = 0 if i < n // 2 or dificultad == "facil" else pasos + max(6, int(pasos * (0.8 - 0.4 * d)))
	return t


## << genero bloques_colores


## >> genero tuberias (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_tuberias(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Tuberias (kit/pipes): el tablero va en los parametros; el mapa, la semilla."""
	return ["tuberias", "#%d" % ((semilla * 269 + i * 3301) % 1000003)]


def _girar_tubo(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15


def parametros_tuberias(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Tablero de 4x5 a 7x9: un arbol al azar desde el grifo que pasa por todas las casillas (asi
	siempre hay solucion) y cada pieza girada al azar. Desde la mitad, con toques contados."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 67 + i)
	w = 4 + min(3, i // 2 + int(1.5 * d))
	h = 5 + min(4, i // 2 + int(2 * d))
	src = (rnd.randrange(w), rnd.randrange(h))
	mask = [0] * (w * h)
	visto = {src}
	pila = [src]
	pasos = {1: (0, -1), 2: (1, 0), 4: (0, 1), 8: (-1, 0)}
	opuesto = {1: 4, 4: 1, 2: 8, 8: 2}
	## Arbol por busqueda en profundidad con algo de anchura (ramas mas cortas y mas cruces).
	while pila:
		x, y = pila[-1] if rnd.random() < 0.7 else pila[rnd.randrange(len(pila))]
		vecinos = [(b, (x + dx, y + dy)) for b, (dx, dy) in pasos.items() if 0 <= x + dx < w and 0 <= y + dy < h and (x + dx, y + dy) not in visto]
		if not vecinos:
			pila.remove((x, y))
			continue
		b, (nx, ny) = rnd.choice(vecinos)
		mask[y * w + x] |= b
		mask[ny * w + nx] |= opuesto[b]
		visto.add((nx, ny))
		pila.append((nx, ny))
	tiles = []
	for m in mask:
		t = m
		for _ in range(rnd.randrange(4)):
			t = _girar_tubo(t)
		tiles.append(t)
	## Que no salga casi resuelto: al menos la mitad de las piezas giradas de verdad.
	def faltan(t: int, s: int) -> int:
		for k2 in range(4):
			if t == s:
				return k2
			t = _girar_tubo(t)
		return 0
	for idx in range(len(tiles)):
		if faltan(tiles[idx], mask[idx]) == 0 and mask[idx] not in (5, 10, 15) and rnd.random() < 0.6:
			tiles[idx] = _girar_tubo(tiles[idx])
	minimo = sum(faltan(t, s) for t, s in zip(tiles, mask))
	toques = 0 if i < n // 2 or dificultad == "facil" else minimo + max(4, int(minimo * (0.6 - 0.3 * d)))
	return {"w": w, "h": h, "src": list(src), "tiles": tiles, "sol": mask, "taps": toques}


## << genero tuberias


## >> genero ajedrez (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_ajedrez(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Ajedrez (kit/chess): la partida va en los parametros; el mapa, la semilla."""
	return ["ajedrez", "#%d" % ((semilla * 271 + i * 3307) % 1000003)]


## Escalera de ventaja: de jugar con la dama y las torres del rival quitadas a la partida de verdad.
_AJEDREZ_ESCALERA = [
	(0.2, ["q", "r", "r"], 1, 0.35),
	(0.4, ["q", "r"], 1, 0.25),
	(0.55, ["q"], 1, 0.15),
	(0.7, ["r"], 2, 0.12),
	(0.85, ["n"], 2, 0.08),
	(9.0, [], 2, 0.05),
]


def parametros_ajedrez(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Lo listo que es el rival, cuanto se equivoca y que piezas le faltan al empezar."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	for tope, quitar, rival, fallo in _AJEDREZ_ESCALERA:
		if d < tope:
			return {"rival": rival, "quitar": list(quitar), "mistake": fallo, "seed": semilla % 99991 + i, "max_plies": 200}
	return {"rival": 2, "quitar": [], "mistake": 0.05, "seed": semilla % 99991 + i, "max_plies": 200}


## << genero ajedrez


## >> genero reversi (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_reversi(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Reversi (kit/reversi): la partida va en los parametros; el mapa, la semilla."""
	return ["reversi", "#%d" % ((semilla * 277 + i * 3313) % 1000003)]


## Escalera: tablero pequeno y rival despistado al principio; tablero de 8x8 y rival que piensa dos
## jugadas al final.
_REVERSI_ESCALERA = [
	(0.25, 6, 1, 0.3),
	(0.45, 6, 2, 0.15),
	(0.65, 8, 1, 0.15),
	(0.85, 8, 2, 0.1),
	(9.0, 8, 2, 0.05),
]


def parametros_reversi(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Tamano del tablero, lo listo que es el rival y cuanto se equivoca."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	for tope, lado, rival, fallo in _REVERSI_ESCALERA:
		if d < tope:
			return {"size": lado, "rival": rival, "mistake": fallo, "seed": semilla % 99991 + i}
	return {"size": 8, "rival": 2, "mistake": 0.05, "seed": semilla % 99991 + i}


## << genero reversi


## >> genero buscar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_buscar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Buscar objetos (kit/hidden): la escena va en los parametros; el mapa, la semilla."""
	return ["buscar", "#%d" % ((semilla * 283 + i * 3319) % 1000003)]


## Las 24 figuras del dibujo por datos (kit/spotdiff/scene_draw.gd).
FIGURAS_BUSCAR = ["circle", "balloon", "square", "gift", "tri", "kite", "star", "flower", "tree", "bush", "house", "cloud", "sun",
	"fish", "car", "heart", "moon", "mushroom", "rock", "bird", "boat", "cake", "cup", "lamp"]


## Figuras que se dibujan casi igual: cuentan como la misma al buscar (que no haya "gemelas").
FAMILIA_BUSCAR = {"kite": "tri", "balloon": "circle", "gift": "square", "cloud": "bush"}


def _familia(k: str) -> str:
	return FAMILIA_BUSCAR.get(k, k)


def _tapada(escena: list, i: int) -> float:
	"""Lo mismo que hidden_map.gd -> covered: cuanto tapan a la figura i las que van despues."""
	a = escena[i]
	ra = a["s"] * 0.5
	peor = 0.0
	for b in escena[i + 1:]:
		d = ((a["x"] - b["x"]) ** 2 + (a["y"] - b["y"]) ** 2) ** 0.5
		rb = b["s"] * 0.5
		if d < ra + rb:
			peor = max(peor, min(1.0, max(0.0, (ra + rb - d) / (2 * ra))))
	return peor


def parametros_buscar(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Escena tematica llena de figuras (de 16 a 46, mas pequenas segun avanza) y de 3 a 8 que buscar,
	cada una la unica de su clase y sin tapar. Tiempo y fallos contados en la segunda mitad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 73 + i)
	tema = list(TEMAS_DIFERENCIAS)[(semilla + i) % len(TEMAS_DIFERENCIAS)]
	t = TEMAS_DIFERENCIAS[tema]
	n_obj = min(8, 3 + i // 2 + int(2 * d))
	n_fig = 16 + int(30 * d) + i
	propias = [f for f in t["k"]]
	resto = [f for f in FIGURAS_BUSCAR if f not in propias]
	rnd.shuffle(propias)
	rnd.shuffle(resto)
	## Las que hay que buscar: mitad del tema, mitad de fuera (asi hay donde elegir relleno).
	buscar = (propias[: (n_obj + 1) // 2] + resto[: n_obj // 2])[:n_obj]
	## Mitad del tema y mitad de fuera, sin dos de la misma familia.
	elegidas: list[str] = []
	for f in buscar + propias + resto:
		if len(elegidas) < n_obj and _familia(f) not in {_familia(e) for e in elegidas}:
			elegidas.append(f)
	buscar = elegidas
	relleno = [f for f in FIGURAS_BUSCAR if _familia(f) not in {_familia(b2) for b2 in buscar}]
	tam = 0.16 - 0.07 * d
	escena: list = []
	for _ in range(n_fig):
		escena.append({"k": rnd.choice(relleno), "x": round(rnd.uniform(0.06, 0.94), 3), "y": round(rnd.uniform(0.06, 0.94), 3),
			"s": round(max(0.06, tam * rnd.uniform(0.75, 1.35)), 3), "c": rnd.choice(COLORES_DIFERENCIAS), "f": rnd.random() < 0.5})
	objetivos = []
	for kind in buscar:
		## Un sitio donde casi no la tapen: varias pruebas y la mejor.
		mejor = None
		for _ in range(40):
			pos = rnd.randrange(len(escena) // 3, len(escena) + 1)
			sh = {"k": kind, "x": round(rnd.uniform(0.1, 0.9), 3), "y": round(rnd.uniform(0.1, 0.9), 3),
				"s": round(max(0.07, tam * rnd.uniform(0.85, 1.1)), 3), "c": rnd.choice(COLORES_DIFERENCIAS), "f": rnd.random() < 0.5}
			if any(((sh["x"] - o["x"]) ** 2 + (sh["y"] - o["y"]) ** 2) ** 0.5 < (sh["s"] + o["s"]) * 0.5 + 0.02 for o in objetivos):
				continue
			prueba = escena[:pos] + [sh] + escena[pos:]
			tap = _tapada(prueba, pos)
			if mejor is None or tap < mejor[0]:
				mejor = (tap, pos, sh)
			if tap <= 0.15:
				break
		if mejor is None:
			## Sin hueco libre entre las otras: al final de la lista (encima de todo).
			mejor = (0.0, len(escena), {"k": kind, "x": round(rnd.uniform(0.1, 0.9), 3), "y": round(rnd.uniform(0.1, 0.9), 3),
				"s": round(max(0.07, tam), 3), "c": rnd.choice(COLORES_DIFERENCIAS), "f": False})
		escena.insert(mejor[1], mejor[2])
		objetivos.append(mejor[2])
	## Si al meter las siguientes se tapo alguna, se suben sus tapadoras al fondo (antes en la lista).
	for sh in objetivos:
		i_obj = escena.index(sh)
		while _tapada(escena, i_obj) > 0.3:
			for j in range(i_obj + 1, len(escena)):
				b = escena[j]
				dist = ((sh["x"] - b["x"]) ** 2 + (sh["y"] - b["y"]) ** 2) ** 0.5
				if dist < (sh["s"] + b["s"]) * 0.5 and b not in objetivos:
					escena.insert(0, escena.pop(j))
					break
			else:
				break
			i_obj = escena.index(sh)
	targets = [escena.index(sh) for sh in objetivos]
	segunda = i >= n // 2 and dificultad != "facil"
	return {"shapes": escena, "targets": targets, "bg": t["bg"], **({"ground": t["ground"]} if "ground" in t else {}),
		"time": int(10 + 8 * n_obj - 20 * d) if segunda else 0, "misses": 5 if segunda else 0, "hints": 2 if i < n // 2 else 1}


## << genero buscar


## >> genero deslizar (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_deslizar(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Puzle de deslizar (kit/slide): el tablero va en los parametros; el mapa, la semilla."""
	return ["deslizar", "#%d" % ((semilla * 281 + i * 3323) % 1000003)]


def parametros_deslizar(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Dibujo tematico (una figura distinta por pieza, como el rompecabezas) con el heroe en medio,
	de 3x3 a 5x5. Se desordena moviendo el hueco al azar desde el dibujo resuelto (asi siempre tiene
	solucion) y se guarda el camino de vuelta como solucion. Desde la mitad, movimientos contados."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 59 + i)
	tema = list(TEMAS_DIFERENCIAS)[(semilla + i) % len(TEMAS_DIFERENCIAS)]
	t = TEMAS_DIFERENCIAS[tema]
	lado = 3 if i < 2 else min(5, 3 + int(i >= 4) + int(d > 0.7))
	combos = [(f, c) for f in t["k"] for c in COLORES_DIFERENCIAS if c != t["bg"]]
	rnd.shuffle(combos)
	escena = []
	for celda in range(lado * lado):
		cx, cy = celda % lado, celda // lado
		f, c = combos[celda % len(combos)]
		escena.append({"k": f, "c": c, "x": round((cx + 0.5 + rnd.uniform(-0.1, 0.1)) / lado, 3),
			"y": round((cy + 0.5 + rnd.uniform(-0.1, 0.1)) / lado, 3), "s": round((0.62 + 0.12 * rnd.random()) / lado, 3),
			"f": rnd.random() < 0.5})
	total = lado * lado
	hueco = total - 1
	pasos = int((14 + 26 * d) * (lado - 1) * 0.75)
	for _ in range(50):
		tiles = list(range(total))
		b = hueco
		camino = [b]
		previa = -1
		for _ in range(pasos):
			x, y = b % lado, b // lado
			vecinos = [v for v, ok in ((b - 1, x > 0), (b + 1, x < lado - 1), (b - lado, y > 0), (b + lado, y < lado - 1)) if ok and v != previa]
			v = rnd.choice(vecinos)
			tiles[b], tiles[v] = tiles[v], tiles[b]
			previa, b = b, v
			camino.append(b)
		en_sitio = sum(1 for a, p in enumerate(tiles) if a == p and p != hueco)
		if tiles != list(range(total)) and en_sitio * 2 <= total:
			break
		pasos += 6
	## Solucion: deshacer el camino del hueco (tocar la casilla donde estaba antes).
	sol = list(reversed(camino[:-1]))
	segunda = i >= n // 2 and dificultad != "facil"
	return {"n": lado, "tiles": tiles, "sol": sol, "moves": len(sol) * 4 if segunda else 0, "scene": escena, "bg": t["bg"],
		**({"ground": t["ground"]} if "ground" in t else {}), "hero": True}


## << genero deslizar


## >> genero ahorcado (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_ahorcado(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Ahorcado con globos (kit/hangman): la palabra la elige el kit del diccionario del idioma del
	jugador con la semilla; el mapa solo la lleva. El analizador lo prueba en los 6 idiomas."""
	return ["ahorcado", "#%d" % ((semilla * 293 + i * 3329) % 1000003)]


def parametros_ahorcado(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Largo (5 a 8 letras: las cortas son las dificiles), globos (7 a 5) y lo rara que es la palabra."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	largo = 6 if i == 0 else (7 - int(2 * d) if i % 2 else 5 + int(3 * d))
	return {"len": max(5, min(8, largo)), "lives": 7 if d < 0.35 else (6 if d < 0.75 else 5), "rank": round(min(1.0, 0.05 + 0.6 * d), 2),
		"hint": 1 if i < n - 2 else 0}


## << genero ahorcado


## >> genero flota (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_flota(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Hundir la flota (kit/battle): las flotas las coloca el kit con la semilla; el mapa la lleva."""
	return ["flota", "#%d" % ((semilla * 307 + i * 3331) % 1000003)]


## Escalera: tablero, flota y rival (0 al azar, 1 caza lo tocado, 2 ademas en damero) con sus fallos.
_FLOTA_ESCALERA = [
	(0.2, 6, [3, 2, 2], 0, 0.0),
	(0.4, 7, [3, 3, 2, 2], 1, 0.45),
	(0.6, 8, [4, 3, 3, 2, 2], 1, 0.3),
	(0.8, 8, [4, 3, 3, 2, 2], 2, 0.2),
	(9.0, 10, [5, 4, 3, 3, 2], 2, 0.1),
]


def parametros_flota(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Tablero, barcos y lo listo que es el rival (de disparar al azar a cazar en damero)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	for tope, lado, barcos, rival, fallo in _FLOTA_ESCALERA:
		if d < tope:
			return {"n": lado, "ships": list(barcos), "rival": rival, "mistake": fallo, "seed": semilla % 99991 + i}
	return {"n": 10, "ships": [5, 4, 3, 3, 2], "rival": 2, "mistake": 0.1, "seed": semilla % 99991 + i}


## << genero flota


## >> genero simon (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_simon(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Simon dice (kit/simon): la secuencia sale de la semilla en el kit; el mapa la lleva."""
	return ["simon", "#%d" % ((semilla * 311 + i * 3343) % 1000003)]


def parametros_simon(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Botones (4 a 6), largo final de la secuencia (4 a 14), velocidad y fallos perdonados."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	return {"pads": 4 if d < 0.45 else (5 if d < 0.75 else 6), "goal": 4 + int(10 * d) + min(i, 2), "speed": round(0.75 - 0.35 * d, 2),
		"lives": 2 if d < 0.4 else (1 if d < 0.8 else 0), "seed": semilla % 99991 + i}


## << genero simon


## >> genero estrategia (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_estrategia(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Estrategia por turnos (kit/tactics): mapa en espejo (el rival arriba, tu abajo) con bosques,
	montanas, ciudades y, a veces, un rio con puentes. Los cuarteles en el centro de cada borde."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rnd = random.Random(semilla * 97 + i * 13)
	w = 8 + int(2 * d)
	h = 10 + int(3 * d)
	mitad = [["."] * w for _ in range((h + 1) // 2)]
	for y in range(len(mitad)):
		for x in range(w):
			v = rnd.random()
			mitad[y][x] = "f" if v < 0.14 else ("m" if v < 0.2 else ".")
	## Ciudades: 1 a 3 por bando, lejos del cuartel.
	for _ in range(1 + int(2 * d) + (1 if i >= 2 else 0)):
		mitad[rnd.randrange(2, len(mitad))][rnd.randrange(w)] = "c"
	filas = [r[:] for r in mitad] + [r[:] for r in reversed(mitad[: h // 2])]
	## Rio por el medio con puentes (desde el tercer nivel, a veces).
	if i >= 2 and rnd.random() < 0.5 and h % 2 == 0:
		medio = h // 2
		for x in range(w):
			filas[medio - 1][x] = "~" if x not in (1, w // 2, w - 2) else "."
			filas[medio][x] = filas[medio - 1][x]
	cx = w // 2
	filas[0][cx] = "h"
	filas[h - 1][cx] = "H"
	## Ejercitos: el mismo para los dos; el tuyo con refuerzos al principio.
	ej = [("inf", -1, 0), ("inf", 1, 0), ("tank", 0, 1)]
	if d > 0.3:
		ej.append(("art", -2, 0))
	if d > 0.55:
		ej.append(("inf", 2, 1))
	if d > 0.8:
		ej.append(("tank", -1, 1))
	extra = 2 if d < 0.3 else (1 if d < 0.65 else 0)
	refuerzos = [("tank", 2, 0), ("art", 0, 2), ("inf", -2, 1)][:extra]
	unidades = []
	for lado, lista in ((2, ej), (1, ej + refuerzos)):
		for t, dx, dy in lista:
			x = max(0, min(w - 1, cx + dx))
			y = dy if lado == 2 else h - 1 - dy
			if filas[y][x] in "~hH" or any(u["x"] == x and u["y"] == y for u in unidades):
				y = y + 1 if lado == 2 else y - 1
			if filas[y][x] == "m" and t != "inf":
				filas[y][x] = "."
			if filas[y][x] == "~":
				filas[y][x] = "."
			unidades.append({"t": t, "x": x, "y": y, "side": lado})
	import json
	return ["".join(r) for r in filas] + ["U" + json.dumps(unidades, separators=(",", ":")), "#%d" % (semilla % 99991 + i)]


def parametros_estrategia(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Separa el mapa de las unidades y pone lo listo que es el rival, sus fallos y los turnos."""
	import json
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	filas = [r for r in (mapa or []) if r and r[0] not in "U#"]
	unidades = next((json.loads(r[1:]) for r in (mapa or []) if r.startswith("U")), [])
	semilla = next((int(r[1:]) for r in (mapa or []) if r.startswith("#") and r[1:].isdigit()), 1)
	return {"tiles": filas, "units": unidades, "ai": round(0.2 + 0.7 * d, 2), "mistake": round(max(0.05, 0.35 - 0.35 * d), 2),
		"turns": 26 + int(10 * d), "seed": semilla}


## << genero estrategia


## >> genero autobatalla (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_autobatalla(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Batalla automatica (kit/autochess): las rondas van en los parametros; el mapa, la semilla."""
	return ["autobatalla", "#%d" % ((semilla * 317 + i * 3347) % 1000003)]


_AUTO_TIPOS = ["warrior", "archer", "knight", "mage", "assassin", "healer"]
_AUTO_LEJOS = {"archer", "mage", "healer"}


def _ejercito_auto(rnd: random.Random, poder: int, ronda: int) -> list:
	"""Ejercito rival de una ronda: unidades de 1 y 2 estrellas hasta sumar 'poder' (una de 2 vale 3)."""
	out, usadas = [], set()
	p = poder
	while p > 0:
		t = _AUTO_TIPOS[rnd.randrange(0, min(6, 2 + ronda))]
		s = 2 if p >= 6 and rnd.random() < 0.4 else 1
		filas = (0, 1) if t in _AUTO_LEJOS else (2, 3)
		libres = [(x, y) for y in filas for x in range(6) if (x, y) not in usadas]
		if not libres:
			libres = [(x, y) for y in range(4) for x in range(6) if (x, y) not in usadas]
		if not libres:
			break
		x, y = rnd.choice(libres)
		usadas.add((x, y))
		out.append({"t": t, "s": s, "x": x, "y": y})
		p -= 3 if s == 2 else 1
	return out


def parametros_autobatalla(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Rondas (4 a 8) con ejercitos que crecen: el ultimo de fuerza 5 (facil) a 12 (dificil)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 61 + i)
	rondas = 4 + min(4, i // 2 + int(2 * d))
	final = 5 + int(7 * d)
	ejercitos = []
	for r in range(rondas):
		poder = max(1, round(1 + (final - 1) * (r / max(1, rondas - 1)) ** 1.2))
		ejercitos.append(_ejercito_auto(rnd, poder, r))
	return {"rounds": ejercitos, "lives": 3, "gold": 6, "slots": 3, "seed": semilla % 99991 + i}


## << genero autobatalla


## >> genero gemas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_gemas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Gemas y heroes (kit/gemrpg): las oleadas van en los parametros; el mapa, la semilla."""
	return ["gemas", "#%d" % ((semilla * 331 + i * 3359) % 1000003)]


_GEMAS_EQUIPO = [{"c": 0, "atk": 12, "skill": "blast"}, {"c": 1, "atk": 10, "skill": "heal"}, {"c": 2, "atk": 11, "skill": "stun"},
	{"c": 3, "atk": 10, "skill": "blast"}, {"c": 4, "atk": 11, "skill": "blast"}]


def parametros_gemas(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Equipo de 3 a 5 heroes y de 2 a 5 oleadas de 1 a 3 monstruos de colores, cada vez mas duros."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 67 + i)
	equipo = [dict(h) for h in _GEMAS_EQUIPO[: 3 + min(2, i // 3)]]
	oleadas = []
	for w in range(2 + min(3, i // 2 + int(d * 1.5))):
		cuantos = 1 if w == 0 else min(3, 1 + rnd.randrange(1, 3))
		vida = int((60 + 220 * d) * (1.0 + 0.35 * w) / (1.0 + 0.4 * (cuantos - 1)))
		oleadas.append([{"c": rnd.randrange(5), "hp": vida, "atk": int(8 + 22 * d), "every": rnd.choice((2, 3, 3))} for _ in range(cuantos)])
	return {"team": equipo, "hp": 260 + 20 * len(equipo), "waves": oleadas, "moves": 0, "seed": semilla % 99991 + i}


## << genero gemas


## >> genero coleccionables (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_coleccionables(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Cartas coleccionables (kit/ccg): los mazos van en los parametros; el mapa, la semilla."""
	return ["coleccionables", "#%d" % ((semilla * 337 + i * 3361) % 1000003)]


## Mazo base (20 cartas con curva de mana) y cartas que mejoran el del rival segun avanza.
_CCG_BASE = ["recluta", "recluta", "lobo", "escudero", "arquera", "arquera", "guardia", "jinete", "paladin", "ogro",
	"chispa", "chispa", "bola_fuego", "pocion", "estudio", "bendicion", "muro", "tormenta", "jinete", "ogro"]
_CCG_FUERTES = ["dragon", "ogro", "paladin", "bola_fuego", "muro", "tormenta"]


def parametros_coleccionables(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""Tu mazo (el base, con un dragon desde la mitad) y el del rival: mas cartas fuertes, mas vida y mas listo."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = int(str(mapa[-1]).lstrip("#") or 1) if mapa and str(mapa[-1]).startswith("#") else 1
	rnd = random.Random(semilla * 71 + i)
	mio = list(_CCG_BASE)
	if i >= n // 2:
		mio[0] = "dragon"
	rival = list(_CCG_BASE)
	for _ in range(int(4 * d)):
		rival[rnd.randrange(len(rival))] = rnd.choice(_CCG_FUERTES)
	return {"deck": mio, "foe_deck": rival, "hp": 30, "foe_hp": 15 + int(10 * d), "ai": round(0.2 + 0.6 * d, 2), "seed": semilla % 99991 + i,
		"first": "player"}


## << genero coleccionables


## >> genero roguelike (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_roguelike(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Roguelike por turnos (kit/crawl): salas al azar unidas por pasillos; la salida en la primera,
	la escalera en la ultima (con jefe en los niveles de jefe); monstruos y objetos segun la dificultad."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rnd = random.Random(semilla * 101 + i * 17)
	w, h = 18 + int(4 * d), 24 + int(8 * d)
	g = [["#"] * w for _ in range(h)]
	salas = []
	for _ in range(200):
		if len(salas) >= 5 + int(3 * d):
			break
		rw, rh = rnd.randint(4, 7), rnd.randint(4, 6)
		rx, ry = rnd.randint(1, w - rw - 1), rnd.randint(1, h - rh - 1)
		if any(rx - 1 < sx + sw and sx - 1 < rx + rw and ry - 1 < sy + sh and sy - 1 < ry + rh for sx, sy, sw, sh in salas):
			continue
		salas.append((rx, ry, rw, rh))
	salas.sort(key=lambda s: (s[1], s[0]))
	for rx, ry, rw, rh in salas:
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				g[y][x] = "."
	centros = [(rx + rw // 2, ry + rh // 2) for rx, ry, rw, rh in salas]
	for (ax, ay), (bx, by) in zip(centros, centros[1:]):
		x, y = ax, ay
		while x != bx:
			g[y][x] = "."
			x += 1 if bx > x else -1
		while y != by:
			g[y][x] = "."
			y += 1 if by > y else -1
	sx, sy = centros[0]
	g[sy][sx] = "P"
	ex, ey = centros[-1]
	g[ey][ex] = ">"
	jefe = i == n - 1 or (i > 0 and i % 4 == 3)
	libres = lambda sala: [(x, y) for y in range(sala[1], sala[1] + sala[3]) for x in range(sala[0], sala[0] + sala[2]) if g[y][x] == "."]
	tipos = ["r", "r", "g"] + (["g", "s"] if d > 0.3 else []) + (["o"] if d > 0.55 else [])
	for k2, sala in enumerate(salas[1:], start=1):
		huecos = libres(sala)
		rnd.shuffle(huecos)
		for _ in range(min(len(huecos), (1 if rnd.random() < 0.7 else 0) + int(1.5 * d) + (1 if k2 > len(salas) // 2 and d > 0.4 else 0))):
			x, y = huecos.pop()
			g[y][x] = rnd.choice(tipos)
		if huecos and rnd.random() < 0.75:
			x, y = huecos.pop()
			g[y][x] = rnd.choice(["!", "!", "$", "/", "]"])
	if jefe:
		cerca = [(ex + dx, ey + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g[ey + dy][ex + dx] == "."]
		if cerca:
			x, y = cerca[0]
			g[y][x] = "B"
	return ["".join(r) for r in g] + ["#%d" % (semilla % 99991 + i)]


def parametros_roguelike(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	"""El heroe empieza mas fuerte en los niveles altos (como si viniera de los anteriores)."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	p = {"hp": 20 + int(10 * d), "atk": 3 + int(2 * d), "def": int(d > 0.6), "sight": 5, "potions": 1 + int(d > 0.5)}
	## Nivel con jefe a mitad de juego (i % 4 == 3): con las fuerzas de un nivel normal el jefe era
	## imposible y la fabrica fallaba tras 8 rondas («Huesitos y Zombis», 12 nov). Se llega mas fuerte.
	if mapa and any("B" in fila for fila in mapa):
		p["hp"] += 8
		p["atk"] += 1
		p["potions"] += 1
	return p


## << genero roguelike


## >> genero bombas (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_bombas(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Bombas (kit/bomber): laberinto clasico de bloques fijos en rejilla y cajas al azar; el heroe
	arriba a la izquierda con hueco para huir de su primera bomba; monstruos lejos; la salida y los
	premios escondidos bajo cajas."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rnd = random.Random(semilla * 131 + i * 29)
	w, h = 11, 13 + 2 * int(d > 0.5)
	g = [["#" if x in (0, w - 1) or y in (0, h - 1) or (x % 2 == 0 and y % 2 == 0) else "." for x in range(w)] for y in range(h)]
	libre_inicio = {(1, 1), (2, 1), (1, 2), (3, 1), (1, 3)}
	densidad = 0.38 + 0.2 * d
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if g[y][x] == "." and (x, y) not in libre_inicio and rnd.random() < densidad:
				g[y][x] = "+"
	g[1][1] = "P"
	cajas = [(x, y) for y in range(h) for x in range(w) if g[y][x] == "+"]
	rnd.shuffle(cajas)
	lejos = [c for c in cajas if c[0] + c[1] >= (w + h) // 2]
	ex, ey = (lejos or cajas)[0]
	g[ey][ex] = "X"
	premios = ["B", "R"] + (["S"] if d > 0.4 else []) + (["B"] if d > 0.7 else [])
	for (x, y), pr in zip([c for c in cajas if g[c[1]][c[0]] == "+"][:len(premios)], premios):
		g[y][x] = pr
	huecos = [(x, y) for y in range(h) for x in range(w) if g[y][x] == "." and x + y >= 7]
	rnd.shuffle(huecos)
	tipos = ["e"] + (["c"] if d > 0.3 else []) + (["f"] if d > 0.6 else [])
	for _ in range(min(len(huecos), 2 + int(4 * d))):
		x, y = huecos.pop()
		g[y][x] = rnd.choice(tipos)
	return ["".join(r) for r in g] + ["#%d" % (semilla % 99991 + i)]


def parametros_bombas(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	malos = sum(f.count(c) for f in (mapa or []) if not f[1:].isdigit() for c in "ecf")
	return {"bombs": 1, "range": 2, "par": 50 + 15 * malos, "seed": semilla_de(mapa)}


def semilla_de(mapa: list[str] | None) -> int:
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			return int(f[1:])
	return 7


## << genero bombas


## >> genero artilleria (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_artilleria(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Artilleria (kit/artillery): el terreno y los soldados van en los parametros (alturas por
	columna); el mapa solo lleva la semilla."""
	return ["artilleria", "#%d" % ((semilla * 211 + i * 4099) % 1000003)]


def _terreno_artilleria(rnd: random.Random, d: float) -> list[int]:
	"""Isla de colinas: suma de ondas al azar, bordes que caen al agua y un valle o dos."""
	ancho = 120
	fases = [(rnd.uniform(0, 6.28), rnd.uniform(0.006, 0.02), rnd.uniform(9, 17)) for _ in range(2)] + [(rnd.uniform(0, 6.28), rnd.uniform(0.03, 0.045), rnd.uniform(2, 5))]
	alt = []
	for x in range(ancho):
		h = 52 + sum(a * math.sin(f + x * w * 6.28) for f, w, a in fases)
		borde = min(x, ancho - 1 - x)
		if borde < 6:
			h -= (6 - borde) * 8
		alt.append(int(max(0, min(130, h))))
	## Un monte en medio en los niveles altos (hay que tirar por encima).
	if d > 0.45:
		c, r, sube = rnd.randint(52, 68), rnd.randint(8, 13), int(18 + 22 * d)
		for x in range(c - r, c + r):
			alt[x] = min(140, alt[x] + int(sube * (1 - ((x - c) / r) ** 2)))
	return alt


def _sitios_artilleria(rnd: random.Random, alt: list[int], desde: int, hasta: int, cuantos: int) -> list[int]:
	buenos = [x for x in range(desde, hasta) if alt[x] > 16]
	rnd.shuffle(buenos)
	out = []
	for x in buenos:
		if all(abs(x - o) >= 6 for o in out):
			out.append(x)
		if len(out) == cuantos:
			break
	return sorted(out)


def parametros_artilleria(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 7
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			semilla = int(f[1:])
	rnd = random.Random(semilla)
	alt = _terreno_artilleria(rnd, d)
	mios = 2 + int(d > 0.5)
	suyos = 2 + int(d > 0.3) + int(d > 0.75)
	return {"ground": alt, "team": _sitios_artilleria(rnd, alt, 9, 48, mios), "foes": _sitios_artilleria(rnd, alt, 72, 111, suyos),
		"hp": 100, "foe_hp": 60 + int(40 * d), "wind": round(4 + 10 * d, 1), "ai": round(0.2 + 0.45 * d, 2), "guide": round(0.6 - 0.35 * d, 2), "seed": semilla}


## << genero artilleria


## >> genero comecocos (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_comecocos(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Comecocos (kit/chomp): laberinto simetrico sin callejones (cada pasillo da la vuelta), casa
	de los fantasmas en el centro, pildoras en las esquinas y a veces un tunel de lado a lado."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rnd = random.Random(semilla * 173 + i * 31)
	w, h = 15, 19
	g = [["#"] * w for _ in range(h)]
	celdas = [(x, y) for y in range(1, h, 2) for x in range(1, 8, 2)]
	espejo = lambda x: w - 1 - x

	def abrir(x, y):
		g[y][x] = "."
		g[y][espejo(x)] = "."

	for x, y in celdas:
		abrir(x, y)
	## Laberinto perfecto en la mitad izquierda (con la columna del centro).
	visto = {celdas[0]}
	pila = [celdas[0]]
	while pila:
		x, y = pila[-1]
		vecinos = [(x + dx, y + dy) for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)) if (x + dx, y + dy) in set(celdas) and (x + dx, y + dy) not in visto]
		if not vecinos:
			pila.pop()
			continue
		nx, ny = rnd.choice(vecinos)
		abrir((x + nx) // 2, (y + ny) // 2)
		visto.add((nx, ny))
		pila.append((nx, ny))

	def salidas(x, y):
		return [(dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < w and 0 <= y + dy < h and g[y + dy][x + dx] != "#"]

	## Sin callejones: cada celda con una sola salida abre otra.
	for x, y in celdas:
		if len(salidas(x, y)) <= 1:
			cand = [(dx, dy) for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)) if 1 <= x + dx <= w - 2 and 1 <= y + dy <= h - 2 and g[y + dy // 2][x + dx // 2] == "#"]
			rnd.shuffle(cand)
			if cand:
				dx, dy = cand[0]
				abrir(x + dx // 2, y + dy // 2)
	## Algun atajo mas.
	for x, y in celdas:
		if rnd.random() < 0.12 + 0.08 * d:
			dx, dy = rnd.choice(((2, 0), (0, 2)))
			if x + dx <= 7 and y + dy <= h - 2:
				abrir(x + dx // 2, y + dy // 2)
	## Casa de los fantasmas en el centro.
	cy = 9
	for x in range(5, 10):
		g[cy][x] = "."
	fantasmas = 2 + int(d > 0.25) + int(d > 0.6)
	for x in [7, 6, 8, 5][:fantasmas]:
		g[cy][x] = "G"
	## Tunel de lado a lado.
	if d > 0.3 and g[cy][1] != "#":
		g[cy][0] = g[cy][w - 1] = " "
	## Pildoras y salida.
	for x, y in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
		g[y][x] = "o"
	g[15][7] = "P"
	return ["".join(r) for r in g] + ["#%d" % (semilla % 99991 + i)]


def parametros_comecocos(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 7
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			semilla = int(f[1:])
	return {"speed": 0.5, "ghost_speed": round(0.34 + 0.12 * d, 3), "fright": int(70 - 35 * d), "lives": 3, "seed": semilla}


## << genero comecocos


## >> genero cadena (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_cadena(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Cadena de bolas (kit/chain): el camino, el lanzador y las bolas van en los parametros; el mapa
	solo lleva la semilla."""
	return ["cadena", "#%d" % ((semilla * 389 + i * 5521) % 1000003)]


def _camino_cadena(rnd: random.Random, forma: int) -> tuple[list[float], list[int]]:
	"""Espiral alrededor del lanzador (en el centro) o zigzag por arriba (lanzador abajo)."""
	pts = []
	if forma == 0:
		cx, cy = 300, 470
		vueltas = rnd.uniform(1.25, 1.6)
		a0 = rnd.uniform(0, 6.28)
		giro = rnd.choice((1, -1))
		pasos = 160
		for k in range(pasos + 1):
			t = k / pasos
			a = a0 + giro * t * vueltas * 6.28
			rx, ry = 270 - 140 * t, 400 - 210 * t
			pts += [round(cx + rx * math.cos(a), 1), round(cy + ry * math.sin(a), 1)]
		return pts, [cx, cy]
	filas = 3 + (forma == 2)
	alto = 620 / filas
	for f in range(filas):
		y = 70 + f * alto
		xs = (40, 560) if f % 2 == 0 else (560, 40)
		for k in range(21):
			x = xs[0] + (xs[1] - xs[0]) * k / 20
			pts += [round(x, 1), round(y + 14 * math.sin(k / 20 * 6.28 * rnd.choice((1, 2))), 1)]
		if f < filas - 1:
			xe = xs[1]
			for k in range(1, 9):
				a = k / 8 * 3.1416
				dx = math.sin(a) * alto * 0.5 * (1 if xe > 300 else -1)
				pts += [round(xe + dx * 0.2, 1), round(y + alto * k / 8, 1)]
	return pts, [300, 820]


def parametros_cadena(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 7
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			semilla = int(f[1:])
	rnd = random.Random(semilla)
	camino, lanzador = _camino_cadena(rnd, (i + semilla) % 3)
	colores = 3 + int(d > 0.35) + int(d > 0.75)
	bolas = []
	for _ in range(30 + int(36 * d)):
		c = rnd.randrange(colores)
		if len(bolas) >= 2 and bolas[-1] == bolas[-2] == c:
			c = (c + 1) % colores
		## A veces dos iguales seguidas (da jugadas).
		if bolas and rnd.random() < 0.3:
			c = bolas[-1] if not (len(bolas) >= 2 and bolas[-1] == bolas[-2]) else c
		bolas.append(c)
	return {"path": camino, "shooter": lanzador, "balls": bolas, "colors": colores, "speed": round(0.7 + 0.6 * d, 2), "seed": semilla}


## << genero cadena


## >> genero lucha (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_lucha(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Lucha 1 contra 1 (kit/fighter): cada nivel es un combate a dos asaltos ganados contra un rival
	con su estilo; el mapa solo lleva la semilla."""
	return ["lucha", "#%d" % ((semilla * 433 + i * 6007) % 1000003)]


def parametros_lucha(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 7
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			semilla = int(f[1:])
	estilos = ["rusher", "zoner", "counter"]
	return {"hp": 100, "foe_hp": 70 + int(50 * d), "ai": round(0.15 + 0.6 * d, 2), "round_time": 60,
		"foe_style": estilos[(i + semilla) % 3], "seed": semilla}


## << genero lucha


## >> genero sandia (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_sandia(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Fusion de frutas (kit/fruitmerge): el tarro y la fruta objetivo van en los parametros; el mapa
	solo lleva la semilla."""
	return ["sandia", "#%d" % ((semilla * 457 + i * 7019) % 1000003)]


def parametros_sandia(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 7
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			semilla = int(f[1:])
	return {"goal": 5 + int(round(3.6 * d)), "drop_max": 4 + int(d > 0.5), "width": 360 - int(40 * d), "seed": semilla}


## << genero sandia


## >> genero pinball (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_pinball(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Pinball (kit/pinball): la mesa (setas y dianas) va en los parametros; el mapa solo lleva la semilla."""
	return ["pinball", "#%d" % ((semilla * 521 + i * 8081) % 1000003)]


def parametros_pinball(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	semilla = 7
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			semilla = int(f[1:])
	rnd = random.Random(semilla)
	setas = []
	for _ in range(200):
		if len(setas) >= 3 + int(d > 0.4):
			break
		x, y = rnd.randint(110, 370), rnd.randint(150, 400)
		if all((x - a) ** 2 + (y - b) ** 2 > 85 ** 2 for a, b in setas):
			setas.append([x, y])
	fila_y = rnd.choice((440, 460))
	dianas = [[200 + 40 * k, fila_y] for k in range(3)] if rnd.random() < 0.5 else [[90, 300 + 40 * k] for k in range(3)]
	return {"bumpers": setas, "targets": dianas, "goal": 4000 + int(8000 * d), "balls": 3, "gravity": round(560 + 160 * d), "seed": semilla}


## << genero pinball


## >> genero metroidvania (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
def generar_metroidvania(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Metroidvania (kit/metroid): salas de 13 x 9 unidas en arbol; en el camino a la meta hay puertas
	que piden habilidades (muro alto: doble salto; foso de pinchos con techo bajo: impulso; bloques:
	martillo; puerta: llave) y cada habilidad esta antes de su puerta, a ser posible en una rama
	lateral (hay que desviarse y volver). Las salas de arriba y abajo se unen con escaleras de
	plataformas que se suben con el salto normal."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	rnd = random.Random(semilla * 613 + i * 9173)
	RW, RH = (3, 3) if d < 0.35 else ((4, 3) if d < 0.75 else (5, 3))
	W, H = RW * 14 + 1, RH * 10 + 1
	g = [["#"] * W for _ in range(H)]
	for ry in range(RH):
		for rx in range(RW):
			for y in range(ry * 10 + 1, ry * 10 + 10):
				for x in range(rx * 14 + 1, rx * 14 + 14):
					g[y][x] = "."
	inicio = (0, RH - 1)
	## Arbol de salas (DFS al azar).
	visto, pila, aristas = {inicio}, [inicio], []
	while pila:
		a = pila[-1]
		vec = [(a[0] + dx, a[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= a[0] + dx < RW and 0 <= a[1] + dy < RH and (a[0] + dx, a[1] + dy) not in visto]
		if not vec:
			pila.pop()
			continue
		b = rnd.choice(vec)
		visto.add(b)
		aristas.append((a, b))
		pila.append(b)
	vecinos = {}
	for a, b in aristas:
		vecinos.setdefault(a, []).append(b)
		vecinos.setdefault(b, []).append(a)
	## Sala de la meta: la mas lejana; camino desde el inicio.
	padre, cola = {inicio: None}, [inicio]
	while cola:
		a = cola.pop(0)
		for b in vecinos.get(a, []):
			if b not in padre:
				padre[b] = a
				cola.append(b)
	meta = max(padre, key=lambda r: (len(_camino_sala(padre, r)), r[0]))
	camino = _camino_sala(padre, meta)
	en_camino = set(camino)
	pasos = list(zip(camino, camino[1:]))
	## Puertas: en aristas horizontales del camino.
	horiz = [e for e in pasos if e[0][1] == e[1][1]]
	cuantas = min(len(horiz), 2 + int(d > 0.3) + int(d > 0.7))
	elegidas = sorted(rnd.sample(range(len(horiz)), cuantas)) if horiz else []
	tipos = ["J", "D", "B", "K"]
	rnd.shuffle(tipos)
	puertas = {}
	for k2, idx in enumerate(elegidas):
		e = horiz[idx]
		puertas[frozenset(e)] = tipos[k2 % 4]
	escaleras = {}
	salta_j = set()
	for a, b in aristas:
		if a[1] == b[1]:
			izq, der = (a, b) if a[0] < b[0] else (b, a)
			wx = der[0] * 14
			y0 = izq[1] * 10
			t = puertas.get(frozenset((a, b)), "")
			if t == "J":
				g[y0 + 1][wx] = "."
				salta_j.update({izq, der})
			elif t == "D":
				for y in range(y0 + 7, y0 + 10):
					g[y][wx] = "."
				for x in range(wx - 4, wx + 5):
					g[y0 + 6][x] = "#"
				for x in range(wx - 3, wx + 4):
					g[y0 + 9][x] = "^"
				g[y0 + 9][wx] = "^"
			elif t == "B":
				for y in range(y0 + 7, y0 + 10):
					g[y][wx] = "%"
			elif t == "K":
				g[y0 + 9][wx] = "L"
			else:
				for y in range(y0 + 7, y0 + 10):
					g[y][wx] = "."
		else:
			arriba, abajo = (a, b) if a[1] < b[1] else (b, a)
			base = abajo[1] * 10
			cx = abajo[0] * 14 + rnd.randint(4, 8)
			for x in range(cx, cx + 3):
				g[base][x] = "."
			lado = rnd.choice((1, -1))
			p1 = range(cx + 3, cx + 6) if lado == 1 else range(cx - 3, cx)
			p2 = range(cx - 3, cx) if lado == 1 else range(cx + 3, cx + 6)
			for x in p1:
				g[base + 6][x] = "#"
			for x in p2:
				g[base + 3][x] = "#"
			escaleras[abajo] = (cx - 3, cx + 6)
			escaleras[arriba] = escaleras.get(arriba, (cx - 1, cx + 4))
	## Regiones: lo que se alcanza abriendo las puertas en orden; cada habilidad va antes de su puerta.
	orden = [frozenset(horiz[idx]) for idx in elegidas]
	abiertas = set()
	usadas = set()
	objetos = {}
	for k3, pu in enumerate(orden):
		region = _region(inicio, vecinos, puertas, abiertas)
		cand = [r for r in region if r not in en_camino and r not in usadas] or [r for r in region if r not in usadas and r != inicio] or list(region)
		cand.sort(key=lambda r: -len(_camino_sala(padre, r)))
		sala = cand[0] if rnd.random() < 0.7 else rnd.choice(cand)
		usadas.add(sala)
		objetos.setdefault(sala, []).append(puertas[pu])
		abiertas.add(pu)
	## Decorado: plataformas con monedas, pinchos pequenos, enemigos y corazones.
	for ry in range(RH):
		for rx in range(RW):
			x0, y0 = rx * 14, ry * 10
			lib = escaleras.get((rx, ry))
			cols = [x for x in range(x0 + 5, x0 + 10) if not lib or not (lib[0] <= x <= lib[1])]
			if (rx, ry) not in escaleras and (rx, ry) not in salta_j and rnd.random() < 0.7:
				px = rnd.randint(x0 + 5, x0 + 7)
				for x in range(px, px + 3):
					g[y0 + 6][x] = "#"
				g[y0 + 5][px + 1] = "$"
			for x in cols[:2]:
				if g[y0 + 9][x] == "." and rnd.random() < 0.5:
					g[y0 + 8][x] = "$"
			if (rx, ry) != inicio and cols and rnd.random() < 0.35 + 0.4 * d:
				ex = rnd.choice(cols)
				if g[y0 + 9][ex] == ".":
					g[y0 + 9][ex] = "E"
			if (rx, ry) != inicio and rnd.random() < 0.25 + 0.3 * d and len(cols) >= 3:
				sx = cols[len(cols) // 2]
				if g[y0 + 9][sx] == "." and g[y0 + 9][sx - 1] in ".$" and g[y0 + 9][sx + 1] in ".$":
					g[y0 + 9][sx] = "^"
	g[(RH - 1) * 10 + 9][2] = "P"
	for sala, cosas in objetos.items():
		x0, y0 = sala[0] * 14, sala[1] * 10
		sitios = [x for x in range(x0 + 2, x0 + 13) if g[y0 + 9][x] in ".$" and g[y0 + 10][x] == "#" and g[y0 + 9][x - 1] != "^" and g[y0 + 9][x + 1] != "^"]
		for k4, c in enumerate(cosas):
			if sitios:
				x = sitios[0] if k4 % 2 == 0 else sitios[-1]
				sitios.remove(x)
				g[y0 + 9][x] = c
	if rnd.random() < 0.6:
		hx, hy = rnd.choice([r for r in padre if r != inicio])
		if g[hy * 10 + 9][hx * 14 + 12] == ".":
			g[hy * 10 + 9][hx * 14 + 12] = "+"
	g[(RH - 1) * 10 + 9][2] = "P"
	g[meta[1] * 10 + 9][meta[0] * 14 + 7] = "G"
	return ["".join(r) for r in g] + ["#%d" % (semilla % 99991 + i)]


def _camino_sala(padre: dict, r) -> list:
	out = []
	while r is not None:
		out.append(r)
		r = padre[r]
	return out[::-1]


def _region(inicio, vecinos: dict, puertas: dict, abiertas: set) -> set:
	vista, cola = {inicio}, [inicio]
	while cola:
		a = cola.pop()
		for b in vecinos.get(a, []):
			e = frozenset((a, b))
			if b not in vista and (e not in puertas or e in abiertas):
				vista.add(b)
				cola.append(b)
	return vista


def parametros_metroidvania(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	return {"hp": 5 - int(2 * d)}


## << genero metroidvania


## >> genero sigilo (creado por nuevo_genero.py: cambia el generador junto con las reglas del juego)
_SIG_DIRS = {"N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0)}
_SIG_CW = {"N": "E", "E": "S", "S": "W", "W": "N"}


def _sigilo_mover(nodos, aristas, estado, q):
	"""Copia en Python de las reglas de kit/stealth (para que el generador solo de tableros con solucion)."""
	p, item, guardias = estado
	if (p, q) not in aristas:
		return None
	guardias = [list(g) for g in guardias]
	for g in guardias:
		if g[3] and g[0] == q:
			g[3] = False
	item = item or q == nodos["C"]
	if q == nodos["X"]:
		return ("gana", item)
	def mira(g):
		n = (g[0][0] + _SIG_DIRS[g[1]][0], g[0][1] + _SIG_DIRS[g[1]][1])
		return n if (g[0], n) in aristas else None
	for g in guardias:
		if g[3] and mira(g) == q:
			return None
	for g in guardias:
		if not g[3]:
			continue
		if g[2] == "patrol":
			n = mira(g)
			if n is None:
				g[1] = _SIG_CW[_SIG_CW[g[1]]]
			else:
				g[0] = n
				if mira(g) is None:
					g[1] = _SIG_CW[_SIG_CW[g[1]]]
		elif g[2] == "rotate":
			for _ in range(4):
				g[1] = _SIG_CW[g[1]]
				if mira(g) is not None:
					break
		if g[0] == q:
			return None
	return (q, item, tuple(tuple(g) for g in guardias))


def _sigilo_resolver(nodos, aristas, inicio, con_item=False, limite=20000, camino=False):
	vistos = {inicio}
	cola = [(inicio, [])]
	i = 0
	while i < len(cola) and i < limite:
		est, ruta = cola[i]
		i += 1
		p = est[0]
		for dx, dy in _SIG_DIRS.values():
			q = (p[0] + dx, p[1] + dy)
			n = _sigilo_mover(nodos, aristas, est, q)
			if n is None:
				continue
			if n[0] == "gana":
				if not con_item or n[1]:
					return ruta + [q] if camino else len(ruta) + 1
				continue
			if n not in vistos:
				vistos.add(n)
				cola.append((n, ruta + [q]))
	return [] if camino else -1


def generar_sigilo(i: int, n: int, enemigos: list[str], dificultad: str, semilla: int, ajuste: float = 0.0,
		opciones: dict | None = None) -> list[str]:
	"""Sigilo por turnos (kit/stealth): tablero de puntos y caminos (arbol con algunos ciclos), salida
	arriba, heroe abajo, guardias que vigilan los pasos y un maletin. Solo vale si se puede resolver,
	si los guardias obligan a pensar y si cuesta unos cuantos movimientos."""
	base, k = CURVA.get(dificultad, CURVA["normal"])
	d = max(0.0, min(1.0, base + k * (i / max(1, n - 1)) + ajuste))
	for intento in range(80):
		rnd = random.Random(semilla * 977 + i * 131 + intento * 7919)
		W, H = 4 + int(d > 0.5), 6 + int(d > 0.3)
		celdas = [(x, y) for y in range(H) for x in range(W)]
		usadas = {(rnd.randrange(W), H - 1)}
		pila = [next(iter(usadas))]
		aristas = set()
		while pila:
			a = pila[-1]
			vec = [(a[0] + dx, a[1] + dy) for dx, dy in _SIG_DIRS.values() if 0 <= a[0] + dx < W and 0 <= a[1] + dy < H and (a[0] + dx, a[1] + dy) not in usadas]
			if not vec or (len(usadas) > W * H * 0.75 and rnd.random() < 0.3):
				pila.pop()
				continue
			b = rnd.choice(vec)
			usadas.add(b)
			aristas |= {(a, b), (b, a)}
			pila.append(b)
		for a in list(usadas):
			for dx, dy in ((1, 0), (0, 1)):
				b = (a[0] + dx, a[1] + dy)
				if b in usadas and rnd.random() < 0.25 + 0.15 * d:
					aristas |= {(a, b), (b, a)}
		abajo = [c for c in usadas if c[1] == max(y for _, y in usadas)]
		arriba = [c for c in usadas if c[1] == min(y for _, y in usadas)]
		inicio, salida = rnd.choice(abajo), rnd.choice(arriba)
		libres = [c for c in usadas if c not in (inicio, salida) and abs(c[0] - inicio[0]) + abs(c[1] - inicio[1]) > 1]
		rnd.shuffle(libres)
		cuantos = min(len(libres) - 1, 2 + int(3 * d))
		guardias = []
		for c in libres[:cuantos]:
			tipo = rnd.choices(["stand", "patrol", "rotate"], [4, 2 + 2 * d, 1 + 2 * d])[0]
			dirs = [k2 for k2, (dx, dy) in _SIG_DIRS.items() if (c, (c[0] + dx, c[1] + dy)) in aristas]
			if not dirs:
				continue
			guardias.append((c, rnd.choice(dirs) if tipo != "rotate" else "N", tipo, True))
		item = libres[cuantos] if len(libres) > cuantos else (-9, -9)
		nodos = {"X": salida, "C": item}
		est = (inicio, False, tuple(guardias))
		## Nadie puede empezar mirando la salida del heroe.
		mejor = _sigilo_resolver(nodos, aristas, est)
		if mejor < 4 + int(3 * d):
			continue
		## Los guardias tienen que importar: el camino corto sin mirarlos tiene que salir mal.
		ruta = _sigilo_resolver(nodos, aristas, (inicio, False, tuple((g[0], g[1], g[2], False) for g in guardias)), camino=True)
		e2 = est
		for q in ruta:
			e2 = _sigilo_mover(nodos, aristas, e2, q) if e2 is not None and e2[0] != "gana" else e2
		if e2 is not None and e2[0] == "gana":
			continue
		g = [[" "] * (2 * W - 1) for _ in range(2 * H - 1)]
		for c in usadas:
			g[2 * c[1]][2 * c[0]] = "."
		for a, b in aristas:
			g[a[1] + b[1]][a[0] + b[0]] = "-" if a[1] == b[1] else "|"
		for c, dr, tipo, _v in guardias:
			g[2 * c[1]][2 * c[0]] = {"stand": dr, "patrol": dr.lower(), "rotate": "R"}[tipo]
		if item[0] >= 0:
			g[2 * item[1]][2 * item[0]] = "C"
		g[2 * inicio[1]][2 * inicio[0]] = "P"
		g[2 * salida[1]][2 * salida[0]] = "X"
		return ["".join(r) for r in g] + ["#%d" % mejor]
	return [".-P", "| |", "X-N"]


def parametros_sigilo(i: int, n: int, dificultad: str, ajuste: float = 0.0, mapa: list[str] | None = None) -> dict:
	mejor = 8
	for f in mapa or []:
		if f.startswith("#") and f[1:].isdigit():
			mejor = int(f[1:])
	return {"par": mejor + 2}


## << genero sigilo
