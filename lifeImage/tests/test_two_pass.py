"""LI.70: two-pass extraction. Pass 1 (blind) suggests categories without seeing the domain set; pass 2 (map) allocates them to
domain ids, logs synonyms and reviews the unmatched as new-domain candidates (refinement log, source `blind_unmatched`)."""
import copy
import json
import re
from pathlib import Path

import pytest

import lifeimage.membership_wide as mw
import lifeimage.two_pass as tp
from lifeimage.canonical import content_hash
from lifeimage.membership import MODEL
from lifeimage.validate import ValidationError, validate_answers

ROOT = Path(__file__).resolve().parent.parent
RELS = ("form", "content", "outcome", "setting")
ID = re.compile(r"\b[csf]\.[a-z][a-z0-9_]+\b")


@pytest.fixture(autouse=True)
def _logs_to_tmp(tmp_path, monkeypatch):
    monkeypatch.setattr(mw, "REFINEMENT_DIR", tmp_path / "refinement")
    monkeypatch.setattr(tp, "REFINEMENT_DIR", tmp_path / "refinement")


def _card(id, label, desc, aliases=(), level="coarse", up=None):
    return {"id": id, "label": label, "description": desc, "aliases": [{"lang": "en", "text": a} for a in aliases], "level": level,
            "links": [{"id": up, "rel": "upstream", "weight": 1.0}] if up else [], "basemap_version": "t"}


CARDS = [
    _card("s.home", "Home and household", "Daily life at home", level="coarse"),
    _card("c.cooking", "Cooking", "Preparing food for eating", ["food preparation"], up="s.home"),
    _card("c.sleep", "Sleep", "Resting through the night", ["slumber"], up="s.home"),
    _card("c.hygiene_grooming", "Hygiene and grooming", "Washing and personal cleanliness", up="s.home"),
    _card("c.film_tv_video", "Film, television and video", "Watching and making moving images", up="s.home"),
    _card("c.earth_sciences", "Earth sciences", "Geology, glaciers and climate", up="s.home"),
    _card("f.baking_bread", "Baking bread", "Making bread and pastry in an oven", ["bread making"], level="fine", up="c.cooking"),
]
IDS = {c["id"] for c in CARDS}


def _items():
    return [{"id": "cal.a", "text": "A woman bakes bread for her neighbours"},
            {"id": "cal.b", "text": "A girl washes her hands with soap before lunch"}]


def _g(label, fit, gloss="a gloss"):
    return {"label": label, "fit": fit, "gloss": gloss}


def _blind(form=None, content=None, outcome=None, setting=None, rel=None):
    return {"verdict": "blind",
            "blind": {"form": form, "content": content, "outcome": outcome, "setting": setting},
            "relational": rel or {"participants": [{"ref": "p1", "role": "actor"}], "action": "bakes bread", "outcome": None, "links": []},
            "reason": "r"}


GOOD_BLIND = {
    "cal.a": _blind(form=[_g("baking", 9), _g("home cooking", 7)], content=[_g("bread", 8), _g("food preparation", 7)],
                    outcome=[_g("neighbourly gifting", 6, "bread given away")], setting=[_g("home kitchen", 6)],
                    rel={"participants": [{"ref": "p1", "role": "actor"}, {"ref": "p2", "role": "beneficiary"}], "action": "bakes bread",
                         "outcome": {"text": "neighbours receive bread", "counterfactual": "they would have had none"}, "links": []}),
    "cal.b": _blind(form=[_g("handwashing", 9), _g("personal hygiene", 8)], content=[_g("hygiene", 9), _g("child health", 5)]),
}


def _sign(task, answer, model=MODEL):
    a = {"task_id": task["task_id"], "task_type": task["task_type"], "input_hash": task["input_hash"], "variant": task["variant"],
         "model": model, "prompt_version": task["prompt_version"]}
    a.update(copy.deepcopy(answer))
    return a


def _write_answers(batch_path, make):
    lines = Path(batch_path).read_text(encoding="utf-8").splitlines()
    out = [json.dumps(_sign(json.loads(l), make(json.loads(l)))) for l in lines[1:]]
    p = Path(str(batch_path).replace(".jsonl", ".answers.jsonl"))
    p.write_text("\n".join(out) + "\n", encoding="utf-8")
    return p


