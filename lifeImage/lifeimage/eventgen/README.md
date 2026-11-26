# eventgen: life-course event generator (increments 1-2)

A generator of synthetic life events driven by a calibration table of published aggregates, and the first two heads (rates, sequence) of
its verifier (`data/events/EVENT_SOURCE_SCOUT.md` section 6). A probe: family formation, schooling, partners, fatherhood, divorce and deaths.
Increment 2 makes every event relational (LI.65) and adds the sequence head.

Run the probe alone: `cd lifeImage && python3 -m lifeimage.eventgen.probe` (about 4 s for the 500 people x 3 regions world with its relational
events, about 25 s with both heads and both counterexamples).
Tests: `python3 -m pytest -q tests/test_eventgen_calibration.py tests/test_eventgen_probe.py tests/test_eventgen_relational.py tests/test_eventgen_sequence.py`.
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
- `relational.py` (increment 2, LI.65): `World.events()` gives every person's events as bundles of layer A (four memberships, outcome memberships with a
  counterfactual naming the model, `model:eventgen:<quantity>@<region>`), layer B (participant records in the library's participation format, one per
  entity: person, spouse, mother, child, parent, school, health service, civil registry, family court; responsibility by freedom from contribution and
  option set, a missing option set takes the governed default and is logged as degraded; impact per affected party; acting_for, under_agreement,
  informed), layer D links (`part_of`: birth in its pregnancy episode, divorce in its marriage span; `causes`: level completed to next level started,
  marriage to a first birth within two years where the model raises the birth hazard on marriage; `concurrent`: dropout and marriage, never `causes`,
  since no source here supports the causal reading; `re_description` is validated but not generated) and the LI.42 metadata (valid and record time,
  place, span). Reuses `validate_row`, `validate_participation_answer` v2, `responsibility_from_freedom`, `LINK_TYPES`, `validate_entity`.
  Calibration event snippets carry the relational form (`relational_form`; free text kept; `tools/eventgen_relationalise.py` adds it in place).
- `sequence.py` (increment 2): the sequence head over the relational events only. Hard checks at zero tolerance (no event after death or before birth, a
  divorce linked part_of a prior marriage, no birth or pregnancy before the minimum maternal age, schooling levels in order, causes precede effects and
  parts lie inside wholes, parenthood by sex, one death); soft statistics (mean and median age at first marriage, its IQR, mean age at childbearing, median
  age at primary completion, share married by 18, share of first births before first marriage) judged by `rates.judge` with the significance rule over
  paired seeds. A target comes from a Param of the region's own stratum or is left unjudged and recorded loudly. `describe` reports median and IQR of first
  events without judging. `variants.py`: the shuffled-order generator and births-ignoring-marriage, for counterexamples.
- `governed.py`: governed thresholds and noise parameters (merged into `lifeimage.governed.GOVERNED`).

## Governed thresholds and noise parameters introduced
Increment 2 adds thresholds `min_maternal_age` 15, `minor_age` 18, `pregnancy_years` 0.75, `mortality_gompertz_slope` 0.09, `divorce_share_default` 0.10,
`divorce_mean_duration` 8, `premarital_first_birth_share` 0.15 with `premarital_rare_below_smam` 25 and `premarital_margin` 0.15, `seq_margin_years` 1,
`seq_margin_prop` 0.05, `concurrent_window_years` 1, `marriage_birth_link_years` 2; noise `noise.nonmarital_birth_relative_hazard` 0.1 [0.05, 1] and
`noise.spouse_age_gap_sd` 3 [2, 5]. Sources in `governed.py`.

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

## Increment 2: partners, fatherhood, deaths, order
- Deaths: piecewise-constant hazards from infant and under-five mortality (WDI) and 40q0 by sex (WPP), a Gompertz rise 40-50 (own stream). The rate head
  now reads shares and marriage age among survivors to the horizon and births per woman-year lived (death is independent, so this is unbiased), and
  checks 40q0 by sex.
- Births depend on marital state with the marginal ASFR preserved (married hazard ASFR / (M(a) + r (1 - M(a))), unmarried r times that, r =
  `noise.nonmarital_birth_relative_hazard`). Births now depend on the marriage-age spread (the increment-1 independence test was amended). A married man
  fathers his spouse's births at her age (spouse age gap from the male minus female marriage-age Params). Divorce share from the Eurostat Param (DEU) or a
  governed default logged as degraded.
- Measured (seeds 1-16, 500 people per region unless stated): the true generator has zero hard violations on every seed; the rate head passes all 72
  statistics. The shuffled-order generator (ages of each event kind permuted among people of one region and sex) passes the rate head (0 fail) and fails
  the sequence head on 60 of 60 seeds (also at 40 people per region), by event after death, divorce without prior marriage, schooling out of order and
  links violating time. The births-ignoring-marriage generator has no hard violation and fails the premarital-first-birth share (KEN, IND) at z of 11 to 18.
- Known soft flag: the share of women married by 18 in India is 17% generated against 22% in the table (z of -4): the normal marriage-age spread (sd 4,
  assumed) is too narrow for the early-marriage tail. A model limitation the head found; not tuned away.
- Gaps: the premarital first-birth target is an assumption (no Param; OECD SF2.4 or DHS needed) judged only where women marry before 25; record time equals
  valid time (no registration lag noise yet); spouse death, remarriage and children as people are not modelled; option sets are modelled only as a free
  adult act or missing (minor dropout and marriage, the other party of a divorce); event impacts are prototype integers. Light mode (`events(light=True)`)
  skips participants and rows for the sequence head's speed; full mode validates every event and every row (schema checks run once per distinct row
  structure, `validate_row_cached`; tests also run the strict check on a sample).

## Gaming and limits
A generator can satisfy the rate head while producing unrealistic sequences: rates are marginal. Increment 2 demonstrates it (the shuffled-order generator
passes the rate head) and the sequence head closes the gap for order and ages at first events; spells and comparison with panels or event histories remain.
Both heads also cannot tell a correct generator from one that reads the table's own value: they verify wiring and sampling, not the realism of the table.
A generator that emits no links passes the link checks vacuously, so the hard rules that read kinds and times (death, schooling order, divorce needing a
linked prior marriage) do not depend on links being present; a divorce emitted without its part_of link fails by design. Gaming of the responsibility
default: no generated participant is assigned full freedom when its option set is missing (the governed 0.5 applies and is logged), so a generator cannot
raise responsibility by omitting option sets. Period rates of one year are applied to all ages (no cohort change); upper-secondary completion, spouse
death and migration are not modelled. Clipped nested shares and region/world substitutions mean some strata are not calibrated to their own place.
Parsimony (increment 2): deaths, spouse, divorce and marital-state births are the minimum for the sequence rules to be non-vacuous; the participation
format, responsibility rule, link vocabulary, entity schema and row validator are the library's, reused. Introduced and candidates for removal once the
generator learns from real event histories: the piecewise mortality model (replaceable by WPP life tables), the pregnancy episode, and the assumed
premarital-birth target.
Event snippets are paraphrases of what each indicator or activity code counts (definition-derived), not real cases; real case vignettes, time-use diary
examples (ATUS and HETUS pages were not fetchable: BLS returned 403) and public-figure biographies remain to be added.
