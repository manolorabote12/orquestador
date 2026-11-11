"""Trabajador de la fabrica: toma juegos de la cola de Supabase, los fabrica y sube el resultado.

	export SUPABASE_URL=https://xxxx.supabase.co
	export SUPABASE_SERVICE_ROLE_KEY=...        (secreto: solo en la maquina del trabajador)
	export ANTHROPIC_API_KEY=...                (directora real; o --simulado)
	python -m trabajador --comfy http://127.0.0.1:8188 --apk --web

Ciclo:
	1 - claim_game_job: toma el trabajo mas antiguo de la cola (varios trabajadores no se pisan).
	2 - Fabrica el juego con la cadena; cada paso se manda a job_progress (Chispa lo cuenta).
	3 - Sube APK, paquete web (index.pck), ficha de Google Play, clip para redes, capturas, icono, informe y el proyecto de Godot al almacen 'juegos'.
	4 - complete_game_job: crea el proyecto y guarda el coste real. Si algo falla, fail_job
	    devuelve las tuercas (con el tope diario) y guarda lo que costo de verdad.
	5 - Cada 5 minutos llama a expire_stuck_jobs (trabajos colgados o en cola demasiado tiempo).
"""

import argparse
import json
import mimetypes
import os
import shutil
import socket
import sys
import tempfile
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

import cadena
import cambio
import versiones
from director import llm


class Supabase:
	def __init__(self, url: str, clave: str):
		self.url = url.rstrip("/")
		self.clave = clave

	def _peticion(self, metodo: str, ruta: str, datos: bytes | None, tipo: str, extra: dict | None = None) -> bytes:
		cab = {"apikey": self.clave, "Authorization": f"Bearer {self.clave}", "Content-Type": tipo}
		cab.update(extra or {})
		req = urllib.request.Request(self.url + ruta, data=datos, method=metodo, headers=cab)
		for intento in range(4):
			try:
				with urllib.request.urlopen(req, timeout=120) as r:
					return r.read()
			except urllib.error.HTTPError as e:
				cuerpo = e.read().decode("utf-8", "replace")[:400]
				if e.code >= 500 and intento < 3:
					time.sleep(2 * (intento + 1))
					continue
				raise RuntimeError(f"Supabase {metodo} {ruta}: HTTP {e.code} {cuerpo}") from e
			except urllib.error.URLError as e:
				if intento < 3:
					time.sleep(2 * (intento + 1))
					continue
				raise RuntimeError(f"Supabase sin conexion: {e}") from e
		raise RuntimeError("Supabase: reintentos agotados")

	def rpc(self, funcion: str, **params: object) -> object:
		r = self._peticion("POST", f"/rest/v1/rpc/{funcion}", json.dumps(params).encode("utf-8"), "application/json")
		return json.loads(r.decode("utf-8")) if r else None

	def bajar(self, ruta: str, destino: Path, bucket: str = "juegos") -> Path:
		datos = self._peticion("GET", f"/storage/v1/object/{bucket}/" + urllib.parse.quote(ruta), None, "application/octet-stream")
		destino.write_bytes(datos)
		return destino

	def subir(self, ruta: str, archivo: Path, bucket: str = "juegos") -> str:
		tipo = mimetypes.guess_type(archivo.name)[0] or "application/octet-stream"
		if archivo.suffix == ".apk":
			tipo = "application/vnd.android.package-archive"
		elif archivo.suffix == ".wasm":
			tipo = "application/wasm"
		elif archivo.suffix in (".js", ".mjs"):
			tipo = "text/javascript"
		destino = f"/storage/v1/object/{bucket}/" + urllib.parse.quote(ruta)
		self._peticion("POST", destino, archivo.read_bytes(), tipo, {"x-upsert": "true"})
		return ruta

	def listar(self, prefijo: str, bucket: str = "juegos", limite: int = 200) -> list[dict]:
		"""Archivos de una carpeta del almacen (nombre y fecha)."""
		r = self._peticion("POST", f"/storage/v1/object/list/{bucket}",
			json.dumps({"prefix": prefijo, "limit": limite, "sortBy": {"column": "created_at", "order": "asc"}}).encode("utf-8"), "application/json")
		return json.loads(r.decode("utf-8")) if r else []

	def borrar(self, rutas: list[str], bucket: str = "juegos") -> None:
		"""Borra archivos del almacen. Nunca para la fabrica: si falla, solo se avisa."""
		rutas = [r for r in rutas if r]
		if not rutas:
			return
		try:
			self._peticion("DELETE", f"/storage/v1/object/{bucket}", json.dumps({"prefixes": rutas}).encode("utf-8"), "application/json")
		except Exception as e:  # noqa: BLE001
			print(f"[trabajador] no se pudieron borrar {len(rutas)} archivos viejos: {e}", flush=True)


## Al guardar una version nueva, de la anterior sobra lo pesado: el proyecto nuevo ya lleva todo el
## historial (volver atras sale de ahi) y la app solo ensena los archivos de la version actual.
PESADOS = ("apk", "web", "clip", "ficha", "proyecto")


def borrar_seguro(sb: "Supabase", rutas: list[str]) -> None:
	"""Limpieza despues de cerrar un trabajo: jamas puede convertir un juego terminado en un fallo."""
	try:
		sb.borrar(rutas)
	except Exception as e:  # noqa: BLE001
		print(f"[trabajador] limpieza omitida: {e}", flush=True)


def limpiar_version_anterior(sb: "Supabase", previos: dict, nuevos: dict) -> None:
	borrar_seguro(sb, [previos.get(k) for k in PESADOS if previos.get(k) and previos.get(k) != nuevos.get(k)])


## Cache del arte (cadena.clave_arte): si un juego falla despues de dibujar, el reintento con el mismo
## diseno recupera el arte en vez de volver a pagar la GPU. Se borra al terminar bien y a los 3 dias.
CARPETA_CACHE = "cache_arte"
DIAS_CACHE = 3


