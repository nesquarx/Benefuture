"""Realistic texts for extraction tests (texts v2): the same persona and the same rows, written the way people write.

The v1 texts are templates: every resume line is `YEAR-YEAR  fragment`, so an extractor can read them with a line
pattern and the extraction scores measure template parsing, not reading. `render_texts_v2(persona)` renders the
persona's claimed events again, deterministic in the persona's seed and independent of every row-generating stream
(the rows, events and v1 texts are untouched; only the texts change):

- Resume formats (one per resume): chronological (dated lines in one of three layouts, headings varied), skills-first
  (a profile, undated key skills, then career history with the dates trailing in brackets) and a narrative bio
  (paragraphs, several events to a line).
- A phrase bank of alternative wordings per kind of event (`BANK`: line, story and skill wordings, each with a neutral,
  an inflating and a deflating version), word-level synonyms for diary and self-description phrases, varied headers,
  contact lines and date layouts.
- Vague and missing dates (`c. 2019`, `early 2010s`, `since 2019`, `2019 or so`, none), and omitted details (the employer,
  the institution), never an omitted event: every claimed row keeps a line of the text, so the truth rows still apply.
- Embellishment matching the calibration type: over-estimators inflate titles and outcomes (`Lead`, `spearheaded`,
  `fluent`, `with distinction`), under-estimators deflate them (`Junior`, `assisted`, `basic`), well-calibrated persons
  write neutrally. Each entry is embellished with probability `P_EMBELLISH`, so a text can carry both a few neutral
  and a few embellished entries. `embellishment_score(text)` counts inflating minus deflating words (a lexicon count, not
  a judgement; a text's neutral wording scores 0).
- Occasional personal lines (interests, references, a generic volunteering line) that state no event and so carry no row.

`render_texts_v2` returns the three texts, `spans` ({doc: {row index: line number}}, 1-based over all lines, as the
v1 provenance spans) and `meta` (the resume format and the number of embellished entries). The v1 provenance spans
refer to the v1 texts; the v2 spans are written beside the v2 texts (`tools/gen_texts_v2.py`).
"""
import datetime as dt
import re
from dataclasses import dataclass, field

from . import catalogue as C
from .common import seed_label, stream
from .life import IMPACTS, LEVELS, MONTHS

P_EMBELLISH = 0.55  # governed: the chance that an entry of an over- or under-estimating persona is embellished
P_VAGUE = 0.25  # governed: the chance a dated entry carries a vague date
P_NO_DATE = 0.15  # governed: the chance an entry carries no date
P_OMIT = 0.2  # governed: the chance a detail (employer, institution) is left out where the bank has a version without it
FORMATS = ("chronological", "skills_first", "narrative")
MON = [m[:3] for m in MONTHS]

INFLATE = frozenset("""senior lead leading head fluent expert expert-level award-winning highly outstanding exceptional
spearheaded pioneered extensive top proven distinction flagship acclaimed influential led successfully""".split())
DEFLATE = frozenset("""assisted helped junior basic little just trainee occasional occasionally limited modest dabbled minor
tried""".split())


def embellishment_score(text):
    """Inflating words minus deflating words in the text (lexicon count)."""
    words = re.findall(r"[a-z]+(?:-[a-z]+)*", text.lower())
    return float(sum(w in INFLATE for w in words) - sum(w in DEFLATE for w in words))


@dataclass
class TextsV2:
    texts: dict
    spans: dict
    meta: dict = field(default_factory=dict)


# ---------- the phrase bank: key -> mode -> (neutral, inflating, deflating); a missing or empty tone falls back to neutral ----------
def _b(n, o=(), u=()):
    return (list(n), list(o), list(u))


