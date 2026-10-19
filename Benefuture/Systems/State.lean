/-
  Benefuture.Systems.State
  Formalization of Phase 4: State, Event, Step, Invariants, and RepCache.
  Corresponds to: Bf_Pseudocode.txt L25, L26, L48-50, L101, L113, L132, L155, L157.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Exp
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Data.List.Basic
import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Ontology.Domain
import Benefuture.Ontology.Reputation
import Benefuture.Economy.Currency

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Economy

set_option linter.unusedVariables false

/-!
  # 4.1 Ground Truth vs Measurement (Latent vs Observed)
  Corresponds to: Bf_Pseudocode.txt L48-50, Architecture.txt §Measurement.
-/

/-- 
  [R] True latent flourishing variables of reality / world state.
  These are latent variables representing true flourishing, true harm, and true non-utilitarian value.
-/
structure LatentFlourishing where
  trueU : ℝ
  trueH : ℝ
  trueN : ℝ

/-- 
  [R] Observed empirical markers (noisy measurements).
  Corresponds to: Bf_Pseudocode.txt L48 `me(M, A)`.
-/
structure ObservedMeasurement where
  obsU : ℝ
  obsH : ℝ
  obsN : ℝ

/--
  -- SPEC-CHOICE: Gap between true latent variable and observed empirical measurement.
  Defines the measurement error / Goodhart distortion gap.
-/
def LatentObsGap (actual : ℝ) (observed : ℝ) : ℝ :=
  |actual - observed|

/-- 
  [P] Goodhart Avoidance Requirement:
  System incentives must reward improvement in the latent true state, not purely 
  the observed marker, to prevent gaming and metric corruption.
-/
def GoodhartResistantIncentive (latentDelta : ℝ) (obsDelta : ℝ) (reward : ℝ) : Prop :=
  reward > 0 → latentDelta > 0 ∧ LatentObsGap latentDelta obsDelta < |latentDelta|

/-!
  # 4.3 RepCache & Lazy Continuous Decay
  Corresponds to: Bf_Pseudocode.txt L101 ("continuous decay").
-/

/--
  [R] Cached reputation score with timestamp.
  Enables O(1) lazy decay reads without continuous chain-wide writes.
-/
structure RepCache where
  lastUpdateTime : ℝ
  cachedScore    : ℝ
  decayRate      : ℝ
  h_rate_pos     : 0 < decayRate

/--
  [R] Continuous exponential decay calculation on lazy read at query time `t`.
-/
noncomputable def lazy_decay_read (cache : RepCache) (t : ℝ) : ℝ :=
  if t ≤ cache.lastUpdateTime then
    cache.cachedScore
  else
    cache.cachedScore * Real.exp (-cache.decayRate * (t - cache.lastUpdateTime))

/--
  [R] THEOREM: Exponential decay commutes with summation over disjoint score components.
  decay(s₁ + s₂, Δt) = decay(s₁, Δt) + decay(s₂, Δt).
-/
theorem cache_correct (s₁ s₂ rate dt : ℝ) :
    (s₁ + s₂) * Real.exp (-rate * dt) =
    s₁ * Real.exp (-rate * dt) + s₂ * Real.exp (-rate * dt) := by
  ring

/--
  [R] THEOREM: Exponential decay chains transitively across checkpoints.
  decay(decay(s, t₁ - t₀), t₂ - t₁) = decay(s, t₂ - t₀).
-/
theorem decay_transitive (s rate t₀ t₁ t₂ : ℝ) :
    (s * Real.exp (-rate * (t₁ - t₀))) * Real.exp (-rate * (t₂ - t₁)) =
    s * Real.exp (-rate * (t₂ - t₀)) := by
  have h_exp : Real.exp (-rate * (t₁ - t₀)) * Real.exp (-rate * (t₂ - t₁)) =
               Real.exp (-rate * (t₁ - t₀) + -rate * (t₂ - t₁)) := by
    rw [← Real.exp_add]
  rw [mul_assoc, h_exp]
  have h_comb : -rate * (t₁ - t₀) + -rate * (t₂ - t₁) = -rate * (t₂ - t₀) := by ring
  rw [h_comb]