def _blind_files(tmp_path, items=None, name="t"):
    items = items or _items()
    paths = tp.write_blind_batches(name, tp.build_blind_batches(items), tmp_path)
    return [(p, _write_answers(p, lambda t: GOOD_BLIND[t["input"]["item"]["id"]])) for p in paths]


def _map_answer(task, drop=None, extra_label=None):
    """A valid mapper answer for a task built from GOOD_BLIND."""
    item = task["input"]["item"]["id"]
    bl = task["input"]["blind"]
    plan = {
        "cal.a": {"form.0": ("c.cooking", "synonym", 0.7), "form.1": ("c.cooking", "synonym", 0.8), "content.0": ("f.baking_bread", "synonym", 0.8),
                  "content.1": ("c.cooking", "exact", 0.9), "outcome.0": ("new", "neighbourly gifting"), "setting.0": ("noise", "a kitchen is a place, not a domain")},
        "cal.b": {"form.0": ("c.hygiene_grooming", "synonym", 0.8), "form.1": ("c.hygiene_grooming", "synonym", 0.9),
                  "content.0": ("c.hygiene_grooming", "synonym", 0.9), "content.1": ("new", "child health")},
    }[item]
    labels = []
    for rel in RELS:
        for g in bl[rel] or []:
            p = plan[g["ref"]]
            if p[0] == "new":
                labels.append({"ref": g["ref"], "action": "new_domain_candidate", "proposed_label": p[1], "gloss": "what it is",
                               "nearest": ["c.hygiene_grooming" if item == "cal.b" else "c.cooking"], "parent": "s.home"})
            elif p[0] == "noise":
                labels.append({"ref": g["ref"], "action": "noise", "reason": p[1]})
            else:
                labels.append({"ref": g["ref"], "action": "match", "domain": p[0], "kind": p[1], "match": p[2]})
    if item == "cal.a":
        types = {"form": {"c.cooking": 1.0}, "content": {"f.baking_bread": 0.6, "c.cooking": 0.4}, "outcome": None, "setting": None}
        ranks = {"form": {"listed": [{"domain": "c.cooking", "fit": 9}], "rejected": {"domain": "c.sleep", "fit": 1}},
                 "content": {"listed": [{"domain": "f.baking_bread", "fit": 9}, {"domain": "c.cooking", "fit": 7}], "rejected": {"domain": "c.sleep", "fit": 1}},
                 "outcome": None, "setting": None}
    else:
        types = {"form": {"c.hygiene_grooming": 1.0}, "content": {"c.hygiene_grooming": 1.0}, "outcome": None, "setting": None}
        ranks = {"form": {"listed": [{"domain": "c.hygiene_grooming", "fit": 9}], "rejected": {"domain": "c.cooking", "fit": 1}},
                 "content": {"listed": [{"domain": "c.hygiene_grooming", "fit": 9}], "rejected": {"domain": "c.cooking", "fit": 2}},
                 "outcome": None, "setting": None}
    if drop:
        labels = [l for l in labels if l["ref"] != drop]
    if extra_label:
        labels.append(extra_label)
    return {"verdict": "map", "types": types, "ranks": ranks, "labels": labels, "reason": "r"}


def _map_files(tmp_path, blind_pairs, name="t", make=None):
    batches = tp.build_map_batches(blind_pairs, CARDS)
    paths = tp.write_map_batches(name, batches, tmp_path)
    return [(p, _write_answers(p, make or _map_answer)) for p in paths]


# ---- pass 1: blind ----
def test_blind_batches_never_show_a_domain_id_in_prefix_or_input():
    pilot = tp.pilot_items()
    allids = set()
    for f in ("data/coarse/seed_v3.jsonl", "data/fine/fine_v1.jsonl"):
        allids |= {json.loads(l)["id"] for l in (ROOT / f).read_text(encoding="utf-8").splitlines() if l.strip()}
    for name, items in pilot.items():
        for (v, p), lines in tp.build_blind_batches(items).items():
            blob = "\n".join(lines)
            assert not ID.search(blob), (name, v, p, ID.search(blob).group(0))
            assert not any(i in blob for i in allids)
            assert json.loads(lines[0])["task_type"] == "blind"


