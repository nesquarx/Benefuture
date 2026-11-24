"""Scoring of the extract task against the synthetic ground truth, per image channel.

The three channels are views over rows: expertise is the form and content memberships of positive rows, impact the
outcome memberships of positive rows, potential every membership of prediction rows (a self-assessed level). Truth rows
come from the resume, the self-description or the diary; only resume rows are recoverable from a resume, so recall is
reported against them (`recall`) and against all truth (`recall_all`), and `coverage_gap` is the share of truth rows
in the channel with no resume evidence. A resume states no self-assessment, so the potential channel has nothing to
recall from it.

Per channel, over (persona, span, domain) units:
- precision, recall: exact domain; `precision_near`, `recall_near`: a domain within one upstream link (the same, a
  direct upstream of it, or one it is upstream of) of a truth domain on the same line also counts. None when the
  denominator is empty.
- magnitude_mae, magnitude_bias: an extracted row is matched to a truth resume row of the same line sharing a domain
  (best Jaccard); error is extracted minus truth magnitude.
- inflation, expertise and impact: the matched row's extracted size against the corroborated size of the same event
  (the mean of its attested and measured rows' magnitudes), relative, averaged over matches, overall and per
  persona calibration (over, under, well). Claimed truth carries the persona's bias, so a reader that copies the text
  inherits it. Potential: the extracted prediction row's magnitude minus the persona's latent expertise (form and
  content memberships) or impact (outcome memberships) for the domain, absolute, on the same 0 to 1 scale.
- projection_corr, projection_corr_all: Pearson correlation, per persona over the union of domains (at least 3), of the
  channel's projected per-domain totals (`projection.project`) between extraction and truth (resume rows; all rows),
  averaged over personas with truth in the channel; a persona whose extraction is constant scores 0.
"""
import gzip
import json
import math
from collections import defaultdict
from pathlib import Path

from .projection import project

CHANNELS = ("expertise", "impact", "potential")
_RELS = {"expertise": {"form", "content"}, "impact": {"outcome"}}
_CALIBRATIONS = ("over", "under", "well")
_MIN_DOMAINS = 3
_ALL_RELS = frozenset({"form", "content", "outcome", "setting"})


def view(row, channel):
    """The memberships of a row that count in the channel (none when the row is not in it)."""
    if channel == "potential":
        return list(row["memberships"]) if row["channel"] == "prediction" else []
    return [m for m in row["memberships"] if m["rel"] in _RELS[channel]] if row["channel"] == "positive" else []


def is_resume(row):
    return row["provenance"]["source"].startswith("resume:")


def span(row):
    return row["provenance"]["span"]


def _mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else None


def _ratio(a, b):
    return a / b if b else None


def _pearson(x, y):
    mx, my = sum(x) / len(x), sum(y) / len(y)
    sxx, syy = sum((a - mx) ** 2 for a in x), sum((b - my) ** 2 for b in y)
    if sxx < 1e-12 or syy < 1e-12:
        return 0.0
    return sum((a - mx) * (b - my) for a, b in zip(x, y)) / math.sqrt(sxx * syy)


def _near_fn(cards):
    up = {c["id"]: {l["id"] for l in c["links"] if l["rel"] == "upstream"} for c in cards}
    return lambda a, b: a == b or b in up.get(a, ()) or a in up.get(b, ())


def _by_line(rows, channel):
    """{(pid, span): [(row, domains)]} of the rows with memberships in the channel."""
    out = defaultdict(list)
    for pid, per in rows.items():
        for r in per:
            ds = {m["domain"] for m in view(r, channel)}
            if ds:
                out[(pid, span(r))].append((r, ds))
    return out


def _projected(rows, channel, known):
    pseudo = []
    for pid, per in rows.items():
        for r in per:
            ms = [m for m in view(r, channel) if m["domain"] in known]
            if ms:
                pseudo.append({"entity": pid, "relation": r["relation"], "memberships": ms, "channel": channel, "sign": r["sign"],
                               "magnitude": r["magnitude"], "revoked": r.get("revoked", False)})
    return pseudo


def _vectors(rows, channel, cards, known):
    proj = project(_projected(rows, channel, known), cards, membership_rels=_ALL_RELS)
    return {pid: {d: ch[channel] for d, ch in doms.items() if channel in ch} for pid, doms in proj.items()}


