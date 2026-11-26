# eventgen: life-course event generator (increments 1-3)

A generator of synthetic life events driven by a calibration table of published aggregates, and the first two heads (rates, sequence) of
its verifier (`data/events/EVENT_SOURCE_SCOUT.md` section 6). A probe: family formation, schooling, partners, fatherhood, divorce and deaths.
Increment 2 makes every event relational (LI.65) and adds the sequence head. Increment 3 adds breadth across the circle (work, health, time use, leisure, civic life, harms).

Run the probe alone: `cd lifeImage && python3 -m lifeimage.eventgen.probe` (about 6 s: the small world, 3 seeds per head: the relational events, the rate head, the domain
head, the sequence head, four counterexamples and the coverage; `--full` runs the larger world with both heads at precision-rule seeds, about 35 s). Coverage report: `python3 -m lifeimage.eventgen.coverage` (writes `data/events/coverage_v1.json`).
Tests are tiered like the parent repository's CI: the default (`pytest -q`) is the fast tier, the heavy tests (large worlds, many seeds) carry `@pytest.mark.full` and run with `python3 -m pytest -q -m full` (heavy alone) or `BF_TIER=full python3 -m pytest -q` (everything). Every mechanism keeps a fast probe test (`test_the_default_probe_runs_in_seconds_and_exercises_every_mechanism_once` and the small unit tests); a full-tier test moves tier, it loses no check. `tests/test_eventgen_speed.py` holds the outputs fixed on fixed seeds (golden fingerprint). Eventgen tests: `python3 -m pytest -q tests/test_eventgen_calibration.py tests/test_eventgen_probe.py tests/test_eventgen_relational.py tests/test_eventgen_sequence.py tests/test_eventgen_breadth.py`.
Rebuild the tables: `python3 tools/eventgen_fetch.py` (v1: schooling, family, WDI, WPP, ILOSTAT) and `python3 tools/eventgen_fetch_domains.py` (v2: Eurostat, India's time-use
survey, WDI, V-Dem, WHO; needs `pdftotext`); both download to a temporary directory and write only aggregates.

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


## Increment 3: breadth across the circle
The placement clean-up (LI.60) scores each coarse field's layout neighbours against event co-membership, so a field no generated event touches cannot be scored.
Increments 1-2 touched 18 of the 247 coarse fields (7.3%, 25 of 30381 field pairs at 2000 people x 3 regions). Increment 3 adds 83 event kinds in `catalog.py`
(the single source of each kind's memberships, participants, statement and counterfactual), generated by `domains.py` from the new Params
(`aggregates_v2_domains.jsonl`, 2065 aggregates: Eurostat HETUS diaries, EU-SILC, EHIS, LFS and crime tables, India's national time-use survey 2019, WDI, V-Dem via
Our World in Data, one WHO fact-sheet statistic). Coverage at 2000 x 3: 162 of 247 fields (65.6%), 639 field pairs co-occur in an event (2.1%: events are
narrow, so most pairs never share one; composite events are the next step); `coverage.py` writes the counts per field and pair.

Machines (each a probe in `probe.py`/`tests/test_eventgen_breadth.py` before it entered the iterated ecosystem; per-person streams per mechanism):
- Work and careers: labour-force participation by age and sex is a nested threshold on the ILOSTAT curve (the share in the labour force at every age is the Param;
  entries and exits are ordered). First entry (industry, services, farm or self-employment from the WDI sector shares; the employer is an entity per job), a first
  spell of job search with probability U, job changes (hazard from the share of employed with tenure under a year), unemployment spells (onset from the
  unemployment rate and a mean duration from the long-term share: the stationary rate is the Param), retirement (the first exit after the governed minimum age).
- Health and care: measles vaccination at one; diabetes, HIV and disability onset as nested thresholds on prevalence curves; tuberculosis incidence; in survey reference
  years doctor visits and informal caring; contraception at marriage (WDI prevalence).
- Time use: `diary_days` per person, ages stratified over the five HETUS bands; each activity (38) by participation and minutes per participant by age and sex;
  a participant's minutes are lognormal around the Param's mean (`noise.time_use_minutes_sd`). A day at work needs a job (the diary's employment is tied to the
  career) and the journey to work follows a day at work.
- Leisure, sport, social and civic life: in `occasion_years` survey reference years per person (cinema, live performance, cultural site, sports event, aerobic
  activity, strength training, cycling, formal and informal volunteering, active citizenship, voting at turnout / election cycle, religious attendance).
- Harms (negative record): victimisation by offence class (police-recorded rate per inhabitant over ages 10-70), sexual violence with a governed female share, partner
  violence (WDI 12-month prevalence, persistence assumption), suspected offences by sex with an age-crime shape and their victim, convictions (conviction/suspect ratio).
- Adoption events (migration, bank account, mobile subscription, internet use), vocational training: one share each from existing WDI/UIS Params, a truncated-normal age.

New entity roles follow the participation format: employer, employment service, clinic, club, polling authority, venue, shop, transit operator, bank, telecom,
immigration authority, police, criminal court; persons: victim, offender (the spouse for partner violence), neighbour, friend, customer, care recipient, dependant.
Responsibility follows freedom with the option sets the domain gives (employer: retain the worker, harm 2; offender: refrain, harm 0; clinic: withhold, harm 1-2);
a minor's work, civic or harm act and the kinds with no option set take the governed default and are logged as degraded.

Fixes of increment 2: (1) marriage age is a mixture with an early component (`marriage.py`) whose weight is solved from the stratum's own WDI share married by 18, the
main component's location keeping the mean at the singulate mean; India's generated share is 22.8% against 22.3% (it was 16.8%); without that Param it is the single normal,
loudly. (2) The assumed premarital-first-birth share is gone: OECD SF2.4 and DHS STATcompiler had no retrievable indicator, Eurostat `demo_fagec` gives live births by the
mother's legal marital status. The births-outside-marriage share (DEU, ECS) is the sourced target; the relative hazard of unmarried women is solved per region from it where it
exists (FRA 0.32), else the noise default; the share of first births before marriage has no source and is reported only. (3) Record time follows valid time by a lognormal
registration lag (civil events median 7 days, others 30, sigma 1) on a deterministic function of (seed, person, kind, age): lags move record times only.

Heads: the rate head takes `domains=True|False|"only"`; the domain head is the rate head over the domain statistics (time-use participation by band and minutes, group-level
India rates, labour-force participation, unemployment, annual participation, vaccination, disability, HIV, TB, harm rates, adoption). Cells below 10% (annual: 20%) are pooled
across age bands: a seed's sample cannot decide them. The sequence head gains hard rules for the domains (work before the minimum age, retirement without work or before the
minimum age, reemployment without a job loss, a job loss inside a spell, a day at work outside employment, an offence before the minimum age, a conviction without suspicion,
partner violence outside a union, record before valid time) and the births-outside-marriage soft statistic.

