#!/usr/bin/env python3
"""Conecta Orquestador con TUS cuentas y lo pone en marcha, de una vez.

Se ejecuta en tu PC, dentro de la carpeta del proyecto (la que sale de orquestador-completo.zip):

	python conectar.py

Antes necesitas (ver PONER-EN-MARCHA.md): Git, GitHub CLI con sesion iniciada (gh auth login),
y las claves de Supabase, Anthropic, RunPod y un token de GitHub con read:packages.

Que hace, en orden (si lo vuelves a lanzar, sigue donde se quedo y no duplica nada):
	1 - Comprueba las herramientas y tu sesion de GitHub.
	2 - Te pide las claves (o las lee de conectar.env) y comprueba que funcionan de verdad.
	3 - Genera lo que no tiene que darte nadie: la llave de subida de la app (Google Play), el
	    secreto que cifra las llaves de los usuarios y la cuenta para el revisor de Google.
	4 - Crea tu repositorio PRIVADO en GitHub y guarda ahi los secretos y variables.
	5 - Prepara la web publica (privacidad, terminos, borrar cuenta) en GitHub Pages.
	6 - Sube el codigo. GitHub despliega la nube (RunPod + Supabase) y compila la app.
	7 - Espera, descarga el .aab firmado en salida/ y te deja los pasos de Google Play.

Nada secreto acaba en el codigo ni en la app: las claves van a los secretos de GitHub (y de ahi a
Supabase y RunPod). Lo generado se guarda en la carpeta .conectar/ (fuera de git): HAZ COPIA de
ella en un sitio seguro (la llave de subida y ORQ_LLAVES_SECRETO no se pueden recuperar).

Opciones:
	--repo NOMBRE        nombre del repositorio (por defecto orquestador)
	--sin-red            no comprueba las claves contra los servicios
	--sin-esperar        sube y lanza todo, pero no espera a que termine
	--solo-comprobar     solo los pasos 1 y 2
	--no-interactivo     no pregunta: todo sale de conectar.env (falla si falta algo)
"""

from __future__ import annotations

import argparse
import base64
import datetime
import json
import os
import re
import secrets
import string
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
PRIVADO = RAIZ / ".conectar"
SALIDA = RAIZ / "salida"
ENV = RAIZ / "conectar.env"
PAQUETE = "com.orquestador.app"

GITIGNORE = """# --- Orquestador (lo pone conectar.py) ---
# Secretos y llaves: NUNCA en git
.conectar/
conectar.env
*.jks
*.p12
*.keystore
salida/
# Generado
node_modules/
dist/
dist-demo/
app/android/
app/ios/
.godot/
__pycache__/
proyectos_*/
*.apk
*.aab
"""

## Lo que hay que pedir. (clave, obligatorio, explicacion, validador)
PEDIR: list[tuple[str, bool, str, str]] = [
	("SUPABASE_URL", True, "Supabase -> Project Settings -> API -> Project URL", "url_supabase"),
	("SUPABASE_ANON_KEY", True, "Supabase -> Project Settings -> API Keys -> anon public (o publishable)", "anon"),
	("SUPABASE_SERVICE_ROLE_KEY", True, "Supabase -> Project Settings -> API Keys -> service_role (o secret). Solo va a GitHub, nunca a la app", "servicio"),
	("SUPABASE_DB_PASSWORD", True, "La contrasena de la base de datos que pusiste al crear el proyecto", "texto"),
	("SUPABASE_ACCESS_TOKEN", True, "supabase.com -> Account -> Access Tokens -> Generate (empieza por sbp_)", "token_supabase"),
	("ANTHROPIC_API_KEY", True, "console.anthropic.com -> API Keys (empieza por sk-ant-). Ponle un limite de gasto", "anthropic"),
	("RUNPOD_API_KEY", True, "runpod.io -> Settings -> API Keys (lectura y escritura)", "texto"),
	("GHCR_TOKEN", True, "github.com -> Settings -> Developer settings -> Tokens (classic) con SOLO read:packages", "token_github"),
	("ORQ_CORREO", True, "Correo de contacto publico (sale en la ficha de Play y en la privacidad)", "correo"),
	("ORQ_RESPONSABLE", True, "Tu nombre o el de tu empresa (sale en privacidad y terminos)", "texto"),
	("ORQ_PLAY_CUENTA", False, "Ruta al JSON de la cuenta de servicio de Google Play (para publicar los juegos). Puedes dejarlo para luego", "archivo_json"),
	("ORQ_APP_ADMOB_APP_ID", False, "AdMob -> Apps -> Orquestador -> ID de app (ca-app-pub-...~...). Puedes dejarlo para luego", "admob_app"),
	("ORQ_APP_ADMOB_PREMIO", False, "AdMob -> bloque de anuncio 'Bonificado' de Orquestador (ca-app-pub-.../...)", "admob_bloque"),
	("GOOGLE_OAUTH_CLIENT_ID", False, "Para 'Entrar con Google' y YouTube: Google Cloud -> Credenciales -> ID de cliente OAuth de tipo "
		"'Aplicacion web' (termina en .apps.googleusercontent.com). Puedes dejarlo para luego", "google_cliente"),
	("GOOGLE_OAUTH_CLIENT_SECRET", False, "El secreto de ese mismo cliente web (va a Supabase y a GitHub, nunca a la app)", "texto"),
	("ORQ_SMTP_USUARIO", False, "Correo que envia los codigos de entrada (p. ej. tu Gmail). Supabase gratis no deja poner el codigo "
		"en el correo sin un servidor de correo propio", "correo"),
	("ORQ_SMTP_CLAVE", False, "Contrasena de aplicacion de ese correo (Gmail: myaccount.google.com/apppasswords, 16 letras)", "texto"),
]

## A que secretos / variables de GitHub va cada cosa.
SECRETOS = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_DB_PASSWORD",
	"SUPABASE_ACCESS_TOKEN", "SUPABASE_PROJECT_REF", "ANTHROPIC_API_KEY", "RUNPOD_API_KEY", "GHCR_TOKEN",
	"ORQ_LLAVES_SECRETO", "ORQ_REVISOR", "ORQ_APP_KEYSTORE_B64", "ORQ_APP_KEYSTORE_PASS",
	"ORQ_PLAY_CUENTA", "ORQ_PLAY_CUENTA_CORREO", "ORQ_PLAY_TIENDA_CUENTA", "GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_CLIENT_SECRET",
	"ORQ_SMTP_USUARIO", "ORQ_SMTP_CLAVE"]
VARIABLES = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "ORQ_WEB", "ORQ_CORREO", "ORQ_RESPONSABLE", "ORQ_PLAY_URL",
	"ORQ_APP_PAQUETE", "ORQ_APP_ADMOB_APP_ID", "ORQ_APP_ADMOB_PREMIO", "ADMOB_REWARDED_AD_UNIT", "GOOGLE_OAUTH_CLIENT_ID"]
