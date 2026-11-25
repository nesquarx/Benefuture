"""Task fine_parent v1: batches (small, k variants), answer validation and the vote merge."""
import json

import pytest

from lifeimage.fine.parent import (MAX_CARDS_PER_BATCH, build_fine_batches, card_view, merge_fine, validate_fine_answers,
                                   write_fine_batches)
from lifeimage.packs import pack_ids

from conftest import link, make_card


def coarse(n=6):
    out = [make_card(f"s.{c}", label=f"Sector {c}", description=f"d {c}", links=[], axes=None) for c in "ab"]
    out += [make_card(f"c.f{i}", label=f"Field {i}", description=f"desc {i}", links=[link("s.a")], axes=None, basemap_version="2027.0")
            for i in range(n)]
    return out


def pool(n):
    return [{"id": f"f.cand_{i:03d}", "label": f"Candidate {i}", "aliases": [f"cand {i}"], "description": f"about {i}",
             "kinds": ["discipline"], "broader_in_source": ["Physics"],
             "sources": [{"source": "openalex", "code": str(i), "label": f"Candidate {i}", "licence_status": "unverified"}]}
            for i in range(n)]


@pytest.fixture
def prompts(tmp_path):
    d = tmp_path / "p"
    d.mkdir()
    (d / "fine_parent.v1.md").write_text("# Task: fine_parent\nJudge each card on its own; do not build a scoring table.\n")
    return d


def batches(n=120, **kw):
    return build_fine_batches(pool(n), coarse(), model="haiku-runner", prompts_dir=kw.pop("prompts"), **kw)


def test_a_larger_batch_than_the_limit_is_refused_not_split_silently(prompts):
    """The generic builder defaults to 300 tasks a batch; past 50 cards runners turn many similar judgements into a
    lookup table, so the fine builder refuses a larger size instead of trusting its caller."""
    with pytest.raises(ValueError, match="at most 50"):
        batches(10, prompts=prompts, max_cards=300)


def test_every_card_is_in_exactly_one_batch_per_variant_and_batches_are_small(prompts):
    b = batches(120, prompts=prompts)
    assert sorted({v for v, _ in b}) == [0, 1, 2]
    for v in range(3):
        parts = [lines for (vv, _), lines in sorted(b.items()) if vv == v]
        ids = [json.loads(l)["input"]["card"]["id"] for lines in parts for l in lines[1:]]
        assert sorted(ids) == [f"f.cand_{i:03d}" for i in range(120)]
        assert max(len(lines) - 1 for lines in parts) <= MAX_CARDS_PER_BATCH == 50
        assert len(parts) == 3  # 120 cards at <= 50: 50, 50, 20


def test_header_has_instructions_then_an_ungrouped_pack_ordered_per_variant(prompts):
    b = batches(10, prompts=prompts)
    prefixes = [json.loads(b[(v, 0)][0])["prefix"] for v in range(3)]
    for p in prefixes:
        assert "do not build a scoring table" in p
        assert pack_ids(p) == {c["id"] for c in coarse()}
        assert p.index("# Task: fine_parent") < p.index("# coarse pack")
    assert len({p.split("# coarse pack", 1)[1] for p in prefixes}) == 3  # fixed shuffles differ
    head = json.loads(b[(0, 0)][0])
    assert head["task_type"] == "fine_parent" and head["model"] == "haiku-runner" and head["prompt_version"] == 1


def test_a_task_sees_its_card_only_so_a_change_elsewhere_keeps_its_hash(prompts):
    a = batches(10, prompts=prompts)
    other = pool(10)
    other[3]["label"] = "Changed"
    c = build_fine_batches(other, coarse(), model="haiku-runner", prompts_dir=prompts)
    hashes = lambda bb: {json.loads(l)["input"]["card"]["id"]: json.loads(l)["input_hash"] for ls in bb.values() for l in ls[1:]}
    ha, hc = hashes(a), hashes(c)
    assert ha["f.cand_003"] != hc["f.cand_003"]
    assert all(ha[i] == hc[i] for i in ha if i != "f.cand_003")
    t = json.loads(a[(0, 0)][1])
    assert set(t["input"]) == {"card", "pack"} and t["allowed_verdicts"] == ["upstream", "overlap", "new_field"]
    assert "sources" not in t["input"]["card"]  # licence and codes are bookkeeping, not evidence for the judgement


def test_card_view_has_no_parent_hint_but_the_sources_own_broader_label():
    v = card_view(pool(1)[0])
    assert v == {"id": "f.cand_000", "label": "Candidate 0", "aliases": ["cand 0"], "description": "about 0",
                 "kinds": ["discipline"], "broader_in_source": ["Physics"]}


def test_cached_answers_are_skipped(prompts):
    class Cache:
        def has(self, t, h, m, p, v):
            return v == 0
    b = batches(10, prompts=prompts, cache=Cache())
    assert {v for v, _ in b} == {1, 2}


def test_batches_are_written_under_the_named_pattern(prompts, tmp_path):
    paths = write_fine_batches(batches(60, prompts=prompts), tmp_path / "out")
    assert sorted(p.name for p in paths)[:2] == ["fine_parent.v1.var0.part0.jsonl", "fine_parent.v1.var0.part1.jsonl"]
    assert len(paths) == 6


