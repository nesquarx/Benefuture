# Real-world data for the simulation

Candidate public datasets for each object and parameter of the simulation (`sim/`), with what each
measures, how it would enter (calibration, validation or a noise range), its access, size and
caveats, and a prioritised plan. Nothing here has entered the simulation yet: every rung still runs
on invented worlds (`sim/README.md`, Noise and Governed thresholds).

## Verification and validation

`README.md` (Claims) keeps two checks apart, and this document only concerns the second.

- **Verification**: the simulation does what the rules say. Julia calls the Lean reference
  (`BenefutureReference`), whose outputs reproduce `spec/vectors/*.json`; acceptance and adversarial
  suites run red first. This says nothing about the world.
- **Validation**: the simulated world behaves like the real one where they can be compared. No
  simulation result has been validated. Data enters in three roles:
  - **Calibration target**: a world parameter (a skill distribution, a noise size, a chance) is set
    from data instead of a first guess. Governed thresholds are never calibrated from data in this
    sense: they are the framework's own choices, governed by SigThGv (L157).
  - **Validation target**: a pattern the calibrated simulation should reproduce without being fitted
    to it (a stylised fact, a distribution shape, a response to a shock). Held-out patterns only.
  - **Noise range**: the realistic range a battery sweeps (`sim/README.md`, Noise), replacing a first
    guess, especially the ranges marked "not yet set".

**Proxy validity.** Benefuture reads outputs only: beliefs, preferences and inner states are not
directly accessible, so understanding and happiness are always estimated from outputs (answers,
test responses, behaviour). Every dataset below is such an output, measured by some institution's
own metric model with its own error. A dataset therefore calibrates the *markers* and *metric
models* of the simulation as much as the latent levels: a test score is a marker of understanding
with error, not understanding. Mapping into the simulation's units means standardising by the
domain's natural spread of outcomes (model error is already expressed relative to it, 8.35), and
the simulation's threshold unit (`ToyParams.th`) has no external scale yet.

**Links.** Each link was checked on 2026-10-30 by an automated request, DOIs against Crossref or the
DOI handle service. Marks: **[403]** the site answered 403 to the automated check (bot protection;
not confirmed in a browser); **[unreachable]** the host could not be reached from this session;
**[unverified]** a claim (licence, availability, figure) not confirmed from the source. Summaries
rest on abstracts and prior knowledge; figures are to be confirmed against the papers before they
enter `README.md` (Claims) or a calibration.

---

## 1. Understanding (U)

Simulation objects: levels `u` per being (initialised 5 + N(0, 1), `toy_state`, `sim/src/m0.jl`);
marker noise `marker_σ` (0.05; 0.02–0.2); floors, median and peak in the success pattern
(`success_pattern`, `sim/src/analysis.jl`).

- **World Bank Harmonized Learning Outcomes (HLO)**, https://datacatalog.worldbank.org/search/dataset/0038001;
  Angrist, Djankov, Goldberg & Patrinos (2021), "Measuring human capital using global learning data",
  *Nature*, https://doi.org/10.1038/s41586-021-03323-7. International and regional tests (PISA,
  TIMSS, PIRLS, regional assessments) linked onto one scale for about 164 countries, 2000–2017.
  *Maps:* validation target for the shape of the cross-country distribution of an understanding proxy
  (floors and medians far apart, slow growth); not individual-level. *Access:* World Bank data
  catalogue, CC BY 4.0 **[unverified]**. *Size:* country-year panel, small. *Caveats:* a test
  linking exercise (a metric model in its own right, with linking error); schooling-age only;
  literacy and numeracy, not understanding at large.
- **PISA** (OECD), https://www.oecd.org/en/about/programmes/pisa/pisa-data.html **[403]**.
  Student-level microdata every three years since 2000 (about 600,000 15-year-olds in 2022), with
  plausible values and background questionnaires. *Maps:* calibration of the within-population
  spread of understanding and of marker error (the plausible values give measurement error
  directly), a noise range for `marker_σ` on understanding. *Access:* free download. *Caveats:*
  cross-sectional (no individual growth), age 15 only, low-stakes test effort varies by country.
- **TIMSS and PIRLS**, https://timssandpirls.bc.edu/. Grade 4 and 8 mathematics, science and reading
  every four or five years. *Maps:* as PISA, with a grade-4/grade-8 cohort comparison that roughly
  gives growth over four years (validation of growth rates). *Access:* free microdata. *Caveats:*
  pseudo-cohorts, not panels.
- **PIAAC, Survey of Adult Skills** (OECD), https://www.oecd.org/en/about/programmes/piaac.html
  **[403]**. Adult literacy, numeracy and problem solving, 16–65. *Maps:* the adult distribution and
  its change with age, the only broad source past schooling; validation of whether levels keep
  rising or decay without teaching. *Caveats:* two cycles a decade apart; cross-sectional.
- **ECLS-K** (US NCES), https://nces.ed.gov/ecls/. Longitudinal cohorts followed from kindergarten
  (1998–99, 2010–11) with repeated assessments. *Maps:* individual growth trajectories and their
  scatter, calibration of per-being growth and of reception (section 5). *Access:* public-use files
  free; restricted-use files under licence. *Caveats:* US only.
- **World Bank Human Capital Index and learning-adjusted years of schooling**,
  https://www.worldbank.org/en/publication/human-capital. Built from HLO plus survival and health.
  *Maps:* an aggregate validation series only.

## 2. Happiness (H)

Simulation objects: levels `h` per being; marker noise on happiness (the same `marker_σ`); H floors
and medians in the success pattern.

