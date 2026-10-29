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
  The domain network (Ontology.Domain [R]: leaves hold shares, parents are fuzzy sets of leaves
  with degrees μ; Proposed.DomainHierarchy [P]: μ from memory as fuzzy subsethood; author rulings,
  BACKPROPAGATION 8.3, 8.4, 8.8). Parents are indexed 0..P-1 and leaves 0..L-1; `mu` is row-major,
  parents × leaves. Shares are laid out as L leaves, then P parent residuals, then the root
  (StandCoin).
-/

def mu_at (mu : Array Float) (nLeaves p l : Nat) : Float := mu.getD (p * nLeaves + l) 0.0

/-- An action's membership in a parent from causal signature overlap: its projection on the
    parent's signature, clamped to [0, 1]. -/
def projection_membership_ref (sig parent : Array Float) : Float :=
  let dot := (sig.zip parent).foldl (fun a (x, y) => a + x * y) 0.0
  let nn := parent.foldl (fun a y => a + y * y) 0.0
  if nn ≤ 0.0 then 0.0 else max 0.0 (min 1.0 (dot / nn))

/--
  Classification by descent through the network. Parents whose membership reaches
  `parentThreshold` match; the candidate leaves are their members (μ ≥ `muMin`), or, when no parent
  matches, the leaves belonging to no parent. Candidates share the action by closeness
  (`classify_ref`); what no candidate takes stays with the matched parents in proportion to
  membership (stuck at a branch), or at the root when no parent matched. A partition of unity.
-/
def classify_network_ref (parentMem leafDists mu : Array Float)
    (parentThreshold muMin leafThreshold temperature : Float) : Array Float :=
  let np := parentMem.size
  let nl := leafDists.size
  let matched := (List.range np).filter fun p => parentMem.getD p 0.0 ≥ parentThreshold
  let candidate (l : Nat) : Bool :=
    if matched.isEmpty then (List.range np).all fun p => mu_at mu nl p l < muMin
    else matched.any fun p => mu_at mu nl p l ≥ muMin
  let cands := ((List.range nl).filter candidate).toArray
  let w := if cands.isEmpty then #[1.0]
    else classify_ref (cands.map fun l => leafDists.getD l 0.0) leafThreshold temperature
  let out := (List.range cands.size).foldl (fun o k => o.set! (cands.getD k 0) (w.getD k 0.0))
    (Array.replicate (nl + np + 1) 0.0)
  let resid := w.getD cands.size 0.0
  if matched.isEmpty then out.modify (nl + np) (· + resid)
  else
    let tot := matched.foldl (fun a p => a + parentMem.getD p 0.0) 0.0
    matched.foldl (fun o p => o.modify (nl + p) (· + resid * parentMem.getD p 0.0 / tot)) out

/--
  Pricing by fallback (L82: a currency exists in a domain only while a model there qualifies). An
  ineligible leaf's share moves to its eligible parents in proportion to μ, or to the root when it
  has none; an ineligible parent's residual moves to the root. The root, StandCoin, predicts no
  value: what reaches it is charged resource cost only.
-/
def fallback_network_ref (mu : Array Float) (leafOk parentOk : Array Bool) (shares : Array Float) :
    Array Float :=
  let nl := leafOk.size
  let np := parentOk.size
  let root := nl + np
  let out := (List.range nl).foldl (fun o l =>
    let s := shares.getD l 0.0
    if leafOk.getD l false then o.modify l (· + s)
    else
      let ps := (List.range np).filter fun p => parentOk.getD p false && mu_at mu nl p l > 0.0
      let tot := ps.foldl (fun a p => a + mu_at mu nl p l) 0.0
      if tot ≤ 0.0 then o.modify root (· + s)
      else ps.foldl (fun o p => o.modify (nl + p) (· + s * mu_at mu nl p l / tot)) o)
    (Array.replicate (nl + np + 1) 0.0)
  let out := (List.range np).foldl
    (fun o p => o.modify (if parentOk.getD p false then nl + p else root) (· + shares.getD (nl + p) 0.0)) out
  out.modify root (· + shares.getD root 0.0)

/-- Aggregate at a parent (Ontology.Domain `aggregate_at_parent`): Σ_leaf μ_p(leaf) · amount(leaf). -/
def aggregate_at_parent_ref (muRow leafAmounts : Array Float) : Float :=
  (muRow.zip leafAmounts).foldl (fun a (m, x) => a + m * x) 0.0

