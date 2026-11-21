"""Round-trip v3 on the confirming battery: does an item's A annotation single out its own text?

Differences from the graded v2, each answering a measured weakness:
- Candidates by annotation similarity. The four decoys of an item are the other items whose annotation is nearest
  to its own: the mean over the A types either annotation answers (form, content, outcome, setting) of the weighted
  Jaccard of the two weight maps (sum of minima over sum of maxima); a type null on both sides is not counted, a type
  answered on one side only counts 0. The nearest decoy's similarity is recorded per task in the key sidecar, so
  difficulty is scored against it, not against nominal levels.
- No plainest true text. v2 showed the runner separating the true text from template decoys by cues other than the
  annotation. Decoys are chosen inside a wording band around the true text, `WORDING_TOLERANCE` (15%) of its length
  in words and of its added wording (words from the first clause boundary on), each with a floor of one word; and
  when every decoy would still be plainer-looking than the true text (more words, or the same with more added
  wording), the farthest chosen decoy is swapped for the nearest in-band one that is at least as plain. A shortfall
  is loud: the key says `equalised: false` and names the out-of-band decoys; `true_plainest` says when no plainer
  decoy was available.
- A text-only control: the same candidates in the same order with no annotation. Its accuracy above chance measures
  what the texts give away; annotation accuracy minus control accuracy (paired by item) is the leak-corrected gain.

Scoring: accuracy by similarity decile of the nearest decoy (rank deciles over tasks, ties by task order, each decile
reporting its similarity range) with Wilson intervals, the control accuracy, the leak-corrected gain overall and per
decile; the overall gain counts only beyond `Z` standard errors of the paired difference (Student-t inflated to
first order), the repository's significance rule. An unanswered task counts as wrong in both arms.
"""
import hashlib
import json
import math
import re
from pathlib import Path

from .canonical import canonical_json, content_hash
from .confirm import MODEL as CONFIRM_MODEL, split_parts
from .membership import DEFAULT_OUT, real_types
from .membership_metrics import weighted_jaccard
from .roundtrip import LABELS, N_CANDIDATES, domain_labels, merge_annotation
from .roundtrip_graded import wilson_interval
from .tasks import DEFAULT_PROMPTS

A_TYPES = real_types("A3S")
N_DECOYS = N_CANDIDATES - 1
WORDING_TOLERANCE = 0.15
Z = 2.0
PROMPT_VERSION = 3
TASK_TYPE = "roundtrip.confirm"
CONTROL_TASK_TYPE = "roundtrip.confirm.control"
N_DECILES = 10
BOUNDARY = re.compile(r"[,;:]|\b(?:and|while|after|before|because|but|so|as|when|whereas|which|who|until|then|since)\b",
                      re.I)


# ---- similarity ----
def _weights(annotation, t):
    return {d["domain"]: d["weight"] for d in annotation.get(t) or []}


def annotation_similarity(a, b, types=A_TYPES):
    """Mean weighted Jaccard over the types either annotation answers; 1.0 when neither answers any."""
    sims = []
    for t in types:
        wa, wb = _weights(a, t), _weights(b, t)
        if wa or wb:
            sims.append(weighted_jaccard(wa, wb))
    return sum(sims) / len(sims) if sims else 1.0


# ---- wording ----
def word_count(text):
    return len(text.split())


def added_wording(text):
    """Words after the first clause boundary: after a comma, semicolon or colon, or from the first connective
    (and, while, after, ...) on; 0 for a text without one."""
    m = BOUNDARY.search(text)
    if not m:
        return 0
    start = m.end() if m.group(0) in ",;:" else m.start()
    return len(text[start:].split())


def in_wording_band(true_text, other, tol=WORDING_TOLERANCE):
    """Whether the other text's length and added wording are within `tol` of the true text's (floor one word)."""
    tw, ow = word_count(true_text), word_count(other)
    ta, oa = added_wording(true_text), added_wording(other)
    return abs(ow - tw) <= max(tol * tw, 1) and abs(oa - ta) <= max(tol * ta, 1)


def _plain(text):
    return (word_count(text), added_wording(text))


def _norm(text):
    return text.strip().lower()


def _hash_key(item_id, other):
    return hashlib.sha256(f"{item_id}|{other}".encode()).hexdigest()


