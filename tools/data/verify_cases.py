#!/usr/bin/env python3
"""
Verify raw case data files and calculate SHA-256 checksums (docs/DATA.md §16d B2, finding 8.87).
"""

import hashlib
import os
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

def verify_all() -> bool:
    all_ok = True
    print(f"Verifying case files in {CASES_DIR}...")
    case_files = sorted(CASES_DIR.glob("*.toml"))
    if not case_files:
        print("ERROR: No .toml case files found!")
        return False

    checksums = {}
    for cf in case_files:
        digest = sha256_file(cf)
        checksums[cf.name] = digest
        print(f"  {cf.name}: {digest}")

    if CHECKSUM_FILE.exists():
        print(f"\nChecking against {CHECKSUM_FILE}...")
        with open(CHECKSUM_FILE, "r") as f:
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
    else:
        print(f"\nCreating {CHECKSUM_FILE}...")
        with open(CHECKSUM_FILE, "w") as f:
            for name, digest in checksums.items():
                f.write(f"{digest}  {name}\n")
        print(f"Wrote {len(checksums)} entries to {CHECKSUM_FILE}")

    return all_ok

if __name__ == "__main__":
    if not verify_all():
        sys.exit(1)
    print("\nAll cases verified successfully.")

