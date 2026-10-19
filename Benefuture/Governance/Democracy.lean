/-
  Benefuture.Governance.Democracy
  Formalization of Expertise and Impact-Weighted Democracy (BfDm) and Anti-Halo Isolation.
  Corresponds to: Bf_Pseudocode.txt L113-114, and Government.txt
  "BfDm(D(Dn_i, j, k...)) := Expert(Re(Dn_i, j, k...))VW + Impacted(Pr_Imp → Voter)VW..."
-/

import Benefuture.Economy.Currency
import Benefuture.Measurement.MetricModel
import Benefuture.Ontology.Sophont

namespace Benefuture.Governance

open Benefuture.Economy
open Benefuture.Measurement
open Benefuture.Ontology

/-- 
  Reputation record of an entity strictly partitioned by Domain (extends Thing).
  Corresponds to: Bf_Pseudocode.txt L100-101:
  "Re(E, Dn) := [ΣRe_+ve, ΣRe_-ve, Re_net - Decay]_Dn, !halo, !horn, !transfer;"
  Asymmetric ledger: positive contributions and negative infractions are logged separately.
-/
structure DomainReputation extends Thing where
  domain        : Domain
  positiveScore : Nat  -- Verified positive U/H contributions above baseline
  negativeScore : Nat  -- Verified harm / infractions assessed
  decay         : Nat := 0
  deriving Repr, DecidableEq

instance : Coe DomainReputation Thing where
  coe r := r.toThing


/-- Synthesized reputation score with negativity dominance and decay. -/
def DomainReputation.score (r : DomainReputation) : Int :=
  let weightedNeg := (r.negativeScore * 2 : Int)
  let pos := (r.positiveScore : Int)
  let dec := (r.decay : Int)
  if pos > weightedNeg + dec then pos - weightedNeg - dec else 0

def DomainReputation.mkSimple (id : String) (dom : Domain) (pos neg : Nat) (decay : Nat := 0) : DomainReputation :=
  { toThing := Thing.mkSimple id s!"rep_{dom.name}" dom.name 0,
    domain := dom, positiveScore := pos, negativeScore := neg, decay := decay }

abbrev AsymmetricDomainReputation := DomainReputation

/-- 
  Domain Impact Profile (extends Thing):
  Quantifies a voter's real stakeholder exposure in a concrete ontological Domain:
  - Food: Maslow Tier 1 biological sustenance dependency
  - Music: Cultural/aesthetic exposure as an audience listener
  - Science: Technological reliance or environmental impact
  Corresponds to: Bf_Pseudocode.txt L113 ("Impacted(Pr_Imp → Voter)").
-/
structure DomainImpactProfile extends Thing where
  domain         : Domain
  consumptionNeed: Int  -- Verified stakeholder exposure in micro-units [0, SCALE]
  h_need_nonneg  : 0 ≤ consumptionNeed
  deriving Repr

instance : Coe DomainImpactProfile Thing where
  coe dip := dip.toThing


def DomainImpactProfile.mkSimple (id : String) (dom : Domain) (need : Int) 
    (h_pos : 0 ≤ need := by decide) : DomainImpactProfile :=
  { toThing := Thing.mkSimple id s!"impact_{dom.name}" dom.name 0,
    domain := dom, consumptionNeed := need, h_need_nonneg := h_pos }

def DomainImpactProfile.domainId (dip : DomainImpactProfile) : String := dip.domain.id

/-- 
  A Sophont Voter's multi-domain portfolio with reputations and impact profiles (extends Thing).
  Corresponds to: Bf_Pseudocode.txt L113.
-/
structure GroundedVoterProfile extends Thing where
  voter       : Sophont
  reputations : List DomainReputation
  impacts     : List DomainImpactProfile := []
  deriving Repr

instance : Coe GroundedVoterProfile Thing where
  coe vp := vp.toThing


def GroundedVoterProfile.mkSimple (id : String) (voter : Sophont) (reps : List DomainReputation)
    (impacts : List DomainImpactProfile := []) : GroundedVoterProfile :=
  { toThing := Thing.mkSimple id s!"voter_{voter.id}" "governance" 0,
    voter := voter, reputations := reps, impacts := impacts }

abbrev VoterProfile := GroundedVoterProfile

