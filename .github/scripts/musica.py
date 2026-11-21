"""Musica por encargo (21 nov, El Farero): un lote de pistas con su ambiente, en ACE-Step (endpoint de
imagenes de RunPod), con el mismo control de calidad que la fabrica (fabrica/arte/musica_ia.py).

	ORQ_COMFY=runpod://<endpoint> python3 .github/scripts/musica.py lote.json carpeta_salida

lote.json: {"familia": "cinematic orchestral", "pistas": [{"id": "menu", "ambiente": "...", "instrumentos": [...],
	"tempo": 80, "tonalidad": "D minor", "segundos": 75, "bucle": true, "papel": "menu"}]}
"""

import json
import os
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2] / "fabrica"
sys.path.insert(0, str(RAIZ))

from arte import musica_ia  # noqa: E402
from arte.runpod import cliente as hacer_cliente  # noqa: E402


def main() -> int:
	lote = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
	out = Path(sys.argv[2])
	out.mkdir(parents=True, exist_ok=True)
	cli = hacer_cliente(os.environ["ORQ_COMFY"])
	if hasattr(cli, "timeout"):
		cli.timeout = 900.0
	flujo = json.loads((RAIZ / "plantillas" / "runpod" / "musica_acestep.json").read_text(encoding="utf-8"))
	inf: dict = {"pistas": {}, "fallos": {}}
	t0 = time.time()
	for i, p in enumerate(lote["pistas"]):
		pid = str(p["id"])
		## Una "biblia" de una sola pista: asi cada una lleva su propio ambiente.
		biblia = {"musica": {"tempo": int(p.get("tempo", 100)), "tonalidad": str(p.get("tonalidad", "")),
			"ambiente": str(p["ambiente"]) + ", " + str(lote.get("familia", "")),
			"instrumentos": p.get("instrumentos", []),
			"pistas": [{"id": str(p.get("papel", pid)), "segundos": int(p.get("segundos", 75)), "bucle": bool(p.get("bucle", True))}]}}
		try:
			pistas, rep = musica_ia.generar(biblia, out / f"_{pid}", cli, flujo, 900 + 37 * i)
			ruta = next(iter(pistas.values()))
			ruta.rename(out / f"{pid}.ogg")
			inf["pistas"][pid] = next(iter(rep["pistas"].values()))
			print(f"[{i + 1}/{len(lote['pistas'])}] {pid} ok", flush=True)
		except Exception as e:  # noqa: BLE001
			inf["fallos"][pid] = str(e)[:300]
			print(f"[{i + 1}/{len(lote['pistas'])}] {pid} FALLO: {e}", flush=True)
	inf["segundos"] = round(time.time() - t0)
	(out / "informe.json").write_text(json.dumps(inf, indent=1, ensure_ascii=False), encoding="utf-8")
	print(json.dumps(inf, ensure_ascii=False)[:1500])
	return 0 if not inf["fallos"] else 1


if __name__ == "__main__":
	sys.exit(main())
