# Life Image: rulings and backpropagation

The register of every author ruling for Life Image, and of findings that should flow back to Benefuture. Process
(author, 2026-11-23): a ruling is recorded here first, with its date and the documents it affects; mechanisms
(schemas, prompts, code, tests) change only after. Detail and reasoning stay in `DESIGN.md`, `PLAN.md` and
`RELATIONS.md`; this file is the index and the source of truth for what was ruled. Withdrawn items are marked, not
deleted. Numbering is stable (LI.n).

## Rulings

### Scope and process
- **LI.1** (2026-11-20) Separate subproject: own folder, workflows, releases; may borrow from Benefuture, must build
  and publish without it. DESIGN.
- **LI.2** (2026-11-20) Product: a library with an API contract, fillable at the simplest by a language model reading
  a resume or prospectus, rendering an infinitely zoomable image down to single pieces of evidence. DESIGN.
- **LI.3** (2026-11-20) Users: real entities on the real basemap; Benefuture simulations on a synthetic basemap until
  they adopt real domain subsets; one contract. DESIGN.
- **LI.4** (2026-11-20) Held by the project before v1.0; basemap data licence separate. DESIGN.
- **LI.5** (2026-11-20) Everything before v1.0 is open to experiment; [R] marks direction, not a freeze. DESIGN.
- **LI.6** (2026-11-20) Building and refining domains is mechanical and manageable by a small model. DESIGN, PLAN.
- **LI.7** (2026-11-20) Runner: Haiku subagents at low effort; an API runner may replace them behind the same task
  files. PLAN.
- **LI.8** (2026-11-21) Restricted runner agent type (`.claude/agents/lifeimage-runner.md`). PLAN.
- **LI.9** (2026-11-20) Gold sets: model-drafted labels reviewed by the author. PLAN.
- **LI.10** (2026-11-21) Review timing: the author reviews disputed cases only after final candidates and a battery;
  until then the lead session's reviews stand in. PLAN.
- **LI.11** (2026-11-20) AI tasks optimised for maximum cache hit. PLAN.
- **LI.12** (2026-11-20) The graph serves as cached classifier context until fine-tuning is possible. PLAN.
- **LI.13** (2026-11-20) The domain map can turn into or feed an embedding engine, and in time become analogous to
  Large Concept Model weights. PLAN.
- **LI.14** (2026-11-21) Graded round-trip decoys, progressively harder up to expected failure. PLAN.
- **LI.15** (2026-11-21) Data use: no real minors; anonymised or synthetic data fine; for extraction tests any data
  if identities are redacted and test data is not saved, except public figures; focus includes regular people.
  DESIGN.
- **LI.16** (2026-11-23) Rulings are recorded in this file before mechanisms change. This file.

### Domains and basemap
- **LI.20** (2026-11-20) Domains concern everything, not only work: the backbone of Benefuture's behavioural
  transaction substrate, able to classify any life event or behaviour. DESIGN.
- **LI.21** (2026-11-21) Everything is a domain; membership is typed, partition of unity per relation type (L22,
  8.156); cross-cutting domains appear as spread patterns. DESIGN. (Withdrawn proposal: harm, transitions and
  consumption as row tags.)
- **LI.22** (2026-11-21) Domains are networks (tree-ish, DAG-ish, sometimes cyclic); "parent" is neither strong nor
  singular; each domain placed once, where closest. DESIGN.
- **LI.23** (2026-11-20) The whole domain space from the start, refined progressively; basemaps yearly; non-raster
  images update automatically. DESIGN.
- **LI.24** (2026-11-20) Top level by the concept's axes: abstract ↔ tangible, personal and social ↔ global and
  professional. DESIGN.
- **LI.25** (2026-11-21) The axes dictate sectors; domain pressure dictates slice widths, adjusted slightly each
  version (AI, mRNA widening); stability is gradual change, not frozen angles. DESIGN.
- **LI.26** (2026-11-20, refined 2026-11-21) Radius from complexity, difficulty and specificity; impact is colour
  intensity, not radius; a net new achievement gets a notch. DESIGN.
- **LI.27** (2026-11-20) The visual shape is expected to come out right by construction. PLAN.

