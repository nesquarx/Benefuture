"""Schema validation plus the rules JSON Schema cannot state (upstream link weights and membership weights per
relation summing to one, vocabularies, tombstone successors, answers matching their task)."""
import json
import math
import re
from functools import lru_cache
from pathlib import Path

from jsonschema import Draft202012Validator

from .membership import VOCABS, real_types
from .packs import pack_entries, pack_ids
from .vocab import EVENT_RELATIONS, LINK_RELS, MEMBERSHIP_RELS, UPSTREAM

SCHEMA_DIR = Path(__file__).resolve().parent.parent / "schemas"
WEIGHT_TOL = 1e-6


class ValidationError(ValueError):
    pass


@lru_cache(maxsize=None)
def _validator(name):
    schema = json.loads((SCHEMA_DIR / f"{name}.schema.json").read_text())
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


def _schema(name, obj):
    errs = sorted(_validator(name).iter_errors(obj), key=lambda e: list(e.path))
    if errs:
        e = errs[0]
        raise ValidationError(f"{name}: {'/'.join(map(str, e.path)) or '<root>'}: {e.message}")


def _sums_to_one(refs, what, key="weight"):
    total = math.fsum(r[key] for r in refs)
    if abs(total - 1.0) > WEIGHT_TOL:
        raise ValidationError(f"{what} weights sum to {total}, not 1")


def validate_card(card, link_rels=LINK_RELS):
    _schema("card", card)
    seen = set()
    for l in card["links"]:
        if l["rel"] not in link_rels:
            raise ValidationError(f"link rel {l['rel']!r} is not in {sorted(link_rels)}")
        if l["id"] == card["id"]:
            raise ValidationError(f"{card['id']}: a domain cannot link to itself")
        if (l["id"], l["rel"]) in seen:
            raise ValidationError(f"{card['id']}: duplicate {l['rel']} link to {l['id']}")
        seen.add((l["id"], l["rel"]))
    upstream = [l for l in card["links"] if l["rel"] == UPSTREAM]
    if upstream:
        _sums_to_one(upstream, "upstream link")
    if (card["status"] == "tombstone") != bool(card["successors"]):
        raise ValidationError("successors are required exactly when status is tombstone")
    if card["successors"]:
        _sums_to_one(card["successors"], "successors")
    return card


def validate_evidence(row, allow_negative=False, relations=EVENT_RELATIONS, membership_rels=MEMBERSHIP_RELS):
    _schema("evidence", row)
    if row["relation"] not in relations:
        raise ValidationError(f"relation {row['relation']!r} is not in {sorted(relations)}")
    by_rel, seen = {}, set()
    for m in row["memberships"]:
        if m.get("counterfactual") is not None and m["rel"] != "outcome":
            raise ValidationError("a counterfactual belongs to an outcome membership only")
        if m["rel"] not in membership_rels:
            raise ValidationError(f"membership rel {m['rel']!r} is not in {sorted(membership_rels)}")
        if (m["domain"], m["rel"]) in seen:
            raise ValidationError(f"duplicate {m['rel']} membership of {m['domain']}")
        seen.add((m["domain"], m["rel"]))
        by_rel.setdefault(m["rel"], []).append(m)
    for rel, ms in sorted(by_rel.items()):
        _sums_to_one(ms, f"{rel} membership")
    if (row["channel"] == "negative") != (row["sign"] == -1):
        raise ValidationError("sign is -1 exactly when the channel is negative")
    if row["channel"] == "negative" and not allow_negative:
        raise ValidationError("the negative channel is reserved")
    return row


def validate_task(task):
    _schema("task", task)
    return task


LINKS_MAX_UPSTREAM = 3
LINKS_MAX_OVERLAP = 6


