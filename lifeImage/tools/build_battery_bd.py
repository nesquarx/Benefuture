"""Write battery BD (layer B participation, layer D event links) into data/batches (gitignored; no model is run).

- participation.v1.var{0,1,2}.jsonl and events.v1.var{0,1,2}.jsonl over `data/gold/bd_items_v0.jsonl`; variants
  reorder the participants (and, for events, the link-type definitions) deterministically.

Usage (from the repository root): python3 lifeImage/tools/build_battery_bd.py [--out DIR]
Answers are validated with `lifeimage.events.validate_bd_answers`; metrics: tools/bd_metrics.py.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.events import TASK_TYPE as EVENTS, build_events_batches  # noqa: E402
from lifeimage.membership import DEFAULT_OUT  # noqa: E402
from lifeimage.participation import (TASK_TYPE as PARTICIPATION, build_participation_batches, load_bd_items,  # noqa: E402
                                     write_bd_batches)


def report(p):
    n = len(p.read_text(encoding="utf-8").splitlines()) - 1
    print(p.name, n, "tasks", f"~{len(p.read_bytes()) // 4} tokens")


if __name__ == "__main__":
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else DEFAULT_OUT
    items = load_bd_items()
    print(len(items), "items")
    for tt, build in ((PARTICIPATION, build_participation_batches), (EVENTS, build_events_batches)):
        for p in write_bd_batches(tt, build(items), out):
            report(p)