class CacheArte:
	def __init__(self, sb: "Supabase"):
		self.sb = sb

	@staticmethod
	def ruta(clave: str) -> str:
		return f"{CARPETA_CACHE}/{clave}.zip"

	def bajar(self, clave: str, destino: Path) -> bool:
		try:
			self.sb.bajar(self.ruta(clave), destino)
			return destino.exists() and destino.stat().st_size > 0
		except Exception:  # noqa: BLE001 - no esta (lo normal): se dibuja
			return False

	def subir(self, clave: str, archivo: Path) -> None:
		if archivo.stat().st_size > LIMITE_SUBIDA:
			print(f"[trabajador] cache de arte demasiado grande ({archivo.stat().st_size // 1048576} MB): no se guarda", flush=True)
			return
		self.sb.subir(self.ruta(clave), archivo)


def limpiar_cache_arte(sb: "Supabase", dias: int = DIAS_CACHE) -> int:
	"""Borra la cache de arte de mas de N dias (de juegos que fallaron y nadie reintento)."""
	import datetime as _dt
	limite = _dt.datetime.now(_dt.timezone.utc) - _dt.timedelta(days=dias)
	viejos = []
	for f in sb.listar(CARPETA_CACHE + "/") or []:
		try:
			fecha = _dt.datetime.fromisoformat(str(f.get("created_at", "")).replace("Z", "+00:00"))
		except ValueError:
			continue
		if f.get("name") and fecha < limite:
			viejos.append(f"{CARPETA_CACHE}/{f['name']}")
	borrar_seguro(sb, viejos)
	return len(viejos)


def guardar_diseno_fallido(sb: "Supabase", job: str, tmp: Path) -> None:
	"""Si el juego falla, su diseno queda en el trabajo: «Reintentar» lo fabrica igual (y recupera el arte)."""
	try:
		disenos = sorted(tmp.glob("*/fabrica/diseno.json"))
		if disenos:
			sb.rpc("guardar_diseno", p_job=job, p_spec=json.loads(disenos[0].read_text(encoding="utf-8")))
	except Exception as e:  # noqa: BLE001
		print(f"[trabajador] no se pudo guardar el diseno para reintentar: {e}", flush=True)


## CPU de la fabrica en RunPod (4 vCPU serverless): se suma al coste real de cada trabajo.
CPU_USD_SEG = float(os.environ.get("ORQ_CPU_USD_SEG") or "0.000061")


def coste_real(gasto: "llm.Gasto", t0: float) -> float:
	"""IA + GPU (todas las maquinas) + CPU de la fabrica. Lo que de verdad ha costado el trabajo."""
	from arte import runpod as _runpod
	return round(gasto.usd + _runpod.GASTO["usd"] + (time.time() - t0) * CPU_USD_SEG, 4)


def oyente_progreso(sb: "Supabase", job: str, campos: tuple):
	"""Manda el avance a la app. Si el servidor ya dio el trabajo por perdido (caducado), se avisa a la
	fabrica para que no siga gastando GPU en algo que nadie va a recibir."""
	from arte import runpod as _runpod

	def avisar(ev: dict) -> None:
		ligero = {k: v for k, v in ev.items() if k in campos}
		sigue = sb.rpc("job_progress", p_job=job, p_event=ligero)
		if sigue is False:
			_runpod.GASTO["cancelado"] = True
			print(f"[trabajador] {job}: el servidor lo dio por terminado; se deja de gastar", flush=True)
	return avisar


## Supabase gratis no admite archivos de mas de 50 MB.
LIMITE_SUBIDA = int(os.environ.get("ORQ_LIMITE_SUBIDA_MB") or "49") * 1024 * 1024


def comprimir_proyecto(proyecto: Path, destino: Path) -> Path:
	_comprimir(proyecto, destino, con_versiones=True)
	if destino.stat().st_size > LIMITE_SUBIDA:
		## Si aun asi no cabe, se guardan solo el juego actual y su memoria (sin las versiones viejas).
		print(f"[trabajador] proyecto de {destino.stat().st_size // 1048576} MB: se guarda sin versiones antiguas", flush=True)
		_comprimir(proyecto, destino, con_versiones=False)
	return destino


def _comprimir(proyecto: Path, destino: Path, con_versiones: bool) -> Path:
	"""Proyecto de Godot listo para abrir (sin cache, compilaciones ni el arte en bruto). Incluye
	la memoria y las versiones (fabrica/memoria.json y fabrica/versiones): asi se puede seguir
	cambiando y volver atras."""
	## Las instantaneas de versiones repiten casi todo el juego: un archivo identico al del juego
	## actual no se guarda dos veces (Supabase gratis no admite archivos de mas de 50 MB).
	iguales: list[str] = []
	with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED) as z:
		for f in proyecto.rglob("*"):
			rel = f.relative_to(proyecto)
			if f.is_dir() or rel.parts[0] in (".godot", "build", "android") or (rel.parts[0] == "fabrica" and len(rel.parts) > 1 and rel.parts[1] == "arte"):
				continue
			if rel.parts[:2] == ("fabrica", "ficha"):
				continue
			if rel.parts[:2] == ("fabrica", "versiones") and not con_versiones:
				continue
			if rel.parts[:2] == ("fabrica", "versiones") and len(rel.parts) > 3:
				vivo = proyecto.joinpath(*rel.parts[3:])
				if vivo.is_file() and vivo.stat().st_size == f.stat().st_size and vivo.read_bytes() == f.read_bytes():
					iguales.append(rel.as_posix())
					continue
			z.write(f, rel.as_posix())
		z.writestr(IGUALES, json.dumps(iguales))
	return destino


IGUALES = "fabrica/versiones_iguales.json"


