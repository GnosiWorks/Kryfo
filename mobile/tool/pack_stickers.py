#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# compiles a pack's svgs and their motion into one file the app draws.
#
#   tool/stickers/NAME/svg/*.svg    the art, 512 x 512, one layered file each
#   tool/stickers/NAME/anim.txt     the motion
#   assets/stickers/NAME.kst        the output, committed
#   build/stickers/png/NAME/*.png   each still frame, for the pixel test (--png)
#
# usage:
#   pack_stickers.py              build fokia.kst
#   --pack NAME                   work on tool/stickers/NAME instead (default fokia)
#   pack_stickers.py --list 17    every layer's children: index, tag, colour, first point
#   pack_stickers.py --report     sizes, halo pieces, bridges, clearances
#   pack_stickers.py --check      rebuild in memory, compare with the committed file
#   pack_stickers.py --selftest   arcs, dashes, bbox, contours, coverage on known shapes
#   pack_stickers.py --only 01,02 build a subset while iterating (never committed)
#   pack_stickers.py --png [DIR]  build in memory and paint each still frame into
#                                 DIR (build/stickers/png/NAME): 512 x 512 rgba,
#                                 straight alpha, the same bytes every run
#   --blur gauss|box3             how the die-cut blur is made (box3 is svg's own)
#
# run by hand when the art or anim.txt changes, like pack_geo.py. numpy is
# for the outline blur and the pngs; the app never runs any of this.
import hashlib
import math
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
PNG_ROOT = HERE.parent / 'build' / 'stickers' / 'png'

# 1: no title, the app shows the name with a capital. 2: a title after the
# name. a pack without a title line stays 1, so its file does not change
VERSION = 1
VERSION_TITLE = 2
PACK_VERSION = 1
UNIT = 5  # coordinates in 1/32 px
Q = 1 << UNIT

DRAWN = ('g', 'path', 'ellipse', 'circle', 'rect', 'polygon')
SHAPES = ('path', 'ellipse', 'circle', 'rect', 'polygon')
SKIPPED = ('defs', 'clipPath', 'linearGradient', 'radialGradient', 'stop',
           'filter', 'feGaussianBlur', 'feComponentTransfer', 'feFuncA',
           'feFlood', 'feComposite', 'feMerge', 'feMergeNode',
           'feColorMatrix', 'feFuncR', 'feFuncG', 'feFuncB')
REFUSED_ATTRS = ('style', 'class', 'vector-effect', 'stroke-dashoffset',
                 'mask', 'marker-start', 'marker-mid', 'marker-end')

# ops, top 3 bits of a u16 word
OP_SAVE, OP_PUSH, OP_POP, OP_CLIP, OP_DRAW, OP_LAYER = range(6)
PUSH_LAYER = 1 << 12

PROPS = {'x': 0, 'y': 1, 'rot': 2, 'sx': 3, 'sy': 4, 'alpha': 5}
REST = {0: 0.0, 1: 0.0, 2: 0.0, 3: 1.0, 4: 1.0, 5: 1.0}
EASES = {'linear': 0, 'hold': 1, 'sine': 2, 'out': 3, 'in': 4, 'back': 5,
         'inout': 6, 'sineout': 7, 'sinein': 8}

# die-cut filter: white where 30a - 0.6 > 0. traced twice, at a quarter and
# three quarters of the ramp: the outer contour at half alpha under the
# inner one gives the filter's soft 2 px rim with no blur at runtime
SIGMA = 5.5
LEVEL = 1.1 / 30
RIM = ((0.85 / 30, 128), (1.35 / 30, 255))
S = 4          # halo raster, pixels per sticker unit
O = -32.0      # raster origin in sticker units
N = (512 + 64) * S


class Fail(Exception):
    pass


def fail(msg):
    raise Fail(msg)


class Pack:
    # tool/stickers/NAME -> assets/stickers/NAME.kst. the name goes on the
    # wire, so it has the wire's shape
    def __init__(self, name):
        if not re.fullmatch(r'[a-z][a-z0-9]{0,15}', name):
            fail(f'pack {name!r}: a to z and digits, 16 at most, a letter first')
        self.name = name
        self.dir = HERE / 'stickers' / name
        self.out = HERE.parent / 'assets' / 'stickers' / f'{name}.kst'
        self.png = PNG_ROOT / name
        if not (self.dir / 'anim.txt').is_file():
            fail(f'no pack {name}: {self.dir / "anim.txt"} is missing')


# ---- matrices: (a b c d e f), x' = a x + c y + e, y' = b x + d y + f

ID = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def mul(m, n):
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + c * B, b * A + d * B, a * C + c * D, b * C + d * D,
            a * E + c * F + e, b * E + d * F + f)


def ap(m, p):
    return (m[0] * p[0] + m[2] * p[1] + m[4], m[1] * p[0] + m[3] * p[1] + m[5])


def tr(x, y):
    return (1.0, 0.0, 0.0, 1.0, x, y)


def rot(deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (c, s, -s, c, 0.0, 0.0)


def scl(sx, sy):
    return (sx, 0.0, 0.0, sy, 0.0, 0.0)


def similarity(m, where):
    a, b, c, d = m[:4]
    if abs(a - d) > 1e-6 or abs(b + c) > 1e-6:
        fail(f'{where}: skew, mirror or non-uniform scale')
    return math.hypot(a, b), math.degrees(math.atan2(b, a))


def parse_transform(s, where):
    m = ID
    for name, args in re.findall(r'(\w+)\s*\(([^)]*)\)', s):
        v = [float(x) for x in re.split(r'[\s,]+', args.strip()) if x]
        if name == 'translate':
            t = tr(v[0], v[1] if len(v) > 1 else 0.0)
        elif name == 'rotate':
            t = rot(v[0])
            if len(v) == 3:
                t = mul(tr(v[1], v[2]), mul(t, tr(-v[1], -v[2])))
        elif name == 'scale':
            t = scl(v[0], v[1] if len(v) > 1 else v[0])
        elif name == 'matrix':
            t = tuple(v)
        else:
            fail(f'{where}: transform {name}')
        m = mul(m, t)
    similarity(m, where)
    return m


# ---- colours

NAMED = {'white': 0xFFFFFF, 'black': 0x000000}


def colour(v, where):
    v = v.strip()
    if v == 'none':
        return None
    if v.startswith('url(#') and v.endswith(')'):
        return ('url', v[5:-1])
    if re.fullmatch(r'#[0-9a-fA-F]{6}', v):
        return int(v[1:], 16)
    if re.fullmatch(r'#[0-9a-fA-F]{3}', v):
        return int(''.join(ch * 2 for ch in v[1:]), 16)
    if v in NAMED:
        return NAMED[v]
    fail(f'{where}: colour {v!r}')


# ---- paths: a list of subpaths [start, segs, closed]; segs ('L', p),
# ('Q', c, p), ('C', c1, c2, p)

NUMRE = re.compile(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')


class Scan:
    def __init__(self, s):
        self.s, self.i = s, 0

    def skip(self):
        while self.i < len(self.s) and self.s[self.i] in ' \t\r\n,':
            self.i += 1

    def done(self):
        self.skip()
        return self.i >= len(self.s)

    def cmd(self):
        self.skip()
        c = self.s[self.i]
        if not c.isalpha():
            return None
        self.i += 1
        return c

    def more(self):
        self.skip()
        return self.i < len(self.s) and not self.s[self.i].isalpha()

    def num(self):
        self.skip()
        m = NUMRE.match(self.s, self.i)
        if not m:
            fail(f'path: number expected at {self.s[self.i:self.i + 12]!r}')
        self.i = m.end()
        return float(m.group())

    def flag(self):
        self.skip()
        c = self.s[self.i]
        if c not in '01':
            fail('path: arc flag')
        self.i += 1
        return c == '1'


def max_arc_angle(r):
    # a 90 degree cubic is off by 2.7e-4 r; keep every piece under 0.01 px
    if r <= 0:
        return math.pi / 2
    return (math.pi / 2) * min(1.0, (0.01 / (2.7e-4 * r)) ** (1 / 6))


def ellipse_arc(cx, cy, rx, ry, phi, t1, dt, scale, end=None):
    n = max(1, math.ceil(abs(dt) / max_arc_angle(max(rx, ry) * scale) - 1e-9))
    d = dt / n
    k = 4 / 3 * math.tan(d / 4)
    cp, sp = math.cos(phi), math.sin(phi)

    def pt(u, v):
        return (cx + rx * cp * u - ry * sp * v, cy + rx * sp * u + ry * cp * v)
    segs = []
    a = t1
    for i in range(n):
        b = a + d
        ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
        c1 = pt(ca - k * sa, sa + k * ca)
        c2 = pt(cb + k * sb, sb - k * cb)
        p = pt(cb, sb) if (i < n - 1 or end is None) else end
        segs.append(('C', c1, c2, p))
        a = b
    return segs


def arc_segs(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2, scale):
    if abs(x1 - x2) < 1e-12 and abs(y1 - y2) < 1e-12:
        return []
    if rx == 0 or ry == 0:
        return [('L', (x2, y2))]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi_deg)
    cp, sp = math.cos(phi), math.sin(phi)
    dx2, dy2 = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cp * dx2 + sp * dy2
    y1p = -sp * dx2 + cp * dy2
    lam = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den))
    if fa == fs:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not fs and dt > 0:
        dt -= 2 * math.pi
    elif fs and dt < 0:
        dt += 2 * math.pi
    return ellipse_arc(cx, cy, rx, ry, phi, t1, dt, scale, end=(x2, y2))


def parse_d(d, scale):
    sc = Scan(d)
    subs = []
    cur = None
    x = y = sx = sy = 0.0
    lastc = lastq = None  # reflection points for S and T

    def start(px, py):
        nonlocal cur
        cur = [(px, py), [], False]
        subs.append(cur)

    def ensure():
        if cur is None or cur[2]:
            start(x, y)
    while not sc.done():
        c = sc.cmd()
        if c is None:
            fail(f'path: command expected in {d[:40]!r}')
        rel = c.islower()
        C = c.upper()
        if C == 'Z':
            if cur is not None:
                cur[2] = True
            x, y = sx, sy
            lastc = lastq = None
            continue
        first = True
        while first or sc.more():
            first = False
            ox, oy = (x, y) if rel else (0.0, 0.0)
            if C == 'M':
                x, y = sc.num() + ox, sc.num() + oy
                sx, sy = x, y
                start(x, y)
                lastc = lastq = None
                C = 'L'  # extra pairs are lines
                continue
            ensure()
            if C == 'L':
                x, y = sc.num() + ox, sc.num() + oy
                cur[1].append(('L', (x, y)))
                lastc = lastq = None
            elif C == 'H':
                x = sc.num() + ox
                cur[1].append(('L', (x, y)))
                lastc = lastq = None
            elif C == 'V':
                y = sc.num() + oy
                cur[1].append(('L', (x, y)))
                lastc = lastq = None
            elif C == 'C':
                c1 = (sc.num() + ox, sc.num() + oy)
                c2 = (sc.num() + ox, sc.num() + oy)
                x, y = sc.num() + ox, sc.num() + oy
                cur[1].append(('C', c1, c2, (x, y)))
                lastc, lastq = c2, None
            elif C == 'S':
                c1 = (2 * x - lastc[0], 2 * y - lastc[1]) if lastc else (x, y)
                c2 = (sc.num() + ox, sc.num() + oy)
                x, y = sc.num() + ox, sc.num() + oy
                cur[1].append(('C', c1, c2, (x, y)))
                lastc, lastq = c2, None
            elif C == 'Q':
                c1 = (sc.num() + ox, sc.num() + oy)
                x, y = sc.num() + ox, sc.num() + oy
                cur[1].append(('Q', c1, (x, y)))
                lastc, lastq = None, c1
            elif C == 'T':
                c1 = (2 * x - lastq[0], 2 * y - lastq[1]) if lastq else (x, y)
                x, y = sc.num() + ox, sc.num() + oy
                cur[1].append(('Q', c1, (x, y)))
                lastc, lastq = None, c1
            elif C == 'A':
                rx, ry, phi = sc.num(), sc.num(), sc.num()
                fa, fs = sc.flag(), sc.flag()
                nx, ny = sc.num() + ox, sc.num() + oy
                cur[1].extend(arc_segs(x, y, rx, ry, phi, fa, fs, nx, ny, scale))
                x, y = nx, ny
                lastc = lastq = None
            else:
                fail(f'path: command {c}')
    return subs


def ellipse_sub(cx, cy, rx, ry, scale):
    # svg's own start and direction: from cx+rx, clockwise through cx, cy+ry
    return [(cx + rx, cy), ellipse_arc(cx, cy, rx, ry, 0.0, 0.0, 2 * math.pi, scale,
                                       end=(cx + rx, cy)), True]


def num_attr(el, k, default=None):
    v = el.a.get(k)
    if v is None:
        if default is None:
            fail(f'{el.where()}: {k} missing')
        return default
    return float(v)


