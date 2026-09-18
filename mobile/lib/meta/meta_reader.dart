// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'byte_source.dart';
import 'tiff.dart';

enum MetaKind { jpeg, png, webp, heif, gif, mp4, unknown }

enum MetaStatus { nothing, found, unreadable, unknown }

class GpsFix {
  final double lat;
  final double lon;
  final double? altitude;
  final String from;
  const GpsFix(this.lat, this.lon, {this.altitude, required this.from});
}

class MetaReport {
  MetaKind kind = MetaKind.unknown;
  MetaStatus status = MetaStatus.unknown;
  String? why;

  GpsFix? gps;
  bool gpsBlank = false;
  String? make;
  String? model;
  String? software;
  String? lens;
  String? serial;
  String? owner;
  String? copyright;
  String? taken;
  String? offset;
  double? accuracyM;
  double? fNumber;
  double? exposure;
  DateTime? created;
  int orientation = 1;
  int thumbnailBytes = 0;
  int otherExifTags = 0;
  bool xmp = false;
  bool iptc = false;
  bool makerNote = false;
  bool comment = false;
  bool secondImage = false;
  bool embeddedVideo = false;
  bool credentials = false;
  bool savedTime = false;
  bool stamps = false;
  int trailingBytes = 0;
  final List<String> textKeys = [];
  final List<String> videoTags = [];
  final List<String> extra = [];

  bool get anything =>
      gps != null ||
      gpsBlank ||
      make != null ||
      model != null ||
      software != null ||
      lens != null ||
      serial != null ||
      owner != null ||
      copyright != null ||
      taken != null ||
      created != null ||
      thumbnailBytes > 0 ||
      otherExifTags > 0 ||
      xmp ||
      iptc ||
      makerNote ||
      comment ||
      secondImage ||
      embeddedVideo ||
      credentials ||
      savedTime ||
      stamps ||
      trailingBytes > 0 ||
      textKeys.isNotEmpty ||
      videoTags.isNotEmpty ||
      extra.isNotEmpty;
}

class _Unreadable implements Exception {
  final String why;
  const _Unreadable(this.why);
}

const _maxBlock = 1 << 20;
const _maxBoxes = 20000;
const _scanChunk = 64 * 1024;

MetaReport readMeta(ByteSource src) => _read(src, false);

MetaReport readMetaStrict(ByteSource src) => _read(src, true);

MetaReport _read(ByteSource src, bool strict) {
  final r = MetaReport();
  try {
    r.kind = _kindOf(src);
    switch (r.kind) {
      case MetaKind.jpeg:
        _jpeg(src, r);
      case MetaKind.png:
        _png(src, r);
      case MetaKind.webp:
        _webp(src, r);
      case MetaKind.heif:
        _heif(src, r);
      case MetaKind.gif:
        _gif(src, r);
      case MetaKind.mp4:
        _mp4(src, r);
      case MetaKind.unknown:
        r.status = MetaStatus.unknown;
        return r;
    }
    r.status = r.anything ? MetaStatus.found : MetaStatus.nothing;
  } on _Unreadable catch (e) {
    r.status = MetaStatus.unreadable;
    r.why = e.why;
  } on RangeError {
    r.status = MetaStatus.unreadable;
    r.why = 'ends before it should';
  } on FormatException catch (e) {
    r.status = MetaStatus.unreadable;
    r.why = e.message;
  } catch (e) {
    if (strict) rethrow;
    r.status = MetaStatus.unreadable;
    r.why = 'could not be read';
  }
  return r;
}

