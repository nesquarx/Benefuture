# Life Image: plan

All items are `[P]` unless marked. Design and rulings: [DESIGN.md](DESIGN.md).

## The paradigm: a mechanical pipeline with small-model micro-tasks

The graph is built by deterministic code; a small model (Haiku-class) answers only bounded judgements the code
cannot settle. Every judgement is a **task card**:

- one fixed task type, a small input (a domain card and at most a few candidates), a schema-checked output (an enum,
  weights, a score in a fixed range), and a one-line reason;
- answered by k independent runs (default 3); agreement is the verdict's credence, disagreement escalates to a larger
  model, then to the author's queue;
- cached by (task type, input hash, model, prompt version), so unchanged items cost nothing on a rebuild;
- runner-agnostic: tasks are JSONL files in, answers JSONL out, so a subagent batch or an API runner can serve them.

Each task type has a **gold set** (author-labelled, about 100–200 cases). A model serves a task type only while its
accuracy on the gold set clears a threshold (default 0.9); below it the task escalates. This is Benefuture's
eligibility of metric models by accuracy, score-only until converged (8.136), and fallback order (8.71), applied to
the work itself, loudly: every escalation and substitution is logged.

Mechanical signals do most of the work: label and alias matching, embeddings, co-occurrence counts (works sharing
topics, postings sharing skills), source hierarchies, and source scales for difficulty. The model is called at the
margin: where the top two mechanical answers are close.

### The domain card

`id` (stable, never reused), `label`, `aliases` (multilingual), `description` (one line), `anchors` (source
identifiers: OpenAlex, ESCO, O*NET, Wikidata), `links` (domain-to-domain: `upstream` with weights summing to 1, `overlap` with overlap weights; optional `strict` for containment),
`axes` (abstract ↔ tangible, personal ↔ global, each in [−1, 1]), `radius` inputs (complexity, difficulty,
specificity) and the composite, `arc` (start, end), `status` (score-only, provisional, stable, tombstone with
successors), `basemap_version`, and per-field provenance and confidence.

### Radius (ruled; mechanics proposed)

Complexity, difficulty and specificity are computed from mechanical proxies and combined monotonically, rank-normalised
within each sector, with a child never inside its parent. Candidate proxies (each to verify against its source):

- specificity: depth in the graph, information content (the negative log share of works or postings under the node),
  ESCO's skill reuse level (transversal → occupation-specific);
- difficulty: O*NET job zones (preparation, 1–5), ISCED levels of the qualifications that teach it;
- complexity: prerequisite depth, the number of distinct parent domains a node draws on.

Built (`lifeimage/radius.py`, `tools/build_radius.py`; `data/coarse/seed_v3.jsonl`, `data/fine/fine_v1.jsonl`; the basemap places
each band by the composite and falls back to depth, logged). Coverage of 1,049 nodes: specificity 100%, complexity 100%,
difficulty 19% (ISCO skill level by major group; O*NET job zones and ISCED education are not in the fetched sources, so
unused). Spearman: complexity~difficulty +0.25 (n=196), complexity~specificity +0.03, difficulty~specificity -0.11 (|z| < 2
for both): the proxies do not yet correlate as ruled, and the report flags it. Specificity is largely popularity in the
co-membership sample; a source of per-domain breadth or reach would test whether that is the cause.

Impact is intensity, not radius. A notch marks a net new achievement: one that creates a new leaf. At the claimed
tier it is flagged only, and drawn once attested.

### Cache-first tasks (ruled: optimise AI tasks for maximum cache hit)

Two caches, both designed for: the answer cache (exact match on a task's canonical input) and the model's prompt
cache (a shared prefix).

- **Canonical inputs.** Cards serialise canonically (sorted keys, normalised text, fixed numeric precision);
  volatile fields (timestamps, run ids, provenance) stay out of the hash. Candidate lists are sorted by id.
- **Context-free tasks.** A task sees only what its answer depends on: rate a field on the axes from its own card,
  not from its neighbours, so a change elsewhere does not invalidate it.
- **Static first, variable last.** Each task type's prompt is a fixed prefix (instructions, schema, examples, the
  coarse map summary) followed by the cards; a batch runs many cards of one type in one session so the prefix is
  reused. Prompt versions change rarely and deliberately.
- **Deterministic variants for votes.** Three identical prompts give correlated answers; the k votes instead use k
  fixed variants (candidate order permuted by a fixed rule, or fixed paraphrases), each cacheable.
- **Model changes do not re-run everything.** On a new model, re-run its gold sets first; re-run items only where
  the gold sets show drift (score-only until converged, 8.136).
- Measured: hit rate per task type and per rebuild, reported with each run.

**The graph as cached context, in place of fine-tuning** (author, 2026-11-20). Until a model can be fine-tuned, the
graph itself is what the classifier learns from, held in context:

- **Context packs.** Each release serialises the graph into compact packs (id, label, parents, short aliases; a
  description only where labels collide), with reviewed gold examples as few-shot cases. One coarse pack (always
  loaded) and one pack per sector (and per subtree where a sector is too large); a pack has a token budget.
- **The cache follows the hierarchy.** A prompt is instructions, then the coarse pack, then a sector pack, then the
  cards: each layer a stable prefix, versioned with the basemap, so it stays valid for a whole release.
