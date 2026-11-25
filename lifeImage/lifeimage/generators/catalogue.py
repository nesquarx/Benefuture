"""Event templates of the synthetic life generator.

A template is a kind of life event: the area of life, how it reads in a diary (`d`), a resume (`r`) and a
self-description (`s`), the memberships of the event (A types: form, content, outcome, setting, each a domain
weight map summing to 1), how the persona takes part (`pattern`), how it is typically recorded (`record`) and
by which source. Domain ids come from `data/coarse/seed_v0.jsonl`. Magnitudes are prototype values, not measurements.

Record classes: formal (a third party keeps a record: school, payroll, clinic, register), log (a device or payment
log may capture it), inf (informal: usually only the person mentions it).
Patterns (see life.py): make, consume, give, receive, joint, vote, harm.
"""
from dataclasses import dataclass, field
from typing import Callable, Optional


@dataclass(frozen=True)
class Tpl:
    key: str
    area: str
    d: str
    mem: dict
    pattern: str = "make"
    rel: str = "causal"
    mag: float = 0.4
    record: str = "inf"
    src: str = ""  # attested source name
    logsrc: str = ""  # measured source name
    r: Optional[str] = None  # resume fragment
    s: Optional[str] = None  # self-description clause
    slots: dict = field(default_factory=dict)
    amin: float = 0.0
    amax: float = 120.0
    roles: tuple = ()
    anchor: bool = False  # a life milestone: always leaves at least one record
    mem_fn: Optional[Callable] = None
    options: tuple = ()  # harm: ((alternative, harm), ...)
    harm: int = 0
    claim: float = 1.0  # multiplier on the propensity to mention it
    test: str = ""  # a test or assessment row: "knowing" (a test of what one knows) or "doing" (an assessment of doing the thing)


def m(f=None, c=None, o=None, s=None):
    return {k: v for k, v in (("form", f), ("content", c), ("outcome", o), ("setting", s)) if v}


L = []


def add(*a, **k):
    L.append(Tpl(*a, **k))


# ---------------- care ----------------
add("eldercare", "care", "looked after my {relative} through {cond}", m({"c.eldercare": 1}, {"c.eldercare": .6, "c.care_of_ill_disabled": .4}, {"c.ageing_body": 1}, {"c.eldercare": 1}),
    "give", mag=.7, record="inf", s="I care for my {relative}", slots={"relative": ["mother", "father", "aunt", "grandmother", "uncle"], "cond": ["a long illness", "dementia", "a hip operation", "failing eyesight", "a stroke"]}, roles=("relative",), amin=22)
add("care_registration", "care", "registered as a carer for my {relative}", m({"c.eldercare": 1}, {"c.welfare_benefits": .5, "c.eldercare": .5}, None, {"c.government_services": 1}),
    "receive", rel="impacted", mag=.2, record="formal", src="carer-allowance-register", slots={"relative": ["mother", "father", "aunt", "grandmother"]}, roles=("agency",), amin=24)
add("pet", "care", "adopted a {pet} called {pname}", m({"c.pet_ownership": 1}, {"c.pet_ownership": 1}, {"c.animal_care_husbandry": 1}, {"c.pet_ownership": 1}),
    "give", mag=.2, record="inf", s="I share my home with a {pet}", slots={"pet": ["dog", "cat", "rabbit", "pair of guinea pigs"], "pname": ["Biscuit", "Pepper", "Mochi", "Juno", "Bramble", "Olive"]}, roles=("pet",), amin=6)
add("mutual_aid", "care", "helped a neighbour {task}", m({"c.mutual_aid": 1}, {"c.mutual_aid": .6, "c.neighbours_community": .4}, {"c.neighbours_community": 1}, {"c.neighbours_community": 1}),
    "give", mag=.25, record="inf", slots={"task": ["move house", "recover after an operation", "fill in a benefits form", "mend a fence", "get to hospital appointments"]}, roles=("neighbour",), amin=12)
add("parenting", "care", "raised {child} through the early years", m({"c.parenting_young_children": 1}, {"c.parenting_young_children": .7, "c.family_ties": .3}, {"c.family_ties": 1}, {"c.household_planning": 1}),
    "give", mag=.8, record="inf", s="I am raising {child}", slots={"child": ["our first child", "our daughter", "our son", "the twins"]}, roles=("child",), amin=16)
add("parenting_teen", "care", "supported {child} through the teenage years", m({"c.parenting_adolescents": 1}, {"c.parenting_adolescents": .7, "c.school_education": .3}, {"c.family_ties": 1}, {"c.household_planning": 1}),
    "give", mag=.6, record="inf", slots={"child": ["our eldest", "our daughter", "our son"]}, roles=("child",), amin=30)

