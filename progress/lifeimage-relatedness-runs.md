Status: ACTIVE 2026-11-25 (lead orchestration)

## Goal and acceptance
Answer all 92 relatedness.v1 batches (var0 and var1, parts 0-45; 4,536 cards) with lifeimage-runner agents, three batches
per runner, then ingest as the layout sim's 'judged' source, check the pre-registered predictions in
data/gold/layout_sim_predictions.md (controls >= random + 3 points; order bias within 1 point), rerun the sim and the blinded
adjacency check (prediction: >= 55% for the sim, coverage > 60%).

## Done
Wave 1 launched: var0 parts 0-29.

## Next
Wave 2: var0 parts 30-45, var1 parts 0-13. Wave 3: var1 parts 14-45. Progress marker is the answers file itself: a batch is
done when data/batches/relatedness.v1.varV.partN.answers.jsonl exists and validates.

## Resume
Missing answers: cd lifeImage && for f in data/batches/relatedness.v1.var*.part*.jsonl; do case $f in *answers*) ;; *) [ -f ${f%.jsonl}.answers.jsonl ] || echo $f;; esac; done
Key: moved to data/ephemeral/relatedness.v1.key.json (out of the runners' reach); tools/relatedness.py ingest reads it from
data/batches/, so copy it back just before ingesting.
