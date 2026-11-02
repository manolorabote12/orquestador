// Bot de textos en inglés: abre la app (demo) con el móvil en inglés, recorre las pantallas y
// apunta los textos que siguen en español. node pruebas/bot-textos-en.cjs (después de npm run build:demo).
// Recoge los textos visibles de cada pantalla (para traducir primero lo que más se ve).
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 400, height: 900 }, locale: "en-US" }); const pg = await ctx.newPage();
  const vistos = new Map();
  const juntar = async (donde) => {
    const t = await pg.evaluate(() => {
      const out = [];
      const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      let n;
      while ((n = w.nextNode())) {
        const s = n.nodeValue.trim();
        const el = n.parentElement;
        if (!s || !el || el.closest('[hidden], script, style')) continue;
        out.push(s);
      }
      for (const el of document.querySelectorAll('[placeholder],[aria-label],[title]')) for (const a of ['placeholder', 'aria-label', 'title']) if (el.getAttribute(a)) out.push(el.getAttribute(a));
      return out;
    });
    for (const s of t) if (/[a-záéíóúñ]{2}/i.test(s)) { if (!vistos.has(s)) vistos.set(s, donde); }
  };
  await pg.goto('file://' + require('path').resolve(__dirname, '../dist-demo/index.html')); await pg.waitForTimeout(1200);
  await juntar('entrada');
  await (await pg.$$('input'))[0].fill('demo@demo.es'); await pg.click('text=Send me the code'); await pg.waitForTimeout(600);
  await juntar('entrada-codigo');
  for (const i of await pg.$$('input')) { if ((await i.getAttribute('type')) !== 'email') await i.fill('123456').catch(() => {}); }
  await pg.click('button:has-text("Sign in")', { timeout: 3000 }).catch(() => {}); await pg.waitForTimeout(1500);
  await juntar('taller');
  await pg.fill('textarea', 'un gato ninja rápido que salta por tejados de noche y aplasta ratas robot');
  await pg.click('button:has-text("Make game")');
  for (let k = 0; k < 7; k++) { await pg.waitForTimeout(5000); await juntar('fabricando'); }
  for (const v of ['juegos', 'lanzadera', 'tuercas', 'cuenta']) { await pg.click(`button.tab[data-vista="${v}"]`); await pg.waitForTimeout(1200); await juntar(v); }
  await pg.click(`button.tab[data-vista="juegos"]`); await pg.waitForTimeout(1000);
  await pg.click('button.game-card'); await pg.waitForTimeout(1500);
  for (const t of ['Workshop', 'Publish', 'Share', 'Players']) { await pg.click(`[role=tab]:has-text("${t}")`); await pg.waitForTimeout(1000); await juntar('ficha-' + t); }
  const out = require('path').join(require('os').tmpdir(), 'orq-bot');
  fs.mkdirSync(out, { recursive: true });
  // Lo que sigue en español (aproximado: palabras y tildes del español).
  const es = [...vistos.entries()].filter(([s]) => /[áéíóúñ¿¡]|\b(el|la|los|las|de|que|tu|con|para|una?|y|en|del|por|juego|juegos|nivel)\b/.test(s));
  fs.writeFileSync(require('path').join(out, 'textos-en.json'), JSON.stringify(es, null, 1));
    console.log('textos', vistos.size, 'quedan en español (con nombres y contenido del usuario):', es.length, 'lista en', out);
  await b.close();
})();
