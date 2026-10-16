import json
import re

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/coverage_report.json") as f:
    report = json.load(f)

print("=== ABBREVIATIONS & LEAN COVERAGE ===")
uncovered_abbrs = []
covered_abbrs = []
for item in report['abbreviations']:
    abbr = item['abbr']
    term = item['term']
    hits = item['hits']
    if not hits:
        uncovered_abbrs.append((abbr, term))
    else:
        covered_abbrs.append((abbr, term, hits))

print(f"Total Abbreviations: {len(report['abbreviations'])}")
print(f"Covered Abbreviations: {len(covered_abbrs)}")
print(f"Uncovered Abbreviations ({len(uncovered_abbrs)}):")
for abbr, term in uncovered_abbrs:
    print(f"  «{abbr}» : {term}")

print("\n=== ARTICLES & LEAN COVERAGE ===")
uncovered_arts = []
covered_arts = []
for item in report['articles']:
    art = item['article']
    hits = item['hits']
    if not hits:
        uncovered_arts.append(art)
    else:
        covered_arts.append((art, hits))

print(f"Total Articles: {len(report['articles'])}")
print(f"Covered Articles: {len(covered_arts)}")
print(f"Uncovered Articles ({len(uncovered_arts)}):")
for art in uncovered_arts:
    print(f"  Article: {art}")
