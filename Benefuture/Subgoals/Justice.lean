/-
  Benefuture.Subgoals.Justice
  Formalization of Crime (Cr ∈ T), Restorative Justice (J), and Reparations.
  Corresponds to: Bf_Pseudocode.txt L115-117, L119, and Justice.txt / Crime.txt
  "Crime«Cr» := Ha | Informed(Volition ∨ Inaction(Lw_mandate ∨ Contract));"
  "J := Repair(Ha) ∧ Prevent(Cr), Restorative;"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Person

namespace Benefuture.Subgoals

open Benefuture.Ontology

/-- 
  Crime (Cr ∈ T): Harm caused through informed volition or culpable inaction:
  Cr := Ha | Informed(Volition ∨ Inaction(Lw_mandate ∨ Contract)).
-/
structure Crime extends Thing where
  perpetrator  : Person
  victim       : Person
  harmAmount   : Int
  isInformed   : Bool
  hasVolition  : Bool
  /-- Informed inaction against a committed action: a duty from a contract, including a law once
      communicated (author ruling, BACKPROPAGATION 8.17). -/
  breachedDuty : Bool := false
  h_harm_pos   : 0 < harmAmount
  h_culpable   : isInformed = true ∧ (hasVolition = true ∨ breachedDuty = true)
  deriving Repr

/-- Coercion: Every Crime is canonically a Thing in Reality. -/
instance : Coe Crime Thing where
  coe cr := cr.toThing


/-- 
  Restorative Package (extends Thing):
  reparationToVictim : Restitution restoring victim's baseline
  rehabilitationCost : Educational and behavioral rehabilitation of perpetrator
-/
structure RestorativePackage extends Thing where
  crime              : Crime
  reparationToVictim : Int
  rehabilitationCost : Int
  deriving Repr

/-- Coercion: Every RestorativePackage is canonically a Thing in Reality. -/
instance : Coe RestorativePackage Thing where
  coe rp := rp.toThing


/-- Helper constructor for Crimes grounded in reality. -/
def Crime.mkSimple (id : String) (perp victim : Person) (harm : Int) (h_pos : 0 < harm) : Crime :=
  { toThing := Thing.mkSimple id s!"crime_{id}" "reality_substrate" 0,
    perpetrator := perp, victim := victim, harmAmount := harm,
    isInformed := true, hasVolition := true, h_harm_pos := h_pos, h_culpable := ⟨rfl, Or.inl rfl⟩ }

/-- Helper constructor for RestorativePackages. -/
def RestorativePackage.mkSimple (id : String) (cr : Crime) (reparation rehab : Int) : RestorativePackage :=
  { toThing := Thing.mkSimple id s!"restorative_{id}" "justice_substrate" 0,
    crime := cr, reparationToVictim := reparation, rehabilitationCost := rehab }

/-- 
  Net societal residual harm after restorative justice intervention:
  ResidualHarm = OriginalHarm - ReparationPaid.
-/
def residual_societal_harm (pkg : RestorativePackage) : Int :=
  pkg.crime.harmAmount - pkg.reparationToVictim

/-- 
  THEOREM: Restorative Minimization Theorem.
  When full restitution is paid to the victim (reparation = harmAmount),
  the uncompensated residual harm drops to zero, restoring the civilizational baseline.
-/
theorem full_reparation_eliminates_residual_harm 
    (pkg : RestorativePackage) (h_full : pkg.reparationToVictim = pkg.crime.harmAmount) :
    residual_societal_harm pkg = 0 := by
  unfold residual_societal_harm
  rw [h_full]
  omega

/-- 
  Accident (extends Thing):
  When harm is caused without informed volition or culpable inaction:
  Harm occurs, but isInformed = false ∨ (hasVolition = false ∧ breachedDuty = false).
  Repair is owed either way (author ruling, BACKPROPAGATION 8.17).
  Corresponds to: Crime.txt L9.
-/
structure Accident extends Thing where
  operator    : Person
  victim      : Person
  harmAmount  : Int
  isInformed  : Bool
  hasVolition : Bool
  breachedDuty : Bool := false
  h_harm_pos  : 0 < harmAmount
  h_accidental : isInformed = false ∨ (hasVolition = false ∧ breachedDuty = false)
  deriving Repr

