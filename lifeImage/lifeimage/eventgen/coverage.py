"""Coverage of the generated events over the circle's coarse fields (LI.60).

The placement clean-up scores each field's layout neighbours against event co-membership, so a field no generated event
touches cannot be scored. An event touches a field when any of its memberships (form, content, outcome or setting) names the
field, directly or through a fine domain's coarse parents. The report counts, per coarse field, the events that touch it and,
per unordered pair of fields, the events that touch both (co-membership), at a stated sample (people, regions, seed).

    python3 -m lifeimage.eventgen.coverage [--people 2000] [--out data/events/coverage_v1.json]
"""
import argparse
import json
import time
import warnings
from collections import Counter
from itertools import combinations
from pathlib import Path

from ..generators.common import seed_ids
from . import calibration as cal

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "events" / "coverage_v1.json"
REGIONS = ("KEN", "IND", "FRA")
# The event kinds of increments 1 and 2 (family formation and schooling): the baseline the breadth increment is measured against.
BASELINE_KINDS = ("born", "preschool", "school_start", "primary_complete", "secondary_start", "secondary_complete", "tertiary_start", "tertiary_complete",
                  "school_dropout", "marriage", "divorce", "pregnancy", "birth_of_child", "fatherhood", "death")


def coarse_fields():
    """The ids of the coarse fields (c.*) of the basemap seed: the 247 the placement clean-up scores."""
    return sorted(i for i in seed_ids() if i.startswith("c."))


def _resolver():
    from ..fine.cards import load_fine, upstream
    parents = {c["id"]: [p for p, _ in upstream(c)] for c in load_fine()}

    def resolve(domain):
        return [domain] if domain.startswith("c.") else parents.get(domain, [])
    return resolve


def event_fields(e, resolve):
    """The set of coarse fields an event touches (any membership)."""
    out = set()
    for m in e["memberships"]:
        out.update(resolve(m["domain"]))
    return out


def count_fields(events, kinds=None, fields=None):
    """{'events': per-field counts, 'pairs': Counter over sorted pairs, 'n_events'} over an iterable of events, optionally only of `kinds`."""
    resolve = _resolver()
    fields = set(fields if fields is not None else coarse_fields())
    per, pairs, n = Counter(), Counter(), 0
    cache = {}
    for e in events:
        if kinds is not None and e["kind"] not in kinds:
            continue
        n += 1
        key = tuple(sorted((m["domain"] for m in e["memberships"])))
        if key not in cache:
            cache[key] = tuple(sorted(f for f in event_fields(e, resolve) if f in fields))
        fs = cache[key]
        per.update(fs)
        pairs.update(combinations(fs, 2))
    return {"events": per, "pairs": pairs, "n_events": n}


def summarise(counts, fields=None):
    fields = list(fields if fields is not None else coarse_fields())
    reached = [f for f in fields if counts["events"][f] > 0]
    possible = len(fields) * (len(fields) - 1) // 2
    return {"fields": len(fields), "reached": len(reached), "share_reached": len(reached) / len(fields), "unreached": sorted(set(fields) - set(reached)),
            "events": counts["n_events"], "pairs_observed": len(counts["pairs"]), "pairs_possible": possible, "share_pairs": len(counts["pairs"]) / possible}


def build_report(people=2000, regions=REGIONS, seed=1, table=None):
    from .world import World
    table = table or cal.load_table()
    t0 = time.time()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        w = World(table, regions, people, seed, region_map=cal.load_regions())
        by = w.events(light=True)
    seconds = time.time() - t0
    events = [e for evs in by.values() for e in evs]
    fields = coarse_fields()
    full = count_fields(events, fields=fields)
    base = count_fields(events, kinds=BASELINE_KINDS, fields=fields)
    kinds = Counter(e["kind"] for e in events)
    s, b = summarise(full, fields), summarise(base, fields)
    top = [{"fields": list(p), "events": c} for p, c in full["pairs"].most_common(25)]
    return {"sample": {"people_per_region": people, "regions": list(regions), "seed": seed, "people": len(w.people), "seconds": round(seconds, 1)},
            "summary": s, "baseline_increment_2_kinds": {k: b[k] for k in ("reached", "share_reached", "events", "pairs_observed", "share_pairs")},
            "per_field_events": {f: full["events"][f] for f in fields}, "events_per_kind": dict(sorted(kinds.items())),
            "pairs_top": top, "pair_count_histogram": _hist(full["pairs"].values()),
            "pairs": {f"{a}|{b}": c for (a, b), c in sorted(full["pairs"].items())}}


def _hist(counts):
    h = Counter()
    for c in counts:
        h["1" if c == 1 else "2-4" if c < 5 else "5-19" if c < 20 else "20-99" if c < 100 else "100+"] += 1
    return dict(h)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=2000)
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args()
    rep = build_report(a.people)
    Path(a.out).write_text(json.dumps(rep, sort_keys=True, indent=1) + "\n", encoding="utf-8")
    s = rep["summary"]
    print(f"{s['reached']}/{s['fields']} fields reached ({s['share_reached']:.1%}); {s['pairs_observed']}/{s['pairs_possible']} pairs ({s['share_pairs']:.1%}); "
          f"{s['events']} events, {rep['sample']['seconds']} s; baseline (increment-2 kinds) {rep['baseline_increment_2_kinds']['reached']} fields")
