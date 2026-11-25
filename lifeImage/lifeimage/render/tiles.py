"""Tiled basemap (LI.52): detail follows resolution.

The disc is mapped into a unit square (cartesian, centre at 0.5, 0.5; half-width `Basemap.extent`, y down) and cut into a
quadtree pyramid z/x/y of 256 px tiles. Every slice is a polygon (arcs sampled so the chord strays under
`tiles.arc_tolerance_px` at that zoom's resolution: no wasted vertices at low zoom), clipped to the tiles it meets.

Screen-space level of detail. A tile at zoom z holds the slices whose on-screen arc width (at mid radius) and radial depth are
both at least `tiles.min_slice_px` pixels at that zoom (`visible`), so the colouring is full detail for the resolution and
`max_zoom` is where everything that exists is shipped. A slice too narrow to ship is not dropped and not drawn as its
parent (the parent's level aggregates its children, LI.51, but the children do not sit over the parent's area, and the parent's
colour is not the mean of what the area shows). Full detail for a resolution is a full-detail render downsampled to it, so
hidden slices of one ring that fall in the same pixel-sized cell (arc position and radius, `tiles.min_slice_px`) become one
`aggregate` polygon: the hull of the members' arcs and radial spans, carrying the member ids (`m`: indices into the sorted slice ids of the archive metadata, largest share first) and each
member's share of the hull's area (`a`: ten-thousandths). Its colour is the members' rendered colours averaged by area in linear light and encoded again
(`aggregate_colour`), the rest of the hull being black. Selection and search resolve the members on zoom. Sectors are always wide enough.

Features carry domain ids only (layers `sector`, `aggregate`, `field`, `fine`, drawn in that order; tag `id`, and `m`, `a` on aggregates); colours come from a per-entity levels file joined at view time, so tiles are public and disclosure
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
LAYERS = ("sector", "aggregate", "field", "fine")
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


def hidden_clusters(bm, z):
    """[[members]]: the slices too narrow to ship at zoom z, grouped by ring kind (fine or field) and pixel-sized cell: arc
    position and radius, each `MIN_SLICE_PX` across, so one cluster is about one pixel of the render."""
    ext = bm.extent
    k = ppu(z, ext)
    cells = {}
    for s in [*bm.slices.values(), *bm.fine.values()]:
        if s.ring == "sector" or visible(s, z, ext):
            continue
        rm = (s.r0 + s.r1) / 2
        rc = (math.floor(rm * k / MIN_SLICE_PX) + 0.5) * MIN_SLICE_PX / k
        mid = (s.start + s.width / 2) % 360
        key = (s.ring, math.floor(math.radians(mid) * rc * k / MIN_SLICE_PX), math.floor(rm * k / MIN_SLICE_PX))
        cells.setdefault(key, []).append(s)
    return [sorted(v, key=lambda s: s.id) for _, v in sorted(cells.items())]


def _area(s):
    return 0.5 * math.radians(s.width) * (s.r1 ** 2 - s.r0 ** 2)


def cluster_hull(members, k):
    """(a0, a1, r0, r1, [(id, share of the hull's area)]) of a cluster at k pixels per unit: the members' arcs and radial
    spans, widened to at least `MIN_SLICE_PX` each way (a hull thinner than a pixel cannot be coded at tile precision, and is
    the pixel whose colour it averages), angles unwrapped around the first member's centre."""
    mids = [(s.start + s.width / 2) % 360 for s in members]
    ref = mids[0]
    rel = [((m - ref + 180) % 360) - 180 for m in mids]
    a0 = ref + min(r - s.width / 2 for r, s in zip(rel, members))
    a1 = ref + max(r + s.width / 2 for r, s in zip(rel, members))
    r0, r1 = min(s.r0 for s in members), max(s.r1 for s in members)
    rc = (r0 + r1) / 2
    pad = 0.25 * MIN_SLICE_PX / k  # members sit strictly inside the hull, clear of tile quantisation
    r0, r1 = r0 - pad, r1 + pad
    a0, a1 = a0 - math.degrees(pad / rc), a1 + math.degrees(pad / rc)
    dr = MIN_SLICE_PX / k - (r1 - r0)
    if dr > 0:
        r0, r1 = r0 - dr / 2, r1 + dr / 2
    da = math.degrees(MIN_SLICE_PX / (rc * k)) - (a1 - a0)
    if da > 0:
        a0, a1 = a0 - da / 2, a1 + da / 2
    hull = 0.5 * math.radians(a1 - a0) * (r1 ** 2 - r0 ** 2)
    return a0, a1, r0, r1, [(s.id, _area(s) / hull) for s in members]


def build_zoom(bm, z):
    """{(x, y): {layer: [(tags, ring)]}} for zoom z."""
    ext, n = bm.extent, 2 ** z
    order = {i: j for j, i in enumerate(sorted([*bm.slices, *bm.fine]))}
    polys = []  # (layer, tags, polygon)
    for s in sorted([*bm.slices.values(), *bm.fine.values()], key=lambda s: s.id):
        if not visible(s, z, ext):
            continue
        layer = "fine" if s.ring == "fine" else s.ring
        polys.append((layer, {"id": s.id}, sector_polygon(s.start, s.start + s.width, s.r0, s.r1, z, ext)))
    for members in hidden_clusters(bm, z):
        a0, a1, r0, r1, shares = cluster_hull(members, ppu(z, ext))
        shares = sorted(shares, key=lambda t: (-t[1], t[0]))
        tags = {"m": ",".join(str(order[i]) for i, _ in shares), "a": ",".join(str(round(w * 10000)) for _, w in shares)}
        polys.append(("aggregate", tags, sector_polygon(a0, a1, r0, r1, z, ext)))
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
        self.order = sorted(self.metadata.get("index", {}))

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


def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _enc(x):
    x = min(1.0, max(0.0, x))
    return int(round(255 * (12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055)))


def aggregate_members(tags, order):
    """[(id, share of the hull's area)] of an aggregate's tags; `order` is the archive's sorted slice ids."""
    return [(order[int(i)], int(w) / 10000) for i, w in zip(tags["m"].split(","), tags["a"].split(","))]


def aggregate_colour(lf, tags, order):
    """(r, g, b) of an aggregate: its members' rendered colours averaged by area share in linear light, then encoded."""
    acc = [0.0, 0.0, 0.0]
    for i, w in aggregate_members(tags, order):
        v = lf["ids"].get(i)
        if v and (v[0] or v[1] or v[2]):
            for j, c in enumerate(colour_of(v)):
                acc[j] += w * _lin(c)
    return tuple(_enc(x) for x in acc)


def feature_colour(lf, layer, tags, order):
    if layer == "aggregate":
        return aggregate_colour(lf, tags, order)
    v = lf["ids"].get(tags["id"])
    return colour_of(v) if v and (v[0] or v[1] or v[2]) else (0, 0, 0)


def feature_claimed(lf, layer, tags, order):
    """Claimed red (the grain) of a feature; an aggregate's is its members' by area share."""
    if layer == "aggregate":
        return sum(w * (lf["ids"].get(i) or [0] * 5)[4] for i, w in aggregate_members(tags, order))
    v = lf["ids"].get(tags["id"])
    return v[4] if v else 0.0


def colour_at(archive, lf, z, wx, wy):
    """The solid colour the tiled render gives at the unit-square point (wx, wy) at zoom z: the topmost feature holding the point,
    its colour from the levels file (an aggregate averages its members); black where none holds it or none is coloured."""
    n = 2 ** z
    x, y = min(n - 1, int(wx * n)), min(n - 1, int(wy * n))
    pt = ((wx * n - x) * MVT_EXTENT, (wy * n - y) * MVT_EXTENT)
    layers = archive.decoded(z, x, y)
    for name in reversed(LAYERS):
        for f in layers.get(name, []):
            if any(_inside(pt, r) for r in f["rings"]):
                return feature_colour(lf, name, f["tags"], archive.order)
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


def _lum(level, k):
    return -k * math.log(1.0 - min(level, 1 - 1e-12))


def group_levels(lfs):
    """The re-saturated sum of several levels files (LI.36 set operations, as `interactive.py`): per domain and channel the
    luminosities add and the tone map applies once, so exposures compose as 1 - prod(1 - level) and a level never exceeds 1;
    saturation is the luminosity-weighted mean of the members'."""
    k = lfs[0]["tone_k"]
    acc = {}
    for lf in lfs:
        for d, v in lf["ids"].items():
            a = acc.setdefault(d, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
            sums = [_lum(v[0], k), _lum(v[1], k), _lum(v[2], k), _lum(v[4], k)]
            mass = sums[0] + sums[1] + sums[2]
            for j in range(4):
                a[j] += sums[j]
            a[4] += mass * v[3]
            a[5] += mass
    ids = {d: [1 - math.exp(-a[0] / k), 1 - math.exp(-a[1] / k), 1 - math.exp(-a[2] / k), a[4] / a[5] if a[5] > 0 else 1.0,
               1 - math.exp(-a[3] / k)] for d, a in sorted(acc.items())}
    return {"kind": "levels", "v": 1, "basemap": lfs[0]["basemap"], "tone_k": k, "ids": ids}


def compare_levels(a, b):
    """{overlap, a_only, b_only}: levels files holding per domain and channel min(A, B), max(A - B, 0) and max(B - A, 0)
    (as `interactive.compare_levels`; saturation follows the side or sides that carry the colour)."""
    out = {n: {} for n in ("overlap", "a_only", "b_only")}
    for d in sorted(set(a["ids"]) | set(b["ids"])):
        x, y = a["ids"].get(d), b["ids"].get(d)
        u, w = x or [0.0, 0.0, 0.0, 1.0, 0.0], y or [0.0, 0.0, 0.0, 1.0, 0.0]
        ov = [min(u[j], w[j]) for j in (0, 1, 2)]
        ao, bo = [max(u[j] - w[j], 0.0) for j in (0, 1, 2)], [max(w[j] - u[j], 0.0) for j in (0, 1, 2)]
        sat = min(u[3], w[3]) if x and y else u[3] if x else w[3]
        for name, ch, s in (("overlap", ov, sat), ("a_only", ao, u[3]), ("b_only", bo, w[3])):
            if any(ch):
                out[name][d] = [*ch, s, 0.0]
    return {n: {"kind": "levels", "v": 1, "basemap": a["basemap"], "tone_k": a["tone_k"], "ids": ids} for n, ids in out.items()}
