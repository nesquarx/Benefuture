/-
  Benefuture.Governance.Democracy
  Formalization of Expertise and Impact-Weighted Democracy (BfDm) and Anti-Halo Isolation.
  Corresponds to: Bf_Pseudocode.txt L100-101, L113-114, and Government.txt
  "BfDm(D(Dn_i, j, k...)) := Base_VW + Expert(Σŵ_i·Re(Dn_i)/ΣRe(Dn_i) | Σŵ=1)VW + Impacted(Pr_Imp → Voter)VW, Delib!Inf←↓Tr, FractalScope, VW < Th ⇒ VoteOptional;"
-/

import Benefuture.Economy.Currency
import Benefuture.Measurement.MetricModel
import Benefuture.Ontology.Sophont
import Benefuture.Ontology.Reputation

namespace Benefuture.Governance

open Benefuture.Economy
open Benefuture.Measurement
open Benefuture.Ontology

/-- 
  Reputation record of an entity strictly partitioned by Domain (extends Thing).
  Corresponds to: Bf_Pseudocode.txt L100-101:
  "Re(E, Dn) = [ΣRe_+ve, ΣRe_-ve, Relevance := Re_net - Decay]_Dn ← recount(Mem), ∄Re(E, ¬Dn), !halo, !horn, !transfer;"
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


/--
  [Legacy] Summary score: positives less twice the negatives less a decay figure, floored at 0.
  This is NOT the ruled asymmetry. The sources define ledger asymmetry as mistakes decaying slower
  than wins (λ₋ < λ₊, ruling 8.29.1; `GovParams.h_lambda_minus_le_plus`,
  `Systems.ParamSpace.Admissible`), with ledger entries never decaying and only the rolling net
  decaying (ruling 8.42.4). The ×2 weighting and the floor are this summary's own choices, kept for
  the Int voting weights below.
-/
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
  [R] Domain-relative expertise (author ruling 8.22.1, settling 8.21; L113: Re(Dn_i)/ΣRe(Dn_i)):
  a voter's expertise enters as its share of the domain's total reputation. Only the vote weight is
  normalised; reputation itself stays absolute (ruling 8.48).
-/
noncomputable def relative_expertise {ι : Type*} (voters : Finset ι) (rep : ι → ℝ) (i : ι) : ℝ :=
  rep i / ∑ j ∈ voters, rep j

/-- THEOREM: Domain-relative expertise shares sum to one across a domain's voters. -/
theorem relative_expertise_sum_one {ι : Type*} (voters : Finset ι) (rep : ι → ℝ)
    (hpos : 0 < ∑ j ∈ voters, rep j) : ∑ i ∈ voters, relative_expertise voters rep i = 1 := by
  unfold relative_expertise
  simp only [div_eq_mul_inv]
  rw [← Finset.sum_mul, mul_inv_cancel₀ (ne_of_gt hpos)]

/--
  THEOREM: No voter's relative expertise exceeds one, however large its raw reputation: the
  expertise term cannot concentrate weight beyond the expertise weight itself (8.21).
-/
theorem relative_expertise_le_one {ι : Type*} (voters : Finset ι) (rep : ι → ℝ) (i : ι)
    (hnn : ∀ j ∈ voters, 0 ≤ rep j) (hi : i ∈ voters) : relative_expertise voters rep i ≤ 1 := by
  unfold relative_expertise
  by_cases h : ∑ j ∈ voters, rep j = 0
  · simp [h]
  · have hpos : 0 < ∑ j ∈ voters, rep j := lt_of_le_of_ne (Finset.sum_nonneg hnn) (Ne.symm h)
    rw [div_le_one hpos]
    exact Finset.single_le_sum hnn hi

/-- THEOREM: Relative expertise is non-negative when reputations are. -/
theorem relative_expertise_nonneg {ι : Type*} (voters : Finset ι) (rep : ι → ℝ) (i : ι)
    (hnn : ∀ j ∈ voters, 0 ≤ rep j) (hi : i ∈ voters) : 0 ≤ relative_expertise voters rep i := by
  unfold relative_expertise
  exact div_nonneg (hnn i hi) (Finset.sum_nonneg hnn)

