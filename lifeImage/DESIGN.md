# Life Image: design

Status tags follow the parent repository: `[R]` ratified by the author, `[P]` proposed, `[OPEN]` unresolved.
Everything before v1.0 is open to experiment (author, 2026-11-20); `[R]` marks the current direction, not a freeze.

## Scope

- **[R] A separate subproject** (author, 2026-11-20): its own folder, workflows and releases; it may borrow from
  Benefuture and must operate and publish without it.
- **[R] The product** (author, 2026-11-20): a library with an API contract, fillable at the simplest by a basic
  language model reading a resume or prospectus, rendering an infinitely zoomable image that resolves down to the
  individual pieces of reputation.
- **[R] Users** (author, 2026-11-20): real entities on the real basemap, and Benefuture simulations on a synthetic
  basemap until they adopt real domain subsets. Both use the same contract.
- **[R] Ownership** (author, 2026-11-20): held by the project before v1.0 is published. The parent repository is
  LGPL; the basemap data needs its own licence, compatible with its sources' terms `[OPEN]`.

- **[R] Domains concern everything, not only work** (author, 2026-11-20): they are to be the backbone of
  Benefuture's behavioural transaction substrate, so the graph must incorporate and classify any life event or
  behaviour (care, health, home, relationships, play, faith, civic life, consumption, harm), not only knowledge,
  skills and occupations.

- **[R] Everything is a domain; membership is typed** (author, 2026-11-21; Benefuture L22 `Dn(T) := [(Dn_i, RelType,
  Wt)]` and ruling 8.156, partition of unity per relation type). Harm, consumption, transitions and events are domains
  like any other. A thing or event belongs to many domains at once through different relations: a birth is an event
  in family and health; it happens to the mother, who also causes it; it causes the newborn; the attending doctor
  handles it and gains expertise in it; a poet writing about it engages in poetry about birth. Watching a film is
  consumption (as a kind of act, subdomain watching), and also culture and recreation (as content and purpose).
  Cross-cutting domains therefore appear on the image as spread patterns, not contiguous slices.

## Layers

1. **Domain graph (basemap).** Every domain, nested and overlapping (Benefuture L22: fuzzy nesting, natural overlap,
   relations learnt from memory rather than declared). Built as part of this work: a real domain graph.
2. **Ingestion.** Adapters turn sources into evidence rows. Tiers: claimed (resume, prospectus, read by a language
   model) → attested (issuers, employers, co-authors, background checks) → measured (publications, logs, causal
   contribution in Benefuture). Confidence never reaches 1.
3. **Contract.** One row per piece of evidence: entity, the entity's relation to the event (relation type), domain
   memberships as (domain, relation type, weight) summing to 1 within each relation type, with the basemap version,
   channel and sign, magnitude, date, tier, confidence, provenance (source and span), revocation. Benefuture's
   per-domain reputation (L101: positive, negative, prediction accuracy, relevance net of decay) is a fold over rows.
4. **Projection.** Angle and radius come from the basemap, never from the entity, so images are comparable and
   combinable (sum for groups, intersection for comparison).
5. **Renderer.** Additive colour on black; semantic zoom from the whole disc to domains, leaves and single rows;
   low confidence visible in the image.

## Basemap

- **[R] The whole domain space from the start, refined progressively without breaking the angles; basemaps change
  yearly; non-raster images update automatically** (author, 2026-11-20). Rows keep their original domain identifiers
  and basemap version; each release ships a migration table (split with weights, merge, rename, deprecate) and
  migration is a pure function. Raster images carry their basemap version (the flange is a natural place).
- **[R] Top level by the concept's axes first** (author, 2026-11-20): abstract ↔ tangible (left ↔ right), personal
  and social ↔ global and professional (bottom ↔ top). Other arrangements may be tried before v1.0.
- **[R] The axes dictate sectors; domain pressure dictates slices** (author, 2026-11-21). Sectors are not a frozen
  list: they emerge from domains' approximate positions on the axes. A domain's slice width follows its pressure (how
  much recorded activity it carries), and each yearly version adjusts slightly: AI was a niche slice inside computer
  science, related to science fiction and philosophy, until the 2000s, and widens over the last decade; mRNA likewise.
  Stability then means gradual change (order kept, per-version drift bounded), not frozen angles; the sequence of
  basemaps is itself a history of what humanity does. Pressure measure `[OPEN]`: the share of recent evidence rows,
  works or postings per domain, smoothed over years.
- **[R] Radius from complexity, difficulty and specificity, which correlate naturally; outward means more of all
  three. Scale of impact is shown by colour intensity, not radius. A net new achievement (beyond known domains) gets
  a notch at the rim** (author, 2026-11-20).
- **[R] Domains are networks, not trees** (author, 2026-11-21): tree-ish and DAG-ish but not always (cycles are
  possible); "parent" is neither a strong nor a singular relation. Each domain is placed once, where it is closest.
