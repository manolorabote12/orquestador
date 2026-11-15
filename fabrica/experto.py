"""Modo experto (15 nov 2026): el autor baja el proyecto de Godot, lo cambia a mano (con Chispa en el
editor, addons/chispa) y lo sube. Aqui se revisa lo subido y se pone encima del proyecto guardado;
despues pasa los bots, el APK y la version como cualquier cambio (cambio.importar_experto).

Seguridad. Lo que sube el autor es codigo: se ejecuta en el trabajador al probar el juego con bots.
1 - Solo se aceptan las carpetas del juego (scenes, mods, assets, kit) y game.json. Nunca addons,
    qa (el arbitro: los bots), project.godot, export_presets.cfg ni fabrica.
2 - Ningun script de editor (@tool, EditorPlugin...): asi importar y exportar (que van con el usuario
    del trabajador) no ejecutan nada del autor.
3 - Jugar el juego (bots, capturas, version web) va con un usuario sin privilegios y sin las variables
    de entorno del trabajador (cadena.SANDBOX): ni claves ni /proc del proceso padre.
4 - Tamano, numero de archivos, rutas (nada de .. ni absolutas), enlaces y extensiones con limite.
"""

import re
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path

MAX_ZIP = 150 * 1024 * 1024
MAX_DESCOMPRIMIDO = 400 * 1024 * 1024
MAX_ARCHIVOS = 6000
CARPETAS = ("scenes/", "mods/", "assets/", "kit/")
SUELTOS = ("game.json",)
EXTENSIONES = {".gd", ".tscn", ".tres", ".gdshader", ".json", ".png", ".jpg", ".jpeg", ".webp", ".svg", ".ogg", ".wav",
	".mp3", ".ttf", ".otf", ".glb", ".gltf", ".bin", ".uid", ".txt", ".md", ".csv", ".translation", ".po"}
## Texto que no puede ir en ningun script ni escena: codigo que se ejecutaria dentro del editor.
PROHIBIDO = [r"@tool\b", r"\bEditor(Plugin|Script|ExportPlugin|ImportPlugin|InspectorPlugin|Interface|FileSystem)\b",
	r"\btool_button\b", r"\bEditorTranslationParserPlugin\b"]
TEXTO = {".gd", ".tscn", ".tres", ".gdshader"}


class ErrorExperto(Exception):
	pass


def _raiz(dentro: Path) -> Path:
	"""Carpeta del zip que tiene el proyecto (el zip puede traer una carpeta por encima)."""
	if (dentro / "project.godot").exists():
		return dentro
	hijos = [p for p in dentro.iterdir() if p.is_dir()]
	for h in hijos:
		if (h / "project.godot").exists():
			return h
	raise ErrorExperto("El zip no es un proyecto de Godot (no encuentro project.godot)")


def _admitido(rel: str) -> bool:
	return rel in SUELTOS or rel.startswith(CARPETAS)


def revisar_zip(zipf: Path) -> list[str]:
	"""Errores del zip (vacio si vale). No descomprime nada."""
	errores: list[str] = []
	if zipf.stat().st_size > MAX_ZIP:
		return [f"El zip pesa {zipf.stat().st_size // 1_000_000} MB (maximo {MAX_ZIP // 1_000_000} MB)"]
	try:
		z = zipfile.ZipFile(zipf)
	except zipfile.BadZipFile:
		return ["El archivo no es un zip"]
	with z:
		infos = z.infolist()
		if len(infos) > MAX_ARCHIVOS:
			return [f"Demasiados archivos ({len(infos)}, maximo {MAX_ARCHIVOS})"]
		total = 0
		for i in infos:
			n = i.filename
			total += i.file_size
			if n.startswith("/") or "\\" in n or ".." in Path(n).parts or re.match(r"^[A-Za-z]:", n):
				errores.append(f"Ruta no valida: {n}")
			modo = (i.external_attr >> 16) & 0o170000
			if modo == stat.S_IFLNK:
				errores.append(f"Enlace no permitido: {n}")
		if total > MAX_DESCOMPRIMIDO:
			errores.append(f"Descomprimido ocupa demasiado ({total // 1_000_000} MB)")
	return errores[:20]