### Image and channels
- **LI.30** (2026-11-21) Colour stays in the event's domains; none to neighbours, a little to major upstream
  domains. DESIGN.
- **LI.31** (2026-11-21) The image is a view over the colour-setting subset of relations; consumption gives at most
  capped expertise; outputs count more. DESIGN.
- **LI.32** (2026-11-21) Each channel projects through its own relations (mRNA expertise stable; impact moved from
  research to health to survival). DESIGN.
- **LI.33** (2026-11-21) Potential is predicted expertise and predicted impact, self-assessment included; red
  potential, green expertise, blue impact; the mix shows estimation, not worth. DESIGN.
- **LI.34** (2026-11-21) Two image versions: predicted/measured now; reputation positive/negative later. DESIGN.
- **LI.37** (2026-11-25; amends LI.33) Channels follow the source document's split. Red is knowledge and potential:
  taking in (reading, watching, attending), claims, self-assessment and predictions. Green is demonstrated skill:
  producing, or doing the thing under assessment. Blue is impact: what the product changes for others. Tests split by
  what they measure: a test of knowing makes red solid (claimed → measured tier); an assessment of doing is green. The
  produced/consumed field and a knowing/doing flag on tests choose between red and green. Estimation still reads in
  the image: grainy red never made solid, and red without green, mean knowing or claiming without doing. DESIGN.
- **LI.36** (2026-11-24) Channels are levels built from events: each event imprints its own variegated pattern on
  the circle (its memberships across related domains), its weight and decay set the pattern's luminosity, and these
  imprints add up per channel; the sum saturates like light, giving per-domain levels. A potential event (a claim or
  prediction) imprints with the level it claims, so red compares with green like for like. Replaces summing row
  magnitudes on one shared scale. DESIGN.