## Nunca como variable (las variables de GitHub se pueden leer): comprobado antes de subir.
NUNCA_VARIABLE = {"SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_DB_PASSWORD", "SUPABASE_ACCESS_TOKEN", "ANTHROPIC_API_KEY",
	"RUNPOD_API_KEY", "GHCR_TOKEN", "ORQ_LLAVES_SECRETO", "ORQ_REVISOR", "ORQ_APP_KEYSTORE_B64",
	"ORQ_APP_KEYSTORE_PASS", "ORQ_PLAY_CUENTA", "ORQ_PLAY_TIENDA_CUENTA", "ORQ_WEB_DEPLOY_KEY", "GOOGLE_OAUTH_CLIENT_SECRET", "ORQ_SMTP_CLAVE"}

GH = os.environ.get("ORQ_GH", "gh")
GIT = os.environ.get("ORQ_GIT", "git")
REMOTO = os.environ.get("ORQ_REMOTO", "https://github.com/{repo}.git")
SUPABASE_API = os.environ.get("ORQ_SUPABASE_API", "https://api.supabase.com").rstrip("/")

## Correo de entrada: la app pide un CODIGO (no un enlace). Un usuario nuevo recibe la plantilla
## de "confirmar cuenta"; uno que ya existe, la de "enlace magico". Las dos llevan el codigo.
CORREO_ASUNTO = "Tu codigo de Orquestador: {{ .Token }}"
CORREO_CUERPO = ("<h2>Tu codigo para entrar en Orquestador</h2>"
	"<p style=\"font-size:32px;letter-spacing:6px;font-weight:bold\">{{ .Token }}</p>"
	"<p>Escribelo en la app. Caduca en una hora. Si no lo has pedido tu, ignora este correo.</p>")


PAUSA = float(os.environ.get("ORQ_PAUSA", "5"))


class Parar(Exception):
	"""Un problema que la persona tiene que arreglar (con el mensaje de como)."""


# ------------------------------------------------------------------ utilidades

def decir(texto: str = "") -> None:
	print(texto, flush=True)


def titulo(n: int, texto: str) -> None:
	decir()
	decir(f"== {n}. {texto} ==")


def correr(cmd: list[str], entrada: str | None = None, ok: tuple[int, ...] = (0,), cwd: Path | None = None) -> str:
	"""Ejecuta y devuelve la salida. Los valores secretos van por la entrada estandar, nunca en
	la linea de comandos (asi no se ven en la lista de procesos)."""
	try:
		r = subprocess.run(cmd, input=entrada, capture_output=True, text=True, cwd=str(cwd or RAIZ),
			encoding="utf-8", errors="replace")
	except FileNotFoundError as e:
		raise Parar(f"No encuentro el programa '{cmd[0]}'. {_como_instalar(cmd[0])}") from e
	if r.returncode not in ok:
		raise Parar(f"Fallo: {' '.join(cmd[:4])}...\n{(r.stderr or r.stdout).strip()[-1500:]}")
	return r.stdout


def _como_instalar(prog: str) -> str:
	if "gh" in Path(prog).name:
		return "Instala GitHub CLI: https://cli.github.com y luego ejecuta: gh auth login"
	if "git" in Path(prog).name:
		return "Instala Git: https://git-scm.com/downloads"
	return ""


def leer_env() -> dict[str, str]:
	d: dict[str, str] = {}
	if ENV.exists():
		for linea in ENV.read_text(encoding="utf-8").splitlines():
			linea = linea.strip()
			if not linea or linea.startswith("#") or "=" not in linea:
				continue
			k, v = linea.split("=", 1)
			d[k.strip()] = v.strip().strip('"').strip("'")
	return d


def guardar_env(d: dict[str, str]) -> None:
	lineas = ["# Claves de Orquestador. SECRETO: no lo compartas ni lo subas a git (ya esta en .gitignore).", ""]
	for k, _o, expl, _v in PEDIR:
		lineas.append(f"# {expl}")
		lineas.append(f"{k}={d.get(k, '')}")
	ENV.write_text("\n".join(lineas) + "\n", encoding="utf-8")
	_solo_yo(ENV)


def _solo_yo(p: Path) -> None:
	try:
		os.chmod(p, 0o600)
	except OSError:
		pass


def estado() -> dict:
	p = PRIVADO / "estado.json"
	if p.exists():
		try:
			return json.loads(p.read_text(encoding="utf-8"))
		except json.JSONDecodeError:
			return {}
	return {}


def guardar_estado(e: dict) -> None:
	PRIVADO.mkdir(exist_ok=True)
	(PRIVADO / "estado.json").write_text(json.dumps(e, indent=1, ensure_ascii=False), encoding="utf-8")


def _jwt_rol(k: str) -> str | None:
	if k.count(".") != 2:
		return None
	try:
		carga = k.split(".")[1]
		return json.loads(base64.urlsafe_b64decode(carga + "=" * (-len(carga) % 4))).get("role")
	except (ValueError, json.JSONDecodeError):
		return None


# ------------------------------------------------------------------ validar (sin red)

def validar(tipo: str, v: str) -> str | None:
	"""None si vale; si no, que le pasa."""
	if tipo == "url_supabase":
		return None if re.fullmatch(r"https://[a-z0-9]{20}\.supabase\.co/?", v) else "tiene que ser https://<20 letras>.supabase.co"
	if tipo == "anon":
		if v.startswith("sb_secret_") or _jwt_rol(v) == "service_role":
			return "esa es la clave SECRETA. Aqui va la anon / publishable (la publica)"
		return None if v.startswith("sb_publishable_") or _jwt_rol(v) == "anon" else "no parece la clave anon de Supabase"
	if tipo == "servicio":
		return None if v.startswith("sb_secret_") or _jwt_rol(v) == "service_role" else "no parece la clave service_role / secret"
	if tipo == "token_supabase":
		return None if v.startswith("sbp_") else "los tokens de la cuenta de Supabase empiezan por sbp_"
	if tipo == "anthropic":
		return None if v.startswith("sk-ant-") else "las claves de Anthropic empiezan por sk-ant-"
	if tipo == "token_github":
		return None if v.startswith(("ghp_", "github_pat_")) else "un token de GitHub empieza por ghp_ (classic)"
	if tipo == "correo":
		return None if re.fullmatch(r"[^@\s]+@[^@\s]+\.[a-z]{2,}", v, re.I) else "no parece un correo"
	if tipo == "archivo_json":
		p = Path(v).expanduser()
		if not p.exists():
			return f"no existe el archivo {p}"
		try:
			j = json.loads(p.read_text(encoding="utf-8"))
		except (OSError, json.JSONDecodeError):
			return "no es un JSON valido"
		return None if j.get("type") == "service_account" and j.get("client_email") else "no es el JSON de una cuenta de servicio"
	if tipo == "admob_app":
		return None if re.fullmatch(r"ca-app-pub-\d{16}~\d{10}", v) else "el ID de app de AdMob es ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"
	if tipo == "google_cliente":
		return None if re.fullmatch(r"\d+-[a-z0-9]+\.apps\.googleusercontent\.com", v) else "el ID de cliente de Google termina en .apps.googleusercontent.com"
	if tipo == "admob_bloque":
		return None if re.fullmatch(r"ca-app-pub-\d{16}/\d{10}", v) else "un bloque de AdMob es ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
	return None if v.strip() else "esta vacio"


