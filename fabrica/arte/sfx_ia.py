"""Efectos de sonido con IA: Stable Audio 3 Medium (ComfyUI en la GPU de RunPod).

Licencia: Stability AI Community License (uso comercial libre por debajo de 1 M$ de ingresos al ano;
el audio generado es de quien lo genera). Por encima, licencia de empresa con Stability AI.

Cada efecto de la Biblia (jump, coin, hurt...) se describe como lo pide el modelo (fuente,
material, espacio, evolucion en el tiempo) con el estilo de la paleta de sonido del juego:
	retro    -> 8-bit chiptune
	suave    -> cartoon suave
	metalico -> mecanico y metalico
Despues: se recorta el silencio del principio, se corta a su duracion, cola con fundido, volumen
igualado y WAV mono para Godot. Control de calidad: ni silencio, ni saturacion. Si un efecto falla,
ese efecto (y solo ese) se queda con la version procedural.
"""

import json
from pathlib import Path

import numpy as np

from . import musica_ia

SR = 44100
ESTILO = {
	"retro": "8-bit retro chiptune video game sound effect, square wave synthesis, dry, crisp",
	"suave": "soft gentle cartoon video game sound effect, rounded tones, warm, clean",
	"metalico": "metallic mechanical video game sound effect, robotic clanks and servo whirs, bright",
}
EFECTOS = {
	"jump": ("quick springy jump, short upward pitch sweep with a light bounce", 0.6),
	"coin": ("coin pickup chime, two quick bright ascending notes with a short sparkle tail", 0.7),
	"hurt": ("character gets hurt, dull soft impact with a quick descending tone", 0.6),
	"land": ("soft landing thud on the ground, short low impact", 0.4),
	"win": ("short victory jingle sting, bright rewarding ascending arpeggio", 1.8),
	"click": ("user interface button click, crisp and very short", 0.25),
	"stomp": ("stomping on an enemy, punchy squash with a springy bounce", 0.6),
	"powerup": ("power-up collected, rising shimmering magical arpeggio", 1.4),
	"shoot": ("small projectile shot, quick zap with a short whoosh", 0.45),
}


class SfxError(Exception):
	pass


def encargos(biblia: dict, semilla: int) -> list[dict]:
	paleta = str(biblia.get("sonido", {}).get("paleta", "retro"))
	estilo = ESTILO.get(paleta, ESTILO["retro"])
	out = []
	for i, nombre in enumerate(biblia.get("sonido", {}).get("efectos", [])):
		desc, seg = EFECTOS.get(nombre, (f"video game sound effect for '{nombre}', short and clear", 0.8))
		## El modelo trabaja mejor con un poco de margen; luego se recorta a "seg".
		out.append({"id": nombre, "prompt": f"{desc}, {estilo}, isolated, no music, no voice. Length: 2 seconds",
			"segundos_modelo": max(2.0, round(seg + 0.8, 1)), "segundos": seg, "semilla": semilla + 37 * i})
	return out


def valores(enc: dict, intento: int) -> dict:
	return {"PROMPT": enc["prompt"], "NEGATIVO": "music, melody, speech, voice, vocals, noise hiss, low quality",
		"DURACION": float(enc["segundos_modelo"]), "SEED": enc["semilla"] + intento * 7919}


def recortar(a: np.ndarray, segundos: float) -> np.ndarray:
	"""Mono, sin silencio inicial, con su duracion y una cola suave."""
	m = a.mean(axis=1) if a.ndim == 2 else a
	umbral = max(0.02 * float(np.max(np.abs(m))), 1e-4)
	inicio = int(np.argmax(np.abs(m) > umbral)) if np.any(np.abs(m) > umbral) else 0
	inicio = max(0, inicio - int(0.004 * SR))
	m = m[inicio:inicio + int(segundos * SR)]
	cola = min(len(m), int(0.06 * SR))
	if cola:
		m = m.copy()
		m[-cola:] *= np.linspace(1.0, 0.0, cola, dtype=np.float32)
	pico = float(np.max(np.abs(m))) if len(m) else 0.0
	return (m * (0.89 / pico)).astype(np.float32) if pico > 0 else m.astype(np.float32)


def revisar(m: np.ndarray, segundos: float) -> list[str]:
	problemas = []
	if len(m) < 0.5 * segundos * SR:
		problemas.append("demasiado corto")
	rms = float(np.sqrt(np.mean(m ** 2))) if len(m) else 0.0
	if rms < 0.02:
		problemas.append("casi en silencio")
	if len(m) and float(np.mean(np.abs(m) > 0.999)) > 0.02:
		problemas.append("saturado")
	return problemas


def guardar_wav(m: np.ndarray, ruta: Path) -> Path:
	import wave

	ruta.parent.mkdir(parents=True, exist_ok=True)
	with wave.open(str(ruta), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes((np.clip(m, -1, 1) * 32767).astype(np.int16).tobytes())
	return ruta


def generar(biblia: dict, carpeta: Path, cliente, flujo: dict, semilla: int, intentos: int = 2) -> tuple[dict[str, Path], dict]:
	"""Devuelve ({efecto: ruta.wav}, informe) con los efectos que salieron bien (los demas, al procedural)."""
	carpeta.mkdir(parents=True, exist_ok=True)
	encs = encargos(biblia, semilla)
	(carpeta / "encargos_sfx.json").write_text(json.dumps(encs, indent=1, ensure_ascii=False), encoding="utf-8")
	efectos: dict[str, Path] = {}
	informe: dict = {"motor": "stable-audio-3-medium", "efectos": {}, "fallidos": {}, "generaciones": 0}
	for enc in encs:
		ultimo: list[str] = []
		for intento in range(intentos):
			try:
				datos = cliente.generar(flujo, valores(enc, intento))[0]
			except Exception as e:  # noqa: BLE001 - un efecto que falla no para los demas
				ultimo = [str(e)[:120]]
				break
			informe["generaciones"] += 1
			m = recortar(musica_ia.decodificar(datos), enc["segundos"])
			ultimo = revisar(m, enc["segundos"])
			if not ultimo:
				efectos[enc["id"]] = guardar_wav(m, carpeta / f"{enc['id']}.wav")
				informe["efectos"][enc["id"]] = {"segundos": round(len(m) / SR, 2), "intentos": intento + 1}
				break
		if enc["id"] not in efectos:
			informe["fallidos"][enc["id"]] = ultimo
	return efectos, informe
