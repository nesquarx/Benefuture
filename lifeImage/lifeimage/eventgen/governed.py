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
}
