"""Dibujar por prompting (15 nov, «lo hacemos con RunPod y prompting»): un lote de piezas con sus
prompts en el endpoint de imagenes, para probar arte (interfaz, mapas, retratos) sin fabricar nada.

	ORQ_COMFY=runpod://<endpoint> python3 .github/scripts/dibujar.py lote.json carpeta_salida

lote.json: {"estilo": "texto de estilo comun", "chroma": "#FF00FF"?, "piezas": [
	{"id": "fondo", "prompt": "...", "ancho": 864, "alto": 1536, "motor": "qwen"|"zimage", "recorte": false, "semilla": 7}]}
recorte=true: se pide sobre el croma y se quita el fondo (piezas sueltas: iconos, marcos...).
Salida: <id>.png por pieza e informe.json (coste y fallos). Lo usa animaciones.yml (accion dibujar).
"""

import io
import json
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2] / "fabrica"
sys.path.insert(0, str(RAIZ))

from PIL import Image  # noqa: E402

from arte import post  # noqa: E402
from arte.runpod import TopeGPU, cliente as hacer_cliente  # noqa: E402
import os  # noqa: E402


def main() -> int:
	lote = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
	out = Path(sys.argv[2])
	out.mkdir(parents=True, exist_ok=True)
	cli = hacer_cliente(os.environ["ORQ_COMFY"])
	if hasattr(cli, "timeout"):
		cli.timeout = 600.0
	flujos = {m: json.loads((RAIZ / "plantillas" / "runpod" / f"crear_{m}.json").read_text(encoding="utf-8")) for m in ("qwen", "zimage")}
	chroma_hex = str(lote.get("chroma", "#FF00FF")).upper()
	chroma = tuple(int(chroma_hex[i:i + 2], 16) for i in (1, 3, 5))
	nombre_chroma = {"#FF00FF": "pure magenta", "#00FF00": "pure green"}.get(chroma_hex, chroma_hex)
	inf: dict = {"piezas": {}, "fallos": {}}
	t0 = time.time()
	for i, p in enumerate(lote["piezas"]):
		## Cada pieza puede llevar su propio estilo (los iconos sin el paisaje del fondo: si no, salen con escena).
		est = str(p.get("estilo", lote.get("estilo", "")))
		prompt = (est + ". " if est else "") + str(p["prompt"])
		if p.get("recorte"):
			prompt += f", isolated, centered, on a plain solid flat {nombre_chroma} background, no shadow, no text"
		try:
			datos = cli.generar(flujos[str(p.get("motor", "qwen"))], {"PROMPT": prompt, "SEED": int(p.get("semilla", 1000 + 37 * i)),
				"ANCHO": int(p.get("ancho", 1024)), "ALTO": int(p.get("alto", 1024))})[0]
		except TopeGPU as e:
			inf["fallos"][p["id"]] = str(e)
			break
		except Exception as e:  # noqa: BLE001 - una pieza que falla no para las demas
			inf["fallos"][p["id"]] = str(e)[:300]
			continue
		img = Image.open(io.BytesIO(datos)).convert("RGBA")
		if p.get("recorte"):
			img = post.quitar_fondo_borde(post.quitar_fondo(img, chroma))
			bb = post.caja(img)
			if bb:
				img = img.crop(bb)
		img.save(out / f"{p['id']}.png")
		inf["piezas"][p["id"]] = {"tam": list(img.size)}
		print(f"[dibujar] {p['id']}: {img.size}", flush=True)
	inf["segundos"] = round(time.time() - t0, 1)
	inf["usd"] = round(float(getattr(cli, "usd", 0.0)), 4)
	(out / "informe.json").write_text(json.dumps(inf, indent=1, ensure_ascii=False), encoding="utf-8")
	print(json.dumps(inf, ensure_ascii=False))
	return 0 if inf["piezas"] else 1


if __name__ == "__main__":
	sys.exit(main())
