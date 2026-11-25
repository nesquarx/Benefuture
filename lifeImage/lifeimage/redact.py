"""Redaction for extraction tests on real texts (LI.15: identities are redacted before anything is stored or shown).

`redact` replaces names, emails, phone numbers, addresses, dates of birth, identifiers, profile URLs and handles with
numbered placeholders ([NAME_1], [EMAIL_2], ...): the same entity keeps its number and different entities differ.
Line structure is preserved, so line-number spans into the text stay valid. `verify_redacted` re-scans a text and
raises `RedactionError` when anything identifying is left; `redact` runs it on its own output, so it never returns a
text it could still recognise as identifying.

Limits, stated: names are found from the names the caller supplies (every variant: full, initial and surname, first
name, possessive, case, accents), from context (labels such as "Name:", "my name is", titles, sign-offs, a resume
header followed by contact details) and from a list of common first names followed by a capitalised word. A surname
that appears alone, with no context and not in `known_names`, is not found; supply `known_names` for real inputs.
Detection runs on a copy with zero-width characters removed and compatibility forms folded (full-width digits), and
spans are mapped back, so such tricks do not hide an identifier.

Raw test inputs live only in `data/ephemeral/` (gitignored); `read_ephemeral` and `redact_ephemeral` refuse any other
location.
"""
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EPHEMERAL = ROOT / "data" / "ephemeral"


class RedactionError(ValueError):
    pass


FIRST_NAMES = frozenset("""
James John Robert Michael William David Richard Joseph Thomas Charles Christopher Daniel Matthew Anthony Mark Donald Steven Paul Andrew Joshua Kenneth
Kevin Brian George Edward Ronald Timothy Jason Jeffrey Ryan Jacob Gary Nicholas Eric Jonathan Stephen Larry Justin Scott Brandon Benjamin Samuel Gregory
Alexander Patrick Frank Raymond Jack Dennis Jerry Tyler Aaron Henry Douglas Peter Adam Nathan Zachary Walter Kyle Harold Carl Jeremy Keith Roger Gerald
Mary Patricia Jennifer Linda Elizabeth Barbara Susan Jessica Sarah Karen Nancy Lisa Betty Margaret Sandra Ashley Kimberly Emily Donna Michelle Carol Amanda
Dorothy Melissa Deborah Stephanie Rebecca Sharon Laura Cynthia Kathleen Amy Angela Shirley Anna Brenda Pamela Emma Nicole Helen Samantha Katherine Christine
Debra Rachel Carolyn Janet Catherine Maria Heather Diane Ruth Julie Joyce Virginia Victoria Kelly Lauren Christina Joan Evelyn Judith Megan Andrea Cheryl
Hannah Jacqueline Martha Gloria Teresa Ann Sara Madison Frances Kathryn Janice Jean Abigail Alice Julia Judy Sophia Grace Denise Amber Doris Marilyn
Danielle Beverly Isabella Theresa Diana Natalie Brittany Charlotte Marie Kayla Alexis Lori Olivia Priya Ravi Arjun Aisha Fatima Mohammed Muhammad Ahmed Ali
Omar Ibrahim Yusuf Hassan Leila Layla Zainab Nadia Ayesha Dina Chen Wei Li Wang Yuki Hiroshi Kenji Mei Jin Min Kim Sofia Elena Carmen Rosa Lucia Mateo
Lucas Diego Carlos Miguel Jose Juan Luis Pedro Javier Pablo Gabriel Hugo Felix Oscar Viktor Ivan Dmitri Sergei Tomasz Mateusz Piotr Pawel Jan Henrik Lars
Ingrid Astrid Nils Sven Kwame Kofi Amara Ngozi Chidi Emeka Tunde Liam Noah Oliver Elijah Ethan Mason Logan Owen Leo Sam Max Ben Tom Dan Tim Joe Jim Bob
Bill Tony Steve Mike Dave Ed Fred Sophie Chloe Zoe Lily Mia Ella Ruby Evie Freya Isla Holly Poppy Imogen Amelia Harper Ava Ivy Nora Clara Anya Irina
Olga Natasha Svetlana Katya Yara Salma Mona Hana Rania Karim Tariq Samir Rashid Faisal Jamal Aamir Sanjay Rahul Amit Vikram Anil Sunil Deepak Neha Pooja
Anita Sunita Kavita Meera Divya Sneha Ananya
""".split())
STOP_AFTER = frozenset("Street Road Avenue Lane Drive Close Way Court Square University College School Hospital Institute Park Bay Hall Library Centre Center".split())
TITLE_STOP = frozenset({"curriculum vitae", "resume", "cv", "personal statement", "cover letter", "summary", "profile"})
ZERO_WIDTH = frozenset("​‌‍⁠﻿­")
STREET_WORDS = r"(?:Street|St|Road|Rd|Avenue|Ave|Lane|Ln|Drive|Dr|Close|Way|Court|Ct|Boulevard|Blvd|Place|Pl|Terrace|Crescent|Square|Gardens|Walk|Row|Hill|Park)"
CAP = r"[A-Z][\w'’\-]*"
POSTAL = r"(?:[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}|(?:NSW|VIC|QLD|WA|SA|TAS|ACT|NT)\s\d{4}|\d{4,5}(?:-\d{4})?)"
EXT = rf"(?:[ \t]*,[ \t]*{CAP}(?:[ \t]+{CAP})*(?:[ \t]+{POSTAL})?)"
DATE_NUM = r"\d{1,4}\s?[/.\-]\s?\d{1,2}\s?[/.\-]\s?\d{1,4}"
MONTH = r"(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"
DATE_TXT = rf"(?:\d{{1,2}}(?:st|nd|rd|th)?(?:\s+of)?\s+{MONTH}\.?,?\s+\d{{4}}|{MONTH}\.?\s+\d{{1,2}}(?:st|nd|rd|th)?,?\s+\d{{4}})"
OPTS = re.IGNORECASE

