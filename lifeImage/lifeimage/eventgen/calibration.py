"""Calibration table: aggregate rate parameters with their strata, sources and source statements.

Only aggregates enter the repository (LI.61, LI.63, LI.64): a published rate, share or mean for a stratum, never a row of
microdata. Each `Param` names its source, URL, licence class, confidence, the age band, sex and region it holds for, and
carries (LI.64) its provenance as `source_statement` (the factual statement that gives the value, with `snippet_locator` and
`retrieved`) and `event_snippets`: records of someone doing something and, where present, what resulted (actor, action,
outcome, timescale, domain tags, source id, locator, sanitization note), kept for recalibration and verification. Event snippets are
paraphrases without personal names (public figures excepted, see `public_figures.txt`), identifying detail or individual rows.
A Param lacking either states why in `snippet_missing`; one lacking its source statement has confidence low.

Region strata: a country (ISO3), a World Bank region (aggregate code) or the world ("WLD"). `Table.lookup` falls back
country -> region -> world and records each substitution loudly (a `degraded` entry and one warning per kind).
"""
import json
import re
import warnings
from dataclasses import asdict, dataclass, fields
from dataclasses import field as _dc_field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAL_DIR = ROOT / "data" / "events" / "calibration"
CONFIDENCE = ("low", "medium", "high")
LICENCES = ("open", "open-sa", "non-commercial", "unread")
SEXES = ("f", "m", "all")
WORLD = "WLD"
WB_REGIONS = frozenset({"EAS", "ECS", "LCN", "MEA", "NAC", "SAS", "SSF", WORLD})
SNIPPET_MAX = 400
TIMESCALES = ("minutes/hours", "day", "weeks-months", "years", "life transition")
EVENT_KEYS = ("actor", "action", "outcome", "timescale", "domains", "source_id", "locator", "sanitization", "relational")
# Capitalised words an event snippet may carry besides a sentence's first word: places, regions, institutions, languages.
PLACE_WORDS = frozenset("""Africa African Asia Asian Europe European America American Americas Latin Caribbean Pacific East South North West
Central Sub-Saharan Saharan Middle Kenya India Germany Brazil China Egypt Kenyan Indian German Brazilian Chinese Egyptian
Eastern Southern Northern Western World Bank United States Arab Republic Rep Pacific Eurostat UN WPP ILO WHO UNICEF UNESCO DHS MICS English""".split())


