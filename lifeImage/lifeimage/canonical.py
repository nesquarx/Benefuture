"""Canonical serialisation and content hashing.

Equal content must hash equal: key order, whitespace, Unicode composition and float noise never change a hash, and
volatile fields (timestamps, run ids, provenance) never enter it. Omitting any of these makes unchanged cards miss
the answer cache.
"""
import hashlib
import json
import math
import re
import unicodedata

VOLATILE = frozenset({"timestamp", "created_at", "updated_at", "run_id", "provenance"})
FLOAT_PLACES = 6
_WS = re.compile(r"\s+")


def _text(s):
    return _WS.sub(" ", unicodedata.normalize("NFC", s)).strip()


def _norm(obj):
    if isinstance(obj, bool) or obj is None:
        return obj
    if isinstance(obj, str):
        return _text(obj)
    if isinstance(obj, int):
        return obj
    if isinstance(obj, float):
        if not math.isfinite(obj):
            raise ValueError("non-finite number is not canonical")
        r = round(obj, FLOAT_PLACES)
        return int(r) if r == int(r) else r
    if isinstance(obj, dict):
        return {_text(str(k)): _norm(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_norm(v) for v in obj]
    raise TypeError(f"not JSON data: {type(obj).__name__}")


def strip_volatile(obj, exclude=VOLATILE):
    """Copy of obj without volatile keys at any depth."""
    if isinstance(obj, dict):
        return {k: strip_volatile(v, exclude) for k, v in obj.items() if k not in exclude}
    if isinstance(obj, (list, tuple)):
        return [strip_volatile(v, exclude) for v in obj]
    return obj


def canonical_json(obj):
    return json.dumps(_norm(obj), sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def content_hash(obj, exclude=VOLATILE):
    return hashlib.sha256(canonical_json(strip_volatile(obj, exclude)).encode("utf-8")).hexdigest()
