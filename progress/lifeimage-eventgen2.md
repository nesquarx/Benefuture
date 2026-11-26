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
(nothing yet beyond red tests)

## In progress / next
implement world changes, relational.py, sequence.py, snippet relational forms, tests, README.

## Files touched
progress/lifeimage-eventgen2.md; lifeImage/tests/test_eventgen_red2.py

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_eventgen_calibration.py tests/test_eventgen_probe.py