instance : Coe Accident Thing where
  coe acc := acc.toThing


/-- 
  Accident Resolution Package:
  Victim receives full restorative restitution, but the operator incurs 
  ZERO punitive friction or criminal sanctions.
-/
structure AccidentResolution extends Thing where
  accident           : Accident
  reparationToVictim : Int
  punitivePenalty    : Int
  deriving Repr

instance : Coe AccidentResolution Thing where
  coe ar := ar.toThing


/-- 
  Standard pure restitution resolution for an accident:
  Reparation equals harm, punitive penalty is strictly zero.
-/
def mk_accident_pure_restitution (acc : Accident) : AccidentResolution :=
  { toThing := Thing.mkSimple s!"res_{acc.id}" s!"accident_res_{acc.id}" "restorative_justice" 0,
    accident := acc, reparationToVictim := acc.harmAmount, punitivePenalty := 0 }

/-- 
  THEOREM: Pure Restitution for Accidents Invariant (Crime.txt L9 & Justice.txt).
  An accident resolved through standard restorative justice completely eliminates 
  residual victim harm while assessing zero punitive friction on the operator.
-/
theorem accident_requires_pure_restitution_without_punitive_friction (acc : Accident) :
    let res := mk_accident_pure_restitution acc
    acc.harmAmount - res.reparationToVictim = 0 ∧ res.punitivePenalty = 0 := by
  dsimp [mk_accident_pure_restitution]
  omega

/-- 
  Ontological Classification of a Harmful Action (L116: Cr := Ha | Informed(Volition ∨
  Inaction(Lw_mandate ∨ Contract))):
  A harmful event constitutes a Crime (Cr) iff it was committed with verified epistemic awareness
  (isInformed = true) and either intentional volition (hasVolition = true) or inaction against a
  law's mandate or a contract (breachedDuty = true). Otherwise, it is an Accident.
  Corresponds to: Bf_Pseudocode.txt L116 & Crime.txt L9.
-/
def is_crime_classification (isInformed : Bool) (hasVolition : Bool) (breachedDuty : Bool := false) : Bool :=
  isInformed && (hasVolition || breachedDuty)

/-- 
  THEOREM: Crime and Accident Invariants are Mutually Exclusive.
  No harmful event is both classified a Crime (informed, and volition or breach of a law's
  mandate or contract, L116) and meets the Accident condition (uninformed, or neither volition
  nor breached duty).
-/
theorem crime_and_accident_mutually_exclusive (isInformed hasVolition breachedDuty : Bool) :
    ¬ (is_crime_classification isInformed hasVolition breachedDuty = true ∧
        (isInformed = false ∨ (hasVolition = false ∧ breachedDuty = false))) := by
  cases isInformed <;> cases hasVolition <;> cases breachedDuty <;> simp [is_crime_classification]

/-- 
  THEOREM: Culpability Classification Invariant (Informed Volition).
  An actor who acts with verified information (isInformed = true) and deliberate volition (hasVolition = true)
  is rigorously classified as committing a Crime.
-/
theorem verified_informed_volition_is_crime :
    is_crime_classification true true = true := by
  rfl

/-- 
  THEOREM: Uninformed Action is an Accident.
  An actor operating without epistemic notice (isInformed = false) 
  cannot be classified as a Crime, regardless of volition.
-/
theorem uninformed_action_is_accident (vol : Bool) :
    is_crime_classification false vol = false := by
  cases vol <;> rfl

/-- 
  THEOREM: Involuntary Action without breached duty is an Accident.
  An actor operating without volition (hasVolition = false) and with no breached duty (the default)
  cannot be classified as a Crime, regardless of information state.
-/
theorem involuntary_action_is_accident (inf : Bool) :
    is_crime_classification inf false = false := by
  cases inf <;> rfl

/-- 
  Epistemic Notice and Volition State:
  Distinguishes genuine ignorance from culpable willful negligence.
