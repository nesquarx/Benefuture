/-
  BenefutureReference.Export
  C-callable entry points for the simulation (`sim/`, Julia `ccall`). Each export wraps one
  reference function; it adds no semantics. Lists cross the boundary as `FloatArray`s, built
  from the caller with `bf_fa_mk` and `bf_fa_push`. Array arguments are owned: each call consumes
  them, so a caller passes every array exactly once.
-/

import BenefutureReference.Functions
import BenefutureReference.Goal
import BenefutureReference.Measurement

namespace BenefutureReference.Export

open BenefutureReference

@[export bf_fa_mk] def faMk (capacity : USize) : FloatArray := FloatArray.emptyWithCapacity capacity.toNat
@[export bf_fa_push] def faPush (a : FloatArray) (x : Float) : FloatArray := a.push x

private def pairs (a b : FloatArray) : List (Float × Float) := a.data.toList.zip b.data.toList

@[export bf_phi] def phi (mags weights : FloatArray) (q kappa : Float) : Float :=
  phi_ref (pairs mags weights) q kappa

@[export bf_sy] def sy (posMags posWeights negMags negWeights : FloatArray)
    (lambda kappa qPlus qMinus : Float) : Float :=
  Sy_ref (pairs posMags posWeights) (pairs negMags negWeights) lambda kappa qPlus qMinus

@[export bf_sy_hat] def syHat (s nu h : Float) : Float := Sy_hat_ref s nu h

@[export bf_sy_signed] def sySigned (xs gainWeights lossWeights : FloatArray)
    (lambda kappa qPlus qMinus : Float) : Float :=
  let items := (xs.data.toList.zip (gainWeights.data.toList.zip lossWeights.data.toList))
  Sy_signed_ref items lambda kappa qPlus qMinus

@[export bf_as] def assess (predicted counter measured t t0 thCx : Float) : Float :=
  As_ref predicted counter measured t t0 thCx

@[export bf_ha_wt] def haWt (severities weights : FloatArray) (lambda : Float) : Float :=
  HaWt_ref (pairs severities weights) lambda

@[export bf_v] def value (u h n alpha beta gamma haWt lambda qPlus qMinus : Float) : Float :=
  V_ref u h n alpha beta gamma haWt lambda qPlus qMinus

@[export bf_harm_schedule_len] def harmScheduleLen (_ : Unit) : USize := harmSchedule_ref.length.toUSize
@[export bf_harm_schedule_at] def harmScheduleAt (i : USize) : Float := harmSchedule_ref.getD i.toNat 0.0

@[export bf_floor_quantile] def floorQuantile (xs : FloatArray) (q : Float) : Float :=
  floor_quantile_ref xs.data q

@[export bf_g_choose] def gChoose (values dScope dMinU dMinH dMaxU : FloatArray) : UInt64 :=
  (g_choose_ref values.data dScope.data dMinU.data dMinH.data dMaxU.data).toUInt64

@[export bf_mm_score] def mmScore (pred obs : FloatArray) : Float := mm_score_ref pred.data obs.data

@[export bf_mm_adopt] def mmAdopt (scores : FloatArray) : UInt64 := (mm_adopt_ref scores.data).toUInt64

end BenefutureReference.Export
