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

Generated from the code by `tools/data/prereg_thresholds.jl` (`julia --project=sim tools/data/prereg_thresholds.jl`), so this table cannot diverge from the rules the replay runs. The replay refuses a case if any of these is altered.

| Parameter | Field | Value | Source |
|---|---|---|---|
| Floor quantile | `q` | 0.1 | ToyParams default (sim/src/m0.jl) |
| Ha_wt synergy κ | `kappa_harm` | 0.5 | bootstrap_params_ref (ParamSpace.lean) |
| Ha_wt exponent q | `q_harm` | 1.5 | bootstrap_params_ref |
| Harm schedule (L61) | `HARM_SCHEDULE` | (0.9, 0.7, 0.45, 0.15, 0.08, 0.04, 0.01) | value.jl / harmSchedule_ref |
| Fr confidence bar | `fr_thConf` | 0.9 | bootstrap_params_ref |
| Fr high-harm bar | `fr_thHigh` | 1.0 | bootstrap_params_ref |
| Fr severity multipliers | `sev_*` | (1000.0, 100.0, 10.0, 1.0, 0.5) | bootstrap_params_ref |
| Leaf status bar | `threshold` | 0.9 | M3cParams default |
| Coarse / parent bar | `coarse_threshold` | 0.75 | M3cParams default |
| Novel-domain floor | `novel_floor` | 0.55 | M3cParams default (8.35) |
| Credence cap | `max_credence` | 0.99 | M3cParams default |
| Model significance z | `model_z` | 2.0 | M3cParams default |
| Ratchet horizon multiple | `ratchet_horizon` | 20.0 | M3cParams default (8.84, 8.85) |
| Accuracy half-life at reference rate | `acc_halflife` | 7.0 | M3cParams default (8.85) |
| Reference transaction rate | `acc_rate_ref` | 5.0 | M3cParams default (8.85) |
| Half-life rate mute | `acc_mute` | 0.5 | M3cParams default (8.85) |
| Delegation cap | `cap` | 0.05 | M5Params default (L114) |
| Participation impact bar | `impact_threshold` | 0.5 | M5Params default (8.46) |
| Long-term window (accession, 8.86) | `lt_window` | 100 | pop_value / pop_choose signature default (sim/src/m7.jl) |

**Amendment 2026-11-05 (before any replay beyond the four original cases).** The earlier table did not match the governed point: it listed a harm schedule (0, 1, 2, 5) and Fr severity multipliers (0, 0.25, 0.5, 1) that exist nowhere in the code (the governed values are above), described κ as a harm weight (it is Ha_wt's synergy parameter), and gave the long-term window as 50 (the code's default is 100). Rows with no source in the code (an escape horizon of 5, a catastrophic ceiling of 10, a minimum skill record of 20, a tie tolerance) are dropped; any replay step that needs one names its governed parameter first. Replays already run on the four original cases are re-run against this table before their results count.

## 3. As-Of Reconstruction and Hindsight Guard

To prevent hindsight bias (Fischhoff 1975; Baron & Hershey 1988):
1. **Strict Temporal Cutoff**: Every case declares a `decision_date` $t_0$. Every source in the information set carries an `as_of_date` (or `issue_date` and `resolution_date` for forecasts), and every option in the option set carries a `known_date`.
2. **Automatic Voiding on Hindsight Leak**: Before invoking $G$ or the voting tally, the loader checks `as_of_date <= decision_date` for all inputs and `known_date <= decision_date` for all options. Any violation marks the case `void = true` and aborts evaluation.
3. **Real-Time Vintages**: Macroeconomic and epidemiological series are scored against the data vintage available at `resolution_date`, with final revised series kept strictly separate for ex-post counterfactual outcome estimation.
4. **No Survivorship**: Forecasters and models that cease submitting remain in the pool up to their last active window; missing submissions after entry are logged in the `degraded` ledger rather than dropped.

---

## 4. Pre-Registered Case Families and Selection Criteria

Cases are selected by structural criteria across the families defined in `docs/DATA.md` §16a: all documented decisions of a class within a period, matched pairs that acted differently, canonical historical successes and failures, and specific cases where caution or delay was the error.

