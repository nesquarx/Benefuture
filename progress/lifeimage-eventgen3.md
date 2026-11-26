# lifeimage-eventgen3 (Life Image eventgen increment 3: breadth across the circle)

Status: IN PROGRESS

## Goal and acceptance checks
1 domain state machines (work and careers, health and care, time use, leisure and sport, social and civic, harms), each a probe first;
2 fixes (marriage-age early tail, sourced premarital-first-birth target, registration-lag noise);
3 every event relational and valid; new roles (employer, clinic, club, polling authority, victim, offender);
4 coverage report `data/events/coverage_v1.json` (fields reached, pair co-membership at a stated sample), red test first (< 20% reached on current generator).
Acceptance: `cd lifeImage && python3 -m pytest -q` green (rerun end to end after the last change); probe one command; coverage report written.

## Predictions (lead, confidence 0.5; recorded before measuring)
(a) >= 60% of 247 coarse fields get generated events at 2,000 people x 3 regions; (b) every event passes the relational validator; (c) full probe with both heads < 60 s;
(d) India married-by-18 passes after the tail change; (e) >= 10 time-use short-term action kinds with calibration.

## Decisions
- Reachable sources (probed 2026-11-26): World Bank API, Eurostat dissemination API (HETUS tus_00*, hlth_*, ilc_*), WHO GHO OData, ILOSTAT rplumber CSV API. BLS 403, ilostat.ilo.org page 403 (rplumber ok).

## Done (WIP)
- coverage.py (red baseline 18/247 = 7.3% fields, 25 of 30381 pairs; at 2000 x 3). Breadth now ~59-65% fields.
- catalog.py (82 kinds: 38 time-use, work, health, civic, leisure, harm, adoption), domains.py (machines, derive, statistics, targets), marriage.py (early-tail mixture),
  tools/eventgen_fetch_domains.py -> data/events/calibration/aggregates_v2_domains.jsonl (2065 Params), relational/world/rates/sequence integration, governed entries.
- Fixes: marriage-age mixture (IND married-by-18 0.228 vs 0.223 after), births-outside-marriage (Eurostat demo_fagec) replaces assumed premarital share, registration lag.

## In progress
tests (red-first file tests/test_eventgen_breadth.py), amend old tests, probe, README, coverage_v1.json

## Next
see In progress

## Files touched
progress/lifeimage-eventgen3.md; lifeImage/lifeimage/eventgen/{catalog,domains,marriage,coverage}.py (new) and {world,relational,rates,sequence,events,governed}.py; lifeImage/tools/eventgen_fetch_domains.py; lifeImage/data/events/calibration/aggregates_v2_domains.jsonl

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_eventgen_*.py && python3 -m lifeimage.eventgen.probe

## Design notes (2026-11-26)
- Baseline coverage (increment-2 kinds): 18/247 fields (7.3%), 25/30381 pairs at 2000 x 3 (coverage.py written; red).
- Sources reachable: HETUS tus_00age (DE + 21 countries, 2000/2010), India TUS 2019 PDF (MoSPI, parsed by pdftotext), Eurostat hlth_silc_20, ilc_ats18, ilc_scp03/19, hlth_ehis_am1e/pe3e, lfsa_egad, une_ltu_a, crim_off_cat, crim_just_sex, demo_fagec, OWID voter turnout (V-Dem), WB diabetes/HIV/TB. Religious attendance: no retrievable aggregate (governed default, degraded).
- ECS stratum = unweighted mean of the Eurostat countries (documented); DEU direct. FRA stays absent from the table (probe demonstration).
- New Param file: data/events/calibration/aggregates_v2_domains.jsonl built by tools/eventgen_fetch_domains.py.