def test_blind_validator_accepts_a_good_answer_and_rejects_domain_ids_in_labels():
    for a in GOOD_BLIND.values():
        tp.validate_blind_answer(a)
    bad = copy.deepcopy(GOOD_BLIND["cal.a"])
    bad["blind"]["form"][0]["label"] = "c.cooking"
    with pytest.raises(ValidationError, match="domain id"):
        tp.validate_blind_answer(bad)
    bad = copy.deepcopy(GOOD_BLIND["cal.a"])
    bad["blind"]["content"][1]["gloss"] = "close to f.baking_bread"
    with pytest.raises(ValidationError, match="domain id"):
        tp.validate_blind_answer(bad)
    bad = copy.deepcopy(GOOD_BLIND["cal.a"])
    bad["relational"]["action"] = "bakes, see c.cooking"
    with pytest.raises(ValidationError, match="domain id"):
        tp.validate_blind_answer(bad)
    bad = copy.deepcopy(GOOD_BLIND["cal.a"])
    bad["blind"]["form"][0]["label"] = "Cooking"
    tp.validate_blind_answer(bad, ids=IDS)  # a plain word that merely matches a label is not an id
    bad["blind"]["form"][0]["label"] = "s.home"
    with pytest.raises(ValidationError, match="domain id"):
        tp.validate_blind_answer(bad, ids=IDS)


@pytest.mark.parametrize("edit,msg", [
    (lambda a: a["blind"]["form"].reverse(), "unranked"),
    (lambda a: a["blind"]["form"][1].update(fit=2), "floor"),
    (lambda a: a["blind"]["form"][0].update(fit=11), "fit"),
    (lambda a: a["blind"]["form"][0].update(fit=7.5), "fit"),
    (lambda a: a["blind"]["form"][1].update(label=a["blind"]["form"][0]["label"]), "duplicate"),
    (lambda a: a["blind"]["form"][0].update(gloss="two\nlines"), "gloss"),
    (lambda a: a["blind"]["form"][0].update(gloss=""), "gloss"),
    (lambda a: a["blind"]["form"][0].update(label="x" * 61), "label"),
    (lambda a: a["blind"]["form"].extend([_g(f"extra {i}", 5) for i in range(8)]), "at most"),
    (lambda a: a["blind"].update(form=None, content=None, outcome=None, setting=None), "every relation"),
    (lambda a: a["blind"].pop("setting"), "exactly"),
    (lambda a: a.pop("relational"), "relational"),
    (lambda a: a["relational"].update(links=[{"type": "because", "other": "x"}]), "link"),
    (lambda a: a["relational"]["participants"].append({"ref": "p1", "role": "x"}), "participant"),
    (lambda a: a["relational"].update(outcome={"text": "x"}), "outcome"),
    (lambda a: a.update(verdict="membership"), "verdict"),
])
def test_blind_validator_rejects_malformed_answers(edit, msg):
    a = copy.deepcopy(GOOD_BLIND["cal.a"])
    edit(a)
    with pytest.raises(ValidationError, match=msg):
        tp.validate_blind_answer(a)


def test_blind_variants_differ_in_prefix_only_and_stay_within_the_file_limit():
    items = [{"id": f"i{n:03d}", "text": f"text {n}"} for n in range(120)]
    b = tp.build_blind_batches(items)
    assert sorted(b) == [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)]
    assert all(len(lines) - 1 <= 50 for lines in b.values())
    assert json.loads(b[(0, 0)][0])["prefix"] != json.loads(b[(1, 0)][0])["prefix"]
    assert b[(0, 0)][0] == b[(0, 2)][0]  # one stable prefix across the parts of a variant (cache hits)
    t0, t1 = json.loads(b[(0, 0)][1]), json.loads(b[(1, 0)][1])
    assert t0["input"] == t1["input"] and t0["input_hash"] == t1["input_hash"] and t0["variant"] == 0 and t1["variant"] == 1


