# Benefuture

> **A Formal Specification for Antifragile, Post-Scarcity Civilizational Flourishing**  
> *A type-checked specification of the Benefuture pseudocode, with invariants and sanity lemmas; behavioural claims (convergence, gaming resistance) are conjectures for simulation.*

[![Lean Action CI](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml/badge.svg)](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.29.0-blue.svg)](https://leanprover.github.io/)
[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-green.svg)](LICENSE)

---

## Overview

**Benefuture** is a mathematical, epistemic, and economic framework designed to guide long-term civilizational trajectory away from catastrophic failure modes (such as wireheading loops, extractive financialization, systemic fragility, and cognitive monoculture) and toward open-ended, reality-grounded flourishing.

This repository hosts the **type-checked specification in Lean 4**. In this architecture:
- **Lean 4 holds the specification**: types, invariants, definitions, structural properties, and mathematical sanity lemmas.
- **Assumptions and requirements** are stated explicitly as hypotheses, structure fields, and design requirements rather than tautological theorems.
- **Behavioural and empirical claims** (such as convergence under adversarial agents, gaming resistance, and stability of metric-model competition) are formulated as conjectures (`Conj_*`) intended for empirical validation in simulation (e.g. in Julia).

---

## Foundational Ontological Architecture

Benefuture organizes all phenomena in the Universe ($\mathbb{U}$) into a strict concentric ontology grounded in physical Reality ($\mathbb{R}$):

$$\text{Sophonts } (S) \subseteq \text{Persons } (Pe) \subseteq \text{Beings } (B) \subseteq \text{Entities } (E) \subseteq \text{Things } (T) \subseteq \text{Reality } (\mathbb{R}) \subseteq \text{Universe } (\mathbb{U})$$

Every operational primitive in the system inherits physical and informational standing as a subtype of `Thing`:
- **Society / Civilization** ($So, Cv \subseteq E \subseteq T$)
- **Empirical Markers** ($M \in T$)
- **Currencies & Resource Accounting** ($C, RA \in T$)
- **Interactions, Actions, Outcomes, & Decisions** ($I, A, O, D \in T$)
- **Laws, Contracts, Accolades, & Crimes** ($Lw, Ct, Aco, Cr \in T$)
- **Memetic Cultures & Artworks** ($Cu, Art \in T$)

### The Core Universal Goal ($G$)

$$\text{Goal } G(t) := \operatorname{argmax}_{A(t)} \left[ \sum_{b \in B(t)} V(A, b(t)) \right] \land \uparrow \mathbb{R}$$

Benefuture defines the civilizational goal as the joint maximization of sentient value **and** the non-decreasing or expanding scope of physical Reality ($\uparrow \mathbb{R}$). Actions that seek to maximize subjective pleasure by blinding sensors, shrinking capability, or collapsing into solipsistic simulation fail the reality condition.

### Canonical Notation & Symbol Disambiguation

To ensure mathematical precision and prevent conflation across foundational concepts:
| Symbol | Canonical Concept | Mathematical Meaning & Formula | Disambiguation Rule |
| :--- | :--- | :--- | :--- |
| **$\mathbb{U}$ / `𝕌`** | **Universe** | Total state space of all logically possible patterns | **Total ontological pattern space** ($\mathbb{R} \subseteq \mathbb{U}$). Never write as plain ASCII $U$. |
| **$\mathbb{R}$ / `ℝ`** | **Reality** | $(\text{Perceivable} \cup \text{Changeable}) \subseteq \mathbb{U}$ | Physical, empirical interactivity domain. |
| **$U$** | **Understanding** | $\text{PrAcc}(\text{Ml}) + \text{CE}(I(\text{Ml})) - (\text{Cy}(\text{Ml}) \mid \text{PrAcc})$ | **Strictly Epistemic Understanding**. Must **never** be interpreted as "utility". |
| **$V$** | **Value** | Generalized flourishing payoff $V(A, b)$ | Represents the true "utility" / value function of an action over $U, H, N$. |
| **$G$** | **Goal** | Civilizational trajectory function $\operatorname{argmax} \sum V \land \uparrow \mathbb{R}$ | Global macro objective. |
| **$H$** | **Happiness** | Internal affective flourishing | Tier $\beta$ in the priority hierarchy ($U > H > N$). |
| **$N$** | **Novelty** | Inverse empirical frequency: $N(x) := 1 / \text{Frequency}(x \mid \mathbb{R})$ | Tier $\gamma$ in the priority hierarchy ($U > H > N$). An operational input and means toward diversity. |
| **$\text{Di}$** | **Diversity** | $\text{Balance}(\text{order}, \text{chaos}) \to \text{Variety}(\text{Sys}) \to \text{Resilience} + \text{Innovation}$ | Emergent macro outcome & civilizational subgoal (`SubG.Diversity`), NOT a scalar priority weight. Novelty injection is one means to maintain diversity balance. |

---

## Invariants, Design Requirements, and Conjectures

Rather than asserting ungrounded real-world guarantees, the specification distinguishes:
- **Sanity Lemmas**: Proven mathematical properties of the operators (e.g. strict monotonicity, odd symmetry, loss penalty sign).
- **Invariants**: Structural invariants on state transitions (e.g. append-only memory, identity injectivity, escrow conservation, balance overflow redirection).
- **Design Requirements**: Parameter conditions required for system properties (e.g. restorative friction $> 0$ for anti-corruption, clawback $\ge$ bounty for anti-cobra).
- **Conjectures**: Behavioural dynamics left to simulation (e.g. convergence under adversarial agents, Goodhart error reduction via metric competition).

