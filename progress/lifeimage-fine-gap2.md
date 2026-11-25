Status: IN PROGRESS 2026-11-25

## Goal and acceptance
Second gap candidate set `gap2` for nine coarse fields with no fine child (cybersecurity, environmental_harm, hospitality_hosting,
reproduction_fertility, self_provisioning, therapy_social_work, medication_adherence, parenting_adolescents, weather_climate_adaptation).
8-20 candidates per field from verified sources (LI.56/57 licences); exclude ids/labels in fine_v0 and earlier sets; build batches (2 variants,
<=50 cards each), do NOT run them. Test: gap2 covers all nine fields, duplicates no existing fine id. `cd lifeImage && python3 -m pytest -q` green.
Prediction (lead): all nine >= 8; < 200 candidates; <= 6 batch files; confidence 0.6.

## Decisions
- Do not touch the `gap` set, data/fine/sources/*.jsonl, or the gap answers. gap2 sources go to data/fine/sources/gap2/<name>.jsonl.
- New module lifeimage/fine/gap2.py (roots per field; reuses gap.py fetchers), tools/fine_gap2_fetch.py, fine_pool.py --gap2-only,
  fine_build_batches --set gap2, fine_apply SETS gains gap2.

## Done
(nothing yet)

## Next
roots -> fetch -> pool -> batches -> test -> commit.

## Files touched
progress/lifeimage-fine-gap2.md
