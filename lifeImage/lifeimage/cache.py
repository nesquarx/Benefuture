"""Content-addressed answer cache.

Key: (task_type, input_hash, model, prompt_version); one vote per variant. Stored as committed JSONL, one file per
task type, because containers are ephemeral and answers are kept as training data. Answers are append-only: a
stored vote is never overwritten, so a rebuild reproduces its earlier verdicts.
"""
import json
from pathlib import Path

from .canonical import canonical_json

DEFAULT_ROOT = Path(__file__).resolve().parent.parent / "data" / "answers"


def _key(a):
    return (a["task_type"], a["input_hash"], a["model"], a["prompt_version"])


class AnswerCache:
    def __init__(self, root=DEFAULT_ROOT):
        self.root = Path(root)
        self._votes = {}  # key -> {variant: answer}
        self._loaded = set()
        self.hits = 0
        self.misses = 0

    def _path(self, task_type):
        return self.root / f"{task_type}.jsonl"

    def _load(self, task_type):
        if task_type in self._loaded:
            return
        self._loaded.add(task_type)
        p = self._path(task_type)
        if p.exists():
            for line in p.read_text().splitlines():
                if line.strip():
                    a = json.loads(line)
                    self._votes.setdefault(_key(a), {}).setdefault(a["variant"], a)

    def get(self, task_type, input_hash, model, prompt_version):
        """{variant: answer} stored for the key (empty when none)."""
        self._load(task_type)
        return dict(self._votes.get((task_type, input_hash, model, prompt_version), {}))

    def has(self, task_type, input_hash, model, prompt_version, variant):
        """Membership test that counts toward the hit rate."""
        hit = variant in self.get(task_type, input_hash, model, prompt_version)
        self.hits += hit
        self.misses += not hit
        return hit

    def put_all(self, answers):
        by_type = {}
        for a in answers:
            self._load(a["task_type"])
            votes = self._votes.setdefault(_key(a), {})
            if a["variant"] in votes:
                continue
            votes[a["variant"]] = a
            by_type.setdefault(a["task_type"], []).append(a)
        for task_type, rows in by_type.items():
            self.root.mkdir(parents=True, exist_ok=True)
            with self._path(task_type).open("a", encoding="utf-8") as f:
                for a in rows:
                    f.write(canonical_json(a) + "\n")

    def hit_rate(self):
        total = self.hits + self.misses
        return self.hits / total if total else 0.0
