"""Revision visual con IA (Claude con vision) sin gastar: API de Anthropic simulada.

	python -m pruebas.prueba_revision
"""

import argparse
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

from arte import cli  # noqa: E402
from director import llm  # noqa: E402
from pruebas import comfy_simulado  # noqa: E402

PETICIONES: list[dict] = []
fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


class Claude(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def do_POST(self):
		d = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)))
		PETICIONES.append(d)
		texto = d["messages"][0]["content"][1]["text"]
		## El primer heroe "se parece a un personaje protegido": debe repetirse.
		mal = "robot" in texto and sum(1 for p in PETICIONES if "robot" in p["messages"][0]["content"][1]["text"]) == 1
		entrada = {"ok": not mal, "problemas": ["se parece demasiado a un personaje famoso"] if mal else [],
			"parecido_protegido": "Personaje famoso" if mal else ""}
		cuerpo = json.dumps({"content": [{"type": "tool_use", "id": "t", "name": "revision", "input": entrada}],
			"usage": {"input_tokens": 1200, "output_tokens": 60}, "stop_reason": "tool_use"}).encode()
		self.send_response(200)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(cuerpo)))
		self.end_headers()
		self.wfile.write(cuerpo)


def main() -> int:
	srv = ThreadingHTTPServer(("127.0.0.1", 0), Claude)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	llm.API_URL = f"http://127.0.0.1:{srv.server_address[1]}/v1/messages"
	os.environ["ANTHROPIC_API_KEY"] = "sk-prueba"
	comfy = comfy_simulado.arrancar(8196)
	gasto = llm.Gasto()
	try:
		inf = cli.fabricar(argparse.Namespace(
			biblia=str(RAIZ / "ejemplos" / "biblia_salto.json"), comfy="http://127.0.0.1:8196",
			crear=str(RAIZ / "plantillas" / "simulado_crear.json"), editar=str(RAIZ / "plantillas" / "simulado_editar.json"),
			salida=str(RAIZ / "salida_prueba" / "revision"), godot="", lado=512, revision=gasto))
	finally:
		comfy.shutdown()
		srv.shutdown()
	print("== Revision visual con IA ==")
	rev = inf.get("revision_ia", {})
	personajes = [p for p in json.load(open(RAIZ / "ejemplos" / "biblia_salto.json"))["personajes"]]
	check("revisa cada personaje (no los objetos)", sorted(rev) == sorted(p["id"] for p in personajes), str(sorted(rev)))
	check("manda la imagen a Claude", all(p["messages"][0]["content"][0]["type"] == "image" for p in PETICIONES))
	check("modelo barato con vision", all(p["model"] == llm.MODELOS[0] for p in PETICIONES))
	heroe = personajes[0]["id"]
	check("parecido a un personaje protegido -> se repite la ficha", rev[heroe]["ok"] is False and inf["regeneradas"] >= 1)
	check("se apunta el coste de la revision", gasto.usd > 0 and any(c["nota"] == "revision_visual" for c in gasto.llamadas), f"{gasto.usd} USD")
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
