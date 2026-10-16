import re
import json

pseudocode_path = "/Users/arko.sen/Desktop/BfTest/Bf_Pseudocode.txt"
with open(pseudocode_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

definitions = []
current_section = "Root"

for idx, line in enumerate(lines):
    raw = line.strip()
    if not raw:
        continue
    if raw.startswith("§"):
        current_section = raw.split(":")[0].strip()
        continue
    
    # Check for := or ::
    if ":=" in raw or "::" in raw:
        # split by := or ::
        if "::" in raw:
            parts = raw.split("::", 1)
            op = "::"
        else:
            parts = raw.split(":=", 1)
            op = ":="
        lhs = parts[0].strip()
        rhs = parts[1].strip()
        # Find any abbreviation in lhs
        abbr_m = re.findall(r'([A-Za-z0-9_]+)\s*«\s*([^»]+)\s*»', lhs)
        definitions.append({
            'line': idx + 1,
            'section': current_section,
            'lhs': lhs,
            'op': op,
            'rhs': rhs,
            'abbrs': abbr_m,
            'raw': raw
        })
    elif raw.startswith("Priority") or raw.startswith("Bounds_B") or raw.startswith("Priorities:"):
        definitions.append({
            'line': idx + 1,
            'section': current_section,
            'lhs': raw.split(":")[0].strip(),
            'op': ":",
            'rhs': ":".join(raw.split(":")[1:]).strip(),
            'abbrs': [],
            'raw': raw
        })

print(f"Mechanically extracted {len(definitions)} defined terms/structures from pseudocode.")
for d in definitions:
    print(f"[Line {d['line']:3d}] {d['section']:12s} | {d['lhs']} {d['op']} {d['rhs'][:60]}")

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/pseudocode_defs.json", "w") as out:
    json.dump(definitions, out, indent=2)
