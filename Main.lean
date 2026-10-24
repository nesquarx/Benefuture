import BenefutureReference

open BenefutureReference

def main : IO Unit := do
  IO.FS.createDirAll "spec/vectors"
  
  -- 1. synergy.json
  let synPos := Sy_ref [(10.0, 1.0), (5.0, 0.5)] [] 1.0 0.5 1.1 1.5
  let synNeg := Sy_ref [] [(10.0, 1.0), (5.0, 0.5)] 1.0 0.5 1.1 1.5
  let synEqual := Sy_ref [(10.0, 1.0)] [(10.0, 1.0)] 1.0 0.5 1.1 1.5
  let synZero := Sy_ref [] [] 1.0 0.5 1.1 1.5
  let synSingle := Sy_ref [(10.0, 1.0)] [] 1.0 0.5 1.1 1.5
  let syHatPos := Sy_hat_ref 10.0 1.0 5.0
  let syHatNeg := Sy_hat_ref (-10.0) 1.0 5.0
  let syHatZero := Sy_hat_ref 0.0 1.0 5.0
  
  let synJson := s!"\{\n  \"synergy_positive\": {synPos},\n  \"synergy_negative\": {synNeg},\n  \"synergy_equal_cancellation\": {synEqual},\n  \"synergy_zero\": {synZero},\n  \"synergy_single\": {synSingle},\n  \"squashed_synergy_pos\": {syHatPos},\n  \"squashed_synergy_neg\": {syHatNeg},\n  \"squashed_synergy_zero\": {syHatZero}\n}\n"
  IO.FS.writeFile "spec/vectors/synergy.json" synJson

  -- 2. assessment.json (L48: ((t ≤ t0 ? Pr : Me) - Pr_counter) / Th_Cx)
  let asExPost := As_ref 10.0 2.0 7.5 15.0 10.0 2.0
  let asExAnte := As_ref 10.0 2.0 7.5 5.0 10.0 2.0
  let asJson := s!"\{\n  \"inputs\": \{\"predicted\": 10.0, \"counter\": 2.0, \"measured\": 7.5, \"t0\": 10.0, \"th_cx\": 2.0},\n  \"assessment_ex_post_t15\": {asExPost},\n  \"assessment_ex_ante_t5\": {asExAnte}\n}\n"
  IO.FS.writeFile "spec/vectors/assessment.json" asJson

  -- 3. value.json (defaultGovParams: α=0.8, β=0.6, γ=0.4, λ=0.5, q₊=1.1, q₋=1.5; κ=2 for V)
  let haTiers : List (Float × Float) := [0.0, 0.0, 1.0, 2.0, 0.0, 0.0, 0.0].zip harmSchedule_ref
  let haWt := HaWt_ref haTiers 0.5
  let vGains := V_ref 2.0 1.5 1.2 0.8 0.6 0.4 haWt 0.5 1.1 1.5
  let vULoss := V_ref (-2.0) 1.5 1.2 0.8 0.6 0.4 haWt 0.5 1.1 1.5
  let vULossNoHarm := V_ref (-2.0) 1.5 1.2 0.8 0.6 0.4 1.0 0.5 1.1 1.5
  let vJson := s!"\{\n  \"harm_tier_magnitudes\": [0.0, 0.0, 1.0, 2.0, 0.0, 0.0, 0.0],\n  \"harm_schedule\": [0.9, 0.7, 0.45, 0.15, 0.08, 0.04, 0.01],\n  \"harm_weight\": {haWt},\n  \"value_all_gains\": {vGains},\n  \"value_u_loss\": {vULoss},\n  \"value_u_loss_unit_harm_weight\": {vULossNoHarm}\n}\n"
  IO.FS.writeFile "spec/vectors/value.json" vJson

  -- 4. escrow.json
  let (up1, hold1, over1) := Escrow_split_ref 1000.0 0.7 0.05
  let (up2, hold2, over2) := Escrow_split_ref 500.0 0.5 0.10
  let escJson := s!"\{\n  \"case_70_win\": \{\n    \"nominal\": 1000.0,\n    \"upfront\": {up1},\n    \"hold\": {hold1},\n    \"overhead\": {over1}\n  },\n  \"case_50_win\": \{\n    \"nominal\": 500.0,\n    \"upfront\": {up2},\n    \"hold\": {hold2},\n    \"overhead\": {over2}\n  }\n}\n"
  IO.FS.writeFile "spec/vectors/escrow.json" escJson

  -- 5. reputation.json
  let repDecay1 := Rep_decay_ref 100.0 10.0 0.05
  let repDecay2 := Rep_decay_ref repDecay1 10.0 0.05
  let repDecayDirect := Rep_decay_ref 100.0 20.0 0.05
  let repJson := s!"\{\n  \"decay_step1\": {repDecay1},\n  \"decay_step2\": {repDecay2},\n  \"decay_direct_20\": {repDecayDirect},\n  \"transitivity_gap\": {repDecay2 - repDecayDirect}\n}\n"
  IO.FS.writeFile "spec/vectors/reputation.json" repJson

  -- 6. democracy.json
  let vwBase := Voting_weight_ref 1000.0 250.0 100.0
  let ehrFull := EHR_attenuate_ref 100.0 1.0
  let ehrHalf := EHR_attenuate_ref 100.0 0.5
  let ehrNone := EHR_attenuate_ref 100.0 0.0
  let demJson := s!"\{\n  \"voting_weight_profile\": {vwBase},\n  \"ehr_full_attenuation\": {ehrFull},\n  \"ehr_half_attenuation\": {ehrHalf},\n  \"ehr_zero_attenuation\": {ehrNone}\n}\n"
  IO.FS.writeFile "spec/vectors/democracy.json" demJson

  -- 7. population.json (Benefuture.Proposed.PopulationDirection)
  let p0 : List Float := [2.0, 6.0, 8.0, 9.0, 10.0]
  let p1 : List Float := [0.0, 6.0, 8.0, 9.0, 10.0]
  let fronts := pareto_front_ref [[1.0, 1.0], [0.5, 1.0], [2.0, 0.0], [0.0, 0.0]]
  let popJson := s!"\{\n  \"skew_key_before\": {skew_key_ref p0},\n  \"skew_key_after_lowering_min\": {skew_key_ref p1},\n  \"novelty_copies_5\": {population_novelty_ref [] [7, 7, 7, 7, 7]},\n  \"novelty_distinct_5\": {population_novelty_ref [] [1, 2, 3, 4, 5]},\n  \"novelty_with_history\": {population_novelty_ref [1, 1, 2] [1, 2, 3]},\n  \"effective_types_mixed\": {effective_types_ref [1, 1, 2, 3, 3, 3]},\n  \"pareto_front_indices\": {fronts},\n  \"delegation_capped_cap100_w10x30\": {accumulate_capped_ref 100.0 0.0 (List.replicate 30 10.0)}\n}\n"
  IO.FS.writeFile "spec/vectors/population.json" popJson

  -- 8. freedom.json (L135, author's reading; defaults thConf = 0.9, thHigh = 1)
  let frJson := s!"\{\n  \"mild_passing_50pct\": {fr_permissible_ref 0.0 0.0 0.0 1.0 0.0 0.5},\n  \"speculative_irreparable_1pct\": {fr_permissible_ref 1.0 0.0 0.0 0.0 0.0 0.01},\n  \"remote_irreversible_0_1pct\": {fr_permissible_ref 0.0 1.0 0.0 0.0 0.0 0.001},\n  \"certain_longterm\": {fr_permissible_ref 0.0 0.0 1.0 0.0 0.0 1.0},\n  \"experiential_variety_repetitive_4\": {experiential_variety_ref [3, 3, 3, 3]},\n  \"experiential_variety_varied_4\": {experiential_variety_ref [1, 2, 3, 3]}\n}\n"
  IO.FS.writeFile "spec/vectors/freedom.json" frJson

  -- 9. harm.json (L54: U-harm below running max, H-harm below rolling average; L37 H score)
  let hJson := s!"\{\n  \"h_harm_coming_down_window_1115_to_2\": {h_harm_ref [1.0, 1.0, 1.0, 5.0] 2.0},\n  \"h_harm_below_average_window_1115_to_1\": {h_harm_ref [1.0, 1.0, 1.0, 5.0] 1.0},\n  \"u_harm_forgetting_hist_358_to_6\": {u_harm_ref [3.0, 5.0, 8.0] 6.0},\n  \"u_harm_at_max_hist_358_to_8\": {u_harm_ref [3.0, 5.0, 8.0] 8.0},\n  \"happiness_sources\": \"(intensity, bias degree, MM confidence): conversation (2, 0, 0), malicious (5, 1, 1), doom-scroll (3, 0.5, 0.8), stupor (4, 0.8, 0.9)\",\n  \"happiness_score_mixed_di_0_5\": {happiness_score_ref [(2.0, 0.0, 0.0), (5.0, 1.0, 1.0), (3.0, 0.5, 0.8), (4.0, 0.8, 0.9)] 0.5}\n}\n"
  IO.FS.writeFile "spec/vectors/harm.json" hJson

  IO.println "Test vectors successfully emitted to spec/vectors/*.json"
