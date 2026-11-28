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
- **LI.17** (2026-11-25) Source licences confirmed by the author: OpenAlex CC0 1.0; ISCO and ESCO CC BY 4.0. All
  three allow commercial use, modification and redistribution without fees; ISCO and ESCO require attribution, carried
  in `ATTRIBUTION.md` and with every release of the basemap. Candidate files built earlier keep the status recorded at
  build time; the next pool build carries `verified`. `lifeimage/fine/sources.py`.
- **LI.56** (2026-11-25; extends LI.17, LI.19) Further licences confirmed by the author. US public domain (17 U.S.C.
  105; no attribution required, credited as best practice; no implied endorsement): LCSH (Library of Congress), NIBRS
  offence codes (FBI), NAICS (Census/OMB), BLS Consumer Expenditure and CPI categories, and the BLS R-COICOP
  concordance. Princeton WordNet: WordNet 3.0 licence, commercial use allowed, verbatim copyright notice and disclaimer
  kept in every copy (Open English WordNet, CC BY 4.0, is an alternative). EuroVoc: CC BY 4.0 (some linked-data
  releases CC0); credit the Publications Office of the EU. COICOP itself: UN copyright, all rights reserved, so it is
  treated like ICATUS (internal calibration only, LI.19) and consumption domains come from the BLS R-COICOP
  concordance instead. Still open: MeSH terms and ShareAlike sources (UNESCO Thesaurus, schema.org).
  `lifeimage/fine/sources.py`, `ATTRIBUTION.md`.
- **LI.57** (2026-11-25; refines LI.4) The basemap data is released under a permissive share-and-use licence, so every
  source must be compatible with permissive redistribution. Consequences (lead reading): ShareAlike sources (UNESCO
  Thesaurus, schema.org) are excluded, as they would bind the basemap to their terms; attribution sources (CC BY,
  ODC-By, the WordNet notice) are compatible but rule out a pure CC0 release, so the basemap's licence is an
  attribution licence (CC BY 4.0 or equivalent) carrying `ATTRIBUTION.md`; MeSH is admissible with its credit line and
  a dated statement that the copy is not kept current, used only where Disease Ontology and MONDO fall short.
- **LI.18** (2026-11-25) Publishable means the whole library at v1.0: the API contract, the basemap data release,
  the viewers (LI.52, LI.53) and the Benefuture bridge together, not the basemap alone. PLAN.
- **LI.19** (2026-11-25; amends LI.17, LI.15) ICATUS is used only for internal calibration (a local benchmark,
  never distributed, never a source of shipped domains). Where it shows something is needed, the domain comes from the
  corresponding elements of the four open sources (OpenAlex, ESCO/ISCO, Wikidata, ATUS) and other openly licensed
  sources. PLAN, `lifeimage/fine/sources.py`.

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
- **LI.55** (2026-11-25; refines LI.24, LI.25) Adjacent domains keep thematic similarity as far as possible; perfect
  gradation is not expected, but outliers that muddy the picture are fixed (seen in the coarse review: arts and
  religion beside mathematics and statistics, finding and securing housing among agriculture). Placement is settled
  by a physics simulation: polar springs to the judged axes' angles and radius, attraction along overlaps, upstream
  links and learnt co-membership, nearness, and repulsion keeping slices apart; the map sorts itself and the result is
  measured before adoption. DESIGN, PLAN.
- **LI.58** (2026-11-25; refines LI.55) In the layout simulation the angular spring is loose and the distance
  spring stricter. Angles settle first without collision; collision then turns on for an effective tessellation.
  Once tuned, the simulation becomes the de facto method of updating the basemap (each version starting from the
  previous layout as its prior). DESIGN, PLAN.
- **LI.59** (2026-11-25; refines LI.55) Where the layout simulation has no pairwise signal (96% of field pairs; 85-88% of the pairs a
  layout puts within two positions), pairs are judged directly: `relatedness.v1`, one card per pair, 0-10, three fixed
  calibration examples, two variants in opposite order, controls with existing signal and random far pairs to calibrate the scale.
  The answers enter the simulation as the optional 'judged' source (weight and floor governed; empty and loudly degraded until
  answers exist). PLAN (proposal, not a ruling).
- **LI.60** (2026-11-25; author, refines LI.55, LI.58) Order of layout work: circular seriation (global ring order over the
  combined similarity, angle penalty from the axes prior) runs after the fine refinement is merged, as a comparison arm on
  the blinded adjacency check. A further placement clean-up: build the event co-membership overlap list from a large sample,
  compare it with each field's layout neighbours, rank the fields with the most mismatch, find the position where each has
  the most matches, then a runner validates the move by seeing the current and suggested placement with both neighbour sets.
  PLAN.
