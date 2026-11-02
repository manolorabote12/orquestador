"""Deriva la interfaz (perfil, fuente y colores por rol) de la Biblia del juego.

El kit de Godot la lee de assets/manifest.json -> "ui". Todos los textos quedan con
contraste WCAG de 4.5:1 o mas sobre su fondo, sea cual sea la paleta.
"""

import colorsys

from .biblia import hex_a_rgb

PERFIL_POR_FAMILIA = {
	"pixel_art": "pixel",
	"cartoon": "cartoon",
	"low_poly": "low_poly",
	"realista": "realista",
	"pintado": "realista",
}

ROLES = ["fondo", "panel", "panel_hi", "borde", "texto", "texto_suave", "acento", "acento_texto", "exito", "peligro"]

RGB = tuple[float, float, float]


def _rgb(h: str) -> RGB:
	r, g, b = hex_a_rgb(h)
	return (r / 255.0, g / 255.0, b / 255.0)


def _hex(c: RGB) -> str:
	return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255.0))) for v in c)


def luminancia(c: RGB) -> float:
	lin = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contraste(a: RGB, b: RGB) -> float:
	la, lb = luminancia(a), luminancia(b)
	return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def _mezcla(a: RGB, b: RGB, t: float) -> RGB:
	return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))  # type: ignore[return-value]


def _oscurecer(c: RGB, k: float) -> RGB:
	return _mezcla(c, (0.0, 0.0, 0.0), k)


def _aclarar(c: RGB, k: float) -> RGB:
	return _mezcla(c, (1.0, 1.0, 1.0), k)


def _fondo_legible(bg: RGB, texto: RGB, objetivo: float = 4.65) -> RGB:
	"""1 - Oscurece (o aclara) el fondo poco a poco hasta que el texto se lea."""
	claro = luminancia(texto) > 0.4
	b = bg
	for _ in range(40):
		if contraste(texto, b) >= objetivo:
			break
		b = _oscurecer(b, 0.06) if claro else _aclarar(b, 0.06)
	return b


def _texto_legible(t: RGB, bg: RGB, objetivo: float) -> RGB:
	oscuro = luminancia(bg) < 0.4
	for _ in range(40):
		if contraste(t, bg) >= objetivo:
			break
		t = _aclarar(t, 0.08) if oscuro else _oscurecer(t, 0.08)
	return t


def _por_tono(paleta: list[RGB], centro: float, ancho: float) -> RGB | None:
	"""Color de la paleta mas saturado cuyo tono (0-360) cae cerca de 'centro'."""
	mejor, puntos = None, 0.0
	for c in paleta:
		h, s, v = colorsys.rgb_to_hsv(*c)
		d = abs((h * 360.0 - centro + 180.0) % 360.0 - 180.0)
		if d <= ancho and s > 0.35 and v > 0.45 and s * v > puntos:
			mejor, puntos = c, s * v
	return mejor


