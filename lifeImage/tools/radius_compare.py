"""Compare the judged radius (radius v1) with itself across variants and with the mechanical proxies.

Usage (from the repository root): python3 lifeImage/tools/radius_compare.py [FILES...]
Default files: data/batches/radius.v1.var*.part*.answers.jsonl, cards from data/coarse/seed_v3.jsonl. Prints the share
of answers at 0 or 10, the agreement of the variants (Spearman, mean absolute difference over fields), the Spearman of
the judged mean with each mechanical proxy and with the composite, and the domains where judged and mechanical rank
disagree most.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.radius_judged import PROXIES, radius_report  # noqa: E402


def read(paths):
    return [json.loads(l) for p in paths for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


def compare(paths, root=ROOT):
    return radius_report(read(paths), read([Path(root) / "data/coarse/seed_v3.jsonl"]))


def format_report(r):
    f = lambda x, pct=False: "n/a" if x is None else f"{x:.1%}" if pct else f"{x:.3f}"
    rows = [f"radius v1: {r['fields']} fields, {r['variants']} variants, {r['answers']} answers; at 0 or 10: {f(r['share_poles'], True)}; "
            f"variant agreement: Spearman {f(r['variant_spearman'])}, mean abs difference {f(r['variant_mad'])}",
            "Spearman of the judged mean with " + ", ".join(f"{p} {f(r['spearman'][p])}" for p in PROXIES),
            "disagree most (judged vs mechanical composite, rank gap):"]
    rows += [f"  {d['gap']:.2f} {d['id']} {d['label']!r} judged {d['judged']} mechanical {d['mechanical']}" for d in r["disagreement"]]
    return "\n".join(rows)


if __name__ == "__main__":
    files = sys.argv[1:] or sorted((ROOT / "data/batches").glob("radius.v1.var*.part*.answers.jsonl"))
    if not files:
        sys.exit("no radius.v1 answers yet: run data/batches/radius.v1.var{0,1}.part{n}.jsonl first")
    print(format_report(compare(files)))
