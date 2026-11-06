"""Extract every <ref> in docs/articles/*.txt with its source article, section and subsection, and the
sentence it supports. Named refs (<ref name="x">...</ref>) are resolved where reused (<ref name="x"/>).
Writes docs/citations_index.json. Usage: python3 tools/wiki/extract_refs.py"""
import json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART = ROOT / "docs" / "articles"
REF = re.compile(r'<ref(?:\s+name\s*=\s*"?([^">/]+)"?)?\s*(?:/>|>(.*?)</ref>)', re.S)
HEAD = re.compile(r"^(={2,6})\s*(.*?)\s*\1\s*$")

def clean(t):
    t = re.sub(r"\s+", " ", t or "").strip()
    return re.sub(r"<nowiki>|</nowiki>", "", t)

out = []
for path in sorted(ART.glob("*.txt")):
    if path.name.startswith("_"):
        continue
    text = path.read_text(errors="replace")
    named = {m.group(1).strip(): clean(m.group(2)) for m in REF.finditer(text) if m.group(1) and m.group(2)}
    # section/subsection by line
    heads, pos = [], 0
    for line in text.splitlines(keepends=True):
        h = HEAD.match(line.strip())
        if h:
            heads.append((pos, len(h.group(1)), h.group(2)))
        pos += len(line)
    for m in REF.finditer(text):
        name, body = (m.group(1) or "").strip(), clean(m.group(2))
        if not body and name in named:
            body = named[name]
        sec = sub = ""
        for p, lvl, title in heads:
            if p > m.start():
                break
            if lvl == 2:
                sec, sub = title, ""
            else:
                sub = title
        before = re.sub(REF, "", text[:m.start()])[-600:].rstrip()
        sentence = clean(re.split(r"(?<=[.!?])\s+|\n\n|----", before)[-1])[-300:]
        out.append({"article": path.stem, "section": sec, "subsection": sub, "name": name,
                    "reference": body, "supports": sentence,
                    "doi_or_url": (re.findall(r"https?://\S+|doi\.org/\S+", body) or [""])[0].rstrip("]).,")})
(ROOT / "docs" / "citations_index.json").write_text(json.dumps(out, ensure_ascii=False, indent=1))
uniq = {r["reference"] for r in out if r["reference"]}
print(f"{len(out)} reference uses in {len({r['article'] for r in out})} articles; {len(uniq)} distinct references")