def shape_subs(el, scale):
    t = el.tag
    if t == 'path':
        return parse_d(el.a['d'], scale)
    if t == 'circle':
        r = num_attr(el, 'r')
        return [ellipse_sub(num_attr(el, 'cx', 0.0), num_attr(el, 'cy', 0.0), r, r, scale)]
    if t == 'ellipse':
        return [ellipse_sub(num_attr(el, 'cx', 0.0), num_attr(el, 'cy', 0.0),
                            num_attr(el, 'rx'), num_attr(el, 'ry'), scale)]
    if t == 'polygon':
        v = [float(x) for x in re.split(r'[\s,]+', el.a['points'].strip()) if x]
        pts = list(zip(v[0::2], v[1::2]))
        return [[pts[0], [('L', p) for p in pts[1:]], True]]
    if t == 'rect':
        x, y = num_attr(el, 'x', 0.0), num_attr(el, 'y', 0.0)
        w, h = num_attr(el, 'width'), num_attr(el, 'height')
        rx = el.a.get('rx')
        ry = el.a.get('ry')
        rx = float(rx) if rx is not None else (float(ry) if ry is not None else 0.0)
        ry = float(ry) if ry is not None else rx
        rx, ry = min(rx, w / 2), min(ry, h / 2)
        if rx <= 0 or ry <= 0:
            return [[(x, y), [('L', (x + w, y)), ('L', (x + w, y + h)), ('L', (x, y + h))], True]]
        segs = [('L', (x + w - rx, y))]
        segs += arc_segs(x + w - rx, y, rx, ry, 0, False, True, x + w, y + ry, scale)
        segs.append(('L', (x + w, y + h - ry)))
        segs += arc_segs(x + w, y + h - ry, rx, ry, 0, False, True, x + w - rx, y + h, scale)
        segs.append(('L', (x + rx, y + h)))
        segs += arc_segs(x + rx, y + h, rx, ry, 0, False, True, x, y + h - ry, scale)
        segs.append(('L', (x, y + ry)))
        segs += arc_segs(x, y + ry, rx, ry, 0, False, True, x + rx, y, scale)
        return [[(x + rx, y), segs, True]]
    fail(f'{el.where()}: shape {t}')


def xform(subs, m):
    return [[ap(m, s), [(g[0],) + tuple(ap(m, p) for p in g[1:]) for g in segs], closed]
            for s, segs, closed in subs]


def bez_eval(ctrl, t):
    t = np.asarray(t, dtype=float)[:, None]
    c = np.asarray(ctrl, dtype=float)
    if len(c) == 3:
        u = 1 - t
        return u * u * c[0] + 2 * u * t * c[1] + t * t * c[2]
    u = 1 - t
    return u ** 3 * c[0] + 3 * u * u * t * c[1] + 3 * u * t * t * c[2] + t ** 3 * c[3]


def seg_ctrl(p0, g):
    return [p0] + list(g[1:])


def seg_extrema(p0, g):
    # parameter values where x or y is extreme inside (0, 1)
    ts = []
    c = np.asarray(seg_ctrl(p0, g), dtype=float)
    for k in (0, 1):
        v = c[:, k]
        if len(v) == 3:
            den = v[0] - 2 * v[1] + v[2]
            if abs(den) > 1e-12:
                ts.append((v[0] - v[1]) / den)
        elif len(v) == 4:
            a = -v[0] + 3 * v[1] - 3 * v[2] + v[3]
            b = 2 * (v[0] - 2 * v[1] + v[2])
            cc = v[1] - v[0]
            if abs(a) < 1e-12:
                if abs(b) > 1e-12:
                    ts.append(-cc / b)
            else:
                disc = b * b - 4 * a * cc
                if disc >= 0:
                    r = math.sqrt(disc)
                    ts += [(-b + r) / (2 * a), (-b - r) / (2 * a)]
    return [t for t in ts if 0 < t < 1]


def bbox(subs):
    xs, ys = [], []
    for s, segs, _ in subs:
        xs.append(s[0])
        ys.append(s[1])
        p0 = s
        for g in segs:
            xs.append(g[-1][0])
            ys.append(g[-1][1])
            if g[0] != 'L':
                ts = seg_extrema(p0, g)
                if ts:
                    pts = bez_eval(seg_ctrl(p0, g), ts)
                    xs += list(pts[:, 0])
                    ys += list(pts[:, 1])
            p0 = g[-1]
    return min(xs), min(ys), max(xs), max(ys)


def seg_split(p0, g, t0, t1):
    # the piece of a segment between t0 and t1: (start, seg)
    c = [np.asarray(p, dtype=float) for p in seg_ctrl(p0, g)]
    if g[0] == 'L':
        a = c[0] + (c[1] - c[0]) * t0
        b = c[0] + (c[1] - c[0]) * t1
        return tuple(a), ('L', tuple(b))

    def split(cs, t):
        left, right = [cs[0]], [cs[-1]]
        cur = cs
        while len(cur) > 1:
            cur = [cur[i] + (cur[i + 1] - cur[i]) * t for i in range(len(cur) - 1)]
            left.append(cur[0])
            right.append(cur[-1])
        return left, right[::-1]
    _, right = split(c, t0)
    if t1 < 1:
        u = (t1 - t0) / (1 - t0) if t0 < 1 else 0
        right, _ = split(right, u)
    pts = [tuple(p) for p in right]
    return pts[0], (g[0],) + tuple(pts[1:])


def seg_table(p0, g, n=64):
    if g[0] == 'L':
        ln = math.dist(p0, g[1])
        return np.array([0.0, 1.0]), np.array([0.0, ln])
    ts = np.linspace(0, 1, n + 1)
    pts = bez_eval(seg_ctrl(p0, g), ts)
    d = np.hypot(*np.diff(pts, axis=0).T)
    return ts, np.concatenate([[0.0], np.cumsum(d)])


def dash_subs(subs, pattern):
    if len(pattern) % 2:
        pattern = pattern * 2
    if sum(pattern) <= 0:
        return subs
    out = []
    for start, segs, closed in subs:
        segs = list(segs)
        last = segs[-1][-1] if segs else start
        if closed and math.dist(last, start) > 1e-9:
            segs.append(('L', start))
        pi, left, on, cur = 0, pattern[0], True, None
        p0 = start
        for g in segs:
            ts, ls = seg_table(p0, g)
            total = ls[-1]
            pos = 0.0
            while pos < total - 1e-9:
                step = min(left, total - pos)
                if on:
                    t0 = float(np.interp(pos, ls, ts))
                    t1 = float(np.interp(pos + step, ls, ts))
                    a, piece = seg_split(p0, g, t0, t1)
                    if cur is None:
                        cur = [a, [], False]
                        out.append(cur)
                    cur[1].append(piece)
                pos += step
                left -= step
                if left <= 1e-9:
                    pi = (pi + 1) % len(pattern)
                    left = pattern[pi]
                    on = not on
                    if not on:
                        cur = None
            p0 = g[-1]
    return out


# ---- the svg tree

class El:
    def __init__(self, tag, a, parent, svg):
        self.tag, self.a, self.parent, self.svg = tag, dict(a), parent, svg
        self.kids = []
        self.id = None
        self.local = ID
        self.clip = None
        self.tint = None  # a colour filter's id
        self.made = False  # made by this tool (lids)

    def where(self):
        path = []
        e = self
        while e.parent is not None:
            if e.id:
                path.append(e.id)
                break
            kids = e.parent.kids
            path.append(f'[{kids.index(e) if e in kids else len(kids)}]')
            e = e.parent
        return f'{self.svg.name}: {"".join(reversed(path)) or self.tag}'

    def ctm(self):
        m = ID
        chain = []
        e = self
        while e is not None:
            chain.append(e)
            e = e.parent
        for e in reversed(chain):
            m = mul(m, e.local)
        return m

    def leaves(self):
        if self.tag != 'g':
            yield self
        for k in self.kids:
            yield from k.leaves()


class Svg:
    def __init__(self, path):
        self.path = path
        self.name = path.name
        self.ids, self.dups, self.grads, self.clips = {}, [], {}, {}
        self.tints = {}
        diecuts = set()
        root = ET.parse(path).getroot()

        def strip(t):
            return t.split('}')[-1]
        for e in root.iter():
            t = strip(e.tag)
            for k in REFUSED_ATTRS:
                if k in e.attrib:
                    fail(f'{self.name}: {t} has {k}')
            if t in ('linearGradient', 'radialGradient'):
                self.grads[e.get('id')] = self.parse_grad(e, t)
            elif t == 'clipPath':
                kids = [c for c in e if strip(c.tag) in SHAPES]
                if len(kids) != 1 or len(e) != 1:
                    fail(f'{self.name}: clipPath {e.get("id")} needs exactly one shape')
                if e.get('clipPathUnits', 'userSpaceOnUse') != 'userSpaceOnUse' or 'transform' in kids[0].attrib:
                    fail(f'{self.name}: clipPath {e.get("id")} units or transform')
                ce = El(strip(kids[0].tag), kids[0].attrib, None, self)
                self.clips[e.get('id')] = (ce, kids[0].get('clip-rule', 'nonzero'))
            elif t not in DRAWN and t not in SKIPPED and t != 'svg':
                fail(f'{self.name}: element {t}')
            if t == 'filter':
                prims = [strip(c.tag) for c in e]
                if prims == ['feGaussianBlur', 'feComponentTransfer', 'feFlood', 'feComposite', 'feMerge']:
                    blur = e[0]
                    if abs(float(blur.get('stdDeviation')) - SIGMA) > 1e-9:
                        fail(f'{self.name}: blur {blur.get("stdDeviation")}')
                    fa = e[1][0]
                    if (fa.get('slope'), fa.get('intercept')) != ('30', '-0.6'):
                        fail(f'{self.name}: die-cut transfer changed')
                    diecuts.add(e.get('id'))
                else:
                    self.tints[e.get('id')] = self.parse_tint(e)
        vb = root.get('viewBox', '').split()
        if vb != ['0', '0', '512', '512']:
            fail(f'{self.name}: viewBox {vb}')
        # the character's group: #fokia in every pack, the remix too
        fok = [e for e in root.iter() if e.get('id') == 'fokia']
        if len(fok) != 1 or fok[0].get('filter', '')[5:-1] not in diecuts:
            fail(f'{self.name}: no #fokia group with the die-cut')

        def build(e, parent):
            el = El(strip(e.tag), e.attrib, parent, self)
            if 'id' in e.attrib:
                name = e.get('id')
                if name in self.ids:
                    n = 2
                    while f'{name}#{n}' in self.ids:
                        n += 1
                    name = f'{name}#{n}'
                    self.dups.append(name)
                self.ids[name] = el
                el.id = name
            if 'transform' in e.attrib:
                el.local = parse_transform(e.get('transform'), el.where())
            if 'clip-path' in e.attrib:
                v = e.get('clip-path')
                if not (v.startswith('url(#') and v.endswith(')')) or v[5:-1] not in self.clips:
                    fail(f'{self.name}: clip-path {v}')
                el.clip = v[5:-1]
            if 'filter' in e.attrib and e is not fok[0]:
                v = e.get('filter')
                if not (v.startswith('url(#') and v.endswith(')')) or v[5:-1] not in self.tints:
                    fail(f'{el.where()}: filter {v}')
                el.tint = v[5:-1]
            for c in e:
                if strip(c.tag) in DRAWN:
                    el.kids.append(build(c, el))
            return el
        self.fokia = build(fok[0], None)
        if len(self.fokia.kids) != 1 or self.fokia.kids[0].tag != 'g':
            fail(f'{self.name}: #fokia should hold one transformed group')
        self.top = self.fokia.kids[0]
        body = self.ids.get('body')
        self.root = body.parent if body is not None else self.top

    def parse_grad(self, e, t):
        def strip(x):
            return x.split('}')[-1]
        if e.get('gradientTransform') or e.get('href') or e.get('{http://www.w3.org/1999/xlink}href'):
            fail(f'{self.name}: gradient {e.get("id")} transform or href')
        if e.get('spreadMethod', 'pad') != 'pad':
            fail(f'{self.name}: gradient spread')
        units = e.get('gradientUnits', 'objectBoundingBox')

        def f(k, d):
            v = e.get(k)
            if v is None:
                return d
            return float(v[:-1]) / 100 if v.endswith('%') else float(v)
        if t == 'linearGradient':
            geo = (f('x1', 0.0), f('y1', 0.0), f('x2', 1.0), f('y2', 0.0))
            kind = 0
        else:
            cx, cy = f('cx', 0.5), f('cy', 0.5)
            if f('fx', cx) != cx or f('fy', cy) != cy:
                fail(f'{self.name}: radial focus')
            geo = (cx, cy, f('r', 0.5), 0.0)
            kind = 1
        stops = []
        last = 0.0
        for s in e:
            if strip(s.tag) != 'stop':
                continue
            o = s.get('offset', '0')
            o = float(o[:-1]) / 100 if o.endswith('%') else float(o)
            o = max(last, min(1.0, o))
            last = o
            c = colour(s.get('stop-color', '#000000'), self.name)
            stops.append((o, c, float(s.get('stop-opacity', '1'))))
        return (kind, geo, units, stops)

    def parse_tint(self, e):
        # a filter that only changes colour (a saturate, linear curves on r g
        # b) acts on each pixel alone, so it is baked into the colours under
        # it. anything else would need the filter at runtime: refused
        def strip(x):
            return x.split('}')[-1]
        fid = e.get('id')
        if e.get('color-interpolation-filters') != 'sRGB':
            fail(f'{self.name}: filter {fid} is not in srgb')
        for k in ('x', 'y', 'width', 'height', 'filterUnits', 'primitiveUnits'):
            if k in e.attrib:
                fail(f'{self.name}: filter {fid} has a region')
        steps = []
        for p in e:
            t = strip(p.tag)
            if any(k in p.attrib for k in ('in', 'in2', 'result')):
                fail(f'{self.name}: filter {fid}: {t} is not a plain chain')
            if t == 'feColorMatrix' and p.get('type') == 'saturate':
                steps.append(('saturate', float(p.get('values', '1'))))
            elif t == 'feComponentTransfer':
                curves = {}
                for f in p:
                    ft = strip(f.tag)
                    if ft not in ('feFuncR', 'feFuncG', 'feFuncB') or f.get('type') != 'linear':
                        fail(f'{self.name}: filter {fid}: {ft} {f.get("type")}')
                    curves['RGB'.index(ft[-1])] = (float(f.get('slope', '1')),
                                                   float(f.get('intercept', '0')))
                steps.append(('linear', curves))
            else:
                fail(f'{self.name}: filter {fid}: {t} {p.get("type", "")}')
        if not steps:
            fail(f'{self.name}: filter {fid} is empty')
        return steps