def validate_links_answer(answer, task, ids=None):
    """A links answer: verdict "links", 1-3 upstream ids with weights summing to 1, 0-6 distinct overlap ids; with
    ids (the pack's) and the task, every id must exist in the pack and none may be the field itself."""
    if answer.get("verdict") != "links":
        raise ValidationError(f"links verdict must be 'links', not {answer.get('verdict')!r}")
    if "upstream" not in answer or "overlap" not in answer:
        raise ValidationError("a links answer needs upstream and overlap")
    up, ov = answer["upstream"], answer["overlap"]
    if not 1 <= len(up) <= LINKS_MAX_UPSTREAM:
        raise ValidationError(f"{len(up)} upstream domains, expected 1-{LINKS_MAX_UPSTREAM}")
    _sums_to_one([{"weight": w} for w in up.values()], "upstream")
    if len(ov) > LINKS_MAX_OVERLAP or len(set(ov)) != len(ov):
        raise ValidationError(f"overlap must be at most {LINKS_MAX_OVERLAP} distinct ids")
    own = task["input"]["card"]["id"]
    for i in [*up, *ov]:
        if i == own:
            raise ValidationError(f"{own}: a domain cannot link to itself")
        if ids is not None and i not in ids:
            raise ValidationError(f"{i} is not in the pack")
    return answer


def validate_membership_answer(answer, vocab, ids=None):
    """A membership answer: verdict "membership", `types` holding exactly the vocabulary's types, each null or a
    non-empty {domain id: weight} summing to 1 (every id in the pack, when given), and `other` (string or null)."""
    if answer.get("verdict") != "membership":
        raise ValidationError(f"membership verdict must be 'membership', not {answer.get('verdict')!r}")
    if "types" not in answer or "other" not in answer:
        raise ValidationError("a membership answer needs types and other")
    types, want = answer["types"], VOCABS[vocab]["types"]
    if sorted(types) != sorted(want):
        raise ValidationError(f"types {sorted(types)} differ from the vocabulary's {sorted(want)}")
    if isinstance(answer["other"], str) and not answer["other"].strip():
        raise ValidationError("other must name a relation or be null, not blank")
    for t, ws in types.items():
        if ws is None:
            continue
        if not ws:
            raise ValidationError(f"{t}: an empty map; use null when the type does not apply")
        _sums_to_one([{"weight": w} for w in ws.values()], f"{t} membership")
        for i in ws:
            if ids is not None and i not in ids:
                raise ValidationError(f"{i} is not in the pack")
    return answer


FIT_MAX = 10
RANKED_MEMBERSHIP_VERSION = 3  # membership prompt versions from here on carry the ranked stopping rule (LI.67)
RANKED_EXTRACT_VERSION = 2  # extract prompt versions from here on carry it


def _fit_floor(floor):
    if floor is not None:
        return floor
    from .governed import governed
    return governed("membership.fit_floor")


def membership_fit_floor(prompt_version):
    from .governed import membership_fit_floor as f
    return f(prompt_version)


def _int_fit(x):
    return isinstance(x, int) and not isinstance(x, bool) and 0 <= x <= FIT_MAX


