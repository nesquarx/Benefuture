# Life Image: gap fine_parent runs (lead)
Status: DONE (2026-11-25); downstream regeneration continues in progress/lifeimage-fine-regen.md

Goal: answer the 30 `fine_parent.v1.gap` batches (15 parts x 2 variants) with lifeimage-runner agents, then merge with
`python3 lifeImage/tools/fine_apply.py` (set `gap` is in SETS) and review coverage.

Prediction (before answers): at least 70 of the 95 childless fields gain one or more accepted fine children; Wikidata
candidates rejected more often than curated sources (LCSH/AAT/DOID) because the fetch was noisy. Confidence 0.6.

Done: var0 part0-14 and var1 part0-4 launched. Next: var1 part5-14 as runner slots free; then fine_apply; commit answers.
Resume: answers land at `lifeImage/data/batches/fine_parent.v1.gap.var{v}.part{n}.answers.jsonl`; relaunch any missing one.

## Result (2026-11-25)
30/30 batches answered and validated. `fine_apply.py --k 2` (base answers exist for variants 0-1 only; var2 batches were
never run). Fine cards 786 -> 1503. Fields without a main-parent fine child: 105 -> 9; of the 95 targeted, 92 gained one
(prediction >= 70: met). Still childless: medication_adherence, parenting_adolescents, weather_climate_adaptation (targeted),
cybersecurity, environmental_harm, hospitality_hosting, reproduction_fertility, self_provisioning, therapy_social_work (not
targeted; they have fine children only as secondary parents). Prediction that Wikidata is rejected more than curated
sources: not met, and ill-posed (fine_parent has no reject verdict; every candidate is placed). Placed on its target
field: Wikidata 0.73, BLS CE 0.71, EuroVoc 0.67, LCSH 0.58, O*NET 0.33, Getty 0.27, MONDO 0.14, DOID 0.00 (disease terms
go to the health fields). Escalations 8.4% overall (gap set 63/717 = 8.8%), above the 5% limit as before (8.1%).
fine_v1 rebuilt by tools/build_radius.py (seed_v3 unchanged). Six downstream tests red: derived files to regenerate.
