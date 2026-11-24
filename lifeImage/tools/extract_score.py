"""Score extract answers against the synthetic ground truth: a markdown report on stdout.

Usage: python3 lifeImage/tools/extract_score.py [data/batches/extract.v1.var{0,1,2}.answers.jsonl]
Each answers file is read with its batch file beside it (same name without `.answers`; the batch has the tasks and
the coarse pack). Answers are checked with `validate_answers`; invalid ones are listed and left out of the scores
(their personas count as nothing extracted), and the rest are completed into claimed evidence rows and scored per
channel (expertise, impact, potential) by lifeimage/extract_metrics.py against data/synthetic.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.extract import evidence_rows  # noqa: E402
from lifeimage.extract_metrics import compute, compute_variants, load_synthetic, render  # noqa: E402
from lifeimage.validate import validate_answers  # noqa: E402


def _lines(path):
    return [l for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def score_file(answers_path, cards, personas, truth, corroborated, basemap_version="0.0.0-draft"):
    """(report, invalid answer count, error lines) of one answers file."""
    answers_path = Path(answers_path)
    batch = _lines(answers_path.with_name(answers_path.name.replace(".answers", "")))
    answers = _lines(answers_path)
    errors = validate_answers(batch, answers)
    bad_lines = {int(e.split(":")[0].split()[1]) for e in errors if e.startswith("line ")}
    tasks = {t["task_id"]: t for t in (json.loads(l) for l in batch[1:])}
    extracted = {}
    for n, line in enumerate(answers, 1):
        a = json.loads(line)
        if n in bad_lines or a["task_id"] not in tasks:
            continue
        t = tasks[a["task_id"]]
        extracted[t["input"]["source"].split(":", 1)[1]] = evidence_rows(a, t["input"], basemap_version)
    return compute(extracted, truth, personas, cards, corroborated), len(bad_lines), errors


def main(argv):
    paths = argv or sorted(str(p) for p in (ROOT / "data/batches").glob("extract.v1.var*.answers.jsonl"))
    if not paths:
        sys.exit(__doc__)
    cards = [json.loads(l) for l in _lines(ROOT / "data/coarse/seed_v2.jsonl")]
    personas, truth, _texts, corroborated = load_synthetic(ROOT / "data/synthetic")
    reports = []
    for p in paths:
        report, invalid, errors = score_file(p, cards, personas, truth, corroborated)
        name = Path(p).name.split(".")[2]
        print(f"{name}: {invalid} invalid answer(s)" + ("" if not errors else "; first: " + errors[0]))
        reports.append(report)
    print()
    sys.stdout.write(render(compute_variants(reports)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
