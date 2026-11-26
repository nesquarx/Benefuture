# lifeimage-seriation (DONE)
Goal (LI.60): circular seriation of the 247 coarse fields as a comparison arm (C) against the shipped order (A) and the force sim (B).
Cost = -combined similarity of circularly adjacent fields + lambda * angular displacement of the field's slot from its axes-prior angle;
guard = LI.25/LI.58 `layout_sim.shift_max`; sectors split <= shipped; deterministic; heuristic = greedy starts + 2-opt + Or-opt + rotations.
Acceptance: `cd lifeImage && python3 -m pytest -q` green; predictions pre-registered (data/gold/layout_sim_predictions.md, "Seriation arm")
before measuring; verdicts recorded; blinded adjacency batches A vs C built (not run); review sheet `--seriation`.

## Decisions
- Slots: the shipped order's tiled slice centres; a field at position p has angle slot[p]; displacement = circ_diff(slot[p], axes prior).
- lambda and guard fixed a priori (governed.py), not tuned on the metrics; a lambda sweep is reported as sensitivity only.
- Named outliers: explicit id sets in lifeimage/seriation.py (arts/religion vs mathematics/statistics; housing vs agriculture fields).
- Batches: data/batches/seriation/adjacency.v1.* (existing A-vs-B batches in data/batches/ untouched); key in data/ephemeral/seriation/.

## Done
- Predictions pre-registered (data/gold/layout_sim_predictions.md "Seriation arm") before the data run; results and verdicts appended there.
- lifeimage/seriation.py (price/cost/improve/greedy/kick/seriate, context, run_arm, compute), governed `layout_sim.seriation_*` (4), tests/test_seriation.py (15, green),
  tools/seriation.py (JSON + batches + key), tools/render_coarse_review.py `--seriation`, review sheet PNG+SVG.
- Found and fixed on the way: guard penalty vanished at lambda 0 (cost = lambda x D); now a separate cost matrix `price`.
- Results: C mean sim 2.243 (6.7x A 0.337; B 0.352), no-signal 0.093 (A 0.729), rank dist 34.1 (A 33.0, not met), outliers removed,
  tiled shift 28.7/79.7/122.8 (mean<=25 and p95<=60 not met), sectors split 16, extra runs 97. lambda x4 would meet stability (20.0/53.6/98), offered not adopted.
- Batches: lifeImage/data/batches/seriation/adjacency.v1.var{0,1}.part{0..4}.jsonl (494 tasks); key lifeImage/data/ephemeral/seriation/adjacency.v1.key.json. NOT run.
- Suite: 1235 passed, 6 failed, all in tests/test_eventgen_* (the concurrent eventgen agent's files), none in seriation/layout.
## In progress
none
## Next (lead)
run the batches, report with `adjacency_report` using the key (A = shipped, B = seriation in key labels); decide lambda x4.
## Files touched
lifeImage/lifeimage/seriation.py, lifeImage/lifeimage/governed.py (4 entries), lifeImage/tests/test_seriation.py, lifeImage/tools/seriation.py,
lifeImage/tools/render_coarse_review.py, lifeImage/data/coarse/seriation_v0.json, lifeImage/data/images/review/coarse_layout_seriation.{png,svg},
lifeImage/data/gold/layout_sim_predictions.md, progress/lifeimage-seriation.md
## Resume
`cd lifeImage && python3 -m pytest -q tests/test_seriation.py && python3 tools/seriation.py` (about 2 min)