/-- Fuzzy subsethood of x in y over remembered actions (Proposed.DomainHierarchy [P]):
    Σ min(m_x, m_y)·CE / Σ m_x·CE, zero without evidence. -/
def subsethood_ref (mx my ce : Array Float) : Float :=
  let den := (mx.zip ce).foldl (fun a (m, c) => a + m * c) 0.0
  let num := ((mx.zip my).zip ce).foldl (fun a ((x, y), c) => a + min x y * c) 0.0
  if den ≤ 0.0 then 0.0 else num / den

/-- An overlap degree as a long-term rolling average of memberships (author ruling,
    BACKPROPAGATION 8.12): each logged action moves μ_p(leaf) toward its share of the action that
    also lies in p, by `rate` × its membership in the leaf, μ + rate · (min(m_leaf, m_p) − m_leaf · μ).
    Averaged over many actions this is the subsethood above; an action outside the leaf leaves μ
    untouched, so domains never fade, and overlaps shift only as reality does. -/
def membership_rolling_ref (mu mLeaf mParent rate : Float) : Float :=
  max 0.0 (min 1.0 (mu + rate * (min mLeaf mParent - mLeaf * mu)))

/-- A model's accuracy in [0, 1] from its score (negative mean squared error): 1 / (1 + RMSE). It is
    also the confidence that splits escrow. -/
def accuracy_ref (score : Float) : Float := 1.0 / (1.0 + Float.sqrt (max (-score) 0.0))

/-- The standard normal distribution function, by Abramowitz and Stegun 7.1.26 for erf (absolute
    error below 1.5e-7). -/
def normal_cdf_ref (x : Float) : Float :=
  let z := x.abs / Float.sqrt 2.0
  let t := 1.0 / (1.0 + 0.3275911 * z)
  let poly := t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))))
  let erf := 1.0 - poly * Float.exp (-(z * z))
  if x ≥ 0.0 then 0.5 * (1.0 + erf) else 0.5 * (1.0 - erf)

/-- A model's credence that an action's assessed value is positive (L84: P(As(V, A, t0) > 0);
    author rulings 8.35, 8.36): its predicted value over its own uncertainty, through the normal
    distribution function. No uncertainty is the greatest credence allowed in the predicted sign;
    infinite uncertainty is a coin toss. Truth levels never reach 1 (author ruling 8.33): credence
    stays within [1 − cap, cap]. -/
def credence_ref (predicted uncertainty cap : Float) : Float :=
  let c := if uncertainty == 0.0 then (if predicted > 0.0 then 1.0 else if predicted < 0.0 then 0.0 else 0.5)
           else normal_cdf_ref (predicted / uncertainty)
  max (1.0 - cap) (min cap c)

/-- Accuracy as the quality of credences (author rulings 8.35, 8.36): 1 − Brier / 0.25, the Brier
    score of random guessing (credence 0.5); 0 is random, 1 perfect (generally unattainable); worse
    than random scores 0; no record, no accuracy. -/
def credence_accuracy_ref (credences outcomes : Array Float) : Float := Id.run do
  let n := min credences.size outcomes.size
  if n == 0 then return 0.0
  let mut b := 0.0
  for i in [0:n] do
    let e := credences[i]! - outcomes[i]!
    b := b + e * e
  return max 0.0 (1.0 - (b / n.toFloat) / 0.25)

/-- Currency eligibility (L82, author ruling): an established domain's model qualifies at
    `threshold`; a novel domain's, after its score-only phase of `minRecords` scored predictions,
    at `novelThreshold`, never below 0.55 (author ruling 8.35: that floor is for discovering what has
    no precedent; established sub-domains need 0.9 or more, new or coarse ones 0.75 or more). -/
def currency_eligible_ref (accuracy records minRecords : Float) (novel : Bool)
    (threshold novelThreshold : Float) : Bool :=
  if novel then records ≥ minRecords && accuracy ≥ max novelThreshold 0.55 else accuracy ≥ threshold

/--
  Resource cost by availability (L83, StandCoin: charges resource cost as per availability): the
  base rate scaled by capacity over what remains, with what remains floored at a thousandth of
  capacity so exhaustion is dear but finite.
-/
def scarcity_cost_ref (base available capacity : Float) : Float :=
  base * capacity / max available (capacity / 1000.0)

end BenefutureReference
