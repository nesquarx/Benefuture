"""Governed thresholds and noise parameters of the event generator (pattern of `lifeimage/governed.py`; merged into `GOVERNED`).

A threshold is a value to be governed later; a noise parameter is a step that can go wrong or vary in reality, drawn on its
own random stream, with a range to explore (`range`). World defaults sit at the mild end of each noise range (nothing is
perfect). Properties of the world (noise, assumed shares) are not thresholds; both kinds are listed so none hides in code.
"""
GOVERNED_EVENTGEN = {
    "eventgen.rate_z": {"default": 2.0, "source": "CLAUDE.md significance rule: an effect counts only beyond z combined standard errors (Student-t inflated); 3 for claims entering README."},
    "eventgen.rate_margin_rel": {"default": 0.10, "source": "Assumption: the smallest relative departure from a calibration value that matters; a rate within 10% is equivalent."},
    "eventgen.margin_floor.per1000": {"default": 1.0, "source": "Assumption: absolute margin floor for rates per 1000 (small rates would otherwise need unbounded precision)."},
    "eventgen.margin_floor.pct": {"default": 1.0, "source": "Assumption: absolute margin floor in percentage points for shares."},
    "eventgen.margin_floor.years": {"default": 0.25, "source": "Assumption: absolute margin floor for mean ages, in years."},
    "eventgen.margin_floor.births_per_woman": {"default": 0.05, "source": "Assumption: absolute margin floor for the total fertility rate."},
    "eventgen.margin_floor.ratio": {"default": 1.0, "source": "Assumption: absolute margin floor for the sex ratio at birth (males per 100 females)."},
    "eventgen.cal_se_rel.high": {"default": 0.02, "source": "Assumption: relative standard error of a high-confidence calibration value (registration or census based)."},
    "eventgen.cal_se_rel.medium": {"default": 0.05, "source": "Assumption: relative standard error of a medium-confidence value (survey or model based)."},
    "eventgen.cal_se_rel.low": {"default": 0.10, "source": "Assumption: relative standard error of a low-confidence value (unverified at its page or indirect)."},
    "eventgen.min_seeds": {"default": 8, "source": "Assumption: fewest paired seeds before precision is judged (a standard error needs a spread)."},
    "eventgen.max_seeds": {"default": 60, "source": "Assumption: seed cap of the precision rule `seeds_until_stable`; a Param still imprecise then is reported inconclusive, never passed."},
    "eventgen.horizon_age": {"default": 50, "source": "Design: persons are followed to this age; covers the 15-49 fertility bands and marriage ages (the normal tail beyond is negligible)."},
    "eventgen.lower_secondary_years": {"default": 3, "source": "Assumption: lower secondary lasts three years (UIS gives only total secondary duration)."},
    "eventgen.partnership_ever_share": {"default": 0.9, "source": "Assumption, low confidence: share who ever marry; no Param yet (UN World Marriage Data is the candidate source). Not checked by the rate head."},
    "eventgen.tertiary_years": {"default": 4, "source": "Assumption: length of a first tertiary degree."},
    "noise.fertility_frailty_sd": {"default": 0.1, "range": [0.0, 0.5], "source": "Assumption: sd of a mean-one lognormal personal multiplier on the annual birth probability (heterogeneity of fecundity and intent); the marginal rate is preserved."},
    "noise.marriage_age_sd": {"default": 4.0, "range": [2.0, 7.0], "source": "Existing generator parameter age_partner_sd (params.py): spread of age at first marriage, years; assumption."},
    "noise.school_entry_delay_p": {"default": 0.15, "range": [0.0, 0.4], "source": "Assumption: probability a child starts school a year late (over-age entry); shifts timing, not shares."},
    "eventgen.min_maternal_age": {"default": 15, "source": "Convention: the youngest age band of the UN WPP fertility tables is 15-19; a birth before 15 is a data error or a different phenomenon, so the sequence head treats it as a hard violation."},
    "eventgen.minor_age": {"default": 18, "source": "Age of majority (UN Convention on the Rights of the Child, art. 1); decides whether a parent is a participant and whether the option set of the act is recorded."},
    "eventgen.pregnancy_years": {"default": 0.75, "source": "Assumption: span of a pregnancy episode before its birth (nine months), as a fraction of a year."},
    "eventgen.mortality_gompertz_slope": {"default": 0.09, "source": "Gompertz law: adult hazard roughly doubles every 8 years (ln 2 / 8 = 0.087); used only 40-50, beyond the last measured 40q0 age."},
    "eventgen.divorce_share_default": {"default": 0.10, "source": "Assumption, low confidence: share of marriages ending in divorce within the horizon when no divorce Param exists at any level (logged as degraded); Eurostat divorces per 100 marriages for DEU is the only Param."},
    "eventgen.divorce_mean_duration": {"default": 8.0, "source": "Assumption: mean years from marriage to divorce (exponential, minimum 0.5 years)."},
    "eventgen.premarital_first_birth_share": {"default": 0.15, "source": "Assumption, low confidence: share of mothers whose first birth precedes their first marriage where births outside marriage are rare (see premarital_rare_below_smam); no Param yet (OECD Family Database SF2.4, DHS and the UN Demographic Yearbook are candidate sources). Checks wiring, not realism."},
    "eventgen.premarital_rare_below_smam": {"default": 25.0, "source": "Assumption: where women's mean age at first marriage is below this (years), marriage precedes childbearing for most women and the premarital share is judged; elsewhere (late marriage, common cohabitation) it is reported only."},
    "eventgen.premarital_margin": {"default": 0.15, "source": "Assumption: 'rare' means within 0.15 of the assumed share (absolute proportion); wide because the assumed share has no data behind it."},
    "eventgen.seq_margin_years": {"default": 1.0, "source": "Assumption: the smallest departure in an age statistic (mean or median age at an event) that matters, in years; equivalence is judged within it."},
    "eventgen.seq_margin_prop": {"default": 0.05, "source": "Assumption: the smallest departure in a share that matters, in absolute proportion."},
    "eventgen.concurrent_window_years": {"default": 1.0, "source": "Assumption: two events whose spans come within this many years overlap for the concurrent link (an instant event has a one-year reporting resolution)."},
    "eventgen.marriage_birth_link_years": {"default": 2.0, "source": "Assumption: a first birth within this many years after the marriage is linked as caused by it (causal reading supported where the model raises the birth hazard on marriage, r < 1)."},
    "noise.nonmarital_birth_relative_hazard": {"default": 0.1, "range": [0.05, 1.0], "source": "Assumption: birth hazard of an unmarried woman relative to a married one at the same age (r); 1 means births ignore marriage (the increment-1 generator). Marginal ASFR is preserved for any r."},
    "noise.spouse_age_gap_sd": {"default": 3.0, "range": [2.0, 5.0], "source": "Assumption: sd in years of the age difference between spouses around the male minus female difference of the mean ages at first marriage."},
}
