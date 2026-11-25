// Opens the vector page at several zooms around a domain and reports the drawn label boxes and how many labels were candidates.
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
(async () => {
  const target = process.argv[2], id = process.argv[3], zooms = JSON.parse(process.argv[4]).map(z => z / 10 + 2.0);
  let srv = null, base;
  if (fs.statSync(target).isDirectory()) {
    srv = http.createServer((req, res) => {
      const f = path.join(target, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
      if (!f.startsWith(target) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
      const buf = fs.readFileSync(f), range = req.headers.range;
      if (range) { const [a, b] = range.slice(6).split('-'), s = +a, e = b === '' ? buf.length - 1 : +b;
        res.writeHead(206, { 'Content-Range': `bytes ${s}-${e}/${buf.length}`, 'Content-Length': e - s + 1 }); return res.end(buf.subarray(s, e + 1)); }
      res.writeHead(200, { 'Content-Type': f.endsWith('.html') ? 'text/html' : 'application/octet-stream' }); res.end(buf);
    }).listen(0);
    base = `http://127.0.0.1:${srv.address().port}/`;
  } else base = 'file://' + target;
  const browser = await chromium.launch();
  const p = await (await browser.newContext({ viewport: { width: 1100, height: 800 }, deviceScaleFactor: 1 })).newPage();
  await p.goto(base);
  await p.waitForFunction(() => window.__tv && window.__tv.ready === true, null, { timeout: 60000 });
  const views = [];
  for (const z of zooms) {
    await p.evaluate(([id, z]) => window.__tv.lookAt(id, z), [id, z]);
    await p.waitForFunction(() => window.__tv.idle === true, null, { timeout: 60000 });
    await p.waitForTimeout(150);
    views.push(await p.evaluate(() => ({ zoom: window.__tv.view().zoom, boxes: window.__tv.labelBoxes, candidates: window.__tv.labelCandidates })));
  }
  console.log(JSON.stringify({ views }));
  await browser.close(); if (srv) srv.close();
})().catch(e => { console.error(e); process.exit(1); });