def test_blind_answers_validate_through_the_runner_validator_and_reject_ids(tmp_path):
    (bp, ap), _ = _blind_files(tmp_path)[:2]
    b, a = bp.read_text(encoding="utf-8").splitlines(), ap.read_text(encoding="utf-8").splitlines()
    assert validate_answers(b, a) == []
    bad = json.loads(a[0])
    bad["blind"]["form"][0]["label"] = "c.cooking"
    errs = validate_answers(b, [json.dumps(bad)] + a[1:])
    assert errs and "domain id" in errs[0]


# ---- pass 2: map ----
def test_map_prefix_carries_the_pack_with_fine_ids_aliases_and_descriptions_and_variants_reorder_it(tmp_path):
    bp = _blind_files(tmp_path)
    b = tp.build_map_batches(bp, CARDS)
    h0, h1 = json.loads(b[(0, 0)][0]), json.loads(b[(1, 0)][0])
    assert h0["task_type"] == "map" and h0["prompt_version"] == 1
    for needle in ("f.baking_bread", "bread making", "Preparing food for eating", "c.cooking"):
        assert needle in h0["prefix"]
    assert h0["prefix"] != h1["prefix"]
    ids = [l.split(" | ")[0] for l in h0["prefix"].split("domain pack follows.\n", 1)[1].splitlines()[1:]]
    assert set(ids) == IDS and ids[0].startswith("s.")


def test_map_batches_need_validated_pass1_answers(tmp_path):
    (bp0, ap0), (bp1, ap1) = _blind_files(tmp_path)
    a = ap0.read_text(encoding="utf-8").splitlines()
    bad = json.loads(a[0])
    bad["blind"]["form"][0]["label"] = "c.cooking"
    ap0.write_text("\n".join([json.dumps(bad)] + a[1:]) + "\n", encoding="utf-8")
    with pytest.raises(ValueError, match="domain id"):
        tp.build_map_batches([(bp0, ap0), (bp1, ap1)], CARDS)


def test_map_input_hash_includes_the_pass1_answer_hash_and_variant_v_reads_pass1_variant_v(tmp_path):
    pairs = _blind_files(tmp_path)
    b = tp.build_map_batches(pairs, CARDS)
    t = json.loads(b[(0, 0)][1])
    assert t["task_type"] == "map" and t["allowed_verdicts"] == ["map"] and t["variant"] == 0
    assert set(t["input"]) == {"item", "blind", "pass1", "pack"}
    refs = [g["ref"] for rel in RELS for g in t["input"]["blind"][rel] or []]
    assert refs[0] == "form.0" and len(refs) == len(set(refs))
    assert not ID.search(json.dumps(t["input"]["blind"]))
    # a different pass-1 answer (one gloss changed) gives another input hash and task id
    (bp0, ap0), (bp1, ap1) = pairs
    a = ap0.read_text(encoding="utf-8").splitlines()
    chg = json.loads(a[0])
    chg["blind"]["form"][0]["gloss"] = "another gloss"
    ap0.write_text("\n".join([json.dumps(chg)] + a[1:]) + "\n", encoding="utf-8")
    t2 = json.loads(tp.build_map_batches([(bp0, ap0), (bp1, ap1)], CARDS)[(0, 0)][1])
    assert t2["input_hash"] != t["input_hash"] and t2["task_id"] != t["task_id"]
    assert t2["input"]["pass1"]["answer_hash"] != t["input"]["pass1"]["answer_hash"]
    assert t2["input"]["pass1"]["input_hash"] == t["input"]["pass1"]["input_hash"]
    # variant 1 reads the pass-1 variant-1 answer
    assert json.loads(b[(1, 0)][1])["input"]["pass1"]["answer_hash"] == json.loads(b[(1, 0)][1])["input"]["pass1"]["answer_hash"]
    assert json.loads(b[(1, 0)][1])["variant"] == 1


