#!/usr/bin/env python3
"""
Fetch a compact, reproducible Stack Exchange domain-reputation sample from api.stackexchange.com/2.3
for Benefuture E2 calibration/validation (docs/DATA.md section 8, Prioritised plan #2).

Fetches resolved answers + question tag sets + cross-site user associations across three related
technical/quantitative Stack Exchange sites (`stats`, `economics`, `cs`), writing clean CSVs
into `cases/calibration_sample/` so pure-Julia adapters can calibrate domain co-occurrence (μ),
per-domain skill heterogeneity, `n_learn`, and no-halo isolation without downloading multi-GB dumps.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

API_BASE = "https://api.stackexchange.com/2.3"
DEFAULT_SITES = ("stats", "economics", "cs")
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_OUT = REPO_ROOT / "cases" / "calibration_sample"


def get_json(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "BenefutureResearch/1.0 (https://github.com/nesquarx/Benefuture)", "Accept-Encoding": "gzip"},
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read()
        if resp.info().get("Content-Encoding") == "gzip" or raw[:2] == b"\x1f\x8b":
            raw = gzip.decompress(raw)
        return json.loads(raw.decode("utf-8"))


def fetch_site_answers(site: str, pages: int = 3, pagesize: int = 100, todate: int | None = None) -> tuple[list[dict], dict[int, list[str]]]:
    answers = []
    for page in range(1, pages + 1):
        query = {
            "order": "desc",
            "sort": "creation",
            "site": site,
            "pagesize": pagesize,
            "page": page,
        }
        if todate is not None:
            query["todate"] = todate
        params = urllib.parse.urlencode(query)
        data = get_json(f"{API_BASE}/answers?{params}")
        items = data.get("items", [])
        if not items:
            break
        answers.extend(items)
        if not data.get("has_more"):
            break
        time.sleep(0.15)

    qids = sorted({a["question_id"] for a in answers if "question_id" in a})
    q_tags: dict[int, list[str]] = {}
    for i in range(0, len(qids), 100):
        batch = ";".join(str(x) for x in qids[i : i + 100])
        q_data = get_json(f"{API_BASE}/questions/{batch}?site={site}&pagesize=100")
        for q in q_data.get("items", []):
            q_tags[q["question_id"]] = q.get("tags", [])
        time.sleep(0.15)
    return answers, q_tags


def fetch_cross_site(account_ids: list[int]) -> list[dict]:
    rows = []
    for i in range(0, len(account_ids), 25):
        batch = ";".join(str(x) for x in account_ids[i : i + 25])
        page = 1
        while True:
            data = get_json(f"{API_BASE}/users/{batch}/associated?pagesize=100&page={page}")
            for item in data.get("items", []):
                rows.append({
                    "account_id": item.get("account_id", ""),
                    "site": item.get("site_name", ""),
                    "site_url": item.get("site_url", ""),
                    "reputation": item.get("reputation", 0),
                    "question_count": item.get("question_count", 0),
                    "answer_count": item.get("answer_count", 0),
                })
            if not data.get("has_more"):
                break
            page += 1
            time.sleep(0.15)
        time.sleep(0.15)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch Stack Exchange calibration sample CSVs")
    parser.add_argument("--sites", nargs="+", default=list(DEFAULT_SITES))
    parser.add_argument("--pages", type=int, default=3)
    parser.add_argument("--settled-days", type=int, default=30)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    post_rows = []
    account_ids = set()
    todate = int(time.time()) - args.settled_days * 86400 if args.settled_days > 0 else None

    for site in args.sites:
        answers, q_tags = fetch_site_answers(site, pages=args.pages, todate=todate)
        for a in answers:
            owner = a.get("owner") or {}
            uid = owner.get("user_id")
            aid = owner.get("account_id")
            qid = a.get("question_id")
            tags = q_tags.get(qid, [])
            if uid is None or not tags:
                continue
            if aid is not None:
                account_ids.add(int(aid))
            post_rows.append({
                "site": site,
                "question_id": qid,
                "answer_id": a["answer_id"],
                "user_id": uid,
                "account_id": aid if aid is not None else "",
                "creation_date": a["creation_date"],
                "score": a.get("score", 0),
                "is_accepted": 1 if a.get("is_accepted") else 0,
                "tags": "|".join(tags),
            })

    cross_rows = fetch_cross_site(sorted(account_ids))

    posts_path = args.out / "stackexchange_answers.csv"
    with posts_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["site", "question_id", "answer_id", "user_id", "account_id", "creation_date", "score", "is_accepted", "tags"])
        w.writeheader()
        w.writerows(sorted(post_rows, key=lambda r: (r["site"], r["creation_date"], r["answer_id"])))

    cross_path = args.out / "stackexchange_cross_site.csv"
    with cross_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["account_id", "site", "site_url", "reputation", "question_count", "answer_count"])
        w.writeheader()
        w.writerows(sorted(cross_rows, key=lambda r: (int(r["account_id"]), r["site"])))

    print(f"Wrote {len(post_rows)} answers to {posts_path}")
    print(f"Wrote {len(cross_rows)} cross-site rows across {len(account_ids)} accounts to {cross_path}")


if __name__ == "__main__":
    main()