# ---------- answers
def answers_for(batch_lines, make):
    head = json.loads(batch_lines[0])
    out = []
    for line in batch_lines[1:]:
        t = json.loads(line)
        out.append(json.dumps({"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"],
                               "variant": t["variant"], "model": head["model"], "prompt_version": t["prompt_version"],
                               "reason": "r", **make(t)}))
    return out


def test_valid_answers_pass(prompts):
    lines = batches(4, prompts=prompts)[(0, 0)]
    ok = answers_for(lines, lambda t: {"verdict": "upstream", "weights": {"c.f1": 0.7, "s.a": 0.3}})
    assert validate_fine_answers(lines, ok) == []
    nf = answers_for(lines, lambda t: {"verdict": "new_field", "reason": "needs a coarse field for X"})
    assert validate_fine_answers(lines, nf) == []


@pytest.mark.parametrize("make, msg", [
    (lambda t: {"verdict": "upstream", "weights": {"c.nope": 1.0}}, "not in the pack"),
    (lambda t: {"verdict": "upstream", "weights": {"c.f0": 0.25, "c.f1": 0.25, "c.f2": 0.25, "c.f3": 0.25}}, "1-3 parents"),
    (lambda t: {"verdict": "upstream"}, "weights"),
    (lambda t: {"verdict": "overlap", "weights": {"c.f0": 0.5, "c.f1": 0.2}}, "sum"),
    (lambda t: {"verdict": "new_field", "weights": {"c.f0": 1.0}}, "no weights"),
    (lambda t: {"verdict": "parents", "weights": {"c.f0": 1.0}}, "not in"),
    (lambda t: {"verdict": "upstream", "weights": {t["input"]["card"]["id"]: 1.0}}, "not in the pack"),
])
def test_adversarial_answers_are_rejected(prompts, make, msg):
    lines = batches(2, prompts=prompts)[(0, 0)]
    errs = validate_fine_answers(lines, answers_for(lines, make))
    assert errs and any(msg in e for e in errs), errs


# ---------- merge
def vote(verdict, weights=None, reason="r"):
    a = {"verdict": verdict, "reason": reason}
    if weights is not None:
        a["weights"] = weights
    return a


def test_unanimous_votes_have_full_agreement_and_no_escalation():
    m = merge_fine({v: vote("upstream", {"c.f1": 0.6, "s.a": 0.4}) for v in range(3)})
    assert m["parents"] == {"c.f1": pytest.approx(0.6), "s.a": pytest.approx(0.4)}
    assert (m["relation"], m["agreement"], m["escalated"], m["main"]) == ("upstream", 1.0, False, "c.f1")
    assert 0.2 < m["confidence"] < 1.0  # never 1: truth levels do not reach 1


def test_majority_parents_need_two_votes_and_weights_are_renormalised():
    m = merge_fine({0: vote("upstream", {"c.f1": 0.7, "s.a": 0.3}), 1: vote("upstream", {"c.f1": 1.0}),
                    2: vote("upstream", {"c.f1": 0.5, "c.f2": 0.5})})
    assert m["parents"] == {"c.f1": pytest.approx(1.0)}  # s.a and c.f2 were named once each
    assert not m["escalated"] and m["agreement"] < 1.0


def test_no_shared_parent_escalates_and_keeps_the_most_named_alone():
    m = merge_fine({0: vote("upstream", {"c.f1": 1.0}), 1: vote("upstream", {"c.f2": 1.0}), 2: vote("upstream", {"c.f3": 1.0})},
                   )
    assert m["escalated"] and len(m["parents"]) == 1 and m["agreement"] == 0.0


def test_relation_kind_follows_the_majority():
    m = merge_fine({0: vote("overlap", {"c.f1": 1.0}), 1: vote("overlap", {"c.f1": 1.0}), 2: vote("upstream", {"c.f1": 1.0})})
    assert m["relation"] == "overlap" and not m["new_field"]


def test_new_field_majority_has_no_parents_and_is_flagged():
    m = merge_fine({0: vote("new_field", reason="needs a field for gambling"), 1: vote("new_field", reason="gambling field"),
                    2: vote("upstream", {"c.f1": 1.0})})
    assert m["new_field"] and m["parents"] == {} and m["relation"] is None
    assert m["escalated"]  # not unanimous
    assert m["new_field_reasons"] == ["needs a field for gambling", "gambling field"]


def test_three_way_split_escalates_and_never_picks_new_field_by_plurality():
    m = merge_fine({0: vote("new_field"), 1: vote("upstream", {"c.f1": 1.0}), 2: vote("overlap", {"c.f1": 1.0})})
    assert m["escalated"] and not m["new_field"] and m["parents"] == {"c.f1": pytest.approx(1.0)}


def test_exactly_k_variants_are_required():
    with pytest.raises(ValueError, match="variants"):
        merge_fine({0: vote("upstream", {"c.f1": 1.0}), 1: vote("upstream", {"c.f1": 1.0})})