BANK = {
    "school": {"line": _b(["Attended {school}", "{school}", "School: {school}"], ["Attended {school} (top of the class)"]),
               "story": _b(["went to {school}", "was at {school}", "attended {school}"])},
    "exam": {"line": _b(["Passed {exam}", "{exam}: passed", "Completed {exam}"], ["Passed {exam} with distinction", "{exam} (outstanding results)"],
                        ["Passed {exam} (just)", "{exam}: just passed"]),
             "story": _b(["passed {exam}", "sat and passed {exam}"], ["passed {exam} with distinction"], ["just passed {exam}"])},
    "degree": {"line": _b(["{degree} in {field}, {uni}", "{uni}: {degree}, {field}", "{degree} {field} ({uni})", "{degree} in {field}"],
                          ["{degree} in {field} with distinction, {uni}"], ["{degree} in {field}, {uni} (modest result)"]),
               "skill": _b(["{field} ({degree})", "{field}, to degree level"], ["Expert knowledge of {field}"], ["Basic grounding in {field}"]),
               "story": _b(["earned a {degree} in {field} at {uni}", "graduated from {uni} with a {degree} in {field}", "studied {field} and graduated in it"],
                           ["graduated from {uni} with distinction in {field}"], ["just about finished a {degree} in {field} at {uni}"])},
    "degree_start": {"line": _b(["Studying {field}, {uni}", "Currently studying {field} at {uni}", "{uni} (current): {field}"],
                                ["Studying {field} at {uni} (top of the year)"], ["Studying {field}, {uni} (early days, just starting)"]),
                     "story": _b(["began studying {field} at {uni}", "am studying {field} at {uni}"], ["began studying {field} at {uni}, highly motivated"],
                                 ["just started studying {field} at {uni}"])},
    "phd": {"line": _b(["PhD, {field}", "Doctorate in {field}", "Doctoral research: {field}"], ["PhD, {field} (leading researcher in the group)"],
                       ["PhD, {field} (modest project)"]),
            "skill": _b(["{field} (doctorate)", "Research in {field}"], ["Expert in {field} (doctorate)"], ["{field} (modest doctoral project)"]),
            "story": _b(["completed a PhD in {field}", "did doctoral research in {field}"], ["completed an award-winning PhD in {field}"],
                        ["just about completed a PhD in {field}"])},
    "course": {"line": _b(["Course in {skill}", "{skill} course", "Short course: {skill}"], ["Advanced {skill} training (top marks)"],
                          ["Introductory course in {skill} (basic)"]),
              "skill": _b(["{skill}", "{skill} (coursework)"], ["{skill} (expert)"], ["{skill} (basic)"]),
              "story": _b(["took a course in {skill}", "did a course in {skill}"], ["became highly proficient in {skill} on a course"],
                          ["dabbled in {skill} on a course"])},
    "language": {"line": _b(["Conversational {lang}", "{lang} (conversational)", "Languages: {lang}"], ["Fluent {lang}", "{lang} (fluent)"],
                            ["Basic {lang}", "{lang} (a little)"]),
                 "skill": _b(["{lang} (conversational)", "{lang}"], ["{lang} (fluent)"], ["{lang} (basic)"]),
                 "story": _b(["learned {lang} well enough to chat", "picked up conversational {lang}"], ["became fluent in {lang}"],
                             ["picked up a little {lang}"])},
    "tutoring": {"line": _b(["Tutor, {subject} ({n} students)", "{subject} tutor, {n} students", "Tutoring in {subject}"],
                            ["Lead {subject} tutor, {n} students"], ["Helped {n} students with {subject}"]),
                 "skill": _b(["{subject} tutoring ({n} students)"], ["Leading {subject} tutoring"], ["Occasional {subject} tutoring"]),
                 "story": _b(["tutored {n} students in {subject}"], ["led a tutoring programme in {subject}"], ["helped {n} students with {subject}"])},
    "publication": {"line": _b(["Paper on {field}", "Publication: {field}", "Author, paper on {field}"], ["Lead author, influential paper on {field}"],
                               ["Minor contributor to a paper on {field}"]),
                    "skill": _b(["Research writing: {field}"], ["Leading research writing: {field}"], ["Minor research writing: {field}"]),
                    "story": _b(["published a paper on {field}"], ["published a leading paper on {field}"], ["had a minor part in a paper on {field}"])},
    "job": {"line": _b(["{title}, {employer}", "{title} at {employer}", "{title} ({employer})", "{employer} - {title}", "{title}", "{title}, {sector_label}"],
                       ["{title}, {employer} (top performer)", "{title}, {employer}; spearheaded key projects", "{title} at {employer}, a proven performer"],
                       ["{title}, {employer} (assisted the team)", "{title} at {employer}, helped out"]),
            "omit": ("{title}", "{title}, {sector_label}"),
            "story": _b(["worked as {title} at {employer}", "joined {employer} as {title}", "spent time as {title} with {employer}", "worked as {title}",
                         "worked in {sector_label}"],
                        ["spearheaded the work as {title} at {employer}", "rose quickly as {title} at {employer}, a proven performer"],
                        ["assisted as {title} at {employer}", "helped out as {title} at {employer}"])},
    "promotion": {"line": _b(["Promoted to {title}", "{title} (promoted)", "Promotion: {title}, {employer}"], ["Swiftly promoted to {title} after outstanding results"],
                             ["Promoted to {title} (a modest step)"]),
                  "story": _b(["was promoted to {title}", "moved up to {title} at {employer}"], ["was swiftly promoted to {title} after outstanding results"],
                              ["was moved up to {title}, a modest step"])},
    "employment_transition": {"line": _b(["Career change into {sector_label}", "Moved into {sector_label}", "Changed career: {sector_label}"],
                                         ["Pioneered a career move into {sector_label}"], ["Dabbled my way into {sector_label}"]),
                              "story": _b(["changed careers into {sector_label}", "switched into {sector_label}"], ["pioneered a career move into {sector_label}"],
                                          ["dabbled my way into {sector_label}"])},
    "retirement": {"line": _b(["Retired", "Retired from {employer}", "Retirement"]), "story": _b(["retired", "retired from {employer}"])},
    "business_start": {"line": _b(["Founder, {biz}", "Owner of a {biz}", "{biz}: founder"], ["Founder and director of a highly successful {biz}"],
                                  ["Owner of a small {biz} (just getting by)"]),
                       "story": _b(["set up my own {biz}", "started a {biz}"], ["built a highly successful {biz} from nothing"], ["started a modest {biz}"])},
    "business_growth": {"line": _b(["Milestone: {growth}", "{growth}"], ["Milestone: {growth} (outstanding growth)"], ["Milestone: {growth} (modest growth)"]),
                        "story": _b(["then we {growth}", "and in time {growth}"], ["then we {growth}, with outstanding growth"], ["then we {growth}, at a modest pace"])},
    "workplace_award": {"line": _b(["{award} award, {employer}", "Winner, {award} award ({employer})", "{employer}: {award} award"],
                                   ["Award-winning: {award} award, {employer}, among the very best"], ["{award} award, {employer} (a team effort, minor role)"]),
                        "story": _b(["won the {award} award at {employer}"], ["won the {award} award at {employer}, an outstanding achievement"],
                                    ["shared in the {award} award at {employer}, in a minor role"])},
    "faith_role": {"line": _b(["Committee member, {body}", "Member of the {body} committee", "{body}: committee"], ["Lead committee member, {body}"],
                              ["Occasional committee helper, {body}"]),
                   "story": _b(["served on the {body}", "sat on the committee of the {body}"], ["led the {body}"], ["helped out on the {body} now and then"])},
    "volunteer": {"line": _b(["Volunteer, {org}", "{org}: volunteer", "Volunteered at {org}"], ["Lead volunteer, {org}"], ["Occasional volunteer, {org}"]),
                  "story": _b(["volunteered at {org}", "gave my time to {org}"], ["led volunteers at {org}"], ["occasionally helped at {org}"])},
    "community_group": {"line": _b(["Member, {group}", "{group} (member)"], ["Leading member, {group}"], ["Occasional member, {group}"]),
                        "story": _b(["joined the {group}"], ["became a leading figure in the {group}"], ["tagged along to the {group} occasionally"])},
    "advocacy": {"line": _b(["Campaigner, {cause}", "Campaign for {cause}"], ["Lead campaigner, {cause}"], ["Occasional campaign helper, {cause}"]),
                 "story": _b(["campaigned for {cause}"], ["led a campaign for {cause}"], ["helped out with a campaign for {cause}"])},
}
TITLE_MOD = {"over": ["Lead", "Head", "Senior"], "under": ["Junior", "Trainee", "Assistant"]}
SKILL_KEYS = frozenset({"degree", "phd", "course", "language", "tutoring", "publication"})
SUMMARY = _b(["{Arch} based in {city}, {country}.", "{Arch} from {city}.", "Based in {city}, with a background as a {arch}.", "{Arch}, {city}."],
             ["Highly motivated {arch} with a proven record of results, based in {city}.", "Outstanding {arch}, an expert in my field, based in {city}."],
             ["Modest {arch} from {city}, with a little training and some experience, still learning.", "Junior-minded {arch} in {city}, happy to assist where needed."])
