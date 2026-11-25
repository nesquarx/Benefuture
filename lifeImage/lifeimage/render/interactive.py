"""Interactive viewer (LI.2): one self-contained HTML file per image, zoomable from the whole disc to single pieces of
evidence, with no network, no libraries and no external files.

Zoom path. depth 0 the whole disc; 1 a sector; 2 a coarse field (its levels, and the fine domains beneath it); 3 the
evidence imprinting that field; 4 one evidence row (one-line reason, tier, date, channel, contribution to the level).
Evidence rows sit at the coarse field because the fine cards carry no rows yet, so the fine domains are listed, not
drawn with levels of their own. Wheel, pinch and drag zoom and pan freely, and the depth follows the zoom (labels
appear where a slice is wide enough on screen); the keyboard walks the same path (arrows, Enter, Escape, + and -), and
the side panel offers every step as a button.

Disclosure (DESIGN, BP.6) is chosen at build time and decides what is in the bytes, never what is hidden by script:
  none     the pattern only: slice geometry and colours under anonymous indices; no ids, labels, names, fine domains,
           rows, zoom or pan wiring.
  summary  adds domain ids and labels, levels per domain, the fine domains and (group) the members' summed imprints;
           zoom reaches the field.
  full     adds the evidence rows with their reports and contributions; zoom reaches a single row.

Contribution of a row. The level of a domain and channel is split among the rows that imprint it in proportion to each
row's own imprint (its single-row sum before the tone map), so contributions sum to the level exactly. The projection's
per-domain caps make a row's imprint alone differ slightly from its share of the whole; the split uses the singles.

Set operations. A group image is the sum of its members' imprints, re-saturated: per-domain luminosities add and the
tone map is applied once (`lifeimage.levels.tone`), so exposures compose as 1 - prod(1 - level) and a level never
exceeds 1. The file carries each member's untoned sums, so the viewer can re-saturate any subset. A comparison image of A
and B holds, per domain and channel, the overlap min(A, B) and each side's difference max(A - B, 0), max(B - A, 0);
overlap plus A's difference is A.

Deterministic: sorted iteration, rounded numbers, no clock. Levels, saturations and slice geometry follow the basemap
as built (`basemap.build_v0`); radii are read from the slices, not assumed.
"""
import gzip
import json
import math
from functools import lru_cache
from html import escape

from .. import levels as lv
from ..packs import is_sector
from . import basemap as bmod
from . import image as im

DISCLOSURES = ("none", "summary", "full")
PROPERTY_WORDS = {"P106": "occupation", "P69": "educated at", "P39": "position held", "P166": "award received",
                  "P800": "notable work", "P108": "employer", "P463": "member of"}
CH = ("red", "green", "blue")

PERSONAS = ("p023", "p012", "p019")  # researcher (over), carer (under), small business owner (well-calibrated)
ORG = "o005"
PUBLIC = "marie-curie"
TEAM = ("p023", "p019", "p033", "p008")
COMPARE = ("p012", "p023")


# ---------- context and specs ----------

def _cap(s):
    return s[:1].upper() + s[1:]


@lru_cache(maxsize=1)
def _events(root=bmod.ROOT):
    out = {}
    for name in ("events.jsonl.gz", "org_events.jsonl.gz"):
        with gzip.open(root / "data/synthetic" / name, "rt", encoding="utf-8") as f:
            for line in f:
                e = json.loads(line)
                out[e["id"]] = e.get("label") or e.get("phrase") or ""
    return out


def context(root=bmod.ROOT):
    """Everything a build reads: cards, the basemap, entities with their rows, fine domains, event labels, asof dates."""
    cards = bmod.load_cards(root / "data/coarse/seed_v2.jsonl")
    fine = {}
    for c in bmod.read_jsonl(root / "data/fine/fine_v0.jsonl"):
        for l in c["links"]:
            if l["rel"] == "upstream":
                fine.setdefault(l["id"], set()).add(c["label"])
    asof = {p["id"]: p["as_of"] for p in bmod.read_jsonl(root / "data/synthetic/personas.jsonl")}
    return {"cards": cards, "by": {c["id"]: c for c in cards}, "bm": bmod.build_v0(root),
            "ents": {e["id"]: e for e in im.load_entities(root)}, "fine": {k: sorted(v) for k, v in fine.items()},
            "asof": asof, "root": root}


def _focus(row, by):
    ms = [m for m in row["memberships"] if m["rel"] in ("form", "content")] or row["memberships"]
    return by[ms[0]["domain"]]["label"] if ms else "an unplaced domain"


def row_reason(row, by, events, trace=None):
    """One line saying what the row records. The generators keep no free text, so it is the event's own label where
    the row came from an event, the Wikidata statement for a public figure, else composed from what the row is."""
    span = row["provenance"]["span"]
    if trace is not None:
        return f'{_cap(PROPERTY_WORDS.get(trace["property"], trace["property"]))}: {trace["label"]}'
    if span.startswith("ev:") and events.get(span[3:]):
        return _cap(events[span[3:]])
    where = row["provenance"]["source"].split(":")[0].replace("-", " ")
    where += f", line {span[1:]}" if span[:1] == "L" and span[1:].isdigit() else f", {span}"
    if row["channel"] == "prediction":
        return f"Self-assessment or forecast in {_focus(row, by)} ({where})"
    kind = row.get("test_kind")
    verb = {"knowing": "Test of knowing", "doing": "Assessment of doing"}.get(kind) or (
        "Took in" if lv.production(row) == "consumed" else "Produced")
    return f"{verb} {_focus(row, by)} ({where})"


def _member(ctx, eid):
    e = ctx["ents"][eid]
    trace = None
    if e["kind"] == "public":
        trace = bmod.read_jsonl(ctx["root"] / f"data/public/{eid}.trace.jsonl")
    events = _events(ctx["root"])
    rows = [dict(r, reason=row_reason(r, ctx["by"], events, trace[i] if trace else None)) for i, r in enumerate(e["rows"])]
    name = e["label"] if e["kind"] != "person" else f'Persona {e["id"]} ({e["archetype"].replace("_", " ")})'
    return {"id": eid, "name": name, "rows": rows, "asof": ctx["asof"].get(eid) if e["kind"] == "person" else None}


def spec_single(ctx, eid):
    m = _member(ctx, eid)
    return {"kind": "single", "title": m["name"], "members": [m]}


def spec_group(ctx, ids, title):
    if not ids:
        raise ValueError("a group needs at least one member")
    return {"kind": "group", "title": title, "members": [_member(ctx, i) for i in ids]}


def spec_compare(ctx, a, b):
    ma, mb = _member(ctx, a), _member(ctx, b)
    return {"kind": "compare", "title": f'{ma["name"]} compared with {mb["name"]}', "members": [ma, mb]}


# ---------- levels, sets, contributions ----------

def sum_raw(raws):
    """Add members' untoned sums: {"solid": {d: {ch: s}}, "claimed": {...}, "tier_mass": {d: {tier: m}}}."""
    out = {"solid": {}, "claimed": {}, "tier_mass": {}}
    for r in raws:
        for layer in ("solid", "claimed"):
            for d, ch in r[layer].items():
                acc = out[layer].setdefault(d, dict.fromkeys(CH, 0.0))
                for k in CH:
                    acc[k] += ch[k]
        for d, tm in r["tier_mass"].items():
            acc = out["tier_mass"].setdefault(d, {})
            for t, m in tm.items():
                acc[t] = acc.get(t, 0.0) + m
    return out


