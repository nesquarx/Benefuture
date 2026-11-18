#!/usr/bin/env python3
"""Fetch what each linked reference says, so relevance can be checked against the sentence it supports.

For every distinct reference in docs/citations_index.json with a link: DOIs -> OpenAlex abstract (Crossref
abstract as fallback); Open Library works -> description and subjects; Wikipedia -> lead extract. Output:
docs/citations_content.json, keyed like docs/citations_annotations.json (by reference text). Content the
sources do not expose is recorded as missing, never guessed."""
import json, re, ssl, subprocess, sys, time, urllib.request, urllib.parse, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
UA = {"User-Agent": "benefuture-citation-check/1.0"}
_USE_CURL = False
def get(url):
    global _USE_CURL
    err = None
    for i in range(3):
        if _USE_CURL:
            p = subprocess.run(
                ["/usr/bin/curl", "-sSL", "--max-time", "20", "-A", UA["User-Agent"], "-w", "\n%{http_code}", url],
                capture_output=True, text=True,
            )
            if p.returncode == 0:
                body, _, code = p.stdout.rpartition("\n")
                if code == "200":
                    try: return json.loads(body)
                    except Exception as je: return {"_error": str(je)}
                if code.startswith("4") and code != "429":
                    return {"_error": f"HTTP {code}"}
                err = RuntimeError(f"HTTP {code}")
            else:
                err = RuntimeError(p.stderr.strip() or f"curl exit {p.returncode}")
            time.sleep(2 ** i)
            continue
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            err = e
            reason = getattr(e, "reason", e)
            if isinstance(e, urllib.error.HTTPError) and 400 <= e.code < 500 and e.code != 429:
                return {"_error": str(e)}
            if isinstance(e, ssl.SSLError) or isinstance(reason, ssl.SSLError) or "CERTIFICATE_VERIFY_FAILED" in str(e):
                _USE_CURL = True
                continue
            time.sleep(2 ** i)
    return {"_error": str(err)}
def openalex(doi):
    d = get("https://api.openalex.org/works/doi:" + urllib.parse.quote(doi) + "?select=title,abstract_inverted_index,primary_location,concepts")
    if "_error" in d: return None
    inv = d.get("abstract_inverted_index") or {}
    words = sorted(((p, w) for w, ps in inv.items() for p in ps))
    ab = " ".join(w for _, w in words)
    concepts = [c["display_name"] for c in (d.get("concepts") or [])[:8]]
    return {"title": d.get("title"), "abstract": ab, "concepts": concepts}
def crossref(doi):
    d = get("https://api.crossref.org/works/" + urllib.parse.quote(doi))
    m = d.get("message", {}) if isinstance(d, dict) else {}
    ab = re.sub(r"<[^>]+>", " ", m.get("abstract", "") or "")
    return {"title": (m.get("title") or [""])[0], "abstract": " ".join(ab.split())}
def openlibrary(url):
    path = urllib.parse.urlparse(url).path.rstrip("/")
    d = get("https://openlibrary.org" + path + ".json")
    if "_error" in d: return None
    desc = d.get("description", "")
    if isinstance(desc, dict): desc = desc.get("value", "")
    concepts = (d.get("subjects") or [])[:12]
    title = d.get("title")
    if not desc and path.startswith("/isbn/") and d.get("works"):
        wpath = d["works"][0].get("key", "")
        if wpath:
            wd = get("https://openlibrary.org" + wpath + ".json")
            if "_error" not in wd:
                wdesc = wd.get("description", "")
                if isinstance(wdesc, dict): wdesc = wdesc.get("value", "")
                desc = desc or wdesc
                concepts = concepts or (wd.get("subjects") or [])[:12]
                title = title or wd.get("title")
    return {"title": title, "abstract": desc, "concepts": concepts}
def wikipedia(url):
    t = urllib.parse.unquote(url.split("/wiki/")[-1])
    d = get("https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&format=json&titles=" + urllib.parse.quote(t))
    pages = d.get("query", {}).get("pages", {}) if isinstance(d, dict) else {}
    p = next(iter(pages.values()), {})
    return {"title": p.get("title"), "abstract": (p.get("extract") or "")[:3000]}
def is_api_link(link):
    return bool(re.search(r"doi\.org/10\.\S+", link)) or "openlibrary.org" in link or "wikipedia.org/wiki/" in link
def main():
    idx = json.load(open(ROOT / "docs/citations_index.json"))
    out_p = ROOT / "docs/citations_content.json"
    out = json.load(open(out_p)) if out_p.exists() else {}
    refs = {}
    for r in idx:
        if r.get("doi_or_url"): refs.setdefault(r["reference"], r["doi_or_url"])
    delta = 0
    for ref, link in refs.items():
        prev = out.get(ref)
        if prev and prev.get("link") == link:
            src = prev.get("source")
            if src == "fetched":
                continue
            if src == "missing" and ("title" in prev or prev.get("checked") or not is_api_link(link)):
                continue
        delta += 1
        c = None
        m = re.search(r"doi\.org/(10\.\S+)", link)
        if m:
            doi = m.group(1).rstrip(".,;)")
            c = openalex(doi)
            if not c or not c.get("abstract"):
                cr = crossref(doi)
                c = {**(c or {}), **{k: v for k, v in cr.items() if v}}
        elif "openlibrary.org" in link: c = openlibrary(link)
        elif "wikipedia.org/wiki/" in link: c = wikipedia(link)
        c = c or {}
        c["link"] = link
        c["checked"] = True
        c["source"] = "missing" if not c.get("abstract") else "fetched"
        out[ref] = c
        time.sleep(0.15)
    json.dump(out, open(out_p, "w"), indent=1, ensure_ascii=False, sort_keys=True)
    n = len(out); k = sum(1 for v in out.values() if v.get("abstract"))
    print(f"checked {delta} delta references ({k}/{n} linked references with content; {n-k} missing)")
main()
