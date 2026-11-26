"""Calibration table: aggregate rate parameters with their strata, sources and source statements.

Only aggregates enter the repository (LI.61, LI.63, LI.64): a published rate, share or mean for a stratum, never a row of
microdata. Each `Param` names its source, URL, licence class, confidence, the age band, sex and region it holds for, and
carries a short sanitized quotation of the source statement (`snippet`, with `snippet_locator` and `retrieved`) so the value
can be re-verified and recalibrated later. A Param without a snippet states why in `snippet_missing` and has confidence low.

Region strata: a country (ISO3), a World Bank region (aggregate code) or the world ("WLD"). `Table.lookup` falls back
country -> region -> world and records each substitution loudly (a `degraded` entry and one warning per kind).
"""
import json
import warnings
from dataclasses import asdict, dataclass, fields
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAL_DIR = ROOT / "data" / "events" / "calibration"
CONFIDENCE = ("low", "medium", "high")
LICENCES = ("open", "open-sa", "non-commercial", "unread")
SEXES = ("f", "m", "all")
WORLD = "WLD"
WB_REGIONS = frozenset({"EAS", "ECS", "LCN", "MEA", "NAC", "SAS", "SSF", WORLD})
SNIPPET_MAX = 400


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
    snippet: str = ""
    snippet_locator: str = ""
    retrieved: str = ""
    snippet_missing: str = ""

    @property
    def key(self):
        return (self.quantity, self.age_band, self.sex, self.region)

    @property
    def region_kind(self):
        return "world" if self.region == WORLD else "region" if self.region in WB_REGIONS else "country"


def validate(p, field_ids=None):
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
    if p.snippet:
        if len(p.snippet) > SNIPPET_MAX:
            raise CalibrationError(f"{p.quantity}: snippet longer than {SNIPPET_MAX} characters (a quotation, not a page)")
        if not p.snippet_locator.strip() or not p.retrieved.strip():
            raise CalibrationError(f"{p.quantity}: a snippet needs snippet_locator and retrieved")
    else:
        if not p.snippet_missing.strip():
            raise CalibrationError(f"{p.quantity}: no snippet and no snippet_missing reason")
        if p.confidence != "low":
            raise CalibrationError(f"{p.quantity}: a Param without a source snippet has confidence low")
    return p


class Table:
    def __init__(self, params, field_ids=None):
        self.params = list(params)
        seen = {}
        for p in self.params:
            validate(p, field_ids)
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
            p = self.get(quantity, age_band, sex, sub)
            if p is None and sex != "all":
                p = self.get(quantity, age_band, "all", sub)
            if p is not None:
                if kind != "exact":
                    self._degrade(step, quantity, region, sub, f"no {quantity} {age_band} {sex} for {region}")
                return p
        self._degrade(step, quantity, region, "none", f"no {quantity} {age_band} {sex} at any level for {region}")
        return None

    def _degrade(self, step, quantity, region, substitute, reason):
        self.degraded.append({"step": step, "mechanism": quantity, "region": region, "substitute": substitute, "reason": reason})
        kind = (quantity, substitute if substitute in ("none", WORLD) else "region")
        if kind not in self._warned:
            self._warned.add(kind)
            warnings.warn(f"degraded: {quantity} for {region} substituted by {substitute} ({reason})", stacklevel=3)


def load_params(directory=CAL_DIR):
    out = []
    for f in sorted(Path(directory).glob("*.jsonl")):
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
