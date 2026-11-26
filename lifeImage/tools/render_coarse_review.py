"""Coarse layout review sheet (the author's gate on the coarse level, PLAN "1. Coarse"): every sector and field of the
built basemap drawn at its angle, width and radial band, coloured by its main sector, every field labelled.

Reads `data/images/v2/basemap.json` (slices as built) and `data/coarse/seed_v3.jsonl` (labels, upstream links). Writes
`data/images/review/coarse_layout.svg` (and `.png` with --png, through Playwright's Chromium). Angles follow the image
renderer: counterclockwise from the right; 0 tangible, 90 global and professional, 180 abstract, 270 personal and
social (`layout.angle_from_axes`). Deterministic.

    python3 tools/render_coarse_review.py [--png]
"""
import argparse
import colorsys
import json
import math
import subprocess
import sys
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZE, R = 2800, 900          # canvas px; data radius 1 -> R px
CX = CY = SIZE / 2
LABEL_R = 1.04               # labels start just outside the outermost field
MIN_SEP = 0.62               # minimum angular separation of labels, degrees


def pt(r, a):
    return CX + r * R * math.cos(math.radians(a)), CY - r * R * math.sin(math.radians(a))


def wedge(r0, r1, a0, a1):
    large = 1 if (a1 - a0) % 360 > 180 else 0
    x0, y0 = pt(r1, a0); x1, y1 = pt(r1, a1); x2, y2 = pt(r0, a1); x3, y3 = pt(r0, a0)
    return (f"M{x0:.1f},{y0:.1f} A{r1*R:.1f},{r1*R:.1f} 0 {large} 0 {x1:.1f},{y1:.1f} "
            f"L{x2:.1f},{y2:.1f} A{r0*R:.1f},{r0*R:.1f} 0 {large} 1 {x3:.1f},{y3:.1f} Z")


def main_sector(cid, by, seen=()):
    ups = sorted((l for l in by[cid]["links"] if l["rel"] == "upstream"), key=lambda l: (-l["weight"], l["id"]))
    for l in ups:
        if l["id"].startswith("s."):
            return l["id"]
    for l in ups:
        if l["id"] in by and l["id"] not in seen:
            s = main_sector(l["id"], by, seen + (cid,))
            if s:
                return s
    return None


def spread(items):
    """Relax label angles so neighbours keep MIN_SEP; items [(angle, id)] sorted. Returns {id: angle}."""
    a = [x for x, _ in items]
    n = len(a)
    for _ in range(400):
        moved = False
        for i in range(n):
            j = (i + 1) % n
            gap = (a[j] - a[i]) % 360
            if gap < MIN_SEP:
                push = (MIN_SEP - gap) / 2
                a[i] -= push; a[j] += push; moved = True
        if not moved:
            break
    return {i: x % 360 for x, (_, i) in zip(a, items)}


def sim_basemap():
    """The simulation's layout (data/coarse/layout_sim_v0.json) tiled by the basemap build, in basemap.json's shape."""
    sys.path.insert(0, str(ROOT))
    from lifeimage import layout_sim
    res = json.loads((ROOT / "data/coarse/layout_sim_v0.json").read_text())
    sl = layout_sim.tiled_slices(res)
    return {"version": f"{res['version']} (simulated placement)",
            "slices": {i: {"ring": s.ring, "start": s.start, "width": s.width, "r0": s.r0, "r1": s.r1} for i, s in sl.items()}}


def seriation_basemap():
    """The seriation order (data/coarse/seriation_v0.json, LI.60) tiled by the basemap build, in basemap.json's shape."""
    sys.path.insert(0, str(ROOT))
    from lifeimage import layout_sim
    res = json.loads((ROOT / "data/coarse/seriation_v0.json").read_text())
    sl = layout_sim.tiled_slices(res)
    return {"version": f"{res['version']} (circular seriation)",
            "slices": {i: {"ring": s.ring, "start": s.start, "width": s.width, "r0": s.r0, "r1": s.r1} for i, s in sl.items()}}


