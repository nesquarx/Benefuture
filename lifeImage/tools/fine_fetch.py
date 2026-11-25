"""Fetch the public classifications used as fine candidates into data/fine/sources/ (trimmed rows, one file each).

Usage (from the repository root): python3 lifeImage/tools/fine_fetch.py [--only openalex esco_isco esco_skills icatus]
Each source is tried on its own; a failure is recorded in `data/fine/sources/network.json` (status `blocked` and the
reason) and the other sources continue. The generic client name of `lifeimage.sources.wikidata` is used; nothing
personal is sent. ICATUS is read from the UN's PDF through `pdftotext -layout`.
"""
import argparse
import functools
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.fine import sources as S  # noqa: E402
from lifeimage.sources.wikidata import http_fetch  # noqa: E402

OUT = ROOT / "data" / "fine" / "sources"
FETCH = functools.partial(http_fetch, pause=0.25)


def get_openalex():
    return S.fetch_openalex_subfields(FETCH), S.OPENALEX_URL.format(page=1)


def get_isco():
    rows = []
    for root in S.ISCO_ROOTS:
        rows += S.crawl_esco(FETCH, "concept", root, max_depth=2)
    return rows, "https://ec.europa.eu/esco/api (ISCO-08 via ESCO)"


def get_skills():
    return S.crawl_esco(FETCH, "skill", S.SKILLS_ROOT, max_depth=2), "https://ec.europa.eu/esco/api (skills hierarchy)"


def get_icatus():
    with tempfile.TemporaryDirectory() as d:
        pdf = Path(d) / "icatus.pdf"
        pdf.write_bytes(S.fetch_text(S.ICATUS_URL))
        text = subprocess.run(["pdftotext", "-layout", str(pdf), "-"], capture_output=True, text=True, check=True).stdout
    return S.parse_icatus(text), S.ICATUS_URL


GETTERS = {"openalex": get_openalex, "esco_isco": get_isco, "esco_skills": get_skills, "icatus": get_icatus}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", choices=sorted(GETTERS))
    a = ap.parse_args(argv)
    net_path = OUT / "network.json"
    net = json.loads(net_path.read_text()) if net_path.exists() else {}
    for name in a.only or sorted(GETTERS):
        try:
            rows, url = GETTERS[name]()
            S.write_jsonl(rows, OUT / f"{name}.jsonl")
            net[name] = {"status": "fetched", "url": url, "rows": len(rows)}
        except Exception as e:  # noqa: BLE001 - any failure is recorded loudly, never silent
            net[name] = {"status": "blocked", "url": GETTERS[name].__name__, "detail": f"{type(e).__name__}: {e}"[:300], "rows": 0}
        print(name, net[name], flush=True)
        net_path.parent.mkdir(parents=True, exist_ok=True)
        net_path.write_text(json.dumps(net, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
