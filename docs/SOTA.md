# State of the art relevant to Benefuture

A survey of work bearing on each layer of the project (agent-based simulation, formal verification,
and the mechanisms themselves), with what each implies for Benefuture. Links were checked against
doi.org and Crossref (or arXiv and the publisher page); summaries rest on abstracts and prior
knowledge, so finer claims are to be confirmed before they enter `README.md` (Claims). Items marked
**[unverified]** could not be confirmed.

## 1. Agent-based simulation of economies, mechanisms and governance

### Macro and market models
- Axtell & Farmer (2025), "Agent-Based Modeling in Economics and Finance: Past, Present, and Future", *Journal of Economic Literature*, https://doi.org/10.1257/jel.20221319. The current review of what economic ABMs reproduce and of their open calibration and validation problems. *For Benefuture:* the frame against which "absorbs messy reality" is judged.
- Dosi, Fagiolo & Roventini (2010), "Schumpeter meeting Keynes", *J. Economic Dynamics & Control* 34, https://doi.org/10.1016/j.jedc.2010.06.018. The K+S family, validated against macro stylised facts. *For Benefuture:* the sim's oracle is internal (the Goal's pattern against the clean world); it has no external facts it must reproduce.
- Deissenberg, van der Hoog & Dawid (2008), EURACE, *Applied Mathematics & Computation*, https://doi.org/10.1016/j.amc.2008.05.116; Dawid & Delli Gatti (2018), "Agent-based macroeconomics", *Handbook of Computational Economics* 4, https://doi.org/10.1016/bs.hescom.2018.02.006. Multi-market policy testbeds; a reference architecture for per-domain currencies.
- Poledna, Miess, Hommes & Rabitsch (2023), "Economic forecasting with an agent-based model", *European Economic Review*, https://doi.org/10.1016/j.euroecorev.2022.104306. A calibrated ABM forecasting as well as VAR and DSGE models. *For Benefuture:* an implementation-ready ABM can be held to out-of-sample forecasts; Phase 1 (score-only) is a natural data source.
- Byrd, Hybinette & Balch (2019), ABIDES, https://arxiv.org/abs/1904.12066; ABIDES-Economist (2024), https://arxiv.org/abs/2402.09563. Discrete-event market simulation with learning agents; relevant once transactions carry timing (L88).

### Tooling
- Datseris, Vahdati & DuBois (2022), Agents.jl, *SIMULATION*, https://doi.org/10.1177/00375497211068820; ter Hoeven et al. (2025), Mesa 3, *JOSS*, https://doi.org/10.21105/joss.07668.
- Dixit & Rackauckas (2022), GlobalSensitivity.jl, *JOSS*, https://doi.org/10.21105/joss.04561; Herman & Usher (2017), SALib, https://doi.org/10.21105/joss.00097; Kwakkel (2017), Exploratory Modeling Workbench, *Env. Modelling & Software*, https://doi.org/10.1016/j.envsoft.2017.06.054.

### LLM-agent societies (2023–2026)
- Park et al. (2023), "Generative Agents", UIST, https://doi.org/10.1145/3586183.3606763; Park et al. (2024), https://arxiv.org/abs/2411.10109.
- Zheng et al. (2022), "The AI Economist", *Science Advances*, https://doi.org/10.1126/sciadv.abk2607: a planner sets taxes against adapting agents; the closest analogue to threshold governance against adaptive agents, and its weakness (attackers confined to the modelled action space) is M6's.
- Koster et al. (2022), *Nature Human Behaviour*, https://doi.org/10.1038/s41562-022-01383-x; Tessler et al. (2024), *Science*, https://doi.org/10.1126/science.adq2852: AI-mediated mechanism design and deliberation.
- Piatti et al. (2024), GovSim, https://arxiv.org/abs/2404.16698 (LLM societies mostly fail to sustain a commons); Fish, Gonczarowski & Shorrer (2024), https://arxiv.org/abs/2404.00806 (LLM pricing agents collude tacitly).
- Critiques: Larooij & Törnberg (2025), https://arxiv.org/abs/2504.03274 (validation mostly subjective); Anthis et al. (2025), https://arxiv.org/abs/2504.02234.
- *For Benefuture:* use LLM agents to discover gaming strategies, each then frozen as a deterministic M6 test; not for quantitative claims.

### Validation and calibration
- Fagiolo et al. (2019), https://doi.org/10.1007/978-3-319-70766-2_31; Platt (2020), *JEDC*, https://doi.org/10.1016/j.jedc.2020.103859; Grazzini, Richiardi & Tsionas (2017), *JEDC*, https://doi.org/10.1016/j.jedc.2017.01.014; Lamperti, Roventini & Sani (2018), *JEDC*, https://doi.org/10.1016/j.jedc.2018.03.011; Dyer et al. (2024), *JEDC*, https://doi.org/10.1016/j.jedc.2024.104827; Grimm et al. (2020), ODD protocol, *JASSS*, https://doi.org/10.18564/jasss.4259.
- *For Benefuture:* testing the sim against the Lean vectors is verification, not validation; the Claims should say so. An ODD description per rung would make the sim reviewable.

