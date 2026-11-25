var0: 0 invalid answer(s)
var1: 0 invalid answer(s)
var2: 0 invalid answer(s)

# Extraction scores (3 variants, 40.0 personas)

Rows: extracted 342 (mean over variants), truth from the resume 340, truth in all texts 2424.

| measure | expertise | impact | potential |
|---|---|---|---|
| precision (exact domain) | 0.662 | n/a | 0.000 |
| recall of resume rows (exact) | 0.508 | 0.000 | n/a |
| precision within one link | 0.672 | n/a | 0.000 |
| precision matched without spans (domain within a link, year within one) | 0.500 | n/a | 0.000 |
| recall matched without spans | 0.355 | 0.000 | n/a |
| recall within one link | 0.514 | 0.000 | n/a |
| recall of all truth rows | 0.096 | 0.000 | 0.000 |
| coverage gap: truth rows with no resume evidence | 0.826 | 0.830 | 1.000 |
| magnitude mean absolute error | 0.184 | n/a | n/a |
| magnitude bias (extracted minus truth) | -0.082 | n/a | n/a |
| matched rows | 285.333 | 0.000 | 0.000 |
| projected totals correlation, resume truth | 0.536 | 0.000 | n/a |
| projected totals correlation, all truth | 0.243 | 0.000 | -0.115 |

Inflation (expertise, impact: relative to the corroborated size of the event; potential: absolute gap to the latent truth), by the persona's calibration:

| channel | overall | over | under | well | n |
|---|---|---|---|---|---|
| expertise | -0.034 | 0.190 | -0.145 | -0.059 | 164 |
| impact | n/a | n/a | n/a | n/a | 0 |
| potential | 0.202 | 0.395 | -0.288 | -0.080 | 6 |

Per variant (expertise): var0 precision 0.642, recall 0.503; var1 precision 0.644, recall 0.510; var2 precision 0.699, recall 0.511
