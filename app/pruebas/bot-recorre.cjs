// Bot 1 (npm run bot): recorre toda la app en modo demo a 360 y 412 px, pulsa los botones y apunta
// errores de JavaScript, desbordes, botones pequenos, textos cortados e imagenes rotas.
// Deja el informe y las capturas en la carpeta temporal (orq-bot).
// Bot que recorre la app (modo demo) de arriba a abajo y apunta lo que falla.
const { chromium } = require('playwright');
const fs = require('fs');
const OUT = require('path').join(require('os').tmpdir(), 'orq-bot');
fs.mkdirSync(OUT, { recursive: true });
const informe = { errores: [], vistas: [], clics: [], pulsados: [], tiempos: {} };
// Idioma del móvil del bot: ORQ_BOT_LANG=en recorre la app en inglés.
const LANG = process.env.ORQ_BOT_LANG === 'en' ? 'en' : 'es';
const TXT = LANG === 'en' ? { enviar: 'Send me the code', entrar: 'Sign in', fabricar: 'Make' } : { enviar: 'Enviarme el código', entrar: 'Entrar', fabricar: 'Fabricar' };
const NO_PULSAR = /^English$|^Español$|sign out|delete|remove|^buy|subscribe|^pay|close class|no longer a gift|publish on google|upload to google|restore version|empty for next term|vaciar|salir|cerrar sesi|borrar (mi )?cuenta|eliminar|^borrar$|comprar|suscrib|pagar|restaurar versi|publicar en google|subir a google|ya no es un regalo|quitar|cerrar clase|terminar/i;

