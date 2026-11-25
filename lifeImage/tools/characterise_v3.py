#!/usr/bin/env python3
"""Characterisation battery v3: the image's levels, grain and tier together, against the v2 summary features.

    python3 tools/characterise_v3.py [--out data/gold/characterisation_v3_report] [--signatures data/gold/characterisation_signatures_v3.json]
                                     [--render-only]

Evaluates the predictions registered in the signatures file (committed before any measurement) on three populations (the 144 extended
personas on truth rows, the same under the legacy projection, the 40 starter personas on rows extracted from resume texts, three
variants pooled), for the v2 summary features and the v3 sets, with nearest centroid and nested logistic regression, leave one out.
Reduction, scaling and tuning are fitted inside the folds (`lifeimage/characterise_v3.py`). The v2 identification predictions and
signatures are re-evaluated unchanged on the same personas. No language or image model is run. Writes `<out>.json` and `<out>.md`.
"""
import argparse
import json
import math
import os
import sys
import warnings
from multiprocessing import Pool
from pathlib import Path

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import numpy as np  # noqa: E402

from lifeimage import ceiling as ce  # noqa: E402
from lifeimage import characterise as ch  # noqa: E402
from lifeimage import characterise_v3 as c3  # noqa: E402

LABELS = ("archetype", "calibration")
CLASSES = {"archetype": ch.ARCHETYPE_ORDER, "calibration": ch.CALIBRATION_ORDER}
SIGS = ROOT / "data/gold/characterisation_signatures_v3.json"
V2_SIGS = ROOT / "data/gold/characterisation_signatures_v2.json"
V2_REPORT = ROOT / "data/gold/characterisation_v2_report.json"
SET_NAMES = {"truth": "extended / new (truth rows)", "legacy": "extended / legacy", "extracted": "starter extracted, three variants pooled / new"}
BASE_SETS = ("v2", "v3", "v3_L", "v3_GT", "v3_pca")
FSETS = {"truth": c3.FEATURE_SETS, "legacy": BASE_SETS, "extracted": BASE_SETS}
NV = 3  # extraction variants

_D = {}


# ---------- build ----------

def build_units(recs, states):
    names, X, groups = c3.image_blocks(states)
    sn = ch.identification_names(recs)
    return {"X": X, "groups": groups, "S": ce.summary_features(recs, sn), "y": {lab: [r[lab] for r in recs] for lab in LABELS}}


def build(k):
    warnings.simplefilter("ignore")
    ext = ch.extended_population()
    rows, asof = {}, {}
    for e in ext:
        rows[e["id"]], asof[e["id"]] = ch.extended_rows(e)
    out, recs_by = {}, {}
    for key, legacy in (("truth", False), ("legacy", True)):
        recs, states = ch.population_records(ext, rows, asof, legacy)
        out[key] = [build_units(recs, states)]
        recs_by[key] = recs
    personas = ch.starter_personas()
    pasof = {p["id"]: p["as_of"] for p in personas}
    extracted = ch.starter_rows("extracted")
    out["extracted"], recs_by["extracted"] = [], []
    for v in range(NV):
        recs, states = ch.population_records(personas, extracted[v], pasof)
        out["extracted"].append(build_units(recs, states))
        recs_by["extracted"].append(recs)
    return out, recs_by, ext, personas


def _job(key):
    st, fs, clf = key
    preds = {lab: [] for lab in LABELS}
    chosen = {lab: [] for lab in LABELS}
    for u in _D["units"][st]:
        M, spec = c3.feature_set(fs, u["X"], u["groups"], u["S"], _D["k"])
        for lab in LABELS:
            p, c = c3.loo(M, u["y"][lab], spec, clf)
            preds[lab] += p
            chosen[lab] += c
    return key, preds, chosen


# ---------- run ----------

