import hashlib
import json

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.links import agreement_stats, merge_links, validate_links_answer
from lifeimage.packs import coarse_pack, is_sector, pack_ids, write_pack
from lifeimage.tasks import merge_answers
from lifeimage.validate import ValidationError, validate_answers

from conftest import link, make_card


def cards():
    out = [make_card(f"s.{n}", label=f"Sector {n}", description=f"About {n}", links=[]) for n in "ab"]
    out.append(make_card("c.z", label="Zed", description="zzz", links=[link("s.a", weight=0.4), link("s.b", weight=0.6)]))
    out.append(make_card("c.m", label="Em", description="mmm", links=[link("s.a")]))
    out.append(make_card("c.y", label="Why", description="yyy", links=[link("s.b")]))
    out.append(make_card("c.x", label="Ex", description="x | pipe\nand newline", links=[link("s.a")]))
    out.append(make_card("c.n", label="No up", description="nnn", links=[]))
    return out


# ---- pack: acceptance
def test_pack_is_one_line_per_domain_sectors_first_then_fields_by_heaviest_upstream():
    lines = coarse_pack(cards()).splitlines()
    assert lines[0].startswith("#") and "2027.0" in lines[0] and "tokens" in lines[0]
    body = [l.split(" | ")[0] for l in lines[1:]]
    assert body == ["s.a", "s.b", "c.m", "c.x", "c.y", "c.z", "c.n"]  # z's heaviest is s.b


def test_pack_lines_are_single_line_and_token_estimate_is_chars_over_four():
    pack = coarse_pack(cards())
    lines = pack.splitlines()
    assert len(lines) == 1 + 7 and all(l.count(" | ") == 2 for l in lines[1:])
    body = "\n".join(lines[1:]) + "\n"
    assert f"~{-(-len(body) // 4)} tokens" in lines[0]


def test_same_cards_byte_identical_pack_regardless_of_input_order_and_volatile_fields():
    a = coarse_pack(cards())
    b = coarse_pack(list(reversed(cards())))
    c = coarse_pack([dict(x, provenance={"label": {"source": "other", "confidence": 0.1}}) for x in cards()])
    assert a == b == c


def test_variants_shuffle_only_inside_groups_deterministically():
    many = cards()[:2] + [make_card(f"c.f{i:02d}", links=[link("s.a")]) for i in range(30)]
    p0, p1, p1b = coarse_pack(many, 0), coarse_pack(many, 1), coarse_pack(many, 1)
    assert p1 == p1b and p0 != p1
    ids = lambda p: [l.split(" | ")[0] for l in p.splitlines()[1:]]
    assert ids(p0)[:2] == ids(p1)[:2] == ["s.a", "s.b"] and sorted(ids(p0)) == sorted(ids(p1))
    assert ids(p0)[2:] == sorted(ids(p0)[2:])


def test_write_pack_names_the_basemap_version(tmp_path):
    p = write_pack(cards(), tmp_path)
    assert p == tmp_path / "coarse.2027.0.txt" and p.read_text() == coarse_pack(cards())
    assert pack_ids(p.read_text()) == {c["id"] for c in cards()}


# ---- pack: counterexamples
def test_mixed_basemap_versions_are_refused():
    with pytest.raises(ValueError):
        coarse_pack(cards() + [make_card("c.q", basemap_version="2028.0")])


def test_a_card_change_changes_the_pack():
    changed = [dict(c, description="different") if c["id"] == "c.m" else c for c in cards()]
    assert coarse_pack(changed) != coarse_pack(cards())


# ---- validation of links answers
def task_for(fid="c.m"):
    return {"task_type": "links", "input": {"card": {"id": fid}}}


def ans(up, ov=(), **kw):
    return {"task_type": "links", "verdict": "links", "upstream": up, "overlap": list(ov), "reason": "r", **kw}


IDS = {"s.a", "s.b", "c.m", "c.x", "c.y", "c.z"}


def test_valid_links_answer_passes():
    a = ans({"s.a": 0.5, "c.y": 0.5}, ["c.x"])
    assert validate_links_answer(a, task_for(), IDS) == a


@pytest.mark.parametrize("a, why", [
    (ans({"s.a": 0.5, "s.b": 0.4}), "sum"),
    (ans({}), "empty"),
    (ans({"s.a": 0.25, "s.b": 0.25, "c.y": 0.25, "c.x": 0.25}), "four upstream"),
    (ans({"s.nope": 1.0}), "unknown id"),
    (ans({"c.m": 1.0}), "self upstream"),
    (ans({"s.a": 1.0}, ["c.m"]), "self overlap"),
    (ans({"s.a": 1.0}, ["c.nope"]), "unknown overlap"),
    (ans({"s.a": 1.0}, ["c.x", "c.y", "c.z", "s.b", "s.a", "c.m", "c.x"]), "seven overlaps"),
    (ans({"s.a": 1.0}, ["c.x", "c.x"]), "duplicate overlap"),
    (ans({"s.a": 1.0}, verdict="other"), "verdict"),
    ({k: v for k, v in ans({"s.a": 1.0}).items() if k != "upstream"}, "missing upstream"),
])
def test_malformed_links_answers_are_rejected(a, why):
    with pytest.raises((ValidationError, ValueError)):
        validate_links_answer(a, task_for(), IDS)


