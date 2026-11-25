"""Build the tiled basemap and its viewers (LI.52, LI.53): basemap -> pyramid; persona -> levels file; pages.

Usage (from the repository root): python3 lifeImage/tools/build_tiles.py [--out lifeImage/data/tiles] [--persona p023 ...]
                                   [--disclosure full] [--measure]

Writes under the output folder:
  basemap.pmtiles                 the vector pyramid (MVT in PMTiles v3), zoom 0 to the zoom where everything exists
  levels-<id>.json                the colour join of each persona at the chosen disclosure (tiles are public, levels are not)
  offline/<id>-vector.html        one self-contained page: whole pyramid + levels, no network
  offline/<id>-raster.html        one self-contained page: PNG pyramid zoom 0 to 2 (1x to 4x) embedded
  online/<id>/vector/             static folder: index.html, basemap.pmtiles (range requests), levels.json
  online/<id>/raster/             static folder: index.html, tiles/z/x/y.png (zoom 0 to 2)
`--measure` prints the load per zoom and per view size (features and bytes), pyramid and page sizes, as JSON. Deterministic: the
same data gives byte-identical files. Runs no model. A new basemap release is a re-run: vector pages recolour from the levels file
(migrated with `tiles.migrate_levels` when it was built on an older version), raster pyramids are re-rendered.
"""
import argparse
import json
import sys
import warnings
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.render import interactive as it  # noqa: E402
from lifeimage.render import tiles as T  # noqa: E402
from lifeimage.render import tileview as V  # noqa: E402


def measure(arch, pyr, bm):
    out = {"zoom": {}, "views": {}}
    for z in range(pyr.meta["maxzoom"] + 1):
        ts = [t for t in arch.tiles() if t[0] == z]
        feats = sum(len(v) for t in ts for v in T.decode_mvt(arch.tile(*t)).values())
        out["zoom"][z] = {"tiles": len(ts), "features": feats, "bytes": sum(arch.tile_size(*t) for t in ts),
                          "slices_shipped": len({f["tags"]["id"] for t in ts for n, v in T.decode_mvt(arch.tile(*t)).items()
                                                 if n != "fallback" for f in v})}
    for px in (200, 1024, 4096):
        z = T.zoom_for_px(px)
        out["views"][px] = {"zoom": z, **{k: out["zoom"][z][k] for k in ("tiles", "features", "bytes", "slices_shipped")}}
    return out


def main(out, personas, disclosure, do_measure):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        ctx = it.context()
    bm = ctx["bm"]
    pyr = T.build_pyramid(bm)
    data = T.pmtiles_bytes(pyr)
    out.mkdir(parents=True, exist_ok=True)
    (out / "basemap.pmtiles").write_bytes(data)
    arch = T.PMTiles(data)
    report = {"basemap": bm.version, "maxzoom": pyr.meta["maxzoom"], "pyramid_tiles": len(pyr.tiles), "pyramid_bytes": len(data)}
    sizes = {}
    for pid in personas:
        spec = it.spec_single(ctx, pid)
        levels = it.analyse(ctx, spec["members"][0])["levels"]
        lf = T.check_levels_ids(V.disclose(T.levels_file(levels, bm.version, pid), ctx, spec, disclosure), set(ctx["by"]))
        (out / f"levels-{pid}.json").write_text(json.dumps(lf, sort_keys=True, separators=(",", ":")), encoding="utf-8")
        (out / "offline").mkdir(exist_ok=True)
        vec = V.offline_vector_html(data, lf, f"Life Image map: {pid}")
        (out / "offline" / f"{pid}-vector.html").write_text(vec, encoding="utf-8")
        pngs = V.raster_pyramid(arch, lf)
        ras = V.offline_raster_html(pngs, pyr.meta, lf, f"Life Image raster: {pid}")
        (out / "offline" / f"{pid}-raster.html").write_text(ras, encoding="utf-8")
        V.online_vector_dir(out / "online" / pid / "vector", data, lf, f"Life Image map: {pid}")
        V.online_raster_dir(out / "online" / pid / "raster", pngs, pyr.meta, f"Life Image raster: {pid}")
        sizes[pid] = {"levels_json": (out / f"levels-{pid}.json").stat().st_size, "offline_vector_html": len(vec.encode()),
                      "offline_raster_html": len(ras.encode()), "raster_tiles": len(pngs), "raster_bytes": sum(map(len, pngs.values()))}
    report["sizes"] = sizes
    if do_measure:
        report["measure"] = measure(arch, pyr, bm)
    print(json.dumps(report, indent=1, sort_keys=True))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "data/tiles")
    ap.add_argument("--persona", action="append")
    ap.add_argument("--disclosure", default="full", choices=V.DISCLOSURES)
    ap.add_argument("--measure", action="store_true")
    a = ap.parse_args()
    main(a.out, a.persona or ["p023"], a.disclosure, a.measure)
