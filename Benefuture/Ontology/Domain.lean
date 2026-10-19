/-
  Benefuture.Ontology.Domain
  Formalization of Domain (Dn ∈ T) as a Bounded Classification Pattern of Reality (ℝ).
  Corresponds to: Bf_Pseudocode.txt L22, and Domain.txt
  
  "Domain«Dn»:=ClassificationPattern(ℝ),Dn(T):=[(Dn_i,RelType,Wt∈[0,1])]|CausalStructure,NaturalOverlap;"
  "A domain is a bounded classification pattern of Reality within which specific types of 
   interactions, resources, and outcomes share causal structure. Domains provide jurisdictional 
   scope for metric models, currencies and reputation, enabling specialized prediction while 
   preventing unbounded claims."
-/

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

abbrev Dn := Domain

end Benefuture.Ontology