def pedir_datos(interactivo: bool) -> dict[str, str]:
	d = leer_env()
	cambios = False
	for k, oblig, expl, tipo in PEDIR:
		v = d.get(k, "").strip()
		while True:
			if v:
				fallo = validar(tipo, v)
				if fallo is None:
					break
				decir(f"  {k}: {fallo}")
				if not interactivo:
					raise Parar(f"Corrige {k} en conectar.env: {fallo}")
				v = ""
			if not interactivo:
				if oblig:
					raise Parar(f"Falta {k} en conectar.env ({expl})")
				break
			decir(f"\n{k}\n  {expl}")
			v = input("  > " if oblig else "  (Intro para dejarlo) > ").strip()
			cambios = True
			if not v and not oblig:
				break
		d[k] = v
	if cambios or not ENV.exists():
		guardar_env(d)
		decir(f"\nGuardado en {ENV.name} (esta fuera de git).")
	d["SUPABASE_URL"] = d["SUPABASE_URL"].rstrip("/")
	d["SUPABASE_PROJECT_REF"] = d["SUPABASE_URL"].split("//")[1].split(".")[0]
	return d


# ------------------------------------------------------------------ comprobar (con red)

def _http(url: str, cabeceras: dict[str, str], cuerpo: bytes | None = None) -> tuple[int, dict, bytes]:
	req = urllib.request.Request(url, data=cuerpo, headers=cabeceras, method="POST" if cuerpo else "GET")
	try:
		with urllib.request.urlopen(req, timeout=20) as r:
			return r.status, dict(r.headers), r.read()
	except urllib.error.HTTPError as e:
		return e.code, dict(e.headers or {}), e.read()


def comprobar_claves(d: dict[str, str]) -> list[str]:
	"""Prueba cada clave contra su servicio (solo lecturas). Devuelve los problemas."""
	malos: list[str] = []

	def prueba(nombre: str, fn) -> None:
		try:
			fallo = fn()
		except (urllib.error.URLError, TimeoutError, OSError) as e:
			decir(f"  ?  {nombre}: no he podido conectar ({e}); sigo")
			return
		if fallo:
			malos.append(f"{nombre}: {fallo}")
			decir(f"  X  {nombre}: {fallo}")
		else:
			decir(f"  ok {nombre}")

	def supabase() -> str | None:
		c, _h, _b = _http(d["SUPABASE_URL"] + "/auth/v1/settings", {"apikey": d["SUPABASE_ANON_KEY"]})
		return None if c == 200 else f"la URL o la clave anon no valen (HTTP {c})"

	def servicio() -> str | None:
		c, _h, _b = _http(d["SUPABASE_URL"] + "/auth/v1/admin/users?per_page=1",
			{"apikey": d["SUPABASE_SERVICE_ROLE_KEY"], "Authorization": "Bearer " + d["SUPABASE_SERVICE_ROLE_KEY"]})
		return None if c == 200 else f"la clave service_role no vale para este proyecto (HTTP {c})"

	def cuenta_supabase() -> str | None:
		c, _h, b = _http("https://api.supabase.com/v1/projects", {"Authorization": "Bearer " + d["SUPABASE_ACCESS_TOKEN"]})
		if c != 200:
			return f"el token sbp_ no vale (HTTP {c})"
		refs = [p.get("id") or p.get("ref") for p in json.loads(b or b"[]")]
		return None if d["SUPABASE_PROJECT_REF"] in refs else "ese token no ve el proyecto de SUPABASE_URL (es de otra cuenta?)"

	def anthropic() -> str | None:
		c, _h, _b = _http("https://api.anthropic.com/v1/models?limit=1",
			{"x-api-key": d["ANTHROPIC_API_KEY"], "anthropic-version": "2023-06-01"})
		return None if c == 200 else f"la clave no vale (HTTP {c})"

	def runpod() -> str | None:
		c, _h, b = _http("https://api.runpod.io/graphql", {"Content-Type": "application/json",
			"Authorization": "Bearer " + d["RUNPOD_API_KEY"]}, json.dumps({"query": "query { myself { id } }"}).encode())
		ok = c == 200 and (json.loads(b or b"{}").get("data") or {}).get("myself")
		return None if ok else f"la clave no vale (HTTP {c})"

	def ghcr() -> str | None:
		c, h, _b = _http("https://api.github.com/user", {"Authorization": "token " + d["GHCR_TOKEN"]})
		if c != 200:
			return f"el token no vale (HTTP {c})"
		scopes = {s.strip() for s in (h.get("X-OAuth-Scopes") or h.get("x-oauth-scopes") or "").split(",")}
		if d["GHCR_TOKEN"].startswith("ghp_") and not ({"read:packages", "write:packages"} & scopes):
			return "le falta el permiso read:packages"
		return None

	prueba("Supabase (URL y anon)", supabase)
	prueba("Supabase (service_role)", servicio)
	prueba("Supabase (token de la cuenta)", cuenta_supabase)
	prueba("Anthropic", anthropic)
	prueba("RunPod", runpod)
	prueba("Token de GitHub (read:packages)", ghcr)
	return malos


# ------------------------------------------------------------------ generar

def _azar(n: int) -> str:
	abc = string.ascii_letters + string.digits
	return "".join(secrets.choice(abc) for _ in range(n))


def _cryptography():
	try:
		import cryptography  # noqa: F401
	except ImportError:
		decir("  Instalando 'cryptography' (para crear las llaves sin Java)...")
		subprocess.run([sys.executable, "-m", "pip", "install", "--user", "--quiet", "cryptography"], check=False)
		import importlib
		importlib.invalidate_caches()
	from cryptography import x509
	from cryptography.hazmat.primitives import hashes, serialization
	from cryptography.hazmat.primitives.asymmetric import ed25519, rsa
	from cryptography.hazmat.primitives.serialization import pkcs12
	from cryptography.x509.oid import NameOID
	return x509, hashes, serialization, rsa, ed25519, pkcs12, NameOID