-/
inductive EpistemicNotice where
  | WarningVerifiedLogged : EpistemicNotice  -- BTS recorded verified warning received
  | NoWarningAvailable    : EpistemicNotice  -- Information was unavailable / unknown
  deriving Repr, DecidableEq

/-- Backward-compatible bridge to EpistemicNotice. -/
def classify_harmful_action 
    (notice : EpistemicNotice) (proceeded : Bool) : Bool :=
  match notice with
  | .WarningVerifiedLogged => is_crime_classification true proceeded
  | .NoWarningAvailable    => is_crime_classification false proceeded

theorem warning_ignored_constitutes_crime :
    classify_harmful_action .WarningVerifiedLogged true = true := by
  rfl

theorem absence_of_notice_is_accident (proceeded : Bool) :
    classify_harmful_action .NoWarningAvailable proceeded = false := by
  cases proceeded <;> rfl

/--
  THEOREM: Informed inaction against a committed action is a crime (L116: Informed(Volition ∨
  Inaction)). A driver bound by traffic law who sees the pedestrian and does not brake.
-/
theorem informed_inaction_under_duty_is_crime :
    is_crime_classification true false true = true := by
  rfl

/--
  THEOREM: Inaction without a committed action is not a crime, informed or not. A bystander with
  no duty has no causal contribution to the harm (assessed against inaction, its counterfactual is
  itself), so no crime arises from it.
-/
theorem inaction_without_duty_is_not_crime (isInformed : Bool) :
    is_crime_classification isInformed false false = false := by
  cases isInformed <;> rfl

/--
  THEOREM: An uninformed breach is an accident: repair is owed, no crime.
-/
theorem uninformed_breach_is_accident (hasVolition breachedDuty : Bool) :
    is_crime_classification false hasVolition breachedDuty = false := by
  rfl

abbrev Cr := Crime
abbrev J := RestorativePackage

/-- Causal distribution penalty capacity cap for an accident (L96:
    `Accident → Penalize ≤ Capacity, Ad(rest), Mandate(Ed)`, author ruling 8.157 ii):
    the contributor's penalty share is bounded by their capacity. -/
noncomputable def accident_contributor (harm cap : ℝ) : ℝ :=
  min harm cap

/-- Remainder of an accidental harm carried by the administration (`Ad(rest)`; L96,
    author ruling 8.157 ii). -/
noncomputable def accident_admin (harm cap : ℝ) : ℝ :=
  harm - min harm cap

/-- Conservation of accidental harm across contributor and administration:
    `accident_contributor harm cap + accident_admin harm cap = harm`. -/
theorem accident_split_conserves (harm cap : ℝ) :
    accident_contributor harm cap + accident_admin harm cap = harm := by
  unfold accident_contributor accident_admin
  ring

/-- The contributor's share of an accident never exceeds their capacity `cap`. -/
theorem accident_contributor_le_cap (harm cap : ℝ) :
    accident_contributor harm cap ≤ cap := by
  unfold accident_contributor
  exact min_le_right harm cap

/-- Both shares of a non-negative accident within non-negative capacity are non-negative. -/
theorem accident_split_nonneg (harm cap : ℝ) (hh : 0 ≤ harm) (hc : 0 ≤ cap) :
    0 ≤ accident_contributor harm cap ∧ 0 ≤ accident_admin harm cap := by
  unfold accident_contributor accident_admin
  exact ⟨le_min hh hc, sub_nonneg.mpr (min_le_left harm cap)⟩

/-- When an accident fits within capacity, the contributor pays all of it and
    the administration carries zero. -/
theorem accident_within_cap (harm cap : ℝ) (hle : harm ≤ cap) :
    accident_contributor harm cap = harm ∧ accident_admin harm cap = 0 := by
  unfold accident_contributor accident_admin
  simp [min_eq_left hle]

/-- When an accident exceeds capacity, the contributor pays exactly `cap` and
    the administration carries the excess `harm - cap`. -/
theorem accident_over_cap (harm cap : ℝ) (hge : cap ≤ harm) :
    accident_contributor harm cap = cap ∧ accident_admin harm cap = harm - cap := by
  unfold accident_contributor accident_admin
  simp [min_eq_right hge]

