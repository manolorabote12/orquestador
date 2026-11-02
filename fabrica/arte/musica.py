"""Musica procedural de cada juego: menu y nivel en bucle perfecto, y un toque de victoria.

Es la musica "de serie" (gratis, al instante y sin GPU). Cuando el trabajador de musica con
ACE-Step este conectado, sustituira a estas pistas con los mismos nombres.

Sale de la Biblia: tempo, ambiente (alegre/oscuro/tranquilo...) y timbre del sonido (retro,
suave, metalico). Armonia con progresiones probadas, melodia con motivo que se repite y
varia (AABA), bajo y bateria. Mismo juego -> misma musica (semilla estable).
"""

import math
import wave
from pathlib import Path

import numpy as np

SR = 22050

ESCALAS = {"mayor": [0, 2, 4, 5, 7, 9, 11], "menor": [0, 2, 3, 5, 7, 8, 10]}
## Progresiones en grados de la escala (0 = tonica).
PROGRESIONES = {
	"mayor": [[0, 4, 5, 3], [0, 5, 3, 4], [0, 3, 0, 4]],
	"menor": [[0, 5, 2, 6], [0, 3, 4, 0], [0, 6, 5, 4]],
}
OSCURO = ("dark", "night", "mysterious", "spooky", "tense", "sad", "ominous", "noche", "oscuro", "misterio")
TRANQUILO = ("calm", "relax", "dreamy", "gentle", "soft", "peaceful", "whimsical", "tranquil")


def _hz(midi: float) -> float:
	return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def _onda(tipo: str, f: float, n: int, ancho: float = 0.5) -> np.ndarray:
	t = np.arange(n) / SR
	fase = (f * t) % 1.0
	if tipo == "cuadrada":
		return np.where(fase < ancho, 1.0, -1.0)
	if tipo == "triangulo":
		return 4.0 * np.abs(fase - 0.5) - 1.0
	if tipo == "sierra":
		return 2.0 * fase - 1.0
	return np.sin(2.0 * math.pi * f * t)


def _env(n: int, ataque: float, caida: float) -> np.ndarray:
	e = np.ones(n)
	a = max(1, int(ataque * SR))
	e[:a] = np.linspace(0.0, 1.0, a)
	cola = np.exp(-np.arange(n) / max(1.0, caida * SR))
	return e * cola


def _nota(tipo: str, midi: float, dur: float, vol: float, ancho: float = 0.5, caida: float = 0.25) -> np.ndarray:
	n = int(dur * SR)
	return _onda(tipo, _hz(midi), n, ancho) * _env(n, 0.004, caida) * vol


def _ruido(dur: float, vol: float, caida: float, rng: np.random.Generator, grave: bool = False) -> np.ndarray:
	n = int(dur * SR)
	r = rng.uniform(-1.0, 1.0, n)
	if grave:
		r = np.convolve(r, np.ones(8) / 8.0, mode="same")
	return r * _env(n, 0.001, caida) * vol


def _bombo(dur: float, vol: float) -> np.ndarray:
	n = int(dur * SR)
	t = np.arange(n) / SR
	f = 120.0 * np.exp(-t * 18.0) + 45.0
	return np.sin(2.0 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 9.0) * vol


def _mezclar(dest: np.ndarray, src: np.ndarray, pos: int) -> None:
	"""Suma con vuelta al principio: lo que se sale del final suena al empezar (bucle perfecto)."""
	n = len(dest)
	fin = pos + len(src)
	if fin <= n:
		dest[pos:fin] += src
	else:
		corte = n - pos
		dest[pos:] += src[:corte]
		dest[: len(src) - corte] += src[corte:]