- **World Happiness Report** (Gallup World Poll data), https://worldhappiness.report/; data page
  https://worldhappiness.report/data-sharing/. Country-year averages of the Cantril ladder (life
  evaluation, 0–10) with explanatory variables, about 140 countries a year. *Maps:* validation of
  cross-country spread and slow change. *Access:* country aggregates published; the individual-level
  Gallup World Poll is proprietary (https://www.gallup.com/178667/gallup-world-poll-work.aspx).
  *Caveats:* life evaluation is one output among several readings of happiness; cultural response
  styles; aggregates hide the floors the Goal needs.
- **World Values Survey**, https://www.worldvaluessurvey.org/WVSDocumentationWV7.jsp. Repeated
  cross-national surveys since 1981 (wave 7, 2017–2022, about 60 countries) with life satisfaction
  and happiness items, values and trust. *Maps:* individual-level distributions of reported
  happiness, so floors (low quantiles) and medians can be read, not only means; calibration of the
  initial spread of `h`. *Access:* free registration, non-commercial terms. *Caveats:*
  cross-sectional; single items.
- **European Social Survey**, https://www.europeansocialsurvey.org/. Biennial since 2002, about 30
  countries, life satisfaction and happiness on 0–10 scales. *Maps:* as WVS with tighter fieldwork
  standards. *Access:* free registration.
- **German Socio-Economic Panel (SOEP)**, https://www.diw.de/soep. Household panel since 1984 with
  yearly life satisfaction for the same people. *Maps:* the one family of sources here that follows
  individuals: within-person volatility (a noise range for happiness markers), recovery after shocks
  (deaths of spouses, unemployment: validation of harm's recovery and of `hazard_σ`), adaptation.
  *Access:* data-use agreement, free for research. *Caveats:* one country.
- **Krueger & Schkade (2008)**, "The reliability of subjective well-being measures", *J. Public
  Economics*, https://doi.org/10.1016/j.jpubeco.2007.12.015; **Lucas & Donnellan (2012)**, "Estimating
  the reliability of single-item life satisfaction measures", *Social Indicators Research*,
  https://doi.org/10.1007/s11205-011-9783-z. Test–retest reliability of life satisfaction around
  0.6–0.7. *Maps:* a noise range for the happiness marker: with reliability r, marker noise is about
  √(1 − r) of the population spread, an order of magnitude above the default 0.05 relative error
  **[to check against the simulation's units]**.
- **Killingsworth & Gilbert (2010)**, "A wandering mind is an unhappy mind", *Science*,
  https://doi.org/10.1126/science.1192439. Experience sampling by phone of momentary happiness and
  activity. *Maps:* the gap between momentary and evaluative readings, a reason the simulation's
  single `h` is a toy assumption.

## 3. Harm

Simulation objects: losses in `u` and `h` (passing harm, harm tier 4 in `being_value`); harm's peak
(the deepest single-being drop, `worst_drop`); hazards (`p_hazard`, `hazard_share`, `hazard_size`,
`hazard_σ`), side effects (`p_side`, `side_share`, `side_size`, `p_foresee`), catastrophes and
outages (`shock`, `sim/src/m3c.jl`), irreparable harm (`irreparable_loss`).

- **Global Burden of Disease (GBD)** (IHME), https://www.healthdata.org/research-analysis/gbd; results
  tool https://vizhub.healthdata.org/gbd-results/; GBD 2021 Diseases and Injuries Collaborators
  (2024), *Lancet*, https://doi.org/10.1016/S0140-6736(24)00757-8. Incidence, prevalence, years lived
  with disability, disability-adjusted life years (DALYs) for 371 causes in 204 countries, 1990–2021.
  *Maps:* calibration of the relative sizes and frequencies of harms by cause (a hazard catalogue
  with rates per being-year), and of the split between passing harm (years lived with disability)
  and irreparable harm (years of life lost); a noise range for `hazard_size` and `p_hazard`.
  *Access:* free registration, non-commercial licence. *Caveats:* modelled estimates (IHME's own
  metric models, with uncertainty intervals); DALYs weigh health, not understanding or happiness;
  disability weights are elicited preferences, which Benefuture does not read.
- **WHO Global Health Estimates**, https://www.who.int/data/global-health-estimates. Deaths and DALYs
  by cause, age and sex. An independent second estimate to set beside GBD: their disagreement is a
  model-pool spread in itself.
- **EM-DAT, the international disaster database**, https://www.emdat.be/. Over 26,000 mass disasters
  since 1900 with deaths, affected people and damage. *Maps:* calibration of catastrophe frequency
  and the heavy tail of their size (`shock(:catastrophe)`, `hazard_share` for rare large events),
  noise range for black swans (M3f). *Access:* free for non-commercial use with registration.
  *Caveats:* reporting thresholds and reporting rising over time.
- **Harvard Medical Practice Study**: Brennan et al. (1991), "Incidence of adverse events and
  negligence in hospitalized patients", *NEJM*, https://doi.org/10.1056/NEJM199102073240604. Adverse
  events in about 3.7% of hospitalisations, about a quarter of them negligent. *Maps:* a
  calibration of side effects of actions in one domain: `p_side` (adverse events per action) and the
  share foreseeable (`p_foresee`, crime against accident by notice, L115). *Caveats:* 1984 New York
  records; a professional domain with strong reporting.
- **ILOSTAT, occupational safety and health**, https://ilostat.ilo.org/topics/safety-and-health-at-work/
  **[403]**. Occupational injury rates by country and sector. *Maps:* a second `p_side` calibration
  across domains (work as an action with side effects on the actor).
- **UCDP conflict data**, https://ucdp.uu.se/downloads/. Organised violence events and deaths
  worldwide since 1989. *Maps:* calibration of external aggressors for EHR (L117; `Governance.ExternalHarm`,
  not yet simulated). *Access:* CC BY 4.0 **[unverified]**.

## 4. Deaths and births (M7)

Simulation objects: the decision-time population and quantile floors (`floor_quantile`); the deaths
rung (`sim/test/m7_tests.jl`); births pending (8.52: models predict the newborn's trajectory, birth
escrow for the shortfall).

- **UN World Population Prospects 2024**, https://population.un.org/wpp/. Estimates and projections
  for 237 countries and areas, 1950–2100: life tables, age-specific fertility, births, deaths,
  migration. *Maps:* calibration of age-specific death hazards and fertility for M7, replacing the
  fixed population; validation of the population pyramid a run produces. *Access:* CC BY 3.0 IGO
  (per third-party metadata records **[unverified]** against the UN page); CSV downloads (the
  `downloads` page did not answer the automated check). *Caveats:* modelled, smoothed estimates.
- **Human Mortality Database**, https://www.mortality.org/, and **Human Fertility Database**,
  https://www.humanfertility.org/. Detailed period and cohort life tables and fertility for about 40
  countries with complete vital registration. *Maps:* the high-quality subset for calibrating
  hazards by age and their trend; cohort data for births by parental age. *Access:* free
  registration; licence to check **[unverified]**.
- *Caveat for both:* death hazards depend on understanding and happiness only through causes the
  simulation does not model; the first use is a demographic backdrop, not a mechanism.

## 5. Teaching reception (M7)

Simulation objects: a lesson's share of the teacher's lead `ε` (set per run, 0.3 in the readings;
0–0.6), learners' reception scatter `reception_σ` (0.5; 0–1.5), class size `class` (10, not yet set),
lessons a teacher offers `lessons` (3, not yet set); `teaching_plan` (`sim/src/m7.jl`).

- **Chetty, Friedman & Rockoff (2014)**, "Measuring the impacts of teachers I/II", *AER*,
  https://doi.org/10.1257/aer.104.9.2593 and https://doi.org/10.1257/aer.104.9.2633. Teacher
  value-added from US district records: one standard deviation of teacher quality moves test scores
  by roughly a tenth of a standard deviation in a year, with lasting effects on adult earnings.
  *Maps:* calibration of the spread of teachers' effects (a teacher-level multiplier on `ε`) and a
  validation target (teaching's long-run effect on later outcomes). *Access:* the paper; the
  administrative data are restricted. *Caveats:* test-score gains are a marker; value-added
  measures are themselves model outputs (with the bias debate the first paper addresses).
- **Kraft (2020)**, "Interpreting effect sizes of education interventions", *Educational
  Researcher*, https://doi.org/10.3102/0013189X20912798. Distribution of effect sizes in
  randomised education trials (median around 0.1 standard deviations on standardised tests) and
  benchmarks for small, medium and large. *Maps:* a noise range for `ε` once the simulation's
  learning gains are expressed in standard deviations of the population.
- **Nickow, Oreopoulos & Quan (2020)**, "The impressive effects of tutoring on PreK-12 learning",
  NBER w27476, https://www.nber.org/papers/w27476. Meta-analysis of randomised tutoring
  programmes (pooled effect around a third of a standard deviation). With **Bloom (1984)**, "The 2
  sigma problem", *Educational Researcher*, https://doi.org/10.3102/0013189X013006004, the classic
  (and larger, contested) tutoring estimate. *Maps:* how gains fall with class size: calibration of
  `class` against `ε`.
- **Tennessee STAR**: Krueger (1999), "Experimental estimates of education production functions",
  *QJE*, https://doi.org/10.1162/003355399556052. Randomised small classes (13–17 against 22–25)
  raised early scores by a few percentile points. *Maps:* a second class-size calibration.
- **Education Endowment Foundation Teaching and Learning Toolkit**,
  https://educationendowmentfoundation.org.uk/education-evidence/teaching-learning-toolkit.
  Meta-analytic summaries of about 30 approaches, in months of additional progress with evidence
  strength. *Maps:* the range of `ε` across kinds of lesson. *Caveats:* months of progress are a
  conversion of effect sizes; comparing approaches inherits the meta-analysis caveats below.
- **Hattie (2008), *Visible Learning***, https://doi.org/10.4324/9780203887332. A synthesis of
  hundreds of meta-analyses into effect sizes per influence (average around 0.4). With
  **Simpson (2017)**, "The misdirection of public policy: comparing and combining standardised effect
  sizes", *J. Education Policy*, https://doi.org/10.1080/02680939.2017.1280183: effect sizes from
  different designs, samples and tests are not comparable, so the ranking is unreliable. *Maps:*
  context only; prefer Kraft's trial distribution.
- **ECLS-K** (section 1): within-classroom scatter of gains, the closest public calibration of
  `reception_σ`.

## 6. Research productivity and innovation (M7)

Simulation objects: `research_share` (governed, 0.1), `p_research` (0.05; 0.01–0.2), `research_σ`
(1; 0.5–2), `research_gain` (2; 0.5–5), `p_teachable` (0.5; 0–1), `research_cost`, in-job innovation
`p_innovate` (0.01; 0–0.05) with its steep rise near the top ((u − median)/(peak − median))⁴, the
chance of success rising as (u / peak)² × novelty.

- **Bloom, Jones, Van Reenen & Webb (2020)**, "Are ideas getting harder to find?", *AER*,
  https://doi.org/10.1257/aer.20180338. Research productivity (output growth per effective
  researcher) falls steeply in every case studied: Moore's law needs many times the researchers of
  the early 1970s; crop yields and medical research likewise. *Maps:* validation target for the
  frontier's response to research spending (diminishing returns), which the simulation's constant
  `p_research` lacks; calibration of a declining chance per researcher as the frontier rises.
- **OECD Main Science and Technology Indicators**,
  https://www.oecd.org/en/data/datasets/main-science-and-technology-indicators.html **[403]**; **UNESCO
  Institute for Statistics**, https://uis.unesco.org/. R&D spending as a share of GDP (around 2–3% in
  the OECD) and researchers per thousand employed. *Maps:* a comparison for `research_share`: the
  simulation's uplift optimum near a fifth of time (8.49) is far above real research shares, which
  says the toy's research stands for more than formal R&D (all learning beyond the frontier) or
  that its chances are too high. A validation question, not a calibration.
- **Sinatra, Wang, Deville, Song & Barabási (2016)**, "Quantifying the evolution of individual
  scientific impact", *Science*, https://doi.org/10.1126/science.aaf5239. A scientist's
  highest-impact work falls at random within the sequence of their work (the random-impact rule),
  scaled by a stable personal factor. *Maps:* a check on the simulation's success chance rising with
  the researcher's level ((u / peak)²): the data suggest a personal multiplier and no career-stage
  effect, closer to the `novelty` trait.
- **Uzzi, Mukherjee, Stringer & Jones (2013)**, "Atypical combinations and scientific impact",
  *Science*, https://doi.org/10.1126/science.1240474; **Park, Leahey & Funk (2023)**, "Papers and
  patents are becoming less disruptive over time", *Nature*, https://doi.org/10.1038/s41586-022-05543-x.
  Novelty as atypical combinations raises the chance of a hit; disruption has declined. *Maps:* the
  `novelty` trait and its trend; `research_gain`'s heavy tail.
- **OpenAlex**, https://openalex.org/. An open catalogue of about 250 million scholarly works with
  authors, institutions, concepts and citations. *Maps:* calibration of output per researcher and
  the distribution of gains (citations as a marker of uptake: teachable gains are cited, tacit ones
  are not); domain formation (new concepts appearing). *Access:* CC0, API and snapshots. *Size:*
  hundreds of GB. *Caveats:* citations are a marker of attention, not of understanding added.
- **PatentsView** (USPTO), https://patentsview.org/; tables at
  https://patentsview.org/download/data-download-tables; USPTO Open Data Portal,
  https://data.uspto.gov/ (the older bulk site, bulkdata.uspto.gov, was **[unreachable]**). US patents
  since 1976 with inventors, assignees, classes and citations. *Maps:* in-job innovation rarity
  (`p_innovate`): inventors per worker by occupation and firm; how concentrated invention is near the
  top of a field; patent classes as a domain network with formation of new classes. *Access:* CC BY
  4.0 **[unverified]**. *Caveats:* patents mark appropriable invention only.
- **Bell, Chetty, Jaravel, Petkova & Van Reenen (2019)**, "Who becomes an inventor in America? The
  importance of exposure to innovation", *QJE*, https://doi.org/10.1093/qje/qjy028. Invention is
  concentrated among those with top childhood maths scores, yet exposure (parents, neighbourhood)
  changes rates sharply. *Maps:* a validation of the steep rise of `p_innovate` near the top, and of
  teaching (exposure) raising it.
- **Kogan, Papanikolaou, Seru & Stoffman (2017)**, "Technological innovation, resource allocation,
  and growth", *QJE*, https://doi.org/10.1093/qje/qjw040. Patent values from stock-market reactions,
  very skewed. *Maps:* the tail of `research_gain`.
- **Eurostat Community Innovation Survey**, https://ec.europa.eu/eurostat/web/science-technology-innovation/database.
  Share of firms introducing innovations, by sector and country. *Maps:* the prevalence of in-job
  innovation at firm level, an upper bound on `p_innovate`.

## 7. Metric models and forecasters: accuracy, pools, takeover

Simulation objects: model error by level (`σ_leaf`, `σ_branch`, `σ_coarse`; relative to the domain's
spread), `bias_σ`, scoring window `window`, accuracy and credence (`credence_accuracy_ref`),
status bars (0.9 / 0.75 / 0.55), the model-pool world assumptions (`p_new_model`, `improve_drift`,
`improve_σ`, `scale_min`, `pool_max`), takeover by `select_candidate_ref` with `model_z`;
in governance, models' published readings (`model_σ0`).

- **COVID-19 Forecast Hub**, https://covid19forecasthub.org/ (repository
  https://github.com/reichlab/covid19-forecast-hub, which answered 403 to the automated web check but
  exists by `git ls-remote`); **Cramer et al. (2022)**, "Evaluation of individual and ensemble
  probabilistic forecasts of COVID-19 mortality in the United States", *PNAS*,
  https://doi.org/10.1073/pnas.2113561119. Dozens of teams' weekly probabilistic forecasts, scored
  against outcomes, with models joining and leaving over time; the ensemble was the most consistently
  accurate while individual models' ranks changed. *Maps:* the best public calibration of the
  model-pool assumptions: arrival rate of new models (`p_new_model`), their accuracy relative to the
  incumbent (`improve_drift`, `improve_σ`), and turnover of the best model; validation of takeover
  dynamics (8.42.2) and of ensembles against single best models. *Access:* open repository; licences
  per team. *Size:* millions of forecast rows. *Caveats:* one domain under a non-stationary shock.
- **M4 Competition**: Makridakis, Spiliotis & Assimakopoulos (2020), "The M4 Competition: 100,000
  time series and 61 forecasting methods", *Int. J. Forecasting*,
  https://doi.org/10.1016/j.ijforecast.2019.04.014. Combinations and hybrids beat pure methods.
  *Maps:* the spread of accuracy across a model pool on identical tasks, a noise range for model
  error by level; a check on whether a pool should price by its single top model (L82) or a
  combination.
- **Good Judgment Project data**, Harvard Dataverse, https://doi.org/10.7910/DVN/BPCDH5 (resolves;
  the Dataverse page answered 202); **Mellers et al. (2014)**, "Psychological strategies for winning a
  geopolitical forecasting tournament", *Psychological Science*,
  https://doi.org/10.1177/0956797614524255. Several hundred thousand forecasts by thousands of
  forecasters on geopolitical questions (2011–2015), with training, teaming and tracking
  experiments; a small group of superforecasters stayed accurate year to year. *Maps:* calibration
  of forecasters' skill distribution and persistence (track records, 8.29); Brier scores to set
  credence accuracy ranges; validation of reputation by track record (people, not models).
  *Access:* open **[unverified: terms]**.