# ---- decoys ----
def pick_decoys(item_id, annotations, texts, n=N_DECOYS, types=A_TYPES):
    """(decoy ids, info). The n nearest annotations whose wording is inside the band (items whose text repeats the
    true text or an earlier candidate's are skipped); the nearest out-of-band ones fill a shortfall, listed in
    `out_of_band` with `equalised` false; then, if the true text is the unique plainest, the farthest decoy gives way
    to the nearest in-band one at least as plain (`true_plainest` records whether it still is). info also holds
    `sims`, each decoy's similarity to the true annotation."""
    mine, true_text = annotations[item_id], texts[item_id]
    sim = {i: annotation_similarity(mine, annotations[i], types) for i in annotations if i != item_id}
    seen, cands = {_norm(true_text)}, []
    for i in sorted(sim, key=lambda i: (-sim[i], _hash_key(item_id, i))):
        if _norm(texts[i]) not in seen:
            seen.add(_norm(texts[i]))
            cands.append(i)
    eligible = [i for i in cands if in_wording_band(true_text, texts[i])]
    chosen = eligible[:n]
    out_of_band = [i for i in cands if i not in chosen][:n - len(chosen)]
    chosen += out_of_band
    plain = lambda ids: min(_plain(texts[i]) for i in ids) > _plain(true_text)
    true_plainest = bool(chosen) and plain(chosen)
    if true_plainest:
        better = [i for i in eligible if i not in chosen and _plain(texts[i]) <= _plain(true_text)]
        if better:
            chosen[-1] = better[0]  # `better` is empty unless the band was never short, so chosen[-1] is in band
            chosen.sort(key=lambda i: (-sim[i], _hash_key(item_id, i)))
            true_plainest = plain(chosen)
    return chosen, {"sims": {i: sim[i] for i in chosen}, "equalised": not out_of_band,
                    "true_plainest": true_plainest, "out_of_band": out_of_band}


def _shuffled(item_id, ids):
    return sorted(ids, key=lambda i: hashlib.sha256(f"{item_id}:{i}".encode()).hexdigest())


def _header(task_type, model, prompts_dir, control):
    name = "roundtrip.v3.control.md" if control else "roundtrip.v3.md"
    prefix = (Path(prompts_dir) / name).read_text(encoding="utf-8").rstrip("\n")
    return json.dumps({"kind": "header", "task_type": task_type, "model": model, "prompt_version": PROMPT_VERSION,
                       "prefix": prefix}, sort_keys=True, ensure_ascii=False)


def _task(task_type, inp):
    h = content_hash(inp)
    tid = f"{h[:16]}-v0"
    return tid, canonical_json({"kind": "task", "task_id": tid, "task_type": task_type,
                                "prompt_version": PROMPT_VERSION, "input_hash": h, "variant": 0, "k": 1,
                                "input": inp, "allowed_verdicts": LABELS})


def build_roundtrip_v3(annotations, texts, *, model=CONFIRM_MODEL, prompts_dir=DEFAULT_PROMPTS, types=A_TYPES,
                       targets=None):
    """(annotated lines, annotated keys, control lines, control keys). `annotations` is the pool: every annotated
    item may be a decoy; tasks are built for `targets` (default: every pool item with four decoys). The control
    task has the same candidates in the same order and no annotation. Key rows: the correct label, the label -> item
    map, per-decoy and nearest-decoy similarity, wording measures, `equalised`, `true_plainest`, `out_of_band`."""
    lines = [_header(TASK_TYPE, model, prompts_dir, False)]
    clines = [_header(CONTROL_TASK_TYPE, model, prompts_dir, True)]
    keys, ckeys = [], []
    for iid in sorted(targets if targets is not None else annotations):
        decoys, info = pick_decoys(iid, annotations, texts, types=types)
        if len(decoys) < N_DECOYS:
            continue
        order = _shuffled(iid, [iid] + decoys)
        label = dict(zip(order, LABELS))
        cands = [{"id": lab, "text": texts[i]} for lab, i in zip(LABELS, order)]
        tid, line = _task(TASK_TYPE, {"annotation": annotations[iid], "candidates": cands})
        ctid, cline = _task(CONTROL_TASK_TYPE, {"candidates": cands})
        sims = {label[i]: s for i, s in info["sims"].items()}
        row = {"item": iid, "correct": label[iid], "candidates": dict(zip(LABELS, order)),
               "decoy_similarity": sims, "nearest_decoy_similarity": max(sims.values()),
               "wording": {label[i]: list(_plain(texts[i])) for i in order}, "equalised": info["equalised"],
               "true_plainest": info["true_plainest"], "out_of_band": sorted(label[i] for i in info["out_of_band"])}
        lines.append(line)
        clines.append(cline)
        keys.append(dict(row, task_id=tid))
        ckeys.append(dict(row, task_id=ctid, arm="control"))
    return lines, keys, clines, ckeys


