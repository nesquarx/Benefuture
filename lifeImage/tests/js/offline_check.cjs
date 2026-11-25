// Opens a page with the network off, reports page errors, any attempted non-file request, lit pixels; screenshot at DPR 1.
const { chromium } = require('playwright');
(async () => {
  const [page, shot] = process.argv.slice(2);
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ offline: true, viewport: { width: 1100, height: 800 }, deviceScaleFactor: 1 });
  const p = await ctx.newPage();
  const errors = [], blocked = [];
  p.on('pageerror', e => errors.push(String(e)));
  p.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  p.on('request', r => { if (!/^(file|data|blob):/.test(r.url())) blocked.push(r.url()); });
  await p.goto('file://' + page);
  await p.waitForFunction(() => window.__tv && window.__tv.ready === true, null, { timeout: 60000 });
  await p.waitForTimeout(300);
  const lit = await p.evaluate(() => window.__tv.litPixels());
  await p.screenshot({ path: shot });
  console.log(JSON.stringify({ errors, blockedRequests: blocked, litPixels: lit }));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