INTERESTS = ["walking and cooking", "gardening and local history", "reading, mostly novels", "cycling and the occasional marathon", "choirs and quiz nights",
             "football on Sundays", "baking for friends", "photography", "board games with the family", "fixing old radios"]
PERSONAL = ["Outside work I enjoy {x}.", "Interests: {x}.", "In my spare time: {x}.", "Enjoys {x}."]
GENERIC_VOL = ["Active in my local community.", "Keen on community work, now and again.", "Always glad to give a hand locally."]
HEAD = {"work": ["Experience", "Work history", "Employment"], "learning": ["Education and training", "Education", "Qualifications"],
        "community": ["Volunteering and community", "Community", "Service and community"], "other": ["Other", "Additional", "Further details"]}
SELF_SYN = [("I work as", ["I'm working as", "I work as"]), ("I hold a degree in", ["I have a degree in"]), ("I care for", ["I look after"]),
            ("I volunteer at", ["I give my time at", "I help out at"]), ("I am retired", ["I'm retired"]), ("I speak some", ["I can speak a bit of"]),
            ("I run my own", ["I have my own"]), ("I have a doctorate in", ["I hold a doctorate in"]), ("I changed careers", ["I switched careers"])]
DIARY_SYN = [("looked after", ["cared for", "took care of"]), ("registered as", ["signed up as"]), ("helped", ["pitched in to help"]), ("adopted", ["took in"]),
             ("raised", ["brought up"]), ("supported", ["stood by"]), ("moved to", ["relocated to"]), ("bought", ["purchased"]),
             ("started", ["began"]), ("graduated from", ["finished my studies at"]), ("completed", ["finished"]), ("took ", ["did "]), ("travelled to", ["visited"]),
             ("went to", ["attended"]), ("joined the", ["signed up to the"]), ("gave to", ["donated to"]), ("passed", ["got through"]),
             ("married", ["got married to"]), ("won the", ["received the"]), ("worked as", ["was working as"])]
