"""Fetch the sources of the second gap set (lifeimage/fine/gap2.py) into data/fine/sources/gap2/ (the first gap set's files stay).

Usage: python3 lifeImage/tools/fine_gap2_fetch.py [--only wikidata lcsh doid]
Each source is recorded in data/fine/sources/gap2/network.json (fetched with rows, or blocked with the reason).
"""
import argparse
import functools
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.fine import gap, gap2  # noqa: E402
from lifeimage.fine import sources as S  # noqa: E402
from lifeimage.sources.wikidata import http_fetch  # noqa: E402

OUT = ROOT / "data" / "fine" / "sources" / "gap2"
FETCH = functools.partial(http_fetch, retries=2, pause=0.3)
OBO = {"doid": ("https://purl.obolibrary.org/obo/doid.obo", gap2.DOID_ROOTS)}


def refetch_fields(fields):
    """Fetch again only `fields` (with their own sitelink floor, gap2.MIN_SITELINKS) and replace their rows in wikidata.jsonl."""
    fetch = functools.partial(http_fetch, retries=4, pause=1.0)
    old = [r for r in S.read_jsonl(OUT / "wikidata.jsonl") if r["target"] not in fields]
    new = []
    for f in fields:
        r, _, e = gap.fetch_wikidata_gap_api(fetch, roots={f: gap2.WIKIDATA_ROOTS[f]}, cap=gap2.CAP,
                                             min_sitelinks=gap2.MIN_SITELINKS.get(f, gap.MIN_SITELINKS))
        new += r
        print(f, len(r), "rows", len(e), "errors", flush=True)
    S.write_jsonl(old + [r for r in new if r["label"].lower() not in gap2.SKIP_LABELS], OUT / "wikidata.jsonl")


def get_wikidata():
    import time
    fetch = functools.partial(http_fetch, retries=4, pause=1.0)
    rows, _, errors = gap.fetch_wikidata_gap_api(fetch, roots=gap2.WIKIDATA_ROOTS, cap=gap2.CAP, log=lambda m: print(m, flush=True))
    for _ in range(3):  # throttled roots are fetched again, slowly
        failed = {e["root"] for e in errors if "root" in e}
        fields = sorted(f for f, rs in gap2.WIKIDATA_ROOTS.items() if failed & set(rs))
        if not fields:
            break
        print("retrying", fields, flush=True)
        time.sleep(60)
        r2, _, e2 = gap.fetch_wikidata_gap_api(fetch, roots={f: gap2.WIKIDATA_ROOTS[f] for f in fields}, cap=gap2.CAP)
        rows = [r for r in rows if r["target"] not in fields] + r2
        errors = [e for e in errors if "root" not in e] + e2
    rows = [r for r in rows if r["label"].lower() not in gap2.SKIP_LABELS]
    return rows, gap.API, {"method": "MediaWiki API, root and direct subclasses, first 100 per root", "errors": errors[:10], "error_count": len(errors)}


def get_lcsh():
    rows, errors = gap.fetch_lcsh_gap(FETCH, roots=gap2.LCSH_ROOTS, cap=6)
    return rows, gap.LCSH_URL, {"errors": errors[:10], "error_count": len(errors)}


def _obo(name):
    url, roots = OBO[name]
    terms = gap.parse_obo(S.fetch_text(url).decode("utf-8"))
    return gap.obo_gap_rows(terms, roots), url, {"terms": len(terms)}


GETTERS = {"wikidata": get_wikidata, "lcsh": get_lcsh, "doid": lambda: _obo("doid")}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", choices=sorted(GETTERS))
    ap.add_argument("--refetch-fields", nargs="*", help="refetch only these fields' Wikidata rows (then exit)")
    a = ap.parse_args(argv)
    if a.refetch_fields:
        return refetch_fields(a.refetch_fields)
    OUT.mkdir(parents=True, exist_ok=True)
    net_path = OUT / "network.json"
    net = json.loads(net_path.read_text()) if net_path.exists() else {}
    for name in a.only or sorted(GETTERS):
        try:
            rows, url, note = GETTERS[name]()
            S.write_jsonl(rows, OUT / f"{name}.jsonl")
            net[name] = {"status": "fetched", "url": url, "rows": len(rows), **note}
        except Exception as e:  # noqa: BLE001 - recorded loudly
            net[name] = {"status": "blocked", "url": name, "detail": f"{type(e).__name__}: {e}"[:300], "rows": 0}
        print(name, {k: v for k, v in net[name].items() if k != "errors"}, flush=True)
        net_path.write_text(json.dumps(net, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
