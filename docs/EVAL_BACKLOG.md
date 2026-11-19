# Evaluation & Simulation Backlog

Items moved out of [`OPEN_PROBLEMS.md`](OPEN_PROBLEMS.md) because they are **evaluation/harness limitations, positive stability findings, or untested simulation scenarios** rather than open theoretical or architectural problems in Benefuture. Tracked here so they can be improved later without cluttering the open-problems boundary.

---

## 1. Historical Replay & Evaluation Harness (E4 / E5)

- **Replay does not yet separate Benefuture from the fewest-deaths rule (E4 round 2).**
  - *Status:* Both are right on 8 of 9 settled cases. Friction against hindsight: cases are frozen with credences before reading, first results are never replaced, and prospective E5 cases are registered before outcomes.
  - *Why it lives here:* Historical crisis cases are mortality-dominated, so any rule weighting irreversible harm heavily agrees with fewest-deaths. Separating Benefuture's priority tiers (`U > H`, eudaimonic vs. raw pleasure, etc.) requires cases matched on mortality that differ in kind (contrast cases already separate 3 of 6: NSF 1950, Land and Water Conservation Fund 1964, Sure Start 1998).
  - *Next:* Expand E5 prospective cases and matched-magnitude contrast cases where priority tiers—not mortality—decide.

- **Base rates from recorded events only (swine flu 1976).**
  - *Status:* Cases declare unrecorded trials (with sources) and count them as non-occurrences. On swine flu 1976, the decision does not flip even at a third of the recorded rate.
  - *Why it lives here:* As-of reference-class selection bias is epistemically unavoidable for any non-hindsight evaluator; the specific open piece on swine flu 1976 is how the stockpile option is priced in the case file and verifying primary as-of reports (deferred per `PLAN.md` E4 source verification).
  - *Next:* Audit stockpile pricing in `cases/swine_flu_1976.toml` and complete primary-text verification across E4 cases when full texts are accessible.

- **Contrast cases for priority tiers are hard to build by hand.**
  - *Status:* `contrast_check` refuses contrasts whose acting options differ in expected deaths beyond tolerance (tobacco 1964 refused).
  - *Why it lives here:* Observational historical data rarely yields clean natural experiments with equal mortality and equal as-of evidence quality differing only in kind.
  - *Next:* Add an automated equal-as-of-evidence check to `contrast_check` (to catch asymmetries like Head Start) and supplement historical contrasts with prospective E5 policy comparisons.

---

## 2. Parameter Stability & Future Sweep Coverage

- **Governed defaults not shown improvable across 71 wide active-world arms or 18 50-year coupled arms (Author Ruling `8.164`).**
  - *Status:* Verified in [`thresholds_wide.md`](../sim/battery/results/thresholds_wide.md) and [`coupled_map.md`](../sim/battery/results/coupled_map.md): all 12 parameters actively touched internal mechanisms (`21–308` audit/establishment diffs; `0` globally inconsequential), `threshold` (`0.9`) and `pattern_attention` (`9.0`) sit on two-sided trade-off frontiers, 8 parameters sit on one-sided cliffs/trade-offs (`acc_halflife = 1.75` confirmed as `tradeoff` at 64 seeds), and all `18/18` 50-year coupled arms touched audits with `0/18` improvements.
  - *Why it lives here:* This is a **positive stability finding** (the bootstrap defaults sit on a robust Pareto frontier rather than being dead or brittle), not an open problem. Defaults remain governed defaults, not universal optima.
  - *Next:* Re-run threshold sensitivity in composed century runs once opt-in mechanisms (`ra_domain`, `proposal_pma`, `open_entry`) are promoted to defaults.

---

## 3. Untested Simulation Variants & Wiring Backlog

- **Deceivers' work harmful/useless variant (`8.115`).** Closed-world output loss is resolved under `open_entry = true` (`P7`: `+19.88 ± 1.63` on `floor_u`, `z = 12.20`, while cutting deceivers' advantage `-45.01 ± 4.99`). Remaining sim variant to add: a regime where deceivers' underlying work is net-harmful or useless rather than productive-but-overstated.
- **Default-on wiring of `ra_domain` (`8.133`, `8.155`).** `ra_domain`, `ra_horizon`, and `ra_reserve_horizon` are verified in `P10`/`P11` (`z = 3.0`) but remain opt-in (`false`/`0`) in `M3cParams` pending governed threshold selection in composed century runs. (Multi-resource physical pools and cross-domain price discovery are tracked separately in `PLAN.md` Spike `D8`.)
- **Decorrelated model cartel vs. `AdvAp` (`B4`, `8.2`, `8.23`).** Distributional collusion detection is re-established at 64 seeds (`z ≥ 3`). Remaining sim variant: a cartel that deliberately decorrelates its errors, tested against full-Bf `AdvAp` insider whistleblowing (`L161`) and `OpenSource` inspection (`L51`).
- **Sybil *beings* outside M5/M3c.** Weighted TN binding (`P14–P15`) and `bound_shapley_shares` (`P34`) are verified in M5 and M3c; Sybil *beings* in M7/composed population worlds remain to be wired and tested.

