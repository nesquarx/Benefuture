"""Fetch the open classification trees behind the gap candidates (coarse fields with no fine child) into data/fine/sources/.

Usage (from the repository root): python3 lifeImage/tools/fine_gap_fetch.py [--only wikidata getty_aat doid mondo onet bls_cex lcsh ...]
Each source is tried on its own and recorded in `data/fine/sources/network.json` (fetched with row counts, or blocked with
the reason); the rest continue. Fetched rows are the trimmed class rows of `lifeimage/fine/gap.py` (code, label, aliases,
description, broader, depth, target field). The generic client name of `lifeimage.sources.wikidata` is used.
"""
import argparse
import functools
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.fine import gap  # noqa: E402
from lifeimage.fine import sources as S  # noqa: E402
from lifeimage.sources.wikidata import http_fetch  # noqa: E402

OUT = ROOT / "data" / "fine" / "sources"
FETCH = functools.partial(http_fetch, retries=2, pause=0.3)
OBO = {"doid": ("https://purl.obolibrary.org/obo/doid.obo", gap.DOID_ROOTS),
       "mondo": ("https://purl.obolibrary.org/obo/mondo.obo", gap.MONDO_ROOTS)}
ONET_URL = "https://www.onetcenter.org/dl_files/database/db_31_0_csv/gwas_to_iwas.csv"


def patient_fetch(url, attempts=14, pause=3.0):
    """GET JSON from the Wikidata Query Service, honouring Retry-After in full (its outage mode allows one request a
    minute and answers 429 with waits of up to 1000 s); a timeout backs off 30 s. Fails loudly after `attempts`."""
    import time
    import urllib.error
    import urllib.request
    from lifeimage.sources.wikidata import USER_AGENT
    last = None
    for _ in range(attempts):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=75) as r:
                data = json.loads(r.read().decode("utf-8"))
            time.sleep(pause)
            return data
        except urllib.error.HTTPError as e:
            last = e
            wait = e.headers.get("Retry-After") if e.headers else None
            print(f"HTTP {e.code}; waiting {wait or 30}s", flush=True)
            time.sleep(min(1200, float(wait)) + 2 if wait and wait.isdigit() else 30)
        except (urllib.error.URLError, TimeoutError) as e:
            last = e
            print(f"{type(e).__name__}; waiting 30s", flush=True)
            time.sleep(30)
    raise last


def get_wikidata():
    import time
    fetch = functools.partial(http_fetch, retries=4, pause=1.0)
    rows, dropped, errors = gap.fetch_wikidata_gap_api(fetch, log=lambda m: print(m, flush=True))
    for _ in range(3):  # the API throttles bursts: the fields whose roots failed are fetched again, slowly
        failed = {e["root"] for e in errors if "root" in e}
        fields = sorted(f for f, rs in gap.WIKIDATA_ROOTS.items() if failed & set(rs))
        if not fields:
            break
        print("retrying", fields, flush=True)
        time.sleep(90)
        r2, d2, e2 = gap.fetch_wikidata_gap_api(fetch, roots={f: gap.WIKIDATA_ROOTS[f] for f in fields})
        rows = [r for r in rows if r["target"] not in fields] + r2
        dropped += d2
        errors = [e for e in errors if "root" not in e] + e2
    note = {"method": "MediaWiki API, direct subclasses, first 100 per root by search relevance (the Query Service answered 429 with waits of 1000 s; gap.fetch_wikidata_gap is the batched SPARQL alternative)", "dropped": len(dropped), "errors": errors[:10], "error_count": len(errors)}
    return rows, "https://www.wikidata.org/w/api.php (each root and its direct subclasses)", note


def get_getty():
    rows, errors = gap.fetch_getty_gap(FETCH)
    return rows, "https://vocab.getty.edu/sparql", {"errors": errors[:10], "error_count": len(errors)}


def _obo(name):
    url, roots = OBO[name]
    terms = gap.parse_obo(S.fetch_text(url).decode("utf-8"))
    return gap.obo_gap_rows(terms, roots), url, {"terms": len(terms)}


def get_onet():
    text = S.fetch_text(ONET_URL).decode("utf-8-sig")
    return gap.onet_rows(text), ONET_URL, {"release": "O*NET 31.0"}


def get_eurovoc():
    rows, errors = gap.fetch_eurovoc_gap(FETCH)
    return rows, gap.EUROVOC_SPARQL, {"errors": errors[:10], "error_count": len(errors)}


def get_lcsh():
    rows, errors = gap.fetch_lcsh_gap(FETCH)
    return rows, "https://id.loc.gov/authorities/subjects/label/", {"errors": errors[:10], "error_count": len(errors)}


def get_cex():
    """BLS Consumer Expenditure item table (one xlsx; openpyxl reads the indent that carries the hierarchy)."""
    import io
    import warnings

    import openpyxl
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        ws = openpyxl.load_workbook(io.BytesIO(S.fetch_text(gap.CEX_URL))).worksheets[0]
    items = [(int(r[0].alignment.indent or 0), str(r[0].value)) for r in ws.iter_rows() if r[0].value]
    return gap.cex_rows(items), gap.CEX_URL, {}


def get_nibrs():
    """FBI NIBRS offence codes: fbi.gov answers a script with an HTML block page (403, or 200 with a page that is not
    the PDF), so there is nothing to parse; recorded as blocked. No offence list is typed in from memory."""
    body = S.fetch_text("https://www.fbi.gov/file-repository/ucr/ucr-2019-1-nibrs-user-manua-093020.pdf", retries=1)
    if not body.startswith(b"%PDF"):
        raise RuntimeError("fbi.gov returned an HTML page instead of the NIBRS PDF (automated clients are blocked)")
    raise RuntimeError("the NIBRS PDF was fetched but no offence-code parser exists yet")


GETTERS = {"wikidata": get_wikidata, "getty_aat": get_getty, "doid": lambda: _obo("doid"), "mondo": lambda: _obo("mondo"),
           "onet": get_onet, "eurovoc": get_eurovoc, "lcsh": get_lcsh, "bls_cex": get_cex, "nibrs": get_nibrs}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", choices=sorted(GETTERS))
    a = ap.parse_args(argv)
    net_path = OUT / "network.json"
    net = json.loads(net_path.read_text()) if net_path.exists() else {}
    for name in a.only or sorted(GETTERS):
        try:
            rows, url, note = GETTERS[name]()
            S.write_jsonl(rows, OUT / f"{name}.jsonl")
            net[name] = {"status": "fetched", "url": url, "rows": len(rows), **note}
        except Exception as e:  # noqa: BLE001 - any failure is recorded loudly, never silent
            net[name] = {"status": "blocked", "url": name, "detail": f"{type(e).__name__}: {e}"[:300], "rows": 0}
        print(name, {k: v for k, v in net[name].items() if k != "errors"}, flush=True)
        net_path.write_text(json.dumps(net, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
