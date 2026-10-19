/-
  Benefuture.Ontology.Domain
  Formalization of Domain (Dn ∈ T) as a Bounded Classification Pattern of Reality (ℝ).
  Corresponds to: Bf_Pseudocode.txt L22, and Domain.txt
  
  "Domain«Dn»:=ClassificationPattern(ℝ),Dn(T):=[(Dn_i,RelType,Wt)]|ΣWt=1,CausalStructure,NaturalOverlap,Nested(fuzzy),Rel(Dn_i,Dn_j)←Mem !declared;"
  "A domain is a bounded classification pattern of Reality within which specific types of 
   interactions, resources, and outcomes share causal structure. Domains provide jurisdictional 
   scope for metric models, currencies and reputation, enabling specialized prediction while 
   preventing unbounded claims."
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Tactic.Linarith
import Benefuture.Math.Order
import Benefuture.Ontology.Thing

namespace Benefuture.Ontology

open Benefuture.Math

/-- 
  Hierarchical category taxonomy for Domains:
  Bootstraps from ISIC Rev. 4, ICF, SUMO, Diderot's tree of human knowledge.
  Level 1 categories: Physical, Informational, Social, Wellbeing.
-/
inductive DomainCategory where
  | Physical       : DomainCategory  -- Biological, Material, Energy, Ecosystem
  | Informational  : DomainCategory  -- Production, Transmission, Application, Sciences
  | Social         : DomainCategory  -- Governance, Care, Community, Justice, Administration
  | Wellbeing      : DomainCategory  -- Hedonic, Eudaimonic, Relational, Meaning
  deriving Repr, DecidableEq

/-- 
  Classification Domain for human, physical, and informational activities (extends Thing).
  Domain«Dn» := ClassificationPattern(ℝ).
  Corresponds to: Bf_Pseudocode.txt L22, Domain.txt L2-18.
-/
structure Domain extends Thing where
  name            : String
  category        : DomainCategory
  causalStructure : List String  -- Characteristic causal mechanisms grounding the domain
  parentDomainId  : Option String := none -- Nested structure: Level 1 -> Level 2 -> Level 3
  h_causal_nonempty : causalStructure ≠ [] -- Grounded in empirical causality, not topic labels
  deriving Repr, DecidableEq

/-- Coercion: Every Domain is canonically a Thing in Reality. -/
instance : Coe Domain Thing where
  coe d := d.toThing

/-- Helper constructor for standard Domains. -/
def Domain.mkSimple (id name : String) (cat : DomainCategory := .Physical) 
    (causalMech : String := "causal_invariance") : Domain :=
  { toThing := Thing.mkSimple id s!"domain_{name}" "reality_ontology" 0,
    name := name,
    category := cat,
    causalStructure := [causalMech],
    parentDomainId := none,
    h_causal_nonempty := by intro h; contradiction }

/-- 
  Relationship type connecting a Thing to a Domain:
  A Thing belongs to multiple domains simultaneously through distinct relationship channels.
-/
inductive RelationshipType where
  | CausalRelationship   : RelationshipType  -- Generates or mediates causal mechanisms
  | ResourceRelationship : RelationshipType  -- Consumes or transforms domain resources
  | OutcomeRelationship  : RelationshipType  -- Generates outcomes affecting domain state
  | SubstrateRelationship: RelationshipType  -- Operates on the physical/digital substrate of the domain
  | RegulatoryScope      : RelationshipType  -- Subject to institutional or legal rules of the domain
  deriving Repr, DecidableEq

/-- 
  Domain relevance signature tuple:
  (Dn_i, RelType, Wt ∈ [0, 1]).
  Corresponds to: Bf_Pseudocode.txt L22: Dn(T) := [(Dn_i, RelType, Wt ∈ [0, 1])].