def _map_ctx(tmp_path):
    pairs = _blind_files(tmp_path)
    b = tp.build_map_batches(pairs, CARDS)
    tasks = {json.loads(l)["input"]["item"]["id"]: json.loads(l) for l in b[(0, 0)][1:]}
    entries = tp.pack_entries(json.loads(b[(0, 0)][0])["prefix"])
    return tasks, entries


def test_map_validator_accepts_a_good_answer(tmp_path):
    tasks, entries = _map_ctx(tmp_path)
    for item, t in tasks.items():
        tp.validate_map_answer(_sign(t, _map_answer(t)), t, entries)


def _bad(tasks, item, edit):
    t = tasks[item]
    a = _sign(t, _map_answer(t))
    edit(a, t)
    return t, a


@pytest.mark.parametrize("item,edit,msg", [
    ("cal.a", lambda a, t: a["types"]["form"].update({"c.nowhere": 0.0}) or a["types"]["form"].update({"c.cooking": 0.5, "c.nowhere": 0.5}), "not in the pack"),
    ("cal.a", lambda a, t: a["ranks"]["content"]["listed"].reverse(), "differ|unranked"),
    ("cal.a", lambda a, t: a["ranks"]["content"]["listed"][1].update(fit=4), "floor"),
    ("cal.a", lambda a, t: a["ranks"]["form"]["rejected"].update(fit=6), "stopped early"),
    ("cal.a", lambda a, t: a["labels"].pop(0), "no review|unmatched|every blind label"),
    ("cal.a", lambda a, t: a["labels"].append(dict(a["labels"][0])), "twice|duplicate"),
    ("cal.a", lambda a, t: a["labels"].append({"ref": "form.9", "action": "noise", "reason": "r"}), "unknown ref"),
    ("cal.a", lambda a, t: a["labels"][0].update(domain="c.nowhere"), "not in the pack"),
    ("cal.a", lambda a, t: a["labels"][0].update(match=1.0), "match"),
    ("cal.a", lambda a, t: a["labels"][0].update(match=0.0), "match"),
    ("cal.a", lambda a, t: a["labels"][0].update(kind="exact"), "exact"),
    ("cal.a", lambda a, t: a["labels"][3].update(kind="maybe"), "kind"),
    ("cal.a", lambda a, t: a["labels"][4].pop("nearest"), "nearest"),
    ("cal.a", lambda a, t: a["labels"][4].update(nearest=["c.nowhere"]), "not in the pack"),
    ("cal.a", lambda a, t: a["labels"][4].update(parent="c.nowhere"), "not in the pack"),
    ("cal.a", lambda a, t: a["labels"][4].update(proposed_label=""), "proposed_label"),
    ("cal.a", lambda a, t: a["labels"][5].pop("reason"), "reason"),
    ("cal.a", lambda a, t: a["labels"][5].update(action="ignore"), "action"),
    ("cal.a", lambda a, t: a["types"].update(form={"c.sleep": 1.0}) or a["ranks"]["form"]["listed"][0].update(domain="c.sleep") or a["ranks"]["form"]["rejected"].update(domain="c.cooking"),
     "anchored|no blind label"),
    ("cal.a", lambda a, t: a.update(verdict="membership"), "verdict"),
    ("cal.a", lambda a, t: a.pop("labels"), "labels"),
])
def test_map_validator_rejects(tmp_path, item, edit, msg):
    tasks, entries = _map_ctx(tmp_path)
    t, a = _bad(tasks, item, edit)
    with pytest.raises(ValidationError, match=msg):
        tp.validate_map_answer(a, t, entries)


def test_map_accepts_every_relation_null_when_every_label_is_noise_or_new(tmp_path):
    tasks, entries = _map_ctx(tmp_path)
    t = tasks["cal.b"]
    a = _sign(t, _map_answer(t))
    a["types"] = {r: None for r in RELS}
    a["ranks"] = {r: None for r in RELS}
    a["labels"] = [{"ref": l["ref"], "action": "noise", "reason": "nothing in the pack"} for l in a["labels"]]
    tp.validate_map_answer(a, t, entries)


