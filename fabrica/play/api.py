"""Cliente minimo de la Google Play Developer API (androidpublisher v3) con cuenta de servicio.

Una publicacion es una "edicion": se abre, se le sube el .aab, se pone en una pista (internal,
alpha = prueba cerrada, beta, production), se cambian textos e imagenes de la ficha, se valida
y se confirma. Si algo falla antes de confirmar, Google descarta la edicion entera.

La cuenta de servicio es de Orquestador: el usuario solo la invita en Play Console (Usuarios y
permisos) como "Gestor de versiones". Su clave JSON vive en el trabajador (ORQ_PLAY_CUENTA).

Sin dependencias de Google: JWT firmado con RS256 (cryptography) y urllib.
"""

import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

API = os.environ.get("ORQ_PLAY_API", "https://androidpublisher.googleapis.com")
ALCANCE = "https://www.googleapis.com/auth/androidpublisher"
from textos import idiomas as _idiomas
## Idioma de la app -> idioma de la ficha de Google Play (los 6 de siempre y los extra de idiomas.py).
IDIOMAS = {k: v["play"] for k, v in _idiomas.LENGUAS.items()}


class ErrorPlay(Exception):
	def __init__(self, mensaje: str, codigo: int = 0, cuerpo: str = ""):
		super().__init__(mensaje)
		self.codigo = codigo
		self.cuerpo = cuerpo


def _b64(b: bytes) -> str:
	return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")


def token(cuenta: dict) -> str:
	"""Token de acceso de 1 hora a partir de la clave JSON de la cuenta de servicio."""
	ahora = int(time.time())
	cab = _b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
	datos = _b64(json.dumps({"iss": cuenta["client_email"], "scope": ALCANCE, "aud": cuenta["token_uri"],
		"iat": ahora, "exp": ahora + 3600}).encode())
	llave = serialization.load_pem_private_key(cuenta["private_key"].encode("utf-8"), password=None)
	firma = llave.sign(f"{cab}.{datos}".encode("ascii"), padding.PKCS1v15(), hashes.SHA256())
	jwt = f"{cab}.{datos}.{_b64(firma)}"
	cuerpo = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": jwt}).encode()
	req = urllib.request.Request(cuenta["token_uri"], data=cuerpo, method="POST",
		headers={"Content-Type": "application/x-www-form-urlencoded"})
	try:
		with urllib.request.urlopen(req, timeout=30) as r:
			return json.loads(r.read())["access_token"]
	except urllib.error.HTTPError as e:
		raise ErrorPlay("Google no acepto la cuenta de servicio", e.code, e.read().decode("utf-8", "replace")) from e


class Play:
	def __init__(self, cuenta: dict, paquete: str):
		self.paquete = paquete
		self.tok = token(cuenta)
		self.edicion = ""
		self.registro: list[str] = []

	def _pedir(self, metodo: str, ruta: str, cuerpo=None, tipo: str = "application/json", subir: bool = False) -> dict:
		base = f"{API}/upload/androidpublisher/v3" if subir else f"{API}/androidpublisher/v3"
		url = f"{base}/applications/{self.paquete}{ruta}"
		if subir:
			url += ("&" if "?" in url else "?") + "uploadType=media"
		datos = cuerpo if isinstance(cuerpo, (bytes, type(None))) else json.dumps(cuerpo).encode("utf-8")
		req = urllib.request.Request(url, data=datos, method=metodo,
			headers={"Authorization": f"Bearer {self.tok}", "Content-Type": tipo})
		self.registro.append(f"{metodo} {ruta.split('?')[0]}")
		try:
			with urllib.request.urlopen(req, timeout=600) as r:
				txt = r.read()
				return json.loads(txt) if txt else {}
		except urllib.error.HTTPError as e:
			cuerpo_err = e.read().decode("utf-8", "replace")
			raise ErrorPlay(traducir(e.code, cuerpo_err), e.code, cuerpo_err) from e

	## ---------------------------------------------------------------- edicion

	def abrir(self) -> str:
		self.edicion = self._pedir("POST", "/edits", {})["id"]
		return self.edicion

	def subir_aab(self, aab: Path) -> int:
		r = self._pedir("POST", f"/edits/{self.edicion}/bundles", aab.read_bytes(), "application/octet-stream", subir=True)
		return int(r["versionCode"])

	def pista(self, pista: str, version: int, notas: dict[str, str], borrador: bool = False) -> None:
		cuerpo = {"track": pista, "releases": [{
			"versionCodes": [str(version)], "status": "draft" if borrador else "completed",
			"releaseNotes": [{"language": IDIOMAS[k], "text": v[:500]} for k, v in notas.items()],
		}]}
		self._pedir("PUT", f"/edits/{self.edicion}/tracks/{pista}", cuerpo)

	def ficha(self, idioma: str, titulo: str, corta: str, larga: str) -> None:
		lang = IDIOMAS[idioma]
		self._pedir("PUT", f"/edits/{self.edicion}/listings/{lang}",
			{"language": lang, "title": titulo[:30], "shortDescription": corta[:80], "fullDescription": larga[:4000]})

	def imagenes(self, idioma: str, tipo: str, archivos: list[Path]) -> int:
		"""tipo: icon, featureGraphic o phoneScreenshots. Borra las que habia y sube las nuevas."""
		lang = IDIOMAS[idioma]
		self._pedir("DELETE", f"/edits/{self.edicion}/listings/{lang}/{tipo}")
		for f in archivos:
			mime = "image/png" if f.suffix.lower() == ".png" else "image/jpeg"
			self._pedir("POST", f"/edits/{self.edicion}/listings/{lang}/{tipo}", f.read_bytes(), mime, subir=True)
		return len(archivos)

	def detalles(self, idioma_defecto: str, correo: str) -> None:
		self._pedir("PATCH", f"/edits/{self.edicion}/details",
			{"defaultLanguage": IDIOMAS[idioma_defecto], "contactEmail": correo})

	def confirmar(self) -> None:
		self._pedir("POST", f"/edits/{self.edicion}:validate", {})
		self._pedir("POST", f"/edits/{self.edicion}:commit", {})

	def descartar(self) -> None:
		if self.edicion:
			try:
				self._pedir("DELETE", f"/edits/{self.edicion}")
			except ErrorPlay:
				pass