def write_roundtrip_v3(lines, keys, clines, ckeys, out_dir=DEFAULT_OUT, max_tokens=40_000):
    """roundtrip.v3[.control].var0.jsonl (split into .p<j> parts when over `max_tokens`) and the key sidecars
    roundtrip.v3[.control].key.jsonl; returns the batch paths."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for stem, ls, ks in (("roundtrip.v3", lines, keys), ("roundtrip.v3.control", clines, ckeys)):
        parts = split_parts(ls[0], ls[1:], max_tokens)
        for j, part in enumerate(parts):
            p = out / (f"{stem}.var0.jsonl" if len(parts) == 1 else f"{stem}.var0.p{j}.jsonl")
            p.write_text("\n".join(part) + "\n", encoding="utf-8")
            paths.append(p)
        (out / f"{stem}.key.jsonl").write_text("\n".join(json.dumps(k, sort_keys=True) for k in ks) + "\n",
                                               encoding="utf-8")
    return paths


# ---- answers to annotations ----
def annotations_from_confirm_answers(answers, item_of_task, labels, types=A_TYPES):
    """{item id: merged annotation} from confirm answers (their A part, the placebo left out), each item's variants
    merged by strict majority (`roundtrip.merge_annotation`). item_of_task: {task id: item id}."""
    by_item = {}
    for a in answers:
        by_item.setdefault(item_of_task[a["task_id"]], []).append(a)
    return {iid: merge_annotation([a for a in sorted(rs, key=lambda a: a["variant"])], types, labels)
            for iid, rs in sorted(by_item.items())}


def roundtrip_from_answers(answer_paths, items, pack_text, *, extra_pool=None, model=CONFIRM_MODEL,
                           prompts_dir=DEFAULT_PROMPTS):
    """Round-trip v3 batches from confirm answers files (each read with the batch file beside it). Tasks are built for
    the items the answers annotate; the decoy pool is those items, plus `extra_pool` = (annotations, texts) of other
    items whose id and text are not among them. Returns (annotated lines, keys, control lines, control keys)."""
    item_of, answers = {}, []
    for p in map(Path, answer_paths):
        batch = p.with_name(p.name.replace(".answers.jsonl", ".jsonl"))
        if batch == p or not batch.exists():
            raise FileNotFoundError(f"no batch file for answers {p} (expected {batch})")
        for l in batch.read_text(encoding="utf-8").splitlines()[1:]:
            t = json.loads(l)
            item_of[t["task_id"]] = t["input"]["item"]["id"]
        answers += [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]
    anns = annotations_from_confirm_answers(answers, item_of, domain_labels(pack_text))
    texts = {i["id"]: i["text"] for i in items if i["id"] in anns}
    targets = sorted(texts)
    pool, pool_texts = dict(anns), dict(texts)
    if extra_pool:
        seen = {_norm(t) for t in texts.values()}
        for iid, a in extra_pool[0].items():
            if iid not in pool and _norm(extra_pool[1][iid]) not in seen:
                pool[iid], pool_texts[iid] = a, extra_pool[1][iid]
    return build_roundtrip_v3(pool, pool_texts, model=model, prompts_dir=prompts_dir, targets=targets)


# ---- scoring ----
def similarity_deciles(sims):
    """Decile (0 = least similar nearest decoy) of each task: rank over tasks, ties broken by task order."""
    n = len(sims)
    order = sorted(range(n), key=lambda i: (sims[i], i))
    out = [0] * n
    for rank, i in enumerate(order):
        out[i] = rank * N_DECILES // n
    return out


def _cell(oks, answered):
    n = len(oks)
    right = sum(oks)
    return {"n": n, "answered": sum(answered), "correct": right,
            "accuracy": right / n if n else float("nan"), "ci": list(wilson_interval(right, n)),
            "chance": 1 / N_CANDIDATES}


def _diff(a, c):
    return a["accuracy"] - c["accuracy"] if a["n"] else float("nan")


def paired_gain(diffs, z=Z):
    """Mean of per-item differences (annotation correct minus control correct), its standard error, and whether it
    beats z standard errors (z inflated to first order for the Student-t with n - 1 degrees of freedom)."""
    n = len(diffs)
    mean = sum(diffs) / n if n else float("nan")
    se = math.sqrt(sum((d - mean) ** 2 for d in diffs) / (n - 1) / n) if n > 1 else float("nan")
    z_eff = z + (z ** 3 + z) / (4 * (n - 1)) if n > 1 else float("nan")
    counts = n > 1 and abs(mean) > z_eff * se if se > 0 else bool(n > 1 and mean != 0)
    return {"n": n, "accuracy": mean, "se": se, "z": z, "z_effective": z_eff, "effect_counts": bool(counts)}


def score_v3(key_rows, answers, control_key_rows, control_answers):
    """Scores of the annotated arm against its control, paired by item. Returns n, `annotated` and `control` cells
    (n, answered, correct, accuracy, Wilson ci, chance), `leak_corrected` (see `paired_gain`), the same three over
    the tasks whose wording was fully equalised (`equalised_only`) and `deciles`: per decile of nearest-decoy
    similarity the cells, the similarity range and the corrected accuracy."""
    got = {a["task_id"]: a["verdict"] for a in answers}
    cgot = {a["task_id"]: a["verdict"] for a in control_answers}
    ctl = {k["item"]: k for k in control_key_rows}
    rows = []
    for k in key_rows:
        c = ctl.get(k["item"])
        if c is None:
            raise ValueError(f"no control task for item {k['item']}")
        rows.append({"sim": k["nearest_decoy_similarity"], "a": got.get(k["task_id"]) == k["correct"],
                     "a_ans": k["task_id"] in got, "c": cgot.get(c["task_id"]) == c["correct"],
                     "c_ans": c["task_id"] in cgot, "eq": k.get("equalised", True)})
    cells = lambda rs: (_cell([r["a"] for r in rs], [r["a_ans"] for r in rs]),
                        _cell([r["c"] for r in rs], [r["c_ans"] for r in rs]))
    a, c = cells(rows)
    out = {"n": len(rows), "annotated": a, "control": c,
           "leak_corrected": paired_gain([int(r["a"]) - int(r["c"]) for r in rows]), "deciles": []}
    eq = [r for r in rows if r["eq"]]
    ea, ec = cells(eq)
    out["equalised_only"] = {"n": len(eq), "annotated": ea, "control": ec,
                             "leak_corrected": paired_gain([int(r["a"]) - int(r["c"]) for r in eq])}
    dec = similarity_deciles([r["sim"] for r in rows])
    for d in range(N_DECILES):
        rs = [r for r, x in zip(rows, dec) if x == d]
        ca, cc = cells(rs)
        sims = [r["sim"] for r in rs]
        out["deciles"].append({"decile": d, "n": len(rs), "sim_range": [min(sims), max(sims)] if rs else [float("nan")] * 2,
                               "annotated": ca, "control": cc, "leak_corrected": _diff(ca, cc)})
    return out


def score_v3_files(key_path, answer_paths, control_key_path, control_answer_paths):
    rows = lambda ps: [json.loads(l) for p in ([ps] if isinstance(ps, (str, Path)) else ps)
                       for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]
    return score_v3(rows(key_path), rows(answer_paths), rows(control_key_path), rows(control_answer_paths))


def render_v3(s):
    """Plain-text report of a `score_v3` result."""
    f = lambda c: f"{c['accuracy']:.1%} [{c['ci'][0]:.1%}, {c['ci'][1]:.1%}] n={c['n']}"
    g = s["leak_corrected"]
    out = [f"annotated accuracy {f(s['annotated'])} (chance {s['annotated']['chance']:.0%})",
           f"text-only control  {f(s['control'])}",
           f"leak-corrected gain {g['accuracy']:+.1%} (se {g['se']:.3f}; beats {g['z_effective']:.2f} se: {g['effect_counts']})",
           f"wording fully equalised only: annotated {f(s['equalised_only']['annotated'])}; control "
           f"{f(s['equalised_only']['control'])}; gain {s['equalised_only']['leak_corrected']['accuracy']:+.1%}",
           "", "decile (nearest-decoy similarity) | annotated | control | gain"]
    for d in s["deciles"]:
        if d["n"]:
            out.append(f"  {d['decile']} [{d['sim_range'][0]:.2f}, {d['sim_range'][1]:.2f}] | {f(d['annotated'])} | "
                       f"{f(d['control'])} | {d['leak_corrected']:+.1%}")
    return "\n".join(out)