- **Metaculus**, API https://www.metaculus.com/api/ (track-record page **[403]**). Community and
  individual probabilistic forecasts on resolved questions. *Maps:* calibration curves and the
  accuracy of an aggregate against individuals; questions as decisions whose outcome becomes
  apparent (`p_apparent`). *Access:* API under terms of use. *Caveats:* self-selected questions.
- **Prediction markets**: Polymarket, https://docs.polymarket.com/ (trades on a public chain plus an
  API); Kalshi, https://docs.kalshi.com/ (API with historical markets); PredictIt,
  https://www.predictit.org/ (current market data public; historical data by academic arrangement
  **[unverified]**); Iowa Electronic Markets, https://iem.uiowa.edu/iem/ (price histories since
  1988). *Maps:* market prices as credences, scored against resolutions: calibration of how far
  money-weighted credences beat individuals, a comparison for escrow by credence (L84). *Caveats:*
  thin markets, fees and position limits distort prices; markets are the decision-market setting
  (`docs/SOTA.md`, prediction markets) only where prices decide actions.
- **Survey of Professional Forecasters** (Philadelphia Fed),
  https://www.philadelphiafed.org/surveys-and-data/real-time-data-research/survey-of-professional-forecasters.
  Quarterly macroeconomic forecasts by a panel since 1968. *Maps:* a long panel of individual
  forecasters for persistence of skill and for `bias_σ` (systematic individual biases).
