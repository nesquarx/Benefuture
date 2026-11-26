"""Probe entry point: `cd lifeImage && python3 -m lifeimage.eventgen.probe [--people N] [--seeds K]`.

Builds the world (default 500 people per region, regions KEN, IND, FRA; FRA is absent from the table and degrades loudly to
its World Bank region and the world), times it with its relational events (LI.65, every event validated), and prints the rate
head's per-Param verdicts, the doubled-fertility counterexample, the sequence head (hard constraints, soft statistics), its two
counterexamples (shuffled order: passes the rate head, fails the sequence head; births ignoring marriage: soft flag only) and the
degraded entries.
"""
import argparse
import time
import warnings

from . import calibration as cal
from .rates import rate_head
from .sequence import sequence_head
from .variants import IGNORES_MARRIAGE, shuffled
from .world import World, misspecify

REGIONS = ("KEN", "IND", "FRA")


def run(people=500, seeds=None, regions=REGIONS, verbose=True):
    table, rm = cal.load_table(), cal.load_regions()
    t0 = time.time()
    w = World(table, regions, people, seed=1, region_map=rm)
    rows = w.rows()
    by = w.events()
    elapsed = time.time() - t0
    n_events = sum(len(v) for v in by.values())
    head_table = cal.load_table()
    rep = rate_head(head_table, lambda s: World(cal.load_table(), regions, 1000, s, region_map=rm), regions, rm, seeds=seeds)
    bad_table = misspecify(head_table, "fertility.asfr", 2.0)
    bad = rate_head(head_table, lambda s: World(misspecify(cal.load_table(), "fertility.asfr", 2.0), regions, 1000, s, region_map=rm), regions, rm, seeds=rep["seeds"])
    mk = lambda s: World(cal.load_table(), regions, 500, s, region_map=rm)  # noqa: E731
    seq = sequence_head(head_table, mk, regions, rm, seeds=seeds or 10)
    shuf = sequence_head(head_table, lambda s: shuffled(mk(s), s), regions, rm, seeds=seeds or 10)
    ign = sequence_head(head_table, lambda s: World(cal.load_table(), regions, 500, s, region_map=rm, noise=IGNORES_MARRIAGE), regions, rm, seeds=seeds or 10)
    if verbose:
        print(f"world: {len(w.people)} people, {len(rows)} rows, {n_events} relational events ({len(w.entities())} entities), {elapsed:.2f} s; "
              f"degraded entries: {len(w.degraded)} table, {len(w.relational_degraded)} responsibility defaults")
        for name, r in (("sequence head, true generator", seq), ("shuffled order", shuf), ("births ignore marriage", ign)):
            flagged = [x["key"] for x in r["soft"] if x["status"] == "fail"]
            print(f"{name}: hard-failing seeds {r['hard_failing_seeds']}/{r['seeds']} {sorted(r['hard_codes'])}; soft {r['soft_summary']}, "
                  f"{r['calibrated_passing']} calibrated statistics pass; soft flags {flagged}")
        print(f"rate head: {rep['summary']} over {rep['seeds']} seeds")
        for r in rep["results"]:
            if r["status"] != "pass":
                print("  ", r["status"], r["key"], f"mean {r.get('mean', float('nan')):.2f} target {r.get('target', float('nan')):.2f} z {r.get('z', float('nan')):.2f}")
        fert = [r for r in bad["results"] if r["key"][0] in ("fertility.asfr", "fertility.tfr")]
        print(f"doubled fertility: {sum(r['status'] == 'fail' for r in fert)} of {len(fert)} fertility statistics fail; min |z| = {min(abs(r['z']) for r in fert):.1f}")
        kinds = {}
        for d in w.degraded:
            kinds.setdefault((d["mechanism"], d["substitute"]), d)
        for d in list(kinds.values())[:8]:
            print("  degraded:", d)
    return {"world": w, "rows": rows, "events": by, "seconds": elapsed, "head": rep, "bad": bad, "table": bad_table, "sequence": seq, "shuffled": shuf,
            "ignores_marriage": ign}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=500)
    ap.add_argument("--seeds", type=int, default=None)
    a = ap.parse_args()
    with warnings.catch_warnings():
        warnings.simplefilter("default")
        run(a.people, a.seeds)