- **[P] Angle-stability invariants**, each with acceptance and counterexample tests: a domain stays near the
  domains it is closest to (containment only where a strict hierarchy exists); neighbours keep their circular order (insertion takes the angle between them); a domain's centre
  angle moves less than a governed ε between versions; a removed domain leaves a tombstone mapping to successors,
  and its neighbours do not close the gap.
- **[P] Seed sources** (licences to verify before use): OpenAlex topics, ESCO, O*NET, Wikidata, and for the rest of life ICATUS, COICOP, ICF/ICD (later ICCS); overlap weights
  learnt from co-occurrence.

## Building the graph

- **[R] Building and refining the domains is mechanical, and manageable by a small model** (author, 2026-11-20), to
  conserve tokens. Levels: coarse, fine, finer, and the event record. Plan: [PLAN.md](PLAN.md).

## Channels

- **[R] Colour stays in the event's domains** (author, 2026-11-21): no bleed to neighbouring domains (similarity never
  credits), a little bleed into major upstream domains.
- **[R] The image is a view over a subset of relations** (author, 2026-11-21). An event's memberships may be many;
  Benefuture's behavioural transaction substrate records them all, and the Life Image keeps only the relations that
  set its colours. Watching many films is all consumption in the substrate, but on the image gives at most some
  expertise in cinema; writing reviews and criticism are outputs, and count for more. The mapping from relation
  types to channels, with its caps, is a governed table.

- **[R] Each channel projects through its own relations** (author, 2026-11-21). Potential, expertise and impact
  apply differently through different relation types, so one entity or domain has a different shape per channel.
  Expertise follows what was done and engaged with (form, content): the shape of mRNA expertise changed only mildly
  over two decades. Impact follows what changed (outcome): mRNA's impact moved from research to health to survival.
  The projection table therefore maps (relation type, participation) to each channel separately.
- **[R] Potential is predicted expertise and predicted impact; self-assessment counts** (author, 2026-11-21; channel
  split amended by LI.37 in `BACKPROPAGATION.md`: red knowledge and potential, green demonstrated skill, blue impact).
  Channels: red potential, green expertise, blue impact (the concept's arrangement 1). The mix shows estimation:
  a mid-career image with much red and little yellow (red + green) or purple (red + blue) shows over-estimation;
  blues, teals and greens without red show under-estimation; a homogeneous blend gives whites and greys with flecks
  of colour: someone who estimated, learnt and contributed in much the same areas. This judges estimation and the use
  of expertise only, not worth. It is Benefuture's prediction accuracy per domain (L101) made visible.
- **[R] Two image versions for now** (author, 2026-11-21). The predicted/measured image (red potential, green
  expertise, blue impact; Benefuture's predicted and measured metric models, L86) fits a world before Benefuture and is
  the first product. The reputation image (positive and negative, L101) needs better negative records, which exist
  today mainly for public figures and convicted offenders, so it comes later and resolves the negative-channel colour.
- **[R] The negative channel comes later** (author, 2026-11-20), as criminal history, known impacts and background
  checks begin to supply it. The contract carries sign, tiers and revocation from v0, so adding it breaks nothing.
- **[P] Obligations for negatives:** gating of sensitive personal data (Benefuture L133), legal erasure (spent
  convictions, expungement, right to erasure) through revocation and per-jurisdiction expiry, and decay with
  rehabilitation (Benefuture L117) as a tested property.
- **[OPEN]** Channel assignment (the concept's arrangement 1, arrangement 2, or a blend).

## Data for prototyping

- **[R] Data use** (author, 2026-11-21): no real minors; anonymised or synthetic data about students and young people
  is fair game. For testing extraction and comparisons any data is fair game provided identities are redacted and the
  test data is not saved; only public figures' data may be kept. Exceptional people are the easy case: the focus
  includes regular people.
- Consequences: a redaction step runs before anything is stored or shown; raw test inputs live only in an ignored
  ephemeral folder (`data/ephemeral/`) or the scratchpad, never in git; what is kept are derived metrics and public
  figures' records. Regular-people tracks: resume datasets (extraction tests only, redacted, unsaved), anonymised
  learning and time-use microdata, and synthetic personas generated from their distributions.

## Risks carried into the design

- Self-reports at the claimed tier: a beautiful image of an inflated resume overstates its authority; confidence
  must show in the image.
- Points are displayed, never peer-awarded: reputation comes from evidence (in Benefuture, causal contribution),
  since peer awards invite rating rings.
- Halo at a glance: no single score; per-domain detail on zoom.
- Regulation: evaluative use in hiring is high-risk under the EU AI Act and limited by GDPR Art. 22 (to verify);
  subject-controlled self-presentation is the safer default.

## Precedents to verify before citing

- Rafols, Porter and Leydesdorff (2010), science overlay maps: an organisation's publications overlaid on a fixed
  global map of science.
- Börner et al. (2012), the UCSD map of science: a stable, maintained base map of subdisciplines.
