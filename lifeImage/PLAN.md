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
