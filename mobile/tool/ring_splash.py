#!/usr/bin/env python3
"""render kryfo-ring.svg to the splash pngs, with no new dependency.

the svg is two concentric circles and a blur, so it is cheaper to draw it
exactly than to pull in a renderer:

  glow  r=184.3 stroke #F59E0B width 51.2 opacity .35, gaussian sd 15.4
  ring  r=184.3 stroke <linear gradient #FBC56B -> #F59E0B -> #C96A06> width 38.4

all in a 512 viewBox. output is rgba with a transparent background; the
window background behind it supplies #0D0B09.

  fit=full  the ring drawn across the whole canvas (legacy splash)
  fit=safe  ring AND glow inside the middle two thirds, which is what
            android 12+ leaves visible after it masks the icon to a circle
"""
import math
import struct
import sys
import zlib

SRC = 512.0
R = 184.3
RING_W = 38.4
GLOW_W = 51.2
GLOW_A = 0.35
GLOW_SD = 15.4
STOPS = [(0.0, (0xFB, 0xC5, 0x6B)), (0.5, (0xF5, 0x9E, 0x0B)), (1.0, (0xC9, 0x6A, 0x06))]
GLOW_RGB = (0xF5, 0x9E, 0x0B)

# how far the glow reaches from the centre, in source units: half the glow
# stroke past the radius, plus three sigma of blur.
GLOW_EXTENT = R + GLOW_W / 2 + 3 * GLOW_SD


def grad(t):
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    for i in range(len(STOPS) - 1):
        a, ca = STOPS[i]
        b, cb = STOPS[i + 1]
        if t <= b:
            f = 0.0 if b == a else (t - a) / (b - a)
            return tuple(round(ca[k] + (cb[k] - ca[k]) * f) for k in range(3))
    return STOPS[-1][1]


def gaussian_blur(a, w, h, sd):
    if sd <= 0:
        return a
    rad = max(1, int(3 * sd))
    ker = [math.exp(-(i * i) / (2 * sd * sd)) for i in range(-rad, rad + 1)]
    s = sum(ker)
    ker = [k / s for k in ker]
    tmp = [0.0] * (w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            acc = 0.0
            for i, k in enumerate(ker):
                xx = x + i - rad
                if 0 <= xx < w:
                    acc += a[row + xx] * k
            tmp[row + x] = acc
    out = [0.0] * (w * h)
    for y in range(h):
        for x in range(w):
            acc = 0.0
            for i, k in enumerate(ker):
                yy = y + i - rad
                if 0 <= yy < h:
                    acc += tmp[yy * w + x] * k
            out[y * w + x] = acc
    return out


def glow_plane():
    """the blurred glow alpha over the whole source box, drawn small: it is a
    blur, so resolution buys nothing and a pure-python convolution costs a
    lot. sampled bilinearly at output resolution."""
    g = 192
    per = g / SRC
    a = [0.0] * (g * g)
    c = g / 2.0
    lo = (R - GLOW_W / 2) * per
    hi = (R + GLOW_W / 2) * per
    ss = 3
    for y in range(g):
        for x in range(g):
            hit = 0
            for sy in range(ss):
                for sx in range(ss):
                    dx = x + (sx + 0.5) / ss - c
                    dy = y + (sy + 0.5) / ss - c
                    if lo <= math.hypot(dx, dy) <= hi:
                        hit += 1
            if hit:
                a[y * g + x] = GLOW_A * hit / (ss * ss)
    return gaussian_blur(a, g, g, GLOW_SD * per), g


def sample(plane, g, u, v):
    fx, fy = u * (g - 1), v * (g - 1)
    x0, y0 = int(fx), int(fy)
    x1, y1 = min(x0 + 1, g - 1), min(y0 + 1, g - 1)
    tx, ty = fx - x0, fy - y0
    return (plane[y0 * g + x0] * (1 - tx) * (1 - ty) +
            plane[y0 * g + x1] * tx * (1 - ty) +
            plane[y1 * g + x0] * (1 - tx) * ty +
            plane[y1 * g + x1] * tx * ty)


GLOW, GN = glow_plane()


def render(size, fit):
    if fit == "safe":
        scale = (size / 3.0) / GLOW_EXTENT
    else:
        scale = size / SRC
    c = size / 2.0
    half_src_px = (SRC / 2.0) * scale
    ss = 3
    lo = (R - RING_W / 2) * scale
    hi = (R + RING_W / 2) * scale
    px = bytearray()
    for y in range(size):
        px.append(0)  # png filter: none
        for x in range(size):
            hit = 0
            for sy in range(ss):
                for sx in range(ss):
                    dx = x + (sx + 0.5) / ss - c
                    dy = y + (sy + 0.5) / ss - c
                    if lo <= math.hypot(dx, dy) <= hi:
                        hit += 1
            u = (x + 0.5 - c + half_src_px) / (2 * half_src_px)
            v = (y + 0.5 - c + half_src_px) / (2 * half_src_px)
            ga = sample(GLOW, GN, u, v) if 0 <= u <= 1 and 0 <= v <= 1 else 0.0

            if hit:
                cov = hit / (ss * ss)
                sx_ = (x + 0.5 - c) / scale + SRC / 2
                sy_ = (y + 0.5 - c) / scale + SRC / 2
                rc, gc, bc = grad((sx_ / SRC + sy_ / SRC) / 2)
            else:
                cov = 0.0
                rc = gc = bc = 0

            oa = cov + ga * (1 - cov)
            if oa <= 0.002:
                px += b"\x00\x00\x00\x00"
                continue
            r = (rc * cov + GLOW_RGB[0] * ga * (1 - cov)) / oa
            gg = (gc * cov + GLOW_RGB[1] * ga * (1 - cov)) / oa
            b = (bc * cov + GLOW_RGB[2] * ga * (1 - cov)) / oa
            px += bytes((min(255, int(r + .5)), min(255, int(gg + .5)),
                         min(255, int(b + .5)), min(255, int(oa * 255 + .5))))
    return bytes(px)


def write_png(path, size, raw):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    out = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
           chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(out)


if __name__ == "__main__":
    path, size, fit = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    write_png(path, size, render(size, fit))
    print(f"  {path}  {size}x{size}  {fit}")
