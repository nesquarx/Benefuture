Status: DONE 2026-11-25 (lead to review; hold-out and named-outlier predictions not met, see predictions file Results)

## Goal and acceptance
LI.55 + LI.58: polar force simulation for coarse placement (loose angular spring, strict radial spring, settle without
collision then collide; reusable `update_layout`). Pre-registered predictions in lifeImage/data/gold/layout_sim_predictions.md
(plus dated addenda) committed before measuring; outputs data/coarse/layout_sim_v0.json, review sheet
data/images/review/coarse_layout_sim.{svg,png}, movers list, blinded adjacency batches (prompt adjacency.v1).

## Decisions
- Sectors are derived (circular mean of their fields), not independent nodes. Radius is a diagnostic state, build keeps judged bands.
- Disclosure: a test fixture ran the real data before the predictions file existed; first result (k_polar 0.3): adjacent mean
  similarity 0.180 after vs 0.188 before (build order). Predictions file records this honestly. Sweep (circular metric,
  unit widths): k_polar 0.3 -> 0.184, 0.1 -> 0.248, 0.03 -> 0.18 (raw-angle prior 0.142): optimiser is noisy/local-minima.
- Planted test uses clusters 60 deg apart with axes noise sd 30 (identical centres cannot be separated by attraction).

## Done
tests/test_layout_sim.py green (24); layout_sim.py implemented; governed entries (LI.58 stiffness: k_polar weak, k_radial strict).

## In progress / next
adjacency.py (stub still), prompts/adjacency.v1.md, tasks type + validate hook, predictions file + commit, real run,
tools/layout_sim.py, review sheet option, batches, full suite, push.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_layout_sim.py tests/test_adjacency.py

## Final state
All items done: adjacency.py + prompt + validate hook, predictions + results, tools/layout_sim.py, review sheet option, batches
(data/batches/adjacency.v1.*, gitignored), governed S2 defaults (k_polar 0.1). Full suite: 1171 pass; test_fine_gap failure belongs to the fine agent.
