"""Capturas de la ficha de Google Play de Orquestador, sacadas de la demo (npm run build:demo).

	python3 tienda/capturas.py      -> tienda/capturas/01.png ... (1080x1920, con titular)

Recorre la app de verdad (Playwright + Chromium): entrar, fabricar, jugar, cambiar, publicar,
Lanzadera y tuercas. Cada pantalla va enmarcada con un titular grande en la letra de la marca."""
import asyncio
import base64
import sys
from pathlib import Path

from playwright.async_api import async_playwright

APP = Path(__file__).resolve().parents[1]
SALIDA = APP / "tienda" / "capturas"
FUENTE = base64.b64encode((APP / "marca" / "big-shoulders-800.woff2").read_bytes()).decode()
CHROMIUM = "/opt/pw-browsers/chromium" if Path("/opt/pw-browsers/chromium").exists() else None

TITULARES = [
	("Crea juegos con IA", "Descríbelo con palabras: Chispa lo diseña, lo dibuja y le pone música"),
	("Mira cómo se fabrica", "Bots prueban cada nivel antes de dártelo"),
	("Tu juego, listo", "Juégalo al instante y descárgalo"),
	("Cámbialo hablando", "Cada cambio es una versión nueva"),
	("Publícalo en Google Play", "Paquete firmado y guía paso a paso"),
	("La Lanzadera", "Consigue tus 12 probadores con la comunidad"),
	("Tuercas y premium", "Anuncios con premio, packs y suscripción"),
]


def marco(png: bytes, titulo: str, sub: str) -> str:
	img = base64.b64encode(png).decode()
	return f"""<html><head><style>
@font-face{{font-family:Marca;font-weight:800;src:url(data:font/woff2;base64,{FUENTE}) format('woff2')}}
body{{margin:0;width:1080px;height:1920px;overflow:hidden;background:#0f2a4a;
background-image:linear-gradient(rgba(232,240,250,.07) 2px,transparent 2px),linear-gradient(90deg,rgba(232,240,250,.07) 2px,transparent 2px);
background-size:54px 54px;display:flex;flex-direction:column;align-items:center}}
h1{{font:800 108px/1 Marca,sans-serif;color:#e8f0fa;margin:92px 40px 0;text-align:center;letter-spacing:1px}}
p{{font:700 42px/1.25 system-ui,sans-serif;color:#f6cf7a;margin:22px 60px 54px;text-align:center}}
.tel{{width:760px;border-radius:52px;overflow:hidden;border:14px solid #061427;box-shadow:0 30px 80px rgba(0,0,0,.55);flex:none}}
.tel img{{display:block;width:100%}}
</style></head><body><h1>{titulo}</h1><p>{sub}</p><div class="tel"><img src="data:image/png;base64,{img}"></div></body></html>"""


async def main() -> int:
	SALIDA.mkdir(parents=True, exist_ok=True)
	pantallas: list[bytes] = []
	async with async_playwright() as p:
		b = await p.chromium.launch(executable_path=CHROMIUM)
		## En espanol siempre (la app se traduce sola si el navegador esta en otro idioma).
		pg = await b.new_page(viewport={"width": 390, "height": 760}, device_scale_factor=2, locale="es-ES")
		errores: list[str] = []
		pg.on("pageerror", lambda e: errores.append(str(e)))
		await pg.goto((APP / "dist-demo" / "index.html").as_uri())
		await pg.add_style_tag(content=".demo-band{display:none!important}")
		await pg.wait_for_timeout(1000)

		async def foto() -> None:
			## Sin rastro de la demo ni avisos flotantes en las capturas de la tienda.
			await pg.add_style_tag(content=".demo-band,.toast{display:none!important}")
			await pg.evaluate("""() => { for (const el of document.querySelectorAll('p, small, div')) {
				if (el.children.length === 0 && /^Demostraci\u00f3n/.test(el.textContent || '')) el.remove(); } }""")
			await pg.wait_for_timeout(400)
			pantallas.append(await pg.screenshot())

		await pg.fill("input[type=email]", "demo@demo.com")
		await pg.get_by_role("button", name="Enviarme el código").click()
		await pg.wait_for_timeout(900)
		await pg.fill("input.code-input", "123456")
		await pg.keyboard.press("Enter")
		await pg.wait_for_timeout(1200)
		otro = pg.locator("button.btn-brass")
		if await pg.locator("textarea").count() == 0 and await otro.count():
			await otro.first.click()
			await pg.wait_for_timeout(800)
		await pg.locator("textarea[aria-label='Tu idea']").fill("un gato ninja rápido que salta por tejados de noche y aplasta ratas robot")
		await foto()
		await pg.get_by_role("button", name="Fabricar juego").click()
		await pg.wait_for_timeout(1200)
		for t in ["Confirmar", "Sí", "Fabricar por"]:
			l = pg.get_by_role("button", name=t)
			if await l.count():
				await l.first.click()
				break
		await pg.wait_for_timeout(14000)
		await foto()
		await pg.wait_for_timeout(24000)
		await pg.get_by_text("Mis juegos").last.click()
		await pg.wait_for_timeout(1000)
		await pg.get_by_text("Bigotes Veloces").first.click()
		await pg.wait_for_timeout(1500)
		await foto()
		await pg.fill("textarea[aria-label='Instrucción para Chispa']", "haz al gato negro y los niveles más difíciles")
		await pg.keyboard.press("Enter")
		await pg.wait_for_timeout(1800)
		await pg.locator(".msg.yo").last.evaluate("e => e.scrollIntoView({block: 'start'})")
		await pg.evaluate("window.scrollBy(0, -90)")
		await foto()
		await pg.fill("input[aria-label='Nombre de estudio']", "Daniel Studio")
		await pg.get_by_text("Guardar y seguir").click()
		await pg.wait_for_timeout(1200)
		await pg.get_by_text("Preparar para Google Play").click()
		await pg.wait_for_timeout(9000)
		await pg.locator("section.sheet").filter(has_text="Publicar en Google Play").scroll_into_view_if_needed()
		await foto()
		await pg.locator("button.tab[data-vista=lanzadera]").click()
		await pg.wait_for_timeout(1200)
		await foto()
		await pg.locator("button.tab[data-vista=tuercas]").click()
		await pg.wait_for_timeout(1200)
		await foto()

		marcos = await b.new_page(viewport={"width": 1080, "height": 1920})
		for i, (png, (titulo, sub)) in enumerate(zip(pantallas, TITULARES), 1):
			await marcos.set_content(marco(png, titulo, sub))
			await marcos.evaluate("document.fonts.ready")
			await marcos.screenshot(path=str(SALIDA / f"{i:02d}.png"))
			print(SALIDA / f"{i:02d}.png")
		await b.close()
	if errores:
		print("errores de la app:", errores)
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(asyncio.run(main()))
