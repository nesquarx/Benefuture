import json

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/semantic_audit.json") as f:
    audit = json.load(f)

print("=== DEFS WITHOUT FOUND_IN ===")
for d in audit['defs']:
    if not d['found_in']:
        print(f"  Line {d['line']}: {d['lhs']} -> term: {d['base_term']}")

print("\n=== ABBRS WITHOUT HAS_PRESENCE ===")
for a in audit['abbrs']:
    if not a['has_presence']:
        print(f"  «{a['abbr']}» : {a['expanded']}")

print("\n=== ARTICLES WITHOUT HAS_PRESENCE ===")
for art in audit['articles']:
    if not art['has_presence']:
        print(f"  Article: {art['article']} (redirect: {art['is_redirect']}, target: {art['target']})")