def crear_llave_subida(ruta: Path, clave: str, nombre: str) -> None:
	"""Llave de subida de Google Play: PKCS12 (lo que crea keytool por defecto) con alias 'subida',
	RSA 4096 y 30 anos de validez (Google pide que dure mas alla de 2033)."""
	x509, hashes, serialization, rsa, _ed, pkcs12, NameOID = _cryptography()
	llave = rsa.generate_private_key(public_exponent=65537, key_size=4096)
	sujeto = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, nombre[:60] or "Orquestador"),
		x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Orquestador")])
	ahora = datetime.datetime.now(datetime.timezone.utc)
	cert = (x509.CertificateBuilder().subject_name(sujeto).issuer_name(sujeto).public_key(llave.public_key())
		.serial_number(x509.random_serial_number()).not_valid_before(ahora - datetime.timedelta(days=1))
		.not_valid_after(ahora + datetime.timedelta(days=365 * 30)).sign(llave, hashes.SHA256()))
	cifrado = (serialization.PrivateFormat.PKCS12.encryption_builder().kdf_rounds(50000)
		.key_cert_algorithm(pkcs12.PBES.PBESv2SHA256AndAES256CBC).hmac_hash(hashes.SHA256()).build(clave.encode()))
	ruta.write_bytes(pkcs12.serialize_key_and_certificates(b"subida", llave, cert, None, cifrado))
	_solo_yo(ruta)


def crear_llave_ssh(ruta: Path) -> str:
	"""Llave de despliegue (ed25519) para la web publica. Devuelve la publica."""
	_x, _h, serialization, _r, ed25519, _p, _n = _cryptography()
	k = ed25519.Ed25519PrivateKey.generate()
	ruta.write_bytes(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.OpenSSH,
		serialization.NoEncryption()))
	_solo_yo(ruta)
	pub = k.public_key().public_bytes(serialization.Encoding.OpenSSH, serialization.PublicFormat.OpenSSH).decode()
	(ruta.with_suffix(".pub")).write_text(pub + " orquestador-web\n", encoding="utf-8")
	return pub


def generar(d: dict[str, str], e: dict) -> None:
	PRIVADO.mkdir(exist_ok=True)
	g = e.setdefault("generado", {})
	if not g.get("ORQ_LLAVES_SECRETO"):
		g["ORQ_LLAVES_SECRETO"] = _azar(40)
		decir("  Secreto que cifra las llaves de firma de los usuarios: creado")
	if not g.get("ORQ_REVISOR"):
		usuario, dominio = d["ORQ_CORREO"].split("@", 1)
		g["ORQ_REVISOR"] = f"{usuario.split('+')[0]}+revisor@{dominio}:{secrets.randbelow(900000) + 100000}"
		decir("  Cuenta para el revisor de Google: creada")
	llave = PRIVADO / "subida.p12"
	if not llave.exists() or not g.get("ORQ_APP_KEYSTORE_PASS"):
		g["ORQ_APP_KEYSTORE_PASS"] = _azar(32)
		crear_llave_subida(llave, g["ORQ_APP_KEYSTORE_PASS"], d.get("ORQ_RESPONSABLE", ""))
		decir("  Llave de subida de la app (Google Play): creada en .conectar/subida.p12")
	guardar_estado(e)
	d.update(g)
	d["ORQ_APP_KEYSTORE_B64"] = base64.b64encode(llave.read_bytes()).decode()
	if d.get("ORQ_PLAY_CUENTA"):
		j = json.loads(Path(d["ORQ_PLAY_CUENTA"]).expanduser().read_text(encoding="utf-8"))
		d["ORQ_PLAY_CUENTA"] = json.dumps(j, separators=(",", ":"))
		d["ORQ_PLAY_CUENTA_CORREO"] = j["client_email"]
		d["ORQ_PLAY_TIENDA_CUENTA"] = d["ORQ_PLAY_CUENTA"]
	d["ORQ_APP_PAQUETE"] = PAQUETE
	d["ORQ_PLAY_URL"] = f"https://play.google.com/store/apps/details?id={PAQUETE}"
	d["ADMOB_REWARDED_AD_UNIT"] = d.get("ORQ_APP_ADMOB_PREMIO", "")
	## Copia legible de lo que no se puede perder.
	(PRIVADO / "GUARDA-ESTO.txt").write_text(
		"Guarda esta carpeta (.conectar) en un sitio seguro: un gestor de contrasenas o un USB.\n\n"
		f"ORQ_LLAVES_SECRETO={g['ORQ_LLAVES_SECRETO']}\n  (cifra las llaves de firma de los juegos de tus usuarios: sin el no se pueden actualizar)\n\n"
		f"Llave de subida de la app: subida.p12  alias=subida  clave={g['ORQ_APP_KEYSTORE_PASS']}\n\n"
		f"Revisor de Google Play: {g['ORQ_REVISOR']}\n", encoding="utf-8")
	_solo_yo(PRIVADO / "GUARDA-ESTO.txt")


# ------------------------------------------------------------------ GitHub

def gh(*args: str, entrada: str | None = None, ok: tuple[int, ...] = (0,)) -> str:
	return correr([GH, *args], entrada=entrada, ok=ok)