def levels_from_raw(raw, governed=lv.DEFAULT):
    """The tone map applied once to (summed) luminosities: the saturating step of `levels.channel_levels`."""
    out = {"solid": {}, "claimed": {}}
    for layer in out:
        for d, row in raw[layer].items():
            out[layer][d] = {k: lv.tone(row[k], governed) for k in CH}
    for d, tm in raw["tier_mass"].items():
        total = math.fsum(tm.values())
        out["solid"][d]["saturation"] = math.fsum(governed.saturation(t) * m for t, m in tm.items()) / total if total > 0 else 1.0
    return out


def compare_levels(a, b):
    """{overlap, a_only, b_only}: per domain and channel min(A, B), max(A - B, 0), max(B - A, 0); saturation follows
    the side(s) that carry the colour."""
    out = {k: {"solid": {}, "claimed": {}} for k in ("overlap", "a_only", "b_only")}
    for layer, chans in (("solid", CH), ("claimed", ("red",))):
        for d in sorted(set(a[layer]) | set(b[layer])):
            x, y = a[layer].get(d, {}), b[layer].get(d, {})
            ov, ao, bo = {}, {}, {}
            for k in chans:
                u, v = x.get(k, 0.0), y.get(k, 0.0)
                ov[k], ao[k], bo[k] = min(u, v), max(u - v, 0.0), max(v - u, 0.0)
            if layer == "solid":
                sa, sb = x.get("saturation", 1.0), y.get("saturation", 1.0)
                ov["saturation"] = min(sa, sb) if x and y else sa if x else sb
                ao["saturation"], bo["saturation"] = sa, sb
            for name, v in (("overlap", ov), ("a_only", ao), ("b_only", bo)):
                if any(v[k] > 0 for k in chans):
                    out[name][layer][d] = v
    return out


def _ref(rows):
    live = [r for r in rows if not r["revoked"] and r["channel"] in ("positive", "prediction")]
    return max((lv.parse_time(r["valid_time"]) for r in live), default=None)


def analyse(ctx, member, governed=lv.DEFAULT):
    """One member's untoned sums, levels, and per-row single sums (rows that imprint nothing are left out)."""
    cards, rows = ctx["cards"], member["rows"]
    ref = member["asof"] or (_ref(rows).isoformat() if _ref(rows) else None)
    raw = lv.raw_sums(rows, cards, governed, member["asof"])
    singles = []
    for i, r in enumerate(rows):
        if r["revoked"] or r["channel"] not in ("positive", "prediction"):
            continue
        one = lv.raw_sums([r], cards, governed, ref)
        if one["solid"] or one["claimed"]:
            singles.append((i, one))
    return {"member": member, "raw": raw, "levels": levels_from_raw(raw, governed), "singles": singles}


def contributions(analyses, levels):
    """{(member index, row index): {domain: {red, green, blue, grain}}}: each domain-channel level split among the rows in
    proportion to their single-row sums (sums to the level)."""
    total = {}
    for a in analyses:
        for _, one in a["singles"]:
            for layer in ("solid", "claimed"):
                for d, ch in one[layer].items():
                    t = total.setdefault((layer, d), dict.fromkeys(CH, 0.0))
                    for k in CH:
                        t[k] += ch[k]
    out = {}
    for mi, a in enumerate(analyses):
        for ri, one in a["singles"]:
            per = out.setdefault((mi, ri), {})
            for layer in ("solid", "claimed"):
                for d, ch in one[layer].items():
                    for k in CH:
                        if ch[k] > 0 and total[(layer, d)][k] > 0:
                            key = k if layer == "solid" else "grain"
                            per.setdefault(d, {})[key] = levels[layer][d][k] * ch[k] / total[(layer, d)][k]
    return out


def _channels(row):
    names = []
    for layer, ch, _rels, _f in lv.route(row):
        names.append(ch if layer == "solid" else "red (grain)")
    return ", ".join(names)


# ---------- model ----------

def _sector_of(by, i, seen=()):
    c = by[i]
    if is_sector(c):
        return i
    for u, _w in sorted(((l["id"], l["weight"]) for l in c["links"] if l["rel"] == "upstream"), key=lambda x: (-x[1], x[0])):
        if u in by and u not in seen:
            if (s := _sector_of(by, u, seen + (i,))) is not None:
                return s
    return None


def _enc(levels, index):
    """{slice index: [red, green, blue, saturation, claimed red]} for slices with any colour."""
    out = {}
    for d, i in index.items():
        s, c = levels["solid"].get(d), levels["claimed"].get(d)
        v = [round(s[k], 4) if s else 0.0 for k in CH] + [round(s["saturation"], 4) if s else 1.0, round(c["red"], 4) if c else 0.0]
        if v[0] or v[1] or v[2] or v[4]:
            out[str(i)] = v
    return out


def build_model(spec, ctx, disclosure, governed=lv.DEFAULT):
    if disclosure not in DISCLOSURES:
        raise ValueError(f"disclosure must be one of {DISCLOSURES}, not {disclosure!r}")
    if not spec["members"]:
        raise ValueError("no members")
    bm, by = ctx["bm"], ctx["by"]
    ordered = sorted(bm.slices.values(), key=lambda s: (s.ring != "sector", s.start, s.id))
    index = {s.id: i for i, s in enumerate(ordered)}
    analyses = [analyse(ctx, m, governed) for m in spec["members"]]
    kind, full, named = spec["kind"], disclosure == "full", disclosure != "none"
    slices = []
    for s in ordered:
        d = {"r": 0 if s.ring == "sector" else 1, "a": round(s.start, 3), "w": round(s.width, 3), "i0": round(s.r0, 4), "i1": round(s.r1, 4)}
        if named:
            sec = _sector_of(by, s.id)
            d.update({"id": s.id, "l": by[s.id]["label"], "p": index[sec] if s.ring == "field" and sec is not None else -1})
        slices.append(d)
    levels = levels_from_raw(sum_raw([a["raw"] for a in analyses]), governed) if kind != "compare" else None
    if kind == "compare":
        a, b = analyses[0]["levels"], analyses[1]["levels"]
        sets = compare_levels(a, b)
        names = ("A", "B") if not named else (spec["members"][0]["name"], spec["members"][1]["name"])
        views = [{"id": "a", "name": names[0], "lv": _enc(a, index)}, {"id": "b", "name": names[1], "lv": _enc(b, index)},
                 {"id": "overlap", "name": "Overlap (min of both)", "lv": _enc(sets["overlap"], index)},
                 {"id": "a_only", "name": f"Only {names[0]} (A minus B)", "lv": _enc(sets["a_only"], index)},
                 {"id": "b_only", "name": f"Only {names[1]} (B minus A)", "lv": _enc(sets["b_only"], index)}]
    else:
        views = [{"id": "main", "name": spec["title"] if named else "Life image", "lv": _enc(levels, index)}]
    model = {"v": 1, "kind": kind, "disclosure": disclosure, "zoom": named, "basemap": bm.version,
             "title": spec["title"] if named else "Life Image: pattern only", "slices": slices, "views": views,
             "tone_k": governed.tone_k, "sat": [governed.saturation(t) for t in ("measured", "attested", "claimed")]}
    if kind == "group" and named:
        model["members"] = [{"name": a["member"]["name"], "raw": {
            str(index[d]): [round(a["raw"]["solid"].get(d, {}).get(k, 0.0), 6) for k in CH]
            + [round(a["raw"]["claimed"].get(d, {}).get("red", 0.0), 6)]
            + [round(a["raw"]["tier_mass"].get(d, {}).get(t, 0.0), 6) for t in ("measured", "attested", "claimed")]
            for d in sorted(set(a["raw"]["solid"]) | set(a["raw"]["claimed"]), key=index.get)}} for a in analyses]
    if named:
        model["fine"] = {str(index[d]): v for d, v in sorted(ctx["fine"].items()) if d in index and slices[index[d]]["r"] == 1}
    if full:
        # rows are reported against the (whole) image: the group's levels, or one entity's
        lev = levels if levels else analyses[0]["levels"]
        contrib = contributions(analyses, lev) if levels else contributions(analyses[:1], lev)
        rows = {}
        for mi, a in enumerate(analyses if levels else analyses[:1]):
            for ri, _one in a["singles"]:
                r = a["member"]["rows"][ri]
                direct = {m["domain"] for m in r["memberships"]}
                for d, v in contrib[(mi, ri)].items():
                    if slices[index[d]]["r"] != 1:
                        continue
                    item = {"t": r["reason"], "k": r["tier"], "d": r["valid_time"], "c": _channels(r),
                            "v": {k: round(x, 4) for k, x in sorted(v.items())},
                            "s": f'{r["provenance"]["source"]} {r["provenance"]["span"]}', "q": r["confidence"]}
                    if d not in direct:
                        item["b"] = 1
                    if kind == "group":
                        item["m"] = mi
                    rows.setdefault(str(index[d]), []).append(item)
        for lst in rows.values():
            lst.sort(key=lambda x: (-math.fsum(x["v"].values()), x["d"], x["t"], x["s"]))
        model["rows"] = rows
    return model