DIARY_FRAME = ["I {p}.", "Today I {p}.", "Well, I {p}.", "Note to self: I {p}.", "I {p}, and glad of it.", "Finally, I {p}."]


def _pick(R, xs):
    """One uniform draw per pick whatever the list's length, so streams stay in step across calibrations (paired designs)."""
    return xs[min(int(R.random() * len(xs)), len(xs) - 1)]


class _Fmt(dict):
    def __missing__(self, k):
        return "{" + k + "}"


def _fill(tpl, d):
    out = tpl
    for _ in range(2):
        out = out.format_map(_Fmt(d))
    return out


def _asof_mi(p):
    return int(p.as_of[:4]) * 12 + int(p.as_of[5:7]) - 1


# ---------- entries ----------
def _entries(p, doc):
    """[(event, row index)] of the claimed rows in the document, in time order."""
    by_row = {ri: e for e in p.events for ri in e["rows"]}
    out = []
    for i, r in enumerate(p.rows):
        if r["tier"] == "claimed" and r["provenance"]["source"].startswith(doc + ":") and i in by_row:
            out.append((by_row[i], i))
    return sorted(out, key=lambda x: (x[0]["valid_time"], x[1]))


class _Tone:
    """Per persona and entry: neutral, or the persona's embellishment direction, drawn from one stream so the pattern of
    which entries are embellished is the same for every calibration of one seed (paired designs); `cal` only sets the
    direction."""

    def __init__(self, cal, R):
        self.cal, self.R, self.count = cal, R, 0

    def draw(self):
        u = self.R.random()
        if self.cal != "well" and u < P_EMBELLISH:
            self.count += 1
            return self.cal
        return "neutral"


