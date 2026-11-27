# Leaf domains: how they enter the graph (design note, proposal)

Status: `[P]` proposal for author review under LI.71 (2026-11-27) and its placement addition (strongest-tie parent). Nothing here is implemented;
the existing LI.22, LI.30, LI.36, LI.51 and LI.67 to LI.70 rules stand until the author rules. Numbers are from `data/fine/fine_v1.jsonl` (1,634
fine cards) and `data/coarse/seed_v3.jsonl` (263 coarse fields and sectors; 1,897 cards in the pass-2 pack).

## 1. What LI.71 asks of the graph

- Domains form a graph, not a tree. A leaf may have several parents (a ticket is a document, a booking and a promissory note, and is not a
  subdomain of travel, since tickets exist for other things). Bread is a subdomain of baked goods, itself of food.
- Senses are distinct domains (ticket, a document entitling travel, and issue ticket, a tracked work item).
- A leaf sits on the circle once, at the edge, under the parent with the strongest tie (measured, for example by co-membership support). Its other
  parents and co-domains need no placement of their own, because the event record paints the relevant co-domains anyway.
- On the image a leaf colours its own pattern strongly at its own position, with some bleed to its parents and relations as the classification
  provides.
- Agents name leaves: blind categories run from the most specific to the most generic, so the specific ones are leaf candidates and the generic
  ones their likely ancestors.

Two graphs are kept apart throughout. The classification graph holds every parent and relation edge and carries no geometry. The placement is a
tree over it (each leaf has exactly one placement parent, the strongest tie), and it is the only place geometry comes from. The bleed rule (section 5)
reads the classification graph only; it adds no placements.

## 2. Nodes and edges

A leaf is a fine card (level `fine`, id `f.<slug>`), the same shape as today's cards with these additions (all optional, so every existing card
stays valid and no id moves: the migration of the 1,634 existing cards is the identity):

| field | meaning |
|---|---|
| `parents` | `[{id, kind, tie, basis}]`: the classification edges upward. `kind` is `is_a` (bread to baked goods; ticket to document, booking, promissory note) or `part_of` (a stall in a market). The target may be a fine card, a coarse field or a sector (today targets are coarse or sector only). `tie` in (0, 1] is the strength of that edge on its own, not shared out: a ticket is wholly a document and wholly a booking. `basis` names where the tie came from (section 3). |
| `primary` | the id of the placement parent; derived (section 4), stored so a version change is a visible event. |
| `sense` | one line fixing the sense (section 3). Required for a card whose label is shared. |
| `relations` | `[{id, kind, weight}]` non-hierarchical links (today's `overlap`, plus `related`, `used_with`). No geometry. |
| `upstream` | kept as a derived field for the existing code: the coarse and sector ancestors reached by the `is_a` closure, weights normalised to 1 as today. `levels.py`, `projection.py` and `layout` read it unchanged. |

Why `tie` and not the existing `weight`: today's upstream weights are a partition of unity over the coarse parents (they sum to 1; 957 cards have one
parent, 568 two, 10 three, 99 none and fall back to `overlap` for placement, 146 overlap links in all). A partition says how a leaf's colour is
shared, not how much it is a kind of each parent: one card cannot be wholly a document and wholly a booking if its weights must sum to 1. So the
partition is derived from the ties (`pi = tie / sum of ties`) where a share is needed, and the ties are kept as the classification.

Cycles are allowed in `relations` and forbidden in `parents` (a domain is not its own ancestor); a validator checks it.

## 3. Senses

- Identity is label plus sense. The id is `f.<slug>` for the first sense met and `f.<slug>__<sense_slug>` when a second sense appears (for example
  `f.ticket__travel_document` and `f.ticket__work_item`; the id pattern `[csf]\.[a-z][a-z0-9_]*` still holds, so id guards are unaffected).
  The first sense keeps its old id when a split happens; the migration records the split (`ticket` to the two senses, with weights by the observed
  usage), as the migration table already allows.
- Every card of a shared label carries `sense`; the display label is "ticket (a document entitling travel)". Aliases belong to one sense. The
  existing alias rule (an `exact` match must equal the label or an alias) stays; a label shared by two senses is matched by its gloss, never by
  the word alone.
- blind.v2 labels carry glosses for this reason, so the mapper compares the label's gloss with each sense's `sense`. The synonym log
  (`data/refinement/synonyms_v1.jsonl`) is keyed today by (label, domain); keyed by (label, gloss digest, domain) it records which sense each
  usage meant, so a word whose glosses cluster apart across usages is a homonym to split, and two senses whose glosses merge are one domain.
- Today's data: 18 normalised labels or aliases are already shared between two cards (for example "computer science" between `c.computer_science`
  and `f.application_computer_science`, "neurology" between two fine cards). They are mostly duplicates to merge or fold, not true homonyms, which
  suggests the senses audit finds more merges than splits at first.

## 4. Placement: the strongest-tie parent

Each leaf has one placement parent, `primary`, the parent of strongest tie `T`; the leaf is placed inside that parent's arc in the outer rings (LI.51
mechanism unchanged: no coarse arc moves). Other parents and relations have no geometry of their own.

