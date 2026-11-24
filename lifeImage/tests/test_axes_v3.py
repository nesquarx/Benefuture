"""Axes v3: one 0-10 judgement per card per axis in small batches (outcome tests, red first against a stub that puts every
field in one batch with a -2..2 scale and reports nothing)."""
import importlib.util
import json
import random
from pathlib import Path

import pytest

from lifeimage import degradation
from lifeimage.axes import axes_input
from lifeimage.axes_v3 import SCALE, TASK_TYPES, build_v3_batches, parse_scale, v3_report, write_v3_batches
from lifeimage.canonical import content_hash
from lifeimage.render import basemap as bmod
from lifeimage.validate import validate_answers

from conftest import link, make_card

ROOT = Path(__file__).resolve().parent.parent
N = 130


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def world(n=N):
    cards = [make_card("s.one", label="Sector", description="d", links=[], axes=None)]
    cards += [make_card(f"f.{k:03d}", label=f"Field {k}", description=f"About field {k}", links=[link("s.one")], axes=None) for k in range(n)]
    return cards


def batches(**kw):
    return build_v3_batches(world(), model="haiku-runner", prompts_dir=ROOT / "prompts", **kw)


def tasks(lines):
    return [json.loads(l) for l in lines[1:]]


def test_every_batch_judges_at_most_60_cards_and_every_field_appears_once_per_type_and_variant():
    b = batches()
    assert {key[0] for key in b} == set(TASK_TYPES) == {"axis_at", "axis_pg"}
    assert max(len(lines) - 1 for lines in b.values()) <= 60
    for t in TASK_TYPES:
        for v in range(3):
            ids = [x["input"]["card"]["id"] for key, lines in sorted(b.items()) if key[:2] == (t, v) for x in tasks(lines)]
            assert sorted(ids) == sorted(f"f.{k:03d}" for k in range(N)), (t, v)


def test_batches_are_balanced_not_one_full_and_one_nearly_empty():
    sizes = sorted(len(l) - 1 for key, l in batches().items() if key[:2] == ("axis_at", 0))
    assert len(sizes) == 3 and sizes[-1] - sizes[0] <= 1  # 130 cards: 44, 43, 43


def test_verdicts_are_strings_0_to_10_and_the_header_names_the_task_type():
    assert SCALE == [str(i) for i in range(11)]
    for (t, v, p), lines in batches().items():
        h = json.loads(lines[0])
        assert h["task_type"] == t and h["prompt_version"] == 3
        for x in tasks(lines):
            assert x["task_type"] == t and x["variant"] == v and x["allowed_verdicts"] == SCALE and x["input"]["candidates"] == []


def test_variants_share_the_input_hash_but_show_the_cards_in_different_orders():
    b = batches()
    order = {v: [x["input"]["card"]["id"] for key, l in sorted(b.items()) if key[:2] == ("axis_at", v) for x in tasks(l)] for v in range(3)}
    assert order[0] != order[1] != order[2] and order[0] != order[2]
    hashes = {v: {x["input"]["card"]["id"]: x["input_hash"] for key, l in b.items() if key[:2] == ("axis_at", v) for x in tasks(l)} for v in range(3)}
    assert hashes[0] == hashes[1] == hashes[2]
    ids = {x["task_id"] for l in b.values() for x in tasks(l)}
    assert len(ids) == len(hashes[0]) * 3  # task ids are per (field, variant); the task type tells the two axes apart


def test_files_are_named_per_type_variant_and_part(tmp_path):
    paths = write_v3_batches(batches(), tmp_path)
    names = sorted(p.name for p in paths)
    assert names == sorted(f"axes.v3.{t}.var{v}.part{n}.jsonl" for t in ("at", "pg") for v in range(3) for n in range(3))
    assert all(p.read_text().count("\n") == len(p.read_text().splitlines()) for p in paths)


def test_the_prefix_forbids_bulk_scoring_and_names_only_its_own_axis():
    b = batches()
    at = json.loads(b[("axis_at", 0, 0)][0])["prefix"]
    pg = json.loads(b[("axis_pg", 0, 0)][0])["prefix"]
    sentence = "judge each task on its own card; do not build a scoring table or script that assigns values in bulk"
    assert sentence in at.lower() and sentence in pg.lower()
    assert "0 = abstract" in at and "10 = tangible" in at and "5 = balanced" in at
    assert "0 = personal" in pg and "10 = global" in pg and "5 = balanced" in pg
    assert "personal" in pg.lower() and "tangible" not in pg.lower()
    assert "abstract" in at.lower() and "professional" not in at.lower()