def test_map_answers_validate_through_the_runner_validator(tmp_path):
    pairs = _blind_files(tmp_path)
    mp = _map_files(tmp_path, pairs)
    for bp, ap in mp:
        assert validate_answers(bp.read_text(encoding="utf-8").splitlines(), ap.read_text(encoding="utf-8").splitlines()) == []
    bp, ap = mp[0]
    a = ap.read_text(encoding="utf-8").splitlines()
    bad = json.loads(a[0])
    bad["labels"] = bad["labels"][1:]
    errs = validate_answers(bp.read_text(encoding="utf-8").splitlines(), [json.dumps(bad)] + a[1:])
    assert errs and "blind label" in errs[0]


# ---- merging ----
def test_merge_blind_gives_agreement_and_escalates_only_when_a_relation_applies_in_one_variant():
    a, b = copy.deepcopy(GOOD_BLIND["cal.a"]), copy.deepcopy(GOOD_BLIND["cal.a"])
    a.update(prompt_version=1, model="m")
    b.update(prompt_version=1, model="m")
    m = tp.merge_blind("cal.a", {0: a, 1: b})
    assert m["confidence"]["form"]["agreement"] == 1.0 and not m["escalate"] and m["labels"]["form"][0]["label"] == "baking"
    b["blind"]["form"][1]["label"] = "kitchen craft"
    m = tp.merge_blind("cal.a", {0: a, 1: b})
    assert m["confidence"]["form"]["agreement"] == pytest.approx(1 / 3) and not m["escalate"]
    b["blind"]["setting"] = None
    m = tp.merge_blind("cal.a", {0: a, 1: b})
    assert m["escalate"] and any("setting" in r for r in m["escalate_reasons"])


# ---- the end-to-end ingest ----
def _ingest(tmp_path, make=None):
    pairs = _blind_files(tmp_path)
    mp = _map_files(tmp_path, pairs, make=make)
    out = tmp_path / "two_pass.jsonl"
    kw = dict(synonyms_path=tmp_path / "synonyms_v1.jsonl", escalation_path=tmp_path / "esc.jsonl", refinement_dir=tmp_path / "refinement")
    return pairs, mp, out, kw, tp.ingest_two_pass(pairs, mp, out, **kw)


def test_ingest_writes_memberships_synonyms_and_blind_unmatched_candidates(tmp_path):
    pairs, mp, out, kw, rows = _ingest(tmp_path)
    by = {r["key"]: r for r in rows}
    a = by["cal.a"]
    assert list(a["memberships"]["content"]) == ["f.baking_bread", "c.cooking"] and a["memberships"]["outcome"] is None
    assert a["variants"] == 2 and a["source"] == "cal" and not a["escalate"]
    assert a["relational"]["0"]["action"] == "bakes bread" and a["blind"]["confidence"]["form"]["agreement"] == 1.0
    assert json.loads(out.read_text(encoding="utf-8").splitlines()[0])["key"] == "cal.a"
    syn = [json.loads(l) for l in kw["synonyms_path"].read_text(encoding="utf-8").splitlines()]
    key = {(s["label"], s["domain"]): s for s in syn}
    s = key[("baking", "c.cooking")]
    assert s["count"] == 2 and s["items"] == 1 and s["kinds"] == {"synonym": 2} and 0 < s["match_mean"] < 1 and s["relations"] == {"form": 2}
    assert ("cooking", "c.cooking") not in key  # a label never given; exact matches are logged with their kind
    assert key[("food preparation", "c.cooking")]["kinds"] == {"exact": 2}
    assert key[("handwashing", "c.hygiene_grooming")]["count"] == 2
    cands = [json.loads(l) for l in (kw["refinement_dir"] / "candidates_v1.jsonl").read_text(encoding="utf-8").splitlines()]
    assert {c["source"] for c in cands} == {"blind_unmatched"}
    got = {(c["item"], c["proposed_label"], c["variant"]) for c in cands}
    assert got == {("cal.a", "neighbourly gifting", 0), ("cal.a", "neighbourly gifting", 1), ("cal.b", "child health", 0), ("cal.b", "child health", 1)}
    c0 = next(c for c in cands if c["item"] == "cal.b")
    assert c0["relation"] == "content" and c0["parent"] == "s.home" and c0["listed"] == ["c.hygiene_grooming"] and c0["gloss"] and c0["fit"] == 5
    assert not any("kitchen" in json.dumps(c) for c in cands)  # noise is not a candidate
    # candidates never enter memberships
    assert not any("gifting" in json.dumps(r["memberships"]) or "child" in json.dumps(r["memberships"]) for r in rows)
    summary = json.loads((kw["refinement_dir"] / "summary_v1.json").read_text(encoding="utf-8"))
    assert summary["by_source"] == {"blind_unmatched": 4}


