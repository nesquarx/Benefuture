# E4 round 2: edge cases for the rules (REPLAY_PREREG §4.7)

Each case is built from as-of sources, committed, then replayed; the builders know the outcomes (these cases
strengthen the rules; E5 tests them). Per case: Benefuture's choice, its cell, the D5 baselines, the rule-set
battery, the credence across joint magnitude jitter × rule sets, and the single-magnitude flips.

## unamir_drawdown_1994 (Resolution 912, 21 April 1994; class bad)

- **Benefuture:** reinforce to about 5,000 with a Chapter VII mandate to protect civilians (compensated): differs from the bad decision (cell bad/differs).
- **Baselines:** fewest deaths and mean welfare also reinforce; status quo and equal-weight keep 2,500; the institution reduced to 270.
- **Robustness:** reinforce in 11 of 16 rule sets (keep 2,500 in the coarse sets without the policy-level irreparable block); credence keep 2,500 55%, reinforce 41%, reduce 3%; 3 single-magnitude flips. Contested: under joint magnitude uncertainty keeping the mission at strength edges out reinforcement, while reduction, the actual choice, is almost never chosen.
- **What it rests on:** dated trials from earlier missions (reductions followed by escalation 3 of 3; weak-mandate missions failing to stop killing 3 of 4; strong missions containing violence 3 of 4), recalled; the 500 thousand unchecked and 100 thousand contained magnitudes are judgment as of the date.
- **For the held E5 peacekeeping cases:** the direction (strength and mandate matter) agrees with Hultman, Kathman and Shannon's abstracts; their effect sizes are still to be read.

## Swine flu vaccination, 24 March 1976 (case committed before replay)

- Benefuture: vaccinate everyone, compensated. Cell bad/agrees: the actual choice matched, and the outcome was bad (no pandemic, Guillain-Barré cases, programme halted in December). Falsifiers F1–F4 all false.
- Baselines: status quo stockpile; minimum deaths, mean welfare, equal weight all vaccinate.
- Rule battery (16 sets): vaccinate 69%, stockpile 31%.
- Credence (20 draws × 16 sets): vaccinate 64%, stockpile 30%, do nothing 6%.
- Sensitivity flips (2), both to stockpile: halving the late-vaccine pandemic's deaths, or doubling the deaths that remain after mass vaccination.
- Reading: with base rates of 3 pandemics in 4 novel-strain trials (selection-biased: fizzled outbreaks are under-recorded) and zero adverse signals in 3 prior campaigns, the rules agree with the decision that was made. The error lies in the inputs, not the rules: the pandemic base rate is taken from the recorded strains only, and the case has no trial for "a strain found in one outbreak that never spreads beyond it". A Benefuture with an adversarial base-rate check (E4 strengthening item, parked) would have priced Fort Dix's lack of spread; stockpiling then wins (first flip). The first result stands.

## DDT cancellation, 14 June 1972 (case committed before replay)

First result (replay code before the fix below; it stands):
- Benefuture: cancel agricultural uses, compensated. Cell good/agrees; F1–F4 false.
- Baselines: status quo keep; minimum deaths and equal weight cancel; mean welfare phase down.
- Rule battery: cancel 75%, keep 25%. Credence (20 draws): keep 70%, cancel 29%, phase down 1%.
- Sensitivity: halving the phase-down's residual harm flipped the choice to keeping DDT. That was non-monotone, and it exposed a defect.

Defect (the sim did what Benefuture would not): the environmental block (8.118) and the irreparable block (8.124) each measure against their own least option. With the phase-down least in environmental harm and cancellation least in deaths, each block excluded the other's least option, and both excluded keeping DDT. With nothing allowed, the fallback chose inaction by default, the one option blocked under both rules. Inaction has no default privilege (8.47). Fix (8.127, ruled by the author 2026-11-08): when every option is blocked, choose the option whose blocked harms exceed their leasts least, each excess relative to its least, summed. Loud. Red test first.

