"""Llenar el Escaparate con juegos de muestra hechos por la propia fabrica (cuenta «Equipo Orquestador").

Quien entra por primera vez ve juegos de verdad para jugar y remezclar, en vez de una galeria vacia.

	python3 nube/escaparate_semilla.py encargar 10   -> objetivo: 10 juegos de muestra (sin cobrar tuercas a nadie)
	python3 nube/escaparate_semilla.py seguir        -> publica los terminados y pone el siguiente en la cola (Reloj)
	python3 nube/escaparate_semilla.py estado        -> cuantos van en cola, hechos, fallidos y publicados
	python3 nube/escaparate_semilla.py cancelar      -> quita de la cola los que aun no han empezado y pone el objetivo a 0

Gasto: cada juego cuesta lo mismo que el de un usuario (~0,30 $ de RunPod y Claude). «encargar» mira el saldo
de RunPod y nunca encarga mas de lo que deja ORQ_SEMILLA_RESERVA $ (3 por defecto) para los usuarios.
Van de UNO EN UNO: solo se pone el siguiente en la cola cuando el anterior ha terminado (el Reloj lo mira cada
15 minutos). Asi el gasto por hora queda muy por debajo del guardian (3 $/h), que para la fabrica si se dispara
(el 11 nov, 10 encargados de golpe sumaban 3,50 $ estimados y el guardian la paro). El vigilante, el guardian y
el boton de parada valen igual que para cualquier juego.
Necesita SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY y (para encargar) RUNPOD_API_KEY.
"""

import datetime
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

AGENTE = "Orquestador/1.0 (+https://github.com)"
CORREO = os.environ.get("ORQ_CUENTA_ESCAPARATE") or "equipo.orquestador@example.com"
AUTOR = "Equipo Orquestador"
COSTE_JUEGO = 0.35
MAXIMO = 25
CLAVE_OBJETIVO = "semilla_objetivo"
## Los juegos de antes del arreglo del arte (11 nov, sprites con escenario dentro) no se publican.
PUBLICAR_DESDE = "2026-11-11T16:11:00Z"
## Los fallos de antes de este momento ya tienen su causa arreglada: no cuentan para dejar de intentarlo.
FALLOS_DESDE = "2026-11-12T07:51:03Z"
INTENTOS_IDEA = 2

# Ideas variadas (genero, estilo y publico) en el orden en que se encargan: con pocas ya hay de todo.
IDEAS = [
	"una gata ninja muy rapida que salta por los tejados de noche y esquiva ratas robot",
	"un pulpo cocinero que reparte sushi en patines por un mercado lleno de gaviotas ladronas",
	"defiende tu castillo de caramelo de un ejercito de hormigas golosas colocando torres de chicle",
	"una nave hecha con piezas de chatarra que esquiva asteroides y rescata astronautas perdidos",
	"un puzle de tuberias en un submarino que hace agua: conecta las valvulas antes de hundirte",
	"un caballero diminuto que salta entre castillos de nubes recogiendo estrellas fugaces",
	"un granjero robot que cultiva verduras gigantes y las vende para ampliar su granja en Marte",
	"carreras de caracoles con turbo por un jardin lleno de charcos, hojas y babosas tramposas",
	"un mago aprendiz que combina hechizos de colores para limpiar una torre llena de slimes",
	"un pinguino repartidor que baja una montana nevada en trineo esquivando focas dormidas",
	"una mazmorra por turnos donde un esqueleto bueno escapa de la cripta con sus amigos zombis",
	"un faro abandonado en una isla: explora, encuentra las piezas y vuelve a encender la luz",
	"un dragon bebe que aprende a volar atravesando aros de fuego sobre un volcan",
	"una pizzeria a contrarreloj donde montas pizzas raras para clientes extraterrestres",
	"un detective perro que resuelve el misterio del hueso robado buscando pistas en el barrio",
	"un buceador que baja a lo mas hondo del oceano recogiendo tesoros antes de quedarse sin aire",
	"un tanque de juguete que defiende la habitacion de un nino de los soldaditos de plastico",
	"un bosque encantado donde plantas semillas magicas que crecen en puentes y escaleras",
	"un parque de atracciones que construyes poco a poco para hacer feliz a una ciudad de gatos",
	"un ninja de papel que corta frutas voladoras en un dojo japones al atardecer",
	"una carrera de karts entre verduras en una cocina gigante con obstaculos de cubiertos",
	"un robot limpiador que ordena un laboratorio empujando cajas a su sitio sin quedarse atascado",
	"un vikingo pescador que pesca monstruos marinos simpaticos en un fiordo helado",
	"una bruja cartera que reparte pociones en escoba por un pueblo colgado de un acantilado",
	"un juego de cartas donde un ejercito de setas defiende el bosque de los leñadores",
]


