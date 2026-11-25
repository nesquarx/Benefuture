#!/usr/bin/env python3
"""Run the characterisation battery: evaluate the pre-registered signatures, blind identification and the humanity-white
check, on the extended population (primary) and the starter personas under each projection.

    python3 tools/characterise.py [--out data/gold/characterisation_v1_report]

Writes `<out>.json` (every number) and `<out>.md` (the report). No model is run: the extended personas are generated,
the extracted rows are the cached answers of `data/batches/texts_v2/extract.v1.var*.answers.jsonl`.
Deterministic: the same data gives byte-identical files.
"""
import argparse
import json
import math
import sys
import warnings
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage import characterise as ch  # noqa: E402

SIG_SHA_NOTE = "signatures: data/gold/characterisation_signatures_v1.json (registered before any new render)"


def clean(x):
    if isinstance(x, float):
        return None if math.isnan(x) else round(x, 5)
    if isinstance(x, dict):
        return {k: clean(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [clean(v) for v in x]
    return x


def run_set(name, entities, rows_by_id, asof_by_id, sigs, legacy=False):
    recs, states = ch.population_records(entities, rows_by_id, asof_by_id, legacy)
    pool = ch.pooled(states)
    verdicts = ch.evaluate_signatures(sigs, recs, pool)
    ident = ch.identify(recs)
    return {"name": name, "n": len(recs), "legacy": legacy, "pooled": pool, "verdicts": verdicts, "tally": ch.tally(verdicts),
            "identification": {k: {kk: vv for kk, vv in v.items() if kk != "predictions"} for k, v in ident.items()},
            "records": recs}


def main(out):
    warnings.simplefilter("ignore")
    sigs = ch.load_signatures()
    log = []
    ext = ch.extended_population()
    ext_rows = {e["id"]: ch.extended_rows(e)[0] for e in ext}
    ext_asof = {e["id"]: "2026-11-24" for e in ext}
    personas = ch.starter_personas()
    asof = {p["id"]: p["as_of"] for p in personas}
    truth = ch.starter_rows("truth")
    resume = ch.starter_rows("resume")
    extracted = ch.starter_rows("extracted", log=log)
    sets = [
        ("extended / new", ext, ext_rows, ext_asof, False),
        ("extended / legacy", ext, ext_rows, ext_asof, True),
        ("starter truth / new", personas, truth, asof, False),
        ("starter truth / legacy", personas, truth, asof, True),
        ("starter resume claims / new", personas, resume, asof, False),
    ]
    for v in range(3):
        sets.append((f"starter extracted var{v} / new", personas, extracted[v], asof, False))
        sets.append((f"starter extracted var{v} / legacy", personas, extracted[v], asof, True))
    results = [run_set(n, e, r, a, sigs, leg) for n, e, r, a, leg in sets]
    post = post_hoc(ext, ext_rows, ext_asof)
    (out.with_suffix(".json")).write_text(json.dumps(clean({"signatures": SIG_SHA_NOTE, "sets": results, "post_hoc": post, "degraded": log}), indent=1, sort_keys=True) + "\n", encoding="utf-8")
    (out.with_suffix(".md")).write_text(report(results, sigs, log, post), encoding="utf-8")
    for r in results:
        i = r["identification"]
        print(f"{r['name']:38s} n={r['n']:3d} held/not/inc={r['tally']['held']}/{r['tally']['not held']}/{r['tally']['inconclusive']} "
              f"archetype {i['archetype']['accuracy']:.2f} calibration {i['calibration']['accuracy']:.2f}")


def f3(x):
    return "n/a" if x is None else f"{x:.3f}"


def interval(v):
    if v["kind"] == "contrast":
        return f"{f3(v.get('effect'))} [{f3(v.get('lo'))}, {f3(v.get('hi'))}] vs {v['delta']}"
    if v["kind"] == "proportion":
        return f"{v['k']}/{v['n']} [{f3(v['lo'])}, {f3(v['hi'])}] vs {v['p0']}"
    if v["kind"] == "band":
        return ", ".join(f"{k} {x:.3f}" for k, x in v["values"].items()) + f" in [{v['lo']}, {v['hi']}]"
    return f"{f3(v['value'])} <= {v['limit']}"


def post_hoc(ext, rows, asof):
    """Not pre-registered: the mean level of the claimed red (over lit claimed slices) and the number of lit claimed slices, by
    calibration, on the extended population; a diagnostic of why the grain-share signatures behave as they do."""
    from statistics import mean
    acc = {}
    for e in ext:
        st = ch.image_state(rows[e["id"]], ch.world_basemap(), asof[e["id"]])
        lit = [x.claimed[0] for x in st.slices if x.claimed[0] > 0]
        acc.setdefault(e["calibration"], []).append((mean(lit) if lit else 0.0, len(lit)))
    return {c: {"mean_claimed_red_level": mean(a for a, _ in v), "mean_lit_claimed_slices": mean(n for _, n in v), "n": len(v)} for c, v in acc.items()}


def report(results, sigs, log, post):
    L = ["# Characterisation v1: report", "",
         "Pre-registered signatures (`characterisation_signatures_v1.json`, committed before any new render) evaluated on the extended population",
         "(144 generated personas, all-tier truth rows; the primary verdicts) and, as secondary readings, on the 40 starter personas under each",
         "projection. No model was run. Held, not held and inconclusive are reported as they fall; signatures are not edited after measurement.", "",
         "## Summary", "", "| set | n | held | not held | inconclusive | archetype id. (LOO) | calibration id. (LOO) |", "|---|---|---|---|---|---|---|"]
    for r in results:
        i = r["identification"]
        a, c = i["archetype"], i["calibration"]
        L.append(f"| {r['name']} | {r['n']} | {r['tally']['held']} | {r['tally']['not held']} | {r['tally']['inconclusive']} | "
                 f"{a['accuracy']:.2f} [{a['wilson'][0]:.2f}, {a['wilson'][1]:.2f}] (chance {a['chance']:.3f}, majority {a['majority']:.2f}) | "
                 f"{c['accuracy']:.2f} [{c['wilson'][0]:.2f}, {c['wilson'][1]:.2f}] (chance {c['chance']:.3f}, majority {c['majority']:.2f}) |")
    L += ["", "Identification: nearest centroid, leave one out, features standardised on the training fold; Wilson 95% interval; chance is 1/classes,",
          "majority the share of the largest class. An interval whose lower end is above the chance and the majority rate is better than chance.", ""]
    prim = results[0]
    L += ["## Signatures on the primary population (extended / new)", "", "| id | prediction | conf | verdict | effect [95% interval] against delta |", "|---|---|---|---|---|"]
    for v in prim["verdicts"]:
        L.append(f"| {v['id']} | {v['statement']} | {v['confidence']} | **{v['verdict']}** | {interval(v)} |")
    L += ["", "## Verdict by set", "", "| id | " + " | ".join(r["name"] for r in results) + " |", "|---|" + "---|" * len(results)]
    for k, s in enumerate(sigs):
        L.append(f"| {s['id']} | " + " | ".join(r["verdicts"][k]["verdict"] for r in results) + " |")
    L += ["", "## Humanity white (pooled composite)", "", "| set | red | green | blue | chroma / mean chroma |", "|---|---|---|---|---|"]
    for r in results:
        p = r["pooled"]
        L.append(f"| {r['name']} | {p['shares']['red']:.3f} | {p['shares']['green']:.3f} | {p['shares']['blue']:.3f} | {p['chroma_over_mean_chroma']:.3f} |")
    L += ["", "## Post-hoc diagnostic (not pre-registered)", "",
          "Extended population, by calibration: the mean level of the claimed red over lit claimed slices, and how many slices carry claimed red.", "",
          "| calibration | mean claimed red level | lit claimed slices | n |", "|---|---|---|---|"]
    L += [f"| {c} | {v['mean_claimed_red_level']:.3f} | {v['mean_lit_claimed_slices']:.1f} | {v['n']} |" for c, v in post.items()]
    L += ["", "Candidate for a v2 signature (to be registered before it is measured on fresh seeds), not a result of v1.", "", "## Degradations", ""]
    L += [f"- {d['step']}: {d['substitute']} ({d['reason']})" for d in log] or ["- none"]
    L += ["", "## Reading notes", "",
          "- Starter cells hold 1 to 4 personas; read the starter verdicts as a check of the pipeline's direction, not as tests with power.",
          "- The extracted rows are claims read from resumes: no attested or measured tier, no self-assessment rows. Signatures that need the solid layer",
          "  cannot hold from them, by construction.", ""]
    return "\n".join(L)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "data/gold/characterisation_v1_report")
    main(ap.parse_args().out)