Measure of the tie, candidate. For a leaf l and a parent p,

    T(l, p) = s(l, p) x tie_edge(l, p) + (1 - s(l, p)) x tie_class(l, p),   s = n / (n + n0)

where `n` is the co-membership support of l with p in the event record (`comembership.py`: items where both have weight above 0, pooled over the
relations, `p(p | l)` the soft conditional the module already computes), `tie_edge` is that conditional and `tie_class` the classification tie
(the `fine_parent` vote weight today; the blind-label chain, section 6, for new leaves). `n0` is governed. With no support (`n = 0`) the rule is the
classification tie alone: the stated fallback before data exists.

Fallback ladder, each step recorded as a `degraded` entry when it is used (progressive degradation, loudly):
1. co-membership support `n >= n_min` for at least one parent: `T` as above;
2. classification ties from the `fine_parent` votes or the blind-label chain;
3. the source's own broader class (`broader_in_source` of the candidate pool);
4. the existing overlap fallback (`placement_parents`), then the nearest coarse field by the pass-2 mapper's review.

Stability (LI.25): the primary changes between basemap versions only when a challenger beats the incumbent by a margin `delta` (governed), and the
change is listed in the version's migration record (a leaf's angle then moves; the guard targets of LI.66 apply). A tie that is exactly equal is
broken by id, as `upstream` does today.

Why the other parents need nothing more: an event that is a ticket purchase lists the ticket in content and the booking in form or outcome (LI.71's
second example), so the record itself paints each co-domain wherever it is placed. Placing a leaf a second time would paint it twice.

## 5. Colouring and bleed

Existing rules this builds on: an imprint lands on the named domain; a governed fraction `beta` (`projection.Governed.bleed_fraction`, 0.1) passes one step to
upstream links by link weight, none to neighbours or overlap links (LI.30), each stream keeps its total (conservation); a coarse level re-saturates
the sum of its own imprints and its fine children's luminosity times link weight, so a field holds a fine imprint whole, once (LI.51).

Candidate rule for a leaf l with an imprint of luminosity L (the LI.36 amount, weight x decay):

    x_l  = (1 - beta) L                                   strong, at its own position
    x_p  = beta (1 - rho) L pi(l, p)    for each parent p, pi = T / sum of T over l's parents
    x_r  = beta rho L omega(l, r)       for each relation r, omega = w / sum of w over l's relations

so the total passed on is `beta L` and the stream is conserved. `rho` (the share of the bleed that goes to relations) is governed with default
0, which is the LI.30 status quo (none to overlap); a positive value is what LI.71's "parents and relations" would mean if the author rules that
relations bleed. With no relations, `rho` is treated as 0 and the remainder stays with the parents; with no parents (an orphan candidate awaiting
review) nothing bleeds and the leaf keeps `L`.

Aggregation is separate from bleed and follows the placement tree only: a parent's level re-saturates its own luminosity plus each child's
luminosity for the children placed under it (LI.51, the child counts whole once). A non-primary parent receives the leaf by bleed only, never by
aggregation. Reason: aggregating through every parent would count one imprint more than once at a shared ancestor (ticket under document and
booking, both under one field), breaking conservation; bleed shares it by `pi` and keeps the total.

Candidate governed coefficients (all go to `lifeimage/governed.py` and the README list when built): `beta` (existing, 0.1); `rho` (0); `n0` (support
at which the co-membership tie weighs half, default 20 items, assumption); `n_min` (support before the co-membership tie is trusted at all, 5);
`delta` (primary change margin, 0.1 of tie); `gamma_depth` (decay of bleed per extra `is_a` step if the author wants more than one step, default
off). Gaming and failure: a leaf nobody can place (no parent) is an orphan, listed and never coloured by guess; a label stuffed into many parents
buys no more colour (shares sum to `beta L`); a sense split that halves a well-supported domain is blocked by the review step below.

Test sketch (dual suites, red first): acceptance (conservation across multi-parent bleed; a ticket imprint lights ticket strongly and its parents
by `pi`; one imprint counted once at a shared ancestor), counterexample (aggregating through every parent double counts: the total at the shared
ancestor exceeds `L`).

## 6. From blind labels to leaf candidates

The existing path (LI.68, LI.70): pass 1 blind labels, pass 2 matches each to a domain (exact or synonym) or reviews it as `new_domain_candidate`
(refinement log, source `blind_unmatched`, with label, gloss, nearest existing domains and a proposed parent) or noise; matches feed the synonym log.
`blind.v2` changes what arrives:

1. Specific to generic. The first categories of a relation are leaf candidates; later ones in the same list are proposed ancestors. Each candidate
   record gains `chain`: the later labels (with glosses) of its list, in order, as `is_a` parent hints, with their weights as the tie's
   `tie_class` seed (normalised to the list). A chain is a hint, not an edge: "financial transaction" after "sale" proposes a parent, and the
   mapper may reject it.
2. Gloss as sense. The record carries the gloss; the mapper compares it with the `sense` of the candidate matches, so "ticket (travel document)"
   matches the travel-document sense, not the work item.
