#!/usr/bin/env python3
"""Fetch public figures from Wikidata (CC0) into data/public/: recorded fixtures, attested rows, trace, metadata.

    python3 tools/gen_public.py            # live: query Wikidata, record fixtures, write rows
    python3 tools/gen_public.py --offline  # replay data/public/fixtures only (no network)

Figures are deceased people (or carry a stated public reason). LI.15: public figures' records may be kept.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.generators.common import seed_ids, validate_row  # noqa: E402
from lifeimage.sources import wikidata  # noqa: E402

OUT = ROOT / "data" / "public"
FIXTURES = OUT / "fixtures"
FIGURES = [  # (slug, qid, why this shape); qids resolved by Wikidata search and checked against the description
    ("marie-curie", "Q7186", "scientist: two Nobel prizes, professorship, laboratory employer, many memberships"),
    ("nelson-mandela", "Q8023", "statesman and lawyer: offices, activism, awards, degrees"),
    ("frida-kahlo", "Q5588", "painter: dated works; Wikidata holds few other statements (a thin record)"),
    ("wangari-maathai", "Q46795", "environmental activist and politician: offices, Nobel peace prize, academic posts"),
    ("johann-sebastian-bach", "Q1339", "composer: court and church employers, many works"),
    ("florence-nightingale", "Q37103", "nurse, reformer and statistician: care, reform, memberships"),
    ("srinivasa-ramanujan", "Q83163", "mathematician: a thin record"),
    ("jesse-owens", "Q52651", "athlete: Olympic awards, little else"),
    ("toni-morrison", "Q72334", "novelist and professor: dated works, awards"),
    ("hedy-lamarr", "Q49034", "actress and inventor: two careers"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args()
    fetch = wikidata.FixtureFetcher(FIXTURES) if args.offline else wikidata.RecordingFetcher(wikidata.http_fetch, FIXTURES)
    ids = sorted(seed_ids())
    OUT.mkdir(parents=True, exist_ok=True)
    summary = []
    for slug, qid, why in FIGURES:
        if args.only and slug not in args.only:
            continue
        fig = wikidata.build_figure(qid, fetch, require_public=True)
        rows, trace = wikidata.to_rows(fig, ids)
        for r in rows:
            validate_row(r)
        (OUT / f"{slug}.rows.jsonl").write_text("".join(json.dumps(r, sort_keys=True, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
        (OUT / f"{slug}.trace.jsonl").write_text("".join(json.dumps(t, sort_keys=True, ensure_ascii=False) + "\n" for t in trace), encoding="utf-8")
        meta = {k: fig[k] for k in ("qid", "label", "description", "birth", "death", "public_reason", "retrieved")}
        meta.update(shape=why, rows=len(rows), unmapped=sum(not t["mapped"] for t in trace), inferred_dates=sum(t["date"] == "inferred" for t in trace),
                    by_property={p: sum(t["property"] == p for t in trace) for p in sorted({t["property"] for t in trace})})
        (OUT / f"{slug}.json").write_text(json.dumps(meta, indent=1, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
        summary.append(meta)
        print(f"{slug:24s} {fig['label']:24s} rows={len(rows):3d} unmapped={meta['unmapped']:3d} {meta['by_property']}")
    if not args.only:
        write_readme(summary)
    return summary


def write_readme(summary):
    L = ["# Public figures from Wikidata", "",
         "Fetched from Wikidata (CC0 1.0, https://www.wikidata.org/wiki/Wikidata:Licensing) by `tools/gen_public.py` using `lifeimage/sources/wikidata.py`; "
         f"retrieved {summary[0]['retrieved']}. All figures are deceased (LI.15: public figures' records may be kept). Spouses and children are not read.", "",
         "Per figure: `<slug>.rows.jsonl` (contract rows, tier attested, entity `wikidata:<QID>`), `<slug>.trace.jsonl` (aligned line by line: property, label, "
         "QID, `mapped`, `fallback`, `date` stated or inferred, whether the statement carried a reference), `<slug>.json` (metadata). "
         "`fixtures/` holds the recorded, trimmed API responses: `python3 tools/gen_public.py --offline` rebuilds every file from them without the network.", "",
         "Mapping to the seed domains is by label matching (`RULES` in `wikidata.py`); a label that matches no rule keeps a property-level fallback domain "
         "(`s.work`, `s.learning`, `s.public`, `s.social`) and `mapped: false`, so a later pass (or the models) can map it. A statement with no date is dated from the figure's earliest "
         "dated statement and flagged `date: inferred` (confidence x 0.85). Confidence is 0.85 for a referenced statement, 0.6 for an unreferenced one. Magnitudes are prototype values.", "",
         "| figure | QID | lived | shape | rows | unmapped | inferred dates | by property |", "|---|---|---|---|---|---|---|---|"]
    for m in summary:
        L.append(f"| {m['label']} | {m['qid']} | {m['birth'][:4]}-{m['death'][:4]} | {m['shape']} | {m['rows']} | {m['unmapped']} | {m['inferred_dates']} | "
                 + ", ".join(f"{p} {n}" for p, n in m["by_property"].items()) + " |")
    L += ["", "Property codes: P106 occupation, P69 educated at, P39 position held, P166 award received, P800 notable work, P108 employer, P463 member of.", ""]
    (OUT / "README.md").write_text("\n".join(L), encoding="utf-8")


if __name__ == "__main__":
    main()