def zoom_path(model, idx):
    """The steps from the disc to a single row for the field at slice index `idx`: depth 0 disc, 1 sector, 2 field,
    3 evidence (when rows are disclosed), 4 the first (largest) row."""
    if not model["zoom"]:
        raise ValueError("no zoom at disclosure none")
    f = model["slices"][int(idx)]
    path = [{"depth": 0}, {"depth": 1, "slice": model["slices"][f["p"]] if f["p"] >= 0 else None}, {"depth": 2, "slice": f}]
    rows = model.get("rows", {}).get(str(idx))
    if rows:
        path += [{"depth": 3, "rows": rows}, {"depth": 4, "row": rows[0]}]
    return path


# ---------- page ----------

def _json(obj):
    s = json.dumps(obj, sort_keys=True, separators=(",", ":"))
    return s.replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")


def build_viewer(spec, ctx, disclosure):
    m = build_model(spec, ctx, disclosure)
    zoom = m["zoom"]
    title = escape(m["title"])
    toolbar = '<div id="toolbar" role="group" aria-label="Views"></div>' if (m["kind"] != "single" and (zoom or m["kind"] == "compare")) else ""
    panel = '<aside id="panel" aria-label="Detail" aria-live="polite"></aside>' if zoom else ""
    note = {"none": "Disclosure: none. Pattern only: no labels and no zoom.",
            "summary": "Disclosure: summary. Labels and levels per domain; zoom reaches the field.",
            "full": "Disclosure: full. Zoom reaches single evidence rows."}[disclosure]
    keys = ("Wheel or pinch to zoom, drag to pan. Keys: arrows (left and right move between neighbours, down goes in, up or "
            "Escape comes out), + and - zoom, Shift with arrows pans, 0 resets.") if zoom else ""
    return (f'<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{title}</title><style>{CSS}{PANEL_CSS if zoom else ""}</style></head><body>'
            f'<header><h1>{title}</h1><p class="note">{escape(note)} Basemap {escape(m["basemap"])}. {escape(keys)}</p></header>'
            f'{toolbar}<main id="app"><div id="stagewrap"><svg id="stage" viewBox="-1.25 -1.25 2.5 2.5" role="img" '
            f'aria-label="Life image" {"tabindex=0" if zoom else ""}></svg></div>{panel}</main>'
            f'<footer>{LEGEND}</footer><noscript><p>This viewer needs JavaScript.</p></noscript>'
            f'<script id="data" type="application/json">{_json(m)}</script>'
            f'<script>{CORE_JS}{INTERACT_JS if zoom else ""}{SELFTEST_JS if zoom else SELFTEST_BASE_JS}</script></body></html>\n')


# ---------- outputs ----------

def _slug(s):
    return s.lower().replace(" ", "-")


def specs(ctx):
    """[(file name, spec, disclosure, one-line description)] in index order."""
    out = []
    for pid in PERSONAS:
        e = ctx["ents"][pid]
        out.append((f"persona-{pid}-full.html", spec_single(ctx, pid), "full", f'Synthetic persona {pid}: {e["archetype"].replace("_", " ")}, calibration {e["calibration"]}'))
    out.append((f"org-{ORG}-full.html", spec_single(ctx, ORG), "full", f'Synthetic organisation: {ctx["ents"][ORG]["label"]} ({ctx["ents"][ORG]["archetype"].replace("_", " ")})'))
    out.append((f"public-{PUBLIC}-full.html", spec_single(ctx, PUBLIC), "full", f'Public figure: {ctx["ents"][PUBLIC]["label"]} (Wikidata)'))
    out.append((f"persona-{PERSONAS[0]}-summary.html", spec_single(ctx, PERSONAS[0]), "summary", f"The same persona {PERSONAS[0]} at summary: labels and levels, no rows"))
    out.append((f"persona-{PERSONAS[0]}-none.html", spec_single(ctx, PERSONAS[0]), "none", f"The same persona {PERSONAS[0]} at none: pattern only"))
    out.append(("group-team.html", spec_group(ctx, TEAM, "Team of four"), "summary",
                "A team of four personas as the re-saturated sum of their imprints; members can be switched off"))
    out.append(("compare.html", spec_compare(ctx, *COMPARE), "summary", f"Overlap and difference of personas {COMPARE[0]} and {COMPARE[1]}"))
    return out


def index_html(items):
    rows = "".join(f'<tr><td><a href="{escape(n)}">{escape(n)}</a></td><td>{escape(d)}</td><td>{escape(desc)}</td></tr>'
                   for n, d, desc in items)
    return (f'<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>Life Image viewers</title><style>{CSS}table{{border-collapse:collapse}}td,th{{padding:.3rem .8rem .3rem 0;text-align:left;'
            f'vertical-align:top}}</style></head><body><header><h1>Life Image: interactive viewers</h1>'
            f'<p class="note">Each file is self-contained and works offline. Disclosure is fixed when a file is built: <b>none</b> carries the '
            f'pattern only (no labels, no zoom), <b>summary</b> adds labels and levels per domain, <b>full</b> adds the evidence rows. '
            f'Entities are synthetic personas and organisations and a deceased public figure.</p></header><main><table>'
            f'<tr><th>file</th><th>disclosure</th><th>what</th></tr>{rows}</table></main><footer>{LEGEND}</footer></body></html>\n')


