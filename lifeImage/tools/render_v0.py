"""Render the predicted/measured image of every synthetic persona, organisation and public figure.

Usage (from the repository root): python3 lifeImage/tools/render_v0.py [--out lifeImage/data/images/v2] [--legacy]
Writes one SVG per entity, `basemap.svg` (the sector ring labelled), `basemap.json` (angles, slices, notes) and
`contact.html` (grid, legend, and the characterisation features beside each image). By default the levels (LI.36) and
the channel split (LI.37, LI.38) and the anchored tone map (LI.39) are drawn, into data/images/v2; `--legacy` draws the earlier projection (default
data/images/v0). Deterministic: the same data gives byte-identical files.
"""
import argparse
import json
import sys
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage import characterise as ch  # noqa: E402
from lifeimage.render import basemap as bmod  # noqa: E402
from lifeimage.render import image as im  # noqa: E402

KIND_PREFIX = {"person": "persona", "organisation": "org", "public": "public"}


def file_name(e):
    return f"{KIND_PREFIX[e['kind']]}-{e['id']}.svg"


def basemap_svg(bm, cards):
    """The basemap alone: slice outlines, sector labels in the inner ring, axis directions."""
    by = {c["id"]: c for c in cards}
    empty = im.render_svg("basemap", {}, bm, size=900).replace("</svg>\n", "")
    import math
    lab = []
    for s in sorted((s for s in bm.slices.values() if s.ring == "sector"), key=lambda s: s.id):
        a = math.radians(s.angle)
        r = (s.r0 + s.r1) / 2
        lab.append(f'<text x="{r * math.cos(a):.3f}" y="{-r * math.sin(a):.3f}" font-size="0.028" fill="#cfcfcf" '
                   f'text-anchor="middle" font-family="sans-serif">{escape(by[s.id]["label"].split(",")[0])}</text>')
    axes = [("tangible", 1.2, 0), ("global", 0, -1.2), ("abstract", -1.2, 0), ("personal", 0, 1.2)]
    ax = "".join(f'<text x="{x}" y="{y}" font-size="0.04" fill="#7a7a7a" text-anchor="middle" font-family="sans-serif">{n}</text>'
                 for n, x, y in axes)
    return empty + "".join(lab) + ax + "</svg>\n"


LEGEND_LEVELS = """<tr><td><span class=sw style="background:#f00"></span>red</td><td>knowledge and potential: taking in (reading, watching, schooling), claims, self-assessment and predictions, and tests of knowing</td></tr>
<tr><td><span class=sw style="background:#0f0"></span>green</td><td>demonstrated skill: attested or measured producing, and assessments of doing</td></tr>
<tr><td><span class=sw style="background:#00f"></span>blue</td><td>impact: the outcome of what attested or measured producing changed for others</td></tr>
<tr><td><span class=sw style="background:#ff0"></span>yellow (red+green), <span class=sw style="background:#f0f"></span>purple (red+blue)</td><td>knowing or claiming matched by doing, or by impact; red without green is knowing or claiming without doing</td></tr>
<tr><td>grain</td><td>claimed potential only: self-assessment, forecasts and claims of capability (red); never made solid, and read against the green beside it</td></tr>
<tr><td>paler colour</td><td>tier: a self-reported event is drawn pale, an attested one slightly less, a measured one at full saturation; the level is the same at every tier</td></tr>
<tr><td>brightness</td><td>a level in [0, 1] per domain and channel: imprints (weight x decay, 15-year half-life) add, then a saturating tone map anchored so a regular 40-year-old's typical touched domain is mid-brightness; absolute across people, a claim imprints the level it claims</td></tr>"""
LEGEND_LEGACY = """<tr><td><span class=sw style="background:#f00"></span>red</td><td>potential: predicted expertise and impact, self-assessment included</td></tr>
<tr><td><span class=sw style="background:#0f0"></span>green</td><td>expertise: what was done and engaged with (form, content)</td></tr>
<tr><td><span class=sw style="background:#00f"></span>blue</td><td>impact: what changed (outcome)</td></tr>
<tr><td><span class=sw style="background:#ff0"></span>yellow (red+green), <span class=sw style="background:#f0f"></span>purple (red+blue)</td><td>potential matched by expertise, or by impact; much red without them is over-estimation</td></tr>
<tr><td><span class=sw style="background:#0ff"></span>teal, blue, green without red</td><td>under-estimation; white and grey with flecks of colour: estimated, learnt and contributed in the same areas</td></tr>
<tr><td>grain, paler colour</td><td>claimed tier (self-reported, not corroborated); solid colour is attested or measured</td></tr>
<tr><td>brightness</td><td>magnitude on a log scale, one fixed scale for every image; older rows dim with a 15-year half-life</td></tr>"""


def feature_line(f):
    """The characterisation features of one image, in a few readable lines."""
    arcs = sorted(((v, k[10:]) for k, v in f.items() if k.startswith("arc_share:")), reverse=True)[:2]
    return (f'R {100 * f["share_red"]:.0f}% G {100 * f["share_green"]:.0f}% B {100 * f["share_blue"]:.0f}%<br>'
            f'grainy red {100 * f["red_grain_share"]:.0f}% &middot; dimmed {100 * f["dimmed_share"]:.0f}%<br>'
            f'clusters {f["n_clusters"]} &middot; spread {f["spread_entropy"]:.2f} &middot; lum {f["luminance"]:.3f}<br>'
            f'{"claim gap %+.2f" % f["claim_gap"] if f["claim_gap"] == f["claim_gap"] else "no claims"} &middot; typical level {f["typical_level"]:.2f}<br>'
            f'top arcs {escape(", ".join(f"{k} {100 * v:.0f}%" for v, k in arcs))}')


