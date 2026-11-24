var0: 0 invalid answer(s)
var1: 0 invalid answer(s)
var2: 0 invalid answer(s)

# Extraction scores (3 variants, 40.0 personas)

Rows: extracted 340 (mean over variants), truth from the resume 340, truth in all texts 2424.

| measure | expertise | impact | potential |
|---|---|---|---|
| precision (exact domain) | 0.623 | 0.024 | n/a |
| recall of resume rows (exact) | 0.522 | 0.006 | n/a |
| precision within one link | 0.700 | 0.314 | n/a |
| recall within one link | 0.582 | 0.083 | n/a |
| recall of all truth rows | 0.103 | 0.001 | 0.000 |
| coverage gap: truth rows with no resume evidence | 0.826 | 0.830 | 1.000 |
| magnitude mean absolute error | 0.136 | 0.067 | n/a |
| magnitude bias (extracted minus truth) | 0.029 | 0.053 | n/a |
| matched rows | 311.333 | 3.000 | 0.000 |
| projected totals correlation, resume truth | 0.535 | -0.157 | n/a |
| projected totals correlation, all truth | 0.248 | -0.069 | 0.000 |

Inflation (expertise, impact: relative to the corroborated size of the event; potential: absolute gap to the latent truth), by the persona's calibration:

| channel | overall | over | under | well | n |
|---|---|---|---|---|---|
| expertise | 0.312 | 0.294 | 0.377 | 0.269 | 134 |
| impact | n/a | n/a | n/a | n/a | 0 |
| potential | n/a | n/a | n/a | n/a | 0 |

Per variant (expertise): var0 precision 0.642, recall 0.548; var1 precision 0.575, recall 0.442; var2 precision 0.652, recall 0.576