def configurar_supabase(d: dict[str, str]) -> bool:
	"""Ajustes del panel de Supabase que no van en las migraciones: correo con codigo y cuentas
	confirmadas (asi nadie crea cuentas falsas para las tuercas de bienvenida)."""
	cuerpo = {
		"mailer_autoconfirm": False,
		"mailer_subjects_magic_link": CORREO_ASUNTO,
		"mailer_templates_magic_link_content": CORREO_CUERPO,
		"mailer_subjects_confirmation": CORREO_ASUNTO,
		"mailer_templates_confirmation_content": CORREO_CUERPO,
	}
	if d.get("ORQ_WEB"):
		cuerpo["site_url"] = d["ORQ_WEB"]
		## La web vuelve aqui despues de elegir la cuenta de Google.
		cuerpo["uri_allow_list"] = d["ORQ_WEB"].rstrip("/") + "/**"
	## Entrar con Google: la app Android manda el id_token del selector de cuentas (audiencia = el
	## cliente web) y la web usa la redireccion de siempre. El secreto solo va a Supabase.
	if d.get("GOOGLE_OAUTH_CLIENT_ID") and d.get("GOOGLE_OAUTH_CLIENT_SECRET"):
		cuerpo["external_google_enabled"] = True
		cuerpo["external_google_client_id"] = d["GOOGLE_OAUTH_CLIENT_ID"]
		cuerpo["external_google_secret"] = d["GOOGLE_OAUTH_CLIENT_SECRET"]
	## Servidor de correo propio: el plan gratis de Supabase solo deja cambiar las plantillas con uno.
	usuario = d.get("ORQ_SMTP_USUARIO", "")
	if usuario and d.get("ORQ_SMTP_CLAVE"):
		gmail = usuario.lower().endswith(("@gmail.com", "@googlemail.com"))
		cuerpo.update({
			"smtp_host": d.get("ORQ_SMTP_HOST") or ("smtp.gmail.com" if gmail else "smtp." + usuario.split("@")[1]),
			"smtp_port": d.get("ORQ_SMTP_PUERTO") or "587",
			"smtp_user": usuario, "smtp_pass": d["ORQ_SMTP_CLAVE"],
			"smtp_admin_email": usuario, "smtp_sender_name": "Orquestador",
		})
	url = f"{SUPABASE_API}/v1/projects/{d['SUPABASE_PROJECT_REF']}/config/auth"

	def enviar(c: dict) -> tuple[bool, str]:
		req = urllib.request.Request(url, data=json.dumps(c).encode(), method="PATCH", headers={
			"Authorization": "Bearer " + d["SUPABASE_ACCESS_TOKEN"], "Content-Type": "application/json"})
		try:
			with urllib.request.urlopen(req, timeout=30) as r:
				return 200 <= r.status < 300, ""
		except urllib.error.HTTPError as e:
			return False, e.read()[:300].decode("utf-8", "replace")
		except (urllib.error.URLError, TimeoutError, OSError):
			return False, ""

	ok, motivo = enviar(cuerpo)
	if not ok and "smtp" in motivo.lower() and "smtp_host" not in cuerpo:
		## Sin correo propio: aplica lo demas y avisa (sin el codigo en el correo la app no deja entrar).
		resto = {k: v for k, v in cuerpo.items() if not k.startswith("mailer_subjects") and not k.startswith("mailer_templates")}
		enviar(resto)
		decir("  AVISO: Supabase gratis no deja poner el codigo en el correo sin un servidor de correo propio.\n"
			"  Rellena ORQ_SMTP_USUARIO y ORQ_SMTP_CLAVE en conectar.env (vale tu Gmail con una contrasena de\n"
			"  aplicacion) y vuelve a lanzar conectar.py. Hasta entonces la app no puede enviar el codigo de entrada.")
		return False
	if ok:
		decir("  Supabase: correo con codigo y confirmacion de cuenta, listos"
			+ (" (y Entrar con Google)" if cuerpo.get("external_google_enabled") else ""))
	else:
		decir("  AVISO: no he podido ajustar el correo de Supabase. Hazlo a mano: Authentication -> Email Templates ->\n"
			"  'Confirm signup' y 'Magic Link': que el texto incluya {{ .Token }} (el codigo de 6 cifras).")
	return ok


def herramientas() -> dict:
	correr([GIT, "--version"])
	try:
		gh("auth", "status")
	except Parar as e:
		if "No encuentro" in str(e):
			raise
		raise Parar("No has iniciado sesion en GitHub CLI. Ejecuta:  gh auth login   (y vuelve a lanzar conectar.py)") from e
	## Que git use la sesion de gh para subir (sin pedir contrasena).
	gh("auth", "setup-git", ok=(0, 1))
	u = json.loads(gh("api", "user"))
	plan = ((u.get("plan") or {}).get("name") or "free").lower()
	decir(f"  GitHub: {u['login']} (plan {plan})")
	return {"login": u["login"], "plan": plan}


def repo_existe(nombre: str) -> bool:
	try:
		gh("repo", "view", nombre, "--json", "name")
		return True
	except Parar:
		return False


def preparar_repo(cuenta: dict, nombre: str) -> str:
	completo = f"{cuenta['login']}/{nombre}"
	if repo_existe(completo):
		decir(f"  Repositorio {completo}: ya existe")
	else:
		gh("repo", "create", completo, "--private", "--description", "Orquestador: crea juegos con IA")
		decir(f"  Repositorio {completo}: creado (privado)")
	return completo


def guardar_en_github(repo: str, d: dict[str, str], extra_secretos: dict[str, str]) -> None:
	for k in VARIABLES:
		assert k not in NUNCA_VARIABLE, k
	n = 0
	for k in SECRETOS:
		v = d.get(k, "")
		if v:
			gh("secret", "set", k, "-R", repo, entrada=v)
			n += 1
	for k, v in extra_secretos.items():
		gh("secret", "set", k, "-R", repo, entrada=v)
		n += 1
	m = 0
	for k in VARIABLES:
		v = d.get(k, "")
		if v:
			gh("variable", "set", k, "-R", repo, "--body", v)
			m += 1
	decir(f"  {n} secretos y {m} variables guardados en GitHub")


def preparar_web(cuenta: dict, repo: str, d: dict[str, str], e: dict) -> dict[str, str]:
	"""Web publica en GitHub Pages. Con cuenta gratis Pages no publica repositorios privados: se
	crea uno PUBLICO solo con la web y una llave que solo puede escribir en el."""
	login = cuenta["login"]
	extra: dict[str, str] = {}
	if cuenta["plan"] == "free":
		web = f"{repo}-web"
		if not repo_existe(web):
			gh("repo", "create", web, "--public", "--add-readme", "--description", "Web publica de Orquestador")
			decir(f"  Repositorio publico de la web {web}: creado")
		llave = PRIVADO / "web_deploy"
		if not llave.exists() or not e.get("web_llave_puesta"):
			crear_llave_ssh(llave)
			gh("repo", "deploy-key", "add", str(llave.with_suffix(".pub")), "-R", web, "-w", "-t", "orquestador-web")
			e["web_llave_puesta"] = True
			guardar_estado(e)
		extra["ORQ_WEB_DEPLOY_KEY"] = llave.read_text(encoding="utf-8")
		d["ORQ_WEB_REPO"] = web
		gh("variable", "set", "ORQ_WEB_REPO", "-R", repo, "--body", web)
		gh("api", "-X", "POST", f"repos/{web}/pages", "-f", "source[branch]=main", "-f", "source[path]=/", ok=(0, 1))
		d["ORQ_WEB"] = f"https://{login.lower()}.github.io/{web.split('/')[1]}"
	else:
		gh("api", "-X", "POST", f"repos/{repo}/pages", "-f", "build_type=workflow", ok=(0, 1))
		d["ORQ_WEB"] = f"https://{login.lower()}.github.io/{repo.split('/')[1]}"
	decir(f"  Web publica: {d['ORQ_WEB']}")
	return extra


def subir_codigo(repo: str) -> str:
	gi = RAIZ / ".gitignore"
	actual = gi.read_text(encoding="utf-8") if gi.exists() else ""
	if ".conectar/" not in actual:
		gi.write_text(actual + ("\n" if actual and not actual.endswith("\n") else "") + GITIGNORE, encoding="utf-8")
	if not (RAIZ / ".git").exists():
		correr([GIT, "init", "-q", "-b", "main"])
	remoto = REMOTO.format(repo=repo)
	if correr([GIT, "remote"]).split().count("origin"):
		correr([GIT, "remote", "set-url", "origin", remoto])
	else:
		correr([GIT, "remote", "add", "origin", remoto])
	correr([GIT, "add", "-A"])
	## Red de seguridad: nada secreto en lo que se va a subir.
	preparados = correr([GIT, "diff", "--cached", "--name-only"]).split()
	prohibido = [f for f in preparados if f.startswith(".conectar/") or f == "conectar.env" or f.endswith((".p12", ".jks", ".keystore"))]
	if prohibido:
		raise Parar(f"Iba a subir archivos secretos: {prohibido}. Revisa .gitignore")
	if preparados:
		correr([GIT, "-c", "user.name=Orquestador", "-c", "user.email=orquestador@users.noreply.github.com",
			"commit", "-qm", "Orquestador"])
	correr([GIT, "push", "-u", "origin", "main"])
	sha = correr([GIT, "rev-parse", "HEAD"]).strip()
	decir(f"  Codigo subido ({sha[:7]})")
	return sha


