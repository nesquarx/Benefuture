"""Context packs: the graph serialised as a compact, canonical text block a model reads from context.

The coarse pack is one line per domain, `id | label | description`: sectors first, then fields grouped by their
heaviest upstream link (groups in sector order, then any other group by id, then fields with no upstream), each
group sorted by id. The same cards give a byte-identical pack, whatever the input order or volatile fields. A
variant above 0 reorders the fields inside each group by a hash of the variant and id, so k variants differ in
prefix but each is stable across reruns.
"""
import hashlib
import re
from pathlib import Path

from .vocab import UPSTREAM

PACK_MARK = "# coarse pack"
_WS = re.compile(r"\s+")


def is_sector(card):
    return card["id"].startswith("s.")


def _line(card):
    cell = lambda s: _WS.sub(" ", s.replace("|", "/")).strip()
    return f"{card['id']} | {cell(card['label'])} | {cell(card['description'])}"


def _heaviest_upstream(card):
    ups = [l for l in card["links"] if l["rel"] == UPSTREAM]
    return min(ups, key=lambda l: (-l["weight"], l["id"]))["id"] if ups else None


def _variant_key(variant, cid):
    return hashlib.sha256(f"{variant}:{cid}".encode()).hexdigest()


def ordered_cards(cards, variant=0):
    sectors = sorted((c for c in cards if is_sector(c)), key=lambda c: c["id"])
    groups = {}
    for c in cards:
        if not is_sector(c):
            groups.setdefault(_heaviest_upstream(c), []).append(c)
    sector_ids = [s["id"] for s in sectors]
    keys = sorted((k for k in groups if k is not None), key=lambda k: (k not in sector_ids, sector_ids.index(k) if k in sector_ids else 0, k))
    keys += [None] if None in groups else []
    out = list(sectors)
    for k in keys:
        out += sorted(groups[k], key=(lambda c: c["id"]) if variant == 0 else (lambda c: _variant_key(variant, c["id"])))
    return out


def basemap_version(cards):
    versions = {c["basemap_version"] for c in cards}
    if len(versions) != 1:
        raise ValueError(f"cards span basemap versions {sorted(versions)}")
    return versions.pop()


def coarse_pack(cards, variant=0):
    version = basemap_version(cards)
    body = "\n".join(_line(c) for c in ordered_cards(cards, variant)) + "\n"
    tokens = -(-len(body) // 4)
    return f"{PACK_MARK} | basemap {version} | {len(cards)} domains | ~{tokens} tokens\n{body}"


def pack_ids(text):
    """Domain ids of a pack, found after the pack header (text before it, such as instructions, is ignored)."""
    at = text.find(PACK_MARK)
    lines = text[at:].splitlines()[1:] if at >= 0 else text.splitlines()
    return {l.split(" | ")[0] for l in lines if l.count(" | ") == 2 and not l.startswith("#")}


def write_pack(cards, root):
    path = Path(root) / f"coarse.{basemap_version(cards)}.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(coarse_pack(cards), encoding="utf-8")
    return path