def _req(metodo: str, url: str, cuerpo: bytes | None = None, cabeceras: dict | None = None) -> bytes:
	k = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
	h = {"apikey": k, "Authorization": "Bearer " + k, "User-Agent": AGENTE, **(cabeceras or {})}
	try:
		with urllib.request.urlopen(urllib.request.Request(url, data=cuerpo, method=metodo, headers=h), timeout=60) as r:
			return r.read()
	except urllib.error.HTTPError as e:
		ruta = url.split("?")[0].replace(os.environ.get("SUPABASE_URL", ""), "")
		raise ValueError(f"{e.code} en {metodo} {ruta}: {e.read()[:200].decode('utf-8', 'replace')}") from None


def base() -> str:
	return os.environ["SUPABASE_URL"].rstrip("/")


def rest(metodo: str, ruta: str, cuerpo: object = None, extra: dict | None = None) -> object:
	datos = None if cuerpo is None else json.dumps(cuerpo).encode()
	txt = _req(metodo, base() + "/rest/v1/" + ruta, datos, {"Content-Type": "application/json", **(extra or {})}).decode()
	return json.loads(txt) if txt.strip() else None


def cuenta() -> str | None:
	"""Id de la cuenta del Escaparate (o None si aun no existe)."""
	q = urllib.parse.urlencode({"page": 1, "per_page": 1000})
	usuarios = json.loads(_req("GET", f"{base()}/auth/v1/admin/users?{q}").decode()).get("users", [])
	return next((u["id"] for u in usuarios if (u.get("email") or "").lower() == CORREO.lower()), None)


def crear_cuenta() -> str:
	u = cuenta()
	if u:
		return u
	cuerpo = json.dumps({"email": CORREO, "email_confirm": True, "user_metadata": {"nombre": AUTOR}}).encode()
	r = json.loads(_req("POST", f"{base()}/auth/v1/admin/users", cuerpo, {"Content-Type": "application/json"}).decode())
	print(f"::notice::Cuenta del Escaparate creada ({CORREO})")
	return r["id"]


def saldo_runpod() -> float | None:
	clave = os.environ.get("RUNPOD_API_KEY", "")
	if not clave:
		return None
	req = urllib.request.Request("https://api.runpod.io/graphql", method="POST",
		data=json.dumps({"query": "query { myself { clientBalance } }"}).encode(),
		headers={"Content-Type": "application/json", "Authorization": "Bearer " + clave, "User-Agent": AGENTE})
	try:
		with urllib.request.urlopen(req, timeout=30) as r:
			return float(json.loads(r.read())["data"]["myself"]["clientBalance"])
	except (urllib.error.URLError, OSError, ValueError, KeyError, TypeError):
		return None


def trabajos(u: str) -> list[dict]:
	return rest("GET", f"jobs?select=id,status,detail,project_id,error,progress,result,created_at&user_id=eq.{u}&kind=eq.game&order=created_at") or []


