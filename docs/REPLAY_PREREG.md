# Pre-Registration: Historical Decision and Rolling-Window Forecasting Replay

This document pre-registers the case-selection criteria, frozen governed thresholds, evaluation cells, statistical hypotheses, and falsifiers for the historical decision replay (`docs/DATA.md` §16a) and the rolling-window forecasting replay (`docs/DATA.md` §16b), per finding 8.87.

The commit hash of this file precedes the creation of any case file (`cases/*.toml`) or replay execution (`sim/src/replay.jl`). The replay harness verifies that thresholds match the frozen defaults below and voids any case whose options or information sources carry dates after the decision date.

---

## 1. Purpose and Scope (Not Curve Fitting)

The replay does not fit Benefuture's parameters to reproduce historical choices. Fitting is permitted only when approximating a historical institution itself as a coarse Benefuture (for example, modelling a central bank's reaction function as a single metric model backing one domain), and only to calibrate that institutional baseline.

For every historical decision, the replay evaluates three counterfactual questions strictly on the information available at the decision date $t_0$:
1. What option Benefuture chooses under the Goal $G$ (and under expertise- and impact-weighted voting where the historical decision was collective).
2. Whether Benefuture's choice agrees with or differs from the actual historical choice.
3. How the counterfactual outcome distribution across affected groups differs along the vector success pattern (floors and medians of understanding and happiness, deepest single-group passing harm, and irreparable harm).

---

## 2. Frozen Governed Thresholds

All governed thresholds sit at their canonical values from `BenefutureReference/ParamSpace.lean` and `sim/README.md`. The replay engine refuses to run a case if any governed threshold is altered from this table.

| Parameter | Symbol / Field | Frozen Value | Role in Replay |
|---|---|---|---|
| Quantile floor | `q_floor` | `0.10` | Bottom decile across affected beings/groups (`bf_floor_quantile`) |
| Lexicographic tie tolerance | `epsilon_tie` | `1e-9` | Tie tolerance in $G$ (`bf_g_choose`) |
| Harm weight scale | `kappa_harm` | `0.5` | Weight on harm relative to understanding and happiness (`bf_v`) |
| Harm convexity exponent | `q_harm` | `1.5` | Convexity exponent in `bf_ha_wt` |
| Harm severity schedule | `HARM_SCHEDULE` | `(0.0, 1.0, 2.0, 5.0)` | Multipliers for none, passing, severe, irreparable harm |
| Freedom confidence threshold | `fr_thConf` | `0.90` | Confidence threshold in freedom report (`bf_fr_permissible`) |
| Freedom high-harm threshold | `fr_thHigh` | `1.00` | High-harm threshold in freedom report (`bootstrap_params_ref`) |
| Freedom severity multipliers | `fr_severities` | `(0.0, 0.25, 0.5, 1.0)` | Per-tier multipliers in `bf_fr_permissible` |
| Escape trial horizon | `escape_horizon` | `5` | Horizon steps for debatable escape trial (`bf_escape_accept`) |
| Escape catastrophic ceiling | `escape_catastrophic` | `10.0` | Catastrophic harm bound blocking escape trials |
| Leaf domain status bar | `acc_bar_leaf` | `0.90` | Minimum lower-confidence accuracy for leaf domain currency |
| Parent domain status bar | `acc_bar_parent` | `0.75` | Minimum lower-confidence accuracy for parent fallback |
| Record credence cap | `credence_cap` | `0.99` | Clamp bound $[1 - \text{cap}, \text{cap}]$ in record credence |
| Model takeover & bar $z$ | `model_z` | `2.0` | Standard-error multiplier for model takeover and bar ratchet |
| Status bar ratchet multiple | `ratchet_multiple` | `20` | Minimum weighted record multiple of half-life before ratcheting |
| Reference half-life | `h_ref` | `7.0` | Reference half-life at reference rate `r_ref` (8.85) |
| Reference record rate | `r_ref` | `5.0` | Reference resolved records per step (8.85) |
| Half-life rate exponent | `decay_beta` | `0.5` | Muted square-root scaling exponent $\beta$ in `bf_decay_halflife` |
| Voting delegation cap | `voting_cap` | `0.05` | Maximum share of total voting weight held by any delegate |
| High-impact voting bar | `impact_threshold` | `0.50` | Impact threshold above which participation duty applies |
| Minimum skill record | `min_skill_record` | `20` | Resolved forecasts required before record weights a voter (8.69) |
| Long-term harm window | `lt_window` | `50` | Horizon over which no existing group may end lower under 8.86 |

Sweeps of `h_ref`, `decay_beta`, `model_z`, and `ratchet_multiple` are permitted only as sensitivity analyses reported alongside the frozen default run, never to select a post-hoc operating point.

---