### Sensitivity analysis, scenario discovery, failure search
- McKay, Beckman & Conover (1979), https://doi.org/10.1080/00401706.1979.10489755; Morris (1991), https://doi.org/10.1080/00401706.1991.10484804; Sobol′ (2001), https://doi.org/10.1016/S0378-4754(00)00270-6; Saltelli et al. (2010), https://doi.org/10.1016/j.cpc.2009.09.018; ten Broeke, van Voorn & Ligtenberg (2016), *JASSS*, https://doi.org/10.18564/jasss.2857; Lee et al. (2015), *JASSS*, https://doi.org/10.18564/jasss.2897.
- Friedman & Fisher (1999), PRIM, https://doi.org/10.1023/A:1008894516817; Bryant & Lempert (2010), https://doi.org/10.1016/j.techfore.2009.08.002.
- Miller (1998), Active Nonlinear Tests, *Management Science*, https://doi.org/10.1287/mnsc.44.6.820; Corso et al. (2021), black-box safety validation, *JAIR*, https://doi.org/10.1613/jair.1.12716; Echard, Gayton & Lemaire (2011), AK-MCS, https://doi.org/10.1016/j.strusafe.2011.01.002; Bect et al. (2012), https://doi.org/10.1007/s11222-011-9241-4.
- *For Benefuture:* the battery's screening is regional sensitivity analysis; PRIM gives interpretable failure boxes; Sobol indices on the continuous success pattern quantify interactions; active learning of the boundary needs fewer runs and tolerates a noisy oracle; searching attacker strategies (not only severities) finds worst cases. No published governance ABM combining Lean-verified rules with failure-boundary batteries was found.

