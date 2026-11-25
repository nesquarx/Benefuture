"""Synthetic life histories: seeded, deterministic persona histories from birth to a given age.

A persona is a latent life (events) plus the evidence that life left: contract rows per tier (claimed texts the
person wrote, attested third-party records, measured logs), self-assessed potential rows with estimation error, and
three rendered texts (resume, self-description, diary-like event list) whose claimed rows are the ground truth for
extraction tests. Most events leave no record at all.

Everything stochastic draws from independent streams per (seed, mechanism), so changing one parameter moves only the
mechanism it governs. Archetypes are parameter presets (params.py), not hard-coded lives.
"""
import datetime as dt
import math
from dataclasses import dataclass, field

from . import catalogue as C
from .common import (BASEMAP_VERSION, CITIES, COUNTRIES, FIRST, LAST, STREETS, clip, normalise, pick, poisson, seed_label,
                     stream)
from .params import ARCHETYPES, SECTORS, resolve
from ..responsibility import responsibility_from_freedom

GENERATOR_VERSION = 1
CALIBRATIONS = ("over", "under", "well")
FIELDS = [("physics", "c.physics"), ("chemistry", "c.chemistry"), ("biology", "c.life_sciences"), ("mathematics", "c.mathematics"),
          ("computer science", "c.computer_science"), ("psychology", "c.psychology"), ("economics", "c.economics"), ("sociology", "c.sociology"),
          ("history", "c.history_science"), ("literature", "c.linguistics_literature"), ("nursing", "c.healthcare_work"),
          ("education studies", "c.teaching_profession"), ("civil engineering", "c.civil_engineering"), ("business", "c.business_science"),
          ("design", "c.visual_arts")]
SCIENCE_FIELDS = FIELDS[:8]
SKILLS = [("spreadsheets", "c.digital_tool_use"), ("Python", "c.software_development"), ("first aid", "c.preventive_health"),
          ("bookkeeping", "c.finance_accounting"), ("welding", "c.skilled_trades"), ("carpentry", "c.skilled_trades"),
          ("project management", "c.management_executive"), ("data analysis", "c.statistics_data"), ("food hygiene", "c.cooking"),
          ("basic electrics", "c.electrical_engineering"), ("web design", "c.software_development"), ("counselling skills", "c.counselling_therapy"),
          ("beekeeping", "c.horticulture_farming"), ("public speaking", "c.everyday_conversation"), ("marketing", "c.sales_marketing")]
SKILL_BIAS = {"researcher": ["data analysis", "Python"], "carer": ["first aid", "counselling skills"],
              "small_business_owner": ["bookkeeping", "marketing"], "shift_worker": ["first aid", "food hygiene"]}
VOL_ORGS = [("the food bank", "c.charity_giving"), ("a children's reading club", "c.school_education"), ("the hospice shop", "c.medical_care"),
            ("the community garden", "c.household_gardening"), ("a youth football team", "c.sport_participation"), ("the repair cafe", "c.reuse_repair"),
            ("a refugee support group", "c.human_rights"), ("the animal shelter", "c.wildlife_conservation")]
BUSINESSES = {"trades": ["workshop", "repair business", "bakery"], "hospitality": ["cafe", "catering business", "guesthouse"],
              "retail": ["shop", "market stall", "online store"], "construction": ["building firm", "joinery business"]}
LEVELS = [(0.25, "a beginner"), (0.5, "competent"), (0.75, "skilled"), (0.9, "very skilled"), (1.01, "an expert")]
IMPACTS = [(0.25, "has hardly mattered to anyone"), (0.5, "has made a small difference"), (0.75, "makes a clear difference to people around me"),
           (0.9, "makes a big difference"), (1.01, "has changed things for many people")]
MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


# ---------- time ----------
def parse_date(s):
    return dt.date.fromisoformat(s)


def mi(y, m):
    return y * 12 + (m - 1)


def ym(i):
    return f"{i // 12:04d}-{i % 12 + 1:02d}"


@dataclass
class Persona:
    id: str
    seed: int
    archetype: str
    age: int
    birth: str
    as_of: str
    name: str
    calibration: str
    bias: float
    country: str
    city: str
    contact: dict
    latent: dict = field(default_factory=dict)
    events: list = field(default_factory=list)
    rows: list = field(default_factory=list)
    texts: dict = field(default_factory=dict)
    params: dict = field(default_factory=dict)

    @property
    def entity(self):
        return f"person:{self.id}"

    @property
    def truth_rows(self):
        """The claimed rows: what an extractor reading the texts should find."""
        return [r for r in self.rows if r["tier"] == "claimed"]

    def meta(self):
        return {"id": self.id, "entity": self.entity, "seed": self.seed, "generator_version": GENERATOR_VERSION, "archetype": self.archetype,
                "age": self.age, "birth": self.birth, "as_of": self.as_of, "name": self.name, "calibration": self.calibration,
                "bias": round(self.bias, 4), "country": self.country, "city": self.city, "contact": self.contact, "latent": self.latent,
                "kind": "person", "synthetic": True}