def _projection_corr(pred, truth, channel, cards, known):
    pv, tv = _vectors(pred, channel, cards, known), _vectors(truth, channel, cards, known)
    scores = []
    for pid, t in tv.items():
        p = pv.get(pid, {})
        dom = sorted(set(t) | set(p))
        if len(dom) >= _MIN_DOMAINS:
            scores.append(_pearson([p.get(d, 0.0) for d in dom], [t.get(d, 0.0) for d in dom]))
    return _mean(scores), len(scores)


def _inflation(pairs, personas):
    """pairs: [(pid, value)] -> {overall, over, under, well, n}."""
    by = defaultdict(list)
    for pid, v in pairs:
        by[personas[pid]["calibration"]].append(v)
    out = {"overall": _mean(v for vs in by.values() for v in vs), "n": sum(map(len, by.values()))}
    out.update({c: _mean(by[c]) for c in _CALIBRATIONS})
    return out


def compute(extracted, truth, personas, cards, corroborated=None):
    """The scores of one extraction: extracted and truth are {persona id: [evidence rows]}; personas {id: persona};
    corroborated {(persona id, span): event size}; see the module docstring."""
    corroborated = corroborated or {}
    near = _near_fn(cards)
    known = {c["id"] for c in cards}
    pids = sorted(truth)
    ext = {p: extracted.get(p, []) for p in pids}
    truth_resume = {p: [r for r in truth[p] if is_resume(r)] for p in pids}
    report = {"personas": len(pids), "channels": {},
              "rows": {"extracted": sum(map(len, ext.values())), "truth_resume": sum(map(len, truth_resume.values())),
                       "truth_all": sum(map(len, truth.values()))}}
    for c in CHANNELS:
        tl, pl, al = _by_line(truth_resume, c), _by_line(ext, c), _by_line(truth, c)
        units = lambda lines: {(pid, sp, d) for (pid, sp), rs in lines.items() for _r, ds in rs for d in ds}
        T, P = units(tl), units(pl)
        all_units = {(pid, r["provenance"]["source"], sp, d) for (pid, sp), rs in al.items() for r, ds in rs for d in ds}
        hit = T & P
        line_domains = lambda lines: {k: set().union(*(ds for _r, ds in rs)) for k, rs in lines.items()}
        td, pd = line_domains(tl), line_domains(pl)
        p_near = sum(any(near(d, t) for t in td.get((pid, sp), ())) for pid, sp, d in P)
        t_near = sum(any(near(d, p) for p in pd.get((pid, sp), ())) for pid, sp, d in T)
        truth_rows = sum(1 for lines in (al,) for rs in lines.values() for _r in rs)
        no_resume = sum(1 for rs in al.values() for r, _ds in rs if not is_resume(r))
        errs, infl = [], []
        for (pid, sp), rs in tl.items():
            for r, ds in rs:
                cands = [(len(ds & pds) / len(ds | pds), e) for e, pds in pl.get((pid, sp), ()) if ds & pds]
                if not cands:
                    continue
                e = max(cands, key=lambda x: x[0])[1]
                errs.append(e["magnitude"] - r["magnitude"])
                if c != "potential" and (pid, sp) in corroborated:
                    infl.append((pid, (e["magnitude"] - corroborated[(pid, sp)]) / corroborated[(pid, sp)]))
        if c == "potential":
            for pid, per in ext.items():
                latent = personas[pid].get("latent", {})
                seen = set()
                for r in per:
                    for m in view(r, c):
                        kind = "impact" if m["rel"] == "outcome" else "expertise"
                        if m["domain"] in latent and (id(r), m["domain"], kind) not in seen:
                            seen.add((id(r), m["domain"], kind))
                            infl.append((pid, r["magnitude"] - latent[m["domain"]][kind]))
        pc, pn = _projection_corr(ext, truth_resume, c, cards, known)
        pca, _ = _projection_corr(ext, truth, c, cards, known)
        report["channels"][c] = {
            "precision": _ratio(len(hit), len(P)), "recall": _ratio(len(hit), len(T)),
            "precision_near": _ratio(p_near, len(P)), "recall_near": _ratio(t_near, len(T)),
            "recall_all": _ratio(len(hit), len(all_units)), "coverage_gap": _ratio(no_resume, truth_rows),
            "magnitude_mae": _mean(abs(e) for e in errs), "magnitude_bias": _mean(errs), "matched": len(errs),
            "inflation": _inflation(infl, personas),
            "projection_corr": pc, "projection_corr_all": pca, "projection_personas": pn}
    return report