def _ultima_ejecucion(repo: str, flujo: str, evento: str | None = None, sha: str | None = None,
		desde: str = "") -> dict | None:
	campos = "databaseId,status,conclusion,event,headSha,createdAt"
	runs = json.loads(gh("run", "list", "-R", repo, "-w", flujo, "-L", "10", "--json", campos) or "[]")
	for r in runs:
		if (evento is None or r["event"] == evento) and (sha is None or r["headSha"] == sha) and r.get("createdAt", "") >= desde:
			return r
	return None


def _ahora() -> str:
	return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _esperar_ejecucion(repo: str, flujo: str, evento: str | None, sha: str | None, segundos: int = 120,
		desde: str = "") -> dict:
	fin = time.time() + segundos
	while True:
		r = _ultima_ejecucion(repo, flujo, evento, sha, desde)
		if r:
			return r
		if time.time() >= fin:
			break
		time.sleep(PAUSA)
	raise Parar(f"GitHub no ha arrancado '{flujo}'. Mira la pestana Actions del repositorio")


def desplegar(repo: str, sha: str, esperar: bool) -> None:
	"""La subida lanza 'Desplegar' sin descargar modelos; la primera vez hace falta con
	primera_vez=true: se cancela la automatica y se lanza la buena."""
	try:
		auto = _esperar_ejecucion(repo, "desplegar.yml", "push", sha, 60)
		if auto["status"] != "completed":
			gh("run", "cancel", str(auto["databaseId"]), "-R", repo, ok=(0, 1))
	except Parar:
		pass
	desde = _ahora()
	gh("workflow", "run", "desplegar.yml", "-R", repo, "-f", "primera_vez=true")
	decir("  Desplegar (primera vez) lanzado: imagenes, RunPod, modelos, motor web y Supabase")
	if not esperar:
		return
	r = _esperar_ejecucion(repo, "desplegar.yml", "workflow_dispatch", None, desde=desde)
	decir("  Esperando a que termine (30-60 min la primera vez; puedes dejarlo corriendo)...")
	gh("run", "watch", str(r["databaseId"]), "-R", repo, "--exit-status", "-i", "30", ok=(0,))
	decir("  Nube desplegada")


def compilar_app(repo: str, sha: str, esperar: bool) -> Path | None:
	try:
		r = _esperar_ejecucion(repo, "app.yml", "push", sha, 60)
	except Parar:
		desde = _ahora()
		gh("workflow", "run", "app.yml", "-R", repo)
		r = _esperar_ejecucion(repo, "app.yml", "workflow_dispatch", None, desde=desde)
	decir("  App Android compilandose en GitHub (unos 10 min)")
	if not esperar:
		return None
	gh("run", "watch", str(r["databaseId"]), "-R", repo, "--exit-status", "-i", "20", ok=(0,))
	SALIDA.mkdir(exist_ok=True)
	gh("run", "download", str(r["databaseId"]), "-R", repo, "-D", str(SALIDA))
	aabs = sorted(SALIDA.rglob("*.aab"))
	apks = sorted(SALIDA.rglob("*.apk"))
	if apks:
		decir(f"  APK de prueba: {apks[-1]}")
	if not aabs:
		raise Parar("La app compilo pero sin .aab (falta la llave de subida en los secretos?)")
	decir(f"  .aab para Google Play: {aabs[-1]}")
	return aabs[-1]


# ------------------------------------------------------------------ final

def siguientes_pasos(d: dict[str, str], aab: Path | None) -> str:
	correo_rev, codigo_rev = d["ORQ_REVISOR"].rsplit(":", 1)
	web = d["ORQ_WEB"]
	t = f"""PASOS QUE SOLO PUEDES HACER TU (Google no deja automatizarlos)

1. Play Console (play.google.com/console, pago unico de 25 $) -> Crear app
   Nombre: Orquestador: crea tu juego   Idioma: espanol (Espana)   App   Gratis
2. Prueba interna -> Crear version -> sube {aab or 'salida/...aab (Actions -> App Android -> Artifacts)'}
   Acepta "Firma de apps de Google Play" (Google guarda la llave final; la tuya es la de subida).
3. Ficha de la tienda: textos de app/tienda/ficha.json, icono y grafico de app/assets/play/,
   capturas de app/tienda/capturas/. Categoria: Entretenimiento.
4. Contenido de la aplicacion:
   - Politica de privacidad: {web}/privacidad.html
   - Acceso a la app -> "Toda o parte de la funcionalidad esta restringida" -> instrucciones:
       Escribe el correo {correo_rev}, pulsa "Enviarme el codigo" y escribe el codigo {codigo_rev}
   - Borrar cuenta: {web}/borrar-cuenta.html
   - Anuncios: Si. Publico objetivo: 16+. Seguridad de los datos: tabla de LANZAR-APP-LEEME.md (apartado 4)
5. Monetizar -> Productos: consumibles tuercas_300, tuercas_1100, tuercas_3600 y la suscripcion
   premium_mensual. Usuarios y permisos -> la cuenta de servicio con "Ver datos financieros" y
   "Gestionar pedidos y suscripciones".
6. Cuenta personal nueva: prueba cerrada con 12 probadores durante 14 dias antes de produccion
   (la Lanzadera de Orquestador sirve justo para eso con tus propios juegos).
7. Comprueba que abren: {web}/privacidad.html  {web}/terminos.html  {web}/borrar-cuenta.html
"""
	if not d.get("ORQ_APP_ADMOB_APP_ID"):
		t += "\nAdMob (cuando quieras anuncios): crea la app y un bloque 'Bonificado', ponlos en conectar.env y vuelve a lanzar conectar.py.\n"
	if d.get("GOOGLE_OAUTH_CLIENT_ID"):
		t += ("\nEntrar con Google en el movil: Google Cloud -> Credenciales -> Crear ID de cliente OAuth -> Android, con el\n"
			"paquete com.orquestador.app y la huella SHA-1 de la llave de SUBIDA y la de Play Console -> Integridad de la app\n"
			"-> Certificado de la llave de firma (un cliente Android por cada huella). En la pantalla de consentimiento,\n"
			"publicala (o anade tus cuentas de prueba). El cliente web ya esta puesto en Supabase y en la app.\n")
	else:
		t += ("\nEntrar con Google (cuando quieras): Google Cloud -> Credenciales -> ID de cliente OAuth 'Aplicacion web';\n"
			"pon su ID y su secreto en GOOGLE_OAUTH_CLIENT_ID y GOOGLE_OAUTH_CLIENT_SECRET de conectar.env y vuelve a lanzar conectar.py.\n")
	if not d.get("ORQ_PLAY_CUENTA"):
		t += ("\nPublicar los juegos de tus usuarios: Google Cloud -> cuenta de servicio -> clave JSON; en Play Console\n"
			"-> Usuarios y permisos -> invitala. Pon la ruta del JSON en ORQ_PLAY_CUENTA y vuelve a lanzar conectar.py.\n")
	t += "\nLuego sigue PRUEBA-REAL.md para probarlo todo con dos moviles.\n"
	return t


