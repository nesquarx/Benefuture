import os
import re
import json

pseudocode_path = "/Users/arko.sen/Desktop/BfTest/Bf_Pseudocode.txt"
lean_dir = "/Users/arko.sen/Desktop/BfTest/Benefuture/Benefuture"
gdrive_dir = "/Users/arko.sen/Desktop/BfTest/gdrive/Benefuture"

with open(pseudocode_path, "r", encoding="utf-8") as f:
    pseudo_text = f.read()

# Load all Lean code
lean_files = {}
for root, _, files in os.walk(lean_dir):
    for f in files:
        if f.endswith(".lean"):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, lean_dir)
            with open(path, "r", encoding="utf-8") as fp:
                lean_files[rel] = fp.read()

# 1. Abbreviations from pseudocode
abbr_matches = re.findall(r'([A-Za-z0-9_]+)\s*«\s*([^»]+)\s*»', pseudo_text)
abbr_dict = {}
for term, abbr in abbr_matches:
    abbr_dict[abbr.strip()] = term.strip()

# 2. Extract definitions from pseudocode
# Look at every definition in §Sets, §Defs, §Af_Axioms
lines = pseudo_text.splitlines()

# Explicit definitions
# Also identify terms in §Taxonomy and §Sets
taxonomy_sections = {}
current_sec = None
for line in lines:
    line_s = line.strip()
    if line_s.startswith("§"):
        current_sec = line_s
    elif current_sec and "Taxonomy" in current_sec:
        m = re.match(r'^\s*([A-Za-z0-9_]+)\s*:\s*\{([^}]+)\}', line_s)
        if m:
            cat = m.group(1)
            items = [x.strip() for x in m.group(2).split(',') if x.strip()]
            taxonomy_sections[cat] = items

print("Taxonomy categories extracted:")
for k, v in taxonomy_sections.items():
    print(f"  {k}: {v}")

# Mechanical search for terms in Lean
def search_lean(term_patterns):
    matches = {}
    for rel, content in lean_files.items():
        found = []
        for pat in term_patterns:
            # Match word boundary or case variations
            # e.g. pat as exact word or camelCase / snake_case
            reg = re.compile(rf'\b{re.escape(pat)}\b', re.IGNORECASE)
            m = reg.findall(content)
            if m:
                found.append(pat)
        if found:
            matches[rel] = list(set(found))
    return matches

# Check abbreviations in Lean
abbr_report = []
for abbr, term in sorted(abbr_dict.items()):
    hits = search_lean([term, abbr])
    abbr_report.append({
        'abbr': abbr,
        'term': term,
        'hits': list(hits.keys()),
        'hit_count': sum(len(v) for v in hits.values())
    })

# Check articles in Lean
articles = []
for fname in sorted(os.listdir(gdrive_dir)):
    if fname.endswith(".txt") and fname != "redirects.txt":
        articles.append(fname[:-4])

article_report = []
for art in articles:
    # simplify name
    clean_art = art.replace("-", " ")
    words = clean_art.split()
    hits = search_lean([clean_art] + words)
    article_report.append({
        'article': art,
        'hits': list(hits.keys())
    })

output = {
    'total_abbreviations': len(abbr_dict),
    'abbreviations': abbr_report,
    'total_articles': len(articles),
    'articles': article_report
}

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/coverage_report.json", "w", encoding="utf-8") as out:
    json.dump(output, out, indent=2)

print("\nAnalysis complete. Report written to coverage_report.json.")