def validate_ranked_types(types, ranks, want, ids=None, where="", floor=None, allow_all_null=False):
    """LI.67: per relation, `types` is null or {domain: weight} in rank order, and `ranks` null exactly then, else
    {"listed": [{"domain", "fit"}...], "rejected": {"domain", "fit"}}. Rejected: lists that are unranked (fits or weights
    rise down the list), a listed domain below the floor, weights not summing to 1, and a list that stopped while its best
    rejected domain is at or above the floor (or that is not auditable: no rejected domain)."""
    floor = _fit_floor(floor)
    pre = f"{where}: " if where else ""
    if not isinstance(types, dict) or sorted(types) != sorted(want):
        raise ValidationError(f"{pre}types must be exactly {sorted(want)}")
    if not isinstance(ranks, dict) or sorted(ranks) != sorted(want):
        raise ValidationError(f"{pre}ranks must be exactly {sorted(want)} (the fit record of the ranked stopping rule)")
    for t in want:
        ws, rk = types[t], ranks[t]
        if ws is None or rk is None:
            if ws is not None or rk is not None:
                raise ValidationError(f"{pre}{t}: types and ranks must both be null or both be given")
            continue
        if not isinstance(ws, dict) or not ws:
            raise ValidationError(f"{pre}{t}: types must be null or a non-empty {{domain: weight}} map")
        if any(isinstance(w, bool) or not isinstance(w, (int, float)) or w <= 0 for w in ws.values()):
            raise ValidationError(f"{pre}{t}: weights must be positive numbers")
        _sums_to_one([{"weight": w} for w in ws.values()], f"{pre}{t} membership")
        if ids is not None:
            for i in ws:
                if i not in ids:
                    raise ValidationError(f"{pre}{i} is not in the pack")
        if not isinstance(rk, dict) or set(rk) != {"listed", "rejected"}:
            raise ValidationError(f"{pre}{t}: ranks must have exactly listed and rejected")
        listed = rk["listed"]
        if not isinstance(listed, list) or not listed or not all(isinstance(e, dict) and set(e) == {"domain", "fit"} for e in listed):
            raise ValidationError(f"{pre}{t}: listed must be a non-empty list of {{domain, fit}}")
        doms = [e["domain"] for e in listed]
        if doms != list(ws):
            raise ValidationError(f"{pre}{t}: listed domains {doms} differ from the weighted domains {list(ws)} (order included)")
        fits = [e["fit"] for e in listed]
        if not all(_int_fit(f) for f in fits):
            raise ValidationError(f"{pre}{t}: fits must be integers 0 to {FIT_MAX}")
        for d, f in zip(doms, fits):
            if f < floor:
                raise ValidationError(f"{pre}{t}: {d} is listed with fit {f}, below the floor {floor}")
        if any(a < b for a, b in zip(fits, fits[1:])):
            raise ValidationError(f"{pre}{t}: unranked, fits {fits} rise down the list")
        wl = list(ws.values())
        if any(a < b - WEIGHT_TOL for a, b in zip(wl, wl[1:])):
            raise ValidationError(f"{pre}{t}: unranked, weights {wl} rise down the list")
        rej = rk["rejected"]
        if not isinstance(rej, dict) or set(rej) != {"domain", "fit"} or not _int_fit(rej["fit"]):
            raise ValidationError(f"{pre}{t}: rejected must be {{domain, fit}} with an integer fit (the stopping point is audited)")
        if rej["domain"] in doms:
            raise ValidationError(f"{pre}{t}: the rejected domain {rej['domain']} is also listed")
        if ids is not None and rej["domain"] not in ids:
            raise ValidationError(f"{pre}{rej['domain']} is not in the pack")
        if rej["fit"] >= floor:
            raise ValidationError(f"{pre}{t}: stopped early, the best rejected domain {rej['domain']} has fit {rej['fit']}, at or above the floor {floor}")
    if all(types[t] is None for t in want) and not allow_all_null:
        raise ValidationError(f"{pre}every relation is null")
    return types


def validate_ranked_membership_answer(answer, vocab, ids=None, floor=None):
    """A v3+ membership answer: verdict "membership", `types` and `ranks` over the vocabulary's real types (no placebo),
    ranked per `validate_ranked_types`, and `other` (string or null). Without `floor`, the floor is that of the answer's
    prompt_version when it carries one (v3: 4, v4: 5; `governed.membership_fit_floor`), else the governed v3 floor."""
    if answer.get("verdict") != "membership":
        raise ValidationError(f"membership verdict must be 'membership', not {answer.get('verdict')!r}")
    for k in ("types", "ranks", "other"):
        if k not in answer:
            raise ValidationError(f"a ranked membership answer needs {k}")
    if isinstance(answer["other"], str) and not answer["other"].strip():
        raise ValidationError("other must name a relation or be null, not blank")
    pv = answer.get("prompt_version")
    if floor is None and isinstance(pv, int) and not isinstance(pv, bool):
        from .governed import membership_fit_floor
        floor = membership_fit_floor(pv)
    validate_ranked_types(answer["types"], answer["ranks"], real_types(vocab), ids, floor=floor)
    return answer


# ---- two-pass extraction (LI.70): pass 1 blind, pass 2 map ----
BLIND_RELS = ("form", "content", "outcome", "setting")
BLIND_LINK_TYPES = ("part_of", "causes", "re_description", "concurrent")
BLIND_LABEL_MAX = 60
_DOMAIN_ID = re.compile(r"\b[csf]\.[a-z][a-z0-9_]*\b")