/-- Recorded exposure from mandated education after an accident (`Mandate(Ed)`, L96;
    `Informed := ∃ I ∈ Mem | I ∈ U(Ha(Outcome))`, L116, author rulings 8.157 iv, 8.159). -/
def post_education_informed (wasInformed mandatedEd : Bool) : Bool :=
  wasInformed || mandatedEd

/-- Mandating education after an accident makes any repeat breach (`hasVolition` or
    `breachedDuty`) informed and therefore classified as a crime (8.157 iv, 8.159). -/
theorem mandated_education_informs_repeat (wasInformed hasVolition breachedDuty : Bool)
    (h_breach : hasVolition = true ∨ breachedDuty = true) :
    is_crime_classification (post_education_informed wasInformed true) hasVolition breachedDuty = true := by
  unfold is_crime_classification post_education_informed
  rcases h_breach with h | h <;> simp [h]

/-- Repeated-pattern escalation count from negative domain reputation events (`pattern(Re_-ve(Dn))`;
    L117 `Rehabilitate(Escalate ← pattern(Re_-ve(Dn)))`, author ruling 8.157 i).
    An isolated lapse (`domNegEvents < patternMin`) triggers zero escalation (`0`), while once the
    pattern threshold `patternMin > 0` is reached the escalation count steps `1, 2, ...`. -/
def pattern_escalation_repeats (domNegEvents patternMin : Nat) : Nat :=
  if patternMin = 0 ∨ domNegEvents < patternMin then 0 else domNegEvents - patternMin + 1

/-- Isolated or below-threshold negative events cause zero sanction escalation (8.157 i). -/
theorem isolated_lapse_zero_escalation (domNegEvents patternMin : Nat)
    (h_lt : domNegEvents < patternMin) :
    pattern_escalation_repeats domNegEvents patternMin = 0 := by
  unfold pattern_escalation_repeats
  simp [h_lt]

/-- Once negative domain events reach a positive pattern threshold, escalation triggers strictly. -/
theorem repeated_pattern_escalates (domNegEvents patternMin : Nat)
    (h_pos : 0 < patternMin) (h_ge : patternMin ≤ domNegEvents) :
    0 < pattern_escalation_repeats domNegEvents patternMin := by
  unfold pattern_escalation_repeats
  have hne : patternMin ≠ 0 := Nat.ne_of_gt h_pos
  have hnotlt : ¬ domNegEvents < patternMin := Nat.not_lt.mpr h_ge
  simp [hne, hnotlt]

/-- Pattern escalation count is monotone non-decreasing in negative domain event count. -/
theorem pattern_escalation_monotone (a b patternMin : Nat) (hle : a ≤ b) :
    pattern_escalation_repeats a patternMin ≤ pattern_escalation_repeats b patternMin := by
  unfold pattern_escalation_repeats
  by_cases hp : patternMin = 0
  · simp [hp]
  · by_cases ha : a < patternMin
    · simp [hp, ha]
    · have hb : ¬ b < patternMin := fun h => ha (Nat.lt_of_le_of_lt hle h)
      simp only [hp, ha, hb, false_or, ↓reduceIte]
      omega

/-- Graduated sanction escrow credence from permanent deception count plus repeated domain negative
    pattern (`8.157 i`, `8.157 iii`: escrow ratcheting is the graduated sanction, while reputation
    penalties remain proportional to assessed harm). Floored at `floorC` so honest future work is
    never excluded (`< patternMin` matches baseline `repeat_escrow_credence`). -/
noncomputable def sanction_escrow_credence (cred negShare : ℝ)
    (deceptions domNegEvents patternMin : Nat) (growth floorC : ℝ) : ℝ :=
  let esc := deceptions + pattern_escalation_repeats domNegEvents patternMin
  max floorC ((1 / 2 + (cred - 1 / 2) * (1 - negShare)) * (1 / (1 + growth)) ^ esc)

/-- Domain-scoped rehabilitative restraint (`Prevent(Cr)` / L117; Justice §Rehabilitation): isolated
    crime/negative events keep full participation (`baseShare`), while repeated criminal patterns
    scale proposal weight by `stepDecay ^ esc` down to a positive floor `minShare` so actors can
    still contribute honestly. -/