3. Relations across lists. Labels of one event under different relations (ticket in content, seat booked in outcome) propose `relations` edges
   by co-occurrence, as the refinement log already proposes domain-domain links.
4. Promotion. A candidate becomes a leaf card when, across items and variants, it recurs (distinct items at least `n_leaf_items`, the share of
   variants naming it at least a governed floor), its glosses cluster to one sense, and its chain agrees on at least one parent that exists in
   the graph; a runner reviews, and the author sees the disputed (as for the gold, LI.69). Otherwise it stays in the log. Nothing enters
   memberships by passing the log, only by passing the floor in a later answer (LI.68 unchanged).
5. Synonyms. Matched labels keep feeding the synonym log; with gloss digests it also proposes sense splits and merges (section 3).
6. Minting. The id is `f.<slug>` plus a sense suffix where needed; the card's `parents` come from the chain and the mapper's nearest domains with
   `basis` naming them; `primary` follows the fallback ladder of section 4, so a new leaf is placed by its classification tie until support exists.

The two-pass mapper (`map.v2`) reads `fit` today; it is adapted to weights and glosses after the `blind.v2` pilot (`data/gold/blind_v2_predictions.md`).

## 7. What the current fine level needs

The 1,634 cards are mostly occupations, disciplines and activity groups (ESCO, OpenAlex, ICATUS, Wikidata, cached answers). The cards LI.71
shows (bread, baked goods, ticket, receipt, seat booked, direct human-to-human transaction) are things, acts and states, and the pack has none of
them (no label contains "bread", "baked", "booking" or "ticket" other than `f.cashier_clerk_ticket`, an occupation). Needs, in order:

1. Schema (`schemas/card.schema.json`): the optional fields of section 2; a validator for `parents` acyclic, `primary` among the parents, `sense`
   present where a label is shared, and `upstream` equal to the derived closure.
2. Links: `upstream` is not single-parent today (578 cards have two or three coarse parents, 531 of them with a second weight at or above 0.3),
   but it is (a) coarse-only: no leaf under a leaf, so bread cannot sit under baked goods; (b) untyped (no `is_a` or `part_of`); (c) a partition
   (weights share one unit instead of each tie standing alone); (d) without a stored primary or the basis of a tie. Existing weights become the
   initial `tie_class` (basis `fine_parent.v1`), `primary` the heaviest as `placement_parents` picks today, so the layout does not move.
3. Code touched when built: `lifeimage/fine/cards.py` (`upstream`, `placement_parents` read `parents` and `primary`), `levels.py` and
   `projection.py` (the bleed of section 5, aggregation along `primary`), `layout` (fine arcs inside the primary parent), `packs.py` (a pack line
   carries the sense for shared labels), `validate.py` (`exact` match rule by label and sense), `refinement.py` and `two_pass.py` (`chain`, gloss
   digest), `migration.py` (split with weights). The tile files, which carry ids only, are unaffected.
4. A senses audit of the 18 shared labels and of the sense-prone words in the synonym log, producing the first merges and splits.
5. A first leaf wave from the `blind.v2` pilot and the snippets: promote candidates by section 6, then re-measure pair coverage (the shortfall
   `data/gold/two_pass_diagnosis.md` names) before wiring the bleed into the full levels.
6. Basemap version: adding leaves widens fine arcs inside their primary parents only (no coarse arc moves); the migration record lists each
   leaf's primary and any change of it.

## Open questions for the author

1. Relations and bleed: does LI.71's "bleed to its parents and relations" mean that relation links (today's overlap) now receive bleed, reversing
   LI.30's "none to neighbours" for them? The note defaults `rho` to 0 (no change) until ruled; a positive default is a one-line change.
2. Depth of the bleed: one step to direct parents (today's rule) or a decaying bleed up the `is_a` chain (a bread imprint reaching baked goods and
   food)? The note keeps one step, with aggregation along the placement tree carrying the rest.
3. Non-primary parents: they receive bleed (as written) but no aggregation and no placement. Is bleed to them wanted at all, given that the event
   record paints the co-domains? If not, `x_p` goes only to the primary parent and the polyhierarchy lives in the classification and the relations.
4. Where is the leaf level: stay in level `fine` with `f.` ids (as written) or a new level (the plan's "finer", LI.54 speaks of fine for every field)?
   Leaves under leaves (bread under baked goods) make `fine` nested, which `levels.py` aggregates in one step today.
5. Tie measure: is co-membership support (`p(parent | leaf)` over the event record, shrunk by `n0`) the measure you want for the strongest tie, or
   should the tie be the mapper's judged `is_a` strength? The note uses the former once data exists and the vote weight before.
6. Sense identity: is a sense split the author's call each time, or may a runner review it with the author seeing only disputes (as LI.69 does for the gold)?
7. Does a leaf with no parent yet (an orphan candidate) stay off the image until placed (as written), or sit in a holding arc at the rim, as the DESIGN's net-new
   achievement notch at the rim does?
8. The authority of `is_a` for things the cards did not cover (bread, ticket, receipt): seed these from a public ontology (Wikidata, an ontology of
   goods and documents; licence to check, as for the fine pool) or grow them only from blind labels?