# ---------------- home ----------------
add("home_repair", "home", "{project}", m({"c.home_repair_diy": 1}, {"c.home_repair_diy": .7, "c.home_organisation": .3}, {"c.household_planning": 1}, {"c.household_planning": 1}),
    "make", mag=.3, record="inf", slots={"project": ["repaired the leaking roof myself", "built a garden shed", "replaced the boiler", "painted the whole flat", "fitted new kitchen units", "rewired two rooms with an electrician friend"]}, amin=16)
add("home_energy", "home", "{project}", m({"c.home_energy_utilities": 1}, {"c.home_energy_utilities": .6, "c.waste_recycling": .4}, {"c.environmental_stewardship": 1}, {"c.household_planning": 1}),
    "make", mag=.25, record="log", logsrc="smart-meter", slots={"project": ["insulated the loft", "installed solar panels", "switched to a heat pump", "started composting"]}, amin=20)
add("garden", "home", "{project}", m({"c.household_gardening": 1}, {"c.household_gardening": .7, "c.horticulture_farming": .3}, {"c.self_provisioning": 1}, {"c.household_gardening": 1}),
    "make", mag=.2, record="inf", slots={"project": ["dug a vegetable patch", "planted an apple tree", "grew tomatoes on the balcony", "built raised beds"]}, amin=8)
add("home_cook", "home", "learned to cook {dish} for the family", m({"c.cooking": 1}, {"c.cooking": .7, "c.nutrition_diet": .3}, {"c.eating_drinking": 1}, {"c.household_planning": 1}),
    "make", mag=.2, record="inf", slots={"dish": ["bread from scratch", "a proper curry", "pasta by hand", "a Sunday roast", "soup for the week"]}, amin=10)
add("move", "home", "moved to {place}", m({"c.moving_relocation": 1}, {"c.housing_search": .5, "c.moving_relocation": .5}, {"c.neighbours_community": 1}, {"c.moving_relocation": 1}),
    "make", mag=.3, record="formal", src="tenancy-record", slots={"place": ["a rented flat in {city}", "a shared house near the station", "a terraced house in {city}", "a smaller flat closer to work"]}, amin=18, anchor=False)
add("own_home", "home", "bought a home in {city}", m({"c.rent_mortgage": 1}, {"c.housing_search": .4, "c.rent_mortgage": .6}, {"c.household_planning": 1}, {"c.rent_mortgage": 1}),
    "make", mag=.6, record="formal", src="land-registry", s="I own my home", amin=21, anchor=True)

# ---------------- family ----------------
add("born", "family", "born in {city}", m({"c.birth_of_child": 1}, {"c.pregnancy_birth": 1}, {"c.family_ties": 1}, {"c.medical_care": 1}),
    "receive", rel="impacted", mag=.3, record="formal", src="birth-register", roles=("parents",), anchor=True, claim=0.5)
add("partner", "family", "started seeing {pname}", m({"c.partnership_romance": 1}, {"c.partnership_romance": 1}, {"c.family_ties": 1}, {"c.socialising": 1}),
    "joint", rel="structural", mag=.4, record="inf", s="I live with {pname}", slots={"pname": ["Sam", "Robin", "Alex", "Noor", "Kit", "Dana", "Mika"]}, roles=("partner",), amin=17)
add("marriage", "family", "married {pname}", m({"c.marriage_wedding": 1}, {"c.marriage_cohabitation": 1}, {"c.family_ties": 1}, {"c.family_rituals": 1}),
    "joint", rel="structural", mag=.6, record="formal", src="marriage-register", s="I am married to {pname}", slots={"pname": ["Sam", "Robin", "Alex", "Noor", "Kit", "Dana", "Mika"]}, roles=("partner",), amin=18, anchor=True)
add("birth_of_child", "family", "welcomed {child}", m({"c.birth_of_child": 1}, {"c.pregnancy_birth": .4, "c.parenting_young_children": .6}, {"c.family_ties": 1}, {"c.medical_care": 1}),
    "give", mag=.8, record="formal", src="birth-register", s="I am a parent", slots={"child": ["our first baby", "a daughter", "a son", "twins"]}, roles=("child", "partner"), amin=16, anchor=True)
