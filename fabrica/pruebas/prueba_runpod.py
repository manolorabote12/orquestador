"""Arte en RunPod serverless sin GPU ni cuenta: API de worker-comfyui simulada.

python -m pruebas.prueba_runpod

Comprueba con los flujos REALES (plantillas/runpod/*.json, aceptados por un ComfyUI de verdad):
1 - la cadena de arte entera funciona con --comfy runpod://<endpoint>;
2 - las imagenes de referencia (ficha del personaje) viajan en input.images;
3 - el coste sale del tiempo de GPU que devuelve RunPod;
4 - errores: clave mala, trabajo FAILED y trabajo colgado (se cancela para no pagar).
"""

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

import numpy as np  # noqa: E402

from arte import cli, musica_ia, voces_ia  # noqa: E402
from arte.comfy import ComfyError  # noqa: E402
from arte.runpod import RunPodCliente, cliente  # noqa: E402
from pruebas import runpod_simulado  # noqa: E402

fallos: list[str] = []


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	print(("  OK   " if ok else "  FAIL ") + nombre + (f"  ({detalle})" if detalle else ""))
	if not ok:
		fallos.append(nombre)


def main() -> int:
	srv = runpod_simulado.arrancar(0)
	puerto = srv.server_address[1]
	os.environ["ORQ_RUNPOD_API"] = f"http://127.0.0.1:{puerto}/v2"
	## Voces: el handler real de nube/voces con un Chatterbox falso detras del mismo RunPod simulado.
	from pruebas import prueba_voces_runpod as pv
	spec = importlib.util.spec_from_file_location("handler_voces", RAIZ.parent / "nube" / "voces" / "handler.py")
	hv = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(hv)
	hv.MODELO = pv.ChatterboxFalso()
	runpod_simulado.ESTADO["voz"] = hv.handler
	os.environ["RUNPOD_API_KEY"] = "rp-clave-prueba"
	os.environ["ORQ_RUNPOD_USD_SEG"] = "0.00031"
	salida = RAIZ / "salida_prueba" / "runpod"
	E = runpod_simulado.ESTADO
	try:
		print("== Cadena de arte en RunPod ==")
		check("runpod:// elige el cliente de RunPod", isinstance(cliente("runpod://abc123"), RunPodCliente))
		inf = cli.fabricar(argparse.Namespace(
			biblia=str(RAIZ / "ejemplos" / "biblia_salto.json"), comfy="runpod://orq-imagen",
			crear=str(RAIZ / "plantillas" / "runpod" / "crear_zimage.json"),
			editar=str(RAIZ / "plantillas" / "runpod" / "editar_klein.json"),
			salida=str(salida), godot="", lado=512, musica=str(RAIZ / "plantillas" / "runpod" / "musica_acestep.json"),
			sfx=str(RAIZ / "plantillas" / "runpod" / "sfx_stableaudio.json"), voces="runpod://orq-voces", fondos=True))
		check("genera todas las imagenes", inf["generaciones"] > 5 and E["peticiones"] == inf["generaciones"] + 12,
			f"{inf['generaciones']} imagenes, {E['peticiones']} trabajos")
		check("el workflow llega completo (LoadImage con su imagen, SaveImage)", not E["errores"], str(E["errores"][:3]))
		check("la ficha viaja como referencia en las ediciones", E["refs"] > 0, f"{E['refs']} referencias")
		check("espera el arranque en frio (IN_PROGRESS) y sigue", E["consultas"] >= 2 * E["peticiones"])
		esperado = round(inf["generaciones"] * 2.3 * 0.00031, 5)
		con_musica = esperado + 12 * 4.1 * 0.00031 + 3 * 1.8 * 0.00019
		check("coste real por segundo de GPU", inf["motor"] == "runpod" and abs(inf["usd"] - con_musica) < 1e-4,
			f"{inf['usd']} USD, {inf['segundos_gpu']} s GPU")
		check("sin avisos de calidad", not inf["avisos"], str(inf["avisos"][:2]))
		check("deja sprites en disco", any(salida.rglob("*.png")))

		print("== Musica con IA (ACE-Step 1.5 XL) ==")
		mi = inf.get("musica_ia") or {}
		check("compone menu, nivel y victoria", sorted(mi.get("pistas", {})) == ["menu", "nivel", "victoria"], str(inf.get("musica_aviso", "")))
		oggs = sorted(p.name for p in (salida / "musica").glob("*.ogg"))
		check("pistas en OGG para Godot", oggs == ["menu.ogg", "nivel.ogg", "victoria.ogg"], str(oggs))
		a = musica_ia.decodificar((salida / "musica" / "nivel.ogg").read_bytes())
		salto = float(np.max(np.abs(a[0] - a[-1])))
		check("el bucle no salta al repetir", salto < 0.15, f"salto {salto:.3f}")
		check("victoria corta y sin bucle", mi["pistas"]["victoria"]["bucle"] is False and mi["pistas"]["victoria"]["segundos"] <= 12.5)
		check("la musica tambien se cobra por segundo de GPU", inf["usd"] > esperado, f"{inf['usd']} USD con musica")
		print("== Efectos de sonido con IA (Stable Audio 3) ==")
		si = inf.get("sfx_ia") or {}
		check("los 9 efectos del juego con IA", len(si.get("efectos", {})) == 9 and not si.get("fallidos"), str(si.get("fallidos") or inf.get("sfx_aviso")))
		import wave as _w
		with _w.open(str(salida / "sfx_ia" / "coin.wav")) as w:
			dur_coin = w.getnframes() / w.getframerate()
			mono = w.getnchannels() == 1
		check("efecto recortado a su duracion y mono", mono and dur_coin <= 0.75, f"{dur_coin:.2f} s")
		print("== Voz del heroe (Chatterbox) ==")
		vi = inf.get("voces_ia") or {}
		check("inicio, victoria y derrota", sorted(vi.get("voces", {})) == ["derrota", "inicio", "victoria"], str(vi.get("fallidas") or inf.get("voces_aviso")))
		check("frases de la Biblia", vi.get("voces", {}).get("victoria") == "¡Una tuerca más!")
		check("tono del personaje: robot -> metalico", voces_ia.tono("small round brass robot")[1] and voces_ia.tono("tiny cat")[0] > 1)
		print("== Voces de la historia ==")
		import base64 as _b64
		import io as _io
		import wave as _wv
		def _seno() -> str:
			buf = _io.BytesIO()
			with _wv.open(buf, "wb") as w:
				w.setnchannels(1)
				w.setsampwidth(2)
				w.setframerate(24000)
				w.writeframes((np.sin(np.arange(24000) * 0.05) * 9000).astype(np.int16).tobytes())
			return _b64.b64encode(buf.getvalue()).decode()
		pedidas = []
		class _Cli:
			def trabajo(self, entrada: dict) -> dict:
				pedidas.append(entrada["texto"])
				return {"error": "sin GPU"} if "falla" in entrada["texto"] else {"audio": _seno()}
		bib = {"dialogos": [{"clave": "d0_0", "texto": "¡Allá voy!", "quien": "heroe", "descripcion": "tiny cat"},
			{"clave": "d0_1", "texto": "Ni lo sueñes.", "quien": "jefe", "descripcion": "huge rat king"},
			{"clave": "d1_0", "texto": "esto falla", "quien": "rival", "descripcion": "robot"}]}
		dv, di = voces_ia.generar_dialogos(bib, salida / "voces_hist", _Cli(), ya={"d0_0"})
		check("graba las frases que faltan con su clave", sorted(dv) == ["d0_1"] and pedidas == ["Ni lo sueñes.", "esto falla"], str(sorted(dv)))
		check("una frase que falla no para las demas", "d1_0" in di["fallidas"])
		print("== Fondos ilustrados ==")
		fi = inf.get("fondos") or {}
		check("fondo vertical (titulo), horizontal (ficha) y de nivel", sorted(fi.get("fondos", {})) == ["horizontal", "nivel", "vertical"], str(fi.get("fallidos")))
		from PIL import Image as _I
		check("fondo vertical 864x1536", _I.open(salida / "portada" / "fondo_vertical.png").size == (864, 1536))
		from arte import portada
		check("el QA rechaza un fondo croma", "fondo croma" in portada.revisar(_I.new("RGB", (64, 64), (255, 0, 255))))
		print("== Musica: reglas ==")
		check("tonalidad 're menor' -> D minor", musica_ia.tonalidad("re menor") == "D minor")
		check("tonalidad 'Bb major' y 'F#m'", musica_ia.tonalidad("Bb major") == "Bb major" and musica_ia.tonalidad("F#m") == "F# minor")
		check("tonalidad rara -> C major", musica_ia.tonalidad("cosmica") == "C major")
		check("detecta silencio", "casi en silencio" in musica_ia.revisar(np.zeros((44100 * 10, 2), np.float32), 10))
		check("detecta pista cortada", any("cortada" in x for x in musica_ia.revisar(np.full((44100 * 3, 2), 0.1, np.float32), 10)))

		print("== Errores ==")
		wf = json.loads((RAIZ / "plantillas" / "runpod" / "crear_zimage.json").read_text(encoding="utf-8"))
		valores = {"PROMPT": "un gato", "SEED": 1, "ANCHO": 512, "ALTO": 512}
		try:
			RunPodCliente("runpod://x", clave="mala").generar(wf, valores)
			check("clave mala da error claro", False)
		except ComfyError as e:
			check("clave mala da error claro", "401" in str(e), str(e)[:60])
		E["fallar"] = 1
		try:
			RunPodCliente("runpod://x").generar(wf, valores)
			check("trabajo FAILED da error con el motivo", False)
		except ComfyError as e:
			check("trabajo FAILED da error con el motivo", "out of memory" in str(e), str(e)[:60])
		E["colgar"] = 1
		try:
			RunPodCliente("runpod://x", timeout=1.5).generar(wf, valores)
			check("trabajo colgado se cancela (no se paga de mas)", False)
		except ComfyError:
			check("trabajo colgado se cancela (no se paga de mas)", E["canceladas"] == 1)
		os.environ.pop("RUNPOD_API_KEY")
		try:
			RunPodCliente("runpod://x")
			check("sin clave no arranca", False)
		except ComfyError as e:
			check("sin clave no arranca", "RUNPOD_API_KEY" in str(e))
	finally:
		srv.shutdown()
	print(f"== {len(fallos)} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
