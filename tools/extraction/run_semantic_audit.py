import os
import re
import json

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/all_abbreviations.json") as f:
    all_abbrs = json.load(f)

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

gdrive_dir = "/Users/arko.sen/Desktop/BfTest/gdrive/Benefuture"
articles = []
for fname in sorted(os.listdir(gdrive_dir)):
    if fname.endswith(".txt") and fname != "redirects.txt":
        articles.append(fname[:-4])

redirects = {}
with open(os.path.join(gdrive_dir, "redirects.txt"), "r") as f:
    for line in f:
        line = line.strip()
        if "->" in line:
            parts = line.split("->")
            src = parts[0].strip()
            tgt = parts[1].replace("#REDIRECT", "").replace(":", "").replace("[[", "").replace("]]", "").strip()
            redirects[src] = tgt

print(f"Loaded {len(all_abbrs)} abbreviations, {len(pseudo_defs)} pseudocode defs, {len(articles)} articles.")

# Check each definition
def_analysis = []
for pdef in pseudo_defs:
    lhs = pdef['lhs']
    rhs = pdef['rhs']
    line = pdef['line']
    
    # Identify key term name
    # e.g., "Reality«ℝ»" -> "Reality", "Synergy«Sy»" -> "Synergy", "Id(T)" -> "Identity", etc.
    m = re.match(r'^([A-Za-z0-9_]+)', lhs)
    base_term = m.group(1) if m else lhs
    
    # Search in Lean
    found_in = []
    for rel, content in lean_files.items():
        # Look for def / structure / theorem with base_term or variations
        if re.search(rf'\b{re.escape(base_term)}\b', content, re.IGNORECASE):
            found_in.append(rel)
    
    def_analysis.append({
        'line': line,
        'lhs': lhs,
        'rhs': rhs,
        'base_term': base_term,
        'found_in': found_in
    })

# Check abbreviations
abbr_analysis = []
for abbr, expanded in all_abbrs.items():
    found_abbr = []
    found_exp = []
    for rel, content in lean_files.items():
        if re.search(rf'\b{re.escape(abbr)}\b', content):
            found_abbr.append(rel)
        if re.search(rf'\b{re.escape(expanded)}\b', content, re.IGNORECASE):
            found_exp.append(rel)
    abbr_analysis.append({
        'abbr': abbr,
        'expanded': expanded,
        'found_abbr': found_abbr,
        'found_exp': found_exp,
        'has_presence': len(found_abbr) > 0 or len(found_exp) > 0
    })

# Check articles
art_analysis = []
for art in articles:
    is_redirect = art in redirects
    target = redirects.get(art, art)
    
    # search both art and target
    clean_names = list(set([art, target] + art.replace("-", " ").split() + target.replace("-", " ").split()))
    found = []
    for rel, content in lean_files.items():
        for cn in clean_names:
            if re.search(rf'\b{re.escape(cn)}\b', content, re.IGNORECASE):
                found.append(rel)
                break
    art_analysis.append({
        'article': art,
        'is_redirect': is_redirect,
        'target': target,
        'found_in': found,
        'has_presence': len(found) > 0
    })

result = {
    'defs': def_analysis,
    'abbrs': abbr_analysis,
    'articles': art_analysis
}

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/semantic_audit.json", "w") as out:
    json.dump(result, out, indent=2)

print("Semantic audit complete.")
