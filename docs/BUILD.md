# Build, structure and reading order

<!-- Moved from README.md (2026-11-06) to keep the README short; links and claims unchanged. -->

##  Repository structure

```
Benefuture/
├── Bf_Pseudocode.txt            # pseudocode copy (identical to spec/ and the block in Benefuture.txt)
├── Benefuture/                  # Lean spec over ℝ (Mathlib): 52 files, 399 theorems
│   ├── Math/ Ontology/ Measurement/ Epistemology/ Axiology/
│   ├── Subgoals/ Governance/ Economy/ Systems/ Axioms/
│   └── Proposed/                # [P] designs: G and distribution, outcome distribution, Shapley sampling,
│                                #   delegation wisdom, revelation game, record credence, domain hierarchy
├── BenefutureReference/         # Float reference (no Mathlib): 12 files; Export.lean holds 114 C exports
├── BenefutureTest/              # ℚ oracles proved = spec, interval-bound oracles, checked at build time
├── Main.lean                    # `lake exe benefuture`: regenerates spec/vectors
├── spec/                        # Bf_Pseudocode.txt (source of truth), vectors/ (12 JSON), extracted/
├── docs/                        # articles/ (wiki source), BACKPROPAGATION, SPEC_DIVERGENCES, PLAN,
│                                #   CALIBRATION, DATA, ODD, OSTROM, SOTA, THEOREM_INDEX, CODING_STYLE
├── sim/                         # Julia package BenefutureSim
│   ├── src/                     # world model, rungs M0–M7, battery.jl (threaded, cached), methods.jl
│   ├── test/                    # acceptance and adversarial suites, probes, differential tests
│   └── battery/                 # economy, governance, attack, convergence and long_horizon batteries (sharded on GitHub runners via battery.yml); results/
├── tools/                       # setup/, battery/ (launcher, hooks), bench/, wiki_sync/, extraction/,
│                                #   bf-graph/, check_readme_claims.py, theorem_index.py
├── COORDINATION.md              # multi-agent task registry
└── CLAUDE.md                    # agent method notes
```

Links: [`Benefuture/`](Benefuture) · [`BenefutureReference/`](../BenefutureReference) ·
[`BenefutureTest/`](../BenefutureTest) · [`sim/`](sim) ([`sim/README.md`](../sim/README.md)) ·
[`spec/`](spec) · [`docs/`](docs) · [`tools/`](tools) · [`Bf_Pseudocode.txt`](../Bf_Pseudocode.txt) ·
[`COORDINATION.md`](../COORDINATION.md) · [`CLAUDE.md`](../CLAUDE.md) ·
[`docs/CODING_STYLE.md`](CODING_STYLE.md)

---

##  Build, verify, simulate

```bash
tools/setup/toolchains.sh
```

```bash
lake exe cache get && lake build
```

```bash
julia --project=sim -e 'using Pkg; Pkg.test()'
```

```bash
julia --project=sim sim/test/probes.jl
```

```bash
tools/battery/run.sh economy governance attack
```

```bash
python3 tools/check_readme_claims.py
```

```bash
python3 tools/theorem_index.py
```

```bash
lake exe benefuture
```

```bash
julia -t auto --project=sim tools/bench/bench.jl
```

In order:

1. `toolchains.sh` installs Lean and Julia (idempotent).
2. `lake build` builds the specification, the reference and the bridge. It fails if any
   differential check fails, so there is no separate `lake test`.
3. `Pkg.test()` runs the full simulation suite: every test file runs and failures are reported at the
   end.
4. `probes.jl` runs the mechanism probes alone, in seconds.
5. `run.sh` starts the batteries detached and multi-threaded (`julia -t auto`); results go to
   `sim/battery/results/`.
6. `check_readme_claims.py` confirms every theorem named in this README exists.
7. `theorem_index.py` regenerates [`docs/THEOREM_INDEX.md`](THEOREM_INDEX.md).
8. `lake exe benefuture` regenerates [`spec/vectors/`](../spec/vectors).
9. `bench.jl` gives cross-machine timings.

CI runs in tiers: the Lean build and the fast simulation tier (rules, units, probes) on every code push to `main`, the full suite as 8 parallel shards nightly and on demand; docs-only pushes run nothing.

### For implementers

- **Two Lean libraries.** The ℝ specification is the mathematical statement: definitions, `Step`
  semantics and conservation invariants. The Float reference implements the rules computably, and the
  simulation defines no rule of its own. Ladder, noise ranges, governed thresholds and the parsimony
  audit are in [`sim/README.md`](../sim/README.md).
- **Runtime checks backed by theorems.** Chosen plans never contract ℝ and never lower max U, min U
  or min H against not acting (`goal_G_sound`). They are never dominated (`dominated_plan_not_chosen`).
  No delegate exceeds Th_k + max single weight (`accumulate_capped_bound`). Summed novelty never
  exceeds the number of distinct types (`population_novelty_hist_le`).