## 3. As-Of Reconstruction and Hindsight Guard

To prevent hindsight bias (Fischhoff 1975; Baron & Hershey 1988):
1. **Strict Temporal Cutoff**: Every case declares a `decision_date` $t_0$. Every source in the information set carries an `as_of_date` (or `issue_date` and `resolution_date` for forecasts), and every option in the option set carries a `known_date`.
2. **Automatic Voiding on Hindsight Leak**: Before invoking $G$ or the voting tally, the loader checks `as_of_date <= decision_date` for all inputs and `known_date <= decision_date` for all options. Any violation marks the case `void = true` and aborts evaluation.
3. **Real-Time Vintages**: Macroeconomic and epidemiological series are scored against the data vintage available at `resolution_date`, with final revised series kept strictly separate for ex-post counterfactual outcome estimation.
4. **No Survivorship**: Forecasters and models that cease submitting remain in the pool up to their last active window; missing submissions after entry are logged in the `degraded` ledger rather than dropped.

---

## 4. Pre-Registered Case Families and Selection Criteria

Cases are selected by structural criteria (all documented decisions of a class within a period, matched pairs that acted differently, and canonical historical successes and failures named below before opening any case file). Within multi-unit families, half of the comparable units or a paired jurisdiction are held out for replication whenever a finding prompts a rule change.

| Family | Pre-Registered Cases | Actual Outcome Class | Tier | Primary vs Held-Out |
|---|---|---|---|---|
| **1. Single high-stakes technical** | Space Shuttle *Challenger* launch (1986-01-28, O-ring temperature record) | Bad (catastrophic loss) | Full / escape | Primary |
| **1. Single high-stakes technical** | US FDA refusal of thalidomide approval (Kelsey review, 1960–1962) | Good (harm prevented) | Full / escape | Primary |
| **2. Low-technology (8.88)** | Ragusa 30-day plague quarantine law (*trentina*, 1377) | Good | Coarse tier | Primary |
| **2. Low-technology (8.88)** | Vienna General Hospital handwashing intervention & institutional rejection (Semmelweis, 1847–1849) | Good intervention / Bad rejection | Coarse tier | Primary |
| **2. Low-technology (8.88)** | Broad Street pump removal & Southwark/Vauxhall vs Lambeth water supply (Snow, 1854) | Good | Coarse tier | Held-out replication |
| **2. Low-technology (8.88)** | Indian Famine Codes (1880s implementation) vs Bengal Famine policy (1943) | Paired Good vs Bad | Coarse tier | Primary (1880s) / Held-out (1943) |
| **2. Low-technology (8.88)** | European city adoption of the movable-type printing press (1450–1500) | Good (understanding gain) | Coarse tier | Held-out replication |
| **3. Long-horizon regulation** | Montreal Protocol on ozone-depleting substances (1987) | Good | Full | Primary |
| **3. Long-horizon regulation** | Phase-out of tetraethyl lead in petrol (1970s–1980s) & tobacco regulation | Bad (delayed action) | Full | Held-out replication |
| **4. Understanding & education** | Tennessee Project STAR class-size experiment (1985–1989) | Good (floor & mean gain) | Full | Primary |
| **4. Understanding & education** | Dismissal of scientists from German universities (1933) | Bad (peak & output loss) | Full | Primary |
| **4. Understanding & education** | Pandemic school closures (2020–2021) & No Child Left Behind (2002) | Contested / Mixed | Full | Held-out replication |
| **5. Pandemic interventions** | Early vs late NPI adoption and testing regimes (2020–2022, OxCGRT + Forecast Hubs) | Paired across jurisdictions | Full + §16b | US Hub (Primary) / European Hub (Held-out) |
| **6. Monetary policy** | FOMC 1970s inflation, Volcker disinflation (1979–1982), September 2008 | Paired Good vs Bad | Full + §16b | US SPF/Greenbook (Primary) / ECB SPF (Held-out) |

---

## 5. Four-Cell Evaluation Matrix and Vector Success Pattern

Each replayed decision is classified on two orthogonal axes:
- **Ex-Post Outcome Quality**: `Good` vs `Bad` (as established by measured historical outcomes and counterfactual comparison units).
- **Benefuture Agreement**: `Agrees` (Benefuture selects the option actually taken) vs `Differs` (Benefuture selects a feasible alternative known at $t_0$).

| Cell | Meaning | Interpretation |
|---|---|---|
| **(Good, Agrees)** | Sound decision, good outcome, Benefuture concurs | Alignment with successful historical judgement |
| **(Good, Differs)** | Good outcome, Benefuture prefers another option | Requires counterfactual check: if Benefuture's choice yields lower floors or higher harm, counts toward Falsifier F2 |
| **(Bad, Agrees)** | Reasonable ex-ante decision that met unforeseeable bad luck | Counts in Benefuture's favour if the risk was genuinely unobservable as-of $t_0$; counts toward Falsifier F1 if catastrophic risk was in the record |
| **(Bad, Differs)** | Foreseeable bad decision rejected by Benefuture | Primary value added: counterfactual difference estimated across competing methods |

