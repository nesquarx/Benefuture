# Life Image

A visual summary of what an entity (a person, a group, an organisation, a book, an AI) has known, done and caused,
drawn on a fixed circular basemap of domains in additive colour, and zoomable down to the individual pieces of
evidence behind it. Judged by outputs, not by self-perception or psychometrics.

Life Image is a subproject of this repository with its own releases and workflows. It may borrow from Benefuture
(domain model, reputation, privacy rules) but builds, tests and publishes without it. It is compatible with
Benefuture's records and works with today's systems: at its simplest, a language model reading a resume or a
prospectus fills the API contract, at the lowest evidence tier.

- Design and recorded decisions: [DESIGN.md](DESIGN.md).
- Origin: the author's concept document "Concept - Life Image" (2019).
- Plan: [PLAN.md](PLAN.md). Rulings and backpropagation: [BACKPROPAGATION.md](BACKPROPAGATION.md) (recorded before mechanisms change).
- Status (pre-v1.0, held by the project): a whole-of-life domain graph (16 sectors, 247 coarse fields placed on two
  judged axes and a judged radius; 786 fine domains from OpenAlex, ESCO/ISCO, Wikidata and the ATUS activity lexicon);
  relation types tested in batteries (layers A, B, D); synthetic regular people, organisations and public figures;
  predicted/measured images (static and an offline zoomable viewer with disclosure levels, group and comparison
  views). From the image's per-domain levels a classifier recovers a persona's archetype at about 0.8 (chance 0.125);
  estimation style is carried by grain and tier (about 0.55, chance 0.33). Details and every measurement: PLAN.md.

## Build and test

Python 3.11+, with `jsonschema` and `pytest`; nothing from the parent repository is imported.

```
python -m pip install jsonschema pytest
pytest lifeImage/tests            # fast tier (default)
BF_TIER=full pytest lifeImage/tests   # every test; `-m full` runs the heavy tier alone
```

Tiers: tests marked `full` (large worlds, many seeds; `pyproject.toml` markers) are excluded by default (`addopts = -m 'not full'`), mirroring the parent repository's fast/full CI split.

- `schemas/`: JSON Schemas (draft 2020-12) for cards, tasks, answers and evidence rows; `lifeimage/validate.py` adds
  the rules a schema cannot state (weights sum to 1, tombstone successors, answers matching their tasks).
- `lifeimage/canonical.py`: canonical JSON and the content hash that keys the cache; volatile fields never enter it.
- `lifeimage/cache.py`, `lifeimage/tasks.py`: the answer cache (committed JSONL in `data/answers/`) and batch files
  built from cards with a fixed prompt prefix from `prompts/<task_type>.v<N>.md`. `prompts/RUNNER.md` tells a runner
  how to turn a batch file into an answers file; `validate_answers` checks it.
- `lifeimage/gold.py`: gold sets and the accuracy gate for serving a task type (default 0.9, governed).
- `lifeimage/layout.py`, `lifeimage/migration.py`: angles, arcs and the stability invariants between basemap
  versions (containment, circular order, centre drift below a governed epsilon, tombstone gaps), and migration
  tables as sparse linear maps over domain-weight vectors.
- `lifeimage/layout_migration.py`, `lifeimage/render/basemap.py` (`LAYOUTS`, `build_v0(layout=)`): the coarse ring order is a pinned
  layout (default `seriation_v0`, version `0.0.0-draft+seriation_v0`, LI.66; `axes_v0` rebuilds the earlier basemap); the per-field angle
  migration and the stability exceptions (LI.25 targets exceeded, deferred to the clean-up) are in
  `data/coarse/layout_migration_seriation_v0.json`.

Each invariant has an acceptance test and a counterexample test (a deliberately bad version that must be rejected).
Governed defaults: `layout.EPSILON` (2 degrees), `layout.INSERT_WIDTH` (3 degrees), `gold.DEFAULT_THRESHOLD` (0.9), `blind.fit_floor` (4) and `blind.max_labels` (6, LI.70 pass 1 of two-pass extraction).
