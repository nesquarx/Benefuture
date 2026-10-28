# Plan

Two parts, per `docs/CODING_STYLE.md` §7. Read Part 2 every turn; read Part 1 only when needed.

## Part 2: Direction and next steps

- **Ratify §7 of `docs/BACKPROPAGATION.md`.** Coherence edits applied to articles and pseudocode as [P].
- **Quantile floors in Lean.** Define the thresholded low quantile used by G's floors (L74) and prove `removal_cannot_raise_floor` for it: order statistics are monotone in each level, so the literal-minimum proof should generalise.
- **Domain-relative expertise.** Government proposes the expertise term relative within each domain; carry it into L113 and `Governance.Democracy`, or reject it.
- **Abbreviation sweep.** Articles spell out Benefuture's own abbreviations and symbols (common parlance and names are fine); earlier text still contains some (for example U/H, MM). Edited lines comply.
- **Simulation** (`sim/`, small increments, red first; rules in Lean, world in Julia; ladder, run lengths and noise ranges in `sim/README.md`). The outcome is a system of rules ready for implementation: the end state has no toy assumptions, absorbs messy reality, and replicates every aspect of the Lean specification and the pseudocode (each pseudocode line and Lean module either simulated or listed as not yet covered in `sim/README.md`). `README.md` (Claims) lists what is proved, by construction or demonstrated, with links and assumptions; it is updated with each increment. Done: M0, M1, first passes of M2, M3, M3b (flat) and M3c (the domain network of Ontology.Domain [R] with a score-only start, overlap degrees as long-term rolling averages, eligibility with a score-only phase for novel leaves, the screened StandCoin lane, novel leaves from blockages). Next:
  - **M3d, from proposals to transactions.** Steps (1)–(3) are done as a first pass (transactions quoted per currency, screened together by G, logged with their quotes); step (4) awaits the author's ruling on causal contribution (BACKPROPAGATION 8.13). Today G picks one plan a step from a menu, a central chooser. Bf has actors transact: every action is a transaction; each relevant currency's model generates a proposal with its price (TP_Gen, L86); the actor composes proposals within a timeout or by default (L88); every executed action and outcome is logged and triggers measurement (Mem, L145), building the behavioural transaction substrate. Steps: (1) a Lean `Transaction` and `TransactionProposal` reference mirroring `Economy.Currency`/`Economy.Pricing`, exported; (2) agents act on their own, each action a transaction with composed proposals (selective composition, as in the Benefuture currency discussion's logger); (3) G enters through prices and the floor check rather than a single argmax; (4) transaction trees: actions consume others' outputs, several contributors per outcome (co-funders of StandCoin work among them), causal contribution by traversal (L93) and causal distribution (L94); (5) the log as the source of everything else: reputation recount, μ, model scoring, CC.
  - **The score-only start.** Benefuture begins with a score-only phase (Implementation, Phase 1) in which a robust set of domains and metric models forms. M3c starts this way over a given bootstrap network; the end state grows the network itself during that phase.
  - **Graduation to Lean objects and to reality.** The end state is implementation-ready: no toy assumptions, every step robust to messy reality's noise. It models `Benefuture/` one to one: `LeafDomain`, `ParentDomain`, `MetricModel` (markers, accuracy, qualification), `Currency`, `TransactionProposal`, `Mem`. Each rung names the objects it approximates and the toy assumptions it still makes (today: signature axes, model noise by σ, one plan chosen by G per step, fixed agents and skills, a single outcome value per plan); each is replaced as the objects arrive.
  - **Governed thresholds.** Every gate value set in the simulation is listed in `sim/README.md` (Governed thresholds) for M4–M5 to govern.
  - **Noise in every step**, with realistic ranges (`sim/README.md`); sweep once the model is solid.
  - Then M4 thresholds, M5 governance, M6 malicious and gaming agents, M7 population, M8 networks and propagation. Rules to export as rungs need them: causal distribution, democracy, delegation cap, SigThGv, harm tiers, freedom, population, EHR, distribution term D. Speed: batch rules into whole-plan Lean calls when runs grow. Then `SimTrace` and the conjectures, including B20–B25.
- **Wiki.** Create the Morality, Art and Freedom pages on the wiki by hand (the sync tool cannot create pages), then add it to `docs/articles/_manifest.json` from a fresh fetch.
- **Open readings.** EHR (BACKPROPAGATION 5.5); reputation decay form and partition of unity (5.6); end-of-horizon conduct (B25).

## Part 1: Done

- Lean 4 specification of the pseudocode with invariants and sanity lemmas; behavioural claims as conjectures over `SimTrace`; Float reference library and JSON test vectors.
- Population direction: staged G, counterfactual floors, assessed distribution term, Pigou–Dalton for H, U shared rather than moved (`u_sharing_gain_nonneg`).
- Coherence audit against the articles: findings and applied edits in `docs/BACKPROPAGATION.md` §7; conjectures B20–B25.
- Self over the long-term window, causal and ideological inheritance, art success by spread of reception, debits for informed falsehood only (BACKPROPAGATION 7.12–7.13).
- Positioning line in Introduction (short) and Philosophy (full, glossed).
- Toy model M3c (domain network, first pass): Lean network rules (descent, fallback by μ, aggregate at parent, subsethood, accuracy, eligibility with a novel floor of 0.5, scarcity cost); learnt μ; StandCoin lane with co-funding; novel leaves from blockages; noise parameters for every step (`sim/README.md`). The strict-tree version it replaced found the overflow trade-off.
- Toy model M3 (domains, first pass): domain rules in Lean (partition of unity, attribution, decay by sign); payment, currency and reputation per domain, nothing crossing; fixed profiles cannot identify per-domain skill and invite profile gaming, so profiles must be measured (`sim/README.md`).
- Toy model M2 (first pass): agents with skill and sloppiness propose plans; escrow split by model confidence, settlement in Lean, reputation with decay; reputation tracks skill when agents are careful and carefulness when they are not (`sim/README.md`).
- Run-length study: burn-in 200 steps, rates over 500+, rare events over 1,000, ten seeds (`sim/README.md`); analysis utilities in `sim/src/analysis.jl`.
- Toy model M1: competing metric models with bias and noise scored against markers (Lean scoring and adoption rules); floors' guarantee degrades with measurement noise into harm or stagnation (BACKPROPAGATION 8.1).
- Toy model M0: fixed population, random plan menus, perfect measurement, G choosing through the Lean rules; floors rise exactly; peak of understanding pulls away from the median (`sim/README.md`).
- Lean–Julia bridge: rules computed by the Lean reference through C exports, rebuilt only when Lean sources change; Goal choice and floor quantile added to the reference; synergy, assessment, harm weight and value served through it.
- Local toolchains (`tools/setup/toolchains.sh`): Lean builds and Julia runs in session; `sim/` package with synergy operators passing the vectors and an adversarial suite; Julia Sim CI.
- Freedom article, with links repointed (BACKPROPAGATION 7.17).
- Art article, with Culture's paragraph reduced to a pointer (BACKPROPAGATION 7.16).
- Morality article, with links repointed and Philosophy §Morality trimmed to its parallels (BACKPROPAGATION 7.15).
- Coding style imported to `docs/CODING_STYLE.md`; agent notes in `CLAUDE.md`.