def descomprimir_proyecto(zipf: Path, proyecto: Path) -> None:
	"""Al reves que comprimir_proyecto: vuelve a poner en las versiones los archivos que eran iguales."""
	with zipfile.ZipFile(zipf) as z:
		z.extractall(proyecto)
	lista = proyecto / IGUALES
	if lista.exists():
		for rel in json.loads(lista.read_text(encoding="utf-8")):
			partes = Path(rel).parts
			origen = proyecto.joinpath(*partes[3:])
			if origen.is_file():
				(proyecto / rel).parent.mkdir(parents=True, exist_ok=True)
				shutil.copy2(origen, proyecto / rel)


def _subir_version(sb: Supabase, carpeta: str, inf: dict, proyecto: Path, tmp: Path) -> dict:
	"""Sube APK, capturas, icono, informe y proyecto de una version. Devuelve sus rutas."""
	archivos: dict = {"capturas": [], "version": inf.get("version", 1)}
	cadena.evento("subida", "inicio", "Guardando tu juego en la nube...")
	def opcional(clave: str, destino: str, origen: Path) -> None:
		try:
			archivos[clave] = sb.subir(destino, origen)
		except Exception as e:  # noqa: BLE001 - sin este archivo el juego funciona igual
			mb = origen.stat().st_size / 1048576 if origen.exists() else 0
			archivos.setdefault("avisos", []).append(f"{clave}: no se pudo guardar ({mb:.0f} MB): {str(e)[:120]}")
			print(f"[trabajador] {clave} no subido ({mb:.0f} MB): {e}", flush=True)

	if inf.get("apk"):
		opcional("apk", f"{carpeta}/{Path(inf['apk']).name}", Path(inf["apk"]))
	if inf.get("web"):
		## 1 - Solo el paquete del juego: el motor web es comun y esta en el bucket "motor".
		archivos["web"] = sb.subir(f"{carpeta}/web/index.pck", Path(inf["web"]))
	if inf.get("clip"):
		opcional("clip", f"{carpeta}/clip_vertical.mp4", Path(inf["clip"]))
	if inf.get("ficha"):
		opcional("ficha", f"{carpeta}/ficha_google_play.zip", Path(inf["ficha"]))
	for c in inf.get("capturas", []):
		archivos["capturas"].append(sb.subir(f"{carpeta}/capturas/{Path(c).name}", Path(c)))
	archivos["icono"] = sb.subir(f"{carpeta}/icono.png", proyecto / "icon.png")
	## Niveles de esta version para el editor manual de la app (mapas, nombres y genero).
	game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	dis = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	niveles = proyecto / "fabrica" / "niveles.json"
	niveles.write_text(json.dumps({"genero": dis.get("genero", "plataformas"), "nombres": [lv.get("name", "") for lv in game["levels"]],
		"mapas": [lv["map"] for lv in game["levels"]], "enemigos": [e["tipo"] for e in dis.get("enemigos", [])],
		"jefe": bool(dis.get("jefe"))}, ensure_ascii=False), encoding="utf-8")
	archivos["niveles"] = sb.subir(f"{carpeta}/niveles.json", niveles)
	informe = proyecto / "fabrica" / "informe.json"
	informe.write_text(json.dumps(inf, indent=1, ensure_ascii=False, default=str), encoding="utf-8")
	archivos["informe"] = sb.subir(f"{carpeta}/informe.json", informe)
	nombre = proyecto.name + "_godot.zip"
	archivos["proyecto"] = sb.subir(f"{carpeta}/{nombre}", comprimir_proyecto(proyecto, tmp / nombre))
	cadena.evento("subida", "ok", "Juego guardado")
	return archivos


