Status: DONE 2026-11-25

## Goal and acceptance
LI.19, LI.54, LI.56, LI.57. A: ICATUS anchors out of shipped files. B: gap fine candidates and parent batches (set 'gap').

## Done
A: lifeimage/fine/calibration.py, tests/test_calibration.py, data/calibration/ gitignored (75 cards moved; no code reads them; anchors are not in any hashed input).
B: lifeimage/fine/gap.py; tools/fine_gap_fetch.py, tools/fine_pool.py --gap-only, fine_build_batches --set gap, fine_apply SETS gap;
data/fine/sources/{wikidata,getty_aat,doid,mondo,onet,eurovoc,lcsh,bls_cex}.jsonl; candidates_gap_v0.jsonl (717), gap_pool_report.json;
30 batches data/batches/fine_parent.v1.gap.var{0,1}.part{0..14}.jsonl (gitignored; rebuild with tools/fine_build_batches.py --set gap).
Full suite 1183 passed, 1 xfailed.

## Open
NIBRS blocked (fbi.gov HTML block page); R-COICOP page not located; Q260607 root and 10 throttled Wikidata roots not fetched
(rerun: python3 tools/fine_gap_fetch.py --only wikidata; slow, the API throttles). weather_climate_adaptation has no candidate.
Runner pass on the gap batches pending (lead).
