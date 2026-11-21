"""Round-trip accuracy of an answers file against its key file.

Usage: python3 lifeImage/tools/roundtrip_score.py data/batches/roundtrip.A4.v1.key.jsonl data/batches/roundtrip.A4.v1.var0.answers.jsonl
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.roundtrip import score_files  # noqa: E402

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    s = score_files(sys.argv[1], sys.argv[2])
    print(json.dumps(s, sort_keys=True))
    print(f"round-trip accuracy {s['accuracy']:.1%} over {s['tasks']} tasks (chance {s['chance']:.0%})")
