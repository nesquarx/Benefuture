"""Catalogue of the event kinds added for breadth across the circle (increment 3): one record per kind, the single source of its memberships
(layer A), its participants (layer B), its statement, counterfactual and short-term action phrasing, read by the event builder
(`relational.py` registers every record), by the generators (`domains.py`) and by the calibration fetch tool.

Kinds come in two families. Life-course kinds (work, health, civic, leisure, harm) happen at a date; time-use kinds are short-term actions on a diary day
(timescale minutes/hours) calibrated by published time-use shares (HETUS, India's national time-use survey). A kind names:
  rel/mag      the library's row relation and a prototype magnitude;
  form, content, outcome, setting     domains of layer A (equal weights; each relation sums to 1);
  roles        participants as (role, contribution, production, impacts [(affected role, sign, magnitude)], option): the option set is
               ("free", alternative, harm) for a free act, ("zero",) when no alternative existed (a forced event), ("missing",) when the domain gives no
               option set (the governed default applies and is logged as degraded), or None for a participant that contributes nothing;
  harm         harm of the outcome produced (0-3), read by the responsibility rule;
  stmt         the event's sentence with {who} and {place};
  course       the counterfactual course of the outcome membership; quantity the Param whose rate it comes from.
"""
from collections import namedtuple

Kind = namedtuple("Kind", "key family rel mag form content outcome setting roles stmt course quantity action outcome_text timescale neg harm group code")


def _roles(*r):
    return tuple(r)


SELF_FREE = ("self", 1.0, "both", [("self", 1, 1)], ("free", "do something else", 0))


def kind(key, family, rel, mag, form, content, outcome, setting, roles, stmt, course, quantity, action, outcome_text=None, timescale="life transition",
         neg=False, harm=0, group=None, code=None):
    return Kind(key, family, rel, mag, tuple(form), tuple(content), tuple(outcome), tuple(setting), tuple(roles), stmt, course, quantity, action,
                outcome_text, timescale, neg, harm, group, code)


def solo(key, grp, code, dom, content, outcome, setting, stmt, action, quantity=None):
    return kind(key, "time", "causal", 0.1, [dom], content, outcome, setting, [("self", 1.0, "both", [("self", 1, 1)], ("free", "spend the time otherwise", 0))],
                stmt, "the person does not do this on the diary day", quantity or f"time.participation.{key}", action, None, "minutes/hours", group=grp, code=code)


def with_other(key, grp, code, dom, content, outcome, setting, other, stmt, action, quantity=None, other_impact=1, other_contrib=0.3):
    return kind(key, "time", "causal", 0.1, [dom], content, outcome, setting,
                [("self", 1 - other_contrib, "both", [("self", 1, 1), (other, 1, 1)], ("free", "spend the time otherwise", 0)),
                 (other, other_contrib, "produced", [("self", other_impact, 1)], ("zero",))],
                stmt, "the person does not do this on the diary day", quantity or f"time.participation.{key}", action, None, "minutes/hours", group=grp, code=code)