def atender_cambio(sb: Supabase, trabajo: dict, opciones: argparse.Namespace) -> None:
	"""Cambio por instruccion o vuelta a una version: baja la ultima version, la cambia y sube la nueva."""
	job = trabajo["job_id"]
	usuario = trabajo["user_id"]
	detalle = trabajo.get("detail") or {}
	print(f"[trabajador] {trabajo['kind']} {job}: {detalle.get('instruccion', detalle.get('version', ''))}", flush=True)
	t0 = time.time()
	avisar = oyente_progreso(sb, job, ("paso", "estado", "mensaje", "t", "titulo", "imagenes", "version", "adelanto"))

	cadena.oyentes.append(avisar)
	tmp = Path(tempfile.mkdtemp(prefix="orq_cambio_"))
	usd = 0.0
	try:
		archivos_previos = trabajo.get("project_files") or {}
		if not archivos_previos.get("proyecto"):
			raise RuntimeError("El juego no tiene proyecto guardado")
		cadena.evento("preparar", "inicio", "Abriendo tu juego...")
		zipf = sb.bajar(archivos_previos["proyecto"], tmp / "previo.zip")
		proyecto = tmp / Path(archivos_previos["proyecto"]).name.replace("_godot.zip", "")
		descomprimir_proyecto(zipf, proyecto)
		mem = versiones.memoria(proyecto)
		if int(mem["version"]) != int(trabajo.get("project_version") or 0):
			raise RuntimeError(f"Versiones desalineadas: proyecto v{mem['version']}, servidor v{trabajo.get('project_version')}")
		ruta_adelanto = f"{usuario}/{trabajo['project_id']}/adelanto/index.pck"
		comunes = dict(proyecto=str(proyecto), simulado=opciones.simulado, arte_simulado=opciones.arte_simulado,
			comfy=opciones.comfy, crear=opciones.crear, editar=opciones.editar, lado=opciones.lado,
			semilla=int(job.replace("-", "")[:6], 16) % 100000, slug="", apk=opciones.apk, capturas=opciones.capturas, web=opciones.web, ficha=opciones.ficha,
			## Un cambio no vuelve a grabar el clip de redes (40 s de espera en cada cambio): la version
			## nueva hereda el que ya tenia. Los videos nuevos se piden aparte (estudio de marketing).
			clip=False,
			## Jugar el cambio cuanto antes: en cuanto los bots lo dan por bueno se sube la version para
			## jugar y la app la ofrece; el APK, las capturas y la ficha siguen mientras tanto.
			adelanto=lambda pck: sb.subir(ruta_adelanto, pck))
		if trabajo["kind"] == "game_restore":
			inf = cambio.volver(argparse.Namespace(volver=int(detalle["version"]), **comunes))
		elif trabajo["kind"] == "game_mod":
			inf = cambio.programar(argparse.Namespace(instruccion=detalle.get("instruccion", ""), **comunes))
			usd = float(inf.get("coste_usd", {}).get("total", 0.0))
		else:
			if any(o.get("referencia") for o in (detalle.get("plan") or {}).get("operaciones", [])):
				_bajar_referencia(sb, usuario, trabajo["project_id"], proyecto, tmp)
			inf = cambio.cambiar(argparse.Namespace(instruccion=detalle.get("instruccion", ""), plan=json.dumps(detalle["plan"]),
				solo_plan=False, volver=0, **comunes))
			usd = float(inf.get("coste_usd", {}).get("total", 0.0))
		carpeta = f"{usuario}/{trabajo['project_id']}/v{inf['version']}"
		archivos = _subir_version(sb, carpeta, inf, proyecto, tmp)
		if not archivos.get("clip") and archivos_previos.get("clip"):
			archivos["clip"] = archivos_previos["clip"]
		diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
		sb.rpc("complete_change_job", p_job=job, p_cost_usd=max(usd, coste_real(llm.Gasto(), t0)), p_units=0, p_title=diseno["titulo"],
			p_spec=diseno, p_files=archivos, p_version=inf["version"])
		limpiar_version_anterior(sb, archivos_previos, archivos)
		print(f"[trabajador] listo {job}: v{inf['version']}", flush=True)
	except Exception as e:  # noqa: BLE001 - cualquier fallo se devuelve al usuario
		traceback.print_exc()
		try:
			devuelto = sb.rpc("fail_job", p_job=job, p_error=str(e)[:400] or e.__class__.__name__,
				p_cost_usd=max(usd, coste_real(llm.Gasto(), t0)), p_refund=True)
			print(f"[trabajador] fallo {job}; devuelto={devuelto}", flush=True)
		except Exception as e2:  # noqa: BLE001
			print(f"[trabajador] no se pudo cerrar el trabajo {job}: {e2}", flush=True)
	finally:
		cadena.oyentes.remove(avisar)
		shutil.rmtree(tmp, ignore_errors=True)
		## El adelanto solo vale mientras dura el trabajo (la version buena ya esta en su carpeta).
		borrar_seguro(sb, [f"{usuario}/{trabajo['project_id']}/adelanto/index.pck"])


def _bajar_referencia(sb: Supabase, usuario: str, proyecto_id: str, proyecto: Path, tmp: Path) -> None:
	"""El dibujo del autor (ya revisado por heroe-dibujo) a fabrica/referencias/heroe.png, como PNG
	de 1024 px como mucho (llega como PNG, JPG o WEBP)."""
	from PIL import Image

	crudo = sb.bajar(f"{usuario}/{proyecto_id}/heroe.png", tmp / "referencia_subida", bucket="referencias")
	img = Image.open(crudo)
	img.thumbnail((1024, 1024))
	destino = proyecto / "fabrica" / "referencias" / "heroe.png"
	destino.parent.mkdir(parents=True, exist_ok=True)
	img.convert("RGBA").save(destino, "PNG")


def atender_marketing(sb: Supabase, trabajo: dict, opciones: argparse.Namespace) -> None:
	"""Videos para redes: baja la version actual, el estudio de marketing hace 3 clips y se suben."""
	from marketing import estudio
	job = trabajo["job_id"]
	usuario = trabajo["user_id"]
	print(f"[trabajador] marketing {job} (proyecto {trabajo['project_id']})", flush=True)
	gasto = llm.Gasto()

	def avisar(ev: dict) -> None:
		ligero = {k: v for k, v in ev.items() if k in ("paso", "estado", "mensaje", "t", "titulo")}
		sb.rpc("job_progress", p_job=job, p_event=ligero)

	cadena.oyentes.append(avisar)
	tmp = Path(tempfile.mkdtemp(prefix="orq_mkt_"))
	try:
		proyecto = _abrir_proyecto(sb, trabajo, tmp)
		r = estudio.generar(proyecto, opciones.simulado, gasto)
		version = int(trabajo.get("project_version") or 1)
		carpeta = f"{usuario}/{trabajo['project_id']}/v{version}/marketing"
		cadena.evento("subida", "inicio", "Guardando los vídeos en la nube...")
		videos = []
		for v in r["videos"]:
			videos.append({"estilo": v["estilo"], "gancho": v["gancho"],
				"mp4": sb.subir(f"{carpeta}/{v['estilo']}.mp4", Path(v["mp4"])),
				"portada": sb.subir(f"{carpeta}/{v['estilo']}.jpg", Path(v["portada"]))})
		archivos = {"videos": videos, "publicacion": r["publicacion"], "redes": r["redes"], "voz": r["voz"],
			"zip": sb.subir(f"{carpeta}/marketing.zip", Path(r["zip"])), "version": version}
		if r.get("trailer"):
			archivos["trailer"] = sb.subir(f"{carpeta}/trailer_16x9.mp4", Path(r["trailer"]))
		cadena.evento("subida", "ok", "Vídeos guardados")
		## YouTube (si el usuario lo pidio): 3 Shorts y el trailer en su canal.
		modo_yt = str((trabajo.get("detail") or {}).get("youtube", "no"))
		if modo_yt in ("oculto", "publico"):
			archivos["youtube"] = _subir_youtube(sb, usuario, r, modo_yt)
		sb.rpc("complete_marketing_job", p_job=job, p_cost_usd=gasto.usd + r.get("usd_voz", 0.0), p_files=archivos)
		print(f"[trabajador] listo {job}: {len(videos)} videos (voz: {r['voz']})", flush=True)
	except Exception as e:  # noqa: BLE001 - cualquier fallo se devuelve al usuario
		traceback.print_exc()
		try:
			devuelto = sb.rpc("fail_job", p_job=job, p_error=str(e)[:400] or e.__class__.__name__, p_cost_usd=gasto.usd, p_refund=True)
			print(f"[trabajador] fallo {job}; devuelto={devuelto}", flush=True)
		except Exception as e2:  # noqa: BLE001
			print(f"[trabajador] no se pudo cerrar el trabajo {job}: {e2}", flush=True)
	finally:
		cadena.oyentes.remove(avisar)
		shutil.rmtree(tmp, ignore_errors=True)


