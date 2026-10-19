/-
  Benefuture.Systems.Memory
  Formalization of Record (Rec ∈ T) and Immutable Memory (Mem ∈ T).
  Corresponds to: Bf_Pseudocode.txt L136, L145, L152, and System Design.txt
  
  "Mem := Immutable {State(t), A(t), O(t), SigRlvCx(t)[], ...}, 
   ∀x ∈ {Exec(A) ∪ O} : Sys → Log(Tx(x)) → BehavioralTxnSubstrate«BTS»;"
  "CvCnt := ... (Mem(t + Δt) ≈ Mem(t) ∧ Lineage(Mem) ∧ Coherent(Mem, G));"
  "Morality«Mr» := ... | Memory(Sl) ⊆ O(Sl);"
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Epistemology.Context

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Epistemology

/-- 
  Immutable Behavioral Record (Rec ∈ T):
  Binds the systemic state at time t, executed actions, observed outcomes, 
  and significant context into a single cryptographically linked transaction record.
  Corresponds to: Bf_Pseudocode.txt L145.
-/
structure MemoryRecord extends Thing where
  timestamp       : Int
  stateSnapshot   : String
  action          : Option Action
  outcome         : Option Outcome
  context         : Context
  parentHash      : String
  recordHash      : String
  deriving Repr

/-- Coercion: Every MemoryRecord is canonically a Thing in Reality. -/
instance : Coe MemoryRecord Thing where
  coe r := r.toThing


/-- 
  Immutable Memory Store (Mem ∈ T):
  The unbroken, append-only behavioral ledger of a Being, Sophont, or Civilization.
  Corresponds to: Bf_Pseudocode.txt L145, L152.
-/
structure ImmutableMemory extends Thing where
  records         : List MemoryRecord
  headHash        : String
  deriving Repr

/-- Coercion: Every ImmutableMemory is canonically a Thing in Reality. -/
instance : Coe ImmutableMemory Thing where
  coe m := m.toThing


/-- Append-only transition: Adding a new record to memory. -/
def append_record (mem : ImmutableMemory) (rec : MemoryRecord) : ImmutableMemory :=
  { toThing := mem.toThing,
    records := rec :: mem.records,
    headHash := rec.recordHash }

/-- 
  THEOREM: Memory Preservation Theorem (Append-Only Invariant).
  Every existing record in memory remains present after appending a new record:
  r ∈ mem.records → r ∈ (append_record mem newRec).records.
-/
theorem memory_preserves_history (mem : ImmutableMemory) (newRec : MemoryRecord) 
    (r : MemoryRecord) (h_in : r ∈ mem.records) :
    r ∈ (append_record mem newRec).records := by
  unfold append_record
  dsimp
  exact List.Mem.tail newRec h_in

/-- 
  THEOREM: Newly Appended Record is Immediately Ingested.
-/
theorem newly_appended_record_is_head (mem : ImmutableMemory) (newRec : MemoryRecord) :
    newRec ∈ (append_record mem newRec).records := by
  unfold append_record
  dsimp
  exact List.Mem.head mem.records

/-- 
  Helper constructor for simple MemoryRecords.
-/
def MemoryRecord.mkSimple (id : String) (t : Int) (state : String) 
    (cx : Context) (parent : String) (recH : String) 
    (act : Option Action := none) (out : Option Outcome := none) : MemoryRecord :=
  { toThing := Thing.mkSimple id s!"record_{id}" cx.domain.name (if t ≥ 0 then t.toNat else 0),
    timestamp := t,
    stateSnapshot := state,
    action := act,
    outcome := out,
    context := cx,
    parentHash := parent,
    recordHash := recH }

/-- 
  Helper constructor for an empty ImmutableMemory genesis store.
-/
def ImmutableMemory.mkGenesis (id : String) : ImmutableMemory :=
  { toThing := Thing.mkSimple id s!"memory_ledger_{id}" "bts_ledger" 0,
    records := [],
    headHash := "0x_genesis" }

abbrev Mem := ImmutableMemory

end Benefuture.Systems