After the fix and precision-set draws (8.128):
- Rule battery: cancel 75%, phase down 12.5%, keep 12.5%. Credence (280 draws): cancel 59%, phase down 23%, keep 18%. Sensitivity flips (2), both now to phase down.
- Reading: the rules agree with the decision, which was good. The human-harm base rate (2 of 4) borrows from high-dose poisonings (Minamata, Yusho), so it is generous to cancellation; the farmworker cost of substitutes is what keeps phase-down in play.

## Credences restated by precision (8.128)

Credences were drawn from a habitual 40 jitter draws, and the FOMC case's cut share moved 13 points between seeds. Draws are now added in batches of 20 until every share's t-inflated standard error is at most 0.02. The first results stand above; the restated ones:
- UNAMIR 1994: reinforce 57%, keep 2,500 40%, reduce 3% (180 draws; first: keep 55%, reinforce 41%). The top pick flips to the reinforcement the rules choose.
- Swine flu 1976: vaccinate 64%, stockpile 34%, do nothing 2% (280 draws; unchanged in substance).
- School closures 2020 (round 1): keep open 53%, close with remote learning 30%, close three weeks 9%, close statewide 8% (200 draws; first: keep open 44%).

## German nuclear phase-out, June 2011 (case committed before replay)

- Benefuture: keep the 2010 extension. Cell bad/differs: it avoids the decision that went badly. F1–F4 false. Reached through the all-blocked fallback (8.127): the environmental block's least option is the phase-out (a severe accident's nationwide happiness loss, −0.5 points on a 0.21 fleet-decade rate, outweighs the fossil replacement's air-pollution deaths in person-points), the irreparable block's least option is keeping the fleet (0.6 against 8.2 thousand expected deaths), so every option is blocked and keeping the fleet has the least relative excess.
- Baselines: status quo and minimum deaths keep; mean welfare and equal weight close the oldest eight only.
- Rule battery: keep 69%, close oldest eight 25%, phase out 6%. Credence (80 draws): keep 76%, phase out 12.5%, close oldest eight 11%. No single-magnitude flips.
- Defect found and fixed (same day, before this record): environmental health harm counted only understanding and happiness losses, not deaths, so the air-pollution deaths were invisible to the environmental block. Deaths now count at their group's baseline understanding plus happiness (a death takes both to zero). The result above is unchanged by the fix (same choice, battery and flips). Red test first (synthetic: environmental block alone, deaths without happiness loss).
- Reading: the rules favour keeping the fleet on deaths, but the environmental block, as the case prices it, prefers the phase-out. That is the judged accident happiness loss doing the work. A nationwide lasting −0.5 is large (about 330 thousand death-equivalents in person-points); the magnitude stands as built.

## Sri Lanka fertiliser import ban, April 2021 (case committed before replay)

First result (8.127 fallback as first built; it stands):
- Benefuture: ban imports now. Cell bad/agrees: it repeated the decision that went badly. F1–F4 false. All-blocked fallback: the environmental block's least option is the ban (least CKDu exposure if agrochemicals drive it), the irreparable block's least option is the phased transition, so everything is blocked and the ban had the least relative excess.
- Baselines: status quo and mean welfare keep imports; minimum deaths phased; equal weight ban.
- Rule battery: ban 75%, keep 25%. Credence (140 draws): ban 68%, keep 22%, phased 10%.

Defect: the fallback weighed only the blocks' excesses, so harms that neither block sees, here the ban's expected yield collapse (farm happiness −3 at probability 0.8), were left out. The author's ruling on 8.127 was "trolley rules", and the trolley ruling (8.124) compares net expected harm. Fixed: when every option is blocked, the choice is the least net expected harm over all scenarios, in one unit (losses of understanding and happiness in person-points, plus deaths at their group's baseline understanding plus happiness); ties go to value. Loud. Red test first.

## Round 2 under the corrected fallback (all first results above stand)

