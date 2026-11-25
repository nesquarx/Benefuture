"""Compare the share of extreme (±2) axes scores between prompt versions, and report axes v3.

Usage (from the repository root):
    python3 lifeImage/tools/axes_compare.py [--v1 FILES...] [--v2 FILES...] [--v3 FILES...]
Defaults: data/batches/axes.v1.var*.answers.jsonl against data/batches/axes.v2.var*.answers.jsonl (v2 answers appear
once the batches are run). Prints, for each version, the share of scores at a pole overall, per axis and the share
of items extreme on both axes, and the drop from v1 to v2.

v3 (data/batches/axes.v3.<at|pg>.var*.part*.answers.jsonl, found by default; --v3 names files, the axis taken from the
`at` or `pg` in the file name): per axis the share of answers at 0 or 10, the mean pairwise agreement of the three
variants (Spearman and mean absolute difference over fields) and the Spearman of the variant mean with the v1/v2 means
and with the pairwise pilot (data/coarse/axes_pairwise_pilot.jsonl).
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.axes import axes_input, extreme_share  # noqa: E402
from lifeimage.axes_pair import axis_means  # noqa: E402
from lifeimage.axes_v3 import AXIS_OF, SHORT, TASK_TYPES, v3_report  # noqa: E402
from lifeimage.canonical import content_hash  # noqa: E402
from lifeimage.packs import is_sector  # noqa: E402


def read(paths):
    return [json.loads(l) for p in paths for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


def compare(v1_paths, v2_paths):
    a, b = extreme_share(read(v1_paths)), extreme_share(read(v2_paths))
    return {"v1": a, "v2": b, "drop": a["share"] - b["share"]}


def report(s):
    rows = [f"{k}: {s[k]['items']} items, extreme scores {s[k]['share']:.1%} (axis 1 {s[k]['axis1']:.1%}, axis 2 "
            f"{s[k]['axis2']:.1%}), both axes extreme {s[k]['both_extreme_items']:.1%}" for k in ("v1", "v2")]
    return "\n".join(rows + [f"drop in extreme share, v1 to v2: {s['drop']:+.1%}"])


def load_v3(paths):
    """{axis name: answers} from v3 answer files, the axis read from `.at.` or `.pg.` in the file name."""
    out = {}
    for p in sorted(map(Path, paths)):
        for t in TASK_TYPES:
            if f".{SHORT[t]}." in p.name:
                out.setdefault(AXIS_OF[t], []).extend(read([p]))
    return out


def v3_context(root=ROOT):
    """(owner {input hash: field id}, v1/v2 means {axis: {id: mean}}, pilot rows) from the seed cards and cached files."""
    cards = read([root / "data/coarse/seed_v0.jsonl"])
    by = {c["id"]: c for c in cards}
    owner = {content_hash(axes_input(c, by)): c["id"] for c in cards if not is_sector(c)}
    old = [read(sorted((root / "data/batches").glob(f"axes.v{v}.var*.answers.jsonl"))) for v in (1, 2)]
    pilot = root / "data/coarse/axes_pairwise_pilot.jsonl"
    return owner, axis_means(cards, [a for a in old if a]), read([pilot]) if pilot.exists() else []


def report_v3(report):
    f = lambda x, pct=False: "n/a" if x is None else f"{x:.1%}" if pct else f"{x:.3f}"
    rows = []
    for ax, s in report.items():
        rows.append(f"v3 {ax}: {s['fields']} fields, {s['variants']} variants, {s['answers']} answers; at 0 or 10: {f(s['share_poles'], True)}; "
                    f"variant agreement: Spearman {f(s['variant_spearman'])}, mean abs difference {f(s['variant_mad'])}; "
                    f"Spearman with v1/v2 means {f(s['spearman_v1v2'])}, with the pairwise pilot {f(s['spearman_pilot'])}")
    return "\n".join(rows)


def compare_v3(paths, root=ROOT):
    owner, v12, pilot = v3_context(root)
    return v3_report(load_v3(paths), v12, pilot, owner)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--v1", nargs="+", default=sorted((ROOT / "data/batches").glob("axes.v1.var*.answers.jsonl")))
    ap.add_argument("--v2", nargs="+", default=sorted((ROOT / "data/batches").glob("axes.v2.var*.answers.jsonl")))
    ap.add_argument("--v3", nargs="+", default=sorted((ROOT / "data/batches").glob("axes.v3.*.var*.part*.answers.jsonl")))
    a = ap.parse_args()
    if not a.v2 and not a.v3:
        sys.exit("no axes.v2 or axes.v3 answers yet: run data/batches/axes.v2.var{0,1,2}.jsonl or the axes.v3 parts first")
    if a.v2:
        print(report(compare(a.v1, a.v2)))
    if a.v3:
        print(report_v3(compare_v3(a.v3)))