- **LI.61** (2026-11-25; author, scopes LI.57) Datasets used to generate synthetic events are calibration only and never
  shipped: the library consumes events either preformatted or categorised by an agent. The shipping licence rule (LI.57)
  does not bind them; their terms need only allow internal research use. Data constraints still hold (anonymised or
  synthetic, no identities kept except public figures, no real underage people identified). PLAN.
- **LI.62** (2026-11-25; author, extends LI.61) Event generation sources are global and multilingual, and include social
  media data available for research use (identities redacted; only derived, de-identified features kept, apart from public
  figures). The outcome is a dataset and generator that produce realistic events as text or preformatted records, covering
  essentially any part of the circle and re-targetable as domains are refined; generator and verifier are trained
  adversarially, the verifier judging real-world-ness against calibration sources. PLAN.
- **LI.63** (2026-11-26; author, scopes LI.61, LI.62) Life Image (basemap and library) is non-commercial, as is all of
  Benefuture. Event sources serve only as base data and verification for the non-ML visualisations: no model training and no
  ingestion of their rows. Non-commercial terms therefore permit their use; sources whose terms bar AI tools or training feed
  only statistics computed by code (no agent reads their rows). EVENT_SOURCE_SCOUT, PLAN.
- **LI.64** (2026-11-26; author, refines LI.61) Every event distribution or rate the generator uses keeps a sanitized
  snippet of the source statement that gives it (the sentence, table row with headers, or indicator definition), with its
  locator and retrieval date, for later recalibration and re-verification. No identities, no individual records, quotation
  length only. PLAN. Refined (author, same day): the snippets kept for calibration are action/event/outcome records, not
  factoids: someone (a de-identified role) doing something, and what resulted where known. The factual statement stays as
  the rate's provenance; event snippets are paraphrased from individual sources, never rows from sources barring AI use.
  Event snippets include short-term actions at any timescale (an hour's practice, a meal cooked, a trip to market), not
  only life transitions; each carries its timescale.
- **LI.65** (2026-11-26; author, refines LI.62, LI.64) Source statements and snippets may be of arbitrary detail, but every
  extracted or generated event is relational: event to domain (form, content, outcome, setting), entity to event
  (contribution, production, responsibility by freedom with the option set, impact per affected party, and the records
  acting for, under agreement, informed), event to event (part_of, causes, re_description, concurrent), with the relation
  metadata of LI.42 (valid and record time, counterfactual reference for outcomes, place and span). RELATIONS, PLAN.
- **LI.66** (2026-11-26; author, refines LI.55, LI.60) Seriation is adopted for the coarse ring order; its stability
  (displacement beyond the LI.25 guard targets) is refined in the placement clean-up.
  Exception list for the clean-up (author, 2026-11-27, "as long as we take care of it later"): the stability targets (mean
  25, p95 60, max 120 degrees) and the 200 px tiled-render missing-area tolerance raised 0.0015 -> 0.0020 after adoption
  (tests/test_tiles.py) are restored there.
  Adopted (2026-11-26): basemap `0.0.0-draft+seriation_v0` (pinned in `data/coarse/layout_seriation_v0.json`; the earlier order
  is `layout="axes_v0"`, version `0.0.0-draft`, still reproducible; no domain id moves, so the id migration is identity).
  Migration record `data/coarse/layout_migration_seriation_v0.json`: field centre shift from the axes angle 15.8 / 32.9 / 42.2
  (mean / p95 / max) before, 28.7 / 79.7 / 122.8 after; old to new centre shift 29.7 / 78.4 / 146.0. Exceptions, recorded and
  loud (`layout_stability`), deferred to the clean-up per LI.66: mean above 25, p95 above 60, and the maximum 2.8 degrees above
  the 120 guard (the pressure-width tiling adds to the slot displacement, which the seriation holds to 120). Tile load per
  worst 1024 x 768 viewport at z0 to z6 rose from 19.0 / 24.5 / 36.0 / 27.6 / 15.2 / 13.6 / 8.8 KB to 28.8 / 37.9 / 54.4 / 33.6 /
  22.1 / 17.7 / 9.0 KB (the order keeps fewer same-sector neighbours, so fewer slices merge into aggregates at coarse zoom);
  still far inside the 150 KB bound.
- **LI.67** (2026-11-26; author, refines LI.22, LI.65) Event memberships are wide: extraction and categorisation agents
  name the primary domain, then the next, and so on, until any further categorisation would be bad quality (a stopping
  rule, its threshold governed). Generated event kinds are categorised the same way, so co-membership covers more pairs.
  PLAN, prompts.
- **LI.68** (2026-11-26; author, refines LI.67) Plausible domains are logged as refinement candidates, not discarded:
  domains an agent lists that the gold set neither accepts nor rejects, and rejected domains just below the floor, go to a
  refinement log (item, relation, domain, fit, agent, variant) feeding gold-set completion, new fine domains and
  domain-domain links; they never enter memberships without passing the floor. PLAN.
- **LI.69** (2026-11-27; author, refines LI.67, LI.68) Membership v4 is adopted provisionally; the 55 domains its calibration
  gold neither accepts nor rejects are judged by runners, the author reviewing only disputed cases, and v4 is re-scored against
  the completed gold. Logging suggested (plausible) domains as refinement candidates is constant: every categorising or
  extraction run writes them. PLAN.
- **LI.70** (2026-11-27; author, refines LI.67, LI.68) Extraction runs in two passes. Pass 1 (blind): an agent suggests the
  event's possible categories without seeing the existing domains. Pass 2: an agent with the domain set allocates the matches,
  logs synonyms (blind label to domain) and reviews the non-matching suggestions as candidate new domain entries (to the
  refinement log). PLAN, prompts.
  Built (2026-11-27, not yet run): `blind.v1` and `map.v1` prompts, `lifeimage/two_pass.py`, validators in `validate.py` (pass 1 rejects domain ids,
  pass 2 rejects ids outside the pack, unranked or below-floor lists, domains no blind label matched and unmatched labels without a review),
  synonym log `data/refinement/synonyms_v1.jsonl`, refinement source `blind_unmatched`; the pass-2 pack carries the 1,897 coarse and fine domains
  (about 62k tokens); predictions in `data/gold/two_pass_predictions.md` (pilot: the 32 controls and 50 snippets). Adoption waits for the pilot.
  Merge and hybrid (2026-11-27, lead decision under LI.67 and LI.68; not yet an author ruling): the variants' lists are merged by a support-weighted union
  (`membership.single_support_floor` 0.2; a lone variant's domain below it goes to the refinement log as `disputed`), the intersection kept by name;
  judged on the v4 calibration (recall 0.963, precision 0.881, padding 0.138 against 0.96, 0.80, 0.35: met) and on the kinds and snippets (median
  listed 2 in form and content: met; field-pair coverage 0.93% against the pre-registered 3x of 0.655%: failed, the pure union of the two variants reaches
  only 1.85x). Diagnosis of the two-pass recall loss (`data/gold/two_pass_diagnosis.md`): most of it is pass 2 allocating a label to one fine domain; the
  hybrid `map.v2` (memberships from the event text with the blind labels as hints, a label matching several domains, `unlabelled_add`) is built, not run
  (`data/gold/two_pass_predictions.md`, hybrid section). Pair coverage beyond 1.85x needs more listed domains per event (a wider prompt or more variants).
- **LI.71** (2026-11-27; author, refines LI.22, LI.51, LI.67, LI.70) How domains and categorisation work:
  - Each relation is its own facet: form is the type of act (sale, retail, exchange, financial transaction); content is the
    things and interactions involved (bread, baked goods, food, direct person-to-person transaction); outcome is the concrete
    change of state for each party (money in, inventory spent; ticket obtained, seat booked, promise held); setting is the
    venue and sphere as far as the statement gives it (market, stall, point of sale, retail, commerce; otherwise unknown). The
    key action decides, not the actor's name or occupation. A domain may sit in several relations when it truly applies to
    each, but not by default.
  - Agents list categories from the most specific to the most generic, weight decreasing; the leafier the better, since
    parents and major relatives follow from the classification.
  - Domains form a graph, not a tree: a leaf can have several parents (a ticket is a document, a booking and a promissory
    note, and not a subdomain of travel, since tickets exist for other things), and senses are distinct domains (an issue
    ticket is a separate thing). Bread is a subdomain of baked goods, itself of food.
  - On the image a leaf colours its own pattern strongly at the edge, with some bleed to its parents and relations as the
    classification provides.
  - Placement (author, same day): a multi-parent leaf sits on the circle under the parent with the strongest tie (measured,
    e.g. by co-membership support); its other parents and co-domains need no placement of their own, since the event record
    paints the relevant co-domains anyway.
  - Worked examples (author's blind categories, decreasing weight): "A baker sells bread at the market": form sale, retail,
    exchange, financial transaction; content bread, baked goods, food, direct human-to-human transaction; outcome money
    input, inventory spent; setting market, stall/store/shop, point of sale, retail, commerce, business. "A woman buys a train
    ticket": form purchase, booking, travel planning, logistics; content ticket/pass, receipt, train, public transportation;
    outcome ticket obtained, promise obtained, seat booked, documentation; setting point of sale (rest unknown). PLAN,
    prompts, DESIGN.
- **LI.72** (2026-11-28; author, refines LI.71) Answers on leaf domains, and held-out categorisations:
  - Bleed is the natural spread that many processed events produce, not a rule: no bleed coefficient on relation links or
    parents (LI.30 stands).
  - A leaf's radius follows its uniqueness and complexity (the radius mechanism), not a fixed level.
  - A multi-parent leaf is placed by co-occurrence (the strongest-tie parent).
  - Senses are kept apart by distinct phrasal names (ticket, issue ticket), not by sense ids.
  - A leaf with no placed parent is impossible by construction; if it happens it stays off the image.
  - Is-a links are seeded from public ontologies, then grown from blind labels.
  - Categorisation lessons from the author's held-out examples: form names the act at every level including role, purpose
    and regularity (commuting, passenger, travel in bus, travel in public transport, transportation, going to work, work
    related activities, preparation for work, regular activity); content names the doing and what it involves (bus ride,
    vehicle ride, journey, getting on/off vehicle); outcome only what the statement supports, from the actor's perspective
    (commuter: journey made, time spent travelling; arrival at work rejected: not stated; passenger carried rejected:
    that is the bus's event); setting runs concrete to
    generic (inside bus, inside vehicle, public transport, vehicle traffic, road networks, surface travel). A compound
    statement is several events (growing maize and selling the surplus are two).
  - Author categorisations (gold, held out from prompts): "A commuter rides the bus to work" as above; "A woman casts her
    ballot at the polling station": form voting, civic participation, electoral process, decision making, democracy;
    content ballot, election, public decision; outcome vote cast, vote entered in count, ballot used, turnout counted;
    setting polling station, election, civic life, democratic polity.
  - Built (2026-11-28, not yet run): `blind.v3` (`prompts/blind.v3.md`, `validate.py` version 3, `two_pass.blind_v3_report`, `label_match.HELD_OUT` and
    `NEGATIVE_LABELS`), pre-registered in `data/gold/blind_v3_predictions.md`; the held-out commuter and ballot lists and the two rejected outcomes
    are judged, never prompted. LI.72 gives no accepted outcome for the commuter: the author's list is requested.
  - Built (2026-11-28, not yet run; refines the v3 pilot verdict in `data/gold/blind_v3_predictions.md`): `blind.v4` (`prompts/blind.v4.md`, `validate.py`
    version 4, `two_pass.blind_v4_report`): minimum list lengths enforced (form 5, content 4, setting 4, outcome 2; fewer only with a per-facet
    `short_reason`), outcome = what the event itself makes true for the actor (sequels and other entities' acts excluded; contrast example "a man posts a
    letter"), `unknown` a zero-weight terminator, content the activity first. The commuter's accepted outcomes "journey made" and "time spent travelling" are
    held-out labels, as are the commuter's five competences; `blind.v4` adds the fifth facet `competence` (skills and know-how the event requires of the acting entity). Pre-registered in `data/gold/blind_v4_predictions.md` (confidence 0.55). The prompt illustrates setting inference with a ferry, not
    the bus, so the held-out setting stays unprompted.
  - Open (author's question, lead's proposal pending ratification): a fifth relation for the expertise an event exercises
    or helps form (commuting: bus travel, recognising a bus, getting on and off, pedestrian navigation, reading street
    signs). PLAN, prompts, DESIGN.
- **LI.73** (2026-11-28; author, resolves the LI.72 open item) A fifth event relation, `competence`: the skills and
  knowledge the event exercises or demonstrates for the acting entity (commuting: bus travel, recognising a bus, getting on
  and off, pedestrian navigation, reading street signs). Name chosen by the lead over "uses" (collides with resources consumed,
  layer B production), "skill" (too narrow: excludes knowledge) and "exercise" (collides with physical exercise); `competence`
  follows ESCO's skills/competences and maps onto the skill domains already in the graph. Rules: only competences the event
  actually requires or shows, specific to generic with decreasing weight; weight by how much the event exercises each; it
  records exercise, not mastery (levels still come from accumulated evidence); it applies to the acting entity only (a
  teacher's event exercises teaching; the learner's own events build the learner's). It feeds the green (demonstrated skill)
  channel directly. Name confirmed by the author: `competence`, defined in prompts as the skills and know-how the event
  requires of the acting entity. PLAN, prompts, RELATIONS, DESIGN.
- **LI.74** (2026-11-28; author, refines LI.73, LI.36–LI.42) Competence has a basis: demonstrated or predicted. Demonstrated
  only from validated events (formal or attested records); competence from non-validated event types (claims, self-reports)
  and from profile statements (credentials, roles, enrolment, plans, self-assessment) is predicted (speculated) until
  validated. Demonstrated feeds the green channel, predicted the red; the evidence tier (claimed, attested, verified) decides
  the basis, so the basis follows the record's validation, not the agent's reading. Agents mark each statement's mode (event
  occurred, claim, plan, credential, role, self-assessment); the pipeline assigns the basis from mode and validation. PLAN,
  RELATIONS, prompts.
  - Built (2026-11-28, not yet run; refines the v4 pilot verdict in `data/gold/blind_v4_predictions.md`): `blind.v5` (`prompts/blind.v5.md`, `validate.py` version 5,
    `two_pass.blind_v5_report`, `two_pass.competence_basis`): per-event `mode` (the six values, required) and `layers` {role, purpose, sub_skill} (labels of the form and
    competence lists, or a declared `none`), form naming the actor's role and the purpose, competence naming concrete sub-skills first, the outcome contrast
    naming sequels and other entities' acts even when paraphrased, eight invented profile statements in the pilot controls (`data/gold/profile_statements_v0.jsonl`),
    the overlap metric reporting a number with near-copies, and `label_match.HELD_OUT_FRESH` (the slot for the author's fresh categorisations: the commuter and the ballot
    are now a development set, having guided three revisions). Pre-registered in `data/gold/blind_v5_predictions.md` (confidence 0.5).
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
- **LI.54** (2026-11-25; amends LI.35, LI.34) Before v1.0 every coarse field has fine domains, harm included (no
  field is held at coarse level), and the reputation version with negative records exists alongside the
  predicted/measured one. DESIGN, PLAN.
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
- **GT.2** (LI.67, proposed) Quality floor of the ranked stopping rule for event memberships: fit score 4 of 10 (`membership.fit_floor`), and the least
  Jaccard agreement of two variants' domain lists for a merged membership to stand unescalated, 0.5 (`membership.agree_floor`). Both are
  assumptions until the control battery (`data/gold/membership_wide_predictions.md`) is judged; prompts `membership.v3`, `extract.v2`.

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

### Eventgen increment 3 findings (proposals, for the author's review; not rulings)
- **P.EG3.1** Time-use and labour-force sources disagree where a person's day at work is concerned: India's 2019 time-use survey reports more men aged 15-29 working on a diary day than the
  ILO modelled labour-force curve has employed (any work activity counts in a diary, a week's reference in a labour-force survey). The generator ties diary work to the career and caps it at the
  share employed, recorded as degraded; a cross-source reconciliation (own-account and unpaid family work) belongs in `docs/CALIBRATION`-style notes for the event sources.
- **P.EG3.2** No retrievable source gives the share of first births before first marriage (OECD SF2.4 and DHS STATcompiler returned no usable indicator; Eurostat `demo_fagec` gives births
  by the mother's legal marital status). The assumed target was removed; the sourced births-outside-marriage share replaces it and calibrates the relative hazard of unmarried women
  per region. Candidate for a later increment: DHS marital-status and birth-history aggregates when reachable.
- **P.EG3.3** A single normal marriage-age spread cannot give both the singulate mean age and the share married by 18 (India: 16.8% against 22.3%); the early-component mixture solved
  from the stratum's own share fixes it (22.8%). Candidate home: RELATIONS (event model notes) and the corpus's marriage-age statistics.
- **P.EG3.4** Field pairs co-occur inside one event only (2.1% of the 30381 pairs at 2000 x 3): LI.60's co-membership overlap list will be sparse for most pairs. Composite events
  (a trip that includes shopping and a meal; a workday with its commute, already linked part_of) and life-level co-membership (fields touched in the same person-year) are candidates.
