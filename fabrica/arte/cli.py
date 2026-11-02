"""Orquestador de la cadena de arte.

Uso:
	python -m arte.cli --biblia ejemplos/biblia_salto.json --comfy http://127.0.0.1:8188 \
		--crear plantillas/crear.json --editar plantillas/editar.json --godot ../orqkit

Flujo por personaje u objeto:
	1 - Ficha de referencia (crear).  2 - Cada frame editando la ficha (editar).
	3 - Postprocesado comun.          4 - QA; lo que falla se regenera con otra semilla.
	5 - Hojas de sprites.             6 - Tiles, efectos de sonido y exportacion a Godot.
"""

import argparse
import io
import json
import os
import sys
import time
from pathlib import Path

from PIL import Image

from . import biblia as bib
from . import godot_export, iconos, musica, musica_ia, portada, post, prompts, qa_arte, revision_ia, sfx, sfx_ia, skin, voces_ia
from .comfy import ComfyError
from .runpod import cliente as cliente_comfy

MAX_INTENTOS = 3


def _imagen(datos: bytes) -> Image.Image:
	return Image.open(io.BytesIO(datos)).convert("RGBA")


def _bytes_png(img: Image.Image) -> bytes:
	b = io.BytesIO()
	img.save(b, "PNG")
	return b.getvalue()


def _valores(enc: dict, intento: int, lado: int, ref_nombre: str | None = None) -> dict:
	v = {"PROMPT": enc["prompt"], "SEED": enc["semilla"] + intento * 7919, "ANCHO": lado, "ALTO": lado}
	if enc.get("negativo"):
		v["NEGATIVO"] = enc["negativo"]
	if ref_nombre:
		v["REF1"] = ref_nombre
	return v