Every case must be registered here with:
- **Decision date ($t_0$)**: The exact historical cutoff date.
- **Decision makers**: Documented individuals, agencies, or institutions responsible.
- **Actual choice**: The historical choice made at $t_0$.
- **Actual outcome class**: `Good`, `Bad`, or `Unclear` (as evaluated ex post in historical analysis).
- **Caution-as-error flag**: Explicitly designating decisions where delay or excessive caution was the error.
- **Sources to collect**: Specific contemporary documents, models, or datasets dated $\le t_0$.
- **Counterfactual estimators**: Competing econometric, epidemiological, or physical models.
- **Pre-registered falsifier**: Specific conditions under which Benefuture's choice on this case counts toward falsification.

Within multi-unit or paired families, held-out cases are named and reserved without opening or examining their detailed records, ensuring clean out-of-sample replication.

### 4.1 Master Registry: Primary Cases (12 Cases)

The primary case set contains 12 balanced historical decisions across §16a families: 4 Good, 4 Bad, and 4 Unclear decisions, including 2 where caution/delay was the primary error.

| ID | Title / Family | Decision Date ($t_0$) | Decision Makers | Actual Choice | Class | Caution Error? |
|---|---|---|---|---|---|---|
| `challenger_1986` | Shuttle *Challenger* STS-51-L launch (Family 1: Technical) | 1986-01-28 | NASA MSFC & Morton Thiokol | Launch at 31°F ambient pad temperature | `Bad` | No |
| `thalidomide_fda_1960` | FDA Thalidomide NDA Review (Family 1: Technical) | 1961-02-23 | Dr. Frances Kelsey, US FDA | Block commercial approval pending peripheral neuropathy & reproductive safety data | `Good` | No |
| `ragusa_quarantine_1377` | Ragusa Plague Quarantine Law (Family 2: Low-Tech) | 1377-07-27 | Major Council of the Republic of Ragusa (Dubrovnik) | Enact 30-day quarantine (*trentina*) on incoming ships/caravans | `Good` | No |
| `semmelweis_vienna_1847` | Vienna General Hospital Handwashing (Family 2: Low-Tech) | 1849-03-20 | Prof. Klein & Medical Faculty, University of Vienna | Terminate Semmelweis's appointment and abandon mandatory chlorinated-lime hand antisepsis | `Bad` | No |
| `famine_codes_1880` | Indian Famine Codes Enactment (Family 2: Low-Tech) | 1883-06-09 | Famine Commission & Government of India | Adopt codified early wage relief, railway grain transport, and price transparency triggers | `Good` | No |
| `montreal_protocol_1987` | Montreal Protocol on ODS (Family 3: Long-Horizon) | 1987-09-16 | UNEP, US EPA, EC, 24 Signatory Nations | Phase down 5 CFCs and 3 halons by 50% by 1999 with 10-year developing nation grace period | `Good` | No |
| `bengal_denial_1942` | Bengal "Denial Policy" Rice Seizure (Family 2: Low-Tech) | 1942-04-15 | War Cabinet & Government of Bengal | Seize boats and surplus coastal rice stockpiles to thwart Japanese invasion, creating entitlement famine | `Bad` | No |
| `german_univ_purge_1933` | Law for Restoration of Professional Civil Service (Family 4: Education) | 1933-04-07 | Reich Government & University Rectors | Dismiss Jewish and politically suspect faculty and scholars across German universities | `Bad` | No |
| `fda_beta_blockers_1975` | Propranolol Secondary Prevention Approval Delay (Family 1: Technical) | 1975-09-12 | US FDA Cardiorenal Advisory Committee | Withhold secondary post-infarction prophylaxis approval for beta-blockers demanding additional US trial | `Bad` | **Yes (Caution Error)** |
| `uk_bse_feed_ban_1988` | UK Ruminant Feed Ban on MBM (Family 3: Long-Horizon) | 1988-06-09 | MAFF & Southwood Working Party | Impose partial ban on ruminant-to-ruminant feed but permit cross-species use and existing feed inventory depletion | `Unclear` | **Yes (Caution Error)** |
| `school_closures_2020` | Primary & Secondary School Closures (Family 5: Pandemic) | 2020-03-20 | State Governors & Epidemiological Task Forces | Enact broad physical school shutdowns across Spring 2020 | `Unclear` | No |
| `fomc_september_2008` | FOMC Inter-Meeting Rate Hold (Family 6: Monetary) | 2008-09-16 | Federal Open Market Committee (Bernanke) | Hold target federal funds rate unchanged at 2.00% immediately following Lehman collapse citing inflation risks | `Unclear` | No |

---

### 4.2 Case Specifications: Primary Set

