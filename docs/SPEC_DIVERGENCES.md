# Benefuture Specification Divergences

This document records every place where the Lean 4 formal specification diverges from, chooses between interpretations of, or extends `spec/Bf_Pseudocode.txt` and the background articles (`docs/articles/*.txt`).

Per the Ground Rules:
- Sources of truth: `spec/Bf_Pseudocode.txt`, then `docs/articles/*.txt`.
- Every definition cites its pseudocode line.
- Where Lean deviates or chooses, a `-- SPEC-CHOICE:` comment is placed in the code and recorded here.
- Status tags: `[R]` ratified by the author; `[P]` proposed default; `[OPEN]` unresolved.

---

## 1. Phase 1 Divergences (Honesty and Cleanup)

### 1.1 Repugnant Conclusion ([OPEN])
- **Source**: `Philosophy.txt` mentions Parfit's Repugnant Conclusion. `Bf_Pseudocode.txt` does not specify a baseline flourishing floor.
- **Divergence**: Previous formalizations introduced an ad hoc `FLOURISHING_BASELINE_FLOOR := 100000` (0.10) and claimed "structural dissolution" of the Repugnant Conclusion.
- **Lean Spec Choice**: Removed `FLOURISHING_BASELINE_FLOOR` and the dissolution claims. Added an `[OPEN]` note and formal lemma `floor_shifts_repugnant_conclusion`: for any non-zero floor $f > 0$, a sufficiently large population $n$ at wellbeing $f$ exceeds any fixed finite flourishing population. The floor relocates the threshold rather than solving the paradox.

### 1.2 Anti-Corruption Choice Architecture (AC) ([P])
- **Source**: `Bf_Pseudocode.txt` L156: `AntiCorruption := ChoiceArchitecture(Effort(Good) < Effort(Bad));`.
- **Divergence**: Previously framed as a mathematical theorem that $a < a + b + c$ from definition.
- **Lean Spec Choice**: Recast as `AntiCorruptionDesignRequirement`: a design parameter assumption requiring restorative friction to be strictly positive (`ac_friction_pos_assumption : 0 < restorativeFriction`).

### 1.3 Anti-Cobra Vulnerability Clawbacks (AdvAp) ([P])
- **Source**: `Bf_Pseudocode.txt` L157; `Adversarial adaptation.txt` §Nuance 1.
- **Divergence**: Previously claimed a theorem eliminating bounty farming.
- **Lean Spec Choice**: Recast as `AntiCobraDesignRequirement`: clawback $\ge$ bounty is guaranteed by construction in the reward formula (`creator_liability := bounty + overhead`), but preventing bounty farming critically assumes that causal attribution successfully detects who planted the flaw (`flaw_planter_attribution_assumption`).

### 1.4 Non-Circularity and Goodhart's Law ([P])
- **Source**: `Bf_Pseudocode.txt` L46-50.
- **Divergence**: Previously claimed a theorem that metric models prevent Goodhart gaming via `m.origin.isEmpirical = true`.
- **Lean Spec Choice**: Recast as `EmpiricalMarkerRequirement`: markers are empirical by construction, which prevents syntactic self-reference, but does NOT solve Goodhart's Law. Addressing Goodhart requires latent vs observed model competition.

### 1.5 Domain Causal Grounding ([P])
- **Source**: `Bf_Pseudocode.txt` L22.
- **Divergence**: Theorem `anti_gerrymandering_causal_grounding` was a definitional tautology returning the structure field `h_causal_nonempty`.
- **Lean Spec Choice**: Retained `h_causal_nonempty` as an explicit structure field / design requirement on `Domain`.

### 1.6 Deletion of Tautological and Overclaimed Theorems
- **Tautological subtyping theorems**: Removed 93 theorems of the form `foo_is_thing : (x : Thing).id = x.id := rfl`. Coercion instances (`Coe`) are preserved.
- **Legacy Risk Claims**: Removed `CivilizationalConcern`, `BenefutureSystemMitigation`, `calculate_systemic_mitigation`, `residual_risk`, and associated theorems asserting elimination of legacy civilizational risk via arbitrary linear coefficients.
- **Constant Yield Claims**: Removed `progressive_goal_yield` (which hardcoded a constant 1000) and `progressive_preserves_core_goal_under_all_contexts`.
- **Definitional Good/Bad Theorems**: Removed `good_action_*` and `harm_causing_action_*` which merely restated `decide (delta_v > 0)`.
- **Non-Spec Synergy Additions**: Removed `net_synergy_balance`, `synergy_pair_gains`, and `synergy_superadditive` (not part of L13 pseudocode formula).
- **Epistemic Dominance of Wireheading**: Dropped integer toy versions `epistemic_dominates_wireheading` and `epistemic_dominates_saturated_wireheading` pending faithful real formulation in Phase 2.
