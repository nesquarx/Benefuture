#!/usr/bin/env python3
"""
Verify raw case data files, enforce as-of historical provenance without hand-typed credences,
and calculate/check SHA-256 checksums (docs/DATA.md §16d B2, finding 8.87).
"""

import csv
import datetime
import hashlib
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
CASES_DIR = REPO_ROOT / "cases"
CHECKSUM_FILE = Path(__file__).resolve().parent / "CHECKSUMS.sha256"

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def parse_date(d_str: str) -> datetime.date:
    # Handles ISO dates including negative or ancient years (e.g. 1377-07-27)
    parts = d_str.strip().split("-")
    if len(parts) == 3:
        return datetime.date(int(parts[0]), int(parts[1]), int(parts[2]))
    raise ValueError(f"Invalid date format: {d_str}")

def verify_case_provenance(toml_path: Path, csv_path: Path) -> bool:
    ok = True
    toml_text = toml_path.read_text(encoding="utf-8")

    # Guard: no typed credences in .toml (8.87: credences come from replayed records as-of, never entered by hand)
    if re.search(r"^\s*credence_accuracy\s*=", toml_text, re.MULTILINE):
        print(f"  [ERROR] {toml_path.name} contains hardcoded 'credence_accuracy'; must be replayed from records!")
        ok = False
    if re.search(r"^\s*pred_confidence\s*=", toml_text, re.MULTILINE):
        print(f"  [ERROR] {toml_path.name} contains hardcoded 'pred_confidence'; must be replayed from records!")
        ok = False

    # Extract decision date
    m_dec = re.search(r'decision_date\s*=\s*"([^"]+)"', toml_text)
    if not m_dec:
        print(f"  [ERROR] {toml_path.name} missing decision_date")
        return False
    dec_date = parse_date(m_dec.group(1))

    # Extract source IDs declared in TOML
    source_ids = set(re.findall(r'\[\[sources\]\][^\[]*?id\s*=\s*"([^"]+)"', toml_text, re.DOTALL))
    if not source_ids:
        print(f"  [ERROR] {toml_path.name} declares no [[sources]]")
        ok = False

    # Verify companion records CSV
    if not csv_path.exists():
        print(f"  [ERROR] Companion records file {csv_path.name} missing!")
        return False

    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        expected_fields = {"source_id", "record_id", "issue_date", "resolution_date", "as_of_date", "predicted", "outcome", "citation_with_page"}
        if not expected_fields.issubset(set(reader.fieldnames or [])):
            print(f"  [ERROR] {csv_path.name} missing required CSV columns; expected {expected_fields}")
            return False

        n_rows = 0
        sources_found = set()
        for idx, row in enumerate(reader, start=2):
            n_rows += 1
            src_id = row["source_id"].strip()
            sources_found.add(src_id)
            if src_id not in source_ids:
                print(f"  [ERROR] {csv_path.name}:{idx} unknown source_id '{src_id}' not declared in {toml_path.name}")
                ok = False

            try:
                as_of = parse_date(row["as_of_date"])
                iss = parse_date(row["issue_date"])
                res = parse_date(row["resolution_date"])
            except ValueError as e:
                print(f"  [ERROR] {csv_path.name}:{idx} invalid date: {e}")
                ok = False
                continue

            # Strict hindsight guard (Falsifier F4)
            if as_of > dec_date:
                print(f"  [ERROR] {csv_path.name}:{idx} hindsight leak: as_of_date {as_of} > decision_date {dec_date}")
                ok = False
            if iss > as_of:
                print(f"  [ERROR] {csv_path.name}:{idx} issue_date {iss} > as_of_date {as_of}")
                ok = False
            if res > as_of:
                print(f"  [ERROR] {csv_path.name}:{idx} resolution_date {res} > as_of_date {as_of}")
                ok = False

            citation = row.get("citation_with_page", "").strip()
            if not citation:
                print(f"  [ERROR] {csv_path.name}:{idx} missing citation_with_page")
                ok = False

        if n_rows == 0:
            print(f"  [ERROR] {csv_path.name} contains 0 records!")
            ok = False

        for sid in source_ids:
            if sid not in sources_found:
                print(f"  [ERROR] Source '{sid}' declared in {toml_path.name} has 0 records in {csv_path.name}")
                ok = False

    return ok

def verify_all(update_checksums: bool = False) -> bool:
    all_ok = True
    print(f"Verifying case files and provenance in {CASES_DIR}...")
    case_tomls = sorted(CASES_DIR.glob("*.toml"))
    if not case_tomls:
        print("ERROR: No .toml case files found!")
        return False

    all_files = []
    for toml_path in case_tomls:
        csv_path = toml_path.with_suffix(".records.csv")
        prov_ok = verify_case_provenance(toml_path, csv_path)
        if prov_ok:
            print(f"  [PROVENANCE OK] {toml_path.name} & {csv_path.name}")
        else:
            all_ok = False
        all_files.append(toml_path)
        if csv_path.exists():
            all_files.append(csv_path)

    all_files = sorted(all_files, key=lambda p: p.name)
    checksums = {f.name: sha256_file(f) for f in all_files}

    if update_checksums or not CHECKSUM_FILE.exists():
        print(f"\nWriting {len(checksums)} entries to {CHECKSUM_FILE}...")
        with open(CHECKSUM_FILE, "w", encoding="utf-8") as f:
            for name, digest in sorted(checksums.items()):
                f.write(f"{digest}  {name}\n")
        print("Checksums updated.")
    else:
        print(f"\nChecking against {CHECKSUM_FILE}...")
        with open(CHECKSUM_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
        expected = {}
        for line in lines:
            parts = line.strip().split()
            if len(parts) >= 2:
                expected[parts[1]] = parts[0]
        for name, digest in checksums.items():
            if name in expected:
                if expected[name] == digest:
                    print(f"  [OK] {name}")
                else:
                    print(f"  [MISMATCH] {name}: expected {expected[name]}, got {digest}")
                    all_ok = False
            else:
                print(f"  [NEW] {name} (not in checksum file)")
                all_ok = False

    return all_ok

if __name__ == "__main__":
    update = "--update" in sys.argv
    if not verify_all(update_checksums=update):
        sys.exit(1)
    print("\nAll cases and provenance verified successfully.")