add("separation", "family", "separated from {pname}", m({"c.divorce": 1}, {"c.divorce": .6, "c.conflict_interpersonal": .4}, {"c.family_ties": 1}, {"c.household_planning": 1}),
    "joint", rel="impacted", mag=.4, record="formal", src="court-record", slots={"pname": ["my partner", "my spouse"]}, roles=("partner",), amin=20, claim=.5)
add("bereavement", "family", "lost my {relative}", m({"c.bereavement": 1}, {"c.death_dying": .5, "c.funeral_mourning": .5}, {"c.family_ties": 1}, {"c.family_rituals": 1}),
    "receive", rel="impacted", mag=.4, record="formal", src="death-register", slots={"relative": ["mother", "father", "grandfather", "grandmother", "partner"]}, roles=("family",), amin=3)
add("family_ritual", "family", "hosted the family {occasion}", m({"c.family_rituals": 1}, {"c.family_rituals": .5, "c.celebrations": .5}, {"c.family_ties": 1}, {"c.hospitality_hosting": 1}),
    "give", mag=.2, record="inf", slots={"occasion": ["for the winter holiday", "for a big birthday", "reunion", "for a naming day"]}, roles=("family",), amin=14)

# ---------------- health ----------------
add("vaccination", "health", "got the {vax} vaccination", m({"c.preventive_health": 1}, {"c.preventive_health": 1}, {"c.physical_health": 1}, {"c.medical_care": 1}),
    "receive", rel="impacted", mag=.1, record="formal", src="immunisation-record", slots={"vax": ["measles", "polio", "tetanus", "HPV", "flu", "whooping cough"]}, roles=("clinic",), claim=.3)
add("preventive", "health", "went for {check}", m({"c.preventive_health": 1}, {"c.preventive_health": .6, "c.medical_care": .4}, {"c.physical_health": 1}, {"c.medical_care": 1}),
    "receive", rel="impacted", mag=.15, record="formal", src="clinic-record", slots={"check": ["a routine health check", "a screening appointment", "a dental check-up", "an eye test"]}, roles=("clinic",), amin=18, claim=.3)
add("exercise", "health", "{activity}", m({"c.exercise_fitness": 1}, {"c.exercise_fitness": .6, "c.sport_participation": .4}, {"c.physical_health": 1}, {"c.outdoor_recreation": 1}),
    "make", mag=.25, record="log", logsrc="wearable-log", slots={"activity": ["ran three mornings a week all summer", "swam most weekends", "cycled to work through the year", "joined a gym and kept going", "walked 8,000 steps a day"]}, amin=11)
add("illness", "health", "was ill with {cond}", m({"c.serious_illness": 1}, {"c.serious_illness": .5, "c.medical_care": .5}, {"c.physical_health": 1}, {"c.medical_care": 1}),
    "receive", rel="impacted", mag=.5, record="formal", src="clinic-record", slots={"cond": ["pneumonia", "a kidney infection", "appendicitis", "a heart scare", "long covid", "a slipped disc"]}, roles=("clinic",), amin=1, claim=.7)
add("injury", "health", "broke a {bone} {how}", m({"c.accident_injury": 1}, {"c.accident_injury": .6, "c.medical_care": .4}, {"c.physical_health": 1}, {"c.medical_care": 1}),
    "receive", rel="impacted", mag=.35, record="formal", src="clinic-record", slots={"bone": ["wrist", "ankle", "collarbone", "leg"], "how": ["playing football", "on an icy pavement", "falling off a bike", "on a ladder"]}, roles=("clinic",), amin=3, claim=.6)
add("mental", "health", "went through a hard patch and {help}", m({"c.mental_health": 1}, {"c.mental_health": .6, "c.counselling_therapy": .4}, {"c.mental_health": 1}, {"c.counselling_therapy": 1}),
    "receive", rel="impacted", mag=.4, record="formal", src="clinic-record", slots={"help": ["saw a counsellor for six months", "started therapy", "took time off and recovered", "joined a support group"]}, roles=("clinic",), amin=14, claim=.4)
add("diet", "health", "changed how I eat: {change}", m({"c.nutrition_diet": 1}, {"c.nutrition_diet": .6, "c.eating_drinking": .4}, {"c.physical_health": 1}, {"c.household_planning": 1}),
    "make", mag=.15, record="inf", slots={"change": ["less sugar", "mostly vegetarian", "regular meals at last", "smaller portions"]}, amin=14)

# ---------------- learning ----------------
add("nursery", "learning", "started nursery at {school}", m({"c.early_childhood_education": 1}, {"c.early_childhood_education": 1}, {"c.children_play": 1}, {"c.early_childhood_education": 1}),
    "receive", rel="impacted", mag=.2, record="formal", src="nursery-record", slots={"school": ["Little Acorns", "the village playgroup", "Sunnyside Nursery"]}, roles=("teachers",), amin=2, amax=7, claim=.3)
