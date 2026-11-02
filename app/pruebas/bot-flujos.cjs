// Bot 2 (npm run bot): rellena los formularios de los flujos (regalo, premio, clase, evento, AdMob,
// itch.io, cartel) y comprueba el resultado. Sale con error si algo falla.
// Segundo bot: rellena los formularios de cada flujo y comprueba lo que pasa.
const { chromium } = require('playwright');
const res = [];
const ok = (n, c, d = '') => { res.push((c ? 'OK    ' : 'FALLO ') + n + (c ? '' : '  (' + d + ')')); };
(async () => {
  const b = await chromium.launch();
  const pg = await b.newPage({ viewport: { width: 360, height: 800 }, locale: 'es-ES' });
  const errs = [];
  pg.on('pageerror', (e) => errs.push(e.message));
  let ultimoAviso = '';
  await pg.exposeFunction('anotarAviso', (t) => { ultimoAviso = t; });
  await pg.addInitScript(() => {
    new MutationObserver((ms) => { for (const m of ms) for (const n of m.addedNodes) if (n.classList && n.classList.contains('toast')) window.anotarAviso(n.textContent); })
      .observe(document, { childList: true, subtree: true });
  });
  const aviso = async (ms = 1500) => { const t0 = Date.now(); while (!ultimoAviso && Date.now() - t0 < ms) await pg.waitForTimeout(100); return ultimoAviso; };
  await pg.goto('file://' + require('path').resolve(__dirname, '../dist-demo/index.html'));
  await pg.waitForTimeout(1200);
  await (await pg.$$('input'))[0].fill('demo@demo.es');
  ultimoAviso = ''; await pg.click('text=Enviarme el código');
  await pg.waitForTimeout(600);
  for (const i of await pg.$$('input')) { if ((await i.getAttribute('type')) !== 'email') await i.fill('123456').catch(() => {}); }
  ultimoAviso = ''; await pg.click('button:has-text("Entrar")', { timeout: 3000 }).catch(() => {});
  await pg.waitForTimeout(1500);
  // Taller: idea corta no deja fabricar.
  await pg.fill('textarea', 'gato');
  ok('taller: idea corta no deja fabricar', await pg.locator('button:has-text("Fabricar juego")').isDisabled());
  ultimoAviso = ''; await pg.click('button[data-uso="regalo"]');
  ok('taller: el uso cambia el ejemplo', (await pg.getAttribute('textarea', 'placeholder')).includes('Lucía'));
  await pg.fill('textarea', 'Lucía, que adora los gatos y la playa, recoge conchas esquivando cangrejos');
  ultimoAviso = ''; await pg.click('button:has-text("Fabricar juego")');
  await pg.waitForTimeout(36000);
  ok('taller: termina y propone la dedicatoria', await pg.locator('button:has-text("Escribir la dedicatoria")').isVisible());
  ultimoAviso = ''; await pg.click('button:has-text("Escribir la dedicatoria")');
  await pg.waitForTimeout(2500);
  ok('regalo: lleva a la pestaña Compartir', await pg.locator('[role=tab][aria-selected=true]:has-text("Compartir")').count() === 1);
  // Regalo: validación y guardado.
  ultimoAviso = ''; await pg.click('button:has-text("Guardar regalo")');
  ok('regalo: sin nombres avisa', (await aviso()).includes('nombres'), ultimoAviso);
  await pg.selectOption('select[aria-label="Ocasión"]', '1');
  await pg.fill('input[aria-label="Para quién"]', 'Lucía');
  await pg.fill('input[aria-label="De quién"]', 'Dani');
  ultimoAviso = ''; await pg.click('button:has-text("Ver cómo lo verá")');
  await pg.waitForTimeout(500);
  ok('regalo: vista previa paso 1 (el enlace)', (await pg.textContent('.rv-pantalla')).includes('Para Lucía'));
  await pg.click('.rv button.btn-brass'); await pg.click('.rv button.btn-brass');
  ok('regalo: vista previa paso 3 (el mensaje)', (await pg.textContent('.rv-pantalla')).includes('Un año más'), await pg.textContent('.rv-pantalla'));
  await pg.screenshot({ path: require('path').join(require('os').tmpdir(), 'orq-bot', 'regalo-vista.png') });
  await pg.click('.rv .player-close');
  ultimoAviso = ''; await pg.click('button:has-text("Guardar regalo")');
  ok('regalo: se guarda', (await aviso()).includes('guardado'), ultimoAviso);
  ok('regalo: estado para el autor', (await pg.textContent('section[data-seccion=regalo]')).includes('Aún no lo ha abierto'));
  ultimoAviso = ''; await pg.click('button:has-text("Mandar el enlace privado")');
  ok('regalo: enlace privado', /copiado|Enviado|listo/i.test(await aviso(3000)), ultimoAviso);
  ultimoAviso = ''; await pg.click('button:has-text("Descargar para itch.io")');
  await pg.waitForTimeout(2500);
  ok('itch: paquete preparado', (await pg.textContent('section:has(h2:has-text("itch.io"))')).includes('Listo'));
  // Jugadores: premio, clase, evento.
  ultimoAviso = ''; await pg.click('[role=tab]:has-text("Jugadores")');
  await pg.waitForTimeout(1000);
  await pg.fill('input[aria-label="Premio"]', 'Café gratis');
  await pg.fill('input[aria-label="Código del premio"]', 'caf é');
  ultimoAviso = ''; await pg.click('button:has-text("Guardar premio")');
  ok('premio: código malo avisa', (await aviso()).includes('código'), ultimoAviso);
  await pg.fill('input[aria-label="Código del premio"]', 'cafe');
  ultimoAviso = ''; await pg.click('button:has-text("Guardar premio")');
  ok('premio: se guarda', (await aviso()).includes('guardado'), ultimoAviso);
  ok('premio: resumen con código', (await pg.textContent('section[data-seccion=premio]')).includes('CAFE-XXXX'));
  await pg.fill('input[aria-label="Código del cliente"]', 'cafe-7f3a');
  ultimoAviso = ''; await pg.click('button:has-text("Canjear")');
  await pg.waitForTimeout(800);
  ok('canje: código válido', (await pg.textContent('.canje')).includes('Válido'), await pg.textContent('.canje'));
  await pg.fill('input[aria-label="Código del cliente"]', 'CAFE-7F3A');
  ultimoAviso = ''; await pg.click('button:has-text("Canjear")');
  await pg.waitForTimeout(800);
  ok('canje: no vale dos veces', (await pg.textContent('.canje')).includes('Ya se usó'), await pg.textContent('.canje'));
  ok('canje: el recuento sube', (await pg.textContent('section[data-seccion=premio]')).includes('canjeado 1'));
  ultimoAviso = ''; await pg.click('button:has-text("Cartel para la tienda")');
  ok('premio: el cartel pide compartir antes', (await aviso()).includes('comparte'), ultimoAviso);
  ultimoAviso = ''; await pg.click('button:has-text("Crear clase")');
  ok('clase: sin nombre avisa', (await aviso()).includes('nombre'), ultimoAviso);
  await pg.fill('input[aria-label="Nombre de la clase"]', '3º B');
  ultimoAviso = ''; await pg.click('button:has-text("Crear clase")');
  ok('clase: se crea con código', /código [A-Z2-9]{6}/.test(await aviso()), ultimoAviso);
  await pg.waitForTimeout(800);
  ok('clase: tabla de alumnos', await pg.locator('.tabla-clase tr').count() >= 3, String(await pg.locator('.tabla-clase tr').count()));
  ok('clase: avisa de quien se atasca', (await pg.textContent('.tabla-clase')).includes('Atascado en el nivel 2'), (await pg.textContent('.tabla-clase')).slice(0, 200));
  ultimoAviso = ''; await pg.click('button:has-text("Vaciar para otro trimestre")');
  ultimoAviso = ''; await pg.click('button:has-text("Pulsa otra vez")');
  ok('clase: vaciar para otro trimestre', (await aviso()).includes('vaciada'), ultimoAviso);
  await pg.fill('input[aria-label="Título del evento"]', 'Fin de semana loco');
  ultimoAviso = ''; await pg.click('button:has-text("Programar evento")');
  ok('evento: se programa', (await aviso()).includes('programado'), ultimoAviso);
  // Publicar: AdMob con ids malos.
  ultimoAviso = ''; await pg.click('[role=tab]:has-text("Publicar")');
  await pg.waitForTimeout(1000);
  const btnAds = pg.locator('button:has-text("Activar anuncios")');
  if (await btnAds.isVisible()) {
    ultimoAviso = ''; await btnAds.click();
    ok('admob: sin ids avisa', (await aviso()).length > 0, ultimoAviso);
  }
  // Compartir el juego en el escaparate y ahora sí, el cartel.
  ultimoAviso = ''; await pg.click('[role=tab]:has-text("Compartir")');
  await pg.waitForTimeout(800);
  const comp = pg.locator('button:has-text("Compartir mi juego")');
  if (await comp.isVisible()) { await comp.click(); await pg.waitForTimeout(2500); }
  ultimoAviso = ''; await pg.click('[role=tab]:has-text("Jugadores")');
  await pg.waitForTimeout(800);
  const [descarga] = await Promise.all([pg.waitForEvent('download', { timeout: 8000 }).catch(() => null), pg.click('button:has-text("Cartel para la tienda")')]);
  ok('premio: con el juego compartido sale el cartel', !!descarga, ultimoAviso);
  ok('sin errores de JavaScript', errs.length === 0, errs.join(' | '));
  console.log(res.join('\n'));
  if (res.some((r) => r.startsWith('FALLO'))) process.exitCode = 1;
  await b.close();
})();