# ---------- the plan: who, when ----------
class Plan:
    def __init__(self, seed, arch, age, as_of, P, pid):
        self.seed, self.arch, self.age, self.P, self.pid = seed, ARCHETYPES[arch], age, P, pid
        self.archname = arch
        self.as_of = parse_date(as_of)
        R = stream(seed, "identity")
        year = self.as_of.year - age
        self.birth = dt.date(year, R.randint(1, 12), R.randint(1, 28))
        if self.birth > self.as_of:
            self.birth = dt.date(year - 1, self.birth.month, self.birth.day)
        self.birth_mi = mi(self.birth.year, self.birth.month)
        self.asof_mi = mi(self.as_of.year, self.as_of.month)
        self.name = f"{pick(R, FIRST)} {pick(R, LAST)}"
        self.city = pick(R, CITIES)
        self.country = pick(R, COUNTRIES)
        self.street = f"{R.randint(1, 120)} {pick(R, STREETS)} {pick(R, ['Street', 'Road', 'Lane', 'Close'])}"
        self.phone_tail = R.randint(100, 199)
        self.dob_style = R.random() < 0.5
        self.R = stream(seed, "records")
        self.raw = []  # raw events
        self.jobs = []
        self.licence_mi = None

    @property
    def exact_age(self):
        return (self.asof_mi - self.birth_mi) / 12

    def at(self, age):
        return self.birth_mi + int(round(age * 12))

    def age_at(self, i):
        return (i - self.birth_mi) / 12

    def emit(self, key, age, R, detail=None, **extra):
        """Record a raw event at `age` (years) when the template allows it and it has happened by `as_of`."""
        t = C.TEMPLATES[key]
        a = max(age, 0.0)
        i = self.at(a)
        if i > self.asof_mi or a < t.amin - 1e-9 or a > t.amax or i < self.birth_mi:
            return None
        d = dict(detail or {})
        d.update(extra)
        d.setdefault("city", self.city)
        for slot, opts in t.slots.items():
            d.setdefault(slot, pick(R, opts))
        ev = {"key": key, "mi": i, "detail": d}
        self.raw.append(ev)
        return ev


def _field(R, arch_name):
    return pick(R, SCIENCE_FIELDS if arch_name == "researcher" else FIELDS)


# ---------- modules ----------
def m_education(pl, P):
    R = stream(pl.seed, "education")
    now, arch = pl.exact_age, pl.archname
    pl.emit("born", 0.0, R)
    pl.emit("nursery", 3.0 + R.random(), R)
    pl.emit("school", 5.0 + R.random() * 0.8, R)
    pl.emit("school", 11.2 + R.random() * 0.5, R, {"school": pick(R, ["Kingsmead Secondary School", "Eastgate Academy", "Westfield High School"])})
    for y in range(7, 19):
        if R.random() < 0.18:
            pl.emit("school_achievement", y + R.random(), R)
    end = P["school_end_age"] + R.random() * 0.4
    pl.emit("exam", end, R)
    pl.school_end = end
    tert = R.random() < P["p_tertiary"]
    fld, fdom = _field(R, arch)
    pl.field = (fld, fdom)
    pl.degree_end = None
    pl.phd_end = None
    if tert:
        start = end + R.choice([0.2, 0.2, 0.2, 1.2])
        dur = R.choice([3.0, 3.0, 4.0])
        uni = pick(R, ["Ravensworth University", "Eastgate College", "the Hartley Institute", "Northmoor University"])
        det = {"field": fld, "field_dom": fdom, "uni": uni}
        pl.emit("degree_start", start, R, det)
        pl.degree_end = start + dur
        pl.emit("degree", pl.degree_end, R, det)
        if pl.arch.get("researcher"):
            pl.phd_end = pl.degree_end + 4.0
            pl.emit("phd", pl.phd_end, R, det)
    else:
        if R.random() < 0.3:
            sk, sd = pick(R, SKILLS)
            pl.emit("course", end + 0.5 + R.random(), R, {"skill": sk, "skill_dom": sd})
    # lifelong learning
    SB = [s for s in SKILLS if s[0] in SKILL_BIAS.get(arch, [])]
    for y in range(18, int(now) + 1):
        if R.random() < P["p_adult_learning_per_year"] * (0.5 if y > 60 else 1.0):
            sk, sd = pick(R, SB) if SB and R.random() < 0.6 else pick(R, SKILLS)
            pl.emit("course", y + R.random(), R, {"skill": sk, "skill_dom": sd})
        if R.random() < 0.12:
            sk, sd = pick(R, SKILLS)
            pl.emit("self_study", y + R.random(), R, {"skill": sk, "skill_dom": sd})
        if R.random() < 0.04:
            pl.emit("language", y + R.random(), R)
        if 17 <= y <= 70 and R.random() < 0.03:
            pl.emit("tutoring", y + R.random(), R, {"n": pick(R, C.TEMPLATES["tutoring"].slots["n"]), "subject": pick(R, C.TEMPLATES["tutoring"].slots["subject"])})
    for y in range(9, 18):
        if R.random() < 0.08:
            sk, sd = pick(R, SKILLS)
            pl.emit("self_study", y + R.random(), R, {"skill": sk, "skill_dom": sd})


def _sector_detail(R, sector, occ=None, senior=False, employer=None):
    """A job in `sector`: `occ` (a dict) remembers the occupation chosen in each sector, so a person keeps one trade."""
    S = SECTORS[sector]
    if occ is None:
        occ = {}
    if sector not in occ:
        occ[sector] = R.randrange(len(S["titles"]))
    i = occ[sector]
    title = ("senior " if senior else "") + S["titles"][i]
    return {"sector": sector, "sector_label": sector.replace("_", " "), "title": title, "employer": employer or S["employers"][(i + R.randrange(2)) % len(S["employers"])],
            "sector_form": S["form"], "sector_content": S["content"], "sector_setting": S["setting"]}