---

## Repository Structure

```
Benefuture/
├── .github/workflows/
│   └── lean_action_ci.yml         # Automated GitHub Actions Lean 4 CI
├── lakefile.toml                  # Lake package configuration
├── lean-toolchain                 # Lean 4 toolchain pin (v4.29.0)
├── lake-manifest.json             # Manifest dependencies
├── Benefuture.lean                # Primary library umbrella import
├── Main.lean                      # Executable specification / test harness
├── Bf_Pseudocode.txt              # Foundational formal pseudocode specification
│
├── Benefuture/                    # Specification modules
│   ├── Math/                      # Parameters, schedules, synergy & saturation
│   ├── Ontology/                  # Concentric ontology & entity definitions
│   ├── Measurement/               # Metric models, empirical markers & thresholds
│   ├── Epistemology/              # Truth correspondence, proper scoring, & info handling
│   ├── Axiology/                  # Priority schedules, value functions & repugnant conclusion
│   ├── Subgoals/                  # Freedom, Morality, Justice, Diversity, Art, & Continuity
│   ├── Governance/                # Liquid democracy, anti-halo isolation, & adversarial adaptation
│   ├── Economy/                   # Backed currencies, resource accounting, & probabilistic escrow
│   ├── Systems/                   # Ledger, memory, pipeline settlement, & technology network
│   └── Axioms/                    # Antifragility axioms and operational requirements
│
├── spec/
│   ├── Bf_Pseudocode.txt          # Primary formal specification source of truth
│   └── extracted/                 # Extracted definitions & abbreviations datasets
├── docs/
│   ├── SPEC_DIVERGENCES.md        # Explicit log of divergences between Lean and sources
│   ├── pseudocode_lean_coherence_audit.md # Historical audit matrix
│   └── articles/                  # Foundational Knowledge Base Articles
└── tools/                         # Maintenance, sync, extraction, and visualization tools
    ├── wiki_sync/                 # Live MediaWiki page fetcher & patch applier
    ├── extraction/                # Pseudocode extraction & semantic audit tools
    └── bf-graph/                  # Concept graph visualizer
```

---

## Quickstart & Verification

### Prerequisites

Install Lean 4 using the official `elan` toolchain manager:

```bash
curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh
source $HOME/.elan/env
```

### Build the Full Specification

Clone the repository and compile:

```bash
git clone https://github.com/nesquarx/Benefuture.git
cd Benefuture
lake build
```

---

## For Implementers

This repository maintains a two-tier formalization architecture:
1. **The Formal Specification (`Benefuture`, over $\mathbb{R}$)**:
   - Formulated over real numbers ($\mathbb{R}$) using Mathlib.
   - States foundational definitions, structural theorems, state transition semantics (`Step`), and exact conservation invariants (append-only memory, identity injectivity, escrow soundness, and supply balance identities).
   - Serves as the mathematical source of truth.
2. **The Computable Reference Library (`BenefutureReference`, over `Float`)**:
   - Zero Mathlib dependencies; completely decoupled from the spec library.
   - Implements computable, Float-based versions of core mathematical operators ($Sy, \hat{Sy}, As, V$, escrow splitting, lazy continuous decay, parent domain aggregation, and voting weights).
   - Generates deterministic JSON test vectors to `spec/vectors/*.json`.

### Working with Simulations (e.g. Julia)
- Spec ↔ reference correspondence is **not** proved in Lean (which uses classical reals).
- Implementers writing simulations (such as the Benefuture agent-based simulation in Julia) should:
  1. Ingest and match the canonical JSON test vectors from `spec/vectors/*.json`.
  2. Implement simulation state transitions conforming to `Step`.
  3. Validate at runtime that simulated trajectories preserve the state invariants proven in `Benefuture.Systems.State`.
- Vector files and the spec definitions they match:
  - `synergy.json`: `net_synergy`, `squashed_synergy` (L13-14).
  - `assessment.json`: `dynamic_assessment_real`, `((t > t₀ ? Me : Pr) − Pr_counter) / Th_Cx` (L48).
  - `value.json`: `compute_harm_weight` (κ = ½, q₊ = 1.5, `harmSchedule`) and `value_on_being` (items (x, w₊, w₋), κ = 2) (L61, L73).
  - `escrow.json`, `reputation.json`, `democracy.json`: escrow split, lazy decay, voting weight and EHR attenuation.
  - `freedom.json`: `fr_permissible` with longtermist defaults, `experiential_variety` (L135, L37).
  - `population.json`: `skew_key`, `population_novelty_hist`, `effective_types`, `pareto_front`, `accumulate_capped` (`Benefuture.Proposed.PopulationDirection`, `Benefuture.Governance.Incentives`).
- Runtime checks that follow from proved theorems: chosen plans pass Fr (no established harm at long-term severity or worse, expected severity within the ceiling) and never contract ℝ (`choose_plan_sound`); no delegate exceeds Th_k + max single weight (`accumulate_capped_bound`); summed novelty never exceeds the number of distinct types (`population_novelty_hist_le`).
- Regenerate vectors with `lake exe benefuture` (Mathlib-free; builds in seconds).

---

## License

This project is licensed under the **GNU Lesser General Public License v2.1** (LGPL-2.1). See the [LICENSE](LICENSE) file for complete terms.