def norm_label(label):
    """A blind label compared case-, space- and punctuation-insensitively."""
    return re.sub(r"[^a-z0-9]+", " ", label.lower()).strip()


def domain_ids_in(text, ids=None):
    """Domain-id-like tokens in `text` (the dotted `c.`, `f.`, `s.` form), and, given the pack's ids, any of them present verbatim."""
    found = set(_DOMAIN_ID.findall(text))
    if ids:
        found |= {i for i in ids if i in text}
    return sorted(found)


def _strings(obj):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from _strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _strings(v)


def _line(x):
    return isinstance(x, str) and bool(x.strip()) and "\n" not in x


def validate_blind_answer(answer, ids=None, floor=None, max_labels=None):
    """A pass-1 answer: verdict "blind", `blind` with exactly the four relations (each null or a ranked list of {label, fit, gloss}: labels
    of one to 60 characters, integer fits 0-10 not below the blind floor and not rising, at most `blind.max_labels`, no duplicate labels, a
    one-line gloss), at least one non-null, and `relational` (participants, action, outcome with counterfactual, links). No string anywhere
    may be a domain id: pass 1 does not see the domain set."""
    from .governed import governed
    floor = governed("blind.fit_floor") if floor is None else floor
    max_labels = governed("blind.max_labels") if max_labels is None else max_labels
    if answer.get("verdict") != "blind":
        raise ValidationError(f"blind verdict must be 'blind', not {answer.get('verdict')!r}")
    for k in ("blind", "relational"):
        if k not in answer:
            raise ValidationError(f"a blind answer needs {k} (relational extraction, LI.65)" if k == "relational" else f"a blind answer needs {k}")
    bl = answer["blind"]
    if not isinstance(bl, dict) or sorted(bl) != sorted(BLIND_RELS):
        raise ValidationError(f"blind must have exactly the keys {sorted(BLIND_RELS)}")
    for rel in BLIND_RELS:
        ls = bl[rel]
        if ls is None:
            continue
        if not isinstance(ls, list) or not ls:
            raise ValidationError(f"{rel}: null or a non-empty list of labels")
        if len(ls) > max_labels:
            raise ValidationError(f"{rel}: {len(ls)} labels, at most {max_labels}")
        seen, fits = set(), []
        for e in ls:
            if not isinstance(e, dict) or set(e) != {"label", "fit", "gloss"}:
                raise ValidationError(f"{rel}: each label must be exactly {{label, fit, gloss}}")
            lab = e["label"]
            if not isinstance(lab, str) or not lab.strip() or len(lab) > BLIND_LABEL_MAX:
                raise ValidationError(f"{rel}: a label is a phrase of 1 to {BLIND_LABEL_MAX} characters")
            if not _line(e["gloss"]):
                raise ValidationError(f"{rel}: {lab!r} needs a non-empty one-line gloss")
            if not _int_fit(e["fit"]):
                raise ValidationError(f"{rel}: fit of {lab!r} must be an integer 0 to {FIT_MAX}")
            if e["fit"] < floor:
                raise ValidationError(f"{rel}: {lab!r} is listed with fit {e['fit']}, below the blind floor {floor}")
            n = norm_label(lab)
            if n in seen:
                raise ValidationError(f"{rel}: duplicate label {lab!r}")
            seen.add(n)
            fits.append(e["fit"])
        if any(a < b for a, b in zip(fits, fits[1:])):
            raise ValidationError(f"{rel}: unranked, fits {fits} rise down the list")
    if all(bl[r] is None for r in BLIND_RELS):
        raise ValidationError("every relation is null")
    rel = answer["relational"]
    if not isinstance(rel, dict) or set(rel) != {"participants", "action", "outcome", "links"}:
        raise ValidationError("relational must have exactly participants, action, outcome and links")
    refs = set()
    if not isinstance(rel["participants"], list):
        raise ValidationError("relational participants must be a list")
    for p in rel["participants"]:
        if not isinstance(p, dict) or set(p) != {"ref", "role"} or not _line(p["ref"]) or not _line(p["role"]):
            raise ValidationError("each participant must be {ref, role} with a ref and a role")
        if p["ref"] in refs:
            raise ValidationError(f"participant ref {p['ref']!r} is used twice")
        refs.add(p["ref"])
    if not _line(rel["action"]):
        raise ValidationError("relational action must be a non-empty line")
    o = rel["outcome"]
    if o is not None and (not isinstance(o, dict) or set(o) != {"text", "counterfactual"} or not _line(o["text"])
                          or not (o["counterfactual"] is None or _line(o["counterfactual"]))):
        raise ValidationError("relational outcome must be null or {text, counterfactual} (counterfactual a line or null)")
    if not isinstance(rel["links"], list):
        raise ValidationError("relational links must be a list")
    for l in rel["links"]:
        if not isinstance(l, dict) or set(l) != {"type", "other"} or l["type"] not in BLIND_LINK_TYPES or not _line(l["other"]):
            raise ValidationError(f"each link must be {{type, other}} with type in {list(BLIND_LINK_TYPES)}")
    bad = sorted({i for s in _strings({"blind": bl, "relational": rel, "reason": answer.get("reason", "")}) for i in domain_ids_in(s, ids)})
    if bad:
        raise ValidationError(f"pass 1 must not use domain ids, found {bad}")
    return answer