# ------------------------------------------------------------------ revisar (despues de desplegar)

FUNCIONES_CLAVE = ["create-game", "plan-change", "apply-change", "ganchos", "delete-account", "review-login", "escaparate"]
SECRETOS_IMPRESCINDIBLES = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_PROJECT_REF",
	"SUPABASE_ACCESS_TOKEN", "SUPABASE_DB_PASSWORD", "ANTHROPIC_API_KEY", "RUNPOD_API_KEY", "GHCR_TOKEN",
	"ORQ_LLAVES_SECRETO", "ORQ_APP_KEYSTORE_B64", "ORQ_APP_KEYSTORE_PASS"]
RUNPOD_REST = os.environ.get("ORQ_RUNPOD_REST", "https://rest.runpod.io/v1").rstrip("/")


def _pedir(url: str, cabeceras: dict[str, str] | None = None, metodo: str = "GET") -> tuple[int, bytes]:
	req = urllib.request.Request(url, headers=cabeceras or {}, method=metodo)
	try:
		with urllib.request.urlopen(req, timeout=20) as r:
			return r.status, r.read()
	except urllib.error.HTTPError as e:
		return e.code, e.read() or b""
	except (urllib.error.URLError, TimeoutError, OSError):
		return 0, b""


def revisar(nombre_repo: str) -> int:
	"""Revisa el sistema YA desplegado, de punta a punta, sin cambiar nada. Cada fallo dice como
	arreglarlo. Deja el informe en salida/REVISION.txt."""
	d = leer_env()
	e = estado()
	g = e.get("generado", {})
	malos: list[str] = []
	lineas: list[str] = []

	def marca(ok: bool, que: str, arreglo: str = "") -> None:
		lineas.append(("  ok " if ok else "  X  ") + que + ("" if ok or not arreglo else f"\n       -> {arreglo}"))
		decir(lineas[-1])
		if not ok:
			malos.append(que)

	if not d.get("SUPABASE_URL"):
		decir("No hay conectar.env: lanza antes  python conectar.py")
		return 2
	url = d["SUPABASE_URL"].rstrip("/")
	ref = url.split("//")[1].split(".")[0]
	srv = d.get("SUPABASE_SERVICE_ROLE_KEY", "")
	cab_srv = {"apikey": srv, "Authorization": "Bearer " + srv}

	titulo(1, "GitHub")
	repo = e.get("repo", "")
	try:
		if not repo:
			repo = f"{json.loads(gh('api', 'user'))['login']}/{nombre_repo}"
		nombres = {x["name"] for x in json.loads(gh("secret", "list", "-R", repo, "--json", "name") or "[]")}
		faltan = [k for k in SECRETOS_IMPRESCINDIBLES if k not in nombres]
		marca(not faltan, f"secretos del repositorio {repo}", f"faltan {faltan}: vuelve a lanzar  python conectar.py")
		for flujo, que in (("desplegar.yml", "despliegue de la nube"), ("app.yml", "compilacion de la app"), ("web.yml", "web publica")):
			r = _ultima_ejecucion(repo, flujo)
			if not r:
				marca(False, f"{que}: nunca se ha ejecutado", f"GitHub -> Actions -> {flujo} -> Run workflow")
				continue
			if r["status"] != "completed":
				marca(True, f"{que}: en marcha ahora mismo (espera a que termine y revisa otra vez)")
				continue
			ok = r["conclusion"] == "success"
			if not ok:
				SALIDA.mkdir(exist_ok=True)
				log = gh("run", "view", str(r["databaseId"]), "-R", repo, "--log-failed", ok=(0, 1))
				(SALIDA / f"fallo-{flujo.split('.')[0]}.txt").write_text(log[-20000:], encoding="utf-8")
			marca(ok, f"{que}: ultima ejecucion {r['conclusion']}",
				f"el final del registro esta en salida/fallo-{flujo.split('.')[0]}.txt: pasamelo")
	except Parar as ex:
		marca(False, "GitHub", str(ex).splitlines()[0])

	titulo(2, "Web publica")
	web = ""
	try:
		vs = {x["name"]: x["value"] for x in json.loads(gh("variable", "list", "-R", repo, "--json", "name,value") or "[]")}
		web = vs.get("ORQ_WEB", "")
	except Parar:
		pass
	if not web:
		marca(False, "variable ORQ_WEB", "vuelve a lanzar  python conectar.py")
	else:
		for pagina in ("privacidad.html", "terminos.html", "borrar-cuenta.html"):
			c, _b = _pedir(f"{web}/{pagina}")
			marca(c == 200, f"{web}/{pagina}", "la web aun no esta publicada: revisa la ejecucion 'web' en Actions")
		c, b = _pedir(f"{web}/config.js")
		texto = b.decode("utf-8", "replace")
		marca(c == 200 and "__SUPABASE_URL__" not in texto and "__ORQ_CORREO__" not in texto,
			"la web lleva tus datos (Supabase y correo)", "faltan variables en GitHub: vuelve a lanzar  python conectar.py")

	titulo(3, "Supabase")
	c, b = _pedir(f"{url}/rest/v1/settings?select=key&limit=1", cab_srv)
	marca(c == 200 and b.strip() not in (b"", b"[]"), "base de datos con las migraciones aplicadas",
		"el paso 'supabase' del despliegue no ha terminado: revisa 'desplegar' en Actions")
	for f in FUNCIONES_CLAVE:
		c, _b = _pedir(f"{url}/functions/v1/{f}", {"Origin": "https://localhost"}, "OPTIONS")
		marca(c in (200, 204), f"funcion {f}", "las funciones no se han desplegado: revisa 'desplegar' en Actions")
	c, _b = _pedir(f"{url}/storage/v1/object/public/motor/godot/4.6.3/index.js", metodo="HEAD")
	marca(c == 200, "motor web de Godot («Jugar ya» en la app)",
		"lanza Actions -> Desplegar -> Run workflow con 'Primera vez' marcado")
	if d.get("SUPABASE_ACCESS_TOKEN"):
		c, b = _pedir(f"{SUPABASE_API}/v1/projects/{ref}/config/auth", {"Authorization": "Bearer " + d["SUPABASE_ACCESS_TOKEN"]})
		conf = json.loads(b or b"{}") if c == 200 else {}
		marca(c == 200 and "{{ .Token }}" in str(conf.get("mailer_templates_confirmation_content", ""))
			and "{{ .Token }}" in str(conf.get("mailer_templates_magic_link_content", "")),
			"el correo de entrada lleva el codigo de 6 cifras",
			"vuelve a lanzar  python conectar.py  (o Authentication -> Email Templates: pon {{ .Token }})")
	revisor = g.get("ORQ_REVISOR", "")
	if revisor:
		correo, codigo = revisor.rsplit(":", 1)
		req = urllib.request.Request(f"{url}/functions/v1/review-login", method="POST",
			data=json.dumps({"email": correo, "codigo": codigo}).encode(),
			headers={"Content-Type": "application/json", "apikey": d.get("SUPABASE_ANON_KEY", "")})
		try:
			with urllib.request.urlopen(req, timeout=30) as r:
				ok = r.status == 200 and "access_token" in r.read().decode()
		except (urllib.error.URLError, TimeoutError, OSError):
			ok = False
		marca(ok, "el revisor de Google puede entrar (correo y codigo de Play Console)",
			"falta el secreto ORQ_REVISOR en Supabase: vuelve a lanzar 'desplegar' en Actions")

	titulo(4, "RunPod")
	c, b = _pedir(f"{RUNPOD_REST}/endpoints", {"Authorization": "Bearer " + d.get("RUNPOD_API_KEY", "")})
	if c != 200:
		marca(False, "RunPod", f"no responde con tu clave (HTTP {c})")
	else:
		lista = json.loads(b or b"[]")
		lista = lista if isinstance(lista, list) else lista.get("data", [])
		hay = {x.get("name") for x in lista}
		for ep in ("orq-fabrica", "orq-imagenes", "orq-voces"):
			marca(ep in hay, f"endpoint {ep}", "el paso 'runpod' del despliegue no ha terminado: revisa 'desplegar' en Actions")

	SALIDA.mkdir(exist_ok=True)
	resumen = ("TODO BIEN: ya puedes crear un juego desde la app." if not malos else
		f"{len(malos)} cosa(s) por arreglar (arriba dice como).")
	(SALIDA / "REVISION.txt").write_text("\n".join(lineas) + "\n\n" + resumen + "\n", encoding="utf-8")
	decir("\n" + resumen)
	return 0 if not malos else 1


