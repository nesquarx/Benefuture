# Refinement log (LI.68)

A refinement candidate is a domain an agent found plausible for an event item that the membership rule did not accept. Three sources:

- `unjudged`: the agent listed it as a secondary domain on a calibration control, and the gold set names it neither fair nor bad.
- `near_floor`: the agent rejected it with fit = floor - 1 (floor 4 for prompt v3, 5 for v4), and the gold set does not judge it.
- `disputed`: only one of the two variants listed it, and the gold set does not judge it.

`candidates_v1.jsonl` has one record per item, relation, domain, source, prompt version and variant (item id and text hash, fit, the
domains listed beside it). It is append-safe and sorted by key. `summary_v1.json` counts, per domain, how often it is a candidate
and from which source, and per (candidate, listed domain) pair how often they co-occur in an answer. The calibration judge
(`tools/build_membership_wide.py judge|refine`) and the ingest (`ingest kinds|snippets`) write both; `refine` backfills from existing
calibration answers.

How it feeds, by review (a recorded ruling), never automatically:

1. Gold-set completion: unjudged and near-floor domains on control items are reviewed and added to a control's `fair` or `bad` list,
   which tightens the membership battery's precision metric.
2. Fine-domain proposals: a domain that recurs as a candidate across items, or that candidates keep pointing near, suggests a
   missing or too-coarse fine domain.
3. Domain-domain links: a candidate that co-occurs with a listed domain across many answers is a proposed link between the two.

None of it changes memberships: a candidate enters a membership only by passing the floor in a later answer.
