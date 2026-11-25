"""Interactive viewer (lifeimage/render/interactive.py): outcomes the viewer files must provide.

Acceptance: disclosure decides what is in the file; a zoom path reaches an evidence row; a group is the re-saturated
sum of its members; a comparison splits overlap from difference; files are deterministic and small.
Adversarial: undisclosed text is absent from the bytes (not hidden by script or style), markup in row text cannot
break out of the page, malformed specs are refused.
"""
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
from functools import lru_cache
from pathlib import Path

import pytest

from lifeimage import levels as lv
from lifeimage.render import interactive as it

ROOT = Path(__file__).resolve().parent.parent
PERSONA = "p023"  # researcher, 129 rows
TEAM = ["p023", "p019", "p033", "p008"]  # researcher, small business owner, career changer, shift worker
CHROME = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")


@lru_cache(maxsize=1)
def ctx():
    return it.context()


def html_of(spec, disclosure):
    return it.build_viewer(spec, ctx(), disclosure)


def model_of(html):
    m = re.search(r'<script id="data" type="application/json">(.*?)</script>', html, re.S)
    assert m, "no embedded data block"
    return json.loads(m.group(1))


@lru_cache(maxsize=None)
def single(disclosure, pid=PERSONA):
    return html_of(it.spec_single(ctx(), pid), disclosure)


def texts_of_entity(pid):
    """Every string a `none` file must not carry: domain ids and labels, row reasons, sources, the entity's name."""
    c = ctx()
    spec = it.spec_single(c, pid)
    out = {spec["members"][0]["name"]}
    out |= {card["label"] for card in c["cards"]} | {card["id"] for card in c["cards"]}
    for row in spec["members"][0]["rows"]:
        out |= {row["reason"], row["provenance"]["source"]}
    return {s for s in out if len(s) > 3}


# ---------- disclosure ----------

def test_none_file_carries_no_label_id_row_text_or_name():
    h = single("none")
    # the page's own code and styles are shared by every file and contain short words that are also labels (fine labels such as
    # "order" or "port"), so the leak check reads what the file carries as data: the model block, the title and the header
    head = " ".join(re.findall(r"<title>(.*?)</title>", h, re.S) + re.findall(r"<h1>(.*?)</h1>", h, re.S))
    carried = head + re.search(r'<script id="data" type="application/json">(.*?)</script>', h, re.S).group(1)
    leaked = sorted(s for s in texts_of_entity(PERSONA) if s in carried)
    assert leaked == [], f"undisclosed text in the none file: {leaked[:5]}"
    m = model_of(h)
    assert m["zoom"] is False and m["disclosure"] == "none"
    assert "rows" not in m and "fine" not in m
    assert all(set(s) <= {"r", "a", "w", "i0", "i1"} for s in m["slices"]), "none slices carry more than geometry"
    assert any(m["views"][0]["lv"].values()), "the pattern itself must still be drawn"


def test_none_file_has_no_zoom_or_pan_wiring():
    h = single("none")
    assert "addEventListener('wheel'" not in h and "pointerdown" not in h and "keydown" not in h


def test_summary_file_has_labels_and_levels_but_no_row_text():
    h = single("summary")
    m = model_of(h)
    labelled = [s for s in m["slices"] if s.get("l")]
    assert len(labelled) == len(m["slices"]) and m["zoom"] is True
    reasons = {r["reason"] for r in it.spec_single(ctx(), PERSONA)["members"][0]["rows"]}
    assert [s for s in reasons | {"ev:" + PERSONA} if len(s) > 3 and s in h] == []
    assert "rows" not in m
    assert "diary:" not in h and "resume:" not in h  # provenance sources are row detail


def test_full_file_carries_row_reports_for_domains_with_evidence():
    m = model_of(single("full"))
    assert m["rows"], "full disclosure carries rows"
    one = next(iter(m["rows"].values()))[0]
    assert {"t", "k", "d", "c", "v", "s"} <= set(one)


def test_unknown_disclosure_is_refused():
    with pytest.raises(ValueError):
        html_of(it.spec_single(ctx(), PERSONA), "everything")


# ---------- zoom path ----------

