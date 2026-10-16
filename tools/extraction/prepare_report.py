import json
import os
import re

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/all_abbreviations.json") as f:
    all_abbrs = json.load(f)

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/pseudocode_defs.json") as f:
    pseudo_defs = json.load(f)

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

print(f"Defs: {len(pseudo_defs)}, Abbrs: {len(all_abbrs)}, Articles: {len(articles)}")

# We will generate a structured dictionary that will be rendered into the final artifact
summary_data = {
    'defs_count': len(pseudo_defs),
    'abbrs_count': len(all_abbrs),
    'articles_count': len(articles),
    'defs': pseudo_defs,
    'abbrs': all_abbrs,
    'articles': [{'name': a, 'is_redirect': a in redirects, 'target': redirects.get(a, a)} for a in articles]
}

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/summary_data.json", "w") as out:
    json.dump(summary_data, out, indent=2)

print("Summary data saved.")
