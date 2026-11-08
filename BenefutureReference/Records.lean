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

/-- An event's probability from an as-of record of `k` occurrences in `n` trials, smoothed by
    Laplace's rule of succession ((k + 1) / (n + 2)): no record gives a coin toss, and no finite record
    gives certainty (8.33). Used by the decision replay (8.87) to price options' scenarios. -/
def event_rate_ref (k n : Float) : Float := (k + 1.0) / (n + 2.0)

/-- Sources' probabilities for one event pooled by their record weights (`source_weight_ref`); with no
    weight anywhere, the plain mean. -/
def pooled_probability_ref (probs weights : Array Float) : Float := Id.run do
  let n := min probs.size weights.size
  if n == 0 then return 0.5
  let mut sw := 0.0
  let mut sp := 0.0
  for i in [0:n] do
    sw := sw + weights[i]!
    sp := sp + weights[i]! * probs[i]!
  if sw ≤ 0.0 then return (probs.foldl (· + ·) 0.0) / n.toFloat
  return sp / sw

/-- An option's expected effect over its scenarios: Σ probability × effect. -/
def expected_effect_ref (probs effects : Array Float) : Float := Id.run do
  let mut e := 0.0
  for i in [0:min probs.size effects.size] do
    e := e + probs[i]! * effects[i]!
  return e

/-- Strong per-being reading over the long-term projection, with understanding offsetting happiness
    (author ruling 8.116). `du`, `dh`: a being's (or group's) change against inaction; projected long
    term, happiness adapts (× `retention`) and understanding compounds (× `compounding`). An
    understanding loss is never offset. A happiness loss is admissible if the projected understanding
    gain covers it with a premium that grows with its size (need = loss × (1 + relative loss /
    `offset_scale`)), and only while the relative loss (over the baseline `base_h`) stays within the
    soft bar `soft_bar`, unless the drop is necessary harm (`nha`). -/
def lt_offset_admissible_ref (du dh base_h : Float) (nha : Bool) (retention compounding offset_scale soft_bar : Float) : Bool :=
  let duL := du * compounding
  let dhL := dh * retention
  if duL < -1e-9 then false
  else if dhL >= -1e-9 then true
  else
    let loss := -dhL
    let rel := if base_h > 0.0 then loss / base_h else loss
    if rel > soft_bar && !nha then false
    else duL >= loss * (1.0 + rel / offset_scale)

/-- Irreparable harm in death-equivalents (author, on 8.124 and 8.126): a group's expected deaths plus the generational
    share of its long-term understanding loss (never regained, or too late for later synergistic breakthroughs:
    the loss × compounding × `persistence`; a recoverable loss is not irreparable), counted as the share of a life's understanding and happiness it
    takes (a death takes both to zero), over the group's population (`pop` in irreparable units). -/
def irreparable_equivalent_ref (deaths du pop base_u base_h compounding persistence : Float) : Float :=
  let loss := if du < 0.0 then -du * compounding * persistence else 0.0
  let life := base_u + base_h
  deaths + (if life > 0.0 then pop * loss / life else 0.0)

/-- Policy-level irreparable harm (author ruling 8.124): among a decision's options, one whose expected
    irreparable harm (aggregate, net of survival it adds elsewhere) exceeds the least such harm by more than
    `tol` is blocked, unless the excess is necessary harm. Individual risk-taking stays under the per-being
    freedom gate. -/
def irreparable_blocked_ref (harm least tol : Float) (nha : Bool) : Bool :=
  harm > least + tol && !nha

/-- A confidence ballot's weight (LqCfdBfDm, author ruling 8.121): the voter's weight × the calibration of its
    confidence record (PrAcc of its past confidences, as a slope in [0, 2]) × its stated log-odds, capped at
    ±`cap`. Stated confidence counts only as far as it has proved calibrated. -/
def cfd_ballot_weight_ref (vw calibration logodds cap : Float) : Float :=
  let l := if logodds > cap then cap else if logodds < -cap then -cap else logodds
  let c := if calibration < 0.0 then 0.0 else if calibration > 2.0 then 2.0 else calibration
  vw * c * l

/-- Environmental health harm (author ruling 8.118): an option, inaction included, is blocked when its
    projected health harm through environmental pathways exceeds the least such harm among the options
    available by more than `tol`, unless that excess is necessary harm. -/
def env_health_blocked_ref (harm least tol : Float) (nha : Bool) : Bool :=
  harm > least + tol && !nha

/-- Measurement chains (8.107): the dependency graph of readings must be acyclic. `adj` is an n × n
    row-major matrix, `adj[i*n+j] > 0` meaning reading i takes reading j as input. Kahn's algorithm:
    true when every node can be removed in some order with no remaining inputs. -/
def acyclic_ref (adj : Array Float) (n : Nat) : Bool := Id.run do
  let mut indeg : Array Nat := Array.replicate n 0
  for i in [0:n] do
    for j in [0:n] do
      if adj[i * n + j]! > 0.0 then indeg := indeg.set! i (indeg[i]! + 1)
  let mut removed : Array Bool := Array.replicate n false
  let mut count := 0
  for _ in [0:n] do
    let mut found := n
    for k in [0:n] do
      if found == n && !removed[k]! && indeg[k]! == 0 then found := k
    if found == n then break
    removed := removed.set! found true
    count := count + 1
    for i in [0:n] do
      if adj[i * n + found]! > 0.0 then indeg := indeg.set! i (indeg[i]! - 1)
  return count == n

/-- Overlap-discounted pooling of readings of one quantity (8.107): each reading's credence is divided
    by its total marker overlap with all readings (`overlap` row-major n × n, diagonal 1), so readings
    that share their markers count once between them. Returns [pooled value, total effective credence]. -/
