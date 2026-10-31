import BenefutureReference.Domains

/-
  BenefutureReference.Records
  Computable reference for rules that read or write records: the reputation a vote earns, the
  delegate audit, a source's weight in deliberation, trickle-down of understanding, the ledgers'
  negative share and one record's credence score.
-/

namespace BenefutureReference

/-- The reputation a vote earns once its decision's optimality is apparent (author rulings 8.29,
    8.48): ±`value` × the domain's scale × voters × the weight share it cast (its causal contribution
    to the decision). -/
def vote_reputation_ref (right : Bool) (value scale voters held total : Float) : Float :=
  (if right then 1.0 else -1.0) * value * scale * voters * held / total

/-- The delegate audit (L114): a delegate is passed over once its record holds at least
    `minRecords` apparent votes and the share right falls below `threshold`. -/
def audited_out_ref (rights records minRecords threshold : Float) : Bool :=
  records ≥ minRecords && rights / records < threshold

/-- A source's weight in deliberation (8.43, 8.44): log-odds of its record's accuracy over the rolling
    net of rights and wrongs, smoothed (Nitzan and Paroush, 1982); no better than chance, no weight. -/
def source_weight_ref (rights wrongs : Float) : Float :=
  let q := (rights + 1.0) / (rights + wrongs + 2.0)
  max 0.0 (Float.log (q / (1.0 - q)))

/-- Understanding trickles down and across (author ruling 8.44): a listener weighs a source only if
    the source's weight is at least its own, or, rarely, for novel input. -/
def heard_ref (source own : Float) (novel : Bool) : Float :=
  if source ≥ own || novel then source else 0.0

/-- Heard weights over many sources at once (8.44; the full ContentionMap, author on 8.45): each
    source at or above the listener's own weight counts in full; each weaker one at the novelty
    chance, the expected value of a rare novel input (a mean-field shortcut for a draw per source). -/
def heard_weights_ref (sources : Array Float) (own pNovel : Float) : Array Float :=
  sources.map fun s => if s ≥ own then s else pNovel * s

/-- The ledgers' negative share (8.42.1): losses over gains plus losses, over entries that never
    decay; zero for an empty ledger. -/
def neg_share_ref (gains losses : Float) : Float :=
  if gains + losses > 0.0 then max 0.0 (min 1.0 (losses / (gains + losses))) else 0.0

/-- One record's credence score (8.36): 1 − (credence − outcome)² / 0.25, unclipped; its mean over a
    window, floored at zero, is `credence_accuracy_ref`. -/
def credence_score_ref (credence outcome : Float) : Float :=
  1.0 - (credence - outcome) ^ 2 / 0.25

/-- Full support where predictions are scored (Chen, Kash, Ruberry & Shnayder 2014; 8.58-a): when
    predictions select which plans are carried out and only what is carried out is scored, a model
    can misreport unseen on the plans its predictions keep out. Given a uniform draw `u` in [0, 1),
    the governed exploration share and the `n` proposals not carried out, returns the 1-based index of
    the one carried out anyway, or 0 for none: each is explored with chance share / n. -/
def explore_pick_ref (u share : Float) (n : Nat) : Nat :=
  if n == 0 || !(u < share) then 0
  else min n ((u / share * n.toFloat).floor.toUInt64.toNat + 1)

/-- Identity binding (Technology Network): an identity is admitted as bound one-to-one to a distinct
    entity only when at least `quorum` clusters' binding confidences reach the governed threshold
    (methods from at least two clusters); a quorum of zero admits every identity (no binding). -/
def binding_admits_ref (confidences : Array Float) (threshold : Float) (quorum : Nat) : Bool :=
  (confidences.filter (fun c => c ≥ threshold)).size ≥ quorum

/-- Identity binding weighted by attestation record ([P], B2): an attestation is a choice scored
    like any other (8.69), so each cluster's say in the quorum is its attestation skill, clipped to
    [0, 1]: a cluster whose attested identities were revealed as sybils scores below its domain's
    model and loses its say. Admitted when the weights of the clusters reaching the threshold sum
    to `quorumWeight`. With every weight 1 it is `binding_admits_ref` at quorum `quorumWeight`. -/
def binding_admits_weighted_ref (confidences weights : Array Float) (threshold quorumWeight : Float) : Bool := Id.run do
  let n := min confidences.size weights.size
  let mut w := 0.0
  for i in [0:n] do
    if confidences[i]! ≥ threshold then w := w + max 0.0 (min 1.0 weights[i]!)
  return w ≥ quorumWeight

/-- Attestation skill read on each side ([P], B2): skill against a coin toss (`choice_skill_ref`
    with model credence 1/2) over the attestations of real entities and, separately, over those of
    false identities; the worse side counts. Pooled skill lets a cluster that vouches for everyone
    buy its say by being right about the easy majority while wrong on every sybil; read by side, it
    fails on the sybils. One side only: that side's skill. No attestations: 0. -/
def class_balanced_skill_ref (credences outcomes : Array Float) : Float := Id.run do
  let n := min credences.size outcomes.size
  let mut cp : Array Float := #[]
  let mut op : Array Float := #[]
  let mut cn : Array Float := #[]
  let mut on : Array Float := #[]
  for i in [0:n] do
    if outcomes[i]! == 1.0 then
      cp := cp.push credences[i]!; op := op.push 1.0
    else
      cn := cn.push credences[i]!; on := on.push 0.0
  let half (k : Nat) : Array Float := Array.mk (List.replicate k 0.5)
  let sp := choice_skill_ref cp (half cp.size) op
  let sn := choice_skill_ref cn (half cn.size) on
  if cp.size == 0 && cn.size == 0 then return 0.0
  if cp.size == 0 then return sn
  if cn.size == 0 then return sp
  return min sp sn

end BenefutureReference