- **Route, then classify.** Cards are routed first against the coarse pack (cheap), grouped by sector, and each
  sector's cards classified in one batch that reads its pack once. Batching by sector is what makes the reuse
  reliable for subagents, whose separate sessions may not share a provider cache.
- **The packs are the classifier's weights until there are weights.** A better graph is a better classifier with no
  training step.

**Every answer is future training data.** Task inputs, answers, votes, escalations and author reviews are kept, so the
packs' behaviour can later be distilled into a fine-tuned small classifier, or a model trained on the graph.

### Toward an embedding engine (ruled: the map can turn into, or feed, an embedding engine)

- **The sparse vector is native.** A domain profile is weights over domain ids summing to 1 (Benefuture L22): a point
  on a simplex over the vocabulary of ids. An entity's image is a fold of its rows into such a vector (per channel),
  so search, group sums and comparisons are vector operations.
- **Migrations are linear.** Each release's migration table is a sparse matrix from old ids to new; vectors migrate
  by multiplication. Ids stay stable dimensions, never reused.
- **Dense embeddings are derived, never the source of truth.** Versioned artefacts built from the cards: text
  (labels, aliases, descriptions), graph (parents, overlaps) and co-occurrence. The card keeps what each needs.
- **Hyperbolic fit.** Poincaré embeddings place general concepts near the centre and specific ones toward the rim
  of a disc, in few dimensions, which is the image's own geometry; a higher-dimensional ball could be the engine and
  the image its anchored two-dimensional view (angles fixed by the basemap, the rest learnt). For the engine, to test.
- **Toward concept-model weights** (author, 2026-11-20: the graph may become analogous to Large Concept Model
  weights). Large Concept Models model language over sentence-level embeddings rather than tokens; the graph would be
  an explicit, named, versioned concept space, a codebook of ids over a continuous space. What to keep now so that
  path stays open: raw co-occurrence statistics (not only the weights derived from them), multilingual labels and
  aliases, evidence rows as an entity-to-concept corpus, and every task answer with its input.
- **Similarity finds; it never credits.** Nearness may retrieve and classify; it must not move reputation between
  domains (Benefuture L101: no transfer, no halo).

## Levels

Each level has its prediction (outcome, ETA in working sessions, confidence; author ruling 8.134) and an acceptance
check. Counts are estimates to replace with measured ones.

### 1. Coarse: sectors and fields (about 100–300 nodes)

- Coverage is all of life (ruled): seed sources beyond work and knowledge, each to verify, include the UN
  International Classification of Activities for Time-Use Statistics (ICATUS), time-use activity lexicons, COICOP
  (consumption by purpose), the WHO classifications of functioning and health (ICF, ICD), and later the UNODC crime
  classification (ICCS) for the negative channel. Acceptance adds a coverage check: a held-out set of everyday life
  events and behaviours each finds a field.

- Author confirms the top sectors on the two axes. A model rates each field on both axes (k = 5); angle is the
  direction in the axes' plane, ordered by insertion between neighbours.
- The one level where the author's eye is the gate: small, and it fixes every later angle.
- Acceptance: every field placed; the author's review passes; ordering invariants hold.
- Prediction: 1–2 sessions; confidence 0.7 that the axes give a readable layout without manual fixes to more than 10%
  of fields.

- Measured (links.v1, 3 Haiku variants over the coarse pack): an upstream link agreed by all three for 99.6% of
  fields, overlap sets agreeing at mean Jaccard 0.62; but every upstream link went to a sector (none field to field)
  and 94.8% of the guessed links survived, against a predicted under 50%. The pack grouped fields under their guessed
  sector, so it anchored the answers: agreement was inflated and the result is a one-level tree, not a network.
  `seed_v1` is kept as data, not adopted. Next prompt version: an ungrouped pack (by id or by angle) and upstream
  links allowed, and asked for, between fields.

- Measured (round 2): **links.v2** (ungrouped pack, field-to-field links asked for): an upstream agreed by all three
  variants for 98.4% of fields; overlap sets Jaccard 0.63; but only 8.1% of fields got a field as upstream (5.9% of
  upstream links), against a predicted 30%, and 86.9% of guessed links survived. At one granularity the model treats
  fields as siblings: upstream links to fields are a cross-level matter (fine to coarse), not a coarse one. Against
  co-membership learnt from 597 annotated events (support ≥ 3), the model's upstream links point the data's way 83.1%
  (166 testable; chance 0.5; predicted ≥ 50%) and its overlaps are data-consistent 79.2% (259 testable). Direction
  between fields is therefore taken from the learnt co-membership, the model's links serving as a check.
  `seed_v2` written. **axes v2** (prompt asking for ±2 only at clear poles): extreme scores 52.6% → 46.6% (predicted
  < 35%); personal ↔ global fell to 36.7%, abstract ↔ tangible rose to 56.4%: the model reads that axis as nearly
  binary. Next: pairwise comparisons against anchors with a Bradley–Terry fit for the abstract ↔ tangible axis.

### 2. Fine: disciplines, occupation groups, skill groups (about 2,000–5,000)

- Crosswalk the sources (labels, aliases, embeddings) into merged cards; tasks: same / overlapping (weight) /
  different; pick parents with weights among a few candidates.
- Placement is mechanical: each domain once, where it is closest (axes, overlaps, upstream domains); neighbours
  ordered by similarity. The graph is a network, so containment holds only where a strict hierarchy exists.
