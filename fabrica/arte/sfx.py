"""Efectos de sonido procedurales (al estilo sfxr): gratis, instantaneos y coherentes.

La paleta sonora de la Biblia decide el timbre de TODOS los efectos:
	retro    -> ondas cuadradas y ruido, como consola de 8/16 bits
	suave    -> seno y triangulo, filtrado, para juegos tranquilos o infantiles
	metalico -> cuadrada estrecha con brillo, para robots y maquinas
Cada efecto es determinista: el mismo juego siempre suena igual.
"""

import wave
from pathlib import Path

import numpy as np

SR = 44100


def _onda(tipo: str, fase: np.ndarray, rng: np.random.Generator, ancho: float = 0.5) -> np.ndarray:
	f = fase % 1.0
	if tipo == "cuadrada":
		return np.where(f < ancho, 1.0, -1.0)
	if tipo == "sierra":
		return 2.0 * f - 1.0
	if tipo == "triangulo":
		return 4.0 * np.abs(f - 0.5) - 1.0
	if tipo == "seno":
		return np.sin(2 * np.pi * f)
	return rng.uniform(-1.0, 1.0, size=fase.shape)


def sintetizar(dur: float, f0: float, f1: float, tipo: str, ataque: float = 0.005, caida: float = 0.6,
				vibrato: float = 0.0, arpegio: list[float] | None = None, ruido: float = 0.0,
				ancho: float = 0.5, semilla: int = 1, paso_bajo: float = 1.0) -> np.ndarray:
	rng = np.random.default_rng(semilla)
	n = int(dur * SR)
	t = np.arange(n) / SR
	freq = f0 * (f1 / f0) ** (t / dur) if f0 > 0 and f1 > 0 else np.full(n, f0)
	if arpegio:
		tramo = n // len(arpegio)
		mult = np.concatenate([np.full(tramo, m) for m in arpegio] + [np.full(n - tramo * len(arpegio), arpegio[-1])])
		freq = freq * mult
	if vibrato:
		freq = freq * (1.0 + vibrato * np.sin(2 * np.pi * 7.0 * t))
	fase = np.cumsum(freq) / SR
	s = _onda(tipo, fase, rng, ancho)
	if ruido:
		s = (1 - ruido) * s + ruido * rng.uniform(-1, 1, n)
	env = np.ones(n)
	a = max(1, int(ataque * SR))
	env[:a] = np.linspace(0, 1, a)
	env *= np.exp(-t / max(dur * caida, 1e-3) * 2.5)
	s = s * env
	if paso_bajo < 1.0:
		y = np.zeros_like(s)
		acc = 0.0
		for i in range(n):
			acc += paso_bajo * (s[i] - acc)
			y[i] = acc
		s = y
	return s


TIMBRES = {
	"retro": {"tipo": "cuadrada", "ruido_tipo": "ruido", "paso_bajo": 1.0, "ancho": 0.5},
	"suave": {"tipo": "triangulo", "ruido_tipo": "ruido", "paso_bajo": 0.25, "ancho": 0.5},
	"metalico": {"tipo": "cuadrada", "ruido_tipo": "ruido", "paso_bajo": 1.0, "ancho": 0.18},
}


def efecto(nombre: str, paleta: str, semilla: int) -> np.ndarray:
	tb = TIMBRES.get(paleta, TIMBRES["retro"])
	tipo, pb, an = tb["tipo"], tb["paso_bajo"], tb["ancho"]
	if nombre == "jump":
		return sintetizar(0.22, 260, 620, tipo, caida=0.7, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "coin":
		return sintetizar(0.28, 988, 988, tipo, arpegio=[1.0, 1.335], caida=0.8, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "hurt":
		return sintetizar(0.32, 420, 90, tipo, ruido=0.45, caida=0.6, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "land":
		return sintetizar(0.09, 140, 60, "ruido", caida=0.4, semilla=semilla, paso_bajo=min(pb, 0.35))
	if nombre == "win":
		return sintetizar(0.9, 523, 523, tipo, arpegio=[1.0, 1.26, 1.5, 2.0], caida=0.9, vibrato=0.01, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "click":
		return sintetizar(0.05, 1400, 900, tipo, caida=0.3, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "stomp":
		return sintetizar(0.16, 560, 150, tipo, ruido=0.3, caida=0.45, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "shoot":
		return sintetizar(0.12, 900, 300, tipo, ruido=0.15, caida=0.35, ancho=an, semilla=semilla, paso_bajo=pb)
	if nombre == "powerup":
		return sintetizar(0.6, 300, 1200, tipo, arpegio=[1.0, 1.25, 1.5], vibrato=0.02, caida=0.9, ancho=an, semilla=semilla, paso_bajo=pb)
	raise ValueError(f"Efecto desconocido: {nombre}")


def normalizar(s: np.ndarray, pico_db: float = -3.0) -> np.ndarray:
	"""Todos los efectos al mismo nivel de pico: ninguno suena mucho mas alto que otro."""
	m = float(np.abs(s).max())
	if m == 0:
		return s
	return s / m * (10 ** (pico_db / 20.0))


def guardar_wav(s: np.ndarray, path: Path) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	pcm = (np.clip(s, -1, 1) * 32767).astype(np.int16)
	with wave.open(str(path), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())


def generar(biblia: dict, carpeta: Path, semilla_base: int) -> dict[str, Path]:
	paleta = biblia["sonido"]["paleta"]
	salida = {}
	for i, nombre in enumerate(biblia["sonido"]["efectos"]):
		s = normalizar(efecto(nombre, paleta, semilla_base + i))
		p = carpeta / f"{nombre}.wav"
		guardar_wav(s, p)
		salida[nombre] = p
	return salida