def _subir_youtube(sb: Supabase, usuario: str, r: dict, modo: str) -> dict:
	"""Sube los Shorts y el trailer. Un fallo de YouTube no estropea los videos ya hechos."""
	from marketing import youtube
	cadena.evento("youtube", "inicio", "Subiendo a tu canal de YouTube...")
	try:
		refresh = sb.rpc("youtube_token", p_user=usuario)
		if not refresh:
			raise youtube.ErrorYoutube("Tu canal de YouTube no esta conectado")
		token = youtube.acceso(str(refresh))
		es = r["redes"]["es"]
		etiquetas = (r["publicacion"].get("es", {}).get("hashtags") or [])
		subidos = []
		for v in r["videos"]:
			vid = youtube.subir(token, Path(v["mp4"]), f"{v['gancho']} #Shorts", es["shorts_descripcion"], etiquetas, modo)
			subidos.append({"estilo": v["estilo"], "id": vid, "url": f"https://youtube.com/shorts/{vid}"})
		if r.get("trailer"):
			titulo = r["publicacion"].get("es", {}).get("titulo") or es["shorts_titulo"].replace("#Shorts", "").strip()
			vid = youtube.subir(token, Path(r["trailer"]), f"{titulo} - Tráiler", es["shorts_descripcion"], etiquetas, modo)
			subidos.append({"estilo": "trailer", "id": vid, "url": f"https://youtu.be/{vid}"})
		cadena.evento("youtube", "ok", f"{len(subidos)} vídeos en tu canal de YouTube")
		return {"modo": modo, "videos": subidos}
	except Exception as e:  # noqa: BLE001
		cadena.evento("youtube", "aviso", f"No se pudo subir a YouTube: {str(e)[:160]}")
		return {"modo": modo, "error": str(e)[:300], "videos": []}


def _abrir_proyecto(sb: Supabase, trabajo: dict, tmp: Path) -> Path:
	previos = trabajo.get("project_files") or {}
	if not previos.get("proyecto"):
		raise RuntimeError("El juego no tiene proyecto guardado")
	cadena.evento("preparar", "inicio", "Abriendo tu juego...")
	zipf = sb.bajar(previos["proyecto"], tmp / "previo.zip")
	proyecto = tmp / Path(previos["proyecto"]).name.replace("_godot.zip", "")
	descomprimir_proyecto(zipf, proyecto)
	## Herramientas de QA al dia (capturas y clips) aunque el juego se fabricara con un kit anterior.
	for f in ("clip.gd", "clip.tscn", "capturas.gd", "capturas.tscn"):
		shutil.copy2(cadena.KIT / "qa" / f, proyecto / "qa" / f)
	cadena.godot(proyecto, "--import", timeout=600)
	return proyecto


def _llave_usuario(sb: Supabase, usuario: str, estudio: str, tmp: Path) -> dict:
	"""La llave de subida del usuario: se baja cifrada o, la primera vez, se crea y se guarda."""
	from play import firma
	ruta = f"{usuario}.llave"
	try:
		paquete = sb.bajar(ruta, tmp / "llave.bin", bucket="llaves").read_bytes()
		return firma.descifrar(paquete, tmp / "upload.jks")
	except RuntimeError as e:
		if "404" not in str(e) and "400" not in str(e) and "not_found" not in str(e).lower():
			raise
	llave = firma.crear(tmp / "upload.jks", estudio)
	(tmp / "llave.bin").write_bytes(firma.cifrar(llave))
	sb.subir(ruta, tmp / "llave.bin", bucket="llaves")
	sb.rpc("set_play_key", p_user=usuario, p_huella=llave["huella_sha256"])
	return llave


def url_privacidad(supabase_url: str, proyecto_id: str) -> str:
	"""1 - Con la web publica (ORQ_WEB = https://<usuario>.github.io/<repo>) la politica se ve como pagina;
	sin ella, el .html del almacen (Supabase lo sirve como texto plano salvo con dominio propio)."""
	web = os.environ.get("ORQ_WEB", "").rstrip("/")
	if web:
		return f"{web}/privacidad.html?j={proyecto_id}"
	return f"{supabase_url}/storage/v1/object/public/legal/{proyecto_id}/privacidad.html"


