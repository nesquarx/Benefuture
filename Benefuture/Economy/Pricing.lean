/-
  Benefuture.Economy.Pricing
  [R] Transaction pricing with resource accounting, over ℝ.
  Corresponds to: Bf_Pseudocode.txt L82, L83, L84, L86, L99; Benefuture currency.txt (Resource
  Accounting, Pricing, supply).
  "C := {C_i} | C_i ↔ MM_j ∈ TopModels(MM_Acc>Th, Dn_i), compete(ΔV / (ΔResource«Rc» + Δt));"
  "RcAccounting«RA»(Transaction«Tx») := ↓Cost / Δ↑(U, H) - Audit ∧ ↓Usage{Rc, t};"
  "TP_Gen(A) :: … price_c = (MM_Me((Rc[], t[]) → A | RA) - MM_Pr(V ← A) + PE_hold);"
  "{CD(Bd) | J(Ha) iff Disputed ∨ RA(Rc, t)} → ⊖Bal(E) ∧ ⊖Supply, OncePer(Ha);"

  Infrastructure cost (MM compute, Technology Network bandwidth) is not a protocol fee. It is part of
  the resources an action consumes, priced at opportunity cost by the network's top MM, paid in the
  transaction price and burned from supply. Infrastructure providers are rewarded like any other
  contributor, through causal distribution (L96).
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Ring
import Mathlib.Algebra.Order.BigOperators.Group.List

namespace Benefuture.Economy

/--
  [R] Resources a transaction consumes (L83): physical quantities with their per-unit opportunity
  costs as valued by the network's top MM, plus compute, network and time
  (Benefuture currency.txt: "including network and compute usage").
-/
structure ResourceUse where
  physical : List (ℝ × ℝ)
  compute  : ℝ
  network  : ℝ
  time     : ℝ

/-- [R] Per-unit opportunity costs of compute, network and time in a currency network's domain. -/
structure ResourcePrices where
  computeCost : ℝ
  networkCost : ℝ
  timeCost    : ℝ

/-- [R] Opportunity cost of the resources consumed: MM_Me((Rc[], t[]) → A | RA) in L86. -/
noncomputable def resource_cost (r : ResourceUse) (pr : ResourcePrices) : ℝ :=
  (r.physical.map (fun x => x.1 * x.2)).sum + pr.computeCost * r.compute +
    pr.networkCost * r.network + pr.timeCost * r.time

/--
  [R] Transaction price (L86): resource cost − predicted value credit + escrow hold.
  `credit` is MM_Pr(V ← A) (the predicted causal-distribution credit); `pWin` is P(As(V) > 0).
  The hold is credit · (1 − P) (L84): only the confident part of the credit is paid up front.
-/
noncomputable def transaction_price (r : ResourceUse) (pr : ResourcePrices) (credit pWin : ℝ) : ℝ :=
  resource_cost r pr - credit + credit * (1 - pWin)

/-- THEOREM: The price is resource cost minus the upfront part of the credit, P · credit. -/
theorem transaction_price_eq (r : ResourceUse) (pr : ResourcePrices) (credit pWin : ℝ) :
    transaction_price r pr credit pWin = resource_cost r pr - pWin * credit := by
  unfold transaction_price
  ring

/--
  THEOREM: Infrastructure use is priced. More compute raises the price when compute has a positive
  opportunity cost; the same holds for network use.
-/
theorem price_strictly_increases_with_compute (r : ResourceUse) (pr : ResourcePrices)
    (credit pWin extra : ℝ) (hc : 0 < pr.computeCost) (hx : 0 < extra) :
    transaction_price r pr credit pWin <
      transaction_price { r with compute := r.compute + extra } pr credit pWin := by
  rw [transaction_price_eq, transaction_price_eq]
  unfold resource_cost
  dsimp only
  nlinarith [mul_pos hc hx]

theorem price_strictly_increases_with_network (r : ResourceUse) (pr : ResourcePrices)
    (credit pWin extra : ℝ) (hn : 0 < pr.networkCost) (hx : 0 < extra) :
    transaction_price r pr credit pWin <
      transaction_price { r with network := r.network + extra } pr credit pWin := by
  rw [transaction_price_eq, transaction_price_eq]
  unfold resource_cost
  dsimp only
  nlinarith [mul_pos hn hx]

/--
  THEOREM: An action the network cannot model (P = 0) pays its full resource cost
  (Benefuture currency.txt: credit "zero if it can't model", "full hold").
-/
theorem unmodelled_action_pays_resource_cost (r : ResourceUse) (pr : ResourcePrices) (credit : ℝ) :
    transaction_price r pr credit 0 = resource_cost r pr := by
  rw [transaction_price_eq]
  ring

/--
  THEOREM: When the confident predicted value exceeds resource cost, the price is negative:
  the system pays the transactor (Benefuture currency.txt).
-/
theorem price_negative_when_value_exceeds_cost (r : ResourceUse) (pr : ResourcePrices)
    (credit pWin : ℝ) (h : resource_cost r pr < pWin * credit) :
    transaction_price r pr credit pWin < 0 := by
  rw [transaction_price_eq]
  linarith

/--
  [R] Change in currency supply (L99; Benefuture currency.txt: "net measured Good minus resource
  consumption minus Harm"). There is no protocol term: nothing is minted for operators outside CD.
-/
def supply_delta (measuredGood resourceCost harmPenalty : ℝ) : ℝ :=
  measuredGood - resourceCost - harmPenalty

/-- THEOREM: Resource use with no measured good strictly shrinks supply (L99 ⊖Supply). -/
theorem resource_use_without_good_burns (cost harm : ℝ) (hc : 0 < cost) (hh : 0 ≤ harm) :
    supply_delta 0 cost harm < 0 := by
  unfold supply_delta
  linarith

/--
  [R] Currency competition efficiency (L82): ΔV / (ΔRc + Δt). Resource cost includes MM compute,
  so a compute-heavy model backing a currency lowers that currency's efficiency.
-/
noncomputable def competition_efficiency (dV resourceCost dt : ℝ) : ℝ :=
  dV / (resourceCost + dt)

/--
  THEOREM: For the same value delivered, a currency whose pricing consumes more resources
  (e.g. a more compute-heavy MM) is strictly less efficient, and loses competition (L82).
-/
theorem heavier_model_less_efficient (dV c₁ c₂ dt : ℝ) (hV : 0 < dV) (h₁ : 0 < c₁ + dt)
    (hc : c₁ < c₂) :
    competition_efficiency dV c₂ dt < competition_efficiency dV c₁ dt := by
  unfold competition_efficiency
  exact div_lt_div_of_pos_left hV h₁ (by linarith)

end Benefuture.Economy
