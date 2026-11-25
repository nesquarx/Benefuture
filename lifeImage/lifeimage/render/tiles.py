"""Tiled basemap (LI.52): detail follows resolution.

The disc is mapped into a unit square (cartesian, centre at 0.5, 0.5; half-width `Basemap.extent`, y down) and cut into a
quadtree pyramid z/x/y of 256 px tiles. Every slice is a polygon (arcs sampled so the chord strays under
`tiles.arc_tolerance_px` at that zoom's resolution: no wasted vertices at low zoom), clipped to the tiles it meets.

Screen-space level of detail. A tile at zoom z holds the slices whose on-screen arc width (at mid radius) and radial depth are
both at least `tiles.min_slice_px` pixels at that zoom (`visible`), so the colouring is full detail for the resolution and
`max_zoom` is where everything that exists is shipped. Two kinds of slice are not shipped when too narrow, with different
fallbacks (a deviation from the one-line LI.52 rule, evidence-driven):
 - a fine slice is drawn as its parent: the hidden children of one parent are merged into runs, each run one `fallback`
   polygon (the hull of the run's arcs and radial span) carrying the parent's id; the parent's level already aggregates its
   children (LI.51, `levels._fold`);
 - a coarse field has no such parent (a sector is not the aggregate of its fields: LI.51 aggregates one step, fine to coarse),
   so a field too narrow to show is simply not drawn (it is under a pixel by construction). Sectors are always wide enough.

Features carry domain ids only (layers `sector`, `field`, `fallback`, `fine`, drawn in that order; tags `id`, and `p`, the
parent, on fine slices); colours come from a per-entity levels file joined at view time, so tiles are public and disclosure
decides which levels file exists. Tiles are Mapbox Vector Tiles (hand-encoded protobuf, no dependency; checked against
`mapbox-vector-tile` and `pmtiles` readers) in a PMTiles v3 archive.

Recalibration: a levels file carries the basemap version; `migrate_levels` moves it to a newer basemap through
`lifeimage.migration` tables, on luminosities (the inverse of the tone map, which add), conserving each channel's total.
"""
import gzip
import hashlib
import json
import math
import struct
from dataclasses import dataclass, field

from .. import governed as gv
from .. import levels as lv
from . import image as im

TILE_PX = 256
MIN_SLICE_PX = gv.governed("tiles.min_slice_px")
ARC_TOL_PX = gv.governed("tiles.arc_tolerance_px")
MVT_EXTENT = 4096
MVT_BUFFER = 64  # tile units (4 px) kept outside the tile so polygons meet without seams
DEPTH_ZOOM = (0, 2, 4, 6)  # the pyramid zoom each interactive depth (disc, sector, field, fine domain) is read at
LAYERS = ("sector", "field", "fallback", "fine")
MAX_ZOOM_CAP = 12


# ---------- geometry and level of detail ----------

def world_of(bm, r, angle_deg):
    """Unit-square position (x right, y down) of radius r and angle (degrees, counter-clockwise) on the basemap's disc."""
    e = bm.extent
    a = math.radians(angle_deg)
    return 0.5 + r * math.cos(a) / (2 * e), 0.5 - r * math.sin(a) / (2 * e)


def ppu(z, ext):
    """Pixels per basemap unit at zoom z."""
    return TILE_PX * 2 ** z / (2 * ext)


def visible(s, z, ext):
    k = ppu(z, ext)
    return min((s.r0 + s.r1) / 2 * math.radians(s.width) * k, (s.r1 - s.r0) * k) >= MIN_SLICE_PX


def zoom_for_px(px):
    """The pyramid zoom whose native resolution covers a full-disc view of px pixels."""
    return max(0, math.ceil(math.log2(px / TILE_PX) - 1e-9))


def max_zoom(bm):
    allslices = [*bm.slices.values(), *bm.fine.values()]
    for z in range(MAX_ZOOM_CAP + 1):
        if all(visible(s, z, bm.extent) for s in allslices):
            return z
    return MAX_ZOOM_CAP


