"""ComfyUI simulado para probar la cadena sin GPU.

Implementa /upload/image, /prompt, /history/<id> y /view como ComfyUI.
Dibuja un robot sobre fondo magenta con colores ligeramente fuera de paleta
(para probar la paleta forzada) y cambia la pose segun el prompt.
A proposito, la PRIMERA vez que se pide "frame 3 of 6" o la pose "passing pose, left leg"
devuelve un personaje enorme y de otro color: el QA debe rechazarlo y la cadena
debe regenerarlo con otra semilla.
"""

import io
import json
import random
import re
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PIL import Image, ImageDraw

ESTADO = {"historial": {}, "imagenes": {}, "trampa_usada": False, "peticiones": 0}
BLOQUEO = threading.Lock()


def _prompt_de(wf: dict) -> tuple[str, int, int]:
	texto, semilla, lado = "", 0, 1024
	for n in wf.values():
		t = n.get("_meta", {}).get("title")
		if t == "PROMPT":
			texto = n["inputs"].get("text", n["inputs"].get("prompt", ""))
		elif t == "SEED":
			semilla = int(n["inputs"].get("seed", n["inputs"].get("noise_seed", 0)))
		elif t == "ANCHO":
			lado = int(n["inputs"].get("width", 1024))
	return texto, semilla, lado


def es_audio(wf: dict) -> bool:
	return any(n.get("class_type", "").startswith("SaveAudio") for n in wf.values())