add("school", "learning", "started {school}", m({"c.school_education": 1}, {"c.school_education": .6, "c.basic_skills": .4}, {"c.school_education": 1}, {"c.school_education": 1}),
    "receive", rel="impacted", mag=.3, record="formal", src="school-record", r="Attended {school}", slots={"school": ["Brookfield Primary School", "Hillcrest Primary", "Kingsmead Secondary School", "Eastgate Academy", "Westfield High School"]}, roles=("teachers",), amin=4, claim=.5)
add("school_achievement", "learning", "{ach}", m({"c.school_education": 1}, {"c.school_education": .5, "c.exams_assessment": .5}, {"c.school_education": 1}, {"c.school_education": 1}),
    "make", mag=.25, record="formal", src="school-record", slots={"ach": ["won the school science prize", "finished the maths challenge in the top ten", "played the lead in the school play", "read the most books in the class", "captained the school team"]}, amin=7, amax=19, roles=("teachers",), claim=.9)
add("exam", "learning", "passed {exam}", m({"c.exams_assessment": 1}, {"c.school_education": .5, "c.basic_skills": .5}, {"c.school_education": 1}, {"c.school_education": 1}),
    "make", mag=.5, record="formal", src="exam-board-record", r="Passed {exam}", slots={"exam": ["national secondary exams", "advanced level exams", "the school-leaving certificate", "the baccalaureate-equivalent"]}, amin=15, anchor=True, test="knowing")
add("degree", "learning", "graduated from {uni} in {field}", m({"c.higher_education": 1}, {"{field_dom}": 1}, {"c.higher_education": 1}, {"c.higher_education": 1}),
    "make", mag=.7, record="formal", src="university-record", r="{degree} in {field}, {uni}", s="I hold a degree in {field}", slots={"uni": ["Ravensworth University", "Eastgate College", "the Hartley Institute", "Northmoor University"], "degree": ["BSc", "BA", "BEng", "MA"]}, amin=19, anchor=True)
add("degree_start", "learning", "started studying {field} at {uni}", m({"c.higher_education": 1}, {"{field_dom}": 1}, None, {"c.higher_education": 1}),
    "receive", rel="impacted", mag=.3, record="formal", src="university-record", r="Studying {field}, {uni}", slots={"uni": ["Ravensworth University", "Eastgate College", "the Hartley Institute", "Northmoor University"]}, roles=("teachers",), amin=17)
add("phd", "learning", "completed a doctorate in {field}", m({"c.research_training": 1}, {"{field_dom}": 1}, {"c.research_training": 1}, {"c.higher_education": 1}),
    "make", mag=.8, record="formal", src="university-record", r="PhD, {field}", s="I have a doctorate in {field}", amin=24, anchor=True)
add("course", "learning", "took {kind} course in {skill}", m({"c.vocational_training": 1}, {"{skill_dom}": 1}, {"c.vocational_training": 1}, {"c.vocational_training": 1}),
    "make", mag=.3, record="formal", src="training-record", r="Course in {skill}", slots={"kind": ["an evening", "an online", "a weekend", "an employer-funded"]}, amin=17, claim=1.2)
add("self_study", "learning", "taught myself {skill}", m({"c.self_directed_learning": 1}, {"{skill_dom}": 1}, {"c.self_directed_learning": 1}, {"c.digital_tool_use": 1}),
    "make", mag=.25, record="inf", s="I am teaching myself {skill}", amin=9)
add("language", "learning", "learned {lang} well enough to hold a conversation", m({"c.language_learning": 1}, {"c.language_learning": 1}, {"c.language_learning": 1}, {"c.self_directed_learning": 1}),
    "make", mag=.35, record="inf", r="Conversational {lang}", s="I speak some {lang}", slots={"lang": ["Spanish", "French", "German", "Mandarin", "Arabic", "Portuguese", "Polish"]}, amin=10)
add("tutoring", "learning", "tutored {n} students in {subject}", m({"c.tutoring_teaching": 1}, {"c.school_education": .6, "c.tutoring_teaching": .4}, {"c.school_education": 1}, {"c.tutoring_teaching": 1}),
    "give", mag=.35, record="inf", r="Tutor, {subject} ({n} students)", slots={"n": ["two", "four", "six", "a dozen"], "subject": ["maths", "English", "chemistry", "reading", "piano"]}, roles=("students",), amin=16)