def tinted(rgb, steps):
    # one colour through a colour filter, as svg does it on srgb values:
    # every primitive's result clamped to 0..1
    c = [((rgb >> 16) & 255) / 255, ((rgb >> 8) & 255) / 255, (rgb & 255) / 255]
    for kind, v in steps:
        if kind == 'saturate':
            s = v
            r, g, b = c
            c = [(0.213 + 0.787 * s) * r + (0.715 - 0.715 * s) * g + (0.072 - 0.072 * s) * b,
                 (0.213 - 0.213 * s) * r + (0.715 + 0.285 * s) * g + (0.072 - 0.072 * s) * b,
                 (0.213 - 0.213 * s) * r + (0.715 - 0.715 * s) * g + (0.072 + 0.928 * s) * b]
        else:
            c = [v[i][0] * c[i] + v[i][1] if i in v else c[i] for i in range(3)]
        c = [min(1.0, max(0.0, x)) for x in c]
    r, g, b = (round(x * 255) for x in c)
    return (r << 16) | (g << 8) | b


def fingerprint(els):
    for e in els:
        for leaf in e.leaves():
            a = leaf.a
            if leaf.tag == 'path':
                v = NUMRE.findall(a['d'])
                return float(v[0]), float(v[1])
            if leaf.tag in ('circle', 'ellipse'):
                return float(a.get('cx', 0)), float(a.get('cy', 0))
            if leaf.tag == 'rect':
                return float(a.get('x', 0)), float(a.get('y', 0))
            if leaf.tag == 'polygon':
                v = NUMRE.findall(a['points'])
                return float(v[0]), float(v[1])
    return None


def select(svg, sel, where):
    m = re.fullmatch(r'([A-Za-z_][\w-]*(?:#\d+)?)((?:\[[^\]]+\])*)', sel)
    if not m:
        fail(f'{where}: selector {sel!r}')
    base = m.group(1)
    if base == 'top':
        el = svg.top
    elif base == 'root':
        el = svg.root
    elif base in svg.ids:
        el = svg.ids[base]
    else:
        fail(f'{where}: no layer {base!r}')
    els = [el]
    for p in re.findall(r'\[([^\]]+)\]', m.group(2)):
        if len(els) != 1:
            fail(f'{where}: a slice must come last in {sel!r}')
        kids = els[0].kids
        if ':' in p:
            a, b = (int(x) for x in p.split(':'))
            if not (0 <= a < b <= len(kids)):
                fail(f'{where}: {sel!r} out of range ({len(kids)} children)')
            els = kids[a:b]
        else:
            i = int(p)
            if not (0 <= i < len(kids)):
                fail(f'{where}: {sel!r} out of range ({len(kids)} children)')
            els = [kids[i]]
    return els


def geom_subs(el, m):
    # every shape under el in the space m maps el's parent to
    out = []
    mm = mul(m, el.local)
    if el.tag == 'g':
        for k in el.kids:
            out += geom_subs(k, mm)
    else:
        out += xform(shape_subs(el, 1.0), mm)
    return out


# ---- easing and tracks, the same maths as sticker_player.dart

def ease(code, u):
    if u <= 0:
        return 0.0
    if u >= 1:
        return 1.0
    if code == 0:
        return u
    if code == 1:
        return 0.0
    if code == 2:
        return -(math.cos(math.pi * u) - 1) / 2
    if code == 3:
        return 1 - (1 - u) ** 3
    if code == 4:
        return u ** 3
    if code == 5:
        c1 = 1.70158
        return 1 + (c1 + 1) * (u - 1) ** 3 + c1 * (u - 1) ** 2
    if code == 6:
        return 4 * u ** 3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2
    if code == 7:
        return math.sin(u * math.pi / 2)
    if code == 8:
        return 1 - math.cos(u * math.pi / 2)
    fail(f'ease {code}')


def track_at(keys, t):
    if t <= keys[0][0]:
        return keys[0][1]
    for i in range(len(keys) - 1):
        t0, v0, _ = keys[i]
        t1, v1, e = keys[i + 1]
        if t0 <= t < t1:
            if t == t0:
                return v0
            return v0 + (v1 - v0) * ease(e, (t - t0) / (t1 - t0))
    return keys[-1][1]


def qvalue(prop, v):
    if prop in (0, 1):
        return round(v * Q)
    if prop == 2:
        return round(v * 100)
    return round(v * 10000)


def dqvalue(prop, q):
    if prop in (0, 1):
        return q / Q
    if prop == 2:
        return q / 100
    return q / 10000


# ---- anim.txt

class Node:
    def __init__(self, name, els, pivot, line):
        self.name, self.els, self.pivot_in, self.line = name, els, pivot, line
        self.index = -1
        self.parent = None
        self.hidden = False
        self.internal = False  # lids and pupils: no amplitude lint
        self.body = False
        self.pivot = (0.0, 0.0)
        self.frame = 0.0
        self.k = 1.0
        self.travel = 0.0  # a lid's way down

    def matrix(self, vals):
        x, y, r, sx, sy = vals[0], vals[1], vals[2], vals[3], vals[4]
        p = self.pivot
        m = tr(p[0], p[1])
        m = mul(m, rot(self.frame))
        m = mul(m, tr(self.k * x, self.k * y))
        m = mul(m, rot(r))
        m = mul(m, scl(sx, sy))
        m = mul(m, rot(-self.frame))
        return mul(m, tr(-p[0], -p[1]))


class Sticker:
    def __init__(self, num, name, loop, emoji, since, line):
        self.num, self.name, self.loop, self.emoji, self.since = num, name, loop, emoji, since
        self.line = line
        self.nodes = []
        self.named = {}
        self.tracks = {}  # (node, prop) -> [(t, v, ease)]
        self.waived = set()  # (node, prop) allowed past the limits
        self.clears = []
        self.cmds = []
        self.svg = None


def parse_pair(s, where):
    try:
        a, b = s.split(',')
        return float(a), float(b)
    except ValueError:
        fail(f'{where}: pair {s!r}')


class Anim:
    def __init__(self, path):
        self.pivots = {}
        self.stickers = {}
        # the name the picker shows; none: the pack name with a capital
        self.title = None
        cur = None
        for no, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            where = f'anim.txt:{no}'
            words = line.split()
            if words[0] == 'title' and not raw[0].isspace():
                if self.title is not None or len(words) < 2:
                    fail(f'{where}: one title, with words')
                self.title = ' '.join(words[1:])
                if len(self.title.encode('utf-8')) > 64:
                    fail(f'{where}: a title of 64 bytes at most')
            elif words[0] == 'pivot' and not raw[0].isspace():
                self.pivots[words[1]] = parse_pair(words[2], where)
            elif words[0] == 'sticker':
                kv = dict(w.split('=', 1) for w in words[3:])
                num = int(words[1])
                cur = Sticker(num, words[2], int(kv.get('loop', 0)), kv['emoji'],
                              int(kv.get('since', 1)), where)
                if num in self.stickers:
                    fail(f'{where}: sticker {num} twice')
                self.stickers[num] = cur
            else:
                if cur is None or not raw[0].isspace():
                    fail(f'{where}: {words[0]} outside a sticker')
                cur.cmds.append((where, words))


# macros, expanded into nodes and tracks against the loaded svg

def pivot_of(anim, spec, where):
    if spec in anim.pivots:
        return anim.pivots[spec]
    return parse_pair(spec, where)


class Build:
    def __init__(self, anim, st, svg):
        self.anim, self.st, self.svg = anim, st, svg

    def node(self, name, els, pivot, where, fp=None):
        if fp is not None:
            got = fingerprint(els)
            if got is None or abs(got[0] - fp[0]) > 0.05 or abs(got[1] - fp[1]) > 0.05:
                fail(f'{where}: fingerprint {fp} does not match {got}: the art moved')
        if pivot is None:
            # the middle of the selection, in its parent's space
            subs = []
            for e in els:
                subs += geom_subs(e, ID)
            x0, y0, x1, y1 = bbox(subs)
            pivot = ((x0 + x1) / 2, (y0 + y1) / 2)
        for e in els:
            if e.parent is not els[0].parent:
                fail(f'{where}: a node takes siblings only')
        n = Node(name, els, pivot, where)
        n.body = any(e.id in ('body', 'head') or self.is_above_root(e) for e in els)
        self.st.nodes.append(n)
        if name:
            self.st.named[name] = n
        return n

    def is_above_root(self, e):
        r = self.svg.root
        while r is not None:
            if r is e:
                return True
            r = r.parent
        return False

    def target(self, spec, pivot, where):
        if spec in self.st.named:
            n = self.st.named[spec]
            if pivot is not None and pivot != n.pivot_in:
                fail(f'{where}: {spec} already has a pivot')
            return n
        els = select(self.svg, spec, where)
        for n in self.st.nodes:
            if n.name is None and n.els == els and (pivot is None or n.pivot_in == pivot):
                return n
        return self.node(None, els, pivot, where)

    def keys(self, n, prop, keys, where, waive=False):
        k = self.st.tracks.setdefault((n, prop), [])
        for t, v, e in keys:
            if k and t <= k[-1][0]:
                if t == k[-1][0] and abs(v - k[-1][1]) < 1e-9:
                    continue
                fail(f'{where}: key times must rise ({t} after {k[-1][0]})')
            k.append((t, v, e))
        if waive:
            self.st.waived.add((n, prop))

    def run(self):
        for where, w in self.st.cmds:
            opts = {}
            args = []
            waive = False
            for x in w[1:]:
                if x == '!':
                    waive = True
                elif '=' in x:
                    k, v = x.split('=', 1)
                    opts[k] = v
                else:
                    args.append(x)
            piv = pivot_of(self.anim, opts['pivot'], where) if 'pivot' in opts else None
            cmd = w[0]
            if cmd == 'node':
                fp = None
                rest = []
                for a in args[2:]:
                    if a.startswith('@'):
                        fp = parse_pair(a[1:], where)
                    else:
                        rest.append(a)
                if rest:
                    fail(f'{where}: node takes a name, a selector, @x,y and pivot=')
                if args[0] in self.st.named:
                    fail(f'{where}: node {args[0]} twice')
                self.node(args[0], select(self.svg, args[1], where), piv, where, fp)
            elif cmd in PROPS or cmd == 'scale':
                n = self.target(args[0], piv, where)
                e = EASES[opts.get('ease', 'sine')]
                keys = []
                for kv in args[1:]:
                    parts = kv.split(':')
                    t, v = float(parts[0]), float(parts[1])
                    ke = EASES[parts[2]] if len(parts) > 2 else e
                    keys.append((t, v, ke))
                for p in (('sx', 'sy') if cmd == 'scale' else (cmd,)):
                    self.keys(n, PROPS[p], keys, where, waive)
            elif cmd == 'clear':
                self.st.clears.append((self.target(args[0], None, where),
                                       self.target(args[1], None, where),
                                       float(args[2]), where))
            else:
                fn = getattr(self, 'm_' + cmd, None)
                if fn is None:
                    fail(f'{where}: unknown {cmd}')
                fn(args, opts, piv, where, waive)

    # -- the macros

    def open_eyes(self, where):
        eyes = self.svg.ids.get('eyes')
        out = []
        if eyes is None:
            return out
        for g in eyes.kids:
            if g.tag != 'g' or g.clip is None:
                continue
            ce, _ = self.svg.clips[g.clip]
            if ce.tag != 'ellipse':
                continue
            cx, cy = float(ce.a['cx']), float(ce.a['cy'])
            rx, ry = float(ce.a['rx']), float(ce.a['ry'])
            art = None
            k = g.kids
            if (len(k) >= 4 and k[-2].tag == 'path' and k[-2].a.get('fill') == '#E2D6C4'
                    and k[-1].tag == 'path' and k[-1].a.get('fill') == 'none'):
                art = k[-2:]
            out.append((g, cx, cy, rx, ry, art))
        if not out:
            fail(f'{where}: no open eyes')
        return out

    def m_blink(self, args, opts, piv, where, waive):
        # the upper lid comes down and a lower one comes up to meet it a
        # little under the middle: a shut eye is lid colour with a lash line
        # across it, in the art's own lid idiom (#E2D6C4, a 6 px line)
        t = float(args[0])
        slow = len(args) > 1 and args[1] == 'slow'
        din, hold, dout = (110, 60, 160) if slow else (70, 40, 110)
        for i, (g, cx, cy, rx, ry, art) in enumerate(self.open_eyes(where)):
            name = f'lid{i}'
            if name in self.st.named:
                up = self.st.named[name]
                low = self.st.named[f'lowlid{i}']
            else:
                meet = cy + ry * 0.35
                if art:
                    line = parse_d(art[1].a['d'], 1.0)
                    pts = [p for s_, segs, _ in line for p in [s_] + [q[-1] for q in segs]]
                    if len(pts) != 2:
                        fail(f'{where}: an art lid line should be one straight line')
                    (lx0, ly0), (lx1, ly1) = pts
                    travel = meet - (ly0 + ly1) / 2
                    # the lid's top edge goes up by the travel: outside the
                    # eye at rest, and never inside it when the lid comes down
                    subs = parse_d(art[0].a['d'], 1.0)
                    if any(q[0] != 'L' for _, segs, _ in subs for q in segs):
                        fail(f'{where}: an art lid should be straight lines')
                    top = min(p[1] for s_, segs, _ in subs for p in [s_] + [q[-1] for q in segs])
                    d = ''
                    for s_, segs, _ in subs:
                        ring = [s_] + [q[-1] for q in segs]
                        d += 'M' + ' L'.join(f'{x:g},{(y - travel if abs(y - top) < 1e-6 else y):g}'
                                             for x, y in ring) + 'Z'
                    art[0].a['d'] = d
                    upper = art
                    at = g.kids.index(art[0])
                else:
                    y0 = cy - ry - 3
                    lx0, ly0, lx1, ly1 = cx - rx - 4, y0, cx + rx + 4, y0
                    travel = meet - y0
                    h = 2 * ry + 12
                    lid = El('path', {'d': f'M{lx0:g},{y0 - h:g} L{lx1:g},{y0 - h:g} '
                                           f'L{lx1:g},{y0:g} L{lx0:g},{y0:g}Z',
                                      'fill': '#E2D6C4'}, g, self.svg)
                    ln = El('path', {'d': f'M{lx0:g},{y0:g} L{lx1:g},{y0:g}', 'fill': 'none',
                                     'stroke': '#0D0B09', 'stroke-width': '6'}, g, self.svg)
                    lid.made = ln.made = True
                    g.kids += [lid, ln]
                    upper = [lid, ln]
                    at = len(g.kids) - 2
                # the lower lid: the line's own slope, parked under the eye
                d0 = cy + ry + 4 - min(ly0, ly1)
                hl = ry + 12
                lower = El('path', {'d': f'M{lx0:g},{ly0 + d0:g} L{lx1:g},{ly1 + d0:g} '
                                         f'L{lx1:g},{max(ly0, ly1) + d0 + hl:g} '
                                         f'L{lx0:g},{max(ly0, ly1) + d0 + hl:g}Z',
                                    'fill': '#E2D6C4'}, g, self.svg)
                lower.made = True
                g.kids.insert(at, lower)
                up = self.node(name, upper, (cx, cy), where)
                up.hidden = not art
                up.travel = travel
                low = self.node(f'lowlid{i}', [lower], (cx, cy), where)
                low.hidden = True
                low.travel = travel - d0
                up.internal = low.internal = True
            for n in (up, low):
                self.keys(n, PROPS['y'], [(t, 0.0, 0), (t + din, n.travel, EASES['in']),
                                          (t + din + hold, n.travel, 0),
                                          (t + din + hold + dout, 0.0, EASES['out'])], where)

    def m_look(self, args, opts, piv, where, waive):
        t = float(args[0])
        dx, dy = parse_pair(args[1], where)
        dur = float(args[2])
        if math.hypot(dx, dy) > 4 and not waive:
            fail(f'{where}: a look is at most 4 px')
        for i, (g, cx, cy, rx, ry, art) in enumerate(self.open_eyes(where)):
            name = f'pupil{i}'
            n = self.st.named.get(name)
            if n is None:
                n = self.node(name, g.kids[0:2], (cx, cy), where)
                n.internal = True
            for p, v in ((0, dx), (1, dy)):
                k = self.st.tracks.get((n, p))
                prev = k[-1][1] if k else 0.0
                self.keys(n, p, [(t, prev, 0), (t + dur, v, EASES['sine'])], where)

    def m_tuft(self, args, opts, piv, where, waive):
        t = float(args[0])
        for sel, fp, p, delay in (('head[3]', (250, 80), (260, 80), 0),
                                  ('head[4]', (230, 86), (231, 86), 40)):
            els = select(self.svg, sel, where)
            got = fingerprint(els)
            if got is None or math.dist(got, fp) > 0.05:
                fail(f'{where}: {sel} is not the tuft here')
            n = self.target(sel, p, where)
            s = t + delay
            self.keys(n, 2, [(s, 0.0, 0), (s + 120, -6.0, EASES['sine']),
                             (s + 280, 3.0, EASES['sine']), (s + 420, 0.0, EASES['sine'])], where)

    def m_breathe(self, args, opts, piv, where, waive):
        s = float(args[0])
        n = self.target('root', piv or self.anim.pivots['root'], where)
        L = self.st.loop
        self.keys(n, 4, [(0, 1.0, 0), (L / 2, s, EASES['sine']), (L, 1.0, EASES['sine'])], where, waive)
        self.keys(n, 3, [(0, 1.0, 0), (L / 2, 1 - (s - 1) / 2, EASES['sine']),
                         (L, 1.0, EASES['sine'])], where, waive)

    def wave(self, a, t0, t1, cycles):
        # a true sine from rest: 0, a, 0, -a, 0 per cycle
        keys = [(t0, 0.0, 0)]
        per = (t1 - t0) / cycles
        for c in range(cycles):
            b = t0 + c * per
            keys += [(b + per / 4, a, EASES['sineout']), (b + per / 2, 0.0, EASES['sinein']),
                     (b + 3 * per / 4, -a, EASES['sineout']), (b + per, 0.0, EASES['sinein'])]
        return keys

    def m_sway(self, args, opts, piv, where, waive):
        n = self.target(args[0], piv, where)
        self.keys(n, 2, self.wave(float(args[1]), 0, self.st.loop, 1), where, waive)

    def m_shiver(self, args, opts, piv, where, waive):
        n = self.target(args[0], piv, where)
        a, per, t0, t1 = (float(x) for x in args[1:5])
        cycles = round((t1 - t0) / per)
        if abs(cycles * per - (t1 - t0)) > 1e-6:
            fail(f'{where}: whole periods only')
        prop = PROPS[opts.get('prop', 'rot')]
        self.keys(n, prop, self.wave(a, t0, t1, cycles), where, waive)

    def m_pulse(self, args, opts, piv, where, waive):
        n = self.target(args[0], piv, where)
        s, t0, t1 = float(args[1]), float(args[2]), float(args[3])
        peak = t0 + 0.4 * (t1 - t0)
        for p in (3, 4):
            self.keys(n, p, [(t0, 1.0, 0), (peak, s, EASES[opts.get('ease', 'out')]),
                             (t1, 1.0, EASES['inout'])], where, waive)

    def m_twinkle(self, args, opts, piv, where, waive):
        n = self.target(args[0], piv, where)
        t = float(args[1])
        for p in (3, 4):
            self.keys(n, p, [(t, 1.0, 0), (t + 140, 1.2, EASES['back']), (t + 400, 1.0, EASES['sine'])],
                      where, waive)
        self.keys(n, 2, [(t, 0.0, 0), (t + 140, 14.0, EASES['back']), (t + 400, 0.0, EASES['sine'])],
                  where, waive)

    def m_drop(self, args, opts, piv, where, waive):
        # falls, shrinking away over the last third, then pops back in at
        # the top. a fade would leave a ghost of its white outline
        n = self.target(args[0], piv, where)
        dy, t0, t1 = float(args[1]), float(args[2]), float(args[3])
        shrink = t0 + 0.65 * (t1 - t0)
        back = float(opts.get('back', 260))
        self.keys(n, 1, [(t0, 0.0, 0), (t1, dy, EASES['in']), (t1 + 1, 0.0, EASES['hold'])], where, waive)
        for p in (3, 4):
            self.keys(n, p, [(t0, 1.0, 0), (shrink, 1.0, 0), (t1, 0.2, EASES['in']),
                             (t1 + 1, 0.0, EASES['hold']), (t1 + 1 + back, 1.0, EASES['back'])],
                      where, True)

    def m_squeeze(self, args, opts, piv, where, waive):
        t = float(args[0])
        eyes = self.svg.ids.get('eyes')
        arcs = [k for k in eyes.kids if k.tag == 'path'] if eyes else []
        if len(arcs) != 1:
            fail(f'{where}: squeeze wants exactly one wink arc')
        n = self.target(f'eyes[{eyes.kids.index(arcs[0])}]', None, where)
        self.keys(n, 4, [(t, 1.0, 0), (t + 120, 0.82, EASES['sine']), (t + 300, 1.0, EASES['sine'])], where)


