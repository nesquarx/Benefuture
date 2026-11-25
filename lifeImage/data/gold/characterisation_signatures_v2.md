# Characterisation signatures v2 (pre-registered 2026-11-25)

Written from the definitions alone (`lifeimage/generators/params.py`, `life.py`, rulings LI.36 to LI.39 and LI.50) and
committed before any image is rendered with grain restricted to claimed potential (LI.38), the anchored tone map
(LI.39) or the literature-based estimation bias (LI.50). The machine-readable twin is
`characterisation_signatures_v2.json` (same ids, deltas and directions); the battery evaluates exactly that file. A
signature is a prediction: held, not held and inconclusive are all reported, and a signature is never edited after
measurement (a revision is a new version). Version 1 (`characterisation_signatures_v1.*`) stays as it was.

Prediction, ETA, confidence: each signature states its direction, the smallest effect that matters (delta) and a
confidence; the ETA for all is the first battery run after the three changes are in.

## What changed in the image, as definitions

- Grain is the claimed-potential layer: only prediction rows (self-assessment, forecast, claim of capability) imprint
  it, red, at the level they claim. No other row makes grain.
- Everything else is solid: knowledge taken in is solid red, producing is solid green and blue, whatever the tier.
  Tier is saturation: the solid colour of a slice is blended toward its grey (the mean of its three channel levels) by
  1 - s, where s is the imprint-weighted mean of the tier saturations (measured 1.0, attested 0.85, claimed 0.5) of the
  rows that built the slice.
- The tone map `level = 1 - exp(-sum / tone_k)` has `tone_k` derived so that the median 40-year-old persona of the
  generated population has its typical touched domain at level 0.5 (absolute across people, never per person).
- The generator's estimate of a domain's expertise or impact is `truth + (1 - feedback) * (better_than_average +
  persona offset + (slope - 1) * (truth - 0.5)) + noise`, with feedback = 1 - exp(-recorded events in the domain /
  scale): large over-estimation where skill is low and feedback sparse, little where feedback is frequent, a
  better-than-average shift, under-estimation among the highly skilled. The persona offset is the calibration trait
  (over, well, under).

## Image state and features

As in version 1 (`characterisation_signatures_v1.md`) for everything not redefined here: per slice, a solid level and a
claimed-potential (grain) level per channel; displayed channel `c = 1 - (1 - s') (1 - g L_claimed)` with grain cover
g = 0.1837 and `s'` the solid level after the saturation blend; luminance y = 0.2126 R + 0.7152 G + 0.0722 B; the
v1 features (shares, `red_grain_share`, `dimmed_share`, `luminance`, `chroma`, `balance_distance`, entropies, clusters,
arcs, recency) keep their definitions.

New features (a claimed slice is a field slice whose claimed red level is at least 0.05; a is the slice area; L_c the
claimed red level; L_g the solid green level; every claimed-slice feature is undefined, and dropped, with no claimed
slice):

- `n_claimed_slices`: their count.
- `claim_gap`: sum a (L_c - L_g) / sum a: claimed potential minus demonstrated skill.
- `claim_gap_abs`: sum a |L_c - L_g| / sum a.
- `grain_green_share`: sum a L_c / (sum a L_c + sum a L_g) over the claimed slices.
- `mean_claimed_level`: the unweighted mean of L_c over the claimed slices.
- `overclaim_share`: sum a [L_c - L_g > 0.10] / sum a; `underclaim_share`: sum a [L_g - L_c > 0.10] / sum a.
- `claim_gap_low_green`: the claim_gap over the claimed slices with L_g < 0.30; `claim_gap_high_green`: over those with
  L_g >= 0.60 (undefined if none).
- `grain_cover`: sum a over field slices with L_c >= 0.05, over sum a of the field slices (0 with no claim).
- `typical_level`: the median, over touched field slices (those a row names directly, not by upstream bleed), of the
  strongest solid channel level (undefined with none).

## Rule

Version 1's rules (contrast with Welch standard error and Student-t critical value; Wilson proportions; bands) and:

