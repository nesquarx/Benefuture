"""Responsibility by freedom (LI.40): a pure function of contribution, the option set at the moment of producing and
the harm of the outcome produced.

Red first on the outcome: the naive stub returns the contribution (it assumes full freedom), so the coerced handover,
the self-defender with no less harmful way out and the beneficiary all come back high instead of low."""
import pytest

from lifeimage.degradation import reset_warned
from lifeimage.governed import GOVERNED, governed
from lifeimage.responsibility import responsibility_from_freedom as rff
from lifeimage.validate import ValidationError


def opts(*pairs):
    return [{"alternative": a, "harm": h} for a, h in pairs]


# ---- what must hold ----
def test_coerced_handover_with_narrow_options_has_low_responsibility():
    # shopkeeper hands over the till (harm 1) because the only other course was being stabbed (harm 3)
    r = rff(0.4, opts(("refuse and be stabbed", 3)), 1)
    assert r <= 0.2


def test_self_defence_without_a_less_harmful_alternative_is_low():
    r = rff(1.0, opts(("submit and be stabbed", 3), ("scream, no one near", 3)), 2)
    assert r <= 0.2


def test_self_defence_with_a_less_harmful_alternative_available_is_higher():
    narrow = rff(1.0, opts(("submit and be stabbed", 3)), 2)
    wide = rff(1.0, opts(("step away and close the door", 0)), 2)
    assert wide >= 0.6 and wide > narrow + 0.3


def test_the_wider_the_gap_to_the_best_alternative_the_higher_the_responsibility():
    vals = [rff(1.0, opts(("alt", h)), 3) for h in (3, 2, 1, 0)]
    assert vals == sorted(vals) and len(set(vals)) == 4


def test_disproportionate_force_with_a_harmless_exit_is_fully_responsible():
    assert rff(1.0, opts(("walk away", 0), ("shout", 0)), 3) == pytest.approx(1.0)


def test_a_less_harmful_option_counts_only_if_strictly_less_harmful_than_the_outcome():
    assert rff(1.0, opts(("equally bad", 2)), 2) <= 0.2


def test_beneficiaries_who_only_receive_carry_none_whatever_the_options():
    for o in (None, [], opts(("anything", 0)), opts(("stab", 3))):
        assert rff(0.0, o, 2) == 0.0


def test_responsibility_stays_in_unit_interval_and_is_not_scaled_down_by_a_small_contribution():
    # overdetermination: a small contribution can still carry responsibility when the participant was free
    r = rff(0.07, opts(("do nothing", 0)), 3)
    assert 0.9 <= r <= 1.0


def test_an_empty_option_set_means_no_alternative_existed_and_is_low_not_the_default():
    assert rff(1.0, [], 2) <= 0.2


def test_a_harmless_outcome_leaves_nothing_to_excuse():
    assert rff(0.5, opts(("else", 0)), 0) == 1.0


# ---- null option set: governed default, logged, never full freedom ----
def test_null_option_set_uses_the_governed_default_and_never_full_freedom():
    log = []
    r = rff(1.0, None, 3, item="bd.x:clerk", log=log)
    assert r == pytest.approx(governed("responsibility.no_option_set")) and r < 1.0


def test_every_use_of_the_default_is_logged_as_a_degradation_record():
    log = []
    rff(1.0, None, 2, item="a:p", log=log)
    rff(0.5, None, 2, item="b:q", log=log)
    assert [r["step"] for r in log] == ["a:p", "b:q"]
    for rec in log:
        assert set(rec) == {"step", "mechanism", "substitute", "reason"}
        assert all(isinstance(v, str) and v.strip() for v in rec.values())
        assert "option set" in rec["reason"]


def test_provided_option_sets_and_zero_contribution_log_nothing():
    log = []
    rff(1.0, opts(("a", 0)), 2, log=log)
    rff(1.0, [], 2, log=log)
    rff(0.0, None, 2, log=log)  # a beneficiary needs no default: contribution 0 gives 0
    assert log == []


def test_the_default_is_warned_loudly_once_per_mechanism():
    reset_warned()
    with pytest.warns(RuntimeWarning, match="degraded"):
        rff(1.0, None, 2, log=[])
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter("error")
        rff(1.0, None, 2, log=[])


def test_governed_values_carry_default_and_source():
    for name, g in GOVERNED.items():
        assert 0 <= g["default"] <= 1 and g["source"].strip(), name
    assert governed("responsibility.floor") < governed("responsibility.no_option_set") < 1
    with pytest.raises(KeyError):
        governed("nope")


# ---- what must fail ----
@pytest.mark.parametrize("bad", [
    [{"alternative": "x", "harm": 4}], [{"alternative": "x", "harm": -1}], [{"alternative": "x", "harm": True}],
    [{"alternative": "x", "harm": 1.5}], [{"alternative": " ", "harm": 1}], [{"alternative": "x"}],
    [{"alternative": "x", "harm": 1, "extra": 1}], "walk away", [["x", 1]], {"alternative": "x", "harm": 1}])
def test_malformed_option_sets_are_rejected(bad):
    with pytest.raises((ValidationError, ValueError)):
        rff(1.0, bad, 2)


@pytest.mark.parametrize("c,h", [(-0.1, 1), (1.1, 1), (float("nan"), 1), (True, 1), (0.5, 4), (0.5, -1), (0.5, 1.5)])
def test_out_of_range_inputs_are_rejected(c, h):
    with pytest.raises((ValidationError, ValueError)):
        rff(c, opts(("a", 0)), h)