add("publication", "learning", "published a paper on {field}", m({"c.science_research_work": 1}, {"{field_dom}": 1}, {"c.research_training": 1}, {"c.higher_education": 1}),
    "joint", mag=.6, record="log", logsrc="publication-index", r="Paper on {field}", amin=24, roles=("coauthors",), claim=.35)

# ---------------- work ----------------
add("job", "work", "worked as {title} at {employer}", m({"{sector_form}": 1}, {"{sector_content}": 1}, {"{sector_content}": 1}, {"{sector_setting}": 1}),
    "joint", mag=.6, record="formal", src="employer-record", r="{title}, {employer}", s="I work as {title}", amin=14, roles=("colleagues", "employer"), anchor=True, claim=1.2)
add("promotion", "work", "was promoted to {title} at {employer}", m({"{sector_form}": 1}, {"{sector_content}": 1}, {"{sector_content}": 1}, {"{sector_setting}": 1}),
    "joint", mag=.4, record="formal", src="employer-record", r="Promoted to {title}", amin=19, roles=("colleagues", "employer"), claim=1.2)
add("job_loss", "work", "lost my job when {employer} {why}", m({"c.job_loss": 1}, {"c.job_loss": .6, "c.employment_job": .4}, {"c.employment_job": 1}, {"c.employment_job": 1}),
    "receive", rel="impacted", mag=.4, record="formal", src="employer-record", slots={"why": ["closed the site", "cut half the staff", "lost its main client"]}, roles=("employer",), amin=17, claim=.7)
add("employment_transition", "work", "changed careers into {sector_label}", m({"c.employment_transition": 1}, {"c.employment_transition": .6, "c.vocational_training": .4}, {"c.employment_job": 1}, {"c.employment_job": 1}),
    "make", mag=.5, record="inf", r="Career change into {sector_label}", s="I changed careers", amin=22, claim=1.5)
add("retirement", "work", "retired from {employer}", m({"c.retirement": 1}, {"c.retirement": 1}, {"c.employment_job": 1}, {"c.employment_job": 1}),
    "receive", rel="impacted", mag=.4, record="formal", src="pension-record", r="Retired", s="I am retired", roles=("employer",), amin=50, anchor=True)
add("business_start", "work", "started my own {biz}", m({"c.entrepreneurship": 1}, {"c.entrepreneurship": .6, "{sector_content}": .4}, {"c.entrepreneurship": 1}, {"{sector_setting}": 1}),
    "make", mag=.75, record="formal", src="company-register", r="Founder, {biz}", s="I run my own {biz}", amin=20, anchor=True, claim=1.5)
add("business_growth", "work", "{growth}", m({"c.business_administration": 1}, {"c.entrepreneurship": .6, "c.sales_marketing": .4}, {"c.entrepreneurship": 1}, {"{sector_setting}": 1}),
    "joint", mag=.45, record="log", logsrc="accounts-ledger", r="{growth}", slots={"growth": ["hired our first two employees", "reached our first profitable year", "opened a second location", "won a regional supplier contract"]}, roles=("staff",), amin=22, claim=1.5)
add("workplace_award", "work", "won the {award} award at {employer}", m({"{sector_form}": 1}, {"{sector_content}": 1}, {"{sector_content}": 1}, {"{sector_setting}": 1}),
    "make", mag=.35, record="formal", src="employer-record", r="{award} award, {employer}", slots={"award": ["customer service", "safety", "team of the year", "newcomer"]}, amin=18, claim=1.5)
add("unemployed", "work", "was out of work for {months} months", m({"c.job_loss": 1}, {"c.job_search": .6, "c.employment_job": .4}, {"c.employment_job": 1}, {"c.job_search": 1}),
    "receive", rel="impacted", mag=.3, record="formal", src="benefits-record", slots={"months": ["three", "five", "eight", "ten"]}, roles=("agency",), amin=18, claim=.5)

# ---------------- leisure ----------------
add("hobby", "leisure", "{hobby}", m({"{hobby_dom}": 1}, {"{hobby_dom}": 1}, {"{hobby_dom}": 1}, {"{hobby_dom}": 1}),
    "make", mag=.2, record="inf", s="{hobby_s}", amin=5)
add("travel", "leisure", "travelled to {place}", m({"c.tourism_travel": 1}, {"c.tourism_travel": .6, "c.cultural_visits": .4}, {"c.tourism_travel": 1}, {"c.tourism_travel": 1}),
    "consume", rel="impacted", mag=.2, record="log", logsrc="booking-log", slots={"place": ["the coast for a week", "Lisbon", "the mountains", "Istanbul", "a cousin's wedding abroad", "Japan", "Morocco"]}, amin=6, claim=.8)
