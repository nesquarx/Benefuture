"""Add the relational form (LI.65) to every event snippet of the committed calibration table, in place and without refetching.

`cd lifeImage && python3 tools/eventgen_relationalise.py`. Idempotent: the form is derived from the snippet and its Param.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lifeimage.eventgen.calibration import CAL_DIR, Table, dump_params, load_params  # noqa: E402
from lifeimage.eventgen.relational import relationalise_params  # noqa: E402

if __name__ == "__main__":
    params = relationalise_params(load_params())
    Table(params)
    dump_params(params, CAL_DIR / "aggregates_v1.jsonl")
    print(f"{len(params)} params, {sum(len(p.event_snippets) for p in params)} event snippets relationalised")
