"""Public classifications as fine-candidate sources: fetchers (injected `fetch(url) -> dict`), parsers, licence status.

Every fetch carries the generic client name of `lifeimage.sources.wikidata` and no personal detail. Fetched material is
stored trimmed under `data/fine/sources/<source>.jsonl` (one row per class: code, label, aliases, description,
broader), so the pool rebuilds offline. A row is a class of a classification, never an individual record.

Licence status per source: `verified` (the licence statement was read on a primary page), `unverified` (believed, but
the pages read did not state it) or `restricted` (a reservation of rights was read; labels are kept as reference
names and the status travels with every candidate).
"""
import json
import re
import time
from pathlib import Path

LICENCES = {
    "wikidata": {"licence": "CC0 1.0", "status": "verified",
                 "evidence": "https://www.wikidata.org/wiki/Wikidata:Licensing (data/SOURCES_EVENTS.md)"},
    "openalex": {"licence": "CC0 1.0 (believed)", "status": "unverified",
                 "evidence": "licence not stated on the OpenAlex help pages read; snapshot LICENSE.txt not read"},
    "esco_isco": {"licence": "ESCO free reuse with attribution, believed CC BY 4.0", "status": "unverified",
                  "evidence": "ESCO download page read; it does not state the licence"},
    "esco_skills": {"licence": "ESCO free reuse with attribution, believed CC BY 4.0", "status": "unverified",
                    "evidence": "ESCO download page read; it does not state the licence"},
    "icatus": {"licence": "United Nations copyright, all rights reserved", "status": "restricted",
               "evidence": "Copyright line of the ICATUS 2016 publication (ST/ESA/STAT/SER.M/98); reference use only"},
    "atus": {"licence": "US government work, public domain (BLS: everything it publishes is in the public domain, except "
                        "previously copyrighted photographs and illustrations; credit requested)", "status": "verified",
             "evidence": "https://www.bls.gov/opub/copyright-information.htm (read 2026-11-25); lexicon https://www.bls.gov/tus/lexicons.htm"},
    "answers": {"licence": "project data", "status": "verified", "evidence": "cached answers of this repository"},
}
KINDS = {"openalex": "discipline", "esco_isco": "occupation", "esco_skills": "skill", "icatus": "activity"}
ESCO_API = "https://ec.europa.eu/esco/api/resource/{kind}?uri={uri}&language=en"
ATUS_URL = "https://www.bls.gov/tus/lexicons/lexiconnoex2025.pdf"
ICATUS_URL = "https://unstats.un.org/unsd/gender/timeuse/23012019%20ICATUS.pdf"
OPENALEX_URL = "https://api.openalex.org/subfields?per-page=200&page={page}"
ISCO_ROOTS = [f"http://data.europa.eu/esco/isco/C{i}" for i in range(10)]
SKILLS_ROOT = "http://data.europa.eu/esco/skill/S"


def _tail(uri):
    return uri.rstrip("/").rsplit("/", 1)[-1]


def parse_openalex_subfields(raw):
    return [{"code": _tail(r["id"]), "label": r["display_name"], "aliases": list(r.get("display_name_alternatives") or []),
             "description": (r.get("description") or "").replace("\n", " ").strip(),
             "broader": (r.get("field") or {}).get("display_name", "")} for r in raw]


def fetch_openalex_subfields(fetch):
    out, page = [], 1
    while True:
        d = fetch(OPENALEX_URL.format(page=page))
        out += d["results"]
        if len(out) >= d["meta"]["count"] or not d["results"]:
            return parse_openalex_subfields(out)
        page += 1


def crawl_esco(fetch, kind, root_uri, max_depth, _depth=0, _parent=""):
    """Preorder rows of an ESCO concept tree down to max_depth (the root is depth 0); narrower concepts by uri."""
    d = fetch(ESCO_API.format(kind=kind, uri=root_uri))
    label = d.get("title") or (d.get("preferredLabel") or {}).get("en", "")
    alt = d.get("alternativeLabel") or {}
    desc = ((d.get("description") or {}).get("en") or {}).get("literal", "")
    rows = [{"code": str(d.get("code") or _tail(d["uri"])), "label": label,
             "aliases": [a for a in (alt.get("en", []) if isinstance(alt, dict) else [])][:6],
             "description": re.sub(r"\s+", " ", desc)[:300].strip(), "broader": _parent, "depth": _depth}]
    if _depth < max_depth:
        for n in sorted(d.get("_links", {}).get("narrowerConcept", []), key=lambda n: n["uri"]):
            rows += crawl_esco(fetch, kind, n["uri"], max_depth, _depth + 1, label)
    return rows


_CODE = re.compile(r"^\s*(\d{1,3})\s{2,}(\S.*?)\s*$")
_NOTE_COLUMN = 80  # footnote text sits far to the right of the activity labels
_NOTE = re.compile(r"(?<=[A-Za-z])\d{1,2}$")  # a footnote marker glued to the label's last word


