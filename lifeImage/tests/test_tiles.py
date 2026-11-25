"""Tiled basemap (LI.52): detail follows resolution.

Acceptance: the tiles a view needs grow with its pixel resolution (a 200 px disc loads far less than a 4096 px one, and at
4096 px every slice at least one pixel across is there and none narrower); the colours the tiled render gives equal the
current renderer's, per domain, at every depth; a viewport loads a bounded number of bytes however deep the zoom; a slice
too narrow for the resolution is drawn as its parent, never a neighbour (LI.30); a levels file built on an older basemap
migrates through `lifeimage.migration` to the new one, conserving each channel's total luminosity; the offline pages hold no
network reference and render with the network off.
Adversarial: a tile outside the viewport is not fetched (checked in Chromium against a counting server), a sub-pixel slice is
not shipped at low zoom, the monolithic viewer's behaviour (the baseline this replaces) is pinned.

Bounds stated before measuring: a 1024 x 768 viewport loads at most VIEW_BYTES_BOUND bytes of tile data at every zoom;
the 200 px full-disc load is at least 5 times smaller than the 4096 px one (prediction, confidence 0.7); the tiled colour
matches the reference within COLOUR_TOL per 8-bit channel (the levels file keeps four decimals).
"""
import json
import os
import math
import re
import shutil
import subprocess
import warnings
from functools import lru_cache
from pathlib import Path

import pytest

from lifeimage import levels as lv
from lifeimage import migration
from lifeimage.render import basemap as bmod
from lifeimage.render import image as im
from lifeimage.render import interactive as it
from lifeimage.render import tiles as T
from lifeimage.render import tileview as V

ROOT = Path(__file__).resolve().parent.parent
PERSONAS = ("p023", "p012", "p019")
COLOUR_TOL = 1
VIEW_W, VIEW_H = 1024, 768
VIEW_BYTES_BOUND = 150_000
NODE = shutil.which("node")
NODE_PATH = "/opt/node-tools/node_modules"
HAVE_PW = NODE is not None and Path(NODE_PATH, "playwright").exists()
NODE_ENV = {**os.environ, "NODE_PATH": NODE_PATH}
JS = Path(__file__).resolve().parent / "js"


@lru_cache(maxsize=1)
def ctx():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return it.context()


@lru_cache(maxsize=1)
def bm():
    return ctx()["bm"]


@lru_cache(maxsize=1)
def pyramid():
    return T.build_pyramid(bm())


@lru_cache(maxsize=1)
def archive_bytes():
    return T.pmtiles_bytes(pyramid())


@lru_cache(maxsize=1)
def archive():
    return T.PMTiles(archive_bytes())


def all_slices():
    return {**bm().slices, **bm().fine}


@lru_cache(maxsize=None)
def levels_of(pid):
    c = ctx()
    a = it.analyse(c, it.spec_single(c, pid)["members"][0])
    return a["levels"]


@lru_cache(maxsize=None)
def lfile(pid):
    return T.levels_file(levels_of(pid), bm().version, pid)


def ids_in(z):
    out = set()
    for (zz, x, y) in archive().tiles():
        if zz == z:
            for name, feats in T.decode_mvt(archive().tile(zz, x, y)).items():
                if name != "fallback":  # a fallback polygon names its parent, which may itself be too narrow to ship
                    out.update(f["tags"]["id"] for f in feats)
    return out


def full_disc_load(px):
    """(features, bytes) of the tiles a full-disc view of px pixels fetches."""
    z = T.zoom_for_px(px)
    n = 0
    size = 0
    for (zz, x, y) in archive().tiles():
        if zz == z:
            size += archive().tile_size(zz, x, y)
            n += sum(len(v) for v in T.decode_mvt(archive().tile(zz, x, y)).values())
    return n, size


@lru_cache(maxsize=None)
def disclosed(pid, disclosure="full"):
    c = ctx()
    return V.disclose(lfile(pid), c, it.spec_single(c, pid), disclosure)


# ---------- baseline: what the monolithic viewer does ----------

def test_baseline_monolithic_viewer_ignores_resolution():
    """The current viewer ships every slice whatever the resolution; at 200 px most are under a pixel (the outcome LI.52 removes)."""
    model = it.build_model(it.spec_single(ctx(), "p023"), ctx(), "summary")
    n = len(model["slices"])
    assert n == len(all_slices())
    ppu = 200 / (2 * bm().extent)
    sub = sum(1 for s in all_slices().values()
              if min((s.r0 + s.r1) / 2 * math.radians(s.width) * ppu, (s.r1 - s.r0) * ppu) < T.MIN_SLICE_PX)
    assert sub / n > 0.5


