# Benefuture Outset Design Principles

Core architectural, ethical, economic, and methodological invariants distilled from the rulings in
[`docs/BACKPROPAGATION.md`](BACKPROPAGATION.md). Checking every new specification, Lean module,
simulation world, or replay case against these invariants at the outset resolves most design questions
before an ad-hoc ruling is needed.

---

## I. Nine Generative Invariants

### 1. Radical Parsimony & Native Reuse ("Domains do what domains do")
* **Invariant:** Express every phenomenon through the existing substrate (`Rel ← Mem` → measurement →
  causal distribution → mint/burn) rather than bolting on special-case rules, separate ledgers, new
  fees, character scores, or ungranted exemptions. Duties (`8.24.2`), catastrophe repair and
  prevention (`8.26.1`), outages and sabotage (`8.30.1`), funding and attestations (`8.69`, `8.70`),
  slander (`8.82`), behavioural conduct (`8.96–8.97`), measurement chains (`8.107`), and meta-research
  (`8.132`) are ordinary actions, choices, or domains.
* **What breaks if violated:** Duplicate debiting across causal distribution and justice (`8.25`),
  unnecessary rule sets (`8.53`, `8.97`), and arbitrary leniency or exceptions that undermine
  ratified gates (`8.100`, `8.124`, `8.135`).

