import re
import os

lean_dir = "/Users/arko.sen/Desktop/BfTest/Benefuture/Benefuture"
lean_files = {}
for root, _, files in os.walk(lean_dir):
    for f in files:
        if f.endswith(".lean"):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, lean_dir)
            with open(path, "r", encoding="utf-8") as fp:
                lean_files[rel] = fp.read()

queries = [
    "NecessaryHarm", "NHa",
    "ResourceAccounting", "RcAccounting", "RA",
    "onExec", "execution",
    "CausalDistribution", "CD",
    "BaselineIncome", "S_BaselnIncm", "SB",
    "squashed_synergy", "Ŝy",
    "calculate_relevance", "relevance",
    "Sophont", "Benesophont",
    "Preference", "Preferences"
]

for q in queries:
    hits = []
    for rel, content in lean_files.items():
        matches = re.findall(rf'(\b[^\n]*{re.escape(q)}[^\n]*)', content, re.IGNORECASE)
        if matches:
            hits.append((rel, len(matches), matches[0].strip()[:80]))
    print(f"\nQuery '{q}': {len(hits)} files matched")
    for rel, count, sample in hits:
        print(f"  {rel} ({count} hits): {sample}")
