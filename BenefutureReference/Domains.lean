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

/--
  An action's profile, assigned by currency metric models from its measured causal signature
  (L22: classification from measured proclivities, not declaration). `dists` are the distances
  from the action's signature to each domain's. Domains within `threshold` share the profile by
  closeness, `exp(-(d² - d_min²) / temperature)` normalised, so the nearest match anchors the scale
  and a match never underflows to none. With no match the action is new to every domain: the
  profile is all StandCoin, the unspecialized currency (the extra last entry), and the action is
  flagged for adjudication. The result has `dists.size + 1` entries and is a partition of unity.
-/
def classify_ref (dists : Array Float) (threshold temperature : Float) : Array Float :=
  let matched := dists.filter (· ≤ threshold)
  if matched.isEmpty then (dists.map fun _ => 0.0).push 1.0
  else
    let m := matched.foldl min matched[0]!
    let w := dists.map fun d => if d ≤ threshold then Float.exp (-(d * d - m * m) / temperature) else 0.0
    let s := w.foldl (· + ·) 0.0
    (w.map (· / s)).push 0.0

/--
  Accumulation threshold of a balance in one domain (L100: AccumThresh(Re, ...)): a base plus a
  share of the entity's positive relevance there. Equity and goal terms come with governance.
-/
def accumulation_threshold_ref (base factor relevance : Float) : Float :=
  base + factor * max relevance 0.0

/-- Balance overflow (L100): the part of a balance above its threshold, reinvested in the domain. -/
def overflow_ref (balance threshold : Float) : Float := max (balance - threshold) 0.0

end BenefutureReference