- `paired`: the per-persona difference of two features `a - b` (or of `a` and a constant when `b` is a number); effect
  `s * mean(diff)`, standard error of the paired differences, Student-t at n - 1 degrees of freedom; held and not held
  as for a contrast.
- `paired_sets`: the same, for one feature over the same personas in two projections.
- `band_stat`: the mean or median of a feature, over the records of an optional subset, inside [lo, hi]: held if
  inside, not held if not (a point statistic, no interval).
- `identification`: blind identification (leave-one-out nearest centroid, features standardised on the training fold);
  a stated minimum is held if the point accuracy reaches it, not held if the Wilson 95% upper end is below it,
  inconclusive otherwise; a stated maximum the mirror image.

Populations as in version 1: primary the extended population (8 archetypes x 3 calibrations x 6 replicates = 144
generated personas, seeds and ages as in the JSON, regenerated with the version-2 generator), secondary the 40 starter
personas under truth rows, resume claims, extracted rows (three variants) and the legacy projection.

## Signatures carried unchanged from version 1

A1 to A17 (archetypes) and G1, G2 (pooled composite) keep their ids, features, directions, deltas and confidences, so
version 1 and 2 verdicts compare. Version 1's whole-image calibration signatures C1 to C7 are superseded by the
per-domain K1 to K12 below: with every taking-in row now solid red, the grainy share of all red no longer measures
calibration.

| id | prediction | feature | direction, delta | conf |
|---|---|---|---|---|
| A1 | student: little blue | share_blue | < rest, 0.05 | medium |
| A2 | student: red spread wide | red_spread_entropy | > rest, 0.03 | low |
| A3 | student: little dimmed | dimmed_share | < rest, 0.05 | high |
| A4 | shift worker: less red | share_red | < rest, 0.03 | low |
| A5 | carer: family arc dominates | arc_share:s.family | > rest, 0.05 | medium |
| A6 | carer: more blue | share_blue | > rest, 0.03 | low |
| A7 | small-business owner: work arc dominates | arc_share:s.work | > rest, 0.05 | medium |
| A8 | researcher: green and blue in science and learning arcs | gb_in:s.science+s.learning | > rest, 0.10 | medium |
| A9 | researcher: red less grainy (attested work) | red_grain_share | < rest, 0.05 | low |
| A10 | retiree: low current luminance | current_luminance | < rest, 0.05 | low |
| A11 | retiree: brighter past than present | past_over_current | > rest, 0.25 | low |
| A12 | retiree: much dimmed | dimmed_share | > rest, 0.08 | high |
| A13 | career changer: more clusters | n_clusters | > rest, 0.5 | low |
| A14 | career changer: two or more clusters in most | n_clusters >= 2 | p0 = 0.5 | low |
| A15 | career changer with two clusters: older one dimmer | cluster_age_gap < 0 | p0 = 0.6 | medium |
| A16 | generalist: spread wide | spread_entropy | > rest, 0.03 | medium |
| A17 | generalist: no dominant arc | max_arc_share | < rest, 0.04 | medium |
| G1 | pooled composite tends toward white | each channel share of the pooled composite | in [0.27, 0.40] | medium |
| G2 | pooling cancels colour | composite chroma / mean persona chroma | <= 0.5 | medium |

## New signatures: calibration, per domain

In the domains a persona claims potential in, over-estimators claim more than they have shown, under-estimators less,
and the gap is largest where the demonstrated skill is low (the Kruger and Dunning shape, with feedback shrinking it).

