#!/usr/bin/env python3
"""Regenerate the synthetic personas' texts in realistic styles (texts v2) into data/synthetic/texts_v2/.

    python3 tools/gen_texts_v2.py          # writes texts_v2/<id>.{resume,self,diary}.txt, <id>.spans.json and truth_spans.jsonl
    python3 tools/gen_texts_v2.py --check  # regenerates in memory and compares with what is on disk

Texts only: the personas, rows, events and v1 texts come from the same generation as tools/gen_starter.py and are not
written here. `<id>.spans.json` maps each document to {row index in the persona's rows (data/synthetic/rows.jsonl order within
the persona): 1-based line number}; the v1 provenance spans refer to the v1 texts, these to the v2 texts.
`truth_spans.jsonl` maps each truth row (data/synthetic/truth/<id>.jsonl order) to the v2 line(s) that render it, or null
when the v2 text omits it; tools/extract_score.py --texts texts_v2 matches rows by it. Deterministic:
reruns are byte-identical.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_starter import AS_OF, PERSONAS  # noqa: E402
from lifeimage.generators import life  # noqa: E402
from lifeimage.generators.texts_v2 import render_texts_v2, truth_spans  # noqa: E402

OUT = ROOT / "data" / "synthetic" / "texts_v2"


def build():
    """{file name: text} of every v2 text and spans file."""
    files, n, records = {}, 0, []
    for arch, ages in PERSONAS:
        for age in ages:
            n += 1
            p = life.generate_persona(1000 + n, arch, age, as_of=AS_OF, pid=f"p{n:03d}")
            r = render_texts_v2(p)
            records += truth_spans(p, r)
            for kind, text in r.texts.items():
                files[f"{p.id}.{kind}.txt"] = text
            files[f"{p.id}.spans.json"] = json.dumps({"format": r.meta["format"], "embellished": r.meta["embellished"],
                                                      "spans": {d: {str(i): ln for i, ln in sorted(m.items())} for d, m in r.spans.items()}},
                                                     indent=1, sort_keys=True) + "\n"
    files["truth_spans.jsonl"] = "".join(json.dumps(x, sort_keys=True) + "\n" for x in records)
    return files


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    files = build()
    if ap.parse_args().check:
        bad = [k for k, v in files.items() if not (OUT / k).exists() or (OUT / k).read_text(encoding="utf-8") != v]
        extra = sorted(p.name for p in OUT.glob("*") if p.name not in files)
        sys.exit(f"stale or missing: {bad[:5]} extra: {extra[:5]}" if bad or extra else 0)
    OUT.mkdir(parents=True, exist_ok=True)
    for k, v in files.items():
        (OUT / k).write_text(v, encoding="utf-8")
    print(f"wrote {len(files)} files to {OUT}")
