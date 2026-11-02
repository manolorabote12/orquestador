"""Prueba de conectar.py sin cuentas: GitHub CLI simulado y un repositorio git local.

	python nube/prueba_conectar.py

Comprueba que:
1 - Los secretos van a secretos (por la entrada estandar) y NUNCA a variables ni al codigo subido.
2 - La llave de subida es un PKCS12 valido con alias "subida" que Java sabe usar para firmar.
3 - Con cuenta gratis se crea el repositorio publico de la web con su llave de despliegue.
4 - Se cancela el despliegue automatico y se lanza el de "primera vez"; se descarga el .aab.
5 - Si se vuelve a lanzar, no regenera las llaves ni duplica nada.
6 - Las claves mal pegadas se detectan antes de tocar nada.
"""

import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
fallos = 0


def check(nombre: str, ok: bool, detalle: str = "") -> None:
	global fallos
	print(("  OK   " if ok else "  FALLO ") + nombre + (f"  ({detalle})" if detalle and not ok else ""))
	if not ok:
		fallos += 1


GH_FALSO = r'''
import json, os, sys, subprocess, datetime
from pathlib import Path
E = Path(os.environ["FALSO_ESTADO"])
st = json.loads(E.read_text()) if E.exists() else {"repos": [], "secretos": {}, "variables": {}, "llamadas": [], "runs": [], "plan": os.environ.get("FALSO_PLAN", "free")}
a = sys.argv[1:]
entrada = sys.stdin.read() if not sys.stdin.isatty() else ""
st["llamadas"].append(a)
def fin(codigo=0, salida=""):
	E.write_text(json.dumps(st))
	sys.stdout.write(salida)
	sys.exit(codigo)
def sha():
	r = subprocess.run(["git", "--git-dir", os.environ["FALSO_BARE"], "rev-parse", "main"], capture_output=True, text=True)
	return r.stdout.strip()
ahora = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
if a[:2] == ["auth", "status"] or a[:2] == ["auth", "setup-git"]:
	fin()
if a[:2] == ["api", "user"]:
	fin(0, json.dumps({"login": "Daniel", "plan": {"name": st["plan"]}}))
if a[:2] == ["repo", "view"]:
	fin(0 if a[2] in st["repos"] else 1, "{}")
if a[:2] == ["repo", "create"]:
	st["repos"].append(a[2]); st.setdefault("publicos", []).append(a[2]) if "--public" in a else None
	fin()
if a[:3] == ["repo", "deploy-key", "add"]:
	st["deploy_key"] = Path(a[3]).read_text(); fin()
if a[:2] == ["secret", "set"]:
	assert "--body" not in a, "secreto en la linea de comandos"
	st["secretos"][a[2]] = entrada; fin()
if a[:2] == ["variable", "set"]:
	st["variables"][a[2]] = a[a.index("--body") + 1]; fin()
if a[0] == "api":
	st.setdefault("pages", []).append(a); fin()
if a[:2] == ["run", "list"]:
	flujo = a[a.index("-w") + 1]
	s = sha()
	runs = [r for r in st["runs"] if r["flujo"] == flujo]
	if s and flujo in ("desplegar.yml", "app.yml", "web.yml") and not any(r["event"] == "push" and r["headSha"] == s for r in runs):
		st["runs"].append({"flujo": flujo, "databaseId": len(st["runs"]) + 1, "status": "in_progress", "conclusion": "", "event": "push", "headSha": s, "createdAt": ahora})
	runs = [r for r in st["runs"] if r["flujo"] == flujo]
	fin(0, json.dumps(list(reversed(runs))))
if a[:2] == ["run", "cancel"]:
	st.setdefault("cancelados", []).append(a[2]); fin()
if a[:2] == ["workflow", "run"]:
	st["runs"].append({"flujo": a[2], "databaseId": len(st["runs"]) + 1, "status": "queued", "conclusion": "", "event": "workflow_dispatch", "headSha": sha(), "createdAt": ahora, "inputs": a[3:]})
	fin()
if a[:2] == ["secret", "list"]:
	fin(0, json.dumps([{"name": k} for k in st["secretos"]]))
if a[:2] == ["variable", "list"]:
	fin(0, json.dumps([{"name": k, "value": v} for k, v in st["variables"].items()]))
if a[:2] == ["run", "view"]:
	fin(0, "linea 1\nError: algo fallo en la nube\n")
if a[:2] == ["run", "watch"]:
	fin()
if a[:2] == ["run", "download"]:
	d = Path(a[a.index("-D") + 1]) / "orquestador-android-1"
	d.mkdir(parents=True, exist_ok=True)
	(d / "app-release.aab").write_bytes(b"aab"); (d / "app-debug.apk").write_bytes(b"apk"); fin()
fin(3, "orden desconocida " + " ".join(a))
'''

