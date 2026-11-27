"""Read-only diagnosis of the two-pass recall loss (`lifeimage/two_pass_diag.py`): each loss class has one case that must land in it,
and the merge rules order as designed (intersection <= weighted <= union)."""
from lifeimage import two_pass_diag as dg

CARDS = {"c.nursing": {"id": "c.nursing", "label": "nursing work", "aliases": [], "level": "coarse", "links": []},
         "c.other": {"id": "c.other", "label": "something else", "aliases": [], "level": "coarse", "links": []}}


def blind(*labels, rel="content"):
    out = {r: None for r in ("form", "content", "outcome", "setting")}
    out[rel] = [{"label": l, "fit": 8, "gloss": ""} for l in labels]
    return {"blind": out}


def mapped(actions, listed=(), rel="content"):
    ranks = {r: None for r in ("form", "content", "outcome", "setting")}
    types = dict(ranks)
    if listed:
        ranks[rel] = {"listed": [{"domain": d, "fit": 8} for d in listed], "rejected": {"domain": "c.other", "fit": 3}}
        types[rel] = {d: 1 / len(listed) for d in listed}
    return {"labels": actions, "ranks": ranks, "types": types}


def cls(b, m):
    return dg.classify_miss("i", "content", "c.nursing", {0: (None, b), 1: (None, b)}, {0: (None, m), 1: (None, m)}, CARDS)[0]


def test_each_class():
    assert cls(blind("weather"), mapped([{"ref": "content.0", "action": "noise", "reason": "x"}])) == "P1"
    assert cls(blind("nursing"), mapped([{"ref": "content.0", "action": "match", "domain": "c.other", "kind": "synonym", "match": 0.5}],
                                        ["c.other"])) == "P2a"
    assert cls(blind("nursing"), mapped([{"ref": "content.0", "action": "match", "domain": "c.nursing", "kind": "exact", "match": 0.9}],
                                        ["c.other"])) == "P2b"
    assert cls(blind("nursing"), mapped([{"ref": "content.0", "action": "noise", "reason": "x"}])) == "P2c"
    b = blind("x")
    b["blind"]["form"] = [{"label": "nursing", "fit": 8, "gloss": ""}]
    m = mapped([{"ref": "form.0", "action": "match", "domain": "c.nursing", "kind": "exact", "match": 0.9},
                {"ref": "content.0", "action": "noise", "reason": "x"}], ["c.other"])
    assert cls(b, m) == "V"


def test_merge_by_one_variant_is_M():
    b = blind("nursing")
    listing = mapped([{"ref": "content.0", "action": "match", "domain": "c.nursing", "kind": "exact", "match": 0.9}], ["c.nursing"])
    lost = mapped([{"ref": "content.0", "action": "noise", "reason": "x"}], ["c.other"])
    assert dg.classify_miss("i", "content", "c.nursing", {0: (None, b), 1: (None, b)}, {0: (None, listing), 1: (None, lost)}, CARDS)[0] == "M"


def test_merge_rules_order():
    a0, a1 = mapped([], ["c.nursing", "c.other"]), mapped([], ["c.other"])
    s = dg.merged_sets({0: a0, 1: a1}, "content", 0.5)
    assert s["intersection"] <= s["weighted"] <= s["union"] and s["intersection"] == {"c.other"} and s["union"] == {"c.nursing", "c.other"}