# ---- the compiled sticker

class Out:
    def __init__(self, palette):
        self.palette = palette
        self.paths, self.path_ix = [], {}
        self.shaders, self.shader_ix = [], {}
        self.paints, self.paint_ix = [], {}
        self.ops = []
        self.draws = []  # for the halo: dict per draw

    def colour_ix(self, rgb):
        if rgb not in self.palette:
            self.palette[rgb] = len(self.palette)
        return self.palette[rgb]

    def path(self, subs, evenodd):
        verbs, pts = [], []
        for s, segs, closed in subs:
            verbs.append(0)
            pts.append(s)
            for g in segs:
                verbs.append({'L': 1, 'Q': 2, 'C': 3}[g[0]])
                pts += g[1:]
            if closed:
                verbs.append(4)
        q = tuple((round(x * Q), round(y * Q)) for x, y in pts)
        for x, y in q:
            if not (-32768 <= x <= 32767 and -32768 <= y <= 32767):
                fail('a point is out of range')
        key = (1 if evenodd else 0, tuple(verbs), q)
        if key not in self.path_ix:
            self.path_ix[key] = len(self.paths)
            self.paths.append(key)
        return self.path_ix[key]

    def shader(self, key):
        if key not in self.shader_ix:
            self.shader_ix[key] = len(self.shaders)
            self.shaders.append(key)
        return self.shader_ix[key]

    def paint(self, key):
        if key not in self.paint_ix:
            self.paint_ix[key] = len(self.paints)
            self.paints.append(key)
        return self.paint_ix[key]

    def op(self, code, arg=0):
        if not (0 <= arg < (1 << 13)):
            fail('op operand out of range')
        self.ops.append((code << 13) | arg)


def compile_sticker(anim, st, svg, palette, blur, report):
    st.svg = svg
    b = Build(anim, st, svg)
    b.run()
    nodes = st.nodes
    for i, n in enumerate(nodes):
        n.index = i
        if i >= (1 << 12):
            fail('too many nodes')

    # nesting: a node's parent is the innermost node around its elements
    def contains(a, bn):
        if a is bn:
            return False
        if a.els == bn.els:
            return nodes.index(a) < nodes.index(bn)
        for e in bn.els:
            x = e
            while x is not None and x not in a.els:
                x = x.parent
            if x is None:
                return False
        return True
    for n in nodes:
        outer = [a for a in nodes if contains(a, n)]
        n.parent = None
        # the innermost: inside all the others
        for a in outer:
            if all(a is c or contains(c, a) for c in outer):
                n.parent = a
    for n in nodes:
        pm = n.els[0].parent.ctm()
        k, fr = similarity(pm, n.line)
        n.k, n.frame = k, fr
        n.pivot = ap(pm, n.pivot_in)

    # partial overlaps cannot nest
    for a in nodes:
        for c in nodes:
            if a is c or a.els[0].parent is not c.els[0].parent:
                continue
            sa = set(map(id, a.els))
            sc_ = set(map(id, c.els))
            if sa & sc_ and not (sa <= sc_ or sc_ <= sa):
                fail(f'{a.line}: nodes overlap without nesting')

    opens, closes = {}, {}
    for n in nodes:
        opens.setdefault(id(n.els[0]), []).append(n)
        closes.setdefault(id(n.els[-1]), []).append(n)

    def depth(n):
        d = 0
        while n.parent is not None:
            d += 1
            n = n.parent
        return d
    for v in opens.values():
        v.sort(key=depth)
    for v in closes.values():
        v.sort(key=depth, reverse=True)

    out = Out(palette)
    art_ops = []
    out.ops = art_ops
    clipstack = []
    nodestack = []
    tints = []  # colour filters around what is drawn, outermost first
    push_at = {}  # op index of each PUSH -> node, for the layer decision

    def ink(c):
        # the inner filter works first, on its own group
        for steps in reversed(tints):
            c = tinted(c, steps)
        return c

    def emit_kids(el, m):
        for k in el.kids:
            for n in opens.get(id(k), []):
                push_at[len(out.ops)] = (n, len(out.draws))
                out.op(OP_PUSH, n.index)
                nodestack.append(n)
            emit(k, m)
            for n in closes.get(id(k), []):
                out.op(OP_POP)
                nodestack.pop()

    def emit(el, ctm):
        m = mul(ctm, el.local)
        if el.clip:
            ce, rule = svg.clips[el.clip]
            s, _ = similarity(m, el.where())
            csubs = xform(shape_subs(ce, s), m)
            out.op(OP_SAVE)
            out.op(OP_CLIP, out.path(csubs, rule == 'evenodd'))
            clipstack.append((csubs, rule == 'evenodd'))
        if el.tint:
            tints.append(svg.tints[el.tint])
        if el.tag == 'g':
            emit_kids(el, m)
        else:
            draw(el, m)
        if el.tint:
            tints.pop()
        if el.clip:
            out.op(OP_POP)
            clipstack.pop()

    def grad_paint(ref, local_subs, m, where):
        if ref not in svg.grads:
            fail(f'{where}: no gradient {ref}')
        kind, geo, units, stops = svg.grads[ref]
        if units == 'objectBoundingBox':
            x0, y0, x1, y1 = bbox(local_subs)
            if x1 - x0 <= 0 or y1 - y0 <= 0:
                fail(f'{where}: gradient on a flat box')
            gm = mul(m, (x1 - x0, 0.0, 0.0, y1 - y0, x0, y0))
        else:
            gm = m
        st_ = tuple((min(255, round(o * 255)), out.colour_ix(ink(c)), round(a * 255)) for o, c, a in stops)
        return out.shader((kind, tuple(round(g, 6) for g in geo), tuple(round(g, 5) for g in gm), st_))

    def draw(el, m):
        where = el.where()
        s, _ = similarity(m, where)
        local = shape_subs(el, s)
        subs = xform(local, m)
        a = el.a
        fill = colour(a.get('fill', '#000000'), where)
        stroke = colour(a.get('stroke', 'none'), where)
        sw = float(a.get('stroke-width', '1'))
        if sw <= 0:
            stroke = None
        o = float(a.get('opacity', '1'))
        fo = float(a.get('fill-opacity', '1'))
        so = float(a.get('stroke-opacity', '1'))
        evenodd = a.get('fill-rule', 'nonzero') == 'evenodd'
        layer = fill is not None and stroke is not None and o < 1
        if layer:
            out.op(OP_LAYER, round(o * 255))
            o = 1.0
        owner = nodestack[-1] if nodestack else None
        hidden = any(n.hidden for n in nodestack)

        def paint_of(c, alpha, style, width=0, cap=0, join=0):
            if isinstance(c, tuple):
                sh = grad_paint(c[1], local, m, where)
                return out.paint((style | 2, sh, round(alpha * 255), width, cap, join))
            return out.paint((style, out.colour_ix(ink(c)), round(alpha * 255), width, cap, join))
        if fill is not None:
            pi = paint_of(fill, o * fo, 0)
            out.op(OP_DRAW, out.path(subs, evenodd))
            out.ops.append(pi)
            out.draws.append(dict(subs=subs, stroke=False, evenodd=evenodd, alpha=o * fo,
                                  clips=list(clipstack), owner=owner, hidden=hidden,
                                  nodes=list(nodestack), where=where))
        if stroke is not None:
            cap = {'butt': 0, 'round': 1, 'square': 2}[a.get('stroke-linecap', 'butt')]
            join = {'miter': 0, 'round': 1, 'bevel': 2}[a.get('stroke-linejoin', 'miter')]
            if float(a.get('stroke-miterlimit', '4')) != 4:
                fail(f'{where}: miter limit')
            ssubs = subs
            if 'stroke-dasharray' in a and a['stroke-dasharray'] != 'none':
                pat = [float(x) for x in re.split(r'[\s,]+', a['stroke-dasharray'].strip())]
                ssubs = xform(dash_subs(local, pat), m)
            width = sw * s
            pi = paint_of(stroke, o * so, 1, round(width * Q), cap, join)
            out.op(OP_DRAW, out.path(ssubs, False))
            out.ops.append(pi)
            out.draws.append(dict(subs=ssubs, stroke=True, width=width, cap=cap, join=join,
                                  alpha=o * so, clips=list(clipstack), owner=owner,
                                  hidden=hidden, nodes=list(nodestack), where=where))
        if layer:
            out.op(OP_POP)

    emit_kids(svg.fokia, ID)
    # which pushes need a layer to fade as one: more than one draw that overlap
    for at, (n, first) in push_at.items():
        mine = [d for d in out.draws[first:] if n in d['nodes']]
        boxes = [draw_box(d) for d in mine]
        overlap = any(boxes_meet(boxes[i], boxes[j]) for i in range(len(boxes))
                      for j in range(i + 1, len(boxes)))
        if overlap and (n, 5) in st.tracks:
            art_ops[at] |= PUSH_LAYER

    tracks = finish_tracks(st, report)
    halo_ops = halo(st, svg, out, nodes, tracks, blur, report)
    ops = halo_ops + art_ops
    check_ops(ops, nodes)
    run_clears(st, out, nodes, tracks, report)
    return pack_blob(st, out, nodes, ops, tracks), out