ENV_BUENO = {
	"SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
	"SUPABASE_ANON_KEY": "x." + base64.urlsafe_b64encode(json.dumps({"role": "anon"}).encode()).decode().rstrip("=") + ".y",
	"SUPABASE_SERVICE_ROLE_KEY": "x." + base64.urlsafe_b64encode(json.dumps({"role": "service_role"}).encode()).decode().rstrip("=") + ".z",
	"SUPABASE_DB_PASSWORD": "contrasena-db",
	"SUPABASE_ACCESS_TOKEN": "sbp_0123456789",
	"ANTHROPIC_API_KEY": "sk-ant-api03-prueba",
	"RUNPOD_API_KEY": "rpa_prueba",
	"GHCR_TOKEN": "ghp_prueba",
	"ORQ_CORREO": "daniel@ejemplo.com",
	"ORQ_RESPONSABLE": "Daniel",
	"ORQ_PLAY_CUENTA": "",
	"ORQ_APP_ADMOB_APP_ID": "ca-app-pub-1234567890123456~1234567890",
	"ORQ_APP_ADMOB_PREMIO": "ca-app-pub-1234567890123456/1234567890",
}


def preparar(tmp: Path, env: dict) -> tuple[Path, dict]:
	proy = tmp / "proyecto"
	(proy / "app").mkdir(parents=True)
	shutil.copy(RAIZ / "conectar.py", proy / "conectar.py")
	(proy / "app" / "index.html").write_text("<html></html>")
	(proy / "LEEME.md").write_text("Orquestador")
	(proy / "app" / "src" / "demo").mkdir(parents=True)
	(proy / "app" / "src" / "demo" / "mk_reto.mp4").write_bytes(b"video")
	(proy / "conectar.env").write_text("\n".join(f"{k}={v}" for k, v in env.items()) + "\n")
	bare = tmp / "remoto.git"
	subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
	falso = tmp / "gh_falso.py"
	falso.write_text(GH_FALSO)
	if os.name == "nt":
		gh = tmp / "gh.cmd"
		gh.write_text(f'@"{sys.executable}" "{falso}" %*\n')
	else:
		gh = tmp / "gh"
		gh.write_text(f'#!/bin/sh\nexec "{sys.executable}" "{falso}" "$@"\n')
		gh.chmod(0o755)
	entorno = dict(os.environ, ORQ_GH=str(gh), ORQ_REMOTO=str(bare), ORQ_PAUSA="0", FALSO_ESTADO=str(tmp / "gh.json"),
		FALSO_BARE=str(bare), GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
	return proy, entorno


def lanzar(proy: Path, entorno: dict, *args: str) -> subprocess.CompletedProcess:
	return subprocess.run([sys.executable, str(proy / "conectar.py"), "--no-interactivo", "--sin-red", *args],
		cwd=proy, env=entorno, capture_output=True, text=True, stdin=subprocess.DEVNULL)


def revisar_prueba(tmp: Path, proy: Path, entorno: dict, st: dict) -> None:
	import http.server
	import threading
	revisor = json.loads((proy / ".conectar" / "estado.json").read_text())["generado"]["ORQ_REVISOR"]
	roto = {"motor": False}

	class Todo(http.server.BaseHTTPRequestHandler):
		def _r(self, code: int, cuerpo: bytes = b"") -> None:
			self.send_response(code)
			self.end_headers()
			if self.command != "HEAD":
				self.wfile.write(cuerpo)

		def do_GET(self):
			p = self.path
			if p.startswith("/web/config.js"):
				return self._r(200, b'window.ORQ = { supabase: "https://x.supabase.co", correo: "daniel@ejemplo.com" };')
			if p.startswith("/web/"):
				return self._r(200, b"<html>ok</html>")
			if p.startswith("/rest/v1/settings"):
				return self._r(200 if self.headers.get("apikey") == ENV_BUENO["SUPABASE_SERVICE_ROLE_KEY"] else 401, b'[{"key":"x"}]')
			if p.startswith("/v1/projects/") and p.endswith("/config/auth"):
				t = "<p>{{ .Token }}</p>"
				return self._r(200, json.dumps({"mailer_templates_confirmation_content": t, "mailer_templates_magic_link_content": t}).encode())
			if p == "/runpod/endpoints":
				return self._r(200, json.dumps([{"name": "orq-fabrica"}, {"name": "orq-imagenes"}, {"name": "orq-voces"}]).encode())
			return self._r(404)

		def do_HEAD(self):
			if self.path.startswith("/storage/v1/object/public/motor/godot/4.6.3/index.js") and not roto["motor"]:
				return self._r(200)
			return self._r(404)

		def do_OPTIONS(self):
			return self._r(204 if self.path.startswith("/functions/v1/") else 404)

		def do_POST(self):
			cuerpo = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
			correo, codigo = revisor.rsplit(":", 1)
			if self.path == "/functions/v1/review-login" and cuerpo == {"email": correo, "codigo": codigo}:
				return self._r(200, b'{"access_token":"t","refresh_token":"r"}')
			return self._r(401)

		def log_message(self, *a):
			pass

	srv = http.server.HTTPServer(("127.0.0.1", 0), Todo)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	base = f"http://127.0.0.1:{srv.server_port}"
	env_txt = (proy / "conectar.env").read_text().replace(ENV_BUENO["SUPABASE_URL"], base)
	(proy / "conectar.env").write_text(env_txt)
	estado_gh = json.loads((tmp / "gh.json").read_text())
	estado_gh["variables"]["ORQ_WEB"] = base + "/web"
	for r in estado_gh["runs"]:
		r["status"], r["conclusion"] = "completed", "success"
	(tmp / "gh.json").write_text(json.dumps(estado_gh))
	ent = dict(entorno, ORQ_SUPABASE_API=base, ORQ_RUNPOD_REST=base + "/runpod")
	r = subprocess.run([sys.executable, str(proy / "conectar.py"), "--revisar"], cwd=proy, env=ent, capture_output=True, text=True)
	check("revisar: todo bien de punta a punta", r.returncode == 0 and "TODO BIEN" in r.stdout, r.stdout[-1500:])
	## Ahora falla el despliegue y falta el motor: lo dice, con el registro guardado.
	estado_gh = json.loads((tmp / "gh.json").read_text())
	for r2 in estado_gh["runs"]:
		if r2["flujo"] == "desplegar.yml":
			r2["conclusion"] = "failure"
	(tmp / "gh.json").write_text(json.dumps(estado_gh))
	roto["motor"] = True
	r = subprocess.run([sys.executable, str(proy / "conectar.py"), "--revisar"], cwd=proy, env=ent, capture_output=True, text=True)
	fallo = proy / "salida" / "fallo-desplegar.txt"
	check("revisar: detecta el despliegue roto y guarda su registro", r.returncode == 1 and fallo.exists()
		and "algo fallo" in fallo.read_text() and "motor web" in r.stdout, r.stdout[-800:])
	srv.shutdown()
	(proy / "conectar.env").write_text(env_txt.replace(base, ENV_BUENO["SUPABASE_URL"]))
	for r3 in estado_gh["runs"]:
		r3["status"] = "in_progress"


def main() -> int:
	print("- conectar.py")
	sys.path.insert(0, str(RAIZ))
	import conectar
	## 6 - Validaciones sin red.
	check("detecta la clave secreta pegada como anon", conectar.validar("anon", ENV_BUENO["SUPABASE_SERVICE_ROLE_KEY"]) is not None)
	check("detecta la anon pegada como service_role", conectar.validar("servicio", ENV_BUENO["SUPABASE_ANON_KEY"]) is not None)
	check("claves nuevas de Supabase (sb_publishable / sb_secret)", conectar.validar("anon", "sb_publishable_x") is None
		and conectar.validar("servicio", "sb_secret_x") is None and conectar.validar("anon", "sb_secret_x") is not None)
	check("URL de Supabase", conectar.validar("url_supabase", "https://abcdefghijklmnopqrst.supabase.co") is None
		and conectar.validar("url_supabase", "https://supabase.com/dashboard/project/x") is not None)
	check("AdMob: ID de app y bloque no se confunden", conectar.validar("admob_app", ENV_BUENO["ORQ_APP_ADMOB_PREMIO"]) is not None
		and conectar.validar("admob_bloque", ENV_BUENO["ORQ_APP_ADMOB_PREMIO"]) is None)
	check("ninguna variable publica es un secreto", not (set(conectar.VARIABLES) & conectar.NUNCA_VARIABLE))

	## Ajustes de Supabase por la API de gestion (servidor local que hace de Supabase).
	import http.server
	import threading
	recibido: list = []

	class Falso(http.server.BaseHTTPRequestHandler):
		def do_PATCH(self):
			recibido.append((self.path, self.headers.get("Authorization"), json.loads(self.rfile.read(int(self.headers["Content-Length"])))))
			self.send_response(200)
			self.end_headers()
			self.wfile.write(b"{}")

		def log_message(self, *a):
			pass

	srv = http.server.HTTPServer(("127.0.0.1", 0), Falso)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	conectar.SUPABASE_API = f"http://127.0.0.1:{srv.server_port}"
	d = dict(ENV_BUENO, SUPABASE_PROJECT_REF="abcdefghijklmnopqrst", ORQ_WEB="https://daniel.github.io/orquestador-web")
	ok = conectar.configurar_supabase(d)
	path, auth, cuerpo = recibido[0] if recibido else ("", "", {})
	check("Supabase: plantillas de correo con el codigo y cuentas confirmadas", ok and path == "/v1/projects/abcdefghijklmnopqrst/config/auth"
		and auth == "Bearer sbp_0123456789" and "{{ .Token }}" in cuerpo.get("mailer_templates_confirmation_content", "")
		and "{{ .Token }}" in cuerpo.get("mailer_templates_magic_link_content", "") and cuerpo.get("mailer_autoconfirm") is False, str(cuerpo)[:200])
	check("Supabase: sin cliente de Google no se toca el proveedor", "external_google_enabled" not in cuerpo)
	conectar.configurar_supabase(dict(d, GOOGLE_OAUTH_CLIENT_ID="123-abc.apps.googleusercontent.com", GOOGLE_OAUTH_CLIENT_SECRET="GOCSPX-x"))
	_, _, cg = recibido[-1]
	check("Supabase: Entrar con Google activado con el cliente web", cg.get("external_google_enabled") is True
		and cg.get("external_google_client_id") == "123-abc.apps.googleusercontent.com" and cg.get("uri_allow_list", "").startswith("https://daniel.github.io"))
	check("Google: el secreto nunca es variable publica", "GOOGLE_OAUTH_CLIENT_SECRET" in conectar.NUNCA_VARIABLE
		and conectar.validar("google_cliente", "123-abc.apps.googleusercontent.com") is None and conectar.validar("google_cliente", "hola") is not None)
	srv.shutdown()
	conectar.SUPABASE_API = "http://127.0.0.1:9"
	check("Supabase sin respuesta: avisa y sigue", conectar.configurar_supabase(d) is False)

	with tempfile.TemporaryDirectory() as t:
		tmp = Path(t)
		proy, entorno = preparar(tmp, ENV_BUENO)
		r = lanzar(proy, entorno)
		check("de principio a fin sin errores", r.returncode == 0, (r.stdout + r.stderr)[-1500:])
		st = json.loads((tmp / "gh.json").read_text())
		## 1 - Secretos.
		faltan = [k for k in ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_PROJECT_REF", "ANTHROPIC_API_KEY",
			"RUNPOD_API_KEY", "GHCR_TOKEN", "ORQ_LLAVES_SECRETO", "ORQ_REVISOR", "ORQ_APP_KEYSTORE_B64",
			"ORQ_APP_KEYSTORE_PASS", "SUPABASE_DB_PASSWORD", "SUPABASE_ACCESS_TOKEN", "ORQ_WEB_DEPLOY_KEY") if not st["secretos"].get(k)]
		check("todos los secretos guardados", not faltan, str(faltan))
		check("el ref del proyecto sale de la URL", st["secretos"].get("SUPABASE_PROJECT_REF") == "abcdefghijklmnopqrst")
		valores_secretos = {v for k, v in st["secretos"].items() if k in conectar.NUNCA_VARIABLE and v}
		check("ningun secreto como variable", not (set(st["variables"].values()) & valores_secretos)
			and not (set(st["variables"]) & conectar.NUNCA_VARIABLE), str(st["variables"].keys()))
		check("variables publicas puestas (web, correo, AdMob, paquete)", all(st["variables"].get(k) for k in
			("SUPABASE_URL", "SUPABASE_ANON_KEY", "ORQ_WEB", "ORQ_CORREO", "ORQ_APP_ADMOB_APP_ID", "ORQ_APP_PAQUETE", "ORQ_WEB_REPO")))
		check("revisor con alias del correo y codigo de 6 cifras", st["secretos"]["ORQ_REVISOR"].startswith("daniel+revisor@ejemplo.com:")
			and len(st["secretos"]["ORQ_REVISOR"].rsplit(":", 1)[1]) == 6)
		## 3 - Web en repositorio publico (cuenta gratis).
		check("repositorio del codigo privado y el de la web publico", "Daniel/orquestador" in st["repos"]
			and st.get("publicos") == ["Daniel/orquestador-web"])
		check("web publica en github.io", st["variables"]["ORQ_WEB"] == "https://daniel.github.io/orquestador-web")
		check("llave de despliegue: la publica en GitHub, la privada como secreto", st.get("deploy_key", "").startswith("ssh-ed25519")
			and "OPENSSH PRIVATE KEY" in st["secretos"]["ORQ_WEB_DEPLOY_KEY"])
		## Lo subido no lleva nada secreto.
		clon = tmp / "clon"
		subprocess.run(["git", "clone", "-q", str(tmp / "remoto.git"), str(clon)], check=True)
		subido = {str(p.relative_to(clon)).replace("\\", "/") for p in clon.rglob("*") if p.is_file() and ".git" not in p.parts}
		check("se subio el codigo", "conectar.py" in subido and "app/index.html" in subido, str(subido))
		check("los videos de la demo se suben (la app los necesita para compilar)", "app/src/demo/mk_reto.mp4" in subido)
		check("no se subio conectar.env ni .conectar/", not any(f.startswith(".conectar") or f == "conectar.env" for f in subido))
		texto = "".join((clon / f).read_text(errors="ignore") for f in subido)
		check("ninguna clave dentro del codigo subido", ENV_BUENO["ANTHROPIC_API_KEY"] not in texto
			and st["secretos"]["ORQ_LLAVES_SECRETO"] not in texto)
		## 4 - Despliegue y app.
		cancelados = st.get("cancelados", [])
		despl = [r2 for r2 in st["runs"] if r2["flujo"] == "desplegar.yml"]
		check("cancela el despliegue automatico y lanza el de primera vez", len(cancelados) == 1
			and any(r2["event"] == "workflow_dispatch" and "primera_vez=true" in r2.get("inputs", []) for r2 in despl))
		check(".aab descargado en salida/", any((proy / "salida").rglob("*.aab")))
		pasos = (proy / "salida" / "SIGUIENTES-PASOS.txt").read_text()
		check("pasos de Play con la URL de privacidad y el revisor", "https://daniel.github.io/orquestador-web/privacidad.html" in pasos
			and "daniel+revisor@ejemplo.com" in pasos)
		## 2 - Llave de subida valida para Java.
		llave = proy / ".conectar" / "subida.p12"
		clave = json.loads((proy / ".conectar" / "estado.json").read_text())["generado"]["ORQ_APP_KEYSTORE_PASS"]
		check("la llave subida es la del secreto", base64.b64decode(st["secretos"]["ORQ_APP_KEYSTORE_B64"]) == llave.read_bytes())
		if shutil.which("keytool") and shutil.which("jarsigner"):
			kl = subprocess.run(["keytool", "-list", "-v", "-keystore", str(llave), "-storepass", clave], capture_output=True, text=True)
			check("keytool la abre: alias subida, RSA 4096", kl.returncode == 0 and "subida" in kl.stdout and "4096" in kl.stdout, kl.stderr[-300:])
			jar = tmp / "prueba.jar"
			subprocess.run([sys.executable, "-c", f"import zipfile;zipfile.ZipFile(r'{jar}','w').writestr('a.txt','hola')"], check=True)
			js = subprocess.run(["jarsigner", "-keystore", str(llave), "-storepass", clave, "-keypass", clave, str(jar), "subida"],
				capture_output=True, text=True)
			jv = subprocess.run(["jarsigner", "-verify", str(jar)], capture_output=True, text=True)
			check("Java firma con ella (como Gradle)", js.returncode == 0 and "jar verified" in jv.stdout, (js.stdout + js.stderr)[-300:])
		else:
			print("  (sin Java: no se prueba la firma)")
		## Revisar el sistema desplegado (servidor local que hace de Supabase, RunPod y la web).
		revisar_prueba(tmp, proy, entorno, st)
		## 5 - Segunda vez: nada nuevo.
		llave_antes = llave.read_bytes()
		secreto_antes = st["secretos"]["ORQ_LLAVES_SECRETO"]
		r2 = lanzar(proy, entorno)
		st2 = json.loads((tmp / "gh.json").read_text())
		check("segunda vez: sin errores", r2.returncode == 0, (r2.stdout + r2.stderr)[-800:])
		check("segunda vez: misma llave y mismo secreto", llave.read_bytes() == llave_antes and st2["secretos"]["ORQ_LLAVES_SECRETO"] == secreto_antes)
		check("segunda vez: no crea repositorios de nuevo", sum(1 for c in st2["llamadas"] if c[:2] == ["repo", "create"]) == 2)

	## 6 - Clave mal pegada: para antes de tocar GitHub.
	with tempfile.TemporaryDirectory() as t:
		tmp = Path(t)
		malo = dict(ENV_BUENO, SUPABASE_ANON_KEY=ENV_BUENO["SUPABASE_SERVICE_ROLE_KEY"])
		proy, entorno = preparar(tmp, malo)
		r = lanzar(proy, entorno)
		st = json.loads((tmp / "gh.json").read_text())
		check("clave secreta como anon: para y lo explica", r.returncode == 2 and "SUPABASE_ANON_KEY" in r.stdout
			and not st["secretos"] and not st["repos"], r.stdout[-400:])

	## Cuenta de pago: Pages en el mismo repositorio (sin repositorio de la web).
	with tempfile.TemporaryDirectory() as t:
		tmp = Path(t)
		proy, entorno = preparar(tmp, ENV_BUENO)
		entorno["FALSO_PLAN"] = "pro"
		r = lanzar(proy, entorno, "--sin-esperar")
		st = json.loads((tmp / "gh.json").read_text())
		check("cuenta Pro: web en el mismo repositorio", r.returncode == 0 and st["repos"] == ["Daniel/orquestador"]
			and st["variables"].get("ORQ_WEB") == "https://daniel.github.io/orquestador" and "ORQ_WEB_REPO" not in st["variables"],
			(r.stdout + r.stderr)[-600:])

	## Comprobacion de secretos en GitHub Actions (antes de desplegar).
	base_env = {k: v for k, v in os.environ.items() if k not in ENV_BUENO}
	ok = subprocess.run([sys.executable, str(RAIZ / "conectar.py"), "--entorno", "--sin-red"], env=dict(base_env, **ENV_BUENO,
		SUPABASE_PROJECT_REF="abcdefghijklmnopqrst"), capture_output=True, text=True)
	check("Actions: secretos correctos, sigue", ok.returncode == 0, ok.stdout[-300:])
	mal = subprocess.run([sys.executable, str(RAIZ / "conectar.py"), "--entorno", "--sin-red"], env=dict(base_env, **dict(ENV_BUENO,
		SUPABASE_ANON_KEY=ENV_BUENO["SUPABASE_SERVICE_ROLE_KEY"], RUNPOD_API_KEY="")), capture_output=True, text=True)
	check("Actions: clave cambiada y secreto vacio, para con el motivo", mal.returncode == 1 and "::error::SUPABASE_ANON_KEY" in mal.stdout
		and "RUNPOD_API_KEY" in mal.stdout, mal.stdout[-400:])
	print(f"== {fallos} fallos ==")
	return 1 if fallos else 0


if __name__ == "__main__":
	sys.exit(main())