#### Case 1: `challenger_1986` (Space Shuttle *Challenger* Launch)
- **Family**: 1. Single high-stakes technical.
- **Decision Date ($t_0$)**: 1986-01-28.
- **Decision Makers**: NASA Marshall Space Flight Center, Morton Thiokol management.
- **Actual Choice**: Launch at 31°F ambient pad temperature.
- **Actual Outcome Class**: `Bad` (loss of vehicle, 7 crew fatalities, space shuttle fleet grounded 32 months).
- **Caution Error**: No (rash action despite engineering warnings).
- **Sources to Collect**:
  - Morton Thiokol engineering teleconference charts on O-ring thermal distress (Boisjoly & Thompson, 1986-01-27).
  - Marshall Space Flight Center Flight Readiness Assessment (Mulloy, 1986-01-27).
  - 24-flight historical launch temperature and O-ring erosion log (Rogers Commission Report, 1986).
- **Counterfactual Estimators**:
  - Rogers Commission logistic probability model of O-ring blow-by vs temperature.
  - Empirical launch history across subsequent warm-weather flights.
- **Pre-Registered Falsifier**: Benefuture selects `launch_at_31F` when contemporary data shows severe blow-by correlation with cold temperatures (Falsifier F1).

#### Case 2: `thalidomide_fda_1960` (US FDA Thalidomide Review)
- **Family**: 1. Single high-stakes technical.
- **Decision Date ($t_0$)**: 1961-02-23.
- **Decision Makers**: Dr. Frances Kelsey, US Food and Drug Administration.
- **Actual Choice**: Withhold commercial NDA approval, demanding rigorous clinical data on peripheral neuropathy and foetal/maternal toxicity.
- **Actual Outcome Class**: `Good` (prevented thousands of severe phocomelia birth defects in the US).
- **Caution Error**: No (justified refusal on safety signals).
- **Sources to Collect**:
  - Richardson-Merrell NDA submission dossier (1960-09-12).
  - Florence Leslie peripheral neuropathy report in the *British Medical Journal* (1960-12-31).
  - Kelsey deficiency letters to Richardson-Merrell (1960-11-10, 1961-01-17, 1961-02-23).
- **Counterfactual Estimators**:
  - European phocomelia incidence rates per thousand live births (West Germany / UK synthetic control).
  - Pharmacokinetic placental transfer models.
- **Pre-Registered Falsifier**: Benefuture approves commercial sale or overrides Kelsey's demand for peripheral neuropathy safety data (Falsifier F1).

#### Case 3: `ragusa_quarantine_1377` (Ragusa Maritime Quarantine Law)
- **Family**: 2. Low-technology (8.88).
- **Decision Date ($t_0$)**: 1377-07-27.
- **Decision Makers**: Major Council (*Consilium Maius*) of the Republic of Ragusa (Dubrovnik).
- **Actual Choice**: Enact 30-day quarantine (*trentina*) on the island of Mrkan/Bobara for arrivals from plague-infested areas.
- **Actual Outcome Class**: `Good` (protected urban population, maintained trade without total blockade).
- **Caution Error**: No.
- **Sources to Collect**:
  - *Liber Viridis* (Green Book of Ragusa) Council deliberation entries, July 1377.
  - Contemporary mortality registers and trade accounts of Adriatic city-states.
- **Counterfactual Estimators**:
  - SEIR plague transmission model comparing full blockade vs 30-day isolation vs open entry.
  - Comparative mortality difference-in-differences across Adriatic ports (Venice, Split, Zadar).
- **Pre-Registered Falsifier**: Benefuture rejects the quarantine order as unproven or favors unregulated open entry, resulting in population collapse (Falsifier F2 / F3).

#### Case 4: `semmelweis_vienna_1847` (Vienna Hospital Hand Antisepsis)
- **Family**: 2. Low-technology (8.88).
- **Decision Date ($t_0$)**: 1849-03-20.
- **Decision Makers**: Professor Klein and Medical Faculty, Vienna General Hospital (Allgemeines Krankenhaus).
- **Actual Choice**: Expel Semmelweis and abandon mandatory chlorinated-lime handwashing for doctors arriving from the autopsy theatre.
- **Actual Outcome Class**: `Bad` (maternal puerperal fever mortality rebounded from 1.3% back above 10%).
- **Caution Error**: No.
- **Sources to Collect**:
  - Vienna First and Second Obstetrical Clinic monthly maternal mortality ledger (1841–1849).
  - Semmelweis's clinical protocol and chlorina liquida disinfection records (May 1847).
  - Klein's administrative reprimands and faculty meeting minutes (March 1849).