def _variants(key, mode, tone):
    spec = BANK.get(key, {}).get(mode) or BANK.get(key, {}).get("line")
    if spec is None:
        return None
    neutral, over, under = spec
    return {"neutral": neutral, "over": over or neutral, "under": under or neutral}[tone]


def _phrase(key, d, mode, tone, R):
    """The wording of one entry (the same number of draws whatever the tone). A tone with no bank wording of its own writes
    neutrally; only a neutral job may drop its employer; titles are modified only for an embellished job or promotion."""
    vs = _variants(key, mode, tone)
    if vs is None:
        return None
    d = dict(d)
    u_omit, u_title = R.random(), R.random()
    if key == "job" and mode == "line" and tone == "neutral" and u_omit < P_OMIT:
        tpl = _pick(R, BANK["job"]["omit"])
    else:
        tpl = _pick(R, vs)
    if tone in TITLE_MOD and "title" in d and key in ("job", "promotion") and not re.search(r"\b(senior|lead|head|junior|trainee|assistant)\b", d["title"], re.I):
        d["title"] = f"{TITLE_MOD[tone][min(int(u_title * 3), 2)]} {d['title']}"
    return _fill(tpl, d)


# ---------- dates ----------
def _decade(y, R):
    part = "early" if y % 10 < 4 else "mid" if y % 10 < 7 else "late"
    return f"{part} {y // 10 * 10}s"


