Status: DONE 2026-11-25 (batches built, no runner run; answers pending)

## Goal and acceptance
Pairwise relatedness judging (relatedness.v1) to grow the layout sim's pairwise signal where missing (signal covers 1127 of
30381 field pairs; LI.55, LI.58). One card per field pair (both fields: label, description, up to 5 fine-children labels), 0-10
scale, 3 fixed calibration examples in the prefix, 2 variants (canonical id order, reversed), batches of <= 50 in data/batches/.
Pairs: (a) within 2 positions in axes or sim layout with no signal; (b) within 5 positions, no signal, cap ~2500 total with
(a); (c) 150 strong-signal controls + 150 random far-apart pairs. Loader -> signal (mean of variants /10, variant agreement as
confidence); layout_sim optional source 'judged' (governed weight, floor), degrade loudly when absent.
Prediction (stated before any run): controls with signal score >= 3 points higher than random far pairs on average, confidence 0.8.
Baseline (current code, real data): signal covers 11.9% of pairs within 2 positions in the axes order, 14.8% in the sim order.

## Decisions
- Answers ingested to data/answers/relatedness.jsonl (self-describing rows: pair, variant, verdict, first); pair list with kinds
  in data/coarse/relatedness_pairs_v1.json; key with task->pair stays in data/batches (gitignored).

## Done
tests/test_relatedness.py (11, green; red first at import), lifeimage/relatedness.py, prompts/relatedness.v1.md, tasks.py + validate.py hooks,
layout_sim 'judged' source (governed w_judged 0.75, judged_floor 0.3; degrades loudly when absent), tools/relatedness.py (build, ingest),
batches (2,268 pairs: 828 near, 1,140 wide (all available, cap 2,500 not reached), 150 control, 150 random; 92 files, gitignored),
data/coarse/relatedness_pairs_v1.json, prediction 3 in data/gold/layout_sim_predictions.md, LI.59 in BACKPROPAGATION.md.
Full suite: 1161 pass (+1 xfail) excluding tests/test_fine_gap.py; its failure belongs to the fine agent.

## In progress / next
Runner answers (lead): then `python3 tools/relatedness.py ingest`, check calibration gap >= 3, rerun tools/layout_sim.py, rerun adjacency judge.

## Files touched
lifeimage/{relatedness,layout_sim,governed,tasks,validate}.py, prompts/relatedness.v1.md, tools/relatedness.py, tests/{test_relatedness,test_layout_sim}.py,
data/coarse/relatedness_pairs_v1.json, data/gold/layout_sim_predictions.md, BACKPROPAGATION.md, this note.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_relatedness.py