def m_work(pl, P):
    R = stream(pl.seed, "work")
    now, arch = pl.exact_age, pl.archname
    A = pl.arch
    sectors = A["sectors"]
    retire = max(50.0, P["retirement_age"] + R.gauss(0, 2))
    if A.get("params", {}).get("retirement_age") is not None and arch == "retiree":
        retire = min(retire, now - 0.3)
    pl.retire_age = retire
    start_main = max(pl.school_end, pl.degree_end or 0, pl.phd_end or 0) + (R.random() * 1.2 if arch != "researcher" else 0.1)
    in_edu_now = pl.degree_end is not None and now < pl.degree_end
    # a teen or student job
    if R.random() < P["p_teen_job"] and now >= 16:
        sec = pick(R, ["retail", "hospitality"] if arch != "student" else A["sectors"][:2])
        a0 = 15.5 + R.random() * 2
        d = _sector_detail(R, sec)
        d.update(years=1.0, parttime=True, first=True)
        pl.emit("job", a0, R, d)
        pl.jobs.append((pl.at(a0), pl.at(a0 + 1.0), sec))
    if arch == "student" and now >= 18 and in_edu_now and R.random() < 0.7:
        sec = pick(R, A["sectors"][:2])
        a0 = max(18.0, now - 1.2)
        d = _sector_detail(R, sec)
        d.update(years=1.0, parttime=True)
        pl.emit("job", a0, R, d)
        pl.jobs.append((pl.at(a0), pl.asof_mi, sec))
    if in_edu_now or start_main >= now:
        return
    end_t = min(retire, now)
    owner = A.get("owner")
    biz_age = None
    if owner:
        biz_age = clip(R.gauss(34, 4), 24.0, max(24.0, now - 1.0)) if now > 24.5 else None
        if biz_age is not None:
            end_t = min(end_t, biz_age)
    changer = A.get("changer")
    occ = {}
    t = start_main
    primary = pick(R, sectors) if arch != "researcher" else "research"
    sector = primary
    first = True
    prev_sector = None
    unemployed_gap = 0.0
    n_jobs = 0
    work_years = end_t - start_main
    while t < end_t - 0.3:
        mean = P["job_tenure_years"]
        L = clip(R.gammavariate(2.0, mean / 2), 0.8, 25.0)
        if changer and n_jobs == 0:
            L = clip(L, 1.0, max(1.0, work_years - 1.5))
        t_end = min(t + L, end_t)
        d = _sector_detail(R, sector, occ)
        d.update(years=round(t_end - t, 2), parttime=(arch == "carer" and R.random() < 0.7))
        ev = pl.emit("job", t, R, d)
        if ev is not None:
            pl.jobs.append((pl.at(t), pl.at(t_end), sector))
        if t_end - t >= 2.5 and R.random() < 0.5:
            pl.emit("promotion", t + (t_end - t) * 0.5, R, _sector_detail(R, sector, occ, senior=True, employer=d["employer"]))
        if R.random() < 0.04 * (t_end - t):
            pl.emit("workplace_award", t + (t_end - t) * R.random(), R, _sector_detail(R, sector, occ, employer=d["employer"]))
        n_jobs += 1
        prev_sector = sector
        # next job: same sector or a change
        change = R.random() < P["p_career_change_per_job"] or (changer and n_jobs == 1)
        if arch == "researcher":
            change = R.random() < 0.2
        if change:
            others = [s for s in sectors if s != sector] or sectors
            sector = pick(R, others) if arch != "researcher" else pick(R, ["education", "software"])
            if t_end < end_t - 0.3:
                pl.emit("employment_transition", t_end, R, {"sector_label": sector.replace("_", " ")})
        t = t_end
        if t < end_t - 0.3 and R.random() < 1 - math.exp(-P["p_unemployment_spell_per_year"] * L):
            pl.emit("job_loss", t, R, {"employer": d["employer"]})
            gap = R.choice([3, 5, 8, 10]) / 12
            pl.emit("unemployed", t + 0.05, R)
            t += gap
    if owner and biz_age is not None:
        sec = pick(R, sectors)
        biz = pick(R, BUSINESSES.get(sec, ["small business"]))
        sd = _sector_detail(R, sec)
        pl.emit("business_start", biz_age, R, {"biz": biz, "sector": sec} | {k: sd[k] for k in ("sector_content", "sector_setting", "sector_form")})
        pl.jobs.append((pl.at(biz_age), pl.asof_mi, "owner"))
        for y in range(int(biz_age) + 1, int(now) + 1):
            if R.random() < 0.3:
                pl.emit("business_growth", y + R.random(), R, {"sector_setting": sd["sector_setting"], "sector_content": sd["sector_content"]})
    if now >= retire or (arch == "retiree" and now >= 50):
        last_emp = pick(R, SECTORS[prev_sector or sectors[0]]["employers"])
        pl.emit("retirement", retire, R, {"employer": last_emp})


def m_family(pl, P):
    R = stream(pl.seed, "family")
    now = pl.exact_age
    partner_age = None
    if R.random() < P["p_partner_by_50"]:
        partner_age = max(17.0, R.gauss(P["age_partner_mean"] - 2, P["age_partner_sd"]))
        pn = pick(R, C.TEMPLATES["partner"].slots["pname"])
        pl.emit("partner", partner_age, R, {"pname": pn})
        if R.random() < 0.7:
            mar = max(18.0, partner_age + R.uniform(0.5, 4.0))
            pl.emit("marriage", mar, R, {"pname": pn})
            if R.random() < P["p_separation"] and now > mar + 4:
                pl.emit("separation", mar + R.uniform(3, 20), R, {"pname": "my spouse"})
        elif R.random() < P["p_separation"] and now > partner_age + 4:
            pl.emit("separation", partner_age + R.uniform(3, 15), R, {"pname": "my partner"})
    has_children = R.random() < P["p_children"] * (1.0 if partner_age is not None else 0.2)
    if pl.arch.get("carer") and partner_age is not None:
        has_children = True
    if has_children:
        a0 = max(17.0, R.gauss(P["age_first_birth_mean"], 3.5))
        if partner_age is not None:
            a0 = max(a0, partner_age + 1.0)
        n = 1 + poisson(R, P["n_children_given_any"] - 1)
        n = min(n, 4)
        a = a0
        for k in range(n):
            ch = pick(R, C.TEMPLATES["birth_of_child"].slots["child"])
            pl.emit("birth_of_child", a, R, {"child": ch})
            pl.emit("parenting", a + 1.0, R, {"child": "our child" if k else pick(R, ["our first child", "our baby"])})
            pl.emit("parenting_teen", a + 13.0, R, {"child": "our child"})
            a += R.uniform(1.8, 4.5)
    # losses
    for who, mean_age in (("mother", 28), ("father", 31)):
        pa = R.gauss(mean_age, 4)
        death = pa + R.gauss(79, 8)
        if death > 25 and R.random() < 0.9:
            pl.emit("bereavement", death, R, {"relative": who})
    for y in range(14, int(now) + 1):
        if R.random() < 0.5:
            pl.emit("family_ritual", y + R.random(), R)


