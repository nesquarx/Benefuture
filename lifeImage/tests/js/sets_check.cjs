// Opens a group or comparison page and reports the levels the viewer holds per mode for the given ids.
const { chromium } = require('playwright');
(async () => {
  const [page, kind, idsJson] = process.argv.slice(2), ids = JSON.parse(idsJson);
  const browser = await chromium.launch();
  const p = await (await browser.newContext({ viewport: { width: 1100, height: 800 } })).newPage();
  const errors = [];
  p.on('pageerror', e => errors.push(String(e)));
  p.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await p.goto('file://' + page);
  await p.waitForFunction(() => window.__tv && window.__tv.ready === true, null, { timeout: 60000 });
  const grab = () => p.evaluate((ids) => { const o = {}; ids.forEach(i => { const v = window.__tv.levelsOf(i); if (v) o[i] = v; }); return o; }, ids);
  const modes = {};
  if (kind === 'group') {
    modes.all = await grab();
    await p.evaluate(() => window.__tv.setMembers([true, false])); modes.only0 = await grab();
  } else {
    for (const [i, n] of ['a', 'b', 'overlap', 'a_only', 'b_only'].entries()) { await p.evaluate((i) => window.__tv.setMode(i), i); modes[n] = await grab(); }
  }
  console.log(JSON.stringify({ errors, modes }));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
