/-
  Benefuture.Subgoals.Morality
  Formalization of Morality (Mr): Recognition of the Extended Self and Rejection of One-Shot Games.
  Corresponds to: Bf_Pseudocode.txt L136, and Philosophy.txt #Morality
  "Morality«Mr» := U(P(∃I(Sl↔ℝ) : CC(I → O(Sl)) = 0) ≈ 0 | Memory(Sl) ⊆ O(Sl)), 1shotGame ⊆ 𝕌 − ℝ;"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
import Benefuture.Ontology.Being
import Benefuture.Ontology.Reality

namespace Benefuture.Subgoals

open Benefuture.Ontology

/-- 
  Causal Feedback of an interaction onto the Being:
  1. Internal: Every interaction deposits memory in the Being's memoryTrace (Memory(Sl) ⊆ O(Sl)).
  2. External: Harm to the commons transmits derived harm back to the Being via its Extended Self.
-/
structure InteractionConsequence extends Thing where
  actor           : Being
  targetCommonsId : String
  link            : InterdependenceLink
  h_link_in_self  : link ∈ actor.extendedSelf
  h_link_target   : link.targetId = targetCommonsId
  deriving Repr

instance : Coe InteractionConsequence Thing where
  coe c := c.toThing


def InteractionConsequence.mkSimple (id : String) (act : Being) (target : String) (lnk : InterdependenceLink) 
    (h_self : lnk ∈ act.extendedSelf) (h_tgt : lnk.targetId = target) : InteractionConsequence :=
  { toThing := Thing.mkSimple id s!"moral_conseq_{id}" "extended_self_substrate" 0,
    actor := act, targetCommonsId := target, link := lnk,
    h_link_in_self := h_self, h_link_target := h_tgt }

/-- 
  An action causing damage to the commons produces direct coupled harm on the actor's extended self.
-/
def self_inflicted_extended_harm (conseq : InteractionConsequence) (damage : Int) : Int :=
  raw_extended_harm conseq.link damage

/-- 
  One-shot game condition:
  An interaction claimed to produce zero causal feedback on the actor (CC = 0).
-/
def is_zero_feedback_interaction (harm_on_self : Int) : Prop :=
  harm_on_self = 0

/-- 
  MASTER THEOREM: Extended Self Eliminates One-Shot Defection.
  Any harmful action on an external target coupled to the actor's extended self (damage > 0)
  strictly causes positive harm back onto the actor (self_inflicted_extended_harm > 0).
  Therefore, defecting under the illusion of a "one-shot game" is mathematically self-destructive.
  One-shot games exist only outside Reality (1shotGame ⊆ 𝕌 − ℝ).
-/
theorem defection_harms_extended_self (conseq : InteractionConsequence) (damage : Int) (h_dam : damage > 0) :
    self_inflicted_extended_harm conseq damage > 0 := by
  unfold self_inflicted_extended_harm
  exact extended_self_propagates_harm conseq.link damage h_dam

theorem no_one_shot_harmful_games (conseq : InteractionConsequence) (damage : Int) (h_dam : damage > 0) :
    ¬ is_zero_feedback_interaction (self_inflicted_extended_harm conseq damage) := by
  unfold is_zero_feedback_interaction
  have hpos := defection_harms_extended_self conseq damage h_dam
  omega

/-- 
  A theoretical one-shot interaction pattern claimed to operate with zero feedback:
  Lacks empirical perception and physical capability in Reality.
-/
def one_shot_game_universe_pattern (id : String) : UniversePattern :=
  { patternId := id, isPerceivable := false, isChangeable := false }



/- =========================================================================
   INTERNAL MEMORY FEEDBACK: Memory(Sl) ⊆ O(Sl)
   Every interaction deposits an indelible trace in the agent's memory,
   guaranteeing that even absent external damage, internal causal consequence
   is strictly non-zero.
   ========================================================================= -/

/-- 
  Predicate: The agent's memory contains the executed interaction record.
  Memory(Sl) ⊆ O(Sl).
-/
def memory_records_interaction (memHistory : List String) (interactionId : String) : Prop :=
  interactionId ∈ memHistory