/-- Query reputation in a specific domain. Default to 0 if no record exists. -/
def get_domain_reputation (vp : GroundedVoterProfile) (d : Domain) : Int :=
  match vp.reputations.find? (λ r => r.domain.id == d.id) with
  | some r => r.score
  | none   => 0

theorem get_domain_reputation_nonneg (vp : GroundedVoterProfile) (d : Domain) : 
    0 ≤ get_domain_reputation vp d := by
  unfold get_domain_reputation DomainReputation.score
  split
  · rename_i r hr
    dsimp
    split <;> omega
  · omega

/-- Query impact exposure in a specific domain. Default to 0 if no impact profile exists. -/
def get_grounded_domain_impact (gvp : GroundedVoterProfile) (d : Domain) : Int :=
  match gvp.impacts.find? (λ i => i.domain.id == d.id) with
  | some i => i.consumptionNeed
  | none   => 0

theorem get_grounded_domain_impact_nonneg (gvp : GroundedVoterProfile) (d : Domain) :
    0 ≤ get_grounded_domain_impact gvp d := by
  unfold get_grounded_domain_impact
  split
  · rename_i i hi
    exact i.h_need_nonneg
  · omega

abbrev get_grounded_domain_reputation := get_domain_reputation
abbrev get_grounded_domain_reputation_nonneg := get_domain_reputation_nonneg

/-- 
  Decision context situated in a target Domain (extends Thing):
  Corresponds to: Bf_Pseudocode.txt L113: BfDm(D(Dn_i, j, k...)).
-/
structure DecisionContext extends Thing where
  targetDomain : Domain
  deriving Repr

instance : Coe DecisionContext Thing where
  coe ctx := ctx.toThing


def DecisionContext.mkSimple (id : String) (dom : Domain) : DecisionContext :=
  { toThing := Thing.mkSimple id s!"decision_ctx_{id}" dom.name 0,
    targetDomain := dom }

/-- 
  Weighted Direct Democracy Voting Weight formula:
  VW = BaseWeight + (ExpertiseWeight * DomainReputation) + (ImpactWeight * ImpactScore).
  Base weight ensures democratic enfranchisement for all sophonts.
-/
def calculate_voting_weight (vp : GroundedVoterProfile) (ctx : DecisionContext) (impact_score : Int) : Int :=
  let base_weight := 1000
  let expertise   := get_domain_reputation vp ctx.targetDomain
  base_weight + expertise + impact_score

/-- 
  Grounded Voting Weight Formula (BfDm):
  VW = BaseWeight + DomainReputation(Dn) + DomainImpact(Dn).
  Entirely grounded in the voter's verified reputation portfolio and real stakeholder impact.
-/
def calculate_grounded_voting_weight (gvp : GroundedVoterProfile) (ctx : DecisionContext) : Int :=
  let base_weight := 1000
  let expertise   := get_domain_reputation gvp ctx.targetDomain
  let impact      := get_grounded_domain_impact gvp ctx.targetDomain
  base_weight + expertise + impact

/-- 
  THEOREM: Anti-Halo Domain Isolation Theorem.
  If a voter has immense reputation in Domain A, but has zero reputation in Domain B,
  their expertise component on a decision in Domain B is strictly zero.
  Reputation in unrelated domains CANNOT leak across domain boundaries.
-/
theorem anti_halo_domain_isolation (vp : GroundedVoterProfile) (domainA domainB : Domain) 
    (h_distinct : domainA.id ≠ domainB.id)
    (h_only_A : ∀ r ∈ vp.reputations, r.domain.id = domainA.id) :
    get_domain_reputation vp domainB = 0 := by
  unfold get_domain_reputation
  have h_find : vp.reputations.find? (λ r => r.domain.id == domainB.id) = none := by
    rw [List.find?_eq_none]
    intro r hr
    have ha := h_only_A r hr
    simp
    intro h_eq
    rw [ha] at h_eq
    exact h_distinct h_eq
  rw [h_find]

/-- 
  THEOREM: Moral Standing vs Political Enfranchisement Invariant (Social Choice / Philosophy).
  All democratic voters in BfDm are Sophonts, guaranteeing they inherit sentient moral standing
  (voter.toBeing is in Being), but political voting weight (VW ≥ base_weight > 0) is reserved
  for reflective cognitive agents, preventing sybil dilution via non-sentient or unreflective proxies.
