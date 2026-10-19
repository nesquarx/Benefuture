/-
  Benefuture.Systems.Economy
  Formalization of Balance Overflow (BalOvflw), Directed Auto-Reinvestment,
  and Sophont Baseline Income (SB).
  Corresponds to: Bf_Pseudocode.txt L103, L143, and Benefuture currency.txt #Supply Stability
-/

import Benefuture.Economy.Currency
import Benefuture.Ontology.Thing

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Economy
open Benefuture.Measurement


/-- 
  Balance Overflow Rule:
  Prevents wealth concentration and hoarding-induced monetary contraction.
  If an entity's balance in currency C exceeds their accumulation threshold,
  the excess is automatically skimmed and redirected into productive domain reinvestment.
-/
structure BalanceOverflowConfig where
  accumulationThreshold : Int
  h_thresh_pos          : 0 < accumulationThreshold
  deriving Repr

/-- 
  Computes the balance deduction and auto-investment amount:
  If Bal > Threshold, Excess = Bal - Threshold.
  Post-balance is strictly capped at Threshold.
-/
def calculate_balance_overflow (current_balance : Int) (cfg : BalanceOverflowConfig) : (Int × Int) :=
  if current_balance > cfg.accumulationThreshold then
    let excess := current_balance - cfg.accumulationThreshold
    (cfg.accumulationThreshold, excess)  -- (new_balance, auto_invest_amount)
  else
    (current_balance, 0)

/-- 
  Public Domain Reinvestment Pool (extends Thing):
  Receives auto-reinvestment funds skimmed by Balance Overflow.
  Directs liquidity into Public Goods (Subgoals: Continuity, Diversity, Art, Freedom).
-/
structure DomainPublicPool extends Thing where
  domain       : Domain
  poolBalance  : Int
  deriving Repr

instance : Coe DomainPublicPool Thing where
  coe p := p.toThing


def DomainPublicPool.mkSimple (id : String) (dom : Domain) (bal : Int) : DomainPublicPool :=
  { toThing := Thing.mkSimple id s!"pool_{dom.name}" dom.name 0,
    domain := dom, poolBalance := bal }

/-- 
  Executes balance overflow transfer from an entity's private balance to the public domain pool:
  (new_private_balance, new_pool_state)
-/
def execute_overflow_reinvestment 
    (private_bal : Int) (pool : DomainPublicPool) (cfg : BalanceOverflowConfig) : (Int × DomainPublicPool) :=
  let res := calculate_balance_overflow private_bal cfg
  (res.1, { pool with poolBalance := pool.poolBalance + res.2 })

/-- 
  THEOREM: Zero-Leak Balance Overflow Conservation Law.
  Total systemic wealth (Private Liquid Balance + Public Domain Pool) is invariant 
  under balance overflow: private deduction strictly equals public reinvestment credit.
-/
theorem balance_overflow_conservation_law 
    (private_bal : Int) (pool : DomainPublicPool) (cfg : BalanceOverflowConfig) :
    let res := execute_overflow_reinvestment private_bal pool cfg
    res.1 + res.2.poolBalance = private_bal + pool.poolBalance := by
  unfold execute_overflow_reinvestment calculate_balance_overflow
  dsimp
  split
  · omega
  · omega


/-- 
  Sophont Baseline Income (SB ∈ T):
  Guarantees that essential survival and baseline flourishing goods (Maslow tiers 1, 2, 3:
  nutrition, healthcare, education, shelter) are priced at or below zero (price ≤ 0)
  for all persons living within their freedom boundary.
  Corresponds to: Bf_Pseudocode.txt L143.
-/
structure BaselineGood extends Thing where
  maslowTier   : Nat := 1  -- Maslow tiers 1, 2, 3: physiological, safety, belonging
  isEssential  : Bool := true
  nominalCost  : Int
  systemSubsidy: Int
  deriving Repr

instance : Coe BaselineGood Thing where
  coe bg := bg.toThing


def BaselineGood.mkSimple (id : String) (tier : Nat) (cost subsidy : Int) : BaselineGood :=
  { toThing := Thing.mkSimple id s!"baseline_good_{id}" "sustenance_infrastructure" 0,
    maslowTier := tier, isEssential := true, nominalCost := cost, systemSubsidy := subsidy }

/-- Effective price paid by a Person for a baseline good. -/
def effective_baseline_price (good : BaselineGood) : Int :=
  good.nominalCost - good.systemSubsidy

/-- 
  THEOREM: Balance Overflow Velocity Floor.
  Whenever an entity's balance exceeds their threshold, the excess is strictly positive 
  and immediately injected into reinvestment, ensuring currency velocity cannot drop to zero.
-/
theorem balance_overflow_activates_reinvestment 
    (bal : Int) (cfg : BalanceOverflowConfig) (h_excess : bal > cfg.accumulationThreshold) :
    (calculate_balance_overflow bal cfg).2 > 0 := by
  unfold calculate_balance_overflow
  split
  · simp
    omega
  · rename_i h
    contradiction

/-- 
  THEOREM: Sophont Baseline Guarantee.
  For any essential good where system subsidy matches or exceeds nominal resource cost,
  the net price to the consumer is guaranteed to be non-positive (price ≤ 0),
  ensuring universal unconditioned survival without debt.
-/
theorem essential_goods_guaranteed_floor (good : BaselineGood) 
    (h_sub : good.systemSubsidy ≥ good.nominalCost) :
    effective_baseline_price good ≤ 0 := by
  unfold effective_baseline_price
  omega

/-- 
  Sophont Baseline Income (SB ∈ T):
  Corresponds to: Bf_Pseudocode.txt L143:
  "S_BaselnIncm«SB»(C_i) := ∀Pe : ensure(maslow123) ← price_c(A → maslow123 | Fr) ≲ 0 ∨ Sig∃(C_i) via(RA);"
  Guarantees that essential survival and baseline flourishing goods are priced at or below zero.
-/
structure SophontBaselineIncome extends Thing where
  currencyId         : String
  guaranteedGoods    : List BaselineGood
  allGoodsSubsidized : ∀ g ∈ guaranteedGoods, g.systemSubsidy ≥ g.nominalCost
  deriving Repr

/-- Coercion: Every SophontBaselineIncome record is canonically a Thing in Reality. -/
instance : Coe SophontBaselineIncome Thing where
  coe sb := sb.toThing


/-- THEOREM: Guaranteed non-positive price for all essential goods under baseline income. -/
theorem baseline_income_guarantees_free_essentials (sb : SophontBaselineIncome) (g : BaselineGood) 
    (hg : g ∈ sb.guaranteedGoods) :
    effective_baseline_price g ≤ 0 :=
  essential_goods_guaranteed_floor g (sb.allGoodsSubsidized g hg)

abbrev S_BaselnIncm := SophontBaselineIncome
abbrev SB := SophontBaselineIncome
abbrev BalOvflw := calculate_balance_overflow

end Benefuture.Systems