def test_zoom_path_reaches_a_row_for_a_domain_with_evidence():
    m = model_of(single("full"))
    path = it.zoom_path(m, next(k for k in m["rows"] if m["slices"][int(k)]["r"] == 1))
    assert [p["depth"] for p in path] == [0, 1, 2, 4, 5]  # disc, sector, field, evidence, row (a field has no fine step)
    assert path[1]["slice"]["r"] == 0 and path[2]["slice"]["r"] == 1
    row = path[4]["row"]
    for key in ("t", "k", "d", "c", "v"):
        assert row[key], f"row report lacks {key}"
    assert row["k"] in ("claimed", "attested", "measured") and row["t"].strip() and "\n" not in row["t"]


def test_zoom_path_stops_at_the_field_when_rows_are_not_disclosed():
    m = model_of(single("summary"))
    field = next(i for i, s in enumerate(m["slices"]) if s["r"] == 1 and m["views"][0]["lv"].get(str(i)))
    assert [p["depth"] for p in it.zoom_path(m, str(field))] == [0, 1, 2]


def test_zoom_path_refused_for_none():
    m = model_of(single("none"))
    with pytest.raises(ValueError):
        it.zoom_path(m, "0")


def test_row_contributions_sum_to_the_domains_level():
    m = model_of(single("full"))
    view = m["views"][0]["lv"]
    checked = 0
    for idx, rows in m["rows"].items():
        lvl = view[idx]
        for ch, k in (("red", 0), ("green", 1), ("blue", 2)):
            got = math.fsum(r["v"].get(ch, 0.0) for r in rows)
            assert got == pytest.approx(lvl[k], abs=2e-3), (idx, ch)
        assert math.fsum(r["v"].get("grain", 0.0) for r in rows) == pytest.approx(lvl[4], abs=2e-3)
        checked += 1
    assert checked >= 5


def test_a_row_with_the_most_evidence_is_reachable_for_every_kind_of_entity():
    for spec in (it.spec_single(ctx(), "o005"), it.spec_single(ctx(), "marie-curie")):
        m = model_of(html_of(spec, "full"))
        assert m["rows"] and all(r["t"] for rows in m["rows"].values() for r in rows)


# ---------- sets ----------

def raw_levels(spec):
    gov = lv.DEFAULT
    total = it.sum_raw([lv.raw_sums(r["rows"], ctx()["cards"], gov, r["asof"]) for r in spec["members"]])
    return it.levels_from_raw(total, gov)


def test_group_levels_equal_the_resaturated_sum_of_members():
    spec = it.spec_group(ctx(), TEAM, "Team")
    m = model_of(html_of(spec, "summary"))
    gov = lv.DEFAULT
    members = [lv.raw_sums(x["rows"], ctx()["cards"], gov, x["asof"]) for x in spec["members"]]
    shared = 0
    for idx, lvl in m["views"][0]["lv"].items():
        d = m["slices"][int(idx)]["id"]
        for ch, k in (("red", 0), ("green", 1), ("blue", 2)):
            s = math.fsum(r["solid"].get(d, {}).get(ch, 0.0) for r in members)
            assert lvl[k] == pytest.approx(lv.tone(s, gov), abs=1e-3)
            parts = [lv.tone(r["solid"].get(d, {}).get(ch, 0.0), gov) for r in members]
            assert lvl[k] == pytest.approx(1 - math.prod(1 - p for p in parts), abs=1e-3)  # exposures compose
            assert lvl[k] <= 1.0
        shared += sum(1 for r in members if any(r["solid"].get(d, {}).values())) > 1
    assert shared > 0, "the team must overlap somewhere for this test to say anything"


def test_group_is_not_the_plain_sum_of_levels_and_never_exceeds_one():
    spec = it.spec_group(ctx(), TEAM, "Team")
    m = model_of(html_of(spec, "summary"))
    singles = [it.analyse(ctx(), x)["levels"] for x in spec["members"]]
    over = 0
    for idx, lvl in m["views"][0]["lv"].items():
        d = m["slices"][int(idx)]["id"]
        for ch, k in (("red", 0), ("green", 1), ("blue", 2)):
            plain = math.fsum(s["solid"].get(d, {}).get(ch, 0.0) for s in singles)
            assert lvl[k] <= 1.0
            over += plain > 1.0 and lvl[k] < 1.0
    assert over > 0, "somewhere the plain sum exceeds 1 while the group stays below it"


