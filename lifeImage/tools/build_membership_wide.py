"""LI.67 wide memberships: write the runner batches, judge the calibration battery, ingest answers. No model is run here.

Usage (from the repository root):
  python3 lifeImage/tools/build_membership_wide.py batches            # calibration, kinds, snippets into data/batches (gitignored)
  python3 lifeImage/tools/build_membership_wide.py judge              # needs the calibration answers files next to the batches
  python3 lifeImage/tools/build_membership_wide.py ingest kinds       # merges the answers into data/events/kind_memberships_v1.jsonl
  python3 lifeImage/tools/build_membership_wide.py ingest snippets    # ... data/events/snippet_memberships_v1.jsonl
Order: run the calibration batches first (two files), judge, and only then the kinds and snippets batches.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.membership import DEFAULT_OUT, DEFAULT_PACK  # noqa: E402
from lifeimage.membership_wide import (ESCALATIONS, KIND_TABLE, PROMPT_VERSION, SNIPPET_TABLE, TASK_TYPE, answers_by_item,  # noqa: E402
                                       build_wide_batches, calibration_items, calibration_report, ingest, kind_items,
                                       load_controls, snippet_items, width_summary, write_wide_batches)

SETS = {"calibration": calibration_items, "kinds": kind_items, "snippets": snippet_items}
TABLES = {"kinds": KIND_TABLE, "snippets": SNIPPET_TABLE}


def files(name):
    """(batch, answers) path pairs of one set, every variant and part present in data/batches."""
    pat = f"{TASK_TYPE}.v{PROMPT_VERSION}.{name}.var*.part*.jsonl"
    batches = sorted(p for p in DEFAULT_OUT.glob(pat) if not p.name.endswith(".answers.jsonl"))
    return [(p, p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))) for p in batches]


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    if cmd == "batches":
        for name, make in SETS.items():
            for p in write_wide_batches(name, build_wide_batches(make(), pack), DEFAULT_OUT):
                print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "judge":
        pairs = files("calibration")
        missing = [str(a.name) for _, a in pairs if not a.exists()]
        if not pairs or missing:
            sys.exit(f"calibration answers missing: {missing or 'no batch files (run `batches`)'}")
        rep = calibration_report(load_controls(), answers_by_item(pairs))
        out = ROOT / "data" / "gold" / "membership_wide_calibration_report.json"
        out.write_text(json.dumps(rep, indent=1, sort_keys=True, default=list) + "\n", encoding="utf-8")
        print(json.dumps({k: v for k, v in rep.items() if k not in ("unjudged_secondary", "bad_secondary")}, indent=1, sort_keys=True))
        print(f"{len(rep['unjudged_secondary'])} unjudged and {len(rep['bad_secondary'])} bad secondary domains listed in {out.relative_to(ROOT)}")
    elif cmd == "ingest" and len(sys.argv) > 2 and sys.argv[2] in TABLES:
        name = sys.argv[2]
        pairs = files(name)
        missing = [str(a.name) for _, a in pairs if not a.exists()]
        if not pairs or missing:
            sys.exit(f"{name} answers missing: {missing or 'no batch files (run `batches`)'}")
        rows = ingest(pairs, TABLES[name], ESCALATIONS.with_name(f"escalations.membership_wide.{name}.jsonl"))
        print(json.dumps(width_summary(rows), indent=1, sort_keys=True))
    else:
        sys.exit(__doc__)