def run(sigs):
    units, recs_by, ext, personas = build(sigs["features"]["pca_k"])
    _D.update(units=units, k=sigs["features"]["pca_k"])
    jobs = [(st, fs, clf) for st in FSETS for fs in FSETS[st] for clf in c3.CLASSIFIERS]
    jobs.sort(key=lambda j: (j[2] != "logistic", j[0] != "truth"))
    with Pool(min(4, os.cpu_count() or 1)) as pool:
        res = {k: (p, c) for k, p, c in pool.imap_unordered(_job, jobs)}
    ys = {st: {lab: sum((u["y"][lab] for u in units[st]), []) for lab in LABELS} for st in units}
    acc, flags, entries = {}, {}, {}
    for (st, fs, clf), (preds, chosen) in sorted(res.items()):
        for lab in LABELS:
            y, p, cl = ys[st][lab], preds[lab], CLASSES[lab]
            m = ce.confusion(y, p, cl)
            a = {**ce.accuracy(y, p), "confusion": m, "recalls": ce.recalls(m, cl), "top_confusions": ce.top_confusions(m, cl, 4), "predictions": p}
            if clf == "logistic":
                a["chosen_c"] = {str(c): chosen[lab].count(c) for c in ce.C_GRID}
            acc[(st, fs, clf, lab)] = a
            flags[(st, fs, clf, lab)] = [x == t for x, t in zip(p, y)]
            entries.setdefault(st, {}).setdefault(fs, {}).setdefault(lab, {})[clf] = a
    n_per = {st: len(units[st][0]["y"]["archetype"]) for st in units}
    clusters_of = lambda st: [i % n_per[st] for i in range(n_per[st] * len(units[st]))] if len(units[st]) > 1 else None  # noqa: E731
    out = {"sets": {st: {"n": len(ys[st]["archetype"]), "personas": n_per[st], "variants": len(units[st]), "columns": {fs: _cols(units[st][0], fs, sigs) for fs in FSETS[st]}}
                    for st in units},
           "results": entries, "paired_vs_v2": [], "verdicts": [], "pca_k": sigs["features"]["pca_k"]}
    for st in units:
        for lab in LABELS:
            for a, b in ((("v3", "logistic"), ("v2", "logistic")), (("v3", "logistic"), ("v2", "centroid")), (("v3", "centroid"), ("v2", "centroid")),
                         (("v3_L", "logistic"), ("v2", "logistic")), (("v3_GT", "logistic"), ("v2", "logistic"))):
                r = c3.paired(flags[(st, *a, lab)], flags[(st, *b, lab)], clusters_of(st))
                out["paired_vs_v2"].append({"set": st, "label": lab, "a": list(a), "b": list(b), **r})
    out["verdicts"] = [c3.verdict(p, acc, flags, clusters_of) for p in sigs["predictions"]]
    out["v2_reevaluation"] = reevaluate_v2(recs_by, ext, personas)
    return out


def _cols(u, fs, sigs):
    M, spec = c3.feature_set(fs, u["X"], u["groups"], u["S"], sigs["features"]["pca_k"])
    return {"raw": int(M.shape[1]), "reduced_to": int(sum(k for _, k in spec.groups) + len(spec.passthrough))}


def reevaluate_v2(recs_by, ext, personas):
    """The v2 identification predictions and signatures, evaluated unchanged on the same personas (the v2 battery's code and files)."""
    spec = json.loads(V2_SIGS.read_text(encoding="utf-8"))
    sigs, ident_specs = spec["signatures"], spec["identification"]
    ident = {"extended / new": ch.identify(recs_by["truth"]), "extended / legacy": ch.identify(recs_by["legacy"])}
    for v in range(NV):
        ident[f"starter extracted var{v} / new"] = ch.identify(recs_by["extracted"][v])
    ident = {n: {lab: {k: x for k, x in r.items() if k != "predictions"} for lab, r in d.items()} for n, d in ident.items()}
    verdicts = ch.evaluate_identification(ident_specs, ident)
    sets = {"extended / new": recs_by["truth"], "extended / legacy": recs_by["legacy"]}
    tallies = {}
    for name in sets:
        pooled = ch.pooled(_states(name, ext))
        tallies[name] = ch.tally(ch.evaluate_signatures(sigs, sets[name], pooled, sets=sets))
    before = {}
    if V2_REPORT.exists():
        d = json.loads(V2_REPORT.read_text(encoding="utf-8"))
        before = {s["name"]: s["tally"] for s in d["sets"] if s["name"] in sets}
    return {"identification": ident, "identification_verdicts": verdicts, "signature_tally": tallies, "committed_v2_report_tally": before}


def _states(name, ext):
    rows, asof = {}, {}
    for e in ext:
        rows[e["id"]], asof[e["id"]] = ch.extended_rows(e)
    return ch.population_records(ext, rows, asof, legacy=name.endswith("legacy"))[1]


