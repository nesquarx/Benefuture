/-
  BenefutureReference.Justice
  Computable reference for crime classification (L115; `Subgoals.Justice`; author ruling,
  BACKPROPAGATION 8.17).
-/

namespace BenefutureReference

/-- Crime is harm through informed volition or informed inaction against a committed action (a
    duty from a contract, including a law once communicated); otherwise the harm is an accident.
    Repair is owed either way. Mirrors `is_crime_classification`. -/
def is_crime_ref (isInformed hasVolition breachedDuty : Bool) : Bool :=
  isInformed && (hasVolition || breachedDuty)

/-- Contributor's share of an uninformed harm (accident), bounded by their capacity
    (`Penalize ≤ Capacity`, L96; author ruling 8.157 ii). Assumes `harm ≥ 0`, `cap ≥ 0`. -/
def accident_contributor_ref (harm cap : Float) : Float :=
  if harm <= cap then harm else cap

/-- Remainder of an uninformed harm carried by the administration (`Ad(rest)`, L96;
    author ruling 8.157 ii). Assumes `harm ≥ 0`, `cap ≥ 0`. -/
def accident_admin_ref (harm cap : Float) : Float :=
  if harm <= cap then 0.0 else harm - cap

/-- Repeated-pattern escalation count from negative domain reputation events (`pattern(Re_-ve(Dn))`,
    L117; author ruling 8.157 i). Returns `0` while `domNegEvents < patternMin`. -/
def pattern_escalation_repeats_ref (domNegEvents patternMin : Nat) : Nat :=
  if patternMin == 0 || domNegEvents < patternMin then 0 else domNegEvents - patternMin + 1

/-- Graduated sanction escrow credence combining permanent `deceptions` and repeated domain negative
    reputation pattern (`8.157 i`, `8.157 iii`). Floored at `floorC`. -/
def sanction_escrow_credence_ref (cred negShare : Float)
    (deceptions domNegEvents patternMin : Nat) (growth floorC : Float) : Float :=
  let esc := deceptions + pattern_escalation_repeats_ref domNegEvents patternMin
  let factor := Float.pow (1.0 / (1.0 + growth)) esc.toFloat
  let raw := (0.5 + (cred - 0.5) * (1.0 - negShare)) * factor
  if raw >= floorC then raw else floorC

/-- Domain-scoped rehabilitative proposal restraint for repeated crime patterns (`Prevent(Cr)`,
    L117; `8.157 i`). Returns `baseShare` for isolated lapses and decays down to `minShare`. -/
def rehabilitate_restraint_ref (baseShare : Float) (crimeEvents patternMin : Nat)
    (stepDecay minShare : Float) : Float :=
  let esc := pattern_escalation_repeats_ref crimeEvents patternMin
  if esc == 0 then baseShare
  else
    let scaled := baseShare * Float.pow stepDecay esc.toFloat
    if scaled >= minShare then scaled else minShare

end BenefutureReference