def sonar(wf: dict) -> bytes:
	"""Musica simulada: acordes al tempo pedido y con la duracion del nodo DURACION (WAV estereo)."""
	import wave

	import numpy as np

	seg, bpm, semilla = 10.0, 120, 0
	for n in wf.values():
		t = n.get("_meta", {}).get("title")
		if t == "DURACION":
			seg = float(n["inputs"].get("seconds", seg))
		elif t == "MUSICA":
			bpm = int(n["inputs"].get("bpm", bpm))
			semilla = int(n["inputs"].get("seed", 0))
	sr = 22050
	tt = np.arange(int(seg * sr)) / sr
	raiz = 220.0 * 2 ** ((semilla % 12) / 12)
	pulso = 0.5 + 0.5 * (np.sin(2 * np.pi * (bpm / 60.0) * tt) > 0)
	x = sum(np.sin(2 * np.pi * raiz * r * tt) for r in (1.0, 1.26, 1.5)) / 3 * 0.4 * pulso
	est = np.stack([x, x * 0.9], axis=1)
	b = io.BytesIO()
	with wave.open(b, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(sr)
		w.writeframes((np.clip(est, -1, 1) * 32767).astype(np.int16).tobytes())
	return b.getvalue()


def dibujar(texto: str, semilla: int, lado: int) -> Image.Image:
	rnd = random.Random(semilla)
	j = lambda c: tuple(max(0, min(255, v + rnd.randint(-14, 14))) for v in c)
	if "background art" in texto or "background layer" in texto:
		## Fondo ilustrado simulado: cielo en degradado, sol y colinas.
		img = Image.new("RGB", (lado, lado))
		d = ImageDraw.Draw(img)
		for y in range(lado):
			t = y / lado
			d.line([(0, y), (lado, y)], fill=(int(40 + 120 * t), int(80 + 90 * t), int(170 - 40 * t)))
		d.ellipse([lado * 0.6, lado * 0.15, lado * 0.8, lado * 0.35], fill=(255, 220, 120))
		for k, c in enumerate([(60, 120, 80), (40, 90, 60)]):
			base = lado * (0.65 + 0.12 * k)
			d.polygon([(0, lado), (0, base), (lado * 0.3, base - lado * 0.12), (lado * 0.7, base + lado * 0.04), (lado, base - lado * 0.08), (lado, lado)], fill=c)
		return img
	if "tileable" in texto:
		mortero = j((22, 35, 58))
		img = Image.new("RGB", (lado, lado), mortero)
		d = ImageDraw.Draw(img)
		filas = 4
		h = lado // filas
		junta = max(2, h // 6)
		for fy in range(filas):
			off = h if fy % 2 else 0
			for fx in range(-1, filas + 1):
				x = fx * h * 2 + off
				d.rectangle([x + junta, fy * h + junta, x + h * 2 - junta, fy * h + h - junta], fill=j((62, 92, 132)))
				d.rectangle([x + junta, fy * h + junta, x + h * 2 - junta, fy * h + junta * 2], fill=j((107, 141, 184)))
		return img
	img = Image.new("RGB", (lado, lado), (255, 0, 255))
	d = ImageDraw.Draw(img)
	u = lado / 32
	trampa = False
	with BLOQUEO:
		if ("passing pose, left leg" in texto) and not ESTADO["trampa_usada"]:
			ESTADO["trampa_usada"] = True
			trampa = True
	if ("hex nut" in texto or "collectible pickup" in texto) and "robot" not in texto and "enemy creature" not in texto:
		ang = 0
		m = re.search(r"(45|135|edge-on)", texto)
		ancho = {"45": 0.7, "135": 0.7, "edge-on": 0.25}.get(m.group(1), 1.0) if m else 1.0
		cx, cy, r = lado / 2, lado / 2, lado * 0.3
		d.ellipse([cx - r * ancho, cy - r, cx + r * ancho, cy + r], fill=j((232, 176, 75)))
		d.ellipse([cx - r * 0.35 * ancho, cy - r * 0.35, cx + r * 0.35 * ancho, cy + r * 0.35], fill=j((92, 61, 14)))
		return img
	if "beetle" in texto or "enemy creature" in texto:
		## Enemigo: caparazon oxidado, ojos rojos y patitas que alternan al andar.
		cx, base, s = lado / 2, lado * 0.88, u * 1.4
		paso = 1.0 if ("right foot forward" in texto or "passing pose, left" in texto) else -1.0
		golpe = "recoiling" in texto
		alto = 7.0 if golpe else 10.0
		for i, px in enumerate((-6.0, -2.0, 2.0, 6.0)):
			dx = paso * (1.0 if i % 2 else -1.0) * 0.8
			d.rectangle([cx + (px + dx - 0.8) * s, base - 3 * s, cx + (px + dx + 0.8) * s, base], fill=j((11, 15, 26)))
		d.pieslice([cx - 9 * s, base - 3 * s - alto * s * 2, cx + 9 * s, base - 3 * s], 180, 360, fill=j((138, 59, 42)))
		d.rectangle([cx - 9 * s, base - 4.5 * s, cx + 9 * s, base - 2.5 * s], fill=j((92, 61, 14)))
		d.line([cx - 3 * s, base - 3 * s - alto * s * 1.8, cx + 1 * s, base - 4 * s], fill=j((217, 119, 74)), width=int(max(2, s * 0.7)))
		for ex in (3.0, 6.0):
			d.rectangle([cx + (ex - 0.9) * s, base - 8 * s, cx + (ex + 0.9) * s, base - 6.2 * s], fill=j((255, 107, 91)))
		return img
	escala = 1.9 if trampa else 1.0
	cuerpo = j((217, 119, 74)) if not trampa else (40, 200, 60)
	cx = lado / 2
	base = lado * 0.9
	piernas = 0.0
	if "contact pose, right foot forward" in texto:
		piernas = 1.0
	elif "contact pose, left foot forward" in texto:
		piernas = -1.0
	salto = "jumping" in texto
	s = u * 1.4 * escala
	if salto:
		base -= 2 * s
	d.rectangle([cx - 5 * s, base - 9 * s, cx + 5 * s, base - 3 * s], fill=cuerpo)
	## El color principal sale del prompt (primer color que aparece), como haria un modelo real.
	tonos = {"black": (34, 32, 40), "white": (236, 236, 242), "red": (200, 52, 52), "blue": (60, 92, 200),
		"green": (64, 160, 84), "purple": (130, 72, 172), "pink": (232, 132, 172), "grey": (130, 130, 142),
		"orange": (232, 140, 60), "yellow": (242, 212, 72), "golden": (232, 176, 75)}
	encontrados = sorted((texto.find(" " + c + " "), c) for c in tonos if (" " + c + " ") in texto)
	cabeza = tonos[encontrados[0][1]] if encontrados and not trampa else (232, 176, 75)
	d.rectangle([cx - 6 * s, base - 19 * s, cx + 6 * s, base - 9 * s], fill=j(cabeza))
	d.ellipse([cx - 2.5 * s, base - 17 * s, cx + 2.5 * s, base - 12 * s], fill=j((232, 240, 250)))
	d.ellipse([cx - 1 * s, base - 15.5 * s, cx + 1 * s, base - 13.5 * s], fill=j((11, 15, 26)))
	d.line([cx, base - 19 * s, cx, base - 23 * s], fill=j((232, 240, 250)), width=int(max(2, s * 0.6)))
	for lado_p, desp in ((-1, piernas), (1, -piernas)):
		x = cx + lado_p * 2.5 * s + desp * 1.5 * s
		d.rectangle([x - 1.2 * s, base - 3 * s, x + 1.2 * s, base], fill=j((11, 15, 26)))
	return img


class Manejador(BaseHTTPRequestHandler):
	def log_message(self, *a: object) -> None:
		pass

	def _json(self, data: object, code: int = 200) -> None:
		cuerpo = json.dumps(data).encode()
		self.send_response(code)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(cuerpo)))
		self.end_headers()
		self.wfile.write(cuerpo)

	def do_POST(self) -> None:
		n = int(self.headers.get("Content-Length", 0))
		cuerpo = self.rfile.read(n)
		if self.path == "/upload/image":
			m = re.search(rb'filename="([^"]+)"', cuerpo)
			nombre = m.group(1).decode() if m else "ref.png"
			self._json({"name": nombre, "subfolder": "", "type": "input"})
			return
		if self.path == "/prompt":
			wf = json.loads(cuerpo)["prompt"]
			if es_audio(wf):
				pid = str(uuid.uuid4())
				fname = f"{pid}.wav"
				salida = next((k for k, v in wf.items() if v.get("_meta", {}).get("title") == "SALIDA"), "9")
				with BLOQUEO:
					ESTADO["imagenes"][fname] = sonar(wf)
					ESTADO["historial"][pid] = {"status": {"status_str": "success"}, "outputs": {salida: {"audio": [{"filename": fname, "subfolder": "", "type": "output"}]}}}
					ESTADO["peticiones"] += 1
				self._json({"prompt_id": pid, "number": 1})
				return
			texto, semilla, lado = _prompt_de(wf)
			img = dibujar(texto, semilla, min(lado, 512))
			b = io.BytesIO()
			img.save(b, "PNG")
			pid = str(uuid.uuid4())
			fname = f"{pid}.png"
			salida = next((k for k, v in wf.items() if v.get("_meta", {}).get("title") == "SALIDA"), "9")
			with BLOQUEO:
				ESTADO["imagenes"][fname] = b.getvalue()
				ESTADO["historial"][pid] = {"status": {"status_str": "success"}, "outputs": {salida: {"images": [{"filename": fname, "subfolder": "", "type": "output"}]}}}
				ESTADO["peticiones"] += 1
			self._json({"prompt_id": pid, "number": 1})
			return
		self._json({"error": "ruta desconocida"}, 404)

	def do_GET(self) -> None:
		if self.path.startswith("/system_stats"):
			return self._json({"system": {"comfyui_version": "simulado"}})
		if self.path.startswith("/history/"):
			pid = self.path.split("/")[-1]
			self._json({pid: ESTADO["historial"][pid]} if pid in ESTADO["historial"] else {})
			return
		if self.path.startswith("/view"):
			m = re.search(r"filename=([^&]+)", self.path)
			datos = ESTADO["imagenes"].get(m.group(1), b"") if m else b""
			self.send_response(200)
			self.send_header("Content-Type", "image/png")
			self.send_header("Content-Length", str(len(datos)))
			self.end_headers()
			self.wfile.write(datos)
			return
		self._json({}, 404)


def arrancar(puerto: int = 8199) -> ThreadingHTTPServer:
	srv = ThreadingHTTPServer(("127.0.0.1", puerto), Manejador)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	return srv
