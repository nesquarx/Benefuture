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

  -- 2. assessment.json
  let asExPost := As_ref 10.0 2.0 7.5 15.0 10.0
  let asExAnte := As_ref 10.0 2.0 7.5 5.0 10.0
  let asJson := s!"\{\n  \"assessment_ex_post\": {asExPost},\n  \"assessment_ex_ante\": {asExAnte}\n}\n"
  IO.FS.writeFile "spec/vectors/assessment.json" asJson

  -- 3. value.json
  let vStandard := V_ref 10.0 2.0 5.0 1.0 1.0 0.4 1.0 1.0 0.5 1.1 1.5
  let vHarmDominated := V_ref 2.0 10.0 1.0 1.0 1.0 0.4 1.0 1.0 0.5 1.1 1.5
  let vJson := s!"\{\n  \"value_standard\": {vStandard},\n  \"value_harm_dominated\": {vHarmDominated}\n}\n"
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

  IO.println "Test vectors successfully emitted to spec/vectors/*.json"