| Case | Choice | Cell | Rule battery | Credence (draws) | Flips |
|---|---|---|---|---|---|
| UNAMIR 1994 | reinforce, compensated | bad/differs | reinforce 69% | reinforce 65%, keep 35% (60) | 2 |
| Swine flu 1976 | vaccinate, compensated | bad/agrees | vaccinate 69% | vaccinate 75%, stockpile 25% (120) | 1 |
| DDT 1972 | cancel, compensated | good/agrees | cancel 75% | phase down 37%, cancel 32%, keep 31% (320) | 4, all to phase down |
| German nuclear 2011 | close oldest eight only | bad/differs | close eight 94% | keep 41%, close eight 38%, phase out 21% (540) | 7 |
| Sri Lanka 2021 | keep imports | bad/differs | keep 94% | keep 62%, ban 30%, phased 7% (320) | 7 |

Reading: DDT, German nuclear and Sri Lanka are contested (many single-magnitude flips; credence split), so none counts as a win. Swine flu repeats the bad decision on as-of base rates. Only UNAMIR is robust and right. The E5 suggestions are unchanged by the fix (`docs/E5_RUNS.md`).

## All E4 and E5 cases re-read with priority tiers (8.129, 2026-11-08)

The replay now values each group's changes through the priority tiers (Lean `tiered_value_ref`); the collapsed
scalar reading stays in the rule battery as a seventeenth set. Each case declares its groups' kinds (`[tiers]`:
education as teachable and meta understanding, developing children's learning capacity as meta and floor,
targeted and poorest groups at the floor and happiness baseline, incomes and jobs as satisficing happiness,
science communities as peak and teachable). The kinds were declared after the outcomes were known for E4 cases,
so the re-read is hindsight-exposed; first results stand. Credences by precision (8.128).

| Case | Choice | Cell | Credence (top three) |
|---|---|---|---|
| bengal_denial_1942 | no_denial_preserve_stocks | bad/differs | no_denial_preserve_stocks 100% |
| bengal_famine_relief_1943 | approve_emergency_grain_shipments+compensated | bad/differs | approve_emergency_grain_shipments 60%, token_shipment_150k_tons 35%, reject_emergency_grain_shipments 5% |
| challenger_1986 | delay_until_53F | bad/differs | delay_until_53F 100% |
| ddt_ban_1972 | cancel_agricultural_uses+compensated | good/agrees | phase_down_keep_essential 38%, cancel_agricultural_uses 32%, keep_registration 29% |
| famine_codes_1880 | adopt_famine_code+compensated | good/agrees | adopt_famine_code 100% |
| fda_beta_blockers_1975 | approve_secondary_prevention | bad/differs | approve_secondary_prevention 100% |
| fomc_september_2008 | cut_50bp | unclear/differs | cut_50bp 60%, hold_at_2_percent 40% |
| german_nuclear_phaseout_2011 | close_oldest_eight_only | bad/differs | keep_2010_extension 42%, close_oldest_eight_only 38%, phase_out_by_2022 21% |
| leaded_petrol_phaseout_1973 | phase_down_total_pool_average_1975_1979+compensated | good/agrees | phase_down_total_pool_average_1975_1979 36%, status_quo_lead_free_availability_only 33%, phase_down_leaded_grade_only_schedule_reproposed 31% |
| montreal_protocol_1987 | adopt_cfc_phase_down+compensated | good/agrees | adopt_cfc_phase_down 100% |
| no_child_left_behind_2002 | reporting_and_flexibility_without_sanctions | unclear/differs | reporting_and_flexibility_without_sanctions 99%, sign_nclb 1% |
| printing_press_europe_1470 | grant_privileges_to_master_printers+compensated | good/agrees | status_quo_scribal_trade_only 94%, grant_privileges_to_master_printers 6% |
| ragusa_quarantine_1377 | enact_30_day_isolation | good/agrees | enact_30_day_isolation 100% |
| school_closures_2020 | close_with_remote_learning | unclear/differs | keep_schools_open 47%, close_with_remote_learning 27%, close_three_weeks 14% |
| semmelweis_vienna_1847 | retain_handwashing_protocol | bad/differs | retain_handwashing_protocol 100% |
| snow_broad_street_1854 | remove_pump_handle | good/agrees | remove_pump_handle 96%, no_intervention_continue_pump 4% |
| sri_lanka_fertiliser_ban_2021 | keep_imports | bad/differs | keep_imports 62%, ban_imports_now 30%, phased_transition 8% |
| swine_flu_vaccination_1976 | vaccinate_everyone+compensated | bad/agrees | vaccinate_everyone 81%, stockpile_and_watch 19%, do_nothing 0% |
| thalidomide_fda_1960 | withhold_approval_pending_safety | good/agrees | withhold_approval_pending_safety 100% |
| uk_bse_feed_ban_1988 | total_ban_and_stock_recall | unclear/differs | total_ban_and_stock_recall 95%, partial_ban_with_stock_drawdown 5% |
| unamir_drawdown_1994 | reinforce_5000_chapter_vii+compensated | bad/differs | reinforce_5000_chapter_vii 67%, maintain_2500 32%, reduce_to_270 1% |
| volcker_disinflation_1979 | reserve_targeting | good/agrees | incomes_policy 51%, reserve_targeting 45%, continue_funds_rate_pegging 4% |
| fda_zrostudirsen_2027 | complete_response_wait | pending/differs | complete_response_wait 95%, accelerated_approval_with_confirmatory_trial 5% |
| fomc_january_2027 | cut_25bp | pending/differs | cut_25bp 62%, hold 34%, hike_25bp 4% |
| imo_net_zero_framework_2026 | adopt_with_pricing+compensated | pending/differs | adopt_with_pricing 77%, adjourn_again 22%, adopt_without_pricing 1% |
| who_pabs_annex_2027 | adopt_binding_benefit_sharing_annex+compensated | pending/differs | adopt_binding_benefit_sharing_annex 74%, extend_negotiations_no_annex 26% |