- **ForecastBench**: Karger et al. (2024), "ForecastBench: a dynamic benchmark of AI forecasting
  capabilities", https://arxiv.org/abs/2409.19839. Machine-learning models and humans on the same
  questions, refreshed over time. *Maps:* the improvement rate of machine forecasters
  (`improve_drift`) in a domain where better models do arrive.

## 8. Reputation ledgers

Simulation objects: per-domain ledgers (hPos, hNeg, relevance with `λpos` 0.05, `λneg` 0.02; L100–L101),
no halo, recount from memory (`recount`), domain network (leaves, parents, μ learnt at `μ_rate`;
formation `form_count`, `form_radius`; `n_learn` not yet set), track records (`track_window`),
normalised reputation in votes (8.22).

- **Stack Exchange data dump**: official dumps by logged-in download since July 2024
  (https://stackoverflow.com/help/data-dumps); archived copies at https://archive.org/details/stackexchange
  (to 2024) and a community re-upload, https://archive.org/details/stackexchange_20251231;
  Stack Exchange Data Explorer, https://data.stackexchange.com/ **[403]**. Every post, vote, comment,
  edit, accepted answer, badge and tag for about 180 sites. *Maps:* the richest public analogue of
  domain-specific reputation: tags as leaf domains and sites as parents (μ from tag co-occurrence,
  formation from new tags); votes and accepted answers as measured outcomes; per-user reputation
  per tag recomputed from the log (validation of the recount and of decay rates); how far reputation
  in one site predicts quality in another (the no-halo isolation, B10); edit and close votes as
  audits. Calibration of agents' skill heterogeneity per domain and of `n_learn`. *Licence:* CC BY-SA
  (2.5, 3.0 or 4.0 by date of contribution); the 2024 download terms add restrictions contested as
  incompatible with the licence. *Size:* tens of GB compressed. *Caveats:* site reputation is
  cumulative votes, not Benefuture's relevance; voting is an output with its own biases (early
  answers favoured); since 2023 activity has fallen.