noncomputable def rehabilitate_restraint (baseShare : ℝ) (crimeEvents patternMin : Nat)
    (stepDecay minShare : ℝ) : ℝ :=
  let esc := pattern_escalation_repeats crimeEvents patternMin
  if esc = 0 then baseShare else max minShare (baseShare * stepDecay ^ esc)

theorem isolated_lapse_no_restraint (baseShare : ℝ) (crimeEvents patternMin : Nat)
    (stepDecay minShare : ℝ) (h_lt : crimeEvents < patternMin) :
    rehabilitate_restraint baseShare crimeEvents patternMin stepDecay minShare = baseShare := by
  unfold rehabilitate_restraint
  simp [isolated_lapse_zero_escalation crimeEvents patternMin h_lt]

theorem sanction_escrow_ge_floor (cred negShare : ℝ) (deceptions domNegEvents patternMin : Nat)
    (growth floorC : ℝ) :
    floorC ≤ sanction_escrow_credence cred negShare deceptions domNegEvents patternMin growth floorC := by
  unfold sanction_escrow_credence
  exact le_max_left _ _

theorem sanction_escrow_monotone_in_pattern (cred negShare : ℝ)
    (deceptions a b patternMin : Nat) (growth floorC : ℝ)
    (hcred0 : 0 ≤ cred) (hns0 : 0 ≤ negShare) (hns1 : negShare ≤ 1)
    (hg : 0 ≤ growth) (hle : a ≤ b) :
    sanction_escrow_credence cred negShare deceptions b patternMin growth floorC ≤
      sanction_escrow_credence cred negShare deceptions a patternMin growth floorC := by
  unfold sanction_escrow_credence
  apply max_le_max_left floorC
  have hbase : 0 ≤ 1 / 2 + (cred - 1 / 2) * (1 - negShare) := by nlinarith
  apply mul_le_mul_of_nonneg_left _ hbase
  have hdiv_nonneg : 0 ≤ 1 / (1 + growth) := by positivity
  have hdiv_le_one : 1 / (1 + growth) ≤ 1 := by
    rw [div_le_one (by linarith)]
    linarith
  exact pow_le_pow_of_le_one hdiv_nonneg hdiv_le_one
    (Nat.add_le_add_left (pattern_escalation_monotone a b patternMin hle) deceptions)

theorem rehabilitate_restraint_ge_min (baseShare : ℝ) (crimeEvents patternMin : Nat)
    (stepDecay minShare : ℝ) (hmin : minShare ≤ baseShare) :
    minShare ≤ rehabilitate_restraint baseShare crimeEvents patternMin stepDecay minShare := by
  unfold rehabilitate_restraint
  by_cases h0 : pattern_escalation_repeats crimeEvents patternMin = 0
  · simp [h0, hmin]
  · simp [h0]

/-- Four-factor responsibility weight for causal distribution (`L96`, author rulings 8.152 & 8.159):
    `Responsibility(Informed, Counterfactual, Severity, Duty)`. Doing (`isAct = true`) and allowing
    (`isAct = false`) share parity when informed under a duty (`isInformed && hasDuty`); omissions
    by an un-obligated bystander (`!isAct && !hasDuty`) carry zero responsibility (minimal duties,
    8.46); uninformed accidents scale by attenuated `accidentFactor ∈ [0, 1]`. -/
noncomputable def responsibility_factor (isAct isInformed hasDuty : Bool)
    (counterfactualRatio severityScale accidentFactor : ℝ) : ℝ :=
  let roleWeight : ℝ :=
    if !isAct && !hasDuty then 0
    else if isInformed then 1
    else min 1 (max 0 accidentFactor)
  roleWeight * min 1 (max 0 counterfactualRatio) * max 0 severityScale

/-- Doing and allowing parity (author ruling 8.152): for an informed actor under a duty, causing
    a harm actively and failing to prevent it carry identical responsibility. -/
theorem doing_allowing_parity_when_informed_duty
    (cf sev acc : ℝ) :
    responsibility_factor true true true cf sev acc =
      responsibility_factor false true true cf sev acc := by
  unfold responsibility_factor
  simp

