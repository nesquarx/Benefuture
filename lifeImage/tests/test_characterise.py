"""Characterisation battery: image features, signature verdicts, blind identification, the humanity-white check.

Features are computed from the image state (levels per slice and layer) and the rows' dates. These tests state what
a feature must report on images built to show exactly one thing, what the verdict rule must decide on data built to
sit on each side of it, and what the classifier must not be able to do (read labels it was not given).
"""
import hashlib
import json
import math
import random
from pathlib import Path

import pytest

from lifeimage import characterise as ch

ROOT = Path(__file__).resolve().parent.parent
SIGS = ROOT / "data/gold/characterisation_signatures_v1.json"
# the sha256 of the pre-registered signatures as committed before any new render (74e84ff)
SIGS_SHA = "a0663d12af98743d6e5a88f48bab1fa97da0627d236070a74b7c28b5853478fd"


def sl(id, start, width, solid=(0, 0, 0), claimed=(0, 0, 0), ring="field", newest=None):
    r0, r1 = (0.44, 0.96) if ring == "field" else (0.16, 0.42)
    return ch.Slice(id, ring, start, width, r0, r1, tuple(solid), tuple(claimed), newest)


def state(slices, asof=20000):
    return ch.State(slices, asof)


def ring(n=36, **kw):  # n equal field slices tiling the circle
    return [sl(f"f{i}", i * 360 / n, 360 / n, **kw) for i in range(n)]


# ---------- features ----------

def test_a_solid_red_image_is_all_red_and_not_grainy_and_a_claimed_red_one_is_all_grain():
    f = ch.features(state(ring(solid=(0.8, 0, 0))))
    assert f["share_red"] == pytest.approx(1.0) and f["red_grain_share"] == pytest.approx(0.0)
    g = ch.features(state(ring(claimed=(0.8, 0, 0))))
    assert g["share_red"] == pytest.approx(1.0) and g["red_grain_share"] == pytest.approx(1.0)
    h = ch.features(state(ring(n=2, solid=(0.4, 0, 0)) + [sl("x", 0, 1, claimed=(0.4, 0, 0))]))
    assert 0.0 < h["red_grain_share"] < 0.2  # a sliver of claim among much solid


def test_a_white_image_has_no_chroma_and_perfect_balance():
    f = ch.features(state(ring(solid=(0.5, 0.5, 0.5))))
    assert f["chroma"] == pytest.approx(0.0) and f["balance_distance"] == pytest.approx(0.0, abs=1e-9)
    assert f["share_red"] == pytest.approx(1 / 3) and f["share_green"] == pytest.approx(1 / 3)
    r = ch.features(state(ring(solid=(0.5, 0, 0))))
    assert r["balance_distance"] == pytest.approx(2 / 3)


def test_luminance_weights_green_most_and_blue_least():
    lum = lambda c: ch.features(state(ring(solid=c)))["luminance"]
    assert lum((0, 1, 0)) == pytest.approx(0.7152) and lum((1, 0, 0)) == pytest.approx(0.2126) and lum((0, 0, 1)) == pytest.approx(0.0722)
    assert ch.features(state(ring()))["luminance"] == 0.0


def test_spread_entropy_is_one_for_an_even_circle_and_near_zero_for_one_degree():
    assert ch.features(state(ring(solid=(0.5, 0.5, 0.5))))["spread_entropy"] == pytest.approx(1.0, abs=1e-6)
    one = [sl("a", 10, 1, solid=(1, 1, 1)), sl("b", 11, 349)]
    assert ch.features(state(one))["spread_entropy"] < 0.02
    assert ch.features(state(ring()))["spread_entropy"] == 0.0


def test_red_spread_entropy_reads_the_red_channel_only():
    s = [sl("a", 0, 180, solid=(0, 1, 0)), sl("b", 180, 180, solid=(1, 0, 0))]
    f = ch.features(state(s))
    assert f["spread_entropy"] > 0.95 and f["red_spread_entropy"] < 0.9 and f["red_spread_entropy"] > 0.8