def _date(R, e, p, present, vague_ok=True):
    """The date text of an entry (single or range) or None. Years from the event's valid time and a job's duration."""
    y, m = int(e["valid_time"][:4]), int(e["valid_time"][5:7])
    yrs = e["detail"].get("years") if e["key"] == "job" else None
    u = R.random()
    if u < P_NO_DATE:
        return None
    end = None
    if yrs:
        em = y * 12 + m - 1 + int(round(yrs * 12))
        end = None if present else (em // 12, em % 12 + 1)
    sep = _pick(R, [" - ", " – ", " to "])
    if R.random() < P_VAGUE and vague_ok:
        if yrs and present:
            return _pick(R, [f"since {y}", f"since about {y}", f"from {_decade(y, R)}"])
        if yrs and end:
            return _pick(R, [f"{y} to about {end[0]}", f"{_decade(y, R)}{sep}{end[0]}", f"around {y}{sep}{end[0]}"])
        return _pick(R, [f"c. {y}", f"around {y}", f"{_decade(y, R)}", f"{y} or so"])
    if R.random() < 0.55:
        s = f"{MON[m - 1]} {y}"
        if yrs:
            return f"{s}{sep}" + ("present" if present else f"{MON[end[1] - 1]} {end[0]}")
        return s
    if yrs:
        return f"{y}{sep}" + ("present" if present else str(end[0]))
    return str(y)


def _present(e, p):
    if e["key"] != "job" or not e["detail"].get("years"):
        return False
    y, m = int(e["valid_time"][:4]), int(e["valid_time"][5:7])
    return y * 12 + m - 1 + int(e["detail"]["years"] * 12) >= _asof_mi(p) - 6 and not e["detail"].get("first")


# ---------- the resume ----------
def _section(e):
    a = C.TEMPLATES[e["key"]].area
    return "work" if a == "work" else "learning" if a == "learning" else "community" if a in ("civic", "faith") else "other"


def _resume(p, R, tone):
    fmt = _pick(R, FORMATS)
    ents = _entries(p, "resume")
    lines, where = [], {}

    def add(text, *rows):
        lines.append(text)
        for r in rows:
            where[r] = len(lines)

    c = p.contact
    first, last = p.name.split(" ", 1)
    head = _pick(R, [lambda: [p.name], lambda: [p.name.upper(), "Curriculum vitae"], lambda: ["CURRICULUM VITAE", p.name], lambda: [f"{last}, {first}"]])()
    lines += head
    lines.append(_pick(R, [f"{c['email']} | {c['phone']} | {c['address']}", f"{c['address']}", f"Tel {c['phone']}  Email {c['email']}"]))
    if R.random() < 0.35:
        b = dt.date.fromisoformat(p.birth)
        lines.append(_pick(R, [f"Born {b.day} {MONTHS[b.month - 1]} {b.year}", f"Date of birth: {b.day:02d}/{b.month:02d}/{b.year}", f"Age {p.age}"]))
    lines.append("")
    arch = p.archetype.replace("_", " ")
    t = tone.draw()
    summary = {"neutral": SUMMARY[0], "over": SUMMARY[1], "under": SUMMARY[2]}[t]
    summary = _fill(_pick(R, summary), {"Arch": arch.capitalize(), "arch": arch, "city": p.city, "country": p.country})

    def body_line(e, mode, layout):
        t = tone.draw()
        text = _phrase(e["key"], e["detail"], mode, t, R) or e["label"]
        date = _date(R, e, p, _present(e, p), vague_ok=mode != "skill")
        if date is None or mode == "skill":
            return text
        return {"pipe": f"{date} | {text}", "colon": f"{date}: {text}", "bracket": f"{text} ({date})", "dash": f"{date} - {text}"}[layout]

    if fmt == "chronological":
        layout = _pick(R, ["pipe", "colon", "bracket", "dash"])
        add("Summary" if R.random() < 0.5 else "Profile")
        add(summary)
        groups = {}
        for e, ri in ents:
            groups.setdefault(_section(e), []).append((e, ri))
        heads = {k: _pick(R, v) for k, v in HEAD.items()}
        for sec in ("work", "learning", "community", "other"):
            if sec not in groups:
                continue
            lines.append("")
            add(heads[sec])
            for e, ri in sorted(groups[sec], key=lambda x: x[0]["valid_time"], reverse=R.random() < 0.8):
                add(body_line(e, "line", layout), ri)
    elif fmt == "skills_first":
        bullet = _pick(R, ["- ", "* ", "• "])
        add("Profile")
        add(summary)
        skills = [x for x in ents if x[0]["key"] in SKILL_KEYS]
        rest = [x for x in ents if x[0]["key"] not in SKILL_KEYS]
        if skills:
            lines.append("")
            add(_pick(R, ["Key skills", "Skills and qualifications", "Core skills"]))
            for e, ri in skills:
                add(bullet + body_line(e, "skill", "bracket"), ri)
        groups = {}
        for e, ri in rest:
            groups.setdefault(_section(e), []).append((e, ri))
        for sec, title in (("work", "Career history"), ("learning", "Education"), ("community", "Community"), ("other", "Other")):
            if sec in groups:
                lines.append("")
                add(title)
                for e, ri in sorted(groups[sec], key=lambda x: x[0]["valid_time"], reverse=True):
                    add(bullet + body_line(e, "line", "bracket"), ri)
    else:  # narrative
        add(_pick(R, ["About me", "Profile", "My story"]))
        intro = summary
        items = []
        for e, ri in ents:
            t = tone.draw()
            story = _phrase(e["key"], e["detail"], "story", t, R) or e["label"]
            y = int(e["valid_time"][:4])
            u = R.random()
            when = "" if u < P_NO_DATE else (_pick(R, [f"c. {y}", f"around {y}", _decade(y, R)]) if u < P_NO_DATE + P_VAGUE else str(y))
            vague = when.startswith(("c.", "around", "early", "mid", "late"))
            sentence = _pick(R, ([f"{when[0].upper() + when[1:]}, I {story}." if vague else f"In {when}, I {story}.", f"I {story} ({when}).",
                                  f"Around then I {story}."] if when else [f"I {story}.", f"At some point I {story}."]))
            if story.startswith(("then we", "and in time")):
                sentence = story[0].upper() + story[1:] + "."
            items.append((sentence, ri))
        first_p = True
        i = 0
        while i < len(items):
            k = 2 + R.randrange(3)
            chunk = items[i:i + k]
            i += k
            text = (intro + " " if first_p else "") + " ".join(s for s, _ in chunk)
            first_p = False
            add(text, *[r for _, r in chunk])
        if first_p:
            add(intro)
    extra = []
    if R.random() < 0.45:
        extra.append(_fill(_pick(R, PERSONAL), {"x": _pick(R, INTERESTS)}))
    if R.random() < 0.2:
        extra.append(_pick(R, GENERIC_VOL))
    if R.random() < 0.4:
        extra.append(_pick(R, ["References available on request.", "References: available on request", "Referees on request."]))
    if extra:
        lines.append("")
        lines += extra
    return "\n".join(lines) + "\n", where, fmt


# ---------- self-description ----------
def _self(p, R):
    lines, where = [], {}
    pieces = []  # (sentence, [row indices])
    pieces.append((_pick(R, [f"My name is {p.name} and I am {p.age} years old.", f"I'm {p.name}, {p.age}.", f"Hello, I am {p.name}. I am {p.age}."]), []))
    pieces.append((_pick(R, [f"I live in {p.city}.", f"I'm based in {p.city}, {p.country}.", f"{p.city} is home."]), []))
    for e, ri in _entries(p, "self"):
        s = e["phrase"] if e.get("phrase") else e["label"]
        for old, news in SELF_SYN:
            if s.startswith(old) and R.random() < 0.6:
                s = _pick(R, news) + s[len(old):]
                break
        pieces.append((s.rstrip(".") + ".", [ri]))
    for i, r in enumerate(p.rows):
        if r["channel"] == "prediction" and r["provenance"]["source"].startswith("self:"):
            dom = r["memberships"][0]["domain"]
            lab = seed_label(dom).lower()
            if any(m["rel"] == "outcome" for m in r["memberships"]):
                im = next(w for th, w in IMPACTS if r["magnitude"] < th)
                pieces.append((_pick(R, [f"What I do in {lab} {im}.", f"Whatever I do in {lab} {im}.", f"My work in {lab} {im}."]), [i]))
            else:
                lv = next(w for th, w in LEVELS if r["magnitude"] < th)
                pieces.append((_pick(R, [f"I would say I am {lv} in {lab}.", f"I'd call myself {lv} in {lab}.", f"In {lab}, I think I am {lv}."]), [i]))
    i = 0
    while i < len(pieces):
        k = 1 + (R.random() < 0.4) + (R.random() < 0.15)
        chunk = pieces[i:i + k]
        i += k
        lines.append(" ".join(s for s, _ in chunk))
        for _, rows in chunk:
            for r in rows:
                where[r] = len(lines)
    return "\n".join(lines) + "\n", where


# ---------- diary ----------
def _diary(p, R):
    lines, where = [], {}
    for e, ri in _entries(p, "diary"):
        day = dt.date.fromisoformat(p.rows[ri]["valid_time"])
        s = e["phrase"] if e.get("phrase") else e["label"]
        for old, news in DIARY_SYN:
            if s.startswith(old) and R.random() < 0.5:
                s = _pick(R, news) + s[len(old):]
                break
        stamp = _pick(R, [day.isoformat(), f"{day.day} {MON[day.month - 1]} {day.year}", f"{MON[day.month - 1]} {day.day}, {day.year}",
                          f"{day.day:02d}/{day.month:02d}/{day.year % 100:02d}", f"{day.strftime('%a')} {day.day} {MON[day.month - 1]}"])
        sep = _pick(R, [": ", " - ", ". ", " "])
        if R.random() < 0.15:
            lines.append(f"{stamp}{sep}{_pick(R, ['Quiet day.', 'Nothing much to report.', 'Rain all day.'])}")
        lines.append(f"{stamp}{sep}{_fill(_pick(R, DIARY_FRAME), {'p': s})}")
        where[ri] = len(lines)
    return "\n".join(lines) + "\n", where


def render_texts_v2(p):
    """The persona's three texts in realistic styles with the v2 spans of its claimed rows; deterministic in the persona's seed."""
    R = stream(p.seed, "texts_v2.resume")
    tone = _Tone(p.calibration, stream(p.seed, "texts_v2.tone"))
    resume, rw, fmt = _resume(p, R, tone)
    self_t, sw = _self(p, stream(p.seed, "texts_v2.self"))
    diary, dw = _diary(p, stream(p.seed, "texts_v2.diary"))
    return TextsV2({"resume": resume, "self": self_t, "diary": diary}, {"resume": rw, "self": sw, "diary": dw},
                   {"format": fmt, "embellished": tone.count})