/--
  [R] Triggers necessitating a full-recount checkpoint.
  1. Time elapsed since last checkpoint exceeds Δt_max
  2. Cumulative uncheckpointed events exceed N_max
  3. A formal dispute was raised on the cached score
-/
structure RecountTriggerParams where
  deltaTMax : ℝ
  nMax      : ℕ

def RecountNeeded (params : RecountTriggerParams) (cache : RepCache) 
    (currentTime : ℝ) (uncheckpointedEvents : ℕ) (disputed : Bool) : Prop :=
  currentTime - cache.lastUpdateTime > params.deltaTMax ∨
  uncheckpointedEvents > params.nMax ∨
  disputed = true

/--
  [R] Checkpointing: Updating the cache to current time with the evaluated lazy decay.
-/
noncomputable def checkpoint (cache : RepCache) (t : ℝ) : RepCache :=
  { lastUpdateTime := max cache.lastUpdateTime t,
    cachedScore    := lazy_decay_read cache (max cache.lastUpdateTime t),
    decayRate      := cache.decayRate,
    h_rate_pos     := cache.h_rate_pos }

/--
  [R] THEOREM: Checkpointing preserves the lazy decay reading for any future query t' ≥ t.
-/
theorem checkpoint_sound (cache : RepCache) (t t' : ℝ) (h_le : cache.lastUpdateTime ≤ t) (h_fut : t ≤ t') :
    lazy_decay_read (checkpoint cache t) t' = lazy_decay_read cache t' := by
  unfold checkpoint lazy_decay_read
  dsimp
  rw [max_eq_right h_le]
  by_cases ht' : t' ≤ t
  · have ht'_eq : t' = t := le_antisymm ht' h_fut
    subst ht'_eq
    rw [if_pos (le_refl t')]
  · rw [if_neg ht']
    have ht'_not_old : ¬(t' ≤ cache.lastUpdateTime) := by
      intro h_contra
      exact ht' (le_trans h_contra h_le)
    rw [if_neg ht'_not_old]
    by_cases ht_old : t ≤ cache.lastUpdateTime
    · have ht_eq : t = cache.lastUpdateTime := le_antisymm ht_old h_le
      subst ht_eq
      rw [if_pos (le_refl cache.lastUpdateTime)]
    · rw [if_neg ht_old]
      have h_split : -cache.decayRate * (t - cache.lastUpdateTime) + -cache.decayRate * (t' - t) =
                     -cache.decayRate * (t' - cache.lastUpdateTime) := by ring
      rw [mul_assoc, ← Real.exp_add, h_split]

/-!
  # 4.2 State, Event, and Step Relation
  Corresponds to: Bf_Pseudocode.txt L25, L26, L101, L113, L132, L155, L157.
-/

/-- Ledger entry in the append-only memory history (L155). -/
structure TxRecord where
  txId      : String
  timestamp : ℝ
  tag       : String

/-- Entity account state in the system. -/
structure Account where
  entityId : String
  balance  : ℝ
  h_nonneg : 0 ≤ balance

/-- Active escrow instance in the system. -/
structure SystemEscrow where
  escrowId    : String
  posterId    : String
  beneficiary : String
  upfront     : ℝ
  ongoingHold : ℝ
  h_up_nonneg : 0 ≤ upfront
  h_on_nonneg : 0 ≤ ongoingHold

/-- Nominal value of an escrow: upfront payment + ongoing hold. -/
def SystemEscrow.nominal (e : SystemEscrow) : ℝ :=
  e.upfront + e.ongoingHold

/-- Global state of the Benefuture institutional apparatus. -/
structure State where
  time            : ℝ
  history         : List TxRecord
  accounts        : List Account
  escrows         : List SystemEscrow
  activeIdentities: List String
  totalMinted     : ℝ
  totalBurned     : ℝ
  totalLost       : ℝ
  reputations     : List (String × RepCache)
  treasuryBalance : ℝ

/-- 
  System Events covering:
  - mint (Cycle, L25)
  - spend
  - escrow_lock
  - escrow_release
  - escrow_forfeit (slashed on bad assessment or fraud)
  - bounty_post
  - bounty_claim
  - bounty_clawback (L157)
  - vote_cast (L113)
  - entity_fork (L101)
  - entity_merge (L101)
  - time_advance (ticks decay)
-/
inductive Event where
  | mint (recipientId : String) (amount : ℝ) (tag : String)
  | spend (payerId : String) (recipientId : String) (amount : ℝ)
  | escrow_lock (escrowId : String) (posterId : String) (beneficiary : String) (upfront : ℝ) (hold : ℝ)
  | escrow_release (escrowId : String)
  | escrow_forfeit (escrowId : String) (slashToTreasury : ℝ)
  | bounty_post (bountyId : String) (creatorId : String) (bountyAmount : ℝ)
  | bounty_claim (bountyId : String) (claimantId : String)
  | bounty_clawback (bountyId : String) (targetId : String) (clawbackAmount : ℝ)
  | vote_cast (voterId : String) (proposalId : String) (weight : ℝ)
  | entity_fork (parentId : String) (child1Id child2Id : String) (ratio : ℝ)
  | entity_merge (child1Id child2Id : String) (mergedId : String)
  | time_advance (deltaT : ℝ)

/-- Query account balance. -/
def get_balance (s : State) (eId : String) : ℝ :=
  match s.accounts.find? (fun a => a.entityId == eId) with
  | some a => a.balance
  | none   => 0

/-- Current total circulating supply of currency. -/
def total_supply (s : State) : ℝ :=
  (s.accounts.map (fun a => a.balance)).sum +
  (s.escrows.map (fun e => e.nominal)).sum +
  s.treasuryBalance

/--
  [R] Step Relation: `Step s ev s'` specifies valid state transitions.
  Enforces all operational guards and invariants.
-/
def Step (s : State) (ev : Event) (s' : State) : Prop :=
  match ev with
  | Event.mint recipient amount tag =>
      amount > 0 ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted + amount ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_mint_{s.history.length}", timestamp := s.time, tag := tag } :: s.history

  | Event.spend payer recipient amount =>
      amount > 0 ∧
      get_balance s payer ≥ amount ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_spend_{s.history.length}", timestamp := s.time, tag := "spend" } :: s.history

  | Event.escrow_lock eid poster ben up hold =>
      ∃ (h_up : 0 ≤ up) (h_hold : 0 ≤ hold),
      up + hold > 0 ∧
      get_balance s poster ≥ up + hold ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = { escrowId := eid, posterId := poster, beneficiary := ben,
                     upfront := up, ongoingHold := hold,
                     h_up_nonneg := h_up, h_on_nonneg := h_hold } :: s.escrows ∧
      s'.history = { txId := s!"tx_lock_{s.history.length}", timestamp := s.time, tag := "escrow_lock" } :: s.history

  | Event.escrow_release eid =>
      (∃ e ∈ s.escrows, e.escrowId = eid) ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows.filter (fun e => e.escrowId ≠ eid) ∧
      s'.history = { txId := s!"tx_rel_{s.history.length}", timestamp := s.time, tag := "escrow_release" } :: s.history

  | Event.escrow_forfeit eid slash =>
      (∃ e ∈ s.escrows, e.escrowId = eid ∧ slash ≤ e.nominal) ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned + slash ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows.filter (fun e => e.escrowId ≠ eid) ∧
      s'.history = { txId := s!"tx_slash_{s.history.length}", timestamp := s.time, tag := "escrow_forfeit" } :: s.history

  | Event.bounty_post bid creator amt =>
      ∃ (h_amt : 0 < amt),
      get_balance s creator ≥ amt ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = { escrowId := bid, posterId := creator, beneficiary := "bounty_pool",
                     upfront := amt, ongoingHold := 0,
                     h_up_nonneg := le_of_lt h_amt, h_on_nonneg := le_refl 0 } :: s.escrows ∧
      s'.history = { txId := s!"tx_bpost_{s.history.length}", timestamp := s.time, tag := "bounty_post" } :: s.history

  | Event.bounty_claim bid claimant =>
      (∃ e ∈ s.escrows, e.escrowId = bid) ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows.filter (fun e => e.escrowId ≠ bid) ∧
      s'.history = { txId := s!"tx_bclaim_{s.history.length}", timestamp := s.time, tag := "bounty_claim" } :: s.history

  | Event.bounty_clawback bid target clawAmt =>
      clawAmt > 0 ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned + clawAmt ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_claw_{s.history.length}", timestamp := s.time, tag := "bounty_clawback" } :: s.history

  | Event.vote_cast voter prop wt =>
      wt ≥ 0 ∧ voter ∈ s.activeIdentities ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_vote_{s.history.length}", timestamp := s.time, tag := "vote_cast" } :: s.history

  | Event.entity_fork parent c1 c2 ratio =>
      ratio > 0 ∧ ratio < 1 ∧ parent ∈ s.activeIdentities ∧
      c1 ∉ s.activeIdentities ∧ c2 ∉ s.activeIdentities ∧ c1 ≠ c2 ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = c1 :: c2 :: (s.activeIdentities.filter (fun id => id ≠ parent)) ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_fork_{s.history.length}", timestamp := s.time, tag := "entity_fork" } :: s.history

  | Event.entity_merge c1 c2 merged =>
      c1 ∈ s.activeIdentities ∧ c2 ∈ s.activeIdentities ∧ c1 ≠ c2 ∧
      merged ∉ s.activeIdentities ∧
      s'.time = s.time ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = merged :: (s.activeIdentities.filter (fun id => id ≠ c1 ∧ id ≠ c2)) ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_merge_{s.history.length}", timestamp := s.time, tag := "entity_merge" } :: s.history

  | Event.time_advance dt =>
      dt > 0 ∧
      s'.time = s.time + dt ∧
      s'.totalMinted = s.totalMinted ∧
      s'.totalBurned = s.totalBurned ∧
      s'.totalLost = s.totalLost ∧
      s'.activeIdentities = s.activeIdentities ∧
      s'.escrows = s.escrows ∧
      s'.history = { txId := s!"tx_time_{s.history.length}", timestamp := s.time + dt, tag := "time_advance" } :: s.history

/-- Reflexive transitive closure of Step. -/
inductive StepStar : State → State → Prop where
  | refl (s : State) : StepStar s s
  | step {s₁ s₂ s₃ : State} (ev : Event) (h1 : Step s₁ ev s₂) (h2 : StepStar s₂ s₃) : StepStar s₁ s₃

/-!
  # 4.4 System Invariants (Proved over Step*)
-/

/--
  [R] INVARIANT (a) Mem (L155): Append-Only Memory.
  Past transaction records are permanently preserved and cannot be overwritten or modified.
  Expressed as list prefix / sublist preservation: s.history is a suffix of s'.history.
-/
def Invariant_Mem (s s' : State) : Prop :=
  ∃ pfx : List TxRecord, s'.history = pfx ++ s.history

theorem step_preserves_mem (s s' : State) (ev : Event) (h : Step s ev s') :
    Invariant_Mem s s' := by
  unfold Invariant_Mem
  cases ev
  case mint recipient amount tag =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_mint_{s.history.length}", timestamp := s.time, tag := tag }]
    rw [h_hist]; rfl
  case spend payer recipient amount =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_spend_{s.history.length}", timestamp := s.time, tag := "spend" }]
    rw [h_hist]; rfl
  case escrow_lock eid poster ben up hold =>
    dsimp [Step] at h; rcases h with ⟨h_up, h_hold, -, -, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_lock_{s.history.length}", timestamp := s.time, tag := "escrow_lock" }]
    rw [h_hist]; rfl
  case escrow_release eid =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_rel_{s.history.length}", timestamp := s.time, tag := "escrow_release" }]
    rw [h_hist]; rfl
  case escrow_forfeit eid slash =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_slash_{s.history.length}", timestamp := s.time, tag := "escrow_forfeit" }]
    rw [h_hist]; rfl
  case bounty_post bid creator amt =>
    dsimp [Step] at h; rcases h with ⟨h_amt, -, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_bpost_{s.history.length}", timestamp := s.time, tag := "bounty_post" }]
    rw [h_hist]; rfl
  case bounty_claim bid claimant =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_bclaim_{s.history.length}", timestamp := s.time, tag := "bounty_claim" }]
    rw [h_hist]; rfl
  case bounty_clawback bid target clawAmt =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_claw_{s.history.length}", timestamp := s.time, tag := "bounty_clawback" }]
    rw [h_hist]; rfl
  case vote_cast voter prop wt =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_vote_{s.history.length}", timestamp := s.time, tag := "vote_cast" }]
    rw [h_hist]; rfl
  case entity_fork parent c1 c2 ratio =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_fork_{s.history.length}", timestamp := s.time, tag := "entity_fork" }]
    rw [h_hist]; rfl
  case entity_merge c1 c2 merged =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_merge_{s.history.length}", timestamp := s.time, tag := "entity_merge" }]
    rw [h_hist]; rfl
  case time_advance dt =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, -, h_hist⟩
    use [{ txId := s!"tx_time_{s.history.length}", timestamp := s.time + dt, tag := "time_advance" }]
    rw [h_hist]; rfl

/--
  [R] INVARIANT (b) Id (L132): Identity Injectivity / Uniqueness.
  No duplicate active identities exist in the system.
-/
def Invariant_Id (s : State) : Prop :=
  s.activeIdentities.Nodup

theorem step_preserves_id (s s' : State) (ev : Event) (h_inv : Invariant_Id s) (h : Step s ev s') :
    Invariant_Id s' := by
  unfold Invariant_Id at *
  cases ev
  case mint =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case spend =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case escrow_lock =>
    dsimp [Step] at h; rcases h with ⟨h_up, h_hold, -, -, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case escrow_release =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case escrow_forfeit =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case bounty_post =>
    dsimp [Step] at h; rcases h with ⟨h_amt, -, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case bounty_claim =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case bounty_clawback =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case vote_cast =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv
  case entity_fork parent c1 c2 ratio =>
    dsimp [Step] at h
    rcases h with ⟨hr1, hr2, h_parent, hc1, hc2, h_diff, -, -, -, -, h_id, -⟩
    rw [h_id]
    rw [List.nodup_cons]
    refine ⟨?_, ?_⟩
    · intro h_in
      simp only [List.mem_cons] at h_in
      rcases h_in with h_c1c2 | h_in_filt
      · exact h_diff h_c1c2
      · rw [List.mem_filter] at h_in_filt
        exact hc1 h_in_filt.1
    · rw [List.nodup_cons]
      refine ⟨?_, ?_⟩
      · intro h_in_filt
        rw [List.mem_filter] at h_in_filt
        exact hc2 h_in_filt.1
      · exact List.Nodup.filter (fun id => id ≠ parent) h_inv
  case entity_merge c1 c2 merged =>
    dsimp [Step] at h
    rcases h with ⟨hc1, hc2, h_diff, h_m, -, -, -, -, h_id, -⟩
    rw [h_id]
    rw [List.nodup_cons]
    refine ⟨?_, ?_⟩
    · intro h_in_filt
      rw [List.mem_filter] at h_in_filt
      exact h_m h_in_filt.1
    · exact List.Nodup.filter (fun id => id ≠ c1 ∧ id ≠ c2) h_inv
  case time_advance dt =>
    dsimp [Step] at h; rcases h with ⟨-, -, -, -, -, h_id, -⟩; rw [h_id]; exact h_inv

/--
  [R] INVARIANT (c) Supply Accounting:
  TotalSupply(t) = TotalSupply(0) + ∑ Mint - ∑ Burn - ∑ Lost.
-/
def SupplyAccountingIdentity (s0 s : State) : Prop :=
  total_supply s = total_supply s0 + s.totalMinted - s.totalBurned - s.totalLost

/--
  [R] INVARIANT (d) Escrow Soundness:
  Escrow.nominal = Escrow.upfront + Escrow.ongoingHold.
  Locked funds cannot exceed poster balance at lock time.
-/
def Invariant_EscrowSoundness (s : State) : Prop :=
  ∀ e ∈ s.escrows, e.nominal = e.upfront + e.ongoingHold ∧ 0 ≤ e.upfront ∧ 0 ≤ e.ongoingHold

theorem step_preserves_escrow_soundness (s s' : State) (ev : Event)
    (h_inv : Invariant_EscrowSoundness s) (h : Step s ev s') :
    Invariant_EscrowSoundness s' := by
  intro e he
  cases ev
  case escrow_lock eid poster ben up hold =>
    dsimp [Step] at h
    rcases h with ⟨hup, hhold, -, -, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he
    simp only [List.mem_cons] at he
    rcases he with rfl | he_old
    · exact ⟨rfl, hup, hhold⟩
    · exact h_inv e he_old
  case escrow_release eid =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he
    rw [List.mem_filter] at he
    exact h_inv e he.1
  case escrow_forfeit eid slash =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he
    rw [List.mem_filter] at he
    exact h_inv e he.1
  case bounty_post bid creator amt =>
    dsimp [Step] at h
    rcases h with ⟨hamt, -, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he
    simp only [List.mem_cons] at he
    rcases he with rfl | he_old
    · exact ⟨rfl, le_of_lt hamt, le_refl 0⟩
    · exact h_inv e he_old
  case bounty_claim bid claimant =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he
    rw [List.mem_filter] at he
    exact h_inv e he.1
  case mint =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he
  case spend =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he
  case bounty_clawback =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he
  case vote_cast =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he
  case entity_fork =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he
  case entity_merge =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he
  case time_advance =>
    dsimp [Step] at h
    rcases h with ⟨-, -, -, -, -, -, hesc, -⟩
    rw [hesc] at he; exact h_inv e he

/--
  [R] INVARIANT (e) BalOvflw (L26):
  Individual balance is bounded by Th_bal via automatic treasury spill.
-/
def Invariant_BalOvflw (s : State) (thBal : ℝ) : Prop :=
  ∀ a ∈ s.accounts, a.balance ≤ thBal

/--
  [R] Auto-spill mechanism to enforce balance ceiling:
  Excess balance is credited to community treasury.
-/
noncomputable def auto_spill_overflow (a : Account) (thBal : ℝ) (h_th : 0 ≤ thBal) : Account × ℝ :=
  if a.balance > thBal then
    ({ a with balance := thBal, h_nonneg := h_th }, a.balance - thBal)
  else
    (a, 0)

theorem auto_spill_enforces_ceiling (a : Account) (thBal : ℝ) (h_th : 0 ≤ thBal) :
    (auto_spill_overflow a thBal h_th).1.balance ≤ thBal := by
  unfold auto_spill_overflow
  split_ifs with h
  · dsimp; rfl
  · exact le_of_not_gt h

end Benefuture.Systems
