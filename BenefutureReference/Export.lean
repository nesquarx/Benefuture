/-
  BenefutureReference.Export
  C-callable entry points for the simulation (`sim/`, Julia `ccall`). Each export wraps one
  reference function; it adds no semantics. Lists cross the boundary as `FloatArray`s, built
  from the caller with `bf_fa_mk` and `bf_fa_push`. Array arguments are owned: each call consumes
  them, so a caller passes every array exactly once. An array returned to the caller is read with
  `bf_fa_size` and `bf_fa_get`, each consuming a reference the caller takes first, and released
  with `bf_fa_drop`.
-/

import BenefutureReference.Functions
import BenefutureReference.Goal
import BenefutureReference.Measurement
import BenefutureReference.Economy
import BenefutureReference.Domains
import BenefutureReference.Justice
import BenefutureReference.Adversarial
import BenefutureReference.Records
import BenefutureReference.ParamSpace
import BenefutureReference.Population

namespace BenefutureReference.Export

open BenefutureReference

@[export bf_fa_mk] def faMk (capacity : USize) : FloatArray := FloatArray.emptyWithCapacity capacity.toNat
@[export bf_fa_push] def faPush (a : FloatArray) (x : Float) : FloatArray := a.push x
-- Exported functions take every argument owned (a borrow annotation is not honoured on export),
-- so reading consumes a reference: the caller takes one (`lean_inc_ref`) before each read.
@[export bf_fa_size] def faSize (a : FloatArray) : USize := a.size.toUSize
@[export bf_fa_get] def faGet (a : FloatArray) (i : USize) : Float := a.data.getD i.toNat 0.0
/-- Releases an array returned to the caller: the argument is owned, so the call consumes it. -/
@[export bf_fa_drop] def faDrop (_ : FloatArray) : UInt8 := 0

private def nats (a : FloatArray) : Array Nat := a.data.map fun x => x.toUInt64.toNat

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

@[export bf_escrow_upfront] def escrowUpfront (nominal pWin : Float) : Float := (Escrow_split_ref nominal pWin).1
@[export bf_escrow_hold] def escrowHold (nominal pWin : Float) : Float := (Escrow_split_ref nominal pWin).2

@[export bf_rep_decay] def repDecay (score dt rate : Float) : Float := Rep_decay_ref score dt rate

@[export bf_resource_cost] def resourceCost (quantities unitCosts : FloatArray)
    (compute network time computeCost networkCost timeCost : Float) : Float :=
  resource_cost_ref (pairs quantities unitCosts) compute network time computeCost networkCost timeCost

@[export bf_transaction_price] def transactionPrice (cost credit pWin : Float) : Float :=
  transaction_price_ref cost credit pWin

@[export bf_supply_delta] def supplyDelta (good cost harm : Float) : Float := supply_delta_ref good cost harm

@[export bf_competition_efficiency] def competitionEfficiency (dV cost dt : Float) : Float :=
  competition_efficiency_ref dV cost dt

@[export bf_settlement] def settle (measured upfrontPaid : Float) : Float := settlement_ref measured upfrontPaid

@[export bf_profile_valid] def profileValid (shares : FloatArray) : UInt8 :=
  if profile_valid_ref shares.data then 1 else 0

@[export bf_attribute] def attributeShare (share cc contribution : Float) : Float := attribute_ref share cc contribution

@[export bf_decay_rate_for] def decayRateFor (signed lambdaPos lambdaNeg : Float) : Float :=
  decay_rate_for_ref signed lambdaPos lambdaNeg

@[export bf_classify_at] def classifyAt (dists : FloatArray) (threshold temperature : Float) (i : USize) : Float :=
  (classify_ref dists.data threshold temperature).getD i.toNat 0.0

@[export bf_accumulation_threshold] def accumulationThreshold (base factor relevance : Float) : Float :=
  accumulation_threshold_ref base factor relevance

@[export bf_overflow] def overflowExcess (balance threshold : Float) : Float := overflow_ref balance threshold

