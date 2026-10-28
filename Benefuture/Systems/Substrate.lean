/-
  Benefuture.Systems.Substrate
  Formalization of the Behavioral Transaction Substrate (BTS), Transaction Trees (TxTree),
  and Causal Contribution (CC) / Causal Distribution (CD).
  Corresponds to: Bf_Pseudocode.txt L94-99, L145-147, and System Design.txt #BTS / Benefuture currency.txt
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Entity

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Ontology

/-- 
  Behavioral Transaction Log Entry (extends Thing):
  Every action in Reality produces an immutable transaction on the BTS.
-/
structure BehavioralTx extends Thing where
  actorId      : String
  actionId     : String
  timestamp    : Nat
  resourceUsed : Int
  outputImpact : Int
  deriving Repr, DecidableEq

/-- Coercion: Every BehavioralTx is canonically a Thing in Reality. -/
instance : Coe BehavioralTx Thing where
  coe tx := tx.toThing


/-- Helper constructor for BehavioralTx on the BTS. -/
def BehavioralTx.mkSimple (id actorId actionId : String) (t : Nat) (rc : Int) (impact : Int) : BehavioralTx :=
  { toThing := Thing.mkSimple id s!"tx_{id}" "bts_ledger" t,
    actorId := actorId, actionId := actionId, timestamp := t, resourceUsed := rc, outputImpact := impact }

/-- 
  Transaction Tree Node (TxTree, extends Thing):
  Tracks upstream dependency chains for Shapley-style value-added attribution.
  Net value added = OutputValue - UpstreamInputsConsumed.
  Corresponds to: Bf_Pseudocode.txt L94 ("TxTree").
-/
structure TxTreeNode extends Thing where
  entityId        : String
  receivedValue   : Int  -- Upstream value consumed
  producedValue   : Int  -- Downstream value emitted
  deriving Repr

instance : Coe TxTreeNode Thing where
  coe node := node.toThing


def TxTreeNode.mkSimple (id entityId : String) (received produced : Int) : TxTreeNode :=
  { toThing := Thing.mkSimple id s!"txtree_{entityId}" "bts_tree" 0,
    entityId := entityId, receivedValue := received, producedValue := produced }

/-- 
  Net Value Added by a node along the causal production chain.
  Ensures an entity is credited strictly for value added, not transaction volume!
-/
def net_value_added (node : TxTreeNode) : Int :=
  node.producedValue - node.receivedValue

/-- 
  Causal Contribution (CC) in micro-units [0, SCALE]:
  Quantifies an entity's proportional role in the ultimate outcome.
-/
def causal_contribution_ratio (node : TxTreeNode) (total_system_gain : Int) : Int :=
  if total_system_gain ≤ 0 then 0
  else
    let nva := net_value_added node
    if nva ≤ 0 then 0
    else (nva * SCALE) / total_system_gain

/-- 
  Causal Distribution (CD):
  Settles final rewards/penalties as a net adjustment over front-loaded escrow payments.
  CD = (ContributionScore * TotalOutcome) / SCALE - UpfrontEscrowPaid.
-/
def causal_distribution_settlement (cc_ratio : Int) (total_outcome : Int) (upfront_escrow_paid : Int) : Int :=
  ((cc_ratio * total_outcome) / SCALE) - upfront_escrow_paid

/-- 
  THEOREM: Value-Added Conservation (Anti-Intermediary Churn).
  A pure pass-through intermediary who consumes 100 units of value and emits 100 units of value
  has a net value added of exactly zero, receiving zero causal contribution credit.
  Volume padding is mathematically neutralized.
-/
theorem pure_intermediary_earns_zero_cc (v : Int) (total : Int) (_htot : total > 0) :
    let passThroughNode : TxTreeNode := TxTreeNode.mkSimple "node_mid" "Middleman" v v
    causal_contribution_ratio passThroughNode total = 0 := by
  dsimp [causal_contribution_ratio, net_value_added, TxTreeNode.mkSimple]
  have : v - v = 0 := by omega
  simp [this]