async function auditar(pg, nombre) {
  const r = await pg.evaluate(() => {
    const W = window.innerWidth;
    const vis = (el) => { const b = el.getBoundingClientRect(); const s = getComputedStyle(el); return b.width > 0 && b.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' && !el.closest('[hidden]'); };
    const desc = (el) => (el.tagName.toLowerCase() + (el.className && typeof el.className === 'string' ? '.' + el.className.split(' ').filter(Boolean).slice(0, 2).join('.') : '') + ' «' + (el.innerText || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').trim().slice(0, 40) + '»');
    const out = { desborde: [], pequenos: [], cortados: [], imagenes: [], sinNombre: [], idsRepetidos: [], contraste: [] };
    // Contraste (WCAG): color del texto contra el primer fondo opaco de sus padres.
    const rgb = (c) => { const m = c.match(/rgba?\(([^)]+)\)/); if (!m) return null; const v = m[1].split(',').map(Number); return { r: v[0], g: v[1], b: v[2], a: v.length > 3 ? v[3] : 1 }; };
    const lum = (c) => { const f = (x) => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
    const fondo = (el) => { for (let e = el; e; e = e.parentElement) { const st = getComputedStyle(e); if (st.backgroundImage && st.backgroundImage !== 'none') return null; const c = rgb(st.backgroundColor); if (c && c.a > 0.9) return c; } return { r: 5, g: 8, b: 15, a: 1 }; };
    for (const el of document.querySelectorAll('p, span, strong, label, h1, h2, h3, button, a, td, th, li, figcaption')) {
      if (!vis(el) || ![...el.childNodes].some((n) => n.nodeType === 3 && n.nodeValue.trim())) continue;
      const st = getComputedStyle(el);
      const fg = rgb(st.color), bg = fondo(el);
      if (!fg || !bg || parseFloat(st.opacity) < 0.6 || el.disabled) continue;
      const a = lum(fg), b2 = lum(bg);
      const ratio = (Math.max(a, b2) + 0.05) / (Math.min(a, b2) + 0.05);
      const grande = parseFloat(st.fontSize) >= 24 || (parseFloat(st.fontSize) >= 18.6 && Number(st.fontWeight) >= 700);
      if (ratio < (grande ? 3 : 4.5)) out.contraste.push(desc(el) + ` ${ratio.toFixed(1)}:1`);
    }
    out.contraste = [...new Set(out.contraste)].slice(0, 10);
    if (document.documentElement.scrollWidth > W + 1) {
      for (const el of document.querySelectorAll('body *')) {
        if (!vis(el)) continue;
        const b = el.getBoundingClientRect();
        if (b.right > W + 1 && !el.closest('.desliza,.chips,.tabla-desliza,.gallery,.log,pre,code')) out.desborde.push(desc(el) + ` right=${Math.round(b.right)}`);
      }
      out.desborde = out.desborde.slice(0, 8);
      out.anchoPagina = document.documentElement.scrollWidth;
    }
    for (const el of document.querySelectorAll('button, a.btn, input, select, textarea, [role=tab]')) {
      if (!vis(el) || el.closest('.tabbar') && false) continue;
      const b = el.getBoundingClientRect();
      if (b.height < 36 || b.width < 36) out.pequenos.push(desc(el) + ` ${Math.round(b.width)}x${Math.round(b.height)}`);
      if (el.tagName === 'BUTTON' && !(el.innerText || '').trim() && !el.getAttribute('aria-label') && !el.getAttribute('title')) out.sinNombre.push(desc(el));
    }
    for (const el of document.querySelectorAll('button, .tag, h1, h2, h3, label, .chip, td, th, p, span, strong')) {
      if (!vis(el) || el.children.length > 2) continue;
      if (el.scrollWidth > el.clientWidth + 2 && el.clientWidth > 0) {
        const s = getComputedStyle(el);
        if (s.overflowX !== 'visible' || s.textOverflow === 'ellipsis' || s.whiteSpace === 'nowrap') {
          if (!el.closest('.desliza,.tabla-desliza,.log')) out.cortados.push(desc(el) + ` ${el.scrollWidth}>${el.clientWidth}`);
        }
      }
    }
    for (const img of document.querySelectorAll('img')) if (img.getAttribute('src') && img.complete && img.naturalWidth === 0 && vis(img)) out.imagenes.push(img.getAttribute('src').slice(0, 80));
    const ids = {};
    for (const el of document.querySelectorAll('[id]')) ids[el.id] = (ids[el.id] || 0) + 1;
    out.idsRepetidos = Object.entries(ids).filter(([, n]) => n > 1).map(([k, n]) => `${k} x${n}`);
    out.pequenos = [...new Set(out.pequenos)].slice(0, 15);
    out.cortados = [...new Set(out.cortados)].slice(0, 15);
    return out;
  });
  r.vista = nombre;
  informe.vistas.push(r);
}

async function entrar(pg) {
  const t0 = Date.now();
  await pg.goto('file://' + require('path').resolve(__dirname, '../dist-demo/index.html'));
  await pg.waitForSelector('button', { timeout: 15000 }).catch(() => {});
  informe.tiempos.arranque_ms = Date.now() - t0;
  await pg.waitForTimeout(800);
  const inputs = await pg.$$('input');
  if (inputs.length) await inputs[0].fill('demo@demo.es');
  await pg.click(`text=${TXT.enviar}`).catch(() => {});
  await pg.waitForTimeout(600);
  for (const i of await pg.$$('input')) { const t = await i.getAttribute('type'); if (t !== 'email') await i.fill('123456').catch(() => {}); }
  await pg.click(`button:has-text("${TXT.entrar}")`, { timeout: 3000 }).catch(() => {});
  await pg.waitForTimeout(1500);
}

async function irVista(pg, id) {
  await pg.click(`button.tab[data-vista="${id}"]`).catch(() => {});
  await pg.waitForTimeout(1200);
}

async function abrirDetalles(pg) {
  // Abre todos los <details> para auditar lo que hay dentro.
  await pg.evaluate(() => document.querySelectorAll('details').forEach((d) => { d.open = true; }));
  await pg.waitForTimeout(400);
}

async function clicarTodo(pg, nombre, volver) {
  const textos = await pg.evaluate(() => [...document.querySelectorAll('main button, .wrap-inner button, button.btn, button.chip')]
    .filter((b) => { const r = b.getBoundingClientRect(); return r.width > 0 && r.height > 0 && !b.disabled && !b.closest('[hidden]'); })
    .map((b, i) => ({ i, t: (b.innerText || b.getAttribute('aria-label') || '').trim().slice(0, 50) })));
  const vistos = new Set();
  let n = 0;
  for (const { t } of textos) {
    if (!t || vistos.has(t) || NO_PULSAR.test(t) || n >= 45) continue;
    vistos.add(t);
    n++;
    const antes = informe.errores.length;
    const loc = pg.locator('button', { hasText: t }).first();
    try {
      if (!(await loc.isVisible())) continue;
      await loc.scrollIntoViewIfNeeded({ timeout: 1500 });
      await loc.click({ timeout: 2500 });
      await pg.waitForTimeout(700);
      informe.pulsados.push(nombre + ': ' + t);
    } catch (e) {
      informe.clics.push({ vista: nombre, boton: t, fallo: 'no se pudo pulsar: ' + String(e.message).split('\n')[0].slice(0, 100) });
      continue;
    }
    if (informe.errores.length > antes) informe.clics.push({ vista: nombre, boton: t, fallo: informe.errores.slice(antes).join(' | ').slice(0, 300) });
    // Cerrar lo que se haya abierto y volver a donde estábamos.
    await pg.keyboard.press('Escape').catch(() => {});
    const capa = pg.locator('.player .player-close').first();
    if (await capa.isVisible().catch(() => false)) await capa.click().catch(() => {});
    const cerrar = pg.locator('.sheet-modal button:has-text("Cerrar"), dialog button:has-text("Cerrar"), .modal button:has-text("Cerrar")').first();
    if (await cerrar.isVisible().catch(() => false)) await cerrar.click().catch(() => {});
    await volver();
  }
}

(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 360, height: 760 }, deviceScaleFactor: 1, locale: LANG === 'en' ? 'en-US' : 'es-ES' });
  const pg = await ctx.newPage();
  let donde = 'entrada';
  pg.on('pageerror', (e) => informe.errores.push(`[${donde}] JS: ${e.message}`));
  pg.on('console', (m) => { if (m.type() === 'error') informe.errores.push(`[${donde}] consola: ${m.text().slice(0, 200)}`); });
  pg.on('dialog', (d) => { informe.errores.push(`[${donde}] diálogo del navegador: ${d.message().slice(0, 100)}`); d.dismiss().catch(() => {}); });
  await auditar(pg, 'entrada 360').catch(() => {});
  await entrar(pg);
  // Fabricar un juego para tener ficha.
  donde = 'taller';
  await pg.fill('textarea', 'un gato ninja rápido que salta por tejados de noche y aplasta ratas robot');
  const tf = Date.now();
  await pg.click(`button:has-text("${TXT.fabricar}")`);
  await pg.waitForSelector('.game-icon, .detail-head', { timeout: 60000 }).catch(() => informe.errores.push('la fábrica (demo) no terminó en 60 s'));
  informe.tiempos.fabricar_demo_ms = Date.now() - tf;
  await pg.waitForTimeout(1000);
  await pg.screenshot({ path: OUT + '/fabricado.png', fullPage: true });
  for (const ancho of [320, 360, 412]) {
    await pg.setViewportSize({ width: ancho, height: 800 });
    for (const v of ['taller', 'juegos', 'lanzadera', 'tuercas', 'cuenta']) {
      donde = `${v} ${ancho}`;
      await irVista(pg, v);
      await abrirDetalles(pg);
      await auditar(pg, donde);
      await pg.screenshot({ path: `${OUT}/${v}-${ancho}.png`, fullPage: true });
    }
    // Ficha del juego y sus 4 pestañas.
    await irVista(pg, 'juegos');
    await pg.click('button.game-card').catch(() => informe.errores.push('no hay tarjeta de juego'));
    await pg.waitForTimeout(2000);
    for (const [i, t] of ['Taller', 'Publicar', 'Compartir', 'Jugadores'].entries()) {
      donde = `ficha/${t} ${ancho}`;
      await pg.locator('.pestanas-juego [role=tab]').nth(i).click().catch(() => {});
      await pg.waitForTimeout(1200);
      await abrirDetalles(pg);
      await auditar(pg, donde);
      await pg.screenshot({ path: `${OUT}/ficha-${t}-${ancho}.png`, fullPage: true });
    }
  }
  // Pasada de clics a 360.
  await pg.setViewportSize({ width: 360, height: 800 });
  for (const v of ['taller', 'lanzadera', 'tuercas', 'cuenta']) {
    donde = `clics ${v}`;
    console.log('clics', v, new Date().toISOString().slice(11, 19));
    await irVista(pg, v);
    await clicarTodo(pg, v, async () => { if (!(await pg.locator(`button.tab[data-vista="${v}"][aria-current], button.tab[data-vista="${v}"].activa, button.tab[data-vista="${v}"].active`).count())) await irVista(pg, v); });
  }
  for (const [i, t] of ['Taller', 'Publicar', 'Compartir', 'Jugadores'].entries()) {
    donde = `clics ficha/${t}`;
    const volver = async () => {
      if ((await pg.locator('.pestanas-juego [role=tab]').nth(i).getAttribute('aria-selected').catch(() => null)) !== 'true') {
        await irVista(pg, 'juegos');
        await pg.click('button.game-card').catch(() => {});
        await pg.waitForTimeout(1500);
        await pg.locator('.pestanas-juego [role=tab]').nth(i).click().catch(() => {});
        await pg.waitForTimeout(800);
      }
    };
    await volver();
    await clicarTodo(pg, `ficha/${t}`, volver);
  }
  fs.writeFileSync(OUT + '/informe.json', JSON.stringify(informe, null, 1));
  await b.close();
  const avisos = informe.vistas.reduce((n, v) => n + (v.contraste || []).length + (v.desborde || []).length, 0);
  console.log('idioma', LANG, 'arranque', informe.tiempos.arranque_ms, 'ms · fabricar (demo)', informe.tiempos.fabricar_demo_ms, 'ms · avisos de contraste y desborde', avisos);
  console.log('pulsados', informe.pulsados.length, 'errores', informe.errores.length, 'clics con fallo', informe.clics.length, 'informe en', OUT);
  if (informe.errores.length || informe.clics.length) process.exitCode = 1;
})();
