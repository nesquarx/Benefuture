"""Merge the three links.v2 answer files into data/coarse/seed_v2.jsonl and compare the result.

Usage (from the repository root):
    python3 lifeImage/tools/apply_links_v2.py ANSWERS_VAR0 ANSWERS_VAR1 ANSWERS_VAR2
The answers are validated against the ungrouped batches rebuilt from seed_v0 (a stale or malformed file fails
loudly). Reports (a) the agreement across variants, how many fields got a field (not only a sector) as upstream, and
how many of seed_v0's guessed upstream links survived; (b) the agreement of the model's upstream and overlap links
with the data-learnt directed co-membership (`data/coarse/comembership_v0.jsonl`) where support >= 3.
"""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.comembership import link_agreement  # noqa: E402
from lifeimage.packs import is_sector  # noqa: E402

_spec = importlib.util.spec_from_file_location("apply_links", ROOT / "tools" / "apply_links.py")
apply_links = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(apply_links)

MODEL = "haiku-runner"
SOURCE = "haiku-runner x3, links.v2"
MIN_SUPPORT = 3


def read_jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def apply(seed_path, answer_paths, out_path, cache, esc_log, comembership=ROOT / "data/coarse/comembership_v0.jsonl",
          prompts_dir=None, model=MODEL):
    stats = apply_links.apply(seed_path, answer_paths, out_path, cache, esc_log, model=model, prompt_version=2,
                              ungrouped=True, prompts_dir=prompts_dir, source=SOURCE)
    new = [c for c in read_jsonl(out_path) if not is_sector(c)]
    ups = [[l["id"] for l in c["links"] if l["rel"] == "upstream"] for c in new]
    stats["fields_with_field_upstream"] = sum(any(not i.startswith("s.") for i in u) for u in ups) / len(new)
    stats["upstream_links_to_fields"] = sum(not i.startswith("s.") for u in ups for i in u) / max(1, sum(map(len, ups)))
    stats["data"] = link_agreement(new, read_jsonl(comembership), MIN_SUPPORT) if Path(comembership).exists() else None
    return stats


def report(s):
    out = [f"fields: {s['fields']}",
           f"fields with an upstream agreed by all 3 variants: {s['upstream_all_agree']:.1%}",
           f"mean Jaccard of overlap sets across variants: {s['overlap_jaccard']:.3f}",
           f"escalated (no upstream named twice): {s['escalated']}",
           f"fields with a field (not only a sector) as upstream: {s['fields_with_field_upstream']:.1%}",
           f"upstream links that go to a field: {s['upstream_links_to_fields']:.1%}",
           f"seed_v0 guessed upstream links retained: {s['v0_upstream_retained']:.1%} of {s['v0_upstream_links']}"]
    d = s["data"]
    if d:
        out += [f"vs data-learnt co-membership (support >= {MIN_SUPPORT}):",
                f"  upstream links testable {d['upstream_testable']} of {d['upstream_links']}, "
                f"pointing the data's way (p(b|a) > p(a|b); chance 0.5) {d['upstream_rate']:.1%}",
                f"  overlap links testable {d['overlap_testable']} of {d['overlap_links']}, "
                f"data-consistent (not strongly directed) {d['overlap_rate']:.1%}"]
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("answers", nargs=3, help="answers files for variants 0, 1, 2 (in order)")
    ap.add_argument("--seed", default=ROOT / "data/coarse/seed_v0.jsonl")
    ap.add_argument("--out", default=ROOT / "data/coarse/seed_v2.jsonl")
    ap.add_argument("--comembership", default=ROOT / "data/coarse/comembership_v0.jsonl")
    a = ap.parse_args(argv)
    s = apply(a.seed, a.answers, a.out, AnswerCache(), ROOT / "data/answers/escalations.links.jsonl", a.comembership)
    print(report(s))
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