String _tag(Uint8List b, int i) => latin1.decode(b.sublist(i, i + 4));
int _be16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int _be32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int _le32(Uint8List b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

bool _allZero(Uint8List b) {
  for (final x in b) {
    if (x != 0) return false;
  }
  return true;
}

const _heifBrands = {
  'heic',
  'heix',
  'hevc',
  'hevx',
  'heim',
  'heis',
  'mif1',
  'msf1',
  'avif',
  'avis',
};
const _mp4Brands = {
  'isom',
  'iso2',
  'iso4',
  'iso5',
  'iso6',
  'mp41',
  'mp42',
  'avc1',
  'M4V ',
  'M4A ',
  'qt  ',
  '3gp4',
  '3gp5',
  '3gp6',
  '3g2a',
  'mmp4',
  'dash',
  'MSNV',
};

MetaKind _kindOf(ByteSource s) {
  if (s.length < 12) return MetaKind.unknown;
  final h = s.read(0, s.length < 64 ? s.length : 64);
  if (h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) return MetaKind.jpeg;
  if (h[0] == 0x89 &&
      h[1] == 0x50 &&
      h[2] == 0x4E &&
      h[3] == 0x47 &&
      h[4] == 0x0D &&
      h[5] == 0x0A &&
      h[6] == 0x1A &&
      h[7] == 0x0A) {
    return MetaKind.png;
  }
  if (_tag(h, 0) == 'RIFF' && _tag(h, 8) == 'WEBP') return MetaKind.webp;
  if (h[0] == 0x47 && h[1] == 0x49 && h[2] == 0x46 && h[3] == 0x38) {
    return MetaKind.gif;
  }
  if (_tag(h, 4) == 'ftyp') {
    final size = _be32(h, 0);
    final end = size < 16 ? 16 : (size > h.length ? h.length : size);
    var mp4 = false;
    for (var i = 8; i + 4 <= end; i += 4) {
      if (i == 12) continue;
      final b = _tag(h, i);
      if (_heifBrands.contains(b)) return MetaKind.heif;
      if (_mp4Brands.contains(b)) mp4 = true;
    }
    return mp4 ? MetaKind.mp4 : MetaKind.mp4;
  }
  final t = _tag(h, 4);
  if (t == 'moov' || t == 'mdat' || t == 'wide' || t == 'free') {
    return MetaKind.mp4;
  }
  return MetaKind.unknown;
}

void _takeExif(Uint8List tiff, MetaReport r) {
  final e = readTiff(tiff);
  if (e == null) {
    if (!_allZero(tiff)) r.extra.add('exif that cannot be read');
    return;
  }
  r.orientation = e.orientation;
  r.make ??= e.make;
  r.model ??= e.model;
  r.software ??= e.software;
  r.lens ??= e.lens;
  r.serial ??= e.serial;
  r.owner ??= e.owner;
  r.copyright ??= e.copyright;
  r.taken ??= e.taken;
  r.offset ??= e.offset;
  r.accuracyM ??= e.accuracyM;
  r.fNumber ??= e.fNumber;
  r.exposure ??= e.exposure;
  if (e.gpsBlank) r.gpsBlank = true;
  if (e.makerNote) r.makerNote = true;
  if (e.comment) r.comment = true;
  if (e.thumbnailBytes > r.thumbnailBytes) r.thumbnailBytes = e.thumbnailBytes;
  r.otherExifTags += e.otherTags;
  if (e.lat != null && e.lon != null) {
    r.gps ??= GpsFix(e.lat!, e.lon!, altitude: e.altitude, from: 'exif');
  }
}

final _xmpLat = RegExp(
  r'GPSLatitude(?:>|=")\s*(\d{1,3})[,\s]+(\d{1,2}(?:\.\d+)?)(?:[,\s]+(\d{1,2}(?:\.\d+)?))?\s*([NS])',
);
final _xmpLon = RegExp(
  r'GPSLongitude(?:>|=")\s*(\d{1,3})[,\s]+(\d{1,2}(?:\.\d+)?)(?:[,\s]+(\d{1,2}(?:\.\d+)?))?\s*([EW])',
);

void _takeXmp(Uint8List body, MetaReport r) {
  if (_allZero(body)) return;
  r.xmp = true;
  final s = latin1.decode(body, allowInvalid: true);
  double? one(RegExp re, String neg) {
    final m = re.firstMatch(s);
    if (m == null) return null;
    final d = double.parse(m.group(1)!);
    final mi = double.parse(m.group(2)!);
    final se = m.group(3) == null ? 0.0 : double.parse(m.group(3)!);
    final v = d + mi / 60 + se / 3600;
    return m.group(4) == neg ? -v : v;
  }

  final lat = one(_xmpLat, 'S'), lon = one(_xmpLon, 'W');
  if (lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180) {
    r.gps ??= GpsFix(lat, lon, from: 'xmp');
  }
  if (s.contains('GContainer') || s.contains('MotionPhoto')) {
    r.embeddedVideo = true;
  }
}

bool _startsWith(Uint8List b, List<int> p, [int at = 0]) {
  if (b.length < at + p.length) return false;
  for (var i = 0; i < p.length; i++) {
    if (b[at + i] != p[i]) return false;
  }
  return true;
}

const _exifHead = [69, 120, 105, 102, 0, 0];
final _xmpHead = [...latin1.encode('http://ns.adobe.com/xap/1.0/'), 0];
final _xmpExtHead = [...latin1.encode('http://ns.adobe.com/xmp/extension/'), 0];
final _iccHead = [...latin1.encode('ICC_PROFILE'), 0];
final _mpfHead = [...latin1.encode('MPF'), 0];
final _psHead = latin1.encode('Photoshop 3.0');
final _adobeHead = latin1.encode('Adobe');

void _jpeg(ByteSource s, MetaReport r) {
  var i = 2;
  while (true) {
    if (i + 4 > s.length) throw const _Unreadable('no picture data');
    final h = s.read(i, 4);
    if (h[0] != 0xFF) throw const _Unreadable('broken segment');
    final m = h[1];
    if (m == 0xFF) {
      i += 1;
      continue;
    }
    if (m == 0xD8 || (m >= 0xD0 && m <= 0xD7) || m == 0x01) {
      i += 2;
      continue;
    }
    if (m == 0xDA) break;
    final len = _be16(h, 2);
    if (len < 2 || i + 2 + len > s.length) {
      throw const _Unreadable('segment runs past the file');
    }
    final body = s.read(i + 4, len - 2);
    _jpegSegment(m, body, r);
    i += 2 + len;
  }
  final end = _jpegEnd(s, i, r);
  if (end < s.length) {
    r.trailingBytes = s.length - end;
    _sniffTrailer(s, end, r);
  }
}

void _jpegSegment(int m, Uint8List body, MetaReport r) {
  if (m == 0xE1) {
    if (_startsWith(body, _exifHead)) {
      _takeExif(Uint8List.sublistView(body, 6), r);
    } else if (_startsWith(body, _xmpHead)) {
      _takeXmp(Uint8List.sublistView(body, _xmpHead.length), r);
    } else if (_startsWith(body, _xmpExtHead)) {
      r.xmp = true;
    } else {
      r.extra.add('app1');
    }
  } else if (m == 0xE2) {
    if (_startsWith(body, _iccHead)) return;
    if (_startsWith(body, _mpfHead)) {
      r.secondImage = true;
    } else {
      r.extra.add('app2');
    }
  } else if (m == 0xED) {
    if (_startsWith(body, _psHead)) {
      r.iptc = true;
    } else {
      r.extra.add('app13');
    }
  } else if (m == 0xEE && _startsWith(body, _adobeHead)) {
    return;
  } else if (m == 0xE0) {
    return;
  } else if (m >= 0xE3 && m <= 0xEF) {
    r.extra.add('app${m - 0xE0}');
  } else if (m == 0xFE) {
    r.comment = true;
  }
}

int _jpegEnd(ByteSource s, int sos, MetaReport r) {
  var i = sos;
  while (true) {
    final h = s.read(i, 4);
    final hl = _be16(h, 2);
    var j = i + 2 + hl;
    if (hl < 2 || j > s.length) throw const _Unreadable('broken scan header');
    int? marker;
    while (marker == null) {
      if (j >= s.length) throw const _Unreadable('no end of picture');
      final n = s.length - j < _scanChunk ? s.length - j : _scanChunk;
      final c = s.read(j, n);
      var k = 0;
      var found = false;
      while (k < n) {
        final f = c.indexOf(0xFF, k);
        if (f < 0) break;
        if (f + 1 >= n) {
          if (j + f + 1 >= s.length) {
            throw const _Unreadable('no end of picture');
          }
          j += f;
          found = true;
          final two = s.read(j, 2);
          final x = two[1];
          if (x == 0x00 || (x >= 0xD0 && x <= 0xD7)) {
            j += 2;
          } else if (x == 0xFF) {
            j += 1;
          } else {
            marker = x;
          }
          break;
        }
        final x = c[f + 1];
        if (x == 0x00 || (x >= 0xD0 && x <= 0xD7)) {
          k = f + 2;
        } else if (x == 0xFF) {
          k = f + 1;
        } else {
          j += f;
          marker = x;
          found = true;
          break;
        }
      }
      if (!found) j += n;
    }
    while (true) {
      if (marker == 0xD9) return j + 2;
      if (marker == 0xDA) break;
      final sh = s.read(j, 4);
      final len = _be16(sh, 2);
      if (len < 2 || j + 2 + len > s.length) {
        throw const _Unreadable('segment runs past the file');
      }
      _jpegSegment(marker!, s.read(j + 4, len - 2), r);
      j += 2 + len;
      final nx = s.read(j, 2);
      if (nx[0] != 0xFF) throw const _Unreadable('broken segment');
      marker = nx[1];
    }
    i = j;
  }
}

void _sniffTrailer(ByteSource s, int from, MetaReport r) {
  final n = s.length - from;
  final head = s.read(from, n < _scanChunk ? n : _scanChunk);
  final text = latin1.decode(head, allowInvalid: true);
  if (text.contains('ftyp')) r.embeddedVideo = true;
  if (text.contains('SEFH') || text.contains('SEFT')) {
    r.extra.add('samsung trailer');
  }
  if (n > _scanChunk) {
    final tail = latin1.decode(
      s.read(s.length - _scanChunk, _scanChunk),
      allowInvalid: true,
    );
    if (tail.contains('SEFT')) r.extra.add('samsung trailer');
    if (tail.contains('ftyp')) r.embeddedVideo = true;
  }
}

const _pngKeep = {
  'IHDR',
  'PLTE',
  'IDAT',
  'IEND',
  'tRNS',
  'gAMA',
  'cHRM',
  'sRGB',
  'iCCP',
  'sBIT',
  'cICP',
  'mDCv',
  'cLLi',
  'bKGD',
  'pHYs',
  'sPLT',
  'hIST',
  'acTL',
  'fcTL',
  'fdAT',
};

void _png(ByteSource s, MetaReport r) {
  var i = 8;
  var boxes = 0;
  while (true) {
    if (++boxes > _maxBoxes) throw const _Unreadable('too many chunks');
    final h = s.read(i, 8);
    final len = _be32(h, 0);
    final type = _tag(h, 4);
    final end = i + 12 + len;
    if (len < 0 || end > s.length) {
      throw const _Unreadable('chunk runs past the file');
    }
    if (type == 'eXIf') {
      if (len > _maxBlock) throw const _Unreadable('exif too large');
      _takeExif(s.read(i + 8, len), r);
    } else if (type == 'tEXt' || type == 'zTXt' || type == 'iTXt') {
      final body = s.read(i + 8, len < _maxBlock ? len : _maxBlock);
      final z = body.indexOf(0);
      final key = latin1.decode(
        body.sublist(0, z < 0 ? (body.length < 79 ? body.length : 79) : z),
        allowInvalid: true,
      );
      if (key == 'XML:com.adobe.xmp') {
        _takeXmp(body, r);
      } else {
        r.textKeys.add(key);
      }
    } else if (type == 'tIME') {
      r.savedTime = true;
    } else if (type == 'caBX') {
      r.credentials = true;
    } else if (!_pngKeep.contains(type)) {
      r.extra.add('chunk $type');
    }
    i = end;
    if (type == 'IEND') break;
  }
  if (i < s.length) r.trailingBytes = s.length - i;
}

void _webp(ByteSource s, MetaReport r) {
  final riffEnd = 8 + _le32(s.read(4, 4), 0);
  if (riffEnd > s.length) throw const _Unreadable('riff runs past the file');
  var i = 12;
  var boxes = 0;
  while (i < riffEnd) {
    if (++boxes > _maxBoxes) throw const _Unreadable('too many chunks');
    final h = s.read(i, 8);
    final type = _tag(h, 0);
    final len = _le32(h, 4);
    if (len < 0 || i + 8 + len > s.length) {
      throw const _Unreadable('chunk runs past the file');
    }
    if (type == 'EXIF') {
      if (len > _maxBlock) throw const _Unreadable('exif too large');
      final b = s.read(i + 8, len);
      _takeExif(_startsWith(b, _exifHead) ? Uint8List.sublistView(b, 6) : b, r);
    } else if (type == 'XMP ') {
      _takeXmp(s.read(i + 8, len < _maxBlock ? len : _maxBlock), r);
    } else if (type == 'VP8X' && len >= 1) {
      final f = s.read(i + 8, 1)[0];
      if (f & 0x08 != 0) r.extra.add('exif flag set');
      if (f & 0x04 != 0) r.extra.add('xmp flag set');
    }
    i += 8 + len + (len & 1);
  }
  final end = riffEnd + (riffEnd & 1);
  if (end < s.length) r.trailingBytes = s.length - end;
}

void _gif(ByteSource s, MetaReport r) {
  if (s.length < 13) throw const _Unreadable('too short');
  final lsd = s.read(0, 13);
  var i = 13;
  if (lsd[10] & 0x80 != 0) i += 3 * (1 << ((lsd[10] & 7) + 1));
  int sub(int p) {
    var n = 0;
    while (true) {
      if (++n > 1 << 22) throw const _Unreadable('too many blocks');
      final l = s.read(p, 1)[0];
      p += 1 + l;
      if (l == 0) return p;
      if (p > s.length) throw const _Unreadable('block runs past the file');
    }
  }

  var boxes = 0;
  while (true) {
    if (++boxes > _maxBoxes * 8) throw const _Unreadable('too many blocks');
    final b = s.read(i, 1)[0];
    if (b == 0x3B) {
      if (i + 1 < s.length) r.trailingBytes = s.length - i - 1;
      return;
    }
    if (b == 0x2C) {
      final d = s.read(i, 10);
      var p = i + 10;
      if (d[9] & 0x80 != 0) p += 3 * (1 << ((d[9] & 7) + 1));
      i = sub(p + 1);
    } else if (b == 0x21) {
      final label = s.read(i + 1, 1)[0];
      if (label == 0xFE) {
        r.comment = true;
      } else if (label == 0xFF) {
        final id = latin1.decode(s.read(i + 3, 11), allowInvalid: true);
        if (id == 'XMP DataXMP') {
          r.xmp = true;
        } else if (id != 'NETSCAPE2.0' && id != 'ANIMEXTS1.0') {
          r.extra.add('app block $id');
        }
      }
      i = sub(i + 2);
    } else {
      throw const _Unreadable('not a gif block');
    }
  }
}

class _Box {
  final String type;
  final int body;
  final int end;
  const _Box(this.type, this.body, this.end);
}

List<_Box> _boxes(ByteSource s, int from, int to, List<int> count) {
  final out = <_Box>[];
  var i = from;
  while (i < to) {
    if (++count[0] > _maxBoxes) throw const _Unreadable('too many boxes');
    if (i + 8 > to) throw const _Unreadable('box header cut short');
    final h = s.read(i, 8);
    var size = _be32(h, 0);
    final type = _tag(h, 4);
    var head = 8;
    if (size == 1) {
      if (i + 16 > to) throw const _Unreadable('box header cut short');
      final x = s.read(i + 8, 8);
      if (_be32(x, 0) > 0x7fff) throw const _Unreadable('box too large');
      size = (_be32(x, 0) << 32) | _be32(x, 4);
      head = 16;
    } else if (size == 0) {
      size = to - i;
    }
    if (size < head || i + size > to) {
      throw const _Unreadable('box runs past its parent');
    }
    out.add(_Box(type, i + head, i + size));
    i += size;
  }
  return out;
}

Uint8List _payload(ByteSource s, _Box b) {
  final n = b.end - b.body;
  if (n > _maxBlock) throw const _Unreadable('box too large to read');
  return s.read(b.body, n);
}

const _heifTop = {'ftyp', 'meta', 'mdat', 'free', 'skip'};
const _heifItems = {
  'hvc1',
  'hev1',
  'av01',
  'avc1',
  'jpeg',
  'grid',
  'iovl',
  'iden',
};

String _printable(String tag) => tag.replaceAll(RegExp(r'[^A-Za-z0-9]'), '?');

void _heif(ByteSource s, MetaReport r) {
  final count = [0];
  final top = _boxes(s, 0, s.length, count);
  final metas = top.where((b) => b.type == 'meta').toList();
  if (metas.isEmpty) throw const _Unreadable('no meta box');
  final meta = metas.first;
  final inner = _boxes(s, meta.body + 4, meta.end, count);
  for (final b in top) {
    if (b.type == 'moov' || b.type == 'mpvd') {
      r.embeddedVideo = true;
    } else if (b.type == 'uuid') {
      r.extra.add('uuid box');
    } else if (!_heifTop.contains(b.type)) {
      r.extra.add('${_printable(b.type)} box');
    }
  }

  final want = <int, String>{};
  for (final x in inner.where((b) => b.type == 'iinf')) {
    final p = _payload(s, x);
    final v = p[0];
    final at = x.body + 4 + (v == 0 ? 2 : 4);
    for (final e in _boxes(s, at, x.end, count)) {
      if (e.type != 'infe') continue;
      final ep = _payload(s, e);
      final ev = ep[0];
      if (ev < 2) continue;
      var q = 4;
      final idLen = ev == 2 ? 2 : 4;
      final id = idLen == 2 ? _be16(ep, q) : _be32(ep, q);
      q += idLen + 2;
      final type = _tag(ep, q);
      q += 4;
      if (type == 'Exif') {
        want[id] = 'exif';
      } else if (type == 'mime') {
        final rest = latin1
            .decode(ep.sublist(q), allowInvalid: true)
            .toLowerCase();
        if (rest.contains('xmp') || rest.contains('rdf+xml')) {
          want[id] = 'xmp';
        } else {
          r.extra.add('attached data');
        }
      } else if (!_heifItems.contains(type)) {
        r.extra.add('${_printable(type)} item');
      }
    }
  }
  if (want.isEmpty) return;

  final ilocs = inner.where((b) => b.type == 'iloc').toList();
  if (ilocs.isEmpty) throw const _Unreadable('items without a location table');
  final idat = inner.where((b) => b.type == 'idat').toList();
  final p = _payload(s, ilocs.first);
  var q = 0;
  final v = p[q];
  if (v > 2) throw const _Unreadable('unknown location table');
  q += 4;
  final offSize = p[q] >> 4, lenSize = p[q] & 15;
  final baseSize = p[q + 1] >> 4;
  final idxSize = v == 0 ? 0 : p[q + 1] & 15;
  q += 2;
  final n = v < 2 ? _be16(p, q) : _be32(p, q);
  q += v < 2 ? 2 : 4;
  int num(int size) {
    if (size == 0) return 0;
    if (size == 4) {
      final x = _be32(p, q);
      q += 4;
      return x;
    }
    if (size == 8) {
      if (_be32(p, q) != 0) throw const _Unreadable('offset too large');
      final x = _be32(p, q + 4);
      q += 8;
      return x;
    }
    throw const _Unreadable('odd field size');
  }

  for (var k = 0; k < n; k++) {
    final idLen = v < 2 ? 2 : 4;
    final id = idLen == 2 ? _be16(p, q) : _be32(p, q);
    q += idLen;
    var method = 0;
    if (v > 0) {
      method = _be16(p, q) & 15;
      q += 2;
    }
    q += 2;
    final base = num(baseSize);
    final extents = _be16(p, q);
    q += 2;
    final parts = BytesBuilder(copy: false);
    for (var e = 0; e < extents; e++) {
      if (idxSize > 0) num(idxSize);
      final off = num(offSize), len = num(lenSize);
      if (!want.containsKey(id)) continue;
      int at;
      if (method == 0) {
        at = base + off;
      } else if (method == 1 && idat.isNotEmpty) {
        at = idat.first.body + base + off;
      } else {
        throw const _Unreadable('item stored in a way not handled');
      }
      if (len <= 0 || len > _maxBlock) {
        throw const _Unreadable('item too large');
      }
      parts.add(s.read(at, len));
    }
    final what = want[id];
    if (what == null) continue;
    final body = parts.toBytes();
    if (body.isEmpty || _allZero(body)) continue;
    if (what == 'exif') {
      if (body.length < 8) {
        r.extra.add('exif that cannot be read');
        continue;
      }
      final skip = 4 + _be32(body, 0);
      if (skip < 4 || skip >= body.length) {
        r.extra.add('exif that cannot be read');
        continue;
      }
      _takeExif(Uint8List.sublistView(body, skip), r);
    } else {
      _takeXmp(body, r);
    }
  }
}

const _mp4Into = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf'};
final _mac = DateTime.utc(1904, 1, 1);

void _mp4(ByteSource s, MetaReport r) {
  final count = [0];
  void walk(int from, int to, int depth) {
    if (depth > 8) throw const _Unreadable('nested too deep');
    for (final b in _boxes(s, from, to, count)) {
      if (_mp4Into.contains(b.type)) {
        walk(b.body, b.end, depth + 1);
      } else if (b.type == 'mvhd' || b.type == 'tkhd' || b.type == 'mdhd') {
        final p = s.read(b.body, (b.end - b.body).clamp(0, 24));
        if (p.length < 12) throw const _Unreadable('short header box');
        final v1 = p[0] == 1;
        if (v1 && p.length < 20) throw const _Unreadable('short header box');
        final c = v1 ? (_be32(p, 4) << 32) | _be32(p, 8) : _be32(p, 4);
        final m = v1 ? (_be32(p, 12) << 32) | _be32(p, 16) : _be32(p, 8);
        if (c != 0 || m != 0) {
          r.stamps = true;
          if (b.type == 'mvhd' && c != 0 && c < 0xFFFFFFFF * 2) {
            r.created = _mac.add(Duration(seconds: c));
          }
        }
      } else if (b.type == 'udta') {
        _udta(s, b, r, count);
      } else if (b.type == 'meta') {
        _qtMeta(s, b, r, count);
      } else if (b.type == 'uuid') {
        final p = s.read(b.body, (b.end - b.body).clamp(0, 16));
        if (!_allZero(p)) r.videoTags.add('uuid');
      }
    }
  }

  walk(0, s.length, 0);
}

final _iso6709 = RegExp(
  r'([+-]\d{1,3}(?:\.\d+)?)([+-]\d{1,3}(?:\.\d+)?)([+-]\d+(?:\.\d+)?)?',
);

void _place(String text, MetaReport r) {
  final m = _iso6709.firstMatch(text);
  if (m == null) return;
  final lat = double.tryParse(m.group(1)!), lon = double.tryParse(m.group(2)!);
  if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return;
  final alt = m.group(3) == null ? null : double.tryParse(m.group(3)!);
  r.gps ??= GpsFix(lat, lon, altitude: alt, from: 'video');
}

void _udta(ByteSource s, _Box u, MetaReport r, List<int> count) {
  for (final b in _boxes(s, u.body, u.end, count)) {
    if (b.type == 'free' || b.type == 'skip') continue;
    final n = b.end - b.body;
    final p = s.read(b.body, n < 4096 ? n : 4096);
    if (_allZero(p)) continue;
    if (b.type == 'meta') {
      _qtMeta(s, b, r, count);
      continue;
    }
    r.videoTags.add(b.type);
    final text = latin1.decode(p, allowInvalid: true);
    if (b.type == _c('xyz')) {
      _place(text, r);
    } else if (b.type == _c('mak') && p.length > 4) {
      r.make ??= _clean(latin1.decode(p.sublist(4), allowInvalid: true));
    } else if (b.type == _c('mod') && p.length > 4) {
      r.model ??= _clean(latin1.decode(p.sublist(4), allowInvalid: true));
    } else if (b.type == _c('swr') && p.length > 4) {
      r.software ??= _clean(latin1.decode(p.sublist(4), allowInvalid: true));
    } else if (b.type == 'loci' && p.length >= 6) {
      var q = 6;
      while (q < p.length && p[q] != 0) {
        q++;
      }
      q += 2;
      if (q + 12 <= p.length) {
        double fx(int i) => _be32(p, i).toSigned(32) / 65536.0;
        final lon = fx(q), lat = fx(q + 4), alt = fx(q + 8);
        if (lat.abs() <= 90 && lon.abs() <= 180) {
          r.gps ??= GpsFix(lat, lon, altitude: alt, from: 'video');
        }
      }
    }
  }
}

String _c(String rest) => String.fromCharCode(0xA9) + rest;

String? _clean(String s) {
  final t = s.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();
  return t.isEmpty ? null : t;
}

void _qtMeta(ByteSource s, _Box m, MetaReport r, List<int> count) {
  if (m.end - m.body < 8) return;
  final peek = s.read(m.body, 8);
  if (_allZero(peek)) return;
  final full = _tag(peek, 4) != 'hdlr';
  final inner = _boxes(s, m.body + (full ? 4 : 0), m.end, count);
  final keys = <String>[];
  for (final b in inner.where((b) => b.type == 'keys')) {
    final p = _payload(s, b);
    if (p.length < 8) continue;
    final n = _be32(p, 4);
    var q = 8;
    for (var k = 0; k < n && q + 8 <= p.length; k++) {
      final size = _be32(p, q);
      if (size < 8 || q + size > p.length) break;
      keys.add(latin1.decode(p.sublist(q + 8, q + size), allowInvalid: true));
      q += size;
    }
  }
  for (final b in inner.where((b) => b.type == 'ilst')) {
    for (final item in _boxes(s, b.body, b.end, count)) {
      final raw = s.read(item.body - 4, 4);
      final idx = _be32(raw, 0);
      final name = idx >= 1 && idx <= keys.length ? keys[idx - 1] : item.type;
      String? value;
      for (final d in _boxes(s, item.body, item.end, count)) {
        if (d.type != 'data') continue;
        final p = _payload(s, d);
        if (p.length > 8) {
          value = _clean(utf8.decode(p.sublist(8), allowMalformed: true));
        }
      }
      r.videoTags.add(name);
      final low = name.toLowerCase();
      if (value == null) continue;
      if (low.contains('location')) _place(value, r);
      if (low.endsWith('.make')) r.make ??= value;
      if (low.endsWith('.model')) r.model ??= value;
      if (low.endsWith('.software')) r.software ??= value;
      if (low.endsWith('creationdate')) r.taken ??= value;
    }
  }
  if (keys.isEmpty && inner.any((b) => b.type == 'ilst')) {
    r.videoTags.add('ilst');
  }
}