def view_tiles(z, ox, oy, w, h):
    """[(x, y)] tiles (row-major) meeting a viewport of w x h pixels whose top-left sits at (ox, oy) in the world measured in
    pixels at zoom z (the world is 256 * 2**z px wide)."""
    n = 2 ** z
    x0, x1 = max(0, math.floor(ox / TILE_PX)), min(n - 1, math.floor((ox + w - 1e-9) / TILE_PX))
    y0, y1 = max(0, math.floor(oy / TILE_PX)), min(n - 1, math.floor((oy + h - 1e-9) / TILE_PX))
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def sector_polygon(a0, a1, r0, r1, z, ext):
    """World-unit polygon of the ring sector (angles in degrees, a1 > a0); arcs sampled to the zoom's tolerance."""
    k = ppu(z, ext)

    def arc(r, ang0, ang1):
        rp = max(r * k, 1e-9)
        step = 2 * math.acos(max(-1.0, 1 - ARC_TOL_PX / rp)) if rp > ARC_TOL_PX else math.pi
        n = max(1, math.ceil(math.radians(abs(ang1 - ang0)) / step))
        return [world_of_ext(r, ang0 + (ang1 - ang0) * i / n, ext) for i in range(n + 1)]
    return arc(r1, a0, a1) + arc(r0, a1, a0)


def world_of_ext(r, angle_deg, ext):
    a = math.radians(angle_deg)
    return 0.5 + r * math.cos(a) / (2 * ext), 0.5 - r * math.sin(a) / (2 * ext)


def _clip_edge(poly, inside, cross):
    out = []
    for i, p in enumerate(poly):
        q = poly[i - 1]
        pi, qi = inside(p), inside(q)
        if pi:
            if not qi:
                out.append(cross(q, p))
            out.append(p)
        elif qi:
            out.append(cross(q, p))
    return out


def clip_rect(poly, x0, y0, x1, y1):
    """Sutherland-Hodgman clip of a polygon to a rectangle."""
    def mk(axis, bound, keep_ge):
        def inside(p):
            return p[axis] >= bound if keep_ge else p[axis] <= bound

        def cross(q, p):
            t = (bound - q[axis]) / (p[axis] - q[axis])
            return (q[0] + t * (p[0] - q[0]), q[1] + t * (p[1] - q[1]))
        return inside, cross
    for axis, bound, ge in ((0, x0, True), (0, x1, False), (1, y0, True), (1, y1, False)):
        if not poly:
            return []
        poly = _clip_edge(poly, *mk(axis, bound, ge))
    return poly


# ---------- MVT ----------

def _varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _zig(n):
    return (n << 1) ^ (n >> 63)


def _ld(num, payload):
    return _varint(num << 3 | 2) + _varint(len(payload)) + payload


def _packed(nums):
    return b"".join(_varint(n) for n in nums)


def _geometry(ring):
    cmds, px, py = [9], 0, 0
    x, y = ring[0]
    cmds += [_zig(x - px), _zig(y - py)]
    px, py = x, y
    cmds.append(2 | (len(ring) - 1) << 3)
    for x, y in ring[1:]:
        cmds += [_zig(x - px), _zig(y - py)]
        px, py = x, y
    cmds.append(15)
    return cmds


def _area2(ring):
    return sum(ring[i][0] * ring[(i + 1) % len(ring)][1] - ring[(i + 1) % len(ring)][0] * ring[i][1] for i in range(len(ring)))


def encode_mvt(layers):
    """layers: {name: [(tags {str: str}, ring [(x, y) ints])]} -> MVT bytes (version 2, extent 4096, polygons)."""
    out = b""
    for name in LAYERS:
        feats = layers.get(name)
        if not feats:
            continue
        keys, vals, kidx, vidx, body = [], [], {}, {}, b""
        for tags, ring in feats:
            tg = []
            for k, v in sorted(tags.items()):
                if k not in kidx:
                    kidx[k] = len(keys)
                    keys.append(k)
                if v not in vidx:
                    vidx[v] = len(vals)
                    vals.append(v)
                tg += [kidx[k], vidx[v]]
            if _area2(ring) < 0:
                ring = ring[::-1]
            f = _ld(2, _packed(tg)) + _varint(3 << 3) + _varint(3) + _ld(4, _packed(_geometry(ring)))
            body += _ld(2, f)
        layer = _varint(15 << 3) + _varint(2) + _ld(1, name.encode()) + body
        layer += b"".join(_ld(3, k.encode()) for k in keys) + b"".join(_ld(4, _ld(1, v.encode())) for v in vals)
        layer += _varint(5 << 3) + _varint(MVT_EXTENT)
        out += _ld(3, layer)
    return out


