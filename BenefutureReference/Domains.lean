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

/-!
  The domain tree (author ruling, BACKPROPAGATION 8.3). Nodes are indexed from 0, the root, which
  carries StandCoin; `parents[i] < i` for every other node, so parents precede children.
-/

/-- Depth of each node: the root at 0, every other node one below its parent. -/
def depths_ref (parents : Array Nat) : Array Nat :=
  (List.range parents.size).foldl
    (fun ds i => ds.push (if i == 0 then 0 else ds.getD (parents.getD i 0) 0 + 1)) #[]

/-- The children of node `v`. -/
def children_ref (parents : Array Nat) (v : Nat) : Array Nat :=
  ((List.range parents.size).filter fun i => i != 0 && parents.getD i 0 == v).toArray

/--
  Classification by descent. Currency metric models match an action's causal signature from the
  root down: at each node the children within the threshold for their depth share the action by
  closeness (`classify_ref`), and whatever no child matches stops there. `dists[i]` is the
  distance from the action's signature to node `i`'s; `thresholds[k]` applies to children of a
  node at depth `k` (the last entry to any deeper level). Returns each node's stopping share, a
  partition of unity: all at a leaf for a recognised action, at a branch for one stuck there, at
  the root for one no domain recognises.
-/
def classify_tree_ref (parents : Array Nat) (dists thresholds : Array Float) (temperature : Float) :
    Array Float :=
  let n := parents.size
  let ds := depths_ref parents
  let init : Array Float × Array Float := ((Array.replicate n 0.0).set! 0 1.0, Array.replicate n 0.0)
  let (_, stop) := (List.range n).foldl (fun (acc : Array Float × Array Float) v =>
    let (flow, stop) := acc
    let f := flow.getD v 0.0
    let cs := children_ref parents v
    if f == 0.0 then acc
    else if cs.isEmpty then (flow, stop.modify v (· + f))
    else
      let th := thresholds.getD (ds.getD v 0) (thresholds.back?.getD 0.0)
      let w := classify_ref (cs.map fun c => dists.getD c 0.0) th temperature
      let flow := (List.range cs.size).foldl
        (fun fl k => fl.modify (cs.getD k 0) (· + f * w.getD k 0.0)) flow
      (flow, stop.modify v (· + f * w.getD cs.size 0.0))) init
  stop

/-- The nearest ancestor of `v` (or `v` itself) whose currency is eligible; the root always is. -/
def eligible_ancestor_ref (parents : Array Nat) (eligible : Array Bool) (v : Nat) : Nat :=
  go v parents.size
where
  go (v fuel : Nat) : Nat :=
    match fuel with
    | 0 => 0
    | fuel + 1 => if v == 0 || eligible.getD v false then v else go (parents.getD v 0) fuel

/--
  Pricing by fallback: each node's share moves to its nearest eligible ancestor (L82: a currency
  exists in a domain only while a model there is accurate above threshold). The root, StandCoin,
  is always eligible but predicts no value, so what reaches it is charged resource cost only.
-/
def fallback_ref (parents : Array Nat) (eligible : Array Bool) (shares : Array Float) : Array Float :=
  (List.range shares.size).foldl
    (fun acc v => acc.modify (eligible_ancestor_ref parents eligible v) (· + shares.getD v 0.0))
    (Array.replicate shares.size 0.0)

/--
  A domain's total over its subtree: its own amount plus all its subdomains' (Domain: a broader
  domain includes the reputation of its sub-domains, without double counting). A subdomain's
  total never includes its parent's.
-/
def subtree_sum_ref (parents : Array Nat) (own : Array Float) : Array Float :=
  (List.range own.size).reverse.foldl
    (fun acc v => if v == 0 then acc else acc.modify (parents.getD v 0) (· + acc.getD v 0.0)) own

/--
  Resource cost by availability (L83, StandCoin: charges resource cost as per availability): the
  base rate scaled by capacity over what remains, with what remains floored at a thousandth of
  capacity so exhaustion is dear but finite.
-/
def scarcity_cost_ref (base available capacity : Float) : Float :=
  base * capacity / max available (capacity / 1000.0)

end BenefutureReference