def test_clusters_count_separated_lit_runs_and_merge_small_gaps_and_drop_slivers():
    two = [sl("a", 0, 20, solid=(1, 1, 1)), sl("b", 20, 160), sl("c", 180, 20, solid=(1, 1, 1)), sl("d", 200, 160)]
    assert ch.features(state(two))["n_clusters"] == 2
    one = [sl("a", 0, 20, solid=(1, 1, 1)), sl("b", 20, 160), sl("d", 180, 180)]
    assert ch.features(state(one))["n_clusters"] == 1
    gap = [sl("a", 0, 20, solid=(1, 1, 1)), sl("g", 20, 10), sl("c", 30, 20, solid=(1, 1, 1)), sl("d", 50, 310)]
    assert ch.features(state(gap))["n_clusters"] == 1  # a gap under 15 degrees merges
    sliver = [sl("a", 0, 60, solid=(1, 1, 1)), sl("b", 60, 120), sl("c", 180, 3, solid=(1, 1, 1)), sl("d", 183, 177)]
    assert ch.features(state(sliver))["n_clusters"] == 1  # under a tenth of the mass is not a cluster
    wrap = [sl("a", 350, 10, solid=(1, 1, 1)), sl("b", 0, 10, solid=(1, 1, 1)), sl("c", 10, 340)]
    assert ch.features(state(wrap))["n_clusters"] == 1  # a run across 0 degrees is one run


def test_cluster_age_gap_is_negative_when_the_older_cluster_is_dimmer():
    old, new = 15000, 19800
    s = [sl("a", 0, 20, solid=(0.2, 0.2, 0.2), newest=old), sl("b", 20, 160), sl("c", 180, 20, solid=(0.9, 0.9, 0.9), newest=new), sl("d", 200, 160)]
    assert ch.features(state(s))["cluster_age_gap"] < -0.3
    s2 = [sl("a", 0, 20, solid=(0.9, 0.9, 0.9), newest=old), sl("b", 20, 160), sl("c", 180, 20, solid=(0.2, 0.2, 0.2), newest=new), sl("d", 200, 160)]
    assert ch.features(state(s2))["cluster_age_gap"] > 0.3
    assert math.isnan(ch.features(state(ring(solid=(1, 1, 1))))["cluster_age_gap"])


def test_sector_arcs_take_the_fields_whose_centre_they_contain():
    sectors = [sl("s.a", 0, 180, ring="sector"), sl("s.b", 180, 180, ring="sector")]
    fields = [sl("f1", 10, 20, solid=(0, 1, 0)), sl("f2", 200, 20, solid=(0, 0, 1)), sl("f3", 100, 20, solid=(0, 1, 0))]
    f = ch.features(state(sectors + fields))
    assert f["arc_share:s.a"] + f["arc_share:s.b"] == pytest.approx(1.0)
    assert f["arc_share:s.a"] > f["arc_share:s.b"]
    assert f["gb_in:s.a"] + f["gb_in:s.b"] == pytest.approx(1.0) and 0 < f["gb_in:s.b"] < 1
    assert f["gb_in:s.a+s.b"] == pytest.approx(1.0)
    assert f["max_arc_share"] == pytest.approx(max(f["arc_share:s.a"], f["arc_share:s.b"]))


def test_recency_luminances_split_current_from_past_domains():
    asof = 20000
    day = lambda y: asof - int(y * 365.25)
    s = [sl("a", 0, 20, solid=(0.9, 0.9, 0.9), newest=day(12)), sl("b", 20, 20, solid=(0.3, 0.3, 0.3), newest=day(1)), sl("c", 40, 20, solid=(0.6, 0.6, 0.6), newest=day(7))]
    f = ch.features(state(s, asof))
    assert f["past_luminance"] == pytest.approx(0.9) and f["current_luminance"] == pytest.approx(0.3)
    assert f["past_over_current"] == pytest.approx(3.0)
    assert math.isnan(ch.features(state([sl("a", 0, 20, solid=(0.9, 0.9, 0.9), newest=day(12))], asof))["past_over_current"])


def test_dimmed_share_is_the_decayed_share_of_the_evidence_and_zero_for_fresh_evidence():
    from conftest import make_row, membership
    fresh = [make_row(valid_time="2026-11", memberships=[membership("c.physics", "content")], magnitude=1.0)]
    old = fresh + [make_row(valid_time="1996-11", memberships=[membership("c.physics", "content")], magnitude=1.0)]
    assert ch.dimmed_share(fresh, "2026-11") == pytest.approx(0.0)
    assert ch.dimmed_share(old, "2026-11") == pytest.approx(1 - (1 + 0.25) / 2, abs=1e-4)  # 30 years in days is 29.9993 years
    assert ch.dimmed_share([], "2026-11") == 0.0


