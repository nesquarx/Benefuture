"""Internal calibration data kept out of shipped files (LI.19).

ICATUS (United Nations copyright, all rights reserved) is a local benchmark: its codes and labels never ship. The
anchors of the coarse cards that cited it live in `data/calibration/icatus_anchors.jsonl` (gitignored), one row per card
`{"id", "anchors": [...]}`. Nothing in the pipeline needs them (no rule, hash or task reads an anchor's source), so a
missing file only costs the calibration view and is recorded loudly.
"""
import json
from pathlib import Path

from ..degradation import record_degradation

ROOT = Path(__file__).resolve().parent.parent.parent
CALIBRATION_ICATUS = ROOT / "data" / "calibration" / "icatus_anchors.jsonl"


def icatus_anchors(path=CALIBRATION_ICATUS, log=None):
    """{card id: [ICATUS anchors]} from the local calibration file; {} (recorded as a degradation) when it is absent."""
    p = Path(path)
    if not p.exists():
        record_degradation("calibration", "icatus calibration anchors", "none (empty mapping)",
                           f"{p} is absent; ICATUS anchors are local calibration data, never shipped (LI.19)", log=log)
        return {}
    rows = [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]
    return {r["id"]: r["anchors"] for r in rows}


def split_icatus_anchors(files, out=CALIBRATION_ICATUS):
    """Move every anchor with source `icatus` from the JSONL card files into the calibration file (merged with what it
    already holds, deduplicated by code and label); other anchors stay. Returns the number of anchors moved."""
    held = {}
    out = Path(out)
    if out.exists():
        held = {r["id"]: r["anchors"] for r in map(json.loads, filter(str.strip, out.read_text(encoding="utf-8").splitlines()))}
    moved = 0
    for f in map(Path, files):
        lines, changed = [], False
        for line in f.read_text(encoding="utf-8").splitlines(keepends=True):
            if line.strip():
                row = json.loads(line)
                ic = [a for a in row.get("anchors", []) if a.get("source") == "icatus"]
                if ic:
                    row["anchors"] = [a for a in row["anchors"] if a.get("source") != "icatus"]
                    cur = held.setdefault(row["id"], [])
                    cur += [a for a in ic if a not in cur]
                    moved += len(ic)
                    changed = True
                    line = json.dumps(row, ensure_ascii=False) + "\n"
            lines.append(line)
        if changed:
            f.write_text("".join(lines), encoding="utf-8")
    if moved:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("".join(json.dumps({"id": i, "anchors": a}, ensure_ascii=False, sort_keys=True) + "\n"
                               for i, a in sorted(held.items())), encoding="utf-8")
    return moved