def componer(tempo: int, modo: str, timbre: str, energia: float, semilla: int, compases: int = 16) -> np.ndarray:
	"""Pista en bucle: 'compases' de 4 tiempos. energia 0..1 (menu ~0.35, nivel ~0.75)."""
	rng = np.random.default_rng(semilla)
	pulso = 60.0 / tempo
	dur_compas = pulso * 4
	n_total = int(round(dur_compas * compases * SR))
	pista = np.zeros(n_total)
	escala = ESCALAS[modo]
	tonica = 57 + int(rng.integers(0, 5))  # La a Re graves
	prog = PROGRESIONES[modo][int(rng.integers(0, len(PROGRESIONES[modo])))]
	lead, ancho = {"retro": ("cuadrada", 0.5), "metalico": ("cuadrada", 0.18), "suave": ("triangulo", 0.5)}.get(timbre, ("cuadrada", 0.5))

	def grado(g: int, octava: int = 0) -> int:
		return tonica + escala[g % 7] + 12 * (g // 7 + octava)

	## Motivo de 2 compases (8 corcheas por compas) a partir de notas del acorde y de paso.
	def motivo() -> list[tuple[int, float] | None]:
		notas: list[tuple[int, float] | None] = []
		g = int(rng.choice([0, 2, 4]))
		for i in range(16):
			if rng.random() < (0.28 - 0.12 * energia) and i % 4 != 0:
				notas.append(None)
				continue
			g = int(np.clip(g + rng.choice([-2, -1, 1, 1, 2, 0]), -2, 9))
			larga = 2.0 if (i % 8 == 6 and rng.random() < 0.6) else 1.0
			notas.append((g, larga))
		return notas

	a, b = motivo(), motivo()
	forma = [a, a, b, a] * (compases // 8) if compases >= 8 else [a]
	corchea = pulso / 2
	for bloque, mot in enumerate(forma):
		inicio_bloque = bloque * 2 * dur_compas
		for i, nota in enumerate(mot):
			if nota is None:
				continue
			g, larga = nota
			acorde = prog[(bloque * 2 + i // 8) % len(prog)]
			midi = grado(g + acorde if rng.random() < 0.15 else g, 1)
			s = _nota(lead, midi, corchea * larga * 0.95, 0.20, ancho, 0.22 + 0.2 * (1 - energia))
			_mezclar(pista, s, int((inicio_bloque + i * corchea) * SR))
	## Bajo: raiz del acorde en negras (o corcheas con mas energia).
	for c in range(compases):
		raiz = grado(prog[c % len(prog)], -1)
		pasos = 8 if energia > 0.6 else 4
		for k in range(pasos):
			midi = raiz + (12 if (pasos == 8 and k % 2 == 1) else 0)
			s = _nota("triangulo", midi, dur_compas / pasos * 0.9, 0.30, 0.5, 0.3)
			_mezclar(pista, s, int((c * dur_compas + k * dur_compas / pasos) * SR))
	## Acordes suaves (arpegio) para rellenar.
	for c in range(compases):
		base = prog[c % len(prog)]
		for k, g in enumerate([base, base + 2, base + 4, base + 2] * 2):
			s = _nota("sinusoide", grado(g, 0), corchea * 0.9, 0.07, 0.5, 0.15)
			_mezclar(pista, s, int((c * dur_compas + k * corchea) * SR))
	## Bateria: bombo en 1 y 3, caja en 2 y 4, charles en corcheas (menos con poca energia).
	if energia > 0.2:
		for c in range(compases):
			for tiempo in range(4):
				pos = int((c * dur_compas + tiempo * pulso) * SR)
				if tiempo in (0, 2):
					_mezclar(pista, _bombo(0.25, 0.55 * energia + 0.2), pos)
				else:
					_mezclar(pista, _ruido(0.18, 0.22 * energia + 0.05, 0.05, rng, grave=True), pos)
				if energia > 0.5:
					for media in (0, 1):
						_mezclar(pista, _ruido(0.05, 0.07, 0.012, rng), pos + int(media * corchea * SR))
	return pista


def jingle(modo: str, timbre: str, tempo: int, semilla: int) -> np.ndarray:
	rng = np.random.default_rng(semilla)
	escala = ESCALAS[modo]
	tonica = 69 + int(rng.integers(0, 3))
	lead, ancho = {"retro": ("cuadrada", 0.5), "metalico": ("cuadrada", 0.18), "suave": ("triangulo", 0.5)}.get(timbre, ("cuadrada", 0.5))
	pulso = 60.0 / max(tempo, 110)
	notas = [0, 2, 4, 7, 4, 7, 9]
	dur = [0.5, 0.5, 0.5, 1.0, 0.5, 0.5, 3.0]
	total = int((sum(dur) * pulso + 0.8) * SR)
	pista = np.zeros(total)
	pos = 0.0
	for g, d in zip(notas, dur):
		midi = tonica + escala[g % 7] + 12 * (g // 7)
		_mezclar(pista, _nota(lead, midi, d * pulso, 0.25, ancho, 0.4 if d > 1 else 0.15), int(pos * SR))
		_mezclar(pista, _nota("triangulo", midi - 24, d * pulso, 0.25, 0.5, 0.4), int(pos * SR))
		pos += d * pulso
	pista[-int(0.4 * SR):] *= np.linspace(1.0, 0.0, int(0.4 * SR))
	return pista


def _guardar(s: np.ndarray, ruta: Path) -> None:
	m = float(np.abs(s).max()) or 1.0
	s = s / m * 0.8
	ruta.parent.mkdir(parents=True, exist_ok=True)
	with wave.open(str(ruta), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes((np.clip(s, -1, 1) * 32767).astype(np.int16).tobytes())


def generar(biblia: dict, carpeta: Path, semilla: int) -> dict[str, Path]:
	mus = biblia.get("musica", {})
	ambiente = str(mus.get("ambiente", "")).lower()
	modo = "menor" if any(p in ambiente for p in OSCURO) else "mayor"
	tranquilo = any(p in ambiente for p in TRANQUILO)
	tempo = int(mus.get("tempo", 118))
	timbre = biblia.get("sonido", {}).get("paleta", "retro")
	salida = {
		"menu": carpeta / "menu.wav",
		"nivel": carpeta / "nivel.wav",
		"victoria": carpeta / "victoria.wav",
	}
	_guardar(componer(max(70, tempo - 16), modo, timbre, 0.3, semilla, 8), salida["menu"])
	_guardar(componer(tempo, modo, timbre, 0.55 if tranquilo else 0.8, semilla + 1, 16), salida["nivel"])
	_guardar(jingle(modo, timbre, tempo, semilla + 2), salida["victoria"])
	return salida