- **LI.38** (2026-11-25; amends LI.37; lead proposal adopted under the author's go-ahead "keep going" of 2026-11-25, not a direct author ruling) Grain marks claimed potential and predictions only: self-assessments, forecasts
  and claims of capability (rows of channel `prediction`). Tier (claimed, attested, measured) never makes grain; it
  shows only as reduced saturation of the solid colour (measured full, attested slightly less, self-reported pale).
  Knowledge taken in is solid red whatever its tier (pale when self-reported); an event reported by the person is
  placed by what it was (producing: green and blue, taking in: red) and drawn pale. DESIGN.
- **LI.39** (2026-11-25; amends LI.36; lead proposal adopted under the author's go-ahead "keep going" of 2026-11-25, not a direct author ruling) The tone map's constant is a governed value anchored to a reference life: the
  median 40-year-old persona of the generated population has its typical touched domain (median over directly
  imprinted domains of the strongest solid channel) at level 0.5, mid-brightness. The scale is absolute across people:
  a thinner life is dimmer, a richer one brighter, never normalised per person. Default and derivation live in
  `lifeimage/governed.py`. DESIGN.
- **LI.51** (2026-11-25; lead proposal under the author's go-ahead "keep going" of 2026-11-25 and the instruction to make evidence reach
  the fine level; not a direct author ruling; amends LI.30 and LI.36) Evidence reaches the fine level. A row names a fine domain
  where its coarse field has fine children; the imprint lands on it, a little bleeds to its upstream coarse field (LI.30), none to
  neighbours, and a coarse level is the re-saturated sum of its children and its own imprints (luminosities add, the tone map
  applies once), so a field holds a fine imprint whole, once. Fine domains are placed once inside their main parent's arc in outer
  rings and no coarse arc moves. The tone constant is re-derived on the coarse aggregate (0.15862, LI.39 rule unchanged). DESIGN.
- **LI.52** (2026-11-25) Detail follows resolution. At any view, enough basemap detail loads for the colouring to be
  full detail at that pixel resolution: a 200 by 200 disc loads simpler than a 4k by 4k one; zooming keeps adding
  detail as available and required, down to all that exists. Online and offline versions, each self-contained at a
  raster and a vector level, both recalibrating to new basemaps as released. Mechanism (lead proposal): a tiled vector
  basemap (map-tile pyramid; MVT/PMTiles candidate) carrying domain ids only, coloured from a per-entity levels file
  joined at view time; a slice too narrow to show at the current resolution is drawn as its parent, whose level already
  aggregates it (LI.51). DESIGN, PLAN.
- **LI.53** (2026-11-25; amends LI.52) Raster covers only 1x to 4x zoom; beyond that a viewer is looking for something
  in particular, which the vector version serves, with selection and search of specific items. The viewer is treated as
  a map: its experience and features follow map conventions (search and fly-to, selection with an information panel,
  labels by zoom, layer toggles per channel, legend, zoom and position indicator, linkable views). DESIGN, PLAN.
- **LI.35** (2026-11-20) The negative channel comes later; the contract carries sign, tiers and revocation from v0.
  DESIGN.

### Relations
- **LI.40** (2026-11-23) Responsibility follows freedom at the moment of producing the outcome; the outcome is
  recorded as it is; the volition record is the option set (alternatives and their harm); self-defence judged by the
  ways of defence available. RELATIONS. Lead's reading, pending confirmation: beneficiaries who only receive carry
  no responsibility.
- **LI.41** (2026-11-23) Production is required whenever contribution is above 0 (produced) or the participant
  receives the output (consumed); a vote produces. RELATIONS.
- **LI.42** (2026-11-23) Relation metadata: each property needs a consumer; proposed set in `RELATIONS.md`
  ("Relation metadata"), adopted with this ruling as the basis for the contract update.

### Synthetic generator
- **LI.50** (2026-11-25; lead proposal adopted under the author's go-ahead "keep going" of 2026-11-25, not a direct author ruling) The generator's self-estimates follow the self-assessment literature, as world parameters with
  ranges and sources in `lifeimage/generators/params.py`, never tuned to make a battery pass: bias is domain-specific
  (larger over-estimation where skill is low and feedback sparse, little where feedback is frequent, a
  better-than-average shift, under-estimation among the highly skilled), replacing a uniform small error. PLAN.

## Governed thresholds proposed (not rulings)

- **GT.1** Responsibility with no recorded option set: 0.5; with options, 0.1 (no less harmful alternative) to 1 (a
  harmless one existed). `lifeimage/governed.py`; each use of the default logged.

## Candidate backpropagations to Benefuture

Each moves to `docs/BACKPROPAGATION.md` when confirmed by the work or the author.

- **BP.1** Domain versioning: rules to split, merge and retire domains, with reputation split by weights
  (parallel to identity Fork and Merge, L123–L124). PLAN item 1.
- **BP.2** Declared seeds against `!declared` (L22): seeding from editorial taxonomies stays score-only until relearnt
  from co-occurrence. PLAN item 2.
- **BP.3** A specificity and difficulty ordinal for domains (novelty L159, accolades L122, predictability). PLAN 3.
- **BP.4** Bootstrap from today's records: evidence tiers as truth levels for the score-only start. PLAN 4.
- **BP.5** Real overlap weights to replace M3c's synthetic bootstrap network. PLAN 5.
- **BP.6** Disclosure levels make L133's query types concrete. PLAN 6.
- **BP.7** The task pipeline as Benefuture's metric-model process applied to itself. PLAN 7.
- **BP.8** Domain profiles as sparse simplex vectors; L101's no-transfer rule should cover similarity. PLAN 8.
- **BP.9** The graph as memory (L22 `Rel ← Mem`) made operational. PLAN 9.
- **BP.10** One substrate for behaviour: gaps in the graph are unpriceable behaviour. PLAN 10.
- **BP.11** Two relation vocabularies in Lean (`RelationshipType`, `RelationType` 8.156) to reconcile. PLAN 11.
- **BP.12** 8.156's "communicative" behaves as a form, not a relation type. RELATIONS.
- **BP.13** An event↔event layer (part_of, causes, re_description, concurrent), native to transaction-log chains
  (L95). RELATIONS.
- **BP.14** Value routing is additive (conservation); culpability is not (degree of responsibility). RELATIONS.
- **BP.15** Outcome measured against the predicted counterfactual credits prevention. RELATIONS.
- **BP.16** L96 `Responsibility(Informed, Counterfactual, Severity, Duty)` needs a freedom term (alternatives
  available), from LI.40. RELATIONS.
