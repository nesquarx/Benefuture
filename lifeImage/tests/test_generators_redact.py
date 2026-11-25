"""Redaction: names, emails, phones, addresses, dates of birth and ids become placeholders, and anything left over
raises. Red first against a stub that only strips phone numbers."""
import pytest

from lifeimage.generators import life
from lifeimage.redact import RedactionError, redact, verify_redacted

NAMES = ["Maria Gonzalez-Pérez"]


def clean(text, names=NAMES, **kw):
    out = redact(text, known_names=names, **kw)
    verify_redacted(out, known_names=names)
    return out


@pytest.mark.parametrize("text,leak", [
    ("Contact: maria.g+jobs@mail.example.co.uk today", "maria.g"),
    ("Mail MARIA@Example.ORG or <m_g@sub.domain.io>.", "@"),
    ("Call +44 20 7946 0958 or (415) 555-0132 or 415.555.0132 or +1-415-555-0132 ext. 4", "555"),
    ("Mobile 0412 345 678; tel: 020 7946 0958", "0412"),
    ("Lives at 221B Baker Street, London NW1 6XE", "Baker"),
    ("42 Wallaby Way, Sydney NSW 2000; 1600 Pennsylvania Ave NW, Washington, DC 20500", "Wallaby"),
    ("Address: Flat 3, 14 Rue de la Paix, 75002 Paris", "Rue de la Paix"),
    ("P.O. Box 1234, Springfield", "1234"),
    ("DOB: 14/03/1990", "1990"),
    ("Date of birth 1990-03-14", "1990"),
    ("born on March 14, 1990 in Leeds", "1990"),
    ("Born 3rd of May 1985.", "1985"),
    ("d.o.b. 03.14.90", "90"),
    ("SSN 123-45-6789 and NI number QQ 12 34 56 C", "6789"),
    ("Passport No: X1234567; Employee ID: EMP-009812", "X1234567"),
    ("IBAN GB82 WEST 1234 5698 7654 32 card 4111 1111 1111 1111", "4111"),
    ("Name: Jonathan Smith\nSkills: Python", "Jonathan"),
    ("My name is Priya Raman and I teach.", "Priya"),
    ("Dr. Alice Okafor, MD led the study", "Okafor"),
    ("Regards,\nLiam O'Neill", "Neill"),
    ("References: Mr. Tomasz Kowalski (manager)", "Kowalski"),
    ("https://www.linkedin.com/in/jane-doe-12345 and twitter @janedoe", "jane"),
])
def test_pii_is_replaced_with_placeholders(text, leak):
    out = clean(text)
    assert leak not in out, out
    assert "[" in out


def test_known_names_every_variant_and_possessive_and_initials_are_caught():
    t = "Maria Gonzalez-Pérez led it. M. Gonzalez-Pérez signed; gonzalez-pérez's team; MARIA GONZALEZ-PÉREZ; Maria"
    out = clean(t)
    assert "Maria" not in out and "onzalez" not in out and "M. G" not in out


def test_content_that_is_not_pii_survives():
    t = "Worked 2015-2019 as a nurse in 3 wards; led 12 staff; trained in 2012; earned 45,000 EUR; ran 5 km on 12 May."
    assert redact(t, known_names=NAMES) == t


def test_anything_unredacted_raises():
    with pytest.raises(RedactionError):
        verify_redacted("write to jane@example.org", known_names=())
    with pytest.raises(RedactionError):
        verify_redacted("Maria Gonzalez-Pérez", known_names=NAMES)
    with pytest.raises(RedactionError):
        verify_redacted("call 415-555-0132", known_names=())
    with pytest.raises(RedactionError):
        verify_redacted("DOB 1990-03-14", known_names=())
    with pytest.raises(RedactionError):
        verify_redacted("John Smith worked here", known_names=())  # a first name followed by a surname
    verify_redacted("[NAME] worked here [EMAIL] [PHONE]", known_names=NAMES)


def test_placeholders_are_stable_and_distinct_per_entity():
    out = redact("Ann Lee met Bo Tan. Ann Lee wrote to bo@example.org and ann@example.org.", known_names=["Ann Lee", "Bo Tan"])
    assert out.count("[NAME_1]") == 2 and out.count("[NAME_2]") == 1
    assert "[EMAIL_1]" in out and "[EMAIL_2]" in out


def test_redaction_keeps_line_structure_and_is_idempotent():
    t = "Name: Jonathan Smith\nEmail: j@example.org\n\nExperience\n2015-2019 Nurse"
    out = redact(t, known_names=["Jonathan Smith"])
    assert "Jonathan" not in out and "j@example.org" not in out
    assert out.count("\n") == t.count("\n") and redact(out, known_names=["Jonathan Smith"]) == out


def test_generated_resume_redacts_cleanly_and_keeps_its_ground_truth_lines():
    for s in range(10):
        p = life.generate_persona(s, "generalist", 40)
        assert "@example.org" in p.texts["resume"] and p.name in p.texts["resume"]
        out = clean(p.texts["resume"], names=[p.name])
        assert out.count("\n") == p.texts["resume"].count("\n")
        assert p.name not in out and "@example.org" not in out and "555-01" not in out
        for e in p.events:
            for i in e["rows"]:
                r = p.rows[i]
                if r["provenance"]["source"].startswith("resume:"):
                    n = int(r["provenance"]["span"].lstrip("L"))
                    assert e["phrase"] in out.splitlines()[n - 1]
        self_text = clean(p.texts["self"], names=[p.name])
        assert p.name.split()[0] not in self_text


@pytest.mark.parametrize("text,leak", [
    ("jane [at] example [dot] org", "example"),
    ("jane(at)example.org", "jane"),
    ("call ４１５-５５５-０１３２ now", "５５５"),
    ("mail ja​ne@exa​mple.org", "example"),
    ("Maria​ Gonzalez​-Pérez", "onzalez"),
    ("Maria Gonzalez-Perez wrote this", "Perez"),
    ("MARIA GONZALEZ-PEREZ", "GONZALEZ"),
    ("Visit www.janedoe-portfolio.com for more", "janedoe"),
    ("Tel +49 (0)30 1234 5678", "1234"),
])
def test_obfuscations_and_variants_do_not_hide_identifiers(text, leak):
    out = clean(text)
    assert leak not in out, out


def test_raw_inputs_are_read_only_from_the_ephemeral_folder(tmp_path):
    from lifeimage import redact as R
    with pytest.raises(ValueError):
        R.read_ephemeral("../README.md")
    with pytest.raises(ValueError):
        R.read_ephemeral("/etc/passwd")
    R.EPHEMERAL.mkdir(parents=True, exist_ok=True)
    f = R.EPHEMERAL / "_redact_test_input.txt"
    f.write_text("Name: Jonathan Smith\nEmail: j@example.org\n")
    try:
        out = R.redact_ephemeral("_redact_test_input.txt", ["Jonathan Smith"])
        assert "Jonathan" not in out and "@" not in out
        assert (R.EPHEMERAL / "_redact_test_input.txt.redacted").read_text() == out
    finally:
        f.unlink()
        (R.EPHEMERAL / "_redact_test_input.txt.redacted").unlink()


def test_verification_error_never_echoes_the_identifier():
    with pytest.raises(RedactionError) as e:
        verify_redacted("write to secret.person@example.org", known_names=())
    assert "secret" not in str(e.value) and "EMAIL" in str(e.value)
