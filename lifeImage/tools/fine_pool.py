"""Build the fine candidate pool offline from data/fine/sources/, data/public/ and data/answers/.

Usage (from the repository root): python3 lifeImage/tools/fine_pool.py
`--atus-only` rebuilds just data/fine/candidates_atus_v0.jsonl (new candidates against the committed first pool).
Writes data/fine/candidates_v0.jsonl (the pool) and data/fine/pool_report.json (every raw item accounted for:
raw = pool + merged + dropped; per-source licence status; network status). Run `tools/fine_fetch.py` first to refresh
the public classifications; this step needs no network and runs no model.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.fine.pool import build_pool, new_candidates, write_pool  # noqa: E402
from lifeimage.fine.sources import read_jsonl  # noqa: E402

FINE = ROOT / "data" / "fine"


def atus_only(coarse):
    """The ATUS candidates against the committed first pool (data/fine/candidates_v0.jsonl), which is left as it is: the
    first pool's cards and cached answers are not rebuilt (a local rights-reserved source file would change it)."""
    first = read_jsonl(FINE / "candidates_v0.jsonl")
    cands, rep = new_candidates(read_jsonl(FINE / "sources" / "atus.jsonl"), first, coarse)
    write_pool(cands, FINE / "candidates_atus_v0.jsonl")
    (FINE / "atus_pool_report.json").write_text(json.dumps(rep, indent=1, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(f"atus: raw {rep['raw']}, new candidates {len(cands)}, merged {rep['merged']}, dropped {len(rep['dropped'])}")


def main(argv=None):
    coarse = read_jsonl(ROOT / "data/coarse/seed_v2.jsonl")
    if argv is None:
        argv = sys.argv[1:]
    if "--atus-only" in argv:
        return atus_only(coarse)
    pool, report = build_pool(coarse)
    write_pool(pool, FINE / "candidates_v0.jsonl")
    (FINE / "pool_report.json").write_text(json.dumps(report, indent=1, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(f"pool {len(pool)}; merged {report['merged']}; dropped {len(report['dropped'])}")
    for s, v in report["by_source"].items():
        print(f"  {s}: raw {v['raw']}, in pool {v['in_pool']}, licence {v['licence_status']}")
    print("  candidates by worst licence status:", report["licence_status_of_candidates"])
    print("  network blocked:", report["network"]["blocked"])
    if (FINE / "sources" / "atus.jsonl").exists():
        atus_only(coarse)


if __name__ == "__main__":
    main()
