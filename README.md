# Benefuture

[![Lean Action CI](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml/badge.svg)](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml)
[![Julia Sim CI](https://github.com/nesquarx/Benefuture/actions/workflows/julia_sim_ci.yml/badge.svg)](https://github.com/nesquarx/Benefuture/actions/workflows/julia_sim_ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.29.0-blue.svg)](https://leanprover.github.io/)
[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-green.svg)](LICENSE)

**Benefuture is a design for a civilization that measures and rewards good.** Its goal and definition of good is to raise
universal understanding first, then happiness, and the two together, *"since understanding creates and
compounds meta-capability"* ([Benefuture](https://benefuture.miraheze.org/wiki/Benefuture)). From that
one goal it derives a whole system: how value is measured, how currencies are issued, how reputation is
earned, how votes are weighted, how flaws are found and repaired, and how its own rules change. It can
be introduced by *"gradual non-violent change by measuring and incentivizing good"*, starting with
scores that carry no money at all.

Today's institutions are, in the author's words, *"fragmentary, misaligned, captured approximations of
principles"*. Benefuture tries to build the comprehensive framework and the correction mechanisms *"to
converge on what we've been clumsily attempting piecemeal for centuries"*. It is *"a rough process
outline of how we might discover those problems, find the solutions, implement them, and keep improving
on the process"*: confident in its design, explicit about what is still unproven, and built to be
corrected. As its critique page puts it, the bootstrap *"is not guaranteed to be right. It is guaranteed
to be correctable."*

Benefuture is a thought experiment, and it says so: its telos is chosen, not discovered. The reasons
for the choice draw on established science and philosophy (consequentialist ethics, measurement and
forecasting, mechanism design, the study of institutions), and most of its mechanisms have long track
records on their own: proper scoring of forecasts, escrow and clawbacks, separation of powers, liquid
democracy, bug bounties, open-source auditing, Ostrom's design principles for governing commons. Some
of its pieces are new, and they come from crossing disciplines. Its main strength, though, is the
synthesis: one goal that the measurement, the money, the reputation, the vote and the correction
mechanisms all serve, so that each covers the others' blind spots.

This repository makes the design precise and puts it under attack. The rules are written in Lean 4 and
proved where they can be. A multi-agent simulation then runs them in worlds built to be as sloppy and
adversarial as reality: noisy measurement, imperfect people who take advice only partly, liars,
colluders, optimised attackers, catastrophes and breakthroughs, with noise calibrated to real data
where it exists. The simulations are not reality; they are a way to imagine what a Benefuture
implementation would do across a wide range of scenarios, and to find where it breaks before anyone
relies on it.

## How it works

| Mechanism | What it does | Why it matters |
|---|---|---|
| **Goal G** ([goals](https://benefuture.miraheze.org/wiki/Benefuture_goals)) | Chooses actions by their value to every being, each kind of understanding, happiness and novelty weighed by its priority (teachable breakthroughs over idle knowledge, meaning over raw pleasure), under floors: the lowest understanding and happiness, and the peak of understanding, must not fall | Success is the whole distribution, not an average that can hide the worst-off |
| **Metric models and domains** ([measurement](https://benefuture.miraheze.org/wiki/Measurement), [domain](https://benefuture.miraheze.org/wiki/Domain)) | Competing, open, audited models measure outcomes in fuzzy, nested domains, scored on how well they predict; competing measurement chains check each other, with audits where they disagree | A market of measures replaces any single measure that can be captured |
| **Domain currencies and StandCoin** ([currency](https://benefuture.miraheze.org/wiki/Benefuture_currency)) | Good mints currency, harm burns it, resources are paid for; currencies never trade with each other; work no model can price falls back to costly StandCoin | Money tracks measured value; speculation has nothing to trade; unpriceable work becomes a call to research |
| **Causal distribution and escrow** | Credit and blame flow along the causal chain; payment is part predicted, part settled on measurement | Overpromising is clawed back; contributors upstream are paid |
| **Reputation** ([reputation](https://benefuture.miraheze.org/wiki/Reputation)) | Earned per domain from what one actually produced; cannot be bought, transferred or inherited; mistakes and successes kept in separate ledgers | Expertise is demonstrated, not claimed |
| **Expertise-weighted liquid democracy** ([government](https://benefuture.miraheze.org/wiki/Government)) | Votes weigh by domain expertise and stake, and carry credences weighted by each voter's calibration record; copied ballots count once; delegation is audited, retractable and capped | Decisions follow demonstrated competence without concentrating power |
| **Adversarial adaptation** ([adversarial adaptation](https://benefuture.miraheze.org/wiki/Adversarial_adaptation)) | Revealing a flaw pays more than exploiting it; exploiters repay in full | Every attacker becomes a potential auditor |
| **Freedom and the harm boundary** ([freedom](https://benefuture.miraheze.org/wiki/Freedom)) | Only established or high-risk harm is restricted; nothing is censored, dangerous knowledge is gated by education | Maximum room to act, with the line drawn at harm |
| **Governed thresholds** | Every gate value can be revised by evidence or by vote, and the bar for accuracy only rises | The rules improve as understanding does |
| **Progressive degradation** ([progressive complexity](https://benefuture.miraheze.org/wiki/Progressive_complexity)) | When a part fails, a coarser one stands in, loudly | The system keeps serving through outages and learns from them |

The author's vision for a mature Benefuture (unfolding understanding, universal uplift, baseline needs
priced at or below zero, flaws as a revenue stream, an epistemic commons) is set out on the
[wiki](https://benefuture.miraheze.org/); its longer-range scenarios are the author's, not findings.

## What this repository has established

| | What | Status |
|---|---|---|
| **Proved** (Lean 4, 414 theorems, no `sorry`) | G never prefers a world that lowers its floors; removing beings cannot raise a floor; revealing a flaw dominates exploiting it once clawbacks apply; delegation caps bound concentration; currency is conserved | For the definitions as written ([theorem index](docs/THEOREM_INDEX.md)) |
| **Simulated** (calibrated toy worlds, paired seeds, stated tests) | Deceit does not pay, for skilled and unskilled actors alike, and audits read the honesty of claims apart from skill (no honest actor is flagged for being less able); repeated deception, once discovered, is priced out and stops damaging the honest; collusion is corrected by audits; at the realistic bad end, its governance decides 97% right against 89% for one person one vote; credence ballots weighted by each voter's calibration record hold 96% against a confident colluding bloc that captures stated-confidence weighting (67%), provided minority choices are subsidised so hidden outcomes surface; identity binding stops whitewashing; time-decayed accuracy beats fixed record windows over long runs; understanding defined by its own equation rises with teaching, models passing whole, and measured that way tracks the truth as records grow and overconfidence lowers it, while claims of causal explanation need audits: unaudited overclaims mislead who teaches and slow the floor of understanding by about 40%; valued through priority tiers (understanding, happiness and novelty each by kind), it stops trading understanding for raw happiness, and tiers decide 3 of 6 historical contrast cases built to differ only in kind; knowing which understanding accelerates the goals is itself learnable, and when a society shares a misjudgement of priorities a small share of research spent on that meta domain lifts the floor of understanding (conjecture, one regime); copied ballots are found by the errors they share and counted once, with no cost to honest voters; competing measurement chains expose a chain that hides harm (as counting deaths by last symptom does) and demote it after a few audits | Toy worlds, not people ([claims record](docs/CLAIMS.md)) |
| **Real data** | Forecasters' skill persists moderately on the COVID-19 Forecast Hub, and short records carry most of it, as Benefuture's record rules assume | One archive ([8.93](docs/BACKPROPAGATION.md)) |
| **In progress** | Historical decisions replayed on what was known at the time, against simple rules on the same prices: right on 6 of 6 settled pre-registered cases; on a held-out set replayed once under frozen code, 3 of 5; with the author's later rulings (compensated reforms, long-term offsets, environmental and policy-level irreparable harm, only generational understanding loss counted as irreparable) 5 of 5, not out of sample; close calls such as the 2020 school closures are reported as contested. A second round of ten cases, each committed before its replay: right on 8 of 9 settled (wrong on the 1976 swine flu vaccination, on the base rates of the time), the same as the fewest-deaths rule, against 6 of 9 for the status quo; 3 robust and right, 5 contested. Choices robust to halving or doubling any judged magnitude: 8 of the 11 settled cases, all right; the other 3 are contested. Current decisions are investigated the same way before their outcomes are known (four so far, with credences, rerun weekly until their horizon: [E5](docs/E5_REPORTS.md)) | Small samples, judged magnitudes ([E4](docs/REPLAY_PREREG.md)) |
| **Open** | Pricing out skilled deceivers costs some growth against status-quo institutions in a small fixed economy (floor of understanding about 5% lower once refused slots pass to others, 10% when they do not), since their real work goes partly unreplaced; entry of new producers is the tracked test; problems every institution shares: deceit that fools every measure, sybils, the limits of measurement; and whether people would adopt it, which only score-only field pilots can answer | Each with its tracked fix ([open problems](docs/OPEN_PROBLEMS.md)) |

Benefuture's own method is to start score-only and let evidence earn trust before money moves; this
repository applies the same discipline to itself.

## Start here

[Wiki](https://benefuture.miraheze.org/) for the full framework · [pseudocode](spec/Bf_Pseudocode.txt) ·
[claims record](docs/CLAIMS.md) (every claim with its theorem, test, hypotheses and toy assumptions) ·
[open problems](docs/OPEN_PROBLEMS.md) · [build, structure and reading order](docs/BUILD.md) ·
[findings log](docs/BACKPROPAGATION.md) · [CLAUDE.md](CLAUDE.md) for agents

Counts: 414 Lean theorems in 53 files (no `sorry`, axioms or `native_decide`); 129 C exports from the
Float reference; CI tiered (rules, units and probes on every code push; the full suite in 8 shards
nightly). Definitions and aspects on the wiki are the author's; this repository's code, tests and much
of its prose are AI-assisted under the author's direction.

## License

GNU Lesser General Public License v2.1 (LGPL-2.1). See [LICENSE](LICENSE).