/-- 
  THEOREM: Internal Memory Trace Invariant.
  Appending an interaction to an agent's memory trace guarantees that 
  the interaction is permanently recorded in the outcomes of the self:
  interactionId ∈ (interactionId :: memHistory).
-/
theorem interaction_permanently_in_memory (memHistory : List String) (interactionId : String) :
    memory_records_interaction (interactionId :: memHistory) interactionId := by
  unfold memory_records_interaction
  exact List.Mem.head memHistory

/-! ## Real-Valued Extended Self Feedback & End-of-Horizon Score (`7.12`, `B25`, M8) -/

/-- Net extended-self feedback transmitted across coupled targets `[(c_k, Δ_k)]` (`L136`, `7.12`):
    each coupling weight `c` is clamped to `[0, 1]` and multiplies target outcome delta `d`. -/
noncomputable def extended_self_feedback : List ℝ → List ℝ → ℝ
  | c :: cs, d :: ds => max 0 (min 1 c) * d + extended_self_feedback cs ds
  | _, _ => 0

/-- Total consequential score across a being's horizon (`7.12`, `B25`):
    - No financial property inheritance when `alive = false`; lifespan bounds experienced `ownRemaining`.
    - Extended self (`Self«Sl»`) couplings continue to transmit coupled outcomes.
    - Posthumous Causal Distribution (`CD`) and ideological inheritance keep attributing delayed
      causal outcomes and ideological legacy gains to the actor's record and heirs. -/
noncomputable def end_of_horizon_score
    (ownRemaining : ℝ) (alive : Bool) (couplings deltas : List ℝ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℝ) : ℝ :=
  (if alive then ownRemaining else 0) +
  extended_self_feedback couplings deltas +
  max 0 causalShare * delayedOutcome +
  max 0 ideologicalShare * ideologicalGain

theorem extended_self_feedback_zero_couplings (couplings deltas : List ℝ)
    (h_zero : ∀ c ∈ couplings, c ≤ 0) :
    extended_self_feedback couplings deltas = 0 := by
  induction couplings generalizing deltas with
  | nil => simp [extended_self_feedback]
  | cons c cs ih =>
    cases deltas with
    | nil => simp [extended_self_feedback]
    | cons d ds =>
      unfold extended_self_feedback
      have hc : c ≤ 0 := h_zero c (List.Mem.head cs)
      have hmin : min (1 : ℝ) c ≤ 0 := min_le_of_right_le hc
      have hmax : max (0 : ℝ) (min 1 c) = 0 := max_eq_left hmin
      rw [hmax, zero_mul, zero_add]
      exact ih ds (fun x hx => h_zero x (List.Mem.tail c hx))

theorem extended_self_feedback_nonpos (couplings deltas : List ℝ)
    (h_harm : ∀ d ∈ deltas, d ≤ 0) :
    extended_self_feedback couplings deltas ≤ 0 := by
  induction couplings generalizing deltas with
  | nil => simp [extended_self_feedback]
  | cons c cs ih =>
    cases deltas with
    | nil => simp [extended_self_feedback]
    | cons d ds =>
      unfold extended_self_feedback
      have h1 : max (0 : ℝ) (min 1 c) * d ≤ 0 :=
        mul_nonpos_of_nonneg_of_nonpos (le_max_left 0 _) (h_harm d (List.Mem.head ds))
      have h2 := ih ds (fun x hx => h_harm x (List.Mem.tail d hx))
      linarith

theorem extended_self_feedback_neg_of_harm
    (c d : ℝ) (cs ds : List ℝ) (hc : 0 < c) (hd : d < 0)
    (h_rest : ∀ x ∈ ds, x ≤ 0) :
    extended_self_feedback (c :: cs) (d :: ds) < 0 := by
  unfold extended_self_feedback
  have hc_pos : 0 < max (0 : ℝ) (min 1 c) :=
    lt_of_lt_of_le (lt_min (by norm_num) hc) (le_max_right _ _)
  have hhead : max (0 : ℝ) (min 1 c) * d < 0 := mul_neg_of_pos_of_neg hc_pos hd
  have htail := extended_self_feedback_nonpos cs ds h_rest
  linarith