- **Movshovitz-Attias et al. (2013)**, "Analysis of the reputation system and user contributions on
  a question answering website: StackOverflow", ASONAM, https://doi.org/10.1145/2492517.2500242. A
  small share of high-reputation users contributes most answers. *Maps:* validation of the
  concentration of reputation a run produces (with overflow's Gini readings, `sim/README.md` M5).
- **World Inequality Database**, https://wid.world/. Income and wealth shares by country. *Maps:*
  a comparison for the balance Gini the overflow parameters produce (M5 readings) and for
  `endowment` (not yet set). *Caveats:* currency balances are not wealth.

## 9. Audit, monitoring, deception and repair (AdvAp)

Simulation objects: deception `deceit`, laundering `launder`, frivolous reporting `frivolous`;
readers' `vigilance` (0.05; 0.01–0.3), `pattern_attention`, `stake_attention`, `audit_cost`; tracing
`p_trace` (0.5; 0.1–0.9), false conviction `p_false_trace` (0.01; 0–0.1); AdvAp reward share
`adv_share` (governed, 0.1) and floor; outages and late re-measurement (`remeasure_σ`).

- **Wikipedia edit and revert history**: dumps at https://dumps.wikimedia.org/; the MediaWiki history
  dataset with revert flags at https://dumps.wikimedia.org/other/mediawiki_history/. Every edit to
  every page with reverts identified. *Maps:* the cleanest public audit log: share of edits that are
  vandalism (deception base rate), time to revert (detection lag: `vigilance` and its attention to
  patterns), reverts of good-faith edits (`p_false_trace`), repair of falsified records (Justice's
  "correcting the records a deception falsified"). *Access:* CC BY-SA. *Size:* terabytes for the
  full history; a single language edition's history dataset is manageable.
- **Geiger & Halfaker (2013)**, "When the levee breaks: without bots, what happens to Wikipedia's
  quality control processes?", WikiSym, https://doi.org/10.1145/2491055.2491061. When the main
  anti-vandalism bot went down, reverts slowed (roughly doubled in time) but humans caught most
  vandalism. *Maps:* a natural experiment matching the measurement outage (M3f): validation of
  "work continues, detection is late, repair follows when monitoring returns" (8.26.5).
- **Halfaker, Geiger, Morgan & Riedl (2013)**, "The rise and decline of an open collaboration
  system", *American Behavioral Scientist*, https://doi.org/10.1177/0002764212469365. Automated and
  strict quality control rejected good-faith newcomers and drove retention down. *Maps:* the cost of
  false positives in audits (`p_false_trace`) on participation, an effect the simulation does not
  model (agents never leave).
- **PAN Wikipedia vandalism corpus (PAN-WVC-10)**, https://webis.de/data/pan-wvc-10.html. About
  32,000 edits labelled by crowd annotators. *Maps:* a labelled set to estimate detection accuracy
  (the audit's significance test against ground truth).
- **Kittur, Suh, Pendleton & Chi (2007)**, "He says, she says: conflict and coordination in
  Wikipedia", CHI, https://doi.org/10.1145/1240624.1240698. Growth of coordination and conflict work.
  *Maps:* the overhead share of monitoring (`audit_cost` relative to work).
- **Retraction Watch database**, now open through Crossref:
  https://www.crossref.org/blog/news-crossref-and-retraction-watch/, data at
  https://gitlab.com/crossref/retraction-watch-data; user guide
  https://retractionwatch.com/retraction-watch-database-user-guide/. Over 50,000 retractions with
  reasons and dates. *Maps:* uncovered deception: time from publication to retraction (detection lag
  in a domain with weak vigilance), the share for misconduct against error (crime against accident),
  repeat offenders (ledger patterns). *Access:* open (licence to check **[unverified]**).
  *Caveats:* only detected cases: the base rate of deception is not in it.
- **Fang, Steen & Casadevall (2012)**, "Misconduct accounts for the majority of retracted
  scientific publications", *PNAS*, https://doi.org/10.1073/pnas.1212247109. About two thirds of
  retractions were for misconduct. **Fanelli (2009)**, "How many scientists fabricate and falsify
  research?", *PLoS ONE*, https://doi.org/10.1371/journal.pone.0005738: about 2% admit fabrication or
  falsification, far more report colleagues doing it. Together: a base rate (`deceit` prevalence) and
  a detection share (retractions against prevalence), a range for `p_trace` in science.
- **Azoulay, Furman, Krieger & Murray (2015)**, "Retractions", *REStat*,
  https://doi.org/10.1162/REST_a_00469; **Azoulay, Bonatti & Krieger (2017)**, "The career effects of
  scandal: evidence from scientific retractions", *Research Policy*,
  https://doi.org/10.1016/j.respol.2017.07.003. Retractions lower citations to related work in the
  field, and misconduct costs authors' prior work more than honest error. *Maps:* validation of
  reputation consequences by kind (ledgers recording deception apart from mistakes, 8.42.1), and a
  caution: the real world spills a retraction's penalty onto neighbours (a horn effect the corpus
  forbids, L101).
- **Kleven et al. (2011)**, "Unwilling or unable to cheat? Evidence from a tax audit experiment in
  Denmark", *Econometrica*, https://doi.org/10.3982/ECTA9113; IRS tax gap estimates from random
  audits, https://www.irs.gov/statistics/irs-the-tax-gap. Evasion is near zero where income is
  reported by third parties and substantial where it is self-reported; audits deter. *Maps:* the
  strongest real support for reading outputs measured by others rather than claims: calibration of
  `deceit` by whether a domain's markers are self-reported, and of deterrence by audit chance.
- **Dyck, Morse & Zingales (2010)**, "Who blows the whistle on corporate fraud?", *J. Finance*,
  https://doi.org/10.1111/j.1540-6261.2010.01614.x; **Dyck, Morse & Zingales (2023)**, "How pervasive
  is corporate fraud?", *Review of Accounting Studies*, https://doi.org/10.1007/s11142-022-09738-5.
  Fraud is mostly revealed by employees, media and others outside the formal monitors, more where
  revealing pays; only about a third of corporate fraud is detected. *Maps:* calibration of
  `p_trace` and of who reads records (`vigilance` by stake); validation of AdvAp's premise that
  rewarded revelation raises detection.
- **SEC whistleblower programme**, https://www.sec.gov/whistleblower: awards of 10–30% of sanctions
  above $1 million, annual reports to Congress. **False Claims Act** statistics (DOJ),
  https://www.justice.gov/civil/false-claims-act: qui tam relators receive 15–30% of recoveries.
  *Maps:* real reward shares for revelation, against the governed `adv_share` (0.1); the relation of
  reward to tips and recoveries is a validation of "reward greater than exploit raises revelation"
  (L160). *Caveats:* rewards follow sanctions, after long delays.
- **Studdert et al. (2006)**, "Claims, errors, and compensation payments in medical malpractice
  litigation", *NEJM*, https://doi.org/10.1056/NEJMsa054479. Reviewed claims: a few per cent involved
  no injury and over a third no error; most error-free claims went unpaid, a minority were paid.
  *Maps:* a calibration of `p_false_trace` (examinations wrongly establishing fault) and of dispute
  resolution's accuracy (L96 `DisputeResolution(J)`).

## 10. Deliberation, contention and echoes

Simulation objects: voters' contacts `n_contacts` (5; 0–20), `p_novel` (0.05), information handling's
ContentionMap (L133), `camp_bias` (0; 0–2), source weights by record (`source_weight_ref`), the echo
finding (8.45), `p_apparent` (0.7; 0.2–1).

- **X Community Notes public data**, https://communitynotes.x.com/guide/en/under-the-hood/download-data
  **[unreachable]** (algorithm repository https://github.com/twitter/communitynotes exists by
  `git ls-remote`); **Wojcik et al. (2022)**, "Birdwatch: crowd wisdom and bridging algorithms can
  inform understanding and reduce the spread of misinformation", https://arxiv.org/abs/2210.15723;
  **Slaughter et al. (2025)**, "Community notes reduce engagement with and diffusion of false
  information online", *PNAS*, https://doi.org/10.1073/pnas.2503413122. Every note and rating with
  status history; notes shown only when raters who usually disagree agree (bridging). *Maps:* the
  largest public record of contention among raters: calibration of `camp_bias` (raters' systematic
  leans from the matrix factorisation's factor), of how often a contested claim reaches agreement,
  and of correction's effect on spread; validation of the ContentionMap's design (surfacing reputable
  sources on both sides) against bridging. *Access:* daily TSV files under X's terms
  **[unverified]**. *Caveats:* raters self-select; the algorithm shapes the data.
- **Polis open data**, https://github.com/compdemocracy/openData (exists by `git ls-remote`; the web
  page answered 403), project https://compdemocracy.org/ and https://pol.is/; **Small et al. (2021)**,
  "Polis: scaling deliberation by mapping high dimensional opinion spaces", *Recerca*,
  https://doi.org/10.6035/recerca.5516; **vTaiwan**, https://info.vtaiwan.tw/. Participants'
  agree/disagree votes on short statements, clustered into opinion groups with consensus
  statements. *Maps:* contention maps from real deliberations: number and size of camps, statements
  bridging them; calibration of `camp_bias` and the share of contested decisions. *Access:* CC BY 4.0
  (per secondary sources **[unverified]** against the repository). *Size:* a few dozen conversations.
- **Vosoughi, Roy & Aral (2018)**, "The spread of true and false news online", *Science*,
  https://doi.org/10.1126/science.aap9559. About 126,000 rumour cascades on Twitter, 2006–2017:
  falsehood spread farther, faster and deeper. *Maps:* validation for M8 propagation and for the echo
  finding (one source's information counted many times). *Access:* data on request under platform
  terms. *Caveats:* **Juul & Ugander (2021)**, "Comparing information diffusion mechanisms by matching
  on cascade size", *PNAS*, https://doi.org/10.1073/pnas.2100786118, find most structural differences
  vanish once cascades are matched on size; **Goel, Anderson, Hofman & Watts (2016)**, "The
  structural virality of online diffusion", *Management Science*,
  https://doi.org/10.1287/mnsc.2015.2158: most cascades are tiny, and large ones range from broadcast
  to viral. Use the size distribution and structural virality as validation targets, not the
  true/false contrast alone.
- **Bakshy, Messing & Adamic (2015)**, "Exposure to ideologically diverse news and opinion on
  Facebook", *Science*, https://doi.org/10.1126/science.aaa1160; **Nyhan et al. (2023)**, "Like-minded
  sources on Facebook are prevalent but not polarizing", *Nature*,
  https://doi.org/10.1038/s41586-023-06297-w. Individual choice narrows exposure more than ranking;
  cutting like-minded exposure for months did not change attitudes. *Maps:* how homophilous contacts
  are (the fixed random network in M5 is a toy assumption) and a caution that exposure changes need
  not move votes.
- **Fishkin et al. (2021)**, "Is deliberation an antidote to extreme partisan polarization?
  Reflections on 'America in One Room'", *APSR*, https://doi.org/10.1017/S0003055421000642.
  Structured deliberation with balanced briefing moved participants away from extremes. *Maps:*
  validation for clean deliberation (Government, Clean Deliberation; 8.43–8.45).
- **SNAP network datasets**, https://snap.stanford.edu/data/. Social, communication and collaboration
  networks. *Maps:* realistic contact networks for M5 deliberation and M8 (degree distributions,
  clustering) in place of `n_contacts` random contacts.

## 11. Delegation behaviour

Simulation objects: `p_delegate` (battery factor, 0–1), delegation cap `cap` (governed, 0.05),
`impact_threshold` (0.5), audited delegation (`audit_window`, `audit_threshold`), concentration of
weight (largest share).

- **LiquidFeedback in the German Pirate Party**: Kling, Kunegis, Hartmann, Strohmaier & Staab
  (2015), "Voting behaviour and power in online democracy", ICWSM,
  https://doi.org/10.1609/icwsm.v9i1.14618, preprint https://arxiv.org/abs/1503.07723. Daily dumps of
  votes and delegations, 2010–2013: super-voters emerged with large theoretical power but mostly
  voted with the majority. *Maps:* calibration of delegation rates, delegation chains and
  concentration without a cap; validation of the cap's effect by counterfactual replay. *Access:*
  the dataset's public release is **[unverified]** (the party's instance was **[unreachable]**).
- **Google Votes**: Hardt & Lopes (2015), "Google Votes: a liquid democracy experiment on a corporate
  social network", Technical Disclosure Commons, https://www.tdcommons.org/dpubs_series/79. Internal
  liquid voting on low-stakes decisions. *Maps:* delegation rates in low-impact decisions (the
  `impact_threshold` regime). *Access:* paper only; no data.
- **On-chain and off-chain DAO governance**: Snapshot, https://docs.snapshot.box/ (public GraphQL API
  of off-chain votes); on-chain delegation of governance tokens (Compound, Uniswap and others);
  **Fritsch, Müller & Wattenhofer (2024)**, "Analyzing voting power in decentralized governance: who
  controls DAOs?", *Blockchain: Research and Applications*, https://doi.org/10.1016/j.bcra.2024.100208;
  **Feichtinger et al. (2023)**, "The hidden shortcomings of (D)AOs: an empirical study of on-chain
  governance", https://arxiv.org/abs/2302.12125. Large, fully public delegation graphs: a few
  delegates hold most voting power, turnout is low. *Maps:* the largest open source on uncapped
  delegation's concentration (validation for `Conj_DelegationDispersed` by replaying delegations under
  the cap) and on participation. *Caveats:* weight is bought with tokens, not earned as reputation;
  pseudonymous identities (Sybil-prone).
