# Characterisation signatures v1 (pre-registered 2026-11-25)

Written from the archetype and calibration definitions (`lifeimage/generators/params.py`, `life.py`) and rulings LI.36
(levels) and LI.37 (channel split) alone, committed before any image is rendered with the new channel split. The
machine-readable twin is `characterisation_signatures_v1.json` (same ids, deltas and directions); the battery
(`lifeimage/characterise.py`) evaluates exactly that file. A signature is a prediction: held, not held and
inconclusive are all reported, and a signature is never edited after measurement (a revision is a new version).

Prediction, ETA, confidence: each signature states its direction, the smallest effect that matters (delta) and a
confidence; the ETA for all of them is the first run of the battery after the levels and the channel split are in.

## Image state and features

The image state is what the renderer draws: per slice i (sector and field wedges of the basemap, area
a_i = width_i * (r1^2 - r0^2) / 2), per layer (solid, claimed) and channel, a level in [0, 1]. The displayed channel is
c_i,ch = 1 - (1 - L_solid) * (1 - g * L_claimed) with grain cover g = 0.1837 (the claimed grain's dot area over its
tile area). Luminance y_i = 0.2126 R + 0.7152 G + 0.0722 B of the displayed channels. Features are computed from this
state and the rows' dates, never by eye.

- `share_red`, `share_green`, `share_blue`: sum a_i c_i,ch over the sum of a_i over the three channels.
- `red_grain_share`: sum a_i L_claimed,red over sum a_i (L_solid,red + L_claimed,red); 0 with no red.
- `dimmed_share`: 1 - sum(magnitude * decay) / sum(magnitude) over the rows that imprint (decay = 0.5^(age / half-life),
  age from the persona's as_of). The same for every projection.
- `luminance`: sum a_i y_i over sum a_i.
- `chroma`: area-weighted mean over lit slices of (max - min) / max of the displayed channels.
- `balance_distance`: the largest |share_ch - 1/3| over the three channel shares.
- Angular bins: 360 one-degree bins on the field ring; bin luminance m_b is the mean y_i of the field slices covering
  the bin (weighted by overlap). A bin is lit when m_b >= 0.10.
- `spread_entropy`: Shannon entropy of p_b = m_b / sum m_b over the bins, divided by ln 360 (0 when dark);
  `red_spread_entropy`: the same with the displayed red channel in place of y.
- `n_clusters`: maximal runs of lit bins (circular), runs separated by fewer than 15 dark degrees merged; a run counts
  when it holds at least 10% of the total mass sum m_b.
- Sector arcs: the inner-ring sector slices tile the circle; a field wedge belongs to the arc that contains its centre
  angle. `arc_share:<sector>` is the luminance share sum a_i y_i of the fields in that arc; `max_arc_share` is the
  largest over the sectors; `gb_in:<sectors>` is the share of all green plus blue (sum a_i (c_g + c_b)) lying in the
  listed arcs.
- Recency: a slice's newest imprint is the latest valid_time of any row that imprints it. `current_luminance` is the mean
  y over lit slices whose newest imprint is at most 5 years before as_of; `past_luminance` the same for at least 10
  years; `past_over_current` is their ratio (undefined, and dropped, if either set is empty).
- `cluster_age_gap`: for an image with two or more clusters, the mean luminance of the cluster with the oldest mean
  newest-imprint date minus that of the newest (negative: the older cluster is dimmer).

## Rule

Contrast (group against `versus`, rest = every other archetype): effect e = s * (mean(group) - mean(versus)), s = +1
for ">" and -1 for "<", Welch standard error, critical value the Student-t 0.975 quantile at the Welch degrees of
freedom (the project's z-rule, t-inflated). Held: e >= delta and e - crit * SE > 0. Not held: e + crit * SE < delta (the
interval excludes the smallest effect that matters). Inconclusive otherwise. Proportions: Wilson 95% interval against
p0 (held: lower >= p0; not held: upper < p0). Bands: held if every value is inside.

Populations. Primary: the extended population (8 archetypes x 3 calibrations x 6 replicates = 144 generated
personas, all-tier truth rows, as_of from the persona), because the starter's 40 personas leave cells of 1 to 4.
Secondary: the starter 40 under four projections (truth rows, claimed resume rows, extracted resume rows, legacy).
Seeds and ages of the extended population are fixed in the JSON.

## Signatures

| id | prediction | feature | direction, delta | conf |
|---|---|---|---|---|
| C1 | over-estimators: more of the red is grainy than well-calibrated | red_grain_share | over > well, 0.05 | medium |
| C2 | over-estimators: more red | share_red | over > well, 0.04 | medium |
| C3 | under-estimators: less red | share_red | under < well, 0.04 | medium |
| C4 | under-estimators: less of the red is grainy | red_grain_share | under < well, 0.05 | low |
| C5 | extremes separate | red_grain_share | over > under, 0.10 | medium |
| C6 | well-calibrated nearer channel balance than over | balance_distance | well < over, 0.03 | low |
| C7 | well-calibrated nearer channel balance than under | balance_distance | well < under, 0.03 | low |
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
| G1 | the pooled composite of all personas tends toward white | each channel share of the pooled composite | in [0.27, 0.40] | medium |
| G2 | pooling cancels colour | composite chroma / mean persona chroma | <= 0.5 | medium |

The pooled composite is the per-slice mean of the displayed channels over every persona of the population (a
saturating sum of many images would be white trivially).

## Reasons, briefly

Calibration: claims and self-assessments are red and grainy (LI.37); over-estimators inflate claimed magnitudes and
predicted levels, under-estimators deflate them, so the claimed red and its grainy share should move with the bias,
while attested and measured rows (green, blue, solid red) do not depend on it. Archetypes follow their parameters:
students take in (consumed rows, red) in recent years; carers give care (family arc, outcomes for others, blue);
owners work (work arc); researchers publish and study (science and learning arcs, attested records); retirees' evidence
is old (dimmed) and their present is thin; career changers have two careers in different sectors, the earlier decayed;
generalists have no interests parameter and so spread. Known weak points a reader should expect: the arc features
depend on how pressure-weighted slice widths place sectors; cells of well-calibrated personas are noisy; the
extracted rows carry claims only, so solid-layer signatures cannot hold for them.
