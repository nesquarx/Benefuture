"""Task batches: cards in, JSONL batch files out; answers in, merged verdicts out.

A batch file is a header line (task type, model, prompt version and the fixed prompt prefix) followed by task
lines. The prefix is static and comes first; everything variable is in the task lines, so a runner reading one
batch reuses the prefix. A task sees only its own card and candidates (context-free), so a change elsewhere does
not invalidate it. Votes use k fixed variants: candidate order permuted by a rule seeded by the input hash.
"""
import hashlib
import json
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from .canonical import canonical_json, content_hash, strip_volatile

DEFAULT_K = 3
DEFAULT_PROMPTS = Path(__file__).resolve().parent.parent / "prompts"
# Allowed verdicts per task type; "candidates" means the candidate ids plus "none".
TASK_TYPES = {
    "relate": ["same", "overlapping", "different"],
    "parent": "candidates",
    "links": ["links"],  # the structure is in the answer's upstream and overlap fields
    "axes_pair": ["a", "b", "tie"],  # which of two domains is further toward the named pole of one axis
    "axis_at": [str(i) for i in range(11)],  # axes v3: abstract 0 to tangible 10, one card per task
    "axis_pg": [str(i) for i in range(11)],  # axes v3: personal and social 0 to global and professional 10
    "adjacency": ["1", "2", "equal"],  # which of two neighbour sets is thematically closer to the field (LI.55)
    "relatedness": [str(i) for i in range(11)],  # how thematically related two coarse fields are, 0 unrelated to 10 near-synonyms
    "radius": [str(i) for i in range(11)],  # judged radius v1: elementary 0 to highly specialised 10, one coarse field per task
}


@dataclass
class Batch:
    name: str
    lines: list = field(default_factory=list)  # header first, then tasks


def read_prefix(task_type, prompt_version, prompts_dir=DEFAULT_PROMPTS):
    return (Path(prompts_dir) / f"{task_type}.v{prompt_version}.md").read_text(encoding="utf-8")


def task_input(card, candidates):
    """Canonical task input: volatile fields stripped, candidates sorted by id."""
    return strip_volatile({"card": card, "candidates": sorted(candidates, key=lambda c: c["id"])})


def variant_order(candidates, input_hash, variant):
    """Variant 0 is sorted by id; variant i orders candidates by sha256(input_hash:i:id)."""
    if variant == 0:
        return sorted(candidates, key=lambda c: c["id"])
    return sorted(candidates, key=lambda c: hashlib.sha256(f"{input_hash}:{variant}:{c['id']}".encode()).hexdigest())


def _allowed(task_type, inp, allowed):
    spec = allowed if allowed is not None else TASK_TYPES.get(task_type)
    if spec is None:
        raise KeyError(f"unknown task type {task_type!r}; pass allowed=")
    if spec == "candidates":
        return [c["id"] for c in inp["candidates"]] + ["none"]
    return list(spec)


def build_batches(task_type, items, *, cache, model, prompt_version, prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K,
                  max_tasks=300, allowed=None):
    """Batches for the (item, variant) pairs not yet cached. items: {"card", "candidates", "group"}.
    Returns [] when everything is cached."""
    prefix = read_prefix(task_type, prompt_version, prompts_dir)
    groups = defaultdict(list)
    for item in items:
        inp = task_input(item["card"], item.get("candidates", []))
        h = content_hash(inp)
        for v in range(k):
            if cache.has(task_type, h, model, prompt_version, v):
                continue
            ordered = dict(inp, candidates=variant_order(inp["candidates"], h, v))
            task = {
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": task_type,
                "prompt_version": prompt_version, "input_hash": h, "variant": v, "k": k,
                "input": ordered, "allowed_verdicts": _allowed(task_type, inp, allowed),
            }
            groups[item.get("group", "all")].append(canonical_json(task))
    # The prefix keeps its own line breaks, so the header is plain JSON, not canonicalised.
    header = json.dumps({"kind": "header", "task_type": task_type, "model": model,
                         "prompt_version": prompt_version, "prefix": prefix}, sort_keys=True, ensure_ascii=False)
    batches = []
    for g in sorted(groups):
        lines = groups[g]
        for i in range(0, len(lines), max_tasks):
            batches.append(Batch(f"{task_type}.v{prompt_version}.{g}.{i // max_tasks:03d}.jsonl",
                                 [header] + lines[i:i + max_tasks]))
    return batches


def write_batches(batches, out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for b in batches:
        (out / b.name).write_text("\n".join(b.lines) + "\n", encoding="utf-8")
    return [out / b.name for b in batches]


@dataclass
class Merged:
    task_type: str
    input_hash: str
    model: str
    prompt_version: int
    verdict: object  # None when no strict majority
    credence: float  # share of the k votes behind the verdict (0 when none)
    votes: dict
    escalate: bool


def merge_answers(answers, k=DEFAULT_K, log_path=None):
    """Majority verdict per key; credence is the agreeing share of k. Anything short of k unanimous votes is
    escalated, and every escalation is appended to log_path."""
    groups = defaultdict(dict)
    for a in answers:
        groups[(a["task_type"], a["input_hash"], a["model"], a["prompt_version"])][a["variant"]] = a["verdict"]
    merged = []
    for key, votes in sorted(groups.items()):
        top = Counter(votes.values()).most_common(2)
        winner, n = top[0]
        strict = len(top) == 1 or n > top[1][1]
        verdict = winner if strict else None
        m = Merged(*key, verdict, n / k if strict else 0.0, dict(sorted(votes.items())), not (len(votes) == k and len(top) == 1))
        merged.append(m)
        if m.escalate and log_path is not None:
            rec = {"task_type": m.task_type, "input_hash": m.input_hash, "model": m.model,
                   "prompt_version": m.prompt_version, "verdict": m.verdict, "credence": m.credence,
                   "votes": {str(v): x for v, x in m.votes.items()},
                   "reason": "no majority" if m.verdict is None else "votes short of unanimous"}
            Path(log_path).parent.mkdir(parents=True, exist_ok=True)
            with Path(log_path).open("a", encoding="utf-8") as f:
                f.write(canonical_json(rec) + "\n")
    return merged
