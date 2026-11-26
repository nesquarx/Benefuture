"""Probe entry point: `cd lifeImage && python3 -m lifeimage.eventgen.probe [--people N] [--seeds K]`.

Builds the world (default 100 people per region, regions KEN, IND, FRA; FRA is absent from the table and degrades loudly to its World Bank region and
the world), times it with its relational events (LI.65, every event validated), and prints both heads: the rate head over the family and schooling
statistics (and its doubled-fertility counterexample), the domain head over the work, health, time-use, leisure, civic and harm statistics (and its doubled
participation counterexample), the sequence head (hard constraints, soft statistics) with its counterexamples (shuffled order and days at work on people
without a job: pass the rate heads, fail the sequence head; births ignoring marriage: soft flag), the coverage of the coarse fields, and the degraded entries.
The heads run on fewer and smaller worlds than the tests' (the whole probe takes under a minute); the tests carry the precision claims.
"""
import argparse
import time
import warnings

from . import calibration as cal
from .rates import rate_head
from .sequence import sequence_head
from .variants import IGNORES_MARRIAGE, career_blind, shuffled
from .world import World, misspecify

REGIONS = ("KEN", "IND", "FRA")


def run(people=100, seeds=None, regions=REGIONS, verbose=True):
    table, rm = cal.load_table(), cal.load_regions()
    t0 = time.time()
    stamps = {}

    def lap(name):
        stamps[name] = round(time.time() - t0 - sum(stamps.values()), 1)
    w = World(table, regions, people, seed=1, region_map=rm)
    rows = w.rows()
    by = w.events()
    elapsed = time.time() - t0
    lap("world, rows and relational events")
    n_events = sum(len(v) for v in by.values())
    head_table = cal.load_table()
    base = lambda s: World(cal.load_table(), regions, 1000, s, region_map=rm, domains=False)   # noqa: E731
    rep = rate_head(head_table, base, regions, rm, seeds=seeds, domains=False)
    bad = rate_head(head_table, lambda s: World(misspecify(cal.load_table(), "fertility.asfr", 2.0), regions, 1000, s, region_map=rm, domains=False), regions, rm,
                    seeds=min(rep["seeds"], 8), domains=False)
    lap("rate head and doubled fertility")
    dom = rate_head(head_table, lambda s: World(cal.load_table(), regions, 600, s, region_map=rm), regions, rm, seeds=seeds or 8, domains="only")
    dom_bad = rate_head(head_table, lambda s: World(misspecify(cal.load_table(), "time.participation.cooking", 2.0), regions, 600, s, region_map=rm), regions, rm,
                        seeds=3, domains="only")
    lap("domain head and doubled participation")
    n = 200
    mk = lambda s: World(cal.load_table(), regions, n, s, region_map=rm)  # noqa: E731
    k = seeds or 5
    seq = sequence_head(head_table, mk, regions, rm, seeds=k)
    shuf = sequence_head(head_table, lambda s: shuffled(mk(s), s), regions, rm, seeds=k)
    blind = sequence_head(head_table, lambda s: career_blind(mk(s), s), regions, rm, seeds=k)
    ign = sequence_head(head_table, lambda s: World(cal.load_table(), regions, n, s, region_map=rm, noise=IGNORES_MARRIAGE), regions, rm, seeds=k)
    lap("sequence head and three counterexamples")
    from . import coverage
    cov = coverage.build_report(500, regions)["summary"]
    lap("coverage")
    if verbose:
        print(f"stage seconds: {stamps}")
        print(f"world: {len(w.people)} people, {len(rows)} rows, {n_events} relational events ({len(w.entities())} entities), {elapsed:.2f} s; "
              f"degraded entries: {len(w.degraded)} table, {len(w.relational_degraded)} responsibility defaults")
        for name, r in (("sequence head, true generator", seq), ("shuffled order", shuf), ("days at work without a job", blind), ("births ignore marriage", ign)):
            flagged = [x["key"] for x in r["soft"] if x["status"] == "fail"]
            print(f"{name}: hard-failing seeds {r['hard_failing_seeds']}/{r['seeds']} {sorted(r['hard_codes'])}; soft {r['soft_summary']}, "
                  f"{r['calibrated_passing']} calibrated statistics pass; soft flags {flagged}")
        print(f"rate head (family and schooling): {rep['summary']} over {rep['seeds']} seeds")
        for r in rep["results"]:
            if r["status"] != "pass":
                print("  ", r["status"], r["key"], f"mean {r.get('mean', float('nan')):.2f} target {r.get('target', float('nan')):.2f} z {r.get('z', float('nan')):.2f}")
        print(f"domain head (work, health, time use, leisure, civic, harm): {dom['summary']} over {dom['seeds']} seeds")
        for r in dom["results"]:
            if r["status"] == "fail":
                print("  ", r["status"], r["key"], f"mean {r.get('mean', float('nan')):.2f} target {r.get('target', float('nan')):.2f} z {r.get('z', float('nan')):.2f}")
        fert = [r for r in bad["results"] if r["key"][0] in ("fertility.asfr", "fertility.tfr")]
        print(f"doubled fertility: {sum(r['status'] == 'fail' for r in fert)} of {len(fert)} fertility statistics fail; min |z| = {min(abs(r['z']) for r in fert):.1f}")
        cook = [r for r in dom_bad["results"] if r["key"][0] == "time.participation.cooking" and r["key"][1] == "all"]
        print(f"doubled cooking participation: {sum(r['status'] == 'fail' for r in cook)} of {len(cook)} cooking statistics fail")
        print(f"coverage at 500 people per region: {cov['reached']}/{cov['fields']} coarse fields ({cov['share_reached']:.0%}), {cov['pairs_observed']} field pairs co-occur")
        kinds = {}
        for d in w.degraded:
            kinds.setdefault((d["mechanism"], d["substitute"]), d)
        for d in list(kinds.values())[:8]:
            print("  degraded:", d)
    return {"world": w, "rows": rows, "events": by, "seconds": elapsed, "head": rep, "domain_head": dom, "bad": bad, "domain_bad": dom_bad, "table": head_table,
            "sequence": seq, "shuffled": shuf, "career_blind": blind, "ignores_marriage": ign, "coverage": cov}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=100)
    ap.add_argument("--seeds", type=int, default=None)
    a = ap.parse_args()
    with warnings.catch_warnings():
        warnings.simplefilter("default")
        run(a.people, a.seeds)
