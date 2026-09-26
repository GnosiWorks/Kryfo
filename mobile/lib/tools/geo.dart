// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class GeoRing {
  final Float32List lon;
  final Float32List lat;
  final double west, east, south, north;
  const GeoRing(
    this.lon,
    this.lat,
    this.west,
    this.east,
    this.south,
    this.north,
  );

  int get length => lon.length;

  bool holds(double x, double y) {
    if (x < west || x > east || y < south || y > north) return false;
    var inside = false;
    for (var i = 0, j = length - 1; i < length; j = i++) {
      final yi = lat[i], yj = lat[j];
      if ((yi > y) != (yj > y) &&
          x < (lon[j] - lon[i]) * (y - yi) / (yj - yi) + lon[i]) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class GeoCountry {
  final String code;
  final String name;
  final List<GeoRing> rings;
  const GeoCountry(this.code, this.name, this.rings);
}

class GeoHit {
  final GeoCountry country;
  final GeoRing ring;
  const GeoHit(this.country, this.ring);
}

class GeoWorld {
  final List<GeoCountry> countries;
  const GeoWorld(this.countries);

  static GeoWorld parse(Uint8List b) {
    final d = ByteData.sublistView(b);
    if (b.length < 7 || latin1.decode(b.sublist(0, 4)) != 'KWLD' || b[4] != 1) {
      throw const FormatException('not a world file');
    }
    var p = 5;
    final n = d.getUint16(p, Endian.little);
    p += 2;
    final out = <GeoCountry>[];
    for (var c = 0; c < n; c++) {
      final code = latin1.decode(b.sublist(p, p + 2));
      final nameLen = b[p + 2];
      p += 3;
      final name = utf8.decode(b.sublist(p, p + nameLen), allowMalformed: true);
      p += nameLen;
      final ringCount = d.getUint16(p, Endian.little);
      p += 2;
      final rings = <GeoRing>[];
      for (var r = 0; r < ringCount; r++) {
        final pts = d.getUint16(p, Endian.little);
        p += 2;
        final lon = Float32List(pts), lat = Float32List(pts);
        var w = 180.0, e = -180.0, s = 90.0, nn = -90.0;
        for (var k = 0; k < pts; k++) {
          final x = d.getInt16(p, Endian.little) / 100;
          final y = d.getInt16(p + 2, Endian.little) / 100;
          p += 4;
          lon[k] = x;
          lat[k] = y;
          w = math.min(w, x);
          e = math.max(e, x);
          s = math.min(s, y);
          nn = math.max(nn, y);
        }
        rings.add(GeoRing(lon, lat, w, e, s, nn));
      }
      out.add(GeoCountry(code, name, rings));
    }
    return GeoWorld(out);
  }

  GeoHit? at(double lat, double lon) {
    GeoHit? best;
    var bestArea = double.infinity;
    for (final c in countries) {
      for (final r in c.rings) {
        if (!r.holds(lon, lat)) continue;
        final area = (r.east - r.west) * (r.north - r.south);
        if (area < bestArea) {
          bestArea = area;
          best = GeoHit(c, r);
        }
      }
    }
    return best;
  }

  String? nameOf(String code) {
    for (final c in countries) {
      if (c.code == code) return c.name;
    }
    return null;
  }
}

class GeoPlace {
  final String name;
  final String country;
  final double lat;
  final double lon;
  final int size;
  const GeoPlace(this.name, this.country, this.lat, this.lon, this.size);
}

class NearPlace {
  final GeoPlace place;
  final double km;
  const NearPlace(this.place, this.km);
}

double kmBetween(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = p2 - p1, dl = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

class GeoPlaces {
  final List<GeoPlace> all;
  const GeoPlaces(this.all);

  static GeoPlaces parse(Uint8List b) {
    final d = ByteData.sublistView(b);
    if (b.length < 9 || latin1.decode(b.sublist(0, 4)) != 'KPLC' || b[4] != 1) {
      throw const FormatException('not a places file');
    }
    final n = d.getUint32(5, Endian.little);
    var p = 9;
    final out = <GeoPlace>[];
    for (var k = 0; k < n; k++) {
      final lon = d.getInt16(p, Endian.little) / 100;
      final lat = d.getInt16(p + 2, Endian.little) / 100;
      final size = b[p + 4];
      final cc = latin1.decode(b.sublist(p + 5, p + 7));
      final len = b[p + 7];
      p += 8;
      out.add(
        GeoPlace(
          utf8.decode(b.sublist(p, p + len), allowMalformed: true),
          cc,
          lat,
          lon,
          size,
        ),
      );
      p += len;
    }
    return GeoPlaces(out);
  }

  NearPlace? nearest(double lat, double lon, {double withinKm = 150}) {
    GeoPlace? best;
    var bestKm = withinKm;
    final reach = withinKm / 111.0;
    final wide = reach / math.max(0.05, math.cos(lat * math.pi / 180));
    for (final c in all) {
      if ((c.lat - lat).abs() > reach) continue;
      var dx = (c.lon - lon).abs();
      if (dx > 180) dx = 360 - dx;
      if (dx > wide) continue;
      final km = kmBetween(lat, lon, c.lat, c.lon);
      if (km < bestKm) {
        bestKm = km;
        best = c;
      }
    }
    return best == null ? null : NearPlace(best, bestKm);
  }

  List<GeoPlace> biggestIn(
    double west,
    double east,
    double south,
    double north, {
    int count = 4,
    double apart = 0,
  }) {
    final inside = [
      for (final c in all)
        if (c.lon >= west && c.lon <= east && c.lat >= south && c.lat <= north)
          c,
    ]..sort((a, b) => b.size.compareTo(a.size));
    final out = <GeoPlace>[];
    for (final c in inside) {
      if (out.length >= count) break;
      if (out.any(
        (o) => (o.lon - c.lon).abs() < apart && (o.lat - c.lat).abs() < apart,
      )) {
        continue;
      }
      out.add(c);
    }
    return out;
  }
}

class GeoView {
  final double west, east, south, north;
  const GeoView(this.west, this.east, this.south, this.north);
}

GeoView viewFor(double lat, double lon, GeoRing? ring, double aspect) {
  var w = ring?.west ?? lon - 6, e = ring?.east ?? lon + 6;
  var s = ring?.south ?? lat - 4, n = ring?.north ?? lat + 4;
  const most = 50.0;
  if (e - w > most) {
    w = lon - most / 2;
    e = lon + most / 2;
  }
  if (n - s > most * 0.7) {
    s = lat - most * 0.35;
    n = lat + most * 0.35;
  }
  final padX = math.max((e - w) * 0.35, 2.0),
      padY = math.max((n - s) * 0.35, 1.5);
  w -= padX;
  e += padX;
  s -= padY;
  n += padY;
  final k = math.max(
    0.2,
    math.cos(((s + n) / 2).clamp(-80.0, 80.0) * math.pi / 180),
  );
  var width = (e - w) * k, height = n - s;
  if (width / height < aspect) {
    width = height * aspect;
  } else {
    height = width / aspect;
  }
  final cx = (w + e) / 2;
  var cy = (s + n) / 2;
  cy = cy.clamp(-90 + height / 2, 90 - height / 2).toDouble();
  return GeoView(
    cx - width / k / 2,
    cx + width / k / 2,
    cy - height / 2,
    cy + height / 2,
  );
}

String coordsLine(double lat, double lon) {
  // no-break spaces, so in arabic and persian a number never leaves its N
  // or E on a line of its own
  String one(double v, String pos, String neg) =>
      '${v.abs().toStringAsFixed(5)}°\u00a0${v >= 0 ? pos : neg}';
  return '${one(lat, 'N', 'S')} · ${one(lon, 'E', 'W')}';
}
