import pytest

from lifeimage.migration import apply_table, build_table, migrate_vector, validate_table

OPS = [
    {"op": "split", "old": "a", "new": [{"id": "a1", "weight": 0.6}, {"id": "a2", "weight": 0.4}]},
    {"op": "merge", "old": ["b", "c"], "new": "bc"},
    {"op": "rename", "old": "d", "new": "d2"},
    {"op": "deprecate", "old": "e", "successors": [{"id": "f", "weight": 1.0}]},
]
IDS = {"a", "b", "c", "d", "e", "f", "g"}


def total(v):
    return sum(v.values())


def test_table_is_sparse_linear_map_with_identity_default():
    t = build_table(OPS, existing_ids=IDS)
    assert t["a"] == {"a1": 0.6, "a2": 0.4}
    assert t["b"] == {"bc": 1.0} and t["c"] == {"bc": 1.0}
    assert t["d"] == {"d2": 1.0} and t["e"] == {"f": 1.0}
    assert "g" not in t


def test_migrate_vector_preserves_total_weight_and_splits_by_weight():
    t = build_table(OPS, existing_ids=IDS)
    v = {"a": 0.4, "b": 0.1, "c": 0.1, "d": 0.2, "e": 0.1, "g": 0.1}
    out = migrate_vector(v, t)
    assert abs(total(out) - 1.0) < 1e-9
    assert out["a1"] == pytest.approx(0.24) and out["a2"] == pytest.approx(0.16)
    assert out["bc"] == pytest.approx(0.2) and out["f"] == pytest.approx(0.1) and out["g"] == pytest.approx(0.1)
    assert all(k not in out for k in ("a", "b", "c", "d", "e"))


def test_migrating_is_a_pure_function():
    t = build_table(OPS, existing_ids=IDS)
    v = {"a": 1.0}
    before = dict(v)
    assert migrate_vector(v, t) == migrate_vector(v, t) and v == before


def test_migrate_vector_requires_a_distribution():
    t = build_table(OPS, existing_ids=IDS)
    with pytest.raises(ValueError):
        migrate_vector({"a": 0.5}, t)


@pytest.mark.parametrize(
    "ops",
    [
        [{"op": "split", "old": "a", "new": [{"id": "a1", "weight": 0.5}, {"id": "a2", "weight": 0.4}]}],
        [{"op": "deprecate", "old": "e", "successors": []}],
        [{"op": "rename", "old": "zzz", "new": "y"}],
        [{"op": "rename", "old": "d", "new": "d2"}, {"op": "merge", "old": ["d", "c"], "new": "x"}],
        [{"op": "explode", "old": "d", "new": "x"}],
    ],
)
def test_bad_tables_rejected(ops):
    with pytest.raises(ValueError):
        build_table(ops, existing_ids=IDS)


def test_retired_ids_are_never_reused():
    with pytest.raises(ValueError):
        build_table([{"op": "rename", "old": "d", "new": "old.retired"}], existing_ids=IDS, retired_ids={"old.retired"})


def test_validate_table_catches_leaky_hand_edited_table():
    with pytest.raises(ValueError):
        validate_table({"a": {"a1": 0.5}})  # mass would leak on migration


def test_apply_table_to_many_vectors():
    t = build_table(OPS, existing_ids=IDS)
    outs = apply_table([{"a": 1.0}, {"g": 1.0}], t)
    assert [abs(total(o) - 1) < 1e-9 for o in outs] == [True, True]