- **Counterfactual Estimators**:
  - Interrupted time series (ITS) on maternal mortality in Clinic 1 vs Clinic 2.
  - Poisson regression on monthly maternal sepsis deaths.
- **Pre-Registered Falsifier**: Benefuture endorses Klein's dismissal of Semmelweis or concludes the 10-fold mortality drop was statistical noise (Falsifier F1 / F3).

#### Case 5: `famine_codes_1880` (Indian Famine Codes Enactment)
- **Family**: 2. Low-technology (8.88).
- **Decision Date ($t_0$)**: 1883-06-09.
- **Decision Makers**: Famine Commission of 1880 and Government of India.
- **Actual Choice**: Promulgate the Provisional Famine Code establishing relief wages, rail grain transport obligations, and price monitoring.
- **Actual Outcome Class**: `Good` (prevented mortality spikes in subsequent drought episodes, e.g. 1888–1889).
- **Caution Error**: No.
- **Sources to Collect**:
  - Report of the Indian Famine Commission, Parts I & II (C. 2591, 1880).
  - Provincial district crop failure indices and rainfall records (1876–1882).
  - Provisional Famine Code draft rules (1883).
- **Counterfactual Estimators**:
  - District-level panel regressions of famine mortality on rainfall shocks pre/post railway and code implementation (Burgess & Donaldson 2010).
- **Pre-Registered Falsifier**: Benefuture rejects the public wage relief guarantee as an economic deadweight loss (Falsifier F2 / F3).

#### Case 6: `montreal_protocol_1987` (Montreal Protocol on Ozone Depletion)
- **Family**: 3. Long-horizon regulation.
- **Decision Date ($t_0$)**: 1987-09-16.
- **Decision Makers**: UNEP, national delegations (US EPA, European Community, Japan, UK).
- **Actual Choice**: Adopt binding schedule to freeze and phase down production and consumption of chlorofluorocarbons (CFC-11, 12, 113, 114, 115) and halons.
- **Actual Outcome Class**: `Good` (reversed stratospheric ozone hole expansion, averted tens of millions of skin cancer cases).
- **Caution Error**: No.
- **Sources to Collect**:
  - WMO/NASA Atmospheric Ozone Assessment (1985).
  - Farman, Gardiner & Shanklin British Antarctic Survey Halley Bay ozone loss paper (*Nature*, 1985).
  - US EPA Regulatory Impact Assessment on Stratospheric Ozone Protection (1987).
- **Counterfactual Estimators**:
  - NASA Goddard "World Avoided" 3D chemistry-climate simulation (Newman et al. 2009).
  - Epidemiological melanoma/cataract incidence scaling models under unmitigated UV flux.
- **Pre-Registered Falsifier**: Benefuture rejects the ban due to the 50-year atmospheric lifetime lag or demands certainty before restricting chemical manufacturing (Falsifier F2).

#### Case 7: `bengal_denial_1942` (Bengal Famine Denial Policy)
- **Family**: 2. Low-technology (8.88).
- **Decision Date ($t_0$)**: 1942-04-15.
- **Decision Makers**: War Cabinet (London), Viceroy Lord Linlithgow, Governor Sir John Herbert (Bengal).
- **Actual Choice**: Confiscate boats capable of carrying $> 10$ persons ("Boat Denial") and purchase/remove surplus coastal rice stocks ("Rice Denial") in coastal Bengal.
- **Actual Outcome Class**: `Bad` (shattered local distribution and peasant exchange entitlements, sparking 1943 famine with 2.1–3.0 million deaths).
- **Caution Error**: No (deliberate deprivation for military denial).
- **Sources to Collect**:
  - Government of Bengal Denial Scheme instructions (April 1942).
  - Contemporary agricultural census and weekly price indices in coastal districts (Midnapore, Barisal, 24-Parganas).
  - Famine Inquiry Commission (Woodhead Commission) report (1945).
- **Counterfactual Estimators**:
  - Sen (1981) entitlement exchange failure model vs food availability decline (FAD).
  - Synthetic control of inland districts with identical crop yields unaffected by boat confiscation.
- **Pre-Registered Falsifier**: Benefuture favors the denial seizures or ignores rural wage-earner subsistence floors (Falsifier F1 / F3).

