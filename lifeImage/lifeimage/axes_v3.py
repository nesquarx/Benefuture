"""Axes v3: one 0-10 judgement per card and axis, small batches, each card judged on its own.

The pairwise pilot showed that runners given many similar judgements build a private lookup table and apply it in
bulk (fields at the poles 4% in the pilot against 46.6% in v2, split-half reliability 0.62). v3 keeps the absolute
scale, which is cheap, but changes the conditions so a runner can judge each card: two task types, one axis each
(`axis_at`: abstract 0 to tangible 10, `axis_pg`: personal and social 0 to global and professional 10, 5 balanced),
one card per task, at most `MAX_TASKS` tasks per batch file (parts are balanced in size), the cards in a different
hash-determined order in each of the k = 3 variants, and the prompt (`prompts/axes.v3.md`, common text plus one
section per axis) and `prompts/RUNNER.md` telling the runner not to script the scoring. The verdict is a string "0".."10".

`v3_report` measures what the pilot failed at: the share of answers at a pole, the agreement of the variants with each
other (Spearman and mean absolute difference over fields, mean over variant pairs) and the Spearman of the variant
mean with the v1/v2 means and with the pairwise pilot's positions.
"""
import hashlib
import json
import math
from itertools import combinations
from pathlib import Path

from .axes import axes_input
from .canonical import canonical_json, content_hash
from .packs import is_sector
from .pairwise import spearman
from .tasks import DEFAULT_K, DEFAULT_PROMPTS

SCALE = [str(i) for i in range(11)]
TASK_TYPES = ("axis_at", "axis_pg")
AXIS_OF = {"axis_at": "abstract_tangible", "axis_pg": "personal_global"}
SHORT = {"axis_at": "at", "axis_pg": "pg"}
PROMPT_VERSION = 3
MAX_TASKS = 60  # governed: tasks per batch file, small enough that a runner judges each one (the pilot's batches held 972)


def parse_scale(verdict):
    """The integer 0..10 of a verdict string such as "7"."""
    if not isinstance(verdict, str) or verdict not in SCALE:
        raise ValueError(f"not an axes v3 verdict: {verdict!r}")
    return int(verdict)


def prefix(task_type, prompts_dir=DEFAULT_PROMPTS, prompt_version=PROMPT_VERSION):
    """The common text of `axes.v3.md` followed by the section of this task type (`## axis_at`, `## axis_pg`)."""
    text = (Path(prompts_dir) / f"axes.v{prompt_version}.md").read_text(encoding="utf-8")
    parts = text.split("\n## ")
    common, sections = parts[0], {p.split("\n", 1)[0].strip(): p for p in parts[1:]}
    return common.rstrip("\n") + "\n\n## " + sections[task_type].rstrip("\n") + "\n"


def _order_key(h, v):
    return hashlib.sha256(f"{h}:{v}:order".encode()).hexdigest()


def balanced_parts(items, max_tasks=MAX_TASKS):
    """Split items in order into the fewest parts of at most max_tasks, sizes differing by at most one."""
    n = len(items)
    if not n:
        return []
    k = -(-n // max_tasks)
    size, extra = divmod(n, k)
    out, i = [], 0
    for p in range(k):
        j = i + size + (p < extra)
        out.append(items[i:j])
        i = j
    return out


def build_v3_batches(cards, *, model, prompt_version=PROMPT_VERSION, prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K, max_tasks=MAX_TASKS,
                     cache=None):
    """{(task type, variant, part): [header, task lines...]}: every field once per type and variant, in the variant's own
    order, in balanced parts of at most max_tasks; cached (field, variant) votes are skipped."""
    by_id = {c["id"]: c for c in cards}
    fields = [(content_hash(inp), inp) for inp in (axes_input(c, by_id) for c in cards if not is_sector(c))]
    out = {}
    for t in TASK_TYPES:
        header = json.dumps({"kind": "header", "task_type": t, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix(t, prompts_dir, prompt_version)}, sort_keys=True, ensure_ascii=False)
        for v in range(k):
            todo = [(h, inp) for h, inp in sorted(fields, key=lambda f: (_order_key(f[0], v), f[0]))
                    if cache is None or not cache.has(t, h, model, prompt_version, v)]
            for n, part in enumerate(balanced_parts(todo, max_tasks)):
                out[(t, v, n)] = [header] + [canonical_json({
                    "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": t, "prompt_version": prompt_version, "input_hash": h,
                    "variant": v, "k": k, "input": inp, "allowed_verdicts": SCALE}) for h, inp in part]
    return out


def write_v3_batches(batches, out_dir):
    """Write axes.v3.<at|pg>.var<v>.part<n>.jsonl files; returns the paths in key order."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (t, v, n), lines in sorted(batches.items()):
        p = out / f"axes.v{PROMPT_VERSION}.{SHORT[t]}.var{v}.part{n}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def v3_means(answers, owner):
    """{field id: (mean 0..10, number of votes)} over the answers, matched by input hash through `owner` {hash: id}."""
    acc = {}
    for a in answers:
        if a["input_hash"] in owner:
            acc.setdefault(owner[a["input_hash"]], []).append(parse_scale(a["verdict"]))
    return {i: (math.fsum(v) / len(v), len(v)) for i, v in sorted(acc.items())}


def _by_variant(answers, owner):
    out = {}
    for a in answers:
        if a["input_hash"] in owner:
            out.setdefault(a["variant"], {})[owner[a["input_hash"]]] = parse_scale(a["verdict"])
    return out


def axis_stats(answers, owner, v12=None, pilot=None):
    """Share at a pole, variant agreement and correlation with the earlier means, for one axis."""
    by_v = _by_variant(answers, owner)
    scores = [parse_scale(a["verdict"]) for a in answers if a["input_hash"] in owner]
    sp, mad = [], []
    for a, b in combinations(sorted(by_v), 2):
        common = sorted(set(by_v[a]) & set(by_v[b]))
        if len(common) > 1:
            sp.append(spearman([by_v[a][i] for i in common], [by_v[b][i] for i in common]))
            mad.append(math.fsum(abs(by_v[a][i] - by_v[b][i]) for i in common) / len(common))
    means = {i: m for i, (m, _) in v3_means(answers, owner).items()}

    def corr(ref):
        common = sorted(set(means) & set(ref or ()))
        return spearman([means[i] for i in common], [ref[i] for i in common]) if len(common) > 1 else None

    mean = lambda xs: math.fsum(xs) / len(xs) if xs else None
    return {"fields": len(means), "variants": len(by_v), "answers": len(scores),
            "share_poles": sum(s in (0, 10) for s in scores) / len(scores) if scores else None,
            "variant_spearman": mean(sp), "variant_mad": mean(mad), "spearman_v1v2": corr(v12), "spearman_pilot": corr(pilot)}


def v3_report(answers_by_axis, means_v12, pilot_rows, owner):
    """{axis: axis_stats}: answers_by_axis {axis name: answers}, means_v12 {axis: {id: mean}}, pilot_rows the
    pairwise pilot's {"axis", "id", "position"} rows, owner {input hash: field id}."""
    pilot = {}
    for r in pilot_rows:
        pilot.setdefault(r["axis"], {})[r["id"]] = r["position"]
    return {ax: axis_stats(ans, owner, (means_v12 or {}).get(ax), pilot.get(ax)) for ax, ans in answers_by_axis.items()}
