"""Realistic texts for extraction (outcome tests, red first against a stub that returns the templated v1 texts):
the templates must no longer parse mechanically, and embellishment must follow the persona's calibration type.

Predictions (stated before measuring): a strict date-led line parser recovers at least 95% of the resume rows on v1 texts
and at most 35% on v2 texts; a lenient one (month names, any separator) at least 95% and at most 60%; the mean count
of inflating words minus deflating words per resume is higher for over-estimators than for well-calibrated personas
and higher for those than for under-estimators, each by at least 0.5 words and beyond z = 3 combined standard errors."""
import importlib.util
import math
import re
import statistics as st
from functools import lru_cache
from pathlib import Path

import pytest

from lifeimage.generators import catalogue as C
from lifeimage.generators import life
from lifeimage.generators.texts_v2 import embellishment_score, render_texts_v2

ROOT = Path(__file__).resolve().parent.parent
AS_OF = "2026-11-24"
STRICT = re.compile(r"^(\d{4})(?:-(\d{4}|present))?  (.+)$")  # what the v1 template writes: "2019-2022  text"
LENIENT = re.compile(r"^\W*(?:[A-Z][a-z]{2,8}\.?\s+)?(\d{4})\b")  # a date-led line in any common layout


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@lru_cache(maxsize=1)
def population():
    out = []
    for n, arch in enumerate(sorted(life.ARCHETYPES)):
        lo, hi = life.ARCHETYPES[arch]["age_range"]
        for j, age in enumerate([lo, lo + (hi - lo) // 4, (lo + hi) // 2, hi - (hi - lo) // 4, hi]):
            out.append(life.generate_persona(100 + 10 * n + j, arch, age, as_of=AS_OF))
    return out


@lru_cache(maxsize=1)
def rendered():
    return [render_texts_v2(p) for p in population()]


def resume_rows(p):
    return [(i, r) for i, r in enumerate(p.rows) if r["tier"] == "claimed" and r["provenance"]["source"].startswith("resume:")]


def recovered(rx, text, spans, rows):
    """Share of the resume rows whose span line a date-led parser reads with the row's year."""
    lines = text.splitlines()
    hit = 0
    for i, r in rows:
        n = spans[i]
        m = rx.match(lines[n - 1]) if 0 < n <= len(lines) else None
        hit += bool(m) and int(m.group(1)) == int(r["valid_time"][:4])
    return hit, len(rows)


def v1_spans(p):
    return {i: int(r["provenance"]["span"][1:]) for i, r in resume_rows(p)}


def parse_score(rx, version, personas=None, texts=None):
    h = n = 0
    for p, t in zip(personas or population(), texts or rendered()):
        rows = resume_rows(p)
        if version == 1:
            a, b = recovered(rx, p.texts["resume"], v1_spans(p), rows)
        else:
            a, b = recovered(rx, t.texts["resume"], t.spans["resume"], rows)
        h, n = h + a, n + b
    return h / n


def test_a_strict_line_parser_that_reads_v1_texts_fails_on_v2_texts():
    v1, v2 = parse_score(STRICT, 1), parse_score(STRICT, 2)
    assert v1 >= 0.95, v1
    assert v2 <= 0.35 and v1 - v2 >= 0.6, (v1, v2)


def test_a_lenient_date_led_parser_also_loses_a_large_share():
    v1, v2 = parse_score(LENIENT, 1), parse_score(LENIENT, 2)
    assert v1 >= 0.95, v1
    assert v2 <= 0.6 and v1 - v2 >= 0.35, (v1, v2)


def test_narrative_and_skills_first_resumes_defeat_the_lenient_parser_each():
    by = {}
    for p, t in zip(population(), rendered()):
        rows = resume_rows(p)
        a, b = recovered(LENIENT, t.texts["resume"], t.spans["resume"], rows)
        h, n = by.get(t.meta["format"], (0, 0))
        by[t.meta["format"]] = (h + a, n + b)
    assert set(by) == {"chronological", "skills_first", "narrative"}
    assert by["narrative"][0] / by["narrative"][1] <= 0.15
    assert by["skills_first"][0] / by["skills_first"][1] <= 0.3


def test_every_format_occurs_in_a_substantial_share_of_the_resumes():
    fm = [t.meta["format"] for p, t in zip(population(), rendered()) if resume_rows(p)]
    for f in ("chronological", "skills_first", "narrative"):
        assert fm.count(f) / len(fm) >= 0.15, (f, fm.count(f), len(fm))


def test_deterministic_by_seed_and_different_across_seeds():
    p, q = population()[12], population()[13]
    a, b, c = render_texts_v2(p), render_texts_v2(p), render_texts_v2(q)
    assert a.texts == b.texts and a.spans == b.spans and a.texts["resume"] != c.texts["resume"]
    assert sum(t.texts["resume"] != p.texts["resume"] for p, t in zip(population(), rendered())) >= 0.9 * len(population())


MAIN_SLOT = {"job": "title", "promotion": "title", "course": "skill", "degree": "field", "degree_start": "field", "phd": "field",
             "language": "lang", "tutoring": "subject", "publication": "field", "volunteer": "org", "community_group": "group",
             "advocacy": "cause", "business_start": "biz", "faith_role": "body", "school": "school", "exam": "exam",
             "workplace_award": "award", "employment_transition": "sector_label", "business_growth": "growth"}


def test_every_truth_row_keeps_a_span_on_a_line_that_still_names_what_it_is_about():
    seen = ok = 0
    for p, t in zip(population(), rendered()):
        lines = t.texts["resume"].splitlines()
        by_row = {ri: e for e in p.events for ri in e["rows"]}
        for i, r in resume_rows(p):
            assert i in t.spans["resume"], "no row is dropped from the text"
            n = t.spans["resume"][i]
            assert 1 <= n <= len(lines) and lines[n - 1].strip()
            e = by_row[i]
            slot = MAIN_SLOT.get(e["key"])
            if slot:
                seen += 1
                ok += str(e["detail"][slot]).lower() in lines[n - 1].lower()
    assert seen > 100 and ok / seen >= 0.97, (ok, seen)


def test_self_and_diary_rows_also_keep_valid_spans_and_diary_dates_vary():
    formats = set()
    for p, t in zip(population(), rendered()):
        for doc in ("self", "diary"):
            lines = t.texts[doc].splitlines()
            for i, r in enumerate(p.rows):
                if r["tier"] == "claimed" and r["provenance"]["source"].startswith(doc + ":"):
                    n = t.spans[doc][i]
                    assert 1 <= n <= len(lines) and lines[n - 1].strip()
        for l in t.texts["diary"].splitlines():
            formats.add(re.sub(r"[A-Za-z]+", "A", re.sub(r"\d", "9", l.split(" ")[0]))[:12])
    assert len(formats) >= 3, formats
    assert any(t.texts["self"] != p.texts["self"] for p, t in zip(population(), rendered()))


def test_phrasing_varies_dates_go_vague_and_personal_lines_appear():
    text = "\n".join(t.texts["resume"] for t in rendered())
    assert re.search(r"\b(c\. \d{4}|around \d{4}|early \d{4}s|late \d{4}s|since \d{4}|\d{4} or so)", text)
    assert re.search(r"(?i)\b(interests|outside work|in my spare time|enjoys)\b", text)
    shapes = set()
    for p, t in zip(population(), rendered()):
        by_row = {ri: e for e in p.events for ri in e["rows"]}
        lines = t.texts["resume"].splitlines()
        for i, r in resume_rows(p):
            e = by_row[i]
            if e["key"] == "job":
                l = lines[t.spans["resume"][i] - 1]
                for slot, tag in (("title", "T"), ("employer", "E")):
                    l = re.sub(re.escape(str(e["detail"][slot])), tag, l, flags=re.I)
                shapes.add(re.sub(r"\d+|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b", "", l))
    assert len(shapes) > 8, shapes


# ---- embellishment follows the calibration type ----
SEEDS = range(60)


@lru_cache(maxsize=1)
def scores():
    out = {}
    for cal in ("over", "well", "under"):
        out[cal] = [embellishment_score(render_texts_v2(life.generate_persona(s, ("generalist", "researcher", "small_business_owner")[s % 3],
                                                                             40 + s % 15, as_of=AS_OF, calibration=cal)).texts["resume"])
                    for s in SEEDS]
    return out


def paired(a, b, z=3.0):
    d = [x - y for x, y in zip(a, b)]
    return st.mean(d), z * st.stdev(d) / math.sqrt(len(d))


def test_over_estimators_embellish_more_than_well_calibrated_who_embellish_more_than_under_estimators():
    s = scores()
    for hi, lo in (("over", "well"), ("well", "under")):
        eff, margin = paired(s[hi], s[lo])
        assert eff >= 0.5 and eff > margin, (hi, lo, eff, margin)


def test_embellishment_correlates_with_the_calibration_type_across_all_personas():
    s = scores()
    xs = [c for c, v in (("over", 1), ("well", 0), ("under", -1)) for c in [v] * len(SEEDS)]
    ys = [y for cal in ("over", "well", "under") for y in s[cal]]
    mx, my = st.mean(xs), st.mean(ys)
    r = sum((a - mx) * (b - my) for a, b in zip(xs, ys)) / math.sqrt(sum((a - mx) ** 2 for a in xs) * sum((b - my) ** 2 for b in ys))
    assert r >= 0.5, r


def test_the_score_counts_inflating_minus_deflating_words():
    assert embellishment_score("Lead engineer, spearheaded an outstanding project") >= 3
    assert embellishment_score("Assisted with a basic course, just a junior role") <= -3
    assert embellishment_score("Worked as a driver at Northgate Distribution") == 0


def test_the_committed_v2_texts_are_what_the_generator_writes_and_the_rows_are_untouched():
    tool = load_tool("gen_texts_v2")
    files = tool.build()
    assert len(files) == 161  # 40 personas x (resume, self, diary, spans), and truth_spans.jsonl
    assert all((tool.OUT / k).read_text(encoding="utf-8") == v for k, v in files.items())
    starter = load_tool("gen_starter")
    assert starter.build()["rows.jsonl"] == (ROOT / "data/synthetic/rows.jsonl").read_text(encoding="utf-8")
