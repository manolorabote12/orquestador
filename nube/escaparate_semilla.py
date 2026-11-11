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
	return rest("GET", f"jobs?select=id,status,detail,project_id,error,progress&user_id=eq.{u}&kind=eq.game&order=created_at") or []


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
		if j["status"] == "failed" and (j.get("error") or "") != "cancelado":
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


def encolar(u: str, idea: str) -> None:
	rest("POST", "jobs", [{"user_id": u, "kind": "game", "cost": 0, "est_cost_usd": COSTE_JUEGO, "status": "queued",
		"detail": {"idea": idea, "semilla": True}}], {"Prefer": "return=minimal"})


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
	idea = siguiente(trabajos(u), meta)
	if not idea:
		return 0
	## Cada juego vuelve a mirar el saldo: si RunPod baja de la reserva, se para aqui.
	if cuantos_caben(1, saldo_runpod(), float(os.environ.get("ORQ_SEMILLA_RESERVA") or "3")) < 1:
		print("::warning::Escaparate de muestra en pausa: el saldo de RunPod esta en la reserva")
		return 0
	encolar(u, idea)
	print(f"::notice::Juego de muestra en la cola: {idea}")
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


def _subir(ruta: str, datos: bytes, tipo: str) -> None:
	_req("POST", f"{base()}/storage/v1/object/escaparate/{ruta}", datos, {"Content-Type": tipo, "x-upsert": "true"})


def _bajar(ruta: str) -> bytes:
	return _req("GET", f"{base()}/storage/v1/object/juegos/{urllib.parse.quote(ruta)}")


def publicar() -> int:
	u = cuenta()
	if not u:
		return 0
	ya = {e["project_id"] for e in (rest("GET", f"escaparate?select=project_id&user_id=eq.{u}") or [])}
	proyectos = rest("GET", f"projects?select=id,title,spec,version,files&user_id=eq.{u}&created_at=gte.{PUBLICAR_DESDE}") or []
	n = 0
	for p in proyectos:
		f = p.get("files") or {}
		if p["id"] in ya or not f.get("web"):
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
	"""Quita del Escaparate los juegos de muestra (todos o solo los de antes del arreglo del arte)."""
	u = cuenta()
	if not u:
		return 0
	viejos = {p["id"] for p in rest("GET", f"projects?select=id&user_id=eq.{u}&created_at=lt.{PUBLICAR_DESDE}") or []}
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
	for j in js:
		if j["status"] == "running":
			pasos = [p for p in (j.get("progress") or []) if isinstance(p, dict)]
			print("::notice::En marcha: " + " | ".join(f"{p.get('paso')} {p.get('estado')} {str(p.get('mensaje') or '')[:60]}" for p in pasos[-8:])[:900])
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
	if accion == "publicar":
		return publicar()
	if accion == "seguir":
		return seguir()
	if accion == "cancelar":
		return cancelar()
	if accion == "capturas":
		return capturas()
	if accion == "retirar":
		cancelar()
		return retirar()
	if accion == "retirar_viejos":
		return retirar(todos=False)
	return estado()


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