def m_care(pl, P):
    R = stream(pl.seed, "care")
    now = pl.exact_age
    carer = pl.arch.get("carer")
    if (carer or R.random() < P["p_eldercare"]) and now >= 25:
        start = max(24.0, now - R.uniform(4, 12)) if carer else R.uniform(40, 65)
        rel = pick(R, C.TEMPLATES["eldercare"].slots["relative"])
        cond = pick(R, C.TEMPLATES["eldercare"].slots["cond"])
        stint = R.uniform(2, 8)
        pl.emit("care_registration", start, R, {"relative": rel})
        y = start
        while y < min(start + stint, now):
            if R.random() < 0.95 or y == start:
                pl.emit("eldercare", y, R, {"relative": rel, "cond": cond})
            y += 1.0
    if R.random() < P["p_pet"]:
        a = R.uniform(6, 50)
        if a <= now:
            pl.emit("pet", a, R)
            if R.random() < 0.4:
                pl.emit("pet", a + R.uniform(8, 14), R)
    for y in range(12, int(now) + 1):
        if R.random() < P["p_mutual_aid_per_year"]:
            pl.emit("mutual_aid", y + R.random(), R)


def m_home(pl, P):
    R = stream(pl.seed, "home")
    now = pl.exact_age
    for y in range(8, int(now) + 1):
        if R.random() < P["p_home_project_per_year"] * (0.4 if y < 18 else 1.0):
            kind = R.random()
            pl.emit("home_repair" if kind < 0.35 else "garden" if kind < 0.6 else "home_cook" if kind < 0.8 else "home_energy", y + R.random(), R)
    a = 18.5
    while a < now:
        a += R.expovariate(1 / 7.0)
        if a < now:
            pl.emit("move", a, R)
    if R.random() < P["p_buy_home_by_40"] or (pl.arch.get("owner") and R.random() < 0.8):
        pl.emit("own_home", max(21.0, R.gauss(P["age_buy_home_mean"], 4)), R)


def m_health(pl, P):
    R = stream(pl.seed, "health")
    now = pl.exact_age
    for age in (0.2, 1.1, 4.2, 12.3):
        pl.emit("vaccination", age + R.random() * 0.3, R)
    active = R.random() < P["p_exercise_regular"]
    for y in range(0, int(now) + 1):
        a = y + R.random()
        if y >= 18 and R.random() < P["p_preventive_per_year"]:
            pl.emit("preventive", a, R)
            if R.random() < 0.3:
                pl.emit("vaccination", a + 0.1, R)
        if active and 11 <= y <= 78 and R.random() < 0.55:
            pl.emit("exercise", a, R)
        h = P["p_health_event_per_year"] * math.exp(P["health_age_slope"] * (y - 30)) * (0.6 if y < 18 else 1.0)
        if R.random() < h:
            u = R.random()
            pl.emit("injury" if u < 0.3 else "illness", a, R)
        if y >= 14 and R.random() < P["p_mental_episode_per_year"]:
            pl.emit("mental", a, R)
        if y >= 14 and R.random() < 0.03:
            pl.emit("diet", a, R)


def m_leisure(pl, P):
    R = stream(pl.seed, "leisure")
    now = pl.exact_age
    interests = set(pl.arch.get("interests", []))
    pool = [h for h in C.HOBBIES]
    favs = [h for h in pool if h[0] in interests]
    chosen = []
    for _ in range(2):
        h = pick(R, favs) if favs and R.random() < 0.6 else pick(R, pool)
        chosen.append(h)
    spans = []
    for h in chosen:
        s = max(h[4], R.uniform(h[4], 30))
        spans.append((h, s, s + R.uniform(5, 45)))
    for y in range(4, int(now) + 1):
        a = y + R.random()
        for (dom, dtext, stext, opts, amin), s, e in spans:
            if s <= a <= e and R.random() < 0.35:
                x = pick(R, opts)
                key = {"c.music_making": "instrument", "c.sport_participation": "sport", "c.visual_arts": "art", "c.crafts_hobbies": "craft",
                       "c.creative_writing": "what", "c.video_gaming": "game", "c.outdoor_recreation": "act", "c.performing_arts": "what",
                       "c.games_play": "what", "c.film_tv_video": "what"}[dom]
                pl.emit("hobby", a, R, {"hobby": dtext.replace("{" + key + "}", x), "hobby_dom": dom, "hobby_s": stext.replace("{" + key + "}", x)})
        if R.random() < P["p_travel_per_year"] * (0.3 if y < 16 else 1.0):
            pl.emit("travel", a, R)
        if R.random() < 0.15 * P["leisure_per_year"] / 1.5:
            pl.emit("concert", a, R)
        if R.random() < 0.15:
            pl.emit("reading", a, R)


def m_faith(pl, P):
    R = stream(pl.seed, "faith")
    now = pl.exact_age
    faithful = R.random() < P["p_faith_active"]
    if faithful:
        pl.emit("rite", 7 + R.random() * 6, R)
        for y in range(6, int(now) + 1):
            if R.random() < 0.7:
                pl.emit("worship", y + R.random(), R)
            if y >= 24 and R.random() < 0.05:
                pl.emit("faith_role", y + R.random(), R)
    for y in range(15, int(now) + 1):
        if R.random() < (0.03 if not faithful else 0.01):
            pl.emit("meaning", y + R.random(), R)


def m_civic(pl, P):
    R = stream(pl.seed, "civic")
    now = pl.exact_age
    cycle = max(1, int(round(P["election_interval_years"])))
    y0 = pl.as_of.year
    voter = R.random()
    for y in range(y0, pl.birth.year + 17, -cycle):
        age = y - pl.birth.year + 0.5
        if age >= 18 and R.random() < P["p_vote"] * (0.7 if age < 25 else 1.0) * (1 if voter < 0.9 else 0):
            pl.emit("vote", age, R)
    vol = R.random() < P["p_volunteer"] or (pl.archname == "retiree" and R.random() < 0.5)
    if vol:
        for _ in range(1 + int(R.random() * 3)):
            a = R.uniform(14, max(15, now))
            org, dom = pick(R, VOL_ORGS)
            pl.emit("volunteer", a, R, {"org": org, "vol_dom": dom})
    for y in range(16, int(now) + 1):
        a = y + R.random()
        if y >= 18 and R.random() < P["p_giving_per_year"] * 0.5:
            pl.emit("giving", a, R)
        if R.random() < 0.04:
            pl.emit("community_group", a, R)
        if y >= 18 and R.random() < 0.1:
            pl.emit("tax", a, R)
        if R.random() < 0.02:
            pl.emit("advocacy", a, R)