def contact_html(ents, bm, total_bytes, feats=None, legacy=False):
    feats = feats or {}
    cells = []
    for kind, title in (("person", "Personas (synthetic)"), ("organisation", "Organisations (synthetic)"),
                        ("public", "Public figures (Wikidata)")):
        cells.append(f"<h2>{title}</h2><div class=grid>")
        for e in [e for e in ents if e["kind"] == kind]:
            cells.append(f'<figure class="cal-{e["calibration"].replace(" ", "-")}"><img loading=lazy src="{file_name(e)}" alt="{escape(e["label"])}">'
                         f'<figcaption><b>{escape(e["label"])}</b><br>{escape(e["archetype"])}<br>'
                         f'calibration: {escape(e["calibration"])} &middot; {len(e["rows"])} rows'
                         f'<br><small>{feature_line(feats[e["id"]]) if e["id"] in feats else ""}</small></figcaption></figure>')
        cells.append("</div>")
    notes = "".join(f"<li>{escape(n)}</li>" for n in bm.notes)
    return f"""<!doctype html>
<html lang=en><meta charset=utf-8><title>Life Image {"v0 legacy" if legacy else "v2"}: contact sheet</title>
<style>
body{{background:#101010;color:#ddd;font:14px/1.4 sans-serif;margin:1.5rem}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:1rem}}
figure{{margin:0;background:#000;padding:.4rem;border:1px solid #222}} img{{width:100%;height:auto;display:block}}
figcaption{{font-size:12px;color:#aaa;padding-top:.3rem}} .sw{{display:inline-block;width:1em;height:1em;vertical-align:-.15em;margin-right:.4em}}
td,th{{padding:.15rem .8rem .15rem 0;text-align:left;vertical-align:top}} h1,h2{{font-weight:600}} a{{color:#8ab}}
</style>
<h1>Life Image {"v0 (legacy projection)" if legacy else "v2 (levels, grain for potential only, anchored scale)"}: predicted/measured</h1>
<p>Basemap {escape(bm.version)}. {len(ents)} entities, all synthetic or public figures. SVG total {total_bytes / 1e6:.1f} MB.</p>
<h2>Legend</h2>
<table>
{LEGEND_LEGACY if legacy else LEGEND_LEVELS}
<tr><td>angle</td><td>0 deg right is tangible, top global, left abstract, bottom personal; slice width follows evidence pressure</td></tr>
<tr><td>radius</td><td>inner ring sectors, outer ring fields; within a ring the band follows the radius composite (complexity, difficulty, specificity)</td></tr>
<tr><td>flange</td><td>triangle at the right rim, with the basemap version; the notch slot at the rim is empty (no net new achievements yet)</td></tr>
</table>
<p>The image judges estimation and the use of expertise, not worth. <a href="basemap.svg">Basemap with sector labels</a>.</p>
<ul>{notes}</ul>
{"".join(cells)}
<p>Negative rows wait for the reputation image. Entities are synthetic personas and organisations and deceased public figures.</p>
</html>
"""


def main(out, legacy=False):
    out.mkdir(parents=True, exist_ok=True)
    cards = bmod.load_all_cards()
    bm = bmod.build_v0(by_depth=legacy, fine=not legacy)  # the legacy projection keeps the earlier depth-only radius and has no fine ring
    ents = im.load_entities()
    total = 0
    asof = {p["id"]: p["as_of"] for p in ch.starter_personas()}
    feats = {}
    for e in ents:
        a = asof.get(e["id"]) if e["kind"] == "person" and not legacy else None  # legacy keeps its own reference (latest valid_time)
        feats[e["id"]] = ch.record_for(e, e["rows"], a, legacy, bm)[0]
        svg = im.render_svg(e["label"], im.channel_values(e["rows"], cards, asof=a, legacy=legacy), bm, legacy=legacy)
        (out / file_name(e)).write_text(svg, encoding="utf-8")
        total += len(svg.encode())
    bsvg = basemap_svg(bm, cards)
    (out / "basemap.svg").write_text(bsvg, encoding="utf-8")
    (out / "basemap.json").write_text(json.dumps({
        "version": bm.version, "notes": bm.notes, "inherited": bm.inherited, "shift_degrees": bm.shift,
        "slices": {i: {"ring": s.ring, "axes_angle": round(s.axes_angle, 3), "start": round(s.start, 3),
                       "width": round(s.width, 3), "r0": s.r0, "r1": s.r1, "pressure": round(s.pressure, 6),
                       "source": s.source, "votes": bm.votes.get(i)} for i, s in sorted(bm.slices.items())}},
        indent=1, sort_keys=True) + "\n", encoding="utf-8")
    (out / "contact.html").write_text(contact_html(ents, bm, total, feats, legacy), encoding="utf-8")
    print(f"{len(ents)} images, {total / 1e6:.2f} MB of SVG; shift {bm.shift}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--legacy", action="store_true", help="draw the earlier projection (summed magnitudes on a log scale)")
    a = ap.parse_args()
    main(a.out or ROOT / ("data/images/v0" if a.legacy else "data/images/v2"), a.legacy)