def draw_box(d):
    x0, y0, x1, y1 = bbox(d['subs'])
    w = d.get('width', 0) / 2 if d['stroke'] else 0
    return x0 - w, y0 - w, x1 + w, y1 + w


def boxes_meet(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def check_ops(ops, nodes):
    depth = 0
    i = 0
    while i < len(ops):
        code, arg = ops[i] >> 13, ops[i] & 0x1FFF
        if code in (OP_SAVE, OP_LAYER):
            depth += 1
        elif code == OP_PUSH:
            if (arg & 0xFFF) >= len(nodes):
                fail('push out of range')
            depth += 1
        elif code == OP_POP:
            depth -= 1
            if depth < 0:
                fail('pop without push')
        elif code == OP_DRAW:
            i += 1
        i += 1
    if depth:
        fail('ops do not balance')


def finish_tracks(st, report):
    tracks = []
    L = st.loop
    if st.tracks and not (2000 <= L <= 3000):
        fail(f'{st.line}: loop {L} ms is outside 2000..3000')
    for (n, prop), keys in st.tracks.items():
        rest = REST[prop]
        if keys[0][0] > 0:
            keys = [(0.0, keys[0][1], 0)] + keys
        if abs(keys[0][1] - rest) > 1e-9:
            fail(f'{n.line}: {n.name or "a node"} does not start at rest')
        if abs(keys[-1][1] - rest) > 1e-9:
            fail(f'{n.line}: {n.name or "a node"} does not end at rest')
        if keys[-1][0] > L:
            fail(f'{n.line}: a key after the loop ends ({keys[-1][0]} > {L})')
        if len(keys) > 255:
            fail(f'{n.line}: too many keys')
        qk = [(round(t), qvalue(prop, v), e) for t, v, e in keys]
        for a, b in zip(qk, qk[1:]):
            if b[0] <= a[0]:
                fail(f'{n.line}: two keys at {b[0]} ms')
        fk = [(t, dqvalue(prop, v), e) for t, v, e in qk]
        # amplitude
        span = max(abs(track_at(fk, t) - rest) for t in np.linspace(0, L, 241))
        name = n.name or '/'.join(e.id or e.tag for e in n.els)
        if (n, prop) not in st.waived and not n.internal:
            lim = None
            if prop == 2:
                lim = 3 if n.body else 12
            elif prop in (0, 1):
                lim = 12
            elif prop in (3, 4):
                lim = 0.03 if n.body else 0.35
                lo = min(track_at(fk, t) for t in np.linspace(0, L, 241))
                if not n.body and lo < 0.85 - 1e-9:
                    fail(f'{n.line}: {name} scales down to {lo:.3f}')
            if lim is not None and span > lim + 1e-9:
                fail(f'{n.line}: {name} {list(PROPS)[prop]} reaches {span:.3f}, the limit is {lim}')
        # the loop closes on itself: the same speed on both sides of the seam
        dt = 1.0
        v0 = (track_at(fk, dt) - track_at(fk, 0)) / dt
        v1 = (track_at(fk, L) - track_at(fk, L - dt)) / dt
        if abs(v0 - v1) > max(span, 1e-6) * 5e-4 + 1e-9:
            fail(f'{n.line}: {name} {list(PROPS)[prop]} jumps at the loop seam ({v0:.4f} vs {v1:.4f} per ms)')
        tracks.append((n, prop, qk, fk))
        if st.waived and (n, prop) in st.waived:
            report.append(f'  waived: {name} {list(PROPS)[prop]} {span:.3f}')
    tracks.sort(key=lambda x: (x[0].index, x[1]))
    return tracks


def node_values(n, tracks, t):
    v = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
    for m, prop, _, fk in tracks:
        if m is n:
            v[prop] = track_at(fk, t)
    return v


def apply_np(m, pts):
    pts = np.asarray(pts, dtype=float)
    return pts @ np.array([[m[0], m[1]], [m[2], m[3]]]) + [m[4], m[5]]


def chain_matrix(n, tracks, t, stop=None):
    m = ID
    chain = []
    x = n
    while x is not None and x is not stop:
        chain.append(x)
        x = x.parent
    for x in reversed(chain):
        m = mul(m, x.matrix(node_values(x, tracks, t)))
    return m


def sample_times(loop, tracks):
    ts = set(np.linspace(0, loop, 97).tolist()) if loop else {0.0}
    for _, _, keys, _ in tracks:
        for t, _, _ in keys:
            ts.add(float(t))
    return sorted(ts)


# ---- the halo raster

CIRCLE = np.stack([np.cos(np.linspace(0, 2 * np.pi, 25)[:-1]),
                   np.sin(np.linspace(0, 2 * np.pi, 25)[:-1])], axis=1)


def flatten(subs, step=2.0):
    # polylines in raster pixels
    out = []
    for start, segs, closed in subs:
        pts = [np.asarray([start], dtype=float)]
        p0 = start
        for g in segs:
            if g[0] == 'L':
                pts.append(np.asarray([g[1]], dtype=float))
            else:
                ctrl = seg_ctrl(p0, g)
                ln = sum(math.dist(ctrl[i], ctrl[i + 1]) for i in range(len(ctrl) - 1)) * S
                n = max(2, min(400, int(ln / step) + 1))
                pts.append(bez_eval(ctrl, np.linspace(0, 1, n + 1)[1:]))
            p0 = g[-1]
        arr = (np.concatenate(pts) - O) * S
        out.append((arr, closed))
    return out


def orient(polys):
    # every polygon counter-clockwise in raster space, so nonzero is a union
    x, y = polys[..., 0], polys[..., 1]
    area = (x * np.roll(y, -1, axis=1) - np.roll(x, -1, axis=1) * y).sum(axis=1)
    neg = area < 0
    polys[neg] = polys[neg][:, ::-1]
    return polys


def stroke_polys(lines, hw, cap, join, circle=CIRCLE, smooth=None):
    # smooth: per line, the points inside a curve; they join round, as a
    # curve's own offset does
    batches = []
    for k, (pts, closed) in enumerate(lines):
        sm = smooth[k] if smooth is not None else np.zeros(len(pts), dtype=bool)
        if len(pts) > 1:
            d = np.hypot(*np.diff(pts, axis=0).T)
            keep = np.concatenate([[True], d > 1e-6])
            pts, sm = pts[keep], sm[keep]
        if closed and len(pts) > 2 and np.hypot(*(pts[0] - pts[-1])) < 1e-6:
            pts, sm = pts[:-1], sm[:-1]
        if len(pts) == 1:
            if cap == 1:
                batches.append((circle * hw + pts[0])[None])
            elif cap == 2:
                batches.append(np.array([[[-hw, -hw], [hw, -hw], [hw, hw], [-hw, hw]]]) + pts[0])
            continue
        if closed:
            P, Qp = pts, np.roll(pts, -1, axis=0)
        else:
            P, Qp = pts[:-1].copy(), pts[1:].copy()
        D = Qp - P
        ln = np.hypot(D[:, 0], D[:, 1])
        U = D / ln[:, None]
        Nn = np.stack([-U[:, 1], U[:, 0]], axis=1)
        if cap == 2 and not closed:
            P[0] -= U[0] * hw
            Qp[-1] += U[-1] * hw
        rects = np.stack([P + Nn * hw, Qp + Nn * hw, Qp - Nn * hw, P - Nn * hw], axis=1)
        batches.append(orient(rects))
        # joins
        if closed:
            vi = np.arange(len(pts))
            u1, u2, n1, n2 = np.roll(U, 1, axis=0), U, np.roll(Nn, 1, axis=0), Nn
            V, sv = pts, sm
        else:
            vi = np.arange(1, len(pts) - 1)
            u1, u2, n1, n2 = U[:-1], U[1:], Nn[:-1], Nn[1:]
            V, sv = pts[1:-1], sm[1:-1]
        if len(vi):
            cr = u1[:, 0] * u2[:, 1] - u1[:, 1] * u2[:, 0]
            dt = (u1 * u2).sum(axis=1)
            ang = np.arctan2(np.abs(cr), dt)
            s = -np.sign(cr)[:, None]
            P1 = V + n1 * hw * s
            P2 = V + n2 * hw * s
            half = np.cos(ang / 2)
            bis = n1 * s + n2 * s
            bl = np.hypot(bis[:, 0], bis[:, 1])
            bl[bl < 1e-12] = 1
            M = V + bis / bl[:, None] * (hw / np.maximum(half, 1e-6))[:, None]
            miter = (1 / np.maximum(half, 1e-6)) <= 4
            rnd = sv | (join == 1)
            big = rnd & (ang > 0.25)
            if big.any():
                batches.append(circle[None] * hw + V[big][:, None, :])
            sel = ~big & (ang > 1e-3)
            Mx = np.where((rnd | (miter & (join == 0)))[:, None], M, P2)
            wed = np.stack([V[sel], P1[sel], Mx[sel], P2[sel]], axis=1)
            if len(wed):
                batches.append(orient(wed))
        if cap == 1 and not closed:
            batches.append(circle[None] * hw + np.stack([pts[0], pts[-1]])[:, None, :])
    return batches


def cover(batches, evenodd=False):
    # binary coverage at pixel centres: (r0, c0, mask) or None
    batches = [b for b in batches if len(b)]
    if not batches:
        return None
    lo = np.min([b.reshape(-1, 2).min(axis=0) for b in batches], axis=0)
    hi = np.max([b.reshape(-1, 2).max(axis=0) for b in batches], axis=0)
    c0 = max(0, int(math.floor(lo[0] - 1)))
    c1 = min(N, int(math.ceil(hi[0] + 1)))
    r0 = max(0, int(math.floor(lo[1] - 1)))
    r1 = min(N, int(math.ceil(hi[1] + 1)))
    if c1 <= c0 or r1 <= r0:
        return None
    X0, Y0, X1, Y1 = [], [], [], []
    for b in batches:
        nb = np.roll(b, -1, axis=1)
        X0.append(b[..., 0].ravel())
        Y0.append(b[..., 1].ravel())
        X1.append(nb[..., 0].ravel())
        Y1.append(nb[..., 1].ravel())
    x0, y0, x1, y1 = (np.concatenate(v) for v in (X0, Y0, X1, Y1))
    d = np.sign(y1 - y0)
    k = d != 0
    x0, y0, x1, y1, d = x0[k], y0[k], x1[k], y1[k], d[k]
    ya, yb = np.minimum(y0, y1), np.maximum(y0, y1)
    rs = np.clip(np.ceil(ya - 0.5).astype(np.int64), r0, r1)
    re_ = np.clip(np.ceil(yb - 0.5).astype(np.int64), r0, r1)
    cnt = re_ - rs
    k = cnt > 0
    x0, y0, x1, y1, d, rs, cnt = x0[k], y0[k], x1[k], y1[k], d[k], rs[k], cnt[k]
    W = c1 - c0 + 1
    if cnt.sum() == 0:
        return None
    idx = np.repeat(np.arange(len(cnt)), cnt)
    off = np.arange(cnt.sum()) - np.repeat(np.cumsum(cnt) - cnt, cnt)
    rows = rs[idx] + off
    xc = x0[idx] + (rows + 0.5 - y0[idx]) * (x1[idx] - x0[idx]) / (y1[idx] - y0[idx])
    cols = np.clip(np.ceil(xc - 0.5).astype(np.int64), c0, c1)
    acc = np.bincount((rows - r0) * W + (cols - c0), weights=d[idx],
                      minlength=(r1 - r0) * W).reshape(r1 - r0, W)
    w = np.rint(np.cumsum(acc, axis=1)[:, :c1 - c0]).astype(np.int64)
    mask = (w % 2 == 1) if evenodd else (w != 0)
    return r0, c0, mask


def fill_batches(subs):
    return [p[None] for p, _ in flatten(subs) if len(p) > 2]


class Raster:
    def __init__(self):
        self.clip_cache = {}

    def clip_mask(self, subs, evenodd):
        key = id(subs)
        if key not in self.clip_cache:
            m = np.zeros((N, N), dtype=bool)
            c = cover(fill_batches(subs), evenodd)
            if c is not None:
                r0, c0, mk = c
                m[r0:r0 + mk.shape[0], c0:c0 + mk.shape[1]] = mk
            self.clip_cache[key] = (subs, m)
        return self.clip_cache[key][1]

    def draw_cover(self, d):
        if 'cov' not in d:
            if d['stroke']:
                hw = d['width'] / 2 * S
                c = cover(stroke_polys(flatten(d['subs']), hw, d['cap'], d['join']))
            else:
                c = cover(fill_batches(d['subs']), d['evenodd'])
            if c is not None:
                r0, c0, mk = c
                f = mk.astype(np.float32)
                for cs, eo in d['clips']:
                    f *= self.clip_mask(cs, eo)[r0:r0 + mk.shape[0], c0:c0 + mk.shape[1]]
                c = (r0, c0, f)
            d['cov'] = c
        return d['cov']

    def alpha(self, draws):
        a = np.zeros((N, N), dtype=np.float32)
        for d in draws:
            c = self.draw_cover(d)
            if c is None:
                continue
            r0, c0, f = c
            win = a[r0:r0 + f.shape[0], c0:c0 + f.shape[1]]
            win += f * d['alpha'] * (1 - win)
        return a


def spectrum(f, how):
    if how == 'grow':
        return np.exp(-2 * (np.pi * S * f) ** 2)
    if how == 'gauss':
        return np.exp(-2 * (np.pi * SIGMA * S * f) ** 2)

    # svg's three-box approximation, sized for the 512 render and scaled up
    def box(width, shift=0.0):
        with np.errstate(invalid='ignore', divide='ignore'):
            k = np.where(f == 0, 1.0, np.sin(np.pi * f * width) / (width * np.sin(np.pi * f)))
        return k * np.exp(-2j * np.pi * f * shift)
    d = math.floor(SIGMA * 3 * math.sqrt(2 * math.pi) / 4 + 0.5)
    if d % 2:
        return box(d * S) ** 3
    return box(d * S, -S / 2) * box(d * S, S / 2) * box((d + 1) * S)


_spec = {}


def blur(a, how):
    if how not in _spec:
        _spec[how] = np.outer(spectrum(np.fft.fftfreq(N), how), spectrum(np.fft.rfftfreq(N), how))
    F = np.fft.rfft2(a.astype(np.float64))
    return np.fft.irfft2(F * _spec[how], s=a.shape)


def bilinear(F, pts):
    # field values at sticker points
    x = (np.asarray(pts)[:, 0] - O) * S - 0.5
    y = (np.asarray(pts)[:, 1] - O) * S - 0.5
    x = np.clip(x, 0, N - 1.001)
    y = np.clip(y, 0, N - 1.001)
    j, i = x.astype(int), y.astype(int)
    fx, fy = x - j, y - i
    return (F[i, j] * (1 - fx) * (1 - fy) + F[i, j + 1] * fx * (1 - fy)
            + F[i + 1, j] * (1 - fx) * fy + F[i + 1, j + 1] * fx * fy)


def contours(F, level):
    V = F >= level
    code = (V[:-1, :-1].astype(np.uint8) | (V[:-1, 1:].astype(np.uint8) << 1)
            | (V[1:, 1:].astype(np.uint8) << 2) | (V[1:, :-1].astype(np.uint8) << 3))
    ii, jj = np.nonzero((code != 0) & (code != 15))
    NC = F.shape[1]
    nxt = {}

    def ek(kind, i, j):
        return ((i * NC + j) << 1) | kind

    def epos(key):
        kind = key & 1
        b = key >> 1
        i, j = divmod(b, NC)
        if kind == 0:
            f1, f2 = F[i, j], F[i, j + 1]
            t = (level - f1) / (f2 - f1)
            return (j + t, i)
        f1, f2 = F[i, j], F[i + 1, j]
        t = (level - f1) / (f2 - f1)
        return (j, i + t)
    for i, j in zip(ii.tolist(), jj.tolist()):
        c = int(code[i, j])
        corners = [(j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1)]
        ins = [bool(c & 1), bool(c & 2), bool(c & 4), bool(c & 8)]
        edges = [ek(0, i, j), ek(1, i, j + 1), ek(0, i + 1, j), ek(1, i, j)]
        # edge e joins corners (e, e+1)
        if c in (5, 10):
            cin = (F[i, j] + F[i, j + 1] + F[i + 1, j + 1] + F[i + 1, j]) / 4 >= level
            if (c == 5) == cin:
                # isolate tr and bl
                pairs = [((0, 1), 1), ((2, 3), 3)]
            else:
                pairs = [((3, 0), 0), ((1, 2), 2)]
        else:
            cross = [e for e in range(4) if ins[e] != ins[(e + 1) % 4]]
            pairs = [(tuple(cross), None)]
        for (ea, eb), iso in pairs:
            ka, kb = edges[ea], edges[eb]
            pa, pb = epos(ka), epos(kb)
            dx, dy = pb[0] - pa[0], pb[1] - pa[1]
            if iso is None:
                best = max(range(4), key=lambda q: abs(dx * (corners[q][1] - pa[1]) - dy * (corners[q][0] - pa[0])))
            else:
                best = iso
            cr = dx * (corners[best][1] - pa[1]) - dy * (corners[best][0] - pa[0])
            if (cr > 0) != ins[best]:
                ka, kb = kb, ka
            nxt[ka] = kb
    loops = []
    while nxt:
        start, k = nxt.popitem()
        keys = [start]
        while k != start:
            keys.append(k)
            k = nxt.pop(k)
        pts = np.array([epos(q) for q in keys], dtype=float)
        pts = O + (pts + 0.5) / S
        loops.append(pts)
    return loops


def loop_area(p):
    x, y = p[:, 0], p[:, 1]
    return 0.5 * float((x * np.roll(y, -1) - np.roll(x, -1) * y).sum())


# ---- curve fitting (schneider)

def fit_bez(d, u, t1, t2):
    p0, p3 = d[0], d[-1]
    b0 = (1 - u) ** 3
    b1 = 3 * u * (1 - u) ** 2
    b2 = 3 * u * u * (1 - u)
    b3 = u ** 3
    A1 = b1[:, None] * t1
    A2 = b2[:, None] * t2
    c00, c01, c11 = (A1 * A1).sum(), (A1 * A2).sum(), (A2 * A2).sum()
    tmp = d - (b0 + b1)[:, None] * p0 - (b2 + b3)[:, None] * p3
    x0, x1 = (A1 * tmp).sum(), (A2 * tmp).sum()
    det = c00 * c11 - c01 * c01
    seg = float(np.hypot(*(p3 - p0)))
    if abs(det) > 1e-12:
        a1 = (x0 * c11 - x1 * c01) / det
        a2 = (c00 * x1 - c01 * x0) / det
    else:
        a1 = a2 = seg / 3
    if a1 < 1e-6 * seg or a2 < 1e-6 * seg:
        a1 = a2 = seg / 3
    return np.array([p0, p0 + t1 * a1, p3 + t2 * a2, p3])


def bez_pts(b, u):
    u = u[:, None]
    return ((1 - u) ** 3 * b[0] + 3 * u * (1 - u) ** 2 * b[1]
            + 3 * u * u * (1 - u) * b[2] + u ** 3 * b[3])


def reparam(d, b, u):
    q = bez_pts(b, u)
    d1 = np.array([3 * (b[1] - b[0]), 3 * (b[2] - b[1]), 3 * (b[3] - b[2])])
    d2 = np.array([2 * (d1[1] - d1[0]), 2 * (d1[2] - d1[1])])
    uu = u[:, None]
    q1 = (1 - uu) ** 2 * d1[0] + 2 * uu * (1 - uu) * d1[1] + uu * uu * d1[2]
    q2 = (1 - uu) * d2[0] + uu * d2[1]
    num = ((q - d) * q1).sum(axis=1)
    den = (q1 * q1).sum(axis=1) + ((q - d) * q2).sum(axis=1)
    with np.errstate(divide='ignore', invalid='ignore'):
        nu = np.where(np.abs(den) > 1e-12, u - num / den, u)
    nu = np.clip(nu, 0, 1)
    return np.maximum.accumulate(nu)


def fit_run(d, t1, t2, err, out, depth=0):
    n = len(d)
    if n <= 2 or depth > 40:
        dist = float(np.hypot(*(d[-1] - d[0]))) / 3
        out.append(np.array([d[0], d[0] + t1 * dist, d[-1] + t2 * dist, d[-1]]))
        return
    ch = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(d, axis=0).T))])
    u = ch / ch[-1]
    b = fit_bez(d, u, t1, t2)
    for it in range(12):
        e = np.hypot(*(bez_pts(b, u) - d).T)
        k = int(np.argmax(e[1:-1])) + 1
        if e[k] < err:
            out.append(b)
            return
        if e[k] > err * 6 and it > 0:
            break
        u = reparam(d, b, u)
        b = fit_bez(d, u, t1, t2)
    w = min(4, k, n - 1 - k)
    tc = d[k - w] - d[k + w]
    tc = tc / max(1e-12, float(np.hypot(*tc)))
    fit_run(d[:k + 1], t1, tc, err, out, depth + 1)
    fit_run(d[k:], -tc, t2, err, out, depth + 1)


