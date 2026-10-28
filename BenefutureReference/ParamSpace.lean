/-
  BenefutureReference.ParamSpace
  Computable reference for the governed parameter space (`Systems.ParamSpace` [R]; L157 SigThGv).
  A parameter vector is an array in the order of `paramFields`, mirroring `ParamVector`.
-/

namespace BenefutureReference

/-- Field order of a parameter vector, as in `ParamVector`. -/
def paramFields : List String :=
  ["alpha", "beta", "gamma", "delta", "kappa", "q_plus", "q_minus", "lambda", "kappa_value",
   "kappa_harm", "q_harm", "nu", "h_param", "lambda_plus", "lambda_minus", "th_sig", "th_gov",
   "fr_thConf", "fr_thHigh", "sev_irreparable", "sev_irreversible", "sev_longterm", "sev_passing",
   "sev_timeLoss", "h_window", "deleg_cap", "ehr_margin", "dist_weight"]

/-- The bootstrap point (`bootstrapParams`). -/
def bootstrap_params_ref : Array Float :=
  #[0.8, 0.6, 0.4, 0.2, 1, 1.1, 1.5, 0.5, 2, 0.5, 1.5, 1, 1, 0.05, 0.05, 0.5, 0.7, 0.9, 1,
    1000, 100, 10, 1, 0.5, 10, 0.05, 0.25, 1]

/-- Admissibility (`Admissible`): the ranges and joint constraints the proved theorems rely on. -/
def admissible_ref (v : Array Float) : Bool :=
  let f (i : Nat) := v.getD i 0.0
  v.size == paramFields.length &&
  -- L11: 1 > α > β > γ > δ > 0
  f 0 < 1 && f 1 < f 0 && f 2 < f 1 && f 3 < f 2 && 0 < f 3 &&
  -- L13: κ ≥ 0, q₊ > 1, q₊ ≤ q₋, 0 ≤ λ ≤ 1; L61, L73
  0 ≤ f 4 && 1 < f 5 && f 5 ≤ f 6 && 0 ≤ f 7 && f 7 ≤ 1 && 0 ≤ f 8 && 0 ≤ f 9 && 1 < f 10 &&
  -- L14, L101, L25, L155
  0 < f 11 && 0 < f 12 && 0 < f 13 && 0 < f 14 && 0 < f 15 && 0 < f 16 &&
  -- L135: confidence in (0, 1], positive ceiling, severities positive and ordered
  0 < f 17 && f 17 ≤ 1 && 0 < f 18 && 0 < f 23 && f 23 ≤ f 22 && f 22 ≤ f 21 && f 21 ≤ f 20 &&
    f 20 ≤ f 19 &&
  -- L54 (a window of at least one step), L114, L117, L62
  1 ≤ f 24 && 0 < f 25 && f 25 ≤ 1 && 0 ≤ f 26 && 0 < f 27

/-- Controlled perturbation (`perturb_step`, L157: Perturb(Th ± δ ∈ Fr)): the candidate is adopted
    only if admissible and every governed field (indices `fields`) moves by at most δ. -/
def perturb_step_ref (cur cand : Array Float) (fields : Array Nat) (δ : Float) : Array Float :=
  if admissible_ref cand && fields.all (fun i => (cand.getD i 0.0 - cur.getD i 0.0).abs ≤ δ) then cand else cur

end BenefutureReference