def _read_varint(b, i):
    n = shift = 0
    while True:
        c = b[i]
        i += 1
        n |= (c & 0x7F) << shift
        if not c & 0x80:
            return n, i
        shift += 7


def _fields(b):
    i = 0
    while i < len(b):
        key, i = _read_varint(b, i)
        num, wt = key >> 3, key & 7
        if wt == 0:
            v, i = _read_varint(b, i)
        elif wt == 2:
            ln, i = _read_varint(b, i)
            v, i = b[i:i + ln], i + ln
        else:
            raise ValueError(f"wire type {wt}")
        yield num, v


def decode_mvt(data):
    """{layer: [{"tags": {k: v}, "rings": [[(x, y)]]}]}."""
    out = {}
    for num, lay in _fields(data):
        if num != 3:
            continue
        name, keys, vals, raw = "", [], [], []
        for n, v in _fields(lay):
            if n == 1:
                name = v.decode()
            elif n == 2:
                raw.append(v)
            elif n == 3:
                keys.append(v.decode())
            elif n == 4:
                vals.append(next(x for m, x in _fields(v) if m == 1).decode())
        feats = []
        for f in raw:
            tags, geom = [], []
            for n, v in _fields(f):
                if n == 2:
                    i = 0
                    while i < len(v):
                        t, i = _read_varint(v, i)
                        tags.append(t)
                elif n == 4:
                    i = 0
                    while i < len(v):
                        t, i = _read_varint(v, i)
                        geom.append(t)
            rings, cur, i, x, y = [], None, 0, 0, 0
            while i < len(geom):
                cmd, cnt = geom[i] & 7, geom[i] >> 3
                i += 1
                if cmd == 7:
                    rings.append(cur)
                    cur = None
                    continue
                for _ in range(cnt):
                    dx, dy = geom[i], geom[i + 1]
                    i += 2
                    x += (dx >> 1) ^ -(dx & 1)
                    y += (dy >> 1) ^ -(dy & 1)
                    if cmd == 1:
                        cur = []
                    cur.append((x, y))
            feats.append({"tags": {keys[tags[j]]: vals[tags[j + 1]] for j in range(0, len(tags), 2)}, "rings": rings})
        out[name] = feats
    return out


# ---------- pyramid ----------

@dataclass
class Pyramid:
    tiles: dict = field(default_factory=dict)  # (z, x, y) -> MVT bytes
    meta: dict = field(default_factory=dict)


def _hidden_runs(bm, z):
    """[(parent id, a0, a1, r0, r1)]: hidden fine children of each parent merged where they touch (no visible child between)."""
    ext = bm.extent
    k = ppu(z, ext)
    kids = {}
    for s in bm.fine.values():
        kids.setdefault(s.parent, []).append(s)
    runs = []
    for pid, ss in sorted(kids.items()):
        base = bm.slices[pid].start
        ss = sorted(ss, key=lambda s: ((s.start - base) % 360, s.id))
        cur = None
        for s in ss:
            rel = (s.start - base) % 360
            if visible(s, z, ext):
                cur = None
                continue
            gap_px = (rel - cur[2]) * math.pi / 180 * (s.r0 + s.r1) / 2 * k if cur else None
            if cur and gap_px <= MIN_SLICE_PX:
                cur[2], cur[3], cur[4] = rel + s.width, min(cur[3], s.r0), max(cur[4], s.r1)
            else:
                cur = [pid, rel, rel + s.width, s.r0, s.r1]
                runs.append(cur)
        # relative angles back to absolute
    return [(p, base_of(bm, p) + a, base_of(bm, p) + b, r0, r1) for p, a, b, r0, r1 in runs]


def base_of(bm, pid):
    return bm.slices[pid].start


