"""Red baseline of increment 2 (kept only until the implementation lands): outcomes of the current generator and checks."""
import random
import warnings

from lifeimage.eventgen import calibration as cal
from lifeimage.eventgen.rates import rate_head
from lifeimage.eventgen.world import World
from lifeimage.generators.common import seed_ids, validate_row

RM = cal.load_regions()
REG = ("KEN", "IND", "FRA")


def mk(seed):
    return World(cal.load_table(field_ids=seed_ids()), REG, 400, seed, region_map=RM)


def test_current_generated_events_carry_participants_and_layer_a_and_valid_time():
    rows = mk(1).rows()
    missing = [r for r in rows if not r.get("participants")]
    assert not missing, f"{len(missing)} of {len(rows)} generated events carry no participant records"


def shuffled(seed):
    w = mk(seed)
    rng = random.Random(seed)
    for r in REG:
        for sx in "fm":
            P = [p for p in w.people if p.region == r and p.sex == sx]
            for kind in {k for p in P for k, _ in p.events}:
                holders = [(p, i) for p in P for i, (k, _) in enumerate(p.events) if k == kind]
                ages = [p.events[i][1] for p, i in holders]
                rng.shuffle(ages)
                for (p, i), a in zip(holders, ages):
                    p.events[i] = (kind, a)
    return w


def test_current_checks_accept_a_shuffled_sequence_and_should_not():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rep = rate_head(cal.load_table(), shuffled, REG, RM, seeds=10)
        ok_rows = all(validate_row(r) for r in shuffled(1).rows())
    passes_all_current_checks = rep["summary"]["fail"] == 0 and ok_rows
    assert not passes_all_current_checks, f"shuffled sequence passes the rate head ({rep['summary']}) and every row validates"