MAP_ACTIONS = ("match", "new_domain_candidate", "noise")
MAP_KINDS = ("exact", "synonym")


def blind_refs(task):
    """{ref: (relation, label entry)} of a map task's blind labels."""
    out = {}
    for rel in BLIND_RELS:
        for e in (task["input"]["blind"].get(rel) or []):
            out[e["ref"]] = (rel, e)
    return out


def validate_map_answer(answer, task, entries, floor=None, version=1):
    """A pass-2 answer: verdict "map"; `types` and `ranks` obey the ranked stopping rule at the v4 floor over ids of the pack (all four
    relations may be null when nothing matched); `labels` holds exactly one entry per blind label of the task: a `match` (pack id, kind
    exact or synonym, `match` confidence strictly between 0 and 1; `exact` only when the label equals the domain's label or an alias), a
    `new_domain_candidate` (proposed_label, gloss, 1-3 nearest ids, a coarse or sector parent) or a `noise` (reason). Every domain of
    `types[rel]` must be matched by a blind label of that relation: an unanchored domain is not a two-pass membership.

    `version` 2 (`map.v2`, the hybrid): a label may have several `match` entries (distinct domains: a fine domain and its coarse parent), a
    `new_domain_candidate` or a `noise` is its only entry; the answer also carries `unlabelled_add`, a list of `{relation, domain}` naming
    every listed domain that no label of its relation matched (and only those): a listed domain is anchored by a label or named there, never both."""
    if floor is None:
        from .governed import membership_fit_floor
        floor = membership_fit_floor(4)
    if answer.get("verdict") != "map":
        raise ValidationError(f"map verdict must be 'map', not {answer.get('verdict')!r}")
    for k in ("types", "ranks", "labels") + (("unlabelled_add",) if version >= 2 else ()):
        if k not in answer:
            raise ValidationError(f"a map answer needs {k}")
    ids = set(entries)
    validate_ranked_types(answer["types"], answer["ranks"], BLIND_RELS, ids, floor=floor, allow_all_null=True)
    refs = blind_refs(task)
    labels = answer["labels"]
    if not isinstance(labels, list):
        raise ValidationError("labels must be a list with one entry per blind label")
    seen, matched = set(), {r: set() for r in BLIND_RELS}
    pairs, review = set(), set()
    for e in labels:
        if not isinstance(e, dict) or not isinstance(e.get("ref"), str):
            raise ValidationError("each label entry needs a ref")
        ref = e["ref"]
        if ref not in refs:
            raise ValidationError(f"unknown ref {ref!r}")
        multi = version >= 2 and e.get("action") == "match" and ref in seen and ref not in review
        if ref in seen and not multi:
            raise ValidationError(f"ref {ref!r} appears twice" + (" (a new_domain_candidate or a noise is the only entry of its ref)" if version >= 2 else ""))
        seen.add(ref)
        rel, blind = refs[ref]
        act = e.get("action")
        if act not in MAP_ACTIONS:
            raise ValidationError(f"{ref}: action {act!r} is not in {list(MAP_ACTIONS)}")
        want = {"match": {"ref", "action", "domain", "kind", "match"},
                "new_domain_candidate": {"ref", "action", "proposed_label", "gloss", "nearest", "parent"},
                "noise": {"ref", "action", "reason"}}[act]
        if set(e) != want:
            raise ValidationError(f"{ref}: keys of a {act} must be exactly {sorted(want)}")
        if act == "match":
            if e["domain"] not in ids:
                raise ValidationError(f"{ref}: {e['domain']} is not in the pack")
            if e["kind"] not in MAP_KINDS:
                raise ValidationError(f"{ref}: kind {e['kind']!r} is not in {list(MAP_KINDS)}")
            m = e["match"]
            if isinstance(m, bool) or not isinstance(m, (int, float)) or not 0 < m < 1:
                raise ValidationError(f"{ref}: match {m!r} must be a number strictly between 0 and 1")
            ent = entries[e["domain"]]
            if e["kind"] == "exact" and norm_label(blind["label"]) not in {norm_label(ent["label"]), *map(norm_label, ent["aliases"])}:
                raise ValidationError(f"{ref}: kind exact, but {blind['label']!r} equals neither the label nor an alias of {e['domain']} (use synonym)")
            if (ref, e["domain"]) in pairs:
                raise ValidationError(f"{ref}: {e['domain']} appears twice for the same label (duplicate match)")
            pairs.add((ref, e["domain"]))
            matched[rel].add(e["domain"])
        elif act == "new_domain_candidate":
            review.add(ref)
            for k in ("proposed_label", "gloss"):
                if not _line(e[k]):
                    raise ValidationError(f"{ref}: {k} must be a non-empty line")
            near = e["nearest"]
            if not isinstance(near, list) or not 1 <= len(near) <= 3 or len(set(near)) != len(near):
                raise ValidationError(f"{ref}: nearest must be 1 to 3 distinct pack ids")
            for i in [*near, e["parent"]]:
                if i not in ids:
                    raise ValidationError(f"{ref}: {i} is not in the pack")
            if not e["parent"].startswith(("c.", "s.")):
                raise ValidationError(f"{ref}: parent {e['parent']} must be a coarse field or a sector")
        else:
            review.add(ref)
            if not _line(e["reason"]):
                raise ValidationError(f"{ref}: a noise entry needs a one-line reason")
    missing = sorted(set(refs) - seen)
    if missing:
        raise ValidationError(f"every blind label needs exactly one entry (a match or a review); none for {missing}")
    added = _validate_unlabelled(answer, ids, matched) if version >= 2 else set()
    for rel in BLIND_RELS:
        for d in answer["types"][rel] or {}:
            if d not in matched[rel] and (rel, d) not in added:
                raise ValidationError(f"{rel}: {d} is anchored by no blind label of {rel} and is not named in unlabelled_add")
    return answer


