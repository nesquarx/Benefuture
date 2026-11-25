// Drives the vector viewer like a map user: search, fly-to, hover, click, hash link, channel toggle, labels.
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
(async () => {
  const target = process.argv[2], sc = JSON.parse(process.argv[3]);
  let srv = null, base;
  if (fs.statSync(target).isDirectory()) {
    srv = http.createServer((req, res) => {
      const f = path.join(target, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
      if (!f.startsWith(target) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
      const buf = fs.readFileSync(f), range = req.headers.range;
      const type = f.endsWith('.html') ? 'text/html' : f.endsWith('.json') ? 'application/json' : 'application/octet-stream';
      if (range) { const [a, b] = range.slice(6).split('-'), s = +a, e = b === '' ? buf.length - 1 : +b;
        res.writeHead(206, { 'Content-Type': type, 'Content-Range': `bytes ${s}-${e}/${buf.length}`, 'Content-Length': e - s + 1 }); return res.end(buf.subarray(s, e + 1)); }
      res.writeHead(200, { 'Content-Type': type, 'Content-Length': buf.length }); res.end(buf);
    }).listen(0);
    base = `http://127.0.0.1:${srv.address().port}/`;
  } else base = 'file://' + target;
  const browser = await chromium.launch();
  const mk = async (url) => {
    const ctx = await browser.newContext({ viewport: { width: 1100, height: 800 }, deviceScaleFactor: 1 });
    const p = await ctx.newPage(); p.errors = [];
    p.on('pageerror', e => p.errors.push(String(e)));
    p.on('console', m => { if (m.type() === 'error') p.errors.push(m.text()); });
    await p.goto(url);
    await p.waitForFunction(() => window.__tv && window.__tv.ready === true, null, { timeout: 60000 });
    await p.waitForFunction(() => window.__tv.idle === true, null, { timeout: 60000 });
    return p;
  };
  const idle = async (p) => { await p.waitForTimeout(100); await p.waitForFunction(() => window.__tv.idle === true, null, { timeout: 60000 }); };
  const p = await mk(base);
  const out = { canvas: await p.evaluate(() => window.__tv.size()), fitZoom: await p.evaluate(() => window.__tv.view().zoom) };
  const fitLabels = await p.evaluate(() => window.__tv.labelsDrawn);
  await p.fill('#search', sc.term); await p.press('#search', 'Enter'); await idle(p);
  const at = await p.evaluate((id) => Object.assign({}, window.__tv.view(), window.__tv.screenOf(id), { selected: window.__tv.selected }), sc.id);
  out.search = { selected: at.selected, x: at.x, y: at.y, zoom: at.zoom, cx: at.cx, cy: at.cy };
  out.panel = await p.evaluate(() => document.getElementById('info').innerText);
  out.labels = { fit: fitLabels, deep: await p.evaluate(() => window.__tv.labelsDrawn) };
  await p.mouse.move(at.x, at.y); await p.waitForTimeout(150);
  out.hover = await p.evaluate(() => window.__tv.hover);
  out.hash = await p.evaluate(() => location.hash);
  await p.keyboard.press('Escape'); await p.mouse.move(2, 2);
  await p.mouse.click(at.x, at.y); await idle(p);
  out.click = { selected: await p.evaluate(() => window.__tv.selected) };
  out.hash = await p.evaluate(() => location.hash);
  await p.mouse.move(2, 2); await p.waitForTimeout(100);
  // The slice centre can fall on the selection outline (#ffd84a, or the white hover outline) when the slice is only a few pixels
  // wide at the fly-to zoom, so sample the nearest pixel to the centre that is fill, not outline; the same point before and after.
  const pt = await p.evaluate(([x, y]) => {
    const isLine = c => (c[0] === 255 && c[1] === 216 && c[2] === 74) || (c[0] === 255 && c[1] === 255 && c[2] === 255);
    const offs = []; for (let dy = -10; dy <= 10; dy++) for (let dx = -10; dx <= 10; dx++) offs.push([dx, dy]);
    offs.sort((a, b) => (a[0] * a[0] + a[1] * a[1]) - (b[0] * b[0] + b[1] * b[1]));
    for (const [dx, dy] of offs) if (!isLine(window.__tv.pixelAt(x + dx, y + dy))) return [x + dx, y + dy];
    return [x, y];
  }, [at.x, at.y]);
  const before = await p.evaluate(([x, y]) => window.__tv.pixelAt(x, y), pt);
  await p.click('#ch-green'); await idle(p);
  const after = await p.evaluate(([x, y]) => window.__tv.pixelAt(x, y), pt);
  out.toggle = { before, after };
  const q = await mk(base + out.hash);
  out.restored = await q.evaluate(() => Object.assign({}, window.__tv.view(), { selected: window.__tv.selected }));
  out.errors = p.errors.concat(q.errors);
  console.log(JSON.stringify(out));
  await browser.close(); if (srv) srv.close();
})().catch(e => { console.error(e); process.exit(1); });