add("concert", "leisure", "went to {what}", m({"c.festivals_events": 1}, {"c.music_listening": .6, "c.festivals_events": .4}, {"c.festivals_events": 1}, {"c.festivals_events": 1}),
    "consume", rel="impacted", mag=.1, record="log", logsrc="ticket-log", slots={"what": ["a festival with friends", "a concert I had waited years for", "the cup final", "an open-air film night"]}, amin=10)
add("reading", "leisure", "read {n} books about {topic}", m({"c.reading": 1}, {"c.reading": .5, "c.self_directed_learning": .5}, {"c.self_directed_learning": 1}, {"c.reading": 1}),
    "consume", rel="impacted", mag=.15, record="inf", slots={"n": ["a dozen", "twenty", "about thirty"], "topic": ["local history", "birds", "cooking", "the first world war", "gardening", "astronomy"]}, amin=7)

# ---------------- faith and meaning ----------------
add("worship", "faith", "{act}", m({"c.religion_worship": 1}, {"c.religion_worship": .6, "c.spirituality": .4}, {"c.religious_community": 1}, {"c.religious_community": 1}),
    "consume", rel="structural", mag=.25, record="inf", s="I attend {venue} regularly", slots={"act": ["went to services every week", "kept the fast through the whole month", "joined the weekly prayer group", "sang in the congregation most Sundays"], "venue": ["our local congregation"]}, amin=6)
add("faith_role", "faith", "served on the {body}", m({"c.religious_community": 1}, {"c.religious_community": .6, "c.community_groups": .4}, {"c.religious_community": 1}, {"c.religious_community": 1}),
    "joint", mag=.35, record="inf", r="Committee member, {body}", slots={"body": ["parish council", "mosque committee", "temple board", "synagogue committee", "church fundraising team"]}, roles=("members",), amin=24)
add("rite", "faith", "{rite}", m({"c.rites_of_passage": 1}, {"c.religion_worship": .5, "c.rites_of_passage": .5}, {"c.religious_community": 1}, {"c.religious_community": 1}),
    "receive", rel="impacted", mag=.3, record="formal", src="congregation-register", slots={"rite": ["was confirmed", "had my coming-of-age ceremony", "was baptised", "completed religious school"]}, roles=("congregation",), amin=6, claim=.5)
add("meaning", "faith", "spent a year working out what I valued: {how}", m({"c.life_purpose": 1}, {"c.philosophical_inquiry": .5, "c.ethical_choice": .5}, {"c.self_reflection": 1}, {"c.life_purpose": 1}),
    "make", mag=.15, record="inf", slots={"how": ["a philosophy reading group", "long walks and a notebook", "talks with an old friend", "volunteering to see what mattered"]}, amin=15)

# ---------------- civic ----------------
add("vote", "civic", "voted in the {election}", m({"c.voting_elections": 1}, {"c.voting_elections": .7, "c.political_participation": .3}, {"c.public_administration": 1}, {"c.voting_elections": 1}),
    "vote", mag=.1, record="formal", src="electoral-record", slots={"election": ["general election", "local elections", "referendum", "council election"]}, amin=18, claim=.5)
add("volunteer", "civic", "volunteered {n} {unit} a week at {org}", m({"c.volunteering": 1}, {"c.volunteering": .5, "{vol_dom}": .5}, {"{vol_dom}": 1}, {"c.civil_society_advocacy": 1}),
    "give", mag=.45, record="inf", r="Volunteer, {org}", s="I volunteer at {org}", slots={"n": ["two", "three", "four", "six"], "unit": ["hours"]}, roles=("beneficiaries",), amin=14, claim=1.3)
add("giving", "civic", "gave to {cause}", m({"c.charity_giving": 1}, {"c.charity_giving": .6, "c.human_rights": .4}, {"c.civil_society_advocacy": 1}, {"c.civil_society_advocacy": 1}),
    "give", mag=.15, record="log", logsrc="payment-log", slots={"cause": ["the flood appeal", "a children's hospice", "the food bank", "a refugee charity", "a local animal shelter"]}, roles=("charity",), amin=16, claim=.5)
add("community_group", "civic", "joined the {group}", m({"c.community_groups": 1}, {"c.community_groups": .6, "c.neighbours_community": .4}, {"c.neighbours_community": 1}, {"c.community_groups": 1}),
    "joint", rel="structural", mag=.25, record="inf", r="Member, {group}", slots={"group": ["residents' association", "allotment society", "choir", "parents' association", "walking club", "repair cafe"]}, roles=("members",), amin=14)