def pooled_reading_ref (values credences overlap : Array Float) : Array Float := Id.run do
  let n := min values.size credences.size
  let mut num := 0.0
  let mut den := 0.0
  for i in [0:n] do
    let mut o := 0.0
    for j in [0:n] do
      o := o + overlap[i * n + j]!
    let w := if o > 0.0 then credences[i]! / o else 0.0
    num := num + w * values[i]!
    den := den + w
  return #[if den > 0.0 then num / den else 0.0, den]

/-- Divergence between chains (8.107): true when some pair of readings differs by more than `z`
    combined standard errors; an automatic audit trigger, and reportable under AdvAp. -/
def chains_diverge_ref (values ses : Array Float) (z : Float) : Bool := Id.run do
  let n := min values.size ses.size
  let mut d := false
  for i in [0:n] do
    for j in [i+1:n] do
      let se := Float.sqrt (ses[i]! ^ 2 + ses[j]! ^ 2)
      if se > 0.0 && Float.abs (values[i]! - values[j]!) / se > z then d := true
  return d

/-- Prediction accuracy net of irreducible uncertainty (author ruling 8.103, on 8.102), for an item whose
    outcomes share one probability: 1 − (Brier − ō(1−ō)) / 0.25, clamped to [0, 1]. The Brier score less
    the record's uncertainty term (Murphy 1973) leaves the forecaster's own error, so exact knowledge of a
    fair coin scores 1 rather than 0. Raw accuracy (`credence_accuracy_ref`) still backs currency. -/
def relative_accuracy_ref (credences outcomes : Array Float) : Float := Id.run do
  let n := min credences.size outcomes.size
  if n == 0 then return 0.0
  let mut b := 0.0
  let mut o := 0.0
  for i in [0:n] do
    b := b + (credences[i]! - outcomes[i]!) ^ 2
    o := o + outcomes[i]!
  let nf := n.toFloat
  let ob := o / nf
  let r := 1.0 - (b / nf - ob * (1.0 - ob)) / 0.25
  return if r < 0.0 then 0.0 else if r > 1.0 then 1.0 else r

/-- Pragmatic understanding of a thing by a model (L31; proposal 8.98): the model's map fit to the thing
    times the weighted mean, over the situations and outcomes that matter, of causal explanation ×
    prediction accuracy × (1 − complexity). Weights are P(X|T)·P(i|T,X)·Impact(i); items below the
    significance threshold `th` are left out. No item at or above it: no understanding (0). -/
def pragmatic_understanding_ref (mapFit : Float) (wt ce acc cy : Array Float) (th : Float) : Float := Id.run do
  let n := min (min wt.size ce.size) (min acc.size cy.size)
  let mut num := 0.0
  let mut den := 0.0
  for i in [0:n] do
    if wt[i]! ≥ th then
      num := num + wt[i]! * ce[i]! * acc[i]! * (1.0 - cy[i]!)
      den := den + wt[i]!
  return if den > 0.0 then mapFit * num / den else 0.0

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

/-- Repeated deception (author 8.91 and its addendum). `significance` holds, per audit interval
    (oldest first), the actor's overstatement in standard errors (t-inflated): the mean of its signed
    errors, quoted minus measured, over their standard error. An interval is deceptive only if that
    exceeds `z`; the persistence is the number of consecutive trailing deceptive intervals, so any
    non-deceptive interval resets it to 0. -/
def persistence_ref (significance : Array Float) (z : Float) : Nat := Id.run do
  let mut n := 0
  for i in [0:significance.size] do
    if significance[significance.size - 1 - i]! > z then n := n + 1 else break
  return n

/-- Escalating ratchet: `ratchet_credence_ref` with the distance from a coin toss shrunk by a further
    factor `(1 + growth)` per persistent interval, persistence capped so the factor is at most
    `cap` (`log cap / log (1 + growth)` intervals). With persistence 0 it is `ratchet_credence_ref`.
    The credence only approaches 0.5, never crosses it, and it screens nobody out. -/
def escalated_credence_ref (credence negShare : Float) (persistence : Nat) (growth cap : Float) : Float :=
  let maxP := Float.log cap / Float.log (1.0 + growth)
  let p := min persistence.toFloat maxP
  0.5 + (credence - 0.5) * (1.0 - negShare) * (1.0 + growth) ^ (-p)

/-- Repeated discovered deception (author ruling on 8.91, 2026-11-06): each deception established by an
    audit adds to the actor's permanent deception record, and escrow rises exponentially with the count:
    the upfront credence is the ledger ratchet's (`ratchet_credence_ref`) times (1 + growth)^(-repeats),
    floored at `floorC` (never zero: the actor is not excluded, and settlement still pays what it delivers).
    Only established deception counts, so bad luck and honest mistakes never raise it. -/
def repeat_escrow_credence_ref (credence negShare : Float) (repeats : Nat) (growth floorC : Float) : Float :=
  max floorC ((0.5 + (credence - 0.5) * (1.0 - negShare)) * Float.pow (1.0 + growth) (-(repeats.toFloat)))

/-- Undeclared copying (8.111; correlated ballots, 8.121): two independent sources' standardised differences have
  variance near the sum of their noise variances (about 1 or 2 by construction); a pair whose standardised
  differences, over at least `minN` readings, have variance below `below` is one source counted twice. -/
def copies_ref (diffs : Array Float) (minN : Nat) (below : Float) : Bool := Id.run do
  let n := diffs.size
  if n < minN || n < 2 then return false
  let mean := diffs.foldl (· + ·) 0.0 / n.toFloat
  let ss := diffs.foldl (fun a x => a + (x - mean) * (x - mean)) 0.0
  return ss / (n.toFloat - 1.0) < below

end BenefutureReference
