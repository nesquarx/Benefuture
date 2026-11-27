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


def _unpack(cards, variant):
    sectors = sorted((c for c in cards if is_sector(c)), key=lambda c: c["id"])
    fields = [c for c in cards if not is_sector(c)]
    fields.sort(key=(lambda c: c["id"]) if variant == 0 else (lambda c: _variant_key(variant, c["id"])))
    return sectors + fields


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


def ungrouped_pack(cards, variant=0):
    """The coarse pack with no grouping: sectors first (by id), then every field by id (variant 0) or by a hash of
    the variant and id (a fixed shuffle). Guessed links never reach it, so they cannot anchor an answer."""
    version = basemap_version(cards)
    body = "\n".join(_line(c) for c in _unpack(cards, variant)) + "\n"
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


# ---- the domain pack of two-pass extraction (LI.70): coarse and fine, with aliases and short descriptions ----
DOMAIN_PACK_MARK = "# domain pack"
FINE_DESC_CHARS = 90  # a fine domain's description is cut to this many characters at a word boundary
PACK_ALIASES = 2  # aliases listed per domain


def _cut(text, n):
    text = _WS.sub(" ", text).strip()
    if len(text) <= n:
        return text
    return text[:n].rsplit(" ", 1)[0].rstrip(",;:") + "..."


def _domain_line(card):
    cell = lambda s: _WS.sub(" ", s.replace("|", "/")).strip()
    aliases = "; ".join(cell(a["text"]) for a in card.get("aliases", [])[:PACK_ALIASES])
    desc = cell(card["description"]) if not card["id"].startswith("f.") else cell(_cut(card["description"], FINE_DESC_CHARS))
    if card["id"].startswith("f."):
        up = _heaviest_upstream(card)
        desc += f" [{up}]" if up else ""
    return f"{card['id']} | {cell(card['label'])} | {aliases} | {desc}"


def domain_pack(cards, variant=0):
    """The pass-2 pack: one line per domain, `id | label | aliases | description`; sectors, then coarse fields, then fine domains
    (each with its coarse parent in brackets), each block by id (variant 0) or by a fixed hash shuffle (variant i)."""
    key = (lambda c: c["id"]) if variant == 0 else (lambda c: _variant_key(variant, c["id"]))
    blocks = [sorted((c for c in cards if c["id"].startswith(pre)), key=key) for pre in ("s.", "c.", "f.")]
    ordered = [c for b in blocks for c in b]
    if len(ordered) != len(cards):
        raise ValueError("every domain id must start with s., c. or f.")
    body = "\n".join(_domain_line(c) for c in ordered) + "\n"
    version = basemap_version(cards)
    return f"{DOMAIN_PACK_MARK} | basemap {version} | {len(cards)} domains | ~{-(-len(body) // 4)} tokens\n{body}"


def pack_entries(text):
    """{id: {"label", "aliases", "description"}} of a domain pack found after its header in `text` (instructions before it are ignored)."""
    at = text.find(DOMAIN_PACK_MARK)
    if at < 0:
        raise ValueError("no domain pack in the text")
    out = {}
    for l in text[at:].splitlines()[1:]:
        parts = l.split(" | ")
        if len(parts) == 4:
            out[parts[0]] = {"label": parts[1], "aliases": [a for a in parts[2].split("; ") if a], "description": parts[3]}
    return out