def fabricar(args: argparse.Namespace) -> dict:
	inicio = time.time()
	biblia = bib.cargar(args.biblia)
	paleta = bib.paleta_rgb(biblia)
	chroma = bib.hex_a_rgb(biblia["estilo"]["fondo_chroma"])
	estilo = biblia["estilo"]
	pixel_art = estilo["familia"] == "pixel_art"
	cliente = cliente_comfy(args.comfy)
	wf_crear = json.loads(Path(args.crear).read_text(encoding="utf-8"))
	wf_editar = json.loads(Path(args.editar).read_text(encoding="utf-8"))
	salida = Path(args.salida)
	salida.mkdir(parents=True, exist_ok=True)

	encargos = prompts.encargos_imagen(biblia)
	(salida / "encargos_imagen.json").write_text(json.dumps(encargos, indent=1, ensure_ascii=False), encoding="utf-8")
	(salida / "encargos_audio.json").write_text(json.dumps(prompts.encargos_audio(biblia), indent=1, ensure_ascii=False), encoding="utf-8")

	informe: dict = {"juego": biblia["juego"]["titulo"], "generaciones": 0, "regeneradas": 0, "sprites": {}, "tiles": {}, "avisos": []}
	hojas: dict = {}
	tiles: dict = {}
	sprites = biblia["personajes"] + biblia.get("objetos", [])
	## 7 - Arte parcial (taller por instrucciones): solo los ids pedidos; el resto se conserva.
	solo = getattr(args, "solo", None)
	if solo is not None:
		sprites = [s for s in sprites if s["id"] in solo]

	for s in sprites:
		sid = s["id"]
		celda = tuple(s["tamano"])
		print(f"[arte] {sid}: ficha de referencia")
		enc_ficha = next(e for e in encargos if e["tipo"] == "ficha" and e["id"] == sid)
		## 13 - Dibujo del autor (revisado en el servidor): la ficha sale de editar SU imagen al
		## estilo del juego en vez de inventarla; los frames siguen como siempre desde la ficha.
		ref_autor = (getattr(args, "referencias", None) or {}).get(sid)
		if ref_autor:
			subida = cliente.subir_imagen(f"{sid}_autor.png", Path(ref_autor).read_bytes())
			enc_dibujo = dict(enc_ficha, prompt=prompts.desde_dibujo(enc_ficha["prompt"]))
			ficha = _imagen(cliente.generar(wf_editar, _valores(enc_dibujo, 0, args.lado, subida))[0])
			informe.setdefault("referencias", []).append(sid)
		else:
			ficha = _imagen(cliente.generar(wf_crear, _valores(enc_ficha, 0, args.lado))[0])
		informe["generaciones"] += 1
		## 12 - Revision visual con IA (Claude) de los personajes; si no pasa, otra semilla (una vez).
		gasto_rev = getattr(args, "revision", None)
		if gasto_rev is not None and s.get("rol") != "objeto":
			try:
				rev_ia = revision_ia.revisar(_bytes_png(ficha), s["descripcion"], estilo["descripcion"], gasto_rev)
				informe.setdefault("revision_ia", {})[sid] = rev_ia
				if not rev_ia["ok"]:
					print(f"[arte] {sid}: la revision visual pide repetir -> {rev_ia['problemas'] or rev_ia['parecido']}")
					ficha = _imagen(cliente.generar(wf_editar, _valores(enc_dibujo, 1, args.lado, subida))[0]) if ref_autor \
						else _imagen(cliente.generar(wf_crear, _valores(enc_ficha, 1, args.lado))[0])
					informe["generaciones"] += 1
					informe["regeneradas"] += 1
			except Exception as e:  # noqa: BLE001 - sin revision se sigue con los filtros automaticos
				informe.setdefault("revision_ia", {})[sid] = {"ok": None, "error": str(e)[:120]}
		ficha.save(salida / f"{sid}_ficha.png")
		ref_nombre = cliente.subir_imagen(f"{sid}_ficha.png", _bytes_png(ficha))
		ficha_proc, _ = post.procesar_animacion([ficha], ficha, celda, estilo, paleta, chroma)
		ficha_proc[0].save(salida / f"{sid}_ficha_{celda[0]}x{celda[1]}.png")

		hojas[sid] = {}
		informe["sprites"][sid] = {}
		for anim, cfg in s["animaciones"].items():
			encs = [e for e in encargos if e["tipo"] == "frame" and e["id"] == sid and e["anim"] == anim]
			crudos = [_imagen(cliente.generar(wf_editar, _valores(e, 0, args.lado, ref_nombre))[0]) for e in encs]
			informe["generaciones"] += len(encs)
			giratorio = anim == "spin"
			for intento in range(MAX_INTENTOS):
				frames, derivas = post.procesar_animacion(crudos, ficha, celda, estilo, paleta, chroma)
				rev = qa_arte.revisar_animacion(frames, ficha_proc[0], celda, derivas, paleta, chroma, pixel_art, giratorio)
				if rev["ok"]:
					break
				print(f"[arte] {sid}/{anim}: QA rechaza frames {sorted(rev['malos'])} -> {rev['malos']}")
				if intento == MAX_INTENTOS - 1:
					informe["avisos"].append(f"{sid}/{anim}: tras {MAX_INTENTOS} intentos quedan frames con problemas {rev['malos']}")
					break
				for i in rev["malos"]:
					crudos[i] = _imagen(cliente.generar(wf_editar, _valores(encs[i], intento + 1, args.lado, ref_nombre))[0])
					informe["generaciones"] += 1
					informe["regeneradas"] += 1
			hojas[sid][anim] = post.hoja(frames)
			informe["sprites"][sid][anim] = {"frames": len(frames), "qa_ok": rev["ok"], "deriva_media": round(sum(derivas) / len(derivas), 1)}

	for esc in biblia.get("escenarios", []):
		if solo is not None and esc["id"] not in solo:
			continue
		enc = next(e for e in encargos if e["tipo"] == "tile" and e["id"] == esc["id"])
		for intento in range(MAX_INTENTOS):
			crudo = _imagen(cliente.generar(wf_crear, _valores(enc, intento, args.lado))[0])
			informe["generaciones"] += 1
			tile, cost, der = post.procesar_tile(crudo, int(esc["tile"]), estilo, paleta)
			rev = qa_arte.revisar_tile(cost, der)
			if rev["ok"]:
				break
			informe["regeneradas"] += 1
		tiles[esc["id"]] = tile
		informe["tiles"][esc["id"]] = {"costura": round(cost, 1), "deriva": round(der, 1), "qa_ok": rev["ok"]}

	efectos: dict = {}
	if solo is None:
		print("[sonido] efectos procedurales")
		efectos = sfx.generar(biblia, salida / "sfx", prompts.semilla(biblia["juego"]["titulo"], "sfx"))
		flujo_s = str(getattr(args, "sfx", "") or "")
		if flujo_s:
			## Efectos con IA (Stable Audio 3): sustituyen a los procedurales que salgan bien.
			print("[sonido] Stable Audio 3")
			try:
				ia, inf_s = sfx_ia.generar(biblia, salida / "sfx_ia", cliente,
					json.loads(Path(flujo_s).read_text(encoding="utf-8")), prompts.semilla(biblia["juego"]["titulo"], "sfx_ia"))
				efectos.update(ia)
				informe["sfx_ia"] = inf_s
			except (ComfyError, OSError, musica_ia.MusicaError) as e:
				informe["sfx_aviso"] = f"Efectos con IA no disponibles ({str(e)[:160]}); se usan los procedurales"
	informe["sfx"] = sorted(efectos)
	## 8 - Musica de serie (menu, nivel, victoria): siempre al fabricar y en el taller si se pide.
	pistas: dict = {}
	if solo is None or "musica" in solo:
		semilla_m = prompts.semilla(biblia["juego"]["titulo"], "musica", biblia.get("musica", {}).get("ambiente", ""))
		flujo_m = str(getattr(args, "musica", "") or "")
		if flujo_m:
			## 9 - Musica con IA (ACE-Step 1.5 XL en la GPU); si algo falla, la procedural de siempre.
			print("[musica] ACE-Step 1.5 XL")
			try:
				pistas, inf_m = musica_ia.generar(biblia, salida / "musica", cliente,
					json.loads(Path(flujo_m).read_text(encoding="utf-8")), semilla_m)
				informe["musica_ia"] = inf_m
			except (musica_ia.MusicaError, ComfyError, OSError) as e:
				informe["musica_aviso"] = f"Musica con IA no disponible ({str(e)[:160]}); se usa la procedural"
				print("[musica]", informe["musica_aviso"])
				pistas = {}
		if not pistas:
			print("[musica] pistas procedurales")
			pistas = musica.generar(biblia, salida / "musica", semilla_m)
	informe["musica"] = sorted(pistas)
	## 10 - Voz del heroe dentro del juego (Chatterbox en RunPod), solo al fabricar o si se pide.
	voces: dict = {}
	cli_voz = None
	destino_voz = str(getattr(args, "voces", "") or "")
	if destino_voz and (solo is None or "voces" in solo):
		print("[voces] Chatterbox")
		try:
			from .runpod import RunPodCliente
			cli_voz = RunPodCliente(destino_voz, timeout=600, usd_seg=float(os.environ.get("ORQ_VOZ_USD_SEG", "0.00019")))
			voces, inf_v = voces_ia.generar(biblia, salida / "voces", cli_voz)
			informe["voces_ia"] = inf_v
			## Frases de la historia (heroe, rival y jefe con su tono).
			dial, inf_d = voces_ia.generar_dialogos(biblia, salida / "voces", cli_voz)
			voces.update(dial)
			informe["voces_historia"] = inf_d
		except Exception as e:  # noqa: BLE001 - sin voz el juego funciona igual
			informe["voces_aviso"] = f"Voces con IA no disponibles ({str(e)[:160]})"
	informe["voces"] = sorted(voces)
	## 11 - Fondos ilustrados (titulo y ficha de la tienda): solo al fabricar o si se pide.
	fondos: dict = {}
	if getattr(args, "fondos", False) and (solo is None or "fondos" in solo):
		print("[arte] fondos ilustrados")
		fondos, inf_f = portada.generar(biblia, salida / "portada", cliente, wf_crear,
			prompts.semilla(biblia["juego"]["titulo"], "portada"))
		informe["fondos"] = inf_f
		informe["generaciones"] += int(inf_f.get("generaciones", 0))
		## 13 - Interfaz dibujada (marco de paneles y botones) en el estilo del juego.
		print("[arte] interfaz dibujada")
		piel, inf_p = skin.generar(biblia, salida / "interfaz", cliente, wf_crear, prompts.semilla(biblia["juego"]["titulo"], "interfaz"))
		informe["interfaz"] = inf_p
		informe["generaciones"] += int(inf_p.get("generaciones", 0))
		fondos["piel"] = piel
		## 14 - Iconos de interfaz (vidas, estrellas, trofeos) en el estilo del juego.
		print("[arte] iconos de interfaz")
		ico, inf_i = iconos.generar(biblia, salida / "interfaz" / "iconos", cliente, wf_crear, prompts.semilla(biblia["juego"]["titulo"], "iconos"))
		informe["iconos"] = inf_i
		informe["generaciones"] += int(inf_i.get("generaciones", 0))
		fondos["iconos"] = ico

	if args.godot:
		m = godot_export.exportar(Path(args.godot), biblia, hojas, tiles, efectos, fusionar=solo is not None,
			quitar=getattr(args, "quitar", None) or [], pistas=pistas, voces=voces, fondos=fondos)
		informe["manifest"] = str(m)
	informe["segundos"] = round(time.time() - inicio, 1)
	## 1 - Coste real cuando el motor lo sabe (RunPod cobra por segundo de GPU).
	informe["motor"] = "runpod" if str(args.comfy).startswith("runpod://") else "comfyui"
	informe["usd"] = round(float(getattr(cliente, "usd", 0.0)) + float(getattr(cli_voz, "usd", 0.0)), 5)
	informe["segundos_gpu"] = round(float(getattr(cliente, "segundos_gpu", 0.0)), 1)
	(salida / "informe.json").write_text(json.dumps(informe, indent=1, ensure_ascii=False), encoding="utf-8")
	return informe


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Cadena de arte de Orquestador")
	p.add_argument("--biblia", required=True)
	p.add_argument("--comfy", default=os.environ.get("ORQ_COMFY", "http://127.0.0.1:8188"), help="http://... (ComfyUI) o runpod://<endpoint>")
	p.add_argument("--crear", required=True, help="Flujo de ComfyUI (formato API) para crear desde texto")
	p.add_argument("--editar", required=True, help="Flujo de ComfyUI (formato API) para editar desde la ficha")
	p.add_argument("--salida", default="salida_arte")
	p.add_argument("--godot", default="", help="Carpeta del proyecto Godot donde exportar")
	p.add_argument("--musica", default="", help="Flujo de ComfyUI para musica con IA (vacio = procedural)")
	p.add_argument("--fondos", action="store_true", help="Genera los fondos ilustrados (titulo y ficha)")
	p.add_argument("--voces", default="", help="runpod://<endpoint de voces> para la voz del heroe (vacio = sin voz)")
	p.add_argument("--sfx", default="", help="Flujo de ComfyUI para efectos con IA (vacio = procedurales)")
	p.add_argument("--lado", type=int, default=1024, help="Resolucion de generacion")
	args = p.parse_args(argv)
	try:
		informe = fabricar(args)
	except bib.BibliaInvalida as e:
		print(e, file=sys.stderr)
		return 2
	print(json.dumps({k: informe[k] for k in ("generaciones", "regeneradas", "segundos")}, ensure_ascii=False))
	for a in informe["avisos"]:
		print("AVISO:", a)
	return 0 if not informe["avisos"] else 1


if __name__ == "__main__":
	sys.exit(main())
