"""Huella de una imagen de Docker: su Dockerfile y todo lo que copia (COPY/ADD).

	python3 nube/huella_imagen.py nube/imagenes/Dockerfile      -> 16 letras

Si la huella no cambia, la imagen es la misma: el despliegue no la vuelve a construir (30 min de
minutos de GitHub en las de GPU) y RunPod no cambia la plantilla (no hay arranque en frio nuevo).
"""
import hashlib
import pathlib
import shlex
import sys


def huella(dockerfile: str) -> str:
	df = pathlib.Path(dockerfile)
	rutas = [df]
	for linea in df.read_text(encoding="utf-8").splitlines():
		partes = shlex.split(linea) if linea.strip().upper().startswith(("COPY ", "ADD ")) else []
		if partes and not any(x.startswith("--from") for x in partes):
			rutas += [pathlib.Path(x) for x in partes[1:-1] if not x.startswith("--")]
	sha = hashlib.sha256()
	for r in sorted(set(rutas)):
		archivos = [r] if r.is_file() else [x for x in r.rglob("*") if x.is_file() and "__pycache__" not in x.parts]
		for f in sorted(archivos):
			sha.update(str(f).encode() + b"\0" + f.read_bytes())
	return sha.hexdigest()[:16]


if __name__ == "__main__":
	print(huella(sys.argv[1]))
