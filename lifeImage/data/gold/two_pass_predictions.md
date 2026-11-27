# Two-pass extraction (LI.70): pre-registered predictions

Registered 2026-11-27, before any pass-1 or pass-2 answer exists. Rule under test: pass 1 `blind.v1` (a runner suggests the event's categories
in its own words, never seeing the domain set, plus the relational extraction of LI.65) and pass 2 `map.v1` (a runner with the domain pack, coarse
and fine, allocates each blind label to a domain id at the v4 floor of 5, logs synonyms, reviews the unmatched labels as `new_domain_candidate`
or `noise`). Code: `lifeimage/two_pass.py`; validators in `lifeimage/validate.py`; pilot batches by
`python3 lifeImage/tools/build_two_pass.py pilot` (pass 1: the 32 membership calibration controls and 50 calibration event snippets, 2 variants,
at most 50 per file, `data/batches/blind.v1.{controls,snippets}.var{0,1}.part0.jsonl`); pass 2 by `build_two_pass.py map` after the pass-1
answers exist; judged by `build_two_pass.py judge`. Confidence 0.5 for the set; each line is a separate claim and the set can fail in parts.

Comparison base: `membership.v4` one pass on the same controls (`data/gold/membership_wide_calibration_report_v4.json`): recall of the gold
`required` domains 0.96 (0.9630), precision among the judged secondaries 0.98 (0.9796). The gold is being completed concurrently (LI.69); the
judge reads the controls file as it stands and the report states which controls file it read.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | Two-pass memberships keep the v4 recall | share of the gold `required` domains listed by the pass-2 memberships, over control cells (both variants) | >= 0.91 (the v4 value 0.96 minus 0.05) |
| 2 | Secondary domains stay real | share of judged secondary domains (gold `fair` against `bad`) that are `fair` | >= 0.95 |
| 3 | Blind labels reveal the synonyms the aliases lack | distinct (blind label, domain) pairs of kind `synonym` in the synonym log over the 82 pilot items | at least 10 |
| 4 | Blind labels reveal missing domains | distinct proposed new domains (candidates the mapper judged non-noise, source `blind_unmatched`) over the 82 pilot items | at least 3 |
| 5 | Pass 1 never sees the domain set (structural) | pass-1 prefix, pass-1 input and every pass-1 label, gloss and relational string contain no domain id: zero domain ids, in every item | 0 in every item |

Also reported, no prediction attached: the unjudged secondary count (as the v4 report), the share of blind labels matched, left as
`new_domain_candidate` and left as `noise`, the agreement of the variants (Jaccard of blind labels, of pass-2 domains), the escalation rate,
the median listed domains per relation.

Reading: 1 and 2 test that the blind step does not cost the memberships anything the domain list buys (anchoring); 3 and 4 test that it gains
what the domain list hides (unanchored categories). Prediction 5 is a structural claim held by the validator and a test; the other four are
distributional claims on one pilot and two variants, so a pass is a pilot result, not a rate.

ETA and adaptation: judged when the lead has the four pass-1 answers files, the pass-2 batches built from them and answered (minutes of runner
time each). Decision rule: if 1 fails (recall below 0.91), the blind labels are too narrow, so widen pass 1 (a lower blind floor than 4, or a
second reading order) before blaming pass 2; if 2 fails, the mapper over-matches (synonym confidence too lax), so raise the match requirement in
`map.v1` text; if 3 fails, the aliases already cover the vocabulary the runners use (a good result: nothing to add, record it); if 4 fails, either
the domain set is already wide enough for these items or the review is conservative, so run the kinds and snippets at scale before concluding.
One re-run on a changed prompt (a new version, the old stays) before any adoption; the pass-1 and pass-2 prompt versions are recorded with every
result.
