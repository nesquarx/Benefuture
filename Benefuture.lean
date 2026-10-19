/-
  Benefuture Library Root
  Imports the complete formalization of the Benefuture framework:
  1. Math: Exact orderings, parameters, and synergy calculations
  2. Ontology: Things, Entities, Beings, Persons, Sophonts
  3. Axiology:
     - Priorities: Tiered synergies for Understanding, Happiness, Novelty, and Harm Weighting
     - Value: Value function V(A, b), Goal function G, Anti-wireheading
  4. Epistemology:
     - Truth: Statements, Facts, Hypotheses, Truth Levels, Ignorance, Causal Explanations, Sapience
     - InfoHandling: InfoHazards, Critical Thinking, Education, Inoculation without Censorship
  5. Measurement:
     - MetricModel: Perceivable Markers, Causal Explanations, Brier Accuracy, Model Competition
  6. Economy:
     - Currency: Backed by winning Metric Models, Probabilistic Escrow, No-Arbitrage
  7. Governance:
     - Democracy: Weighted Direct Democracy, Anti-Halo Domain Isolation
     - Adversarial: Adversarial Adaptation, Revelation Dominance
  8. Subgoals (SubG):
     - Freedom: Permissible action maximization bounded by non-irreversible harm
     - Morality: Rejection of one-shot game illusions via extended self causal feedback
     - Justice: Restorative restitution over retribution
     - Diversity: Anti-monoculture axiom and novelty injection
     - Art: Aesthetic transmission of affect and epistemic insight
     - Continuity: Civilizational memory and antifragile harm intervention invariants
-/

import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Reality
import Benefuture.Ontology.Entity

import Benefuture.Ontology.Being
import Benefuture.Ontology.Person
import Benefuture.Ontology.Sophont
import Benefuture.Ontology.Domain
import Benefuture.Ontology.Law
import Benefuture.Axiology.Priorities
import Benefuture.Axiology.Value
import Benefuture.Axiology.RepugnantConclusion
import Benefuture.Epistemology.Context
import Benefuture.Epistemology.Prediction
import Benefuture.Epistemology.Truth
import Benefuture.Epistemology.InfoHandling
import Benefuture.Measurement.Threshold
import Benefuture.Measurement.MetricModel
import Benefuture.Economy.Currency
import Benefuture.Governance.Democracy
import Benefuture.Governance.Adversarial
import Benefuture.Subgoals.Freedom
import Benefuture.Subgoals.Morality
import Benefuture.Subgoals.Justice
import Benefuture.Subgoals.Diversity
import Benefuture.Subgoals.Art
import Benefuture.Subgoals.Continuity
import Benefuture.Systems.Memory
import Benefuture.Systems.Substrate
import Benefuture.Systems.Economy
import Benefuture.Systems.Governance
import Benefuture.Systems.TechnologyNetwork
import Benefuture.Systems.Enforcement
import Benefuture.Systems.Pipeline
import Benefuture.Systems.State
import Benefuture.Governance.Incentives
import Benefuture.Ontology.Reputation
import Benefuture.Axioms.Antifragility

namespace Benefuture

/-- 
  𝕌 represents the Universe (total pattern state space).
  Contrasted with ℝ (Reality: perceivable and changeable patterns).
  Formal theorem: ℝ ⊆ 𝕌.
-/
abbrev 𝕌 := Benefuture.Ontology.𝕌
abbrev Universe := Benefuture.Ontology.Universe

/-- 
  U represents Understanding (U := PrAcc + CE - Cy).
  In Benefuture, U is purely epistemic understanding, NOT utilitarian utility.
  Civilizational objective is Value (V) / Flourishing (G).
-/
abbrev U := Benefuture.Epistemology.U

end Benefuture

