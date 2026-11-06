"""Generate the "Index of references by article" section for docs/articles/Citations.txt from
docs/citations_index.json and docs/citations_annotations.json (relations are AI-annotated; the author's
text is unchanged). Re-running replaces the generated section.
Usage: python3 tools/wiki/citations_section.py"""
import json, pathlib, collections

ROOT = pathlib.Path(__file__).resolve().parents[2]
idx = json.loads((ROOT / "docs/citations_index.json").read_text())
ann = {a["i"]: a for a in json.loads((ROOT / "docs/citations_annotations.json").read_text())}
START, END = "<!-- BEGIN GENERATED INDEX -->", "<!-- END GENERATED INDEX -->"
by_art = collections.OrderedDict()
for i, r in enumerate(idx):
    if r["article"] == "Citations":
        continue
    by_art.setdefault(r["article"], []).append((i, r))
out = [START, "== Index of references by article ==",
       "''Generated from every reference in the articles (tools/wiki/citations_section.py). Each row names the source article and section, the claim the reference supports, and how it relates to Benefuture. The relation column is AI-annotated and may be imperfect; the references and claims are the articles' own.''", ""]
for art, rows in by_art.items():
    out += [f"=== [[{art}]] ===", '{| class="wikitable sortable"', "! Section !! Supports !! Reference !! Relation to Benefuture"]
    for i, r in rows:
        a = ann.get(i, {})
        sec = " › ".join(x for x in (r["section"], r["subsection"]) if x) or "(lead)"
        sup = (r["supports"] or "").replace("|", "&#124;")
        rel = f"'''{a.get('relation', '')}''' — {a.get('bf_link', '')}: {a.get('note', '')}".replace("|", "&#124;")
        out += ["|-", f"| {sec} || {sup} || {r['reference'].replace('|', '&#124;')} || {rel}"]
    out += ["|}", ""]
out.append(END)
p = ROOT / "docs/articles/Citations.txt"
t = p.read_text()
if START in t:
    t = t[:t.index(START)] + t[t.index(END) + len(END):]
p.write_text(t.rstrip() + "\n\n" + "\n".join(out) + "\n")
print(f"{sum(len(v) for v in by_art.values())} rows from {len(by_art)} articles")
