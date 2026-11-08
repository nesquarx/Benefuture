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
