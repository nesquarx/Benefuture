"""Check that every theorem README.md names exists, under that name, in the file it links to.
README links name theorems by ID and point at their file without line numbers, which drift.
Usage: python3 tools/check_readme_claims.py (exit status 1 on any missing theorem)."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# The README and the claims record it links to (docs/CLAIMS.md links with a ../ prefix).
text = (ROOT / "README.md").read_text() + "\n" + (ROOT / "docs" / "CLAIMS.md").read_text().replace("](../Benefuture/", "](Benefuture/")
missing = []
names = re.findall(r"\[`([^`]+)`\]\((Benefuture/[^)#]+\.lean)\)", text)
for name, path in names:
    source = (ROOT / path).read_text() if (ROOT / path).exists() else ""
    if not re.search(rf"^(theorem|lemma)\s+{re.escape(name)}\b", source, re.M):
        missing.append(f"{name} in {path}")
print("\n".join(missing) if missing else f"all {len(names)} named theorems found")
sys.exit(1 if missing else 0)
