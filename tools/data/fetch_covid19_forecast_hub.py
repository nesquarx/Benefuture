#!/usr/bin/env python3
"""
Fetch a fixed sample of the CDC/UMass COVID-19 Forecast Hub archive (docs/DATA.md §16b, Brief D2).

Downloads, for each model and weekly forecast date, the hub submission file, keeps only US-national
1-week-ahead incident-death quantile rows, and downloads the hub truth (JHU incident deaths, git-LFS)
keeping only US rows. Writes two small files under cases/archive_sample/:
  covid19_hub_us_inc_death_1wk.forecasts.csv   forecaster,forecast_date,target_end_date,quantile,value
  covid19_hub_us_inc_death.truth.csv           date,value   (daily US incident deaths, final vintage)
plus a manifest of the SHA-256 of every raw download. Nothing larger than 5 MB is written.
Output checksums go to tools/data/CHECKSUMS.sha256 (with --write-checksums).

Source: https://github.com/reichlab/covid19-forecast-hub (archived, CC-BY 4.0 / MIT per repo).
Caveat: truth is the final archived vintage, not the as-of vintage; revisions are not reconstructed.
"""
import argparse, csv, datetime, hashlib, io, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "cases" / "archive_sample"
RAW = "https://raw.githubusercontent.com/reichlab/covid19-forecast-hub/master"
LFS = "https://media.githubusercontent.com/media/reichlab/covid19-forecast-hub/master"
MODELS = ["COVIDhub-ensemble", "COVIDhub-baseline", "LANL-GrowthRate", "UMass-MechBayes", "CU-select",
          "USC-SI_kJalpha", "JHU_IDD-CovidSP", "Columbia_UNC-SurvCon", "CovidAnalytics-DELPHI", "MOBS-GLEAM_COVID"]
START, N_WEEKS = datetime.date(2020, 7, 6), 30   # Mondays; a model's file may be dated the Sunday before
TARGET = "1 wk ahead inc death"


def get(url):
    for _ in range(3):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return r.read()
        except Exception:
            pass
    return None


def one(args):
    m, d = args
    data = None
    for off in (0, 1):   # Monday file, else the Sunday file (same forecast week)
        dd = (datetime.date.fromisoformat(d) - datetime.timedelta(days=off)).isoformat()
        data = get(f"{RAW}/data-processed/{m}/{dd}-{m}.csv")
        if data is not None:
            break
    if data is None:
        return m, d, None, []
    rows = []
    for r in csv.DictReader(io.StringIO(data.decode())):
        if r["location"] == "US" and r["target"] == TARGET and r["type"] == "quantile":
            rows.append((m, r["forecast_date"], r["target_end_date"], r["quantile"], r["value"]))
    return m, d, hashlib.sha256(data).hexdigest(), rows


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write-checksums", action="store_true")
    ap.add_argument("--start", default=START.isoformat(), help="first Monday (default: the committed sample's)")
    ap.add_argument("--weeks", type=int, default=N_WEEKS, help="number of weekly forecast dates")
    ap.add_argument("--out", default=None, help="output directory (default: cases/archive_sample, the committed sample)")
    a = ap.parse_args()
    global OUT
    if a.out:
        OUT = Path(a.out)
    OUT.mkdir(parents=True, exist_ok=True)
    start = datetime.date.fromisoformat(a.start)
    dates = [(start + datetime.timedelta(days=7 * i)).isoformat() for i in range(a.weeks)]
    jobs = [(m, d) for m in MODELS for d in dates]
    with ThreadPoolExecutor(6) as ex:
        res = list(ex.map(one, jobs))
    fc, man = [], []
    for m, d, h, rows in sorted(res, key=lambda x: (x[0], x[1])):
        man.append((m, d, h or "MISSING", len(rows)))
        fc += rows
    with open(OUT / "covid19_hub_us_inc_death_1wk.forecasts.csv", "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["forecaster", "forecast_date", "target_end_date", "quantile", "value"])
        w.writerows(fc)
    with open(OUT / "covid19_hub_raw_manifest.csv", "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["forecaster", "forecast_date", "raw_sha256", "us_rows"])
        w.writerows(man)
    t = get(f"{LFS}/data-truth/truth-Incident%20Deaths.csv")
    if t is None:
        sys.exit("truth download failed")
    tr = [(r["date"], r["value"]) for r in csv.DictReader(io.StringIO(t.decode())) if r["location"] == "US"]
    tr.sort()
    with open(OUT / "covid19_hub_us_inc_death.truth.csv", "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["date", "value"])
        w.writerows(tr)
    print("truth raw sha256", hashlib.sha256(t).hexdigest(), "rows", len(tr))
    if not a.out:   # the committed sample stays small; a full-archive run writes outside the repository
        for p in OUT.glob("covid19_hub_*"):
            assert p.stat().st_size < 5_000_000, p
    if a.write_checksums and not a.out:
        ck = ROOT / "tools" / "data" / "CHECKSUMS.sha256"
        lines = [l for l in ck.read_text().splitlines() if "archive_sample/" not in l]
        for p in sorted(OUT.glob("covid19_hub_*")):
            lines.append(f"{sha(p)}  archive_sample/{p.name}")
        ck.write_text("\n".join(lines) + "\n")
    print("forecast rows", len(fc), "missing files", sum(1 for x in man if x[2] == "MISSING"))


if __name__ == "__main__":
    main()
