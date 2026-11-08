# E5 run log

One row per case per run (REPLAY_PREREG §8, lifecycle); rows are appended, never edited.

| Date | Commit | Code hash | Case | Suggestion | Rule-set battery | Magnitude flips |
|---|---|---|---|---|---|---|
| 2026-11-07 | 03f42de | 4cd84c35fa6b69ed | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 92%, hold 8% | 8 |
| 2026-11-07 | 03f42de | 4cd84c35fa6b69ed | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 4 |
| 2026-11-07 | a12123a | 4cd84c35fa6b69ed | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 92%, accelerated_approval_with_confirmatory_trial 8% | 0 |
| 2026-11-07 | a12123a | 4cd84c35fa6b69ed | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 92%, hold 8% | 8 |
| 2026-11-07 | a12123a | 4cd84c35fa6b69ed | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 4 |
| 2026-11-07 | 2d9ecfa | 3a32b9a683038e8f | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 92%, accelerated_approval_with_confirmatory_trial 8% | 0 |
| 2026-11-07 | 2d9ecfa | 3a32b9a683038e8f | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 92%, hold 8% | 8 |
| 2026-11-07 | 2d9ecfa | 3a32b9a683038e8f | imo_net_zero_framework_2026 | adopt_with_pricing (compensated) | adopt_with_pricing 69%, adjourn_again 31% | 0 |
| 2026-11-07 | 2d9ecfa | 3a32b9a683038e8f | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 4 |

From 2026-11-07 (later the same day) rows carry an eighth column: Benefuture's credence across joint magnitude jitter (log-normal, σ = ln 2 / 2) × the 13 rule sets (`replay_credence`).
| 2026-11-07 | a2eaa4e | a3a05d1f9f09f396 | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 92%, accelerated_approval_with_confirmatory_trial 8% | 0 | complete_response_wait 95%, accelerated_approval_with_confirmatory_trial 5% |
| 2026-11-07 | a2eaa4e | a3a05d1f9f09f396 | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 92%, hold 8% | 8 | hold 58%, cut_25bp 38%, hike_25bp 4% |
| 2026-11-07 | a2eaa4e | a3a05d1f9f09f396 | imo_net_zero_framework_2026 | adopt_with_pricing (compensated) | adopt_with_pricing 69%, adjourn_again 31% | 0 | adopt_with_pricing 77%, adjourn_again 23% |
| 2026-11-07 | a2eaa4e | a3a05d1f9f09f396 | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 4 | extend_negotiations_no_annex 56%, adopt_binding_benefit_sharing_annex 44% |
| 2026-11-07 | 4e70ef2 | a980f17f9aa16010 | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 93%, accelerated_approval_with_confirmatory_trial 7% | 0 | complete_response_wait 95%, accelerated_approval_with_confirmatory_trial 5% |
| 2026-11-07 | 4e70ef2 | a980f17f9aa16010 | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 93%, hold 7% | 8 | hold 58%, cut_25bp 38%, hike_25bp 4% |
| 2026-11-07 | 4e70ef2 | a980f17f9aa16010 | imo_net_zero_framework_2026 | adopt_with_pricing (compensated) | adopt_with_pricing 71%, adjourn_again 29% | 0 | adopt_with_pricing 79%, adjourn_again 21% |
| 2026-11-07 | 4e70ef2 | a980f17f9aa16010 | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 2 | adopt_binding_benefit_sharing_annex 57%, extend_negotiations_no_annex 43% |
| 2026-11-07 | 4edfebf | a79526ed7e3b80bb | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 93%, accelerated_approval_with_confirmatory_trial 7% | 0 | complete_response_wait 95%, accelerated_approval_with_confirmatory_trial 5% |
| 2026-11-07 | 4edfebf | a79526ed7e3b80bb | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 93%, hold 7% | 4 | cut_25bp 54%, hold 40%, hike_25bp 6% |
| 2026-11-07 | 4edfebf | a79526ed7e3b80bb | imo_net_zero_framework_2026 | adopt_with_pricing (compensated) | adopt_with_pricing 71%, adjourn_again 29% | 0 | adopt_with_pricing 79%, adjourn_again 21% |
| 2026-11-07 | 4edfebf | a79526ed7e3b80bb | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 4 | adopt_binding_benefit_sharing_annex 55%, extend_negotiations_no_annex 45% |
| 2026-11-08 | b31d05f | 449a7ee8f58764a3 | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 94%, accelerated_approval_with_confirmatory_trial 6% | 0 | complete_response_wait 96%, accelerated_approval_with_confirmatory_trial 4% |
| 2026-11-08 | b31d05f | 449a7ee8f58764a3 | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 94%, hold 6% | 4 | cut_25bp 55%, hold 39%, hike_25bp 6% |
| 2026-11-08 | b31d05f | 449a7ee8f58764a3 | imo_net_zero_framework_2026 | adopt_with_pricing (compensated) | adopt_with_pricing 75%, adjourn_again 25% | 0 | adopt_with_pricing 82%, adjourn_again 18% |
| 2026-11-08 | b31d05f | 449a7ee8f58764a3 | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 2 | adopt_binding_benefit_sharing_annex 58%, extend_negotiations_no_annex 42% |
| 2026-11-08 | 9e613ab | deaf38221ff149a8 | fda_zrostudirsen_2027 | complete_response_wait | complete_response_wait 94%, accelerated_approval_with_confirmatory_trial 6% | 0 | complete_response_wait 96%, accelerated_approval_with_confirmatory_trial 4% |
| 2026-11-08 | 9e613ab | deaf38221ff149a8 | fomc_january_2027 | cut_25bp (compensated) | cut_25bp 94%, hold 6% | 4 | cut_25bp 49%, hold 45%, hike_25bp 6% |
| 2026-11-08 | 9e613ab | deaf38221ff149a8 | imo_net_zero_framework_2026 | adopt_with_pricing (compensated) | adopt_with_pricing 75%, adjourn_again 25% | 0 | adopt_with_pricing 82%, adjourn_again 18% |
| 2026-11-08 | 9e613ab | deaf38221ff149a8 | who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex (compensated) | adopt_binding_benefit_sharing_annex 100% | 2 | adopt_binding_benefit_sharing_annex 55%, extend_negotiations_no_annex 45% |
