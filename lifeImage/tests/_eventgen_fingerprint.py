"""Fingerprint of the eventgen outputs on fixed seeds (rows, relational events, statistics, head verdicts); the speed work must leave it unchanged.
Regenerate the golden only for an intended output change: python3 tests/_eventgen_fingerprint.py > tests/data_eventgen_golden.json"""
import hashlib
import json
import sys
import warnings

REGIONS = ("KEN", "IND", "FRA")


def _h(obj):
    return hashlib.sha256(json.dumps(obj, sort_keys=True, default=repr).encode()).hexdigest()


def _verdicts(head):
    return [[list(r["key"]), r["status"], None if "mean" not in r else round(r["mean"], 9)] for r in head["results"]] if "results" in head else None


def fingerprint():
    from lifeimage.eventgen import calibration as cal
    from lifeimage.eventgen.rates import rate_head
    from lifeimage.eventgen.sequence import sequence_head
    from lifeimage.eventgen.world import World
    table, rm = cal.load_table(), cal.load_regions()
    out = {}
    for seed in (1, 2):
        w = World(table, REGIONS, 40, seed, region_map=rm)
        out[f"rows{seed}"] = _h(w.rows())
        out[f"events{seed}"] = _h(w.events())
        out[f"stats{seed}"] = _h(sorted((list(k), round(v, 9) if v == v else "nan") for k, v in w.statistics().items()))
        out[f"degraded{seed}"] = _h(w.degraded)
    rh = rate_head(table, lambda s: World(cal.load_table(), REGIONS, 150, s, region_map=rm), REGIONS, rm, seeds=2)
    out["rate_head"] = _h(_verdicts(rh))
    dh = rate_head(table, lambda s: World(cal.load_table(), REGIONS, 100, s, region_map=rm), REGIONS, rm, seeds=2, domains="only")
    out["domain_head"] = _h(_verdicts(dh))
    sh = sequence_head(table, lambda s: World(cal.load_table(), REGIONS, 60, s, region_map=rm), REGIONS, rm, seeds=2)
    out["sequence_head"] = _h([sh["hard"], sh["soft_summary"], [[list(r["key"]), r["status"]] for r in sh["soft"]]])
    return out


if __name__ == "__main__":
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        json.dump(fingerprint(), sys.stdout, indent=1, sort_keys=True)
        print()
