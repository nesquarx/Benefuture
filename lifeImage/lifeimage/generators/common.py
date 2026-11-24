"""Shared helpers of the generators: seed domains, row validation, small random utilities, name pools."""
import json
import math
import random
from functools import lru_cache
from pathlib import Path

from ..validate import validate_evidence

ROOT = Path(__file__).resolve().parents[2]
SEED_PATH = ROOT / "data" / "coarse" / "seed_v0.jsonl"
A_RELS = frozenset({"form", "content", "outcome", "setting"})  # the A3S membership types
BASEMAP_VERSION = "0.0.0-draft"  # the seed domains' basemap version


@lru_cache(maxsize=1)
def seed_cards():
    return {json.loads(l)["id"]: json.loads(l) for l in SEED_PATH.read_text(encoding="utf-8").splitlines() if l.strip()}


def seed_ids():
    return set(seed_cards())


def seed_label(domain):
    return seed_cards()[domain]["label"]


def validate_row(row):
    """The contract check every generated row passes (the negative channel is allowed: rare harm is recorded)."""
    return validate_evidence(row, allow_negative=True, membership_rels=A_RELS)


def padded(t):
    """(year, month, day) of a valid or record time, missing parts as 1."""
    p = t.split("T")[0].split("-")
    return tuple(int(x) for x in p) + (1,) * (3 - len(p))


def stream(seed, label):
    """An independent deterministic random stream per (seed, label): changing one mechanism's parameter never
    shifts another's draws, so arms of an experiment share their seeds (common random numbers)."""
    return random.Random(f"{seed}|{label}")


def poisson(rng, lam):
    if lam <= 0:
        return 0
    limit, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p <= limit:
            return k
        k += 1


def clip(x, lo, hi):
    return max(lo, min(hi, x))


def pick(rng, seq):
    return seq[rng.randrange(len(seq))]


def normalise(weights):
    total = math.fsum(weights.values())
    return {k: v / total for k, v in weights.items()}


FIRST = ["Maria", "Jonathan", "Priya", "Liam", "Aisha", "Tomasz", "Chen", "Fatima", "Olivia", "Mohammed", "Sofia", "Daniel", "Amara", "Lucas",
         "Yuki", "Elena", "Samuel", "Nadia", "Oscar", "Leila", "Ravi", "Hannah", "Kwame", "Ingrid", "Mateo", "Zainab", "Peter", "Mei",
         "Gabriel", "Anna", "Kofi", "Clara", "Hugo", "Layla", "Viktor", "Rosa", "Arjun", "Emma", "Diego", "Ngozi", "Felix", "Sara",
         "Ibrahim", "Julia", "Mateusz", "Ayesha", "Henrik", "Carmen", "Thomas", "Dina"]
LAST = ["Smith", "Okafor", "Raman", "O'Neill", "Kowalski", "Wang", "Hussain", "Gonzalez", "Nakamura", "Petrov", "Mensah", "Larsen", "Silva",
        "Haddad", "Fischer", "Novak", "Adeyemi", "Moreau", "Bianchi", "Kaur", "Brown", "Ivanova", "Santos", "Lindqvist", "Osei", "Tanaka",
        "Murphy", "Costa", "Rahman", "Weber", "Nguyen", "Lopez", "Andersson", "Chopra", "Diallo", "Jensen", "Romano", "Kim", "Patel", "Walker"]
CITIES = ["Ashford Vale", "Kingsmere", "Northwick", "Lowmoor", "Stonebridge", "Harlow Green", "Eastholm", "Westerby", "Marlowe Bay", "Fenwick", "Redcliffe", "Oakhurst"]
STREETS = ["Elm", "Mill", "Orchard", "Station", "Church", "Meadow", "Hillside", "Bridge", "Chapel", "Garden"]
COUNTRIES = ["GB", "US", "DE", "CA", "AU", "IE"]
