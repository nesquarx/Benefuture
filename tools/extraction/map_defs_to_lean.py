import json
import os
import re

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/pseudocode_defs.json") as f:
    pseudo_defs = json.load(f)

lean_dir = "/Users/arko.sen/Desktop/BfTest/Benefuture/Benefuture"
lean_files = {}
for root, _, files in os.walk(lean_dir):
    for f in files:
        if f.endswith(".lean"):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, lean_dir)
            with open(path, "r", encoding="utf-8") as fp:
                lean_files[rel] = fp.read()

print(f"Total pseudocode def lines: {len(pseudo_defs)}")

def find_in_lean(query_list):
    results = []
    for rel, content in lean_files.items():
        for q in query_list:
            if not q: continue
            # match identifier
            m = re.findall(rf'\b{re.escape(q)}\b', content, re.IGNORECASE)
            if m:
                results.append((rel, q, len(m)))
    return results

mapped = []
unmapped = []

for item in pseudo_defs:
    lhs = item['lhs']
    # Extract terms/words from lhs
    words = re.findall(r'[A-Za-z0-9_]+', lhs)
    abbrs = [a[1] for a in item['abbrs']]
    search_terms = list(set(words + abbrs))
    
    hits = find_in_lean(search_terms)
    if hits:
        mapped.append((item, hits))
    else:
        unmapped.append((item, search_terms))

print(f"Mapped: {len(mapped)}")
print(f"Unmapped: {len(unmapped)}")
for u, s in unmapped:
    print(f"  Line {u['line']}: {u['lhs']} -> searched {s}")
