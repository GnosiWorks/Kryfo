#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# writes the desktop icons from the scalable seal,
# linux/icons/hicolor/scalable/apps/app.kryfo.Kryfo.svg: windows'
# runner/resources/app_icon.ico (16 to 256, the taskbar, tray, setup and
# uninstall all use it), the hicolor pngs and linux/kryfo.png (window, tray).
# small sizes get a bigger seal and bigger drops so both still read; the
# groove ring goes at 24 px and below. needs pillow.
#
#   python3 tool/desktop_icons.py           write the files
#   python3 tool/desktop_icons.py --check   fail when a committed file differs
import io
import math
import os
import re
import struct
import sys
from xml.etree import ElementTree as ET

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE = os.path.join(HERE, '..')
SVG = os.path.join(MOBILE, 'linux', 'icons', 'hicolor', 'scalable', 'apps', 'app.kryfo.Kryfo.svg')
ICO = os.path.join(MOBILE, 'windows', 'runner', 'resources', 'app_icon.ico')
HICOLOR = os.path.join(MOBILE, 'linux', 'icons', 'hicolor', '%dx%d', 'apps', 'app.kryfo.Kryfo.png')
TRAY = os.path.join(MOBILE, 'linux', 'kryfo.png')
NS = '{http://www.w3.org/2000/svg}'

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
HICOLOR_SIZES = [16, 22, 24, 32, 48, 64, 128, 256, 512]

# per size: seal scale, an up-left shift (svg units after the seal scale) to
# make room for the drops, the ring, the drop scale (around each drop's
# middle), how far the drops move out from the seal and the small one away
# from the big one (svg units before the seal scale), and snap: the big drop's middle on
# a pixel corner, the small one's on a pixel centre. 64 and up is the master.
TUNE = {
    16: dict(scale=0.74, shift=(-1.2, -1.2), ring=False, drop=2.4, push=2.8, spread=5.0, snap=True),
    22: dict(scale=0.78, shift=(-1.0, -1.0), ring=False, drop=1.8, push=3.0, spread=4.5, snap=True),
    24: dict(scale=0.78, shift=(-1.0, -1.0), ring=False, drop=1.9, push=2.8, spread=4.5, snap=True),
    32: dict(scale=0.74, ring=True, drop=1.5, push=2.2, spread=3.0, snap=True),
    48: dict(scale=0.74, ring=True, drop=1.25, push=1.4, spread=1.5, snap=True),
}
MASTER = dict(scale=None, ring=True, drop=1.0, push=0.0, spread=0.0)


def flatten(d):
    """absolute M L Q C Z paths as lists of points per subpath"""
    t = re.findall(r'[MLQCZ]|-?\d*\.?\d+(?:e-?\d+)?', d)
    if re.search(r'[a-zA-Z]', re.sub(r'[MLQCZe]', '', d)):
        sys.exit('only absolute M L Q C Z paths')
    subs, cur, i, cmd, p = [], [], 0, None, (0.0, 0.0)
    num = lambda k: float(t[k])
    while i < len(t):
        if t[i] in 'MLQCZ':
            cmd = t[i]
            i += 1
        if cmd == 'M':
            if cur:
                subs.append(cur)
            p = (num(i), num(i + 1))
            cur = [p]
            i += 2
            cmd = 'L'
        elif cmd == 'L':
            p = (num(i), num(i + 1))
            cur.append(p)
            i += 2
        elif cmd == 'Q':
            c, e = (num(i), num(i + 1)), (num(i + 2), num(i + 3))
            for k in range(1, 17):
                u = k / 16
                cur.append(tuple((1 - u) ** 2 * p[j] + 2 * (1 - u) * u * c[j] + u * u * e[j] for j in (0, 1)))
            p = e
            i += 4
        elif cmd == 'C':
            c1, c2, e = (num(i), num(i + 1)), (num(i + 2), num(i + 3)), (num(i + 4), num(i + 5))
            for k in range(1, 25):
                u = k / 24
                cur.append(tuple((1 - u) ** 3 * p[j] + 3 * (1 - u) ** 2 * u * c1[j]
                                 + 3 * (1 - u) * u * u * c2[j] + u ** 3 * e[j] for j in (0, 1)))
            p = e
            i += 6
        elif cmd == 'Z':
            if cur:
                subs.append(cur)
            cur, cmd = [], None
    if cur:
        subs.append(cur)
    return subs


