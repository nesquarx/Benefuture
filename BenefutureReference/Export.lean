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
import BenefutureReference.Sources
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

@[export bf_tiered_value] def tieredValue (u h n : FloatArray) (alpha beta gamma haWt lambda qPlus qMinus : Float) : Float :=
  tiered_value_ref u.data.toList h.data.toList n.data.toList alpha beta gamma haWt lambda qPlus qMinus

@[export bf_tiered_value_sched] def tieredValueSched (u h n su sh sn : FloatArray)
    (alpha beta gamma haWt lambda qPlus qMinus : Float) : Float :=
  tiered_value_sched_ref u.data.toList h.data.toList n.data.toList su.data.toList sh.data.toList sn.data.toList
    alpha beta gamma haWt lambda qPlus qMinus

@[export bf_tier_schedule_at] def tierScheduleAt (which i : USize) : Float :=
  (if which == 0 then tierScheduleU_ref else if which == 1 then tierScheduleH_ref else tierScheduleN_ref).getD i.toNat 0.0

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
@[export bf_record_credence] def recordCredence (predicted : Float) (errors : FloatArray) (cap : Float) : Float :=
  record_credence_ref predicted errors.data cap
@[export bf_choice_skill] def choiceSkill (credences modelCredences outcomes : FloatArray) : Float :=
  choice_skill_ref credences.data modelCredences.data outcomes.data
@[export bf_credence_accuracy] def credenceAccuracy (credences outcomes : FloatArray) : Float :=
  credence_accuracy_ref credences.data outcomes.data

@[export bf_currency_eligible] def currencyEligible (acc records minRecords : Float) (novel : UInt8)
    (threshold novelThreshold novelFloor : Float) : UInt8 :=
  if currency_eligible_ref acc records minRecords (novel == 1) threshold novelThreshold novelFloor then 1 else 0

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

@[export bf_heard_weights] def heardWeights (sources : FloatArray) (own pNovel : Float) : FloatArray :=
  ⟨heard_weights_ref sources.data own pNovel⟩

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

@[export bf_scarcity_cost] def scarcityCost (base available capacity floorShare : Float) : Float :=
  scarcity_cost_ref base available capacity floorShare

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

-- Shapley sampling
@[export bf_shapley_sampled] def shapleySampled (n m : USize) (perms vals : FloatArray) : FloatArray :=
  ⟨shapley_sampled_ref n.toNat m.toNat perms.data vals.data⟩

@[export bf_shapley_sample_count] def shapleySampleCount (n : USize) (eps delta : Float) : USize :=
  (shapley_sample_count_ref n.toNat eps delta).toUSize

-- M3c decision market and attacks
@[export bf_explore_pick] def explorePick (u share : Float) (n : USize) : USize :=
  (explore_pick_ref u share n.toNat).toUSize

@[export bf_binding_admits] def bindingAdmits (confidences : FloatArray) (threshold : Float) (quorum : USize) : UInt8 :=
  if binding_admits_ref confidences.data threshold quorum.toNat then 1 else 0

-- M5 source tags
@[export bf_count_once] def countOnce (ids ws : FloatArray) : FloatArray := ⟨count_once_ref ids.data ws.data⟩

@[export bf_tagged_reading] def taggedReading (self own ownSide : Float) (ids sides ws : FloatArray) : Float :=
  tagged_reading_ref self own ownSide ids.data sides.data ws.data

@[export bf_tags_falsified] def tagsFalsified (claimed logged : FloatArray) : USize :=
  (tags_falsified_ref claimed.data logged.data).toUSize

@[export bf_undisclosed_echo] def undisclosedEcho (agree n aSelf aSrc margin z : Float) : UInt8 :=
  if undisclosed_echo_ref agree n aSelf aSrc margin z then 1 else 0

-- B2 identity binding weighted by attestation record
@[export bf_binding_admits_weighted] def bindingAdmitsWeighted (confidences weights : FloatArray) (threshold quorumWeight : Float) : UInt8 :=
  if binding_admits_weighted_ref confidences.data weights.data threshold quorumWeight then 1 else 0

@[export bf_class_balanced_skill] def classBalancedSkill (credences outcomes : FloatArray) : Float :=
  class_balanced_skill_ref credences.data outcomes.data

-- EHR (L117): the expected response to an external harm h
@[export bf_ehr_expected_response] def ehrExpectedResponse (alpha delta margin h rePos reNeg : Float) : Float :=
  ehr_expected_response_ref alpha delta margin h rePos reNeg

-- 8.76 the reporter's schedule
@[export bf_self_report_payout] def selfReportPayout (n e bonus : Float) : Float := self_report_payout_ref n e bonus
@[export bf_caught_charge] def caughtCharge (clawback bonus auditCost : Float) : Float := caught_charge_ref clawback bonus auditCost
@[export bf_caught_reward] def caughtReward (clawback n bonus : Float) : Float := caught_reward_ref clawback n bonus

@[export bf_false_report_charge] def falseReportCharge (harm reward auditCost : Float) : Float := false_report_charge_ref harm reward auditCost

-- 8.84 the ratchet on status bars
@[export bf_ratchet_bar] def ratchetBar (accuracies : FloatArray) (bar : Float) (k : USize) (margin : Float) : Float :=
  ratchet_bar_ref accuracies.data bar k.toNat margin