def build_all(ctx):
    """{file name: text} for every viewer and the index."""
    out, items = {}, []
    for name, spec, disclosure, desc in specs(ctx):
        out[name] = build_viewer(spec, ctx, disclosure)
        items.append((name, disclosure, desc))
    out["index.html"] = index_html(items)
    return dict(sorted(out.items()))


LEGEND = ('<p class="legend"><span class="sw" style="background:#f00"></span>red knowledge and potential '
          '<span class="sw" style="background:#0f0"></span>green demonstrated skill '
          '<span class="sw" style="background:#00f"></span>blue impact; grain is claimed potential; paler is self-reported; '
          'brightness is a level in [0, 1] and levels of a group re-saturate rather than exceed 1. '
          'The image judges estimation and the use of expertise, not worth.</p>')

CSS = """:root{--bg:#0b0b0c;--fg:#e4e4e6;--mute:#9a9aa2;--line:#2a2a30;--card:#141417;--acc:#8ab4ff}
@media (prefers-color-scheme:light){:root{--bg:#f4f4f6;--fg:#17171a;--mute:#5a5a64;--line:#cfcfd6;--card:#fff;--acc:#1a4fd0}}
*{box-sizing:border-box}body{margin:0;padding:0 16px 24px;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,sans-serif}
h1{font-size:1.25rem;margin:.8rem 0 .2rem}.note,.legend{color:var(--mute);font-size:.85rem;margin:.2rem 0}a{color:var(--acc)}
.sw{display:inline-block;width:.9em;height:.9em;vertical-align:-.1em;margin:0 .3em 0 .6em}
#app{display:grid;grid-template-columns:minmax(0,1fr);gap:16px;align-items:start}
#stagewrap{background:#000;border:1px solid var(--line);border-radius:6px;overflow:hidden;touch-action:none;max-width:min(100%,86vh);margin:0 auto;width:100%}
#stage{display:block;width:100%;height:auto;aspect-ratio:1;cursor:default;outline:none}#stage:focus-visible{outline:2px solid var(--acc);outline-offset:-2px}
#stage text{font-family:system-ui,sans-serif;fill:#e8e8ea;pointer-events:none;paint-order:stroke;stroke:#000;stroke-linejoin:round}
#toolbar{margin:.5rem 0;display:flex;flex-wrap:wrap;gap:.4rem 1rem}#toolbar label{display:inline-flex;gap:.35rem;align-items:center}
"""

PANEL_CSS = """#app{grid-template-columns:minmax(0,1fr) minmax(16rem,23rem)}#stage{cursor:grab}#stage.drag{cursor:grabbing}
@media (max-width:820px){#app{grid-template-columns:minmax(0,1fr)}}
#panel{background:var(--card);border:1px solid var(--line);border-radius:6px;padding:.7rem .8rem;max-height:86vh;overflow:auto}
#panel h2{font-size:1.05rem;margin:.2rem 0 .4rem}#panel nav{display:flex;flex-wrap:wrap;gap:.3rem;margin-bottom:.5rem}
#panel button{font:inherit;color:var(--fg);background:transparent;border:1px solid var(--line);border-radius:4px;padding:.2rem .5rem;cursor:pointer;text-align:left}
#panel button:hover,#panel button:focus-visible{border-color:var(--acc);outline:none}#panel button[aria-current=true]{border-color:var(--acc)}
#panel ul{list-style:none;margin:.3rem 0;padding:0;display:grid;gap:.25rem}#panel li button{width:100%}
.bar{display:grid;grid-template-columns:4.2rem 1fr 3rem;gap:.4rem;align-items:center;font-size:.82rem;margin:.1rem 0}
.bar i{display:block;height:.55rem;background:var(--line);border-radius:3px;overflow:hidden}.bar b{display:block;height:100%}
.bar span:last-child{text-align:right;color:var(--mute)}.sub{color:var(--mute);font-size:.8rem}
#panel dl{display:grid;grid-template-columns:6rem 1fr;gap:.2rem .6rem;margin:.4rem 0}#panel dt{color:var(--mute)}#panel dd{margin:0;overflow-wrap:anywhere}
"""

CORE_JS = r"""
window.__errs=[];window.addEventListener('error',function(e){window.__errs.push(String(e.message))});
(function(){'use strict';
var M=JSON.parse(document.getElementById('data').textContent),NS='http://www.w3.org/2000/svg',S=M.slices,N=S.length;
var LAB=M.disclosure!=='none',ROWS=M.disclosure==='full',ZOOM=M.zoom,svg=document.getElementById('stage');
function se(tag,at,par){var e=document.createElementNS(NS,tag);for(var k in at)e.setAttribute(k,at[k]);if(par)par.appendChild(e);return e}
function pt(r,a){a=a*Math.PI/180;return (r*Math.cos(a)).toFixed(4)+' '+(-r*Math.sin(a)).toFixed(4)}
function wedge(s){var a0=s.a,a1=s.a+s.w,big=s.w>180?1:0;
 return 'M'+pt(s.i1,a0)+'A'+s.i1+' '+s.i1+' 0 '+big+' 0 '+pt(s.i1,a1)+'L'+pt(s.i0,a1)+'A'+s.i0+' '+s.i0+' 0 '+big+' 1 '+pt(s.i0,a0)+'Z'}
function rgb(v){var c=[v[0],v[1],v[2]],t=v[3];if(t!==1){var g=(c[0]+c[1]+c[2])/3;c=c.map(function(x){return g+t*(x-g)})}
 return 'rgb('+c.map(function(x){return Math.round(255*Math.min(1,Math.max(0,x)))}).join(',')+')'}
var defs=se('defs',{},svg);
var pat=se('pattern',{id:'dots',width:.014,height:.014,patternUnits:'userSpaceOnUse'},defs);
se('rect',{width:.014,height:.014,fill:'#000'},pat);var dot=se('rect',{width:.006,height:.006,fill:'#fff'},pat);
var mask=se('mask',{id:'grain',maskUnits:'userSpaceOnUse',x:-1.25,y:-1.25,width:2.5,height:2.5},defs),mrect=se('rect',{x:-1.25,y:-1.25,width:2.5,height:2.5,fill:'url(#dots)'},mask);
se('rect',{x:-1.25,y:-1.25,width:2.5,height:2.5,fill:'#000'},svg);
var cam=se('g',{id:'cam'},svg),gW=se('g',{id:'wedges'},cam),gC=se('g',{id:'claimed',mask:'url(#grain)',style:'mix-blend-mode:screen'},cam),
 gG=se('g',{id:'guides',fill:'none',stroke:'#202024','stroke-width':1.2,'vector-effect':'non-scaling-stroke'},cam),
 gS=se('g',{id:'sel'},cam),gT=se('g',{id:'ticks'},cam),gL=se('g',{id:'labels'},cam);
var W=[],C=[];
S.forEach(function(s,i){var d=wedge(s);
 W[i]=se('path',{d:d,fill:'#000'},gW);C[i]=se('path',{d:d,fill:'#000',display:'none'},gC);
 se('path',{d:d,'vector-effect':'non-scaling-stroke'},gG)});
var view=0,groupSel=null,LV=M.views[0].lv;
function groupLv(sel){var out={},acc={};
 M.members.forEach(function(m,j){if(!sel[j])return;for(var i in m.raw){var a=acc[i]||(acc[i]=[0,0,0,0,0,0,0]),v=m.raw[i];for(var q=0;q<7;q++)a[q]+=v[q]}});
 for(var i in acc){var a=acc[i],k=M.tone_k,t=function(x){return 1-Math.exp(-x/k)},m=a[4]+a[5]+a[6],
  sat=m>0?(M.sat[0]*a[4]+M.sat[1]*a[5]+M.sat[2]*a[6])/m:1,v=[t(a[0]),t(a[1]),t(a[2]),sat,t(a[3])];
  if(v[0]||v[1]||v[2]||v[4])out[i]=v}return out}
function paint(){for(var i=0;i<N;i++){var v=LV[i];
  W[i].setAttribute('fill',v&&(v[0]||v[1]||v[2])?rgb(v):'#000');
  if(v&&v[4]){C[i].setAttribute('fill',rgb([v[4],0,0,1]));C[i].removeAttribute('display')}else C[i].setAttribute('display','none')}}
function setLv(lv){LV=lv;paint();if(window.__redraw)window.__redraw()}
function setView(j){view=j;setLv(M.views[j].lv)}
function setMembers(sel){groupSel=sel;setLv(groupLv(sel))}
paint();
window.__li={mask:mask,mrect:mrect,M:M,S:S,N:N,W:W,svg:svg,cam:cam,gL:gL,gT:gT,gS:gS,pat:pat,dot:dot,se:se,pt:pt,wedge:wedge,rgb:rgb,
 get lv(){return LV},setView:setView,setMembers:setMembers,groupLv:groupLv,setLv:setLv,labelsOn:LAB,rowsOn:ROWS,zoomOn:ZOOM};
var tb=document.getElementById('toolbar');
if(tb&&M.kind==='compare'){M.views.forEach(function(v,j){var l=document.createElement('label'),r=document.createElement('input');
 r.type='radio';r.name='view';r.value=v.id;r.checked=j===0;r.addEventListener('change',function(){setView(j)});
 l.appendChild(r);l.appendChild(document.createTextNode(v.name));tb.appendChild(l)})}
if(tb&&M.kind==='group'&&M.members){groupSel=M.members.map(function(){return true});
 M.members.forEach(function(m,j){var l=document.createElement('label'),c=document.createElement('input');
 c.type='checkbox';c.checked=true;c.addEventListener('change',function(){groupSel[j]=c.checked;setMembers(groupSel)});
 l.appendChild(c);l.appendChild(document.createTextNode(m.name));tb.appendChild(l)})}
})();
"""