-/
structure DomainRelevance where
  domain       : Domain
  relationType : RelationshipType
  weight       : Int  -- Magnitude of belongingness scaled in micro-units [0, SCALE]
  h_wt_nonneg  : 0 ≤ weight
  h_wt_bound   : weight ≤ SCALE
  deriving Repr

/-- 
  Domain Signature: The full weighted multi-domain membership profile of a Thing in Reality.
-/
def DomainSignature := List DomainRelevance

/-- Extract total membership weight of a Thing in a given domain across all relationship types. -/
def domain_membership_weight (sig : DomainSignature) (d : Domain) : Int :=
  sig.foldl (fun acc rel => if rel.domain.id = d.id then acc + rel.weight else acc) 0

/-- 
  Natural Overlap between two domains based on shared causal structure.
  Where domains routinely overlap, mandatory metric model competition emerges.
-/
def causal_overlap_count (d1 d2 : Domain) : Nat :=
  d1.causalStructure.foldl (fun acc mech => if d2.causalStructure.contains mech then acc + 1 else acc) 0

/-- Two domains are causally disjoint if no causal mechanism of d1 appears in d2. -/
def are_causally_disjoint (d1 d2 : Domain) : Prop :=
  ∀ mech ∈ d1.causalStructure, mech ∉ d2.causalStructure

theorem foldl_overlap_zero (l : List String) (d2 : Domain) (acc : Nat)
    (h_none : ∀ mech ∈ l, mech ∉ d2.causalStructure) :
    l.foldl (fun a mech => if d2.causalStructure.contains mech then a + 1 else a) acc = acc := by
  induction l generalizing acc with
  | nil => rfl
  | cons head tail ih =>
    dsimp
    have h_head : head ∉ d2.causalStructure := h_none head (by simp)
    have h_b : d2.causalStructure.contains head = false := by
      rw [List.contains_eq_mem]
      exact decide_eq_false h_head
    rw [h_b]
    dsimp
    apply ih
    intro m hm
    exact h_none m (by simp [hm])

/-- 
  Mandatory Competition Predicate:
  Where domain overlap exceeds the competition threshold, multiple metric models
  must compete to measure and price activities, preventing monopolistic capture.
  Corresponds to: Domain.txt L14, L66.
-/
def requires_model_competition (overlapScore : Int) (th_competition : Int) : Bool :=
  overlapScore ≥ th_competition

/-- 
  [P] Design requirement: Anti-Gerrymandering Causal Grounding.
  Domain boundaries are required to possess non-empty causal grounding in Reality
  via the `h_causal_nonempty` structure field of `Domain`, ensuring that topic rebranding
  alone cannot evade causal accountability.
-/
abbrev anti_gerrymandering_causal_grounding (d : Domain) : d.causalStructure ≠ [] :=
  d.h_causal_nonempty

/-- 
  THEOREM: Disjoint Domain Zero-Overlap Theorem.
  If two domains are causally disjoint, their overlap count is constructively proven to be identically zero.
-/
theorem disjoint_domains_have_zero_overlap (d1 d2 : Domain) (h : are_causally_disjoint d1 d2) :
    causal_overlap_count d1 d2 = 0 := by
  unfold causal_overlap_count are_causally_disjoint at *
  exact foldl_overlap_zero d1.causalStructure d2 0 h

/- =========================================================================
   3.2 [R] DOMAIN PATTERNS, SHARES, AND FUZZY HIERARCHY
   - Only the domain PATTERN is defined (consortium-maintained, bootstrapped).
   - Domain-domain relations computed from Mem records, never declared.
   - Memberships of a Thing/action are SHARES summing to 1 (a partition of unity).
   - Leaves hold shares; parents are fuzzy sets of leaves with degrees μ_p ∈ [0, 1].
   ========================================================================= -/

/-- 
  [R] Leaf Domain: The atomic jurisdictional unit holding discrete shares of credit/value.
  Decision profiles and reputation balances reside on leaf domains.
-/
structure LeafDomain where
  id   : String
  name : String := id
  deriving Repr, DecidableEq