### Vector Success Pattern
Counterfactual differences are never summed into a single scalar utility. Every case reports:
1. `floor_u_delta`, `median_u_delta`: Change in the 10th percentile and median understanding marker across affected groups.
2. `floor_h_delta`, `median_h_delta`: Change in the 10th percentile and median happiness/welfare marker across affected groups.
3. `max_group_nha`: Deepest passing harm (`NHa`) borne by any single group, and whether long-term trajectories (`Ha_lt` over `lt_window`) recover above the no-action counterfactual (8.86).
4. `irreparable_harm`: Deaths, permanent disability, or lost knowledge (`Ha_irr`), priced via `bf_life_value` and `bf_foreclosed`.
5. `degraded`: Loud degradation ledger recording every fallback (coarse tier, parent domain, relative bar, missing forecast submission).

---

## 6. Pre-Registered Rolling-Window Forecasting Hypotheses (§16b)

All forecasting hypotheses are tested on paired record streams using Diebold–Mariano and Giacomini–White block standard errors at $z = 2.0$ ($z = 3.0$ or held-out dataset replication for `README.md` and `docs/BACKPROPAGATION.md`).

- **R1 (Selection)**: Out-of-sample accuracy (Brier score or negatively oriented Weighted Interval Score) of the currency's active model (`bf_select_candidate` at `model_z = 2.0`) beats (a) keeping the initial incumbent forever and (b) unguarded trailing-window switching (`paired_effect`, $z \ge 2.0$), and is at least non-inferior to the equal-weight and hub ensembles within a pre-stated equivalence margin of **5% of mean ensemble error** (`equivalent`, one-sided `side = :low`).
- **R2 (Horizons)**: Following a documented regime shift, rate-adaptive time decay (`decay_beta = 0.5`) achieves a shorter takeover lag than a fixed record count (`decay_beta = 1.0`) and fewer false switches between shifts than a fixed calendar window (`decay_beta = 0.0`) (`paired_effect`, $z \ge 2.0$).
- **R3 (Credence)**: Record credence (`bf_record_credence` / `bf_decayed_record_credence`) achieves lower empirical coverage calibration error ($|\text{empirical hit rate} - \text{stated credence}|$) on heavy-tailed real forecast errors than Gaussian credence (`bf_credence`) (`paired_effect`, $z \ge 2.0$).
- **R4 (Regimes)**: Domain qualification and stall rates under `acc_bar_leaf = 0.90`, `acc_bar_parent = 0.75`, and `bf_ratchet_bar` are reported as `proportion_interval` per domain family and compared against the literature predictability baselines in `docs/CALIBRATION.md` §8 (R5).
- **R5 (Overstatement)**: On binary probability records, extremising forecasters win fixed-window takeovers at the rate predicted by finding 8.58-c, and full-record / settlement rules reduce false takeovers (`paired_effect`, $z \ge 2.0$).
- **R6 (Persistence)**: Rank correlation of forecaster accuracy across consecutive non-overlapping windows is significantly positive ($z \ge 2.0$), supporting persistent track-record weighting (8.29).

---

## 7. Pre-Registered Falsifiers

A mechanism or tier is falsified—and must be recorded in `docs/BACKPROPAGATION.md` rather than patched per case—if any of the following occur under the frozen thresholds:

1. **F1 — Catastrophic As-Of Choice**: On the information set available at $t_0$, Benefuture selects an option whose contemporary record already indicated severe or irreparable harm (`Ha_irr > 0` or floor collapse) and whose actual or counterfactual outcome is catastrophic (for example, approving the *Challenger* launch at 31°F or approving thalidomide without reproductive safety data).
2. **F2 — Rejection of Sound Consensus Without a Superior Known Option**: Benefuture disagrees with a decision judged good both ex ante and ex post (such as the 1377 Ragusa quarantine, Snow's pump removal, or the Montreal Protocol) and selects an alternative whose counterfactual floor or irreparable-harm profile is worse beyond noise.
3. **F3 — Failure of Progressive Complexity (8.88)**: In the coarse tier (parent-level markers, rule-only fallbacks, no dense model pool), Benefuture performs worse than the historical actors on low-technology cases where they succeeded, demonstrating that the rules depend on modern high-frequency measurement rather than degrading gracefully.
4. **F4 — Hindsight Dependence**: A desirable decision in any case depends on an input or option dated after $t_0$, or disappears when post-$t_0$ revisions are replaced by real-time vintages.

