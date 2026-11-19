/-
  BenefutureTest.Differential
  Cedar-style differential testing of the Float reference (`BenefutureReference`) against the
  Mathlib specification (`Benefuture`), run at build time: `lake build` elaborates this module and
  fails if any check fails.

  The chain for each rule covered here:
    ℝ specification  =  ℚ oracle    (proved below: `*_spec`, the oracle cast to ℝ is the spec)
    ℚ oracle         ≈  Float reference   (tested below on generated inputs, within tolerance)
  ℚ is exact and computable, so the oracle evaluates what the specification says, and the proof
  ties it to the specification itself rather than to a second transcription. Inputs are dyadic
  rationals, exactly representable as Float, so comparisons (`cur < cap` in capped delegation)
  branch identically on both sides; outputs are compared within 1e-9 relative tolerance.

  Covered (ℝ spec ↔ Float reference): `supply_delta`, `competition_efficiency`,
  `rolling_average`, `accumulate_capped`, `p_forgive`, `p_overreact`, `severity_score` at
  `defaultFrParams`, `Voting_weight` ↔ `Voting_weight_ref`, `Proposed.shapley` ↔ `shapley_ref`,
  `Proposed.shapley_sampled` ↔ `shapley_sampled_ref`, `Proposed.recordCredence` ↔
  `record_credence_ref`. Interval-bound ℚ oracles covering rules with exp, log, sqrt:
  `Rep_decay_ref`, `shapley_sample_count_ref`, `phi_ref` (at q = 1), `normal_cdf_ref`, `credence_ref`.
  Computable specifications compared directly: `bounty_reward` (ℤ) ↔ `advap_reward_ref` at share
  1/10 and floor 1 (equal where the prevented harm is a multiple of 10, within 1 otherwise: the spec
  floors harm / 10), `upfront_payment` (ℤ, parts per million) ↔ `Escrow_split_ref` (within 1, by
  flooring). Exact checks over ℚ: the mean of marginals over all n! orderings equals the subset form
  of Shapley for n ≤ 5 (the identity cited, not proved, in `Proposed.ShapleySampling`).

  Not covered: rules whose specification involves real exponents or noncomputable choices
  (`Sy`, `HaWt`, `V`, `accuracy`), rules with no ℝ counterpart in `Benefuture/` (most of
  `BenefutureReference.Domains`, `Records`, `Justice`, `Adversarial`, `ParamSpace`,
  `Measurement`'s model scoring); and noncomputable choices (`g_choose`, `pareto_front` over
  `Classical`). These rely on `spec/vectors` and the Julia suites. No refinement proof links ℝ to
  Float: Float rounding is tested, not bounded.
-/

import Mathlib.Data.Rat.Cast.Order
import Mathlib.Data.Rat.Cast.Lemmas
import Mathlib.Algebra.Order.Field.Rat
import Benefuture.Economy.Pricing
import Benefuture.Economy.Currency
import Benefuture.Governance.Incentives
import Benefuture.Governance.ExternalHarm
import Benefuture.Governance.Adversarial
import Benefuture.Subgoals.Freedom
import Benefuture.Subgoals.Justice
import Benefuture.Subgoals.Morality
import Benefuture.Subgoals.Art
import Benefuture.Epistemology.InfoHandling
import Benefuture.Epistemology.Truth
import Benefuture.Ontology.Entity
import Benefuture.Systems.TechnologyNetwork
import Benefuture.Systems.ParamSpace
import Benefuture.Axiology.Priorities
import Benefuture.Proposed.OutcomeDistribution
import Benefuture.Proposed.ShapleySampling
import Benefuture.Proposed.RecordCredence
import BenefutureReference

namespace BenefutureTest

open Finset

/-! ## ℚ oracles, each proved to be its ℝ specification -/

def supplyQ (g c h : ℚ) : ℚ := g - c - h
theorem supplyQ_spec (g c h : ℚ) :
    (supplyQ g c h : ℝ) = Benefuture.Economy.supply_delta g c h := by
  simp [supplyQ, Benefuture.Economy.supply_delta]

def efficiencyQ (dV c dt : ℚ) : ℚ := dV / (c + dt)
theorem efficiencyQ_spec (dV c dt : ℚ) :
    (efficiencyQ dV c dt : ℝ) = Benefuture.Economy.competition_efficiency dV c dt := by
  simp [efficiencyQ, Benefuture.Economy.competition_efficiency]

def rollingQ (w : List ℚ) : ℚ := if w = [] then 0 else w.sum / w.length
theorem rollingQ_spec (w : List ℚ) :
    (rollingQ w : ℝ) = Benefuture.Axiology.rolling_average (w.map (↑)) := by
  unfold rollingQ Benefuture.Axiology.rolling_average
  by_cases h : w = []
  · simp [h]
  · simp [h, Rat.cast_list_sum]

def cappedQ (cap : ℚ) : ℚ → List ℚ → ℚ
  | cur, [] => cur
  | cur, w :: ws => cappedQ cap (if cur < cap then cur + w else cur) ws