## ---------------------------------------------------------------- productos del kit (compras)

## Los mismos que kit/store.gd, con su precio base en euros (Google lo convierte a cada pais).
PRODUCTOS = {
	"monedas_500": 990000, "monedas_3000": 4990000, "pase_temporada": 3990000, "sin_anuncios": 2990000,
	"pack_inicio": 3990000,
}
TEXTOS_PRODUCTOS = {
	"es": {"monedas_500": ("500 monedas", "Monedas para la tienda del juego."),
		"monedas_3000": ("3000 monedas", "Un buen saco de monedas para la tienda del juego."),
		"pase_temporada": ("Pase premium", "Premios premium del pase de esta temporada."),
		"sin_anuncios": ("Sin anuncios", "Quita para siempre los anuncios que salen entre niveles."),
		"pack_inicio": ("Pack de inicio", "2000 monedas y sin anuncios para siempre.")},
	"en": {"monedas_500": ("500 coins", "Coins for the in-game shop."),
		"monedas_3000": ("3000 coins", "A big bag of coins for the in-game shop."),
		"pase_temporada": ("Premium pass", "Premium rewards of this season's pass."),
		"sin_anuncios": ("No ads", "Removes the ads between levels forever."),
		"pack_inicio": ("Starter pack", "2000 coins and no ads forever.")},
	"pt": {"monedas_500": ("500 moedas", "Moedas para a loja do jogo."),
		"monedas_3000": ("3000 moedas", "Um saco grande de moedas para a loja do jogo."),
		"pase_temporada": ("Passe premium", "Prêmios premium do passe desta temporada."),
		"sin_anuncios": ("Sem anúncios", "Remove para sempre os anúncios entre fases."),
		"pack_inicio": ("Pacote inicial", "2000 moedas e sem anúncios para sempre.")},
	"fr": {"monedas_500": ("500 pièces", "Des pièces pour la boutique du jeu."),
		"monedas_3000": ("3000 pièces", "Un gros sac de pièces pour la boutique du jeu."),
		"pase_temporada": ("Passe premium", "Récompenses premium du passe de cette saison."),
		"sin_anuncios": ("Sans publicité", "Supprime pour toujours les pubs entre les niveaux."),
		"pack_inicio": ("Pack de départ", "2000 pièces et sans pub pour toujours.")},
	"de": {"monedas_500": ("500 Münzen", "Münzen für den Spielshop."),
		"monedas_3000": ("3000 Münzen", "Ein großer Sack Münzen für den Spielshop."),
		"pase_temporada": ("Premium-Pass", "Premium-Belohnungen des Passes dieser Saison."),
		"sin_anuncios": ("Werbefrei", "Entfernt die Werbung zwischen den Levels für immer."),
		"pack_inicio": ("Startpaket", "2000 Münzen und für immer werbefrei.")},
	"it": {"monedas_500": ("500 monete", "Monete per il negozio del gioco."),
		"monedas_3000": ("3000 monete", "Un grande sacco di monete per il negozio del gioco."),
		"pase_temporada": ("Pass premium", "Premi premium del pass di questa stagione."),
		"sin_anuncios": ("Senza pubblicità", "Toglie per sempre la pubblicità tra i livelli."),
		"pack_inicio": ("Pacchetto iniziale", "2000 monete e senza pubblicità per sempre.")},
}