#### Case 8: `german_univ_purge_1933` (Dismissal of Scientists from German Universities)
- **Family**: 4. Understanding & education.
- **Decision Date ($t_0$)**: 1933-04-07.
- **Decision Makers**: German Reich Ministry of Interior, University Rectors.
- **Actual Choice**: Enforce §3 ("Aryan Clause") of the Law for the Restoration of the Professional Civil Service, dismissing Jewish, socialist, and pacifist academics.
- **Actual Outcome Class**: `Bad` (immediate dismissal of 15% of faculty, catastrophic long-term collapse of German mathematics, physics, and medical research supremacy).
- **Caution Error**: No.
- **Sources to Collect**:
  - Text of Gesetz zur Wiederherstellung des Berufsbeamtentums (RGBl. I S. 175, 1933-04-07).
  - List of Dismissed Academics (Emergency Society of German Scholars Abroad / Notgemeinschaft deutscher Wissenschaftler im Ausland, 1936).
  - Pre-1933 German university faculty rosters, citation indexes, and Nobel prize counts.
- **Counterfactual Estimators**:
  - Waldinger (2010, 2012) department-level difference-in-differences on patent output, citations, and PhD placements across affected vs unaffected departments.
- **Pre-Registered Falsifier**: Benefuture evaluates faculty purges as neutral or beneficial to educational output (Falsifier F1).

#### Case 9: `fda_beta_blockers_1975` (Delay in Beta-Blocker Post-Infarction Approval)
- **Family**: 1. Single high-stakes technical.
- **Decision Date ($t_0$)**: 1975-09-12.
- **Decision Makers**: US FDA Cardiorenal Advisory Committee.
- **Actual Choice**: Refuse secondary prevention indication for propranolol following acute myocardial infarction, demanding duplicative US randomized clinical trials despite European multicentre trial evidence.
- **Actual Outcome Class**: `Bad` (delayed approval by 6 years until 1981, causing an estimated 10,000–17,000 avoidable deaths per year among US post-infarction patients).
- **Caution Error**: **Yes (Caution Error)**: Excessively cautious regulator held back life-saving therapy over procedural trial provenance.
- **Sources to Collect**:
  - Multicentre International Study results on oral practolol/propranolol (*BMJ*, 1975).
  - FDA Cardiorenal Advisory Committee transcripts and review memorandum (September 1975).
  - US annual acute myocardial infarction survival statistics (1975–1981).
- **Counterfactual Estimators**:
  - Cox proportional hazards survival models from the European trials applied to US post-MI patient cohorts.
  - Counterfactual mortality estimation (Peltzman 1973; Wardell 1973 drug lag methodology).
- **Pre-Registered Falsifier**: Benefuture concurs with the delay on bureaucratic grounds despite overwhelming survival hazard ratio reduction (Falsifier F1).

#### Case 10: `uk_bse_feed_ban_1988` (UK Partial Ruminant Feed Ban on MBM)
- **Family**: 3. Long-horizon regulation.
- **Decision Date ($t_0$)**: 1988-06-09.
- **Decision Makers**: UK Ministry of Agriculture, Fisheries and Food (MAFF) and Southwood Working Party.
- **Actual Choice**: Enact a partial ban on meat-and-bone meal (MBM) in ruminant feed, but permit sales of existing contaminated feed stockpiles and allow cross-species poultry/pig feed manufacturing in shared mills.
- **Actual Outcome Class**: `Unclear` (recognized threat early, but compromise caution allowed cross-contamination to infect millions of cattle and cause variant CJD in humans).
- **Caution Error**: **Yes (Caution Error)**: Regulatory hesitation to impose complete financial loss on feed mills caused partial enforcement failure.
- **Sources to Collect**:
  - Southwood Working Party Report on Bovine Spongiform Encephalopathy (MAFF, 1988).
  - Central Veterinary Laboratory (CVL) epidemiological bulletins (Wilesmith et al. 1988).
  - BSE transmission feed mill surveys (1988–1990).
- **Counterfactual Estimators**:
  - Ferguson et al. (2002) back-calculation mathematical model of BSE cattle infection trajectories and vCJD human exposure under total vs partial ban.
- **Pre-Registered Falsifier**: Benefuture endorses the compromise exemption allowing feed inventory drawdowns without testing (Falsifier F1).

#### Case 11: `school_closures_2020` (Spring 2020 Pandemic School Closures)
- **Family**: 5. Pandemic interventions.
- **Decision Date ($t_0$)**: 2020-03-20.
- **Decision Makers**: State Governors and Public Health Officers across 50 US States.
- **Actual Choice**: Mandate statewide shutdown of in-person K-12 schooling.
- **Actual Outcome Class**: `Unclear` (curbed early transmission uncertainty, but inflicted severe learning loss, mental health harms, and widened achievement gaps with negligible viral suppression in young children).
- **Caution Error**: No (high uncertainty ex ante).
- **Sources to Collect**:
  - Imperial College COVID-19 Response Team Report 9 (Ferguson et al., 2020-03-16).
  - CDC Morbidity and Mortality Weekly Report (MMWR) school-age contact and transmission summaries (March 2020).
  - NWEA and NAEP baseline student achievement test distributions (2018–2019).
