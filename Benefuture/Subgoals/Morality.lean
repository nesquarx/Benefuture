/-
  Benefuture.Subgoals.Morality
  Formalization of Morality (Mr): Recognition of the Extended Self and Rejection of One-Shot Games.
  Corresponds to: Bf_Pseudocode.txt L136, and Philosophy.txt #Morality
  "Morality«Mr» := U(P(∃I(Sl↔ℝ) : CC(I → O(Sl)) = 0) ≈ 0 | Memory(Sl) ⊆ O(Sl)), 1shotGame ⊆ 𝕌 − ℝ;"
-/

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

abbrev Mr := InteractionConsequence

end Benefuture.Subgoals