def test_runner_instructions_carry_the_same_rule():
    text = (ROOT / "prompts/RUNNER.md").read_text().lower()
    assert "judge each task on its own card; do not build a scoring table or script that assigns values in bulk" in text


def test_a_well_formed_answer_validates_and_an_old_scale_verdict_does_not():
    b = batches()
    lines = b[("axis_pg", 1, 0)]
    t = tasks(lines)[0]
    ans = {"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": t["variant"], "model": "haiku-runner",
           "prompt_version": 3, "verdict": "7", "reason": "r"}
    rest = [dict(ans, task_id=x["task_id"], input_hash=x["input_hash"]) for x in tasks(lines)]
    assert validate_answers(lines, [json.dumps(a) for a in rest]) == []
    rest[0]["verdict"] = "+2,-1"
    assert any("not in" in e for e in validate_answers(lines, [json.dumps(a) for a in rest]))


def test_parse_scale_accepts_only_integers_0_to_10():
    assert [parse_scale(str(i)) for i in range(11)] == list(range(11))
    for bad in ("11", "-1", "5.0", "", "+2,-1", 5):
        with pytest.raises(ValueError):
            parse_scale(bad)


# ---- the report ----
def answer(field_id, v, verdict, cards=None):
    return {"input_hash": H[field_id], "variant": v, "verdict": str(verdict)}


CARDS = world(40)
BY = {c["id"]: c for c in CARDS}
H = {c["id"]: content_hash(axes_input(c, BY)) for c in CARDS if c["id"].startswith("f.")}
FIELDS = sorted(H)


def votes(fn, k=3):
    return [answer(f, v, fn(f, v)) for f in FIELDS for v in range(k)]


def rank(f):
    return int(f.split(".")[1])


def means_pm2():
    return {"abstract_tangible": {f: (rank(f) - 20) / 10 for f in FIELDS}, "personal_global": {f: (20 - rank(f)) / 10 for f in FIELDS}}


def pilot_rows():
    return [{"axis": ax, "id": f, "position": m, "se": 0.1} for ax, mm in means_pm2().items() for f, m in mm.items()]


def report(at, pg):
    return v3_report({"abstract_tangible": at, "personal_global": pg}, means_pm2(), pilot_rows(), {h: f for f, h in H.items()})


def test_identical_variants_agree_perfectly_and_a_bulk_lookup_shows_in_the_pole_share():
    lin = lambda f, v: round(rank(f) * 10 / 39)
    r = report(votes(lin), votes(lambda f, v: 10 - round(rank(f) * 10 / 39)))
    a = r["abstract_tangible"]
    assert a["variant_spearman"] == pytest.approx(1.0) and a["variant_mad"] == pytest.approx(0.0)
    assert a["spearman_v1v2"] > 0.99 and a["spearman_pilot"] > 0.99  # rounding to 11 levels ties a few fields
    assert r["personal_global"]["spearman_v1v2"] > 0.99
    assert 0 < a["share_poles"] < 0.5  # 0 and 10 only at the ends of the ranking
    lookup = votes(lambda f, v: 10 if rank(f) >= 20 else 0)  # the pilot's failure: everything at a pole
    assert report(lookup, lookup)["abstract_tangible"]["share_poles"] == 1.0


def test_disagreeing_variants_lower_the_agreement_and_raise_the_difference():
    rng = random.Random(3)
    noisy = votes(lambda f, v: rng.randint(0, 10))
    a = report(noisy, noisy)["abstract_tangible"]
    assert abs(a["variant_spearman"]) < 0.4 and a["variant_mad"] > 2.5
    assert a["variants"] == 3 and a["fields"] == 40


def test_reversed_positions_give_negative_correlations():
    a = report(votes(lambda f, v: 10 - round(rank(f) * 10 / 39)), votes(lambda f, v: 5))["abstract_tangible"]
    assert a["spearman_v1v2"] < -0.99 and a["spearman_pilot"] < -0.99


