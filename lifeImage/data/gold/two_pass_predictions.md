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

## Pilot judged (lead, 2026-11-27)
82 items (32 controls, 50 snippets), 2 variants per pass. Pass-1 labels containing domain ids: 0 (structural, met). Distinct
synonyms logged: 488 (>= 10, met). New-domain candidates judged non-noise by the mapper: 4 on controls (5 overall; e.g.
public infrastructure works, public road clearance, child health, food hygiene) (>= 3, met). Precision among judged secondaries
0.968 (2 bad, 50 unjudged; >= 0.95, met); pre-registered-style precision with unjudged against 0.536. Recall of gold-required
domains 0.630 against v4's 0.963 (>= 0.913 required: **failed**, by a wide margin). Escalations 70 of 82 items: the two variants
rarely agree on the full list, and the merge keeps only domains both variants listed. 42 noise labels, 44 unmatched.
Not yet diagnosed: whether recall is lost in pass 1 (blind labels never name the required category), in pass 2 (labels named
but mapped elsewhere or below the floor), or in the merge (each variant has the domain, not both).

## Hybrid pass 2 `map.v2` (pre-registered 2026-11-27, before any map.v2 answer exists; LI.70 refined by `data/gold/two_pass_diagnosis.md`; confidence 0.55 for the set)

Rule under test: pass 1 `blind.v1` unchanged (its answers are reused); pass 2 `map.v2` (`prompts/map.v2.md`) builds the memberships by the v4 rule (floor 5)
from the event text over the whole pack, with the blind labels as hints; a label may match several domains (a fine domain and its coarse parent;
one `match` entry per domain); a listed domain no label of that relation matched is an `unlabelled_add` (obvious domains only); synonym logging and the
review of unmatched labels (`new_domain_candidate`, `noise`) stay. Variants merged by the support-weighted union (`membership.single_support_floor`,
`data/gold/membership_wide_predictions.md`). Judged over the 32 controls against gold v1 and the 50 snippets for the ledgers; map.v1 stays reproducible
(`--version 1`). Batches: `python3 lifeImage/tools/build_two_pass.py map --version 2` (`data/batches/map.v2.{controls,snippets}.var{0,1}.part0.jsonl`),
judged by `build_two_pass.py judge --version 2`. Base: v4 one pass, per variant 0.963 (26 of 27 cells), merged 0.963; map.v1 per variant 0.630.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | Per-variant recall returns to the v4 range | recall of gold `required` per variant (27 cells each), each variant | >= 0.913 (v4 0.963 minus 0.05); expected 0.925 to 0.963 |
| 2 | Merged recall at least as good | recall of `required` of the merged lists (support-weighted union) | >= 0.926 (25 of 27) |
| 3 | Judged secondaries stay real | share of judged secondaries (gold fair against bad), per variant | >= 0.95 |
| 4 | Escalations bounded | controls escalated under the merge (v4 21 of 32; map.v1 28 of 32) | <= 24 of 32 |
| 5 | Blind labels still reveal synonyms | distinct (label, domain) synonym pairs over the 82 pilot items (map.v1: 488) | >= 10 |
| 6 | Blind labels still reveal missing domains | distinct non-noise new-domain candidates, source `blind_unmatched` | >= 3 |

Also reported, no prediction attached: merged `precision_secondary` (gold v1, unjudged and unsure against) and padding (complete definition), the number of
`unlabelled_add` entries (and per relation), the share of labels matched to more than one domain, agreement of the variants, the median listed per relation.
Adapted from the diagnosis's pre-registered line: the diagnosis fixed per-variant recall >= 0.913, judged precision >= 0.95, at most 24 of 32 controls
escalated, at least 10 synonyms and 3 candidates (0.55); this section adds the merged recall (2) because the merge is now the support-weighted union.
Decision if 1 fails: the hybrid is no better than the one-label-one-domain mapper; run v4 one pass beside blind labels (pass 1 as a logger only) rather than
extend pass 2. If 3 fails: the unlabelled additions over-reach (check their share of the secondaries). If 4 fails: escalation is a property of two short
lists, not of the mapper; report it and do not tune the agreement floor on this pilot.

## map.v2 judged (hybrid; lead, 2026-11-27)
Same pass-1 answers; pass 2 by the v4 rule from the event text with blind labels as hints; support-weighted union merge.
Recall of required: variant 0 0.778, variant 1 0.741 (>= 0.913 each: **failed**), merged 0.741 (>= 0.926: **failed**); map.v1 was
0.630 per variant. Precision among judged secondaries 0.884 (>= 0.95: **failed**; 13 bad, 55 not in gold v1). Controls escalated
27 of 32 (<= 24: **failed**). Synonyms 793 distinct cells and new-domain candidates 11 on controls (13 overall), noise labels 8,
unlabelled adds 8 (met). Pass-1 domain ids 0 (met). The hybrid recovered about a third of the gap to one-pass v4 (recall 0.963,
judged precision 0.887 on gold v1) and none of the precision. Reading: two-pass is weaker than one-pass for allocating
memberships, and strong for discovery (synonyms, new-domain candidates). Lead's proposal to the author: memberships from the
one-pass v4 prompt; the blind pass kept for discovery only, its labels logged as synonyms and candidates (LI.68-70).
