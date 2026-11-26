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

/-- Four-factor responsibility weight for causal distribution (`L96`, rulings 8.152 & 8.159).
    Matches `Benefuture.Subgoals.responsibility_factor`. -/
def responsibility_factor_ref (isAct isInformed hasDuty : Bool)
    (counterfactualRatio severityScale accidentFactor : Float) : Float :=
  let clamp01 (x : Float) : Float :=
    let nn := if x > 0.0 then x else 0.0
    if nn < 1.0 then nn else 1.0
  let roleWeight :=
    if !isAct && !hasDuty then 0.0
    else if isInformed then 1.0
    else clamp01 accidentFactor
  let sevNN := if severityScale > 0.0 then severityScale else 0.0
  roleWeight * clamp01 counterfactualRatio * sevNN

/-- Audit probability of a forcible restraint (`L121`; ruling 8.169 c): `min 1 (floor + (1 - floor) *
    burden / bar)`, burden `sev * (1 + dur / durScale)`; 1 at and above the severity bar. Matches
    `Benefuture.Subgoals.restraint_audit_prob`. Assumes `bar > 0`, `durScale > 0`. -/
def restraint_audit_prob_ref (sev dur durScale bar floorP : Float) : Float :=
  let burden := sev * (1.0 + dur / durScale)
  let raw := floorP + (1.0 - floorP) * (burden / bar)
  if raw < 1.0 then raw else 1.0

/-- Liability of the enforcing entity (`L120`; ruling 8.169 ii): zero when the audit upholds the
    restraint, else `max 0 kappa * max 0 cost`. Matches `false_restraint_liability`. -/
def false_restraint_liability_ref (upheld : Bool) (kappa cost : Float) : Float :=
  if upheld then 0.0
  else (if kappa > 0.0 then kappa else 0.0) * (if cost > 0.0 then cost else 0.0)

/-- Weight of the audit's credence that the restraint was false (ruling 8.169 iii): `clamp (2 conf - 1)`
    to [0, 1]; zero at and below one half. Matches `restraint_audit_weight`. -/
def restraint_audit_weight_ref (conf : Float) : Float :=
  let w := 2.0 * conf - 1.0
  if w < 0.0 then 0.0 else if w > 1.0 then 1.0 else w

/-- Credence-scaled liability: `max 0 kappa * max 0 cost * weight conf`. Matches
    `credence_restraint_liability`. -/
def credence_restraint_liability_ref (conf kappa cost : Float) : Float :=
  (if kappa > 0.0 then kappa else 0.0) * (if cost > 0.0 then cost else 0.0) * restraint_audit_weight_ref conf

/-- Restraint-balance alarm (ruling 8.170 e): flagged once at least `minAudits` verdicts are audited
    and `falseN >= ratio * trueN`. Matches `restraint_balance_flawed`. -/
def restraint_balance_flawed_ref (minAudits falseN trueN : Nat) (ratio : Float) : Bool :=
  minAudits ≤ falseN + trueN && ratio * trueN.toFloat ≤ falseN.toFloat

/-- Interval alarm (ruling 8.175 (1)): at least `minAudits` verdicts audited, `ratio * trueN < falseN`
    and `z^2 * ratio * (falseN + trueN) < (falseN - ratio * trueN)^2` (the Wilson lower bound of the false
    share exceeds the bar `ratio / (1 + ratio)` at `z`). Matches `restraint_alarm_interval`. -/
def restraint_alarm_interval_ref (minAudits falseN trueN : Nat) (ratio z : Float) : Bool :=
  let f := falseN.toFloat
  let t := trueN.toFloat
  minAudits ≤ falseN + trueN && ratio * t < f && z * z * ratio * (f + t) < (f - ratio * t) * (f - ratio * t)

/-- Voice of a panel expert (`L115`): minority clusters get the weight raised by `uplift`, never
    lowered. Matches `panel_voice`. -/
def panel_voice_ref (vw uplift : Float) (minority : Bool) : Float :=
  if minority then vw * (if uplift > 1.0 then uplift else 1.0) else vw

end BenefutureReference