def m_consumption(pl, P):
    R = stream(pl.seed, "consumption")
    now = pl.exact_age
    for y in range(5, 16):
        if R.random() < 0.15:
            pl.emit("pocket_money", y + R.random(), R)
    for y in range(14, int(now) + 1):
        a = y + R.random()
        if R.random() < P["p_large_purchase_per_year"]:
            pl.emit("large_purchase", a, R)
        if y >= 18 and R.random() < 0.05:
            pl.emit("loan", a, R)
        if y >= 18 and R.random() < 0.06:
            pl.emit("saving", a, R)
        if R.random() < 0.06:
            pl.emit("repair_reuse", a, R)
    if R.random() < 0.75:
        a = R.uniform(17, 20)
        if pl.emit("driving_licence", a, R):
            pl.licence_mi = pl.at(a)
    if R.random() < 0.03:
        pl.emit("relocation_abroad", R.uniform(20, 45), R)


def _employed_at(pl, i):
    return any(s <= i <= e for s, e, _ in pl.jobs)


def m_harm(pl, P):
    R = stream(pl.seed, "harm")
    now = pl.exact_age
    n = 0
    for y in range(12, int(now) + 1):
        if n >= 3 or R.random() >= P["p_harm_per_year"] * (1.5 if y < 30 else 1.0):
            continue
        a = y + R.random()
        i = pl.at(a)
        cand = []
        if pl.licence_mi and i >= pl.licence_mi:
            cand.append("traffic_offence")
        if _employed_at(pl, i):
            cand.append("workplace_negligence")
        if a <= 30:
            cand += ["petty_theft", "academic_cheating"]
        if 8 <= a <= 19:
            cand.append("bullying")
        if a >= 14:
            cand.append("misinformation")
        cand = [k for k in cand if C.TEMPLATES[k].amin <= a <= C.TEMPLATES[k].amax]
        if cand:
            pl.emit(pick(R, cand), a, R)
            n += 1


MODULES = (m_education, m_work, m_family, m_care, m_home, m_health, m_leisure, m_faith, m_civic, m_consumption, m_harm)


# ---------- participation ----------
class _Fmt(dict):
    def __missing__(self, k):
        return "{" + k + "}"


def fmt(text, detail):
    if text is None:
        return None
    out = text
    for _ in range(2):  # slots may hold {city}
        out = out.format_map(_Fmt(detail))
    return out


def participation(tpl, detail, eid, me, R):
    roles = tpl.roles
    ids = {r: f"{eid}:{r}" for r in roles}
    participants = [{"id": me, "label": "the person"}] + [{"id": ids[r], "label": r} for r in roles]

    def entry(pid, contribution, production, impact=(), **kw):
        return {"id": pid, "contribution": contribution, "responsibility": 0.0, "impact": list(impact), "acting_for": None, "under_agreement": None,
                "informed": None, "volition": "free" if contribution > 0 else None, "volition_record": None, "production": production,
                "option_set": None, **kw}

    pat = tpl.pattern
    me_e = entry(me, 1.0, "produced")
    others = []
    if pat == "make":
        pass
    elif pat == "consume":
        me_e = entry(me, 0.0, "consumed", [{"party": me, "sign": 1, "magnitude": 1}])
    elif pat == "give":
        c = round(R.uniform(0.7, 0.9), 3) if len(roles) <= 1 else round(R.uniform(0.35, 0.5), 3)
        rest = [r for r in roles[1:]]
        me_e = entry(me, c, "produced", [{"party": ids[roles[0]], "sign": 1, "magnitude": R.choice([1, 2, 2, 3]), **({"count": R.choice([1, 1, 2, 3])} if tpl.key in ("volunteer", "tutoring", "giving") else {})}])
        others.append(entry(ids[roles[0]], 0.0, "consumed"))
        for r in rest:
            others.append(entry(ids[r], round((1 - c) / len(rest) - 0.001, 3), "produced"))
    elif pat == "receive":
        me_e = entry(me, 0.0, "consumed", [{"party": me, "sign": 1, "magnitude": R.choice([1, 1, 2])}])
        others.append(entry(ids[roles[0]], 0.9, "produced", [{"party": me, "sign": 1, "magnitude": R.choice([1, 2, 2])}]))
        if tpl.area == "health":
            others[0]["informed"] = "informed consent recorded"
    elif pat == "joint":
        c = round(R.uniform(0.15, 0.5), 3)
        me_e = entry(me, c, "produced")
        for r in roles:
            others.append(entry(ids[r], round((1 - c) / len(roles) - 0.001, 3), "produced"))
        if "employer" in roles:
            me_e["acting_for"] = detail.get("employer") or "the employer"
            me_e["under_agreement"] = "employment contract"
    elif pat == "vote":
        me_e = entry(me, 0.0001, "produced")
        # the vote produces a share of the electorate's decision; the electorate receives it
        others.append(entry(ids.get("electorate", f"{eid}:electorate"), 0.0, "consumed"))
        participants.append({"id": f"{eid}:electorate", "label": "electorate"})
        me_e["impact"] = [{"party": f"{eid}:electorate", "sign": 1, "magnitude": 1, "count": R.choice([2000, 15000, 80000])}]
    elif pat == "harm":
        c = round(R.uniform(0.6, 1.0), 3)
        victim = ids[roles[0]]
        opts = [{"alternative": a, "harm": h} for a, h in tpl.options]
        me_e = entry(me, c, "produced", [{"party": victim, "sign": -1, "magnitude": tpl.harm}], option_set=opts)
        if R.random() < 0.2:
            me_e["volition"] = "constrained"
            me_e["volition_record"] = "under pressure at the time"
        others.append(entry(victim, 0.0, None))
        others[-1]["volition"] = None
        extra = round(1 - c - 0.001, 3)
        if extra > 0.05 and len(roles) > 1:
            others.append(entry(ids[roles[1]], extra, "produced"))
    present = {e["id"] for e in others}
    for r in roles:  # a listed role that takes no part in the pattern stays a bystander
        if ids[r] not in present:
            others.append(entry(ids[r], 0.0, None))
    harm_level = tpl.harm if pat == "harm" else 0
    for e in [me_e, *others]:
        e["responsibility"] = round(responsibility_from_freedom(e["contribution"], e["option_set"] if e["option_set"] is not None else [], harm_level if e["id"] == me else 0), 4)
    if tpl.key == "move":
        me_e["under_agreement"] = "tenancy agreement"
    return participants, {"verdict": "participation", "participants": [me_e, *others]}


