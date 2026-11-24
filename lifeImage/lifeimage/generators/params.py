"""World parameters of the synthetic life generator: one place, each with a range and a source note.

Defaults are plausible published figures for a mixed high-income population (OECD and US sources mostly); where no
figure is known the entry says "assumption" and confidence is low. Confidence is about how well the figure transfers
to the unit used here (a person-year, a recorded event), not about the survey. Nothing assumes ideal behaviour: people
over- and under-estimate themselves, most of life is unrecorded, and claims are less reliable than records.

Archetypes are parameter presets (overrides inside the ranges plus a career and interest profile and a plausible age
range), never hard-coded lives: the same engine and the same rng streams produce every archetype.

Figures produced by today's institutions (record coverage, formal-training rates) describe the status-quo baseline of
a prototype dataset and are a sweep, not a claim about a Benefuture society.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Param:
    name: str
    default: float
    low: float
    high: float
    unit: str
    source: str
    confidence: str  # low | medium | high
    note: str = ""


def _p(name, default, low, high, unit, source, confidence, note=""):
    return name, Param(name, default, low, high, unit, source, confidence, note)


PARAMS = dict([
    # ---- family ----
    _p("p_partner_by_50", 0.78, 0.5, 0.95, "share", "Pew Research Center 2021: about 25% of US 40-year-olds had never married; OECD Family Database (partnering rates)", "medium"),
    _p("age_partner_mean", 28.5, 22, 34, "years", "US Census Bureau 2022 median age at first marriage 30.1 (men), 28.2 (women); OECD Family Database 2020 about 30-33", "medium"),
    _p("age_partner_sd", 4.0, 2, 7, "years", "assumption (spread of the same series)", "low"),
    _p("p_children", 0.8, 0.5, 0.95, "share", "Pew Research Center 2018: about 15% of US women aged 40-44 childless; OECD Family Database", "medium"),
    _p("age_first_birth_mean", 29.0, 22, 34, "years", "OECD Family Database 2020: mean age at first birth about 29.5", "medium"),
    _p("n_children_given_any", 2.0, 1.2, 3.2, "children", "OECD completed fertility about 1.7 overall, so about 2.1 among parents", "medium"),
    _p("p_separation", 0.3, 0.1, 0.5, "share of partnerships", "Eurostat and US CDC crude divorce statistics; about 30-40% of marriages end in divorce", "low"),
    # ---- learning ----
    _p("p_tertiary", 0.42, 0.15, 1.0, "share", "OECD Education at a Glance 2023: 47% of 25-34 year-olds hold a tertiary degree (older cohorts lower)", "medium"),
    _p("school_end_age", 17.0, 15, 19, "years", "OECD compulsory schooling ends at 15-18; upper secondary completion about 17-18", "medium"),
    _p("p_adult_learning_per_year", 0.25, 0.05, 0.6, "per year", "OECD PIAAC: about half of adults took part in formal or non-formal learning in the past 12 months", "medium", "recorded events are the notable subset"),
    # ---- work ----
    _p("p_teen_job", 0.35, 0.1, 0.6, "share", "US BLS: about a third of 16-19 year-olds employed in summer; lower in term time", "medium"),
    _p("job_tenure_years", 4.0, 2, 10, "years", "US BLS Employee Tenure 2022: median 3.9 years (OECD mean about 9)", "medium", "median; sampled as a gamma with this mean"),
    _p("p_unemployment_spell_per_year", 0.05, 0.01, 0.2, "per year", "OECD unemployment about 5%; spell incidence assumed near the rate", "low"),
    _p("retirement_age", 65.0, 58, 72, "years", "OECD Pensions at a Glance 2023: normal retirement age about 64; effective about 63-64", "medium"),
    _p("p_career_change_per_job", 0.3, 0.05, 0.7, "per job change", "US BLS: occupational switching accounts for a large part of job changes; assumption", "low"),
    # ---- civic and meaning ----
    _p("p_vote", 0.65, 0.3, 0.9, "per election", "US Census 2020 turnout 66% of citizens; OECD turnout about 65-70%", "medium"),
    _p("election_interval_years", 4.0, 2, 6, "years", "typical national cycle", "high"),
    _p("p_volunteer", 0.25, 0.05, 0.5, "share", "AmeriCorps and US Census CPS 2021: 23% formal volunteering (28% in 2023)", "medium"),
    _p("p_faith_active", 0.3, 0.05, 0.7, "share", "Pew Research Center 2018: about 30% of US adults attend services weekly; much lower in parts of Europe", "medium"),
    _p("p_giving_per_year", 0.5, 0.1, 0.8, "per year", "Giving USA and Indiana University Lilly School: about half of US households give to charity", "medium"),
    # ---- care and home ----
    _p("p_eldercare", 0.2, 0.05, 0.5, "share", "AARP and NAC 2020: 21% of US adults care for an adult family member", "medium"),
    _p("p_pet", 0.5, 0.1, 0.7, "share", "APPA 2023: 66% of US households own a pet; lower in many countries", "low"),
    _p("p_mutual_aid_per_year", 0.2, 0.05, 0.5, "per year", "assumption (informal help to neighbours; time-use surveys show it is common but rarely logged)", "low"),
    _p("p_home_project_per_year", 0.4, 0.1, 0.8, "per year", "assumption (DIY and household projects)", "low"),
    # ---- health ----
    _p("p_health_event_per_year", 0.03, 0.005, 0.08, "per year at age 30", "US CDC NHDS: about 3-4% of adults hospitalised per year; recorded notable events subset", "low"),
    _p("health_age_slope", 0.03, 0.0, 0.06, "log hazard per year of age", "assumption (hospital use roughly doubles each 20-25 years of age)", "low"),
    _p("p_preventive_per_year", 0.4, 0.1, 0.8, "per year", "US CDC: about 45% of adults had a flu vaccination; screening uptake varies", "medium"),
    _p("p_exercise_regular", 0.55, 0.2, 0.8, "share", "WHO 2018: about 31% of adults insufficiently active worldwide, so about 69% sufficient (US about 50%)", "medium"),
    _p("p_mental_episode_per_year", 0.05, 0.01, 0.12, "per year", "US NSDUH 2021: 8% of adults had a major depressive episode; treated and recorded subset", "medium"),
    # ---- leisure, consumption, mobility ----
    _p("leisure_per_year", 1.5, 0.5, 4.0, "events per year", "assumption (ATUS: about 5 hours of leisure a day; recorded notable events are few)", "low"),
    _p("p_travel_per_year", 0.5, 0.1, 0.9, "per year", "assumption (notable trips)", "low"),
    _p("p_buy_home_by_40", 0.5, 0.2, 0.8, "share", "US homeownership 65% overall, about 38% under 35; OECD varies widely", "medium"),
    _p("age_buy_home_mean", 33.0, 26, 42, "years", "US NAR: first-time buyer median age 35 (2023)", "medium"),
    _p("p_large_purchase_per_year", 0.25, 0.05, 0.6, "per year", "assumption (car, appliance, major purchase)", "low"),
    # ---- rare harm ----
    _p("p_harm_per_year", 0.006, 0.0005, 0.03, "per adult year", "assumption: about a fifth of adults cause one recorded culpable harm (traffic offence, negligence, misconduct) in a working life", "low", "harm is rare, recorded on the negative channel with an option set"),
    # ---- records and reliability ----
    _p("p_attested_formal", 0.55, 0.2, 0.9, "share of formal events", "assumption (status-quo baseline: school, payroll, clinic and civic records that reach the dataset)", "low"),
    _p("p_attested_informal", 0.04, 0.0, 0.2, "share of informal events", "assumption (a third party attests a hobby, a gift, a club night)", "low"),
    _p("p_measured_logged", 0.2, 0.05, 0.5, "share of loggable events", "Pew Research Center 2020: 21% of US adults use a smartwatch or fitness tracker; payment logs cover more", "medium"),
    _p("p_digital_trace", 0.5, 0.2, 0.9, "share of persons", "ECB SPACE 2022: about 59% of euro-area point-of-sale payments by card; many persons also use cash", "low", "payment, bank, booking and ticket logs"),
    _p("p_log_capture", 0.9, 0.5, 1.0, "share of loggable events", "assumption (a person who keeps a log captures most of what it can see)", "low"),
    _p("p_claim_mention", 0.3, 0.1, 0.9, "share of events", "assumption (how much of a life a person writes down in a resume, diary or self-description)", "low"),
    _p("conf_claimed", 0.5, 0.2, 0.7, "confidence", "DESIGN.md tiers: self-report is the weakest tier; assumption", "low"),
    _p("conf_attested", 0.8, 0.6, 0.95, "confidence", "DESIGN.md tiers: third-party record; assumption", "low"),
    _p("conf_measured", 0.85, 0.6, 0.97, "confidence", "DESIGN.md tiers: logs and outputs; assumption", "low"),
    _p("conf_noise_sd", 0.06, 0.0, 0.12, "confidence", "assumption", "low"),
    _p("recall_decay_per_year", 0.01, 0.0, 0.03, "confidence per year since the event", "autobiographical memory decay (Rubin and Wenzel 1996), order of magnitude only", "low"),
    # ---- self-assessed potential ----
    _p("p_over", 0.4, 0.1, 0.7, "share", "Kruger and Dunning 1999 and Svenson 1981 (88% of drivers rate themselves safer than the median): most people overestimate", "low"),
    _p("p_under", 0.25, 0.05, 0.5, "share", "Clance and Imes 1978 (impostor phenomenon); prevalence uncertain", "low"),
    _p("bias_over", 0.22, 0.05, 0.4, "potential units (0-1)", "Kruger and Dunning 1999: the bottom quartile placed itself about 0.5 percentile points high; scaled down", "low"),
    _p("bias_under", -0.18, -0.4, -0.05, "potential units (0-1)", "assumption (mirror of the overestimate, smaller)", "low"),
    _p("bias_sd", 0.06, 0.01, 0.12, "potential units (0-1)", "assumption (persons differ within a calibration type)", "low"),
    _p("est_noise_sd", 0.08, 0.02, 0.2, "potential units (0-1)", "assumption (every self-estimate carries noise, even when well calibrated)", "low"),
    _p("est_regression_slope", 0.3, 0.0, 0.6, "share", "Kruger and Dunning 1999: estimates regress toward the middle (weaker people overestimate, stronger underestimate)", "low"),
])

# Jobs per sector: titles, employer stems, domains (form = the kind of act, content = what it is about, setting = where)
SECTORS = {
    "logistics": {"titles": ["warehouse operative", "delivery driver", "forklift driver", "dispatcher"], "employers": ["Harbour Freight", "Quickline Logistics", "Northgate Distribution", "Redbank Haulage"],
                  "form": {"c.transport_logistics": 1.0}, "content": {"c.transport_logistics": 0.7, "c.driving": 0.3}, "setting": {"c.transport_logistics": 1.0}},
    "retail": {"titles": ["shop assistant", "cashier", "store supervisor", "sales associate"], "employers": ["Greenfield Stores", "Corner Mart", "Highstreet Goods", "Maple Retail"],
               "form": {"c.retail_work": 1.0}, "content": {"c.retail_work": 0.6, "c.customer_service": 0.4}, "setting": {"c.retail_work": 1.0}},
    "hospitality": {"titles": ["waiter", "line cook", "barista", "hotel receptionist", "kitchen assistant"], "employers": ["The Old Mill Kitchen", "Lakeside Hotel", "Riverside Bistro", "Copper Pot Diner"],
                    "form": {"c.hospitality_work": 1.0}, "content": {"c.cooking": 0.4, "c.customer_service": 0.6}, "setting": {"c.hospitality_work": 1.0}},
    "healthcare": {"titles": ["nurse", "healthcare assistant", "paramedic", "physiotherapist", "pharmacy technician"], "employers": ["St Aldric Hospital", "Valley Health Trust", "Westmoor Clinic", "Oakhurst Care Group"],
                   "form": {"c.healthcare_work": 1.0}, "content": {"c.medical_care": 0.6, "c.physical_health": 0.4}, "setting": {"c.medical_care": 1.0}},
    "education": {"titles": ["primary school teacher", "teaching assistant", "secondary maths teacher", "lecturer"], "employers": ["Brookfield Primary", "Hillcrest Academy", "Eastgate College", "Kingsmead School"],
                  "form": {"c.teaching_profession": 1.0}, "content": {"c.school_education": 0.6, "c.tutoring_teaching": 0.4}, "setting": {"c.school_education": 1.0}},
    "office": {"titles": ["administrator", "accounts clerk", "project coordinator", "office manager"], "employers": ["Pellam and Cole", "Brightwater Services", "Norfolk Mutual", "Ashdown Partners"],
               "form": {"c.business_administration": 1.0}, "content": {"c.business_administration": 0.6, "c.finance_accounting": 0.4}, "setting": {"c.business_administration": 1.0}},
    "construction": {"titles": ["electrician", "carpenter", "site foreman", "plumber", "bricklayer"], "employers": ["Stonebridge Builders", "Ironwood Contractors", "Tallis Electrical", "Kestrel Build"],
                     "form": {"c.construction_trades": 1.0}, "content": {"c.civil_engineering": 0.3, "c.home_repair_diy": 0.3, "c.construction_trades": 0.4}, "setting": {"c.construction_trades": 1.0}},
    "software": {"titles": ["software developer", "QA engineer", "data analyst", "systems administrator"], "employers": ["Lumen Labs", "Quartz Software", "Nimbus Works", "Tessel Systems"],
                 "form": {"c.software_development": 1.0}, "content": {"c.software_development": 0.6, "c.computer_science": 0.4}, "setting": {"c.software_development": 1.0}},
    "research": {"titles": ["research assistant", "postdoctoral researcher", "research scientist", "laboratory technician"], "employers": ["Halden Institute", "Ravensworth University", "Corvale Research Centre", "Meridian Laboratory"],
                 "form": {"c.science_research_work": 1.0}, "content": {"c.life_sciences": 0.25, "c.physics": 0.25, "c.statistics_data": 0.25, "c.chemistry": 0.25}, "setting": {"c.science_research_work": 1.0}},
    "public": {"titles": ["council officer", "benefits adviser", "planning assistant", "civil servant"], "employers": ["Marlow District Council", "County Records Office", "Regional Housing Agency", "Public Works Department"],
               "form": {"c.public_administration": 1.0}, "content": {"c.government_services": 0.5, "c.public_administration": 0.5}, "setting": {"c.public_administration": 1.0}},
    "care_work": {"titles": ["care worker", "home carer", "support worker", "nursery assistant"], "employers": ["Willowbrook Care", "Daybreak Support Services", "Linden Home Care", "Little Acorns Nursery"],
                  "form": {"c.therapy_social_work": 1.0}, "content": {"c.care_of_ill_disabled": 0.5, "c.eldercare": 0.5}, "setting": {"c.therapy_social_work": 1.0}},
    "trades": {"titles": ["mechanic", "welder", "baker", "hairdresser", "tailor"], "employers": ["Foxley Motors", "Ashby Workshop", "Crumb and Co", "Sable Studio", "Pinnock Tailoring"],
               "form": {"c.skilled_trades": 1.0}, "content": {"c.manufacturing": 0.3, "c.skilled_trades": 0.7}, "setting": {"c.skilled_trades": 1.0}},
    "farming": {"titles": ["farm hand", "dairy worker", "orchard worker", "grower"], "employers": ["Hollin Farm", "Three Oaks Orchard", "Barrow Dairy", "Fenland Growers"],
                "form": {"c.agri_forestry_fishing_work": 1.0}, "content": {"c.horticulture_farming": 0.6, "c.animal_care_husbandry": 0.4}, "setting": {"c.agri_forestry_fishing_work": 1.0}},
}
SECTOR_NAMES = sorted(SECTORS)

ARCHETYPES = {
    "student": {"age_range": (8, 24), "params": {"p_tertiary": 0.7, "p_adult_learning_per_year": 0.45, "p_teen_job": 0.3, "p_partner_by_50": 0.7},
                "sectors": ["retail", "hospitality", "education"], "interests": ["c.school_education", "c.higher_education", "c.games_play", "c.sport_participation", "c.music_making", "c.reading"], "in_education": True},
    "shift_worker": {"age_range": (22, 62), "params": {"p_tertiary": 0.2, "job_tenure_years": 5.0, "p_adult_learning_per_year": 0.1, "p_health_event_per_year": 0.04, "p_exercise_regular": 0.4},
                     "sectors": ["logistics", "hospitality", "healthcare", "retail"], "interests": ["c.sport_spectating", "c.video_gaming", "c.cooking", "c.driving"]},
    "carer": {"age_range": (28, 72), "params": {"p_eldercare": 0.5, "p_children": 0.9, "p_mutual_aid_per_year": 0.4, "p_adult_learning_per_year": 0.1},
              "sectors": ["care_work", "retail", "office"], "interests": ["c.care_of_ill_disabled", "c.eldercare", "c.household_gardening", "c.cooking"], "carer": True},
    "small_business_owner": {"age_range": (28, 68), "params": {"p_tertiary": 0.35, "job_tenure_years": 6.0, "p_large_purchase_per_year": 0.4},
                             "sectors": ["trades", "hospitality", "retail", "construction"], "interests": ["c.entrepreneurship", "c.sales_marketing", "c.finance_accounting"], "owner": True},
    "researcher": {"age_range": (24, 70), "params": {"p_tertiary": 0.98, "p_adult_learning_per_year": 0.5, "job_tenure_years": 4.0, "p_teen_job": 0.15},
                   "sectors": ["research", "education", "software"], "interests": ["c.science_research_work", "c.research_training", "c.statistics_data", "c.reading"], "researcher": True},
    "retiree": {"age_range": (62, 90), "params": {"retirement_age": 63.0, "p_faith_active": 0.4, "p_volunteer": 0.35, "p_health_event_per_year": 0.045},
                "sectors": ["office", "public", "construction", "education", "healthcare"], "interests": ["c.household_gardening", "c.family_ties", "c.volunteering", "c.reading"]},
    "career_changer": {"age_range": (28, 60), "params": {"p_career_change_per_job": 0.7, "p_adult_learning_per_year": 0.4, "job_tenure_years": 3.0},
                       "sectors": ["office", "software", "healthcare", "trades", "education", "public"], "interests": ["c.employment_transition", "c.vocational_training", "c.self_directed_learning"], "changer": True},
    "generalist": {"age_range": (18, 90), "params": {}, "sectors": SECTOR_NAMES, "interests": []},
}


def resolve(overrides=None):
    """{name: value} of every parameter: the defaults, with `overrides` checked against each range."""
    out = {k: p.default for k, p in PARAMS.items()}
    for k, v in (overrides or {}).items():
        if k not in PARAMS:
            raise ValueError(f"unknown parameter {k!r}")
        p = PARAMS[k]
        if isinstance(v, bool) or not isinstance(v, (int, float)) or not p.low <= v <= p.high:
            raise ValueError(f"{k}={v!r} outside its range [{p.low}, {p.high}]")
        out[k] = v
    return out