### Governed thresholds and noise parameters introduced
Thresholds: `eventgen.life_horizon_age` 70, `min_working_age` 15, `min_offending_age` 14, `retirement_min_age` 45, `unemployment_spell_default_years` 0.5,
`job_change_default` 0.08, `diary_days` 4, `occasion_years` 3, `election_cycle_years` 4, `voting_age` 18, `religious_attendance_default` 0.30,
`sexual_violence_female_share` 0.85, `offending_peak_age` 18, `offending_decay_per_year` 0.08, `conviction_delay_years` 1, `diabetes_gradient_age` 55,
`diabetes_gradient_sd` 12, `hiv_onset_mean` 28, `hiv_onset_sd` 7, `partner_violence_persistence` 0.5, `time_ratio_cap` 20, `margin_floor.minutes` 5, `margin_floor.per100k` 5.
Removed: `premarital_first_birth_share`, `premarital_rare_below_smam`, `premarital_margin`. Noise (own stream, range): `noise.time_use_minutes_sd` 0.5 [0.3, 0.8],
`noise.registration_lag_civil_days` 7 [0, 60], `noise.registration_lag_other_days` 30 [0, 180], `noise.registration_lag_sigma` 1 [0.5, 2],
`noise.marriage_early_mean` 16.5 [15.5, 17.5], `noise.marriage_early_sd` 1.5 [1, 2]. Sources and reasons are in `governed.py`.

### Parsimony (increment 3)
Native mechanisms reused: the marginal-preserving state dependence of increment 2 (births outside marriage solve the existing relative hazard), nested thresholds for stocks
(one latent draw per person gives the marginal at every age and ordered entries), the participation format, responsibility rule, link vocabulary and entity schema.
Introduced, each a candidate for removal once the generator learns from event histories: the labour-force curve interpolation, the persistence latent of partner violence,
the age-crime shape, the diary-day and reference-year sampling designs, the adoption ages, the India group rescaling of the European activity profile.

### Gaming and limits (increment 3)
How each mechanism can satisfy its checks while being unrealistic:
- Participation and minutes are marginals: days at work could fall on people without a job. `variants.career_blind` does exactly that (permutes days at work among diary days of
  one region, sex and band): the domain head passes it, the sequence head fails it (`work_day_outside_employment`); the generator ties the diary to the career for that reason.
  Study, childcare and the other activities are still independent of the life (a child's diary day may hold childcare; school days are not tied to enrolment): reported limit.
- Nested thresholds reproduce a stock at every age and say nothing about flows; incidence by age (diabetes onset, disability) follows an assumed gradient only for diabetes and HIV.
- Unemployment spells are homogeneous across people (a person may have many spells; real spells cluster); the stationary rate is right by construction and the head checks it.
- A time-use rate rescaled by group (India) matches the survey's group rates by solving the scale; it carries the European composition within the group (assumption, recorded as
  degraded `group`). Kenya has no time-use source: the European profile stands in (recorded as `ECS profile (cross-region)`), so its time-use verdicts verify wiring only.
- Diary days at work are capped at the share employed (India men 15-29 report more days at work than the ILO labour-force curve supports): a source conflict, recorded loudly
  (`share employed (cap)`), the target follows the cap as the education clip does.
- Recorded offence rates understate victimisation and one victim can have several offences; applied as per-person hazards over ages 10-70 (children are exposed too in reality).
- The coverage statistic counts a field reached by any membership of any event: it can be satisfied by a kind whose memberships name many fields loosely. Each kind's domains are
  its form, content, outcome and setting only, checked to exist; field pairs co-occur only inside one event (2.1%), which the report states.
- Event snippets are paraphrases of what each indicator or activity code counts, never real cases; diary-day examples are definition-derived.