def test_ingest_is_idempotent_for_the_synonym_log_and_the_refinement_log(tmp_path):
    pairs, mp, out, kw, rows = _ingest(tmp_path)
    first = (kw["synonyms_path"].read_bytes(), (kw["refinement_dir"] / "candidates_v1.jsonl").read_bytes())
    tp.ingest_two_pass(pairs, mp, out, **kw)
    assert (kw["synonyms_path"].read_bytes(), (kw["refinement_dir"] / "candidates_v1.jsonl").read_bytes()) == first


def test_ingest_refuses_a_pass2_answer_built_on_a_different_pass1_answer(tmp_path):
    pairs = _blind_files(tmp_path)
    mp = _map_files(tmp_path, pairs)
    ap0 = pairs[0][1]
    a = ap0.read_text(encoding="utf-8").splitlines()
    chg = json.loads(a[0])
    chg["blind"]["form"][0]["gloss"] = "changed after pass 2 was built"
    ap0.write_text("\n".join([json.dumps(chg)] + a[1:]) + "\n", encoding="utf-8")
    with pytest.raises(ValueError, match="pass-1 answer"):
        tp.ingest_two_pass(pairs, mp, tmp_path / "o.jsonl", synonyms_path=tmp_path / "s.jsonl", escalation_path=tmp_path / "e.jsonl",
                           refinement_dir=tmp_path / "r")


def test_ingest_escalates_when_the_variants_disagree_on_the_primary_domain(tmp_path):
    def make(t):
        a = _map_answer(t)
        if t["variant"] == 1 and t["input"]["item"]["id"] == "cal.b":
            a["types"]["form"] = {"c.cooking": 0.6, "c.hygiene_grooming": 0.4}
            a["ranks"]["form"]["listed"] = [{"domain": "c.cooking", "fit": 9}, {"domain": "c.hygiene_grooming", "fit": 7}]
            a["ranks"]["form"]["rejected"] = {"domain": "c.sleep", "fit": 1}
            a["labels"][0] = {"ref": "form.0", "action": "match", "domain": "c.cooking", "kind": "synonym", "match": 0.4}
            a["labels"][1] = {"ref": "form.1", "action": "match", "domain": "c.hygiene_grooming", "kind": "synonym", "match": 0.7}
        return a
    pairs, mp, out, kw, rows = _ingest(tmp_path, make=make)
    by = {r["key"]: r for r in rows}
    # support-weighted union (default): both variants' domains are kept, the one both listed outweighs the lone one
    assert set(by["cal.b"]["memberships"]["form"]) == {"c.hygiene_grooming", "c.cooking"} and by["cal.b"]["merge"] == "support_union"
    assert by["cal.b"]["memberships"]["form"]["c.hygiene_grooming"] > by["cal.b"]["memberships"]["form"]["c.cooking"]
    assert by["cal.b"]["confidence"]["form"]["support"] == {"c.hygiene_grooming": 1.0, "c.cooking": 0.5}
    old = {r["key"]: r for r in tp.ingest_two_pass(pairs, mp, tmp_path / "o2.jsonl", **{**kw, "synonyms_path": tmp_path / "s2.jsonl",
                                                                                          "escalation_path": tmp_path / "e2.jsonl"}, merge="intersection")}
    assert old["cal.b"]["memberships"]["form"] == {"c.hygiene_grooming": 1.0}  # the old rule, by name: only the domain both variants listed
    assert by["cal.b"]["escalate"] and any("primary domains differ" in r for r in by["cal.b"]["escalate_reasons"])
    assert by["cal.b"]["confidence"]["form"]["agreement"] == 0.5
    assert not by["cal.a"]["escalate"]
    esc = [json.loads(l) for l in kw["escalation_path"].read_text(encoding="utf-8").splitlines()]
    assert [e["key"] for e in esc] == ["cal.b"]


