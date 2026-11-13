#!/usr/bin/env python3
"""
Fetch and extract M4 competition point-forecast method benchmarks (61 submissions + benchmarks)
from Mcompetitions/M4-methods `Evaluation and Ranks.xlsx` into `cases/calibration_sample/m4_methods_benchmark.csv`
for Benefuture E2 model-pool cross-check (`docs/DATA.md` Prioritised plan #1).
"""

from __future__ import annotations

import argparse
import csv
import io
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

XLSX_URL = "https://raw.githubusercontent.com/Mcompetitions/M4-methods/master/Evaluation%20and%20Ranks.xlsx"
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_OUT = REPO_ROOT / "cases" / "calibration_sample" / "m4_methods_benchmark.csv"


def extract_m4_rows(xlsx_bytes: bytes) -> list[dict]:
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(io.BytesIO(xlsx_bytes)) as z:
        ss_root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        strings = ["".join(si.itertext()) for si in ss_root.findall("m:si", ns)]
        sheet = ET.fromstring(z.read("xl/worksheets/sheet2.xml"))

    raw_rows = []
    for row in sheet.findall(".//m:row", ns):
        vals = []
        for c in row.findall("m:c", ns):
            v = c.find("m:v", ns)
            if v is None:
                vals.append("")
            elif c.attrib.get("t") == "s":
                vals.append(strings[int(v.text)])
            else:
                vals.append(v.text or "")
        raw_rows.append(vals)

    naive2_smape = None
    naive2_mase = None
    parsed = []
    for r in raw_rows[2:]:
        if len(r) < 22 or not r[0].strip():
            continue
        method = r[0].strip()
        try:
            smape = float(r[7])
            mase = float(r[14])
            owa = float(r[21])
        except ValueError:
            continue
        if method == "Naive2":
            naive2_smape = smape
            naive2_mase = mase
        parsed.append({"method": method, "smape": smape, "mase": mase, "owa": owa})

    assert naive2_smape is not None and naive2_mase is not None, "Naive2 benchmark row not found"
    out = []
    for p in parsed:
        out.append({
            "method": p["method"],
            "smape": f"{p['smape']:.6f}",
            "naive_smape": f"{naive2_smape:.6f}",
            "mase": f"{p['mase']:.6f}",
            "naive_mase": f"{naive2_mase:.6f}",
            "ratio": f"{p['owa']:.6f}",
        })
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch M4 competition benchmark table CSV")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    req = urllib.request.Request(
        XLSX_URL,
        headers={"User-Agent": "BenefutureResearch/1.0 (https://github.com/nesquarx/Benefuture)"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()

    rows = extract_m4_rows(data)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["method", "smape", "naive_smape", "mase", "naive_mase", "ratio"])
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} M4 benchmark methods to {args.out}")


if __name__ == "__main__":
    main()