def build(sim=False, seriation=False):
    bm = seriation_basemap() if seriation else sim_basemap() if sim else json.loads((ROOT / "data/images/v2/basemap.json").read_text())
    cards = [json.loads(l) for l in (ROOT / "data/coarse/seed_v3.jsonl").read_text().splitlines() if l.strip()]
    by = {c["id"]: c for c in cards}
    sl = bm["slices"]
    sectors = sorted((k for k, v in sl.items() if v["ring"] == "sector"), key=lambda k: sl[k]["start"] + sl[k]["width"] / 2)
    hue = {s: i / len(sectors) for i, s in enumerate(sectors)}

    def colour(sec, light):
        r, g, b = colorsys.hls_to_rgb(hue.get(sec, 0.0), light, 0.55 if sec else 0.0)
        return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" '
           f'font-family="Helvetica, Arial, sans-serif">', f'<rect width="{SIZE}" height="{SIZE}" fill="#fbfaf7"/>']
    for g in (0.25, 0.5, 0.75, 1.0):
        out.append(f'<circle cx="{CX}" cy="{CY}" r="{g*R}" fill="none" stroke="#d8d4cc" stroke-width="1" stroke-dasharray="4 6"/>')
    for a, name in ((0, "TANGIBLE"), (90, "GLOBAL / PROFESSIONAL"), (180, "ABSTRACT"), (270, "PERSONAL / SOCIAL")):
        x0, y0 = pt(0.05, a); x1, y1 = pt(1.0, a)
        out.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="#bbb4a8" stroke-width="1.5"/>')
    fields = sorted((k for k, v in sl.items() if v["ring"] == "field"), key=lambda k: sl[k]["start"])
    secof = {f: main_sector(f, by) for f in fields}
    for f in fields:
        v = sl[f]
        out.append(f'<path d="{wedge(v["r0"], v["r1"], v["start"], v["start"] + v["width"])}" fill="{colour(secof[f], 0.62)}" '
                   f'stroke="#fbfaf7" stroke-width="0.8"><title>{escape(by[f]["label"])} ({f})</title></path>')
    for s in sectors:
        v = sl[s]
        out.append(f'<path d="{wedge(v["r0"], v["r1"], v["start"], v["start"] + v["width"])}" fill="{colour(s, 0.42)}" '
                   f'stroke="#fbfaf7" stroke-width="1.5"/>')
    # sector numbers on their arcs, names in the legend (hub labels collide)
    for n, s in enumerate(sectors, 1):
        v = sl[s]; a = v["start"] + v["width"] / 2
        x, y = pt((v["r0"] + v["r1"]) / 2, a)
        out.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="14" font-weight="bold" fill="#fff" '
                   f'text-anchor="middle" dominant-baseline="middle">{n}</text>')
        ly = 130 + 26 * n
        out.append(f'<rect x="{SIZE-430}" y="{ly-9}" width="18" height="18" fill="{colour(s, 0.42)}"/>'
                   f'<text x="{SIZE-404}" y="{ly}" font-size="15" fill="#3a352e" dominant-baseline="middle">'
                   f'{n}. {escape(by[s]["label"])}</text>')
    # field labels, spread and leadered
    rmax = max(sl[f]["r1"] for f in fields)
    lab = spread(sorted(((sl[f]["start"] + sl[f]["width"] / 2) % 360, f) for f in fields))
    for f in fields:
        v = sl[f]; a0 = (v["start"] + v["width"] / 2) % 360; a = lab[f]
        r_text = rmax * LABEL_R
        x0, y0 = pt(v["r1"], a0); x1, y1 = pt(rmax * 1.01, a0); x2, y2 = pt(r_text - 0.005, a)
        out.append(f'<polyline points="{x0:.1f},{y0:.1f} {x1:.1f},{y1:.1f} {x2:.1f},{y2:.1f}" fill="none" stroke="#c9c3b8" stroke-width="0.6"/>')
        x, y = pt(r_text, a)
        flip = 90 < a < 270
        rot = -a + (180 if flip else 0)
        anchor = "end" if flip else "start"
        out.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="10.5" fill="{colour(secof[f], 0.28)}" text-anchor="{anchor}" '
                   f'dominant-baseline="middle" transform="rotate({rot:.2f} {x:.1f} {y:.1f})">{escape(by[f]["label"])}</text>')
    for a, name in ((0, "TANGIBLE  →"), (90, "GLOBAL / PROFESSIONAL"), (180, "←  ABSTRACT"), (270, "PERSONAL / SOCIAL")):
        x, y = pt(1.42 if a in (0, 180) else 1.45, a)
        out.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="20" letter-spacing="3" fill="#7a7266" text-anchor="middle" '
                   f'dominant-baseline="middle">{name}</text>')
    out.append(f'<text x="40" y="50" font-size="26" fill="#3a352e">Life Image coarse layout, basemap {escape(str(bm.get("version")))}</text>')
    how = ("circular seriation (ring order maximising adjacent similarity, displacement from the axes priced)" if seriation else
           "polar force simulation (axes as a weak prior, attraction along links, repulsion)" if sim else "judged axes")
    out.append(f'<text x="40" y="82" font-size="15" fill="#7a7266">{len(sectors)} sectors (inner ring) and {len(fields)} fields. '
               f'Angle: {how}. Radial band: judged advanced/specialised score (dashed rings at 0.25 steps). '
               'Width: domain pressure (synthetic sample, provisional). Colour: main sector.</text>')
    out.append('</svg>')
    return "\n".join(out), len(sectors), len(fields)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--png", action="store_true")
    ap.add_argument("--layout-sim", action="store_true", help="take angles from data/coarse/layout_sim_v0.json")
    ap.add_argument("--seriation", action="store_true", help="take angles from data/coarse/seriation_v0.json")
    args = ap.parse_args()
    svg, ns, nf = build(args.layout_sim, args.seriation)
    name = "coarse_layout_seriation" if args.seriation else "coarse_layout_sim" if args.layout_sim else "coarse_layout"
    d = ROOT / "data/images/review"; d.mkdir(parents=True, exist_ok=True)
    p = d / f"{name}.svg"; p.write_text(svg)
    print(f"{p}: {ns} sectors, {nf} fields")
    if args.png:
        js = (f"const {{chromium}}=require('playwright');(async()=>{{const b=await chromium.launch();"
              f"const pg=await b.newPage({{viewport:{{width:{SIZE},height:{SIZE}}},deviceScaleFactor:1}});"
              f"await pg.goto('file://{p}');await pg.screenshot({{path:'{d / f'{name}.png'}'}});await b.close();}})();")
        subprocess.run(["node", "-e", js], check=True)
        print(d / f"{name}.png")


if __name__ == "__main__":
    sys.exit(main())