# ---------- records: which tiers capture an event ----------
LOG_ADOPTION = {"wearable-log": "p_measured_logged", "payment-log": "p_digital_trace", "bank-log": "p_digital_trace", "booking-log": "p_digital_trace",
                "ticket-log": "p_digital_trace", "smart-meter": None, "platform-moderation-log": None, "publication-index": None,
                "accounts-ledger": None}
LOG_FIXED = {"smart-meter": 0.4, "platform-moderation-log": 1.0, "publication-index": 0.95, "accounts-ledger": 0.6}
CONF_FLOOR = 0.05


def _membership_weights(tpl, detail):
    """The event's memberships: placeholders like {sector_content} expand to the detail's domain map."""
    out = []
    for rel in ("form", "content", "outcome", "setting"):
        spec = tpl.mem.get(rel)
        if not spec:
            continue
        w = {}
        for k, v in spec.items():
            if k.startswith("{"):
                val = detail.get(k[1:-1])
                if val is None:
                    raise KeyError(f"{tpl.key}: detail lacks {k}")
                if isinstance(val, str):
                    w[val] = w.get(val, 0) + v
                else:
                    for d, x in val.items():
                        w[d] = w.get(d, 0) + v * x
            else:
                w[k] = w.get(k, 0) + v
        for d, x in normalise(w).items():
            out.append({"domain": d, "rel": rel, "weight": round(x, 6)})
    # rounding must keep each relation summing to 1
    by = {}
    for mm in out:
        by.setdefault(mm["rel"], []).append(mm)
    for ms in by.values():
        ms[-1]["weight"] = round(1 - sum(x["weight"] for x in ms[:-1]), 6)
    return out


def _day(R, i, as_of):
    y, mo = i // 12, i % 12 + 1
    top = 28
    if (y, mo) == (as_of.year, as_of.month):
        top = max(1, min(28, as_of.day))
    return dt.date(y, mo, R.randint(1, top))


def _conf(R, P, tier, base_key, years_ago=0.0):
    c = P[base_key] + R.gauss(0, P["conf_noise_sd"])
    if tier == "claimed":
        c -= P["recall_decay_per_year"] * years_ago
    return round(clip(c, CONF_FLOOR, 0.97), 3)


def _lines_resume(pl, evs, tpls):
    """Lines of the resume; returns (lines, {event index: line number})."""
    c = pl.contact
    lines = [pl.name, f"{c['email']} | {c['phone']} | {c['address']}"]
    if pl.dob_style:
        lines.append(f"Date of birth: {pl.birth.day} {MONTHS[pl.birth.month - 1]} {pl.birth.year}")
    lines += ["", "Summary", f"{pl.archname.replace('_', ' ').capitalize()} based in {pl.city}, {pl.country}.", ""]
    groups = {"Experience": [], "Education and training": [], "Volunteering and community": [], "Other": []}
    for idx in evs:
        e, t = pl._events[idx], tpls[idx]
        sec = "Experience" if t.area == "work" else "Education and training" if t.area == "learning" else "Volunteering and community" if t.area in ("civic", "faith") else "Other"
        groups[sec].append(idx)
    where = {}
    for sec, idxs in groups.items():
        if not idxs:
            continue
        lines.append(sec)
        for idx in sorted(idxs, key=lambda k: -pl._events[k]["mi"]):
            e, t = pl._events[idx], tpls[idx]
            d = e["detail"]
            y0 = e["mi"] // 12
            if t.key == "job" and d.get("years"):
                y1 = y0 + int(round(d["years"]))
                end = "present" if pl._events[idx]["mi"] + int(d["years"] * 12) >= pl.asof_mi - 6 and not d.get("first") else str(y1)
                period = f"{y0}-{end}"
            else:
                period = str(y0)
            frag = fmt(t.r, d)
            e["phrase_resume"] = frag
            lines.append(f"{period}  {frag}")
            where[idx] = len(lines)
        lines.append("")
    if lines[-1] == "":
        lines.pop()
    return lines, where