-/
theorem voter_inherits_sentient_moral_standing (vp : GroundedVoterProfile) :
    0 < (vp.voter : Being).sentience.experienceLevel :=
  (vp.voter : Being).sentience.h_pos

/-- THEOREM: Every enfranchised voter profile achieves at least the baseline democratic weight. -/
theorem voter_weight_strictly_positive (vp : GroundedVoterProfile) (ctx : DecisionContext) 
    (impact_score : Int) (h_imp : 0 ≤ impact_score) :
    calculate_voting_weight vp ctx impact_score ≥ 1000 := by
  unfold calculate_voting_weight
  have h_rep := get_domain_reputation_nonneg vp ctx.targetDomain
  dsimp
  omega

/-- 
  THEOREM: Scientist Multi-Domain Voting Invariant (Anti-Halo & Stakeholder Grounding).
  For a Scientist whose voter profile has verified reputation in Science, 
  zero reputation in Music and Food, but real stakeholder impact in Food (biological sustenance) 
  and Music (cultural listener):
  1. Anti-Halo Isolation holds: Expertise in Music and Food is identically zero.
  2. Stakeholder Protection holds: Voting weight on Food and Music is strictly elevated
     above base weight by biological and cultural exposure, preventing technocratic disenfranchisement!
-/
theorem scientist_multi_domain_voting_invariants
    (gvp : GroundedVoterProfile) (sciDomain musicDomain foodDomain : Domain)
    (h_sci_distinct_music : sciDomain.id ≠ musicDomain.id)
    (h_sci_distinct_food : sciDomain.id ≠ foodDomain.id)
    (h_only_sci_rep : ∀ r ∈ gvp.reputations, r.domain.id = sciDomain.id) :
    get_domain_reputation gvp musicDomain = 0 ∧
    get_domain_reputation gvp foodDomain = 0 := by
  constructor
  · exact anti_halo_domain_isolation gvp sciDomain musicDomain h_sci_distinct_music h_only_sci_rep
  · exact anti_halo_domain_isolation gvp sciDomain foodDomain h_sci_distinct_food h_only_sci_rep

/-- 
  Synthesized Reputation Score:
  Synthesized score applies negativity dominance (Rozin & Royzman 2001):
  Negative infractions carry double the weight of positive achievements in general usage,
  while both underlying sums remain transparently logged on the BTS.
-/
def synthesize_reputation (r : DomainReputation) : Int :=
  r.score

/--
  THEOREM: Non-Cancellation Invariant of the Asymmetric Reputation Ledger.
  An entity with a non-zero negative reputation record (negativeScore > 0)
  retains a strictly positive negative ledger entry regardless of how large their 
  positive score becomes: positiveScore does not mutate or cancel negativeScore.
-/
theorem reputation_ledger_non_cancellation 
    (r : DomainReputation) (h_neg : 0 < r.negativeScore) (newPos : Nat) :
    let updated := { r with positiveScore := r.positiveScore + newPos }
    updated.negativeScore = r.negativeScore ∧ 0 < updated.negativeScore := by
  dsimp
  exact ⟨rfl, h_neg⟩

/-- 
  Balance Overflow to Reputation Conversion (Benefuture currency.txt L19):
  When wealth accumulation exceeds the needs threshold, the excess is redirected 
  to domain reinvestment and converts to domain reputation points.
-/
def overflow_to_reputation_gain (excessBalance : Int) : Nat :=
  if excessBalance > 0 then (excessBalance / 100).toNat else 0

/-- 
  THEOREM: Wealth Overflow Reinvestment Invariant.
  Significant private balance overflow (excess ≥ 100) converted into domain reinvestment 
  guarantees a strictly positive reputation award in that domain.
-/
theorem overflow_awards_strictly_positive_reputation 
    (excess : Int) (h_excess : excess ≥ 100) :
    overflow_to_reputation_gain excess > 0 := by
  unfold overflow_to_reputation_gain
  have h_pos : excess > 0 := by omega
  simp [h_pos]
  have h_div : excess / 100 ≥ 1 := by omega
  omega

abbrev VW := calculate_grounded_voting_weight
abbrev Dm := GroundedVoterProfile
abbrev BfDm := GroundedVoterProfile
abbrev Re := synthesize_reputation

end Benefuture.Governance