/-- 
  [R] Generic Partition of Unity:
  Memberships of an action or thing across leaf domains are non-negative shares summing to 1.
  Indexed generically by RelType.
  SPEC-CHOICE: In the single-partition reading, RelType = Unit.
-/
structure PartitionOfUnity (RelType : Type) (leaves : Finset LeafDomain) where
  share : RelType → LeafDomain → ℝ
  h_nonneg : ∀ r l, 0 ≤ share r l
  h_sum_one : ∀ r, (leaves.sum (fun l => share r l)) = 1
  h_support : ∀ r l, l ∉ leaves → share r l = 0

abbrev SinglePartitionOfUnity (leaves : Finset LeafDomain) :=
  PartitionOfUnity Unit leaves

/-- 
  [P] Parent Domain: A fuzzy set of leaf domains.
  Each parent domain has degrees μ_p : LeafDomain → [0, 1] (degree of membership, NOT share).
-/
structure ParentDomain (leaves : Finset LeafDomain) where
  id         : String
  name       : String := id
  μ          : LeafDomain → ℝ
  h_μ_nonneg : ∀ l, 0 ≤ μ l
  h_μ_bound  : ∀ l, μ l ≤ 1

/-- 
  [R] Aggregate value or credit at a parent domain:
  any aggregate at p = Σ_leaf μ_p(leaf) · aggregate(leaf).
-/
def aggregate_at_parent {leaves : Finset LeafDomain} (p : ParentDomain leaves)
    (leaf_agg : LeafDomain → ℝ) : ℝ :=
  leaves.sum (fun l => p.μ l * leaf_agg l)

/-- 
  THEOREM: No Double Counting in Parent Domain Aggregation.
  For any single unit of value v ≥ 0 partitioned across leaves via shares summing to 1,
  the aggregate measured at any parent domain p cannot exceed v.
-/
theorem aggregate_no_double_count {leaves : Finset LeafDomain} (p : ParentDomain leaves)
    (shares : LeafDomain → ℝ) (h_nonneg : ∀ l, 0 ≤ shares l)
    (h_sum : leaves.sum shares = 1) (v : ℝ) (hv : 0 ≤ v) :
    leaves.sum (fun l => p.μ l * (shares l * v)) ≤ v := by
  have h_le : leaves.sum (fun l => p.μ l * (shares l * v)) ≤ leaves.sum (fun l => 1 * (shares l * v)) := by
    apply Finset.sum_le_sum
    intro l _
    have h_prod : 0 ≤ shares l * v := mul_nonneg (h_nonneg l) hv
    have h_mu := p.h_μ_bound l
    nlinarith
  have h_eq : leaves.sum (fun l => 1 * (shares l * v)) = v := by
    have h_one : leaves.sum (fun l => 1 * (shares l * v)) = leaves.sum (fun l => shares l * v) := by
      apply Finset.sum_congr rfl
      intro l _
      rw [one_mul]
    rw [h_one, ← Finset.sum_mul, h_sum, one_mul]
  linarith

/-- 
  THEOREM: Monotonicity of Parent Aggregates.
  If child domain c has degrees μ_c pointwise less than or equal to parent domain p,
  then for any non-negative leaf aggregate, aggregate(c) ≤ aggregate(p).
-/
theorem aggregate_monotonicity {leaves : Finset LeafDomain}
    (c p : ParentDomain leaves) (h_le : ∀ l, c.μ l ≤ p.μ l)
    (leaf_agg : LeafDomain → ℝ) (h_agg_nonneg : ∀ l, 0 ≤ leaf_agg l) :
    aggregate_at_parent c leaf_agg ≤ aggregate_at_parent p leaf_agg := by
  unfold aggregate_at_parent
  apply Finset.sum_le_sum
  intro l _
  have h_diff := h_le l
  have h_pos := h_agg_nonneg l
  nlinarith

abbrev Dn := Domain

end Benefuture.Ontology