def build_zoom(bm, z):
    """{(x, y): {layer: [(tags, ring)]}} for zoom z."""
    ext, n = bm.extent, 2 ** z
    polys = []  # (layer, tags, polygon)
    for s in sorted([*bm.slices.values(), *bm.fine.values()], key=lambda s: s.id):
        if not visible(s, z, ext):
            continue
        layer = "fine" if s.ring == "fine" else s.ring
        tags = {"id": s.id}
        if s.ring == "fine":
            tags["p"] = s.parent
        polys.append((layer, tags, sector_polygon(s.start, s.start + s.width, s.r0, s.r1, z, ext)))
    for pid, a0, a1, r0, r1 in _hidden_runs(bm, z):
        polys.append(("fallback", {"id": pid}, sector_polygon(a0, a1, r0, r1, z, ext)))
    tiles, b = {}, MVT_BUFFER / MVT_EXTENT
    for layer, tags, poly in polys:
        xs, ys = [p[0] * n for p in poly], [p[1] * n for p in poly]
        for ty in range(max(0, math.floor(min(ys) - b)), min(n - 1, math.floor(max(ys) + b)) + 1):
            for tx in range(max(0, math.floor(min(xs) - b)), min(n - 1, math.floor(max(xs) + b)) + 1):
                loc = [(x * n - tx, y * n - ty) for x, y in poly]
                cl = clip_rect(loc, -b, -b, 1 + b, 1 + b)
                if len(cl) < 3:
                    continue
                ring = []
                for x, y in cl:
                    q = (round(x * MVT_EXTENT), round(y * MVT_EXTENT))
                    if not ring or q != ring[-1]:
                        ring.append(q)
                if len(ring) > 1 and ring[0] == ring[-1]:
                    ring.pop()
                if len(ring) >= 3 and abs(_area2(ring)) > 0:
                    tiles.setdefault((tx, ty), {}).setdefault(layer, []).append((tags, ring))
    return tiles


def slice_index(bm):
    """{id: [start, width, r0, r1, ring (0 sector, 1 field, 2 fine), parent]} (degrees, basemap units): where each slice is, so a
    viewer can fly to a domain before its tile is loaded. Geometry only, as public as the tiles."""
    ring = {"sector": 0, "field": 1, "fine": 2}
    return {s.id: [round(s.start, 4), round(s.width, 4), round(s.r0, 4), round(s.r1, 4), ring[s.ring], s.parent or ""]
            for s in sorted([*bm.slices.values(), *bm.fine.values()], key=lambda s: s.id)}


def build_pyramid(bm, maxzoom=None):
    maxzoom = max_zoom(bm) if maxzoom is None else maxzoom
    pyr = Pyramid(meta={"basemap": bm.version, "extent": bm.extent, "minzoom": 0, "maxzoom": maxzoom, "tile_px": TILE_PX,
                        "min_slice_px": MIN_SLICE_PX, "layers": list(LAYERS),
                        "index": slice_index(bm)})
    for z in range(maxzoom + 1):
        for (x, y), layers in build_zoom(bm, z).items():
            pyr.tiles[(z, x, y)] = encode_mvt(layers)
    return pyr


# ---------- PMTiles v3 ----------

def tileid(z, x, y):
    acc = ((1 << (z * 2)) - 1) // 3
    for a in range(z - 1, -1, -1):
        s = 1 << a
        rx, ry = s & x, s & y
        acc += ((3 * rx) ^ ry) << a
        if ry == 0:
            if rx != 0:
                x, y = s - 1 - x, s - 1 - y
            x, y = y, x
    return acc


