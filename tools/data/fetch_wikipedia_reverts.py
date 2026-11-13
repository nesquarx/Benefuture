#!/usr/bin/env python3
"""
Fetch a compact, reproducible English Wikipedia mainspace (ns=0) edit-and-revert sample from the
MediaWiki API for Benefuture E2 audit calibration/validation (docs/DATA.md section 9, Plan #3).

Collects chronological edits in a UTC window and looks up immediately following revisions on each
reverted page to measure exact revert latency (seconds), bot vs human reverters, and re-reverted
reverts (`was_re_reverted`, empirical `p_false_trace` proxy) into `cases/calibration_sample/`.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

API_URL = "https://en.wikipedia.org/w/api.php"
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_OUT = REPO_ROOT / "cases" / "calibration_sample"


def api_get(params: dict) -> dict:
    url = f"{API_URL}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "BenefutureResearch/1.0 (https://github.com/nesquarx/Benefuture)"},
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def parse_ts(ts: str) -> dt.datetime:
    return dt.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)


def fetch_recent_mainspace(limit: int = 1000, rcstart: str | None = None) -> list[dict]:
    items = []
    rccontinue = None
    while len(items) < limit:
        params = {
            "action": "query",
            "list": "recentchanges",
            "rcnamespace": "0",
            "rctype": "edit",
            "rcprop": "title|ids|timestamp|flags|tags|user|sizes",
            "rclimit": min(500, limit - len(items)),
            "format": "json",
        }
        if rcstart:
            params["rcstart"] = rcstart
        if rccontinue:
            params["rccontinue"] = rccontinue
        data = api_get(params)
        batch = data.get("query", {}).get("recentchanges", [])
        if not batch:
            break
        items.extend(batch)
        cont = data.get("continue") or {}
        rccontinue = cont.get("rccontinue")
        if not rccontinue:
            break
        time.sleep(0.1)
    return items[:limit]


def resolve_revert_latency(page_ids: list[int], target_rev_map: dict[int, list[dict]]) -> dict[int, tuple[float, int, int]]:
    """For reverted revisions, inspect page revision history to find the reverting revision and whether
    that revert was itself later reverted."""
    out: dict[int, tuple[float, int, int]] = {}
    for pid in page_ids:
        data = api_get({
            "action": "query",
            "prop": "revisions",
            "pageids": str(pid),
            "rvprop": "ids|timestamp|user|tags|flags",
            "rvlimit": 30,
            "format": "json",
        })
        pages = data.get("query", {}).get("pages", {})
        revs = pages.get(str(pid), {}).get("revisions", [])
        if not revs:
            continue
        # revs arrive newest-first; reverse to chronological order
        revs = list(reversed(revs))
        for item in target_rev_map.get(pid, []):
            rid = item["revid"]
            t0 = parse_ts(item["timestamp"])
            idx = next((i for i, r in enumerate(revs) if r["revid"] == rid), None)
            if idx is None or idx + 1 >= len(revs):
                continue
            revert_rev = None
            for nxt in revs[idx + 1 :]:
                rtags = set(nxt.get("tags", []))
                if rtags & {"mw-rollback", "mw-undo", "mw-manual-revert", "mw-reverted"} or "bot" in str(nxt.get("user", "")).lower():
                    revert_rev = nxt
                    break
            if revert_rev is None:
                revert_rev = revs[idx + 1]
            delay = max(0.0, (parse_ts(revert_rev["timestamp"]) - t0).total_seconds())
            rev_tags = set(revert_rev.get("tags", []))
            uname = str(revert_rev.get("user", ""))
            is_bot = 1 if ("bot" in uname.lower() or "bot" in revert_rev) else 0
            re_reverted = 1 if "mw-reverted" in rev_tags else 0
            out[rid] = (delay, is_bot, re_reverted)
        time.sleep(0.05)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch Wikipedia mainspace edit/revert sample CSV")
    parser.add_argument("--limit", type=int, default=800)
    parser.add_argument("--rcstart", type=str, default=None, help="ISO UTC timestamp to walk backwards from")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    changes = fetch_recent_mainspace(limit=args.limit, rcstart=args.rcstart)

    reverted_by_page: dict[int, list[dict]] = {}
    for ch in changes:
        if "mw-reverted" in ch.get("tags", []):
            reverted_by_page.setdefault(ch["pageid"], []).append(ch)

    latency_map = resolve_revert_latency(sorted(reverted_by_page), reverted_by_page)

    out_path = args.out / "wikipedia_reverts_sample.csv"
    rows = []
    for ch in sorted(changes, key=lambda c: (c["timestamp"], c["revid"])):
        tags = set(ch.get("tags", []))
        reverted = 1 if "mw-reverted" in tags else 0
        delay, bot_rev, re_rev = latency_map.get(ch["revid"], ("", "", ""))
        rows.append({
            "revid": ch["revid"],
            "pageid": ch["pageid"],
            "timestamp": ch["timestamp"],
            "editor_is_bot": 1 if "bot" in ch else 0,
            "is_reverted": reverted,
            "is_revert_action": 1 if bool(tags & {"mw-rollback", "mw-undo", "mw-manual-revert"}) else 0,
            "revert_delay_sec": f"{delay:.1f}" if delay != "" else "",
            "reverter_is_bot": bot_rev,
            "revert_was_undone": re_rev,
            "bytes_delta": int(ch.get("newlen", 0)) - int(ch.get("oldlen", 0)),
        })

    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "revid",
                "pageid",
                "timestamp",
                "editor_is_bot",
                "is_reverted",
                "is_revert_action",
                "revert_delay_sec",
                "reverter_is_bot",
                "revert_was_undone",
                "bytes_delta",
            ],
        )
        w.writeheader()
        w.writerows(rows)

    n_rev = sum(r["is_reverted"] for r in rows)
    n_res = sum(1 for r in rows if r["revert_delay_sec"] != "")
    print(f"Wrote {len(rows)} edits ({n_rev} reverted, {n_res} with resolved latency) to {out_path}")


if __name__ == "__main__":
    main()