RX = {
    "EMAIL": [re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}"),
              re.compile(r"[A-Za-z0-9._%+\-]+\s*(?:\[at\]|\(at\)|\{at\}|\sat\s)\s*[A-Za-z0-9\-]+(?:\s*(?:\[dot\]|\(dot\)|\{dot\}|\.)\s*[A-Za-z0-9\-]+)+", OPTS)],
    "URL": [re.compile(r"(?:https?://|www\.)[^\s<>\"')\]]+", OPTS)],
    "HANDLE": [re.compile(r"(?<![\w@.])@[A-Za-z0-9_]{3,30}\b")],
    "ID": [re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
           re.compile(r"\b[A-Z]{2}\s?\d{2}\s?\d{2}\s?\d{2}\s?[A-D]\b"),
           re.compile(r"\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]{4}){2,7}(?:\s?[A-Z0-9]{1,4})?\b")],
    "ADDRESS": [re.compile(rf"\b\d{{1,5}}[A-Za-z]?[ \t]+(?:{CAP}[ \t]+){{0,4}}{STREET_WORDS}\b\.?(?:[ \t]+(?:NW|NE|SW|SE|N|S|E|W)\b)?{EXT}*"),
                re.compile(rf"\b\d{{1,5}}[A-Za-z]?[ \t]+(?:Rue|Via|Calle|Avenida|Boulevard|Avenue)[ \t]+(?:(?:de[ \t]+la|de|du|des|del|di)[ \t]+)?{CAP}(?:[ \t]+{CAP})*{EXT}*"),
                re.compile(rf"\b(?:Flat|Apt\.?|Apartment|Unit|Suite)[ \t]+\w+[ \t]*,[ \t]*\d{{1,5}}[A-Za-z]?[ \t]+[^\n,;]+{EXT}*"),
                re.compile(rf"\bP\.?[ \t]?O\.?[ \t]?Box[ \t]+\d+{EXT}*", OPTS),
                re.compile(r"(?i:address)\s*:[ \t]*[^\n]+"),
                re.compile(r"\b[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}\b")],
}
ID_LABEL = re.compile(r"(?i)\b(?:passport(?:\s*(?:no\.?|number|#))?|employee\s*id|staff\s*id|national\s*id|customer\s*id|member(?:ship)?\s*(?:no\.?|number|id)|licen[cs]e(?:\s*(?:no\.?|number))?|tax\s*id|nin|ssn|id(?:\s*(?:no\.?|number))?)\s*[:#]?\s*([A-Z0-9][A-Z0-9\-]{4,})")
PHONES = [
    re.compile(r"(?<![\w.])(?:\+|00)\d{1,3}[\s.\-]?(?:\(\d{1,4}\)[\s.\-]?)?\d{1,4}(?:[\s.\-]\d{2,4}){1,4}(?:\s?(?:ext\.?|x)\s?\d{1,5})?", OPTS),
    re.compile(r"(?<![\w.])(?:1[\s.\-])?\(?\d{3}\)?[\s.\-]\d{3}[\s.\-]\d{4}(?:\s?(?:ext\.?|x)\s?\d{1,5})?", OPTS),
    re.compile(r"(?<![\w.])0\d{2,4}[\s\-]\d{3,4}[\s\-]\d{3,4}\b"),
]
DOB_CUE = r"(?:d\.?\s?o\.?\s?b\b\.?|date\s+of\s+birth|birth\s?date|birthday|born(?:\s+on)?)\s*[:\-]?\s*"
DOB = re.compile(rf"(?i:{DOB_CUE})(?P<d>{DATE_NUM}|{DATE_TXT}|\d{{4}})", re.IGNORECASE)
NAME_LABEL = re.compile(r"(?im)^[ \t]*(?:name|full\s+name|candidate|applicant|referee|reference|contact(?:\s+person)?|signed)\s*:[ \t]*(?P<n>[^\n]+?)[ \t]*$")
MY_NAME = re.compile(rf"(?i:my\s+name\s+is|call\s+me|name's)[ \t]+(?P<n>{CAP}(?:[ \t]+{CAP}){{0,2}})")
TITLED = re.compile(rf"\b(?:Mr|Mrs|Ms|Miss|Mx|Dr|Prof|Professor|Sir|Dame|Rev|Reverend)\b\.?[ \t]+(?P<n>{CAP}(?:[ \t]+{CAP}){{0,2}})")
SIGNOFF = re.compile(r"(?im)^[ \t]*(?:best\s+regards|kind\s+regards|warm\s+regards|regards|sincerely|yours\s+sincerely|yours\s+faithfully|best\s+wishes|thanks|thank\s+you|cheers),?[ \t]*\n[ \t]*(?P<n>[^\n]{2,60}?)[ \t]*$")
NAMELIKE = re.compile(rf"^{CAP}(?:[ \t]+(?:[A-Z]\.|{CAP})){{1,3}}$")
FIRST_THEN = re.compile(rf"\b(?P<f>[A-Z][a-z]+)(?P<rest>(?:[ \t]+(?:[A-Z]\.|[A-Z][\w'’\-]*[a-z\w]))(?:[ \t]+[A-Z][\w'’\-]*)?)")


