"""Subida a YouTube sin Google: token OAuth y subida reanudable simulados.

	python -m pruebas.prueba_youtube
"""

import json
import os
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

SUBIDAS: list[dict] = []
fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


class Google(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def _json(self, d, code=200, extra=None):
		b = json.dumps(d).encode()
		self.send_response(code)
		self.send_header("Content-Type", "application/json")
		for k, v in (extra or {}).items():
			self.send_header(k, v)
		self.send_header("Content-Length", str(len(b)))
		self.end_headers()
		self.wfile.write(b)

	def do_POST(self):
		cuerpo = self.rfile.read(int(self.headers.get("Content-Length") or 0))
		if self.path.startswith("/token"):
			if b"refresh_token=1%2F%2Fretirado" in cuerpo:
				return self._json({"error": "invalid_grant"}, 400)
			return self._json({"access_token": "ya29.prueba"})
		meta = json.loads(cuerpo)
		n = len(SUBIDAS)
		SUBIDAS.append({"meta": meta, "auth": self.headers.get("Authorization"), "bytes": 0})
		puerto = self.server.server_address[1]
		return self._json({}, 200, {"Location": f"http://127.0.0.1:{puerto}/put/{n}"})

	def do_PUT(self):
		n = int(self.path.rsplit("/", 1)[-1])
		datos = self.rfile.read(int(self.headers.get("Content-Length") or 0))
		SUBIDAS[n]["bytes"] = len(datos)
		return self._json({"id": f"vid{n}"})


class SbFalso:
	def __init__(self, token):
		self.token = token

	def rpc(self, funcion, **p):
		return self.token if funcion == "youtube_token" else True


def main() -> int:
	srv = ThreadingHTTPServer(("127.0.0.1", 0), Google)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	base = f"http://127.0.0.1:{srv.server_address[1]}"
	os.environ.update({"ORQ_GOOGLE_TOKEN_URL": base + "/token", "ORQ_YOUTUBE_UPLOAD_URL": base + "/upload",
		"GOOGLE_OAUTH_CLIENT_ID": "c", "GOOGLE_OAUTH_CLIENT_SECRET": "s"})
	import importlib

	from marketing import youtube
	importlib.reload(youtube)
	import trabajador

	tmp = Path(tempfile.mkdtemp())
	vids = []
	for e in ("reto", "curiosidad", "humor"):
		(tmp / f"{e}.mp4").write_bytes(b"\0" * 1000)
		vids.append({"estilo": e, "gancho": f"Gancho {e}", "mp4": str(tmp / f"{e}.mp4")})
	(tmp / "trailer.mp4").write_bytes(b"\0" * 3000)
	r = {"videos": vids, "trailer": str(tmp / "trailer.mp4"),
		"redes": {"es": {"shorts_titulo": "Bigotes #Shorts", "shorts_descripcion": "Juega gratis"}},
		"publicacion": {"es": {"titulo": "Bigotes Veloces: ¿llegas al final?", "hashtags": ["#juegos", "#android"]}}}
	print("== YouTube ==")
	res = trabajador._subir_youtube(SbFalso("1//rt"), "u1", r, "oculto")
	check("sube 3 Shorts y el trailer", len(res["videos"]) == 4 and len(SUBIDAS) == 4, str(res.get("error")))
	check("Shorts con #Shorts en el titulo", all("#Shorts" in s["meta"]["snippet"]["title"] for s in SUBIDAS[:3]))
	check("oculto -> unlisted", all(s["meta"]["status"]["privacyStatus"] == "unlisted" for s in SUBIDAS))
	check("declara IA y que no es para ninos", all(s["meta"]["status"]["containsSyntheticMedia"] and not s["meta"]["status"]["selfDeclaredMadeForKids"] for s in SUBIDAS))
	check("sube el video entero con el token del usuario", SUBIDAS[3]["bytes"] == 3000 and SUBIDAS[0]["auth"] == "Bearer ya29.prueba")
	check("enlaces a los videos", res["videos"][0]["url"].startswith("https://youtube.com/shorts/") and res["videos"][3]["url"].startswith("https://youtu.be/"))
	res2 = trabajador._subir_youtube(SbFalso("1//retirado"), "u1", r, "publico")
	check("permiso retirado -> aviso claro, sin romper", "vuelve a conectar" in res2.get("error", ""), res2.get("error", "")[:60])
	res3 = trabajador._subir_youtube(SbFalso(None), "u1", r, "publico")
	check("sin canal conectado -> aviso", "no esta conectado" in res3.get("error", ""))
	srv.shutdown()
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