# ---- time use (HETUS activity codes; groups follow India's national time-use survey 2019) ----
TIME = [
    solo("sleep", "personal_care", "AC01", "c.sleep", ["c.sleep"], ["c.physical_health", "c.mental_health"], ["c.home_organisation"],
         "A {who} in {place} slept at night", "slept through the night in their own bed"),
    solo("eating", "personal_care", "AC02", "c.eating_drinking", ["c.eating_drinking", "c.nutrition_diet"], ["c.nutrition_diet"], ["c.home_organisation", "c.restaurants_dining"],
         "A {who} in {place} sat down to a meal", "sat down and ate a meal"),
    solo("personal_care_other", "personal_care", "AC03", "c.hygiene_grooming", ["c.hygiene_grooming", "c.personal_appearance"], ["c.physical_health"], ["c.home_organisation"],
         "A {who} in {place} washed and groomed", "washed, dressed and groomed"),
    with_other("employment", "employment", "AC1A", "c.employment_job", ["c.employment_job", "c.workplace_relations"], ["c.income_earning"], ["c.employment_job"], "employer",
               "A {who} in {place} worked a shift", "worked a full shift, including the trip to and from work", other_impact=1, other_contrib=0.3),
    with_other("study_class", "learning", "AC21A", "c.school_education", ["c.school_education", "c.basic_skills", "c.higher_education"], ["c.school_education"], ["c.school_education"], "school",
               "A {who} in {place} attended lessons", "attended a day of lessons", other_contrib=0.5),
    solo("homework", "learning", "AC212", "c.self_directed_learning", ["c.self_directed_learning", "c.school_education", "c.exams_assessment"], ["c.school_education"], ["c.home_organisation"],
         "A {who} in {place} did homework", "worked through homework at the kitchen table"),
    solo("free_time_study", "learning", "AC22", "c.self_directed_learning", ["c.self_directed_learning", "c.language_learning", "c.vocational_training"], ["c.basic_skills"], ["c.home_organisation"],
         "A {who} in {place} studied in their own time", "studied a language or course on their own"),
    with_other("cooking", "domestic", "AC31A", "c.cooking", ["c.cooking", "c.household_planning"], ["c.nutrition_diet", "c.family_ties"], ["c.home_organisation"], "family",
               "A {who} in {place} cooked a meal for the household", "prepared the evening meal for the household"),
    solo("dishwashing", "domestic", "AC313", "c.cleaning_laundry", ["c.cleaning_laundry"], ["c.hygiene_grooming"], ["c.home_organisation"],
         "A {who} in {place} washed the dishes", "washed up after the meal"),
    solo("cleaning", "domestic", "AC321", "c.cleaning_laundry", ["c.cleaning_laundry", "c.home_organisation"], ["c.hygiene_grooming", "c.home_organisation"], ["c.home_organisation"],
         "A {who} in {place} cleaned the home", "swept and cleaned the rooms of the home"),
    solo("laundry", "domestic", "AC331", "c.cleaning_laundry", ["c.cleaning_laundry", "c.personal_appearance"], ["c.personal_appearance"], ["c.home_organisation"],
         "A {who} in {place} did the laundry", "washed, hung and folded the family's clothes"),
    solo("gardening_pets", "domestic", "AC34A", "c.household_gardening", ["c.household_gardening", "c.pet_ownership"], ["c.household_gardening", "c.pet_ownership"], ["c.home_organisation", "c.outdoor_recreation"],
         "A {who} in {place} tended the garden and pets", "watered the garden and fed the pets"),
    solo("construction_repairs", "domestic", "AC35", "c.home_repair_diy", ["c.home_repair_diy", "c.maker_tinkering", "c.reuse_repair"], ["c.home_repair_diy"], ["c.home_organisation"],
         "A {who} in {place} repaired something at home", "fixed a leaking tap and mended a shelf at home"),
    with_other("shopping", "domestic", "AC36", "c.shopping_errands", ["c.shopping_errands", "c.retail_shopping", "c.food_purchasing"], ["c.household_budgeting", "c.food_purchasing"],
               ["c.retail_shopping", "c.shopping_errands"], "shop", "A {who} in {place} went shopping", "bought groceries and household goods at a shop", other_contrib=0.3),
    solo("household_management", "domestic", "AC37_39", "c.household_budgeting", ["c.household_budgeting", "c.household_planning", "c.banking_payments", "c.government_services"], ["c.household_budgeting"],
         ["c.home_organisation"], "A {who} in {place} managed household affairs", "paid bills, filled in forms and planned the week for the household"),
    with_other("childcare", "caregiving", "AC38A", "c.parenting_young_children", ["c.parenting_young_children", "c.childcare_other"], ["c.family_ties", "c.children_play"],
               ["c.home_organisation"], "dependent", "A {who} in {place} looked after a child", "fed, bathed and watched over a child", other_contrib=0.1),
    with_other("child_teaching", "caregiving", "AC38B", "c.parenting_young_children", ["c.parenting_young_children", "c.tutoring_teaching", "c.reading"], ["c.basic_skills", "c.family_ties"],
               ["c.home_organisation"], "dependent", "A {who} in {place} read and talked with a child", "read a story and talked through the day with a child", other_contrib=0.2),
    with_other("transporting_child", "caregiving", "AC938", "c.childcare_other", ["c.childcare_other", "c.driving", "c.walking_cycling"], ["c.family_ties", "c.road_safety"],
               ["c.commuting"], "dependent", "A {who} in {place} took a child to school", "walked or drove a child to school and back", other_contrib=0.1),
    with_other("volunteering", "volunteering", "AC41", "c.volunteering", ["c.volunteering", "c.community_groups", "c.civil_society_advocacy"], ["c.community_groups"], ["c.community_groups"], "club",
               "A {who} in {place} did unpaid work for an association", "gave an afternoon to an association's unpaid work", other_contrib=0.3),
    with_other("informal_help", "volunteering", "AC42", "c.mutual_aid", ["c.mutual_aid", "c.neighbours_community", "c.charity_giving"], ["c.neighbours_community", "c.mutual_aid"],
               ["c.neighbours_community"], "neighbour", "A {who} in {place} helped another household", "helped a neighbour carry and repair things", other_contrib=0.1),
    with_other("participatory", "social_religious", "AC43", "c.religion_worship", ["c.religion_worship", "c.religious_community", "c.political_participation", "c.community_groups"],
               ["c.religious_community", "c.community_groups"], ["c.religious_community", "c.community_groups"], "club", "A {who} in {place} took part in a meeting or service",
               "attended a religious service or a community meeting", other_contrib=0.3),
    with_other("visiting_feasts", "social_religious", "AC51A", "c.socialising", ["c.socialising", "c.hospitality_hosting", "c.celebrations", "c.family_rituals"],
               ["c.friendship", "c.family_ties"], ["c.family_rituals", "c.celebrations"], "friend", "A {who} in {place} visited or hosted guests", "visited relatives and shared a festive meal", other_contrib=0.4),
    with_other("social_other", "social_religious", "AC51B", "c.friendship", ["c.friendship", "c.everyday_conversation", "c.socialising"], ["c.friendship", "c.loneliness_isolation"],
               ["c.socialising"], "friend", "A {who} in {place} spent time with friends", "chatted and spent the evening with friends", other_contrib=0.4),
    with_other("entertainment_culture", "leisure", "AC52", "c.cultural_visits", ["c.cultural_visits", "c.film_tv_video", "c.performing_arts", "c.festivals_events"],
               ["c.cultural_visits", "c.cultural_identity"], ["c.cultural_visits", "c.nightlife"], "venue", "A {who} in {place} went out to a show or exhibition", "went to a film, a concert or an exhibition", other_contrib=0.2),
    solo("resting", "leisure", "AC53", "c.mental_health", ["c.mental_health", "c.self_reflection"], ["c.mental_health"], ["c.home_organisation"],
         "A {who} in {place} rested", "sat quietly and rested"),
    solo("sport", "leisure", "AC6A", "c.sport_participation", ["c.sport_participation", "c.exercise_fitness", "c.outdoor_recreation"], ["c.physical_health", "c.exercise_fitness"],
         ["c.sport_participation", "c.outdoor_recreation"], "A {who} in {place} played sport", "played a sport or went for a run"),
    solo("walking_hiking", "leisure", "AC611", "c.walking_cycling", ["c.walking_cycling", "c.outdoor_recreation"], ["c.physical_health", "c.environmental_stewardship"], ["c.outdoor_recreation"],
         "A {who} in {place} walked for pleasure", "walked a long way along a path for pleasure"),
    solo("computing", "leisure", "AC7A", "c.digital_tool_use", ["c.digital_tool_use", "c.social_media", "c.online_commerce"], ["c.digital_tool_use"], ["c.home_organisation"],
         "A {who} in {place} used a computer", "answered messages and browsed on a computer"),
    solo("hobbies_games", "leisure", "AC7B", "c.crafts_hobbies", ["c.crafts_hobbies", "c.games_play", "c.music_making", "c.visual_arts", "c.creative_writing"], ["c.crafts_hobbies"],
         ["c.home_organisation"], "A {who} in {place} pursued a hobby", "played a board game, drew or practised an instrument"),
    solo("computer_games", "leisure", "AC733", "c.video_gaming", ["c.video_gaming", "c.games_play"], ["c.video_gaming"], ["c.home_organisation"],
         "A {who} in {place} played computer games", "played a computer game"),
    solo("reading_periodicals", "leisure", "AC811", "c.news_media", ["c.news_media", "c.reading"], ["c.news_media"], ["c.home_organisation"],
         "A {who} in {place} read a newspaper or magazine", "read the paper and a magazine"),
    solo("reading_books", "leisure", "AC812", "c.reading", ["c.reading", "c.self_directed_learning"], ["c.reading"], ["c.home_organisation"],
         "A {who} in {place} read a book", "read a book for an hour"),
    solo("television", "leisure", "AC82", "c.film_tv_video", ["c.film_tv_video", "c.news_media"], ["c.film_tv_video"], ["c.home_organisation"],
         "A {who} in {place} watched television", "watched a programme on television"),
    solo("radio_music", "leisure", "AC83", "c.music_listening", ["c.music_listening", "c.news_media"], ["c.music_listening"], ["c.home_organisation"],
         "A {who} in {place} listened to radio or music", "listened to the radio and to music"),
    with_other("travel_work", "employment", "AC913", "c.commuting", ["c.commuting", "c.public_transport", "c.driving", "c.walking_cycling"], ["c.commuting", "c.road_safety"],
               ["c.commuting"], "transit", "A {who} in {place} travelled to work", "travelled to work by bus, car or on foot", other_contrib=0.2),
    with_other("travel_shopping", "domestic", "AC936", "c.shopping_errands", ["c.shopping_errands", "c.driving", "c.public_transport"], ["c.shopping_errands"],
               ["c.commuting"], "transit", "A {who} in {place} travelled to do errands", "travelled across town to do errands", other_contrib=0.2),
    with_other("travel_leisure", "leisure", "AC9D", "c.tourism_travel", ["c.tourism_travel", "c.walking_cycling", "c.driving"], ["c.tourism_travel", "c.socialising"],
               ["c.commuting", "c.tourism_travel"], "transit", "A {who} in {place} travelled for leisure", "travelled to meet friends and see a place", other_contrib=0.2),
    with_other("own_use_production", "own_use", None, "c.self_provisioning", ["c.self_provisioning", "c.horticulture_farming", "c.animal_care_husbandry", "c.fishing_hunting_foraging"],
               ["c.self_provisioning", "c.nutrition_diet"], ["c.horticulture_farming", "c.animal_care_husbandry"], "family", "A {who} in {place} produced goods for the household's own use",
               "grew vegetables and tended animals for the household's own use", other_contrib=0.2),
]
TIME_BY_KEY = {k.key: k for k in TIME}
INDIA_GROUPS = {"employment": "Employment and related activities", "own_use": "Production of goods for own final use", "domestic": "Unpaid domestic services for household members",
                "caregiving": "Unpaid caregiving services for household members", "volunteering": "Unpaid volunteer, trainee and other unpaid work", "learning": "Learning",
                "social_religious": "Socializing and communication, community participation and religious practice", "leisure": "Culture, leisure, mass-media and sports practices",
                "personal_care": "Self-care and maintenance"}