add("tax", "civic", "filed {what} on time", m({"c.taxation_compliance": 1}, {"c.taxation_compliance": 1}, {"c.public_administration": 1}, {"c.government_services": 1}),
    "make", mag=.08, record="formal", src="tax-record", slots={"what": ["my first tax return", "the household tax return", "the self-assessment"]}, amin=18, claim=.1)
add("advocacy", "civic", "campaigned for {cause}", m({"c.civil_society_advocacy": 1}, {"c.political_participation": .5, "c.civil_society_advocacy": .5}, {"c.public_administration": 1}, {"c.civil_society_advocacy": 1}),
    "joint", mag=.35, record="inf", r="Campaigner, {cause}", slots={"cause": ["a safer crossing outside the school", "the library's opening hours", "a new bus route", "a ban on night flights"]}, roles=("campaigners",), amin=16, claim=1.1)

# ---------------- consumption ----------------
add("large_purchase", "consumption", "bought {item}", m({"c.retail_shopping": 1}, {"c.retail_shopping": .6, "c.household_budgeting": .4}, {"c.household_planning": 1}, {"c.retail_shopping": 1}),
    "consume", rel="impacted", mag=.12, record="log", logsrc="payment-log", slots={"item": ["a second-hand car", "a washing machine", "a laptop", "a new bed", "a bicycle", "a sofa"]}, amin=14, claim=.6)
add("pocket_money", "consumption", "saved my pocket money for {item}", m({"c.household_budgeting": 1}, {"c.retail_shopping": .5, "c.household_budgeting": .5}, {"c.household_budgeting": 1}, {"c.retail_shopping": 1}),
    "consume", rel="impacted", mag=.05, record="inf", slots={"item": ["a bike", "a football", "a game", "trainers", "a guitar"]}, amin=5, amax=16)
add("loan", "consumption", "took out a {kind} loan", m({"c.borrowing_debt": 1}, {"c.borrowing_debt": .6, "c.personal_finance": .4}, {"c.personal_finance": 1}, {"c.banking_payments": 1}),
    "receive", rel="impacted", mag=.2, record="formal", src="credit-record", slots={"kind": ["student", "car", "small personal", "home improvement"]}, roles=("lender",), amin=18, claim=.3)
add("saving", "consumption", "started saving {pct} of my pay each month", m({"c.saving_investing": 1}, {"c.saving_investing": .6, "c.personal_finance": .4}, {"c.personal_finance": 1}, {"c.banking_payments": 1}),
    "make", mag=.15, record="log", logsrc="bank-log", slots={"pct": ["a tenth", "a fifth", "what was left"]}, amin=16, claim=.6)
add("repair_reuse", "consumption", "{what}", m({"c.reuse_repair": 1}, {"c.reuse_repair": .6, "c.waste_recycling": .4}, {"c.environmental_stewardship": 1}, {"c.reuse_repair": 1}),
    "make", mag=.1, record="inf", slots={"what": ["mended instead of replacing: a coat, a chair, a bike", "bought second-hand for a whole year", "set up a swap with friends"]}, amin=10)

# ---------------- mobility ----------------
add("driving_licence", "mobility", "passed my driving test", m({"c.driving": 1}, {"c.driving": .6, "c.road_safety": .4}, {"c.driving": 1}, {"c.road_safety": 1}),
    "make", mag=.3, record="formal", src="licence-register", amin=17, anchor=True, test="doing")
add("relocation_abroad", "mobility", "moved abroad to {place}", m({"c.migration": 1}, {"c.border_migration_admin": .5, "c.moving_relocation": .5}, {"c.migration": 1}, {"c.migration": 1}),
    "make", mag=.5, record="formal", src="visa-record", slots={"place": ["Canada", "Germany", "Australia", "Spain", "the Netherlands"]}, amin=18, anchor=True)

# ---------------- rare harm ----------------
add("traffic_offence", "harm", "was fined for {off}", m({"c.traffic_offences": 1}, {"c.road_safety": .5, "c.traffic_offences": .5}, {"c.road_safety": 1}, {"c.driving": 1}),
    "harm", rel="causal", mag=.25, record="formal", src="fine-record", slots={"off": ["speeding", "using a phone while driving", "driving after two drinks"]}, amin=17, harm=1, claim=.2,
    options=(("kept to the limit", 0), ("pulled over to answer", 0), ("carried on", 1)), roles=("road users",))
