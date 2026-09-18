// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

class TiffInfo {
  int orientation = 1;
  String? make;
  String? model;
  String? software;
  String? lens;
  String? serial;
  String? owner;
  String? copyright;
  String? taken;
  String? offset;
  double? lat;
  double? lon;
  double? altitude;
  bool gpsBlank = false;
  bool makerNote = false;
  bool comment = false;
  int thumbnailBytes = 0;
  int otherTags = 0;
}

const _maxEntries = 512;

class _T {
  final Uint8List b;
  final bool le;
  _T(this.b, this.le);

  bool has(int at, int n) => at >= 0 && n >= 0 && at + n <= b.length;
  int u16(int i) => le ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1];
  int u32(int i) => le
      ? b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)
      : (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
}

const _sizes = {
  1: 1,
  2: 1,
  3: 2,
  4: 4,
  5: 8,
  6: 1,
  7: 1,
  8: 2,
  9: 4,
  10: 8,
  11: 4,
  12: 8,
};

TiffInfo? readTiff(Uint8List block) {
  if (block.length < 8) return null;
  final le = block[0] == 0x49 && block[1] == 0x49;
  if (!le && !(block[0] == 0x4D && block[1] == 0x4D)) return null;
  final t = _T(block, le);
  if (t.u16(2) != 42) return null;
  final info = TiffInfo();
  final seen = <int>{};

  int? valueAt(int entry) {
    final type = t.u16(entry + 2);
    final count = t.u32(entry + 4);
    final size = (_sizes[type] ?? 0) * count;
    if (size <= 0) return null;
    if (size <= 4) return entry + 8;
    final off = t.u32(entry + 8);
    return t.has(off, size) ? off : null;
  }

  String? text(int entry) {
    final at = valueAt(entry);
    if (at == null) return null;
    final count = t.u32(entry + 4);
    if (count > 4096 || !t.has(at, count)) return null;
    final s = latin1
        .decode(block.sublist(at, at + count), allowInvalid: true)
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    return s.isEmpty ? null : s;
  }

  double? rational(int at) {
    if (!t.has(at, 8)) return null;
    final d = t.u32(at + 4);
    return d == 0 ? null : t.u32(at) / d;
  }

  double? dms(int entry) {
    if (t.u16(entry + 2) != 5 || t.u32(entry + 4) != 3) return null;
    final at = t.u32(entry + 8);
    final d = rational(at), m = rational(at + 8), s = rational(at + 16);
    if (d == null || m == null) return null;
    return d + m / 60 + (s ?? 0) / 3600;
  }

  int? ifd(int at, void Function(int tag, int entry) each) {
    if (!t.has(at, 2) || !seen.add(at)) return null;
    final n = t.u16(at);
    if (n > _maxEntries || !t.has(at + 2, n * 12)) return null;
    for (var k = 0; k < n; k++) {
      final e = at + 2 + k * 12;
      each(t.u16(e), e);
    }
    final next = at + 2 + n * 12;
    return t.has(next, 4) ? t.u32(next) : 0;
  }

  int? exifAt, gpsAt;
  final next = ifd(t.u32(4), (tag, e) {
    switch (tag) {
      case 0x0112:
        final v = t.u16(e + 8);
        if (v >= 1 && v <= 8) info.orientation = v;
      case 0x010F:
        info.make = text(e);
      case 0x0110:
        info.model = text(e);
      case 0x0131:
        info.software = text(e);
      case 0x0132:
        info.taken ??= text(e);
      case 0x013B:
        info.owner = text(e);
      case 0x8298:
        info.copyright = text(e);
      case 0x8769:
        exifAt = t.u32(e + 8);
      case 0x8825:
        gpsAt = t.u32(e + 8);
      default:
        info.otherTags++;
    }
  });
  if (next == null) return null;

  if (exifAt != null) {
    String? original;
    ifd(exifAt!, (tag, e) {
      switch (tag) {
        case 0x9003:
          original = text(e);
        case 0x9004:
          info.taken ??= text(e);
        case 0x9011:
        case 0x9010:
        case 0x9012:
          info.offset ??= text(e);
        case 0xA434:
          info.lens = text(e);
        case 0xA431:
          info.serial = text(e);
        case 0xA430:
          info.owner ??= text(e);
        case 0x927C:
          info.makerNote = true;
        case 0x9286:
          info.comment = true;
        default:
          info.otherTags++;
      }
    });
    if (original != null) info.taken = original;
  }

  if (gpsAt != null) {
    String? latRef, lonRef;
    int? altRef;
    var hadFix = false;
    ifd(gpsAt!, (tag, e) {
      switch (tag) {
        case 1:
          latRef = text(e);
        case 2:
          hadFix = true;
          info.lat = dms(e);
        case 3:
          lonRef = text(e);
        case 4:
          hadFix = true;
          info.lon = dms(e);
        case 5:
          altRef = block[e + 8];
        case 6:
          info.altitude = rational(t.u32(e + 8));
        default:
          info.otherTags++;
      }
    });
    if (info.lat != null && latRef == 'S') info.lat = -info.lat!;
    if (info.lon != null && lonRef == 'W') info.lon = -info.lon!;
    if (info.altitude != null && altRef == 1) info.altitude = -info.altitude!;
    if (info.lat == null || info.lon == null) {
      info.lat = null;
      info.lon = null;
    } else if (info.lat!.abs() > 90 || info.lon!.abs() > 180) {
      info.lat = null;
      info.lon = null;
      info.otherTags++;
    } else if (info.lat == 0 && info.lon == 0) {
      info.lat = null;
      info.lon = null;
    }
    if (hadFix && info.lat == null) info.gpsBlank = true;
  }

  if (next != 0) {
    int? off, len;
    ifd(next, (tag, e) {
      if (tag == 0x0201) off = t.u32(e + 8);
      if (tag == 0x0202) len = t.u32(e + 8);
    });
    if (off != null && len != null && len! > 0 && t.has(off!, len!)) {
      info.thumbnailBytes = len!;
    } else if (off != null || len != null) {
      info.otherTags++;
    }
  }
  return info;
}