def generate_persona(seed, archetype="generalist", age=30, as_of="2026-11-24", params=None, calibration=None, pid=None):
    """One persona: events, evidence rows, texts. Deterministic in (seed, archetype, age, as_of, params, calibration)."""
    if archetype not in ARCHETYPES:
        raise ValueError(f"unknown archetype {archetype!r}")
    if not isinstance(age, int) or age < 0 or age > 110:
        raise ValueError(f"age must be an integer 0-110, not {age!r}")
    arch = ARCHETYPES[archetype]
    P = resolve({**arch["params"], **(params or {})})
    pid = pid or f"s{seed:04d}"
    pl = Plan(seed, archetype, age, as_of, P, pid)
    cal_R = stream(seed, "calibration")
    if calibration is None:
        u = cal_R.random()
        calibration = "over" if u < P["p_over"] else "under" if u < P["p_over"] + P["p_under"] else "well"
    if calibration not in CALIBRATIONS:
        raise ValueError(f"calibration must be one of {CALIBRATIONS}")
    first, last = pl.name.split(" ", 1)
    pl.contact = {"email": f"{first.lower()}.{last.lower().replace(chr(39), '')}@example.org", "phone": f"(415) 555-0{pl.phone_tail}",
                  "address": f"{pl.street}, {pl.city}"}
    base = {"over": P["bias_over"], "under": P["bias_under"], "well": 0.0}[calibration]
    bias = base + cal_R.gauss(0, P["bias_sd"] * (0.5 if calibration == "well" else 1.0))
    persona = Persona(pid, seed, archetype, age, pl.birth.isoformat(), as_of, pl.name, calibration, bias, pl.country, pl.city, pl.contact,
                      params=dict(params or {}))
    for mod in MODULES:
        mod(pl, P)
    raw = sorted(pl.raw, key=lambda e: (e["mi"], e["key"]))
    pl._events = raw
    tpls = [C.TEMPLATES[e["key"]] for e in raw]
    # --- participation, ids ---
    R_p = stream(seed, "participation")
    events = []
    for n, (e, t) in enumerate(zip(raw, tpls)):
        eid = f"{pid}-e{n:03d}"
        parts, ans = participation(t, e["detail"], eid, persona.entity, R_p)
        events.append({"id": eid, "key": t.key, "area": t.area, "valid_time": ym(e["mi"]), "label": fmt(t.d, e["detail"]), "detail": {
            k: v for k, v in e["detail"].items() if isinstance(v, (str, int, float, bool))}, "participants": parts, "participation": ans,
            "tiers": [], "rows": [], "phrase": None})
    # --- which tiers record each event ---
    R_t = stream(seed, "tiers")
    verb = R_t.uniform(0.6, 1.4)
    adopt = {src: (R_t.random() < P[k] if k else R_t.random() < LOG_FIXED[src]) for src, k in LOG_ADOPTION.items()}
    if archetype == "researcher":
        adopt["publication-index"] = True
    decided = []
    for n, (e, t) in enumerate(zip(raw, tpls)):
        tiers = []
        a_p = P["p_attested_formal"] if t.record == "formal" else P["p_attested_informal"]
        if t.src and R_t.random() < a_p:
            tiers.append("attested")
        if t.logsrc and adopt.get(t.logsrc) and R_t.random() < P["p_log_capture"]:
            tiers.append("measured")
        claim_p = clip(P["p_claim_mention"] * verb * t.claim, 0.0, 0.97)
        if R_t.random() < claim_p:
            tiers.append("claimed")
        if not tiers and t.anchor:
            tiers.append("attested" if t.src else "claimed")
        decided.append(tiers)
    # a diary needs a few lines: promote some unrecorded or unclaimed events when too few were claimed
    claimed_idx = [n for n, ts in enumerate(decided) if "claimed" in ts]
    pool = [n for n, ts in enumerate(decided) if "claimed" not in ts and tpls[n].area != "harm"]
    R_t2 = stream(seed, "promote")
    R_t2.shuffle(pool)
    while len(claimed_idx) < 4 and pool:
        n = pool.pop()
        decided[n].append("claimed")
        claimed_idx.append(n)
    # --- documents ---
    R_d = stream(seed, "documents")
    docs = {}
    for n in claimed_idx:
        t = tpls[n]
        if t.area == "harm":
            docs[n] = "diary"
        elif t.r and age >= 16 and R_d.random() < 0.85:
            docs[n] = "resume"
        elif t.s and R_d.random() < 0.35 and sum(1 for d in docs.values() if d == "self") < 5:
            docs[n] = "self"
        else:
            docs[n] = "diary"
    resume_lines, resume_where = _lines_resume(pl, [n for n, d in docs.items() if d == "resume"], tpls)
    # self-description
    self_lines = [f"My name is {pl.name} and I am {age} years old.", f"I live in {pl.city}."]
    self_where = {}
    for n in sorted((n for n, d in docs.items() if d == "self"), key=lambda k: raw[k]["mi"]):
        sent = fmt(tpls[n].s, raw[n]["detail"])
        events[n]["phrase_self"] = sent
        self_lines.append(f"{sent}.")
        self_where[n] = len(self_lines)
    # diary
    diary_lines, diary_where, diary_day = [], {}, {}
    for n in sorted((n for n, d in docs.items() if d == "diary"), key=lambda k: raw[k]["mi"]):
        day = _day(R_d, raw[n]["mi"], pl.as_of)
        diary_day[n] = day
        phrase = fmt(tpls[n].d, raw[n]["detail"])
        diary_lines.append(f"{day.isoformat()}: I {phrase}.")
        diary_where[n] = len(diary_lines)
        events[n]["phrase_diary"] = phrase
    # --- potential: latent truth and self-estimate ---
    R_l = stream(seed, "latent")
    weight = {}
    for ev, e, t in zip(events, raw, tpls):
        # potential comes from what the person produces: receiving care or schooling builds none
        learner = t.area == "learning" and t.rel == "impacted"  # schooling builds some potential, at half weight
        if t.area == "harm" or (t.rel == "impacted" and not learner) or (not learner and ev["participation"]["participants"][0]["contribution"] <= 0):
            continue
        for mm in _membership_weights(t, e["detail"]):
            if mm["rel"] == "content":
                weight[mm["domain"]] = weight.get(mm["domain"], 0.0) + mm["weight"] * t.mag * (0.5 if learner else 1.0)
    top = sorted(weight, key=lambda d: (-weight[d], d))[:6]
    skill = R_l.betavariate(4, 4)
    wmax = max(weight.values()) if weight else 1.0
    R_e = stream(seed, "estimate")
    est = {}
    truth = {}
    for d in top:
        te = clip(0.5 * skill + 0.5 * (0.2 + 0.8 * weight[d] / wmax) + R_l.gauss(0, 0.06), 0.02, 0.98)
        ti = clip(0.6 * te + 0.4 * R_l.betavariate(3, 3) + R_l.gauss(0, 0.04), 0.02, 0.98)
        persona.latent[d] = {"expertise": round(te, 4), "impact": round(ti, 4)}
        truth[d] = (te, ti)
    # A self-estimate follows the self-assessment literature (LI.50): it follows the truth with a shallow slope around the
    # middle of the scale, shifted up (better-than-average) and by the persona's own offset, and all of that bias shrinks
    # as feedback in the domain grows (events lived there), so low skill with sparse feedback is over-estimated, the
    # highly skilled under-estimated, and frequent feedback leaves little bias.
    n_events = {}
    for e, t in zip(raw, tpls):
        if t.area != "harm":
            for mm in _membership_weights(t, e["detail"]):
                if mm["rel"] == "content":
                    n_events[mm["domain"]] = n_events.get(mm["domain"], 0) + 1
    for d in top:
        fb = 1.0 - math.exp(-n_events.get(d, 0) / P["est_feedback_scale"])
        persona.latent[d]["feedback"] = round(fb, 4)
        est[d] = {}
        for kind, tv in zip(("expertise", "impact"), truth[d]):
            bias_d = P["est_bta"] + bias + (P["est_slope"] - 1.0) * (tv - 0.5)
            v = tv + (1.0 - fb) * bias_d + R_e.gauss(0, P["est_noise_sd"])
            est[d][kind] = round(clip(v, 0.01, 0.99), 4)
    pred_where = {}
    for d in top:
        lab = seed_label(d).lower()
        lv = next(w for th, w in LEVELS if est[d]["expertise"] < th)
        self_lines.append(f"I would say I am {lv} in {lab}.")
        pred_where[(d, "expertise")] = len(self_lines)
        im = next(w for th, w in IMPACTS if est[d]["impact"] < th)
        self_lines.append(f"What I do in {lab} {im}.")
        pred_where[(d, "impact")] = len(self_lines)
    persona.texts = {"resume": "\n".join(resume_lines) + "\n", "self": "\n".join(self_lines) + "\n", "diary": "\n".join(diary_lines) + "\n"}
    # --- rows ---
    R_r = stream(seed, "rows")
    rows = []
    ctx = {"jurisdiction": pl.country}
    for n, (e, t) in enumerate(zip(raw, tpls)):
        d = e["detail"]
        mem = _membership_weights(t, d)
        me = next(x for x in events[n]["participation"]["participants"] if x["id"] == persona.entity)
        mag = t.mag * R_r.uniform(0.8, 1.2) * (0.6 + 0.4 * me["contribution"] ** 0.5)
        if t.key == "job":
            mag *= clip(0.5 + d.get("years", 1.0) / 5, 0.5, 1.5)
        harm = t.pattern == "harm"
        years_ago = (pl.asof_mi - e["mi"]) / 12
        for tier in ("claimed", "attested", "measured"):
            if tier not in decided[n]:
                continue
            row = {"entity": persona.entity, "relation": t.rel, "memberships": mem, "basemap_version": BASEMAP_VERSION,
                   "channel": "negative" if harm else "positive", "sign": -1 if harm else 1, "entity_kind": "person", "revoked": False}
            row["production"] = me["production"]
            if t.test:
                row["test_kind"] = t.test
            if harm:
                row["option_set"] = me["option_set"]
            if tier == "claimed":
                doc = docs[n]
                if doc == "diary":
                    vt, rt = diary_day[n].isoformat(), min(diary_day[n] + dt.timedelta(days=R_r.randint(0, 30)), pl.as_of).isoformat()
                    span = f"L{diary_where[n]}"
                    events[n]["phrase"] = events[n]["phrase_diary"]
                else:
                    vt = str(e["mi"] // 12) if years_ago > 8 else ym(e["mi"])
                    rt = pl.as_of.isoformat()
                    span = f"L{(resume_where if doc == 'resume' else self_where)[n]}"
                    events[n]["phrase"] = raw[n]["phrase_resume"] if doc == "resume" else events[n]["phrase_self"]
                row.update(tier="claimed", magnitude=round(max(0.0, mag * clip(1 + bias, 0.5, 1.5)), 4), valid_time=vt, record_time=rt,
                           confidence=_conf(R_r, P, "claimed", "conf_claimed", years_ago), provenance={"source": f"{doc}:{pid}", "span": span})
            elif tier == "attested":
                lag = R_r.randint(0, 6)
                rt_i = min(e["mi"] + lag, pl.asof_mi)
                vt = _day(R_r, e["mi"], pl.as_of).isoformat() if t.record == "formal" else ym(e["mi"])
                rt = ym(rt_i) if rt_i > e["mi"] else vt
                row.update(tier="attested", magnitude=round(mag, 4), valid_time=vt, record_time=rt, context=ctx,
                           confidence=_conf(R_r, P, "attested", "conf_attested"), provenance={"source": f"{t.src or 'third-party-attestation'}:{pid}", "span": f"ev:{events[n]['id']}"})
            else:
                day = _day(R_r, e["mi"], pl.as_of)
                row.update(tier="measured", magnitude=round(mag * R_r.uniform(0.9, 1.1), 4), valid_time=day.isoformat(), record_time=f"{day.isoformat()}T12:00Z",
                           confidence=_conf(R_r, P, "measured", "conf_measured"), provenance={"source": f"{t.logsrc}:{pid}", "span": f"ev:{events[n]['id']}"})
            events[n]["rows"].append(len(rows))
            events[n]["tiers"].append(tier)
            rows.append(row)
    for d in top:
        for kind in ("expertise", "impact"):
            mems = [{"domain": d, "rel": "outcome", "weight": 1.0}] if kind == "impact" else [{"domain": d, "rel": "form", "weight": 1.0}, {"domain": d, "rel": "content", "weight": 1.0}]
            rows.append({"entity": persona.entity, "relation": "causal", "memberships": mems, "basemap_version": BASEMAP_VERSION, "channel": "prediction",
                         "sign": 1, "magnitude": est[d][kind], "valid_time": pl.as_of.isoformat()[:7], "record_time": pl.as_of.isoformat(), "tier": "claimed",
                         "confidence": _conf(R_r, P, "claimed", "conf_claimed"), "entity_kind": "person", "revoked": False,
                         "provenance": {"source": f"self:{pid}", "span": f"L{pred_where[(d, kind)]}"}})
    for ev in events:
        for k in ("phrase_diary", "phrase_resume", "phrase_self"):
            ev.pop(k, None)
    persona.events, persona.rows = events, rows
    return persona