def test_the_compare_tool_reports_v3_from_answer_files(tmp_path):
    tool = load_tool("axes_compare")
    cards = world(20)
    (tmp_path / "data/coarse").mkdir(parents=True)
    (tmp_path / "data/batches").mkdir()
    (tmp_path / "data/coarse/seed_v0.jsonl").write_text("\n".join(json.dumps(c) for c in cards) + "\n")
    by = {c["id"]: c for c in cards}
    h = {c["id"]: content_hash(axes_input(c, by)) for c in cards if c["id"].startswith("f.")}
    for t in ("at", "pg"):
        for v in range(3):
            lines = [json.dumps({"input_hash": h[f], "variant": v, "verdict": str(round(int(f[2:]) * 10 / 19))}) for f in sorted(h)]
            (tmp_path / f"data/batches/axes.v3.{t}.var{v}.part0.answers.jsonl").write_text("\n".join(lines) + "\n")
    r = tool.compare_v3(sorted((tmp_path / "data/batches").glob("axes.v3.*.answers.jsonl")), tmp_path)
    assert set(r) == {"abstract_tangible", "personal_global"}
    a = r["abstract_tangible"]
    assert a["fields"] == 20 and a["variants"] == 3 and a["variant_spearman"] == pytest.approx(1.0) and a["variant_mad"] == 0
    assert a["spearman_v1v2"] is None and a["spearman_pilot"] is None  # no v1/v2 answers or pilot in this root
    text = tool.report_v3(r)
    assert "abstract_tangible" in text and "at 0 or 10" in text and "n/a" in text


# ---- the basemap takes v3 means when present ----
def write_cache(path, task_type, cards, verdicts):
    by = {c["id"]: c for c in cards}
    lines = [json.dumps({"task_type": task_type, "input_hash": content_hash(axes_input(by[i], by)), "model": "m", "prompt_version": 3,
                         "variant": v, "verdict": str(x), "task_id": f"{i}-{v}", "reason": "r"})
             for i, xs in verdicts.items() for v, x in enumerate(xs)]
    path.write_text("\n".join(lines) + "\n")


def v12_cache(path, cards, scores):
    by = {c["id"]: c for c in cards}
    path.write_text("\n".join(json.dumps({"task_type": "axes", "input_hash": content_hash(axes_input(by[i], by)), "variant": 0, "verdict": s})
                              for i, s in scores.items()) + "\n")


def test_v3_means_replace_v1v2_per_field_and_the_fallback_is_logged(tmp_path):
    cards = world(3)
    v12_cache(tmp_path / "axes.jsonl", cards, {"f.000": "-2,-2", "f.001": "-2,-2", "f.002": "+2,+2"})
    write_cache(tmp_path / "axis_at.jsonl", "axis_at", cards, {"f.000": [10, 10, 10], "f.001": [5, 5, 5]})
    write_cache(tmp_path / "axis_pg.jsonl", "axis_pg", cards, {"f.000": [0, 0, 0], "f.001": [10, 10, 10]})
    log = []
    ax = bmod.axes_means(cards, tmp_path / "axes.jsonl", [], log=log)
    assert ax["f.000"]["abstract_tangible"] == pytest.approx(1.0) and ax["f.000"]["personal_global"] == pytest.approx(-1.0)  # v3: 10 tangible, 0 personal
    assert ax["f.001"]["abstract_tangible"] == pytest.approx(0.0) and ax["f.001"]["personal_global"] == pytest.approx(1.0)
    assert ax["f.002"]["abstract_tangible"] == pytest.approx(1.0) and ax["f.002"]["personal_global"] == pytest.approx(1.0)  # v1/v2 fallback
    assert ax["f.000"]["votes"] == 3 and ax["f.000"].get("source") == "v3" and ax["f.002"].get("source") == "v1v2"
    fb = [d for d in log if d["mechanism"] == "axes_v3"]
    assert len(fb) == 1 and "f.002" in fb[0]["step"] and fb[0]["substitute"] == "axes v1/v2 means"


def test_without_v3_answers_every_field_falls_back_loudly_and_unchanged(tmp_path):
    cards = world(2)
    v12_cache(tmp_path / "axes.jsonl", cards, {"f.000": "+1,-1", "f.001": "0,+2"})
    log = []
    degradation.reset_warned()
    with pytest.warns(RuntimeWarning, match="axes_v3"):
        ax = bmod.axes_means(cards, tmp_path / "axes.jsonl", [], log=log)
    assert ax["f.000"] == {"abstract_tangible": 0.5, "personal_global": -0.5, "votes": 1, "source": "v1v2"}
    assert [d["mechanism"] for d in log] == ["axes_v3"]