-- 8.85 time-decayed accuracy
@[export bf_decay_halflife] def decayHalflife (rate refRate refHalflife mute : Float) : Float :=
  decay_halflife_ref rate refRate refHalflife mute
@[export bf_decayed_accuracy] def decayedAccuracy (credences outcomes ages : FloatArray) (h : Float) : Float :=
  decayed_accuracy_ref credences.data outcomes.data ages.data h
@[export bf_decayed_mean_se] def decayedMeanSe (xs ages : FloatArray) (h : Float) : FloatArray :=
  ⟨decayed_mean_se_ref xs.data ages.data h⟩

@[export bf_decayed_record_credence] def decayedRecordCredence (predicted : Float) (errors ages : FloatArray) (h cap : Float) : Float :=
  decayed_record_credence_ref predicted errors.data ages.data h cap

@[export bf_decayed_rms] def decayedRms (errors ages : FloatArray) (halflife : Float) : Float :=
  decayed_rms_ref errors.data ages.data halflife

@[export bf_accession_admissible] def accessionAdmissible (dScope dMinU dMinH dMaxU : Float) (existingDeltaU existingDeltaH : FloatArray) : UInt8 :=
  if accession_admissible_ref dScope dMinU dMinH dMaxU existingDeltaU.data existingDeltaH.data then 1 else 0

@[export bf_ha_wt_params] def haWtParams (severities weights : FloatArray) (lambda kappa qHarm : Float) : Float :=
  HaWt_params_ref (pairs severities weights) lambda kappa qHarm

@[export bf_fr_permissible_params] def frPermissibleParams (irreparable irreversible longterm passing timeLoss confidence thConf thHigh sIrr sIrv sLt sPass sTime : Float) : UInt8 :=
  if fr_permissible_params_ref irreparable irreversible longterm passing timeLoss confidence thConf thHigh sIrr sIrv sLt sPass sTime then 1 else 0

@[export bf_pinball_loss] def pinballLoss (q predicted outcome : Float) : Float :=
  pinball_loss_ref q predicted outcome

@[export bf_quantile_score] def quantileScore (quantiles predictions outcomes : FloatArray) (scale : Float) : Float :=
  quantile_score_ref quantiles.data predictions.data outcomes.data scale

@[export bf_persistence] def persistence (significance : FloatArray) (z : Float) : UInt32 :=
  (persistence_ref significance.data z).toUInt32

@[export bf_escalated_credence] def escalatedCredence (credence negShare persistence growth cap : Float) : Float :=
  escalated_credence_ref credence negShare persistence.toUInt64.toNat growth cap

-- 8.87 decision replay: scenario pricing from as-of records
@[export bf_event_rate] def eventRate (k n : Float) : Float := event_rate_ref k n
@[export bf_pooled_probability] def pooledProbability (probs weights : FloatArray) : Float :=
  pooled_probability_ref probs.data weights.data
@[export bf_lt_offset_admissible] def ltOffsetAdmissible (du dh base_h : Float) (nha : UInt8) (retention compounding offset_scale soft_bar : Float) : UInt8 :=
  if lt_offset_admissible_ref du dh base_h (nha != 0) retention compounding offset_scale soft_bar then 1 else 0

@[export bf_irreparable_equivalent] def irreparableEquivalent (deaths du pop base_u base_h compounding persistence : Float) : Float :=
  irreparable_equivalent_ref deaths du pop base_u base_h compounding persistence

@[export bf_irreparable_blocked] def irreparableBlocked (harm least tol : Float) (nha : UInt8) : UInt8 :=
  if irreparable_blocked_ref harm least tol (nha != 0) then 1 else 0

@[export bf_cfd_ballot_weight] def cfdBallotWeight (vw calibration logodds cap : Float) : Float :=
  cfd_ballot_weight_ref vw calibration logodds cap

@[export bf_env_health_blocked] def envHealthBlocked (harm least tol : Float) (nha : UInt8) : UInt8 :=
  if env_health_blocked_ref harm least tol (nha != 0) then 1 else 0

@[export bf_acyclic] def acyclicE (adj : FloatArray) (n : USize) : UInt8 := if acyclic_ref adj.data n.toNat then 1 else 0

@[export bf_pooled_reading] def pooledReading (values credences overlap : FloatArray) : FloatArray :=
  ⟨pooled_reading_ref values.data credences.data overlap.data⟩

@[export bf_chains_diverge] def chainsDiverge (values ses : FloatArray) (z : Float) : UInt8 :=
  if chains_diverge_ref values.data ses.data z then 1 else 0

@[export bf_relative_accuracy] def relativeAccuracy (credences outcomes : FloatArray) : Float :=
  relative_accuracy_ref credences.data outcomes.data

@[export bf_pragmatic_understanding] def pragmaticUnderstanding (mapFit : Float) (wt ce acc cy : FloatArray) (th : Float) : Float :=
  pragmatic_understanding_ref mapFit wt.data ce.data acc.data cy.data th

@[export bf_expected_effect] def expectedEffect (probs effects : FloatArray) : Float :=
  expected_effect_ref probs.data effects.data

-- 8.91 ruling: escrow exponential in discovered repeats
@[export bf_repeat_escrow_credence] def repeatEscrowCredence (credence negShare : Float) (repeats : USize) (growth floorC : Float) : Float :=
  repeat_escrow_credence_ref credence negShare repeats.toNat growth floorC

end BenefutureReference.Export