Reading: no choice changes, and credences move by at most five points. The kinds belong to groups, so every option
in a case carries the same ones, and the tiers mostly rescale. Priorities bite where options differ in the kind of
change they make for the same group (a reform yielding teachable against tacit understanding, or eudaimonic against
raw happiness), and few of these cases pose that contrast; many choices are also settled by the floors and blocks
before value. Next: option-level kinds where a case's options genuinely differ in kind (school closures with remote
learning against without; printing against scribal copying; research programmes), declared from as-of sources,
and new E4 and E5 candidates chosen where the contrast is the decision.

### Option-level kinds (8.129, 2026-11-08; as-of bases stated in the case files)

- NCLB 2002: sanction-driven gains declared narrow (median and floor, little teachable or meta; as-of basis:
  score inflation under high-stakes testing, Koretz and others on Kentucky's KIRIS in the 1990s); reporting
  without sanctions declared broader. Choice unchanged: reporting and flexibility, 100% of rule sets and credence.
- Printing 1470: scribal gains declared less teachable (copies scarce and variant). Choice unchanged: printers'
  privileges, compensated; rule battery and credence 94% for the scribal status quo (as before).
- School closures 2020: no as-of basis found to split closure's loss differently from remote learning's by
  kind, so nothing declared.

Reading: where options differ in kind here, they also differ in magnitude by far more, and magnitude decides.
Priorities should decide cases where options are close in size but differ in kind; such cases are the next E4
and E5 candidates (research funding against applied programmes, teaching reforms against test regimes).

## Smallpox eradication, May 1966 / January 1967 (case committed before replay; tiers declared before replay)

- Benefuture: intensified global eradication, compensated (donors' cost restored from the gains). Cell good/agrees; F1–F4 false.
- Baselines: status quo continues national control; minimum deaths, mean welfare and equal weight all eradicate.
- Rule battery (17 sets): eradicate 100%. Credence (540 draws): eradicate 68%, regional elimination of accessible areas first 32%, continued control 1%.
- Sensitivity flips (2), both to regional elimination (halving the gap between the campaign's success and failure tolls).
- Reading: an easy case on the record of the time: three of five elimination attempts had succeeded where tried, and the toll of continued control dwarfed the cost. The rules agree with a decision that went well; simple rules agree too, so it does not separate Benefuture from them. Not a contrast case for priorities (all options differ in size, not kind).