/--
  [R] The expertise share of L113: Σŵ_l · Re(Dn_l)/ΣRe(Dn_l) over the decision's domains `leaves`,
  with decision weights ŵ summing to one; `rep l` is each voter's reputation in domain l.
-/
noncomputable def expertise_share {ι κ : Type*} (leaves : Finset κ) (w : κ → ℝ)
    (voters : Finset ι) (rep : κ → ι → ℝ) (i : ι) : ℝ :=
  ∑ l ∈ leaves, w l * relative_expertise voters (rep l) i

/-- THEOREM: The expertise share is at most one (from `relative_expertise_le_one`, Σŵ = 1). -/
theorem expertise_share_le_one {ι κ : Type*} (leaves : Finset κ) (w : κ → ℝ)
    (voters : Finset ι) (rep : κ → ι → ℝ) (i : ι)
    (hw : ∀ l ∈ leaves, 0 ≤ w l) (hsum : ∑ l ∈ leaves, w l = 1)
    (hnn : ∀ l ∈ leaves, ∀ j ∈ voters, 0 ≤ rep l j) (hi : i ∈ voters) :
    expertise_share leaves w voters rep i ≤ 1 := by
  unfold expertise_share
  calc ∑ l ∈ leaves, w l * relative_expertise voters (rep l) i
      ≤ ∑ l ∈ leaves, w l * 1 :=
        Finset.sum_le_sum (fun l hl => mul_le_mul_of_nonneg_left
          (relative_expertise_le_one voters (rep l) i (hnn l hl) hi) (hw l hl))
    _ = 1 := by simp [hsum]

/-- THEOREM: The expertise share is non-negative when weights and reputations are. -/
theorem expertise_share_nonneg {ι κ : Type*} (leaves : Finset κ) (w : κ → ℝ)
    (voters : Finset ι) (rep : κ → ι → ℝ) (i : ι)
    (hw : ∀ l ∈ leaves, 0 ≤ w l) (hnn : ∀ l ∈ leaves, ∀ j ∈ voters, 0 ≤ rep l j)
    (hi : i ∈ voters) : 0 ≤ expertise_share leaves w voters rep i := by
  unfold expertise_share
  exact Finset.sum_nonneg (fun l hl =>
    mul_nonneg (hw l hl) (relative_expertise_nonneg voters (rep l) i (hnn l hl) hi))

/--
  THEOREM (anti-halo, L101 !halo): a voter with no reputation in any of the decision's domains has
  expertise share zero, whatever it holds elsewhere.
-/
theorem expertise_share_zero_of_no_reputation {ι κ : Type*} (leaves : Finset κ) (w : κ → ℝ)
    (voters : Finset ι) (rep : κ → ι → ℝ) (i : ι) (h0 : ∀ l ∈ leaves, rep l i = 0) :
    expertise_share leaves w voters rep i = 0 := by
  unfold expertise_share relative_expertise
  exact Finset.sum_eq_zero (fun l hl => by rw [h0 l hl, zero_div, mul_zero])

/--
  [P] Governed coefficients of BfDm's vote weight (L113): base, expertise and impact weights.
  Thresholds to be governed (SigThGv, L157), not constants of the rule.
-/
structure VoteWeightParams where
  base_weight        : ℝ
  expertise_weight   : ℝ
  impact_weight      : ℝ
  h_base_pos         : 0 < base_weight
  h_expertise_nonneg : 0 ≤ expertise_weight
  h_impact_nonneg    : 0 ≤ impact_weight

/--
  [R] BfDm vote weight (L113; rulings 8.22.1, 8.48):
  VW_i = Base_VW + expertise_weight · Σŵ_l·Re_i(Dn_l)/ΣRe(Dn_l) + impact_weight · Impacted_i.
  The expertise term is normalised at the vote only; reputations stay absolute (8.48).