def cuantos_caben(pedidos: int, saldo: float | None, reserva: float) -> int:
	"""Pura: cuantos juegos se pueden encargar sin bajar el saldo de RunPod de la reserva."""
	pedidos = max(0, min(int(pedidos), MAXIMO))
	if saldo is None:
		return 0
	return max(0, min(pedidos, int((saldo - reserva) // COSTE_JUEGO)))


def elegir(pedidos: int, hechas: set[str], fallos: dict[str, int] | None = None) -> list[str]:
	"""Pura: las siguientes ideas que aun no se han hecho (ni han fallado INTENTOS_IDEA veces)."""
	fallos = fallos or {}
	return [i for i in IDEAS if i not in hechas and fallos.get(i, 0) < INTENTOS_IDEA][:pedidos]


def siguiente(js: list[dict], objetivo: int) -> str | None:
	"""Pura: la idea que toca poner en la cola ahora, o None (hay uno en marcha, ya se llego al objetivo...)."""
	if any(j["status"] in ("queued", "running") for j in js):
		return None
	hechas = {str((j.get("detail") or {}).get("idea") or "") for j in js if j["status"] == "done"}
	if len(hechas) >= objetivo:
		return None
	fallos: dict[str, int] = {}
	for j in js:
		if j["status"] == "failed" and (j.get("error") or "") != "cancelado" and str(j.get("created_at") or "9") >= FALLOS_DESDE:
			i = str((j.get("detail") or {}).get("idea") or "")
			fallos[i] = fallos.get(i, 0) + 1
	## Demasiados fallos seguidos: algo va mal en la fabrica, no se sigue gastando.
	if sum(fallos.values()) >= max(3, objetivo // 2):
		return None
	ideas = elegir(1, hechas, fallos)
	return ideas[0] if ideas else None


def objetivo() -> int:
	f = rest("GET", f"settings?select=value&key=eq.{CLAVE_OBJETIVO}") or []
	return int(float(f[0]["value"])) if f else 0


def poner_objetivo(n: int) -> None:
	rest("POST", "settings", [{"key": CLAVE_OBJETIVO, "value": n, "note": "Juegos de muestra del Escaparate (nube/escaparate_semilla.py)"}],
		{"Prefer": "resolution=merge-duplicates,return=minimal"})


def diseno_con_arte(js: list[dict], idea: str) -> dict | None:
	"""Pura: el diseno de un intento fallido de esta idea que ya tenia el arte dibujado (y pagado). Fabricar
	con ese mismo diseno recupera el arte de la cache en vez de dibujarlo otra vez."""
	for j in reversed(js):
		if j["status"] != "failed" or str((j.get("detail") or {}).get("idea") or "") != idea or str(j.get("created_at") or "") < PUBLICAR_DESDE:
			continue
		diseno = (j.get("result") or {}).get("diseno")
		arte = any(isinstance(p, dict) and p.get("paso") == "arte" and p.get("estado") == "ok" for p in j.get("progress") or [])
		if arte and isinstance(diseno, dict):
			return diseno
	return None


def mejor_proyecto(js: list[dict], idea: str) -> str | None:
	"""Pura: el proyecto terminado de esta idea con mejor nota visual (el mas nuevo si empatan). Para
	rehacer un juego con el kit nuevo sin volver a dibujar el arte (la cache lo recupera)."""
	notas = notas_visuales(js)
	mejor, clave = None, (-1, "")
	for j in js:
		## Se compara el principio: la idea se guarda recortada a 400 letras (y la marca la alarga).
		if j["status"] != "done" or not j.get("project_id") or str((j.get("detail") or {}).get("idea") or "")[:300] != idea[:300]:
			continue
		k = (notas.get(j["project_id"], 0), str(j.get("created_at") or ""))
		if k > clave:
			mejor, clave = j["project_id"], k
	return mejor


def despertar() -> bool:
	"""Despierta la fabrica de RunPod para que coja la cola ya. Sin esto, un juego encargado por el Reloj
	esperaba al siguiente Reloj (que GitHub retrasa a veces mas de media hora: 12 nov)."""
	clave = os.environ.get("RUNPOD_API_KEY", "")
	if not clave:
		return False
	cab = {"Authorization": "Bearer " + clave, "User-Agent": AGENTE, "Content-Type": "application/json"}
	try:
		with urllib.request.urlopen(urllib.request.Request("https://rest.runpod.io/v1/endpoints", headers=cab), timeout=30) as r:
			d = json.loads(r.read())
		d = d if isinstance(d, list) else d.get("data", [])
		ep = next((e["id"] for e in d if e.get("name") == "orq-fabrica"), "")
		if not ep:
			return False
		req = urllib.request.Request(f"https://api.runpod.ai/v2/{ep}/run", data=json.dumps({"input": {"despertar": "escaparate"}}).encode(),
			method="POST", headers=cab)
		with urllib.request.urlopen(req, timeout=30):
			return True
	except (urllib.error.URLError, OSError, ValueError, KeyError):
		return False


def encolar(u: str, idea: str, diseno: dict | None = None) -> None:
	detalle = {"idea": idea, "semilla": True, **({"diseno": diseno} if diseno else {})}
	rest("POST", "jobs", [{"user_id": u, "kind": "game", "cost": 0, "est_cost_usd": COSTE_JUEGO, "status": "queued",
		"detail": detalle}], {"Prefer": "return=minimal"})
	if not despertar():
		print("::warning::No se pudo despertar la fabrica: el juego espera al siguiente Reloj")


def encargar(n: int) -> int:
	if rest("POST", "rpc/fabrica_pausada", {}):
		print("::error::La fabrica esta PARADA: reanudala antes de encargar juegos")
		return 1
	reserva = float(os.environ.get("ORQ_SEMILLA_RESERVA") or "3")
	saldo = saldo_runpod()
	if saldo is None:
		print("::error::No se pudo leer el saldo de RunPod: no se encarga nada (por seguridad)")
		return 1
	u = crear_cuenta()
	js = trabajos(u)
	hechos = len({str((j.get("detail") or {}).get("idea") or "") for j in js if j["status"] == "done"})
	caben = cuantos_caben(n, saldo, reserva)
	if caben < n:
		print(f"::warning::Saldo de RunPod {saldo:.2f} $: solo caben {caben} de {n} sin bajar de {reserva:.2f} $")
	meta = min(len(IDEAS), hechos + caben)
	poner_objetivo(meta)
	print(f"::notice::Objetivo: {meta} juegos de muestra ({hechos} ya hechos, ~{caben * COSTE_JUEGO:.2f} $ mas). Van de uno en uno; el Reloj pone el siguiente y publica los terminados.")
	return seguir()


def seguir() -> int:
	meta = objetivo()
	## Objetivo 0 (cancelado): ni se encarga ni se publica nada.
	if meta <= 0:
		return 0
	publicar()
	u = cuenta()
	if not u or rest("POST", "rpc/fabrica_pausada", {}):
		return 0
	js = trabajos(u)
	idea = siguiente(js, meta)
	if not idea:
		return 0
	## Cada juego vuelve a mirar el saldo: si RunPod baja de la reserva, se para aqui.
	if cuantos_caben(1, saldo_runpod(), float(os.environ.get("ORQ_SEMILLA_RESERVA") or "3")) < 1:
		print("::warning::Escaparate de muestra en pausa: el saldo de RunPod esta en la reserva")
		return 0
	previo = diseno_con_arte(js, idea)
	encolar(u, idea, previo)
	print(f"::notice::Juego de muestra en la cola: {idea}" + (" (con el arte ya dibujado)" if previo else ""))
	return 0


def encargar_idea(idea: str) -> int:
	"""Un juego concreto ya (pruebas de fuego): fuera de la lista y del objetivo, con el mismo control de saldo."""
	idea = " ".join(idea.split())[:400]
	if len(idea) < 12:
		print("::error::Escribe la idea del juego (al menos 12 letras)")
		return 1
	if rest("POST", "rpc/fabrica_pausada", {}):
		print("::error::La fabrica esta PARADA: reanudala antes de encargar juegos")
		return 1
	saldo = saldo_runpod()
	reserva = float(os.environ.get("ORQ_SEMILLA_RESERVA") or "3")
	if cuantos_caben(1, saldo, reserva) < 1:
		print(f"::error::Saldo de RunPod {saldo if saldo is not None else '?'} $ (reserva {reserva:.2f} $): no se encarga")
		return 1
	u = crear_cuenta()
	## «[rehacer] idea»: mismo diseno (y arte) que la mejor version ya hecha de esa idea, con el kit de hoy.
	previo = None
	if idea.startswith("[rehacer]"):
		idea = idea[len("[rehacer]"):].strip()
		pid = mejor_proyecto(trabajos(u), idea)
		filas = rest("GET", f"projects?select=spec&id=eq.{pid}") if pid else []
		previo = filas[0]["spec"] if filas and isinstance(filas[0].get("spec"), dict) else None
		if previo is None:
			print("::warning::No hay una version terminada de esa idea con diseno: se hace de cero")
	encolar(u, idea, previo)
	print(f"::notice::Juego encargado{' (rehecho con el diseno y el arte de la mejor version)' if previo else ''}: {idea}")
	return 0


def cancelar() -> int:
	poner_objetivo(0)
	u = cuenta()
	if not u:
		return 0
	rest("PATCH", f"jobs?user_id=eq.{u}&status=eq.queued", {"status": "failed", "error": "cancelado", "provider_cost_usd": 0,
		"refunded": True, "finished_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}, {"Prefer": "return=minimal"})
	print("::notice::Juegos de muestra en cola cancelados (no costaron nada) y objetivo a 0")
	return 0


NOTA_MINIMA = 6


def notas_visuales(js: list[dict]) -> dict[str, int]:
	"""Pura: {project_id: nota de la critica visual} de los trabajos terminados que la tienen."""
	notas: dict[str, int] = {}
	for j in js:
		if j["status"] != "done" or not j.get("project_id"):
			continue
		for p in j.get("progress") or []:
			if isinstance(p, dict) and p.get("paso") == "critica" and isinstance(p.get("nota"), (int, float)):
				notas[j["project_id"]] = int(p["nota"])
	return notas


def _subir(ruta: str, datos: bytes, tipo: str) -> None:
	## 30 dias de cache: la app pide ?v=<version>, asi que una version nueva nunca sale vieja (menos trafico).
	_req("POST", f"{base()}/storage/v1/object/escaparate/{ruta}", datos, {"Content-Type": tipo, "x-upsert": "true", "cache-control": "max-age=2592000"})


def _bajar(ruta: str) -> bytes:
	return _req("GET", f"{base()}/storage/v1/object/juegos/{urllib.parse.quote(ruta)}")


def _clave(titulo: str) -> str:
	"""Mismo juego aunque cambie el subtitulo: «Marea Alta: Rey Cangrejo» y «Marea Alta»."""
	return str(titulo or "").split(":")[0].strip().lower()


def _retirar_uno(u: str, pid: str, titulo: str) -> None:
	rest("POST", "rpc/escaparate_retirar", {"p_user": u, "p_project": pid})
	rutas = [f"{pid}/{n}" for n in ("index.pck", "icono.png", "portada.png", "ficha.json")]
	try:
		_req("DELETE", f"{base()}/storage/v1/object/escaparate", json.dumps({"prefixes": rutas}).encode(), {"Content-Type": "application/json"})
	except ValueError as err:
		print(f"::warning::{titulo}: {err}")
	print(f"::notice::Retirado del Escaparate (hay una version mas nueva): {titulo}")


def publicar() -> int:
	u = cuenta()
	if not u:
		return 0
	publicados = rest("GET", f"escaparate?select=project_id,titulo&user_id=eq.{u}") or []
	ya = {e["project_id"] for e in publicados}
	proyectos = rest("GET", f"projects?select=id,title,spec,version,files,created_at&user_id=eq.{u}&created_at=gte.{PUBLICAR_DESDE}") or []
	## Varias versiones del mismo juego (14 nov: Marea Alta v1, v4, v5...): solo va la mas nueva que
	## tenga paquete web, y las anteriores se retiran del Escaparate.
	nuevo: dict[str, dict] = {}
	for p in proyectos:
		if (p.get("files") or {}).get("web"):
			k = _clave(p["title"])
			if k not in nuevo or str(p.get("created_at", "")) > str(nuevo[k].get("created_at", "")):
				nuevo[k] = p
	for e in publicados:
		k = _clave(e.get("titulo", ""))
		if k in nuevo and nuevo[k]["id"] != e["project_id"] and any(x["id"] == e["project_id"] for x in proyectos):
			_retirar_uno(u, e["project_id"], e.get("titulo", ""))
			ya.discard(e["project_id"])
	n = 0
	notas = notas_visuales(trabajos(u))
	for p in proyectos:
		f = p.get("files") or {}
		if p["id"] in ya or not f.get("web"):
			continue
		if nuevo.get(_clave(p["title"]), p)["id"] != p["id"]:
			continue
		## Sin capturas no hay portada ni critica visual: no se publica (12 nov: «Agua a Bordo» salio asi).
		if not [c for c in (f.get("capturas") or []) if isinstance(c, str)]:
			print(f"::warning::{p['title']}: sin capturas (ni portada ni critica), no se publica en el Escaparate")
			continue
		## Al Escaparate solo va lo que la critica visual aprueba (o lo que aun no tiene critica).
		if notas.get(p["id"], 10) < NOTA_MINIMA:
			print(f"::warning::{p['title']}: nota visual {notas[p['id']]}/10, no se publica en el Escaparate")
			continue
		try:
			## Lo mismo que hace la funcion «escaparate» al compartir desde la app (supabase/functions/_shared/escaparate.ts).
			pck = _bajar(f["web"])
			print(f"  {p['title']}: paquete de {len(pck) / 1048576:.1f} MB")
			_subir(f"{p['id']}/index.pck", pck, "application/octet-stream")
			if f.get("icono"):
				_subir(f"{p['id']}/icono.png", _bajar(f["icono"]), "image/png")
			capturas = [c for c in (f.get("capturas") or []) if isinstance(c, str)]
			if capturas:
				_subir(f"{p['id']}/portada.png", _bajar(capturas[0]), "image/png")
			spec = p.get("spec") or {}
			ficha = {"titulo": p["title"], "resumen": str(spec.get("resumen") or ""), "genero": str(spec.get("genero") or ""),
				"autor": AUTOR, "version": p["version"], "portada": bool(capturas), "icono": bool(f.get("icono"))}
			_subir(f"{p['id']}/ficha.json", json.dumps(ficha, ensure_ascii=False).encode(), "application/json")
			rest("POST", "rpc/escaparate_publicar", {"p_user": u, "p_project": p["id"], "p_autor": AUTOR})
			n += 1
			print(f"::notice::Al Escaparate: {p['title']}")
		except (urllib.error.URLError, OSError, ValueError) as e:
			print(f"::warning::No se pudo publicar {p['title']}: {str(e)[:150]}")
	return 0


def rescatar_capturas(carpeta: str = "rescate") -> int:
	"""Juegos de muestra que salieron sin capturas (pantalla virtual rota en algunas maquinas, 12 nov):
	las capturas hechas despues fuera de RunPod (rama «rescate», una carpeta por titulo) se suben a su
	juego y se publica lo que toque. Sin GPU: no gasta RunPod."""
	from pathlib import Path
	u = cuenta()
	if not u:
		return 0
	raiz = Path(carpeta)
	for p in rest("GET", f"projects?select=id,title,files&user_id=eq.{u}") or []:
		f = p.get("files") or {}
		if [c for c in (f.get("capturas") or []) if isinstance(c, str)]:
			continue
		d = raiz / "".join(c if c.isalnum() else "_" for c in p["title"])[:40]
		pngs = sorted(d.glob("*.png")) if d.is_dir() else []
		base_ruta = str(f.get("icono") or f.get("web") or "").rsplit("/", 1)[0]
		if not pngs or not base_ruta:
			continue
		rutas = []
		for png in pngs:
			ruta = f"{base_ruta}/capturas/{png.name}"
			_req("POST", f"{base()}/storage/v1/object/juegos/{ruta}", png.read_bytes(), {"Content-Type": "image/png", "x-upsert": "true"})
			rutas.append(ruta)
		f["capturas"] = rutas
		rest("PATCH", f"projects?id=eq.{p['id']}", {"files": f}, {"Prefer": "return=minimal"})
		print(f"::notice::{p['title']}: {len(rutas)} capturas rescatadas")
	return publicar()


def capturas(carpeta: str = "capturas_muestra") -> int:
	"""Baja capturas, icono y clip de los juegos de muestra terminados (para mirarlos sin instalar nada)."""
	from pathlib import Path
	u = cuenta()
	if not u:
		return 0
	for p in rest("GET", f"projects?select=id,title,files&user_id=eq.{u}&order=created_at") or []:
		f = p.get("files") or {}
		d = Path(carpeta) / "".join(c if c.isalnum() else "_" for c in p["title"])[:40]
		d.mkdir(parents=True, exist_ok=True)
		rutas = [c for c in (f.get("capturas") or []) if isinstance(c, str)] + [f[k] for k in ("icono", "clip", "informe", "proyecto") if f.get(k)]
		for r in rutas:
			try:
				(d / r.split("/")[-1]).write_bytes(_bajar(r))
			except (urllib.error.URLError, OSError, ValueError) as e:
				print(f"::warning::{p['title']}: {r}: {str(e)[:120]}")
		print(f"::notice::{p['title']}: {len(rutas)} archivos")
	## Disenos de los fallidos (para reproducir el fallo fuera del servidor).
	for j in rest("GET", f"jobs?select=id,error,detail,result&user_id=eq.{u}&kind=eq.game&status=eq.failed&error=neq.cancelado&order=created_at.desc&limit=3") or []:
		d = Path(carpeta) / "_fallidos"
		d.mkdir(parents=True, exist_ok=True)
		(d / f"{j['id'][:8]}.json").write_text(json.dumps({"error": j.get("error"), "detail": j.get("detail"), "result": j.get("result")}, indent=1, ensure_ascii=False), encoding="utf-8")
	return 0


def retirar(todos: bool = True) -> int:
	"""Quita del Escaparate los juegos de muestra (todos, o solo los de antes del arreglo del arte y los
	que se publicaron sin capturas)."""
	u = cuenta()
	if not u:
		return 0
	viejos = {p["id"] for p in rest("GET", f"projects?select=id&user_id=eq.{u}&created_at=lt.{PUBLICAR_DESDE}") or []}
	for p in rest("GET", f"projects?select=id,files&user_id=eq.{u}") or []:
		if not [c for c in ((p.get("files") or {}).get("capturas") or []) if isinstance(c, str)]:
			viejos.add(p["id"])
	for e in rest("GET", f"escaparate?select=project_id,titulo&user_id=eq.{u}") or []:
		if not todos and e["project_id"] not in viejos:
			continue
		rest("POST", "rpc/escaparate_retirar", {"p_user": u, "p_project": e["project_id"]})
		rutas = [f"{e['project_id']}/{n}" for n in ("index.pck", "icono.png", "portada.png", "ficha.json")]
		try:
			_req("DELETE", f"{base()}/storage/v1/object/escaparate", json.dumps({"prefixes": rutas}).encode(), {"Content-Type": "application/json"})
		except ValueError as err:
			print(f"::warning::{e['titulo']}: {err}")
		print(f"::notice::Retirado del Escaparate: {e['titulo']}")
	return 0


def estado() -> int:
	u = cuenta()
	if not u:
		print("::notice::Escaparate de muestra: aun no se ha encargado nada")
		return 0
	js = trabajos(u)
	pub = rest("GET", f"escaparate?select=project_id&user_id=eq.{u}") or []
	cuenta_estados: dict[str, int] = {}
	for j in js:
		cuenta_estados[j["status"]] = cuenta_estados.get(j["status"], 0) + 1
	pausa = rest("GET", "settings?select=value,note&key=eq.fabrica_pausada") or [{}]
	en_marcha = rest("GET", "jobs?select=kind,user_id,started_at&status=eq.running") or []
	print(f"::notice::Escaparate de muestra: objetivo {objetivo()} | {cuenta_estados} | publicados {len(pub)} | fabrica: {pausa[0]} | en marcha: {en_marcha}")
	hechos_ult = next((j for j in reversed(js) if j["status"] == "done"), None)
	for j in js:
		if j["status"] == "running":
			pasos = [p for p in (j.get("progress") or []) if isinstance(p, dict)]
			print("::notice::En marcha: " + " | ".join(f"{p.get('paso')} {p.get('estado')} {str(p.get('mensaje') or '')[:60]}" for p in pasos[-8:])[:900])
		if j["status"] == "done" and j is hechos_ult:
			avisos = [p for p in (j.get("progress") or []) if isinstance(p, dict) and (p.get("estado") == "aviso" or p.get("paso") == "critica")]
			for p in avisos[-4:]:
				print(f"::notice::Aviso del ultimo terminado: {p.get('paso')}: {str(p.get('mensaje') or '')[:800]}")
		if j["status"] == "failed" and j.get("error") != "cancelado":
			pasos = j.get("progress") or []
			ultimos = " | ".join(f"{p.get('paso')} {p.get('estado')} {str(p.get('mensaje') or '')[:70]}" for p in pasos[-6:] if isinstance(p, dict))
			print(f"::warning::Fallo «{str((j.get('detail') or {}).get('idea'))[:60]}»: {str(j.get('error'))[:700]} || {ultimos[:700]}")
	return 0


def main(args: list[str]) -> int:
	accion = args[0] if args else "estado"
	if accion == "encargar":
		n = args[1].strip() if len(args) > 1 else "10"
		return encargar(int(n) if n.isdigit() else 10)
	if accion == "encargar_idea":
		return encargar_idea(" ".join(args[1:]))
	if accion == "publicar":
		return publicar()
	if accion == "seguir":
		return seguir()
	if accion == "cancelar":
		return cancelar()
	if accion == "capturas":
		return capturas()
	if accion == "rescatar_capturas":
		return rescatar_capturas()
	if accion == "retirar":
		cancelar()
		return retirar()
	if accion == "retirar_viejos":
		return retirar(todos=False)
	return estado()


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