def _average(items):
    first = items[0]
    if isinstance(first, dict):
        return {k: _average([i[k] for i in items]) for k in first}
    vals = [i for i in items if i is not None]
    return sum(vals) / len(vals) if vals else None


def compute_variants(reports):
    """The mean of the variants' reports (undefined values ignored), with the reports under `per_variant`."""
    out = _average(list(reports))
    out["variants"] = len(reports)
    out["per_variant"] = list(reports)
    return out


def corroborated_magnitudes(rows, events):
    """{(persona id, span): mean magnitude of the attested and measured rows of the event a resume row claims}.
    rows, events: {entity: [...]}; events index into the entity's rows (file order), as the generators write them."""
    out = {}
    for entity, evs in events.items():
        mine = rows.get(entity, [])
        for ev in evs:
            claimed = [mine[i] for i, t in zip(ev["rows"], ev["tiers"]) if t == "claimed"]
            others = [mine[i]["magnitude"] for i, t in zip(ev["rows"], ev["tiers"]) if t != "claimed"]
            for r in claimed:
                if others and is_resume(r):
                    out[(entity.split(":", 1)[1], span(r))] = sum(others) / len(others)
    return out


def _jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def load_synthetic(root):
    """(personas {id: persona}, truth {id: rows}, resume texts {id: text}, corroborated sizes) of the synthetic persons."""
    root = Path(root)
    personas = {p["id"]: p for p in _jsonl(root / "personas.jsonl")}
    truth = {pid: _jsonl(root / "truth" / f"{pid}.jsonl") for pid in personas}
    texts = {pid: (root / "texts" / f"{pid}.resume.txt").read_text(encoding="utf-8") for pid in personas}
    rows, events = defaultdict(list), defaultdict(list)
    for r in _jsonl(root / "rows.jsonl"):
        rows[r["entity"]].append(r)
    with gzip.open(root / "events.jsonl.gz", "rt", encoding="utf-8") as f:
        for l in f:
            e = json.loads(l)
            events[e["entity"]].append(e)
    return personas, truth, texts, corroborated_magnitudes(rows, events)


def _f(x, pct=False):
    if x is None:
        return "n/a"
    return f"{x:.1%}" if pct else f"{x:+.3f}" if False else f"{x:.3f}"


def render(report):
    """A markdown report of compute_variants (or compute) output."""
    lines = [f"# Extraction scores ({report.get('variants', 1)} variants, {report['personas']} personas)", "",
             f"Rows: extracted {report['rows']['extracted']:.0f} (mean over variants), truth from the resume "
             f"{report['rows']['truth_resume']:.0f}, truth in all texts {report['rows']['truth_all']:.0f}.", ""]
    lines += ["| measure | " + " | ".join(CHANNELS) + " |", "|---|" + "---|" * len(CHANNELS)]
    ch = report["channels"]
    rows = [("precision (exact domain)", "precision"), ("recall of resume rows (exact)", "recall"),
            ("precision within one link", "precision_near"), ("recall within one link", "recall_near"),
            ("recall of all truth rows", "recall_all"), ("coverage gap: truth rows with no resume evidence", "coverage_gap"),
            ("magnitude mean absolute error", "magnitude_mae"), ("magnitude bias (extracted minus truth)", "magnitude_bias"),
            ("matched rows", "matched"), ("projected totals correlation, resume truth", "projection_corr"),
            ("projected totals correlation, all truth", "projection_corr_all")]
    for label, key in rows:
        lines.append(f"| {label} | " + " | ".join(_f(ch[c][key]) for c in CHANNELS) + " |")
    lines += ["", "Inflation (expertise, impact: relative to the corroborated size of the event; potential: absolute gap to the "
              "latent truth), by the persona's calibration:", "", "| channel | overall | over | under | well | n |", "|---|---|---|---|---|---|"]
    for c in CHANNELS:
        i = ch[c]["inflation"]
        lines.append(f"| {c} | " + " | ".join(_f(i[k]) for k in ("overall", "over", "under", "well")) + f" | {i['n']:.0f} |")
    pv = report.get("per_variant")
    if pv and len(pv) > 1:
        lines += ["", "Per variant (expertise): " + "; ".join(
            f"var{n} precision {_f(r['channels']['expertise']['precision'])}, recall {_f(r['channels']['expertise']['recall'])}"
            for n, r in enumerate(pv))]
    return "\n".join(lines) + "\n"
