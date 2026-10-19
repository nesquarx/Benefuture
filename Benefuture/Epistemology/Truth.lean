/-
  Benefuture.Epistemology.Truth
  Formalization of the Benefuture Epistemological Taxonomy:
  Truth (Tr), TruthLevel (Tr_lvl), Fact (F), Hypothesis (Hy), Ignorance (Ig),
  Context (Cx), Causal Explanation (CE), Prediction (Pr), Understanding (U: General & Pragmatic), Sapience (Sp), Communication (Cm).
  Corresponds to: Bf_Pseudocode.txt L27-33, L39-45, L66, and Epistemology taxonomy.
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Measurement.MetricModel
import Benefuture.Epistemology.Context

namespace Benefuture.Epistemology

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Measurement

/- --- 1. Statements, Facts, Hypotheses, and Truth Levels --- -/

/-- 
  An Epistemic Statement about Reality (extends Thing).
  Corresponds to: Bf_Pseudocode.txt L40: "Truth«Tr» := Statement ≡ ℝ;"
-/
structure Statement extends Thing where
  content : String
  domain  : Domain
  deriving Repr, DecidableEq

/-- Coercion: Every Statement is canonically a Thing in Reality. -/
instance : Coe Statement Thing where
  coe s := s.toThing


/-- Helper constructor for Statements. -/
def Statement.mkSimple (id content : String) (dom : Domain) : Statement :=
  { toThing := Thing.mkSimple id s!"statement_{id}" dom.name 0, content := content, domain := dom }

/-- 
  Truth Level Tr_lvl(Tr_i, Cx): Graded correspondence to Reality in [0, SCALE).
  ↑U ∝ ↑Tr_lvl.
-/
structure TruthLevel where
  level      : Int  -- In [0, SCALE]
  h_nonneg   : 0 ≤ level
  h_bound    : level ≤ SCALE
  deriving Repr

/-- 
  Fact (F): A Statement that is both Objective and Verifiable in Reality.
-/
structure Fact extends Statement where
  is_objective  : Bool
  is_verifiable : Bool
  h_objective   : is_objective = true
  h_verifiable  : is_verifiable = true
  deriving Repr

/-- Coercion: Every Fact is canonically a Thing in Reality. -/
instance : Coe Fact Thing where
  coe f := f.toStatement.toThing


/-- 
  Hypothesis (Hy): A Statement that is Testable and Falsifiable.
-/
structure Hypothesis extends Statement where
  is_testable   : Bool
  h_testable    : is_testable = true
  deriving Repr

/-- Coercion: Every Hypothesis is canonically a Thing in Reality. -/
instance : Coe Hypothesis Thing where
  coe h := h.toStatement.toThing


/-- 
  Epistemic Context (Cx ∈ T, extends Context):
  The background operational and epistemic context under which a statement is evaluated.
  Relevance Rlv := ΔU / U.
  Corresponds to: Bf_Pseudocode.txt L41 ("Context«Cx»").
-/
structure EpistemicContext extends Context where
  priorUnderstanding : Int  -- Prior U in micro-units
  h_prior_pos        : 0 < priorUnderstanding
  deriving Repr

instance : Coe EpistemicContext Context where
  coe ec := ec.toContext

instance : Coe EpistemicContext Thing where
  coe ec := ec.toContext.toThing


def EpistemicContext.mkSimple (id : String) (dom : Domain) (priorU : Int)
    (h_pos : 0 < priorU := by decide) : EpistemicContext :=
  { toContext := Context.mkOptimal id dom,
    priorUnderstanding := priorU,
    h_prior_pos := h_pos }

/-- Relevance of new information relative to background context: Rlv = ΔU / U_prior. -/
def calculate_relevance (delta_u : Int) (ctx : EpistemicContext) : Int :=
  (delta_u * SCALE) / ctx.priorUnderstanding

/- --- 2. Ignorance and Causal Explanation --- -/

