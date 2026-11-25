"""Build the interactive Life Image viewers: self-contained HTML, one file per image, plus an index.

Usage (from the repository root): python3 lifeImage/tools/render_interactive.py [--out lifeImage/data/images/interactive]
Writes 3 synthetic personas, 1 synthetic organisation and 1 public figure at disclosure `full`, the first persona again
at `summary` and `none`, a team of four personas as a group image, one comparison, and `index.html`. Disclosure is fixed
at build time: a file built at `none` does not contain labels, ids or rows. Deterministic: the same data gives
byte-identical files. Runs no model.
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.render import interactive as it  # noqa: E402


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    files = it.build_all(it.context())
    for name, text in files.items():
        (out / name).write_text(text, encoding="utf-8")
    biggest = max(files, key=lambda n: len(files[n]))
    print(f"{len(files)} files, {sum(len(t.encode()) for t in files.values()) / 1e6:.2f} MB; largest {biggest} "
          f"{len(files[biggest].encode()) / 1e6:.2f} MB")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "data/images/interactive")
    main(ap.parse_args().out)