def atender_publicar(sb: Supabase, trabajo: dict, opciones: argparse.Namespace) -> None:
	"""Google Play: primera vez (.aab + guia + politica) o subida por la API."""
	from play import cuestionarios, publicador
	job = trabajo["job_id"]
	usuario = trabajo["user_id"]
	d = trabajo.get("detail") or {}
	print(f"[trabajador] publicar {job} ({d.get('modo')}, {d.get('pista')})", flush=True)

	def avisar(ev: dict) -> None:
		ligero = {k: v for k, v in ev.items() if k in ("paso", "estado", "mensaje", "t")}
		sb.rpc("job_progress", p_job=job, p_event=ligero)

	cadena.oyentes.append(avisar)
	tmp = Path(tempfile.mkdtemp(prefix="orq_pub_"))
	try:
		proyecto = _abrir_proyecto(sb, trabajo, tmp)
		diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
		llave = _llave_usuario(sb, usuario, d["estudio"], tmp)
		version = int(trabajo.get("project_version") or 1)
		codigo = max(int(d.get("version_code") or 0) + 1, version * 100)
		paquete = d.get("paquete") or cuestionarios.paquete_para(d["estudio"], diseno)
		url_priv = url_privacidad(sb.url, trabajo["project_id"])
		prep = publicador.preparar(proyecto, d["estudio"], d["correo"], llave, codigo, paquete, url_privacidad=url_priv,
			admob=d.get("admob"))
		sb.subir(f"{trabajo['project_id']}/privacidad.html", Path(prep["privacidad"]), bucket="legal")
		sb.subir(f"{trabajo['project_id']}/privacidad.json", Path(prep["privacidad_json"]), bucket="legal")
		carpeta = f"{usuario}/{trabajo['project_id']}/v{version}/play"
		archivos = {"guia": prep["guia"], "privacidad_url": url_priv, "paquete": paquete, "huella_llave": prep["huella_llave"],
			"version_code": codigo, "aab": sb.subir(f"{carpeta}/{Path(prep['aab']).name}", Path(prep["aab"]))}
		play = {"paquete": paquete, "version_code": codigo, "huella_llave": prep["huella_llave"], "anuncios": bool(prep.get("anuncios"))}
		if d.get("modo") == "subir":
			ultimo = (versiones.memoria(proyecto).get("historial") or [{}])[-1]
			nota = str(ultimo.get("resumen") or "Mejoras y correcciones.")[:450]
			r = publicador.subir(prep, d.get("pista", "alpha"), {"es": nota, "en": "Improvements and fixes."}, d["correo"])
			play.update({"estado": "borrador" if r["borrador"] else "subido", "pista": r["pista"], "subido_en": int(time.time())})
			archivos["resultado"] = {k: r[k] for k in ("version", "pista", "borrador", "imagenes")}
		else:
			play["estado"] = "primer_aab"
		sb.rpc("complete_publish_job", p_job=job, p_cost_usd=0.0, p_play=play, p_files=archivos)
		print(f"[trabajador] listo {job}: {paquete} v{codigo} ({play['estado']})", flush=True)
	except Exception as e:  # noqa: BLE001 - cualquier fallo se cuenta al usuario
		traceback.print_exc()
		try:
			sb.rpc("fail_job", p_job=job, p_error=str(e)[:400] or e.__class__.__name__, p_cost_usd=0.0, p_refund=True)
		except Exception as e2:  # noqa: BLE001
			print(f"[trabajador] no se pudo cerrar el trabajo {job}: {e2}", flush=True)
	finally:
		cadena.oyentes.remove(avisar)
		shutil.rmtree(tmp, ignore_errors=True)


def cruzada(sb: "Supabase", usuario: str, sin: str = "") -> list[dict]:
	"""Otros juegos del mismo autor para la promocion cruzada: los de Google Play (ya subidos) y los
	del escaparate (se juegan en la web). Si algo falla, nada (nunca para la fabricacion)."""
	try:
		filas = json.loads(sb._peticion("GET", f"/rest/v1/projects?user_id=eq.{urllib.parse.quote(usuario)}&select=id,title,play&order=updated_at.desc&limit=20",
			None, "application/json") or b"[]")
		esc = json.loads(sb._peticion("GET", f"/rest/v1/escaparate?user_id=eq.{urllib.parse.quote(usuario)}&oculto=eq.false&select=project_id",
			None, "application/json") or b"[]")
	except Exception:  # noqa: BLE001
		return []
	en_web = {str(e["project_id"]) for e in esc}
	web = os.environ.get("ORQ_WEB", "").rstrip("/")
	out = []
	for p in filas:
		if str(p.get("id")) == sin or not p.get("title"):
			continue
		play = p.get("play") or {}
		if play.get("paquete") and play.get("estado") in ("subido", "produccion", "publicado"):
			out.append({"title": p["title"], "url": f"https://play.google.com/store/apps/details?id={play['paquete']}"})
		elif web and str(p["id"]) in en_web:
			out.append({"title": p["title"], "url": f"{web}/jugar.html?j={p['id']}"})
	return out[:6]


def atender_previa(sb: Supabase, trabajo: dict, opciones: argparse.Namespace) -> None:
	"""Vista previa gratis: solo el diseno (un minuto, ~0,01 $). Si falla no hay nada que devolver."""
	job = trabajo["job_id"]
	gasto = llm.Gasto()
	t0 = time.time()
	print(f"[trabajador] vista previa {job}: {trabajo['idea'][:80]}", flush=True)
	usuario = trabajo["user_id"]
	tmp = Path(tempfile.mkdtemp(prefix="orq_previa_"))
	try:
		## Diseno + niveles + boceto jugable con los dibujos provisionales (sin tarjeta grafica).
		diseno, boceto = None, None
		try:
			inf = cadena.fabricar(argparse.Namespace(
				idea=trabajo["idea"], salida=str(tmp), simulado=opciones.simulado, arte_simulado=True,
				comfy=opciones.comfy, crear=opciones.crear, editar=opciones.editar, lado=opciones.lado,
				semilla=int(job.replace("-", "")[:6], 16) % 100000, apk=False, capturas=False, web=opciones.web,
				ficha=False, clip=False, gasto=gasto, solo_boceto=True,
				boceto=lambda pck: sb.subir(f"{usuario}/{job}/boceto/index.pck", pck)))
			diseno, boceto = inf["diseno"], inf.get("boceto")
		except Exception as e:  # noqa: BLE001 - sin boceto, al menos el diseno
			print(f"[trabajador] vista previa sin boceto ({str(e)[:160]}): solo el diseno", flush=True)
		if diseno is None:
			diseno, _ = cadena.disenar_previa(trabajo["idea"], opciones.simulado, gasto)
		sb.rpc("complete_preview_job", p_job=job, p_spec=diseno, p_cost_usd=coste_real(gasto, t0), p_boceto=boceto)
		print(f"[trabajador] vista previa lista {job}: {diseno.get('titulo')} (boceto: {'si' if boceto else 'no'})", flush=True)
	except Exception as e:  # noqa: BLE001 - se cierra como fallida; no habia cobro
		traceback.print_exc()
		try:
			sb.rpc("fail_job", p_job=job, p_error=str(e)[:400] or e.__class__.__name__, p_cost_usd=coste_real(gasto, t0), p_refund=False)
		except Exception as e2:  # noqa: BLE001
			print(f"[trabajador] no se pudo cerrar la vista previa {job}: {e2}", flush=True)
	finally:
		shutil.rmtree(tmp, ignore_errors=True)


