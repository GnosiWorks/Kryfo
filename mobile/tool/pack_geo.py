#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# packs the two data files the tools tab draws its map from.
#
#   world.bin   natural earth 1:110m admin 0 countries, public domain
#               https://github.com/nvkelso/natural-earth-vector (v5.1.2)
#               geojson/ne_110m_admin_0_countries.geojson
#   places.bin.gz   geonames cities15000, cc-by 4.0
#               https://download.geonames.org/export/dump/cities15000.zip
#
# usage: pack_geo.py ne_110m_admin_0_countries.geojson cities15000.txt outdir
# run by hand when the sources change. the app never fetches anything.
import gzip
import json
import math
import struct
import sys


def q(v):
    return max(-32768, min(32767, round(v * 100)))


def world(path):
    feats = json.load(open(path, encoding='utf-8'))['features']
    out = bytearray(b'KWLD\x01')
    rows = []
    for f in feats:
        p = f['properties']
        cc = p.get('ISO_A2_EH') or p.get('ISO_A2') or '--'
        if len(cc) != 2 or not cc.isalpha():
            cc = '--'
        name = (p.get('NAME_LONG') or p.get('NAME') or '').encode('utf-8')[:255]
        g = f['geometry']
        polys = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]
        rings = []
        for poly in polys:
            ring = []
            for lon, lat in poly[0]:
                pt = (q(lon), q(lat))
                if not ring or ring[-1] != pt:
                    ring.append(pt)
            if len(ring) >= 4:
                rings.append(ring)
        rows.append((cc, name, rings))
    rows.sort(key=lambda r: (r[0], r[1]))
    out += struct.pack('<H', len(rows))
    for cc, name, rings in rows:
        out += cc.encode('ascii') + bytes([len(name)]) + name
        out += struct.pack('<H', len(rings))
        for ring in rings:
            out += struct.pack('<H', len(ring))
            for x, y in ring:
                out += struct.pack('<hh', x, y)
    return bytes(out)


def places(path):
    rows = []
    for line in open(path, encoding='utf-8'):
        c = line.rstrip('\n').split('\t')
        name = c[1].encode('utf-8')[:255]
        lat, lon, cc = float(c[4]), float(c[5]), c[8]
        pop = int(c[14] or 0)
        if len(cc) != 2 or not name:
            continue
        size = 0 if pop <= 0 else min(255, round(math.log10(pop) * 30))
        rows.append((q(lon), q(lat), size, cc.encode('ascii'), name))
    rows.sort()
    out = bytearray(b'KPLC\x01') + struct.pack('<I', len(rows))
    for x, y, size, cc, name in rows:
        out += struct.pack('<hhB', x, y, size) + cc + bytes([len(name)]) + name
    return gzip.compress(bytes(out), 9, mtime=0)


if __name__ == '__main__':
    geo, cities, outdir = sys.argv[1:4]
    for name, data in (('world.bin', world(geo)), ('places.bin.gz', places(cities))):
        open(f'{outdir}/{name}', 'wb').write(data)
        print(name, len(data))
