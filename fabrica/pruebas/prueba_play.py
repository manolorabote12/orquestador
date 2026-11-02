"""Publicacion en Google Play contra un servidor falso que imita la API de Google.

	python -m pruebas.prueba_play

Comprueba: firma del JWT de la cuenta de servicio, orden de llamadas de una edicion, subida del
.aab, paso a borrador si la app aun es borrador, textos e imagenes en dos idiomas, que se
descarta la edicion si algo falla, y que los errores de Google se traducen a lo que hay que hacer.
"""

import base64
import json
import os
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

LLAVE = rsa.generate_private_key(public_exponent=65537, key_size=2048)
ESTADO = {"llamadas": [], "borrador": True, "paquetes": {"com.danielstudio.bigotes"}, "permiso": True, "subidas": 0}


def _b64d(s: str) -> bytes:
	return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


class Falso(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def _responder(self, codigo: int, datos: dict) -> None:
		cuerpo = json.dumps(datos).encode()
		self.send_response(codigo)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(cuerpo)))
		self.end_headers()
		self.wfile.write(cuerpo)

	def _todo(self, metodo: str) -> None:
		largo = int(self.headers.get("Content-Length") or 0)
		cuerpo = self.rfile.read(largo) if largo else b""
		ruta = self.path.split("?")[0]
		if ruta == "/token":
			form = dict(p.split("=", 1) for p in cuerpo.decode().split("&"))
			cab, datos, firma = form["assertion"].split(".")
			try:
				LLAVE.public_key().verify(_b64d(firma), f"{cab}.{datos}".encode(), padding.PKCS1v15(), hashes.SHA256())
			except Exception:  # noqa: BLE001
				return self._responder(400, {"error": "invalid_grant"})
			claims = json.loads(_b64d(datos))
			assert claims["scope"].endswith("androidpublisher")
			return self._responder(200, {"access_token": "tok-123", "expires_in": 3600})
		if self.headers.get("Authorization") != "Bearer tok-123":
			return self._responder(401, {"error": {"message": "no auth"}})
		subida = ruta.startswith("/upload/")
		ruta = ruta.replace("/upload", "", 1).replace("/androidpublisher/v3/applications/", "")
		paquete, _, resto = ruta.partition("/")
		ESTADO["llamadas"].append(f"{metodo} {resto}" + (" [subida]" if subida else ""))
		if not ESTADO["permiso"]:
			return self._responder(403, {"error": {"message": "The caller does not have permission"}})
		if paquete not in ESTADO["paquetes"]:
			return self._responder(404, {"error": {"message": "Package not found: " + paquete}})
		if resto.startswith("inappproducts/"):
			if ESTADO.get("sin_pagos"):
				return self._responder(403, {"error": {"message": "This developer account does not have a merchant account (payments profile)."}})
			c = json.loads(cuerpo)
			assert c["defaultPrice"]["currency"] == "EUR" and c["status"] == "active" and "es-ES" in c["listings"]
			return self._responder(200, c)
		if metodo == "POST" and resto == "edits":
			return self._responder(200, {"id": "edicion-1"})
		if subida and resto.endswith("/bundles"):
			assert cuerpo.startswith(b"PK"), "el .aab tiene que ser un zip"
			return self._responder(200, {"versionCode": 7, "sha256": "x"})
		if metodo == "PUT" and "/tracks/" in resto:
			rel = json.loads(cuerpo)["releases"][0]
			if ESTADO["borrador"] and rel["status"] != "draft":
				return self._responder(400, {"error": {"message": "Only releases with status draft may be created on draft app."}})
			return self._responder(200, json.loads(cuerpo))
		if subida and "/listings/" in resto:
			ESTADO["subidas"] += 1
			assert self.headers.get("Content-Type") in ("image/png", "image/jpeg")
			return self._responder(200, {"image": {"id": "i"}})
		return self._responder(200, {})

	def do_GET(self):
		self._todo("GET")

	def do_POST(self):
		self._todo("POST")

	def do_PUT(self):
		self._todo("PUT")

	def do_PATCH(self):
		self._todo("PATCH")

	def do_DELETE(self):
		self._todo("DELETE")


