"""Write the extract v1 batches over the synthetic personas' resumes: 3 variants in data/batches (no model is run).

Usage (from the repository root): python3 lifeImage/tools/build_extract_batches.py
Files (gitignored): data/batches/extract.v1.var{0,1,2}.jsonl, one task per persona, the coarse pack in the prefix in a
different order per variant. Run them on the runner agent, then score with tools/extract_score.py.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.extract import SYNTHETIC, build_extract_batches, resume_input, write_extract_batches  # noqa: E402
from lifeimage.membership import DEFAULT_OUT, DEFAULT_PACK  # noqa: E402

if __name__ == "__main__":
    personas = [json.loads(l) for l in (SYNTHETIC / "personas.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    inputs = [resume_input(p, (SYNTHETIC / "texts" / f"{p['id']}.resume.txt").read_text(encoding="utf-8")) for p in personas]
    batches = build_extract_batches(inputs, DEFAULT_PACK.read_text(encoding="utf-8"))
    for p in write_extract_batches(batches, DEFAULT_OUT):
        print(p.name, len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks", f"~{-(-p.stat().st_size // 4)} tokens")