/-- 
  Upstream causal dependency link in the production DAG (extends Thing):
  Tracks backward attribution weight from a downstream breakthrough (e.g. Science invention)
  back to upstream enablers (e.g. Singer's music, Baker's bread, Farmer's wheat).
  Corresponds to: Bf_Pseudocode.txt L95.
-/
structure UpstreamLink extends Thing where
  ancestorId        : String
  attributionWeight : Int  -- Weight in micro-units [0, SCALE]
  h_wt_pos          : 0 < attributionWeight
  deriving Repr

instance : Coe UpstreamLink Thing where
  coe link := link.toThing


def UpstreamLink.mkSimple (id ancestorId : String) (weight : Int) 
    (h_pos : 0 < weight := by decide) : UpstreamLink :=
  { toThing := Thing.mkSimple id s!"link_{id}" "causal_lineage" 0,
    ancestorId := ancestorId, attributionWeight := weight, h_wt_pos := h_pos }

/-- Computes backward-propagated value attribution across a causal dependency link. -/
def compute_upstream_attribution (breakthroughValue : Int) (link : UpstreamLink) : Int :=
  (breakthroughValue * link.attributionWeight) / SCALE

/-- 
  THEOREM: Multi-Hop Upstream Causal Attribution Invariant (BTS / Shapley Lineage).
  When a downstream breakthrough of positive scale occurs (e.g. Scientist invents something),
  every upstream causal ancestor with positive attribution weight (Singer, Baker, Farmer)
  is guaranteed a strictly positive backward-propagated value attribution:
  Attribution(Ancestor) > 0.
-/
theorem upstream_ancestor_earns_positive_attribution 
    (breakthroughValue : Int) (link : UpstreamLink)
    (h_val : breakthroughValue ≥ SCALE) :
    compute_upstream_attribution breakthroughValue link > 0 := by
  unfold compute_upstream_attribution
  have h_scale_pos : (SCALE : Int) > 0 := by decide
  have h_diff : breakthroughValue - SCALE ≥ 0 := by omega
  have h_prod : (breakthroughValue - SCALE) * link.attributionWeight ≥ 0 := 
    Int.mul_nonneg h_diff (by have := link.h_wt_pos; omega)
  have h_expand : (breakthroughValue - SCALE) * link.attributionWeight = 
                  breakthroughValue * link.attributionWeight - SCALE * link.attributionWeight := 
    Int.sub_mul breakthroughValue SCALE link.attributionWeight
  have h_ge : breakthroughValue * link.attributionWeight ≥ SCALE * link.attributionWeight := by omega
  have h_div_ge : (breakthroughValue * link.attributionWeight) / SCALE ≥ 
                  (SCALE * link.attributionWeight) / SCALE := by
    apply Int.ediv_le_ediv h_scale_pos h_ge
  have h_cancel : (SCALE * link.attributionWeight) / SCALE = link.attributionWeight := by
    rw [Int.mul_comm]
    exact Int.mul_ediv_cancel link.attributionWeight (by decide)
  rw [h_cancel] at h_div_ge
  have := link.h_wt_pos
  omega

/-- 
  Ex-Post Windfall Settlement (The Potter's Bowl Invariant):
  Corresponds to: Life in benefuture.txt L132-166 & Bf_Pseudocode.txt ProbabilisticEscrow.
  When actual measured value in Reality (measuredValue) strictly exceeds the ex-ante 
  predicted value (predictedValue), the final settlement is NOT capped by prediction.
  1. The escrowed hold is released in full.
  2. Supplementary causal distribution (surplus = measuredValue - predictedValue) is minted 
     and distributed across the causal production tree.
-/
def calculate_ex_post_settlement (upfrontPaid escrowHold predictedValue measuredValue : Int) : Int :=
  if measuredValue > predictedValue then
    let surplus := measuredValue - predictedValue
    upfrontPaid + escrowHold + surplus
  else
    upfrontPaid + (escrowHold * measuredValue) / (if predictedValue > 0 then predictedValue else 1)

/-- 
  THEOREM: Ex-Post Windfall Surpasses Upfront Release.
  When measured outcomes strictly exceed ex-ante predictions, the total ex-post 
  settlement strictly exceeds the upfront payment and equals the full measured value:
  Settlement = Upfront + Hold + Surplus = MeasuredValue > Upfront.
  The probabilistic escrow operates as a conservative floor, never a ceiling.
-/
theorem windfall_settlement_equals_measured_value 
    (upfront hold pred meas : Int)
    (h_conserv : upfront + hold = pred)
    (h_surplus : meas > pred)
    (h_hold_pos : 0 < hold) :
    calculate_ex_post_settlement upfront hold pred meas = meas ∧
    calculate_ex_post_settlement upfront hold pred meas > upfront := by
  unfold calculate_ex_post_settlement
  have h_meas_gt : meas > pred := h_surplus
  simp [h_meas_gt]
  constructor
  · omega
  · omega

/-- 
  Causal Distribution (CD ∈ T):
  Corresponds to: Bf_Pseudocode.txt L96:
  "CausalDistribution«CD» := (Reward«Rw», Penalize) ∝ CC + N_CCtype - PE_paid | DisputeResolution(Justice«J»);"
  Settles final rewards/penalties as a net adjustment over front-loaded escrow payments.
-/
structure CausalDistribution extends Thing where
  entityId        : String
  causalScore     : Int
  noveltyBonus    : Int
  escrowPaid      : Int
  settlement      : Int
  isReward        : Bool  -- True for Reward (Rw), False for Penalize
  deriving Repr, DecidableEq

/-- Coercion: Every CausalDistribution record is canonically a Thing in Reality. -/
instance : Coe CausalDistribution Thing where
  coe cd := cd.toThing


/-- 
  Execution Lifecycle Record onExec(A) (extends Thing):
  Corresponds to: Bf_Pseudocode.txt L87-91:
  "onExec(A) :: { Trigger(A) ⇒ {TP_k} ← TP_Gen(A | Cx); TP* ← Compose(Actor ∈ {S ∨ E}, {TP_k}, Timeout | Default | Auto); Log(A,Cx | TP*,TP[]) };"
-/
structure ExecutionRecord extends Thing where
  actionId           : String
  contextDomain      : String
  selectedProposal   : String
  candidateProposals : List String
  isAutoSelected     : Bool
  deriving Repr, DecidableEq

/-- Coercion: Every ExecutionRecord is canonically a Thing in Reality. -/
instance : Coe ExecutionRecord Thing where
  coe er := er.toThing


/-- Standard onExec lifecycle constructor. -/
def on_exec (actionId : String) (dom : String) (selected : String) (candidates : List String) : ExecutionRecord :=
  { toThing := Thing.mkSimple s!"exec_{actionId}" s!"on_exec_{actionId}" dom 0,
    actionId := actionId, contextDomain := dom, selectedProposal := selected, candidateProposals := candidates, isAutoSelected := true }

abbrev CD := CausalDistribution
/--
  COUNTEREXAMPLE: CC by clamped value added over-distributes along a chain with a loss.
  A adds 10 (receives 0, produces 10), B adds 5 (receives 10, produces 15), C destroys 10 (receives
  15, produces 5); the measured outcome is 5. CC credits A 10 and B 5 and C nothing: 15 distributed
  for an outcome of 5, and C's loss is distributed to no one. Signed value added (produced −
  received) would telescope to the outcome exactly, but leaves L93's range [0, 1]. Resolved by the
  author's ruling (BACKPROPAGATION 8.14): credit follows the outcome's assessed parts, positive
  parts paying their contributors and negative parts penalising theirs, each side within [0, 1].
-/
theorem cc_clamped_overdistributes :
    let a := TxTreeNode.mkSimple "a" "A" 0 10
    let b := TxTreeNode.mkSimple "b" "B" 10 15
    let c := TxTreeNode.mkSimple "c" "C" 15 5
    let total : Int := 5
    causal_distribution_settlement (causal_contribution_ratio a total) total 0
      + causal_distribution_settlement (causal_contribution_ratio b total) total 0
      + causal_distribution_settlement (causal_contribution_ratio c total) total 0 = 15
    ∧ net_value_added a + net_value_added b + net_value_added c = total := by
  decide

abbrev CC := causal_contribution_ratio
abbrev BTS := BehavioralTx

end Benefuture.Systems

