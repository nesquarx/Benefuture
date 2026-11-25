// Serves an online folder with Range support, opens it at a given view, reports the tiles and bytes the client fetched.
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
(async () => {
  const [dir, z, ox, oy, w, h] = process.argv.slice(2);
  const log = [];
  const srv = http.createServer((req, res) => {
    const f = path.join(dir, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
    if (!f.startsWith(dir) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    const buf = fs.readFileSync(f), range = req.headers.range;
    const type = f.endsWith('.html') ? 'text/html' : f.endsWith('.json') ? 'application/json' : 'application/octet-stream';
    if (range && /^bytes=/.test(range)) {
      const [a, b] = range.slice(6).split('-'), s = +a, e = b === '' ? buf.length - 1 : +b;
      log.push({ url: req.url, start: s, end: e });
      res.writeHead(206, { 'Content-Type': type, 'Content-Range': `bytes ${s}-${e}/${buf.length}`, 'Content-Length': e - s + 1, 'Accept-Ranges': 'bytes' });
      return res.end(buf.subarray(s, e + 1));
    }
    log.push({ url: req.url, start: 0, end: buf.length - 1, whole: true });
    res.writeHead(200, { 'Content-Type': type, 'Content-Length': buf.length, 'Accept-Ranges': 'bytes' });
    res.end(buf);
  }).listen(0);
  const port = srv.address().port;
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  const p = await ctx.newPage();
  const errors = [];
  p.on('pageerror', e => errors.push(String(e)));
  p.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await p.goto(`http://127.0.0.1:${port}/`);
  await p.waitForFunction(() => window.__tv && window.__tv.ready === true, null, { timeout: 60000 });
  await p.evaluate(([z, ox, oy]) => window.__tv.clearLog() || window.__tv.setView(+z, +ox, +oy), [z, ox, oy]);
  await p.waitForFunction(() => window.__tv.idle === true, null, { timeout: 60000 });
  await p.waitForTimeout(300);
  const info = await p.evaluate(() => ({ tiles: window.__tv.tilesFetched, bytes: window.__tv.tileBytes, lit: window.__tv.litPixels(), size: window.__tv.size() }));
  console.log(JSON.stringify({ errors, tilesFetched: info.tiles, tileBytes: info.bytes, litPixels: info.lit, canvas: info.size, requests: log.length }));
  await browser.close(); srv.close();
})().catch(e => { console.error(e); process.exit(1); });