def test_group_file_lets_the_viewer_resaturate_selected_members():
    m = model_of(html_of(it.spec_group(ctx(), TEAM, "Team"), "summary"))
    assert len(m["members"]) == 4 and m["tone_k"] == pytest.approx(lv.DEFAULT.tone_k)
    total = {}
    for mem in m["members"]:
        for idx, v in mem["raw"].items():
            acc = total.setdefault(idx, [0.0] * 4)
            for i in range(4):
                acc[i] += v[i]
    for idx, lvl in m["views"][0]["lv"].items():
        assert lvl[0] == pytest.approx(lv.tone(total[idx][0]), abs=1e-3)
        assert lvl[1] == pytest.approx(lv.tone(total[idx][1]), abs=1e-3)


def test_group_of_nobody_is_refused():
    with pytest.raises(ValueError):
        it.spec_group(ctx(), [], "Empty")


def test_compare_overlap_and_difference_partition_each_image():
    spec = it.spec_compare(ctx(), "p012", "p023")
    m = model_of(html_of(spec, "summary"))
    views = {v["id"]: v["lv"] for v in m["views"]}
    assert set(views) == {"a", "b", "overlap", "a_only", "b_only"}
    seen_a_only = seen_overlap = False
    for idx in set(views["a"]) | set(views["b"]):
        a = views["a"].get(idx, [0] * 5)
        b = views["b"].get(idx, [0] * 5)
        ov = views["overlap"].get(idx, [0] * 5)
        ao = views["a_only"].get(idx, [0] * 5)
        bo = views["b_only"].get(idx, [0] * 5)
        for k in range(3):
            assert ov[k] == pytest.approx(min(a[k], b[k]), abs=2e-4)
            assert ov[k] + ao[k] == pytest.approx(a[k], abs=3e-4)
            assert ov[k] + bo[k] == pytest.approx(b[k], abs=3e-4)
            assert ao[k] == 0 or bo[k] == 0
        seen_a_only |= any(ao[:3])
        seen_overlap |= any(ov[:3])
    assert seen_a_only and seen_overlap


def test_comparing_an_image_with_itself_has_no_difference():
    spec = it.spec_compare(ctx(), PERSONA, PERSONA)
    m = model_of(html_of(spec, "summary"))
    views = {v["id"]: v["lv"] for v in m["views"]}
    assert not any(any(v[:3]) for v in views["a_only"].values()) and not any(any(v[:3]) for v in views["b_only"].values())
    assert views["overlap"] == views["a"]


# ---------- robustness ----------

def test_markup_in_row_text_cannot_leave_the_data_block():
    spec = it.spec_single(ctx(), PERSONA)
    spec["members"][0]["rows"][0]["reason"] = "</script><img src=x onerror=alert(1)> &  "
    h = html_of(spec, "full")
    assert h.count("</script>") == h.count("<script"), "a row broke out of its script block"
    assert "<img src=x" not in h
    assert model_of(h)  # still parses


def test_files_are_deterministic():
    a = it.build_all(ctx())
    b = it.build_all(ctx())
    assert a.keys() == b.keys() and all(a[k] == b[k] for k in a)


def test_every_file_is_self_contained_and_under_two_megabytes():
    files = it.build_all(ctx())
    assert len(files) == 10  # 5 at full, the same persona at none and summary, group, comparison, index
    for name, h in files.items():
        assert len(h.encode()) < 2_000_000, name
        assert not re.search(r"(src|href)\s*=\s*[\"'](https?:)?//", h), f"{name} reaches for the network"
        assert "<script src" not in h and "@import" not in h and "url(http" not in h


def test_expected_outputs_exist_with_their_disclosure():
    files = it.build_all(ctx())
    full = [n for n, h in files.items() if n != "index.html" and model_of(h)["disclosure"] == "full"]
    assert len(full) == 5
    kinds = {model_of(h)["kind"] for n, h in files.items() if n != "index.html"}
    assert kinds == {"single", "group", "compare"}
    assert sum(1 for n in files if n.endswith("-none.html")) == 1 and sum(1 for n in files if n.endswith("-summary.html")) == 1
    assert "index.html" in files


