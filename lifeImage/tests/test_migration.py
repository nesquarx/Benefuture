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


# ---- evidence memberships across a release ----------------------------------------------------------------------

from lifeimage.migration import convert_card_v0, convert_cards_v0, migrate_memberships, migrate_row  # noqa: E402

from conftest import make_row, membership  # noqa: E402


def per_rel(ms):
    out = {}
    for m in ms:
        out[m["rel"]] = out.get(m["rel"], 0.0) + m["weight"]
    return out


def as_map(ms):
    return {(m["domain"], m["rel"]): m["weight"] for m in ms}


def test_memberships_keep_each_relation_summing_to_one_and_split_by_weight():
    t = build_table(OPS, existing_ids=IDS)
    ms = [membership("a", "content", 0.5), membership("g", "content", 0.5), membership("d", "purpose", 1.0)]
    out = migrate_memberships(ms, t)
    assert per_rel(out) == pytest.approx({"content": 1.0, "purpose": 1.0})
    m = as_map(out)
    assert m[("a1", "content")] == pytest.approx(0.3) and m[("a2", "content")] == pytest.approx(0.2)
    assert m[("g", "content")] == pytest.approx(0.5) and m[("d2", "purpose")] == pytest.approx(1.0)


def test_colliding_targets_within_a_relation_add_instead_of_overwriting():
    t = build_table(OPS, existing_ids=IDS)
    ms = [membership("b", "content", 0.4), membership("c", "content", 0.35), membership("g", "content", 0.25)]
    out = migrate_memberships(ms, t)  # b and c merge into bc: 0.75
    assert as_map(out)[("bc", "content")] == pytest.approx(0.75)
    assert per_rel(out)["content"] == pytest.approx(1.0)


def test_same_domain_under_different_relations_stays_separate():
    t = build_table(OPS, existing_ids=IDS)
    ms = [membership("b", "content", 1.0), membership("c", "purpose", 1.0)]
    out = migrate_memberships(ms, t)
    assert as_map(out) == pytest.approx({("bc", "content"): 1.0, ("bc", "purpose"): 1.0})
    assert per_rel(out) == pytest.approx({"content": 1.0, "purpose": 1.0})


def test_migrate_row_changes_only_memberships_and_basemap_version():
    t = build_table(OPS, existing_ids=IDS)
    row = make_row(memberships=[membership("a", "content", 1.0)], magnitude=3.0)
    out = migrate_row(row, t, "2028.0")
    assert out["basemap_version"] == "2028.0" and row["basemap_version"] == "2027.0"
    assert {k: v for k, v in out.items() if k not in ("memberships", "basemap_version")} == {
        k: v for k, v in row.items() if k not in ("memberships", "basemap_version")}
    assert per_rel(out["memberships"]) == pytest.approx({"content": 1.0})


def test_migrate_memberships_rejects_relations_that_do_not_sum_to_one():
    with pytest.raises(ValueError, match="content"):
        migrate_memberships([membership("a", "content", 0.5)], build_table(OPS, existing_ids=IDS))


# ---- card migration: parents -> upstream, neighbours -> overlap -------------------------------------------------

def old_card(id, parents=(), neighbours=(), prov=None, **over):
    c = {"id": id, "label": id, "aliases": [], "description": "d", "level": "coarse", "anchors": [],
         "parents": [{"id": p, "weight": w} for p, w in parents],
         "neighbours": [{"id": n, "weight": w} for n, w in neighbours],
         "axes": None, "radius": None, "arc": None, "status": "score_only", "successors": [],
         "basemap_version": "0.0.0-draft",
         "provenance": prov if prov is not None else {"label": {"source": "s", "confidence": 0.6}}}
    c.update(over)
    return c


def link_map(card, rel):
    return {l["id"]: l["weight"] for l in card["links"] if l["rel"] == rel}


def test_card_migration_keeps_every_weight_under_the_right_relation():
    c = old_card("c", parents=[("p", 0.7), ("q", 0.3)], neighbours=[("n", 0.5), ("m", 0.25)])
    out = convert_card_v0(c)
    assert link_map(out, "upstream") == {"p": 0.7, "q": 0.3}
    assert link_map(out, "overlap") == {"n": 0.5, "m": 0.25}
    assert len(out["links"]) == 4 and "parents" not in out and "neighbours" not in out


def test_card_migration_keeps_a_domain_that_is_both_parent_and_neighbour_as_two_links():
    out = convert_card_v0(old_card("c", parents=[("p", 1.0)], neighbours=[("p", 0.4), ("n", 0.6)]))
    assert link_map(out, "upstream") == {"p": 1.0}
    assert link_map(out, "overlap") == {"p": 0.4, "n": 0.6}


def test_card_migration_keeps_ids_and_everything_else():
    c = old_card("c", parents=[("p", 1.0)], label="Label", description="Desc", status="stable", successors=[],
                 anchors=[{"source": "icf", "code": "d5", "label": "x"}])
    out = convert_card_v0(c)
    drop = ("parents", "neighbours", "links", "provenance")
    assert {k: v for k, v in out.items() if k not in drop} == {k: v for k, v in c.items() if k not in drop}


def test_card_migration_folds_link_provenance_to_the_weaker_confidence():
    prov = {"label": {"source": "s", "confidence": 0.6}, "parents": {"source": "drafted", "confidence": 0.5},
            "neighbours": {"source": "drafted", "confidence": 0.4}}
    out = convert_card_v0(old_card("c", parents=[("p", 1.0)], neighbours=[("n", 1.0)], prov=prov))
    assert out["provenance"]["links"] == {"source": "drafted", "confidence": 0.4}
    assert "parents" not in out["provenance"] and "neighbours" not in out["provenance"]
    assert out["provenance"]["label"] == prov["label"]


def test_card_migration_output_validates_and_input_is_untouched():
    from lifeimage.validate import validate_card
    c = old_card("c", parents=[("p", 0.6), ("q", 0.4)], neighbours=[("n", 0.5)])
    before = repr(c)
    validate_card(convert_card_v0(c))
    assert repr(c) == before


def test_card_migration_refuses_cards_already_migrated():
    out = convert_card_v0(old_card("c"))
    with pytest.raises(ValueError, match="parents"):
        convert_card_v0(out)


def test_convert_cards_preserves_order_and_count():
    cs = [old_card("a"), old_card("b", parents=[("a", 1.0)])]
    assert [c["id"] for c in convert_cards_v0(cs)] == ["a", "b"]


def test_seed_file_is_in_the_network_format_with_every_weight_conserved():
    import json
    from pathlib import Path
    from lifeimage.validate import validate_card
    rows = [json.loads(l) for l in (Path(__file__).resolve().parent.parent / "data/coarse/seed_v0.jsonl").open()]
    assert len(rows) == 263
    for r in rows:
        validate_card(r)
        assert "parents" not in r and "neighbours" not in r
    assert sum(1 for r in rows if link_map(r, "upstream")) == 247
    assert sum(1 for r in rows if link_map(r, "overlap")) == 246