theorem cappedQ_spec (cap : ℚ) : ∀ (ws : List ℚ) (cur : ℚ),
    (cappedQ cap cur ws : ℝ) = Benefuture.Governance.accumulate_capped cap cur (ws.map (↑))
  | [], cur => by simp [cappedQ, Benefuture.Governance.accumulate_capped]
  | w :: ws, cur => by
    simp only [cappedQ, List.map_cons, Benefuture.Governance.accumulate_capped]
    rw [cappedQ_spec cap ws]
    by_cases h : cur < cap
    · have h' : (cur : ℝ) < cap := by exact_mod_cast h
      simp [h, h']
    · have h' : ¬ (cur : ℝ) < cap := by exact_mod_cast h
      simp [h, h']

def forgiveQ (alpha re : ℚ) : ℚ := min 1 (alpha * re)
def overreactQ (alpha delta rePos reNeg : ℚ) : ℚ := min (1 - forgiveQ alpha rePos) (delta * reNeg)
theorem forgiveQ_spec (alpha delta margin re : ℚ) :
    (forgiveQ alpha re : ℝ) = Benefuture.Governance.p_forgive ⟨alpha, delta, margin⟩ re := by
  simp [forgiveQ, Benefuture.Governance.p_forgive]
theorem overreactQ_spec (alpha delta margin rp rn : ℚ) :
    (overreactQ alpha delta rp rn : ℝ) = Benefuture.Governance.p_overreact ⟨alpha, delta, margin⟩ rp rn := by
  simp [overreactQ, forgiveQ, Benefuture.Governance.p_overreact, Benefuture.Governance.p_forgive]

def severityQ (a b c d e : ℚ) : ℚ := 1000 * a + 100 * b + 10 * c + 1 * d + (1 / 2) * e
theorem severityQ_spec (a b c d e : ℚ) :
    (severityQ a b c d e : ℝ) = Benefuture.Subgoals.severity_score
      { irreparable := a, irreversible := b, longterm := c, passing := d, timeLoss := e }
      Benefuture.Subgoals.defaultFrParams := by
  simp [severityQ, Benefuture.Subgoals.severity_score, Benefuture.Subgoals.defaultFrParams]
  norm_num

def shapleyQ (n : ℕ) (v : Finset (Fin n) → ℚ) (i : Fin n) : ℚ :=
  ∑ S ∈ (univ.erase i).powerset,
    ((S.card.factorial * (n - S.card - 1).factorial : ℕ) : ℚ) / (n.factorial : ℚ) * (v (insert i S) - v S)
theorem shapleyQ_spec (n : ℕ) (v : Finset (Fin n) → ℚ) (i : Fin n) :
    (shapleyQ n v i : ℝ) = Benefuture.Proposed.shapley univ (fun S => (v S : ℝ)) i := by
  simp only [shapleyQ, Benefuture.Proposed.shapley, card_univ, Fintype.card_fin]
  push_cast
  rfl

def marginalsFromQ {n : ℕ} (v : Finset (Fin n) → ℚ) : Finset (Fin n) → List (Fin n) → Fin n → ℚ
  | _, [], _ => 0
  | pre, a :: rest, i => (if i = a then v (insert a pre) - v pre else 0) + marginalsFromQ v (insert a pre) rest i
def sampledQ {n : ℕ} (v : Finset (Fin n) → ℚ) (samples : List (List (Fin n))) (i : Fin n) : ℚ :=
  (samples.map fun σ => marginalsFromQ v ∅ σ i).sum / samples.length

theorem marginalsFromQ_spec {n : ℕ} (v : Finset (Fin n) → ℚ) : ∀ (σ : List (Fin n)) (pre : Finset (Fin n)) (i : Fin n),
    (marginalsFromQ v pre σ i : ℝ) = Benefuture.Proposed.marginalsFrom (fun S => (v S : ℝ)) pre σ i
  | [], _, _ => by simp [marginalsFromQ, Benefuture.Proposed.marginalsFrom]
  | a :: rest, pre, i => by
    simp only [marginalsFromQ, Benefuture.Proposed.marginalsFrom]
    rw [← marginalsFromQ_spec v rest (insert a pre) i]
    split_ifs <;> push_cast <;> ring
theorem sampledQ_spec {n : ℕ} (v : Finset (Fin n) → ℚ) (samples : List (List (Fin n))) (i : Fin n) :
    (sampledQ v samples i : ℝ) = Benefuture.Proposed.shapley_sampled (fun S => (v S : ℝ)) samples i := by
  unfold sampledQ Benefuture.Proposed.shapley_sampled Benefuture.Proposed.marginals
  push_cast [Rat.cast_list_sum]
  simp only [List.map_map, Function.comp_def, marginalsFromQ_spec]

def recordWeightQ (v e : ℚ) : ℚ := if e < v then 1 else if e = v then 1 / 2 else 0
def recordCredenceQ (cap v : ℚ) (errs : List ℚ) : ℚ :=
  max (1 - cap) (min cap (if errs = [] then 1 / 2 else (errs.map (recordWeightQ v)).sum / errs.length))
theorem recordCredenceQ_spec (cap v : ℚ) (errs : List ℚ) :
    (recordCredenceQ cap v errs : ℝ) = Benefuture.Proposed.recordCredence cap v (errs.map (↑)) := by
  have hw : ∀ e : ℚ, ((recordWeightQ v e : ℚ) : ℝ) = Benefuture.Proposed.recordWeight v e := by
    intro e; unfold recordWeightQ Benefuture.Proposed.recordWeight
    by_cases h1 : e < v
    · have h1' : (e : ℝ) < v := by exact_mod_cast h1
      simp [h1, h1']
    · have h1' : ¬ (e : ℝ) < v := by exact_mod_cast h1
      by_cases h2 : e = v
      · subst h2; simp
      · have h2' : (e : ℝ) ≠ v := by exact_mod_cast h2
        simp [h1, h1', h2, h2']
  have hs : ((errs.map (recordWeightQ v)).sum : ℝ) = Benefuture.Proposed.recordScore v (errs.map (↑)) := by
    unfold Benefuture.Proposed.recordScore
    induction errs with
    | nil => simp
    | cons e rest ih => simp [List.map_cons, List.sum_cons, hw, ih]
  unfold recordCredenceQ Benefuture.Proposed.recordCredence
  by_cases h : errs = []
  · subst h; simp
  · simp [h, hs, Rat.cast_max, Rat.cast_min]

def votingWeightQ (base expWt : ℚ) (profile : List (ℚ × ℚ)) (impWt impact : ℚ) : ℚ :=
  let expertise := (profile.map fun (w, r) => w * r).sum
  base + expWt * expertise + impWt * impact

theorem votingWeightQ_spec (base expWt : ℚ) (profile : List (ℚ × ℚ)) (impWt impact : ℚ) :
    (votingWeightQ base expWt profile impWt impact : ℝ) =
      (base : ℝ) + (expWt : ℝ) * ((profile.map fun (w, r) => (w : ℝ) * (r : ℝ)).sum) +
        (impWt : ℝ) * (impact : ℝ) := by
  dsimp [votingWeightQ]
  push_cast [Rat.cast_list_sum]
  simp only [List.map_map, Function.comp_def]
  push_cast
  rfl

def accidentContributorQ (harm cap : ℚ) : ℚ := min harm cap
def accidentAdminQ (harm cap : ℚ) : ℚ := harm - min harm cap
theorem accidentContributorQ_spec (harm cap : ℚ) :
    (accidentContributorQ harm cap : ℝ) = Benefuture.Subgoals.accident_contributor harm cap := by
  simp [accidentContributorQ, Benefuture.Subgoals.accident_contributor, Rat.cast_min]
theorem accidentAdminQ_spec (harm cap : ℚ) :
    (accidentAdminQ harm cap : ℝ) = Benefuture.Subgoals.accident_admin harm cap := by
  simp [accidentAdminQ, Benefuture.Subgoals.accident_admin, Rat.cast_sub, Rat.cast_min]

def sanctionEscrowCredenceQ (cred negShare : ℚ) (deceptions domNegEvents patternMin : Nat)
    (growth floorC : ℚ) : ℚ :=
  let esc := deceptions + Benefuture.Subgoals.pattern_escalation_repeats domNegEvents patternMin
  max floorC ((1 / 2 + (cred - 1 / 2) * (1 - negShare)) * (1 / (1 + growth)) ^ esc)

theorem sanctionEscrowCredenceQ_spec (cred negShare : ℚ) (deceptions domNegEvents patternMin : Nat)
    (growth floorC : ℚ) :
    (sanctionEscrowCredenceQ cred negShare deceptions domNegEvents patternMin growth floorC : ℝ) =
      Benefuture.Subgoals.sanction_escrow_credence cred negShare deceptions domNegEvents patternMin growth floorC := by
  simp [sanctionEscrowCredenceQ, Benefuture.Subgoals.sanction_escrow_credence, Rat.cast_max]

def rehabilitateRestraintQ (baseShare : ℚ) (crimeEvents patternMin : Nat)
    (stepDecay minShare : ℚ) : ℚ :=
  let esc := Benefuture.Subgoals.pattern_escalation_repeats crimeEvents patternMin
  if esc = 0 then baseShare else max minShare (baseShare * stepDecay ^ esc)

theorem rehabilitateRestraintQ_spec (baseShare : ℚ) (crimeEvents patternMin : Nat)
    (stepDecay minShare : ℚ) :
    (rehabilitateRestraintQ baseShare crimeEvents patternMin stepDecay minShare : ℝ) =
      Benefuture.Subgoals.rehabilitate_restraint baseShare crimeEvents patternMin stepDecay minShare := by
  unfold rehabilitateRestraintQ Benefuture.Subgoals.rehabilitate_restraint
  by_cases h : Benefuture.Subgoals.pattern_escalation_repeats crimeEvents patternMin = 0 <;>
    simp [h, Rat.cast_max]

def raValuePerCostQ (measuredGain resourceCost auditCost fallback : ℚ) : ℚ :=
  let totalCost := resourceCost + max 0 auditCost
  if 0 < totalCost then measuredGain / totalCost else fallback

theorem raValuePerCostQ_spec (measuredGain resourceCost auditCost fallback : ℚ) :
    (raValuePerCostQ measuredGain resourceCost auditCost fallback : ℝ) =
      Benefuture.Economy.ra_value_per_cost measuredGain resourceCost auditCost fallback := by
  unfold raValuePerCostQ Benefuture.Economy.ra_value_per_cost
  by_cases h : (0 : ℚ) < resourceCost + max 0 auditCost
  · have hr : (0 : ℝ) < (resourceCost : ℝ) + max 0 (auditCost : ℝ) := by
      have : ((0 : ℚ) : ℝ) < ((resourceCost + max 0 auditCost : ℚ) : ℝ) := Rat.cast_lt.mpr h
      simpa [Rat.cast_add, Rat.cast_max] using this
    simp [h, hr, Rat.cast_div, Rat.cast_add, Rat.cast_max]
  · have hr : ¬ ((0 : ℝ) < (resourceCost : ℝ) + max 0 (auditCost : ℝ)) := by
      intro hpos
      apply h
      have : ((0 : ℚ) : ℝ) < ((resourceCost + max 0 auditCost : ℚ) : ℝ) := by
        simpa [Rat.cast_add, Rat.cast_max] using hpos
      exact Rat.cast_lt.mp this
    simp [h, hr]

def raCommonsReserveQ (expectedNeed fallbackRate horizon : ℚ) : ℚ :=
  max 0 expectedNeed * max 0 fallbackRate * max 0 horizon

theorem raCommonsReserveQ_spec (expectedNeed fallbackRate horizon : ℚ) :
    (raCommonsReserveQ expectedNeed fallbackRate horizon : ℝ) =
      Benefuture.Economy.ra_commons_reserve expectedNeed fallbackRate horizon := by
  simp [raCommonsReserveQ, Benefuture.Economy.ra_commons_reserve, Rat.cast_mul, Rat.cast_max]

def raContractionFactorQ (claims deliverableCap rate minScale : ℚ) : ℚ :=
  if claims ≤ deliverableCap ∨ deliverableCap ≤ 0 then 1
  else max minScale (1 - rate * min 1 ((claims - deliverableCap) / deliverableCap))

theorem raContractionFactorQ_spec (claims deliverableCap rate minScale : ℚ) :
    (raContractionFactorQ claims deliverableCap rate minScale : ℝ) =
      Benefuture.Economy.ra_contraction_factor claims deliverableCap rate minScale := by
  unfold raContractionFactorQ Benefuture.Economy.ra_contraction_factor
  by_cases h : claims ≤ deliverableCap ∨ deliverableCap ≤ 0
  · have hr : (claims : ℝ) ≤ (deliverableCap : ℝ) ∨ (deliverableCap : ℝ) ≤ 0 := by
      rcases h with h1 | h2
      · exact Or.inl (by exact_mod_cast h1)
      · exact Or.inr (by exact_mod_cast h2)
    simp [h, hr]
  · have hr : ¬ ((claims : ℝ) ≤ (deliverableCap : ℝ) ∨ (deliverableCap : ℝ) ≤ 0) := by
      intro hor; apply h
      rcases hor with h1 | h2
      · exact Or.inl (by exact_mod_cast h1)
      · exact Or.inr (by exact_mod_cast h2)
    simp [h, hr, Rat.cast_max, Rat.cast_sub, Rat.cast_mul, Rat.cast_min, Rat.cast_div]

def responsibilityFactorQ (isAct isInformed hasDuty : Bool) (cf sev acc : ℚ) : ℚ :=
  let roleWeight : ℚ :=
    if !isAct && !hasDuty then 0
    else if isInformed then 1
    else min 1 (max 0 acc)
  roleWeight * min 1 (max 0 cf) * max 0 sev

theorem responsibilityFactorQ_spec (isAct isInformed hasDuty : Bool) (cf sev acc : ℚ) :
    (responsibilityFactorQ isAct isInformed hasDuty cf sev acc : ℝ) =
      Benefuture.Subgoals.responsibility_factor isAct isInformed hasDuty cf sev acc := by
  unfold responsibilityFactorQ Benefuture.Subgoals.responsibility_factor
  cases isAct <;> cases isInformed <;> cases hasDuty <;>
    simp [Rat.cast_mul, Rat.cast_min, Rat.cast_max]

def weightedAttestationSayQ (threshold : ℚ) : List ℚ → List ℚ → ℚ
  | c :: cs, w :: ws =>
    (if c ≥ threshold then max 0 (min 1 w) else 0) + weightedAttestationSayQ threshold cs ws
  | _, _ => 0

theorem weightedAttestationSayQ_spec (threshold : ℚ) (confs weights : List ℚ) :
    (weightedAttestationSayQ threshold confs weights : ℝ) =
      Benefuture.Systems.weighted_attestation_say (threshold : ℝ)
        (confs.map (fun q : ℚ => (q : ℝ))) (weights.map (fun q : ℚ => (q : ℝ))) := by
  induction confs generalizing weights with
  | nil => simp [weightedAttestationSayQ, Benefuture.Systems.weighted_attestation_say]
  | cons c cs ih =>
    cases weights with
    | nil => simp [weightedAttestationSayQ, Benefuture.Systems.weighted_attestation_say]
    | cons w ws =>
      unfold weightedAttestationSayQ Benefuture.Systems.weighted_attestation_say
      simp only [List.map_cons, Rat.cast_add, ih ws]
      by_cases hc : c ≥ threshold
      · have hcr : (c : ℝ) ≥ (threshold : ℝ) := Rat.cast_le.mpr hc
        simp [hc, hcr, Rat.cast_max, Rat.cast_min]
      · have hcr : ¬ ((c : ℝ) ≥ (threshold : ℝ)) := by exact_mod_cast hc
        simp [hc, hcr]

def bindingAdmitsWeightedQ (confs weights : List ℚ) (threshold quorumWeight : ℚ) : Bool :=
  decide (weightedAttestationSayQ threshold confs weights ≥ quorumWeight)

theorem bindingAdmitsWeightedQ_spec (confs weights : List ℚ) (threshold quorumWeight : ℚ) :
    bindingAdmitsWeightedQ confs weights threshold quorumWeight = true ↔
      Benefuture.Systems.binding_admits_weighted_spec
        (confs.map (fun q : ℚ => (q : ℝ))) (weights.map (fun q : ℚ => (q : ℝ)))
        (threshold : ℝ) (quorumWeight : ℝ) := by
  unfold bindingAdmitsWeightedQ Benefuture.Systems.binding_admits_weighted_spec
  rw [← weightedAttestationSayQ_spec]
  simp only [decide_eq_true_eq]
  exact ⟨fun h => Rat.cast_le.mpr h, fun h => Rat.cast_le.mp h⟩

def decidingScopeFromQ (k : ℕ) : List (ℚ × Bool) → ℚ → ℕ
  | [], _ => k
  | [_], _ => k
  | (s, w) :: rest, shareMin =>
    if w && decide (shareMin ≤ s) then k else decidingScopeFromQ (k + 1) rest shareMin

def decidingScopeQ (scopes : List (ℚ × Bool)) (shareMin : ℚ) : ℕ :=
  decidingScopeFromQ 0 scopes shareMin

theorem decidingScopeFromQ_spec (k : ℕ) (scopes : List (ℚ × Bool)) (shareMin : ℚ) :
    decidingScopeFromQ k scopes shareMin =
      Benefuture.Systems.deciding_scope_from k
        (scopes.map (fun sw => ((sw.1 : ℝ), sw.2))) (shareMin : ℝ) := by
  induction scopes generalizing k with
  | nil => simp [decidingScopeFromQ, Benefuture.Systems.deciding_scope_from]
  | cons sw rest ih =>
    cases rest with
    | nil => simp [decidingScopeFromQ, Benefuture.Systems.deciding_scope_from]
    | cons sw₁ tl =>
      unfold decidingScopeFromQ Benefuture.Systems.deciding_scope_from
      simp only [List.map_cons, ih (k + 1)]
      by_cases hw : sw.2 = true
      · by_cases hs : shareMin ≤ sw.1
        · have hsr : (shareMin : ℝ) ≤ (sw.1 : ℝ) := Rat.cast_le.mpr hs
          simp [hw, hs, hsr]
        · have hsr : ¬ ((shareMin : ℝ) ≤ (sw.1 : ℝ)) := by exact_mod_cast hs
          simp [hw, hs, hsr]
      · simp [hw]

theorem decidingScopeQ_spec (scopes : List (ℚ × Bool)) (shareMin : ℚ) :
    decidingScopeQ scopes shareMin =
      Benefuture.Systems.deciding_scope
        (scopes.map (fun sw => ((sw.1 : ℝ), sw.2))) (shareMin : ℝ) :=
  decidingScopeFromQ_spec 0 scopes shareMin

def extendedSelfFeedbackQ : List ℚ → List ℚ → ℚ
  | c :: cs, d :: ds => max 0 (min 1 c) * d + extendedSelfFeedbackQ cs ds
  | _, _ => 0

theorem extendedSelfFeedbackQ_spec (couplings deltas : List ℚ) :
    (extendedSelfFeedbackQ couplings deltas : ℝ) =
      Benefuture.Subgoals.extended_self_feedback (couplings.map (↑)) (deltas.map (↑)) := by
  induction couplings generalizing deltas with
  | nil => simp [extendedSelfFeedbackQ, Benefuture.Subgoals.extended_self_feedback]
  | cons c cs ih =>
    cases deltas with
    | nil => simp [extendedSelfFeedbackQ, Benefuture.Subgoals.extended_self_feedback]
    | cons d ds =>
      simp only [extendedSelfFeedbackQ, List.map_cons,
        Benefuture.Subgoals.extended_self_feedback, Rat.cast_add, Rat.cast_mul, ih ds]
      congr 2
      push_cast
      rfl

def propagatedControlQ : List ℚ → ℚ
  | [] => 1
  | c :: cs => max 0 (min 1 c) * propagatedControlQ cs

theorem propagatedControlQ_spec (controls : List ℚ) :
    (propagatedControlQ controls : ℝ) =
      Benefuture.Ontology.propagated_control (controls.map (↑)) := by
  induction controls with
  | nil => simp [propagatedControlQ, Benefuture.Ontology.propagated_control]
  | cons c cs ih =>
    simp only [propagatedControlQ, List.map_cons,
      Benefuture.Ontology.propagated_control, Rat.cast_mul, ih]
    congr 1
    push_cast
    rfl

def propagatedLiabilityQ (directHarm : ℚ) (controls : List ℚ) : ℚ :=
  if directHarm ≤ 0 then 0 else directHarm * propagatedControlQ controls

theorem propagatedLiabilityQ_spec (directHarm : ℚ) (controls : List ℚ) :
    (propagatedLiabilityQ directHarm controls : ℝ) =
      Benefuture.Ontology.propagated_liability directHarm (controls.map (↑)) := by
  unfold propagatedLiabilityQ Benefuture.Ontology.propagated_liability
  by_cases h : directHarm ≤ 0
  · have h' : (directHarm : ℝ) ≤ 0 := by exact_mod_cast h
    simp [h, h']
  · have h' : ¬ ((directHarm : ℝ) ≤ 0) := by exact_mod_cast h
    simp [h, h', propagatedControlQ_spec]

def endOfHorizonScoreQ
    (ownRemaining : ℚ) (alive : Bool) (couplings deltas : List ℚ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℚ) : ℚ :=
  (if alive then ownRemaining else 0) +
  extendedSelfFeedbackQ couplings deltas +
  max 0 causalShare * delayedOutcome +
  max 0 ideologicalShare * ideologicalGain

theorem endOfHorizonScoreQ_spec
    (ownRemaining : ℚ) (alive : Bool) (couplings deltas : List ℚ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℚ) :
    (endOfHorizonScoreQ ownRemaining alive couplings deltas
      causalShare delayedOutcome ideologicalShare ideologicalGain : ℝ) =
      Benefuture.Subgoals.end_of_horizon_score ownRemaining alive
        (couplings.map (↑)) (deltas.map (↑))
        causalShare delayedOutcome ideologicalShare ideologicalGain := by
  unfold endOfHorizonScoreQ Benefuture.Subgoals.end_of_horizon_score
  rw [← extendedSelfFeedbackQ_spec]
  cases alive <;> simp

def endOfHorizonPredictedScoreQ
    (immediateOwn futureOwn : ℚ) (aliveAtOutcome : Bool) (couplings deltas : List ℚ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℚ) : ℚ :=
  immediateOwn +
  (if aliveAtOutcome then futureOwn else 0) +
  extendedSelfFeedbackQ couplings deltas +
  max 0 causalShare * delayedOutcome +
  max 0 ideologicalShare * ideologicalGain

theorem endOfHorizonPredictedScoreQ_spec
    (immediateOwn futureOwn : ℚ) (aliveAtOutcome : Bool) (couplings deltas : List ℚ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℚ) :
    (endOfHorizonPredictedScoreQ immediateOwn futureOwn aliveAtOutcome couplings deltas
      causalShare delayedOutcome ideologicalShare ideologicalGain : ℝ) =
      Benefuture.Subgoals.end_of_horizon_predicted_score immediateOwn futureOwn aliveAtOutcome
        (couplings.map (↑)) (deltas.map (↑))
        causalShare delayedOutcome ideologicalShare ideologicalGain := by
  unfold endOfHorizonPredictedScoreQ Benefuture.Subgoals.end_of_horizon_predicted_score
  rw [← extendedSelfFeedbackQ_spec]
  cases aliveAtOutcome <;> simp

def ihzAccessRiskQ (clearance reqEd potentialHarm : ℚ) : ℚ :=
  if clearance ≥ reqEd then 0 else max 0 potentialHarm

theorem ihzAccessRiskQ_spec (clearance reqEd potentialHarm : ℚ) :
    (ihzAccessRiskQ clearance reqEd potentialHarm : ℝ) =
      Benefuture.Epistemology.ihz_access_risk_real clearance reqEd potentialHarm := by
  unfold ihzAccessRiskQ Benefuture.Epistemology.ihz_access_risk_real
  by_cases h : clearance ≥ reqEd
  · have h' : (clearance : ℝ) ≥ (reqEd : ℝ) := by exact_mod_cast h
    simp [h, h']
  · have h' : ¬ ((clearance : ℝ) ≥ (reqEd : ℝ)) := by exact_mod_cast h
    simp [h, h']

def artDistributionL1LossQ : List ℚ → List ℚ → ℚ
  | p :: ps, q :: qs => |p - q| + artDistributionL1LossQ ps qs
  | _, _ => 0

theorem artDistributionL1LossQ_spec (intent reception : List ℚ) :
    (artDistributionL1LossQ intent reception : ℝ) =
      Benefuture.Subgoals.art_distribution_l1_loss (intent.map (↑)) (reception.map (↑)) := by
  induction intent generalizing reception with
  | nil => simp [artDistributionL1LossQ, Benefuture.Subgoals.art_distribution_l1_loss]
  | cons p ps ih =>
    cases reception with
    | nil => simp [artDistributionL1LossQ, Benefuture.Subgoals.art_distribution_l1_loss]
    | cons q qs =>
      simp only [artDistributionL1LossQ, List.map_cons,
        Benefuture.Subgoals.art_distribution_l1_loss, Rat.cast_add, Rat.cast_abs, Rat.cast_sub, ih qs]

def artSuccessScoreQ (intent reception : List ℚ) : ℚ :=
  max 0 (1 - artDistributionL1LossQ intent reception / 2)

theorem artSuccessScoreQ_spec (intent reception : List ℚ) :
    (artSuccessScoreQ intent reception : ℝ) =
      Benefuture.Subgoals.art_success_score (intent.map (↑)) (reception.map (↑)) := by
  unfold artSuccessScoreQ Benefuture.Subgoals.art_success_score
  rw [← artDistributionL1LossQ_spec]
  push_cast
  rfl

def artSurplusValueQ (truthDeltaU novelty : ℚ) : ℚ :=
  max 0 truthDeltaU + max 0 novelty

theorem artSurplusValueQ_spec (truthDeltaU novelty : ℚ) :
    (artSurplusValueQ truthDeltaU novelty : ℝ) =
      Benefuture.Subgoals.art_surplus_value truthDeltaU novelty := by
  unfold artSurplusValueQ Benefuture.Subgoals.art_surplus_value
  push_cast
  rfl

def chainTruthLevelQ (baseLevel : ℚ) (hops : List ℚ) : ℚ :=
  max 0 (min 1 baseLevel) * propagatedControlQ hops

theorem chainTruthLevelQ_spec (baseLevel : ℚ) (hops : List ℚ) :
    (chainTruthLevelQ baseLevel hops : ℝ) =
      Benefuture.Epistemology.chain_truth_level baseLevel (hops.map (↑)) := by
  unfold chainTruthLevelQ Benefuture.Epistemology.chain_truth_level
  rw [← propagatedControlQ_spec]
  push_cast
  rfl

def advapRecountTallyQ : List (ℚ × ℚ × Bool) → ℚ
  | [] => 0
  | (h, v, a) :: rest => (if a then h * v else 0) + advapRecountTallyQ rest

theorem advapRecountTallyQ_spec (entries : List (ℚ × ℚ × Bool)) :
    (advapRecountTallyQ entries : ℝ) =
      Benefuture.Governance.advap_recount_tally
        (entries.map fun e => ((e.1 : ℝ), (e.2.1 : ℝ), e.2.2)) := by
  induction entries with
  | nil => simp [advapRecountTallyQ, Benefuture.Governance.advap_recount_tally]
  | cons hd tl ih =>
      rcases hd with ⟨h, v, a⟩
      cases a <;>
        simp [advapRecountTallyQ, Benefuture.Governance.advap_recount_tally, ih]

def advapRecountQ (entries : List (ℚ × ℚ × Bool)) (truth : ℚ) : Bool :=
  if 0 ≤ advapRecountTallyQ entries then decide (0 < truth) else decide (truth < 0)

theorem advapRecountQ_spec (entries : List (ℚ × ℚ × Bool)) (truth : ℚ) :
    advapRecountQ entries truth =
      Benefuture.Governance.advap_recount_correct
        (entries.map fun e => ((e.1 : ℝ), (e.2.1 : ℝ), e.2.2)) (truth : ℝ) := by
  unfold advapRecountQ Benefuture.Governance.advap_recount_correct
  rw [← advapRecountTallyQ_spec]
  have h1 : decide (0 ≤ (advapRecountTallyQ entries : ℝ)) = decide (0 ≤ advapRecountTallyQ entries) := by
    simp [Rat.cast_nonneg]
  have h2 : decide ((0 : ℝ) < (truth : ℝ)) = decide (0 < truth) := by
    simp [Rat.cast_pos]
  have h3 : decide ((truth : ℝ) < 0) = decide (truth < 0) := by
    simp [Rat.cast_lt_zero]
  rw [h2, h3]
  by_cases h : 0 ≤ advapRecountTallyQ entries <;>
    simp [h, show (0 : ℝ) ≤ (advapRecountTallyQ entries : ℝ) ↔ 0 ≤ advapRecountTallyQ entries from Rat.cast_nonneg]

/-! ## Interval-bound oracles for nonlinear functions -/

/-- Rational square root bounds via Heron's method. For S ≥ 0, returns (lo, hi) such that lo ≤ √S ≤ hi. -/
def sqrtBoundsQ (S : ℚ) : ℚ × ℚ :=
  if S ≤ 0 then (0, 0)
  else
    let nBits := S.num.natAbs.log2
    let dBits := S.den.log2
    let halfExp : ℤ := ((nBits : ℤ) - (dBits : ℤ)) / 2
    let x0 : ℚ :=
      if halfExp ≥ 0 then (2 : ℚ) ^ halfExp.toNat
      else 1 / ((2 : ℚ) ^ (-halfExp).toNat)
    let rec loop (x : ℚ) : Nat → ℚ
      | 0 => x
      | n + 1 => loop ((x + S / x) / 2) n
    let xFinal := loop x0 5
    let lo := min xFinal (S / xFinal)
    let hi := max xFinal (S / xFinal)
    (lo, hi)

/-- Rational exp(-u) bounds for u ≥ 0. Returns (lo, hi) such that lo ≤ exp(-u) ≤ hi. -/
def expNegBoundsQ (u : ℚ) : ℚ × ℚ :=
  if u ≤ 0 then (1, 1)
  else if u ≥ 80 then (0, 1 / (2 ^ 80 : ℚ))
  else
    let rec reduce (x : ℚ) (k : Nat) : Nat → ℚ × Nat
      | 0 => (x, k)
      | fuel + 1 =>
        if x ≤ 1 / 2 then (x, k)
        else reduce (x / 2) (k + 1) fuel
    let (v, k) := reduce u 0 8
    let rec taylor (term sum : ℚ) (i : Nat) : Nat → ℚ × ℚ
      | 0 => (sum, sum + term * v / (i + 1))
      | n + 1 =>
        let term' := term * v / (i + 1)
        let sum' := if (i + 1) % 2 == 1 then sum - term' else sum + term'
        taylor term' sum' (i + 1) n
    let (baseLo, baseHi) := taylor 1 1 0 15
    let rec squareK (lo hi : ℚ) : Nat → ℚ × ℚ
      | 0 => (lo, hi)
      | n + 1 => squareK (lo * lo) (hi * hi) n
    squareK (max 0 baseLo) baseHi k

/-- Rational ln(x) bounds for x ≥ 1. Returns (lo, hi) such that lo ≤ ln(x) ≤ hi. -/
def lnBoundsQ (x : ℚ) : ℚ × ℚ :=
  if x ≤ 1 then (0, 0)
  else
    let ln2Lo : ℚ := 6931471805599 / 10000000000000
    let ln2Hi : ℚ := 6931471805600 / 10000000000000
    let rec reduce (z : ℚ) (k : Nat) : Nat → ℚ × Nat
      | 0 => (z, k)
      | fuel + 1 =>
        if z < 2 then (z, k)
        else reduce (z / 2) (k + 1) fuel
    let (w, k) := reduce x 0 32
    let y := (w - 1) / (w + 1)
    let y2 := y * y
    let rec series (term : ℚ) (sum : ℚ) (idx : Nat) : Nat → ℚ × ℚ
      | 0 =>
        let tailBound := if 1 - y2 = 0 then 0 else term * y2 / ((2 * idx + 1) * (1 - y2))
        (2 * sum, 2 * (sum + tailBound))
      | n + 1 =>
        let term' := term * y2
        series term' (sum + term' / (2 * (idx + 1) + 1)) (idx + 1) n
    let (baseLo, baseHi) := series y y 0 12
    (baseLo + k * ln2Lo, baseHi + k * ln2Hi)

def repDecayBoundsQ (score dt lambda : ℚ) : ℚ × ℚ :=
  if dt ≤ 0 then (score, score)
  else
    let (elo, ehi) := expNegBoundsQ (lambda * dt)
    if score ≥ 0 then (score * elo, score * ehi)
    else (score * ehi, score * elo)

def shapleySampleCountBoundsQ (n : Nat) (eps delta : ℚ) : Nat × Nat :=
  if eps ≤ 0 || delta ≤ 0 || n == 0 then (0, 0)
  else
    let x := 2 * (n : ℚ) / delta
    let denom := 2 * eps * eps
    let (lnLo, lnHi) := lnBoundsQ x
    let ceilQ (q : ℚ) : Nat :=
      if q ≤ 0 then 0
      else (q.num + q.den - 1) / q.den |>.toNat
    (ceilQ (lnLo / denom), ceilQ (lnHi / denom))

def phiBoundsQ (items : List (ℚ × ℚ)) (kappa : ℚ) : ℚ × ℚ :=
  let linearSum := (items.map fun (a, w) => w * a).sum
  let pairs := BenefutureReference.crossPairs items
  let crossSum := (pairs.map fun ((a1, w1), (a2, w2)) => w1 * w2 * (a1 * a2)).sum
  let (sqrtLo, sqrtHi) := sqrtBoundsQ crossSum
  if kappa ≥ 0 then
    (linearSum + kappa * sqrtLo, linearSum + kappa * sqrtHi)
  else
    (linearSum + kappa * sqrtHi, linearSum + kappa * sqrtLo)

def normalCdfBoundsQ (x : ℚ) : ℚ × ℚ :=
  let xabs := |x|
  let (sqrt2Lo, sqrt2Hi) := sqrtBoundsQ 2
  let zLo := xabs / sqrt2Hi
  let zHi := xabs / sqrt2Lo
  let c0 : ℚ := 3275911 / 10000000
  let tLo := 1 / (1 + c0 * zHi)
  let tHi := 1 / (1 + c0 * zLo)
  let a1 : ℚ := 254829592 / 1000000000
  let a2 : ℚ := -284496736 / 1000000000
  let a3 : ℚ := 1421413741 / 1000000000
  let a4 : ℚ := -1453152027 / 1000000000
  let a5 : ℚ := 1061405429 / 1000000000
  let polyQ (t : ℚ) : ℚ :=
    t * (a1 + t * (a2 + t * (a3 + t * (a4 + t * a5))))
  let polyLo := min (polyQ tLo) (polyQ tHi)
  let polyHi := max (polyQ tLo) (polyQ tHi)
  let (expLo, _) := expNegBoundsQ (zHi * zHi)
  let (_, expHi) := expNegBoundsQ (zLo * zLo)
  let termLo := max 0 (polyLo * expLo)
  let termHi := polyHi * expHi
  let erfLo := 1 - termHi
  let erfHi := 1 - termLo
  if x ≥ 0 then
    ((1 + erfLo) / 2, (1 + erfHi) / 2)
  else
    ((1 - erfHi) / 2, (1 - erfLo) / 2)

def credenceBoundsQ (predicted uncertainty cap : ℚ) : ℚ × ℚ :=
  if uncertainty = 0 then
    let c : ℚ := if predicted > 0 then 1 else if predicted < 0 then 0 else 1 / 2
    (max (1 - cap) (min cap c), max (1 - cap) (min cap c))
  else
    let (nLo, nHi) := normalCdfBoundsQ (predicted / uncertainty)
    (max (1 - cap) (min cap nLo), max (1 - cap) (min cap nHi))

/-! ## Generated inputs -/

/-- A 64-bit linear congruential generator (Knuth's MMIX constants); fixed seeds, so every build
    checks the same inputs. -/
structure Gen where
  s : UInt64

def Gen.next (g : Gen) : UInt64 × Gen :=
  let s := g.s * 6364136223846793005 + 1442695040888963407
  (s >>> 11, ⟨s⟩)

def Gen.below (g : Gen) (k : Nat) : Nat × Gen :=
  let (x, g) := g.next
  (x.toNat % k, g)

/-- A dyadic rational z / 2^e with |z| < 2^20, e < 8: exact in Float. -/
def Gen.dyadic (g : Gen) : ℚ × Gen :=
  let (z, g) := g.below (2 ^ 21)
  let (e, g) := g.below 8
  (((z : ℤ) - 2 ^ 20 : ℤ) / (2 ^ e : ℚ), g)

def Gen.dyadicNonneg (g : Gen) : ℚ × Gen :=
  let (q, g) := g.dyadic
  (|q|, g)

def ratToFloat (q : ℚ) : Float :=
  let nBits := q.num.natAbs.log2
  let dBits := q.den.log2
  let maxBits := max nBits dBits
  if maxBits ≤ 900 then
    Float.ofInt q.num / q.den.toFloat
  else
    let shift := maxBits - 900
    let nShifted : ℤ := q.num >>> shift
    let dShifted : Nat := max 1 (q.den >>> shift)
    Float.ofInt nShifted / dShifted.toFloat

def close (f : Float) (q : ℚ) : Bool :=
  let r := ratToFloat q
  (f - r).abs ≤ 1e-9 * (1 + r.abs)

def inInterval (f : Float) (lo hi : ℚ) (tol : Float := 1e-6) : Bool :=
  let rlo := ratToFloat lo
  let rhi := ratToFloat hi
  let scale := 1.0 + f.abs
  f ≥ rlo - tol * scale && f ≤ rhi + tol * scale

/-- Runs `trials` generated cases; a case returns whether the Float reference agreed. -/
def checkAll (name : String) (trials : Nat) (seed : UInt64) (case : Gen → Bool × Gen) : IO Unit := do
  let mut g : Gen := ⟨seed⟩
  let mut bad := 0
  for _ in [0:trials] do
    let (ok, g') := case g
    g := g'
    unless ok do bad := bad + 1
  if bad > 0 then
    throw <| IO.userError s!"differential {name}: {bad} of {trials} cases disagree"
  IO.println s!"differential {name}: {trials} cases agree"

/-- Bitmask of a coalition of Fin n. -/
def maskOf {n : ℕ} (S : Finset (Fin n)) : Nat := S.sum fun i => 2 ^ i.val

/-- A random game on n contributors: one dyadic value per bitmask. -/
def Gen.game (g : Gen) (n : Nat) : Array ℚ × Gen := Id.run do
  let mut g := g
  let mut vs : Array ℚ := #[]
  for _ in [0:2 ^ n] do
    let (q, g') := g.dyadic
    g := g'
    vs := vs.push q
  (vs, g)

/-- A random ordering of 0 … n − 1 (Fisher–Yates). -/
def Gen.perm (g : Gen) (n : Nat) : List Nat × Gen := Id.run do
  let mut g := g
  let mut a : Array Nat := (List.range n).toArray
  for k in [0:n] do
    let j := n - 1 - k
    let (r, g') := g.below (j + 1)
    g := g'
    a := a.swapIfInBounds j r
  (a.toList, g)

def toFin (n : Nat) (l : List Nat) : List (Fin n) := l.filterMap fun i => if h : i < n then some ⟨i, h⟩ else none

/-! ## The checks (run when this module is built) -/

open BenefutureReference in
def runAll : IO Unit := do
  checkAll "supply_delta" 500 1 fun g =>
    let (a, g) := g.dyadic; let (b, g) := g.dyadic; let (c, g) := g.dyadic
    (close (supply_delta_ref (ratToFloat a) (ratToFloat b) (ratToFloat c)) (supplyQ a b c), g)
  checkAll "competition_efficiency" 500 2 fun g =>
    let (a, g) := g.dyadic; let (b, g) := g.dyadicNonneg; let (c, g) := g.dyadicNonneg
    if b + c = 0 then (true, g) else
    (close (competition_efficiency_ref (ratToFloat a) (ratToFloat b) (ratToFloat c)) (efficiencyQ a b c), g)
  checkAll "rolling_average" 300 3 fun g => Id.run do
    let (k, g) := g.below 8
    let mut g := g
    let mut w : List ℚ := []
    for _ in [0:k] do
      let (q, g') := g.dyadic
      g := g'; w := q :: w
    (close (rolling_average_ref (w.map ratToFloat)) (rollingQ w), g)
  checkAll "accumulate_capped" 500 4 fun g => Id.run do
    let (cap, g) := g.dyadicNonneg; let (cur, g) := g.dyadicNonneg
    let (k, g) := g.below 8
    let mut g := g
    let mut ws : List ℚ := []
    for _ in [0:k] do
      let (q, g') := g.dyadicNonneg
      g := g'; ws := q :: ws
    (close (accumulate_capped_ref (ratToFloat cap) (ratToFloat cur) (ws.map ratToFloat)) (cappedQ cap cur ws), g)
  checkAll "p_forgive, p_overreact" 500 5 fun g =>
    let (a, g) := g.dyadicNonneg; let (d, g) := g.dyadicNonneg
    let (rp, g) := g.dyadicNonneg; let (rn, g) := g.dyadicNonneg
    let (a, d) := (a / 2 ^ 20, d / 2 ^ 20)
    (close (p_forgive_ref (ratToFloat a) (ratToFloat rp)) (forgiveQ a rp) &&
     close (p_overreact_ref (ratToFloat a) (ratToFloat d) (ratToFloat rp) (ratToFloat rn)) (overreactQ a d rp rn), g)
  checkAll "severity_score" 500 6 fun g =>
    let (a, g) := g.dyadicNonneg; let (b, g) := g.dyadicNonneg; let (c, g) := g.dyadicNonneg
    let (d, g) := g.dyadicNonneg; let (e, g) := g.dyadicNonneg
    (close (severity_score_ref (ratToFloat a) (ratToFloat b) (ratToFloat c) (ratToFloat d) (ratToFloat e))
      (severityQ a b c d e), g)
  checkAll "shapley" 120 7 fun g =>
    let (n, g) := g.below 6
    let (vs, g) := g.game n
    let v : Finset (Fin n) → ℚ := fun S => vs.getD (maskOf S) 0
    let φ := shapley_ref n (vs.map ratToFloat)
    ((List.finRange n).all fun i => close (φ.getD i.val 0) (shapleyQ n v i), g)
  checkAll "shapley_sampled" 200 8 fun g => Id.run do
    let (n, g) := g.below 7
    let (m, g) := g.below 6
    let (vs, g) := g.game n
    let v : Finset (Fin n) → ℚ := fun S => vs.getD (maskOf S) 0
    let mut g := g
    let mut samples : List (List Nat) := []
    for _ in [0:m + 1] do
      let (p, g') := g.perm n
      g := g'; samples := samples ++ [p]
    let perms := samples.foldl (fun a p => a ++ (p.map Nat.toFloat).toArray) #[]
    let along (p : List Nat) : List Float :=
      (List.range (n + 1)).map fun k => ratToFloat (vs.getD ((p.take k).foldl (fun s i => s + 2 ^ i) 0) 0)
    let vals := samples.foldl (fun a p => a ++ (along p).toArray) #[]
    let φ := shapley_sampled_ref n (m + 1) perms vals
    let fs := samples.map (toFin n)
    ((List.finRange n).all fun i => close (φ.getD i.val 0) (sampledQ v fs i), g)
  -- Exact over ℚ: the mean over all n! orderings is the subset form of Shapley.
  checkAll "shapley orderings = subsets (exact, ℚ)" 60 9 fun g =>
    let (n, g) := g.below 6
    let (vs, g) := g.game n
    let v : Finset (Fin n) → ℚ := fun S => vs.getD (maskOf S) 0
    let all := (List.finRange n).permutations
    ((List.finRange n).all fun i => sampledQ v all i == shapleyQ n v i, g)
  checkAll "record_credence" 400 12 fun g => Id.run do
    let (k, g) := g.below 9
    let (v, g) := g.dyadic
    let mut g := g
    let mut errs : List ℚ := []
    for _ in [0:k] do
      let (q, g') := g.dyadic
      g := g'; errs := q :: errs
    let (tie, g2) := g.below 3
    let es := if tie == 0 then v :: errs else errs  -- ties counted half on both sides
    (close (record_credence_ref (ratToFloat v) (es.map ratToFloat).toArray 0.99) (recordCredenceQ (99 / 100) v es), g2)
  -- Computable ℤ specifications.
  checkAll "bounty_reward vs advap_reward_ref" 500 10 fun g =>
    let (gain, g) := g.below 100000; let (harm, g) := g.below 100000
    let spec := Benefuture.Governance.bounty_reward gain harm
    let f := advap_reward_ref gain.toFloat harm.toFloat 0.1 1.0
    let err := (f - Float.ofInt spec).abs
    (if harm % 10 == 0 then err ≤ 1e-6 else err < 1.0, g)
  checkAll "upfront_payment vs Escrow_split_ref" 500 11 fun g =>
    let (nom, g) := g.below 1000000000; let (conf, g) := g.below 1000001
    if h : conf ≤ 1000000 then
      let pe := Benefuture.Economy.ProbabilisticEscrow.mkSimple "e" conf (by omega)
        (by simp only [Benefuture.Math.SCALE]; omega)
      let spec := Benefuture.Economy.upfront_payment nom pe
      let f := (Escrow_split_ref nom.toFloat (conf.toFloat / 1000000.0)).1
      ((f - Float.ofInt spec).abs < 1.0 + 1e-6, g)
    else (true, g)
  -- Exact over ℚ: Voting_weight (L113)
  checkAll "Voting_weight" 500 13 fun g => Id.run do
    let (base, g) := g.dyadicNonneg
    let (expWt, g) := g.dyadicNonneg
    let (impWt, g) := g.dyadicNonneg
    let (impact, g) := g.dyadicNonneg
    let (th, g) := g.dyadicNonneg
    let (k, g) := g.below 6
    let mut g := g
    let mut profile : List (ℚ × ℚ) := []
    for _ in [0:k] do
      let (w, g') := g.dyadicNonneg
      let (r, g'') := g'.dyadicNonneg
      g := g''; profile := (w / 16, r) :: profile
    let q := votingWeightQ base expWt profile impWt impact
    let f := Voting_weight_ref (ratToFloat base) (ratToFloat expWt)
      (profile.map fun (w, r) => (ratToFloat w, ratToFloat r))
      (ratToFloat impWt) (ratToFloat impact) (ratToFloat th)
    (close f.1 q && f.2 == (q < th), g)
  -- Interval-bound oracles for nonlinear functions
  checkAll "Rep_decay" 500 14 fun g =>
    let (score, g) := g.dyadic
    let (dt, g) := g.dyadic
    let (lam, g) := g.dyadicNonneg
    let (lo, hi) := repDecayBoundsQ score dt (lam / 16)
    let f := Rep_decay_ref (ratToFloat score) (ratToFloat dt) (ratToFloat (lam / 16))
    (inInterval f lo hi 1e-6, g)
  checkAll "shapley_sample_count" 400 15 fun g =>
    let (n0, g) := g.below 20
    let n := n0 + 1
    let (eps0, g) := g.below 50
    let eps : ℚ := ((eps0 : ℚ) + 1) / 100
    let (del0, g) := g.below 50
    let delta : ℚ := ((del0 : ℚ) + 1) / 100
    let (lo, hi) := shapleySampleCountBoundsQ n eps delta
    let f := shapley_sample_count_ref n (ratToFloat eps) (ratToFloat delta)
    (f + 1 ≥ lo && f ≤ hi + 1, g)
  checkAll "phi" 400 16 fun g => Id.run do
    let (k, g) := g.below 5
    let (kappa, g) := g.dyadicNonneg
    let mut g := g
    let mut items : List (ℚ × ℚ) := []
    for _ in [0:k] do
      let (a, g') := g.dyadicNonneg
      let (w, g'') := g'.dyadicNonneg
      g := g''; items := (a / 8, w / 8) :: items
    let (lo, hi) := phiBoundsQ items (kappa / 8)
    let f := phi_ref (items.map fun (a, w) => (ratToFloat a, ratToFloat w)) 1.0 (ratToFloat (kappa / 8))
    (inInterval f lo hi 1e-6, g)
  checkAll "normal_cdf" 500 17 fun g =>
    let (x, g) := g.dyadic
    let (lo, hi) := normalCdfBoundsQ (x / 4)
    let f := normal_cdf_ref (ratToFloat (x / 4))
    (inInterval f lo hi 1e-5, g)
  checkAll "credence" 500 18 fun g =>
    let (pred, g) := g.dyadic
    let (unc, g) := g.dyadicNonneg
    let (cap0, g) := g.below 49
    let cap : ℚ := ((cap0 : ℚ) + 51) / 100
    let (lo, hi) := credenceBoundsQ (pred / 4) (unc / 4) cap
    let f := credence_ref (ratToFloat (pred / 4)) (ratToFloat (unc / 4)) (ratToFloat cap)
    (inInterval f lo hi 1e-5, g)
  checkAll "accident_split" 400 19 fun g =>
    let (harm, g) := g.dyadicNonneg
    let (cap, g) := g.dyadicNonneg
    let c := accident_contributor_ref (ratToFloat harm) (ratToFloat cap)
    let a := accident_admin_ref (ratToFloat harm) (ratToFloat cap)
    (close c (accidentContributorQ harm cap) && close a (accidentAdminQ harm cap), g)
  checkAll "sanction_escrow_credence" 400 20 fun g =>
    let (c0, g) := g.below 101
    let (n0, g) := g.below 101
    let (dec, g) := g.below 6
    let (neg, g) := g.below 12
    let (pmin, g) := g.below 6
    let (gr0, g) := g.below 10
    let (fl0, g) := g.below 50
    let cred : ℚ := (c0 : ℚ) / 100
    let negShare : ℚ := (n0 : ℚ) / 100
    let growth : ℚ := (gr0 : ℚ) / 4
    let floorC : ℚ := (fl0 : ℚ) / 1000
    let f := sanction_escrow_credence_ref (ratToFloat cred) (ratToFloat negShare) dec neg pmin
      (ratToFloat growth) (ratToFloat floorC)
    let q := sanctionEscrowCredenceQ cred negShare dec neg pmin growth floorC
    (close f q, g)
  checkAll "rehabilitate_restraint" 400 21 fun g =>
    let (b0, g) := g.below 101
    let (cr, g) := g.below 12
    let (pmin, g) := g.below 6
    let (d0, g) := g.below 101
    let (m0, g) := g.below 50
    let baseShare : ℚ := (b0 : ℚ) / 100
    let stepDecay : ℚ := (d0 : ℚ) / 100
    let minShare : ℚ := (m0 : ℚ) / 200
    let f := rehabilitate_restraint_ref (ratToFloat baseShare) cr pmin (ratToFloat stepDecay) (ratToFloat minShare)
    let q := rehabilitateRestraintQ baseShare cr pmin stepDecay minShare
    (close f q, g)
  checkAll "ra_value_per_cost" 400 22 fun g =>
    let (g0, g) := g.below 129
    let (r0, g) := g.below 65
    let (a0, g) := g.below 65
    let (fb0, g) := g.below 33
    let gain : ℚ := ((g0 : ℚ) - 32) / 8
    let rc : ℚ := ((r0 : ℚ) - 4) / 8
    let ac : ℚ := ((a0 : ℚ) - 4) / 8
    let fb : ℚ := (fb0 : ℚ) / 16
    let f := ra_value_per_cost_ref (ratToFloat gain) (ratToFloat rc) (ratToFloat ac) (ratToFloat fb)
    let q := raValuePerCostQ gain rc ac fb
    (close f q, g)
  checkAll "ra_commons_reserve" 400 23 fun g =>
    let (n0, g) := g.below 100
    let (r0, g) := g.below 33
    let (h0, g) := g.below 65
    let need : ℚ := ((n0 : ℚ) - 10) / 8
    let fRate : ℚ := ((r0 : ℚ) - 4) / 32
    let hor : ℚ := ((h0 : ℚ) - 4) / 8
    let f := ra_commons_reserve_ref (ratToFloat need) (ratToFloat fRate) (ratToFloat hor)
    let q := raCommonsReserveQ need fRate hor
    (close f q, g)
  checkAll "ra_contraction_factor" 400 24 fun g =>
    let (c0, g) := g.below 129
    let (d0, g) := g.below 65
    let (r0, g) := g.below 33
    let (m0, g) := g.below 17
    let claims : ℚ := (c0 : ℚ) / 16
    let cap : ℚ := ((d0 : ℚ) - 4) / 16
    let rate : ℚ := (r0 : ℚ) / 32
    let minScale : ℚ := (m0 : ℚ) / 32
    let f := ra_contraction_factor_ref (ratToFloat claims) (ratToFloat cap) (ratToFloat rate) (ratToFloat minScale)
    let q := raContractionFactorQ claims cap rate minScale
    (close f q, g)
  checkAll "responsibility_factor" 400 25 fun g =>
    let (b0, g) := g.below 8
    let (cf0, g) := g.below 49
    let (s0, g) := g.below 65
    let (a0, g) := g.below 49
    let isAct := b0 % 2 == 1
    let isInf := (b0 / 2) % 2 == 1
    let hasDuty := (b0 / 4) % 2 == 1
    let cf : ℚ := ((cf0 : ℚ) - 8) / 32
    let sev : ℚ := ((s0 : ℚ) - 4) / 16
    let acc : ℚ := ((a0 : ℚ) - 8) / 32
    let f := responsibility_factor_ref isAct isInf hasDuty (ratToFloat cf) (ratToFloat sev) (ratToFloat acc)
    let q := responsibilityFactorQ isAct isInf hasDuty cf sev acc
    (close f q, g)
  checkAll "binding_admits_weighted" 400 26 fun g =>
    let (c0, g) := g.below 17
    let (c1, g) := g.below 17
    let (c2, g) := g.below 17
    let (w0, g) := g.below 33
    let (w1, g) := g.below 33
    let (w2, g) := g.below 33
    let (th0, g) := g.below 17
    let (qw0, g) := g.below 33
    let confs : List ℚ := [(c0 : ℚ) / 16, (c1 : ℚ) / 16, (c2 : ℚ) / 16]
    let weights : List ℚ := [((w0 : ℚ) - 12) / 16, ((w1 : ℚ) - 12) / 16, ((w2 : ℚ) - 12) / 16]
    let th : ℚ := (th0 : ℚ) / 16
    let qw : ℚ := (qw0 : ℚ) / 16
    let f := binding_admits_weighted_ref (Array.mk (confs.map ratToFloat))
               (Array.mk (weights.map ratToFloat)) (ratToFloat th) (ratToFloat qw)
    let q := bindingAdmitsWeightedQ confs weights th qw
    (f == q, g)
  checkAll "deciding_scope" 400 27 fun g =>
    let (s0, g) := g.below 17
    let (s1, g) := g.below 17
    let (s2, g) := g.below 17
    let (b0, g) := g.below 8
    let (m0, g) := g.below 17
    let shares : List ℚ := [(s0 : ℚ) / 16, (s1 : ℚ) / 16, (s2 : ℚ) / 16]
    let w0 := b0 % 2 == 1
    let w1 := (b0 / 2) % 2 == 1
    let w2 := (b0 / 4) % 2 == 1
    let within : List Bool := [w0, w1, w2]
    let withinF : List Float := [if w0 then 1.0 else 0.0, if w1 then 1.0 else 0.0, if w2 then 1.0 else 0.0]
    let m : ℚ := (m0 : ℚ) / 16
    let f := deciding_scope_ref (Array.mk (shares.map ratToFloat)) (Array.mk withinF) (ratToFloat m)
    let q := decidingScopeQ (shares.zip within) m
    (f == q, g)
  checkAll "extended_self_feedback" 400 28 fun g =>
    let (c0, g) := g.below 33
    let (c1, g) := g.below 33
    let (c2, g) := g.below 33
    let (d0, g) := g.below 65
    let (d1, g) := g.below 65
    let (d2, g) := g.below 65
    let cs : List ℚ := [((c0 : ℚ) - 8) / 16, ((c1 : ℚ) - 8) / 16, ((c2 : ℚ) - 8) / 16]
    let ds : List ℚ := [((d0 : ℚ) - 32) / 8, ((d1 : ℚ) - 32) / 8, ((d2 : ℚ) - 32) / 8]
    let f := extended_self_feedback_ref (Array.mk (cs.map ratToFloat)) (Array.mk (ds.map ratToFloat))
    let q := extendedSelfFeedbackQ cs ds
    (close f q, g)
  checkAll "propagated_liability" 400 29 fun g =>
    let (h0, g) := g.below 65
    let (c0, g) := g.below 33
    let (c1, g) := g.below 33
    let (c2, g) := g.below 33
    let harm : ℚ := ((h0 : ℚ) - 16) / 8
    let cs : List ℚ := [((c0 : ℚ) - 8) / 16, ((c1 : ℚ) - 8) / 16, ((c2 : ℚ) - 8) / 16]
    let f := propagated_liability_ref (ratToFloat harm) (Array.mk (cs.map ratToFloat))
    let q := propagatedLiabilityQ harm cs
    (close f q, g)
  checkAll "end_of_horizon_score" 400 30 fun g =>
    let (o0, g) := g.below 65
    let (a0, g) := g.below 2
    let (c0, g) := g.below 33
    let (c1, g) := g.below 33
    let (d0, g) := g.below 65
    let (d1, g) := g.below 65
    let (cs0, g) := g.below 33
    let (do0, g) := g.below 65
    let (is0, g) := g.below 33
    let (ig0, g) := g.below 65
    let own : ℚ := ((o0 : ℚ) - 16) / 8
    let alive := a0 == 1
    let cs : List ℚ := [((c0 : ℚ) - 8) / 16, ((c1 : ℚ) - 8) / 16]
    let ds : List ℚ := [((d0 : ℚ) - 32) / 8, ((d1 : ℚ) - 32) / 8]
    let cShare : ℚ := ((cs0 : ℚ) - 8) / 16
    let dOut : ℚ := ((do0 : ℚ) - 32) / 8
    let iShare : ℚ := ((is0 : ℚ) - 8) / 16
    let iGain : ℚ := ((ig0 : ℚ) - 32) / 8
    let f := end_of_horizon_score_ref (ratToFloat own) alive
      (Array.mk (cs.map ratToFloat)) (Array.mk (ds.map ratToFloat))
      (ratToFloat cShare) (ratToFloat dOut) (ratToFloat iShare) (ratToFloat iGain)
    let q := endOfHorizonScoreQ own alive cs ds cShare dOut iShare iGain
    (close f q, g)
  checkAll "end_of_horizon_predicted_score" 400 31 fun g =>
    let (im0, g) := g.below 65
    let (fu0, g) := g.below 65
    let (a0, g) := g.below 2
    let (c0, g) := g.below 33
    let (c1, g) := g.below 33
    let (d0, g) := g.below 65
    let (d1, g) := g.below 65
    let (cs0, g) := g.below 33
    let (do0, g) := g.below 65
    let (is0, g) := g.below 33
    let (ig0, g) := g.below 65
    let imm : ℚ := ((im0 : ℚ) - 16) / 8
    let fut : ℚ := ((fu0 : ℚ) - 16) / 8
    let aliveOut := a0 == 1
    let cs : List ℚ := [((c0 : ℚ) - 8) / 16, ((c1 : ℚ) - 8) / 16]
    let ds : List ℚ := [((d0 : ℚ) - 32) / 8, ((d1 : ℚ) - 32) / 8]
    let cShare : ℚ := ((cs0 : ℚ) - 8) / 16
    let dOut : ℚ := ((do0 : ℚ) - 32) / 8
    let iShare : ℚ := ((is0 : ℚ) - 8) / 16
    let iGain : ℚ := ((ig0 : ℚ) - 32) / 8
    let f := end_of_horizon_predicted_score_ref (ratToFloat imm) (ratToFloat fut) aliveOut
      (Array.mk (cs.map ratToFloat)) (Array.mk (ds.map ratToFloat))
      (ratToFloat cShare) (ratToFloat dOut) (ratToFloat iShare) (ratToFloat iGain)
    let q := endOfHorizonPredictedScoreQ imm fut aliveOut cs ds cShare dOut iShare iGain
    (close f q, g)
  checkAll "ihz_access_risk" 400 32 fun g =>
    let (cl0, g) := g.below 65
    let (rq0, g) := g.below 65
    let (ph0, g) := g.below 65
    let clearance : ℚ := ((cl0 : ℚ) - 16) / 8
    let reqEd : ℚ := ((rq0 : ℚ) - 16) / 8
    let harm : ℚ := ((ph0 : ℚ) - 16) / 8
    let f := ihz_access_risk_ref (ratToFloat clearance) (ratToFloat reqEd) (ratToFloat harm)
    let q := ihzAccessRiskQ clearance reqEd harm
    (close f q, g)
  checkAll "art_success_score" 400 33 fun g =>
    let (p0, g) := g.below 17
    let (p1, g) := g.below 17
    let (p2, g) := g.below 17
    let (q0, g) := g.below 17
    let (q1, g) := g.below 17
    let (q2, g) := g.below 17
    let ps : List ℚ := [(p0 : ℚ) / 16, (p1 : ℚ) / 16, (p2 : ℚ) / 16]
    let qs : List ℚ := [(q0 : ℚ) / 16, (q1 : ℚ) / 16, (q2 : ℚ) / 16]
    let f := art_success_score_ref (Array.mk (ps.map ratToFloat)) (Array.mk (qs.map ratToFloat))
    let q := artSuccessScoreQ ps qs
    (close f q, g)
  checkAll "art_surplus_value" 400 34 fun g =>
    let (u0, g) := g.below 65
    let (n0, g) := g.below 65
    let u : ℚ := ((u0 : ℚ) - 16) / 8
    let nov : ℚ := ((n0 : ℚ) - 16) / 8
    let f := art_surplus_value_ref (ratToFloat u) (ratToFloat nov)
    let q := artSurplusValueQ u nov
    (close f q, g)
  checkAll "chain_truth_level" 400 35 fun g =>
    let (b0, g) := g.below 33
    let (h0, g) := g.below 33
    let (h1, g) := g.below 33
    let (h2, g) := g.below 33
    let b : ℚ := ((b0 : ℚ) - 8) / 16
    let hs : List ℚ := [((h0 : ℚ) - 8) / 16, ((h1 : ℚ) - 8) / 16, ((h2 : ℚ) - 8) / 16]
    let f := chain_truth_level_ref (ratToFloat b) (Array.mk (hs.map ratToFloat))
    let q := chainTruthLevelQ b hs
    (close f q, g)
  checkAll "advap_recount_correct" 400 36 fun g =>
    let (h0, g) := g.below 33
    let (h1, g) := g.below 33
    let (h2, g) := g.below 33
    let (v0, g) := g.below 33
    let (v1, g) := g.below 33
    let (v2, g) := g.below 33
    let (b0, g) := g.below 8
    let (tr0, g) := g.below 33
    let hs : List ℚ := [(h0 : ℚ) / 16, (h1 : ℚ) / 16, (h2 : ℚ) / 16]
    let vs : List ℚ := [((v0 : ℚ) - 16) / 8, ((v1 : ℚ) - 16) / 8, ((v2 : ℚ) - 16) / 8]
    let a0 := b0 % 2 == 1
    let a1 := (b0 / 2) % 2 == 1
    let a2 := (b0 / 4) % 2 == 1
    let actQ : List Bool := [a0, a1, a2]
    let actF : List Float := [if a0 then 1.0 else 0.0, if a1 then 1.0 else 0.0, if a2 then 1.0 else 0.0]
    let tr : ℚ := ((tr0 : ℚ) - 16) / 8
    let entries := (hs.zip vs).zip actQ |>.map fun ((h, v), a) => (h, v, a)
    let f := advap_recount_correct_ref (Array.mk (hs.map ratToFloat))
      (Array.mk (vs.map ratToFloat)) (Array.mk actF) (ratToFloat tr)
    let q := advapRecountQ entries tr
    (f == q, g)
  checkAll "contention_map" 400 37 fun g =>
    let (r0, g) := g.below 65
    let (r1, g) := g.below 65
    let (r2, g) := g.below 65
    let (r3, g) := g.below 65
    let (self0, g) := g.below 5
    let reps : List ℚ := [((r0 : ℚ) - 16) / 8, ((r1 : ℚ) - 16) / 8, ((r2 : ℚ) - 16) / 8, ((r3 : ℚ) - 16) / 8]
    let f := contention_map_ref (Array.mk (reps.map ratToFloat)) self0
    let q := Benefuture.Governance.contention_map_rank reps self0
    (f.toList == q.map Nat.toFloat, g)

#eval runAll

end BenefutureTest