def crear_productos(play: "Play", idiomas: list[str]) -> int:
	"""Crea o actualiza los 4 productos del kit (fuera de la edicion). Devuelve cuantos."""
	n = 0
	langs = [i for i in idiomas if i in TEXTOS_PRODUCTOS] or ["es"]
	for sku, micros in PRODUCTOS.items():
		cuerpo = {
			"packageName": play.paquete, "sku": sku, "status": "active", "purchaseType": "managedUser",
			"defaultLanguage": IDIOMAS[langs[0]],
			"defaultPrice": {"priceMicros": str(micros), "currency": "EUR"},
			"listings": {IDIOMAS[i]: {"title": TEXTOS_PRODUCTOS[i][sku][0], "description": TEXTOS_PRODUCTOS[i][sku][1]} for i in langs},
		}
		play._pedir("PUT", f"/inappproducts/{sku}?allowMissing=true&autoConvertMissingPrices=true", cuerpo)
		n += 1
	return n


def traducir(codigo: int, cuerpo: str) -> str:
	"""Los errores de Google, en lo que el usuario tiene que hacer."""
	t = cuerpo.lower()
	if "merchant" in t or "payments profile" in t:
		return "Para vender dentro del juego, crea tu perfil de pagos en Play Console (Configuración > Perfil de pagos)."
	if codigo == 404 or "package not found" in t or "no application was found" in t:
		return "Google Play no encuentra el juego: créalo en Play Console con este nombre de paquete y sube el primer .aab a mano."
	if codigo in (401, 403) or "permission" in t or "caller does not have" in t:
		return "Orquestador no tiene permiso: invita a su cuenta de servicio en Play Console > Usuarios y permisos."
	if "version code" in t and ("already" in t or "used" in t):
		return "Ese número de versión ya se subió: haz un cambio en el juego para generar una versión nueva."
	if "draft app" in t or "only releases with status draft" in t:
		return "El juego aún es un borrador en Play Console: se sube como borrador y lo envías tú a revisión."
	if "target" in t and "api" in t:
		return "Google pide una versión de Android más nueva (target API). Actualiza la fábrica y vuelve a publicar."
	if "signed with the wrong key" in t or "upload key" in t or "certificate" in t:
		return "El .aab está firmado con otra llave: en Play Console revisa la llave de subida (huella SHA-256)."
	return f"Google Play respondió {codigo}: {cuerpo[:300]}"


def publicar(cuenta: dict, paquete: str, aab: Path, ficha_dir: Path, pista: str = "internal",
		notas: dict[str, str] | None = None, correo: str = "", aviso=print) -> dict:
	"""Todo de una vez: .aab a la pista + textos e imagenes de la ficha en todos sus idiomas."""
	play = Play(cuenta, paquete)
	notas = notas or {"es": "Primera versión.", "en": "First release."}
	textos = json.loads((ficha_dir / "textos.json").read_text(encoding="utf-8"))
	try:
		play.abrir()
		aviso("Subiendo el juego a Google Play...")
		version = play.subir_aab(aab)
		try:
			play.pista(pista, version, notas)
			borrador = False
		except ErrorPlay as e:
			if "borrador" not in str(e):
				raise
			play.pista(pista, version, notas, borrador=True)
			borrador = True
		aviso("Poniendo textos, icono, gráfico destacado y capturas...")
		if correo:
			play.detalles("es", correo)
		imagenes = 0
		for idioma in textos:
			if idioma not in IDIOMAS:
				continue
			sub = "capturas" if idioma == "es" else f"capturas_{idioma}"
			if not (ficha_dir / sub).exists():
				sub = "capturas_en"
			t = textos[idioma]
			play.ficha(idioma, t["titulo"], t["corta"], t["larga"])
			imagenes += play.imagenes(idioma, "icon", [ficha_dir / "icono_512.png"])
			imagenes += play.imagenes(idioma, "featureGraphic", [ficha_dir / "destacado_1024x500.png"])
			imagenes += play.imagenes(idioma, "phoneScreenshots", sorted((ficha_dir / sub).glob("*.png"))[:8])
		play.confirmar()
		## Compras dentro del juego: si falla (sin perfil de pagos...), el juego sale igual sin tienda.
		productos, aviso_productos = 0, ""
		try:
			productos = crear_productos(play, [i for i in textos if i in IDIOMAS and i in TEXTOS_PRODUCTOS])
		except ErrorPlay as e:
			aviso_productos = str(e)
			aviso("Las compras dentro del juego no se pudieron crear: " + aviso_productos)
		return {"ok": True, "version": version, "pista": pista, "borrador": borrador, "imagenes": imagenes,
			"edicion": play.edicion, "llamadas": play.registro, "productos": productos, "aviso_productos": aviso_productos}
	except Exception:
		play.descartar()
		raise