- **Berinsky et al. (2025)**, "Tracking truth with liquid democracy", *Management Science*,
  https://doi.org/10.1287/mnsc.2023.02470. Experiments fitting real delegation behaviour. *Maps:*
  calibration of whom people delegate to as a function of others' accuracy (a behavioural model in
  place of "delegate to the highest reputation under the cap").
- **International IDEA voter turnout database**, https://www.idea.int/data-tools/data/voter-turnout-database.
  Turnout in national elections worldwide. *Maps:* participation (`participation`, the duty to vote
  above a threshold, 8.46) as a world property.

## 12. Bounties

Simulation objects: AdvAp's reward and liability (`advap_reward_ref`, `advap_liability_ref`),
bounty farming (planting a flaw and reporting it, Lean `anti_cobra_effect_no_bounty_farming`);
bounties on planted flaws not yet simulated.

- **HackerOne disclosed reports (Hacktivity)**, https://hackerone.com/hacktivity; **Maillart, Zhao,
  Grossklags & Chuang (2017)**, "Given enough eyeballs, all bugs are shallow? Revisiting Eric Raymond
  with bug bounty programs", *J. Cybersecurity*, https://doi.org/10.1093/cybsec/tyx008; **Zhao,
  Grossklags & Liu (2015)**, "An empirical study of web vulnerability discovery ecosystems", CCS,
  https://doi.org/10.1145/2810103.2813704. Publicly disclosed vulnerability reports with bounties;
  researchers flock to newly launched programmes and returns per programme diminish. *Maps:*
  calibration of report rates against reward size (AdvAp's response to `adv_share`), of the decline
  of findings as a system is audited, and of duplicate and invalid reports (`frivolous`); validation of
  "reward above exploit raises revelation". *Access:* public web listings; bulk scraping under the
  platform's terms; community datasets **[unverified]**. *Caveats:* disclosed reports are a selected
  minority.
- **Finifter, Akhawe & Wagner (2013)**, "An empirical study of vulnerability rewards programs",
  USENIX Security, https://www.usenix.org/conference/usenixsecurity13/technical-sessions/presentation/finifter.
  Chrome and Firefox programmes: rewards cost less than hiring and drew many outside reporters.
  *Maps:* the cost of AdvAp relative to internal monitoring (`audit_cost`).

## 13. Commons governance and resources

Simulation objects: the commons (resource costs paid less repair spending, 8.26.7 [OPEN]), the
single resource stock (`capacity`, `regen`, `regen_σ`, `cost_per_touch`, `cost_σ`), unassigned
harm insured through the commons.

- **Ostrom's CPR and design-principle data**: **Cox, Arnold & Villamayor Tomás (2010)**, "A review of
  design principles for community-based natural resource management", *Ecology and Society*,
  https://doi.org/10.5751/es-03704-150438 (91 studies, principles broadly supported); **Baggio et al.
  (2016)**, "Explaining success and failure in the commons: the configural nature of Ostrom's
  institutional design principles", *Int. J. of the Commons*, https://doi.org/10.18352/ijc.634
  (no single principle suffices; combinations do). *Maps:* validation of the institutional
  configurations a run converges under (`docs/OSTROM.md`).
- **SES Library**, https://seslibrary.asu.edu/ (certificate error on the automated check), and
  **SESMAD**, https://sesmad.dartmouth.edu/. Coded case studies of social-ecological systems.
  *Maps:* case-level validation (which principles present, outcome). *Caveats:* small n, coder
  judgement.
- **IFRI, International Forestry Resources and Institutions**,
  https://en.wikipedia.org/wiki/International_Forestry_Resources_and_Institutions (its own site was
  **[unreachable]**); the Ostrom Workshop, https://ostromworkshop.indiana.edu/. Forest sites in
  over a dozen countries since 1992 with institutions, monitoring and forest condition. *Maps:*
  calibration of monitoring and sanctioning against resource condition. *Access:* by request to the
  network **[unverified]**.