- Acceptance: invariants hold; gold-set accuracy per task type at or above threshold; at most 5% of nodes escalated.
- Prediction: 2–3 sessions; confidence 0.6 (the crosswalk across editorial sources is the risk).

### 3. Finer: topics, skills, concepts (about 50,000+), grown on demand

- Mostly mechanical: nearest parents by embedding and co-occurrence; tasks only at the margin.
- Grown lazily: a finer node is made when evidence needs it; unmapped claims that cluster propose a new node (the
  same pattern as Benefuture's novel leaves formed from clustered blockages, M3c).
- Acceptance: random audits against the gold set; drift of existing angles within ε.
- Prediction: continuous; tasks for under 20% of nodes, confidence 0.6.

### 4. Event record: evidence rows

- Extraction: a small model turns a resume or prospectus into claims with source spans, dates and tier `claimed`.
- Mapping: retrieve the top candidates from the graph; a task picks domain weights. Unmapped claims feed level 3.
- Rows follow the contract (DESIGN.md); Benefuture's per-domain reputation is a fold over them.
- Acceptance: on a hand-labelled set of resumes, mapping precision and recall above stated targets, and calibration
  of stated confidence checked.
- Prediction: 2 sessions to a first extractor; confidence 0.75.

### Yearly release (and continuous refinement)

Snapshot sources (versioned, hashed) → crosswalk → diff against the current graph into change proposals (new, split,
merge, rename, deprecate) → tasks adjudicate → invariant checks (a violation keeps the old angle: stability beats
optimality) → migration table → release. Non-raster images re-render from rows migrated forward.

## Resume point (paused by the author, 2026-11-21, to save tokens)

1. Re-run the three participation batches (`data/batches/participation.v1.var{0,1,2}.jsonl`; rebuild with
   `python3 lifeImage/tools/build_battery_bd.py` if the folder is empty) on the `lifeimage-runner` agent type, using
   the validator named in each batch header; events answers are already cached. Then score with
   `python3 lifeImage/tools/bd_metrics.py` and record in `RELATIONS.md`.
2. Assemble the final candidate sets (RELATIONS.md, "Current candidate") from the A, B and D results.
3. Confirming battery: text-only round-trip control, decoys where the true text is not the plainest, difficulty
   scored by nearest-decoy similarity, generated decoys for the hard bins; then the author's review of disputed cases.
4. links.v2 (ungrouped pack, field-to-field upstream; built, not yet run) and axes.v2 (±2 only at clear poles; v1 scored
   52.6% of scores at a pole): `python3 lifeImage/tools/build_v2_batches.py` writes `data/batches/{links,axes}.v2.var{0,1,2}.jsonl`
   (model `haiku-runner`); then `tools/apply_links_v2.py` (seed_v2, compared with seed_v0 and with the data-learnt
   co-membership, `data/coarse/comembership_v0.jsonl` from `tools/build_comembership.py`) and `tools/axes_compare.py`.
   `lifeimage/pressure.py` is the pressure measure (LI.25) for later slice widths; layout does not use it yet.

## Datasets and generators (round 2)

- Synthetic: 40 personas (8 archetype presets, ages 8–85, 3 minors) and 6 organisations in `data/synthetic/`, 5,274
  rows; tiers claimed 51%, attested 32%, measured 18%; 460 self-assessed potential rows with over-, under- and
  well-calibrated estimators; texts (resume, self-description, diary, prospectus) with ground truth; byte-reproducible
  (`tools/gen_starter.py --check`). 51 world parameters in `lifeimage/generators/params.py`, each with a range and a
  source; demographic figures medium confidence, record coverage, claim rates and self-assessment bias low
  (assumptions, to calibrate).
- Public: 10 deceased public figures from Wikidata (CC0) in `data/public/`, 376 attested rows, 161 labels unmapped and
  ~180 dates inferred (both flagged); offline fixtures for CI.
- Redaction for extraction tests on real texts (`lifeimage/redact.py`); raw inputs only in `data/ephemeral/`.
- Pairwise pilot (abstract ↔ tangible): `tools/build_axes_pair_batches.py --axis abstract_tangible --comparisons 4
  --single-order` writes `data/batches/axes_pair.abstract_tangible.pilot.part{0..4}.jsonl` (972 pairs, each asked once,
  the first slot an Euler orientation so every field is first as often as second give or take one); after the runs,
  `tools/axes_pair_fit.py --pilot` reports split-half reliability, Spearman with the v1 and v2 means and the extreme
  share. Prediction: split-half at least 0.7 (confidence 0.5; four comparisons a field is sparse).
- Extraction test (task `extract` v1, `prompts/extract.v1.md`): `tools/build_extract_batches.py` writes
  `data/batches/extract.v1.var{0,1,2}.jsonl` (40 resumes each, ~16k tokens); `tools/extract_score.py` scores the answers
  per channel (expertise = form and content, impact = outcome, potential = prediction rows) against the truth:
  precision and recall exact and within one upstream link, magnitude error, inflation by calibration, coverage and the
  projected per-domain correlation. Resumes carry 17% of the truth rows (the rest is diary and self-description), so
  `recall` is against resume rows and `recall_all` against all truth. Prediction: exact precision at least 0.6 and
  recall at least 0.5 (confidence 0.5).
- Tests pass on a clean checkout with the network blocked (682 passed, 2 network tests skipped).

## Round 2 measurements: images, pilot, extraction

- **Images v0** (`data/images/v0/`, `tools/render_v0.py`): 56 renders (40 personas, 6 organisations, 10 public
  figures), byte-reproducible. Over-estimation is barely visible: red sums a few self-assessment rows while green and
  blue sum many events; proposed fix (awaiting the author): fold channels into per-domain levels so red compares
  claimed with realised level. Slices uneven (pressure from a tiny sample); radius carries depth only.
- **Pairwise pilot** (abstract ↔ tangible, 972 pairs): runners did not judge pairs independently; they scored each
  domain on a private 0–10 scale and derived verdicts from it, so the pilot measures absolute scoring. Positions agree
  with the v1/v2 means (Spearman 0.86); fields at the poles 4% (v2: 46.6%); split-half reliability 0.62 (predicted
  ≥ 0.8; runners' private scales differ). The order was already in the integer scores; the pile-up at the poles is a
  scale artefact. Next: axes v3 on a 0–10 scale. Lesson: low-effort runners turn many similar judgements into a lookup
  table, so designs that need independent judgements need small batches.
- **Axes v3** (0–10 scale, ≤ 50 cards per runner, each card judged on its own; abstract ↔ tangible, 2 variants):
  scores at 0 or 10: 3.0% (v1 52.1%, v2 56.4% on this axis; predicted < 15%); variant agreement Spearman 0.943, mean
  absolute difference 0.59 points (predicted ≥ 0.75); Spearman with v1/v2 means 0.956 and with the pairwise pilot
  0.878 (predicted ≥ 0.8). Personal ↔ global v3: at 0 or 10 5.3%, variant agreement 0.952, Spearman with v1/v2 means
  0.955. Adopted on both axes; images re-rendered on the v3 basemap. Small batches cost about
  45k tokens per runner and stop the lookup-table shortcut.
- **Extraction on realistic texts** (`texts_v2`, 40 varied resumes, 3 variants; `data/gold/extract_v1_texts_v2_scores.md`):
  truth rows are matched by the v2 lines that render them (`data/synthetic/texts_v2/truth_spans.jsonl`, written by
  `tools/gen_texts_v2.py`; `tools/extract_score.py --texts texts_v2`). Expertise precision 0.66 exact, 0.67 within one link;
  recall of resume rows 0.51 / 0.51 (on the templated texts 0.62 / 0.70 and 0.52 / 0.58): extraction held without
  templates. Matched without spans (domain within a link, year within one) precision 0.50, recall 0.36. Expertise
  inflation by calibration: over +0.19, well -0.06, under -0.15 (ordered, unlike the templated texts). Projection
  correlation 0.536 with the resume truth, 0.243 with the whole life. The earlier row-level collapse (0.19 / 0.14) was a
  scorer artefact: the truth spans still pointed at the v1 template lines.

- **Extraction v1** (40 synthetic resumes, 3 variants; `data/gold/extract_v1_scores.md`): resumes carry 17% of a
  persona's truth rows. Expertise precision 0.62 exact, 0.70 within one link; recall of resume rows 0.52 / 0.58
  (predicted ≥ 0.6 within a link: just missed). Impact almost absent (precision within a link 0.31, recall 0.08) and no
  potential rows: resumes state roles, not outcomes or self-assessment. A resume-based image correlates 0.25 with the
  whole-life truth image. Expertise inflation 0.31, not ordered by calibration type (the synthetic resumes do not render
  calibration). Caveat: runners parsed the templated synthetic resumes by pattern, so this measures template parsing;
  realistic varied texts (or redacted real resumes, LI.15) are needed.

- **Axes v3 (batches built, not run)** (`prompts/axes.v3.md`, `lifeimage/axes_v3.py`, `tools/build_v3_batches.py`): two task
  types, `axis_at` and `axis_pg`, each verdict a string "0".."10" (0 abstract / personal-social, 10 tangible /
  global-professional, 5 balanced), one card per task, 247 fields in 5 balanced parts of 49-50 tasks per type and variant
  (30 files, `data/batches/axes.v3.<at|pg>.var{0,1,2}.part{n}.jsonl`, gitignored), a different card order per variant;
  the prompt and `prompts/RUNNER.md` forbid bulk scoring tables. Predicted by the next measurement (ETA: when run; confidence
  moderate): fields at 0 or 10 below 25%, mean pairwise variant Spearman at least 0.8, Spearman with the v1/v2 means at
  least 0.85. `tools/axes_compare.py` reports all of it, and with the pairwise pilot; `render/basemap.py` takes v3 means per
  field when both axes have votes and falls back to v1/v2 loudly (degradation `axes_v3`).
- **Texts v2** (`lifeimage/generators/texts_v2.py`, `tools/gen_texts_v2.py`, `data/synthetic/texts_v2/`): the 40 personas'
  texts regenerated, rows unchanged, in three resume formats (chronological, skills-first, narrative bio), a phrase bank,
  vague and missing dates, omitted details (never an omitted row), personal lines, and embellishment matching the
  calibration type (over inflates, under deflates, well neutral). A date-led line parser that recovers all resume rows of the
  v1 texts recovers 0% (strict) and 18% (lenient) of the v2 rows; inflating minus deflating words per resume: over +6.6, well
  +0.4, under -5.1. Next: rerun extraction (3 variants) on texts_v2 and score with the v2 spans in `<id>.spans.json`.

## Characterisation battery v1 (LI.36 levels, LI.37 channels)

Signatures pre-registered and hash-pinned before rendering (`74e84ff`, `data/gold/characterisation_signatures_v1.*`);
report `data/gold/characterisation_v1_report.md`; images `data/images/v1/`.

- 144 generated personas (6 per archetype × calibration), truth rows: 26 signatures, 6 held, 9 not held, 11
  inconclusive. Blind identification (leave-one-out nearest centroid): archetype 0.58 [0.49, 0.65] (chance 0.125;
  predicted ≥ 0.60; legacy summing 0.56); calibration 0.31 (chance 0.33; predicted ≥ 0.70; legacy 0.25): not
  recoverable.
- Why calibration vanished: under LI.37 red also carries everything taken in, which every persona does, so claimed
  potential is a small part of red (grainy-red share about 87% for everyone); the generator's calibration effect on
  claimed levels is also small (mean claimed red level over 0.21, well 0.16, under 0.14; post hoc).
- Extracted rows (resume claims only): archetype 0.19, calibration 0.57 (likely an artefact of claims-only rows).
- Humanity-white: pooled channel shares balance (R 0.35, G 0.28, B 0.37, within band), but slices stay coloured
  (composite chroma 0.92 of the mean persona's, limit 0.5): 144 people do not saturate every domain.
- Images are very dark (mean luminance 0.002–0.04): the saturating tone map's constant is set for far more evidence
  than a regular life holds.

## Characterisation battery v2 (LI.38 grain, LI.39 tone anchor, LI.50 estimation bias)

Signatures pre-registered and hash-pinned before rendering (`883da98`, `data/gold/characterisation_signatures_v2.*`: v1
archetype and pooled signatures unchanged, per-domain calibration K1-K13, whole-image W1-W6, predicted identification
I1-I6); report `data/gold/characterisation_v2_report.md`; images `data/images/v2/`.

- Changes: grain is claimed potential only (prediction rows); tier is saturation (measured 1.0, attested 0.85, claimed
  0.5) and never changes a level; knowledge taken in is solid red. `levels.tone_k` = 0.16388, derived by
  `governed.derive_tone_k` (median 40-year-old generalist of the generated population: typical touched domain at level
  0.5). Generator self-estimates: domain-specific bias with feedback (`est_bta`, `est_slope`, `est_feedback_scale`,
  literature in `params.py`), `data/synthetic` and `texts_v2` regenerated.
- 144 personas, truth rows: 38 signatures, 14 held, 10 not held, 14 inconclusive. Held: tone anchor (W1 median typical
  level 0.556 at ages 36 to 44, W2, W3 mean luminance 0.168 against 0.031 in v1), tier as saturation (W4, W5), the
  Dunning-Kruger shape of the claim gap (K12, K13) and claimed levels by calibration (K6, K7). Inconclusive: the gap
  and grain-share contrasts between calibrations (K1-K5, K8-K11): effects of the predicted sign at 0.06 to 0.13 against
  deltas of 0.05 to 0.15, intervals including zero at 48 personas a cell.
- Blind identification (leave-one-out nearest centroid): truth archetype 0.53 [0.45, 0.61] (predicted at least 0.60:
  inconclusive; v1 0.58); truth calibration 0.47 [0.39, 0.55] (predicted at least 0.45: held; chance 0.333; v1 0.31);
  legacy 0.54 and 0.36 (predicted at most 0.62 and 0.40: held).
- Caveat: the cached extraction answers were read from the earlier self-texts, so extracted-row calibration (0.53, held)
  carries the earlier generator's bias; re-extraction (a model run) is needed for a fair reading. Extracted archetype
  0.17 (predicted at least 0.25: not held).

## Characterisation battery v2 (LI.38 grain, LI.39 tone anchor, LI.50 literature bias)

Signatures pre-registered `883da98`; report `data/gold/characterisation_v2_report.md`; images `data/images/v2/`.
- 38 signatures: 14 held, 10 not held, 14 inconclusive (per-domain calibration effects have the predicted sign,
  0.06–0.13, intervals include zero).
- Blind identification, truth rows: calibration 0.47 [0.39, 0.55] (v1 0.31, chance 0.33; held against ≥ 0.45);
  archetype 0.53 [0.45, 0.61] (inconclusive against ≥ 0.60). Legacy summing: archetype 0.54, calibration 0.36.
  Extracted rows, re-extracted from the regenerated texts (3 variants pooled): archetype 0.22 [0.15, 0.30]
  (inconclusive against ≥ 0.25), calibration 0.46 [0.37, 0.55] (held against ≥ 0.40): a resume carries the person's
  estimation style, not their archetype, since resumes show mostly work.
- Mean luminance 0.031 → 0.168; tone constant derived so a median 40-year-old's typical domain sits at 0.556.
- Caveat: estimate–truth correlation in the generator is 0.48 against the literature's ~0.29, so the generated
  people are better calibrated than real ones; calibration should be easier to see in real data, not harder.

## Fine level, first pass

- 650 candidates from Wikidata unmapped classes (48, CC0), OpenAlex subfields (242, CC0 believed), ISCO minor groups
  via ESCO (120) and ESCO skill groups (75) (licence statements not read: unverified), one from answers, and ICATUS
  (164). ICATUS is United Nations copyright with all rights reserved, so its candidates are excluded from the
  published pool and batches; its raw list stays local (gitignored) as a private benchmark (lead decision under the
  rule that licences are verified before use). 486 candidates go to the parent task: 30 batches of ≤ 50 cards,
  3 variants. OpenAlex and ESCO licences still need a primary-page check before any release.

- **Fine parents applied** (fine_parent v1, 2 variants, 486 candidates; `data/fine/fine_v0.jsonl`): 453 upstream, 33
  overlap; escalated 8.6% (limit 5%); mean agreement 0.71; no candidate asked for a new coarse field (predicted < 10%;
  possibly a prompt bias toward existing fields). Multi-parent pairs are supported by learnt co-membership in 32.7%
  of cases against a 1.6% baseline over all coarse pairs (20×): the parents carry real structure. 149 of 247 coarse
  fields have no fine child: the licence-clean sources are academic and occupational (OpenAlex, ESCO, ISCO), and the
  life-activity source (ICATUS) was excluded. Next: a licence-clean life-activity source, the American Time Use
  Survey activity lexicon (US government work, public domain, to verify), for the care, home, leisure and personal
  fields. Seven answers carried mistyped hashes despite their runners' validation; repaired by copying from the batch.
- **ATUS lexicon as the life-activity source** (2026-11-25): BLS states everything it publishes is public domain
  (`copyright-information.htm`, licence `verified`, `sources.py` LICENCES). bls.gov refuses scripted downloads (403), so
  the 2025 lexicon PDF came through a browser-like fetch and `tools/fine_fetch.py --only atus --atus-pdf FILE` reads it
  (318 category rows: majors, second and third tiers; n.e.c., waiting, security, travel and data codes skipped).
  `tools/fine_pool.py --atus-only` gives 300 new candidates (`data/fine/candidates_atus_v0.jsonl`; the first 486 stay
  untouched), `tools/fine_build_batches.py --set atus` writes `fine_parent.v1.atus.var{0,1}.part{0..5}.jsonl` (2 variants,
  50 cards). Pending: a runner pass; then `tools/fine_apply.py` merges them and reports the fields that gained children
  (prediction: care, home, leisure and personal fields gain children; at least 40 of the 149 childless fields).
- **Extraction check on the regenerated texts**: `tools/build_extract_batches.py --texts texts_v2` rebuilds
  `data/batches/texts_v2/extract.v1.var{0,1,2}.jsonl` and removes the answers to the older texts; `characterise.py`
  reports the extracted-row sets as absent (loudly) until new answers exist, and refuses answers whose batch holds
  other texts than `data/synthetic/texts_v2`.

- **Life-activity fines** (ATUS 2025 activity lexicon, BLS, public domain verified; 300 candidates, 2 variants): fine
  level now 786 cards (739 upstream, 47 overlap; escalated 8.1%; agreement 0.70). Coarse fields with no fine child
  149 → 105 (44 gained: sleep, eating, hygiene, parenting, home repair, shopping, worship, volunteering, sport, play,
  among others). Predicted ≥ 150 candidates (held) and two-thirds of the childless fields covered (missed: 30%); the
  remaining 105 include harm, health conditions, relationships and the arts, which neither source details. Multi-parent
  pairs supported by learnt co-membership 35.1% against a 1.6% baseline.

- **Radius proxies, mechanical** (`1ac3c2c`; seed_v3, fine_v1): coverage specificity 100%, complexity 100%, difficulty
  19% (ISCO skill levels only). Spearman: complexity–difficulty +0.25 (n 196), complexity–specificity +0.03,
  difficulty–specificity −0.11 (not significant). Predicted ≥ 0.3 for each pair: missed. The information-content
  proxy measures how popular a domain is in the evidence, not how specialised it is. LI.26 expects the three to
  correlate; the mechanical proxies do not capture them. Next: a radius scale judged per card on 0–10 (how advanced
  and specialised; the axes v3 method), coarse first, compared with the mechanical proxies.

- **Interactive viewer** (`4a2236d`; `data/images/interactive/`, 10 files, 0.95 MB): offline HTML; semantic zoom from
  disc to sector, coarse field and evidence rows (reason, tier, date, channel, contribution); disclosure levels none
  (pattern only: no labels, ids, row text or zoom in the file), summary, full; a group image (4 personas, re-saturated
  sum) and a comparison view; deterministic. (Rows attached at the coarse field then; evidence reaches the fine level
  since LI.51, see "Evidence at the fine level".)

- **Judged radius** (radius v1, 0–10, coarse fields, 2 variants): at 0 or 10 4.7%; variant agreement Spearman 0.921,
  mean absolute difference 0.53 (predicted ≥ 0.85: held); Spearman with ISCO difficulty 0.31 (predicted ≥ 0.4:
  missed narrowly), with the popularity-driven specificity proxy 0.02 (predicted near zero: held). The largest
  disagreements show the mechanical composite inverted (rites of passage, gifts and clothing placed outward; physics,
  sociology and life sciences inward); the judged scale places them as LI.26 intends. Adopted: the radius composite
  takes the judged score where present (fine domains still fall back to the mechanical composite, logged); seed_v3,
  fine_v1, the v2 images and the interactive viewers rebuilt.

- **Evidence at the fine level** (LI.51; `fine/cards.py`, `generators/fine_pick.py`, `levels.py`, `render/`): a persona's event
  that falls in a coarse field with fine children also names one (deterministic per seed, event and field on its own random
  stream; chance = the fine card's upstream link weight toward the field x exp(sharpness x fit), fit = idf-weighted share of the
  child's words carried by the event's wording and key, plus half the share carried by the archetype's sectors and interests;
  `fine_fit_sharpness` 6, a world parameter). Predictions made before the measurement: 45-75% of event rows name a fine domain
  (measured 96.0% of 16,113 event rows of the 144 extended personas, and 96% over 911 in the tests: missed high, as the templates
  use common fields, 93 of the 144 domains they name having fine children); chosen children fit the wording better than a random
  sibling by at least 3 standard errors (held). Imprints land on the named fine domain, `bleed_fraction` of it moves to its
  upstream coarse field (LI.30), nothing to neighbours or overlap links, and a coarse level is the re-saturated sum of its own
  luminosity (direct imprints and the bleed it received) and its children's luminosities times their link weights, so the
  child keeps 1 - bleed of an imprint and the field holds the whole of it once. One step only: a sector is lit by what names
  coarse fields directly, not by their fine children. Placed once inside the main parent's arc by the existing plan
  (`fine/placement.py`, ordered by pull toward the other parents); the 92 fine domains whose main parent is a sector sit in a
  second outer ring inside that sector's arc, the 47 with no upstream link by their heaviest overlap link (logged as
  `fine_placement`); radial bands from the fine cards' mechanical composite, the judged radius covering coarse fields only
  (logged as `radius_judged`). Coarse arcs, order and centres are untouched (pressure is counted at the coarse fields), the
  static renderer widens its viewBox to `Basemap.extent` and draws the fine slices in the outer rings, and the interactive viewer
  walks disc, sector, field, fine domain, evidence, row (depth 0-5; a row is listed at its fine domain and, flagged as carried
  up, at the field above it so contributions still sum to each level). Features read the coarse rings as before; `fine_*`
  descriptors read the fine ring. `data/synthetic`, `tools/render_v0.py` (v2 images, 9.57 MB of SVG for 56 images, each about
  190 KB against 55 KB before: the 786 added outlines; legacy v0 keeps no fine ring, 2.10 MB) and the interactive viewers
  (10 files, 1.85 MB, largest 0.30 MB) regenerated. The tone constant was re-derived on the coarse aggregate: 0.16388 to 0.15862
  (the LI.39 rule applied to fine evidence; the typical touched coarse field counts its main fine-parent field, not the lighter
  parents of a two-parent child). Truth rows (`truth/*.jsonl`) are the claimed rows as they are; extraction is scored on them
  read at the coarse level (`fine.cards.coarsen_rows`), since a resume names a field.
- **Characterisation battery v2 on fine evidence** (re-measurement; signatures unchanged; `data/gold/characterisation_v2_fine_report.*`,
  `python3 tools/characterise.py --out data/gold/characterisation_v2_fine_report --label "v2 on fine evidence"`; 29 s): 38
  signatures, 14 held, 11 not held, 13 inconclusive (v2: 14, 10, 14). Blind identification, truth rows, 144 personas: archetype
  0.569 [0.488, 0.647] against the control of the same personas and code with every row kept at the coarse fields 0.562 and
  the v2 report's 0.535 (fine against control: 8 personas right only with fine, 7 only without, exact sign test p = 1.0);
  calibration 0.451 [0.372, 0.533] against 0.472 and 0.465 (10 / 13, p = 0.68). Predicted: within 0.05 of the control (held);
  the exploratory fine-ring descriptors add at least 0.05 to archetype identification (missed: 0.556, 3 / 5, p = 0.73). Finer
  resolution does not change identification here: the generator's evidence splits over children without separating archetypes
  beyond what the coarse fields already show. A touched fine domain's median level is 0.376 against 0.449 for a touched coarse
  field.

- **Evidence at the fine level** (`5934e8f`): 96% of event rows name a fine domain; levels form at the fine level and
  aggregate into coarse fields; fine ring drawn; the viewer zooms coarse → fine → rows. Battery v2 re-measured on fine
  evidence (signatures unchanged): archetype 0.569 against a same-code coarse control 0.562 (8 vs 7 flips, p = 1.0),
  calibration 0.451 against 0.472: finer resolution does not change identification (predicted +0.05: missed). The limit
  is elsewhere (the features or the generator's archetype signal), not resolution. Images grew to ~190 KB each.

- **Identification ceiling** (`data/gold/identification_ceiling.*`; predictions committed before measurement,
  `f59c09a`): archetype from the image's full per-domain levels 0.85 [0.78, 0.90], from the raw truth rows 0.78
  [0.70, 0.84], from the battery's summary features 0.57 [0.49, 0.65] (levels minus summary +0.27, sign test p < 0.001).
  The image carries the archetype; the summary features lose it. Calibration is the reverse: summary features
  (which include the grain share) 0.58 with a logistic classifier, raw rows 0.39, levels alone 0.17: estimation lives
  in grain and tier, not in levels, as LI.38 intends. Fine rings add nothing measurable (+0.01). Next: the
  characterisation battery should read the image's levels and grain together (a v3 feature set, pre-registered).

## Order of work

0. Tooling: card schema, task-card format and runner interface, cache, gold-set harness, invariant tests (acceptance
   and counterexample, red first).
1. Coarse, with the author's review.
2. Fine.
3. Event record on a few real resumes, which pulls in the finer levels it needs.
4. Renderer prototype.
5. Benefuture bridge: an M3c run exported as rows, folded back, matching its per-domain reputation exactly.

## Candidate backpropagations to Benefuture

Recorded here until the work confirms them; each goes to `docs/BACKPROPAGATION.md` when it does.

1. **Domain versioning.** Benefuture's domains (`Ontology.Domain`, L22) have no rule for splitting, merging or
   retiring a domain, though reputation and currency are keyed by domain. A migration rule (reputation split by
   weights, tombstones) parallels identity Fork and Merge (L123–L124).
2. **Declared seeds against `!declared`.** L22 says domain relations are learnt from memory, not declared. ESCO and
   O*NET are editorial, so seeding from them is declared; it must stay score-only until relearnt from co-occurrence.
   A possible divergence to record.
3. **A specificity and difficulty ordinal.** Benefuture nests domains but does not grade them. Radius measures could
   inform novelty priority (L159), accolade merit for net new contributions (L122), and domain predictability (R5).
4. **Bootstrap from today's records.** Benefuture reads outputs; resumes are self-reports. The tiers (claimed,
   attested, measured) as truth levels may be the data path for Implementation Phase 1 (the score-only start).
5. **Real overlap weights.** The graph's learnt overlaps could replace M3c's synthetic bootstrap network and give real
   partition-of-unity weights per relation type (8.156).
6. **Disclosure levels.** Zoom depth by disclosure makes L133's privacy query types concrete.
7. **Dogfooding.** The pipeline (accuracy-gated models, credence by agreement, escalation, loud logging) is
   Benefuture's metric-model process run on itself; its measured behaviour is evidence for or against that process.
8. **Domain profiles as vectors.** L22's `Dn(T)` with weights summing to 1 is a sparse simplex vector; classifying an
   action into domains (`relevantDn(A)`, L86) is retrieval in that space. A similarity space also invites
   reputation to leak to nearby domains; L101's no-transfer rule should say it holds for similarity too.
9. **The graph as memory.** L22 learns domain relations from memory (`Rel ← Mem`); a graph that serves as context
   packs now and as concept-model weights later is that memory made operational, and a candidate concrete form for
   how metric models classify actions into domains.
10. **One substrate for behaviour.** If every action is classified into these domains, the transaction substrate
    (L84–L91: proposals generated per relevant domain) and reputation (L101) share one graph with the Life Image;
    gaps in the graph become places where behaviour cannot be priced or credited, which the coverage check measures.

11. **Two relation vocabularies.** Lean holds `RelationshipType` (causal, resource, outcome, substrate, regulatory)
    and the ruled `RelationType` (8.156: causal, structural, communicative). The entity-to-event relations the
    Life Image needs (causes, undergoes, handles with expertise, communicates about) map partly onto each, and
    "undergoes" matches the impacted side of vote weight (8.158) more than either list; a coherence point to settle.
12. **Withdrawn (2026-11-21):** the proposal to turn harm, transitions and consumption into row tags instead of
    domains. It forgot typed membership (L22, 8.156); they are domains, and cross-cutting ones.

## Decided

- **[R] Review timing** (author, 2026-11-21): the author reviews disputed cases only once the final candidate
  sets are in place and a battery has run on them; until then the lead session's reviews stand in.
- **[R] Restricted runner** (author, 2026-11-21): task batches run on the `lifeimage-runner` agent type
  (`.claude/agents/lifeimage-runner.md`: read, write and the validator only).
- **[R] Graded round-trip decoys** (author, 2026-11-21): distractors progressively harder, up to cases so nuanced
  that failure is expected, so the test measures where validity ends.
- **[R] Runner** (author, 2026-11-20): Haiku subagents at low effort, reading task batches and writing answers; an
  API runner may replace them later behind the same task-file interface.
- **[R] Domains are networks, placed once where closest; colour never bleeds to neighbours, a little to major
  upstream domains; the image keeps only the relations that set its colours, outputs counting more than
  consumption** (author, 2026-11-21).
- **[R] Everything is a domain; membership is typed per relation, with a partition of unity per relation type**
  (author, 2026-11-21; L22, 8.156). Cross-cutting domains appear as spread patterns.
- **[R] Domains cover every life event and behaviour** (author, 2026-11-20), as the backbone of Benefuture's
  behavioural transaction substrate.
- **[R] Gold sets** (author, 2026-11-20): model-drafted labels, reviewed by the author.
- **[R] AI tasks optimised for maximum cache hit** (author, 2026-11-20).
- **[R] The domain map built so it can turn into, or feed, an embedding engine** (author, 2026-11-20), and in time
  become analogous to Large Concept Model weights.
- **[R] The graph serves as cached classifier context until fine-tuning is possible** (author, 2026-11-20).
- **[R] The visual shape is expected to come out right by construction** (author, 2026-11-20); layout is not a risk
  to plan around.

## Open

- Licences of the seed sources, verified before any are used.
