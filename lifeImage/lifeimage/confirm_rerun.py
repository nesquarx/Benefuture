"""The rerun set for confirm v2: the items the author reviewed (`data/gold/review_v1.md`: the most disputed items and
the round-trip misses, deduplicated) plus four self-defence items (`data/gold/confirm_selfdefence_v0.jsonl`: no less
harmful option, a clear less harmful option, disproportionate force, ambiguous). Review items keep their text and
participants from the confirm item set unchanged, so v1 and v2 answers compare on the same items.

`COERCED` names, per review item, the participant whose responsibility the freedom rule should lower (a handover made
under a recorded threat). It lists only items whose text records the threat: the bare "a shopkeeper hands over the
till money" records none and is not a coerced item.
"""
from pathlib import Path

from .confirm import DEFAULT_ITEMS, load_confirm_items
from .membership import DEFAULT_GOLD

REVIEW = DEFAULT_GOLD / "review_v1.md"
SELFDEFENCE = DEFAULT_GOLD / "confirm_selfdefence_v0.jsonl"
COERCED = {"bd.mp.threat_cash.a": "shopkeeper", "bd.new.coercion": "clerk", "bd.mp.donation_coerced.b": "donor"}


def review_ids(path=REVIEW):
    """Item ids of the review file, in order, without duplicates: each `## <id> (disagreements: n)` heading, then the
    `- <id>: <text>` lines under the round-trip misses."""
    ids, in_misses = [], False
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            in_misses = line.startswith("## Round-trip misses")
            if "(disagreements" in line:
                ids.append(line[3:].split(" (disagreements")[0].strip())
        elif in_misses and line.startswith("- ") and ":" in line:
            ids.append(line[2:].split(":", 1)[0].strip())
    return list(dict.fromkeys(ids))


def load_selfdefence(path=SELFDEFENCE):
    return load_confirm_items(path)


def rerun_items(items=None, ids=None, selfdefence=None):
    """The review items (from `items`, default the confirm item set) in review order, then the self-defence items.
    An id the review lists but the item set lacks raises: a silent drop would shrink the comparison."""
    by_id = {i["id"]: i for i in (load_confirm_items(DEFAULT_ITEMS) if items is None else items)}
    ids = review_ids() if ids is None else ids
    missing = [i for i in ids if i not in by_id]
    if missing:
        raise ValueError(f"review items not in the confirm item set: {missing}")
    return [by_id[i] for i in ids] + (load_selfdefence() if selfdefence is None else selfdefence)