- **RAM Legacy Stock Assessment Database**, https://www.ramlegacy.org/. Biomass, catch and
  reference points for hundreds of fish stocks. *Maps:* calibration of `regen` and `regen_σ` (surplus
  production and its variability), the only resource-regeneration noise range from data here; with
  **Costello, Gaines & Lynham (2008)**, "Can catch shares prevent fisheries collapse?", *Science*,
  https://doi.org/10.1126/science.1159478, validation that accounting for use (individual quotas)
  slows collapse, the role of resource accounting (L83).

## 14. Currency uptake

Simulation objects: the score-only start (`init_steps`, Implementation Phase 1), currencies
qualifying (status bars), agents' `endowment` (not yet set), StandCoin's lane; a phased rollout
(L140) not yet simulated.

- **Suri & Jack (2016)**, "The long-run poverty and gender impacts of mobile money", *Science*,
  https://doi.org/10.1126/science.aah5309; **Jack & Suri (2014)**, "Risk sharing and transactions
  costs: evidence from Kenya's mobile money revolution", *AER*, https://doi.org/10.1257/aer.104.1.183.
  M-Pesa spread to most Kenyan households within a few years; access lifted an estimated 2% of
  households out of poverty, more for female-headed ones; users smoothed consumption against shocks.
  *Maps:* calibration of an adoption curve for a voluntary currency (the phased rollout) and
  validation of uptake driven by utility for the worst-off (the floors). *Caveats:* a payment rail
  in an existing currency, not a new unit of account.