def _normalise(text):
    """(normalised text, index map back to the original): zero-width characters removed, compatibility forms folded."""
    out, idx = [], []
    for i, ch in enumerate(text):
        if ch in ZERO_WIDTH:
            continue
        n = unicodedata.normalize("NFKC", ch)
        for c in n:
            out.append(c)
            idx.append(i)
    return "".join(out), idx


def _strip_accents(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def _luhn(digits):
    s, alt = 0, False
    for ch in reversed(digits):
        d = int(ch)
        if alt:
            d = d * 2 - 9 if d * 2 > 9 else d * 2
        s += d
        alt = not alt
    return s % 10 == 0


def _name_variants(name):
    """[(regex, flags)] matching every variant of a known name: full, 'F. Last', 'Last, First', surname parts, first name."""
    parts = name.split()
    if not parts:
        return []
    first, last = parts[0], parts[-1]
    out = []
    forms = {name, f"{first[0]}. {' '.join(parts[1:])}", f"{first[0]} {' '.join(parts[1:])}"}
    if len(parts) > 1:
        forms.add(f"{' '.join(parts[1:])}, {first}")
        forms.add(f"{first} {last[0]}.")
    for f in forms:
        for g in {f, _strip_accents(f)}:
            out.append((rf"(?<!\w){re.escape(g).replace(r'\ ', r'[ \t]+')}(?:['’]s)?(?!\w)", re.IGNORECASE))
    if len(parts) > 1:
        surname = " ".join(parts[1:])
        for sn in {surname, _strip_accents(surname)} | {p for p in re.split(r"[-\s]", surname) if len(p) >= 4} | {_strip_accents(p) for p in re.split(r"[-\s]", surname) if len(p) >= 4}:
            if len(sn) >= 3:
                out.append((rf"(?<!\w){re.escape(sn)}(?:['’]s)?(?!\w)", re.IGNORECASE))
    if len(first) >= 3:
        for fn in {first, _strip_accents(first)}:
            out.append((rf"(?<!\w)(?:{re.escape(fn)}|{re.escape(fn.upper())})(?:['’]s)?(?!\w)", 0))
    return out


def _spans(norm, known_names, allow):
    """[(start, end, kind, key)] found in the normalised text (key: entity number for known names)."""
    spans = []

    def add(m, kind, group=0, key=None):
        s, e = m.span(group)
        if s < e:
            spans.append((s, e, kind, key))

    for kind, rxs in RX.items():
        for rx in rxs:
            for m in rx.finditer(norm):
                add(m, kind)
    for m in ID_LABEL.finditer(norm):
        add(m, "ID", 1)
    for m in re.finditer(r"\b(?:\d[ \-]?){13,19}\b", norm):
        digits = re.sub(r"\D", "", m.group())
        if 13 <= len(digits) <= 19 and _luhn(digits):
            add(m, "ID")
    for rx in PHONES:
        for m in rx.finditer(norm):
            if len(re.sub(r"\D", "", m.group())) >= 7:
                add(m, "PHONE")
    for m in DOB.finditer(norm):
        add(m, "DOB", "d")
    for rx in (NAME_LABEL, SIGNOFF):
        for m in rx.finditer(norm):
            if len(m.group("n").split()) <= 5 and not any(ch.isdigit() or ch in "@[]" for ch in m.group("n")):
                add(m, "NAME", "n")
    for rx in (MY_NAME, TITLED):
        for m in rx.finditer(norm):
            add(m, "NAME", "n")
    lines = norm.split("\n")
    pos = 0
    first_seen = False
    for li, line in enumerate(lines):
        if line.strip() and not first_seen:
            first_seen = True
            near = "\n".join(lines[li + 1:li + 4])
            if NAMELIKE.match(line.strip()) and line.strip().lower() not in TITLE_STOP and (re.search(r"@|\d{3}[\s.\-]\d{3,4}", near) or "[EMAIL" in near):
                s = pos + line.index(line.strip())
                spans.append((s, s + len(line.strip()), "NAME", None))
        pos += len(line) + 1
    for m in FIRST_THEN.finditer(norm):
        if m.group("f") in FIRST_NAMES and m.group("rest").split()[0] not in STOP_AFTER:
            whole = m.group().strip()
            if whole not in allow and not any(w in STOP_AFTER for w in whole.split()):
                spans.append((m.start(), m.end(), "NAME", None))
    for k, name in enumerate(known_names):
        for pat, fl in _name_variants(name):
            for m in re.finditer(pat, norm, fl | re.UNICODE):
                spans.append((m.start(), m.end(), "NAME", k))
    return spans


def _resolve(spans):
    """Non-overlapping spans: the earliest, then the longest, wins."""
    spans = sorted(spans, key=lambda s: (s[0], -(s[1] - s[0]), s[3] is None))  # a known name outranks a guess
    out, end = [], -1
    for s in spans:
        if s[0] >= end:
            out.append(s)
            end = s[1]
    return out


def redact(text, known_names=(), allow=()):
    """`text` with identifying spans replaced by numbered placeholders; raises RedactionError if any remain."""
    names = [n for n in known_names if n and n.strip()]
    norm, idx = _normalise(text)
    spans = _resolve(_spans(norm, names, set(allow)))
    counters = {}
    labels = {}
    out, last = [], 0
    for s, e, kind, key in spans:
        o_s, o_e = idx[s], idx[e - 1] + 1
        if kind == "NAME" and key is not None:
            ident = ("NAME", key)
        else:
            ident = (kind, re.sub(r"\W", "", norm[s:e]).lower())
        if ident not in labels:
            if kind == "NAME":
                labels[ident] = (key + 1) if key is not None else len(names) + 1 + sum(1 for k in labels if k[0] == "NAME" and not isinstance(k[1], int))
            else:
                counters[kind] = counters.get(kind, 0) + 1
                labels[ident] = counters[kind]
        out.append(text[last:o_s])
        out.append(f"[{kind}_{labels[ident]}]")
        last = o_e
    out.append(text[last:])
    result = "".join(out)
    verify_redacted(result, names, allow)
    return result


def verify_redacted(text, known_names=(), allow=()):
    """`text` itself when nothing identifying is detectable in it; otherwise RedactionError naming kinds and offsets
    (never the values, so the error cannot leak what it guards)."""
    norm, _ = _normalise(text)
    left = _resolve(_spans(norm, [n for n in known_names if n and n.strip()], set(allow)))
    if left:
        raise RedactionError("unredacted " + ", ".join(f"{k}@{s}" for s, e, k, _ in left[:10]))
    return text


def read_ephemeral(name):
    """The text of `data/ephemeral/<name>`; any path that resolves outside that folder is refused."""
    path = (EPHEMERAL / name).resolve()
    if EPHEMERAL.resolve() not in path.parents:
        raise ValueError(f"{name!r} is outside data/ephemeral/; raw test inputs live only there")
    return path.read_text(encoding="utf-8")


def redact_ephemeral(name, known_names=(), allow=()):
    """Redact `data/ephemeral/<name>` into `data/ephemeral/<name>.redacted` and return the redacted text; the raw
    input and its redaction never leave the ignored folder."""
    text = redact(read_ephemeral(name), known_names, allow)
    out = (EPHEMERAL / (name + ".redacted")).resolve()
    if EPHEMERAL.resolve() not in out.parents:
        raise ValueError("output outside data/ephemeral/")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    return text