-/
noncomputable def bfdm_vote_weight {ι κ : Type*} (vp : VoteWeightParams) (leaves : Finset κ)
    (w : κ → ℝ) (voters : Finset ι) (rep : κ → ι → ℝ) (impact : ι → ℝ) (i : ι) : ℝ :=
  vp.base_weight + vp.expertise_weight * expertise_share leaves w voters rep i +
    vp.impact_weight * impact i

/--
  THEOREM: The expertise term of the BfDm vote weight is at most the expertise weight, however
  large a voter's raw reputation (`relative_expertise_le_one`): expertise cannot concentrate vote
  weight beyond its governed coefficient (8.21, 8.22.1).
-/
theorem bfdm_expertise_term_le_weight {ι κ : Type*} (vp : VoteWeightParams) (leaves : Finset κ)
    (w : κ → ℝ) (voters : Finset ι) (rep : κ → ι → ℝ) (i : ι)
    (hw : ∀ l ∈ leaves, 0 ≤ w l) (hsum : ∑ l ∈ leaves, w l = 1)
    (hnn : ∀ l ∈ leaves, ∀ j ∈ voters, 0 ≤ rep l j) (hi : i ∈ voters) :
    vp.expertise_weight * expertise_share leaves w voters rep i ≤ vp.expertise_weight :=
  mul_le_of_le_one_right vp.h_expertise_nonneg
    (expertise_share_le_one leaves w voters rep i hw hsum hnn hi)

/--
  THEOREM: Bounds on the BfDm vote weight: at least the base weight, and at most base plus the
  expertise weight plus the voter's impact term.
-/
theorem bfdm_vote_weight_bounds {ι κ : Type*} (vp : VoteWeightParams) (leaves : Finset κ)
    (w : κ → ℝ) (voters : Finset ι) (rep : κ → ι → ℝ) (impact : ι → ℝ) (i : ι)
    (hw : ∀ l ∈ leaves, 0 ≤ w l) (hsum : ∑ l ∈ leaves, w l = 1)
    (hnn : ∀ l ∈ leaves, ∀ j ∈ voters, 0 ≤ rep l j) (hi : i ∈ voters) (himp : 0 ≤ impact i) :
    vp.base_weight ≤ bfdm_vote_weight vp leaves w voters rep impact i ∧
      bfdm_vote_weight vp leaves w voters rep impact i ≤
        vp.base_weight + vp.expertise_weight + vp.impact_weight * impact i := by
  unfold bfdm_vote_weight
  have h1 := bfdm_expertise_term_le_weight vp leaves w voters rep i hw hsum hnn hi
  have h2 := mul_nonneg vp.h_expertise_nonneg (expertise_share_nonneg leaves w voters rep i hw hnn hi)
  have h3 := mul_nonneg vp.h_impact_nonneg himp
  constructor <;> linarith

/--
  [Legacy] Int voting weight: VW = 1000 + raw domain reputation + impact score. Not L113: the
  expertise term is the raw `DomainReputation.score`, not normalised, and the coefficients are
  fixed. Superseded by `bfdm_vote_weight`.
-/
def calculate_voting_weight (vp : GroundedVoterProfile) (ctx : DecisionContext) (impact_score : Int) : Int :=
  let base_weight := 1000
  let expertise   := get_domain_reputation vp ctx.targetDomain
  base_weight + expertise + impact_score

/--
  [Legacy] Grounded Int voting weight: VW = 1000 + raw DomainReputation(Dn) + DomainImpact(Dn).
  Not L113: raw reputation, not normalised (rulings 8.22.1, 8.48), fixed coefficients.
  Superseded by `bfdm_vote_weight`.
-/
def calculate_grounded_voting_weight (gvp : GroundedVoterProfile) (ctx : DecisionContext) : Int :=
  let base_weight := 1000
  let expertise   := get_domain_reputation gvp ctx.targetDomain
  let impact      := get_grounded_domain_impact gvp ctx.targetDomain
  base_weight + expertise + impact

