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

end BenefutureReference
