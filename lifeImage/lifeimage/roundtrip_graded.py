"""Graded round-trip v2: decoys of rising difficulty, so the test shows where the annotation's validity ends.

Levels (each task: the true item plus four decoys; chance is 1/5):
  L1 random items; L2 same top form domain; L3 same top form and content; L4 same top form, content and setting
  (outcome where the vocabulary has no setting); L5 near-duplicate texts that differ from the true event only in a
  nuance the annotation types are meant to carry (`data/gold/roundtrip_l5_v0.jsonl`), where failure is expected for
  the nuances layer A does not encode (consumed versus produced, consent, acting for, count-as, volition).

L1 to L4 decoys come from the annotated pool. A level that too few items qualify for is filled from the next-easier
level, and the fill is loud: every decoy carries the level it actually came from (`decoy_levels` in the key sidecar,
which the runner never sees) and the item's `backfilled` count; the scorer reports backfilled items per level.
Matching is on the top domain of a type; an unanswered type (null) matches only another null, and only for the
setting/outcome level, never for form or content.
"""
import hashlib
import json
import math
from pathlib import Path

from .canonical import canonical_json, content_hash
from .membership import DEFAULT_GOLD, DEFAULT_PROMPTS, item_input, pack_hash, real_types
from .roundtrip import LABELS, N_CANDIDATES, domain_labels, merge_annotation

LEVELS = (1, 2, 3, 4, 5)
N_DECOYS = N_CANDIDATES - 1
PROMPT_VERSION = 2
MODEL = "haiku-subagent-low"
A_KINDS = {"outcome", "setting", "content"}
L5_KINDS = A_KINDS | {"consumed_vs_produced", "consent", "acting_for", "count_as", "volition"}
L5_FILE = "roundtrip_l5_v0.jsonl"


def _top(annotation, t):
    ds = annotation.get(t)
    return ds[0]["domain"] if ds else None


def _hash_key(item_id, other):
    return hashlib.sha256(f"{item_id}|{other}".encode()).hexdigest()


def similarity(a, b, types):
    """Shared annotation mass between two annotations: over the real types, the sum of the smaller weight of each
    domain both keep."""
    tot = 0.0
    for t in types:
        wa = {d["domain"]: d["weight"] for d in a.get(t) or []}
        wb = {d["domain"]: d["weight"] for d in b.get(t) or []}
        tot += sum(min(w, wb[d]) for d, w in wa.items() if d in wb)
    return tot


def _qualifies(level, mine, other, types):
    """Whether `other` is a level-`level` decoy for `mine` (annotations)."""
    if level <= 1:
        return True
    need = [types[0], types[1] if len(types) > 1 else None]
    for t in need[:level]:  # L2: form; L3+: form and content
        if t is not None and (_top(mine, t) is None or _top(mine, t) != _top(other, t)):
            return False
    if level >= 4:
        t4 = "setting" if "setting" in types else "outcome"
        if t4 in mine and _top(mine, t4) != _top(other, t4):
            return False
    return True


def level_decoys(item_id, level, annotations, texts, types, n=N_DECOYS):
    """[(decoy id, level it actually came from)]: the item's n decoys for the level. Candidates qualifying at the
    level come first; a shortfall is filled from level-1, level-2 ... down to L1 (all other items), each decoy
    marked with its source level. Within a tier, L1 is random (hash order); above L1 the nearest come first (most
    shared annotation domains, `similarity`), so a fill is the nearest available, not random, and hash order breaks
    ties; every order is deterministic. Items whose text repeats the true text or an earlier decoy's are skipped."""
    mine = annotations[item_id]
    seen = {texts[item_id].strip().lower()}
    near = (lambda i: _hash_key(item_id, i)) if level == 1 else \
        (lambda i: (-similarity(mine, annotations[i], types), _hash_key(item_id, i)))
    others = sorted((i for i in annotations if i != item_id), key=near)
    out, taken = [], set()
    for lv in range(level, 0, -1):
        for i in others:
            if len(out) == n:
                return out
            key = texts[i].strip().lower()
            if i in taken or key in seen or not _qualifies(lv, mine, annotations[i], types):
                continue
            taken.add(i)
            seen.add(key)
            out.append((i, lv))
    return out


def _shuffled(item_id, ids):
    return sorted(ids, key=lambda i: hashlib.sha256(f"{item_id}:{i}".encode()).hexdigest())


def _header(vocab, prompt_version, model, prompts_dir):
    prefix = (Path(prompts_dir) / f"roundtrip.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    return json.dumps({"kind": "header", "task_type": f"roundtrip.{vocab}", "model": model,
                       "prompt_version": prompt_version, "prefix": prefix}, sort_keys=True, ensure_ascii=False)


