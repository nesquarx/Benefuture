"""Organisation generator: small entities with prospectus-like text and ground-truth rows (red first against a stub
that emits nothing)."""
import pytest

from lifeimage.generators import org
from lifeimage.generators.common import padded, seed_ids, validate_row
from lifeimage.validate import validate_entity

KINDS = {"cafe", "charity", "software_firm", "farm", "clinic", "sports_club"}


def test_kinds_cover_the_requested_shapes():
    assert KINDS <= set(org.KINDS)


@pytest.mark.parametrize("kind", sorted(KINDS))
def test_rows_meet_the_contract_and_the_prospectus_carries_the_claims(kind):
    ids = seed_ids()
    for seed in range(5):
        o = org.generate_org(seed, kind)
        validate_entity({"id": o.entity, "kind": "organisation"})
        assert len(o.rows) >= 12 and len(o.text.splitlines()) >= 10
        tiers = {r["tier"] for r in o.rows}
        assert tiers == {"claimed", "attested", "measured"}, tiers
        for r in o.rows:
            validate_row(r)
            assert r["entity"] == o.entity and r["confidence"] < 1 and r["entity_kind"] == "organisation"
            assert {m["domain"] for m in r["memberships"]} <= ids
            assert padded(r["valid_time"]) <= padded(r["record_time"]) <= padded(o.as_of)
            if r["tier"] == "claimed":
                assert r["provenance"]["source"].startswith("prospectus:")
                n = int(r["provenance"]["span"].lstrip("L"))
                by = {i: e for e in o.events for i in e["rows"]}
                assert by[o.rows.index(r)]["phrase"] in o.text.splitlines()[n - 1]
        assert o.name in o.text


def test_deterministic_and_seed_sensitive_and_kinds_differ_in_domains():
    a, b, c = org.generate_org(1, "cafe"), org.generate_org(1, "cafe"), org.generate_org(2, "cafe")
    assert a.rows == b.rows and a.text == b.text and a.rows != c.rows and a.name != c.name
    dom = lambda o: {m["domain"] for r in o.rows for m in r["memberships"]}
    assert dom(org.generate_org(1, "cafe")) != dom(org.generate_org(1, "software_firm"))
    assert "c.hospitality_work" in dom(a) or "c.restaurants_dining" in dom(a)
    assert "c.software_development" in dom(org.generate_org(1, "software_firm"))


def test_rare_harm_negative_rows_carry_option_sets_and_unknown_kind_is_rejected():
    neg = [r for s in range(60) for r in org.generate_org(s, "cafe").rows if r["channel"] == "negative"]
    assert 0 < len(neg) < 60 * 3 and all(r["option_set"] for r in neg)
    with pytest.raises(ValueError):
        org.generate_org(1, "spaceport")