add("workplace_negligence", "harm", "caused {what}", m({"c.negligence_recklessness": 1}, {"c.occupational_safety": .5, "c.negligence_recklessness": .5}, {"c.occupational_safety": 1}, {"c.employment_job": 1}),
    "harm", rel="causal", mag=.35, record="formal", src="incident-report", slots={"what": ["a spill that injured a colleague", "an error that delayed treatment", "a missed safety check"]}, amin=17, harm=2, claim=.15,
    options=(("run the safety check", 0), ("ask a colleague to cover", 1), ("skip it", 2)), roles=("colleague",))
add("petty_theft", "harm", "was cautioned for {what}", m({"c.theft_property_crime": 1}, {"c.theft_property_crime": 1}, {"c.theft_property_crime": 1}, {"c.retail_shopping": 1}),
    "harm", rel="causal", mag=.2, record="formal", src="police-caution", slots={"what": ["shoplifting", "taking a bike that was not mine", "scrapping copper"]}, amin=13, amax=30, harm=1, claim=.1,
    options=(("paid for it", 0), ("asked a friend to lend money", 0), ("took it", 1)), roles=("shop owner",))
add("bullying", "harm", "was reported for bullying {who}", m({"c.bullying_harassment": 1}, {"c.bullying_harassment": .6, "c.conflict_interpersonal": .4}, {"c.mental_health": 1}, {"c.school_education": 1}),
    "harm", rel="causal", mag=.3, record="formal", src="school-record", slots={"who": ["a classmate", "a younger pupil", "a teammate"]}, amin=8, amax=19, harm=2, claim=.1,
    options=(("stayed out of it", 0), ("told the others to stop", 0), ("joined in", 2)), roles=("classmate",))
add("misinformation", "harm", "passed on a false story that {what}", m({"c.misinformation_defamation": 1}, {"c.misinformation_defamation": .6, "c.social_media": .4}, {"c.reputation_gossip": 1}, {"c.social_media": 1}),
    "harm", rel="causal", mag=.2, record="log", logsrc="platform-moderation-log", slots={"what": ["named a local shop owner", "spread through the parents' group", "cost a neighbour a customer"]}, amin=14, harm=1, claim=.15,
    options=(("checked first", 0), ("said nothing", 0), ("shared it", 1)), roles=("neighbour",))
add("academic_cheating", "harm", "was caught copying in {what}", m({"c.academic_dishonesty": 1}, {"c.academic_dishonesty": 1}, {"c.exams_assessment": 1}, {"c.school_education": 1}),
    "harm", rel="causal", mag=.2, record="formal", src="school-record", slots={"what": ["a coursework essay", "a chemistry test", "a group report"]}, amin=11, amax=30, harm=1, claim=.1,
    options=(("asked for an extension", 0), ("did my own draft", 0), ("copied", 1)), roles=("classmates",))

TEMPLATES = {t.key: t for t in L}
BY_AREA = {}
for t in L:
    BY_AREA.setdefault(t.area, []).append(t)

HOBBIES = [
    ("c.music_making", "played {instrument} in a band", "I play {instrument}", ["guitar", "piano", "drums", "violin", "trumpet"], 6),
    ("c.sport_participation", "played {sport} for the local team", "I play {sport}", ["football", "basketball", "cricket", "hockey", "netball", "rugby"], 6),
    ("c.visual_arts", "painted and sold a few {art}", "I paint", ["watercolours", "portraits", "landscapes", "murals"], 8),
    ("c.crafts_hobbies", "made {craft} for friends", "I make {craft}", ["knitted jumpers", "pottery", "furniture", "quilts", "jewellery"], 8),
    ("c.creative_writing", "wrote {what} and shared it online", "I write", ["short stories", "a blog about home life", "poems", "a novel draft"], 10),
    ("c.video_gaming", "put in serious hours on {game}", "I game", ["a strategy game", "an online team shooter", "a farming simulator", "chess online"], 8),
    ("c.outdoor_recreation", "went {act} most weekends", "I love the outdoors", ["hiking", "climbing", "kayaking", "birdwatching", "fishing"], 8),
    ("c.performing_arts", "joined {what}", "I perform", ["an amateur theatre company", "a dance troupe", "a community choir"], 8),
    ("c.games_play", "ran a weekly {what} night", "I host game nights", ["board game", "quiz", "role-playing game"], 14),
    ("c.film_tv_video", "got into {what}", "I am a film fan", ["film club screenings", "making short videos", "documentaries"], 10),
]