INTERACT_JS = r"""
(function(){'use strict';
var L=window.__li,M=L.M,S=L.S,N=L.N,se=L.se,svg=L.svg,camg=L.cam,gL=L.gL,gT=L.gT,gS=L.gS,ROWS=L.rowsOn,TAU=Math.PI/180;
var panel=document.getElementById('panel'),stage=svg,cam={s:1,x:0,y:0},st={sec:null,field:null,rows:false,row:null},msel=null;
var SORT='contribution',SMIN=1,SMAX=40,timer=null,raf=0;
function kpx(){var r=svg.getBoundingClientRect();return Math.min(r.width,r.height)/2.5||240}
function rmid(s){return (s.i0+s.i1)/2}
function ctr(s){var a=(s.a+s.w/2)*TAU,r=rmid(s);return [r*Math.cos(a),-r*Math.sin(a)]}
function bbox(s){var xs=[],ys=[];for(var q=0;q<=8;q++){var a=(s.a+s.w*q/8)*TAU;[s.i0,s.i1].forEach(function(r){xs.push(r*Math.cos(a));ys.push(-r*Math.sin(a))})}
 return [Math.min.apply(0,xs),Math.max.apply(0,xs),Math.min.apply(0,ys),Math.max.apply(0,ys)]}
function lvl(i){return L.lv[i]||null}
function tot(i){var v=lvl(i);return v?v[0]+v[1]+v[2]+v[4]:0}
function byAngle(list){return list.slice().sort(function(a,b){return S[a].a-S[b].a||a-b})}
function sectors(){var o=[];S.forEach(function(s,i){if(s.r===0)o.push(i)});return byAngle(o)}
function kids(sec){var o=[];S.forEach(function(s,i){if(s.r===1&&s.p===sec)o.push(i)});return byAngle(o)}
function rowsOf(f){var r=(M.rows&&M.rows[f])||[];return r.map(function(x,i){x._i=i;return x}).filter(function(x){return !msel||x.m===undefined||msel[x.m]})}
function sortedRows(f){var r=rowsOf(f).slice();if(SORT==='date')r.sort(function(a,b){return a.d<b.d?1:a.d>b.d?-1:a._i-b._i});return r}
function depth(){return st.sec===null?0:st.field===null?1:!st.rows?2:st.row===null?3:4}
function applyCam(){var s=cam.s,w=2.5/s;svg.setAttribute('viewBox',(cam.x-w/2).toFixed(5)+' '+(cam.y-w/2).toFixed(5)+' '+w.toFixed(5)+' '+w.toFixed(5));
 L.pat.setAttribute('width',.014/s);L.pat.setAttribute('height',.014/s);L.dot.setAttribute('width',.006/s);L.dot.setAttribute('height',.006/s);
 [L.mask,L.mrect].forEach(function(e){e.setAttribute('x',(cam.x-w/2).toFixed(5));e.setAttribute('y',(cam.y-w/2).toFixed(5));e.setAttribute('width',w.toFixed(5));e.setAttribute('height',w.toFixed(5))});redraw()}
function clampCam(c){c.s=Math.min(SMAX,Math.max(SMIN,c.s));c.x=Math.min(1.2,Math.max(-1.2,c.x));c.y=Math.min(1.2,Math.max(-1.2,c.y))}
var tid=0;
function setCam(s,x,y,animate){var t={s:s,x:x,y:y};clampCam(t);
 if(!animate||window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches){tid++;cam=t;applyCam();return}
 var from={s:cam.s,x:cam.x,y:cam.y},t0=null,my=++tid;var tween=function(now){if(my!==tid)return;if(t0===null)t0=now;var u=Math.min(1,(now-t0)/240),e=u*u*(3-2*u);
  cam={s:from.s*Math.pow(t.s/from.s,e),x:from.x+(t.x-from.x)*e,y:from.y+(t.y-from.y)*e};applyCam();draw();if(u<1)requestAnimationFrame(tween)};
 requestAnimationFrame(tween)}
function fit(b,pad){var w=Math.max(b[1]-b[0],1e-3),h=Math.max(b[3]-b[2],1e-3);return Math.min(SMAX,Math.max(SMIN,pad*2.5/Math.max(w,h)))}
function rowPos(f){var rs=rowsOf(f).slice().sort(function(a,b){return a.d<b.d?-1:a.d>b.d?1:a._i-b._i}),s=S[f],n=rs.length,a=(s.a+s.w/2)*TAU,out=[];
 rs.forEach(function(r,j){var rad=s.i0+(s.i1-s.i0)*(0.04+0.92*(n>1?j/(n-1):.5));out.push({row:r,x:rad*Math.cos(a),y:-rad*Math.sin(a),rad:rad})});return out}
function camFor(){var d=depth();
 if(d===0)return [1,0,0];
 if(d===1){if(st.sec<0)return [1,0,0];var c=ctr(S[st.sec]),a=(S[st.sec].a+S[st.sec].w/2)*TAU;return [2.2,.55*Math.cos(a)*.6+c[0]*.4,-.55*Math.sin(a)*.6+c[1]*.4]}
 var f=S[st.field];if(d===2){var b=bbox(f),c=ctr(f);return [fit(b,.8),c[0],c[1]]}
 var ps=rowPos(st.field);if(d===3||st.row===null){var c=ctr(f);return [18,c[0],c[1]]}
 var hit=ps.filter(function(p){return p.row._i===st.row})[0];return hit?[26,hit.x,hit.y]:[18,ctr(f)[0],ctr(f)[1]]}
function go(next,quiet){st=next;var c=camFor();setCam(c[0],c[1],c[2],true);render();if(!quiet)announce()}
function announce(){var d=depth(),t=d===0?M.title:d===1?(st.sec>=0?S[st.sec].l:'Other fields'):S[st.field].l;
 var e=document.getElementById('live');if(!e){e=document.createElement('div');e.id='live';e.setAttribute('aria-live','polite');e.style.cssText='position:absolute;left:-9999px';document.body.appendChild(e)}
 e.textContent=['Whole disc','Sector','Field','Evidence','Row'][d]+': '+t}
// ---- drawing: selection, dimming, labels, ticks
function render(){var d=depth(),sel=d>=2?st.field:d===1?st.sec:-1;
 for(var i=0;i<N;i++){var s=S[i],on=true;
  if(d>=2)on=i===st.field||i===st.sec;else if(d===1)on=i===st.sec||(s.r===1&&s.p===st.sec);
  L.W[i].setAttribute('opacity',on?1:.3)}
 gS.textContent='';if(sel>=0)se('path',{d:L.wedge(S[sel]),fill:'none',stroke:'#fff','stroke-width':2,'vector-effect':'non-scaling-stroke'},gS);
 redraw();panelRender()}
function fmt(n){return n.toFixed(2)}
function redraw(){if(raf)return;raf=requestAnimationFrame(function(){raf=0;draw()})}
function draw(){var s=cam.s,k=kpx(),ks=k*s,vw=svg.getBoundingClientRect().width/2/ks+.1;gL.textContent='';gT.textContent='';
 var fs=10.5/ks,d=depth();
 S.forEach(function(sl,i){var arc=sl.w*TAU*rmid(sl)*ks,mid=ctr(sl),forced=(d>=1&&(i===st.sec||i===st.field));
  if(!forced&&arc<12)return;if(Math.abs(mid[0]-cam.x)>vw+.3||Math.abs(mid[1]-cam.y)>vw+.3)return;
  var avail=(sl.i1-sl.i0)*ks,v=lvl(i),txt=sl.l+(forced&&v&&arc>=12?' '+fmt(Math.max(v[0],v[1],v[2])):'');
  var maxc=Math.floor(avail/(10.5*.56));if(txt.length>maxc)txt=txt.slice(0,Math.max(3,maxc-1))+'…';
  var a=(sl.a+sl.w/2),flip=Math.cos(a*TAU)<0,t=se('text',{x:mid[0],y:mid[1],'font-size':fs,'text-anchor':'middle','dominant-baseline':'central','stroke-width':fs*.3,
   transform:'rotate('+(-a+(flip?180:0))+' '+mid[0]+' '+mid[1]+')'},gL);t.textContent=txt;if(forced)t.setAttribute('font-weight','700')});
 if(d>=3&&st.field!==null){var ps=rowPos(st.field);
  ps.forEach(function(p,j){var c=dominant(p.row),on=p.row._i===st.row,space=Math.min(j?(p.rad-ps[j-1].rad)*ks:99,j<ps.length-1?(ps[j+1].rad-p.rad)*ks:99);
   se('circle',{cx:p.x,cy:p.y,r:(on?7:4.5)/ks,fill:c,stroke:on?'#fff':'#000','stroke-width':1.4/ks},gT);
   if(space>=13||on){var t=se('text',{x:p.x+10/ks,y:p.y,'font-size':fs,'stroke-width':fs*.3,'dominant-baseline':'central'},gT);var u=p.row.t;t.textContent=u.length>48?u.slice(0,47)+'…':u}})}}
window.__redraw=redraw;
function dominant(r){var best='grain',v=0;for(var k in r.v)if(r.v[k]>v){v=r.v[k];best=k}
 return {red:'#ff5a5a',green:'#4be06a',blue:'#5a8cff',grain:'#ff9a9a'}[best]}
// ---- state transitions
function best(list){var b=null,m=-1;list.forEach(function(i){var t=tot(i);if(t>m){m=t;b=i}});return b}
function bestSector(){var all=sectors(),withKid=all.filter(function(s){return kids(s).some(function(f){return tot(f)>0})});return best(withKid.length?withKid:all)}
function down(){var d=depth();
 if(d===0){var s=bestSector();if(s===null){var f=best(S.map(function(x,i){return i}).filter(function(i){return S[i].r===1}));if(f===null)return;go({sec:S[f].p,field:null,rows:false,row:null});return}go({sec:s,field:null,rows:false,row:null})}
 else if(d===1){var ks=kids(st.sec);var f=ks.length?best(ks.filter(function(i){return tot(i)>0}).concat(ks.filter(function(i){return !tot(i)}))):null;
  if(f===null||(tot(f)===0&&ks.some(function(i){return tot(i)>0})))f=best(ks);if(f!==null)go({sec:st.sec,field:f,rows:false,row:null})}
 else if(d===2){if(ROWS&&rowsOf(st.field).length)go({sec:st.sec,field:st.field,rows:true,row:null});else announceText(ROWS?'No evidence rows for this field':'Rows are not disclosed in this file')}
 else if(d===3){var r=sortedRows(st.field);if(r.length)go({sec:st.sec,field:st.field,rows:true,row:r[0]._i})}}
function up(){var d=depth();if(d===0)return;
 if(d===1)go({sec:null,field:null,rows:false,row:null});else if(d===2)go({sec:st.sec,field:null,rows:false,row:null});
 else if(d===3)go({sec:st.sec,field:st.field,rows:false,row:null});else go({sec:st.sec,field:st.field,rows:true,row:null})}
function step(dir){var d=depth();
 if(d===0){var all=sectors();if(all.length)go({sec:dir>0?all[0]:all[all.length-1],field:null,rows:false,row:null});return}
 if(d===1||d===2){var list=d===1?sectors():kids(st.sec),cur=d===1?st.sec:st.field,j=list.indexOf(cur);if(!list.length)return;
  var n=list[(j+dir+list.length)%list.length];go(d===1?{sec:n,field:null,rows:false,row:null}:{sec:st.sec,field:n,rows:false,row:null});return}
 var r=sortedRows(st.field);if(!r.length)return;var pos=d===3?(dir>0?0:r.length-1):r.findIndex(function(x){return x._i===st.row})+dir;
 pos=Math.min(r.length-1,Math.max(0,pos));go({sec:st.sec,field:st.field,rows:true,row:r[pos]._i})}
function announceText(t){var e=document.getElementById('live');if(e)e.textContent=t}
function select(i){var s=S[i];if(s.r===0){go({sec:i,field:null,rows:false,row:null})}
 else if(st.field===i&&!st.rows&&ROWS&&rowsOf(i).length)go({sec:s.p,field:i,rows:true,row:null});else go({sec:s.p,field:i,rows:false,row:null})}
function selectRow(f,idx){go({sec:S[f].p,field:f,rows:true,row:idx})}
// ---- panel
function h(tag,par,text,at){var e=document.createElement(tag);if(text!==undefined)e.textContent=text;for(var k in at||{})e.setAttribute(k,at[k]);if(par)par.appendChild(e);return e}
function btn(par,text,fn,cur){var li=par.tagName==='UL'?h('li',par):par,b=h('button',li,text,{type:'button'});if(cur)b.setAttribute('aria-current','true');b.addEventListener('click',fn);return b}
function bars(par,v){var names=[['red','#ff4040',0],['green','#30d050',1],['blue','#4070ff',2],['claimed','#ff9a9a',4]];
 names.forEach(function(n){var val=v?v[n[2]]:0,b=h('div',par,undefined,{'class':'bar'});h('span',b,n[0]);var i=h('i',b),f=h('b',i);f.style.width=Math.round(100*val)+'%';f.style.background=n[1];h('span',b,fmt(val))});
 if(v&&(v[0]||v[1]||v[2])){h('div',par,'colour kept '+Math.round(100*v[3])+'% (paler where the evidence is self-reported)',{'class':'sub'})}}
function crumbs(par){var n=h('nav',par,undefined,{'aria-label':'Zoom path'}),d=depth();
 btn(n,'Whole disc',function(){go({sec:null,field:null,rows:false,row:null})},d===0);
 if(d>=1)btn(n,st.sec>=0?S[st.sec].l:'Other fields',function(){go({sec:st.sec,field:null,rows:false,row:null})},d===1);
 if(d>=2)btn(n,S[st.field].l,function(){go({sec:st.sec,field:st.field,rows:false,row:null})},d===2);
 if(d>=3)btn(n,'Evidence',function(){go({sec:st.sec,field:st.field,rows:true,row:null})},d===3);
 if(d>=4)btn(n,'Row',function(){},true)}
function panelRender(){var p=panel,d=depth();p.textContent='';crumbs(p);
 if(d===0){h('h2',p,M.title);h('p',p,'Sectors by total level. Select one, or zoom the image.',{'class':'sub'});
  var ul=h('ul',p);sectors().sort(function(a,b){return tot(b)-tot(a)}).forEach(function(i){btn(ul,S[i].l+'  '+fmt(Math.max.apply(0,(lvl(i)||[0]).slice(0,3))),function(){select(i)})})}
 else if(d===1){h('h2',p,st.sec>=0?S[st.sec].l:'Other fields');if(st.sec>=0)bars(p,lvl(st.sec));h('h3',p,'Fields',{'class':'sub'});
  var ul=h('ul',p);kids(st.sec).sort(function(a,b){return tot(b)-tot(a)}).forEach(function(i){btn(ul,S[i].l+'  '+fmt(Math.max.apply(0,(lvl(i)||[0]).slice(0,3))),function(){select(i)})})}
 else if(d===2){var f=S[st.field];h('h2',p,f.l);bars(p,lvl(st.field));var fn=(M.fine&&M.fine[st.field])||[];
  h('h3',p,'Fine domains ('+fn.length+')',{'class':'sub'});
  if(fn.length){var ul=h('ul',p);fn.forEach(function(t){h('li',ul,t)});h('p',p,'Evidence rows are placed at the field; fine domains carry no rows of their own yet.',{'class':'sub'})}
  var n=rowsOf(st.field).length;
  if(ROWS){if(n)btn(p,'Evidence rows ('+n+')',function(){select(st.field)});else h('p',p,'No evidence rows imprint this field.',{'class':'sub'})}
  else h('p',p,'Row detail is not disclosed in this file.',{'class':'sub'})}
 else{var f=S[st.field],rs=sortedRows(st.field);h('h2',p,f.l+': evidence ('+rs.length+')');
  var o=h('div',p),sb=h('button',o,'Sorted by '+(SORT==='contribution'?'contribution':'date')+' (switch)',{type:'button'});
  sb.addEventListener('click',function(){SORT=SORT==='contribution'?'date':'contribution';panelRender()});
  if(d===4){rowDetail(p,rs.filter(function(r){return r._i===st.row})[0])}
  var ul=h('ul',p);rs.forEach(function(r){var tot_=0;for(var k in r.v)tot_+=r.v[k];
   btn(ul,r.t+'  · '+r.k+' · '+r.d+' · '+r.c+' · +'+tot_.toFixed(3),function(){selectRow(st.field,r._i)},r._i===st.row)})}}
function rowDetail(p,r){if(!r)return;var c=h('section',p,undefined,{id:'rowdetail','aria-label':'Evidence row'});var dl=h('dl',c);
 function kv(a,b){h('dt',dl,a);h('dd',dl,b)}
 kv('Reason',r.t);kv('Tier',r.k+(r.k==='claimed'?' (self-reported, drawn pale)':''));kv('Date',r.d);kv('Channel',r.c);
 var parts=[];for(var k in r.v)parts.push(k+' +'+r.v[k].toFixed(4));kv('Contribution to the level',parts.join(', ')+(r.b?' (bled from a neighbouring domain)':''));
 kv('Source',r.s);kv('Confidence',String(r.q));if(r.m!==undefined)kv('Member',M.members?M.members[r.m].name:String(r.m))}
// ---- gestures
function toModel(cx,cy){var r=svg.getBoundingClientRect(),ks=kpx()*cam.s;return [cam.x+(cx-r.left-r.width/2)/ks,cam.y+(cy-r.top-r.height/2)/ks]}
function zoomAt(f,cx,cy){var p=toModel(cx,cy),s=Math.min(SMAX,Math.max(SMIN,cam.s*f)),r=svg.getBoundingClientRect(),ks=kpx()*s;
 cam={s:s,x:p[0]-(cx-r.left-r.width/2)/ks,y:p[1]-(cy-r.top-r.height/2)/ks};clampCam(cam);tid++;applyCam();later()}
function later(){clearTimeout(timer);timer=setTimeout(syncFromCam,160)}
function hitSlice(x,y){var r=Math.hypot(x,y),a=(Math.atan2(-y,x)/TAU+360)%360,out=-1;
 S.forEach(function(s,i){if(r>=s.i0&&r<=s.i1){var d=(a-s.a+360)%360;if(d<=s.w)out=i}});return out}
function syncFromCam(){var s=cam.s,want=s>=1.6?1:0;if(s>=3.2)want=2;if(s>=12&&ROWS)want=3;
 if(want===0){if(depth()!==0){st={sec:null,field:null,rows:false,row:null};render()}return}
 var h_=hitSlice(cam.x,cam.y),n={sec:st.sec,field:st.field,rows:st.rows,row:st.row};
 if(h_>=0){var sl=S[h_];if(sl.r===0)n={sec:h_,field:want>=2&&st.sec===h_?st.field:null,rows:false,row:null};
  else{n.sec=sl.p;if(want>=2)n.field=h_;else n.field=null}}
 if(want<2){n.field=null;n.rows=false;n.row=null}if(want<3){n.rows=false;n.row=null}
 if(want>=3&&n.field!==null&&rowsOf(n.field).length){n.rows=true}else if(want>=3)n.rows=false;
 if(n.sec===null&&want>=1)return;
 if(n.sec!==st.sec||n.field!==st.field||n.rows!==st.rows){st=n;render()}}
var ptrs={},drag=null,pinch=null;
function rowTickAt(cx,cy){if(depth()<3||st.field===null)return null;var r=svg.getBoundingClientRect(),ks=kpx()*cam.s,best=null,bd=1e9;
 rowPos(st.field).forEach(function(p){var dx=(p.x-cam.x)*ks+r.width/2+r.left-cx,dy=(p.y-cam.y)*ks+r.height/2+r.top-cy,d=Math.hypot(dx,dy);if(d<bd&&d<12){bd=d;best=p}});return best}
stage.addEventListener('wheel',function(e){e.preventDefault();var f=Math.exp(-e.deltaY*(e.ctrlKey?.01:.0016));zoomAt(f,e.clientX,e.clientY)},{passive:false});
stage.addEventListener('pointerdown',function(e){ptrs[e.pointerId]={x:e.clientX,y:e.clientY};try{stage.setPointerCapture(e.pointerId)}catch(_){}
 var ids=Object.keys(ptrs);if(ids.length===1)drag={x:e.clientX,y:e.clientY,cx:cam.x,cy:cam.y,moved:false};
 else if(ids.length===2){var a=ptrs[ids[0]],b=ptrs[ids[1]];pinch={d:Math.hypot(a.x-b.x,a.y-b.y),s:cam.s};drag=null}});
stage.addEventListener('pointermove',function(e){if(!ptrs[e.pointerId])return;ptrs[e.pointerId]={x:e.clientX,y:e.clientY};var ids=Object.keys(ptrs);
 if(ids.length===2&&pinch){var a=ptrs[ids[0]],b=ptrs[ids[1]],d=Math.hypot(a.x-b.x,a.y-b.y);zoomAt(pinch.s*d/pinch.d/cam.s,(a.x+b.x)/2,(a.y+b.y)/2);return}
 if(drag){var dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(!drag.moved&&Math.hypot(dx,dy)<5)return;drag.moved=true;stage.classList.add('drag');
  var ks=kpx()*cam.s;cam={s:cam.s,x:drag.cx-dx/ks,y:drag.cy-dy/ks};clampCam(cam);tid++;applyCam()}});
function end(e){var was=drag;delete ptrs[e.pointerId];if(Object.keys(ptrs).length<2)pinch=null;stage.classList.remove('drag');
 if(Object.keys(ptrs).length===0){drag=null;
  if(was&&!was.moved&&e.type==='pointerup'){var tk=rowTickAt(e.clientX,e.clientY);if(tk){selectRow(st.field,tk.row._i);return}
   var m=toModel(e.clientX,e.clientY),i=hitSlice(m[0],m[1]);if(i>=0)select(i);else if(depth()>0)go({sec:null,field:null,rows:false,row:null})}
  else if(was&&was.moved)later()}}
stage.addEventListener('pointerup',end);stage.addEventListener('pointercancel',end);
stage.addEventListener('keydown',function(e){var k=e.key,pan=.12/cam.s,handled=true;
 if(e.shiftKey&&k.indexOf('Arrow')===0){setCam(cam.s,cam.x+(k==='ArrowRight'?pan:k==='ArrowLeft'?-pan:0),cam.y+(k==='ArrowDown'?pan:k==='ArrowUp'?-pan:0),false)}
 else if(k==='ArrowRight')step(1);else if(k==='ArrowLeft')step(-1);else if(k==='ArrowDown'||k==='Enter')down();
 else if(k==='ArrowUp'||k==='Escape'||k==='Backspace')up();else if(k==='+'||k==='='){setCam(cam.s*1.4,cam.x,cam.y,true);later()}
 else if(k==='-'||k==='_'){setCam(cam.s/1.4,cam.x,cam.y,true);later()}else if(k==='0'||k==='Home')go({sec:null,field:null,rows:false,row:null});else handled=false;
 if(handled)e.preventDefault()});
window.addEventListener('resize',redraw);
var setLvOrig=L.setLv;L.setLv=function(lv){setLvOrig(lv);panelRender()};
var oldM=L.setMembers;L.setMembers=function(sel){msel=sel;oldM(sel)};
L.nav={down:down,up:up,step:step,depth:depth,state:function(){return st},select:select,cam:function(){return cam},zoomAt:zoomAt,sync:syncFromCam,draw:draw};
render();draw();
})();
"""