def main() -> int:
	srv = HTTPServer(("127.0.0.1", 0), Falso)
	puerto = srv.server_address[1]
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	os.environ["ORQ_PLAY_API"] = f"http://127.0.0.1:{puerto}"
	from play import api
	api.API = os.environ["ORQ_PLAY_API"]
	from PIL import Image
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	pem = LLAVE.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
	cuenta = {"client_email": "orquestador@proyecto.iam.gserviceaccount.com", "private_key": pem,
		"token_uri": f"http://127.0.0.1:{puerto}/token"}
	with tempfile.TemporaryDirectory() as t:
		t = Path(t)
		aab = t / "juego.aab"
		import zipfile
		with zipfile.ZipFile(aab, "w") as z:
			z.writestr("base/manifest/AndroidManifest.xml", "x")
		ficha = t / "ficha"
		for sub in ("capturas", "capturas_en"):
			(ficha / sub).mkdir(parents=True)
			for i in range(6):
				Image.new("RGB", (1080, 1920)).save(ficha / sub / f"{i}.png")
		Image.new("RGBA", (512, 512), (1, 2, 3, 255)).save(ficha / "icono_512.png")
		Image.new("RGB", (1024, 500)).save(ficha / "destacado_1024x500.png")
		(ficha / "textos.json").write_text(json.dumps({i: {"titulo": "Bigotes", "corta": "Corta", "larga": "Larga"} for i in ("es", "en")}))

		r = api.publicar(cuenta, "com.danielstudio.bigotes", aab, ficha, "internal", correo="dani@example.com", aviso=lambda m: None)
		check("publica: version del .aab", r["version"] == 7, str(r))
		check("app en borrador: la version se sube como borrador", r["borrador"] is True)
		check("16 imagenes subidas (icono, destacado y 6 capturas por idioma)", r["imagenes"] == 16 and ESTADO["subidas"] == 16, str(r["imagenes"]))
		ll = ESTADO["llamadas"]
		orden = [ll.index("POST edits"), ll.index("POST edits/edicion-1/bundles [subida]"),
			ll.index("PUT edits/edicion-1/listings/es-ES"), ll.index("POST edits/edicion-1:validate"), ll.index("POST edits/edicion-1:commit")]
		check("orden: abrir, subir, ficha, validar, confirmar", orden == sorted(orden), str(orden))
		check("textos en es-ES y en-US", "PUT edits/edicion-1/listings/en-US" in ll)
		check("crea los 5 productos de la tienda del juego", r["productos"] == 5 and "PUT inappproducts/sin_anuncios" in ll and "PUT inappproducts/pack_inicio" in ll
			and ll.index("PUT inappproducts/monedas_500") > ll.index("POST edits/edicion-1:commit"), str(r.get("aviso_productos")))
		ESTADO["sin_pagos"] = True
		ESTADO["llamadas"].clear()
		r = api.publicar(cuenta, "com.danielstudio.bigotes", aab, ficha, "internal", aviso=lambda m: None)
		check("sin perfil de pagos el juego se publica igual y explica que hacer", r["ok"] and r["productos"] == 0 and "perfil de pagos" in r["aviso_productos"], r["aviso_productos"])
		ESTADO["sin_pagos"] = False

		ESTADO["borrador"] = False
		ESTADO["llamadas"].clear()
		r = api.publicar(cuenta, "com.danielstudio.bigotes", aab, ficha, "alpha", aviso=lambda m: None)
		check("app ya publicada: version completa en prueba cerrada (alpha)", r["borrador"] is False and r["pista"] == "alpha")

		ESTADO["llamadas"].clear()
		try:
			api.publicar(cuenta, "com.otro.juego", aab, ficha, aviso=lambda m: None)
			check("paquete que no existe da error", False)
		except api.ErrorPlay as e:
			check("paquete que no existe: explica que hay que crearlo en Play Console", "créalo en Play Console" in str(e), str(e))

		ESTADO["permiso"] = False
		try:
			api.publicar(cuenta, "com.danielstudio.bigotes", aab, ficha, aviso=lambda m: None)
			check("sin permiso da error", False)
		except api.ErrorPlay as e:
			check("sin permiso: explica que hay que invitar a la cuenta de servicio", "invita" in str(e), str(e))
		ESTADO["permiso"] = True

		otra = rsa.generate_private_key(public_exponent=65537, key_size=2048)
		mala = dict(cuenta, private_key=otra.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
			serialization.NoEncryption()).decode())
		try:
			api.token(mala)
			check("una llave falsa no consigue token", False)
		except api.ErrorPlay:
			check("una llave falsa no consigue token", True)
		## Publicador completo (ficha real + guia + politica) con el .aab simulado: aqui no hay Gradle.
		if os.environ.get("ORQ_PRUEBA_PROYECTO"):
			proyecto = Path(os.environ["ORQ_PRUEBA_PROYECTO"])
		else:
			import argparse

			import cadena
			inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja que salta por tejados de noche", salida=str(t / "juegos"),
				simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=3, apk=False, capturas=False))
			proyecto = Path(inf["proyecto"])
		if (proyecto / "fabrica" / "diseno.json").exists():
			from play import aab as aab_mod
			from play import publicador
			original = aab_mod.generar
			aab_mod.generar = lambda pr, paq, ver, ll: aab
			os.environ["ORQ_PLAY_CUENTA"] = json.dumps(cuenta)
			ESTADO["paquetes"].add("com.danielstudio.bigotesveloces")
			try:
				prep = publicador.preparar(proyecto, "Daniel Studio", "dani@example.com", {"huella_sha256": "AA:BB"}, 300)
				check("publicador: paquete con el estudio y el juego", prep["paquete"] == "com.danielstudio.bigotesveloces", prep["paquete"])
				pasos = {p["id"] for p in prep["guia"]["pasos"]}
				check("guia con los 9 pasos", {"cuenta", "crear", "acceso", "primer_aab", "contenido", "clasificacion", "datos", "ficha", "probadores"} <= pasos)
				check("la guia trae el correo de la cuenta de servicio", "orquestador@proyecto.iam.gserviceaccount.com" in json.dumps(prep["guia"]))
				check("politica de privacidad escrita", "Bigotes Veloces" in Path(prep["privacidad"]).read_text(encoding="utf-8"))
				g = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
				check("los retos enlazan a la ficha de la tienda", g.get("share_url") == "https://play.google.com/store/apps/details?id=com.danielstudio.bigotesveloces", str(g.get("share_url")))
				import cadena as cad
				cad.escribir_game(proyecto, json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8")),
					[x["map"] for x in g["levels"]])
				check("el enlace sobrevive a la siguiente version", json.loads((proyecto / "game.json").read_text(encoding="utf-8")).get("share_url", "").endswith("bigotesveloces"))
				r = publicador.subir(prep, "alpha", {"es": "Hola", "en": "Hi"})
				check("publicador sube con la ficha real (icono, destacado, capturas)", r["ok"] and r["imagenes"] >= 6, str(r.get("imagenes")))
			finally:
				aab_mod.generar = original
	srv.shutdown()
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
