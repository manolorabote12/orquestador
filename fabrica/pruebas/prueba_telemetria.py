"""Datos anonimos de partida de punta a punta: un juego fabricado, jugado por el bot en Godot,
manda su lote a un servidor falso con la forma exacta de la funcion registrar_partida.

	python -m pruebas.prueba_telemetria
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import cadena

RECIBIDO: list[dict] = []
CABECERAS: list[dict] = []


class Falso(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def do_POST(self):
		largo = int(self.headers.get("Content-Length") or 0)
		cuerpo = json.loads(self.rfile.read(largo) or b"{}")
		RECIBIDO.append({"ruta": self.path, "cuerpo": cuerpo})
		CABECERAS.append({"apikey": self.headers.get("apikey"), "auth": self.headers.get("Authorization")})
		r = json.dumps(len(cuerpo.get("p_eventos", []))).encode()
		self.send_response(200)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(r)))
		self.end_headers()
		self.wfile.write(r)


def main() -> int:
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	srv = HTTPServer(("127.0.0.1", 0), Falso)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	os.environ["ORQ_TELEMETRIA_URL"] = f"http://127.0.0.1:{srv.server_address[1]}"
	os.environ["ORQ_TELEMETRIA_CLAVE"] = "clave-anon-publica"
	tmp = Path(tempfile.mkdtemp(prefix="orq_tel_"))
	inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja que salta por tejados de noche", salida=str(tmp), simulado=True,
		arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=8, apk=False, capturas=False,
		telemetria_id="0f0e0d0c-0b0a-4908-8706-050403020100"))
	proyecto = Path(inf["proyecto"])
	shutil.copy2(cadena.KIT / "qa" / "telemetry_e2e.gd", proyecto / "qa" / "telemetry_e2e.gd")
	shutil.copy2(cadena.KIT / "qa" / "telemetry_e2e.tscn", proyecto / "qa" / "telemetry_e2e.tscn")
	r2 = cadena.godot(proyecto, "--fixed-fps", "60", "res://qa/telemetry_e2e.tscn", timeout=300)
	check("sin el permiso de prueba, una partida sin pantalla (bot) no se envia", r2.returncode != 0 and "enviado=false" in r2.stdout + r2.stderr)
	RECIBIDO.clear()
	CABECERAS.clear()
	r = cadena.godot(proyecto, "--fixed-fps", "60", "res://qa/telemetry_e2e.tscn", "--", "--telemetria-prueba", timeout=300)
	salida = r.stdout + r.stderr
	check("el bot juega y el lote se envia", r.returncode == 0 and "enviado=true" in salida, salida[-600:])
	## El juego tambien habla con el servidor de lo online (fantasmas...): se mira el lote de datos.
	lotes = [x for x in RECIBIDO if x["ruta"] == "/rest/v1/rpc/registrar_partida"]
	check("va a la funcion registrar_partida", bool(lotes), str([x["ruta"] for x in RECIBIDO]))
	if lotes:
		c = lotes[0]["cuerpo"]
		check("con los parametros de la funcion", set(c) == {"p_juego", "p_version", "p_sesion", "p_eventos"}, str(set(c)))
		check("juego y version del game.json", c["p_juego"] == "0f0e0d0c-0b0a-4908-8706-050403020100" and c["p_version"] == 1)
		ev = c["p_eventos"]
		check("un intento ganado del nivel 1", any(e["n"] == 0 and e["r"] == "gana" for e in ev), str(ev))
		check("solo datos de partida (n, r, s, m, e)", all(set(e) <= {"n", "r", "s", "m", "e"} for e in ev))
		check("sesion aleatoria con el formato que acepta el servidor", len(c["p_sesion"]) == 16
			and all(ch in "0123456789abcdef" for ch in c["p_sesion"]))
		check("con la clave publica (anon)", all(x["apikey"] == "clave-anon-publica" for x in CABECERAS))
	srv.shutdown()
	shutil.rmtree(tmp, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
