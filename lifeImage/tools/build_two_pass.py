"""LI.70 two-pass extraction: write the runner batches, ingest the answers, judge the pre-registered predictions. No model is run here.

Usage (from the repository root); sets are `controls` (the 32 membership calibration controls) and `snippets` (50 calibration snippets):
  python3 lifeImage/tools/build_two_pass.py pilot                 # pass-1 batches: data/batches/blind.v1.<set>.var{0,1}.part0.jsonl
  python3 lifeImage/tools/build_two_pass.py map [--sets a,b]      # pass-2 batches from the validated pass-1 answers: map.v1.<set>.var{0,1}.part0.jsonl
  python3 lifeImage/tools/build_two_pass.py ingest [--sets a,b]   # memberships table, synonym log (data/refinement/synonyms_v1.jsonl), blind_unmatched candidates
  python3 lifeImage/tools/build_two_pass.py judge                 # data/gold/two_pass_report.json against data/gold/two_pass_predictions.md
  python3 lifeImage/tools/build_two_pass.py status                # which batch and answers files exist
Order: pilot, run the pass-1 batches, map, run the pass-2 batches, ingest, judge. Batch files are gitignored (data/batches).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage import two_pass as tp  # noqa: E402
from lifeimage.membership import DEFAULT_OUT  # noqa: E402
from lifeimage.membership_wide import load_controls  # noqa: E402
from lifeimage.refinement import read_log  # noqa: E402

V4_REPORT = ROOT / "data" / "gold" / "membership_wide_calibration_report_v4.json"


def files(task_type, name, version=1):
    batches = sorted(p for p in DEFAULT_OUT.glob(f"{task_type}.v{version}.{name}.var*.part*.jsonl") if not p.name.endswith(".answers.jsonl"))
    return [(p, p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))) for p in batches]


def need(pairs, what):
    missing = [a.name for _, a in pairs if not a.exists()]
    if not pairs or missing:
        sys.exit(f"{what} answers missing: {missing or 'no batch files'}")
    return pairs


if __name__ == "__main__":
    args = sys.argv[1:]
    sets = ["controls", "snippets"]
    if "--sets" in args:
        i = args.index("--sets")
        sets = args[i + 1].split(",")
        del args[i:i + 2]
    cmd = args[0] if args else ""
    if cmd == "pilot":
        for p in tp.pilot_blind_batches(DEFAULT_OUT):
            print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "map":
        cards = tp.load_domain_cards()
        for name in sets:
            for p in tp.write_map_batches(name, tp.build_map_batches(need(files("blind", name), "pass-1"), cards), DEFAULT_OUT):
                print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "ingest":
        blind = [pr for n in sets for pr in need(files("blind", n), "pass-1")]
        mapped = [pr for n in sets for pr in need(files("map", n), "pass-2")]
        rows = tp.ingest_two_pass(blind, mapped)
        print(json.dumps({"items": len(rows), "escalated": sum(r["escalate"] for r in rows),
                          "synonyms": len(read_log(tp.SYNONYMS)), "candidates": sum(1 for c in read_log(tp.REFINEMENT_DIR / "candidates_v1.jsonl") if c["source"] == "blind_unmatched")}))
    elif cmd == "judge":
        blind, mapped = need(files("blind", "controls"), "pass-1"), need(files("map", "controls"), "pass-2")
        v4 = json.loads(V4_REPORT.read_text(encoding="utf-8"))["recall_required"]
        rep = tp.two_pass_report(load_controls(), tp.answers_by_item(blind), tp.answers_by_item(mapped), synonyms=read_log(tp.SYNONYMS),
                                 candidates=read_log(tp.REFINEMENT_DIR / "candidates_v1.jsonl"), v4_recall=v4)
        tp.REPORT.write_text(json.dumps(rep, indent=1, sort_keys=True, default=list) + "\n", encoding="utf-8")
        print(json.dumps({k: v for k, v in rep.items() if k != "median_listed"}, indent=1, sort_keys=True))
    elif cmd == "status":
        for t in ("blind", "map"):
            for n in ("controls", "snippets"):
                pairs = files(t, n)
                print(t, n, [(b.name, a.exists()) for b, a in pairs])
    else:
        sys.exit(__doc__)