def _validate_unlabelled(answer, ids, matched):
    """The set of (relation, domain) of a map.v2 answer's `unlabelled_add`: a list of exactly-keyed entries naming domains listed in `types`
    of that relation that no label of the relation matched, each once."""
    add = answer["unlabelled_add"]
    if not isinstance(add, list):
        raise ValidationError("unlabelled_add must be a list (empty when none)")
    out = set()
    for e in add:
        if not isinstance(e, dict) or set(e) != {"relation", "domain"}:
            raise ValidationError("each unlabelled_add entry needs exactly the keys ['domain', 'relation']")
        rel, d = e["relation"], e["domain"]
        if rel not in BLIND_RELS:
            raise ValidationError(f"unlabelled_add: relation {rel!r} is not in {list(BLIND_RELS)}")
        if d not in ids:
            raise ValidationError(f"unlabelled_add: {d} is not in the pack")
        if d not in (answer["types"][rel] or {}):
            raise ValidationError(f"unlabelled_add: {d} is not listed in types of {rel}")
        if d in matched[rel]:
            raise ValidationError(f"unlabelled_add: {d} is matched by a label of {rel}; it is not unlabelled, remove it from unlabelled_add")
        if (rel, d) in out:
            raise ValidationError(f"unlabelled_add: {rel} {d} appears twice (duplicate)")
        out.add((rel, d))
    return out


