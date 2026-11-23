"""Narracion por encargo (23 nov): un lote de frases con una voz descrita con palabras (Qwen3-TTS VoiceDesign,
endpoint de voces de RunPod). Sale un .ogg por frase, recortado y con el volumen igualado.

	ORQ_VOCES=runpod://<endpoint> python3 .github/scripts/narrar.py lote.json carpeta_salida

lote.json: {"voz": "A calm old male narrator...", "idioma": "es", "lineas": [{"id": "esc_1", "texto": "..."}]}
"""

import base64
import json
import os
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2] / "fabrica"
sys.path.insert(0, str(RAIZ))

from arte import voces_ia  # noqa: E402
from arte.runpod import RunPodCliente  # noqa: E402


def main() -> int:
	lote = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
	out = Path(sys.argv[2])
	out.mkdir(parents=True, exist_ok=True)
	cli = RunPodCliente(os.environ["ORQ_VOCES"], timeout=900, usd_seg=float(os.environ.get("ORQ_VOZ_USD_SEG") or "0.000208"))
	inf: dict = {"lineas": {}, "fallos": {}}
	t0 = time.time()
	for i, l in enumerate(lote["lineas"]):
		lid = str(l["id"])
		try:
			r = cli.trabajo({"motor": "qwen", "texto": str(l["texto"]), "idioma": str(lote.get("idioma", "es")), "voz": str(l.get("voz", lote["voz"]))})
			if r.get("error") or not r.get("audio"):
				raise voces_ia.VozError(str(r.get("error") or "sin audio"))
			ruta = voces_ia.procesar(base64.b64decode(r["audio"]), 1.0, False, out / f"{lid}.ogg")
			inf["lineas"][lid] = {"bytes": ruta.stat().st_size}
			print(f"[{i + 1}/{len(lote['lineas'])}] {lid} ok", flush=True)
		except Exception as e:  # noqa: BLE001
			inf["fallos"][lid] = str(e)[:300]
			print(f"[{i + 1}/{len(lote['lineas'])}] {lid} FALLO: {e}", flush=True)
	inf["segundos"] = round(time.time() - t0)
	inf["usd"] = round(float(getattr(cli, "usd", 0.0)), 4)
	(out / "informe.json").write_text(json.dumps(inf, indent=1, ensure_ascii=False), encoding="utf-8")
	print(json.dumps({"ok": len(inf["lineas"]), "fallos": len(inf["fallos"]), "usd": inf["usd"]}))
	return 0 if inf["lineas"] else 1


if __name__ == "__main__":
	sys.exit(main())