# ---------- the live viewer (headless Chrome; skipped without a browser) ----------

def run_selftest(path):
    out = subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--virtual-time-budget=4000",
                          "--dump-dom", f"file://{path}#selftest"], capture_output=True, text=True, timeout=90).stdout
    m = re.search(r'<pre id="selftest">(.*?)</pre>', out, re.S)
    assert m, out[-400:]
    return json.loads(m.group(1).replace("&quot;", '"').replace("&amp;", "&"))


@pytest.mark.skipif(CHROME is None, reason="no headless browser")
@pytest.mark.parametrize("disclosure", ["none", "summary", "full"])
def test_viewer_runs_and_obeys_its_disclosure_in_a_browser(disclosure, tmp_path):
    p = tmp_path / f"v-{disclosure}.html"
    p.write_text(single(disclosure), encoding="utf-8")
    r = run_selftest(p)
    assert r["errors"] == [], r
    assert r["wedges"] > 200
    if disclosure == "none":
        assert r["zoomed"] is False and r["labels"] == 0 and r["panel"] is False
    else:
        # full reaches a row (5); summary stops at the field (2) or, when its best field has fine children, at a fine domain (3)
        assert r["zoomed"] is True and (r["maxDepth"] == 5 if disclosure == "full" else r["maxDepth"] in (2, 3)), r
        assert r["labelsAtDisc"] > 0 and r["wheelChangedScale"] is True
    if disclosure == "full":
        assert r["rowShown"] and r["rowFields"] >= 5
        assert r["keyboardReachedRow"] is True


@pytest.mark.skipif(CHROME is None, reason="no headless browser")
def test_group_and_compare_viewers_switch_in_a_browser(tmp_path):
    g = tmp_path / "g.html"
    g.write_text(html_of(it.spec_group(ctx(), TEAM, "Team"), "summary"), encoding="utf-8")
    rg = run_selftest(g)
    assert rg["errors"] == [] and rg["groupMatches"] is True and rg["groupTogglesChange"] is True, rg
    c = tmp_path / "c.html"
    c.write_text(html_of(it.spec_compare(ctx(), "p012", "p023"), "summary"), encoding="utf-8")
    rc = run_selftest(c)
    assert rc["errors"] == [] and rc["views"] == 5 and rc["viewsDiffer"] is True, rc


@pytest.mark.skipif(CHROME is None, reason="no headless browser")
@pytest.mark.parametrize("downs,what", [(2, "the field wedge"), (4, "the wedge around a row")])
def test_zoomed_view_paints_the_domain_it_zoomed_to(downs, what, tmp_path):
    Image = pytest.importorskip("PIL.Image")
    inject = ("<script>var st=window.__li.svg;function key(k){st.dispatchEvent(new KeyboardEvent('keydown',{key:k,bubbles:true}))};"
              + "key('ArrowDown');" * downs + "</script></body>")
    p = tmp_path / "z.html"
    p.write_text(single("full").replace("</body>", inject), encoding="utf-8")
    shot = tmp_path / "z.png"
    subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--force-prefers-reduced-motion", "--window-size=1200,800",
                    "--virtual-time-budget=3000", f"--screenshot={shot}", f"file://{p}"], capture_output=True, timeout=90)
    im = Image.open(shot).convert("RGB")
    px = [im.getpixel((x, y)) for x in range(380, 460, 10) for y in range(420, 500, 10)]
    lit = sum(1 for c in px if max(c) > 60)
    assert lit >= len(px) // 2, f"{what} is not painted at the centre of the zoomed view ({lit} of {len(px)} samples lit)"


# ---------- the tool ----------

def test_tool_writes_the_outputs(tmp_path):
    r = subprocess.run([sys.executable, str(ROOT / "tools/render_interactive.py"), "--out", str(tmp_path)],
                       capture_output=True, text=True, cwd=ROOT)
    assert r.returncode == 0, r.stderr
    names = sorted(p.name for p in tmp_path.glob("*.html"))
    assert "index.html" in names and len(names) == 10