/-- Minimal-duty bystander safeguard (8.46, 8.152): an un-obligated bystander's omission carries
    zero responsibility regardless of awareness or severity. -/
theorem bystander_omission_zero_responsibility
    (inf : Bool) (cf sev acc : ℝ) :
    responsibility_factor false inf false cf sev acc = 0 := by
  unfold responsibility_factor
  simp

/-- Zero counterfactual effect incurs zero responsibility (harm that would have happened anyway). -/
theorem zero_counterfactual_zero_responsibility
    (isAct isInformed hasDuty : Bool) {cf : ℝ} (hcf : cf ≤ 0) (sev acc : ℝ) :
    responsibility_factor isAct isInformed hasDuty cf sev acc = 0 := by
  unfold responsibility_factor
  have hm : max 0 cf = 0 := max_eq_left hcf
  simp [hm]

/-- Responsibility factor is always non-negative. -/
theorem responsibility_nonneg
    (isAct isInformed hasDuty : Bool) (cf sev acc : ℝ) :
    0 ≤ responsibility_factor isAct isInformed hasDuty cf sev acc := by
  unfold responsibility_factor
  refine mul_nonneg (mul_nonneg ?_ (le_min zero_le_one (le_max_left _ _))) (le_max_left _ _)
  cases isAct <;> cases isInformed <;> cases hasDuty <;> simp [le_min zero_le_one (le_max_left _ _)]

/-- Responsibility is monotonically non-decreasing in severity. -/
theorem responsibility_monotone_in_severity
    (isAct isInformed hasDuty : Bool) (cf acc : ℝ) {sev₁ sev₂ : ℝ} (hsev : sev₁ ≤ sev₂) :
    responsibility_factor isAct isInformed hasDuty cf sev₁ acc ≤
      responsibility_factor isAct isInformed hasDuty cf sev₂ acc := by
  unfold responsibility_factor
  refine mul_le_mul_of_nonneg_left (max_le_max_left 0 hsev) ?_
  refine mul_nonneg ?_ (le_min zero_le_one (le_max_left _ _))
  cases isAct <;> cases isInformed <;> cases hasDuty <;> simp [le_min zero_le_one (le_max_left _ _)]

/-- Being informed never carries less responsibility than being uninformed (`!Ig_pays`, 8.152 / 8.159). -/
theorem informed_ge_uninformed_responsibility
    (isAct hasDuty : Bool) (cf sev acc : ℝ) :
    responsibility_factor isAct false hasDuty cf sev acc ≤
      responsibility_factor isAct true hasDuty cf sev acc := by
  unfold responsibility_factor
  refine mul_le_mul_of_nonneg_right
    (mul_le_mul_of_nonneg_right ?_ (le_min zero_le_one (le_max_left _ _))) (le_max_left _ _)
  cases isAct <;> cases hasDuty <;> simp

/-- Restraint burden (`L121` Proportional; author ruling 8.169): the severity of a forcible
    restraint grows with its duration, `sev * (1 + dur / durScale)`. -/
noncomputable def restraint_burden (sev dur durScale : ℝ) : ℝ := sev * (1 + dur / durScale)

/-- Probability that a forcible restraint by the Administration is audited (`L121` DueProcess; AdvAp,
    funded from the commons; author ruling 8.169 option c): a floor plus a share rising with the
    burden, reaching 1 at the governed severity bar `bar`. -/
noncomputable def restraint_audit_prob (sev dur durScale bar floorP : ℝ) : ℝ :=
  min 1 (floorP + (1 - floorP) * (restraint_burden sev dur durScale / bar))

/-- Liability of the enforcing entity for a restraint (`L120` liability order; ruling 8.169): zero
    when the audit upholds the restraint, otherwise the weight `kappa` times the cost it imposed.
    The commons carries the audit cost; the enforcer carries this. -/
noncomputable def false_restraint_liability (upheld : Bool) (kappa cost : ℝ) : ℝ :=
  if upheld then 0 else max 0 kappa * max 0 cost

