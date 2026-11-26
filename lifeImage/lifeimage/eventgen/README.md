# eventgen: life-course event generator (increment 1)

A generator of synthetic life events driven by a calibration table of published aggregates, and the first head (rates) of its
verifier (`data/events/EVENT_SOURCE_SCOUT.md` section 6). Increment 1 is a probe: family formation and schooling only.

Run the probe alone: `cd lifeImage && python3 -m lifeimage.eventgen.probe` (about 2 s for 500 people x 3 regions plus the rate head).
Tests: `python3 -m pytest -q tests/test_eventgen_calibration.py tests/test_eventgen_probe.py`.
Rebuild the table: `python3 tools/eventgen_fetch.py` (downloads to a temporary directory; only aggregates are written).

## Parts
- `calibration.py`: `Param` (quantity, value, unit, age band, sex, region, year, source id and URL, licence class, confidence, notes,
  `source_statement` with locator and retrieval date, `event_snippets`, `snippet_missing`), `Table` (validation, duplicate keys fail,
  `lookup` falls back country -> World Bank region -> world and sex -> all, each substitution a loud `degraded` entry, one warning per kind).
  Table: `data/events/calibration/aggregates_v1.jsonl` (aggregates only; real microdata never enters the repository), `regions.json`
  (country -> World Bank region), `public_figures.txt` (the only names an event snippet may carry).
- `world.py`: per-person state machine (birth, preschool, primary, secondary, tertiary with completion or dropout; first marriage;
  births of women by age band). Every gate derives from the table's cohort shares (`derive_setup`, nested: a level cannot exceed the one
  before, clips recorded loudly). One random stream per (seed, region, mechanism) and a fixed number of draws per person, so a noise
  parameter moves only its own mechanism and arms share seeds.
- `events.py`: event kinds and rows in the library's contract format over existing coarse domains (fine only where unambiguous), validated by `validate_row`.
- `rates.py`: the rate head. Per Param: effect, Student-t-inflated standard error across paired seeds, calibration uncertainty by confidence,
  verdict pass (equivalent within the margin), fail (z >= 2 and beyond the margin) or inconclusive; seeds are added until every verdict is decided (cap 60).
- `governed.py`: governed thresholds and noise parameters (merged into `lifeimage.governed.GOVERNED`).

## Governed thresholds and noise parameters introduced
Thresholds: `eventgen.rate_z` 2, `rate_margin_rel` 0.10, `margin_floor.*` (per1000 1, pct 1, years 0.25, births_per_woman 0.05, ratio 1),
`cal_se_rel.{high,medium,low}` 0.02/0.05/0.10, `min_seeds` 8, `max_seeds` 60, `horizon_age` 50, `lower_secondary_years` 3, `tertiary_years` 4,
`partnership_ever_share` 0.9 (assumption, unchecked).
Noise (own stream, range): `noise.fertility_frailty_sd` 0.1 [0, 0.5], `noise.marriage_age_sd` 4 [2, 7], `noise.school_entry_delay_p` 0.15 [0, 0.4].
Defaults sit at the mild end of each range. Sources and reasons are in `governed.py`.

## Parsimony
Existing mechanisms do not generate event sequences from rates: `generators/life.py` draws archetype-driven lives from `params.py` figures
without regional strata, and nothing compares a generated population with published rates. Added: the stratified calibration table with
provenance and event snippets, a gate-per-level state machine with degrade-loudly lookup, and the rate head. The `Param` here extends the
`params.py` form (default, source, confidence) with strata and snippets; once the generator replaces `params.py` figures, that file's family
and schooling entries are candidates for removal. Region codes reuse World Bank regions; `validate_row` and the coarse seed ids are reused, not copied.

## Gaming and limits
A generator can satisfy the rate head while producing unrealistic sequences: rates are marginal. Here births ignore marital state, marriage has no spouse,
school levels ignore age at birth of children, and nothing prevents a birth at 15 after a degree at 14. The sequence head (ages at first events, spells,
order and hard constraints against panels and event histories) is the next increment for that reason. The head also cannot tell a correct generator from
one that reads the table's own value; it verifies wiring and sampling, not the realism of the table. Period rates of one year are applied to all ages
(no cohort change); deaths, partners, fatherhood and upper-secondary completion are not modelled. Clipped nested shares and region/world substitutions
mean some strata are not calibrated to their own place.
Event snippets are paraphrases of what each indicator or activity code counts (definition-derived), not real cases; real case vignettes, time-use diary
examples (ATUS and HETUS pages were not fetchable: BLS returned 403) and public-figure biographies remain to be added.