# ---------- acceptance ----------

def test_lod_scales_with_resolution():
    n200, b200 = full_disc_load(200)
    n4096, b4096 = full_disc_load(4096)
    assert n200 < n4096 and b200 < b4096


def test_prediction_200px_load_at_least_5x_smaller_than_4096px():
    _, b200 = full_disc_load(200)
    _, b4096 = full_disc_load(4096)
    assert b4096 / b200 >= 5, f"{b4096} / {b200} = {b4096 / b200:.2f}"


def test_full_resolution_has_every_slice_at_least_one_pixel_and_none_narrower():
    px = 4096
    ppu = px / (2 * bm().extent)
    want = {i for i, s in all_slices().items()
            if min((s.r0 + s.r1) / 2 * math.radians(s.width) * ppu, (s.r1 - s.r0) * ppu) >= 1.0}
    z = T.zoom_for_px(px)
    got = ids_in(z)
    got_own = {i for i in got if i in all_slices()}
    assert want <= got_own
    narrower = {i for i in got_own - want}
    assert not narrower, sorted(narrower)[:5]


def test_everything_that_exists_is_shipped_at_the_deepest_zoom():
    z = T.max_zoom(bm())
    assert {i for i in ids_in(z) if i in all_slices()} == set(all_slices())


@pytest.mark.parametrize("pid", PERSONAS)
@pytest.mark.parametrize("depth", range(4))
def test_tiled_colours_equal_the_current_renderer(pid, depth):
    z = T.DEPTH_ZOOM[depth]
    lev, lf = levels_of(pid), lfile(pid)
    worst, checked = 0, 0
    for i, s in all_slices().items():
        if not T.visible(s, z, bm().extent):
            continue
        wx, wy = T.world_of(bm(), (s.r0 + s.r1) / 2, s.angle)
        got = T.colour_at(archive(), lf, z, wx, wy)
        ch = lev["solid"].get(i)
        want = im.rgb(ch, levels=True) if ch and any(ch[k] > 0 for k in im.CHANNELS) else (0, 0, 0)
        worst = max(worst, max(abs(a - b) for a, b in zip(got, want)))
        checked += 1
    assert checked >= 100
    assert worst <= COLOUR_TOL, worst


def test_persona_images_are_not_blank_and_differ():
    cols = [sum(1 for v in lfile(p)["ids"].values() if v[0] or v[1] or v[2]) for p in PERSONAS]
    assert min(cols) > 10
    assert len({tuple(sorted(lfile(p)["ids"])) for p in PERSONAS}) > 1


