"""Iconos y pantalla de arranque de la app desde logo.svg (Chromium de Playwright).
Salida: assets/ con lo que espera @capacitor/assets (icon-only, icon-foreground, icon-background,
splash, splash-dark) y la ficha de Play (icono 512 y grafico destacado 1024x500)."""
import asyncio
import base64
import sys
from pathlib import Path

from playwright.async_api import async_playwright

AQUI = Path(__file__).parent
SALIDA = AQUI.parent / "assets"
LOGO = base64.b64encode((AQUI / "logo.svg").read_bytes()).decode()
FONDO = "#0f2a4a"
## Big Shoulders Stencil Display (SIL OFL), la misma letra de los titulos de la app.
FUENTE = base64.b64encode((AQUI / "big-shoulders-800.woff2").read_bytes()).decode()
ESTILO = ("<style>@font-face{font-family:Marca;font-weight:800;src:url(data:font/woff2;base64,%s) format('woff2')}</style>" % FUENTE)
REJILLA = ("background-image:linear-gradient(rgba(232,240,250,.07) 2px,transparent 2px),"
	"linear-gradient(90deg,rgba(232,240,250,.07) 2px,transparent 2px);background-size:{t}px {t}px;background-position:center;")


def pagina(w: int, h: int, cuerpo: str, fondo: str = FONDO, rejilla: int = 0) -> str:
	r = REJILLA.format(t=rejilla) if rejilla else ""
	return (f"<html><head>{ESTILO}</head><body style='margin:0;width:{w}px;height:{h}px;overflow:hidden;background:{fondo};{r}"
		f"display:flex;align-items:center;justify-content:center;font-family:Marca,sans-serif;font-weight:800'>{cuerpo}</body></html>")


def logo(px: int) -> str:
	return f"<img src='data:image/svg+xml;base64,{LOGO}' style='width:{px}px;height:{px}px'>"


TRABAJOS = {
	## Icono clasico: logo grande sobre azul (Android lo recorta en circulo o squircle).
	"icon-only.png": (1024, 1024, lambda: pagina(1024, 1024, logo(1380), rejilla=64)),
	## Adaptativo: el primer plano en la zona segura (66 %), el fondo aparte.
	"icon-foreground.png": (1024, 1024, lambda: pagina(1024, 1024, logo(1000), fondo="transparent")),
	"icon-background.png": (1024, 1024, lambda: pagina(1024, 1024, "", rejilla=64)),
	"splash.png": (2732, 2732, lambda: pagina(2732, 2732, logo(1100), rejilla=96)),
	"splash-dark.png": (2732, 2732, lambda: pagina(2732, 2732, logo(1100), fondo="#0a1e36", rejilla=96)),
	"play/icono-512.png": (512, 512, lambda: pagina(512, 512, logo(690), rejilla=32)),
	"play/grafico-destacado.png": (1024, 500, lambda: pagina(1024, 500,
		"<div style='margin-left:-60px;margin-right:-40px'>" + logo(520) + "</div><div style='color:#e8f0fa'><div style='font-size:118px;letter-spacing:2px;line-height:.95'>ORQUESTADOR</div>"
		"<div style='font:700 30px system-ui,sans-serif;color:#f6cf7a;margin-top:16px'>Describe un juego. Juégalo en minutos.</div></div>",
		rejilla=40)),
}


async def main() -> int:
	async with async_playwright() as p:
		b = await p.chromium.launch(executable_path="/opt/pw-browsers/chromium" if Path("/opt/pw-browsers/chromium").exists() else None)
		for nombre, (w, h, html) in TRABAJOS.items():
			pg = await b.new_page(viewport={"width": w, "height": h})
			await pg.set_content(html())
			await pg.evaluate("document.fonts.ready")
			destino = SALIDA / nombre
			destino.parent.mkdir(parents=True, exist_ok=True)
			await pg.screenshot(path=str(destino), omit_background=nombre == "icon-foreground.png")
			await pg.close()
			print(destino.relative_to(AQUI.parent), w, h)
		await b.close()
	return 0


if __name__ == "__main__":
	sys.exit(asyncio.run(main()))
