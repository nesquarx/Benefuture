# lifeimage-eventgen2 (Life Image eventgen increment 2: relational events, partners/deaths, sequence head)

Status: IN PROGRESS

## Goal and acceptance checks
A relational events (LI.65): layers A (4 memberships, partition of unity), B (participant records, responsibility by freedom, impacts, acting_for/under_agreement/informed), D (part_of, causes, re_description, concurrent), LI.42 metadata (valid/record time, place/span, counterfactual on outcomes); calibration event snippets get a relational form.
B probe: partners (spouse entity), fatherhood, deaths (WPP/WDI mortality), < 10 s for 500 x 3.
C sequence head: hard zero-tolerance checks, soft checks vs calibration with significance rule; shuffled-order variant passes rate head, fails sequence head; premarital-birth variant flagged softly.
Acceptance: `cd lifeImage && python3 -m pytest -q` green; probe one command.

## Predictions (lead, confidence 0.55, recorded before measuring)
(a) every generated event passes the relational validator; (b) shuffled variant passes rate head and fails sequence head on >= 95% of seeds; (c) probe with partners and deaths < 10 s (500 x 3); (d) >= 3 soft sequence statistics have calibration targets and pass.

## Red baseline (current code, before implementing; tests/test_eventgen_red2.py)
- "9776 of 9776 generated events carry no participant records"
- shuffled sequence (ages permuted among persons per region, sex, kind) passes the rate head (46 pass, 0 fail, 20 inconclusive at 10 seeds) and every row validates.

## Decisions
- Reuse: validate_row / validate_evidence (rows), validate_participation_answer v2 (layer B), responsibility_from_freedom (degraded log), LINK_TYPES (layer D), validate_entity.
- Births become marital-state dependent with the marginal ASFR preserved (h_married = ASFR / (M(a) + r (1-M(a)))); this couples births to marriage noise (existing independence test amended).

## Done
- World: deaths (own stream; WDI infant/under-5, WPP 40q0, Gompertz 40-50), spouse gap, divorce (Param or governed default, degraded), marital-state births with marginal ASFR preserved, fatherhood; rate head reads survivors / woman-years and checks 40q0 (72 statistics pass).
- `relational.py`: layers A, B (library participation format + responsibility by freedom, degraded defaults logged), D (part_of, causes, concurrent; re_description validated only), LI.42 metadata, relational event snippets (1120 in the committed table), `World.events()`, `entities()`.
- `sequence.py`, `variants.py`: hard checks (zero tolerance) and soft statistics with significance rule; shuffled-order and births-ignore-marriage counterexamples.
- Tests: tests/test_eventgen_relational.py (26), tests/test_eventgen_sequence.py (21); calibration/probe tests amended (EV helper, noise coupling).
- README of the package updated; probe prints both heads and counterexamples.

## Measurements and prediction verdicts
- (a) HOLDS: every generated event passes validate_event (validated at build, 14570 events for 1500 people) and a strict validate_row on a sample.
- (b) HOLDS: shuffled order passes the rate head (0 fail of 72) and fails the sequence head on 60/60 seeds (also 40 people per region).
- (c) HOLDS: world + rows + relational events for 500 x 3 in about 3.7 s.
- (d) HOLDS: 11 calibrated (Param) soft statistics pass; one known soft flag: IND share married by 18 (0.17 vs 0.22, z -4; sd of marriage age too narrow).
Findings: premarital-first-birth share depends strongly on region through marriage age (FRA 0.47, KEN 0.24, IND 0.11), so the single assumed target is judged only where women marry before 25; world-level fallback Params are no valid soft targets (FRA married-by-18 world value 19% vs 1%): such statistics are left unjudged, recorded as degraded.

## In progress
final full-suite run, commit and push, mark DONE.

## Next
Real premarital/nonmarital birth data (OECD SF2.4, DHS); marriage-age distribution with a heavier early tail (IND); spells and event-history comparison; registration-lag noise (record time); spouse death and remarriage; upper secondary; work events (employer role).

## Files touched
progress/lifeimage-eventgen2.md; lifeImage/lifeimage/eventgen/{world,events,rates,calibration,governed,probe,relational,sequence,variants}.py and README.md; lifeImage/tests/test_eventgen_{calibration,probe,relational,sequence}.py; lifeImage/tools/{eventgen_fetch,eventgen_relationalise}.py; lifeImage/data/events/calibration/aggregates_v1.jsonl

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_eventgen_calibration.py tests/test_eventgen_probe.py tests/test_eventgen_relational.py tests/test_eventgen_sequence.py && python3 -m lifeimage.eventgen.probe