theorem end_of_horizon_dead_drops_own
    (own₁ own₂ : ℝ) (couplings deltas : List ℝ)
    (cs dOut is_ iGain : ℝ) :
    end_of_horizon_score own₁ false couplings deltas cs dOut is_ iGain =
      end_of_horizon_score own₂ false couplings deltas cs dOut is_ iGain := by
  simp [end_of_horizon_score]

theorem end_of_horizon_dead_defection_neg
    (ownRemaining c d : ℝ) (cs ds : List ℝ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℝ)
    (hc : 0 < c) (hd : d < 0) (h_rest : ∀ x ∈ ds, x ≤ 0)
    (h_cd : delayedOutcome ≤ 0) (h_id : ideologicalGain ≤ 0) :
    end_of_horizon_score ownRemaining false (c :: cs) (d :: ds)
      causalShare delayedOutcome ideologicalShare ideologicalGain < 0 := by
  unfold end_of_horizon_score
  simp only [Bool.false_eq_true, ↓reduceIte, zero_add]
  have hfb := extended_self_feedback_neg_of_harm c d cs ds hc hd h_rest
  have h1 : max 0 causalShare * delayedOutcome ≤ 0 :=
    mul_nonpos_of_nonneg_of_nonpos (le_max_left 0 _) h_cd
  have h2 : max 0 ideologicalShare * ideologicalGain ≤ 0 :=
    mul_nonpos_of_nonneg_of_nonpos (le_max_left 0 _) h_id
  linarith

/-- Decision-time prediction across an action's horizon (`7.12`, `B25`):
    `immediateOwn` counts at choice time while alive, `futureOwn` is gated on whether
    the actor expects to remain alive at the predicted outcome time (`aliveAtOutcome`),
    whereas `extended_self_feedback` on coupled targets (`Self«Sl»`) plus posthumous CD
    and ideological legacy continue even when `aliveAtOutcome = false`. -/
noncomputable def end_of_horizon_predicted_score
    (immediateOwn futureOwn : ℝ) (aliveAtOutcome : Bool)
    (couplings deltas : List ℝ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℝ) : ℝ :=
  immediateOwn +
  (if aliveAtOutcome then futureOwn else 0) +
  extended_self_feedback couplings deltas +
  max 0 causalShare * delayedOutcome +
  max 0 ideologicalShare * ideologicalGain

theorem end_of_horizon_predicted_drops_future_own
    (immediateOwn future₁ future₂ : ℝ) (couplings deltas : List ℝ)
    (cs dOut is_ iGain : ℝ) :
    end_of_horizon_predicted_score immediateOwn future₁ false couplings deltas cs dOut is_ iGain =
      end_of_horizon_predicted_score immediateOwn future₂ false couplings deltas cs dOut is_ iGain := by
  simp [end_of_horizon_predicted_score]

theorem predicted_harm_after_lifespan_detracts
    (immediateOwn futureOwn c d : ℝ) (cs ds : List ℝ)
    (causalShare delayedOutcome ideologicalShare ideologicalGain : ℝ)
    (hc : 0 < c) (hd : d < 0) (h_rest : ∀ x ∈ ds, x ≤ 0)
    (h_cd : delayedOutcome ≤ 0) (h_id : ideologicalGain ≤ 0) :
    end_of_horizon_predicted_score immediateOwn futureOwn false (c :: cs) (d :: ds)
      causalShare delayedOutcome ideologicalShare ideologicalGain < immediateOwn := by
  unfold end_of_horizon_predicted_score
  simp only [Bool.false_eq_true, ↓reduceIte, add_zero]
  have hfb := extended_self_feedback_neg_of_harm c d cs ds hc hd h_rest
  have h1 : max 0 causalShare * delayedOutcome ≤ 0 :=
    mul_nonpos_of_nonneg_of_nonpos (le_max_left 0 _) h_cd
  have h2 : max 0 ideologicalShare * ideologicalGain ≤ 0 :=
    mul_nonpos_of_nonneg_of_nonpos (le_max_left 0 _) h_id
  linarith

abbrev Mr := InteractionConsequence

end Benefuture.Subgoals