- **Parameter space.** `Benefuture.Systems.ParamSpace` defines `ParamVector`, `Admissible` and
  `bootstrapParams`. Sweep only inside `Admissible`, where the structural theorems hold
  (`governed_params_admissible`). Every gate value is listed with its default and source in
  [governed thresholds](../sim/README.md#governed-thresholds).
- **Vector files** (`spec/vectors/*.json`): `synergy`, `assessment`, `value`, `ehr`, `pricing`,
  `escrow`, `reputation`, `democracy`, `harm`, `freedom`, `population`, `births`, each tied to its pseudocode
  line in the generator ([`Main.lean`](../Main.lean)).

### Notation

| Symbol | Concept | Pseudocode |
| :--- | :--- | :--- |
| `𝕌`, `ℝ` | Universe; reality = perceivable ∪ changeable | L16 |
| `T ⊇ E ⊇ B ⊇ Pe ⊇ S` | Things, entities, beings, persons, sophonts | |
| `U` | Understanding (never utility): PrAcc + CE − complexity | |
| `H`, `N`, `Di` | Happiness, novelty, diversity | |
| `Sy`, `Ŝy` | Synergy, squashed synergy | L13–14 |
| `V` | Value of an action on a being, against not acting | L73 |
| `G` | Goal: argmax Σ_b Sy(V(A, b), As(pushDistr)) ∧ ↑ℝ ∧ ¬↓(U(max, min), H(min)) | L74 |

---

##  Reading order and references

**Wiki** ([benefuture.miraheze.org](https://benefuture.miraheze.org/); MediaWiki source in
[`docs/articles/`](articles), synced by [`tools/wiki_sync/`](../tools/wiki_sync)):

1. [Introduction](https://benefuture.miraheze.org/wiki/Introduction), then
   [Benefuture](https://benefuture.miraheze.org/wiki/Benefuture).
2. [Benefuture goals](https://benefuture.miraheze.org/wiki/Benefuture_goals) and
   [Philosophy](https://benefuture.miraheze.org/wiki/Philosophy) (Cognitive Progressive
   Utilitarianism).
3. [System Design](https://benefuture.miraheze.org/wiki/System_Design),
   [Adversarial adaptation](https://benefuture.miraheze.org/wiki/Adversarial_adaptation) and
   [Progressive complexity](https://benefuture.miraheze.org/wiki/Progressive_complexity).
4. [Measurement](https://benefuture.miraheze.org/wiki/Measurement) and
   [Benefuture currency](https://benefuture.miraheze.org/wiki/Benefuture_currency).
5. [Government](https://benefuture.miraheze.org/wiki/Government),
   [Law](https://benefuture.miraheze.org/wiki/Law) and
   [Justice](https://benefuture.miraheze.org/wiki/Justice).
6. [Implementation prototype](https://benefuture.miraheze.org/wiki/Implementation_prototype),
   [Critique addressal](https://benefuture.miraheze.org/wiki/Critique_addressal) and
   [Life in benefuture](https://benefuture.miraheze.org/wiki/Life_in_benefuture).

Creator: [Nesquarx](https://www.nesquarx.com/).

**Key references**, with what each contributes here:

- **Goodhart's law.** [Manheim & Garrabrant 2018](https://arxiv.org/abs/1803.04585) divide it into
  regressional, extremal, causal and adversarial variants; the corpus maps a countermeasure to each.
- **Commons governance.** [Ostrom 1990](https://doi.org/10.1017/CBO9780511807763) gives the design
  principles of long-enduring commons institutions. [Wilson, Ostrom & Cox 2013](https://doi.org/10.1016/j.jebo.2012.12.010)
  generalise them to groups of any kind. Both are the yardstick in [`docs/OSTROM.md`](OSTROM.md).
- **Competition and currencies.** [Hayek 1968/2002](https://doi.org/10.1007/s12113-002-1029-0) treats
  competition as a discovery procedure, which the corpus runs among metric models.
  [Hayek 1976](https://iea.org.uk/wp-content/uploads/2016/07/Denationalisation%20of%20Money.pdf) argues
  for competing private currencies, where Benefuture keeps domain currencies non-exchangeable.
- **Markets in beliefs.** [Hanson 2003](https://doi.org/10.1023/A:1022058209073) introduces
  combinatorial information markets (market scoring rules). [Hanson 2013](https://doi.org/10.1111/jopp.12008)
  proposes futarchy: vote on values, bet on beliefs. These are the template for paying on prediction
  and settling on outcome.
- **Mechanism design.** Hurwicz (1960) and [Myerson 1981](https://doi.org/10.1287/moor.6.1.58) found
  incentive compatibility and optimal mechanism design ([2007 Nobel summary](https://www.nobelprize.org/prizes/economic-sciences/2007/summary/)).
  That is the standard the revelation game is proved against.
- **Capabilities.** Sen (1999) and [Nussbaum 2011](https://doi.org/10.4159/harvard.9780674061200)
  judge welfare by what people can do and be ([overview](https://plato.stanford.edu/entries/capability-approach/)),
  which is close to valuing understanding as a capability.
- **Reference dependence.** [Kahneman & Tversky 1979](https://doi.org/10.2307/1914185): losses loom
  larger than gains, relative to a reference point. This underlies harm's reference points and the
  loss-aversion results, including where loss aversion fails.
- **Two-level utilitarianism.** [Rawls 1955](https://doi.org/10.2307/2182230) distinguishes justifying
  a practice from justifying an act within it. [Hare 1981](https://doi.org/10.1093/0198246609.001.0001)
  sets intuitive rules against critical thinking. Together they ground progressive complexity.
- **Voting impossibility.** [Gibbard 1973](https://doi.org/10.2307/1914083) and
  [Satterthwaite 1975](https://doi.org/10.1016/0022-0531(75)90050-2) show every non-dictatorial
  one-shot rule over three or more options is manipulable. This motivates repeated, outcome-scored
  voting.
- **Influence and wisdom in networks.** [Golub & Jackson 2010](https://doi.org/10.1257/mic.2.1.112)
  show naive learning converges to the truth when no one keeps outsized influence, which the
  delegation bounds formalise. [DeMarzo, Vayanos & Zwiebel 2003](https://doi.org/10.1162/00335530360698469)
  describe persuasion bias from repeated signals, reproduced and removed by source tags.

The corpus's full bibliography is in [Citations](articles/Citations.txt) and the articles' own
reference lists.

---