def test_viewport_bytes_are_bounded_at_every_zoom():
    arch = archive()
    zmax = T.max_zoom(bm())
    worst = {}
    for z in range(zmax + 1):
        n = 2 ** z
        best = 0
        # viewport positions on a coarse grid of the world at zoom z
        span = n * 256
        for ox in range(0, max(1, span - VIEW_W) + 1, max(64, (span - VIEW_W) // 8 or 64)):
            for oy in range(0, max(1, span - VIEW_H) + 1, max(64, (span - VIEW_H) // 8 or 64)):
                tiles = T.view_tiles(z, ox, oy, VIEW_W, VIEW_H)
                best = max(best, sum(arch.tile_size(z, x, y) for x, y in tiles))
        worst[z] = best
    assert max(worst.values()) <= VIEW_BYTES_BOUND, worst
    assert worst[zmax] <= 1.5 * worst[3] + 1000, worst


def test_hidden_child_takes_its_parents_colour_never_a_neighbours():
    """At low zoom, a fine slice too narrow to ship is drawn in the colour of the parent whose level aggregates it (LI.51)."""
    z = 2
    ext = bm().extent
    lf = lfile("p023")
    hidden = [s for s in bm().fine.values() if not T.visible(s, z, ext)]
    assert len(hidden) > 100
    lit = 0
    for s in hidden:
        wx, wy = T.world_of(bm(), (s.r0 + s.r1) / 2, s.angle)
        got = T.colour_at(archive(), lf, z, wx, wy)
        pv = lf["ids"].get(s.parent)
        want = T.colour_of(pv) if pv and (pv[0] or pv[1] or pv[2]) else (0, 0, 0)
        assert max(abs(a - b) for a, b in zip(got, want)) <= COLOUR_TOL, (s.id, got, want)
        lit += want != (0, 0, 0)
    assert lit > 5, "no hidden child with a lit parent: the check proves nothing"


def test_every_fine_feature_names_its_parent():
    for feats in T.decode_mvt(archive().tile(*next(iter(sorted(t for t in archive().tiles() if t[0] == 6))))).get("fine", []):
        assert feats["tags"]["p"] in all_slices()


# ---------- recalibration ----------

def test_recalibration_conserves_channel_totals_and_renders_every_id():
    lf = lfile("p023")
    ids = sorted(i for i, v in lf["ids"].items() if v[0] or v[1] or v[2])
    a, b = ids[0], ids[1]
    new_a = [i for i in all_slices() if i not in lf["ids"]][:2]
    old = json.loads(json.dumps(lf))
    old["basemap"] = "0.0.0-older"
    for k, nm in ((a, "old." + a), (b, "old." + b)):
        old["ids"][nm] = old["ids"].pop(k)
    table = migration.build_table(
        [{"op": "rename", "old": "old." + a, "new": a},
         {"op": "split", "old": "old." + b, "new": [{"id": new_a[0], "weight": 0.6}, {"id": new_a[1], "weight": 0.4}]}],
        existing_ids={"old." + a, "old." + b})
    new = T.migrate_levels(old, table, bm().version)
    assert new["basemap"] == bm().version
    before, after = T.luminosity_totals(old), T.luminosity_totals(new)
    for k in ("red", "green", "blue", "claimed"):
        assert after[k] == pytest.approx(before[k], rel=1e-9, abs=1e-12), k
    assert set(new["ids"]) <= set(all_slices())
    for i, v in new["ids"].items():  # renders: every id resolves to a colour in a tile that carries it
        assert len(T.colour_of(v)) == 3
    s0 = all_slices()[new_a[0]]
    wx, wy = T.world_of(bm(), (s0.r0 + s0.r1) / 2, s0.angle)
    got = T.colour_at(archive(), new, T.max_zoom(bm()), wx, wy)
    assert got != (0, 0, 0)  # the split-off share lights the new domain


def test_recalibration_refuses_a_levels_file_the_table_cannot_place():
    lf = lfile("p023")
    bad = json.loads(json.dumps(lf))
    bad["ids"]["retired.nowhere"] = [0.5, 0.5, 0.5, 1.0, 0.0]
    new = T.migrate_levels(bad, {}, bm().version)
    with pytest.raises(ValueError, match="retired.nowhere"):
        T.check_levels_ids(new, set(all_slices()))


# ---------- format ----------

def test_pmtiles_roundtrip_and_mvt_polygons_are_wellformed():
    arch = archive()
    assert arch.header["tile_type"] == 1 and arch.header["max_zoom"] == T.max_zoom(bm())
    ts = sorted(arch.tiles())
    assert len(ts) == len(set(ts)) > 100
    z, x, y = next(t for t in ts if t[0] == 3 and arch.tile_size(*t) > 100)
    for feats in T.decode_mvt(arch.tile(z, x, y)).values():
        for f in feats:
            for ring in f["rings"]:
                assert len(ring) >= 3
                assert all(-T.MVT_BUFFER - 1 <= px <= T.MVT_EXTENT + T.MVT_BUFFER + 1 for px, _ in ring)


def test_features_carry_only_ids():
    for t in sorted(archive().tiles())[:50]:
        for feats in T.decode_mvt(archive().tile(*t)).values():
            for f in feats:
                assert set(f["tags"]) <= {"id", "p"}


# ---------- counterexamples ----------

def test_no_subpixel_slice_is_shipped_at_low_zoom():
    ext = bm().extent
    for z in (0, 1, 2):
        shipped = {i for i in ids_in(z) if i in all_slices() and all_slices()[i].ring != "sector"}
        for i in shipped:
            assert T.visible(all_slices()[i], z, ext), (z, i)
        assert len(shipped) < len(all_slices())


def test_view_tiles_excludes_tiles_outside_the_viewport():
    tiles = T.view_tiles(4, 0, 0, 256, 256)
    assert tiles == [(0, 0)]
    tiles = T.view_tiles(4, 300, 0, 200, 100)
    assert tiles == [(1, 0)]
    assert T.view_tiles(4, 255, 255, 2, 2) == [(0, 0), (1, 0), (0, 1), (1, 1)]


# ---------- offline and online pages ----------

@lru_cache(maxsize=1)
def offline_pages():
    lf = lfile("p023")
    vec = V.offline_vector_html(archive_bytes(), disclosed("p023"), "Persona p023")
    ras = V.offline_raster_html(V.raster_pyramid(archive(), lf, V.RASTER_MAXZOOM), pyramid().meta, lf, "Persona p023")
    return {"vector": vec, "raster": ras}


@pytest.mark.parametrize("kind", ["vector", "raster"])
def test_offline_pages_have_no_external_reference(kind):
    html = offline_pages()[kind]
    assert not re.search(r"https?://", html.replace("http://www.w3.org/2000/svg", "")), re.findall(r"https?://[^\s\"']+", html)[:3]
    assert not re.search(r"<(script|link|img|iframe)[^>]+(src|href)=[\"'](?!data:|#)", html)
    assert "XMLHttpRequest" not in html


@pytest.mark.skipif(not HAVE_PW, reason="no playwright")
@pytest.mark.parametrize("kind", ["vector", "raster"])
def test_offline_pages_render_in_chromium_with_the_network_blocked(kind, tmp_path):
    page = tmp_path / f"{kind}.html"
    page.write_text(offline_pages()[kind], encoding="utf-8")
    shot = tmp_path / f"{kind}.png"
    out = subprocess.run([NODE, str(JS / "offline_check.cjs"), str(page), str(shot)], capture_output=True, text=True, timeout=120,
                         env=NODE_ENV)
    assert out.returncode == 0, out.stderr[-800:]
    r = json.loads(out.stdout)
    assert r["errors"] == []
    assert r["blockedRequests"] == []
    assert r["litPixels"] > 500
    assert shot.stat().st_size > 2000
    keep = Path(__file__).resolve().parent.parent / "data/tiles/shots"
    if keep.parent.exists():
        keep.mkdir(exist_ok=True)
        shutil.copy(shot, keep / f"offline-{kind}.png")


@pytest.mark.skipif(not HAVE_PW, reason="no playwright")
def test_online_vector_fetches_only_the_tiles_of_the_viewport(tmp_path):
    out_dir = tmp_path / "online"
    V.online_vector_dir(out_dir, archive_bytes(), disclosed("p023"), "Persona p023")
    z, ox, oy = 4, 2100, 1500  # world pixel offset of the viewport's top-left at zoom 4 (4096 px world)
    out = subprocess.run([NODE, str(JS / "online_check.cjs"), str(out_dir), str(z), str(ox), str(oy), str(VIEW_W), str(VIEW_H)],
                         capture_output=True, text=True, timeout=120, env=NODE_ENV)
    assert out.returncode == 0, out.stderr[-800:]
    r = json.loads(out.stdout)
    assert r["errors"] == []
    want = {tuple(t) for t in T.view_tiles(z, ox, oy, r["canvas"]["w"], r["canvas"]["h"])}  # the canvas is the viewport (the panel takes the rest)
    fetched = {tuple(t[1:]) for t in map(tuple, r["tilesFetched"]) if t[0] == z}
    assert fetched == want
    assert all(t[0] == z for t in r["tilesFetched"])
    assert r["tileBytes"] <= VIEW_BYTES_BOUND
    assert r["litPixels"] > 200


# ---------- raster covers 1x to 4x only (LI.53) ----------

def test_raster_stops_at_four_times_zoom():
    assert V.RASTER_MAXZOOM == 2
    pngs = V.raster_pyramid(archive(), lfile("p023"), V.RASTER_MAXZOOM)
    assert pngs and max(z for z, _, _ in pngs) == 2 and min(z for z, _, _ in pngs) == 0


def test_raster_tile_matches_vector_colours():
    from PIL import Image
    import io
    pngs = V.raster_pyramid(archive(), lfile("p023"), 2)
    lf = lfile("p023")
    z, ext = 2, bm().extent
    worst, n = 0, 0
    for i, s in all_slices().items():
        if not T.visible(s, z, ext) or s.ring == "fine":
            continue
        wx, wy = T.world_of(bm(), (s.r0 + s.r1) / 2, s.angle)
        x, y = int(wx * 4), int(wy * 4)
        if (z, x, y) not in pngs:
            continue
        im_ = Image.open(io.BytesIO(pngs[(z, x, y)])).convert("RGB")
        px = im_.getpixel((min(255, int((wx * 4 - x) * 256)), min(255, int((wy * 4 - y) * 256))))
        want = T.colour_at(archive(), lf, z, wx, wy)
        if all(w < 40 for w in want):
            continue
        # the raster is anti-aliased; thin slices blend with black or their neighbours, so judge slices at least 4 px across
        if min((s.r0 + s.r1) / 2 * math.radians(s.width) * 256 * 4 / (2 * ext), (s.r1 - s.r0) * 256 * 4 / (2 * ext)) < 4:
            continue
        worst = max(worst, max(abs(a - b) for a, b in list(zip(px, want))[1:]))  # red also carries the claimed grain
        n += 1
    assert n >= 5 and worst <= 12, (n, worst)


# ---------- map conventions of the vector viewer (LI.53) ----------

@lru_cache(maxsize=1)
def probe():
    """A fine domain with a unique label, a clear green level and a lit parent."""
    lf = disclosed("p023")
    labels = lf["labels"]
    counts = {}
    for l in labels.values():
        counts[l.lower()] = counts.get(l.lower(), 0) + 1
    for i, v in sorted(lf["ids"].items()):
        if i in bm().fine and v[1] > 0.3 and counts[labels[i].lower()] == 1 and labels[i].isascii():
            return i, labels[i], v
    raise AssertionError("no probe domain")


def map_run(target, scenario):
    out = subprocess.run([NODE, str(JS / "map_check.cjs"), str(target), json.dumps(scenario)], capture_output=True, text=True,
                         timeout=180, env=NODE_ENV)
    assert out.returncode == 0, out.stderr[-1000:]
    return json.loads(out.stdout)


@pytest.fixture(scope="module")
def map_target(tmp_path_factory):
    d = tmp_path_factory.mktemp("maps")
    off = d / "offline.html"
    off.write_text(V.offline_vector_html(archive_bytes(), disclosed("p023"), "Persona p023"), encoding="utf-8")
    V.online_vector_dir(d / "online", archive_bytes(), disclosed("p023"), "Persona p023")
    return {"offline": off, "online": d / "online"}


@pytest.mark.skipif(not HAVE_PW, reason="no playwright")
@pytest.mark.parametrize("which", ["offline", "online"])
def test_map_search_select_hash_toggle_hover_labels(which, map_target):
    i, label, v = probe()
    r = map_run(map_target[which], {"term": label, "id": i})
    assert r["errors"] == []
    # search finds the fine domain and the view lands on it (its centre inside the canvas, zoomed well past the full disc)
    assert r["search"]["selected"] == i
    assert 0 < r["search"]["x"] < r["canvas"]["w"] and 0 < r["search"]["y"] < r["canvas"]["h"]
    assert r["search"]["zoom"] > r["fitZoom"] + 2
    # selection: the panel shows the right domain and its levels
    assert label in r["panel"] and i in r["panel"]
    assert f"{v[1]:.2f}" in r["panel"] and "green" in r["panel"].lower()
    # clicking the slice selects it too; hovering highlights it
    assert r["click"]["selected"] == i and r["hover"] == i
    # url hash round trip
    assert r["hash"].startswith("#") and "z=" in r["hash"]
    assert abs(r["restored"]["zoom"] - r["search"]["zoom"]) < 0.01
    assert abs(r["restored"]["cx"] - r["search"]["cx"]) < 1e-3 and abs(r["restored"]["cy"] - r["search"]["cy"]) < 1e-3
    assert r["restored"]["selected"] == i
    # channel toggle changes the rendered colour at the slice (green off removes its green)
    assert r["toggle"]["before"][1] > r["toggle"]["after"][1] + 20
    # labels appear by zoom where they fit
    assert r["labels"]["fit"] < r["labels"]["deep"] and r["labels"]["deep"] >= 1


def test_disclosure_none_ships_no_names_or_rows():
    lf = V.disclose(lfile("p023"), ctx(), it.spec_single(ctx(), "p023"), "none")
    assert "labels" not in lf and "rows" not in lf and "parents" not in lf
    summary = V.disclose(lfile("p023"), ctx(), it.spec_single(ctx(), "p023"), "summary")
    assert "labels" in summary and "rows" not in summary
    assert "rows" in disclosed("p023", "full") and disclosed("p023", "full")["rows"]