def revisar_archivo(rel: str, ruta: Path) -> list[str]:
	ext = ruta.suffix.lower()
	if ext not in EXTENSIONES:
		return [f"{rel}: tipo de archivo no admitido ({ext or 'sin extension'})"]
	if ext in TEXTO:
		txt = ruta.read_text(encoding="utf-8", errors="replace")
		for p in PROHIBIDO:
			m = re.search(p, txt)
			if m:
				return [f"{rel}: no se admite '{m.group(0)}' (codigo que se ejecuta dentro del editor)"]
	return []


def aplicar(proyecto: Path, zipf: Path) -> dict:
	"""Pone lo subido encima del proyecto. Devuelve {"cambiados", "nuevos", "borrados", "ignorados"}.
	Lanza ErrorExperto si algo no vale (y entonces no toca nada)."""
	errores = revisar_zip(zipf)
	if errores:
		raise ErrorExperto("El proyecto subido no vale: " + "; ".join(errores))
	tmp = Path(tempfile.mkdtemp(prefix="orq_experto_"))
	try:
		with zipfile.ZipFile(zipf) as z:
			z.extractall(tmp)
		raiz = _raiz(tmp)
		subidos: dict[str, Path] = {}
		ignorados: list[str] = []
		for p in sorted(raiz.rglob("*")):
			if not p.is_file() or p.is_symlink():
				continue
			rel = p.relative_to(raiz).as_posix()
			if rel.startswith(".godot/") or rel.endswith(".import") or "/." in "/" + rel:
				continue
			if not _admitido(rel):
				ignorados.append(rel)
				continue
			subidos[rel] = p
		errores = []
		for rel, p in subidos.items():
			errores += revisar_archivo(rel, p)
		if errores:
			raise ErrorExperto("El proyecto subido no vale: " + "; ".join(errores[:12]))
		if "game.json" in subidos:
			import json
			try:
				json.loads(subidos["game.json"].read_text(encoding="utf-8"))
			except ValueError as e:
				raise ErrorExperto(f"game.json no es un JSON valido: {e}") from e
		cambiados, nuevos = [], []
		for rel, p in subidos.items():
			destino = proyecto / rel
			if destino.exists():
				if destino.read_bytes() == p.read_bytes():
					continue
				cambiados.append(rel)
			else:
				nuevos.append(rel)
			destino.parent.mkdir(parents=True, exist_ok=True)
			shutil.copyfile(p, destino)
		## Mods borrados a mano: si la carpeta mods/ venia en el zip, lo que falta se quita.
		borrados = []
		if (raiz / "mods").is_dir() and (proyecto / "mods").is_dir():
			for q in (proyecto / "mods").rglob("*"):
				rel = q.relative_to(proyecto).as_posix()
				if q.is_file() and not rel.endswith((".import", ".uid")) and rel not in subidos:
					q.unlink()
					borrados.append(rel)
		if not (cambiados or nuevos or borrados):
			raise ErrorExperto("No has cambiado nada respecto a la version guardada")
		return {"cambiados": cambiados, "nuevos": nuevos, "borrados": borrados, "ignorados": ignorados[:50]}
	finally:
		shutil.rmtree(tmp, ignore_errors=True)


def resumen(r: dict) -> str:
	partes = []
	for k, nombre in (("cambiados", "cambiados"), ("nuevos", "nuevos"), ("borrados", "quitados")):
		if r.get(k):
			partes.append(f"{len(r[k])} {nombre}")
	txt = "Cambios hechos a mano en Godot: " + ", ".join(partes) + " (archivos)"
	if r.get("ignorados"):
		txt += f". No se usan {len(r['ignorados'])} archivos de fuera del juego (addons, qa, ajustes del proyecto)"
	return txt
