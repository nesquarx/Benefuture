"""LI.67 wide memberships: write the runner batches, judge the calibration battery, ingest answers. No model is run here.

Usage (from the repository root); `--version N` picks the prompt version (default 4, the one under calibration; 3 reproduces v3):
  python3 lifeImage/tools/build_membership_wide.py batches [--version N] [--sets calibration,kinds,snippets]
      # default sets: calibration only (kinds and snippets wait for the calibration verdict); into data/batches (gitignored)
  python3 lifeImage/tools/build_membership_wide.py judge [--version N]      # needs the calibration answers files next to the batches
  python3 lifeImage/tools/build_membership_wide.py refine [--version N]     # backfill the LI.68 refinement log from the calibration answers
  python3 lifeImage/tools/build_membership_wide.py unjudged [--version N]   # data/gold/membership_wide_unjudged_v<N>.md for review
  python3 lifeImage/tools/build_membership_wide.py judge --version 3|4 --gold v1   # re-judge the answers against the completed gold (LI.69)
  python3 lifeImage/tools/build_membership_wide.py gold-batches   # gold-completion batches (task gold_judge) for the v3 and v4 unjudged domains
  python3 lifeImage/tools/build_membership_wide.py gold-ingest    # agreed verdicts -> membership_wide_controls_v1.jsonl, disputes -> membership_wide_disputed_v1.md
  python3 lifeImage/tools/build_membership_wide.py ingest kinds       # merges the answers into data/events/kind_memberships_v1.jsonl
  python3 lifeImage/tools/build_membership_wide.py ingest snippets    # ... data/events/snippet_memberships_v1.jsonl
Order: run the calibration batches first (two files), judge, and only then the kinds and snippets batches.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage import gold_judge as gj  # noqa: E402
from lifeimage.membership import DEFAULT_OUT, DEFAULT_PACK  # noqa: E402
from lifeimage.membership_wide import (ESCALATIONS, KIND_TABLE, LATEST_PROMPT_VERSION, SNIPPET_TABLE, TASK_TYPE, answers_by_item,  # noqa: E402
                                       build_wide_batches, calibration_items, calibration_report, ingest, kind_items, log_calibration,
                                       load_controls, unjudged_review, _pack_labels, snippet_items, width_summary, write_wide_batches)

SETS = {"calibration": calibration_items, "kinds": kind_items, "snippets": snippet_items}
TABLES = {"kinds": KIND_TABLE, "snippets": SNIPPET_TABLE}


def files(name, version=LATEST_PROMPT_VERSION):
    """(batch, answers) path pairs of one set, every variant and part present in data/batches."""
    pat = f"{TASK_TYPE}.v{version}.{name}.var*.part*.jsonl"
    batches = sorted(p for p in DEFAULT_OUT.glob(pat) if not p.name.endswith(".answers.jsonl"))
    return [(p, p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))) for p in batches]


if __name__ == "__main__":
    args = sys.argv[1:]
    opts = {}
    for flag in ("--version", "--sets", "--gold"):
        if flag in args:
            i = args.index(flag)
            opts[flag] = args[i + 1]
            del args[i:i + 2]
    version = int(opts.get("--version", LATEST_PROMPT_VERSION))
    gold = opts.get("--gold", "v0")
    sets = opts.get("--sets", "calibration").split(",")
    cmd = args[0] if args else ""
    sys.argv = [sys.argv[0]] + args
    suffix = "" if version == 3 else f"_v{version}"
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    if cmd == "batches":
        for name in sets:
            make = SETS[name]
            for p in write_wide_batches(name, build_wide_batches(make(), pack, prompt_version=version), DEFAULT_OUT, prompt_version=version):
                print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "judge":
        pairs = files("calibration", version)
        missing = [str(a.name) for _, a in pairs if not a.exists()]
        if not pairs or missing:
            sys.exit(f"calibration answers missing: {missing or 'no batch files (run `batches`)'}")
        if gold not in ("v0", "v1"):
            sys.exit("--gold is v0 or v1")
        controls = load_controls(gj.CONTROLS_V1) if gold == "v1" else load_controls()
        rep = calibration_report(controls, answers_by_item(pairs), prompt_version=version, complete_gold=gold == "v1")
        out = gj.report_path(version, gold)
        out.write_text(json.dumps(rep, indent=1, sort_keys=True, default=list) + "\n", encoding="utf-8")
        if gold == "v0":
            log_calibration(load_controls(), answers_by_item(pairs), version)  # LI.68: candidates to data/refinement/
        print(json.dumps({k: v for k, v in rep.items() if k not in ("unjudged_secondary", "bad_secondary")}, indent=1, sort_keys=True))
        print(f"{len(rep['unjudged_secondary'])} unjudged and {len(rep['bad_secondary'])} bad secondary domains listed in {out.relative_to(ROOT)}")
    elif cmd in ("gold-batches", "gold-ingest"):
        if cmd == "gold-batches":
            by = {}
            for v in (3, 4):
                pairs = files("calibration", v)
                if not pairs or any(not a.exists() for _, a in pairs):
                    sys.exit(f"v{v} calibration answers missing")
                by[v] = answers_by_item(pairs)
            controls = load_controls()
            entries = gj.unjudged_entries(controls, by)
            for p in gj.write_gold_batches(gj.build_gold_batches(entries, controls, pack)):
                print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
            print(len(entries), "unjudged (item, relation, domain) triples")
        else:
            batch_files = sorted(p for p in DEFAULT_OUT.glob(f"{gj.TASK_TYPE}.v{gj.PROMPT_VERSION}.gold.var*.part*.jsonl") if not p.name.endswith(".answers.jsonl"))
            pairs = [(p, p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))) for p in batch_files]
            if not pairs or any(not a.exists() for _, a in pairs):
                sys.exit("gold-judge answers missing (run `gold-batches`, then the batches)")
            controls = load_controls()
            res = gj.complete_gold(controls, gj.read_verdicts(pairs), rulings=gj.read_rulings())
            gj.write_controls(res["controls"], gj.CONTROLS_V1)
            gj.DISPUTED.write_text(gj.disputed_review(res["disputed"], controls, pack), encoding="utf-8")
            print(gj.CONTROLS_V1.relative_to(ROOT), "written;", len(res["disputed"]), "disputed in", gj.DISPUTED.relative_to(ROOT))
    elif cmd == "refine":
        pairs = files("calibration", version)
        if not pairs or any(not a.exists() for _, a in pairs):
            sys.exit("calibration answers missing")
        s = log_calibration(load_controls(), answers_by_item(pairs), version)
        print(json.dumps({"records": s["records"], "by_version_source": s["by_version_source"]}, sort_keys=True))
    elif cmd == "unjudged":
        pairs = files("calibration", version)
        if not pairs or any(not a.exists() for _, a in pairs):
            sys.exit("calibration answers missing")
        out = ROOT / "data" / "gold" / f"membership_wide_unjudged_v{version}.md"
        out.write_text(unjudged_review(load_controls(), answers_by_item(pairs), _pack_labels(pack), version=version) + "\n", encoding="utf-8")
        print(out.relative_to(ROOT))
    elif cmd == "ingest" and len(sys.argv) > 2 and sys.argv[2] in TABLES:
        name = sys.argv[2]
        pairs = files(name, version)
        missing = [str(a.name) for _, a in pairs if not a.exists()]
        if not pairs or missing:
            sys.exit(f"{name} answers missing: {missing or 'no batch files (run `batches`)'}")
        rows = ingest(pairs, TABLES[name], ESCALATIONS.with_name(f"escalations.membership_wide.{name}.jsonl"))
        print(json.dumps(width_summary(rows), indent=1, sort_keys=True))
    else:
        sys.exit(__doc__)