def _label(text):
    return _NOTE.sub("", re.split(r"\s{3,}", text.strip())[0])
_FURNITURE = re.compile(r"^(International Classification|Annex|Major|division|Division)", re.I)


def parse_icatus(text):
    """Divisions (2 digits) and groups (3 digits) of ICATUS 2016's complete classification, with wrapped labels
    joined and page furniture skipped. Nothing before `C. Complete classification` or after `D. Explanatory notes`."""
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if re.fullmatch(r"\s*C\. Complete classification\s*", l))
    stop = next((i for i in range(start, len(lines)) if re.fullmatch(r"\s*D\. Explanatory notes\s*", lines[i])), len(lines))
    recs, names = [], {}
    for l in lines[start + 1:stop]:
        if not l.strip():
            continue
        m = _CODE.match(l)
        indent = len(l) - len(l.lstrip())
        if m and not _FURNITURE.match(m.group(2)) and indent < _NOTE_COLUMN:
            recs.append({"code": m.group(1), "label": _label(m.group(2))})
        elif recs and not _FURNITURE.match(l.strip()) and 20 <= indent < _NOTE_COLUMN and not _CODE.match(l):
            recs[-1]["label"] += " " + _label(l)
    for r in recs:
        names[r["code"]] = r["label"]
    return [{"code": r["code"], "label": r["label"], "aliases": [], "description": "",
             "broader": names.get(r["code"][:-1], "")} for r in recs if len(r["code"]) in (2, 3)]


_ATUS_LINE = re.compile(r"^(\s*)(\d{2})\s{2,}(\S.*?)\s*$")
_ATUS_RESIDUAL = re.compile(r"n\.?e\.?c\.?\*?$|^waiting\b|\bwaiting (?:associated|related|assoc)|\bsecurity (?:procedures|related)", re.I)
_ATUS_SKIP_MAJOR = {"18": "travel is a context of an activity, not an activity", "50": "data codes name no activity"}
_ATUS_WORDS = [(r"\bnonhh\b", "non-household"), (r"\bhh\b", "household"), (r"\bsvcs\b", "services"), (r"\brel\.", "related"),
               (r"\bassoc\.", "associated"), (r"\bexc\.|\bex\b", "except"), (r"\binc\.", "including"), (r"\bw/(?=\w)", "with ")]


def _atus_label(text):
    text = re.sub(r"\s+", " ", text.replace("*", "")).strip()
    for pat, rep in _ATUS_WORDS:
        text = re.sub(pat, rep, text)
    return text.strip()


def parse_atus_lexicon(text, year=2025):
    """Major (depth 1), second-tier (2) and third-tier (3) categories of the BLS ATUS activity lexicon (text of
    `pdftotext -layout`, the version without activity examples). Codes concatenate the tiers (`01`, `0101`, `010102`).
    Residual categories (n.e.c.), waiting and security-procedure categories, travel (major 18: a context of an activity)
    and data codes (major 50) are not activities and are skipped; abbreviations are spelled out. Tiers are told apart by
    indentation; page numbers and headers carry no label and never match."""
    rows, major, second, skip = [], None, None, False
    names = {}
    for line in text.splitlines():
        m = _ATUS_LINE.match(line)
        if not m or "Lexicon" in line or "Categories" in line:
            continue
        indent, num, raw = len(m.group(1)), m.group(2), m.group(3)
        depth = 1 if indent < 10 else (2 if indent < 28 else 3)
        if depth == 1:
            major, second, skip = num, None, num in _ATUS_SKIP_MAJOR
            code = num
        elif depth == 2:
            second, code = num, f"{major}{num}"
        else:
            code = f"{major}{second}{num}"
        if major is None or (depth == 3 and second is None):
            continue
        label = _atus_label(raw)
        names[code] = label
        if skip or _ATUS_RESIDUAL.search(label):
            continue
        broader = names.get(code[:-2], "") if depth > 1 else ""
        rows.append({"code": code, "label": label, "aliases": [], "depth": depth, "broader": broader,
                     "description": f"ATUS {year} {('major', 'second-tier', 'third-tier')[depth - 1]} activity category"
                                    + (f" (under {broader})" if broader else "") + "."})
    if not rows:
        raise ValueError("no activity categories found in the lexicon text")
    return rows


def read_jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def write_jsonl(rows, path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("".join(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n" for r in rows), encoding="utf-8")


def fetch_text(url, retries=4):
    """GET a document as bytes (generic client name; back-off)."""
    import urllib.error
    import urllib.request
    from ..sources.wikidata import USER_AGENT
    last = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": USER_AGENT}), timeout=90) as r:
                return r.read()
        except (urllib.error.URLError, TimeoutError) as e:
            last = e
            time.sleep(2 ** attempt)
    raise last