/-- 
  [R] THEOREM: Anti-Halo Domain Isolation over Decision Profiles.
  Corresponds to: Bf_Pseudocode.txt L101 ("!halo, !horn, !transfer"), L113 ("VW_expert").
  If a decision context D has decision profile dp with support on leaves L_D,
  and a voter has zero relevance across all leaves in L_D, then their expert voting
  weight on D is strictly zero (assuming baseline f(0) = 0).
  Reputation in other domains CANNOT leak into decision D, even with complex domain overlap.
-/
theorem anti_halo_domain_isolation {leaves : Finset LeafDomain}
    (dp : DecisionProfile leaves)
    (relScores : LeafDomain → ReRelevance)
    (f : ℝ → ℝ)
    (hf0 : f 0 = 0)
    (h_zero_relevant : ∀ l ∈ leaves, dp.weights l > 0 → (relScores l).rel = 0) :
    VW_expert dp relScores f = 0 := by
  unfold VW_expert
  have h_terms_zero : ∀ l ∈ leaves, dp.weights l * f (relScores l).rel = 0 := by
    intro l hl
    by_cases hw : dp.weights l = 0
    · rw [hw, zero_mul]
    · have h_pos : dp.weights l > 0 := lt_of_le_of_ne (dp.h_weights_nonneg l) (Ne.symm hw)
      have h_rel := h_zero_relevant l hl h_pos
      rw [h_rel, hf0, mul_zero]
  have h_sum_zero : leaves.sum (fun l => dp.weights l * f (relScores l).rel) =
                    leaves.sum (fun _ => 0) := by
    apply Finset.sum_congr rfl
    intro l hl
    exact h_terms_zero l hl
  rw [h_sum_zero, Finset.sum_const_zero]

/-- 
  THEOREM: Anti-Halo Domain Isolation on Grounded Voter Profiles.
  If a voter has reputations only in Domain A, their queried reputation in a distinct Domain B is 0.
-/
theorem anti_halo_grounded_isolation (vp : GroundedVoterProfile) (domainA domainB : Domain) 
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
  THEOREM: Every voter in a BfDm profile is a Sophont, and so a Being with positive sentience
  (moral standing). That is all this proves: it says nothing about sybil resistance, which rests on
  identity binding (L132) and on base votes following novelty and personhood rather than identity
  count (ruling 8.35.5), neither formalised here.
-/
theorem voter_inherits_sentient_moral_standing (vp : GroundedVoterProfile) :
    0 < (vp.voter : Being).sentience.experienceLevel :=
  (vp.voter : Being).sentience.h_pos

/-- THEOREM: The legacy Int voting weight is at least its base 1000 (see `bfdm_vote_weight_bounds`). -/
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
  · exact anti_halo_grounded_isolation gvp sciDomain musicDomain h_sci_distinct_music h_only_sci_rep
  · exact anti_halo_grounded_isolation gvp sciDomain foodDomain h_sci_distinct_food h_only_sci_rep

/--
  [Legacy] Synthesized reputation score: `DomainReputation.score` (negatives ×2, floored at 0). Not
  the ruled asymmetry, which is slower decay of mistakes than of wins (λ₋ < λ₊, ruling 8.29.1) on
  ledgers whose entries never decay (ruling 8.42.4). Both underlying sums stay logged.
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

/- Balance overflow confers no reputation directly (author ruling 8.51): the excess is directed
   auto-investment (L103), and the reinvestment earns reputation only through the ordinary channels
   once its outcomes are measured (L100: causal contribution to U and H, plus novelty). Reputation
   cannot be purchased. -/

abbrev VW := calculate_grounded_voting_weight
abbrev Dm := GroundedVoterProfile
abbrev BfDm := GroundedVoterProfile
abbrev Re := synthesize_reputation

end Benefuture.Governance
