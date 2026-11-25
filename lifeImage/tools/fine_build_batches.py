"""Write the fine_parent v1 batches for the candidate pool (no model is run).

Usage (from the repository root): python3 lifeImage/tools/fine_build_batches.py [--k 3] [--out data/batches] [--set atus]
Writes data/batches/fine_parent.v1.var{0,1,2}.part{n}.jsonl (gitignored; at most 50 cards each; model `haiku-runner`),
skipping (candidate, variant) pairs already in the answer cache. Each file's header holds the instructions and the
ungrouped coarse pack in that variant's fixed shuffle. Run the batches on the runner agent type (prompts/RUNNER.md),
then `tools/fine_apply.py`.
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.fine.parent import build_fine_batches, write_fine_batches  # noqa: E402
from lifeimage.fine.sources import read_jsonl  # noqa: E402

MODEL = "haiku-runner"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--out", default=ROOT / "data/batches")
    ap.add_argument("--candidates", default=ROOT / "data/fine/candidates_v0.jsonl")
    ap.add_argument("--set", choices=["atus", "gap", "gap2"], help="build the batches of a further candidate set (2 variants, tagged files)")
    ap.add_argument("--coarse", default=ROOT / "data/coarse/seed_v2.jsonl")
    a = ap.parse_args(argv)
    if a.set:  # only the new candidates: data/fine/candidates_<set>_v0.jsonl, 2 variants
        a.candidates, a.k = ROOT / f"data/fine/candidates_{a.set}_v0.jsonl", 2
    batches = build_fine_batches(read_jsonl(a.candidates), read_jsonl(a.coarse), cache=AnswerCache(), model=MODEL, k=a.k)
    for p in write_fine_batches(batches, a.out, tag=a.set):
        print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "cards")


if __name__ == "__main__":
    main()