def unit(v):
    ln = float(np.hypot(*v))
    return v / ln if ln > 1e-12 else v


def fit_loop(p, err=0.1):
    n = len(p)
    ch = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(np.vstack([p, p[:1]]), axis=0).T))])
    total = ch[-1]
    # corners: where the direction turns by more than 35 degrees within a px
    look = 1.0
    ext = np.concatenate([ch[:-1] - total, ch[:-1], ch[:-1] + total])
    idx = np.arange(n)
    back = np.searchsorted(ext, ch[:-1] + total - look) - n
    fwd = np.searchsorted(ext, ch[:-1] + total + look) - n
    vb = p - p[back % n]
    vf = p[fwd % n] - p
    ang = np.arctan2(np.abs(vb[:, 0] * vf[:, 1] - vb[:, 1] * vf[:, 0]), (vb * vf).sum(axis=1))
    cand = [i for i in idx if ang[i] > math.radians(35)]
    corners = []
    for i in sorted(cand, key=lambda i: -ang[i]):
        if all(min(abs(ch[i] - ch[c]), total - abs(ch[i] - ch[c])) > 3 for c in corners):
            corners.append(i)
    corners.sort()

    out = []
    if not corners:
        k = 4
        t = unit(p[k % n] - p[-k])
        d = np.vstack([p, p[:1]])
        fit_run(d, t, -t, err, out)
        return out
    rolled = np.roll(p, -corners[0], axis=0)
    cs = [(c - corners[0]) % n for c in corners] + [n]
    rolled = np.vstack([rolled, rolled[:1]])
    for a, b in zip(cs, cs[1:]):
        d = rolled[a:b + 1]
        if len(d) < 2:
            continue
        k = min(4, len(d) - 1)
        t1 = unit(d[k] - d[0])
        t2 = unit(d[-1 - k] - d[-1])
        fit_run(d, t1, t2, err, out)
    return out


def loop_subs(beziers):
    start = tuple(beziers[0][0])
    segs = [('C', tuple(b[1]), tuple(b[2]), tuple(b[3])) for b in beziers]
    return [start, segs, True]


# ---- halo pieces

def halo(st, svg, out, nodes, tracks, how, report):
    ras = Raster()
    draws = [d for d in out.draws if not d['hidden']]
    times = sample_times(st.loop, tracks)
    moving = {tk[0] for tk in tracks}
    # a node moves if it or anything above it has tracks
    def owner_of(d, cands):
        for n in reversed(d['nodes']):
            if n in cands:
                return n
        return None
    cands = set(n for n in nodes if n in moving)
    # deepest first: a node whose outline never leaves its parent's needs no piece
    order = sorted(cands, key=lambda n: -len(ancestors(n)))
    for n in order:
        mine = [d for d in draws if owner_of(d, cands) is n]
        if not mine:
            cands.discard(n)
            continue
        par = next((a for a in ancestors(n) if a in cands), None)
        # everything else, at rest: a part that stays inside it as it moves
        # draws its outline with its parent
        rest = [d for d in draws if owner_of(d, cands) is not n]
        fn = blur(ras.alpha(mine), how)
        fp = blur(ras.alpha(rest), how)
        pts = np.concatenate(contours(fn, LEVEL)) if fn.max() >= LEVEL else None
        if pts is None:
            cands.discard(n)
            continue
        inside = True
        for t in times:
            q = apply_np(chain_matrix(n, tracks, t, stop=par), pts[::4])
            if (bilinear(fp, q) < LEVEL * 1.05).any():
                inside = False
                break
        if inside:
            cands.discard(n)
    owners = [None] + [n for n in nodes if n in cands]
    groups = {o: [d for d in draws if owner_of(d, cands) is o] for o in owners}
    A = blur(ras.alpha(draws), how)
    F = {o: (blur(ras.alpha(groups[o]), how) if groups[o] else None) for o in owners}
    region = A >= LEVEL
    mine = {o: (F[o] >= LEVEL) for o in owners if F[o] is not None}
    covered = np.zeros_like(region)
    for m in mine.values():
        covered |= m
    bridges = region & ~covered
    # each pixel of a bridge goes with the part whose field is strongest
    # there, so in motion a bridge shears down its middle instead of riding
    # whole on one side (a blade) or staying behind (a fin)
    extra = {o: np.zeros((N, N), dtype=bool) for o in owners}
    lines = []
    have = [o for o in owners if F[o] is not None]
    if bridges.any() and have:
        stack = np.stack([F[o] for o in have])
        best = np.argmax(stack, axis=0)
        for k, o in enumerate(have):
            extra[o] |= bridges & (best == k)
    for comp, (r0, r1, c0, c1) in components(bridges):
        area = comp.sum() / (S * S)
        if area >= 1:
            parts = sorted({owner_name(o) for o in have
                            if (extra[o][r0:r1, c0:c1] & comp).any()})
            lines.append(f'  bridge {area:6.1f} px2 -> {" + ".join(parts)}')
    ops = []
    pieces = []
    for o in owners:
        f = F[o]
        if f is None and not extra[o].any():
            continue
        g = f if f is not None else np.zeros((N, N))
        if extra[o].any():
            # the bridge grown by 2 px (two sigmas of a 1 px blur), smooth
            bf = blur(extra[o].astype(np.float32), 'grow')
            g = np.maximum(g, LEVEL * bf / 0.02275)
        piece = np.minimum(A, g)
        if piece.max() < LEVEL:
            continue
        rims = []
        for level, alpha in RIM:
            subs = []
            for p in contours(piece, level):
                if abs(loop_area(p)) < 0.5:
                    continue
                subs.append(loop_subs(fit_loop(p)))
            if subs:
                rims.append((subs, alpha))
        if not rims:
            continue
        chain = [] if o is None else ancestors(o)[::-1] + [o]
        for n in chain:
            ops.append((OP_PUSH << 13) | n.index)
        white = out.colour_ix(0xFFFFFF)
        for subs, alpha in rims:
            pi = out.paint((0, white, alpha, 0, 0, 0))
            ops.append((OP_DRAW << 13) | out.path(subs, True))
            ops.append(pi)
        for _ in chain:
            ops.append(OP_POP << 13)
        pieces.append((owner_name(o), sum(len(s[1]) for subs, _ in rims for s in subs)))
    report.append('  halo: ' + ', '.join(f'{n} {c}' for n, c in pieces))
    report.extend(lines)
    return ops


