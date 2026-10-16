import re
import os
import json

pseudocode_path = "/Users/arko.sen/Desktop/BfTest/Bf_Pseudocode.txt"
gdrive_dir = "/Users/arko.sen/Desktop/BfTest/gdrive/Benefuture"

with open(pseudocode_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Extract all abbreviations: Term«Abbr»
abbr_pattern = re.compile(r'([A-Za-z0-9_]+)\s*«\s*([^»]+)\s*»')
abbr_matches = abbr_pattern.findall(text)
abbreviations = {}
for term, abbr in abbr_matches:
    abbreviations[abbr.strip()] = term.strip()

print(f"Total abbreviations found: {len(abbr_matches)}")
for abbr, term in sorted(abbreviations.items()):
    print(f"  «{abbr}» : {term}")

# 2. Extract defined terms (lines with := or ::, or in §Sets, §Af_Axioms, §Priorities, etc.)
lines = text.splitlines()

defined_terms = []

# Pattern for assignment: e.g. "Name := ..." or "Name(args) := ..." or "Name :: ..."
def_pattern = re.compile(r'^\s*([A-Za-z0-9_«»]+(?:\([^\)]*\))?(?:_\{[^\}]+\}|_[A-Za-z0-9_«»]+)?)\s*(?::=|::|:)\s*(.*)')

# Let's inspect each line
for line_idx, line in enumerate(lines):
    line_clean = line.strip()
    if not line_clean or line_clean.startswith('//'):
        continue
    # Check for := or ::
    m = re.search(r'([A-Za-z0-9_«»]+(?:\([^\)]*\))?(?:_\{[^\}]+\}|_[A-Za-z0-9_«»]+)?)\s*(:=|::)\s*(.*)', line_clean)
    if m:
        lhs = m.group(1).strip()
        op = m.group(2)
        rhs = m.group(3).strip()
        defined_terms.append({
            'line': line_idx + 1,
            'lhs': lhs,
            'op': op,
            'rhs': rhs,
            'raw': line_clean
        })

print(f"\nTotal defined terms via := / :: found: {len(defined_terms)}")
for d in defined_terms:
    print(f"  Line {d['line']}: {d['lhs']} {d['op']} {d['rhs'][:50]}...")

# 3. Extract article names from gdrive/Benefuture
articles = []
for fname in sorted(os.listdir(gdrive_dir)):
    if fname.endswith(".txt") and fname != "redirects.txt":
        art_name = fname[:-4]
        articles.append(art_name)

print(f"\nTotal article files found: {len(articles)}")
for a in articles:
    print(f"  Article: {a}")