private def bools (a : FloatArray) : Array Bool := a.data.map (· > 0.5)

@[export bf_projection_membership] def projectionMembership (sig parent : FloatArray) : Float :=
  projection_membership_ref sig.data parent.data

@[export bf_classify_network] def classifyNetwork (parentMem leafDists mu : FloatArray)
    (parentThreshold muMin leafThreshold temperature : Float) : FloatArray :=
  ⟨classify_network_ref parentMem.data leafDists.data mu.data parentThreshold muMin leafThreshold temperature⟩

@[export bf_fallback_network] def fallbackNetwork (mu leafOk parentOk shares : FloatArray) : FloatArray :=
  ⟨fallback_network_ref mu.data (bools leafOk) (bools parentOk) shares.data⟩

@[export bf_aggregate_at_parent] def aggregateAtParent (muRow leafAmounts : FloatArray) : Float :=
  aggregate_at_parent_ref muRow.data leafAmounts.data

@[export bf_subsethood] def subsethood (mx my ce : FloatArray) : Float := subsethood_ref mx.data my.data ce.data

@[export bf_membership_rolling] def membershipRolling (mu mLeaf mParent rate : Float) : Float :=
  membership_rolling_ref mu mLeaf mParent rate

@[export bf_accuracy] def accuracy (score : Float) : Float := accuracy_ref score

@[export bf_credence] def credence (predicted uncertainty cap : Float) : Float := credence_ref predicted uncertainty cap
@[export bf_credence_accuracy] def credenceAccuracy (credences outcomes : FloatArray) : Float :=
  credence_accuracy_ref credences.data outcomes.data

@[export bf_currency_eligible] def currencyEligible (acc records minRecords : Float) (novel : UInt8)
    (threshold novelThreshold : Float) : UInt8 :=
  if currency_eligible_ref acc records minRecords (novel == 1) threshold novelThreshold then 1 else 0

@[export bf_relative_bar] def relativeBar (established coarse alternative : Float) : Float :=
  relative_bar_ref established coarse alternative

@[export bf_cc_share] def ccShare (part sideTotal : Float) : Float := cc_share_ref part sideTotal

@[export bf_cause_settlement] def causeSettlement (cc total upfrontPaid : Float) : Float :=
  cause_settlement_ref cc total upfrontPaid

@[export bf_carry_fee] def carryFee (makerPos accoladeRate contractShare : Float) (contracted : UInt8) : Float :=
  carry_fee_ref makerPos accoladeRate contractShare (contracted != 0)

@[export bf_shapley] def shapleyShares (n : USize) (v : FloatArray) : FloatArray := ⟨shapley_ref n.toNat v.data⟩

@[export bf_cc_assessed] def ccAssessed (confidence threshold : Float) : UInt8 :=
  if cc_assessed_ref confidence threshold then 1 else 0

@[export bf_traversal_shares] def traversalShares (netC degree : FloatArray) (decay : Float) : FloatArray :=
  ⟨traversal_shares_ref netC.data degree.data decay⟩

@[export bf_is_crime] def isCrime (informed volition breached : UInt8) : UInt8 :=
  if is_crime_ref (informed == 1) (volition == 1) (breached == 1) then 1 else 0

@[export bf_advap_reward] def advapReward (gain harm share floor : Float) : Float :=
  advap_reward_ref gain harm share floor

@[export bf_advap_liability] def advapLiability (reward auditCost : Float) : Float :=
  advap_liability_ref reward auditCost

@[export bf_report_penalty] def reportPenalty (unfounded threshold auditCost : Float) : Float :=
  report_penalty_ref unfounded threshold auditCost

@[export bf_ratchet_credence] def ratchetCredence (credence negShare : Float) : Float :=
  ratchet_credence_ref credence negShare

@[export bf_fr_permissible] def frPermissible (irreparable irreversible longterm passing timeLoss confidence : Float) : UInt8 :=
  if fr_permissible_ref irreparable irreversible longterm passing timeLoss confidence then 1 else 0