def atender(sb: Supabase, trabajo: dict, opciones: argparse.Namespace) -> None:
	if trabajo.get("kind") in ("game_change", "game_restore", "game_mod"):
		return atender_cambio(sb, trabajo, opciones)
	if trabajo.get("kind") == "game_marketing":
		return atender_marketing(sb, trabajo, opciones)
	if trabajo.get("kind") == "game_publish":
		return atender_publicar(sb, trabajo, opciones)
	if trabajo.get("kind") == "game_preview":
		return atender_previa(sb, trabajo, opciones)
	job = trabajo["job_id"]
	usuario = trabajo["user_id"]
	idea = trabajo["idea"]
	canario = bool((trabajo.get("detail") or {}).get("canario"))
	print(f"[trabajador] trabajo {job}{' (canario)' if canario else ''}: {idea[:80]}", flush=True)
	gasto = llm.Gasto()
	t0 = time.time()
	## Solo lo que Chispa necesita: paso, estado, mensaje y algun numero.
	avisar = oyente_progreso(sb, job, ("paso", "estado", "mensaje", "t", "titulo", "imagenes", "mb", "total_s", "boceto",
		"gpu_s", "arranque_s", "seg_img", "tope"))

	cadena.oyentes.append(avisar)
	tmp = Path(tempfile.mkdtemp(prefix="orq_"))
	try:
		args = argparse.Namespace(
			idea=idea, salida=str(tmp), simulado=opciones.simulado, arte_simulado=opciones.arte_simulado,
			comfy=opciones.comfy, crear=opciones.crear, editar=opciones.editar, lado=opciones.lado,
			semilla=int(job.replace("-", "")[:6], 16) % 100000, apk=opciones.apk, capturas=opciones.capturas, web=opciones.web,
			## Canario semanal (prueba automatica): juego pequeno, sin ficha ni clip, para gastar lo minimo.
			ficha=opciones.ficha and not canario, clip=opciones.clip and not canario, ligero=canario, gasto=gasto,
			telemetria_id=job, boceto=lambda pck: sb.subir(f"{usuario}/{job}/boceto/index.pck", pck),
			## Vista previa aprobada: se fabrica con ese diseno (lo puso el servidor, no el jugador).
			diseno=(trabajo.get("detail") or {}).get("diseno") or None,
			cache_arte=CacheArte(sb),
			cruzada=cruzada(sb, usuario, job))
		inf = cadena.fabricar(args)
		proyecto = Path(inf["proyecto"])
		archivos = _subir_version(sb, f"{usuario}/{job}/v1", inf, proyecto, tmp)
		diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
		sb.rpc("complete_game_job", p_job=job, p_cost_usd=max(inf["coste_usd"]["total"], coste_real(gasto, t0)), p_units=inf["imagenes"],
			p_title=inf["titulo"], p_spec=diseno, p_files=archivos)
		borrar_seguro(sb, [f"{usuario}/{job}/boceto/index.pck"] + ([CacheArte.ruta(inf["clave_arte"])] if inf.get("clave_arte") else []))
		print(f"[trabajador] listo {job}: {inf['titulo']} ({inf['total_s']} s, {inf['coste_usd']['total']} $)", flush=True)
	except Exception as e:  # noqa: BLE001 - cualquier fallo se devuelve al usuario
		traceback.print_exc()
		motivo = str(e)[:400] or e.__class__.__name__
		guardar_diseno_fallido(sb, job, tmp)
		try:
			devuelto = sb.rpc("fail_job", p_job=job, p_error=motivo, p_cost_usd=coste_real(gasto, t0), p_refund=True)
			print(f"[trabajador] fallo {job}; devuelto={devuelto}", flush=True)
		except Exception as e2:  # noqa: BLE001
			print(f"[trabajador] no se pudo cerrar el trabajo {job}: {e2}", flush=True)
	finally:
		cadena.oyentes.remove(avisar)
		shutil.rmtree(tmp, ignore_errors=True)


def mantenimiento(sb: Supabase, aprender: bool) -> None:
	"""Cierra trabajos caducados (devuelve tuercas) y, si toca, recalibra con los jugadores."""
	if aprender:
		## Lo que ha aprendido de los jugadores calibra los juegos nuevos.
		try:
			import aprendizaje
			cal = aprendizaje.actualizar(sb)
			print(f"[trabajador] aprendizaje: {len(cal)} ajustes de dificultad", flush=True)
		except Exception as e:  # noqa: BLE001 - aprender nunca para la fabrica
			print(f"[trabajador] aprendizaje: {e}", flush=True)
	try:
		## Giros: lo que ha aprendido toda la fabrica (que giro falla en que genero).
		import giros
		giros.guardar_servidor(sb.rpc("giros_estadisticas") or {})
	except Exception as e:  # noqa: BLE001
		print(f"[trabajador] giros: {e}", flush=True)
	try:
		## Huellas de los juegos de toda la fabrica (para que no salgan copias).
		import originalidad
		originalidad.guardar_servidor(sb.rpc("huellas_recientes") or [])
	except Exception as e:  # noqa: BLE001
		print(f"[trabajador] huellas: {e}", flush=True)
	try:
		sb.rpc("lz_revisar")
	except RuntimeError as e:
		print(f"[trabajador] lanzadera: {e}", flush=True)
	try:
		sb.rpc("arena_limpiar")
	except RuntimeError as e:
		print(f"[trabajador] arena: {e}", flush=True)
	try:
		sb.rpc("nube_limpiar")
	except RuntimeError as e:
		print(f"[trabajador] nube: {e}", flush=True)
	try:
		viejos = sb.rpc("limpiar_previas") or []
		borrar_seguro(sb, list(viejos))
		if viejos:
			print(f"[trabajador] {len(viejos)} bocetos de vistas previas viejas borrados", flush=True)
	except Exception as e:  # noqa: BLE001
		print(f"[trabajador] bocetos de vistas previas: {e}", flush=True)
	try:
		n = limpiar_cache_arte(sb)
		if n:
			print(f"[trabajador] {n} caches de arte viejas borradas", flush=True)
	except Exception as e:  # noqa: BLE001
		print(f"[trabajador] cache de arte: {e}", flush=True)
	try:
		n = sb.rpc("expire_stuck_jobs")
		if n:
			print(f"[trabajador] {n} trabajos caducados cerrados y devueltos", flush=True)
	except RuntimeError as e:
		print(f"[trabajador] limpieza: {e}", flush=True)