| id | prediction | feature | direction, delta | conf |
|---|---|---|---|---|
| K1 | over-estimators: claimed potential above demonstrated skill, more than well-calibrated | claim_gap | over > well, 0.08 | medium |
| K2 | under-estimators: claimed potential below, less than well-calibrated | claim_gap | under < well, 0.05 | low |
| K3 | the extremes separate on the gap | claim_gap | over > under, 0.15 | medium |
| K4 | over-estimators: grain is a larger share of grain plus green | grain_green_share | over > well, 0.05 | medium |
| K5 | under-estimators: grain is a smaller share | grain_green_share | under < well, 0.03 | low |
| K6 | over-estimators: higher claimed levels | mean_claimed_level | over > well, 0.03 | medium |
| K7 | under-estimators: lower claimed levels | mean_claimed_level | under < well, 0.02 | low |
| K8 | over-estimators: more of the claimed area exceeds demonstrated skill | overclaim_share | over > well, 0.10 | medium |
| K9 | under-estimators: more of the claimed area falls short of demonstrated skill | underclaim_share | under > well, 0.05 | low |
| K10 | well-calibrated: smaller absolute gap than over-estimators | claim_gap_abs | well < over, 0.05 | medium |
| K11 | well-calibrated: smaller absolute gap than under-estimators | claim_gap_abs | well < under, 0.02 | low |
| K12 | the gap is larger where demonstrated skill is low than where it is high (all personas, paired) | claim_gap_low_green - claim_gap_high_green | paired, > 0.20 | medium |
| K13 | where demonstrated skill is high, claims fall below it (all personas) | claim_gap_high_green | one sample, < 0 by 0.02 | medium |

## New signatures: whole image

| id | prediction | feature | statistic, delta | conf |
|---|---|---|---|---|
| W1 | the reference life's typical touched domain sits at mid-brightness: personas aged 36 to 44 | typical_level | median in [0.35, 0.65] | medium |
| W2 | the scale is absolute: students (thin evidence) sit dimmer than others | typical_level | student < rest, 0.05 | medium |
| W3 | an ordinary life is no longer almost black | luminance | mean over the extended population in [0.04, 0.25] | low |
| W4 | tier shows as saturation: resume-claim images are paler than truth images of the same people | chroma | paired sets, claims < truth, 0.10 | medium |
| W5 | grain needs a prediction: no starter resume-claim image carries grain | grain_cover | mean over the starter resume-claim set in [0, 0] | high |
| W6 | grain is a minor part of the red | red_grain_share | mean over the extended population in [0.05, 0.40] | low |

## Predicted blind identification (leave-one-out nearest centroid)

Features: the v1 identification features plus `typical_level`, `grain_cover`, `n_claimed_slices`, `claim_gap`,
`claim_gap_abs`, `grain_green_share`, `mean_claimed_level`, `overclaim_share` and `underclaim_share`. Version 1
measured, on truth rows, archetype 0.58 (chance 0.125) and calibration 0.31 (chance 0.333); legacy 0.56 and 0.25.

| id | set | label | prediction | basis | conf |
|---|---|---|---|---|---|
| I1 | extended truth | archetype | at least 0.60 | v1 plus a brighter, absolute scale and richer features | medium |
| I2 | extended truth | calibration | at least 0.45 (lower Wilson end above chance 0.333) | per-domain gap features and a generator that now biases claims | low |
| I3 | starter extracted rows (three variants) | archetype | at least 0.25 | claims-only rows lose the attested record; v1 0.12 to 0.28 | low |
| I4 | starter extracted rows (three variants) | calibration | at least 0.40 | extracted self-assessment rows now make grain; v1 0.53 to 0.62 was an artefact of claims-only rows | low |
| I5 | extended legacy | archetype | at most 0.62 (v1 0.56; the legacy channels do not change) | legacy tier-based layers | medium |
| I6 | extended legacy | calibration | at most 0.40 (near chance) | legacy grain is tier-based and sees no per-domain gap | low |

## Reasons, briefly

Calibration: the claim of expertise or impact in a domain is the persona's own estimate; the generator now biases it
by skill and feedback, so the gap between the grain (claim) and the green (demonstrated) in the domains claimed carries
the calibration trait, while solid layers do not depend on it. Archetype signatures follow their parameters as in
version 1. The anchor puts a regular life near mid-brightness, so luminance and the typical level become informative
across people; the tier blend shows in chroma. Known weak points a reader should expect: green is a noisy measure of
demonstrated skill (it is a tone-mapped sum of produced evidence, not the latent expertise), and feedback shrinks the
very bias the signatures look for, so K2, K5, K7, K9 and K11 may be inconclusive at 48 personas a cell.
