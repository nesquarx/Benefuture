"""Fit pairwise axis positions (Bradley-Terry with ties) from axes_pair answers; no model is run.

Usage (from the repository root): python3 lifeImage/tools/axes_pair_fit.py [--out FILE] [--pilot [--axis AXIS]]
With --pilot it reads the single-order pilot's answers (data/batches/axes_pair.<axis>.pilot.part*.answers.jsonl, built
by build_axes_pair_batches.py --axis ABSTRACT_TANGIBLE --comparisons 4 --single-order), regenerates its tasks and writes
data/coarse/axes_pairwise_pilot.jsonl, leaving the full fit's file alone. Otherwise reads the answers next to the batches (data/batches/axes_pair.<axis>.v1.part*.answers.jsonl), regenerates the
designed tasks from seed_v0 and the axes v1/v2 answers, and writes data/coarse/axes_pairwise_v1.jsonl (id, axis,
position rescaled to [-1, 1], se). Prints per axis the Spearman agreement with the v1 and v2 means, the share of fields
at the extremes (|position| > 0.8) and the split-half reliability (fit on half the comparisons against the other half).
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.axes_pair import AXES, axis_means, build_pair_batches, comparisons_from_answers  # noqa: E402
from lifeimage.pairwise import fit_bt, rescale, spearman, split_half_reliability  # noqa: E402

EXTREME = 0.8


def read(paths):
    return [json.loads(l) for p in paths for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


PILOT_COMPARISONS = 4


def answer_files(batches, axis, pilot=False):
    """The answers files of the axis: the pilot's parts, or the full design's (v1) parts, in part order."""
    tag = "pilot" if pilot else "v1"
    files = Path(batches).glob(f"axes_pair.{axis}.{tag}.part*.answers.jsonl")
    return sorted(files, key=lambda p: int(p.name.rsplit(".part", 1)[1].split(".", 1)[0]))


def fit_axis(axis, tasks, answers, means, seed=0, version_means=None):
    """(rows, stats) for one axis: rows {id, axis, position, se}; stats compare with the prior means."""
    comps = comparisons_from_answers(answers, tasks)
    ids = sorted(means)
    fit = fit_bt(comps, ids=ids)
    pos, se = rescale(fit.theta, fit.se)
    rows = [{"id": i, "axis": axis, "position": round(pos[i], 6), "se": round(se[i], 6)} for i in ids]
    col = [pos[i] for i in ids]
    stats = {"fields": len(ids), "comparisons": len(comps), "tie_share": sum(c[2] == "tie" for c in comps) / max(len(comps), 1),
             "nu": fit.nu, "spearman_v1v2": spearman(col, [means[i] for i in ids]),
             "extreme_share": sum(abs(p) > EXTREME for p in col) / len(col),
             "split_half": split_half_reliability(comps, seed=seed, ids=ids)}
    for name, m in (version_means or {}).items():
        stats[f"spearman_{name}"] = spearman(col, [m[i] for i in ids])
    return rows, stats


def write_rows(rows, path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("".join(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n" for r in rows), encoding="utf-8")


def report(stats):
    out = []
    for axis, s in stats.items():
        extra = "".join(f", Spearman with {k[9:]} means {v:+.3f}" for k, v in s.items() if k in ("spearman_v1", "spearman_v2"))
        out.append(f"{axis}: {s['fields']} fields, {s['comparisons']} comparisons ({s['tie_share']:.1%} ties, nu {s['nu']:.2f}); "
                   f"Spearman with the v1/v2 mean {s['spearman_v1v2']:+.3f}{extra}; extremes (|position| > {EXTREME}) "
                   f"{s['extreme_share']:.1%}; split-half reliability {s['split_half']:+.3f}")
    return "\n".join(out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=None)
    ap.add_argument("--model", default="haiku-runner")
    ap.add_argument("--pilot", action="store_true", help="fit the single-order pilot's answers")
    ap.add_argument("--axis", choices=AXES, default=None, help="one axis only (the pilot covers abstract_tangible)")
    a = ap.parse_args()
    axes = [a.axis] if a.axis else ["abstract_tangible"] if a.pilot else list(AXES)
    out = a.out or ROOT / ("data/coarse/axes_pairwise_pilot.jsonl" if a.pilot else "data/coarse/axes_pairwise_v1.jsonl")
    batches = ROOT / "data/batches"
    cards = read([ROOT / "data/coarse/seed_v0.jsonl"])
    v1, v2 = (read(sorted(batches.glob(f"axes.v{v}.var*.answers.jsonl"))) for v in (1, 2))
    prior, m1, m2 = axis_means(cards, [v1, v2]), axis_means(cards, [v1]), axis_means(cards, [v2])
    rows, stats = [], {}
    for axis in axes:
        files = answer_files(batches, axis, a.pilot)
        if not files:
            sys.exit(f"no answers for {axis}: run data/batches/axes_pair.{axis}.{'pilot' if a.pilot else 'v1'}.part*.jsonl first")
        kw = {"comparisons": PILOT_COMPARISONS, "single_order": True} if a.pilot else {}
        tasks = [json.loads(l) for p in build_pair_batches(cards, prior[axis], axis, model=a.model, **kw) for l in p[1:]]
        r, stats[axis] = fit_axis(axis, tasks, read(files), prior[axis], version_means={"v1": m1[axis], "v2": m2[axis]})
        rows += r
    write_rows(rows, out)
    print(report(stats))
