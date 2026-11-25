"""Write the extract v1 batches over the synthetic personas' resumes: 3 variants in data/batches (no model is run).

Usage (from the repository root): python3 lifeImage/tools/build_extract_batches.py [--texts texts_v2] [--out DIR]
Writing a set removes the answers files beside it: they answered the texts it replaces.
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

def main(argv=None):
    argv = sys.argv[1:] if argv is None else list(argv)
    texts, out = "texts", DEFAULT_OUT
    if "--texts" in argv:  # e.g. --texts texts_v2 writes to data/batches/texts_v2/ so v1 batches stay intact
        texts = argv[argv.index("--texts") + 1]
        out = DEFAULT_OUT / texts
    if "--out" in argv:
        out = Path(argv[argv.index("--out") + 1])
    personas = [json.loads(l) for l in (SYNTHETIC / "personas.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    inputs = [resume_input(p, (SYNTHETIC / texts / f"{p['id']}.resume.txt").read_text(encoding="utf-8")) for p in personas]
    batches = build_extract_batches(inputs, DEFAULT_PACK.read_text(encoding="utf-8"))
    paths = write_extract_batches(batches, out)
    for stale in sorted(out.glob("extract.v1.var*.answers.jsonl")):  # answers to the texts the batches replace
        stale.unlink()
        print(f"removed {stale.name}: it answered the previous texts and must not be scored against these", file=sys.stderr)
    for p in paths:
        print(p.name, len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks", f"~{-(-p.stat().st_size // 4)} tokens")


if __name__ == "__main__":
    main()