def load():
    root = ET.parse(SVG).getroot()
    vb = [float(v) for v in root.get('viewBox').split()]
    tile = root.find(NS + 'rect')
    g = root.find(NS + 'g')
    m = re.match(r'translate\(([\d.]+) ([\d.]+)\) scale\(([\d.]+)\)', g.get('transform'))
    cuts = [p.get('d') for p in g.iter(NS + 'path') if p.get('fill') == '#000']
    fills = [p for grp in g.findall(NS + 'g') for p in grp.findall(NS + 'path')]
    body = [p.get('d') for p in fills if p.get('mask')]
    drops = [p.get('d') for p in fills if not p.get('mask')]
    if len(cuts) != 2 or len(body) != 1 or len(drops) != 1:
        sys.exit('the scalable svg is not the seal it was')
    ink = g.find(NS + 'g').get('fill')
    return dict(
        vb=vb, rx=float(tile.get('rx')), wax=tile.get('fill'), ink=ink,
        piv=(float(m.group(1)), float(m.group(2))), scale=float(m.group(3)),
        body=flatten(body[0]), k=flatten(cuts[0]), ring=flatten(cuts[1]), drops=flatten(drops[0]))


def mid(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def render(art, size):
    tune = TUNE.get(size, dict(MASTER, scale=art['scale']))
    ss = max(4, 2048 // size)
    n = size * ss
    x0, y0, w, _ = art['vb']
    k = n / w
    s = tune['scale']
    px, py = art['piv']
    # the seal's middle: drops move out from here
    cx, cy = mid(art['body'][0])

    sx, sy = tune.get('shift', (0.0, 0.0))

    def to_px(p):
        # pillow puts pixel centres on whole numbers
        return ((px + (p[0] - px) * s + sx - x0) * k - 0.5, (py + (p[1] - py) * s + sy - y0) * k - 0.5)

    def fill(subs, prep=lambda p: p):
        # even-odd: every subpath flips what it covers
        out = Image.new('1', (n, n), 0)
        for sub in subs:
            one = Image.new('1', (n, n), 0)
            ImageDraw.Draw(one).polygon([to_px(prep(p)) for p in sub], fill=1)
            out = ImageChops.logical_xor(out, one)
        return out

    seal = fill(art['body'])
    seal = ImageChops.subtract(seal.convert('L'), fill(art['k']).convert('L'))
    if tune['ring']:
        seal = ImageChops.subtract(seal, fill(art['ring']).convert('L'))
    ink = seal
    parts = [seal.reduce(ss)]
    # the big drop's middle, to move the small one away from it
    bx, by = mid(art['drops'][0])
    for drop in art['drops']:
        dx, dy = mid(drop)
        ux, uy = dx - cx, dy - cy
        ul = math.hypot(ux, uy)
        vx, vy = dx - bx, dy - by
        vl = math.hypot(vx, vy) or math.inf
        ox = ux / ul * tune['push'] + vx / vl * tune['spread']
        oy = uy / ul * tune['push'] + vy / vl * tune['spread']

        if tune.get('snap'):
            half = 0.0 if drop is art['drops'][0] else 0.5
            for j, (d, o, pv, sh) in enumerate(((dx, ox, px, sx), (dy, oy, py, sy))):
                at = (pv + (d + o - pv) * s + sh - (x0, y0)[j]) * size / w
                fix = (round(at - half) + half - at) * w / size / s
                if j == 0:
                    ox += fix
                else:
                    oy += fix

        def prep(p, dx=dx, dy=dy, ox=ox, oy=oy):
            return (dx + (p[0] - dx) * tune['drop'] + ox, dy + (p[1] - dy) * tune['drop'] + oy)

        one = fill([drop], prep).convert('L')
        parts.append(one.reduce(ss))
        ink = ImageChops.lighter(ink, one)
    tile = Image.new('L', (n, n), 0)
    r = art['rx'] * k
    ImageDraw.Draw(tile).rounded_rectangle((0, 0, n - 1, n - 1), radius=r, fill=255)
    ink = ImageChops.multiply(ink, tile)
    a = tile.reduce(ss)
    i = ink.reduce(ss)
    wax, inkc = rgb(art['wax']), rgb(art['ink'])
    out = Image.new('RGBA', (size, size))
    pa, pi, po = a.load(), i.load(), out.load()
    for y in range(size):
        for x in range(size):
            al = pa[x, y]
            if al == 0:
                po[x, y] = (0, 0, 0, 0)
                continue
            f = min(1.0, pi[x, y] / al)
            po[x, y] = tuple(round(wax[j] + (inkc[j] - wax[j]) * f) for j in range(3)) + (al,)
    readable(size, parts)
    return out


def readable(size, parts):
    """each drop has a solid pixel and no solid pixel touching the seal's
    or the other drop's"""
    solid = [{(x, y) for y in range(size) for x in range(size) if p.getpixel((x, y)) >= 128}
             for p in parts]
    near = lambda a, b: any((x + i, y + j) in b for x, y in a for i in (-1, 0, 1) for j in (-1, 0, 1))
    for d in (1, 2):
        if not any(parts[d].getpixel(q) >= 216 for q in solid[d]):
            sys.exit('%d px: drop %d has no solid pixel' % (size, d))
        if near(solid[d], solid[0]) or near(solid[d], solid[3 - d]):
            sys.exit('%d px: drop %d runs into its neighbour' % (size, d))


def png(im):
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=True)
    return b.getvalue()


def ico(frames):
    """png frames, as windows has read them since vista"""
    head = struct.pack('<HHH', 0, 1, len(frames))
    data, off = b'', 6 + 16 * len(frames)
    for im in frames:
        p = png(im)
        w = im.width % 256
        head += struct.pack('<BBBBHHII', w, w, 0, 0, 1, 32, len(p), off + len(data))
        data += p
    return head + data


def outputs(art):
    got = {s: render(art, s) for s in sorted(set(ICO_SIZES + HICOLOR_SIZES))}
    files = {ICO: [got[s] for s in ICO_SIZES], TRAY: [got[512]]}
    for s in HICOLOR_SIZES:
        files[HICOLOR % (s, s)] = [got[s]]
    return files


def read(path):
    if path.endswith('.ico'):
        d = open(path, 'rb').read()
        out = []
        for j in range(struct.unpack('<H', d[4:6])[0]):
            ln, off = struct.unpack('<II', d[14 + 16 * j:22 + 16 * j])
            out.append(Image.open(io.BytesIO(d[off:off + ln])).convert('RGBA'))
        return out
    return [Image.open(path).convert('RGBA')]


def same(a, b):
    return len(a) == len(b) and all(
        x.size == y.size and ImageChops.difference(x, y).getbbox() is None for x, y in zip(a, b))


if __name__ == '__main__':
    files = outputs(load())
    if '--check' in sys.argv:
        bad = [p for p, fr in files.items() if not os.path.isfile(p) or not same(read(p), fr)]
        for p in bad:
            print('differs: %s' % os.path.relpath(p, MOBILE))
        print('desktop icons are current' if not bad else 'run tool/desktop_icons.py')
        sys.exit(1 if bad else 0)
    for p, fr in files.items():
        open(p, 'wb').write(ico(fr) if p.endswith('.ico') else png(fr[0]))
        if not same(read(p), fr):
            sys.exit('wrote %s but it reads back different' % p)
        print(os.path.relpath(p, MOBILE))
