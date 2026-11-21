## Layer A: membership (A3S)

| vocabulary | answers | items | other rate | forced rate | red-team other | mean alpha | mean Jaccard | mean weighted Jaccard |
|---|---|---|---|---|---|---|---|---|
| A3S | 360 | 120 | 0.3% | 24.2% | 0.0% | 0.77 | 0.77 | 0.75 |

| vocabulary | type | applicability | null rate | alpha (top domain) | mean Jaccard | weighted Jaccard |
|---|---|---|---|---|---|---|
| A3S | form | 100.0% | 0.0% | 0.82 | 0.80 | 0.77 |
| A3S | content | 100.0% | 0.0% | 0.83 | 0.76 | 0.72 |
| A3S | outcome | 29.2% | 70.8% | 0.81 | 0.86 | 0.85 |
| A3S | setting | 68.9% | 31.1% | 0.61 | 0.66 | 0.66 |

Placebo noise floor (type `flavour`, meaningless by design; excluded from the means):

| vocabulary | fill rate | alpha | mean Jaccard | weighted Jaccard |
|---|---|---|---|---|
| A3S | 0.3% | 0.00 | 0.99 | 0.99 |

Minimal pairs: share of pairs with identical A-annotations. For `A` (and `A:<type>`) this is the collision rate, which should be low; for the other kinds identical is expected.

| vocabulary | pairs marked | pairs | identical | share |
|---|---|---|---|---|
| A3S | A | 4 | 0 | 0.0% |
| A3S | A:content | 1 | 0 | 0.0% |
| A3S | A:form | 1 | 0 | 0.0% |
| A3S | A:outcome | 1 | 0 | 0.0% |
| A3S | A:setting | 1 | 0 | 0.0% |
| A3S | B | 5 | 3 | 60.0% |
| A3S | D | 2 | 1 | 50.0% |

| vocabulary | type pair | items with a swap |
|---|---|---|
| A3S | form / content | 7.5% |
| A3S | form / outcome | 1.7% |
| A3S | form / setting | 1.7% |
| A3S | content / outcome | 3.3% |
| A3S | content / setting | 2.5% |
| A3S | outcome / setting | 0.0% |

## Layer B: participation (360 answers, 120 items)

Agreement per field (alpha: interval for numbers, nominal for categories; variants are coders):

| field | kind | alpha | null rate |
|---|---|---|---|
| contribution | interval | 0.92 | n/a |
| responsibility | interval | 0.89 | n/a |
| impact_net | interval | 0.65 | n/a |
| production | nominal | 0.57 | 64.8% |
| volition | nominal | 0.77 | 97.7% |
| acting_for | nominal | 0.78 | 98.8% |
| informed | nominal | 1.00 | 99.6% |
| under_agreement | nominal | 0.63 | 98.6% |

Contribution Spearman (mean over variant pairs): 0.90. Impact party Jaccard: 0.89. Empty impact lists: 83.3%.

Conservation violations (contributions to one outcome summing above 1): 0 of 360 answers (0.0%); largest sum 1.00.

Overdetermination (6 items): pattern met in 88.9% of 18 answers; mean contribution 0.07, mean responsibility 0.55, mean divergence (responsibility minus contribution) 0.48.

| item | pattern met |
|---|---|
| bd.mp.decisive_vote.a | 33.3% |
| bd.new.archers | 100.0% |
| bd.new.volunteers | 100.0% |
| bd.new.vote5 | 100.0% |
| bd.rt.36 | 100.0% |
| bd.rt.37 | 100.0% |

Collision rate on B minimal pairs: 1 of 5 pairs have identical B annotations (20.0%; should be low). Differing in an expected field: 4 of 5 (80.0%).

| field | pairs differing |
|---|---|
| contribution | 20.0% |
| responsibility | 20.0% |
| impact_sign | 0.0% |
| acting_for | 0.0% |
| under_agreement | 20.0% |
| informed | 20.0% |
| volition | 40.0% |
| production | 0.0% |

## Layer D: event links (360 answers, 120 items)

Number of sub-events: interval alpha 0.66, mean 1.43.

Link-type agreement over 104 matched sub-event pairs: nominal alpha 0.65; among 98 pairs linked in either variant, identical label 88.8%.

Share of scenarios where any variant uses each link type:

| link type | share |
|---|---|
| part_of | 4.2% |
| causes | 34.2% |
| re_description | 1.7% |
| concurrent | 4.2% |

D minimal pairs: the richer text gets more sub-events in 2 of 2 pairs (100.0%).

## Production on consumed-versus-produced pairs

Focal answers equal to the expected value: 98.9% over 90 answers; null 1.1%. Pairs whose two texts get different non-null productions: 15 of 15.

| expected | answers | match rate |
|---|---|---|
| consumed | 45 | 100.0% |
| produced | 45 | 97.8% |

## Outcome against the counterfactual

| group | items | answers | outcome filled | items filled by majority |
|---|---|---|---|---|
| change | 22 | 66 | 100.0% | 100.0% |
| null | 8 | 24 | 0.0% | 0.0% |
| plain | 36 | 108 | 10.2% | 8.3% |

Counterfactual items matching the expectation (change: filled, null: not filled): 100.0%.