def tile_of_id(tid):
    z = 0
    while True:
        n = ((1 << (2 * z)) - 1) // 3
        m = n + (1 << (2 * z))
        if tid < m:
            break
        z += 1
    pos, x, y, t = tid - n, 0, 0, tid - n
    s = 1
    while s < (1 << z):
        rx = 1 & (t // 2)
        ry = 1 & (t ^ rx)
        if ry == 0:
            if rx == 1:
                x, y = s - 1 - x, s - 1 - y
            x, y = y, x
        x += s * rx
        y += s * ry
        t //= 4
        s *= 2
    return z, x, y


def _gz(b):
    return gzip.compress(b, 9, mtime=0)


def _dir_bytes(entries):
    """entries: [(tile_id, offset, length, run_length)] sorted by id."""
    out = bytearray(_varint(len(entries)))
    last = 0
    for e in entries:
        out += _varint(e[0] - last)
        last = e[0]
    for e in entries:
        out += _varint(e[3])
    for e in entries:
        out += _varint(e[2])
    prev = None
    for e in entries:
        out += _varint(0 if prev is not None and e[1] == prev[1] + prev[2] else e[1] + 1)
        prev = e
    return _gz(bytes(out))


def pmtiles_bytes(pyr):
    items = sorted((tileid(*k), k) for k in pyr.tiles)
    data, seen, entries = bytearray(), {}, []
    for tid, k in items:
        blob = _gz(pyr.tiles[k])
        h = hashlib.sha1(blob).digest()
        if h not in seen:
            seen[h] = (len(data), len(blob))
            data += blob
        off, ln = seen[h]
        entries.append((tid, off, ln, 1))
    meta = _gz(json.dumps(pyr.meta, sort_keys=True).encode())
    root, leaves = _dir_bytes(entries), b""
    if 127 + len(root) + len(meta) > 16384:
        size = 4096
        while True:
            chunks = [entries[i:i + size] for i in range(0, len(entries), size)]
            blobs = [_dir_bytes(c) for c in chunks]
            rentries, off = [], 0
            for c, bl in zip(chunks, blobs):
                rentries.append((c[0][0], off, len(bl), 0))
                off += len(bl)
            root = _dir_bytes(rentries)
            if 127 + len(root) + len(meta) <= 16384 or size >= len(entries):
                break
            size *= 2
        leaves = b"".join(blobs)
    ro, mo = 127, 127 + len(root)
    lo = mo + len(meta)
    do = lo + len(leaves)
    zs = [k[0] for k in pyr.tiles]
    hdr = b"PMTiles" + bytes([3]) + struct.pack("<10Q", ro, len(root), mo, len(meta), lo, len(leaves), do, len(data), len(entries), len(entries))
    hdr += struct.pack("<Q", len(seen))
    hdr += bytes([1, 2, 2, 1, min(zs), max(zs)])
    hdr += struct.pack("<4i", 0, 0, 0, 0) + bytes([0]) + struct.pack("<2i", 0, 0)
    assert len(hdr) == 127
    return hdr + root + meta + leaves + bytes(data)


def _read_dir(b):
    b = gzip.decompress(b)
    n, i = _read_varint(b, 0)
    ids, last = [], 0
    for _ in range(n):
        d, i = _read_varint(b, i)
        last += d
        ids.append(last)
    runs = []
    for _ in range(n):
        v, i = _read_varint(b, i)
        runs.append(v)
    lens = []
    for _ in range(n):
        v, i = _read_varint(b, i)
        lens.append(v)
    offs, prev = [], None
    for j in range(n):
        v, i = _read_varint(b, i)
        off = prev[0] + prev[1] if v == 0 and prev else v - 1
        offs.append(off)
        prev = (off, lens[j])
    return list(zip(ids, offs, lens, runs))


class PMTiles:
    """Reader of a PMTiles v3 archive held in memory."""

    def __init__(self, data):
        self.data = data
        if data[:7] != b"PMTiles" or data[7] != 3:
            raise ValueError("not a PMTiles v3 archive")
        q = struct.unpack("<11Q", data[8:96])
        self.header = {"root": q[0:2], "meta": q[2:4], "leaf": q[4:6], "data": q[6:8], "entries": q[9], "contents": q[10],
                       "tile_type": data[99], "min_zoom": data[100], "max_zoom": data[101],
                       "tile_compression": data[98], "internal_compression": data[97]}
        self.metadata = json.loads(gzip.decompress(data[q[2]:q[2] + q[3]]))
        self._root = _read_dir(data[q[0]:q[0] + q[1]])
        self._leaf = {}
        self._cache = {}

    def _entries(self):
        for e in self._root:
            if e[3] > 0:
                yield e
            else:
                lo, ll = self.header["leaf"]
                if e[1] not in self._leaf:
                    self._leaf[e[1]] = _read_dir(self.data[lo + e[1]:lo + e[1] + e[2]])
                yield from self._leaf[e[1]]

    def tiles(self):
        out = []
        for tid, _o, _l, run in self._entries():
            out += [tile_of_id(tid + j) for j in range(run)]
        return out

    def _find(self, z, x, y):
        tid = tileid(z, x, y)
        for e in self._entries():
            if e[0] <= tid < e[0] + max(e[3], 1):
                return e
        return None

    def tile_size(self, z, x, y):
        e = self._find(z, x, y)
        return e[2] if e else 0

    def tile(self, z, x, y):
        key = (z, x, y)
        if key not in self._cache:
            e = self._find(z, x, y)
            if e is None:
                self._cache[key] = None
            else:
                do = self.header["data"][0]
                self._cache[key] = gzip.decompress(self.data[do + e[1]:do + e[1] + e[2]])
        return self._cache[key]

    def decoded(self, z, x, y):
        key = ("d", z, x, y)
        if key not in self._cache:
            t = self.tile(z, x, y)
            self._cache[key] = decode_mvt(t) if t else {}
        return self._cache[key]


# ---------- levels file ----------

def levels_file(levels, version, title=""):
    """The per-entity colour join: {"ids": {domain id: [red, green, blue, saturation, claimed red]}} (levels in [0, 1], four
    decimals), the basemap version they were built on and the tone constant (to convert levels back to luminosities)."""
    ids = {}
    for d in sorted(set(levels["solid"]) | set(levels["claimed"])):
        s, c = levels["solid"].get(d), levels["claimed"].get(d)
        v = [round(s[k], 4) if s else 0.0 for k in im.CHANNELS] + [round(s["saturation"], 4) if s else 1.0, round(c["red"], 4) if c else 0.0]
        if v[0] or v[1] or v[2] or v[4]:
            ids[d] = v
    return {"kind": "levels", "v": 1, "basemap": version, "title": title, "tone_k": lv.DEFAULT.tone_k, "ids": ids}


def colour_of(v):
    return im.rgb({"red": v[0], "green": v[1], "blue": v[2], "saturation": v[3]}, levels=True)


def _inside(pt, ring):
    x, y = pt
    ins = False
    for i in range(len(ring)):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % len(ring)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            ins = not ins
    return ins


def colour_at(archive, lf, z, wx, wy):
    """The solid colour the tiled render gives at the unit-square point (wx, wy) at zoom z: the topmost feature holding the point,
    its colour from the levels file (a fallback feature carries its parent's id); black where none holds it or none is coloured."""
    n = 2 ** z
    x, y = min(n - 1, int(wx * n)), min(n - 1, int(wy * n))
    pt = ((wx * n - x) * MVT_EXTENT, (wy * n - y) * MVT_EXTENT)
    layers = archive.decoded(z, x, y)
    for name in reversed(LAYERS):
        for f in layers.get(name, []):
            if any(_inside(pt, r) for r in f["rings"]):
                v = lf["ids"].get(f["tags"]["id"])
                return colour_of(v) if v and (v[0] or v[1] or v[2]) else (0, 0, 0)
    return (0, 0, 0)


def luminosity_totals(lf):
    """Per-channel totals of luminosity (the inverse tone map, which adds): red, green, blue and claimed red."""
    k = lf["tone_k"]
    out = dict.fromkeys(("red", "green", "blue", "claimed"), 0.0)
    for v in lf["ids"].values():
        for name, level in zip(out, (v[0], v[1], v[2], v[4])):
            out[name] += -k * math.log(1.0 - min(level, 1 - 1e-12))
    return out


def migrate_levels(lf, table, version):
    """The levels file on a newer basemap: each domain's luminosities move through the migration table (rows sum to 1, so each
    channel's total is conserved), levels are re-toned, saturation is the luminosity-weighted mean of the olds it came from."""
    k = lf["tone_k"]
    acc = {}
    for old, v in lf["ids"].items():
        sums = [-k * math.log(1.0 - min(level, 1 - 1e-12)) for level in (v[0], v[1], v[2], v[4])]
        mass = sums[0] + sums[1] + sums[2]
        for new, w in table.get(old, {old: 1.0}).items():
            a = acc.setdefault(new, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
            for j in range(4):
                a[j] += w * sums[j]
            a[4] += w * mass * v[3]
            a[5] += w * mass
    ids = {}
    for d, a in sorted(acc.items()):
        ids[d] = [1 - math.exp(-a[0] / k), 1 - math.exp(-a[1] / k), 1 - math.exp(-a[2] / k), a[4] / a[5] if a[5] > 0 else 1.0,
                  1 - math.exp(-a[3] / k)]
    return {**{x: y for x, y in lf.items() if x not in ("ids", "rows", "labels", "parents")}, "basemap": version, "ids": ids}


def check_levels_ids(lf, valid):
    missing = sorted(set(lf["ids"]) - set(valid))
    if missing:
        raise ValueError(f"levels file names ids the basemap does not have: {', '.join(missing[:5])}")
    return lf