/-- 
  Ignorance (Ig): The absence of verified Understanding in a Domain.
  Ig(Dn) := ¬∃ U ∈ Dn.
-/
def is_domain_ignorant (verified_models_in_domain : List MetricModel) : Prop :=
  verified_models_in_domain = []

instance (v : List MetricModel) : Decidable (is_domain_ignorant v) := by
  unfold is_domain_ignorant
  infer_instance

/-- 
  Causal Explanation (CE ∈ T):
  Corresponds to: Bf_Pseudocode.txt L28:
  "CausalExplanation«CE» := Rel(T[]) : Explain(History(ℝ)) ∧ (Complement ∨ Subsum)(CE_estd);"
  Relational explanation over a set of Things in Reality, grounded as a Thing.
-/
structure CausalExplanation extends Thing where
  domain           : Domain
  relationalThings : List Thing := []  -- Rel(T[])
  subsumesPrior    : Bool
  complementsPrior : Bool
  h_valid_relation : subsumesPrior = true ∨ complementsPrior = true
  deriving Repr

instance : Coe CausalExplanation Thing where
  coe ce := ce.toThing


def CausalExplanation.mkSimple (id : String) (dom : Domain) (rel : List Thing := [])
    (subsumes complements : Bool := true)
    (h_val : subsumes = true ∨ complements = true := by decide) : CausalExplanation :=
  { toThing := Thing.mkSimple id s!"ce_{id}" dom.name 0,
    domain := dom, relationalThings := rel,
    subsumesPrior := subsumes, complementsPrior := complements,
    h_valid_relation := h_val }

/- --- 3. Understanding: General and Pragmatic --- -/

/-- 
  General Understanding grounded directly on Option CausalExplanation:
  U(Ml) := PrAcc(Ml) + CE(I(Ml)) - Complexity(Ml).
  Corresponds to: Bf_Pseudocode.txt L30.
-/
def general_understanding_with_ce (acc : PredictionAccuracy) (ce : Option CausalExplanation) (complexity_penalty : Int) : Int :=
  let ce_score := match ce with
    | some _ => 300000  -- 0.3 bonus for verified causal mechanism
    | none   => 0
  acc.brier_accuracy + ce_score - complexity_penalty

/-- General Understanding U(Model) with boolean indicator. -/
def general_understanding (acc : PredictionAccuracy) (has_ce : Bool) (complexity_penalty : Int) : Int :=
  let ce_score := if has_ce then 300000 else 0  -- 0.3 bonus for causal mechanism
  acc.brier_accuracy + ce_score - complexity_penalty

/-- 
  Pragmatic Understanding (extends Thing):
  Pragmatic(T, Ml) := MapFit(T, Ml_id) * [∑ (Wt * CE * PrAcc * (1 - Cy)) / ∑ Wt]
  Corresponds to: Bf_Pseudocode.txt L31.
  Measures contextual, applied problem-solving capability on a concrete Thing T in Reality.
-/
structure PragmaticAssessment extends Thing where
  targetThingId : String := ""
  mapFit        : Int  -- Alignment between model and target Thing [0, SCALE]
  weight        : Int  -- P(X|T) * P(i|T, X) * Impact(i)
  ceBonus       : Int  -- Causal explanation weight
  prAcc         : Int  -- Prediction accuracy
  complexity    : Int  -- Complexity discount Cy
  deriving Repr

instance : Coe PragmaticAssessment Thing where
  coe asmt := asmt.toThing


def PragmaticAssessment.mkSimple (id targetId : String) (fit wt ce acc comp : Int) : PragmaticAssessment :=
  { toThing := Thing.mkSimple id s!"asmt_{id}" "pragmatics" 0,
    targetThingId := targetId, mapFit := fit, weight := wt, ceBonus := ce, prAcc := acc, complexity := comp }

def pragmatic_understanding (asmt : PragmaticAssessment) : Int :=
  let quality := (asmt.ceBonus * asmt.prAcc) / SCALE
  let discounted := (quality * (SCALE - asmt.complexity)) / SCALE
  (asmt.mapFit * discounted) / SCALE

