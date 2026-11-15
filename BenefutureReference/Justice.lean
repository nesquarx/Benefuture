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

end BenefutureReference