def colores(paleta_hex: list[str], fijos: dict | None = None) -> dict[str, str]:
	"""2 - Colores por rol a partir de la paleta de la Biblia."""
	pal = [_rgb(h) for h in paleta_hex]
	por_luz = sorted(pal, key=luminancia)
	oscuro = por_luz[0]
	claro = por_luz[-1]
	texto = claro if luminancia(claro) > 0.7 else (0.957, 0.965, 0.984)
	## Fondo: el oscuro de la familia de tono dominante de la paleta (su "cielo"), sin negro puro.
	mitad = por_luz[: max(1, len(por_luz) // 2)]

	def _familia(c: RGB) -> int:
		h = colorsys.rgb_to_hsv(*c)[0]
		return sum(1 for o in pal if colorsys.rgb_to_hsv(*o)[1] > 0.15 and abs((colorsys.rgb_to_hsv(*o)[0] - h + 0.5) % 1.0 - 0.5) < 0.08)

	fondo = max(mitad, key=lambda c: _familia(c) * 0.1 + (1.0 - luminancia(c)) * 0.5 - (0.05 if luminancia(c) < 0.008 else 0.0))
	if luminancia(fondo) > 0.08:
		fondo = _oscurecer(fondo, 0.45)
	## Si la Biblia fija el fondo (la directora pone el cielo primero), manda ese.
	if fijos and fijos.get("fondo"):
		fondo = _rgb(fijos["fondo"])
	panel = _aclarar(fondo, 0.10)
	## Panel resaltado (botones): un color medio que se distinga del fondo, de la misma familia de tono.
	h_fondo = colorsys.rgb_to_hsv(*fondo)[0]
	medios = [c for c in pal if 0.03 < luminancia(c) < 0.3 and contraste(c, fondo) >= 1.35]

	def _afinidad(c: RGB) -> float:
		d = abs((colorsys.rgb_to_hsv(*c)[0] - h_fondo + 0.5) % 1.0 - 0.5)
		return -d + contraste(c, fondo) * 0.05

	panel_hi = max(medios, key=_afinidad) if medios else _aclarar(fondo, 0.22)
	## Acento: el color vivo y luminoso que no sea rojo de peligro ni el de exito.
	def _tono(c: RGB) -> float:
		return colorsys.rgb_to_hsv(*c)[0] * 360.0

	vivos = [c for c in pal if colorsys.rgb_to_hsv(*c)[1] > 0.35 and luminancia(c) > 0.25]
	no_rojos = [c for c in vivos if 25.0 < _tono(c) < 335.0 and not (95.0 < _tono(c) < 165.0)]
	elegibles = no_rojos or vivos
	acento = max(elegibles, key=lambda c: colorsys.rgb_to_hsv(*c)[1] * colorsys.rgb_to_hsv(*c)[2] + luminancia(c) * 0.3) if elegibles else (0.91, 0.69, 0.29)
	acento_texto = oscuro if contraste(oscuro, acento) >= contraste((0.98, 0.98, 0.98), acento) else (0.98, 0.98, 0.98)
	exito = _por_tono(pal, 130.0, 45.0) or (0.56, 0.89, 0.65)
	peligro = _por_tono(pal, 5.0, 25.0) or (1.0, 0.42, 0.36)
	out: dict[str, RGB] = {
		"fondo": fondo, "panel": panel, "panel_hi": panel_hi, "borde": _oscurecer(fondo, 0.55),
		"texto": texto, "texto_suave": _mezcla(texto, panel, 0.35), "acento": acento,
		"acento_texto": acento_texto, "exito": exito, "peligro": peligro,
	}
	for rol, valor in (fijos or {}).items():
		out[rol] = _rgb(valor)
	## 3 - Garantia de lectura: igual que UiTheme.ensure_contrast en el kit.
	for rol in ["fondo", "panel", "panel_hi"]:
		out[rol] = _fondo_legible(out[rol], out["texto"])
	out["texto_suave"] = _texto_legible(out["texto_suave"], out["panel"], 3.1)
	if contraste(out["acento_texto"], out["acento"]) < 4.65:
		d, l = (0.08, 0.08, 0.08), (0.98, 0.98, 0.98)
		out["acento_texto"] = d if contraste(d, out["acento"]) >= contraste(l, out["acento"]) else l
	out["acento"] = _fondo_legible(out["acento"], out["acento_texto"])
	out["exito"] = _texto_legible(out["exito"], out["panel"], 4.65)
	return {r: _hex(out[r]) for r in ROLES}


def derivar(biblia: dict) -> dict:
	"""4 - Bloque "ui" del manifest: perfil, fuente (opcional) y colores."""
	cfg = biblia.get("interfaz", {})
	perfil = cfg.get("perfil") or PERFIL_POR_FAMILIA.get(biblia["estilo"]["familia"], "pixel")
	ui = {"perfil": perfil, "colores": colores(biblia["estilo"]["paleta"], cfg.get("colores"))}
	if cfg.get("fuente"):
		ui["fuente"] = cfg["fuente"]
	return ui


def informe_contraste(ui: dict) -> dict[str, float]:
	c = {k: _rgb(v) for k, v in ui["colores"].items()}
	return {
		"texto/fondo": round(contraste(c["texto"], c["fondo"]), 2),
		"texto/panel": round(contraste(c["texto"], c["panel"]), 2),
		"texto/boton": round(contraste(c["texto"], c["panel_hi"]), 2),
		"acento_texto/acento": round(contraste(c["acento_texto"], c["acento"]), 2),
		"exito/panel": round(contraste(c["exito"], c["panel"]), 2),
	}
