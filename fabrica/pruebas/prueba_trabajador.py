"""El trabajador con un Supabase falso en memoria: publicar en Google Play (primera vez y subida
por la API falsa de prueba_play) y, con --completa, los videos para redes.

	python -m pruebas.prueba_trabajador [--completa]
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
import threading
from http.server import HTTPServer
from pathlib import Path

import cadena
import trabajador
from pruebas import prueba_play


class SupabaseFalso:
	def __init__(self):
		self.url = "https://falso.supabase.co"
		self.archivos: dict[str, bytes] = {}
		self.rpcs: list[tuple[str, dict]] = []

	def rpc(self, funcion: str, **params):
		self.rpcs.append((funcion, params))
		return True

	def bajar(self, ruta: str, destino: Path, bucket: str = "juegos") -> Path:
		clave = f"{bucket}/{ruta}"
		if clave not in self.archivos:
			raise RuntimeError(f"Supabase GET {clave}: HTTP 400 not_found")
		destino.write_bytes(self.archivos[clave])
		return destino

	def subir(self, ruta: str, archivo: Path, bucket: str = "juegos") -> str:
		self.archivos[f"{bucket}/{ruta}"] = archivo.read_bytes()
		return ruta

	def borrar(self, rutas: list, bucket: str = "juegos") -> None:
		self.borrados = getattr(self, "borrados", []) + list(rutas)
		for r in rutas:
			self.archivos.pop(f"{bucket}/{r}", None)
			self.archivos.pop(r, None)

	def ultimo(self, funcion: str) -> dict:
		return [p for f, p in self.rpcs if f == funcion][-1]


def main() -> int:
	p = argparse.ArgumentParser()
	p.add_argument("--completa", action="store_true")
	a = p.parse_args()
	fallos = 0

	def check(nombre: str, ok: bool, detalle: str = "") -> None:
		nonlocal fallos
		print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
		fallos += 0 if ok else 1

	os.environ.setdefault("ORQ_LLAVES_SECRETO", "secreto-de-prueba-de-mas-de-24-caracteres")
	srv = HTTPServer(("127.0.0.1", 0), prueba_play.Falso)
	puerto = srv.server_address[1]
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	from cryptography.hazmat.primitives import serialization
	from play import aab, api
	api.API = f"http://127.0.0.1:{puerto}"
	pem = prueba_play.LLAVE.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
		serialization.NoEncryption()).decode()
	os.environ["ORQ_PLAY_CUENTA"] = json.dumps({"client_email": "orq@x.iam.gserviceaccount.com", "private_key": pem,
		"token_uri": f"http://127.0.0.1:{puerto}/token"})

	tmp = Path(tempfile.mkdtemp(prefix="orq_trab_"))
	inf = cadena.fabricar(argparse.Namespace(idea="un gato ninja que salta por tejados de noche", salida=str(tmp), simulado=True,
		arte_simulado=True, comfy="", crear="", editar="", lado=512, semilla=5, apk=False, capturas=False))
	proyecto = Path(inf["proyecto"])
	sb = SupabaseFalso()
	zipf = trabajador.comprimir_proyecto(proyecto, tmp / "p_godot.zip")
	sb.archivos["juegos/u1/p1/v1/bigotes_veloces_godot.zip"] = zipf.read_bytes()
	files = {"proyecto": "u1/p1/v1/bigotes_veloces_godot.zip"}

	## .aab simulado: aqui no hay Gradle (en el trabajador real lo compila Godot).
	import zipfile
	falso = tmp / "falso.aab"
	with zipfile.ZipFile(falso, "w") as z:
		z.writestr("base/manifest/AndroidManifest.xml", "x")
	aab.generar = lambda pr, paq, ver, ll: falso
	prueba_play.ESTADO["paquetes"].add("com.danielstudio.bigotesveloces")

	print("== Publicar: primera vez ==")
	t1 = {"job_id": "j1", "user_id": "u1", "kind": "game_publish", "project_id": "p1", "project_files": files, "project_version": 1,
		"detail": {"modo": "primer_aab", "pista": "internal", "estudio": "Daniel Studio", "correo": "dani@x.com", "version_code": 0}}
	trabajador.atender(sb, t1, argparse.Namespace())
	fin = [f for f, _ in sb.rpcs if f in ("complete_publish_job", "fail_job")]
	check("termina bien", fin[-1:] == ["complete_publish_job"], str([p for f, p in sb.rpcs if f == "fail_job"])[:300])
	if fin[-1:] == ["complete_publish_job"]:
		r = sb.ultimo("complete_publish_job")
		check("paquete com.<estudio>.<juego> y version 100", r["p_play"]["paquete"] == "com.danielstudio.bigotesveloces"
			and r["p_play"]["version_code"] == 100 and r["p_play"]["estado"] == "primer_aab", str(r["p_play"]))
		check("guia y politica de privacidad publica", "pasos" in r["p_files"]["guia"] and "legal/p1/privacidad.html" in r["p_files"]["privacidad_url"]
			and "legal/p1/privacidad.html" in sb.archivos)
		pj = json.loads(sb.archivos.get("legal/p1/privacidad.json", b"{}"))
		check("politica en JSON para la web publica", pj.get("titulo") and "<h1>" in pj.get("cuerpo", "") and "<html" not in pj["cuerpo"])
		os.environ["ORQ_WEB"] = "https://dani.github.io/orquestador/"
		check("con web publica la URL es la pagina buena", trabajador.url_privacidad(sb.url, "p1") == "https://dani.github.io/orquestador/privacidad.html?j=p1")
		del os.environ["ORQ_WEB"]
		check("el .aab queda para descargar", any(k.endswith(".aab") for k in sb.archivos))
		check("llave de subida guardada cifrada y su huella anotada", "llaves/u1.llave" in sb.archivos
			and b"BEGIN" not in sb.archivos["llaves/u1.llave"] and sb.ultimo("set_play_key")["p_huella"])
		huella = sb.ultimo("set_play_key")["p_huella"]

		print("== Publicar: subida por la API ==")
		prueba_play.ESTADO["borrador"] = False
		t2 = dict(t1, job_id="j2", detail=dict(t1["detail"], modo="subir", pista="alpha", paquete="com.danielstudio.bigotesveloces", version_code=100))
		n_llaves = len([f for f, _ in sb.rpcs if f == "set_play_key"])
		trabajador.atender(sb, t2, argparse.Namespace())
		r = sb.ultimo("complete_publish_job")
		check("sube a prueba cerrada con version 101", r["p_play"].get("estado") == "subido" and r["p_play"]["version_code"] == 101
			and r["p_play"]["pista"] == "alpha", str(r["p_play"]))
		check("reutiliza la misma llave (no crea otra)", len([f for f, _ in sb.rpcs if f == "set_play_key"]) == n_llaves
			and r["p_play"]["huella_llave"] == huella)

	print("== Juego nuevo con boceto jugable ==")
	t0 = {"job_id": "0000bb00-0000-0000-0000-000000000000", "user_id": "u2", "kind": "game", "idea": "un robot que salta por un desguace lleno de chatarra"}
	opc0 = argparse.Namespace(simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512,
		apk=False, capturas=False, web=True, ficha=False, clip=False)
	trabajador.atender(sb, t0, opc0)
	check("juego nuevo terminado", [f for f, _ in sb.rpcs if f in ("complete_game_job", "fail_job")][-1:] == ["complete_game_job"],
		str([p for f, p in sb.rpcs if f == "fail_job"])[-300:])
	bocetos = [p["p_event"] for f, p in sb.rpcs if f == "job_progress" and p["p_event"].get("boceto")]
	## El boceto se sube y avisa antes del arte; con el juego ya guardado se borra (ocupa sitio y no sirve).
	check("boceto subido y avisado antes del arte", bool(bocetos) and bocetos[0]["boceto"].startswith("u2/0000bb00"), str(bocetos)[:200])
	check("boceto borrado al terminar", bool(bocetos) and bocetos[0]["boceto"] in getattr(sb, "borrados", [])
		and f"juegos/{bocetos[0]['boceto']}" not in sb.archivos, str(getattr(sb, "borrados", []))[:200])
	pasos = [p["p_event"]["paso"] for f, p in sb.rpcs if f == "job_progress" and p.get("p_job") == t0["job_id"]]
	check("el boceto llega antes que el arte", "boceto" in pasos and pasos.index("boceto") < pasos.index("arte"))

	print("== Agente programador (game_mod) ==")
	t4 = {"job_id": "0000aa04-0000-0000-0000-000000000000", "user_id": "u1", "kind": "game_mod", "project_id": "p1",
		"project_files": files, "project_version": 1, "detail": {"instruccion": "que salgan chispas doradas al empezar"}}
	opc = argparse.Namespace(simulado=True, arte_simulado=True, comfy="", crear="", editar="", lado=512,
		apk=False, capturas=False, web=False, ficha=False, clip=False)
	trabajador.atender(sb, t4, opc)
	fin = [f for f, _ in sb.rpcs if f in ("complete_change_job", "fail_job")]
	check("el mod termina como version nueva", fin[-1:] == ["complete_change_job"], str([p for f, p in sb.rpcs if f == "fail_job"])[-300:])
	if fin[-1:] == ["complete_change_job"]:
		r = sb.ultimo("complete_change_job")
		check("version 2 con el proyecto subido", r["p_version"] == 2 and f"juegos/{r['p_files']['proyecto']}" in sb.archivos, str(r["p_files"])[:200])
		import io
		with zipfile.ZipFile(io.BytesIO(sb.archivos[f"juegos/{r['p_files']['proyecto']}"])) as z:
			nombres = z.namelist()
			game = json.loads(z.read("game.json"))
		check("el zip lleva el mod y game.json lo carga", any(n.startswith("mods/") and n.endswith(".gd") for n in nombres)
			and any(m.startswith("res://mods/") for m in game.get("mods", [])), str(game.get("mods")))
		check("coste anotado sin cobrar de mas", float(r["p_cost_usd"]) >= 0.0)

		## Editor manual: el nivel dibujado a mano se usa tal cual y lo prueban los bots.
		check("la version trae los niveles para el editor", f"juegos/{r['p_files'].get('niveles', '')}" in sb.archivos)
		niv = json.loads(sb.archivos[f"juegos/{r['p_files']['niveles']}"])
		mapa = [str(f) for f in niv["mapas"][0]]
		y, x = next((y, x) for y in range(len(mapa) - 1, 0, -1) for x in range(4, len(mapa[y]))
			if mapa[y - 1][x] == "." and mapa[y][x] == "#")
		mapa[y - 1] = mapa[y - 1][:x] + "C" + mapa[y - 1][x + 1:]
		plan = {"resumen": "a mano", "operaciones": [{"op": "mapa", "indice": 0, "mapa": mapa}]}
		t5 = {"job_id": "0000aa05-0000-0000-0000-000000000000", "user_id": "u1", "kind": "game_change", "project_id": "p1", "project_files": r["p_files"],
			"project_version": 2, "detail": {"instruccion": "Edición a mano", "plan": plan}}
		trabajador.atender(sb, t5, opc)
		r5 = sb.ultimo("complete_change_job")
		check("nivel a mano: version nueva con el mapa tal cual", r5["p_version"] == 3
			and json.loads(sb.archivos[f"juegos/{r5['p_files']['niveles']}"])["mapas"][0] == mapa)
		malo = ["." * len(mapa[0])] * (len(mapa) - 1) + ["#" * len(mapa[0])]
		malo[2] = "G" + malo[2][1:]
		malo[len(malo) - 2] = malo[len(malo) - 2][:-1] + "P"
		malo[len(malo) - 3] = "#" * len(mapa[0])
		t6 = dict(t5, job_id="0000aa06-0000-0000-0000-000000000000", project_files=r5["p_files"], project_version=3,
			detail={"instruccion": "Edición a mano", "plan": {"resumen": "a mano", "operaciones": [{"op": "mapa", "indice": 0, "mapa": malo}]}})
		trabajador.atender(sb, t6, opc)
		f6 = sb.ultimo("fail_job")
		check("nivel a mano imposible: falla, lo explica y devuelve", f6 and "Tu nivel 1 no se puede jugar" in f6["p_error"] and f6["p_refund"] is True,
			str(f6)[:300])

	if a.completa:
		print("== Videos para redes ==")
		os.environ["ORQ_VOZ"] = "simulado"
		t3 = {"job_id": "j3", "user_id": "u1", "kind": "game_marketing", "project_id": "p1", "project_files": files,
			"project_version": 1, "detail": {"version": 1}}
		trabajador.atender(sb, t3, argparse.Namespace(simulado=True))
		ok = [f for f, _ in sb.rpcs][-1] == "complete_marketing_job"
		check("videos para redes terminados", ok)
		if ok:
			m = sb.ultimo("complete_marketing_job")["p_files"]
			check("3 videos subidos con portada", len(m["videos"]) == 3 and all(f"juegos/{v['mp4']}" in sb.archivos for v in m["videos"]))
	srv.shutdown()
	shutil.rmtree(tmp, ignore_errors=True)
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
