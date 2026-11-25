#!/usr/bin/env python3
"""Run the characterisation battery: evaluate the pre-registered signatures, blind identification and the humanity-white
check, on the extended population (primary) and the starter personas under each projection.

    python3 tools/characterise.py [--out data/gold/characterisation_v2_report] [--signatures data/gold/characterisation_signatures_v2.json]

Writes `<out>.json` (every number) and `<out>.md` (the report); the pre-registered identification predictions are evaluated too. No model is run: the extended personas are generated,
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

SIG_NOTE = "signatures: {} (registered before any render with the version-2 semantics)"


def clean(x):
    if isinstance(x, float):
        return None if math.isnan(x) else round(x, 5)
    if isinstance(x, dict):
        return {k: clean(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [clean(v) for v in x]
    return x


V1_REPORT = ROOT / "data/gold/characterisation_v1_report.json"


def run_set(name, entities, rows_by_id, asof_by_id, legacy=False):
    recs, states = ch.population_records(entities, rows_by_id, asof_by_id, legacy)
    pool = ch.pooled(states)
    ident = ch.identify(recs)
    return {"name": name, "n": len(recs), "legacy": legacy, "pooled": pool,
            "identification": {k: {kk: vv for kk, vv in v.items() if kk != "predictions"} for k, v in ident.items()}, "records": recs}


def mean_of(recs, key):
    from statistics import mean
    xs = [r[key] for r in recs if not (isinstance(r[key], float) and math.isnan(r[key]))]
    return mean(xs) if xs else None


def v1_luminance():
    """{set name: (mean, min, max) luminance} from the version-1 report, or {} if it is absent."""
    if not V1_REPORT.exists():
        return {}
    out = {}
    for st in json.loads(V1_REPORT.read_text(encoding="utf-8"))["sets"]:
        xs = [r["luminance"] for r in st["records"]]
        out[st["name"]] = (sum(xs) / len(xs), min(xs), max(xs))
    return out


def main(out, signatures=None):
    warnings.simplefilter("ignore")
    signatures = signatures or ch.SIGNATURES
    sigs = ch.load_signatures(signatures)
    ident_specs = ch.load_identification(signatures)
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
    results = [run_set(n, e, r, a, leg) for n, e, r, a, leg in sets]
    by_name = {r["name"]: r["records"] for r in results}
    for r in results:
        r["verdicts"] = ch.evaluate_signatures(sigs, r["records"], r["pooled"], sets=by_name)
        r["tally"] = ch.tally(r["verdicts"])
    ident_verdicts = ch.evaluate_identification(ident_specs, {r["name"]: r["identification"] for r in results})
    post = post_hoc(ext)
    lum = {r["name"]: {"mean": mean_of(r["records"], "luminance"), "typical_level": mean_of(r["records"], "typical_level")} for r in results}
    payload = {"signatures": SIG_NOTE.format(Path(signatures).name), "sets": results, "identification_verdicts": ident_verdicts,
               "luminance": lum, "luminance_v1": v1_luminance(), "post_hoc": post, "degraded": log}
    (out.with_suffix(".json")).write_text(json.dumps(clean(payload), indent=1, sort_keys=True) + "\n", encoding="utf-8")
    (out.with_suffix(".md")).write_text(report(results, sigs, ident_verdicts, lum, v1_luminance(), log, post), encoding="utf-8")
    for r in results:
        i = r["identification"]
        print(f"{r['name']:38s} n={r['n']:3d} held/not/inc={r['tally']['held']}/{r['tally']['not held']}/{r['tally']['inconclusive']} "
              f"archetype {i['archetype']['accuracy']:.2f} calibration {i['calibration']['accuracy']:.2f}")
    for v in ident_verdicts:
        print(f"{v['id']} {v['set']} {v['label']} {v['bound']} {v['value']}: {v['verdict']} ({v['accuracy']})")


def f3(x):
    return "n/a" if x is None else f"{x:.3f}"


def interval(v):
    if v["kind"] in ("contrast", "paired", "paired_sets"):
        return f"{f3(v.get('effect'))} [{f3(v.get('lo'))}, {f3(v.get('hi'))}] vs {v['delta']}"
    if v["kind"] == "proportion":
        return f"{v['k']}/{v['n']} [{f3(v['lo'])}, {f3(v['hi'])}] vs {v['p0']}"
    if v["kind"] == "band":
        return ", ".join(f"{k} {x:.3f}" for k, x in v["values"].items()) + f" in [{v['lo']}, {v['hi']}]"
    if v["kind"] == "band_stat":
        return f"{v.get('stat')} {f3(v.get('value'))} (n={v.get('n')}) in [{v['lo']}, {v['hi']}]"
    return f"{f3(v['value'])} <= {v['limit']}"


def post_hoc(ext):
    """Not pre-registered. On the extended population: the mean estimate-minus-truth over every claimed domain by calibration, and
    the correlation between estimate and truth pooled over the population (Zell and Krizan 2014 report about 0.29)."""
    from statistics import mean
    from lifeimage.generators import life
    by, xs, ys = {}, [], []
    for e in ext:
        p = life.generate_persona(seed=e["seed"], archetype=e["archetype"], age=e["age"], calibration=e["calibration"], pid=e["id"])
        est = {}
        for r in p.rows:
            if r["channel"] == "prediction":
                m = r["memberships"][0]
                est[(m["domain"], "impact" if m["rel"] == "outcome" else "expertise")] = r["magnitude"]
        for d, lat in p.latent.items():
            for kind in ("expertise", "impact"):
                by.setdefault(e["calibration"], []).append(est[(d, kind)] - lat[kind])
                xs.append(lat[kind])
                ys.append(est[(d, kind)])
    mx, my = mean(xs), mean(ys)
    cov = sum((a - mx) * (b - my) for a, b in zip(xs, ys))
    r = cov / math.sqrt(sum((a - mx) ** 2 for a in xs) * sum((b - my) ** 2 for b in ys))
    return {"mean_estimate_minus_truth": {c: mean(v) for c, v in by.items()}, "n_estimates": len(xs), "pooled_correlation_estimate_truth": r}


def report(results, sigs, ident_verdicts, lum, lum_v1, log, post):
    L = ["# Characterisation v2: report", "",
         "Pre-registered signatures (`characterisation_signatures_v2.json`, committed before any render with grain restricted to claimed potential, the",
         "anchored tone map or the literature-based estimation bias) evaluated on the extended population (144 generated personas, all-tier truth rows; the",
         "primary verdicts) and, as secondary readings, on the 40 starter personas under each projection. No model was run. Held, not held and inconclusive",
         "are reported as they fall; signatures are not edited after measurement.", "",
         "## Summary", "", "| set | n | held | not held | inconclusive | archetype id. (LOO) | calibration id. (LOO) |", "|---|---|---|---|---|---|---|"]
    for r in results:
        i = r["identification"]
        a, c = i["archetype"], i["calibration"]
        L.append(f"| {r['name']} | {r['n']} | {r['tally']['held']} | {r['tally']['not held']} | {r['tally']['inconclusive']} | "
                 f"{a['accuracy']:.2f} [{a['wilson'][0]:.2f}, {a['wilson'][1]:.2f}] (chance {a['chance']:.3f}, majority {a['majority']:.2f}) | "
                 f"{c['accuracy']:.2f} [{c['wilson'][0]:.2f}, {c['wilson'][1]:.2f}] (chance {c['chance']:.3f}, majority {c['majority']:.2f}) |")
    L += ["", "Identification: nearest centroid, leave one out, features standardised on the training fold; Wilson 95% interval; chance is 1/classes,",
          "majority the share of the largest class. An interval whose lower end is above the chance and the majority rate is better than chance.", ""]
    L += ["## Predicted blind identification", "",
          "The three extracted variants are pooled (correct and n summed over the variants) for the extracted rows: the registered line names the three variants",
          "together and does not say how to combine them; this reading was fixed before any measurement.", "",
          "| id | set | label | prediction | accuracy [95% interval] | verdict |", "|---|---|---|---|---|---|"]
    for v in ident_verdicts:
        L.append(f"| {v['id']} | {v['set']} | {v['label']} | {'at least' if v['bound'] == 'min' else 'at most'} {v['value']:.2f} | "
                 f"{f3(v['accuracy'])} [{v['lo']:.3f}, {v['hi']:.3f}] (n={v['n']}) | {v['verdict']} |")
    prim = results[0]
    L += ["", "## Signatures on the primary population (extended / new)", "", "| id | prediction | conf | verdict | effect [95% interval] against delta |", "|---|---|---|---|---|"]
    for v in prim["verdicts"]:
        L.append(f"| {v['id']} | {v['statement']} | {v['confidence']} | **{v['verdict']}** | {interval(v)} |")
    L += ["", "## Verdict by set", "", "| id | " + " | ".join(r["name"] for r in results) + " |", "|---|" + "---|" * len(results)]
    for k, s in enumerate(sigs):
        L.append(f"| {s['id']} | " + " | ".join(r["verdicts"][k]["verdict"] for r in results) + " |")
    L += ["", "## Humanity white (pooled composite)", "", "| set | red | green | blue | chroma / mean chroma |", "|---|---|---|---|---|"]
    for r in results:
        p = r["pooled"]
        L.append(f"| {r['name']} | {p['shares']['red']:.3f} | {p['shares']['green']:.3f} | {p['shares']['blue']:.3f} | {p['chroma_over_mean_chroma']:.3f} |")
    L += ["", "## Luminance, before and after", "",
          "Mean image luminance by set; version 1 is the earlier report (earlier tone constant, claimed tier as grain, earlier generator).", "",
          "| set | mean luminance v1 (min, max) | mean luminance v2 | mean typical level v2 |", "|---|---|---|---|"]
    for r in results:
        b = lum_v1.get(r["name"])
        L.append(f"| {r['name']} | {f'{b[0]:.4f} ({b[1]:.4f}, {b[2]:.4f})' if b else 'n/a'} | {f3(lum[r['name']]['mean'])} | {f3(lum[r['name']]['typical_level'])} |")
    L += ["", "## Post-hoc diagnostic (not pre-registered)", "",
          "Extended population: mean estimate minus truth over every claimed domain, by calibration, and the pooled correlation between estimate and truth",
          f"({post['n_estimates']} estimates; Zell and Krizan 2014 report about 0.29 between self-assessment and performance).", "",
          "| calibration | mean estimate minus truth |", "|---|---|"]
    L += [f"| {c} | {v:.3f} |" for c, v in sorted(post["mean_estimate_minus_truth"].items())]
    L += ["", f"Pooled correlation of estimate and truth: {post['pooled_correlation_estimate_truth']:.3f}.", "", "## Degradations", ""]
    L += [f"- {d['step']}: {d['substitute']} ({d['reason']})" for d in log] or ["- none"]
    L += ["", "## Reading notes", "",
          "- Starter cells hold 1 to 4 personas; read the starter verdicts as a check of the pipeline's direction, not as tests with power.",
          "- Extracted rows are claims read from resumes and texts: tier shows as pale solid colour and self-assessments as grain, but no attested or measured",
          "  tier exists in them, so signatures that need demonstrated skill rest on claimed green only.",
          "- Signatures that name a projection (W4, W5) report the same value in every column.", ""]
    return "\n".join(L)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "data/gold/characterisation_v2_report")
    ap.add_argument("--signatures", type=Path, default=None)
    a = ap.parse_args()
    main(a.out, a.signatures)
