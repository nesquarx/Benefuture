// Scratch: prototype the free-floating force layout against real parsed data.
import fs from "node:fs";
import { parseBfPseudocode } from "./parse.mjs";

const graph = parseBfPseudocode(fs.readFileSync(new URL("../../Bf_Pseudocode.txt", import.meta.url), "utf8"));
const nodes = graph.nodes;
const edges = graph.edges;
const nodeById = new Map(nodes.map((n) => [n.id, n]));

const nodeW = (id) => {
  const n = nodeById.get(id);
  const label = n ? n.name : id;
  return Math.max(64, Math.ceil(label.length * 6.6) + 22);
};
const NODE_H = 40;

function run({ ITER, SPRING, REPEL, SPRING_K, GRAV, C0 }) {
  const ids = nodes.map((n) => n.id);
  const pos = new Map();
  ids.forEach((id, i) => {
    const r = C0 * Math.sqrt(i + 0.5);
    const a = i * 2.399963;
    pos.set(id, { x: 700 + r * Math.cos(a), y: 500 + r * Math.sin(a) });
  });
  for (let it = 0; it < ITER; it++) {
    const disp = new Map(ids.map((id) => [id, { x: 0, y: 0 }]));
    for (let i = 0; i < ids.length; i++) {
      const a = pos.get(ids[i]);
      const da = disp.get(ids[i]);
      for (let j = i + 1; j < ids.length; j++) {
        const b = pos.get(ids[j]);
        const db = disp.get(ids[j]);
        let dx = a.x - b.x;
        let dy = a.y - b.y;
        let d2 = dx * dx + dy * dy;
        if (d2 < 0.01) {
          dx = 0.13 * (i - j || 1);
          dy = 0.07;
          d2 = dx * dx + dy * dy;
        }
        const d = Math.sqrt(d2);
        const f = REPEL / d2;
        const ux = dx / d;
        const uy = dy / d;
        da.x += ux * f;
        da.y += uy * f;
        db.x -= ux * f;
        db.y -= uy * f;
      }
    }
    for (const e of edges) {
      const a = pos.get(e.from);
      const b = pos.get(e.to);
      if (!a || !b) continue;
      const da = disp.get(e.from);
      const db = disp.get(e.to);
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const d = Math.max(1, Math.hypot(dx, dy));
      const f = (d - SPRING) * SPRING_K;
      const ux = dx / d;
      const uy = dy / d;
      da.x += ux * f;
      da.y += uy * f;
      db.x -= ux * f;
      db.y -= uy * f;
    }
    let cx = 0;
    let cy = 0;
    for (const id of ids) {
      cx += pos.get(id).x;
      cy += pos.get(id).y;
    }
    cx /= ids.length;
    cy /= ids.length;
    const temp = Math.max(0.06, 1 - it / ITER);
    const maxStep = 26 * temp;
    for (const id of ids) {
      const p = pos.get(id);
      const d = disp.get(id);
      d.x += (cx - p.x) * GRAV;
      d.y += (cy - p.y) * GRAV;
      const len = Math.hypot(d.x, d.y) || 1;
      const s = Math.min(len, maxStep) / len;
      p.x += d.x * s;
      p.y += d.y * s;
    }
  }
  // rectangle-separation relaxation: push overlapping boxes apart, axis of least penetration
  const PAD = 14;
  for (let pass = 0; pass < 120; pass++) {
    let moved = false;
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const a = pos.get(ids[i]);
        const b = pos.get(ids[j]);
        const aw = nodeW(ids[i]);
        const bw = nodeW(ids[j]);
        const ox = Math.min(a.x + aw + PAD, b.x + bw + PAD) - Math.max(a.x - PAD, b.x - PAD);
        const oy = Math.min(a.y + NODE_H + PAD, b.y + NODE_H + PAD) - Math.max(a.y - PAD, b.y - PAD);
        if (ox > 0 && oy > 0) {
          moved = true;
          if (ox < oy) {
            const push = ox / 2;
            if (a.x < b.x) { a.x -= push; b.x += push; } else { a.x += push; b.x -= push; }
          } else {
            const push = oy / 2;
            if (a.y < b.y) { a.y -= push; b.y += push; } else { a.y += push; b.y -= push; }
          }
        }
      }
    }
    if (!moved) break;
  }
  // measure
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const [id, p] of pos) {
    minX = Math.min(minX, p.x);
    minY = Math.min(minY, p.y);
    maxX = Math.max(maxX, p.x + nodeW(id));
    maxY = Math.max(maxY, p.y + NODE_H);
  }
  let overlaps = 0;
  let worst = 0;
  const idsArr = ids;
  for (let i = 0; i < idsArr.length; i++) {
    for (let j = i + 1; j < idsArr.length; j++) {
      const a = pos.get(idsArr[i]);
      const b = pos.get(idsArr[j]);
      const aw = nodeW(idsArr[i]);
      const bw = nodeW(idsArr[j]);
      const ox = Math.min(a.x + aw, b.x + bw) - Math.max(a.x, b.x);
      const oy = Math.min(a.y + NODE_H, b.y + NODE_H) - Math.max(a.y, b.y);
      if (ox > 0 && oy > 0) {
        overlaps++;
        worst = Math.max(worst, Math.min(ox, oy));
      }
    }
  }
  return { w: Math.round(maxX - minX), h: Math.round(maxY - minY), overlaps, worst: Math.round(worst) };
}

const t0 = Date.now();
for (const cfg of [
  { ITER: 420, SPRING: 190, REPEL: 32000, SPRING_K: 0.045, GRAV: 0.015, C0: 120 },
  { ITER: 600, SPRING: 200, REPEL: 45000, SPRING_K: 0.04, GRAV: 0.012, C0: 120 },
  { ITER: 600, SPRING: 210, REPEL: 60000, SPRING_K: 0.035, GRAV: 0.01, C0: 140 },
]) {
  const r = run(cfg);
  console.log(JSON.stringify(cfg), "→", JSON.stringify(r), `${Date.now() - t0}ms`);
}
