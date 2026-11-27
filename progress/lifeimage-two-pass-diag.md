# lifeimage-two-pass-diag

Status: DONE

## Goal and acceptance checks
Diagnose where two-pass membership recall (0.630 vs v4 0.963) is lost, without changing prompts or code; deliver
`lifeImage/data/gold/two_pass_diagnosis.md` (classification table, per-variant/union/weighted recall, escalation causes, v4 comparison,
recommendation with pre-registered prediction). Read-only analysis function plus test allowed. No LLM batches.

## Decisions
- 0.630 is per-variant recall (the judge scores each variant's list); intersection merge is 0.481; union 0.778.
- Classes by word-overlap heuristic then audited by eye; both reported.
- Recommendation: hybrid (pass 2 v4 rule with blind hints, multi-domain per label); not implemented.

## Done
lifeimage/two_pass_diag.py, tests/test_two_pass_diag.py (3 green), data/gold/two_pass_diagnosis.md.

## In progress / Next
none (lead decides).

## Files touched
lifeImage/lifeimage/two_pass_diag.py, lifeImage/tests/test_two_pass_diag.py, lifeImage/data/gold/two_pass_diagnosis.md, progress/lifeimage-two-pass-diag.md

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_two_pass_diag.py