/-- 
  Sapience (Sp, extends Thing):
  The intersection of Understanding and Forward Predictive Agency.
  Sp := U & Pr(I).
  Corresponds to: Bf_Pseudocode.txt L17, L66.
-/
structure SapienceProfile extends Thing where
  understandingLevel : Int
  predictiveCapacity : Int
  h_u_pos            : 0 < understandingLevel
  h_pr_pos           : 0 < predictiveCapacity
  deriving Repr

instance : Coe SapienceProfile Thing where
  coe sp := sp.toThing


def SapienceProfile.mkSimple (id : String) (u pr : Int)
    (h_u : 0 < u := by decide) (h_pr : 0 < pr := by decide) : SapienceProfile :=
  { toThing := Thing.mkSimple id s!"sapience_{id}" "epistemology" 0,
    understandingLevel := u, predictiveCapacity := pr,
    h_u_pos := h_u, h_pr_pos := h_pr }

/-- 
  Communication (Cm extends Interaction):
  Comm«Cm» := Ou(E_i, U_i) → Input(E_j, U_j) | U_i ≈ U_j.
  Process of transmitting understanding between entities.
  Corresponds to: Bf_Pseudocode.txt L66.
-/
structure Communication extends Interaction where
  senderUnderstanding   : Int
  receiverUnderstanding : Int
  transmittedInformation: Int
  h_info_pos            : transmittedInformation > 0
  deriving Repr

instance : Coe Communication Thing where
  coe cm := cm.toInteraction.toThing


/-- 
  THEOREMS: Epistemic Dominance and Grounding.
-/
theorem causal_model_strictly_dominates_blackbox 
    (acc : PredictionAccuracy) (comp : Int) :
    general_understanding acc true comp > general_understanding acc false comp := by
  dsimp [general_understanding]
  omega

theorem causal_explanation_enhances_understanding 
    (acc : PredictionAccuracy) (ce : CausalExplanation) (comp : Int) :
    general_understanding_with_ce acc (some ce) comp > general_understanding_with_ce acc none comp := by
  dsimp [general_understanding_with_ce]
  omega

theorem pragmatic_fit_amplification (asmt : PragmaticAssessment) 
    (h_fit : asmt.mapFit > 0) (h_qual : (asmt.ceBonus * asmt.prAcc) / SCALE > 0) 
    (h_comp : asmt.complexity < SCALE) :
    pragmatic_understanding asmt ≥ 0 := by
  unfold pragmatic_understanding
  have h1 : (asmt.ceBonus * asmt.prAcc) / SCALE ≥ 0 := by omega
  have h2 : SCALE - asmt.complexity ≥ 0 := by omega
  have h_mul1 : (asmt.ceBonus * asmt.prAcc) / SCALE * (SCALE - asmt.complexity) ≥ 0 := Int.mul_nonneg h1 h2
  have h_div1 : ((asmt.ceBonus * asmt.prAcc) / SCALE * (SCALE - asmt.complexity)) / SCALE ≥ 0 :=
    Int.ediv_nonneg h_mul1 (by decide)
  have h_fit_ge : asmt.mapFit ≥ 0 := by omega
  have h_mul2 : asmt.mapFit * (((asmt.ceBonus * asmt.prAcc) / SCALE * (SCALE - asmt.complexity)) / SCALE) ≥ 0 :=
    Int.mul_nonneg h_fit_ge h_div1
  exact Int.ediv_nonneg h_mul2 (by decide)

abbrev Tr := Statement
abbrev Tr_lvl := TruthLevel
abbrev F := Fact
abbrev Hy := Hypothesis
abbrev Ig := is_domain_ignorant
abbrev CE := CausalExplanation
abbrev Rlv := calculate_relevance
abbrev Cm := Communication
abbrev U := general_understanding

end Benefuture.Epistemology