EXTRACT_KEYS = {"span", "relation", "channel", "magnitude", "valid_time", "types"}
EXTRACT_CHANNELS = ("positive", "prediction")  # the negative channel is reserved
EXTRACT_MAGNITUDE_MAX = 1.5
_SPAN = re.compile(r"^L(\d+)$")
_VALID_TIME = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")


def validate_extract_answer(answer, task, ids=None, ranked=False, floor=None):
    """An extract answer: verdict "rows" and `rows`, each row exactly span (`L<n>` of a non-blank line of the task's
    `lines`), relation (an event relation), channel (positive or prediction), magnitude (0 to 1.5), valid_time (null or a
    date) and `types` (exactly the A3S types, each null or {domain: weight} summing to 1, ids in the pack when given,
    at least one non-null). An answer with no rows is valid. With `ranked` (extract v2, LI.67) each row also carries `ranks`
    and its lists obey the ranked stopping rule (`validate_ranked_types`)."""
    if answer.get("verdict") != "rows":
        raise ValidationError(f"extract verdict must be 'rows', not {answer.get('verdict')!r}")
    rows = answer.get("rows")
    if not isinstance(rows, list):
        raise ValidationError("an extract answer needs a list `rows`")
    lines = {int(l[1:l.index(":")]) for l in task["input"]["lines"] if l.startswith("L") and ":" in l}
    want = sorted(real_types("A3S"))
    for n, r in enumerate(rows):
        where = f"row {n}"
        keys = EXTRACT_KEYS | {"ranks"} if ranked else EXTRACT_KEYS
        if not isinstance(r, dict) or set(r) != keys:
            raise ValidationError(f"{where}: keys must be exactly {sorted(keys)}")
        m = _SPAN.match(r["span"]) if isinstance(r["span"], str) else None
        if not m or int(m.group(1)) not in lines:
            raise ValidationError(f"{where}: span {r['span']!r} is not a line of the text")
        if r["relation"] not in EVENT_RELATIONS:
            raise ValidationError(f"{where}: relation {r['relation']!r} is not in {sorted(EVENT_RELATIONS)}")
        if r["channel"] not in EXTRACT_CHANNELS:
            raise ValidationError(f"{where}: channel {r['channel']!r} is not in {list(EXTRACT_CHANNELS)}")
        mag = r["magnitude"]
        if isinstance(mag, bool) or not isinstance(mag, (int, float)) or not 0 <= mag <= EXTRACT_MAGNITUDE_MAX:
            raise ValidationError(f"{where}: magnitude {mag!r} is not a number in [0, {EXTRACT_MAGNITUDE_MAX}]")
        vt = r["valid_time"]
        if vt is not None and not (isinstance(vt, str) and _VALID_TIME.match(vt)):
            raise ValidationError(f"{where}: valid_time {vt!r} is neither null nor YYYY[-MM[-DD]]")
        types = r["types"]
        if ranked:
            validate_ranked_types(types, r["ranks"], want, ids, where=where, floor=floor)
            continue
        if not isinstance(types, dict) or sorted(types) != want:
            raise ValidationError(f"{where}: types must be exactly {want}")
        if all(ws is None for ws in types.values()):
            raise ValidationError(f"{where}: every type is null; the row belongs to no domain")
        for t, ws in types.items():
            if ws is None:
                continue
            if not isinstance(ws, dict) or not ws:
                raise ValidationError(f"{where}: {t} must be null or a non-empty {{domain: weight}} map")
            if any(isinstance(w, bool) or not isinstance(w, (int, float)) or w <= 0 for w in ws.values()):
                raise ValidationError(f"{where}: {t} weights must be positive numbers")
            _sums_to_one([{"weight": w} for w in ws.values()], f"{where} {t}")
            for i in ws:
                if ids is not None and i not in ids:
                    raise ValidationError(f"{where}: {i} is not in the pack")
    return answer


