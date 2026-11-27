"""LI.70 two-pass extraction: write the runner batches, ingest the answers, judge the pre-registered predictions. No model is run here.

Usage (from the repository root); sets are `controls` (the 32 membership calibration controls) and `snippets` (50 calibration snippets):
  python3 lifeImage/tools/build_two_pass.py pilot                 # pass-1 batches: data/batches/blind.v1.<set>.var{0,1}.part0.jsonl
  python3 lifeImage/tools/build_two_pass.py map [--sets a,b] [--version N]      # pass-2 batches from the validated pass-1 answers: map.v<N>.<set>.var{0,1}.part0.jsonl
  python3 lifeImage/tools/build_two_pass.py ingest [--sets a,b] [--version N] [--merge RULE]   # memberships table, synonym log (data/refinement/synonyms_v1.jsonl), blind_unmatched candidates
  python3 lifeImage/tools/build_two_pass.py judge [--version N] [--gold v0|v1]   # data/gold/two_pass_report[_vN].json against data/gold/two_pass_predictions.md
--version is the pass-2 prompt version (default 2, the hybrid `map.v2`; 1 reproduces `map.v1`); --gold v1 judges against the completed gold (default v1 for version 2, v0 for 1);
--merge is the variant merge rule (support_union, the default, or intersection).
  python3 lifeImage/tools/build_two_pass.py pilot --blind-version 2 --sets controls   # LI.71 `blind.v2` pass-1 batches: blind.v2.controls.var{0,1}.part0.jsonl
  python3 lifeImage/tools/build_two_pass.py label_match           # judge batches (label_match.v1.blind_v2.part*.jsonl) from the validated blind.v2 controls answers
  python3 lifeImage/tools/build_two_pass.py report_v2             # data/gold/blind_v2_report.json against data/gold/blind_v2_predictions.md
  python3 lifeImage/tools/build_two_pass.py status                # which batch and answers files exist
Order: pilot, run the pass-1 batches, map, run the pass-2 batches, ingest, judge. Batch files are gitignored (data/batches).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage import gold_judge as gj  # noqa: E402
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
    opts = {}
    for flag in ("--version", "--gold", "--merge", "--blind-version"):
        if flag in args:
            i = args.index(flag)
            opts[flag] = args[i + 1]
            del args[i:i + 2]
    version = int(opts.get("--version", tp.LATEST_MAP_VERSION))
    gold = opts.get("--gold", "v1" if version >= 2 else "v0")
    merge = opts.get("--merge")
    if "--sets" in args:
        i = args.index("--sets")
        sets = args[i + 1].split(",")
        del args[i:i + 2]
    cmd = args[0] if args else ""
    if cmd == "pilot":
        bv = int(opts.get("--blind-version", tp.BLIND_VERSION))
        for p in tp.pilot_blind_batches(DEFAULT_OUT, bv, sets=sets if "--sets" in sys.argv else None):
            print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "map":
        cards = tp.load_domain_cards()
        for name in sets:
            for p in tp.write_map_batches(name, tp.build_map_batches(need(files("blind", name), "pass-1"), cards, prompt_version=version), DEFAULT_OUT, version):
                print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "ingest":
        blind = [pr for n in sets for pr in need(files("blind", n), "pass-1")]
        mapped = [pr for n in sets for pr in need(files("map", n, version), "pass-2")]
        rows = tp.ingest_two_pass(blind, mapped, tp.table_path(version), escalation_path=tp.escalation_path(version), merge=merge)
        print(json.dumps({"items": len(rows), "escalated": sum(r["escalate"] for r in rows),
                          "synonyms": len(read_log(tp.SYNONYMS)), "candidates": sum(1 for c in read_log(tp.REFINEMENT_DIR / "candidates_v1.jsonl") if c["source"] == "blind_unmatched")}))
    elif cmd == "judge":
        blind, mapped = need(files("blind", "controls"), "pass-1"), need(files("map", "controls", version), "pass-2")
        v4 = json.loads(V4_REPORT.read_text(encoding="utf-8"))["recall_required"]
        controls = load_controls(gj.CONTROLS_V1) if gold == "v1" else load_controls()
        rep = tp.two_pass_report(controls, tp.answers_by_item(blind), tp.answers_by_item(mapped), synonyms=read_log(tp.SYNONYMS),
                                 candidates=read_log(tp.REFINEMENT_DIR / "candidates_v1.jsonl"), v4_recall=v4, complete_gold=gold == "v1")
        tp.report_path(version).write_text(json.dumps(rep, indent=1, sort_keys=True, default=list) + "\n", encoding="utf-8")
        print(json.dumps({k: v for k, v in rep.items() if k != "median_listed"}, indent=1, sort_keys=True))
    elif cmd == "label_match":
        from lifeimage import label_match as lm
        for p in lm.write_label_match_batches("blind_v2", lm.build_label_match_batches(need(files("blind", "controls", 2), "blind.v2")), DEFAULT_OUT):
            print(p.relative_to(ROOT), len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
    elif cmd == "report_v2":
        from lifeimage import label_match as lm
        blind = tp.answers_by_item(need(files("blind", "controls", 2), "blind.v2"))
        judged = []
        batch_files = sorted(p for p in DEFAULT_OUT.glob("label_match.v1.blind_v2.part*.jsonl") if not p.name.endswith(".answers.jsonl"))
        for bp, ap in need([(p, p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))) for p in batch_files], "label_match"):
            b, a = bp.read_text(encoding="utf-8").splitlines(), ap.read_text(encoding="utf-8").splitlines()
            tasks = {json.loads(l)["task_id"]: json.loads(l) for l in b[1:]}
            judged += [(tasks[json.loads(l)["task_id"]], json.loads(l)) for l in a]
        rep = tp.blind_v2_report(blind, judged)
        (ROOT / "data" / "gold" / "blind_v2_report.json").write_text(json.dumps(rep, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps(rep, indent=1, sort_keys=True))
    elif cmd == "status":
        for t in ("blind", "map"):
            for n in ("controls", "snippets"):
                pairs = files(t, n, version if t == "map" else 1)
                print(t, n, [(b.name, a.exists()) for b, a in pairs])
        print("blind.v2 controls", [(b.name, a.exists()) for b, a in files("blind", "controls", 2)])
    else:
        sys.exit(__doc__)
