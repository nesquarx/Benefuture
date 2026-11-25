# Life Image: gap fine_parent runs (lead)
Status: ACTIVE (2026-11-25)

Goal: answer the 30 `fine_parent.v1.gap` batches (15 parts x 2 variants) with lifeimage-runner agents, then merge with
`python3 lifeImage/tools/fine_apply.py` (set `gap` is in SETS) and review coverage.

Prediction (before answers): at least 70 of the 95 childless fields gain one or more accepted fine children; Wikidata
candidates rejected more often than curated sources (LCSH/AAT/DOID) because the fetch was noisy. Confidence 0.6.

Done: var0 part0-14 and var1 part0-4 launched. Next: var1 part5-14 as runner slots free; then fine_apply; commit answers.
Resume: answers land at `lifeImage/data/batches/fine_parent.v1.gap.var{v}.part{n}.answers.jsonl`; relaunch any missing one.