def owner_name(o):
    if o is None:
        return 'still'
    return o.name or '/'.join(e.id or e.tag for e in o.els)


def ancestors(n):
    out = []
    x = n.parent
    while x is not None:
        out.append(x)
        x = x.parent
    return out


def components(mask):
    # 4-connected components by runs: yields (component window, (r0, r1, c0, c1))
    rows = np.nonzero(mask.any(axis=1))[0]
    parent = []

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    runs = []
    prev = []
    for r in rows.tolist():
        line = mask[r]
        d = np.diff(np.concatenate([[0], line.astype(np.int8), [0]]))
        starts, ends = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
        cur = []
        for a, b in zip(starts.tolist(), ends.tolist()):
            k = len(runs)
            runs.append((r, a, b))
            parent.append(k)
            for pk in prev:
                pr, pa, pb = runs[pk]
                if pr == r - 1 and pa < b and a < pb:
                    ra, rb = find(k), find(pk)
                    if ra != rb:
                        parent[ra] = rb
            cur.append(k)
        prev = cur
    groups = {}
    for k in range(len(runs)):
        groups.setdefault(find(k), []).append(runs[k])
    for rs in groups.values():
        r0 = min(r for r, _, _ in rs)
        r1 = max(r for r, _, _ in rs) + 1
        c0 = min(a for _, a, _ in rs)
        c1 = max(b for _, _, b in rs)
        comp = np.zeros((r1 - r0, c1 - c0), dtype=bool)
        for r, a, b in rs:
            comp[r - r0, a - c0:b - c0] = True
        yield comp, (r0, r1, c0, c1)


# ---- clearances: two moving parts that must not touch

def cloud(out, n, ras):
    # outline points of a node's art, with the stroke's half width; points
    # a clip hides do not count
    pts, rad = [], []
    for d in out.draws:
        if n not in d['nodes'] or d['hidden']:
            continue
        for p, closed in flatten(d['subs'], step=4.0):
            keep = np.ones(len(p), dtype=bool)
            ij = np.clip(np.floor(p).astype(int), 0, N - 1)
            for cs, eo in d['clips']:
                keep &= ras.clip_mask(cs, eo)[ij[:, 1], ij[:, 0]]
            q = p[keep] / S + O
            pts.append(q)
            rad.append(np.full(len(q), d.get('width', 0) / 2 if d['stroke'] else 0.0))
    return np.concatenate(pts), np.concatenate(rad)


def run_clears(st, out, nodes, tracks, report):
    ras = Raster()
    for a, b, gap, where in st.clears:
        pa, ra = cloud(out, a, ras)
        pb, rb = cloud(out, b, ras)
        worst = math.inf
        at = 0
        rest = None
        for t in sample_times(st.loop, tracks):
            ma = chain_matrix(a, tracks, t)
            mb = chain_matrix(b, tracks, t)
            qa = apply_np(ma, pa)
            qb = apply_np(mb, pb)
            dd = np.hypot(qa[:, None, 0] - qb[None, :, 0], qa[:, None, 1] - qb[None, :, 1])
            g = float((dd - ra[:, None] - rb[None, :]).min())
            if rest is None:
                rest = g
            if g < worst:
                worst, at = g, t
        report.append(f'  clear {owner_name(a)} {owner_name(b)}: {worst:.1f} px at {at:.0f} ms, '
                      f'{rest:.1f} at rest (wants {gap:g})')
        if worst < gap:
            fail(f'{where}: {owner_name(a)} comes within {worst:.1f} px of {owner_name(b)} '
                 f'at {at:.0f} ms')


# ---- output

def pack_blob(st, out, nodes, ops, tracks):
    b = bytearray()
    emoji = st.emoji.encode('utf-8')
    b += struct.pack('<HHHB', st.num, st.since, st.loop, len(emoji)) + emoji
    b += struct.pack('<H', len(out.paths))
    for eo, verbs, pts in out.paths:
        b += struct.pack('<BHH', eo, len(verbs), len(pts))
        b += bytes(verbs)
        b += struct.pack(f'<{2 * len(pts)}h', *[v for p in pts for v in p])
    b += struct.pack('<B', len(out.shaders))
    for kind, geo, gm, stops in out.shaders:
        b += struct.pack('<B4f6fB', kind, *geo, *gm, len(stops))
        for o, c, a in stops:
            b += struct.pack('<BBB', o, c, a)
    b += struct.pack('<H', len(out.paints))
    for style, c, a, w, cap, join in out.paints:
        b += struct.pack('<BBBHBB', style, c, a, w, cap, join)
    b += struct.pack('<H', len(nodes))
    for n in nodes:
        par = n.parent.index if n.parent is not None else 0xFFFF
        b += struct.pack('<HhhhHB', par, round(n.pivot[0] * Q), round(n.pivot[1] * Q),
                         round(n.frame * 100), round(n.k * 10000), 1 if n.hidden else 0)
    b += struct.pack('<H', len(ops))
    b += struct.pack(f'<{len(ops)}H', *ops)
    b += struct.pack('<H', len(tracks))
    for n, prop, keys, _ in tracks:
        b += struct.pack('<HBB', n.index, prop, len(keys))
        for t, v, e in keys:
            b += struct.pack('<HhB', t, v, e)
    return bytes(b)


def source_hash(pack):
    h = hashlib.sha256()
    for f in sorted((pack.dir / 'svg').glob('*.svg'), key=lambda p: p.name):
        h.update(f.read_bytes())
    h.update((pack.dir / 'anim.txt').read_bytes())
    return h.digest()[:16]


def svg_num(f):
    # files are CHARACTER-NN-name.svg; the number is the sticker's id
    parts = f.stem.split('-')
    if len(parts) < 3 or not re.fullmatch(r'\d{2,4}', parts[1]):
        fail(f'{f.name}: not name-NN-what.svg')
    return int(parts[1])


def svg_file(pack, num):
    got = [f for f in sorted((pack.dir / 'svg').glob('*.svg')) if svg_num(f) == num]
    if len(got) != 1:
        fail(f'sticker {num}: {len(got)} svg files')
    return got[0]


def build(pack, only=None, blur_how='box3', verbose=False):
    anim = Anim(pack.dir / 'anim.txt')
    files = sorted((pack.dir / 'svg').glob('*.svg'))
    nums = sorted(svg_num(f) for f in files)
    if len(set(nums)) != len(nums):
        fail(f'{pack.name}: two svg files with one number')
    if sorted(anim.stickers) != nums:
        fail(f'anim.txt lists {sorted(anim.stickers)}, the svg folder has {nums}')
    palette = {}
    blobs = []
    report = []
    sizes = {}
    for num in nums:
        if only and num not in only:
            continue
        st = anim.stickers[num]
        svg = Svg(svg_file(pack, num))
        if st.name not in svg.name:
            fail(f'{st.line}: {st.name} is not {svg.name}')
        rep = []
        blob, out = compile_sticker(anim, st, svg, palette, blur_how, rep)
        blobs.append((num, blob))
        sizes[num] = len(blob)
        report.append(f'{num:02d} {st.name}: {len(blob)} bytes, {len(out.paths)} paths, '
                      f'{len(out.paints)} paints, {len(st.nodes)} nodes, '
                      f'{sum(1 for o in out.ops if (o >> 13) == OP_DRAW)} draws, loop {st.loop}')
        report += rep
        if svg.dups:
            report.append(f'  duplicate ids named {", ".join(svg.dups)}')
        if len(blob) > 64 * 1024:
            fail(f'sticker {num} is {len(blob)} bytes, over 64 kb')
        if verbose:
            print('\n'.join(report[-(len(rep) + 1):]), flush=True)
    if len(palette) > 255:
        fail('palette over 255 colours')
    head = bytearray(b'KSTK')
    name = pack.name.encode('ascii')
    title = anim.title.encode('utf-8') if anim.title is not None else None
    head += struct.pack('<BBH', VERSION if title is None else VERSION_TITLE, UNIT, PACK_VERSION)
    head += source_hash(pack)
    head += struct.pack('<B', len(name)) + name
    if title is not None:
        head += struct.pack('<B', len(title)) + title
    pal = sorted(palette.items(), key=lambda kv: kv[1])
    head += struct.pack('<B', len(pal))
    for rgb, _ in pal:
        head += struct.pack('<I', 0xFF000000 | rgb)
    head += struct.pack('<H', len(blobs))
    off = len(head) + len(blobs) * 10
    index = bytearray()
    for num, blob in blobs:
        index += struct.pack('<HII', num, off, len(blob))
        off += len(blob)
    data = bytes(head + index + b''.join(blob for _, blob in blobs))
    return data, report, sizes


# ---- --png: each still frame from the built pack, painted the way
# sticker_player.dart paints it, for the pixel test

SUB = 16     # sample rows a pixel row; along a row coverage is exact
TOL = 0.02   # flattening, px
BOX = 512


def read_pack(data):
    # the palette and every blob, as sticker_pack.dart reads them
    o = 24
    o += 1 + data[o]
    if data[4] == VERSION_TITLE:
        o += 1 + data[o]
    npal = data[o]
    pal = struct.unpack_from(f'<{npal}I', data, o + 1)
    o += 1 + 4 * npal
    (count,) = struct.unpack_from('<H', data, o)
    blobs = []
    for i in range(count):
        num, off, ln = struct.unpack_from('<HII', data, o + 2 + 10 * i)
        blobs.append((num, data[off:off + ln]))
    return pal, blobs


class Still:
    # what the still frame needs from a blob: paths, shaders, paints,
    # hidden nodes and the ops
    def __init__(self, b):
        o = 0

        def rd(fmt):
            nonlocal o
            v = struct.unpack_from('<' + fmt, b, o)
            o += struct.calcsize('<' + fmt)
            return v
        ne = rd('HHHB')[3]
        o += ne
        self.paths = []
        for _ in range(rd('H')[0]):
            eo, nv, npt = rd('BHH')
            verbs = b[o:o + nv]
            o += nv
            v = rd(f'{2 * npt}h')
            pts = [(v[2 * i] / Q, v[2 * i + 1] / Q) for i in range(npt)]
            subs, k = [], 0
            for vb in verbs:
                if vb == 0:
                    subs.append([pts[k], [], False])
                    k += 1
                elif vb == 4:
                    subs[-1][2] = True
                else:
                    subs[-1][1].append(('LQC'[vb - 1],) + tuple(pts[k:k + vb]))
                    k += vb
            self.paths.append((subs, eo == 1))
        self.shaders = []
        for _ in range(rd('B')[0]):
            v = rd('B4f6fB')
            self.shaders.append((v[0], v[1:5], v[5:11], [rd('BBB') for _ in range(v[11])]))
        self.paints = [rd('BBBHBB') for _ in range(rd('H')[0])]
        self.hidden = [rd('HhhhHB')[5] & 1 for _ in range(rd('H')[0])]
        (nops,) = rd('H')
        self.ops = rd(f'{nops}H')
        self.jump = {}
        stack = []
        i = 0
        while i < nops:
            code = self.ops[i] >> 13
            if code in (OP_SAVE, OP_PUSH, OP_LAYER):
                stack.append(i)
            elif code == OP_POP:
                self.jump[stack.pop()] = i
            elif code == OP_DRAW:
                i += 1
            i += 1


def flat_px(subs):
    # polylines in px, curves cut until each piece is within TOL, and per
    # line which points are inside a curve
    lines, smooth = [], []
    for start, segs, closed in subs:
        pts = [np.asarray([start], dtype=float)]
        sm = [False]
        p0 = start
        for g in segs:
            if g[0] == 'L':
                pts.append(np.asarray([g[1]], dtype=float))
                sm.append(False)
            else:
                c = np.asarray(seg_ctrl(p0, g), dtype=float)
                dd = np.hypot(*(c[:-2] - 2 * c[1:-1] + c[2:]).T).max()
                k = 0.25 if g[0] == 'Q' else 0.75
                n = max(1, math.ceil(math.sqrt(k * dd / TOL)))
                pts.append(bez_eval(c, np.linspace(0, 1, n + 1)[1:]))
                sm += [True] * (n - 1) + [False]
            p0 = g[-1]
        lines.append((np.concatenate(pts), closed))
        smooth.append(np.array(sm))
    return lines, smooth


def fill_px(subs):
    return [p[None] for p, _ in flat_px(subs)[0] if len(p) > 2]


