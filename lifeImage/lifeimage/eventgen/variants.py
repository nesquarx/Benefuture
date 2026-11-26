"""Deliberately wrong generators for counterexamples of the verifier (never used as worlds of record).

`shuffled(world, seed)`: the gaming case of increment 1. The ages of each kind of event are permuted among the people of the same
region and sex who have that event, so every marginal the rate head reads (births per woman-year by band, shares reaching each level,
mean age at marriage, deaths before 40) is unchanged while every life is incoherent (a degree before school, a birth after death, a
divorce before the marriage). The rate head cannot tell it from the true generator; the sequence head must.
`ignores_marriage`: births ignore marital state (noise.nonmarital_birth_relative_hazard = 1, the increment-1 generator): coherent lives,
but a birth before marriage far more often than the region's data allows (a soft, not a hard, failure).
"""
import random

IGNORES_MARRIAGE = {"nonmarital_birth_relative_hazard": 1.0}


def shuffled(world, seed=0):
    rng = random.Random(f"shuffle|{seed}")
    for r in world.regions:
        for sx in "fm":
            P = [p for p in world.people if p.region == r and p.sex == sx]
            for kind in sorted({k for p in P for k, _ in p.events} - {"born"}):
                holders = [(p, i) for p in P for i, (k, _) in enumerate(p.events) if k == kind]
                ages = [p.events[i][1] for p, i in holders]
                rng.shuffle(ages)
                for (p, i), a in zip(holders, ages):
                    p.events[i] = (kind, a)
    for p in world.people:   # the death age follows the (shuffled) death event; events keep their kind-wise order from the generator's list
        p.death = next((a for k, a in p.events if k == "death"), None)
    return world
