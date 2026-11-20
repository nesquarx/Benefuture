from lifeimage.canonical import canonical_json, content_hash


def test_key_order_does_not_change_hash():
    assert content_hash({"a": 1, "b": [1, 2]}) == content_hash({"b": [1, 2], "a": 1})


def test_whitespace_and_unicode_normalised():
    a = {"label": "Café  au   lait\n"}
    b = {"label": "Café au lait"}
    assert content_hash(a) == content_hash(b)


def test_float_precision_fixed_at_six_places():
    assert content_hash({"w": 0.1 + 0.2}) == content_hash({"w": 0.3})
    assert content_hash({"w": 1.0}) == content_hash({"w": 1})
    assert content_hash({"w": 0.3}) != content_hash({"w": 0.300001})


def test_volatile_fields_excluded_at_any_depth():
    base = {"id": "x", "inner": {"v": 1}}
    noisy = {
        "id": "x",
        "timestamp": "2026-11-20T10:00:00Z",
        "run_id": "r1",
        "provenance": {"label": {"source": "s", "confidence": 0.5}},
        "inner": {"v": 1, "created_at": "now", "provenance": {}},
    }
    assert content_hash(base) == content_hash(noisy)


def test_real_changes_change_hash():
    assert content_hash({"id": "x", "label": "a"}) != content_hash({"id": "x", "label": "b"})
    assert content_hash([1, 2]) != content_hash([2, 1])


def test_canonical_json_is_deterministic_text():
    assert canonical_json({"b": 1, "a": "x  y"}) == '{"a":"x y","b":1}'


def test_nan_rejected():
    import pytest

    with pytest.raises(ValueError):
        canonical_json({"w": float("nan")})
