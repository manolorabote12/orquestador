"""Lo ejecuta el Mac de GitHub Actions (.github/workflows/ios.yml) para UN trabajo de App Store.

	python nube/ios/mac.py <id del trabajo>
Variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ORQ_LLAVES_SECRETO, GODOT (ruta al ejecutable).
"""

import json
import os
import shutil
import sys
import tempfile
import time
import traceback
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2] / "fabrica"
sys.path.insert(0, str(RAIZ))

import cadena  # noqa: E402
import trabajador  # noqa: E402
from apple import ios, llave  # noqa: E402
from play import cuestionarios  # noqa: E402


def main(job: str, sb=None) -> int:
	sb = sb or trabajador.Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
	filas = sb.rpc("claim_ios_job", p_job=job, p_worker="github-mac") or []
	if not filas:
		print("Trabajo no encontrado o ya en marcha", file=sys.stderr)
		return 1
	t = filas[0]
	d = t.get("detail") or {}

	def avisar(ev: dict) -> None:
		sb.rpc("job_progress", p_job=job, p_event={k: v for k, v in ev.items() if k in ("paso", "estado", "mensaje", "t")})

	cadena.oyentes.append(avisar)
	tmp = Path(tempfile.mkdtemp(prefix="orq_ios_"))
	try:
		cadena.evento("ios", "inicio", "Preparando el juego para iPhone y iPad...")
		proyecto = trabajador._abrir_proyecto(sb, {**t, "job_id": job}, tmp)
		diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
		bundle = d.get("bundle") or cuestionarios.paquete_para(d.get("estudio") or "orquestador", diseno)
		clave = tmp / "AuthKey.p8"
		clave.write_text(llave.descifrar(sb.bajar(d["clave_ruta"], tmp / "clave.bin", bucket="llaves").read_bytes()), encoding="utf-8")
		os.chmod(clave, 0o600)
		nombre = ios.nombre_xcode(diseno["titulo"])
		build = int(d.get("build") or 1)
		ios.poner_preset(proyecto, d["equipo"], bundle, "1.0", build, nombre)
		ios.compilar_y_subir(proyecto, d["equipo"], bundle, clave, d["clave_id"], d["emisor"], nombre,
			godot=os.environ.get("GODOT", "godot"), aviso=lambda m: cadena.evento("ios", "inicio", m))
		cadena.evento("ios", "ok", "En App Store Connect: aparecerá en TestFlight en unos minutos")
		sb.rpc("complete_ios_job", p_job=job, p_cost_usd=0.3, p_ios={"bundle": bundle, "build": build, "estado": "subido",
			"subido_en": int(time.time())})
		return 0
	except Exception as e:  # noqa: BLE001
		traceback.print_exc()
		try:
			sb.rpc("fail_job", p_job=job, p_error=str(e)[:400] or e.__class__.__name__, p_cost_usd=0.0, p_refund=True)
		except Exception as e2:  # noqa: BLE001
			print("No se pudo cerrar el trabajo:", e2, file=sys.stderr)
		return 1
	finally:
		cadena.oyentes.remove(avisar)
		shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
	sys.exit(main(sys.argv[1]))