# ---------- the verdict rule ----------

def test_wilson_interval_matches_the_textbook_value():
    lo, hi = ch.wilson(8, 10)
    assert lo == pytest.approx(0.4902, abs=2e-3) and hi == pytest.approx(0.9433, abs=2e-3)
    assert ch.wilson(0, 0) == (0.0, 1.0)


def test_contrast_is_held_not_held_or_inconclusive_by_the_interval():
    rng = random.Random(1)
    big = [1.0 + rng.gauss(0, 0.1) for _ in range(40)]
    base = [0.5 + rng.gauss(0, 0.1) for _ in range(40)]
    assert ch.contrast_verdict(big, base, ">", 0.2)["verdict"] == "held"
    assert ch.contrast_verdict(big, base, "<", 0.2)["verdict"] == "not held"  # the wrong way round
    same = [0.5 + rng.gauss(0, 0.05) for _ in range(60)]
    base2 = [0.5 + rng.gauss(0, 0.05) for _ in range(60)]
    assert ch.contrast_verdict(same, base2, ">", 0.2)["verdict"] == "not held"  # an interval that excludes delta
    noisy_a, noisy_b = [0.9, 0.2, 1.1], [0.4, 0.3, 0.5]
    assert ch.contrast_verdict(noisy_a, noisy_b, ">", 0.1)["verdict"] == "inconclusive"
    # a significant effect smaller than the smallest effect that matters is not held
    assert ch.contrast_verdict([0.55 + rng.gauss(0, 0.01) for _ in range(50)], [0.5 + rng.gauss(0, 0.01) for _ in range(50)], ">", 0.2)["verdict"] == "not held"


def test_proportion_is_decided_by_the_wilson_interval_against_p0():
    assert ch.proportion_verdict(18, 20, 0.5)["verdict"] == "held"
    assert ch.proportion_verdict(2, 20, 0.5)["verdict"] == "not held"
    assert ch.proportion_verdict(3, 5, 0.5)["verdict"] == "inconclusive"
    assert ch.proportion_verdict(0, 0, 0.5)["verdict"] == "inconclusive"


# ---------- blind identification ----------

def blobs(n_per=12, k=3, sep=3.0, seed=0, dims=4):
    rng = random.Random(seed)
    X, y = [], []
    for c in range(k):
        for _ in range(n_per):
            X.append([sep * (c == d) + rng.gauss(0, 0.3) for d in range(dims)])
            y.append(f"c{c}")
    return X, y


def test_nearest_centroid_loo_identifies_separable_classes():
    X, y = blobs()
    assert ch.loo_accuracy(X, y)["accuracy"] > 0.95


def test_classifier_cannot_beat_chance_on_shuffled_labels_and_cannot_read_its_own_label():
    X, y = blobs(n_per=20)
    rng = random.Random(5)
    rng.shuffle(y)
    r = ch.loo_accuracy(X, y)
    assert r["wilson"][0] <= r["chance"] <= r["wilson"][1] + 0.1 and r["accuracy"] < 0.55
    single = ch.loo_accuracy([[0.0], [1.0], [2.0]], ["a", "b", "c"])  # each class has one member: held out, nothing to learn from
    assert single["accuracy"] == 0.0


def test_features_are_standardised_on_the_training_fold_only():
    X = [[0.0], [0.1], [0.2], [100.0]]
    y = ["a", "a", "a", "b"]
    r = ch.loo_accuracy(X, y)  # the outlier is the only b: held out it cannot be identified; the a's are
    assert r["correct"] == 3


def test_chance_is_reported_beside_the_uniform_and_the_majority_rate():
    X, y = blobs(n_per=5, k=4)
    r = ch.loo_accuracy(X, y)
    assert r["chance"] == pytest.approx(0.25) and r["majority"] == pytest.approx(0.25)


# ---------- humanity white ----------