# ---------- report ----------

def iv(r):
    return f"{r['accuracy']:.3f} [{r['wilson'][0]:.3f}, {r['wilson'][1]:.3f}]"


def matrix_md(m, classes):
    L = ["| truth \\ predicted | " + " | ".join(c[:4] for c in classes) + " | recall |", "|---|" + "---|" * (len(classes) + 1)]
    for i, c in enumerate(classes):
        L.append(f"| {c} | " + " | ".join(str(v) if j != i else f"**{v}**" for j, v in enumerate(m[i])) + f" | {m[i][i] / sum(m[i]):.2f} |")
    return L


def report(out, sigs):
    R = out["results"]
    L = ["# Characterisation v3: report", "",
         "Predictions registered in `characterisation_signatures_v3.json` (hash-pinned, committed before any measurement) evaluated on three populations: "
         "the 144 extended personas on truth rows, the same personas under the legacy projection, and the 40 starter personas on rows extracted from resume "
         "texts (three variants, each leave-one-out within its variant, pooled to 120 persona-variants). The v3 feature set is the image's per-domain solid "
         f"levels, red grain share and tier saturation (coarse rings) reduced by PCA (k = {out['pca_k']}, fitted inside every training fold and every inner "
         "fold of the penalty search, labels never read) plus the v2 summary features. Classifiers: nearest centroid and L2 logistic regression with nested "
         "cross-validation. No language or image model was run. Predictions are not edited after measurement.", "",
         "## Accuracy (leave one out, Wilson 95% interval)", ""]
    for st in SET_NAMES:
        s = out["sets"][st]
        L += [f"### {SET_NAMES[st]} (n = {s['n']})", "", "| feature set | columns (raw, after reduction) | classifier | archetype | calibration |", "|---|---|---|---|---|"]
        for fs in FSETS[st]:
            for clf in c3.CLASSIFIERS:
                c = s["columns"][fs]
                L.append(f"| {fs}{' (exploratory)' if fs in ('v3_k10', 'v3_k40') else ''} | {c['raw']}, {c['reduced_to']} | {clf} | {iv(R[st][fs]['archetype'][clf])} | {iv(R[st][fs]['calibration'][clf])} |")
        a0 = R[st]["v2"]["archetype"]["centroid"]
        c0 = R[st]["v2"]["calibration"]["centroid"]
        L += ["", f"Chance {a0['chance']:.3f} (archetype) and {c0['chance']:.3f} (calibration); majority class {a0['majority']:.3f} and {c0['majority']:.3f}.", ""]
    L += ["## Paired differences against v2 (same personas)", "",
          "Difference of accuracy a - b, 95% interval of the paired difference (clustered by persona, Student-t, for the extracted set), exact sign test "
          "(extracted: on the persona-level sign). Only a / only b: units where only a (b) is right.", "",
          "| set | label | a | b | a - b [interval] | only a | only b | sign p |", "|---|---|---|---|---|---|---|---|"]
    for r in out["paired_vs_v2"]:
        L.append(f"| {r['set']} | {r['label']} | {'/'.join(r['a'])} | {'/'.join(r['b'])} | {r['diff']:+.3f} [{r['lo']:+.3f}, {r['hi']:+.3f}] | {r['only_a']} | {r['only_b']} | {r['sign_p']:.3f} |")
    L += ["", "## Predictions against results", "", "| id | confidence | verdict | observed | prediction |", "|---|---|---|---|---|"]
    for v in out["verdicts"]:
        if "diff" in v:
            obs = f"{v['diff']:+.3f} [{v['lo']:+.3f}, {v['hi']:+.3f}] against {v['delta']}"
        elif "accuracy" in v:
            obs = f"{v['accuracy']:.3f} [{v['lo']:.3f}, {v['hi']:.3f}] against {v['value']}"
        else:
            obs = ", ".join(f"{c} {v['recalls'][c]:.2f}" for c in v["observed"])
        L.append(f"| {v['id']} | {v['confidence']:.2f} | **{v['verdict']}** | {obs} | {v['text']} |")
    tally = {k: sum(v["verdict"] == k for v in out["verdicts"]) for k in ("held", "not held", "inconclusive")}
    exp = sum(v["confidence"] for v in out["verdicts"])
    L += ["", f"Held {tally['held']}, not held {tally['not held']}, inconclusive {tally['inconclusive']} of {len(out['verdicts'])}; the stated confidences expected {exp:.1f} to hold.", "",
          "## Confusion matrices (logistic; rows truth, columns predicted, first four letters)", ""]
    for st in SET_NAMES:
        for lab in LABELS:
            for fs in ("v2", "v3"):
                r = R[st][fs][lab]["logistic"]
                L += [f"#### {SET_NAMES[st]}, {lab}, {fs} ({r['correct']}/{r['n']})", ""] + matrix_md(r["confusion"], CLASSES[lab]) + [""]
                L += ["- top pairs: " + "; ".join(f"{a} / {b} ({x} / {y})" for a, b, x, y in r["top_confusions"]), ""]
    L += ["## Penalty chosen by the nested search (logistic, truth rows; leave-one-out folds per C)", "", "| feature set | label | " + " | ".join(f"{c:g}" for c in ce.C_GRID) + " |", "|---|---|" + "---|" * len(ce.C_GRID)]
    for fs in FSETS["truth"]:
        for lab in LABELS:
            cc = R["truth"][fs][lab]["logistic"]["chosen_c"]
            L.append(f"| {fs} | {lab} | " + " | ".join(str(cc[str(c)]) for c in ce.C_GRID) + " |")
    v2 = out["v2_reevaluation"]
    L += ["", "## v2 signatures re-evaluated unchanged", "",
          "The v2 identification predictions (I1 to I6) and the 38 signatures, evaluated with the v2 battery's code and the unchanged v2 file on the same personas "
          "as this report (current generator and code, fine evidence).", "", "| id | set | label | prediction | accuracy | verdict |", "|---|---|---|---|---|---|"]
    for v in v2["identification_verdicts"]:
        L.append(f"| {v['id']} | {v['set']} | {v['label']} | {'at least' if v['bound'] == 'min' else 'at most'} {v['value']:.2f} | {v['accuracy']:.3f} [{v['lo']:.3f}, {v['hi']:.3f}] (n={v['n']}) | {v['verdict']} |")
    L += ["", "| set | held | not held | inconclusive | committed v2 report (held / not held / inconclusive) |", "|---|---|---|---|---|"]
    for n, t in v2["signature_tally"].items():
        b = v2["committed_v2_report_tally"].get(n)
        L.append(f"| {n} | {t['held']} | {t['not held']} | {t['inconclusive']} | {'/'.join(str(b[k]) for k in ('held', 'not held', 'inconclusive')) if b else 'n/a'} |")
    L += ["", "## Limits", "",
          "- 144 personas: intervals of about +-0.08; the extracted set is 40 personas read three ways (120 persona-variants, not independent), so its intervals are clustered by persona.",
          "- One reduction size (k = 20) was registered; k = 10 and 40 are exploratory sensitivity on truth rows.",
          "- The summary features are carried unreduced, so a v3 gain is from the reduced image blocks.",
          "- Generated data: what the generator puts in is what can come out; no real population is measured here.",
          "- No multiplicity adjustment; each prediction is read on its own.", ""]
    return "\n".join(L) + "\n"


def clean(x):
    if isinstance(x, float):
        return None if math.isnan(x) else round(x, 5)
    if isinstance(x, dict):
        return {str(k): clean(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [clean(v) for v in x]
    if isinstance(x, np.generic):
        return clean(x.item())
    return x


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "data/gold/characterisation_v3_report"))
    ap.add_argument("--signatures", default=str(SIGS))
    ap.add_argument("--render-only", action="store_true")
    a = ap.parse_args()
    sigs = json.loads(Path(a.signatures).read_text(encoding="utf-8"))
    out_path = Path(a.out)
    if a.render_only:
        out = json.loads(out_path.with_suffix(".json").read_text(encoding="utf-8"))
    else:
        out = clean(run(sigs))
        out_path.with_suffix(".json").write_text(json.dumps(out, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    out_path.with_suffix(".md").write_text(report(out, sigs), encoding="utf-8")
    for v in out["verdicts"]:
        print(v["id"], v["verdict"], round(v.get("diff", v.get("accuracy", 0)) or 0, 3))


if __name__ == "__main__":
    main()