def validate_adjacency_input(task):
    """An adjacency task: `input.card` plus `set_1` and `set_2`, two domains each, none the card's own."""
    inp = task["input"]
    own = inp.get("card", {}).get("id")
    for k in ("set_1", "set_2"):
        s = inp.get(k)
        if not isinstance(s, list) or len(s) != 2 or len({c.get("id") for c in s}) != 2:
            raise ValidationError(f"adjacency {k} must hold two distinct domains")
        if any(c.get("id") == own for c in s):
            raise ValidationError(f"adjacency {k} contains the card's own domain")
    return task


def validate_relatedness_input(task):
    """A relatedness task: `input.first` and `input.second`, two distinct fields, each with at most five children labels."""
    inp = task["input"]
    ids = []
    for k in ("first", "second"):
        f = inp.get(k)
        if not isinstance(f, dict) or not f.get("id"):
            raise ValidationError(f"relatedness {k} must be a field with an id")
        if not isinstance(f.get("children"), list) or len(f["children"]) > 5:
            raise ValidationError(f"relatedness {k} children must be a list of at most five labels")
        ids.append(f["id"])
    if ids[0] == ids[1]:
        raise ValidationError("relatedness needs two distinct fields")
    return task


def validate_answer(answer):
    _schema("answer", answer)
    if "weights" in answer:
        _sums_to_one([{"weight": w} for w in answer["weights"].values()], "answer")
    return answer


def validate_answers(batch_lines, answer_lines):
    """Errors (empty when valid) of an answers file against its batch file: exactly one well-formed answer per
    task, echoing the task's identity, with a verdict from its allowed set."""
    errors = []
    header = json.loads(batch_lines[0])
    membership = header["task_type"].startswith("membership.")
    extract = header["task_type"] == "extract"
    blind = header["task_type"] == "blind"
    mapping = header["task_type"] == "map"
    entries = pack_entries(header["prefix"]) if mapping else None
    ids = pack_ids(header["prefix"]) if header["task_type"] == "links" or membership or extract else None
    tasks = {}
    for line in batch_lines[1:]:
        t = validate_task(json.loads(line))
        if header["task_type"] == "adjacency":
            validate_adjacency_input(t)
        if header["task_type"] == "relatedness":
            validate_relatedness_input(t)
        tasks[t["task_id"]] = t
    seen = set()
    for n, line in enumerate(answer_lines, 1):
        try:
            a = validate_answer(json.loads(line))
        except (ValueError, ValidationError) as e:
            errors.append(f"line {n}: {e}")
            continue
        t = tasks.get(a["task_id"])
        if t is None:
            errors.append(f"line {n}: unknown task_id {a['task_id']}")
            continue
        if a["task_id"] in seen:
            errors.append(f"line {n}: duplicate answer for {a['task_id']}")
        seen.add(a["task_id"])
        for f in ("task_type", "input_hash", "variant", "prompt_version"):
            if a[f] != t[f]:
                errors.append(f"line {n}: {f} {a[f]!r} differs from the task's {t[f]!r}")
        if a["model"] != header["model"]:
            errors.append(f"line {n}: model {a['model']!r} differs from the batch's {header['model']!r}")
        if a["verdict"] not in t["allowed_verdicts"]:
            errors.append(f"line {n}: verdict {a['verdict']!r} not in {t['allowed_verdicts']}")
        if t["task_type"] == "links":
            try:
                validate_links_answer(a, t, ids)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if extract:
            try:
                validate_extract_answer(a, t, ids, ranked=header["prompt_version"] >= RANKED_EXTRACT_VERSION)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if blind:
            try:
                validate_blind_answer(a)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if mapping:
            try:
                validate_map_answer(a, t, entries, version=header["prompt_version"])
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if membership:
            vocab = header["task_type"].split(".", 1)[1]
            try:
                if header["prompt_version"] >= RANKED_MEMBERSHIP_VERSION:
                    validate_ranked_membership_answer(a, vocab, ids, floor=membership_fit_floor(header["prompt_version"]))
                else:
                    validate_membership_answer(a, vocab, ids)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
    for missing in sorted(set(tasks) - seen):
        errors.append(f"missing answer for {missing}")
    return errors


def validate_entity(entity):
    _schema("entity", entity)
    return entity


def validate_count_as(rule):
    _schema("count_as", rule)
    return rule