def public_figures(directory=None):
    f = Path(directory or CAL_DIR) / "public_figures.txt"
    return frozenset(l.strip() for l in f.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")) if f.exists() else frozenset()


def personal_names(text, figures=frozenset()):
    """Capitalised tokens that are neither a sentence's first word, nor a place or institution, nor part of a listed public figure."""
    for fig in figures:
        text = text.replace(fig, " ")
    out = []
    for sent in re.split(r"(?<=[.!?])\s+", text):
        for i, w in enumerate(re.findall(r"[A-Za-z][A-Za-z'-]*", sent)):
            if i and w[0].isupper() and w not in PLACE_WORDS and not w.isupper():
                out.append(w)
    return out


def validate_event_snippet(e, figures=frozenset()):
    if not isinstance(e, dict) or any(k not in e for k in EVENT_KEYS):
        raise CalibrationError(f"event snippet needs keys {EVENT_KEYS}")
    for k in ("actor", "action", "source_id", "locator", "sanitization"):
        if not str(e[k]).strip():
            raise CalibrationError(f"event snippet without {k}")
    if e["timescale"] not in TIMESCALES:
        raise CalibrationError(f"event snippet timescale {e['timescale']!r} not in {TIMESCALES}")
    if not e["domains"] or not all(str(d).startswith("c.") for d in e["domains"]):
        raise CalibrationError("event snippet needs coarse domain tags")
    text = " ".join(str(e[k] or "") for k in ("actor", "action", "outcome"))
    if len(text) > SNIPPET_MAX:
        raise CalibrationError("event snippet longer than a short record")
    names = personal_names(text, figures)
    if names:
        raise CalibrationError(f"event snippet carries a personal name {names} not on the public-figure list")
    from .relational import validate_relational_snippet   # LI.65: the free text stays, and its relational form must be complete
    from ..validate import ValidationError
    try:
        validate_relational_snippet(e["relational"])
    except (ValidationError, KeyError, TypeError) as exc:
        raise CalibrationError(f"event snippet's relational form is incomplete: {exc}") from exc


class CalibrationError(ValueError):
    pass


@dataclass(frozen=True)
class Param:
    field: str            # coarse field family id (c.*)
    quantity: str         # dotted name, e.g. fertility.asfr
    value: float
    unit: str
    age_band: str         # "15-19", "0", "all"
    sex: str              # f | m | all
    region: str           # ISO3 country, World Bank region code, or WLD
    year: int
    source_id: str
    source_url: str
    licence: str
    confidence: str
    notes: str = ""
    source_statement: str = ""
    event_snippets: list = _dc_field(default_factory=list)
    snippet_locator: str = ""
    retrieved: str = ""
    snippet_missing: str = ""

    @property
    def key(self):
        return (self.quantity, self.age_band, self.sex, self.region)

    @property
    def region_kind(self):
        return "world" if self.region == WORLD else "region" if self.region in WB_REGIONS else "country"


def validate(p, field_ids=None, figures=frozenset()):
    """Raise CalibrationError unless `p` is a complete, well-formed Param."""
    for f in ("field", "quantity", "unit", "age_band", "sex", "region", "source_id", "source_url", "licence", "confidence"):
        if not str(getattr(p, f)).strip():
            raise CalibrationError(f"{p.quantity}: missing {f}")
    if not p.source_url.startswith(("http://", "https://")):
        raise CalibrationError(f"{p.quantity}: source_url must be an http(s) URL")
    if p.confidence not in CONFIDENCE:
        raise CalibrationError(f"{p.quantity}: confidence {p.confidence!r} not in {CONFIDENCE}")
    if p.licence not in LICENCES:
        raise CalibrationError(f"{p.quantity}: licence {p.licence!r} not in {LICENCES}")
    if p.sex not in SEXES:
        raise CalibrationError(f"{p.quantity}: sex {p.sex!r} not in {SEXES}")
    if not isinstance(p.value, (int, float)) or isinstance(p.value, bool) or p.value != p.value:
        raise CalibrationError(f"{p.quantity}: value must be a finite number")
    if not isinstance(p.year, int) or not 1900 <= p.year <= 2100:
        raise CalibrationError(f"{p.quantity}: year out of range")
    if p.region != p.region.upper() or not (p.region in WB_REGIONS or len(p.region) == 3):
        raise CalibrationError(f"{p.quantity}: region {p.region!r} is neither a country (ISO3), a World Bank region nor WLD")
    if field_ids is not None and p.field not in field_ids:
        raise CalibrationError(f"{p.quantity}: unknown field {p.field}")
    if p.source_statement:
        if len(p.source_statement) > SNIPPET_MAX:
            raise CalibrationError(f"{p.quantity}: source_statement longer than {SNIPPET_MAX} characters (a quotation, not a page)")
        if not p.snippet_locator.strip() or not p.retrieved.strip():
            raise CalibrationError(f"{p.quantity}: a source_statement needs snippet_locator and retrieved")
    elif p.confidence != "low":
        raise CalibrationError(f"{p.quantity}: a Param without a source statement has confidence low")
    for e in p.event_snippets:
        validate_event_snippet(e, figures)
    if not (p.source_statement and p.event_snippets) and not p.snippet_missing.strip():
        raise CalibrationError(f"{p.quantity}: lacks a source statement or an event snippet and gives no snippet_missing reason")
    return p


_VALIDATED = {}     # id(param) -> param, kept alive so the id stays unique; skips re-validating the same Param in every world's table


class Table:
    def __init__(self, params, field_ids=None, figures=None):
        self.params = list(params)
        memo = figures is None and field_ids is None
        figures = public_figures() if figures is None else figures
        seen = {}
        for p in self.params:
            if not (memo and _VALIDATED.get(id(p)) is p):   # a Param is frozen: once valid (default field ids and figures), always valid
                validate(p, field_ids, figures)
                if memo:
                    _VALIDATED[id(p)] = p
            if p.key in seen:
                raise CalibrationError(f"duplicate key {p.key}")
            seen[p.key] = p
        self._by = seen
        self.degraded = []
        self._warned = set()

    def get(self, quantity, age_band, sex, region):
        return self._by.get((quantity, age_band, sex, region))

    def lookup(self, quantity, age_band, sex, region, regions=None, step="setup"):
        """The Param for the stratum, else the region's, else the world's, each substitution recorded loudly.

        `regions` maps a country to its World Bank region. Returns None (recorded as a `degraded` entry with substitute
        "none") when not even the world has the quantity; the caller decides what to do, the run never stalls."""
        chain = [(region, "exact")]
        reg = (regions or {}).get(region)
        if reg and reg != region:
            chain.append((reg, "region"))
        if region != WORLD:
            chain.append((WORLD, "world"))
        for sub, kind in chain:
            for sx in dict.fromkeys((sex, "all")):
                p = self.get(quantity, age_band, sx, sub)
                if p is not None:
                    if kind != "exact" or sx != sex:
                        label = sub if sx == sex else f"{sub}:sex={sx}"
                        self.degrade(step, quantity, region, label, f"no {quantity} {age_band} {sex} for {region}")
                    return p
        self.degrade(step, quantity, region, "none", f"caller default used: no {quantity} {age_band} {sex} at any level for {region}")
        return None

    def degrade(self, step, quantity, region, substitute, reason):
        self.degraded.append({"step": step, "mechanism": quantity, "region": region, "substitute": substitute, "reason": reason})
        kind = (quantity, "none" if substitute == "none" else "world" if substitute.startswith(WORLD) else "region")
        if kind not in self._warned:
            self._warned.add(kind)
            warnings.warn(f"degraded: {quantity} for {region} substituted by {substitute} ({reason})", stacklevel=3)


_PARAMS = {}


def load_params(directory=CAL_DIR):
    """The Params of every file in `directory`; parsed once per file state (path, mtime, size), the Params are frozen and shared."""
    files = sorted(Path(directory).glob("*.jsonl"))
    stamp = tuple((str(f), f.stat().st_mtime_ns, f.stat().st_size) for f in files)
    if stamp not in _PARAMS:
        _PARAMS.clear()
        _PARAMS[stamp] = _parse_params(files)
    return list(_PARAMS[stamp])


def _parse_params(files):
    out = []
    for f in files:
        for line in f.read_text(encoding="utf-8").splitlines():
            if line.strip():
                d = json.loads(line)
                out.append(Param(**{k: d[k] for k in (x.name for x in fields(Param)) if k in d}))
    return out


def load_regions(directory=CAL_DIR):
    return json.loads((Path(directory) / "regions.json").read_text(encoding="utf-8"))


def load_table(directory=CAL_DIR, field_ids=None):
    return Table(load_params(directory), field_ids)


def dump_params(params, path):
    with open(path, "w", encoding="utf-8") as f:
        for p in sorted(params, key=lambda p: p.key):
            f.write(json.dumps(asdict(p), sort_keys=True, ensure_ascii=False) + "\n")