def test_validate_answers_checks_links_against_the_pack_in_the_header():
    from lifeimage.tasks import canonical_json
    prefix = "instructions\n" + coarse_pack(cards())
    header = json.dumps({"kind": "header", "task_type": "links", "model": "m", "prompt_version": 1, "prefix": prefix})
    task = {"kind": "task", "task_id": "t-v0", "task_type": "links", "prompt_version": 1, "input_hash": "h", "variant": 0,
            "k": 3, "input": {"card": {"id": "c.m"}}, "allowed_verdicts": ["links"]}
    base = {"task_id": "t-v0", "task_type": "links", "input_hash": "h", "variant": 0, "model": "m", "prompt_version": 1,
            "verdict": "links", "reason": "r", "upstream": {"s.a": 1.0}, "overlap": ["c.x"]}
    ok = validate_answers([header, json.dumps(task)], [json.dumps(base)])
    assert ok == []
    bad = validate_answers([header, json.dumps(task)], [json.dumps(dict(base, overlap=["c.ghost"]))])
    assert bad and "c.ghost" in bad[0]
    bad = validate_answers([header, json.dumps(task)], [json.dumps(dict(base, upstream={"c.m": 1.0}))])
    assert bad


# ---- merge
def v(up, ov=()):
    return ans(up, ov)


def test_majority_upstream_kept_weights_averaged_over_namers_then_renormalised():
    votes = {0: v({"s.a": 0.6, "s.b": 0.4}), 1: v({"s.a": 0.8, "c.y": 0.2}), 2: v({"s.a": 0.7, "s.b": 0.3})}
    m = merge_links(votes, "c.m")
    assert set(m["upstream"]) == {"s.a", "s.b"}  # c.y named once is dropped
    a, b = 0.7, 0.35  # s.a mean(.6,.8,.7); s.b mean(.4,.3)
    assert m["upstream"]["s.a"] == pytest.approx(a / (a + b)) and sum(m["upstream"].values()) == pytest.approx(1)
    assert m["escalated"] is False


def test_no_upstream_reaching_two_keeps_most_named_and_logs_escalation(tmp_path):
    log = tmp_path / "esc.jsonl"
    votes = {0: v({"s.a": 1.0}), 1: v({"s.b": 0.6, "c.y": 0.4}), 2: v({"c.z": 1.0})}
    m = merge_links(votes, "c.m", log_path=log)
    assert len(m["upstream"]) == 1 and sum(m["upstream"].values()) == pytest.approx(1)
    assert m["escalated"] is True
    rec = json.loads(log.read_text().splitlines()[0])
    assert rec["field"] == "c.m" and "no upstream" in rec["reason"]


def test_most_named_wins_the_fallback_over_a_single_heavier_vote(tmp_path):
    # s.a named twice cannot be the fallback case; build a real fallback with a two-vote variant set
    votes = {0: v({"s.a": 0.5, "s.b": 0.5}), 1: v({"s.c": 1.0}), 2: v({"s.d": 1.0})}
    m = merge_links(votes, "c.m", log_path=tmp_path / "e")
    assert m["escalated"] and list(m["upstream"].values()) == [pytest.approx(1.0)]


def test_overlaps_need_two_of_three():
    votes = {0: v({"s.a": 1.0}, ["c.x", "c.y"]), 1: v({"s.a": 1.0}, ["c.x", "c.z"]), 2: v({"s.a": 1.0}, ["c.x"])}
    assert merge_links(votes, "c.m")["overlap"] == ["c.x"]
    votes = {0: v({"s.a": 1.0}, ["c.x"]), 1: v({"s.a": 1.0}, ["c.y"]), 2: v({"s.a": 1.0}, ["c.z"])}
    assert merge_links(votes, "c.m")["overlap"] == []


def test_a_lone_dissenter_never_changes_a_unanimous_merge():
    same = {"s.a": 0.7, "s.b": 0.3}
    votes = {0: v(same, ["c.x"]), 1: v(same, ["c.x"]), 2: v({"c.z": 1.0}, ["c.y"])}
    m = merge_links(votes, "c.m")
    assert set(m["upstream"]) == {"s.a", "s.b"} and m["overlap"] == ["c.x"]


def test_merge_requires_all_k_votes():
    with pytest.raises(ValueError):
        merge_links({0: v({"s.a": 1.0}), 1: v({"s.a": 1.0})}, "c.m")


def test_stats_report_unanimous_upstream_share_and_overlap_jaccard():
    f1 = {0: v({"s.a": 1.0}, ["c.x", "c.y"]), 1: v({"s.a": 1.0}, ["c.x", "c.y"]), 2: v({"s.a": 1.0}, ["c.x", "c.y"])}
    f2 = {0: v({"s.a": 1.0}, ["c.x"]), 1: v({"s.b": 1.0}, ["c.y"]), 2: v({"s.c": 1.0}, ["c.z"])}
    s = agreement_stats({"f1": f1, "f2": f2})
    assert s["upstream_all_agree"] == 0.5
    assert s["overlap_jaccard"] == pytest.approx((1.0 + 0.0) / 2)


def test_existing_credence_merge_still_works_on_the_links_verdict():
    answers = [{"task_type": "links", "input_hash": "h", "model": "m", "prompt_version": 1, "variant": i, "verdict": "links"}
               for i in range(3)]
    assert merge_answers(answers)[0].credence == 1.0