SELFTEST_BASE_JS = r"""
(function(){if(location.hash!=='#selftest')return;var L=window.__li,R={errors:window.__errs,wedges:L.W.length,labels:L.gL.childNodes.length,panel:!!document.getElementById('panel')};
 var before=L.svg.getAttribute('viewBox');
 L.svg.dispatchEvent(new WheelEvent('wheel',{deltaY:-400,clientX:300,clientY:300,bubbles:true,cancelable:true}));
 R.zoomed=L.svg.getAttribute('viewBox')!==before;
 var pre=document.createElement('pre');pre.id='selftest';pre.textContent=JSON.stringify(R);document.body.appendChild(pre)})();
"""

SELFTEST_JS = r"""
(function(){if(location.hash!=='#selftest')return;var L=window.__li,N=L.nav,M=L.M,R={errors:window.__errs,wedges:L.W.length,panel:!!document.getElementById('panel')},stage=L.svg;
 function key(k,o){stage.dispatchEvent(new KeyboardEvent('keydown',Object.assign({key:k,bubbles:true,cancelable:true},o||{})))}
 function done(){var pre=document.createElement('pre');pre.id='selftest';pre.textContent=JSON.stringify(R);document.body.appendChild(pre)}
 function diff(a,b){var m=0,ks=new Set(Object.keys(a).concat(Object.keys(b)));ks.forEach(function(i){var x=a[i]||[0,0,0,1,0],y=b[i]||[0,0,0,1,0];for(var q=0;q<5;q++)if(q!==3||(a[i]&&b[i]))m=Math.max(m,Math.abs(x[q]-y[q]))});return m}
 N.draw();R.labelsAtDisc=L.gL.childNodes.length;
 var before=N.cam().s;stage.dispatchEvent(new WheelEvent('wheel',{deltaY:-500,clientX:300,clientY:300,bubbles:true,cancelable:true}));
 R.wheelChangedScale=N.cam().s>before;R.zoomed=R.wheelChangedScale;
 key('0');var md=0;for(var q=0;q<6;q++){key('ArrowDown');md=Math.max(md,N.depth())}R.maxDepth=md;
 R.keyboardReachedRow=N.depth()===4;
 var rd=document.getElementById('rowdetail');R.rowShown=!!rd&&rd.textContent.length>20;R.rowFields=rd?rd.querySelectorAll('dt').length:0;
 key('ArrowUp');key('ArrowUp');R.upTwo=N.depth()===(md>=4?2:0);key('0');
 if(M.kind==='group'&&M.members){var all=M.members.map(function(){return true}),g=L.groupLv(all);R.groupMatches=diff(g,M.views[0].lv)<2e-3;
  var one=all.slice();one[0]=false;L.setMembers(one);R.groupTogglesChange=diff(L.lv,M.views[0].lv)>1e-3;L.setMembers(all)}
 if(M.kind==='compare'){R.views=document.querySelectorAll('#toolbar input[type=radio]').length;L.setView(0);var a=JSON.stringify(L.lv);L.setView(2);R.viewsDiffer=a!==JSON.stringify(L.lv)}
 setTimeout(done,50)})();
"""