def vaciar_cola(sb: Supabase, opciones: argparse.Namespace, nombre: str, maximo: int = 0, limite_s: float = 0.0) -> int:
	"""Atiende trabajos hasta que la cola queda vacia (o se llega al maximo / al limite de tiempo).
	Lo usan el trabajador propio y la fabrica en RunPod (runpod_handler.py)."""
	inicio = time.time()
	hechos = 0
	while True:
		if maximo and hechos >= maximo:
			break
		if limite_s and time.time() - inicio > limite_s:
			break
		try:
			filas = sb.rpc("claim_game_job", p_worker=nombre) or []
		except RuntimeError as e:
			print(f"[trabajador] cola: {e}", flush=True)
			break
		if not filas:
			break
		## Cada trabajo empieza con su tope de GPU a cero.
		from arte import runpod as _runpod
		_runpod.reiniciar_gasto()
		atender(sb, filas[0], opciones)
		hechos += 1
	return hechos


def preparar_entorno() -> None:
	## Los juegos mandan sus datos anonimos de partida a este mismo Supabase con la clave publica.
	if os.environ.get("SUPABASE_ANON_KEY") and os.environ.get("SUPABASE_URL"):
		os.environ.setdefault("ORQ_TELEMETRIA_URL", os.environ["SUPABASE_URL"])
		os.environ.setdefault("ORQ_TELEMETRIA_CLAVE", os.environ["SUPABASE_ANON_KEY"])


def argumentos() -> argparse.ArgumentParser:
	p = argparse.ArgumentParser(description="Trabajador de la fabrica de Orquestador")
	p.add_argument("--simulado", action="store_true")
	p.add_argument("--arte-simulado", action="store_true")
	p.add_argument("--comfy", default=os.environ.get("ORQ_COMFY", "http://127.0.0.1:8188"),
		help="runpod://<endpoint> (GPU alquilada por segundos) o http://... (ComfyUI propio)")
	p.add_argument("--crear", default=cadena.flujo_arte("crear"))
	p.add_argument("--editar", default=cadena.flujo_arte("editar"))
	## Resolucion de los dibujos: acaban en celdas de 32-64 px, asi que 768 (0,56 MP) basta y la GPU
	## tarda casi la mitad que a 1024. ORQ_LADO para cambiarla sin tocar codigo.
	p.add_argument("--lado", type=int, default=int(os.environ.get("ORQ_LADO") or "768"))
	p.add_argument("--apk", action="store_true")
	p.add_argument("--capturas", action="store_true")
	p.add_argument("--web", action="store_true", help="Sube tambien la version para jugar en la app")
	p.add_argument("--ficha", action="store_true", help="Sube tambien la ficha de Google Play (.zip)")
	p.add_argument("--clip", action="store_true", help="Sube tambien un clip vertical para redes (.mp4, necesita ffmpeg)")
	p.add_argument("--espera", type=float, default=5.0, help="Segundos entre consultas a la cola")
	p.add_argument("--una-vez", action="store_true", help="Atiende como mucho un trabajo y sale")
	return p


def conectar_aprendizaje(sb: "Supabase") -> None:
	"""Lo que aprende una maquina (giros que fallan, huellas de juegos) va al servidor para todas."""
	import giros
	import originalidad
	giros.remoto = lambda genero, giro, ok, problema: sb.rpc("giro_anotar", p_genero=genero, p_giro=giro, p_ok=ok, p_problema=problema)
	originalidad.remoto = lambda genero, h: sb.rpc("huella_anotar", p_genero=genero, p_firma=h)


def main(argv: list[str] | None = None) -> int:
	a = argumentos().parse_args(argv)
	url = os.environ.get("SUPABASE_URL", "")
	clave = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
	if not url or not clave:
		print("Faltan SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
		return 2
	sb = Supabase(url, clave)
	## Cada giro que se prueba se apunta en el servidor: aprenden todas las maquinas de lo mismo.
	import giros
	conectar_aprendizaje(sb)
	preparar_entorno()
	nombre = f"{socket.gethostname()}-{os.getpid()}"
	ultima_limpieza = 0.0
	ultimo_aprendizaje = 0.0
	print(f"[trabajador] {nombre} esperando juegos...", flush=True)
	while True:
		if time.time() - ultima_limpieza > 300:
			aprender = time.time() - ultimo_aprendizaje > 6 * 3600
			mantenimiento(sb, aprender)
			ultima_limpieza = time.time()
			if aprender:
				ultimo_aprendizaje = time.time()
		if vaciar_cola(sb, a, nombre, maximo=1 if a.una_vez else 0):
			if a.una_vez:
				return 0
		else:
			if a.una_vez:
				return 0
			time.sleep(a.espera)


if __name__ == "__main__":
	sys.exit(main())