- **World Bank Global Findex**, https://www.worldbank.org/en/publication/globalfindex. Account and
  mobile-money ownership by country and demographic group, every three or four years since 2011.
  *Maps:* cross-country adoption curves. *Access:* CC BY 4.0 **[unverified]**.
- **Pix** (Banco Central do Brasil), https://www.bcb.gov.br/en/financialstability/pix_en. Instant
  payments adopted by most Brazilian adults within about two years of launch in 2020, with monthly
  statistics. *Maps:* a fast, state-backed uptake curve to contrast with M-Pesa.
- **Bass (1969)**, "A new product growth model for consumer durables", *Management Science*,
  https://doi.org/10.1287/mnsc.15.5.215. The standard diffusion model (innovation and imitation
  coefficients), to fit to the curves above and to compare with a run's uptake.
- **Complementary and local currencies**: the Complementary Currency Resource Center database
  **[unverified]** (https://www.complementarycurrency.org/ reset the connection). Records of local
  and time currencies, most of which stall: a validation target for currencies that never qualify.

## 15. Noise ranges marked "not yet set"

From `sim/README.md` (Noise). Each row names the data that could set it; none can be set without
fixing the simulation's units first (section 1, Proxy validity).

| Parameter | Data |
|---|---|
| `hazard_share`, `hazard_size` | GBD incidence and DALYs per cause (share of a population hit per event, harm per being); EM-DAT for rare large events |
| `side_share`, `side_size` | Harvard Medical Practice Study (adverse events per hospitalisation, severity); ILOSTAT injuries per worker |
| `p_upstream`, `β_upstream` | OpenAlex and PatentsView citations (share of works building on a recent one, the cited work's share of value; with Kogan et al. values); Stack Exchange answers linking earlier ones |
| `n_learn` | COVID-19 Forecast Hub and Metaculus (records a new model or forecaster needs before its accuracy settles); Stack Exchange new tags |
| `endowment` | World Inequality Database (initial distribution); Global Findex (starting balances in mobile money) |
| `ToyParams.touch`, `ToyParams.shift` | GBD and EEF effect distributions (share of a population an intervention reaches, scatter of mean effects); Kraft (2020) |
| `class`, `lessons` | STAR, Nickow et al. (class size against gain); ECLS-K (teachers per learner) |
| `skill_gain`, `trial_units` | Good Judgment Project (how skill sharpens a forecaster's signal); Polis and vTaiwan (locales a decision applies to) |
| `vigilance` (range set, base rate not) | Wikipedia revert latency; Dyck–Morse–Zingales detection shares |

---

## Prioritised plan

Each pick names its rung, its role and the toy assumption it would retire. Order is by how much a
dataset constrains what the simulation currently invents, and how directly it maps.

1. **Model pools: COVID-19 Forecast Hub, with M4 as a cross-check** (M3c economy and M5 governance;
   calibration). Set `p_new_model`, `improve_drift`, `improve_σ` and `scale_min` from the arrival and
   relative accuracy of real forecasting teams, and model error by level from real spreads; then
   *validate* (held out) the turnover of the best model and the ensemble-against-best comparison.
   Retires the toy assumptions "model noise by σ" and "better models arrive at an invented rate"
   (8.42.2), the two most consequential assumptions behind the eligibility cliff (8.32).
2. **Domain reputation: the Stack Exchange dump** (M3–M3c; calibration then validation). Build a real
   domain network (tags as leaves, sites as parents, μ from co-occurrence), calibrate per-domain skill
   heterogeneity and `n_learn`, then validate the recount, the decay rates' effect on how well
   relevance tracks later answer quality, and no-halo isolation across sites. Retires "fixed agents
   and skills" drawn from uniform ranges and "signature axes" as the domain geometry.
3. **Audit and repair: Wikipedia edit/revert history, with Geiger–Halfaker's outage** (M3f and M6
   AdvAp; noise ranges then validation). Set `vigilance`, detection lag, `p_false_trace` and the
   deception base rate from vandalism and reverts; validate the outage reading (late detection, repair
   on return) against the bot outage. Retires readers' vigilance as a constant and the invented
   false-conviction rate. Retraction Watch with Fanelli and Dyck–Morse–Zingales then gives a
   low-vigilance domain to test the same parameters out of sample.
4. **Teaching: Chetty–Friedman–Rockoff, Kraft, Nickow et al., ECLS-K** (M7; calibration). Express
   lesson gains in standard deviations of the population and set `ε`, `reception_σ`, `class` and a
   spread of teacher quality. Retires "ε set per run" and the uniform teacher. Validation target:
   long-run effects of teaching on later levels.
5. **Population: UN WPP and the Human Mortality Database, with GBD** (M7 births and deaths;
   calibration). Age-specific death hazards and fertility for the births rung (8.52), and GBD's
   split of passing against irreparable harm for `irreparable_loss`. Retires "fixed population" and
   "every loss is passing harm".

Later: delegation (DAO graphs and LiquidFeedback, if its data can be obtained) for the M5 pathology
suite (`docs/SOTA.md` action 3); Community Notes and Polis for contention (`camp_bias`); RAM Legacy
for resource regeneration once the commons balance (8.26.7) is ruled; M-Pesa, Findex and Pix for a
phased-rollout rung.

What none of this does: it cannot validate the Goal or the rules themselves. Data can make the
simulated world realistic and can show that the simulation reproduces patterns of today's
institutions where those share Benefuture's mechanism (reputation, audits, forecasting); whether
Benefuture's rules would do better in the world is a claim no dataset of today's world settles.