def png_cover(batches, evenodd=False):
    # area coverage on the 512 grid: SUB sample rows a pixel row, each one
    # exact across. (r0, c0, cov) or None
    batches = [b for b in batches if len(b)]
    if not batches:
        return None
    lo = np.min([b.reshape(-1, 2).min(axis=0) for b in batches], axis=0)
    hi = np.max([b.reshape(-1, 2).max(axis=0) for b in batches], axis=0)
    c0, c1 = max(0, math.floor(lo[0])), min(BOX, math.ceil(hi[0]))
    r0, r1 = max(0, math.floor(lo[1])), min(BOX, math.ceil(hi[1]))
    if c1 <= c0 or r1 <= r0:
        return None
    x0 = np.concatenate([b[..., 0].ravel() for b in batches])
    y0 = np.concatenate([b[..., 1].ravel() for b in batches])
    x1 = np.concatenate([np.roll(b, -1, axis=1)[..., 0].ravel() for b in batches])
    y1 = np.concatenate([np.roll(b, -1, axis=1)[..., 1].ravel() for b in batches])
    d = np.sign(y1 - y0).astype(np.int64)
    k = d != 0
    x0, y0, x1, y1, d = x0[k], y0[k], x1[k], y1[k], d[k]
    # sample row k sits at (k + 0.5) / SUB; an edge takes the rows in [ya, yb)
    ks = np.clip(np.ceil(np.minimum(y0, y1) * SUB - 0.5), r0 * SUB, r1 * SUB).astype(np.int64)
    ke = np.clip(np.ceil(np.maximum(y0, y1) * SUB - 0.5), r0 * SUB, r1 * SUB).astype(np.int64)
    cnt = ke - ks
    if cnt.sum() == 0:
        return None
    idx = np.repeat(np.arange(len(cnt)), cnt)
    rows = ks[idx] + np.arange(cnt.sum()) - np.repeat(np.cumsum(cnt) - cnt, cnt)
    y = (rows + 0.5) / SUB
    x = x0[idx] + (y - y0[idx]) * (x1[idx] - x0[idx]) / (y1[idx] - y0[idx])
    order = np.lexsort((x, rows))
    rows, x, d = rows[order], x[order], d[idx][order]
    # closed outlines: every row's winding is back to 0 at its last crossing
    wind = np.cumsum(d)[:-1]
    inside = (wind % 2 == 1) if evenodd else (wind != 0)
    a = np.clip(x[:-1][inside], c0, c1)
    b = np.clip(x[1:][inside], c0, c1)
    rows = rows[:-1][inside]
    W = c1 - c0 + 2
    base = (rows - r0 * SUB) * W - c0
    acc = np.zeros((r1 - r0) * SUB * W)
    # a span [a, b) adds clamp(j + 1 - a, 0, 1) - clamp(j + 1 - b, 0, 1) to
    # column j: steps of 1 - frac at floor and frac one further, summed across
    for v, sign in ((a, 1.0), (b, -1.0)):
        fl = np.floor(v)
        fr = v - fl
        at = base + fl.astype(np.int64)
        acc += np.bincount(at, weights=sign * (1 - fr), minlength=len(acc))
        acc += np.bincount(at + 1, weights=sign * fr, minlength=len(acc))
    cov = np.cumsum(acc.reshape(-1, W), axis=1)[:, :c1 - c0]
    cov = cov.reshape(r1 - r0, SUB, c1 - c0).sum(axis=1) / SUB
    return r0, c0, np.clip(cov, 0.0, 1.0)


def png_circle(hw):
    n = max(24, math.ceil(math.pi / math.acos(max(-1.0, 1 - 0.01 / max(hw, 1e-6)))))
    a = np.arange(n) * (2 * math.pi / n)
    return np.stack([np.cos(a), np.sin(a)], axis=1)


def rgb_of(v):
    return np.array([(v >> 16) & 255, (v >> 8) & 255, v & 255], dtype=float) / 255


def png_shade(sh, pal, r0, c0, h, w):
    # a gradient at pixel centres, premultiplied; stops mix unpremultiplied
    kind, geo, m, stops = sh
    yy, xx = np.mgrid[r0:r0 + h, c0:c0 + w] + 0.5
    a, b, c, d, e, f = m
    det = a * d - b * c
    px, py = xx - e, yy - f
    qx, qy = (d * px - c * py) / det, (a * py - b * px) / det
    if kind == 0:
        dx, dy = geo[2] - geo[0], geo[3] - geo[1]
        t = ((qx - geo[0]) * dx + (qy - geo[1]) * dy) / (dx * dx + dy * dy)
    else:
        t = np.hypot(qx - geo[0], qy - geo[1]) / geo[2]
    offs = np.array([s[0] / 255 for s in stops])
    cols = np.array([list(rgb_of(pal[s[1]])) + [s[2] / 255] for s in stops])
    t = np.clip(t, offs[0], offs[-1])
    j = np.clip(np.searchsorted(offs, t, side='right') - 1, 0, len(offs) - 2)
    span = offs[j + 1] - offs[j]
    u = np.where(span > 0, (t - offs[j]) / np.where(span > 0, span, 1), 1.0)[..., None]
    out = cols[j] + (cols[j + 1] - cols[j]) * u
    out[..., :3] *= out[..., 3:]
    return out


def paint_still(st, pal):
    # sticker_player.dart's paintSticker with v null: nodes at rest, the
    # hidden ones skipped. premultiplied rgba, 0..1
    img = np.zeros((BOX, BOX, 4))
    clip = None
    stack = []
    ops = st.ops
    i = 0
    while i < len(ops):
        code, arg = ops[i] >> 13, ops[i] & 0x1FFF
        if code == OP_PUSH and st.hidden[arg & 0xFFF]:
            i = st.jump[i] + 1
            continue
        if code in (OP_SAVE, OP_PUSH):
            stack.append((clip, None))
        elif code == OP_LAYER:
            stack.append((clip, (img, (arg & 0xFF) / 255)))
            img = np.zeros_like(img)
        elif code == OP_POP:
            clip, layer = stack.pop()
            if layer is not None:
                under, a = layer
                under *= 1 - img[..., 3:] * a
                under += img * a
                img = under
        elif code == OP_CLIP:
            subs, eo = st.paths[arg]
            m = np.zeros((BOX, BOX))
            c = png_cover(fill_px(subs), eo)
            if c is not None:
                r0, c0, f = c
                m[r0:r0 + f.shape[0], c0:c0 + f.shape[1]] = f
            clip = m if clip is None else clip * m
        elif code == OP_DRAW:
            i += 1
            subs, eo = st.paths[arg]
            style, ci, alpha, w, cap, join = st.paints[ops[i]]
            if style & 1:
                hw = w / Q / 2
                lines, smooth = flat_px(subs)
                c = png_cover(stroke_polys(lines, hw, cap, join, png_circle(hw), smooth))
            else:
                c = png_cover(fill_px(subs), eo)
            if c is not None:
                r0, c0, f = c
                h, w_ = f.shape
                if clip is not None:
                    f = f * clip[r0:r0 + h, c0:c0 + w_]
                if style & 2:
                    src = png_shade(st.shaders[ci], pal, r0, c0, h, w_) * (alpha / 255)
                else:
                    src = np.append(rgb_of(pal[ci]), 1.0) * (alpha / 255)
                    src = np.broadcast_to(src, (h, w_, 4))
                win = img[r0:r0 + h, c0:c0 + w_]
                win *= 1 - (f * src[..., 3])[..., None]
                win += f[..., None] * src
        i += 1
    return img


def png_bytes(img):
    # straight alpha rgba8, one idat, no filters, no timestamps
    a = np.clip(img[..., 3], 0, 1)
    a8 = np.rint(a * 255)
    rgb = img[..., :3] / np.where(a > 0, a, 1)[..., None]
    rgb8 = np.rint(np.clip(rgb, 0, 1) * 255)
    rgb8[a8 == 0] = 0
    px = np.concatenate([rgb8, a8[..., None]], axis=2).astype(np.uint8)
    h, w = a.shape
    raw = np.zeros((h, w * 4 + 1), dtype=np.uint8)
    raw[:, 1:] = px.reshape(h, -1)

    def chunk(t, body):
        return struct.pack('>I', len(body)) + t + body + struct.pack('>I', zlib.crc32(t + body))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw.tobytes(), 9)) + chunk(b'IEND', b''))


def write_pngs(pack, data, where):
    pal, blobs = read_pack(data)
    where.mkdir(parents=True, exist_ok=True)
    for num, b in blobs:
        (where / (svg_file(pack, num).stem + '.png')).write_bytes(png_bytes(paint_still(Still(b), pal)))
    print(f'wrote {len(blobs)} pngs to {where}')


# ---- --list and --selftest

def list_sticker(pack, num):
    svg = Svg(svg_file(pack, num))

    def show(el, ind, idx):
        a = el.a
        bits = []
        for k in ('id', 'fill', 'stroke', 'stroke-width', 'opacity', 'transform', 'clip-path', 'filter'):
            if k in a:
                bits.append(f'{k}={a[k]}')
        fp = fingerprint([el])
        at = f' @{fp[0]:g},{fp[1]:g}' if fp else ''
        print('  ' * ind + f'[{idx}] {el.tag}{at} ' + ' '.join(bits))
        for i, k in enumerate(el.kids):
            show(k, ind + 1, i)
    print(f'{svg.name}: root is {svg.root.id or "top" if svg.root is svg.top else svg.root.where()}')
    show(svg.top, 0, 0)


def selftest():
    # arcs: a circle of r 240 stays within 0.01 px
    sub = ellipse_sub(0, 0, 240, 240, 1.0)
    worst = 0
    p0 = sub[0]
    for g in sub[1]:
        pts = bez_eval(seg_ctrl(p0, g), np.linspace(0, 1, 50))
        worst = max(worst, float(np.abs(np.hypot(pts[:, 0], pts[:, 1]) - 240).max()))
        p0 = g[-1]
    assert worst < 0.01, f'arc error {worst}'
    # dashes: 2 10 along a 120 px line gives ten 2 px dashes
    d = dash_subs([[(0, 0), [('L', (120, 0))], False]], [2, 10])
    assert len(d) == 10 and abs(d[1][0][0] - 12) < 1e-9, d[:2]
    # bbox of a cubic with an extremum inside
    x0, y0, x1, y1 = bbox([[(0, 0), [('C', (0, 100), (100, 100), (100, 0))], False]])
    assert abs(y1 - 75) < 1e-9, y1
    # contours: a disc of r 40 traced within 0.05 px
    yy, xx = np.mgrid[0:N, 0:N]
    cx = cy = (100 - O) * S - 0.5
    F = np.clip(40 * S - np.hypot(xx - cx, yy - cy) + 0.5, 0, 1)
    loops = contours(F.astype(float), 0.5)
    assert len(loops) == 1
    r = np.hypot(loops[0][:, 0] - 100, loops[0][:, 1] - 100)
    assert abs(r - 40).max() < 0.05, abs(r - 40).max()
    fit = fit_loop(loops[0])
    pts = np.concatenate([bez_pts(b, np.linspace(0, 1, 20)) for b in fit])
    r = np.hypot(pts[:, 0] - 100, pts[:, 1] - 100)
    assert abs(r - 40).max() < 0.15, abs(r - 40).max()
    # the raster: a 10 px square covers 1600 pixels at 4x
    c = cover(fill_batches([[(0, 0), [('L', (10, 0)), ('L', (10, 10)), ('L', (0, 10))], True]]))
    assert c[2].sum() == 1600, c[2].sum()
    # the png coverage: a square a quarter px off is 100 px2, 0.75 on its edges
    sq = [[(10.25, 10.25), [('L', (20.25, 10.25)), ('L', (20.25, 20.25)), ('L', (10.25, 20.25))], True]]
    r0, c0, f = png_cover(fill_px(sq))
    assert abs(f.sum() - 100) < 1e-9 and abs(f[1, 0] - 0.75) < 1e-9, f.sum()
    # and a ring, even-odd, within 0.1 percent of its area
    ring = [ellipse_sub(100, 100, 40, 40, 1.0), ellipse_sub(100, 100, 20, 20, 1.0)]
    area = png_cover(fill_px(ring), True)[2].sum()
    assert abs(area / (math.pi * 1200) - 1) < 1e-3, area
    print('selftest ok')


def main(argv):
    only = None
    how = 'box3'
    if '--blur' in argv:
        how = argv[argv.index('--blur') + 1]
        if how not in ('gauss', 'box3'):
            fail('--blur gauss|box3')
    if '--selftest' in argv:
        selftest()
        return 0
    name = 'fokia'
    if '--pack' in argv:
        k = argv.index('--pack') + 1
        if k >= len(argv):
            fail('--pack NAME')
        name = argv[k]
    pack = Pack(name)
    run = 'tool/pack_stickers.py' + ('' if name == 'fokia' else f' --pack {name}')
    if '--only' in argv:
        only = {int(x) for x in argv[argv.index('--only') + 1].split(',')}
    if '--list' in argv:
        list_sticker(pack, int(argv[argv.index('--list') + 1]))
        return 0
    data, report, sizes = build(pack, only, how, verbose='--report' in argv)
    if '--png' in argv:
        k = argv.index('--png') + 1
        where = Path(argv[k]) if k < len(argv) and not argv[k].startswith('--') else pack.png
        write_pngs(pack, data, where)
        return 0
    if '--check' in argv:
        old = pack.out.read_bytes() if pack.out.exists() else b''
        if old != data:
            print(f'{pack.out.name} is stale: run {run}')
            return 1
        print(f'{pack.out.name} is up to date')
        return 0
    if only:
        print('\n'.join(report))
        print(f'{len(data)} bytes, not written (--only)')
        return 0
    pack.out.parent.mkdir(parents=True, exist_ok=True)
    pack.out.write_bytes(data)
    if '--report' not in argv:
        print('\n'.join(r for r in report if not r.startswith('  ')))
    big = max(sizes.items(), key=lambda kv: kv[1])
    print(f'wrote {pack.out.name}: {len(data)} bytes, {len(sizes)} stickers, '
          f'biggest {big[0]:02d} at {big[1]} bytes')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except Fail as e:
        print(f'pack_stickers: {e}', file=sys.stderr)
        sys.exit(2)