## 2. Formal verification of social choice, mechanism design and economics
- Nipkow (2009), Arrow and Gibbard–Satterthwaite in HOL, https://doi.org/10.1007/s10817-009-9147-4; Tang & Lin (2009), *Artificial Intelligence*, https://doi.org/10.1016/j.artint.2009.02.005; Brandt & Geist (2016), *JAIR*, https://doi.org/10.1613/jair.4959; Brandl, Brandt, Eberl & Geist (2018), *JACM*, https://doi.org/10.1145/3125642. *For Benefuture:* small instances of weighted voting with capped delegation can be searched by solver for axiom conflicts and certified in Lean.
- Holliday, Norman & Pacuit (2021), "Voting Theory in the Lean Theorem Prover", LORI, https://doi.org/10.1007/978-3-030-88708-7_9 (Lean 3 **[unverified]**): a template for Governance definitions.
- Caminati, Kerber, Lange & Rowat (2015), verified VCG with generated code, EC, https://doi.org/10.1145/2764468.2764511; Barthe et al. (2015), POPL, https://doi.org/10.1145/2676726.2677000; Barthe et al. (2016), WINE, https://doi.org/10.1007/978-3-662-54110-4_20. *For Benefuture:* "revealing pays more than exploiting" can be stated as a relational, dominant-strategy theorem.
- Pusceddu & Bartoletti (2024), automated market makers in Lean 4, FMBC, https://doi.org/10.4230/OASIcs.FMBC.2024.5; "Formalizing Scarf, Brouwer, and Nash in Lean" (2026), https://arxiv.org/abs/2607.05987; Lean game-theory libraries on Reservoir (contents **[unverified]**). No Arrow or Gibbard–Satterthwaite in Mathlib found.
- Linking verified rules to running code: Cedar (Cutler et al. 2024, OOPSLA, https://doi.org/10.1145/3649835; Disselkoen et al. 2024, https://doi.org/10.1145/3663529.3663854): a Lean model with proofs and differential random testing of production code against it; SampCert (2024), https://arxiv.org/abs/2412.01671. *For Benefuture:* the `BenefutureReference` plus `spec/vectors` pattern is Cedar's, without its generated-input differential testing; and no refinement links the ℝ theorems to the Float reference that runs.

## 3. Work closest to Benefuture's mechanisms

### Liquid democracy
- Kahng, Mackenzie & Procaccia (2021), *JAIR*, https://doi.org/10.1613/jair.1.12261; Caragiannis & Micha (2019), IJCAI, https://doi.org/10.24963/ijcai.2019/17: delegation can do worse than direct voting.
- Gölz, Kahng, Mackenzie & Procaccia (2021), *ACM TEAC*, https://doi.org/10.1145/3485012: multiple acceptable delegates, minimising maximum weight, the formal ancestor of a cap.
- Berinsky et al. (2025), "Tracking Truth with Liquid Democracy", *Management Science* 71(9), https://doi.org/10.1287/mnsc.2023.02470: with fitted delegation behaviour, liquid democracy beats direct voting.
- Alouf-Heffetz et al. (2024), control and bribery of delegations, https://arxiv.org/abs/2403.07558; Kling et al. (2015), LiquidFeedback, https://arxiv.org/abs/1503.07723 (super-voters emerge).
- *For Benefuture:* test the capped, audited, expertise-weighted delegation against the adversarial instances of Kahng and Caragiannis–Micha, and against bribery of delegates, with direct voting as baseline.

### Correlated votes and herding
- Ladha (1992), *AJPS*, https://doi.org/10.2307/2111584; Dietrich & Spiekermann (2013), https://doi.org/10.1017/S0266267113000096; Lorenz et al. (2011), *PNAS*, https://doi.org/10.1073/pnas.1008636108; Becker, Brackbill & Centola (2017), *PNAS*, https://doi.org/10.1073/pnas.1615978114.
- Golub & Jackson (2010), *AEJ: Micro*, https://doi.org/10.1257/mic.2.1.112: learning on networks reaches the truth only if no one's influence stays large.
- DeMarzo, Vayanos & Zwiebel (2003), "Persuasion Bias", *QJE*, https://doi.org/10.1162/00335530360698469: information heard along many paths is counted many times.
- *For Benefuture:* finding 8.45 (echoes count information many times) is persuasion bias, with a formal model and known corrections; Golub–Jackson's condition is a theorem-shaped case for the delegation and expertise caps.

### Prediction markets, scoring rules, forecasters
- Hanson (2003), https://doi.org/10.1023/A:1022058209073; Hanson (2013), https://doi.org/10.1111/jopp.12008; Wolfers & Zitzewitz (2004), https://doi.org/10.1257/0895330041371321.
- Chen, Kash, Ruberry & Shnayder (2014), *ACM TEAC*, https://doi.org/10.1145/2556271: when predictions decide which action is taken, honest reporting needs every action taken with positive probability. Perdomo et al. (2020), performative prediction, https://proceedings.mlr.press/v119/perdomo20a.html.
- Gneiting & Raftery (2007), *JASA*, https://doi.org/10.1198/016214506000001437 (1 − Brier/0.25 stays proper); Witkowski et al. (2023), *Management Science*, https://doi.org/10.1287/mnsc.2022.4410 (rank-based rewards make forecasters exaggerate).
- *For Benefuture:* metric models are scored on plans their own predictions select: the decision-market setting. Randomised-block experiments (8.22) are Chen et al.'s fix, but only with full support where predictions are scored; rank-based retirement of models may reward extremised forecasts. Both deserve tests.

### Bounties
- Breidenbach et al. (2018), "Enter the Hydra", USENIX Security, https://www.usenix.org/conference/usenixsecurity18/presentation/breindenbach; Maillart et al. (2017), *J. Cybersecurity*, https://doi.org/10.1093/cybsec/tyx008. *For Benefuture:* test sit-then-report (exploit, then disclose) and bounty farming.

### Ostrom's design principles
- Ostrom (1990), https://doi.org/10.1017/CBO9780511807763; Cox, Arnold & Villamayor Tomás (2010), https://doi.org/10.5751/es-03704-150438; Pitt, Schaumeier & Artikis (2012), *ACM TAAS*, https://doi.org/10.1145/2382570.2382575. *For Benefuture:* audit against the eight principles, especially graduated sanctions against reparation-first.

### Shapley credit
- Castro, Gómez & Tejada (2009), sampling estimator, https://doi.org/10.1016/j.cor.2008.04.004; Frye et al. (2020), asymmetric Shapley, NeurIPS; Heskes et al. (2020), causal Shapley, NeurIPS; Aziz et al. (2011), false-name manipulation, *JAIR*, https://doi.org/10.1613/jair.3166.
- *For Benefuture:* exact Shapley is O(2ⁿ) (capped at 10 contributors); sampling with a stated error bound scales; causal distribution over transaction trees is closest to asymmetric or causal Shapley; identity forks are false-name manipulation, to test.

### Reputation attacks
- Douceur (2002), https://doi.org/10.1007/3-540-45748-8_24; Friedman & Resnick (2001), https://doi.org/10.1111/j.1430-9134.2001.00173.x; Cheng & Friedman (2005), https://doi.org/10.1145/1080192.1080202 (no symmetric reputation function is sybilproof); Hoffman, Zage & Nita-Rotaru (2009), *ACM CSUR*, https://doi.org/10.1145/1592451.1592452.
- *For Benefuture:* test whitewashing, on-off oscillation, slandering and sybil inflation; state whether the reputation recount is symmetric in Cheng–Friedman's sense.

### Quadratic voting and funding
- Lalley & Weyl (2018), https://doi.org/10.1257/pandp.20181002; Buterin, Hitzig & Weyl (2019), *Management Science*, https://doi.org/10.1287/mnsc.2019.3337 (breaks under collusion and sybils). Impact certificates: no peer-reviewed evaluation found **[unverified]**.

### Goodhart
- Manheim & Garrabrant (2018), https://arxiv.org/abs/1803.04585; Holmström & Milgrom (1991), *JLEO*, https://doi.org/10.1093/jleo/7.special_issue.24; Kleinberg & Raghavan (2020), *ACM TEAC*, https://doi.org/10.1145/3417742; Gao, Schulman & Hilton (2023), reward-model overoptimisation, https://proceedings.mlr.press/v202/gao23h.html.
- *For Benefuture:* measure the overoptimisation curve (true G against the proxy as pressure on a metric model rises); competing models and adversarial adaptation should keep the gap bounded.

### Population ethics
- Arrhenius (2000), https://doi.org/10.1017/S0266267100000249; Blackorby, Bossert & Donaldson (2005), https://doi.org/10.1017/ccol0521825512; Asheim & Zuber (2014), *Theoretical Economics*, https://doi.org/10.3982/TE1338.
- *For Benefuture:* the success pattern is rank-sensitive and multi-criteria, closest to Asheim–Zuber; Arrhenius guarantees it gives up one plausible axiom, which the corpus should name; M7 births should test the Repugnant and Sadistic Conclusions.

### Diversity and exploration
- Hong & Page (2004), *PNAS*, https://doi.org/10.1073/pnas.0403723101, with Thompson's critique (2014), https://doi.org/10.1090/noti1163; March (1991), https://doi.org/10.1287/orsc.2.1.71; Lazer & Friedman (2007), *ASQ*, https://doi.org/10.2189/asqu.52.4.667; Zollman (2010), *Erkenntnis*, https://doi.org/10.1007/s10670-009-9194-6.
- *For Benefuture:* the novelty bonus is Zollman's transient diversity; Lazer–Friedman's setup benchmarks how connected deliberation can be before it converges too early.

### Threshold governance as experimental design
- Kasy & Sautmann (2021), *Econometrica*, https://doi.org/10.3982/ECTA17527; Kohavi, Tang & Xu (2020), https://doi.org/10.1017/9781108653985. *For Benefuture:* exploration sampling could cut SigThGv's regret; guardrail metrics mirror harm floors.

## Prioritised actions
1. Upgrade the failure-boundary battery: PRIM failure boxes, Sobol indices on the continuous success pattern, active learning of the boundary, seed counts sized by variance stability.
2. Search for attacks adversarially (optimised attacker strategies), using LLM agents only to discover exploits that then become deterministic M6 tests.
3. A liquid-democracy pathology suite for M5 (concentration, bad delegation, bribery, cycles), against direct voting; a Lean conjecture tying the delegation cap to Golub–Jackson's condition. *Suite done* (`sim/test/m5_tests.jl`, "SOTA #3"; `sim/README.md`, M5): each pathology reproduced uncapped and unaudited, bounded by the capped, audited, expertise-weighted delegation; the Golub–Jackson conjecture is B26 (Lean, one-round part proved).
4. Name 8.45 after DeMarzo–Vayanos–Zwiebel persuasion bias and use their model as the deliberation benchmark. *Done* (`sim/test/m5_tests.jl`, "SOTA #4"): untagged updating reproduces the DVZ walk-count weights; source tags (author ruling on 8.45) hear each origin once.
5. Close the decision-market gap: full-support randomisation where predictions are scored; test whether rank-based model retirement rewards extremised forecasts.
6. Shapley: a sampling estimator with a governed error bound; asymmetric or causal Shapley as candidates for causal distribution; false-name tests for forks.
7. A reputation-attack suite (whitewashing, on-off, slandering, sybils); state the recount's symmetry.
8. Cedar-style differential testing between the Mathlib specification, the Float reference and the Julia guards, or a stated gap in Claims.
9. Reuse formalisations: Holliday–Norman–Pacuit for Governance, a Lean game-theory library for the manufactured prisoner's dilemma, solver-plus-Lean certification of small voting instances, Barthe-style relational incentive statements.
10. Population-ethics and Goodhart probes: births against the Repugnant and Sadistic Conclusions, the overoptimisation curve; an ODD description per rung and an audit against Ostrom's principles.
