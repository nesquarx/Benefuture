Status: PAUSED 2026-11-25 (agent stopped at the usage limit; WIP committed by the lead, unreviewed)

## Goal and acceptance
LI.55, LI.58: polar force simulation for coarse placement. Loose angular spring to the axes (or prior layout), strict
radial spring; phase 1 without collision, phase 2 with collision for tessellation; attraction along overlap and upstream
links, co-membership (support floor), shared fine children, TF-IDF nearness. Reusable function (cards, signals, prior,
governed weights) -> layout + diagnostics. Pre-registered predictions in data/gold/layout_sim_predictions.md (plus addendum
for LI.58 settings) committed before measuring. Outputs: data/coarse/layout_sim_v0.json, review sheet
data/images/review/coarse_layout_sim.{svg,png}, movers list, blinded adjacency batches (prompt adjacency.v1) for the runner.
Tests: planted clusters reunited within a shift bound; zero attraction returns the prior order; determinism; tiles.

## Done (from the working tree at pause; not verified by the lead)
lifeimage/layout_sim.py, lifeimage/adjacency.py, tests/test_layout_sim.py, tests/test_adjacency.py, edits to governed.py.

## Next
Check tests; predictions file; run on real data; review sheet; batches; full suite.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_layout_sim.py tests/test_adjacency.py
