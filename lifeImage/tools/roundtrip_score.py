"""Round-trip accuracy of an answers file against its key file.

Usage: python3 lifeImage/tools/roundtrip_score.py data/batches/roundtrip.A4.v1.key.jsonl data/batches/roundtrip.A4.v1.var0.answers.jsonl
Graded v2 (accuracy per level with Wilson interval, chance line, L5 split by nuance kind); each KEY's answers are
the same path with `.key.jsonl` replaced by `.answers.jsonl`:
       python3 lifeImage/tools/roundtrip_score.py --graded data/batches/roundtrip.A3S.v2.L*.key.jsonl
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

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


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--graded":
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
