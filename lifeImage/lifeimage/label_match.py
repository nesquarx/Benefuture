"""LI.71: `label_match.v1`, the judge of how a `blind.v2` run's categories compare with the author's own.

The author categorised two events by hand (LI.71 worked examples, controls `cal.d01` and `cal.d02`): per relation a list of labels from the most
specific to the most generic. A runner judges, for each author label and each run (variant) separately, whether the run's list for that relation holds
a label of the same sense: `match` (same sense, wording aside), `partial` (a broader, narrower or overlapping sense) or `none`. One task per
(variant, item, relation, author label); the answer names the run label it relied on (`run_ref`, null for `none`). The batch is built from the
validated `blind.v2` answers, so it exists only once they do (`tools/build_two_pass.py label_match`). No model is run here.
"""
import json
from pathlib import Path

from .canonical import canonical_json, content_hash
from .membership import DEFAULT_OUT, MODEL
from .tasks import DEFAULT_PROMPTS
from .validate import BLIND_RELS, BLIND_UNKNOWN, ValidationError, norm_label

TASK = "label_match"
VERSION = 1
MAX_TASKS = 50
VERDICTS = ["match", "partial", "none"]
PARTIAL_CREDIT = 0.5  # the share of a label a `partial` verdict counts in the pre-registered match share

# LI.71, the author's blind categories in decreasing weight (the setting of the train ticket: the rest unknown)
AUTHOR_LABELS = {
    "cal.d01": {"form": ["sale", "retail", "exchange", "financial transaction"],
                "content": ["bread", "baked goods", "food", "direct human-to-human transaction"],
                "outcome": ["money input", "inventory spent"],
                "setting": ["market", "stall/store/shop", "point of sale", "retail", "commerce", "business"]},
    "cal.d02": {"form": ["purchase", "booking", "travel planning", "logistics"],
                "content": ["ticket/pass", "receipt", "train", "public transportation"],
                "outcome": ["ticket obtained", "promise obtained", "seat booked", "documentation"],
                "setting": ["point of sale"]},
}


# LI.72, the author's held-out categorisations (never in any prompt): the commuter (cal.s08) and the ballot (cal.s04), in decreasing weight. LI.72 names
# no accepted outcome for the commuter, only the two rejected ones below, so its outcome list is empty and its outcome is judged by the negatives alone.
HELD_OUT = {
    "cal.s08": {"form": ["commuting", "passenger", "travel in bus", "travel in public transport", "transportation", "going to work",
                         "work related activities", "preparation for work", "regular activity"],
                "content": ["bus ride", "vehicle ride", "journey", "getting on/off vehicle"],
                "outcome": [],
                "setting": ["inside bus", "inside vehicle", "public transport", "vehicle traffic", "road networks", "surface travel"]},
    "cal.s04": {"form": ["voting", "civic participation", "electoral process", "decision making", "democracy"],
                "content": ["ballot", "election", "public decision"],
                "outcome": ["vote cast", "vote entered in count", "ballot used", "turnout counted"],
                "setting": ["polling station", "election", "civic life", "democratic polity"]},
}
# The author's rejected outcomes (LI.72): "arrival at work" is not stated; "passenger carried" is the bus's event. Judged like any author label, but a
# match is a failure of the run; the judge is not told (the task input is the same as for an accepted label).
NEGATIVE_LABELS = {"cal.s08": {"outcome": ["arrival at work", "passenger carried"]}}


def run_view(answer, rel):
    """The run's categories of one relation as the judge sees them: refs `r0`, `r1`, ... (the `unknown` marker is not a category). A `blind.v3`
    answer's events are read in order and their lists run on (the judge compares the author's event with the whole run)."""
    blinds = [e["blind"] for e in answer["events"]] if "events" in answer else [answer["blind"]]
    entries = [e for bl in blinds for e in (bl[rel] or [])]
    return [{"ref": f"r{i}", "label": e["label"], "gloss": e["gloss"]} for i, e in enumerate(e for e in entries if norm_label(e["label"]) != BLIND_UNKNOWN)]


def _instructions(prompts_dir=DEFAULT_PROMPTS):
    return (Path(prompts_dir) / f"{TASK}.v{VERSION}.md").read_text(encoding="utf-8").rstrip("\n")


def build_label_match_batches(blind_pairs, *, max_tasks=MAX_TASKS, model=MODEL, prompts_dir=DEFAULT_PROMPTS, authors=None, negatives=None):
    """{part: [header, task lines...]}: one task per (variant, author item, relation, author label) over the validated `blind.v2` answers
    (`blind_pairs`: (batch, answers) paths), at most `max_tasks` per part. Variant v of the judge reads variant v of the run. `authors` ({item:
    {relation: labels}}, default the LI.71 in-prompt examples) and `negatives` (the author's rejected labels, appended to their relation) widen it for
    `blind.v3` (the held-out categorisations, `HELD_OUT`, `NEGATIVE_LABELS`)."""
    authors = AUTHOR_LABELS if authors is None else authors
    negatives = negatives or {}
    from .two_pass import answers_by_item
    got = answers_by_item(blind_pairs)
    header = json.dumps({"kind": "header", "task_type": TASK, "model": model, "prompt_version": VERSION, "prefix": _instructions(prompts_dir)},
                        sort_keys=True, ensure_ascii=False)
    lines = []
    for v in sorted({v for per in got.values() for v in per}):
        for key in sorted(authors):
            if key not in got or v not in got[key]:
                raise ValueError(f"{key}: no blind answer from variant {v}")
            text, ans = got[key][v]
            for rel in BLIND_RELS:
                run = run_view(ans, rel)
                for label in authors[key][rel] + negatives.get(key, {}).get(rel, []):
                    inp = {"item": {"id": key, "text": text}, "relation": rel, "author_label": label, "run": run}
                    h = content_hash(inp)
                    lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK, "prompt_version": VERSION,
                                                 "input_hash": h, "variant": v, "k": 2, "input": inp, "allowed_verdicts": list(VERDICTS)}))
    return {p // max_tasks: [header] + lines[p:p + max_tasks] for p in range(0, len(lines), max_tasks)}


def write_label_match_batches(name, batches, out_dir=DEFAULT_OUT):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for p, lines in sorted(batches.items()):
        path = out / f"{TASK}.v{VERSION}.{name}.part{p}.jsonl"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


def validate_label_match_answer(answer, task):
    """`run_ref` is one of the task's run refs for `match` and `partial`, null for `none`."""
    ref = answer.get("run_ref", "missing")
    if ref == "missing":
        raise ValidationError("a label_match answer needs run_ref (a run ref, or null for none)")
    refs = {r["ref"] for r in task["input"]["run"]}
    if answer["verdict"] == "none":
        if ref is not None:
            raise ValidationError(f"verdict none must have run_ref null, not {ref!r}")
    elif ref not in refs:
        raise ValidationError(f"run_ref {ref!r} is not one of the run's refs {sorted(refs)}")
    return answer