def comprobar_entorno(con_red: bool) -> int:
	"""En GitHub Actions, antes de desplegar: los secretos existen y tienen buena pinta. Asi un
	secreto mal pegado para en 10 segundos con un mensaje claro, y no a los 40 minutos."""
	d = {k: os.environ.get(k, "").strip() for k, *_r in PEDIR}
	for k in ("SUPABASE_PROJECT_REF",):
		d[k] = os.environ.get(k, "").strip()
	malos = []
	for k, oblig, expl, tipo in PEDIR:
		if tipo in ("archivo_json", "correo") or k.startswith("ORQ_APP_ADMOB") or k == "ORQ_RESPONSABLE":
			continue
		v = d.get(k, "")
		if not v:
			if oblig:
				malos.append(f"falta el secreto {k} ({expl})")
			continue
		fallo = validar(tipo, v)
		if fallo:
			malos.append(f"{k}: {fallo}")
	if d.get("SUPABASE_URL") and d.get("SUPABASE_PROJECT_REF") and d["SUPABASE_PROJECT_REF"] not in d["SUPABASE_URL"]:
		malos.append("SUPABASE_PROJECT_REF no coincide con SUPABASE_URL")
	if not malos and con_red:
		d["SUPABASE_URL"] = d["SUPABASE_URL"].rstrip("/")
		d["SUPABASE_PROJECT_REF"] = d["SUPABASE_PROJECT_REF"] or d["SUPABASE_URL"].split("//")[1].split(".")[0]
		malos += comprobar_claves(d)
	for m in malos:
		print(f"::error::{m}")
	if malos:
		print("Arreglalo en GitHub -> Settings -> Secrets and variables -> Actions (o vuelve a lanzar conectar.py)")
		return 1
	print("Secretos correctos")
	return 0


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(description="Conecta Orquestador con tus cuentas")
	ap.add_argument("--repo", default="orquestador")
	ap.add_argument("--sin-red", action="store_true")
	ap.add_argument("--sin-esperar", action="store_true")
	ap.add_argument("--solo-comprobar", action="store_true")
	ap.add_argument("--no-interactivo", action="store_true")
	ap.add_argument("--revisar", action="store_true", help="revisa que todo funcione ya desplegado (no cambia nada)")
	ap.add_argument("--entorno", action="store_true", help="(GitHub Actions) comprueba los secretos del entorno y para si hay alguno mal")
	a = ap.parse_args(argv)
	interactivo = not a.no_interactivo and sys.stdin.isatty()
	if a.entorno:
		return comprobar_entorno(not a.sin_red)
	if a.revisar:
		return revisar(a.repo)
	try:
		titulo(1, "Herramientas")
		cuenta = herramientas()
		titulo(2, "Tus claves")
		d = pedir_datos(interactivo)
		if not a.sin_red:
			malos = comprobar_claves(d)
			if malos:
				raise Parar("Arregla esto en conectar.env y vuelve a lanzar:\n  - " + "\n  - ".join(malos))
		if a.solo_comprobar:
			decir("\nTodo correcto.")
			return 0
		e = estado()
		titulo(3, "Llaves y secretos propios")
		generar(d, e)
		titulo(4, "Repositorio y secretos en GitHub")
		repo = preparar_repo(cuenta, a.repo)
		titulo(5, "Web publica")
		extra = preparar_web(cuenta, repo, d, e)
		guardar_en_github(repo, d, extra)
		if not a.sin_red:
			configurar_supabase(d)
		titulo(6, "Subir y desplegar")
		sha = subir_codigo(repo)
		e["repo"], e["sha"] = repo, sha
		guardar_estado(e)
		desplegar(repo, sha, not a.sin_esperar)
		titulo(7, "App para Google Play")
		aab = compilar_app(repo, sha, not a.sin_esperar)
		SALIDA.mkdir(exist_ok=True)
		pasos = siguientes_pasos(d, aab)
		(SALIDA / "SIGUIENTES-PASOS.txt").write_text(pasos, encoding="utf-8")
		decir()
		decir(pasos)
		decir("Copia la carpeta .conectar/ a un sitio seguro (ver .conectar/GUARDA-ESTO.txt).")
		return 0
	except Parar as e:
		decir(f"\nPARADO: {e}")
		return 2
	except KeyboardInterrupt:
		decir("\nCancelado. Vuelve a lanzarlo cuando quieras: sigue donde se quedo.")
		return 130


if __name__ == "__main__":
	sys.exit(main())