# groups with travel kinds: India books travel under the activity it serves; HETUS 'travel' codes map to the same groups (employment, domestic, leisure)
AGE_BANDS = ((15, 20, "15-20"), (20, 25, "20-24"), (25, 45, "25-44"), (45, 65, "45-64"), (65, 200, "65+"))


def free(alt, harm=0):
    return ("free", alt, harm)


def _life(key, family, rel, mag, form, content, outcome, setting, roles, stmt, course, quantity, action, outcome_text=None, timescale="life transition", neg=False, harm=0):
    return kind(key, family, rel, mag, form, content, outcome, setting, roles, stmt, course, quantity, action, outcome_text, timescale, neg, harm)


def person(contrib, option, impacts=None):
    return ("self", contrib, "both", impacts if impacts is not None else [("self", 1, 2)], option)


LIFE = [
    # ---- work and careers ----
    _life("industry_work_start", "work", "structural", 0.5, ["c.employment_job"], ["c.manufacturing", "c.construction_trades", "c.skilled_trades", "c.employment_job", "c.occupational_safety"],
          ["c.income_earning", "c.employment_job"], ["c.manufacturing", "c.construction_trades", "c.employment_job"],
          [person(0.5, free("stay out of the labour force")), ("employer", 0.5, "produced", [("self", 1, 2)], free("leave the post unfilled"))],
          "A {who} in {place} started a first job in industry or construction", "the person stays out of work at this age", "work.industry_employment", "started a first paid job in a workshop or on a site",
          "began earning an income"),
    _life("service_work_start", "work", "structural", 0.5, ["c.employment_job"], ["c.retail_work", "c.hospitality_work", "c.customer_service", "c.personal_services_work", "c.transport_logistics", "c.employment_job"],
          ["c.income_earning", "c.employment_job"], ["c.retail_work", "c.hospitality_work", "c.employment_job"],
          [person(0.5, free("stay out of the labour force")), ("employer", 0.5, "produced", [("self", 1, 2)], free("leave the post unfilled"))],
          "A {who} in {place} started a first job in services", "the person stays out of work at this age", "work.services_employment", "started a first paid job serving customers",
          "began earning an income"),
    _life("farm_work_start", "work", "structural", 0.5, ["c.agri_forestry_fishing_work"], ["c.agri_forestry_fishing_work", "c.horticulture_farming", "c.animal_care_husbandry"],
          ["c.income_earning", "c.self_provisioning"], ["c.horticulture_farming", "c.agri_forestry_fishing_work"],
          [person(0.6, free("take other work")), ("family", 0.4, "produced", [("self", 1, 1)], free("farm without help"))],
          "A {who} in {place} began work in farming, forestry or fishing", "the person does not work in farming", "work.agriculture_employment", "began working in the fields",
          "earned a living from the land"),
    _life("self_employment_start", "work", "structural", 0.5, ["c.entrepreneurship"], ["c.entrepreneurship", "c.business_administration", "c.informal_gig"],
          ["c.income_earning", "c.entrepreneurship"], ["c.entrepreneurship", "c.employment_job"],
          [person(0.7, free("take a post with an employer")), ("customer", 0.3, "consumed", [("self", 1, 1)], None)],
          "A {who} in {place} began working for themselves", "the person works for an employer", "work.self_employment", "began to work on their own account",
          "earned from their own business"),
    _life("job_change", "work", "structural", 0.4, ["c.employment_transition"], ["c.employment_transition", "c.job_search", "c.workplace_relations"],
          ["c.employment_job", "c.income_earning"], ["c.employment_job"],
          [person(0.5, free("stay in the job")), ("employer", 0.5, "produced", [("self", 1, 1)], free("keep the worker in the old role"))],
          "A {who} in {place} changed jobs", "the person stays in the same job", "work.new_job_share", "moved to a new employer",
          "started in a new post"),
    _life("job_search_start", "work", "impacted", 0.4, ["c.job_search"], ["c.job_search", "c.employment_transition", "c.welfare_benefits"],
          ["c.job_search", "c.poverty_scarcity"], ["c.employment_job", "c.government_services"],
          [person(0.8, free("stay out of the labour force")), ("employment_service", 0.2, "produced", [("self", 1, 1)], free("offer no placement", 1))],
          "A {who} in {place} entered the labour force and began looking for a first job", "the person finds a job at once or stays out of the labour force", "work.youth_unemployment",
          "registered as looking for a first job", "searched for weeks before starting work", timescale="weeks-months", neg=True, harm=1),
    _life("job_loss", "work", "impacted", 0.6, ["c.job_loss"], ["c.job_loss", "c.employment_transition", "c.welfare_benefits"],
          ["c.poverty_scarcity", "c.job_search", "c.welfare_benefits"], ["c.employment_job", "c.government_services"],
          [("self", 0.2, "produced", [("self", -1, 2)], ("zero",)), ("employer", 0.8, "produced", [("self", -1, 2)], free("keep the worker", 0))],
          "A {who} in {place} lost a job and began looking for work", "the person keeps the job", "work.unemployment", "was laid off and began looking for a new job",
          "went without pay while searching", timescale="weeks-months", neg=True, harm=2),
    _life("reemployment", "work", "structural", 0.5, ["c.employment_transition"], ["c.job_search", "c.employment_transition", "c.employment_job"],
          ["c.employment_job", "c.income_earning"], ["c.employment_job"],
          [person(0.5, free("keep searching")), ("employer", 0.5, "produced", [("self", 1, 2)], free("leave the post unfilled"))],
          "A {who} in {place} found work after a spell without a job", "the spell of unemployment continues", "work.long_term_unemployment_share", "accepted a job offer after months of searching",
          "returned to paid work"),
    _life("retirement", "work", "structural", 0.6, ["c.retirement"], ["c.retirement", "c.welfare_benefits", "c.ageing_body"], ["c.retirement", "c.household_budgeting"], ["c.government_services", "c.home_organisation"],
          [person(0.6, free("keep working")), ("employer", 0.2, "produced", [("self", 1, 1)], free("keep the worker on")), ("agency", 0.2, "produced", [("self", 1, 1)], free("withhold the pension", 2))],
          "A {who} in {place} left the labour force and retired", "the person stays in the labour force", "work.labour_force_participation", "stopped working and began to draw a pension",
          "lived on a pension and savings"),
    # ---- health and care ----
    _life("vaccination", "health", "impacted", 0.3, ["c.preventive_health"], ["c.preventive_health", "c.medical_care"], ["c.preventive_health", "c.public_health_science"], ["c.medical_care"],
          [("self", 0.0, "consumed", [("self", 1, 2)], None), ("parent", 0.4, "produced", [("self", 1, 2)], free("decline the vaccine", 1)), ("clinic", 0.6, "produced", [("self", 1, 2)], free("withhold the vaccine", 1))],
          "A child in {place} was vaccinated against measles", "the child is not vaccinated", "health.measles_immunisation", "was held while a nurse gave the measles injection",
          "was protected against measles", timescale="minutes/hours"),
    _life("chronic_condition_onset", "health", "impacted", 0.6, ["c.serious_illness"], ["c.serious_illness", "c.physical_health", "c.medication_adherence"],
          ["c.physical_health", "c.medication_adherence", "c.medical_care"], ["c.medical_care", "c.home_organisation"],
          [("self", 0.0, "consumed", [("self", -1, 2)], None), ("clinic", 1.0, "produced", [("self", 1, 1)], free("miss the diagnosis", 1))],
          "A {who} in {place} was diagnosed with diabetes", "the person is not diagnosed with a long-term condition", "health.diabetes_prevalence", "was diagnosed with diabetes at a clinic",
          "began a lifelong treatment", neg=True, harm=1),
    _life("infectious_illness", "health", "impacted", 0.6, ["c.serious_illness"], ["c.serious_illness", "c.public_health_science", "c.medical_care"],
          ["c.physical_health", "c.medical_care"], ["c.medical_care", "c.public_safety_emergency"],
          [("self", 0.0, "consumed", [("self", -1, 2)], None), ("clinic", 1.0, "produced", [("self", 1, 2)], free("send the patient home untreated", 2))],
          "A {who} in {place} fell ill with tuberculosis", "the person does not fall ill with tuberculosis", "health.tb_incidence", "fell ill with tuberculosis and began months of treatment",
          "completed a course of treatment", timescale="weeks-months", neg=True, harm=2),
    _life("hiv_diagnosis", "health", "impacted", 0.7, ["c.serious_illness"], ["c.serious_illness", "c.sexuality", "c.preventive_health"], ["c.medical_care", "c.medication_adherence", "c.mental_health"],
          ["c.medical_care"], [("self", 0.2, "both", [("self", -1, 3)], ("missing",)), ("clinic", 0.8, "produced", [("self", 1, 2)], free("withhold the test result", 2))],
          "A {who} in {place} was diagnosed with HIV", "the person is not infected with HIV", "health.hiv_prevalence", "was diagnosed with HIV and began treatment",
          "lived with a managed chronic infection", neg=True, harm=2),
    _life("disability_onset", "health", "impacted", 0.6, ["c.disability_adaptation"], ["c.disability_adaptation", "c.care_of_ill_disabled", "c.ageing_body"],
          ["c.disability_adaptation", "c.physical_health", "c.home_repair_diy"], ["c.home_organisation", "c.medical_care"],
          [("self", 0.0, "consumed", [("self", -1, 2)], None), ("family", 0.5, "produced", [("self", 1, 1)], free("leave the person without help", 1)), ("clinic", 0.5, "produced", [("self", 1, 1)], free("offer no rehabilitation", 1))],
          "A {who} in {place} began to live with a lasting limitation", "the person lives without a lasting limitation", "health.disability_prevalence", "began to need help with daily activities because of a lasting health problem",
          "adapted the home and routines", neg=True, harm=1),
    _life("doctor_visit", "health", "impacted", 0.3, ["c.medical_care"], ["c.medical_care", "c.physical_health", "c.preventive_health"], ["c.physical_health", "c.medication_adherence"], ["c.medical_care"],
          [person(0.4, free("stay home")), ("clinic", 0.6, "produced", [("self", 1, 1)], free("turn the patient away", 1))],
          "A {who} in {place} saw a doctor", "the person does not see a doctor this year", "health.doctor_visit_12m", "waited at a surgery and was examined by a doctor",
          "left with advice or a prescription", timescale="minutes/hours"),
    _life("hospital_stay", "health", "impacted", 0.6, ["c.medical_care"], ["c.medical_care", "c.serious_illness", "c.accident_injury"], ["c.physical_health", "c.medical_care"], ["c.medical_care"],
          [("self", 0.1, "both", [("self", 1, 2)], ("zero",)), ("clinic", 0.9, "produced", [("self", 1, 2)], free("discharge the patient untreated", 2))],
          "A {who} in {place} was admitted to hospital", "the person is not admitted", "health.hospital_discharges", "was admitted to hospital for treatment and stayed several days",
          "was treated and discharged", timescale="weeks-months"),
    _life("caregiving_start", "health", "causal", 0.5, ["c.care_of_ill_disabled"], ["c.care_of_ill_disabled", "c.eldercare", "c.family_ties"], ["c.care_of_ill_disabled", "c.family_ties", "c.mental_health"],
          ["c.home_organisation", "c.medical_care"],
          [person(0.7, free("leave the care to others", 1), [("self", 1, 1), ("care_recipient", 1, 2)]), ("care_recipient", 0.0, "consumed", [("self", -1, 1)], None), ("clinic", 0.3, "produced", [("care_recipient", 1, 1)], free("offer no support", 1))],
          "A {who} in {place} was caring regularly for a sick or older relative", "the relative is cared for by others or not at all", "health.informal_care_share", "helped a sick or older relative every week",
          "took on a regular caring role", timescale="years", harm=1),
    # ---- leisure and sport (occasions in a reference year) ----
    _life("cinema_visit", "leisure", "causal", 0.2, ["c.film_tv_video"], ["c.film_tv_video", "c.cultural_visits"], ["c.cultural_visits", "c.socialising"], ["c.cultural_visits", "c.nightlife"],
          [person(0.7, free("stay at home"), [("self", 1, 1)]), ("venue", 0.3, "produced", [("self", 1, 1)], free("close the cinema"))],
          "A {who} in {place} went to the cinema", "the person does not go to the cinema this year", "leisure.cinema_12m", "bought a ticket and watched a film at the cinema", None, timescale="minutes/hours"),
    _life("live_performance", "leisure", "causal", 0.2, ["c.performing_arts"], ["c.performing_arts", "c.music_listening", "c.festivals_events"], ["c.cultural_visits", "c.cultural_identity"], ["c.festivals_events", "c.nightlife"],
          [person(0.7, free("stay at home"), [("self", 1, 1)]), ("venue", 0.3, "produced", [("self", 1, 1)], free("cancel the show"))],
          "A {who} in {place} went to a live performance", "the person does not go to a live performance this year", "leisure.live_performance_12m", "went to a concert or a play", None, timescale="minutes/hours"),
    _life("cultural_site_visit", "leisure", "causal", 0.2, ["c.cultural_visits"], ["c.cultural_visits", "c.history_science", "c.tourism_travel"], ["c.cultural_visits", "c.arts_humanities_studies"], ["c.cultural_visits"],
          [person(0.7, free("stay at home"), [("self", 1, 1)]), ("venue", 0.3, "produced", [("self", 1, 1)], free("close the site"))],
          "A {who} in {place} visited a museum or historic site", "the person does not visit a cultural site this year", "leisure.cultural_site_12m", "walked through a museum or a historic site", None, timescale="minutes/hours"),
    _life("sports_event", "leisure", "causal", 0.2, ["c.sport_spectating"], ["c.sport_spectating", "c.socialising", "c.gambling"], ["c.sport_spectating", "c.cultural_identity"], ["c.sport_spectating", "c.festivals_events"],
          [person(0.7, free("stay at home"), [("self", 1, 1)]), ("club", 0.3, "produced", [("self", 1, 1)], free("cancel the match"))],
          "A {who} in {place} watched a sports event in person", "the person does not attend a sports event this year", "leisure.sports_event_12m", "sat in a stand and watched a match", None, timescale="minutes/hours"),
    _life("aerobic_sport", "leisure", "causal", 0.3, ["c.sport_participation"], ["c.sport_participation", "c.exercise_fitness"], ["c.physical_health", "c.exercise_fitness"], ["c.sport_participation", "c.outdoor_recreation"],
          [person(0.8, free("stay inactive"), [("self", 1, 1)]), ("club", 0.2, "produced", [("self", 1, 1)], free("close the facility"))],
          "A {who} in {place} trained in an aerobic sport", "the person does no aerobic sport this week", "leisure.aerobic_sport_week", "went for a long run or a swim", None, timescale="minutes/hours"),
    _life("strength_training", "leisure", "causal", 0.3, ["c.exercise_fitness"], ["c.exercise_fitness", "c.sport_participation"], ["c.physical_health", "c.personal_appearance"], ["c.sport_participation"],
          [person(0.8, free("stay inactive"), [("self", 1, 1)]), ("club", 0.2, "produced", [("self", 1, 1)], free("close the gym"))],
          "A {who} in {place} did muscle-strengthening exercise", "the person does no strength training this week", "leisure.strength_week", "lifted weights at a gym", None, timescale="minutes/hours"),
    _life("cycling_trip", "leisure", "causal", 0.2, ["c.walking_cycling"], ["c.walking_cycling", "c.commuting", "c.outdoor_recreation"], ["c.physical_health", "c.environmental_stewardship"], ["c.walking_cycling", "c.road_safety"],
          [person(1.0, free("travel by car"), [("self", 1, 1)])],
          "A {who} in {place} cycled to get somewhere", "the person does not cycle this week", "leisure.cycling_week", "cycled to work and back", None, timescale="minutes/hours"),
    # ---- social and civic ----
    _life("voting", "civic", "structural", 0.4, ["c.voting_elections"], ["c.voting_elections", "c.political_participation", "c.political_discourse"], ["c.political_participation", "c.public_administration"],
          ["c.voting_elections", "c.government_services"],
          [person(0.5, free("abstain"), [("self", 1, 1)]), ("polling", 0.5, "produced", [("self", 1, 1)], free("close the polling station", 1))],
          "A {who} in {place} voted in an election", "the person does not vote", "civic.voter_turnout", "queued at a polling station and cast a ballot", "took part in choosing the government", timescale="minutes/hours"),
    _life("formal_volunteering", "civic", "causal", 0.3, ["c.volunteering"], ["c.volunteering", "c.community_groups", "c.civil_society_advocacy"], ["c.community_groups", "c.mutual_aid"], ["c.community_groups"],
          [person(0.7, free("decline to help"), [("self", 1, 1), ("club", 1, 2)]), ("club", 0.3, "produced", [("self", 1, 1)], free("turn the volunteer away"))],
          "A {who} in {place} volunteered for an organisation", "the person does no organised voluntary work this year", "civic.formal_volunteering_12m", "gave unpaid time to an organisation's work", "added to a community project", timescale="weeks-months"),
    _life("informal_volunteering", "civic", "causal", 0.3, ["c.mutual_aid"], ["c.mutual_aid", "c.neighbours_community", "c.charity_giving"], ["c.neighbours_community", "c.mutual_aid"], ["c.neighbours_community"],
          [person(0.8, free("decline to help"), [("self", 1, 1), ("neighbour", 1, 2)]), ("neighbour", 0.2, "produced", [("self", 1, 1)], free("refuse the offer"))],
          "A {who} in {place} helped people outside the household without an organisation", "the person gives no informal help this year", "civic.informal_volunteering_12m", "helped a neighbour in need", "left the neighbour better off", timescale="weeks-months"),
    _life("active_citizenship", "civic", "causal", 0.4, ["c.civil_society_advocacy"], ["c.civil_society_advocacy", "c.political_participation", "c.human_rights"], ["c.political_participation", "c.public_administration", "c.legal_system"],
          ["c.public_administration", "c.political_discourse"],
          [person(0.8, free("stay silent"), [("self", 1, 1)]), ("polling", 0.2, "produced", [("self", 1, 1)], free("ignore the petition"))],
          "A {who} in {place} took part in a petition or a public meeting", "the person takes no part in public affairs this year", "civic.active_citizenship_12m", "signed a petition and spoke at a public meeting", "put an issue before the authorities", timescale="weeks-months"),
    _life("religious_service", "civic", "causal", 0.2, ["c.religion_worship"], ["c.religion_worship", "c.spirituality", "c.religious_community"], ["c.religious_community", "c.life_purpose"], ["c.religion_worship", "c.family_rituals"],
          [person(0.8, free("stay at home"), [("self", 1, 1)]), ("club", 0.2, "produced", [("self", 1, 1)], free("close the place of worship"))],
          "A {who} in {place} attended a religious service", "the person does not attend a service this year", "civic.religious_attendance", "attended a service at a place of worship", None, timescale="minutes/hours"),
    # ---- harms (negative record): offender and victim roles ----
    _life("theft_victim", "harm", "impacted", 0.5, ["c.theft_property_crime"], ["c.theft_property_crime", "c.policing_enforcement"], ["c.poverty_scarcity", "c.insurance_risk", "c.public_safety_emergency"], ["c.public_safety_emergency", "c.retail_shopping"],
          [("self", 0.0, "consumed", [("self", -1, 1)], None), ("offender", 0.9, "produced", [("self", -1, 1)], free("refrain from the theft", 0)), ("police", 0.1, "produced", [("self", 1, 1)], free("ignore the report", 1))],
          "A {who} in {place} had property stolen", "the person is not a victim of theft", "harm.theft_recorded_rate", "had a bag stolen on the street", "lost belongings and reported the theft", neg=True, harm=1),
    _life("burglary_victim", "harm", "impacted", 0.6, ["c.theft_property_crime"], ["c.theft_property_crime", "c.home_energy_utilities", "c.policing_enforcement"], ["c.home_repair_diy", "c.insurance_risk", "c.mental_health"], ["c.home_organisation", "c.public_safety_emergency"],
          [("self", 0.0, "consumed", [("self", -1, 2)], None), ("offender", 0.9, "produced", [("self", -1, 2)], free("refrain from the break-in", 0)), ("police", 0.1, "produced", [("self", 1, 1)], free("ignore the report", 1))],
          "A {who} in {place} had the home burgled", "the home is not burgled", "harm.burglary_recorded_rate", "came home to a forced door and missing goods", "repaired the lock and filed an insurance claim", neg=True, harm=2),
    _life("robbery_victim", "harm", "impacted", 0.7, ["c.violence_assault"], ["c.violence_assault", "c.theft_property_crime", "c.policing_enforcement"], ["c.mental_health", "c.public_safety_emergency", "c.insurance_risk"], ["c.public_safety_emergency"],
          [("self", 0.0, "consumed", [("self", -1, 2)], None), ("offender", 0.9, "produced", [("self", -1, 2)], free("refrain from the robbery", 0)), ("police", 0.1, "produced", [("self", 1, 1)], free("ignore the report", 1))],
          "A {who} in {place} was robbed", "the person is not robbed", "harm.robbery_recorded_rate", "was threatened and robbed of a phone", "reported the robbery to the police", neg=True, harm=2),
    _life("assault_victim", "harm", "impacted", 0.8, ["c.violence_assault"], ["c.violence_assault", "c.accident_injury", "c.policing_enforcement"], ["c.physical_health", "c.mental_health", "c.medical_care"], ["c.public_safety_emergency", "c.medical_care"],
          [("self", 0.0, "consumed", [("self", -1, 3)], None), ("offender", 0.9, "produced", [("self", -1, 3)], free("refrain from the attack", 0)), ("police", 0.1, "produced", [("self", 1, 1)], free("ignore the report", 1))],
          "A {who} in {place} was seriously assaulted", "the person is not assaulted", "harm.assault_recorded_rate", "was attacked and treated for injuries", "recovered and reported the assault", neg=True, harm=3),
    _life("sexual_violence_victim", "harm", "impacted", 0.9, ["c.sexual_violence"], ["c.sexual_violence", "c.policing_enforcement", "c.counselling_therapy"], ["c.mental_health", "c.legal_system", "c.counselling_therapy"], ["c.public_safety_emergency", "c.legal_system"],
          [("self", 0.0, "consumed", [("self", -1, 3)], None), ("offender", 1.0, "produced", [("self", -1, 3)], free("refrain from the assault", 0))],
          "A {who} in {place} suffered a sexual assault", "the person is not assaulted", "harm.sexual_violence_recorded_rate", "was sexually assaulted and sought help", "received support and counselling", neg=True, harm=3),
    _life("partner_violence_victim", "harm", "impacted", 0.8, ["c.domestic_abuse"], ["c.domestic_abuse", "c.violence_assault", "c.family_ties"], ["c.mental_health", "c.physical_health", "c.counselling_therapy"], ["c.home_organisation", "c.legal_system"],
          [("self", 0.0, "consumed", [("self", -1, 3)], None), ("offender", 1.0, "produced", [("self", -1, 3)], free("refrain from the violence", 0))],
          "A {who} in {place} was attacked by a partner", "the person is not attacked by a partner", "harm.partner_violence_12m", "was physically or sexually attacked by a partner", "told an interviewer about the violence", neg=True, harm=3, timescale="weeks-months")
    ,
    _life("fraud_victim", "harm", "impacted", 0.6, ["c.fraud_deception"], ["c.fraud_deception", "c.banking_payments", "c.policing_enforcement"], ["c.poverty_scarcity", "c.banking_payments", "c.insurance_risk"], ["c.online_commerce", "c.banking_payments"],
          [("self", 0.0, "consumed", [("self", -1, 2)], None), ("offender", 1.0, "produced", [("self", -1, 2)], free("refrain from the fraud", 0))],
          "A {who} in {place} was defrauded", "the person is not defrauded", "harm.fraud_recorded_rate", "paid for goods that never arrived", "lost savings and disputed the payment", neg=True, harm=2),
    _life("cyber_victim", "harm", "impacted", 0.5, ["c.cybercrime"], ["c.cybercrime", "c.cybersecurity", "c.online_harassment"], ["c.digital_tool_use", "c.stalking_privacy", "c.banking_payments"], ["c.digital_tool_use", "c.social_media"],
          [("self", 0.0, "consumed", [("self", -1, 1)], None), ("offender", 1.0, "produced", [("self", -1, 1)], free("refrain from the intrusion", 0))],
          "A {who} in {place} was the target of a computer crime", "the person is not targeted online", "harm.cybercrime_recorded_rate", "had an online account taken over", "regained access and changed passwords", neg=True, harm=1),
    _life("suspected_offence", "harm", "causal", 0.6, ["c.policing_enforcement"], ["c.policing_enforcement", "c.theft_property_crime", "c.violence_assault", "c.drug_crime", "c.fraud_deception"],
          ["c.legal_system", "c.incarceration", "c.reputation_gossip"], ["c.policing_enforcement", "c.legal_system"],
          [("self", 0.8, "produced", [("victim", -1, 2), ("self", -1, 2)], free("refrain from the offence", 0)), ("victim", 0.0, "consumed", [("self", -1, 1)], None), ("police", 0.2, "produced", [("victim", 1, 1)], free("let the offence pass", 1))],
          "A {who} in {place} was suspected of an offence", "the person is not suspected of an offence", "harm.suspect_rate", "was questioned by the police as a suspect", "came before the prosecutor", neg=True, harm=2),
    _life("conviction", "harm", "structural", 0.7, ["c.legal_system"], ["c.legal_system", "c.incarceration", "c.policing_enforcement"], ["c.incarceration", "c.reputation_gossip", "c.rites_of_passage"], ["c.legal_system"],
          [("self", 0.6, "produced", [("victim", -1, 2), ("self", -1, 3)], free("refrain from the offence", 0)), ("victim", 0.0, "consumed", [("self", -1, 1)], None), ("criminal_court", 0.4, "produced", [("victim", 1, 2)], free("acquit despite the evidence", 2))],
          "A {who} in {place} was convicted of an offence", "the person is not convicted", "harm.conviction_rate", "was found guilty and sentenced", "served the sentence", neg=True, harm=2, timescale="years"),
]
LIFE += [
    _life("migration", "mobility", "structural", 0.7, ["c.migration"], ["c.migration", "c.border_migration_admin", "c.moving_relocation", "c.housing_search"],
          ["c.migration", "c.identity_change", "c.cultural_identity"], ["c.border_migration_admin", "c.housing_search"],
          [person(0.7, free("stay in the home country", 1)), ("immigration", 0.3, "produced", [("self", 1, 2)], free("refuse entry", 2))],
          "A {who} in {place} moved to live in another country", "the person stays in the country of birth", "mobility.migrant_stock", "moved abroad and registered with the authorities",
          "became part of the migrant population there"),
    _life("account_opening", "money", "structural", 0.3, ["c.banking_payments"], ["c.banking_payments", "c.saving_investing", "c.personal_finance"], ["c.saving_investing", "c.household_budgeting", "c.borrowing_debt"],
          ["c.banking_payments"], [person(0.6, free("keep cash only"), [("self", 1, 1)]), ("bank", 0.4, "produced", [("self", 1, 1)], free("refuse the account"))],
          "A {who} in {place} opened a bank or mobile-money account", "the person has no account", "money.account_ownership", "opened an account and made a first deposit", "gained access to formal payments"),
    _life("phone_subscription", "tech", "structural", 0.2, ["c.subscriptions_telecom"], ["c.subscriptions_telecom", "c.digital_tool_use"], ["c.digital_tool_use", "c.friendship"], ["c.subscriptions_telecom"],
          [person(0.6, free("go without a phone"), [("self", 1, 1)]), ("telecom", 0.4, "produced", [("self", 1, 1)], free("refuse the subscription"))],
          "A {who} in {place} took out a mobile phone subscription", "the person has no mobile subscription", "tech.mobile_subscriptions", "took out a mobile phone subscription", None, timescale="minutes/hours"),
    _life("internet_adoption", "tech", "structural", 0.3, ["c.digital_tool_use"], ["c.digital_tool_use", "c.social_media", "c.online_commerce", "c.news_media"], ["c.digital_tool_use", "c.self_directed_learning"],
          ["c.digital_tool_use", "c.subscriptions_telecom"], [person(0.7, free("stay offline"), [("self", 1, 1)]), ("telecom", 0.3, "produced", [("self", 1, 1)], free("offer no connection"))],
          "A {who} in {place} started using the internet", "the person does not use the internet", "tech.internet_use", "went online for the first time", None, timescale="day"),
    _life("contraception_start", "health", "impacted", 0.4, ["c.reproduction_fertility"], ["c.reproduction_fertility", "c.preventive_health", "c.sexuality", "c.partnership_romance"],
          ["c.reproduction_fertility", "c.family_ties", "c.household_planning"], ["c.medical_care", "c.family_ties"],
          [person(0.7, free("use no method"), [("self", 1, 2)]), ("clinic", 0.3, "produced", [("self", 1, 1)], free("withhold the method", 1))],
          "A {who} in {place} began using a method of family planning", "the woman uses no method", "family.contraceptive_prevalence", "began using a method to avoid pregnancy", "postponed or limited childbearing"),
    _life("vocational_training_start", "work", "structural", 0.4, ["c.vocational_training"], ["c.vocational_training", "c.skilled_trades", "c.school_education"], ["c.vocational_training", "c.employment_transition"],
          ["c.vocational_training", "c.school_education"], [person(0.5, free("follow the general track"), [("self", 1, 2)]), ("school", 0.5, "produced", [("self", 1, 2)], free("offer no vocational track"))],
          "A {who} in {place} began a vocational programme in secondary school", "the pupil follows the general track", "education.vocational_share_secondary", "followed a vocational programme in secondary school", None, timescale="years"),
]
LIFE = [k for k in LIFE if k is not None]
ALL = TIME + LIFE
BY_KEY = {k.key: k for k in ALL}