def _task(vocab, prompt_version, annotation, candidates):
    inp = {"annotation": annotation, "candidates": candidates}
    h = content_hash(inp)
    tid = f"{h[:16]}-v0"
    return tid, canonical_json({"kind": "task", "task_id": tid, "task_type": f"roundtrip.{vocab}",
                                "prompt_version": prompt_version, "input_hash": h, "variant": 0, "k": 1,
                                "input": inp, "allowed_verdicts": LABELS})


def build_graded_batch(vocab, level, annotations, texts, *, model=MODEL, prompt_version=PROMPT_VERSION,
                       prompts_dir=DEFAULT_PROMPTS):
    """(batch lines, key rows) for one of L1 to L4. Key rows carry the level, each decoy's source level and the
    count of decoys that came from an easier level."""
    if level not in (1, 2, 3, 4):
        raise ValueError(f"levels 1-4 are built from the pool, not {level}")
    types = real_types(vocab)
    lines, keys = [_header(vocab, prompt_version, model, prompts_dir)], []
    for iid in sorted(annotations):
        d = level_decoys(iid, level, annotations, texts, types)
        if len(d) < N_DECOYS:
            continue
        src = dict(d)
        order = _shuffled(iid, [iid] + [i for i, _ in d])
        cands = [{"id": lab, "text": texts[i]} for lab, i in zip(LABELS, order)]
        tid, line = _task(vocab, prompt_version, annotations[iid], cands)
        lines.append(line)
        keys.append({"task_id": tid, "item": iid, "level": level, "correct": LABELS[order.index(iid)],
                     "candidates": dict(zip(LABELS, order)),
                     "decoy_levels": {lab: src[i] for lab, i in zip(LABELS, order) if i != iid},
                     "backfilled": sum(1 for _, lv in d if lv < level)})
    return lines, keys


# ---- level 5 ----
def load_l5(gold_dir=DEFAULT_GOLD):
    """The L5 gold rows [{id, kind, a_encodable, true, decoys, note}], validated: four decoys, five distinct texts,
    a known nuance kind, `a_encodable` agreeing with the kind, a note, unique ids."""
    rows = [json.loads(l) for l in (Path(gold_dir) / L5_FILE).read_text(encoding="utf-8").splitlines() if l.strip()]
    ids = set()
    for r in rows:
        texts = [r.get("true", ""), *r.get("decoys", [])]
        if (len(r.get("decoys", [])) != N_DECOYS or len({t.strip().lower() for t in texts}) != N_CANDIDATES
                or r.get("kind") not in L5_KINDS or r.get("a_encodable") != (r.get("kind") in A_KINDS)
                or not r.get("note") or r.get("id") in ids):
            raise ValueError(f"malformed L5 row {r.get('id')!r}")
        ids.add(r["id"])
    return rows


def l5_items(rows):
    """[{id, text}] for every true text (`<id>.t`) and decoy text (`<id>.d1` to `.d4`), in file order."""
    out = []
    for r in rows:
        out.append({"id": f"{r['id']}.t", "text": r["true"]})
        out += [{"id": f"{r['id']}.d{k}", "text": t} for k, t in enumerate(r["decoys"], 1)]
    return out


def l5_annotations(vocab, items, pack_text, answer_rows):
    """{item id: merged annotation} from membership answers (found by input hash, merged over their variants).
    Items without answers are left out."""
    labels, ph = domain_labels(pack_text), pack_hash(pack_text)
    by_hash = {}
    for a in answer_rows:
        by_hash.setdefault(a["input_hash"], {}).setdefault(a["variant"], a)
    out = {}
    for it in items:
        votes = by_hash.get(content_hash(item_input(it, ph)))
        if votes:
            out[it["id"]] = merge_annotation([votes[v] for v in sorted(votes)], real_types(vocab), labels)
    return out


def same_annotation(a, b):
    """Equal top domain on every type either annotation answers (weights and secondary domains ignored)."""
    return all(_top(a, t) == _top(b, t) for t in set(a) | set(b))


