"""Round-trip accuracy of an answers file against its key file.

Usage: python3 lifeImage/tools/roundtrip_score.py data/batches/roundtrip.A4.v1.key.jsonl data/batches/roundtrip.A4.v1.var0.answers.jsonl
Graded v2 (accuracy per level with Wilson interval, chance line, L5 split by nuance kind); each KEY's answers are
the same path with `.key.jsonl` replaced by `.answers.jsonl`:
       python3 lifeImage/tools/roundtrip_score.py --graded data/batches/roundtrip.A3S.v2.L*.key.jsonl
Round-trip v3 (accuracy by nearest-decoy similarity decile, text-only control, leak-corrected gain):
       python3 lifeImage/tools/roundtrip_score.py --v3 --key data/batches/roundtrip.v3.key.jsonl \
           --answers data/batches/roundtrip.v3.var0.answers.jsonl \
           --control-key data/batches/roundtrip.v3.control.key.jsonl \
           --control-answers data/batches/roundtrip.v3.control.var0.answers.jsonl
(`--answers` and `--control-answers` take several files when a batch was split into parts.)
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.confirm_roundtrip import render_v3, score_v3_files  # noqa: E402
from lifeimage.roundtrip import score_files  # noqa: E402
from lifeimage.roundtrip_graded import render_graded, score_graded_files  # noqa: E402


def graded_pairs(key_paths):
    """[(key path, answers path)] for the keys whose answers exist; a missing answers file is reported, not skipped."""
    out = []
    for k in key_paths:
        a = str(k).replace(".key.jsonl", ".answers.jsonl")
        if not Path(a).exists():
            print(f"no answers yet for {k} (expected {a})", file=sys.stderr)
            continue
        out.append((k, a))
    return out


def v3_args(argv):
    """{--key, --control-key: path; --answers, --control-answers: [paths]} from the arguments after --v3."""
    out, cur = {}, None
    for a in argv:
        if a.startswith("--"):
            cur = a[2:].replace("-", "_")
            out[cur] = []
        elif cur is None:
            sys.exit(__doc__)
        else:
            out[cur].append(a)
    if set(out) != {"key", "answers", "control_key", "control_answers"} or len(out["key"]) != 1 or len(out["control_key"]) != 1:
        sys.exit(__doc__)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--v3":
        v = v3_args(sys.argv[2:])
        s = score_v3_files(v["key"][0], v["answers"], v["control_key"][0], v["control_answers"])
        print(json.dumps(s, sort_keys=True))
        print(render_v3(s))
    elif len(sys.argv) > 2 and sys.argv[1] == "--graded":
        pairs = graded_pairs(sys.argv[2:])
        if not pairs:
            sys.exit("no scorable key/answers pairs")
        s = score_graded_files([k for k, _ in pairs], [a for _, a in pairs])
        print(json.dumps(s, sort_keys=True))
        print(render_graded(s))
    elif len(sys.argv) != 3:
        sys.exit(__doc__)
    else:
        s = score_files(sys.argv[1], sys.argv[2])
        print(json.dumps(s, sort_keys=True))
        print(f"round-trip accuracy {s['accuracy']:.1%} over {s['tasks']} tasks (chance {s['chance']:.0%})")
