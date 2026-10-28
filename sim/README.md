# BenefutureSim

Agent-based simulation of the Benefuture specification. The rules (synergy, value, harm weight,
assessment, floors, Goal G's choice) are computed by the Lean reference library
`BenefutureReference` through its C exports (`BenefutureReference/Export.lean`); this package
supplies the world they act on, and checks behavioural conjectures over the resulting traces.

```
julia --project=sim -e 'using Pkg; Pkg.test()'
```

Loading the package rebuilds the Lean shared library only when the hash of the Lean reference
sources changes. Toolchains: `tools/setup/toolchains.sh`.

## Model ladder

Each rung adds one source of mess and must still run in minutes, not hours.

| Rung | World | Status |
|---|---|---|
| M0 | Fixed population; random plan menus; perfect measurement; every loss is passing harm; no novelty, scope or distribution term | done |
| M1 | Measurement through competing metric models with bias and noise; latent against observed levels | next |
| M2 | Currency, probabilistic escrow and causal distribution; reputation | |
| M3 | Adversarial agents: gaming, exploit against reveal | |
| M4 | Governance: weighted voting, capped liquid delegation, threshold drift | |
| M5 | Population change: births, deaths, forks | |
| M6 | Domains, networks, propagation and leakage across games; end of lifespan | |

## M0 observations

1,000 beings, 100 steps, 20 random plans a step, seed 1 (about 8 s):

- A plan beats inaction in 89 of 100 steps.
- Floors of understanding and happiness rise (3.7 → 10.1 and 3.7 → 9.5), as `Conj_FloorsRise` requires; in M0 it holds exactly, since measurement is perfect and G never accepts a plan that lowers a floor against inaction.
- The peak of understanding pulls away from the median (8.0 → 38.6 against 5.1 → 16.2). With the distribution term D absent and gain exponent q₊ > 1, concentrated gains score well; this is the frontier-compounding question of conjecture B17, to revisit once D and sharing of understanding are modelled.