def build_l5_batch(vocab, rows, annotations, *, model=MODEL, prompt_version=PROMPT_VERSION,
                   prompts_dir=DEFAULT_PROMPTS):
    """(batch lines, key rows) for L5. The annotation shown is the true text's merged annotation; every true text
    must have one. Keys carry the nuance kind, whether layer A encodes it, the note, and per decoy whether its own
    annotation equals the true one's (`a_identical`, only where the decoy was annotated)."""
    missing = [r["id"] for r in rows if f"{r['id']}.t" not in annotations]
    if missing:
        raise ValueError(f"no annotation for the true text of {len(missing)} L5 items (first: {missing[0]}); "
                         "annotate them first (membership.<V>.v2.l5 batches)")
    lines, keys = [_header(vocab, prompt_version, model, prompts_dir)], []
    for r in rows:
        ids = [f"{r['id']}.t"] + [f"{r['id']}.d{k}" for k in range(1, N_DECOYS + 1)]
        text = dict(zip(ids, [r["true"], *r["decoys"]]))
        order = _shuffled(r["id"], ids)
        cands = [{"id": lab, "text": text[i]} for lab, i in zip(LABELS, order)]
        tid, line = _task(vocab, prompt_version, annotations[ids[0]], cands)
        lines.append(line)
        keys.append({"task_id": tid, "item": r["id"], "level": 5, "correct": LABELS[order.index(ids[0])],
                     "candidates": dict(zip(LABELS, order)),
                     "decoy_levels": {lab: 5 for lab, i in zip(LABELS, order) if i != ids[0]}, "backfilled": 0,
                     "kind": r["kind"], "a_encodable": r["a_encodable"], "note": r["note"],
                     "a_identical": {lab: same_annotation(annotations[ids[0]], annotations[i])
                                     for lab, i in zip(LABELS, order) if i != ids[0] and i in annotations}})
    return lines, keys


# ---- scoring ----
def wilson_interval(k, n, z=1.96):
    """Wilson score interval for k successes in n trials (95% by default); NaNs when n is 0."""
    if n == 0:
        return float("nan"), float("nan")
    p = k / n
    d = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return max(0.0, centre - half), min(1.0, centre + half)


def _cell(rows, got):
    n = len(rows)
    right = sum(got.get(k["task_id"]) == k["correct"] for k in rows)
    return {"n": n, "answered": sum(k["task_id"] in got for k in rows), "correct": right,
            "accuracy": right / n if n else float("nan"), "ci": list(wilson_interval(right, n)),
            "chance": 1 / N_CANDIDATES}


def score_graded(key_rows, answers):
    """Accuracy per level with its Wilson interval and the chance line; unanswered tasks count as wrong. Per level,
    also the items that needed backfill and accuracy over those that did not. For L5: accuracy for A-encodable
    versus other nuances, and per nuance kind."""
    got = {a["task_id"]: a["verdict"] for a in answers}
    out = {"levels": {}}
    for lv in sorted({k["level"] for k in key_rows}):
        rows = [k for k in key_rows if k["level"] == lv]
        cell = _cell(rows, got)
        clean = [k for k in rows if not k.get("backfilled")]
        cell["backfilled_items"] = len(rows) - len(clean)
        cell["accuracy_unbackfilled"] = _cell(clean, got)["accuracy"]
        out["levels"][str(lv)] = cell
    l5 = [k for k in key_rows if k["level"] == 5]
    if l5:
        out["l5"] = {"a_encodable": _cell([k for k in l5 if k["a_encodable"]], got),
                     "not_a_encodable": _cell([k for k in l5 if not k["a_encodable"]], got),
                     "by_kind": {kind: _cell([k for k in l5 if k["kind"] == kind], got)
                                 for kind in sorted({k["kind"] for k in l5})}}
    return out


def score_graded_files(key_paths, answer_paths):
    rows = lambda p: [json.loads(l) for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]
    keys = [r for p in key_paths for r in rows(p)]
    return score_graded(keys, [a for p in answer_paths for a in rows(p)])


def render_graded(s):
    """Plain-text table of a `score_graded` result."""
    f = lambda c: f"{c['accuracy']:.1%} [{c['ci'][0]:.1%}, {c['ci'][1]:.1%}] n={c['n']} (chance {c['chance']:.0%})"
    out = ["level accuracy [95% Wilson]"]
    for lv, c in s["levels"].items():
        out.append(f"  L{lv}: {f(c)}; backfilled items {c['backfilled_items']}, accuracy without backfill "
                   f"{c['accuracy_unbackfilled']:.1%}")
    if "l5" in s:
        out.append(f"  L5 A-encodable nuances: {f(s['l5']['a_encodable'])}")
        out.append(f"  L5 other nuances:       {f(s['l5']['not_a_encodable'])}")
        for kind, c in s["l5"]["by_kind"].items():
            out.append(f"    {kind}: {f(c)}")
    return "\n".join(out)
