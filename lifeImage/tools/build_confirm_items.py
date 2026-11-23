"""Write the confirming battery's item set, data/gold/confirm_items_v0.jsonl (120 items; no model is run).

Sources (field `source`):
- a_pool (36): stratified from the 273-item layer-A pool (items whose text is also a layer-B/D item are left to the
  `bd` source): 20 coverage events spaced over their first expected domain, 8 red-team cases spaced over their
  ids, and 4 whole minimal pairs, one per A kind (outcome, content, setting, form). The pool had no participants;
  they are listed here, because the combined task asks for layer B on every item.
- bd (24): from `bd_items_v0.jsonl`, unchanged: the overdetermination items, every B and D minimal pair chosen,
  and a few red-team and new scenarios.
- counterfactual (30): new texts that state or imply what would otherwise have happened (`counterfactual`:
  stated | implied; `expected_outcome`: change | null, null where the counterfactual equals the observed course,
  as in a failed rescue).
- production_pair (30): 15 consumed-versus-produced pairs; side a is consumed, side b is produced, for the one
  focal participant named in `expect_production`.

Usage (from the repository root): python3 lifeImage/tools/build_confirm_items.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.membership import DEFAULT_GOLD, load_items_v2  # noqa: E402

OUT = DEFAULT_GOLD / "confirm_items_v0.jsonl"
N_EVENTS, N_REDTEAM = 20, 8
A_PAIRS = ("irrigation", "teach_topic", "study_place", "actor_surgeon")  # outcome, content, setting, form


def P(*pairs):
    return [{"id": i, "label": l} for i, l in pairs]


A_PARTICIPANTS = {
    "ev.105": P(("engineer", "the person training the model"), ("model", "the model being trained")),
    "ev.91": P(("applicant", "the visa applicant"), ("agency", "the border agency")),
    "ev.19": P(("grandmother", "the grandmother"), ("grandchildren", "the grandchildren")),
    "ev.25": P(("cook", "the person cooking"), ("diners", "the four people fed")),
    "ev.13": P(("learner", "the person learning to use the wheelchair")),
    "ev.20": P(("carer", "the person caring at weekends"), ("father", "the father with dementia")),
    "ev.131": P(("workers", "the forced labourers"), ("operator", "the boat's operator")),
    "ev.32": P(("person", "the person meeting a friend"), ("friend", "the old friend")),
    "ev.99": P(("student", "the new student"), ("university", "the university")),
    "ev.24": P(("payer", "the person paying"), ("utility", "the electricity company")),
    "ev.108": P(("jobseeker", "the person applying and interviewing"), ("employers", "the employers interviewing")),
    "ev.6": P(("patient", "the patient with the cough"), ("clinic", "the clinic")),
    "ev.67": P(("learner", "the person learning guitar")),
    "ev.66": P(("hiker", "the person hiking")),
    "ev.47": P(("marchers", "the people on the climate march")),
    "ev.56": P(("worshipper", "the person attending prayers"), ("congregation", "the congregation")),
    "ev.61": P(("teenager", "the teenager"), ("congregation", "the family and congregation")),
    "ev.104": P(("programmer", "the programmer"), ("employer", "the employer")),
    "ev.90": P(("driver", "the driver who ran the red light"), ("other_party", "the other road user in the collision")),
    "ev.27": P(("sorter", "the person sorting the recycling"), ("recycling_service", "the recycling service")),
    "rt.3": P(("citizen", "the citizen who does not vote"), ("electorate", "the electorate")),
    "rt.8": P(("winner", "the boxer who knocks out"), ("loser", "the boxer knocked out")),
    "rt.13": P(("host", "the podcast host"), ("listeners", "the listeners")),
    "rt.18": P(("trainee", "the trainee pilot"), ("instructor", "the instructor")),
    "rt.24": P(("person_a", "the first person greeting"), ("person_b", "the second person greeting")),
    "rt.29": P(("planter", "the person planting"), ("community", "the community around the tree")),
    "rt.85": P(("person", "the person making coffee")),
    "rt.91": P(("scroller", "the person doomscrolling"), ("platform", "the platform serving the feed")),
    "mp.irrigation.a": P(("farmer", "the farmer"), ("field", "the field")),
    "mp.irrigation.b": P(("farmer", "the farmer"), ("field", "the field")),
    "mp.teach_topic.a": P(("teacher", "the teacher"), ("class", "the class")),
    "mp.teach_topic.b": P(("teacher", "the teacher"), ("class", "the class")),
    "mp.study_place.a": P(("student", "the student")),
    "mp.study_place.b": P(("student", "the student")),
    "mp.actor_surgeon.a": P(("actor", "the actor"), ("audience", "the audience of the drama")),
    "mp.actor_surgeon.b": P(("surgeon", "the surgeon"), ("patient", "the patient")),
}

BD_IDS = (
    "bd.rt.36", "bd.rt.37", "bd.new.archers", "bd.new.vote5", "bd.new.volunteers",
    "bd.mp.decisive_vote.a", "bd.mp.decisive_vote.b",
    "bd.mp.surgery_assault.a", "bd.mp.surgery_assault.b", "bd.mp.donation_coerced.a", "bd.mp.donation_coerced.b",
    "bd.mp.informed_pharmacist.a", "bd.mp.informed_pharmacist.b", "bd.mp.acting_for.a", "bd.mp.acting_for.b",
    "bd.mp.threat_cash.a", "bd.mp.threat_cash.b", "bd.mp.onion_step.a", "bd.mp.onion_step.b",
    "bd.rt.42", "bd.rt.55", "bd.rt.59", "bd.new.coercion", "bd.new.ghostwriter",
)

# (id suffix, text, participants, counterfactual, expected outcome)
COUNTERFACTUAL = [
    ("vaccination_outbreak", "A clinic vaccinates 40 schoolchildren against measles while an outbreak spreads through the district, and none of them falls ill, whereas a third of their unvaccinated cousins do",
     P(("clinic", "the clinic"), ("vaccinated", "the 40 vaccinated schoolchildren"), ("cousins", "their unvaccinated cousins")), "stated", "change"),
    ("vaccination_flu", "A pharmacist gives a pensioner a flu jab in October, and the pensioner stays well through a winter in which her flatmate, without a jab, is hospitalised with flu",
     P(("pharmacist", "the pharmacist"), ("pensioner", "the pensioner"), ("flatmate", "her unvaccinated flatmate")), "stated", "change"),
    ("storm_embankment", "A rail crew reinforces an embankment the week before a storm, and the line stays open while the neighbouring unreinforced line floods and closes for ten days",
     P(("rail_crew", "the rail crew"), ("passengers", "the passengers on the line")), "stated", "change"),
    ("storm_roof", "A homeowner replaces loose roof tiles a week before a storm, and the house stays dry whereas the identical house next door, with its loose tiles, floods the loft",
     P(("homeowner", "the homeowner"), ("neighbour", "the neighbour with loose tiles")), "stated", "change"),
    ("surgery_appendix", "A surgeon removes a patient's inflamed appendix, which without the operation would have burst within a day, and the patient goes home after three days",
     P(("surgeon", "the surgeon"), ("patient", "the patient")), "stated", "change"),
    ("surgery_recovery", "A surgeon replaces a patient's worn hip, and the patient, who could not walk to the door before the operation, walks the length of the street within two months",
     P(("surgeon", "the surgeon"), ("patient", "the patient")), "implied", "change"),
    ("surgery_inoperable", "A surgeon opens a patient to remove a tumour that proves inoperable, closes the incision, and the patient's condition is what it would have been without the operation",
     P(("surgeon", "the surgeon"), ("patient", "the patient")), "stated", "null"),
    ("rescue_kayak", "Two kayakers pull a capsized teenager from a cold lake within a minute, and the teenager, who would have drowned within minutes otherwise, walks home wrapped in a blanket",
     P(("kayakers", "the two kayakers"), ("teenager", "the capsized teenager")), "stated", "change"),
    ("rescue_lifeguard_failed", "A lifeguard dives for a swimmer who has already drowned and brings her ashore, and the outcome is what it would have been had the lifeguard stayed on the chair",
     P(("lifeguard", "the lifeguard"), ("swimmer", "the drowned swimmer")), "stated", "null"),
    ("rescue_mountain_failed", "Mountain rescuers climb through the night to a stranded hiker, but he has died of exposure before they arrive, and he would have died even had they set out an hour earlier",
     P(("rescuers", "the mountain rescuers"), ("hiker", "the stranded hiker")), "stated", "null"),
    ("rescue_boat_failed", "A lifeboat crew searches for a fishing boat that sank an hour earlier and finds no one, and the search changes nothing for the fishermen, who would have drowned whatever the crew did",
     P(("crew", "the lifeboat crew"), ("fishermen", "the fishermen who sank")), "stated", "null"),
    ("tutoring_no_effect", "A tutor teaches a pupil algebra for a term, and the pupil's marks stay at 45 percent, exactly where they would have stayed without the tutoring",
     P(("tutor", "the tutor"), ("pupil", "the pupil")), "stated", "null"),
    ("fertiliser_no_effect", "A farmer sprays a field with an expensive fertiliser, and the harvest is what an unsprayed field would have given",
     P(("farmer", "the farmer"), ("field", "the sprayed field")), "stated", "null"),
    ("alarm_no_fire", "A homeowner fits a smoke alarm in a flat where no fire ever breaks out, and the household's years there are what they would have been without the alarm",
     P(("homeowner", "the homeowner"), ("household", "the household")), "stated", "null"),
    ("petition_ignored", "Residents sign a petition for a pedestrian crossing, and the council builds the crossing it had already planned and would have built without the petition",
     P(("residents", "the residents who signed"), ("council", "the council")), "stated", "null"),
    ("firebreak", "A farmer clears a firebreak before the dry summer, and when the wildfire arrives it stops at the cleared strip and the barns survive while the uncleared farm next door burns down",
     P(("farmer", "the farmer"), ("neighbour_farm", "the neighbouring farm")), "stated", "change"),
    ("brakes", "A mechanic replaces worn brake pads before a family's mountain trip, and the car brakes safely on the long descent where the worn pads would have failed",
     P(("mechanic", "the mechanic"), ("family", "the family in the car")), "stated", "change"),
    ("dredging", "A town crew dredges the river channel before the spring melt, and the melt passes without flooding, unlike two years ago when the silted channel overflowed into the streets",
     P(("crew", "the town crew"), ("residents", "the residents by the river")), "stated", "change"),
    ("tutoring", "A teacher gives a struggling pupil extra tutoring for a term, and the pupil's marks rise from 40 to 70 percent while the class's other struggling pupils stay flat",
     P(("teacher", "the teacher"), ("pupil", "the tutored pupil")), "stated", "change"),
    ("snow_path", "A neighbour clears an elderly woman's snow-covered path before dawn, so she reaches her dialysis appointment, which she would have missed otherwise",
     P(("neighbour", "the neighbour"), ("woman", "the elderly woman")), "stated", "change"),
    ("cooling", "An engineer repairs a data centre's cooling system before a heatwave, and the centre keeps running, whereas a rival's unrepaired centre goes offline for a day",
     P(("engineer", "the engineer"), ("customers", "the data centre's customers")), "stated", "change"),
    ("pharmacist_catch", "A pharmacist notices a doubled dose on a prescription and phones the doctor, so the patient avoids the overdose the original prescription would have caused",
     P(("pharmacist", "the pharmacist"), ("patient", "the patient"), ("doctor", "the prescribing doctor")), "stated", "change"),
    ("mangroves", "A coastal village plants mangroves along its shore over ten years, and when the cyclone hits its houses stand, whereas those in the unplanted villages up the coast are flooded",
     P(("villagers", "the villagers who planted"), ("other_villages", "the unplanted villages up the coast")), "stated", "change"),
    ("road_salt", "A council salts the roads before a freezing night, and no crashes are reported on the salted roads, whereas an unsalted lane records three",
     P(("council", "the council"), ("drivers", "the drivers on the roads")), "stated", "change"),
    ("texting_driver", "A driver reads a text while driving and clips a cyclist who would have passed safely, breaking the cyclist's collarbone",
     P(("driver", "the driver"), ("cyclist", "the cyclist")), "stated", "change"),
    ("solvent_dump", "A factory dumps solvent upstream of a village well, and the water tests that were clean the month before show contamination afterwards",
     P(("factory", "the factory"), ("villagers", "the villagers using the well")), "implied", "change"),
    ("sandbags", "Volunteers stack sandbags along a street before the river peaks, and the houses behind the bags stay dry, whereas the houses in the next street, without bags, are flooded",
     P(("volunteers", "the volunteers"), ("residents", "the residents of the street")), "stated", "change"),
    ("reading_hour", "A town opens a weekly reading hour at its library, and the children who attend gain two reading levels in a year, after two years in which their levels had not moved",
     P(("library", "the library"), ("children", "the children who attend")), "implied", "change"),
    ("seatbelt", "A passenger wears a seatbelt when the car skids into a ditch and walks away with bruises, whereas the unbelted passenger beside her is thrown against the windscreen",
     P(("belted", "the belted passenger"), ("unbelted", "the unbelted passenger"), ("driver", "the driver")), "stated", "change"),
    ("transfusion", "A nurse starts a blood transfusion for a mother bleeding after childbirth, and she is sitting up and talking by evening, when without the blood she would not have survived the night",
     P(("nurse", "the nurse"), ("mother", "the mother")), "stated", "change"),
]

# (name, consumed text, consumed participants, focal, produced text, produced participants, focal)
PRODUCTION = [
    ("watch_review", "A man watches a new documentary about glaciers at the cinema", P(("viewer", "the man watching"), ("filmmakers", "the filmmakers")), "viewer",
     "A man reviews a new documentary about glaciers and the local paper prints his review", P(("reviewer", "the man reviewing"), ("readers", "the paper's readers")), "reviewer"),
    ("read_annotate", "A student reads a chapter of a physics textbook in the library", P(("reader", "the student reading"), ("author", "the textbook's author")), "reader",
     "A student annotates a chapter of a physics textbook and shares her notes with the class", P(("annotator", "the student annotating"), ("classmates", "her classmates")), "annotator"),
    ("eat_cook", "A woman eats a hot dinner at her neighbours' table", P(("diner", "the woman eating"), ("hosts", "her neighbours")), "diner",
     "A woman cooks a hot dinner for her neighbours", P(("cook", "the woman cooking"), ("neighbours", "her neighbours")), "cook"),
    ("listen_perform", "A man listens to a string quartet in the town hall", P(("listener", "the man listening"), ("quartet", "the string quartet")), "listener",
     "A man plays in a string quartet for an audience in the town hall", P(("player", "the man playing"), ("audience", "the audience")), "player"),
    ("live_repair", "A tenant sits dry in a flat under a newly repaired roof", P(("tenant", "the tenant"), ("roofer", "the roofer who repaired it")), "tenant",
     "A roofer repairs the roof over a tenant's flat", P(("roofer", "the roofer"), ("tenant", "the tenant")), "roofer"),
    ("read_report", "A commuter reads a newspaper report about the floods on the train", P(("reader", "the commuter reading"), ("reporter", "the reporter")), "reader",
     "A reporter writes a newspaper report about the floods that the paper prints", P(("reporter", "the reporter"), ("readers", "the paper's readers")), "reporter"),
    ("cross_build", "A commuter walks across a new footbridge to the station", P(("commuter", "the commuter"), ("builders", "the builders")), "commuter",
     "A crew builds a new footbridge for commuters to reach the station", P(("crew", "the building crew"), ("commuters", "the commuters")), "crew"),
    ("download_record", "A teenager downloads a free tutorial video on bike repair", P(("viewer", "the teenager downloading"), ("uploader", "the uploader")), "viewer",
     "A teenager records and posts a free tutorial video on bike repair", P(("maker", "the teenager recording"), ("viewers", "the people who watch it")), "maker"),
    ("wear_knit", "A boy wears a woollen coat that his aunt knitted", P(("wearer", "the boy wearing"), ("aunt", "his aunt")), "wearer",
     "A woman knits a woollen coat for her nephew", P(("knitter", "the woman knitting"), ("nephew", "her nephew")), "knitter"),
    ("attend_teach", "A pupil sits through a maths lesson on fractions", P(("pupil", "the pupil"), ("teacher", "the teacher")), "pupil",
     "A teacher gives a maths lesson on fractions to her pupils", P(("teacher", "the teacher"), ("pupils", "her pupils")), "teacher"),
    ("heat_service", "A family heats its flat with the gas boiler through the evening", P(("family", "the family"), ("supplier", "the gas supplier")), "family",
     "A plumber services the gas boiler in a family's flat", P(("plumber", "the plumber"), ("family", "the family")), "plumber"),
    ("buy_bake", "A customer buys a warm loaf at the corner bakery", P(("customer", "the customer"), ("baker", "the baker")), "customer",
     "A baker bakes the loaves that the corner bakery sells", P(("baker", "the baker"), ("customers", "the bakery's customers")), "baker"),
    ("jab", "A patient receives a flu jab at the pharmacy", P(("patient", "the patient"), ("pharmacist", "the pharmacist")), "patient",
     "A pharmacist gives a patient a flu jab at the pharmacy", P(("pharmacist", "the pharmacist"), ("patient", "the patient")), "pharmacist"),
    ("follow_commentate", "A viewer follows a livestream of a chess match", P(("viewer", "the viewer"), ("commentator", "the commentator")), "viewer",
     "A grandmaster commentates a chess match on a livestream", P(("commentator", "the grandmaster commentating"), ("viewers", "the viewers")), "commentator"),
    ("read_translate", "A tourist reads the menu in a harbour restaurant", P(("tourist", "the tourist"), ("translator", "the menu's translator")), "tourist",
     "A translator translates a harbour restaurant's menu for its tourist guests", P(("translator", "the translator"), ("guests", "the tourist guests")), "translator"),
]


def spaced(seq, n):
    """n items evenly spaced over seq."""
    return [seq[(2 * i + 1) * len(seq) // (2 * n)] for i in range(n)]


def rows(name):
    return [json.loads(l) for l in (DEFAULT_GOLD / name).read_text(encoding="utf-8").splitlines() if l.strip()]


def build():
    bd = {r["id"]: r for r in rows("bd_items_v0.jsonl")}
    bd_texts = {r["text"].strip().lower() for r in bd.values()}
    pool = [i for i in load_items_v2(DEFAULT_GOLD) if i["text"].strip().lower() not in bd_texts]
    cov = {r["id"]: r for r in rows("coverage_events_v0.jsonl")}
    ev = sorted((i for i in pool if i["id"].startswith("ev.")),
                key=lambda i: ((cov[i["id"]]["expected_fields"] or [""])[0], i["id"]))
    rt = sorted((i for i in pool if i["id"].startswith("rt.")), key=lambda i: int(i["id"][3:]))
    mp = {i["id"]: i for i in pool if i["id"].startswith("mp.")}
    picked = [(i, "coverage") for i in spaced(ev, N_EVENTS)] + [(i, "redteam") for i in spaced(rt, N_REDTEAM)]
    for p in A_PAIRS:
        picked += [(mp[f"mp.{p}.a"], "pair_A"), (mp[f"mp.{p}.b"], "pair_A")]
    out = []
    for i, kind in picked:
        out.append({"id": i["id"], "text": i["text"], "source": "a_pool", "source_id": i["id"], "tags": [kind],
                    "participants": A_PARTICIPANTS[i["id"]]})
    assert {r["id"] for r in out} == set(A_PARTICIPANTS), "participants listed for exactly the picked A items"
    for iid in BD_IDS:
        r = dict(bd[iid])
        r["bd_source"], r["source"] = r["source"], "bd"
        out.append(r)
    for name, text, ps, cf, exp in COUNTERFACTUAL:
        out.append({"id": f"cf.{name}", "text": text, "source": "counterfactual", "participants": ps,
                    "counterfactual": cf, "expected_outcome": exp, "tags": ["counterfactual", exp]})
    for name, ta, pa, fa, tb, pb, fb in PRODUCTION:
        out.append({"id": f"cp.{name}.a", "text": ta, "source": "production_pair", "participants": pa,
                    "pair": f"cp.{name}", "side": "a", "expect_production": {fa: "consumed"}, "tags": ["production"]})
        out.append({"id": f"cp.{name}.b", "text": tb, "source": "production_pair", "participants": pb,
                    "pair": f"cp.{name}", "side": "b", "expect_production": {fb: "produced"}, "tags": ["production"]})
    texts = [r["text"].strip().lower() for r in out]
    assert len(set(texts)) == len(texts), "item texts must be unique"
    return out


if __name__ == "__main__":
    items = build()
    OUT.write_text("\n".join(json.dumps(r, sort_keys=True, ensure_ascii=False) for r in items) + "\n", encoding="utf-8")
    from collections import Counter
    print(len(items), "items", dict(Counter(r["source"] for r in items)))