@[export bf_vote_reputation] def voteReputation (right : UInt8) (value scale voters held total : Float) : Float :=
  vote_reputation_ref (right != 0) value scale voters held total

@[export bf_audited_out] def auditedOut (rights records minRecords threshold : Float) : UInt8 :=
  if audited_out_ref rights records minRecords threshold then 1 else 0

@[export bf_source_weight] def sourceWeight (rights wrongs : Float) : Float := source_weight_ref rights wrongs

@[export bf_heard] def heard (source own : Float) (novel : UInt8) : Float := heard_ref source own (novel != 0)

@[export bf_neg_share] def negShare (gains losses : Float) : Float := neg_share_ref gains losses

@[export bf_credence_score] def credenceScore (credence outcome : Float) : Float := credence_score_ref credence outcome

@[export bf_param_count] def paramCount (_ : Unit) : USize := paramFields.length.toUSize
@[export bf_bootstrap_params] def bootstrapParams (_ : Unit) : FloatArray := ⟨bootstrap_params_ref⟩
@[export bf_admissible] def admissible (v : FloatArray) : UInt8 := if admissible_ref v.data then 1 else 0
@[export bf_perturb_step] def perturbStep (cur cand fields : FloatArray) (δ : Float) : FloatArray :=
  ⟨perturb_step_ref cur.data cand.data (fields.data.map fun x => x.toUInt64.toNat) δ⟩

@[export bf_select_candidate] def selectCandidate (means ses : FloatArray) (z : Float) : USize :=
  (select_candidate_ref means.data ses.data z).toUSize

@[export bf_escape_accept] def escapeAccept (means ses : FloatArray) (gains harms irreparable z : Float) : UInt8 :=
  if escape_accept_ref means.data ses.data gains harms irreparable.toUInt64.toNat z then 1 else 0

@[export bf_gauge_radius] def gaugeRadius (δ : Float) (harmed : UInt8) (factor : Float) : Float :=
  gauge_radius_ref δ (harmed != 0) factor

@[export bf_voting_weight] def votingWeight (base expertiseWeight : Float) (shares reps : FloatArray)
    (impactWeight impact thOptional : Float) : Float :=
  (Voting_weight_ref base expertiseWeight (pairs shares reps) impactWeight impact thOptional).1

@[export bf_vote_optional] def voteOptional (base expertiseWeight : Float) (shares reps : FloatArray)
    (impactWeight impact thOptional : Float) : UInt8 :=
  if (Voting_weight_ref base expertiseWeight (pairs shares reps) impactWeight impact thOptional).2 then 1 else 0

@[export bf_accumulate_capped] def accumulateCapped (cap cur : Float) (ws : FloatArray) : Float :=
  accumulate_capped_ref cap cur ws.data.toList

@[export bf_relative_reputation] def relativeReputation (reps : FloatArray) : FloatArray := ⟨relative_reputation_ref reps.data⟩

@[export bf_scarcity_cost] def scarcityCost (base available capacity : Float) : Float :=
  scarcity_cost_ref base available capacity

-- M7 births and deaths
@[export bf_foreclosed] def foreclosed (u h growthU growthH window : Float) : Float :=
  foreclosed_ref u h growthU growthH window

@[export bf_life_value] def lifeValue (foreclosed tierWeight scale : Float) (saved : UInt8) : Float :=
  life_value_ref foreclosed tierWeight scale (saved != 0)

@[export bf_optimistic_average] def optimisticAverage (preds : FloatArray) (q : Float) : Float :=
  optimistic_average_ref preds.data q

@[export bf_birth_level] def birthLevel (preds : FloatArray) (q confidence threshold initial : Float) : Float :=
  birth_level_ref preds.data q confidence threshold initial

@[export bf_shortfall] def shortfall (levels : FloatArray) (baseline : Float) : Float :=
  shortfall_ref levels.data baseline

@[export bf_birth_escrow] def birthEscrow (initial predicted : Float) (window : USize) (baseline : Float) : Float :=
  birth_escrow_ref initial predicted window.toNat baseline

end BenefutureReference.Export