theorem restraint_audit_prob_certain_above_bar (sev dur durScale bar floorP : ℝ)
    (hbar : 0 < bar) (hf : floorP ≤ 1)
    (h : bar ≤ restraint_burden sev dur durScale) :
    restraint_audit_prob sev dur durScale bar floorP = 1 := by
  unfold restraint_audit_prob
  apply min_eq_left
  have h1 : 1 ≤ restraint_burden sev dur durScale / bar := by
    rw [le_div_iff₀ hbar]; linarith
  nlinarith

theorem restraint_audit_prob_below_one_below_bar (sev dur durScale bar floorP : ℝ)
    (hbar : 0 < bar) (hf : floorP < 1)
    (h : restraint_burden sev dur durScale < bar) :
    restraint_audit_prob sev dur durScale bar floorP < 1 := by
  unfold restraint_audit_prob
  apply lt_of_le_of_lt (min_le_right _ _)
  have h1 : restraint_burden sev dur durScale / bar < 1 := by
    rw [div_lt_iff₀ hbar]; linarith
  nlinarith

theorem restraint_audit_prob_mono_in_burden (b1 b2 bar floorP : ℝ)
    (hbar : 0 < bar) (hf : floorP ≤ 1) (hle : b1 ≤ b2) :
    min 1 (floorP + (1 - floorP) * (b1 / bar)) ≤ min 1 (floorP + (1 - floorP) * (b2 / bar)) := by
  apply min_le_min_left
  have : b1 / bar ≤ b2 / bar := div_le_div_of_nonneg_right hle hbar.le
  nlinarith

/-- Monotone in severity at fixed duration. -/
theorem restraint_audit_prob_mono_severity (s1 s2 dur durScale bar floorP : ℝ)
    (hbar : 0 < bar) (hf : floorP ≤ 1) (hd : 0 ≤ dur) (hds : 0 < durScale) (hle : s1 ≤ s2) :
    restraint_audit_prob s1 dur durScale bar floorP ≤ restraint_audit_prob s2 dur durScale bar floorP := by
  unfold restraint_audit_prob
  apply restraint_audit_prob_mono_in_burden _ _ bar floorP hbar hf
  unfold restraint_burden
  have : 0 ≤ 1 + dur / durScale := by positivity
  exact mul_le_mul_of_nonneg_right hle this

/-- Monotone in duration at fixed non-negative severity. -/
theorem restraint_audit_prob_mono_duration (sev d1 d2 durScale bar floorP : ℝ)
    (hbar : 0 < bar) (hf : floorP ≤ 1) (hs : 0 ≤ sev) (hds : 0 < durScale) (hle : d1 ≤ d2) :
    restraint_audit_prob sev d1 durScale bar floorP ≤ restraint_audit_prob sev d2 durScale bar floorP := by
  unfold restraint_audit_prob
  apply restraint_audit_prob_mono_in_burden _ _ bar floorP hbar hf
  unfold restraint_burden
  have : d1 / durScale ≤ d2 / durScale := div_le_div_of_nonneg_right hle hds.le
  exact mul_le_mul_of_nonneg_left (by linarith) hs

theorem false_restraint_liability_zero_when_upheld (kappa cost : ℝ) :
    false_restraint_liability true kappa cost = 0 := by
  simp [false_restraint_liability]

/-- Counterexample guard: an overturned restraint at positive weight and cost is never free for the
    enforcer (the unaudited, costless restraint of the toy enforcement world is exactly zero). -/
theorem false_restraint_liability_positive_when_overturned (kappa cost : ℝ)
    (hk : 0 < kappa) (hc : 0 < cost) :
    0 < false_restraint_liability false kappa cost := by
  simp only [false_restraint_liability, Bool.false_eq_true, if_false]
  rw [max_eq_right hk.le, max_eq_right hc.le]
  exact mul_pos hk hc

theorem false_restraint_liability_mono_kappa (k1 k2 cost : ℝ) (hle : k1 ≤ k2) :
    false_restraint_liability false k1 cost ≤ false_restraint_liability false k2 cost := by
  simp only [false_restraint_liability, Bool.false_eq_true, if_false]
  exact mul_le_mul_of_nonneg_right (max_le_max_left 0 hle) (le_max_left 0 cost)

end Benefuture.Subgoals