def test_pooled_composite_of_complementary_images_tends_toward_white_and_of_one_hue_does_not():
    mix = [state(ring(solid=c)) for c in ((0.8, 0, 0), (0, 0.8, 0), (0, 0, 0.8))]
    p = ch.pooled(mix)
    assert all(abs(v - 1 / 3) < 0.02 for v in p["shares"].values()) and p["chroma_over_mean_chroma"] < 0.1
    red = ch.pooled([state(ring(solid=(0.8, 0, 0))) for _ in range(3)])
    assert red["shares"]["red"] > 0.9 and red["chroma_over_mean_chroma"] == pytest.approx(1.0)


# ---------- the pre-registration ----------

def test_signatures_json_and_markdown_list_the_same_ids_and_were_not_edited_after_registration():
    raw = SIGS.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == SIGS_SHA
    data = json.loads(raw)
    md = (ROOT / "data/gold/characterisation_signatures_v1.md").read_text(encoding="utf-8")
    ids = [s["id"] for s in data["signatures"]]
    assert len(ids) == len(set(ids)) >= 20
    for i in ids:
        assert f"| {i} |" in md, i


def test_every_signature_names_a_feature_the_battery_computes():
    data = json.loads(SIGS.read_text(encoding="utf-8"))
    names = ch.feature_names()
    for s in data["signatures"]:
        if s["kind"] in ("contrast", "band", "contrast_pooled"):
            f = s["feature"]
            assert f in names or f.startswith(("arc_share:", "gb_in:")) or f.startswith("pooled_"), (s["id"], f)
        assert s["confidence"] in ("low", "medium", "high")


# ---------- the data ----------

def test_extracted_rows_are_mapped_to_personas_for_every_variant_and_carry_claims_only():
    pops = ch.starter_rows("extracted")
    assert set(pops) == {0, 1, 2}
    for v, by in pops.items():
        assert len(by) == 40 and sum(len(r) for r in by.values()) > 100
        assert all(r["tier"] == "claimed" for rows in by.values() for r in rows)


def test_the_new_projection_shows_a_young_students_schooling_as_red_where_the_legacy_one_does_not():
    p = ch.starter_personas()[0]
    rows = ch.starter_rows("truth")[p["id"]]
    new = ch.image_state(rows, ch.world_basemap(), asof=p["as_of"])
    old = ch.image_state(rows, ch.world_basemap(), asof=p["as_of"], legacy=True)
    assert ch.features(new)["share_red"] > ch.features(old)["share_red"] + 0.1


def test_the_extended_population_is_deterministic_and_balanced():
    a, b = ch.extended_population(), ch.extended_population()
    assert [p["id"] for p in a] == [p["id"] for p in b] and len(a) == 144
    cells = {}
    for p in a:
        cells[(p["archetype"], p["calibration"])] = cells.get((p["archetype"], p["calibration"]), 0) + 1
    assert len(cells) == 24 and set(cells.values()) == {6}


# ---------- the tools ----------

def test_contact_sheet_shows_features_beside_every_image_and_legacy_reproduces_the_earlier_files(tmp_path):
    import importlib.util
    spec = importlib.util.spec_from_file_location("render_v0", ROOT / "tools/render_v0.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.main(tmp_path / "v1")
    html = (tmp_path / "v1/contact.html").read_text(encoding="utf-8")
    assert html.count("grainy red") >= 56 and "knowledge and potential" in html
    mod.main(tmp_path / "v0", legacy=True)
    old = ROOT / "data/images/v0"
    assert all((old / f.name).read_bytes() == f.read_bytes() for f in (tmp_path / "v0").glob("*.svg"))
    assert (tmp_path / "v1/persona-p001.svg").read_bytes() != (tmp_path / "v0/persona-p001.svg").read_bytes()


def test_the_report_tool_is_deterministic(tmp_path):
    import importlib.util
    spec = importlib.util.spec_from_file_location("characterise_tool", ROOT / "tools/characterise.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.main(tmp_path / "a")
    mod.main(tmp_path / "b")
    assert (tmp_path / "a.json").read_bytes() == (tmp_path / "b.json").read_bytes()
    assert (tmp_path / "a.md").read_text(encoding="utf-8").count("**held**") + (tmp_path / "a.md").read_text(encoding="utf-8").count("**not held**") + \
        (tmp_path / "a.md").read_text(encoding="utf-8").count("**inconclusive**") == len(json.loads(SIGS.read_text(encoding="utf-8"))["signatures"])
