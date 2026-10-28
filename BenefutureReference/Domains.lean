/-
  BenefutureReference.Domains
  Computable reference for domain profiles and attribution (L22, L101), over Float. Mirrors
  `PartitionOfUnity` (Ontology.Domain) and `compute_hPos`, `compute_hNeg`, `action_decay_rate`
  (Ontology.Reputation).
-/

namespace BenefutureReference

/-- A domain profile is a partition of unity: non-negative shares summing to 1 (to 1e-9). -/
def profile_valid_ref (shares : Array Float) : Bool :=
  shares.size > 0 && shares.all (· ≥ 0.0) &&
    (let s := shares.foldl (· + ·) 0.0; (s - 1.0).abs ≤ 1e-9)

/--
  What an action attributes to one leaf domain: its share there × the entity's causal
  contribution × the contribution (positive and negative are attributed separately).
-/
def attribute_ref (share cc contribution : Float) : Float := share * (cc * contribution)

/-- Relevance decays at the rate of its sign: gains at λ₊, losses at λ₋. -/
def decay_rate_for_ref (signed lambdaPos lambdaNeg : Float) : Float :=
  if signed ≥ 0.0 then lambdaPos else lambdaNeg

end BenefutureReference