# ---- the pilot and the pre-registration ----
def test_pilot_builds_pass1_batches_over_the_32_controls_and_50_snippets_two_variants_at_most_50_per_file(tmp_path):
    paths = tp.pilot_blind_batches(tmp_path)
    names = sorted(p.name for p in paths)
    assert names == [f"blind.v1.{s}.var{v}.part0.jsonl" for s in ("controls", "snippets") for v in (0, 1)]
    counts = {p.name: len(p.read_text(encoding="utf-8").splitlines()) - 1 for p in paths}
    assert counts["blind.v1.controls.var0.part0.jsonl"] == 32 and counts["blind.v1.snippets.var1.part0.jsonl"] == 50
    ctl = {json.loads(l)["id"] for l in (ROOT / "data/gold/membership_wide_controls_v0.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    got = {json.loads(l)["input"]["item"]["id"] for l in paths[0].read_text(encoding="utf-8").splitlines()[1:]}
    assert got == ctl
    assert not any(ID.search(p.read_text(encoding="utf-8")) for p in paths)


def test_predictions_are_preregistered_before_any_answer_exists():
    text = (ROOT / "data" / "gold" / "two_pass_predictions.md").read_text(encoding="utf-8")
    for needle in ("0.91", "0.95", "at least 10", "at least 3", "structural", "Confidence 0.5", "0.96", "blind.v1", "map.v1"):
        assert needle in text, needle
    assert not list((ROOT / "data" / "batches").glob("blind.v1.*.answers.jsonl")) or "judged" in text


def test_report_judges_the_preregistered_predictions(tmp_path):
    pairs, mp, out, kw, rows = _ingest(tmp_path)
    controls = [{"id": "cal.a", "group": "multi", "text": "t", "fair": {"form": ["c.cooking"], "content": ["f.baking_bread", "c.cooking"]},
                 "bad": {}, "required": {"content": ["f.baking_bread"]}}]
    rep = tp.two_pass_report(controls, tp.answers_by_item(pairs), tp.answers_by_item(mp), synonyms=[json.loads(l) for l in kw["synonyms_path"].read_text().splitlines()],
                             candidates=[json.loads(l) for l in (kw["refinement_dir"] / "candidates_v1.jsonl").read_text().splitlines()],
                             v4_recall=0.9630)
    assert rep["recall_required"] == 1.0 and rep["predictions"]["recall_at_least_v4_minus_0.05"] is True
    assert rep["distinct_synonyms"] == 6 and rep["predictions"]["at_least_10_synonyms"] is False
    assert rep["new_domain_candidates"] == 2 and rep["predictions"]["at_least_3_candidates"] is False
    assert rep["pass1_domain_ids"] == 0 and rep["predictions"]["pass1_labels_never_contain_domain_ids"] is True


def test_governed_thresholds_of_the_blind_pass_are_listed():
    from lifeimage.governed import GOVERNED
    assert GOVERNED["blind.fit_floor"]["default"] == 4 and GOVERNED["blind.max_labels"]["default"] == 6
    assert "blind.fit_floor" in (ROOT / "README.md").read_text(encoding="utf-8")


def test_the_real_domain_pack_covers_every_coarse_and_fine_domain_and_parses_back():
    cards = tp.load_domain_cards()
    text = tp.domain_pack(cards, 0)
    entries = tp.pack_entries(text)
    assert len(entries) == len(cards) == len(text.splitlines()) - 1 and all(text.splitlines()[i].count(" | ") == 3 for i in range(1, 50))
    assert {c["id"] for c in cards} == set(entries) and sum(i.startswith("f.") for i in entries) > 1000
    assert tp.domain_pack(cards, 1) != text and set(tp.pack_entries(tp.domain_pack(cards, 1))) == set(entries)