### 2. Epistemology: Outputs Only, Counterfactual, Double-Blind
* **Invariant:** Read **outputs only**; beliefs, intent, declared profiles, and stated confidence
  carry weight only as measured and calibrated against outcomes (`7.1`, `8.2–8.3`, `8.121`).
  * **Counterfactual attribution:** Credit only counterfactual value added (`As` against `¬A` or a
    committed mandate—never raw pass-through volume or replaceable intermediaries, `8.14–8.18`,
    `8.26.2`). Measure understanding operationally via the pragmatic equation net of irreducible
    uncertainty (`8.98`, `8.103`), and evaluate interventions on a `"predict - measure - adapt"` loop
    at their stated ETA with confidence grace (`8.134`).
  * **Double-blind convergence:** Never trust a single source or measurement chain (`8.107`).
    Correlated voices, echoes, and copies collapse to one source (*"twenty pieces of the same 1x
    knowledge are not one piece of 20x knowledge"*, `8.68`), while minority paradigms remain active
    and scored (`8.45`, `8.111`, `8.121–8.122`).
* **What breaks if violated:** Profile gaming (`8.2`), intermediaries taking half of Shapley value
  (`8.18`), zero understanding read on random processes (`8.103`), confident blocs capturing votes
  (`8.121`), echo amplification (`8.45`), and myopic rejection of long-horizon reforms (`8.134`).

### 3. Strict Firewalls & Conservation Across Scopes
* **Invariant:** Keep orthogonal quantities strictly separated and conserved:
  * **Money ≠ Reputation ≠ Votes:** Overflow auto-invests (`BalOvflw`) and earns reputation only if
    reinvestment causes measured good (`8.51`, `8.74/8.77`). Models and sources **inform**, never vote
    or take vote shares (`8.42.2`, `8.60`).
  * **Skill is domain-local (aggregates upward only); Honesty is global:** *"An expert baker can say
    to the minute when the bread comes out perfect and cannot say where a frisbee will turn."*
    Untested in a domain means unknown (`8.80`). Only systematic overstatement and miscalibration
    travel globally through the transactions/honesty domain (`8.78–8.79`, `8.95–8.97`).
  * **Non-decaying memory & absolute reputation:** Raw ledger entries never decay (`8.42.4`); only
    rolling nets decay (`λ₋ < λ₊`, time-adjusted to domain tempo, `8.29.1`, `8.85`). Normalise vote
    weights, never personal reputation (*"I have not done less if someone else has done more"*,
    `8.48`). Understanding is shared (never conserved/moved, `7.2`) and globally position-comparable,
    while happiness kinds are personal (`8.129`). Forks divide social power (`SoPo`); merges sum it
    (`8.34`, `§8.131`).
  * **Book once & tie currency to real `Rc/t`:** One outcome mints or burns once, split by share
    (`8.25.1`, `8.96`). All measured harm—including StandCoin-lane work (`8.67`) and chosen-risk
    deaths (`8.130`)—is logged and charged. Global resource accounting (`RA`) is an estimating domain
    that keeps issuance bound to deliverable resources and time (`8.27`, `8.133`).
* **What breaks if violated:** Halos/horns across domains (`8.79`), cashing in credibility across
  domains (`8.80`), wealth buying standing (`8.51`), sybil/fork allowances (`§8.131`), unpriced lane
  harm (`8.67`), and an unbacked *"vibe economy issuing checks it can't cash"* (`8.133`).

### 4. Tiered, Synergised & Long-Term Value — Never One Scalar
* **Invariant:** Represent `U`, `H`, `N`, and `Ha` through priority tiers, synergy (`0 ≤ λ ≤ 1`),
  threshold-normalised inputs (`≥ 1`), and context-dependent impact weights (`drag` vs. `seatbelt`,
  `1.1–1.6`, `8.117`, `8.129`). Evaluate harm and trajectories over the long-term window `Ha_lt`:
  happiness adapts and is transient while understanding compounds (`8.116`), meta levels compound on a
  governed bell curve (`8.131`), `U`-harm compares against running maximum (forgetting is harm), and
  `H`-harm compares against rolling average (coming down from a peak is not harm, `2.1`).
* **What breaks if violated:** Non-transferable happiness or trivial novelty outranking teachable meta
  understanding (`8.129`), one-step checks rejecting valid `NHa` tunnels (`4.3`) or permitting small
  sacrifices (`8.47`), and routine reversible learning dips treated like death (`8.125–8.126`).

### 5. Decision-Time Ethics: Zero Privilege for Inaction, Trolley & Fail-Loud
* **Invariant:** Benefuture ranks **actions over decision-time beings**, never hypothetical worlds
  (`4.1`, `8.86`).
  * **No status-quo privilege:** Inaction (`¬A`) is screened, blocked, and compared identically to any
    active option (`4.4`, `8.118`, `8.124`, `8.127`).
  * **Universal strong reading & uplift:** Forced additions and births are taken as given and uplifted
    (births via optimistic trajectory + causer escrow, `8.52`). No existing being is left worse off
    over `Ha_lt`, with compensated reforms priced as standard options (`8.100`) and loud fallback to
    combined floors when infeasible (`8.86`).
  * **Trolley & fail-loud:** Policy-level irreparable harm compares aggregate net expected harm across
    all options (`8.124`). When every option is blocked, **search for lateral options first, else
    choose least net expected harm, and log loudly** (`8.127`).
* **What breaks if violated:** Breeding/world-ranking paradoxes (`8.56`, `8.86`), status-quo veto of
  beneficial reforms (`8.99–8.100`), and silent default to a harmful inaction (`8.124`, `8.127`).

### 6. Extended Self & Mortality: Lifespan Bounds Experience, Never Legacy
* **Invariant:** Biological lifespan bounds only when direct harm can be experienced (`7.12`), never
  the horizon of intent, value, or accountability:
  1. **Extended self outlasts the being:** `Self«Sl»` spans `Ha_lt` and includes external things,
     works, and relations that persist beyond the being's lifespan (`7.12`, `Being`, `Morality`).
  2. **No financial inheritance; causal and ideological inheritance continue:** Property is not
     inherited (preventing dynastic wealth concentration), while posthumous causal distribution,
     reputation recounting, and ideological inheritance continue (`7.12`, `SIM_CONJECTURES.md` B25).
* **What breaks if violated:** Modelling mortal agents as finite-horizon players for whom end-of-life
  defection becomes rational once financial inheritance is absent (`B25`), or adding property
  inheritance to manufacture artificial continuity.

### 7. Freedom First: Report Constraints, Price Risk, Govern Thresholds, Ratchet Bars Up
* **Invariant:** Freedom is the default (`8.24.3`). `Fr` is reported rather than used as a hard
  pre-filter (`2.5`, `8.47`). Freely chosen personal risk is priced across the extended self rather than
  banned (`7.7`, `8.130`). Duties are minimal, governed, and originate only in contracts, communicated
  laws, or self-created hazards (`8.15`, `8.17.3`, `8.46`). Infohazards gate by recorded education,
  never owner approval (`7.6`). Adoption is voluntary and incentive-shaped (`8.30.3`, `8.42.4`).
  * **Governed thresholds & monotonic quality bars:** Every constant, schedule, window, and horizon is
    a governed threshold (`8.24.5`, `8.129`), adapted via experimental design (`SigThGv`, `8.22.3`).
    Quality bars compare against real domain alternatives (`8.41`), ratchet strictly upward on
    sustained evidence (`8.84`), and never lower under stress (`8.35.4`, `8.135`): models mature
    score-only before currency, continuous escrow grades trust, and fallbacks degrade loudly
    (`other qualified models → parent → lower credence → StandCoin`, `8.71`, `8.73`) with `RA`
    contracting if claims outrun capacity (`8.71`, `8.133`).
* **What breaks if violated:** Hard-coded magic constants, frozen rules on tragic choices (`2.5`),
  paternalistic bans on chosen risk (`8.130`), races to the bottom on eligibility (`8.35.4`), and
  absorbing economic stalls (`8.71`).

### 8. Adversarial Mechanism Design: Expect Exploits, Reward Defection, Protect Luck
* **Invariant:** Audit every rule before building for gaming via blind spots, outages, clones, echoes,
  forks, currency splitting, or artificial scarcity (`8.24.4`, `8.26.5`, `8.133`).
  * **Full restoration & cartel instability:** Uncovered lies trigger full causal repair of falsified
    records (`8.38.1`) and apply justice to every detected lie, including slander (`8.82`). Exploiters
    repay **all** market-wide harm caused (including price premiums on others' supply) plus detection
    and audit costs (`8.133`). Honest loophole reporting (`8.76`) and cartel defection (`8.133`,
    rewarded by co-conspirators while lone self-report of withholding earns zero) must dominate
    collusion.
  * **Protect luck, honest mistakes, and newcomers:** Escalate scrutiny/escrow only on consecutive
    significant signed overstatements—never raw noise or isolated errors, and never to permanent
    exclusion below the harm boundary (`8.91` + addendum). Admit newcomers at defined entry points
    with progressive rights (`8.72`).
* **What breaks if violated:** Unpunished outage sabotage (`8.26.5`), profitable supply cartels
  (`8.133`), lingering corrupted model scores (`8.38.1`), and false-positive exclusion of high-variance
  honest agents (`8.91`).

### 9. Build & Calibration Discipline ("Nothing is perfect, in the world or in the work")
* **Invariant:** Apply Benefuture's epistemology to developing Benefuture (`§8.86`, `8.33`):
  * **Fix the world model before questioning a ratified rule:** Weird tradeoffs or stalls usually trace
    to missing world dynamics (`happiness kinds`, `budget constraint`, `entry`, `warm-up length`) or an
    unexamined corpus equation (`L82`, `L103`), not a defective ratified rule (`8.73–8.74`, `8.129`,
    `8.133`, `8.135`, `L3.2–L3.4`).
  * **Separate policy knobs from world outcomes:** Behaviour, uptake, personal valuations, sparse
    expertise, and model arrival are noisy world properties measured from outputs, never clean control
    knobs (`8.90`, `8.129`, `8.132`).
  * **Rigour & loud failure:** Keep simulation rules 1:1 with Lean (`8.8e`) and viable at coarse,
    low-tech settings (`8.88`). Calibrate human invariants separately from emergent institutional rates
    (`8.63`), test against a calibrated status quo (`8.92`) at 10/20/100-year horizons with shocks
    (`8.64`), replay history as-of without curve-fitting (`8.87`), report sensitivity and rule batteries
    (`8.113`, `8.119`), re-run prior cases after rule changes (`8.129`), keep original runs visible
    beside reruns (`8.99`), and make degraded or refused states fail loud (`8.86`, `8.127`, `L3.2`).
* **What breaks if violated:** Tuning schedules to cover missing world models (`8.129`), strawman
  baselines (`8.92`), silent degradation, hindsight leakage (`8.87`), and 1-ULP seed fragility (`8.66`).

---

## II. Outset Pre-Build Checklist (11 Gates)

Verify every new rule, domain, Lean theorem, simulation world, or replay before implementation:

1. **Corpus & Native Reuse:** Does the pseudocode already specify this (`L82`, `L103`, `L133`), and can
   existing domains, ledgers, `As`/`Sy`/`CD`/`AdvAp` handle it with zero new mechanism?
2. **Math & Symbol Contract:** Are all subscripts named, weights matched to tier arities (`|Pm| = n`),
   inputs threshold-normalised (`≥ 1`), monotonicity bounds stated (`0 ≤ λ ≤ 1`), and distinct meanings
   given distinct symbols (`Di` vs. `Di_exp`)?
3. **Outputs & Estimator/Actuator Split:** Are all inputs read strictly from observable outputs, with
   estimators (e.g., `RA`) decoupled from actuators (`pricing`, `contraction`)?
4. **Governed Parameter vs. World Property:** Is each scalar explicitly classified as a governed
   threshold (`threshold`, `horizon`, `schedule`) or as a noisy world property/outcome (`uptake`,
   `personal H kinds`, `skill sparsity`, `model arrival`)?
5. **Scope & Firewall Integrity:** Are domain-local (`skill`, `bar`), upward-only (`parent ≥ Σ sub`),
   global (`honesty of claims`), individual vs. policy (`chosen risk` vs. `aggregate net harm`), and
   `money ≠ rep ≠ vote` boundaries enforced?
6. **Time & Reference Points:** Are references explicit (`running max` for `U`, `rolling avg` for `H`,
   committed vs. `¬A` counterfactuals), windows time-adjusted to domain rate (`8.85`), and decisions
   judged at their stated `Ha_lt` / `ETA + grace` horizon (`8.134`)?
7. **Extended Self & Mortality Boundary:** Does biological lifespan bound only *experienced harm*,
   while `Self«Sl»`, causal/reputation attribution, and ideological inheritance outlast the being with
   zero property inheritance (`7.12`, `B25`)?
8. **Conservation & Full Harm Accounting:** Is every outcome booked once (`no double debit`), tied to
   real `Rc/t`, inclusive of all measured harm (`lane`, `chosen risk`, `commons`), and conserved across
   forks/merges (`SoPo`)?
9. **Degradation & All-Blocked Fallback:** Is the fallback ladder explicit (`plural models → parent →
   lower credence → StandCoin → RA contraction`; `strong → floors`; `lateral search → trolley least
   harm`), and does every fallback log loudly?
10. **Adversarial & Error-Margin Check:** Have clones/echoes, sybils/forks, currency splitting,
    outages, and artificial scarcity been stress-tested—and are zero-mean noise, honest mistakes, and
    newcomers protected from unfair escalation?
11. **Validation Hygiene:** Is the baseline a calibrated real status quo (`8.92`), are seeds drawn to
    precision (`8.128`), are sensitivity and rule-battery checks run without post-hoc tuning, and did
    we audit the world model before changing a ratified rule?

---

## III. Genuinely Open Design Choices Remaining

Only these substantive design choices remain open in [`docs/BACKPROPAGATION.md`](BACKPROPAGATION.md):
* **Formula details (`§5.5–5.6`, `§8.26.7`):** Exact form of `EHR` forgiveness/overreaction,
  exponential vs. subtractive reputation decay / partition-of-unity scope, and how `RA` sets the
  commons' balance share.
* **Moral / risk boundary details (`§8.47`, `§8.123`):** Whether doing and allowing differ (trolley
  switch vs. footbridge/organ-harvest variants), and whether policy-level irreparable harm needs an
  absolute count bar beside per-being/net checks.
* **Cold-start stall (`L3.2–L3.4`):** How an economy starting with immature models breaks the
  `no currency → no funded work → no records → no currency` loop without lowering ratified quality
  bars (e.g., whether a minimum score-only phase or floor is required by rule).

