"""Del juego fabricado a Google Play en un paso.

	python -m play.publicador <proyecto> --estudio "Daniel Studio" --correo tu@correo.com --modo primer_aab
	python -m play.publicador <proyecto> --estudio "Daniel Studio" --correo tu@correo.com --modo subir --pista alpha

modo primer_aab  Prepara todo para la primera vez: .aab firmado, ficha validada, politica de
                 privacidad y la guia con cada dato y respuesta listos para copiar.
modo subir       Lo sube por la API de Google (cuenta de servicio en ORQ_PLAY_CUENTA, ruta al JSON
                 o el JSON entero): .aab a la pista + textos e imagenes en espanol e ingles.
"""

import argparse
import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
if str(RAIZ) not in sys.path:
	sys.path.insert(0, str(RAIZ))

import cadena  # noqa: E402
import ficha  # noqa: E402
import recursos  # noqa: E402
import versiones  # noqa: E402
from play import anuncios as anuncios_mod  # noqa: E402
from play import aab, api, cuestionarios, firma  # noqa: E402

PISTAS = ("internal", "alpha", "beta", "production")


class ErrorPublicar(Exception):
	pass


def cuenta_servicio() -> dict:
	v = os.environ.get("ORQ_PLAY_CUENTA", "")
	if not v:
		raise ErrorPublicar("Falta ORQ_PLAY_CUENTA (clave JSON de la cuenta de servicio de Orquestador)")
	return json.loads(Path(v).read_text(encoding="utf-8") if not v.lstrip().startswith("{") else v)


def correo_servicio() -> str:
	try:
		return cuenta_servicio()["client_email"]
	except (ErrorPublicar, KeyError, json.JSONDecodeError):
		return "la cuenta de servicio de Orquestador"


def asegurar_capturas(proyecto: Path) -> None:
	out = proyecto / "fabrica" / "capturas"
	if out.exists() and len(list(out.glob("*.png"))) >= 3:
		return
	cadena.evento("capturas", "inicio", "Haciendo capturas para la tienda...")
	cadena.godot(proyecto, "--resolution", "720x1280", "--rendering-driver", "opengl3", "--fixed-fps", "60",
		"res://qa/capturas.tscn", "--", f"--out={out}", timeout=300, display=True)
	if len(list(out.glob("*.png"))) < 2:
		raise ErrorPublicar("No se pudieron hacer las capturas del juego")


def preparar(proyecto: Path, estudio: str, correo: str, llave: dict, codigo_version: int, paquete: str = "",
		anuncios: bool | None = None, telemetria: bool | None = None, url_privacidad: str = "", admob: dict | None = None) -> dict:
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	## Anuncios reales solo con los ids de AdMob del usuario; si no, la version de tienda va sin anuncios.
	## Juego para ninos: anuncios marcados para menores (contenido apto y sin personalizar).
	con_anuncios = anuncios_mod.aplicar(proyecto, admob, para_ninos=diseno.get("publico") == "infantil")
	if anuncios is None:
		anuncios = con_anuncios
	if telemetria is None:
		## Se declara si el juego envia datos anonimos de partida (game.json -> telemetry).
		telemetria = "telemetry" in json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	paquete = paquete or cuestionarios.paquete_para(estudio, diseno)
	## Retos entre amigos: el enlace del reto lleva a la ficha de la tienda (se guarda para las
	## versiones siguientes, que rehacen game.json).
	cadena.fijar_enlace(proyecto, f"https://play.google.com/store/apps/details?id={paquete}")
	asegurar_capturas(proyecto)
	cadena.evento("ficha", "inicio", "Preparando icono, gráfico destacado, capturas y textos a la medida de Google...")
	f = ficha.generar(proyecto)
	if f["problemas"]:
		raise ErrorPublicar("La ficha no cumple las reglas de la tienda: " + "; ".join(f["problemas"][:4]))
	cadena.evento("ficha", "ok", "Ficha lista y comprobada")
	cadena.evento("aab", "inicio", "Compilando el .aab firmado para Android 16 (API 36)...")
	salida = aab.generar(proyecto, paquete, codigo_version, llave)
	cadena.evento("aab", "ok", "Juego compilado y firmado", mb=round(salida.stat().st_size / 1e6, 1))
	carpeta = proyecto / "fabrica" / "play"
	carpeta.mkdir(parents=True, exist_ok=True)
	(carpeta / "privacidad.html").write_text(cuestionarios.privacidad_html(diseno, correo, anuncios, telemetria), encoding="utf-8")
	(carpeta / "privacidad.json").write_text(cuestionarios.privacidad_json(diseno, correo, anuncios, telemetria), encoding="utf-8")
	g = cuestionarios.guia(diseno, paquete, correo, url_privacidad or "(se rellena al subir la política)", anuncios, telemetria)
	texto = json.dumps(g, ensure_ascii=False).replace("{CUENTA_SERVICIO}", correo_servicio())
	(carpeta / "guia.json").write_text(texto, encoding="utf-8")
	return {"anuncios": anuncios, "paquete": paquete, "aab": str(salida), "ficha": f["carpeta"], "guia": json.loads(texto),
		"privacidad": str(carpeta / "privacidad.html"), "privacidad_json": str(carpeta / "privacidad.json"), "huella_llave": llave.get("huella_sha256", ""), "version_code": codigo_version}


def subir(prep: dict, pista: str, notas: dict[str, str], correo: str = "") -> dict:
	if pista not in PISTAS:
		raise ErrorPublicar(f"Pista desconocida: {pista}")
	cadena.evento("subida_play", "inicio", "Subiendo a Google Play...")
	r = api.publicar(cuenta_servicio(), prep["paquete"], Path(prep["aab"]), Path(prep["ficha"]), pista, notas, correo,
		aviso=lambda m: cadena.evento("subida_play", "inicio", m))
	cadena.evento("subida_play", "ok", "En Google Play" + (" como borrador: envíalo a revisión en Play Console" if r["borrador"] else ""))
	return r


def main() -> int:
	p = argparse.ArgumentParser(description="Publica un juego fabricado en Google Play")
	p.add_argument("proyecto")
	p.add_argument("--estudio", required=True, help="Tu nombre de estudio (va en el nombre del paquete)")
	p.add_argument("--correo", required=True)
	p.add_argument("--modo", choices=["primer_aab", "subir"], default="primer_aab")
	p.add_argument("--pista", default="alpha", choices=PISTAS)
	p.add_argument("--paquete", default="")
	p.add_argument("--llave", help="Almacen .jks de subida (si no, se crea build/upload.jks)")
	p.add_argument("--clave", default="")
	p.add_argument("--version-code", type=int, default=0)
	a = p.parse_args()
	proyecto = Path(a.proyecto)
	llave = ({"ruta": a.llave, "alias": firma.ALIAS, "clave": a.clave, "huella_sha256": firma.huella(Path(a.llave), a.clave)}
		if a.llave else firma.crear(proyecto / "build" / "upload.jks", a.estudio))
	codigo = a.version_code or int(versiones.memoria(proyecto)["version"]) * 100
	try:
		prep = preparar(proyecto, a.estudio, a.correo, llave, codigo, a.paquete)
		print(json.dumps({k: prep[k] for k in ("paquete", "aab", "privacidad", "huella_llave", "version_code")}, indent=1, ensure_ascii=False))
		if a.modo == "subir":
			print(json.dumps(subir(prep, a.pista, {"es": "Nueva versión.", "en": "New version."}, a.correo), indent=1))
	except (ErrorPublicar, aab.ErrorAab, api.ErrorPlay, firma.ErrorFirma) as e:
		print("ERROR:", e)
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main())