- **Counterfactual Estimators**:
  - Quasi-experimental difference-in-differences across states with differing closure durations (e.g. Florida vs California) controlling for local epidemic wave timing.
  - Chetty et al. (2020) Opportunity Insights student engagement and math progress panel.
- **Pre-Registered Falsifier**: Benefuture evaluates school closure purely on virus $R_t$ while completely ignoring child learning loss and developmental floors (Falsifier F2 / F3).

#### Case 12: `fomc_september_2008` (FOMC Inter-Meeting Rate Hold During Lehman Collapse)
- **Family**: 6. Monetary policy.
- **Decision Date ($t_0$)**: 2008-09-16.
- **Decision Makers**: Federal Open Market Committee (Chairman Ben Bernanke).
- **Actual Choice**: Hold the target federal funds rate unchanged at 2.00% (voting 10–0) despite Lehman Brothers filing for bankruptcy 24 hours earlier and AIG facing insolvency, citing oil price inflation concerns.
- **Actual Outcome Class**: `Unclear` (rapid subsequent escalation forced emergency cuts and unconventional liquidity facilities within weeks, but September 16 hold reflected genuine contemporary inflation model readings).
- **Caution Error**: No.
- **Sources to Collect**:
  - FOMC Meeting Transcript and Minutes of September 16, 2008.
  - Federal Reserve Board staff Greenbook / Tealbook forecast vintage for September 2008.
  - Real-time Survey of Professional Forecasters (SPF) Q3 2008 projections.
  - Financial distress indicators: TED spread, LIBOR-OIS spread as of 2008-09-16.
- **Counterfactual Estimators**:
  - FRB/US structural macroeconomic model simulation with 50bp vs 100bp emergency rate cut on September 16.
  - Structural Vector Autoregression (SVAR) with high-frequency financial shock identification.
- **Pre-Registered Falsifier**: Benefuture ignores severe liquidity market dislocation and bank inter-lending freezes when evaluating macro-financial distress (Falsifier F1).

---

### 4.3 Master Registry: Held-Out Cases (6 Cases)

The held-out case set contains 6 cases that are formally reserved. Their metadata, dates, and historical outcomes are catalogued below, but their raw records are kept untouched until the primary replay and calibration are frozen.

| ID | Title / Family | Decision Date ($t_0$) | Decision Makers | Actual Choice | Class | Caution Error? |
|---|---|---|---|---|---|---|
| `snow_broad_street_1854` | Broad Street Pump Handle Removal (Family 2: Low-Tech) | 1854-09-07 | St. James Parish Board of Guardians | Remove the Broad Street pump handle based on Snow's waterborne cholera map | `Good` | No |
| `printing_press_europe_1470` | Municipal Adoption of Printing Press (Family 2: Low-Tech) | 1475-01-01 | City Councils of European Commercial Cities | Grant municipal privileges and workshop licenses to master printers | `Good` | No |
| `leaded_petrol_phaseout_1973` | EPA Reduction of Lead in Gasoline (Family 3: Long-Horizon) | 1973-11-28 | US EPA Administrator Russell Train | Promulgate scheduled reduction of lead additives in gasoline despite industry litigation | `Good` | No |
| `bengal_famine_relief_1943` | Bengal Famine Relief Refusal (Family 2: Low-Tech) | 1943-08-04 | UK War Cabinet & Prime Minister Churchill | Reject Viceroy Wavell's emergency requests for 500,000 tons of grain shipments to Bengal | `Bad` | No |
| `no_child_left_behind_2002` | High-Stakes Accountability Enactment (Family 4: Education) | 2002-01-08 | US Congress & President Bush | Sign No Child Left Behind Act mandating 100% proficiency with punitive sanctions for failing schools | `Unclear` | No |
| `volcker_disinflation_1979` | Shift to Non-Borrowed Reserve Targeting (Family 6: Monetary) | 1979-10-06 | Federal Open Market Committee (Paul Volcker) | Abandon federal funds rate pegging in favor of strict bank reserve targeting to break inflation | `Good` | No |

---

## 5. Four-Cell Evaluation Matrix and Vector Success Pattern

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

