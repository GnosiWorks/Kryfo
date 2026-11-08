// SPDX-License-Identifier: GPL-3.0-or-later
// what a picture or video carries beside itself, read without decoding it.
// the cleaners rely on it twice: before, to say what will go, and after, to
// refuse a copy that still reads as anything.
import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'byte_source.dart';
import 'c2pa.dart';
import 'icc.dart';
import 'heif_items.dart';
import 'iso.dart';
import 'mp4_tracks.dart';
import 'sef.dart';
import 'tiff.dart';
import '../l10n/l10n.dart';

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

  /// the mobile network country code a samsung camera wrote
  String? networkCountry;

  /// block names in a samsung trailer
  final List<String> sefEntries = [];

  /// the id an apple live photo shares with its video
  String? liveId;

  /// the app or device named in content credentials
  String? madeWith;

  /// made by software, as the file declares
  bool syntheticLabel = false;

  /// png text fields that hold a prompt and its settings
  final List<String> syntheticPrompt = [];

  /// small copies besides the exif one: jfif, jfxx, photoshop, heif
  int smallCopies = 0;
  bool depthMap = false;
  bool portraitMatte = false;

  /// google's lens blur keeps the photo from before the blur
  bool beforeBlur = false;

  /// a gain map, the layer that brightens it on an hdr screen
  bool hdrLayer = false;

  /// pictures inside besides the one shown and the hdr layer
  int extraPictures = 0;

  /// photo sphere keys, how a 360 view is drawn
  bool sphere = false;

  /// xmp edit history and the ids that tie copies of one photo together
  bool editHistory = false;

  /// video: every track, as handler/format
  final List<String> tracks = [];

  /// tracks besides picture, sound and subtitles
  int extraTracks = 0;
  bool timecode = false;
  int gpsPoints = 0;
  bool motionSensors = false;

  /// handler names and vendor fields that name the maker's software
  bool handlerNames = false;

  /// bytes left in free space or between the samples the file uses
  int leftoverBytes = 0;

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
      extra.isNotEmpty ||
      networkCountry != null ||
      sefEntries.isNotEmpty ||
      liveId != null ||
      madeWith != null ||
      syntheticLabel ||
      syntheticPrompt.isNotEmpty ||
      smallCopies > 0 ||
      depthMap ||
      portraitMatte ||
      beforeBlur ||
      hdrLayer ||
      extraPictures > 0 ||
      sphere ||
      editHistory ||
      extraTracks > 0 ||
      timecode ||
      gpsPoints > 0 ||
      motionSensors ||
      handlerNames ||
      leftoverBytes > 0;
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
  } on IsoError catch (e) {
    r.status = MetaStatus.unreadable;
    r.why = e.why;
  } on RangeError {
    r.status = MetaStatus.unreadable;
    r.why = l10n.metaReaderEndsBeforeItShould;
  } on FormatException catch (e) {
    r.status = MetaStatus.unreadable;
    r.why = e.message;
  } catch (e) {
    if (strict) rethrow;
    r.status = MetaStatus.unreadable;
    r.why = l10n.metaReaderCouldNotBeRead;
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
  'mif2',
  'mif3',
  'msf1',
  'avif',
  'avis',
};

/// brands of an image sequence, whose moov is the animation
const kHeifSequences = {'msf1', 'hevc', 'hevx', 'hevm', 'hevs', 'avis'};

/// what [s] is by its first bytes alone, nothing more read
MetaKind metaKindOf(ByteSource s) => _kindOf(s);

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
    for (var i = 8; i + 4 <= end; i += 4) {
      if (i == 12) continue;
      if (_heifBrands.contains(_tag(h, i))) return MetaKind.heif;
    }
    return MetaKind.mp4;
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
    if (!_allZero(tiff)) r.extra.add(l10n.metaReaderExifThatCannotBe);
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
  r.liveId ??= e.liveId;
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
final _gainSemantic = RegExp(r'Semantic\s*=\s*"GainMap"|Semantic>GainMap<');
final _motionSemantic = RegExp(r'Semantic\s*=\s*"MotionPhoto"');

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
  r.make ??= _xmpValue(s, 'tiff:Make');
  r.model ??= _xmpValue(s, 'tiff:Model');
  r.software ??= _xmpValue(s, 'xmp:CreatorTool');
  r.taken ??=
      _xmpValue(s, 'exif:DateTimeOriginal') ??
      _xmpValue(s, 'photoshop:DateCreated') ??
      _xmpValue(s, 'xmp:CreateDate');
  if (s.contains('xmpMM:History') ||
      s.contains('xmpMM:DerivedFrom') ||
      s.contains('xmpMM:OriginalDocumentID')) {
    r.editHistory = true;
  }
  _xmpSignals(s, r);
}

// a simple xmp property, written as an attribute or an element
String? _xmpValue(String s, String key) {
  final at = s.indexOf(key);
  if (at < 0) return null;
  final m = RegExp(
    '${RegExp.escape(key)}(?:="([^"]{1,200})"|>([^<]{1,200})<)',
  ).firstMatch(s.substring(at));
  return _clean(m?.group(1) ?? m?.group(2) ?? '');
}

// what an xmp packet, or a piece of extended xmp, says is hung beside the
// picture
void _xmpSignals(String s, MetaReport r) {
  if (_motionSemantic.hasMatch(s) ||
      s.contains('MicroVideo') ||
      s.contains('MotionPhoto=') ||
      s.contains('MotionPhoto>')) {
    r.embeddedVideo = true;
  }
  if (_gainSemantic.hasMatch(s) ||
      s.contains('hdrgm:') ||
      s.contains('HDRGainMap')) {
    r.hdrLayer = true;
  }
  if (s.contains('GPano:')) r.sphere = true;
  if (s.contains('GDepth:')) r.depthMap = true;
  if (s.contains('GImage:Data') || s.contains('GImage:Mime')) {
    r.beforeBlur = true;
  }
  if (s.contains('DigitalSourceType') &&
      kSyntheticSourceTypes.any(s.contains)) {
    r.syntheticLabel = true;
  }
}

void _takeCredentials(Credentials cr, MetaReport r) {
  r.madeWith ??= cr.madeWith;
  if (cr.syntheticLabel) r.syntheticLabel = true;
  if (cr.lat != null && cr.lon != null) {
    r.gps ??= GpsFix(cr.lat!, cr.lon!, from: 'credentials');
  }
}

// a colour profile whose text names a screen or an app (icc.dart)
void _takeIcc(Uint8List p, MetaReport r) {
  if (iccNamesSomething(p)) r.extra.add(l10n.metaReaderColourProfileName);
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
final _jfifHead = [...latin1.encode('JFIF'), 0];
final _jfxxHead = [...latin1.encode('JFXX'), 0];

class _JpegNotes {
  final credentials = BytesBuilder(copy: false);
  final icc = <(int, Uint8List)>[];
  int mpfImages = 0;
}

void _jpeg(ByteSource s, MetaReport r) {
  final notes = _JpegNotes();
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
    // a decoder skips ff 00 and reads on: what it hides goes unread here
    if (m == 0x00) throw const _Unreadable('broken segment');
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
    _jpegSegment(m, body, r, notes);
    i += 2 + len;
  }
  final end = _jpegEnd(s, i, r, notes);
  if (end < s.length) {
    r.trailingBytes = s.length - end;
    _sniffTrailer(s, end, r);
  }
  final c = notes.credentials.toBytes();
  if (c.isNotEmpty) {
    final cr = readCredentials(c);
    if (cr.found) {
      r.credentials = true;
      _takeCredentials(cr, r);
    } else {
      r.extra.add('app11');
    }
  }
  if (notes.icc.isNotEmpty) {
    notes.icc.sort((a, b) => a.$1.compareTo(b.$1));
    final p = BytesBuilder(copy: false);
    for (final (_, b) in notes.icc) {
      p.add(b);
    }
    _takeIcc(p.toBytes(), r);
  }
  if (notes.mpfImages > 1) {
    var more = notes.mpfImages - 1;
    if (r.hdrLayer) more--;
    if (more > r.extraPictures) r.extraPictures = more;
  }
}

void _jpegSegment(int m, Uint8List body, MetaReport r, _JpegNotes notes) {
  if (m == 0xE1) {
    if (_startsWith(body, _exifHead)) {
      _takeExif(Uint8List.sublistView(body, 6), r);
    } else if (_startsWith(body, _xmpHead)) {
      _takeXmp(Uint8List.sublistView(body, _xmpHead.length), r);
    } else if (_startsWith(body, _xmpExtHead)) {
      r.xmp = true;
      _xmpSignals(latin1.decode(body, allowInvalid: true), r);
    } else {
      r.extra.add('app1');
    }
  } else if (m == 0xE2) {
    if (_startsWith(body, _iccHead)) {
      if (body.length > 14) {
        notes.icc.add((body[12], Uint8List.sublistView(body, 14)));
      }
      return;
    }
    if (_startsWith(body, _mpfHead)) {
      r.secondImage = true;
      final n = _mpfCount(Uint8List.sublistView(body, 4));
      if (n > notes.mpfImages) notes.mpfImages = n;
    } else {
      r.extra.add('app2');
    }
  } else if (m == 0xEB) {
    // content credentials, spread over as many segments as it needs: each
    // starts "JP", a box instance, a sequence number, then the store
    if (body.length > 8 && body[0] == 0x4A && body[1] == 0x50) {
      notes.credentials.add(Uint8List.sublistView(body, 8));
    } else {
      r.extra.add('app11');
    }
  } else if (m == 0xED) {
    if (_startsWith(body, _psHead)) {
      r.iptc = true;
      r.smallCopies += _photoshopThumbs(body);
    } else {
      r.extra.add('app13');
    }
  } else if (m == 0xEE && _startsWith(body, _adobeHead)) {
    return;
  } else if (m == 0xE0) {
    if (_startsWith(body, _jfifHead)) {
      if (body.length >= 14 && body[12] * body[13] > 0) r.smallCopies++;
    } else if (_startsWith(body, _jfxxHead)) {
      r.smallCopies++;
    } else {
      r.extra.add('app0');
    }
  } else if (m >= 0xE3 && m <= 0xEF) {
    r.extra.add('app${m - 0xE0}');
  } else if (m == 0xFE) {
    r.comment = true;
  }
}

// the number of pictures an mpf index lists
int _mpfCount(Uint8List t) {
  if (t.length < 8) return 0;
  final le = t[0] == 0x49;
  int u16(int i) => le ? t[i] | (t[i + 1] << 8) : (t[i] << 8) | t[i + 1];
  int u32(int i) => le
      ? t[i] | (t[i + 1] << 8) | (t[i + 2] << 16) | (t[i + 3] << 24)
      : (t[i] << 24) | (t[i + 1] << 16) | (t[i + 2] << 8) | t[i + 3];
  final at = u32(4);
  if (at + 2 > t.length) return 0;
  final n = u16(at);
  for (var k = 0; k < n && at + 2 + k * 12 + 12 <= t.length; k++) {
    final e = at + 2 + k * 12;
    if (u16(e) == 0xB001) return u32(e + 8);
  }
  return 0;
}

// photoshop resources 0x0409 and 0x040C are thumbnails
int _photoshopThumbs(Uint8List b) {
  var i = _psHead.length + 1;
  var n = 0;
  while (i + 12 <= b.length) {
    if (b[i] != 0x38 || b[i + 1] != 0x42 || b[i + 2] != 0x49) break; // 8BI
    final id = _be16(b, i + 4);
    var p = i + 6;
    final nameLen = b[p];
    p += 1 + nameLen;
    if (p & 1 == 1) p++;
    if (p + 4 > b.length) break;
    final size = _be32(b, p);
    p += 4;
    if (id == 0x0409 || id == 0x040C) n++;
    i = p + size + (size & 1);
  }
  return n;
}

int _jpegEnd(ByteSource s, int sos, MetaReport r, _JpegNotes notes) {
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
      if (marker == 0xFF) {
        j += 1;
        marker = s.read(j, 2)[1];
        continue;
      }
      if (marker == 0x00 ||
          marker == 0x01 ||
          (marker! >= 0xD0 && marker <= 0xD8)) {
        throw const _Unreadable('broken segment');
      }
      final sh = s.read(j, 4);
      final len = _be16(sh, 2);
      if (len < 2 || j + 2 + len > s.length) {
        throw const _Unreadable('segment runs past the file');
      }
      _jpegSegment(marker, s.read(j + 4, len - 2), r, notes);
      j += 2 + len;
      final nx = s.read(j, 2);
      if (nx[0] != 0xFF) throw const _Unreadable('broken segment');
      marker = nx[1];
    }
    i = j;
  }
}

void _sniffTrailer(ByteSource s, int from, MetaReport r) {
  final sef = readSef(s, from: from);
  if (sef != null) {
    r.extra.add(l10n.metaReaderSamsungTrailer);
    _sefFindings(s, sef, r);
  }
  final n = s.length - from;
  final head = s.read(from, n < _scanChunk ? n : _scanChunk);
  final text = latin1.decode(head, allowInvalid: true);
  if (text.contains('ftyp')) r.embeddedVideo = true;
  if (sef == null && (text.contains('SEFH') || text.contains('SEFT'))) {
    r.extra.add(l10n.metaReaderSamsungTrailer);
  }
  if (text.contains('hdrgm:') ||
      text.contains('HDRGainMap') ||
      text.contains('urn:iso:std:iso:ts:21496')) {
    r.hdrLayer = true;
  }
  if (n > _scanChunk) {
    final tail = latin1.decode(
      s.read(s.length - _scanChunk, _scanChunk),
      allowInvalid: true,
    );
    if (sef == null && tail.contains('SEFT')) {
      r.extra.add(l10n.metaReaderSamsungTrailer);
    }
    if (tail.contains('ftyp')) r.embeddedVideo = true;
  }
}

void _sefFindings(ByteSource s, SefTrailer sef, MetaReport r) {
  r.networkCountry ??= sef.networkCountry(s);
  for (final e in sef.entries) {
    r.sefEntries.add(e.name);
    if (e.name == 'MotionPhoto_Data') r.embeddedVideo = true;
    if (e.name.contains('DepthMap')) r.depthMap = true;
    if (e.len >= 12) {
      final b = s.read(e.at, 12);
      if (b[0] == 0xFF && b[1] == 0xD8) r.extraPictures++;
      if (_tag(b, 4) == 'ftyp') r.embeddedVideo = true;
    }
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

// text keys image generators write their prompt and settings under
const _promptKeys = {
  'parameters',
  'prompt',
  'workflow',
  'negative_prompt',
  'sd-metadata',
  'Dream',
  'generation_data',
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
      } else if (key.startsWith('Raw profile type ')) {
        r.textKeys.add(key);
        _rawProfile(type, body, z, key.substring(17), r);
      } else {
        r.textKeys.add(key);
        final text = latin1.decode(body, allowInvalid: true);
        if (_promptKeys.contains(key) ||
            key.startsWith('invoke') ||
            (key == 'Description' && text.contains('Job ID'))) {
          r.syntheticPrompt.add(key);
        }
        if (kSyntheticSourceTypes.any(text.contains)) r.syntheticLabel = true;
      }
    } else if (type == 'iCCP') {
      final body = s.read(i + 8, len < _maxBlock ? len : _maxBlock);
      final z = body.indexOf(0);
      final p = z < 0 ? null : _inflate(Uint8List.sublistView(body, z + 2));
      if (p != null) _takeIcc(p, r);
    } else if (type == 'tIME') {
      r.savedTime = true;
    } else if (type == 'caBX') {
      r.credentials = true;
      final cr = readCredentials(
        s.read(i + 8, len < _maxBlock ? len : _maxBlock),
      );
      _takeCredentials(cr, r);
    } else if (!_pngKeep.contains(type)) {
      r.extra.add(l10n.metaReaderChunk(type));
    }
    i = end;
    if (type == 'IEND') break;
  }
  if (i < s.length) r.trailingBytes = s.length - i;
}

// imagemagick keeps exif, xmp and iptc in a text chunk as hex: a newline,
// the profile name, its length, then the bytes
void _rawProfile(
  String type,
  Uint8List body,
  int z,
  String name,
  MetaReport r,
) {
  Uint8List? text;
  if (type == 'tEXt') {
    text = Uint8List.sublistView(body, z + 1);
  } else if (type == 'zTXt' && z + 2 <= body.length) {
    text = _inflate(Uint8List.sublistView(body, z + 2));
  } else if (type == 'iTXt' && z + 3 <= body.length) {
    final compressed = body[z + 1] == 1;
    var q = z + 3;
    for (var n = 0; n < 2; n++) {
      final e = body.indexOf(0, q);
      if (e < 0) return;
      q = e + 1;
    }
    final rest = Uint8List.sublistView(body, q);
    text = compressed ? _inflate(rest) : rest;
  }
  if (text == null) return;
  final words = latin1
      .decode(text, allowInvalid: true)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length < 3) return;
  // the stated length, then hex; anything after it is not the profile
  final n = int.tryParse(words[1]) ?? 0;
  final hex = words.skip(2).join();
  if (n == 0 || n > _maxBlock || hex.length < n * 2) return;
  final bytes = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final v = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (v == null) return;
    bytes[i] = v;
  }
  switch (name) {
    case 'exif' || 'APP1':
      _takeExif(
        _startsWith(bytes, _exifHead) ? Uint8List.sublistView(bytes, 6) : bytes,
        r,
      );
    case 'xmp':
      _takeXmp(bytes, r);
    case 'iptc' || '8bim':
      r.iptc = true;
  }
}

Uint8List? _inflate(Uint8List b) {
  try {
    final out = ZLibDecoder().convert(b);
    return out.length > 4 * _maxBlock ? null : Uint8List.fromList(out);
  } on FormatException {
    return null;
  }
}

/// the webp chunks a picture is drawn from, still or animated
const kWebpKeep = {'VP8 ', 'VP8L', 'VP8X', 'ALPH', 'ANIM', 'ANMF', 'ICCP'};

void _webp(ByteSource s, MetaReport r) {
  final riffEnd = 8 + _le32(s.read(4, 4), 0);
  if (riffEnd > s.length) throw const _Unreadable('riff runs past the file');
  var i = 12;
  var boxes = 0;
  var exifFlag = false, exifChunk = false;
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
      exifChunk = true;
      final b = s.read(i + 8, len);
      _takeExif(_startsWith(b, _exifHead) ? Uint8List.sublistView(b, 6) : b, r);
    } else if (type == 'XMP ') {
      _takeXmp(s.read(i + 8, len < _maxBlock ? len : _maxBlock), r);
    } else if (type == 'C2PA') {
      r.credentials = true;
      final cr = readCredentials(
        s.read(i + 8, len < _maxBlock ? len : _maxBlock),
      );
      _takeCredentials(cr, r);
    } else if (type == 'ICCP') {
      _takeIcc(s.read(i + 8, len < _maxBlock ? len : _maxBlock), r);
    } else if (type == 'VP8X' && len >= 1) {
      final f = s.read(i + 8, 1)[0];
      if (f & 0x08 != 0) exifFlag = true;
      if (f & 0x04 != 0) r.extra.add(l10n.metaReaderXmpFlagSet);
    } else if (!kWebpKeep.contains(type)) {
      r.extra.add(l10n.metaReaderChunk(type));
    }
    i += 8 + len + (len & 1);
  }
  if (exifFlag && !exifChunk) r.extra.add(l10n.metaReaderExifFlagSet);
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
      final end = sub(i + 2);
      // a plain text block is drawn by almost no viewer: hidden text
      if (label == 0xFE || label == 0x01) {
        r.comment = true;
      } else if (label == 0xFF) {
        final id = latin1.decode(s.read(i + 3, 11), allowInvalid: true);
        if (id == 'XMP DataXMP') {
          // xmp is written raw, its length bytes are part of the text
          final n = end - i - 14;
          _takeXmp(s.read(i + 14, n < _maxBlock ? n : _maxBlock), r);
          r.xmp = true;
        } else if (id.startsWith('C2PA_GIF')) {
          r.credentials = true;
          _takeCredentials(readCredentials(_gifData(s, i + 14, end)), r);
        } else if (id != 'NETSCAPE2.0' && id != 'ANIMEXTS1.0') {
          r.extra.add(l10n.metaReaderAppBlock(id));
        }
      }
      i = end;
    } else {
      throw const _Unreadable('not a gif block');
    }
  }
}

// the sub-blocks from [p] to [end] joined, up to a megabyte
Uint8List _gifData(ByteSource s, int p, int end) {
  final out = BytesBuilder(copy: false);
  while (p < end && out.length < _maxBlock) {
    final n = s.read(p, 1)[0];
    if (n == 0 || p + 1 + n > end) break;
    out.add(s.read(p + 1, n));
    p += 1 + n;
  }
  return out.toBytes();
}

String _printable(String tag) => tag.replaceAll(RegExp(r'[^A-Za-z0-9]'), '?');

// ---- heif and avif ----

/// meta children a heif picture needs
const kHeifMetaKeep = {
  'hdlr',
  'pitm',
  'iloc',
  'iinf',
  'iref',
  'iprp',
  'idat',
  'grpl',
  'dinf',
};

Iterable<String> heifBrands(ByteSource s, IsoBox ftyp) sync* {
  if (ftyp.type != 'ftyp' || ftyp.bodySize > 1024) return;
  final b = s.read(ftyp.body, ftyp.bodySize);
  for (var i = 0; i + 4 <= b.length; i += 4) {
    if (i == 4) continue; // minor version
    yield _tag(b, i);
  }
}

void _heif(ByteSource s, MetaReport r) {
  final count = [0];
  final top = isoBoxes(s, 0, s.length, count);
  if (firstOf(top, 'mini') != null) {
    throw const _Unreadable('a compact heif kryfo does not read yet');
  }
  final meta = firstOf(top, 'meta');
  if (meta == null) throw const _Unreadable('no meta box');
  final m = readHeifMeta(s, meta, count);
  final sequence =
      top.isNotEmpty && heifBrands(s, top.first).any(kHeifSequences.contains);
  final picture = heifPictureItems(s, m);
  if (picture.isEmpty) throw const _Unreadable('no picture item');

  // what every byte of mdat and idat is there for
  final used = Ranges();
  final usedIdat = Ranges();
  for (final id in m.items.keys) {
    final p = m.places[id];
    if (p == null) continue;
    for (final e in p.extents) {
      final to = e.len == 0 ? s.length : e.at + e.len;
      if (p.method == 0) used.add(e.at, to);
      if (p.method == 1) usedIdat.add(e.at, to);
    }
  }

  for (final k in m.kids) {
    if (k.type == 'hdlr') {
      if (_handlerNamed(s, k)) r.handlerNames = true;
    } else if (k.type == 'free' || k.type == 'skip') {
      if (nonZero(s, k.body, k.bodySize)) r.leftoverBytes += k.bodySize;
    } else if (!kHeifMetaKeep.contains(k.type)) {
      if (nonZero(s, k.body, k.bodySize)) {
        r.extra.add(l10n.metaReaderBox(_printable(k.type)));
      }
    }
  }
  // a description, a date or a vendor block hung on an item as a property
  for (final p in m.props) {
    if (!kHeifPropKeep.contains(p.type) && nonZero(s, p.body, p.bodySize)) {
      r.extra.add(l10n.metaReaderBox(_printable(p.type)));
    }
    if (p.type == 'colr' && p.bodySize > 4 && p.bodySize < _maxBlock) {
      final b = s.read(p.body, p.bodySize);
      final kind = _tag(b, 0);
      if (kind == 'prof' || kind == 'rICC') {
        _takeIcc(Uint8List.sublistView(b, 4), r);
      }
    }
  }
  final idat = m.idat;
  if (idat != null) {
    for (final (a, b) in Ranges.gaps(usedIdat.merged, 0, idat.bodySize)) {
      if (nonZero(s, idat.body + a, b - a)) r.leftoverBytes += b - a;
    }
  }

  var hdr = false;
  for (final id in m.items.keys) {
    final role = heifRole(s, m, id, picture);
    switch (role) {
      case HeifRole.picture:
        final t = m.items[id]?.type ?? '';
        if (!kHeifCodings.contains(t)) {
          r.extra.add(l10n.metaReaderItem(_printable(t)));
        }
      case HeifRole.exif:
        final body = _itemBytes(s, m, id);
        if (body == null || body.isEmpty || _allZero(body)) break;
        if (body.length < 8) {
          r.extra.add(l10n.metaReaderExifThatCannotBe);
          break;
        }
        final skip = 4 + _be32(body, 0);
        if (skip < 4 || skip >= body.length) {
          r.extra.add(l10n.metaReaderExifThatCannotBe);
          break;
        }
        _takeExif(Uint8List.sublistView(body, skip), r);
      case HeifRole.xmp:
        final body = _itemBytes(s, m, id);
        if (body != null) _takeXmp(body, r);
      case HeifRole.thumbnail:
        r.smallCopies++;
      case HeifRole.depth:
        r.depthMap = true;
      case HeifRole.matte:
        r.portraitMatte = true;
      case HeifRole.hdr:
        hdr = true;
      case HeifRole.another:
        r.extraPictures++;
      case HeifRole.attached:
        r.extra.add(l10n.metaReaderAttachedData);
      case HeifRole.other:
        final t = m.items[id]?.type ?? '';
        r.extra.add(l10n.metaReaderItem(_printable(t)));
    }
  }
  if (hdr) r.hdrLayer = true;

  Mp4Layout? anim;
  for (final b in top) {
    switch (b.type) {
      case 'ftyp' || 'mdat':
        break;
      case 'meta':
        // the picture is read from the first one; another is beside it
        if (b.start != meta.start) r.extra.add(l10n.metaReaderBox('meta'));
      case 'free' || 'skip':
        if (nonZero(s, b.body, b.bodySize)) r.leftoverBytes += b.bodySize;
      case 'moov':
        if (sequence && anim == null) {
          anim = readMp4LayoutOf(s, top, count);
          _moovFindings(s, anim, r, count);
          used.addAll(anim.keptSamples);
        } else {
          r.embeddedVideo = true;
        }
      case 'mpvd':
        r.embeddedVideo = true;
      case 'uuid':
        _uuid(s, b, r, picture: true);
      default:
        r.extra.add(l10n.metaReaderBox(_printable(b.type)));
    }
  }
  // a second ftyp after the picture is a whole file hung behind it
  if (top.skip(1).any((b) => b.type == 'ftyp')) r.embeddedVideo = true;

  final merged = used.merged;
  for (final b in top.where((b) => b.type == 'mdat')) {
    for (final (x, y) in Ranges.gaps(merged, b.body, b.end)) {
      if (nonZero(s, x, y - x)) r.leftoverBytes += y - x;
    }
  }
}

Uint8List? _itemBytes(ByteSource s, HeifMeta m, int id) {
  final ranges = m.fileRanges(id);
  if (ranges == null) {
    throw const _Unreadable('item stored in a way not handled');
  }
  final parts = BytesBuilder(copy: false);
  for (final (a, b) in ranges) {
    if (b - a <= 0 || b - a > _maxBlock) {
      throw const _Unreadable('item too large');
    }
    parts.add(s.read(a, b - a));
  }
  return parts.toBytes();
}

// a hdlr box's name, or the vendor fields quicktime puts before it
bool _handlerNamed(ByteSource s, IsoBox h) {
  if (h.bodySize <= 12) return false;
  return nonZero(s, h.body + 12, h.bodySize - 12);
}

void _uuid(ByteSource s, IsoBox b, MetaReport r, {bool picture = false}) {
  final n = b.bodySize;
  final p = s.read(b.body, n < _maxBlock ? n : _maxBlock);
  if (_allZero(p)) return;
  final cr = readCredentials(p);
  if (cr.found) {
    r.credentials = true;
    _takeCredentials(cr, r);
  } else if (picture) {
    r.extra.add(l10n.metaReaderUuidBox);
  } else {
    r.videoTags.add('uuid');
  }
}

// ---- mp4, mov, 3gp ----

final _mac = DateTime.utc(1904, 1, 1);

void _mp4(ByteSource s, MetaReport r) {
  final count = [0];
  var end = s.length;
  final sef = readSef(s);
  if (sef != null) {
    end = sef.start;
    r.extra.add(l10n.metaReaderSamsungTrailer);
    _sefFindings(s, sef, r);
  }
  final top = isoBoxes(s, 0, end, count);
  final lay = readMp4LayoutOf(s, top, count);
  for (final b in top) {
    if (b.type == 'moov' || b.type == 'mdat') continue;
    if (kFreeBoxes.contains(b.type)) {
      if (nonZero(s, b.body, b.bodySize)) r.leftoverBytes += b.bodySize;
    } else if (b.type == 'uuid') {
      _uuid(s, b, r);
    } else if (b.type == 'meta') {
      _qtMeta(s, b, r, count);
    } else if (!kMp4Top.contains(b.type)) {
      if (nonZero(s, b.body, b.bodySize)) {
        r.extra.add(l10n.metaReaderBox(_printable(b.type)));
      }
    } else if (b.type == 'moof') {
      _moofFindings(s, b, r, count);
    }
  }
  // without a moov no player reads mdat as a video
  if (lay.moov == null) return;
  _moovFindings(s, lay, r, count);
  final merged = lay.keptSamples.merged;
  for (final b in lay.mdats) {
    for (final (x, y) in Ranges.gaps(merged, b.body, b.end)) {
      if (nonZero(s, x, y - x)) r.leftoverBytes += y - x;
    }
  }
}

void _moofFindings(ByteSource s, IsoBox moof, MetaReport r, List<int> c) {
  for (final b in isoBoxes(s, moof.body, moof.end, c)) {
    if (b.type == 'traf') {
      for (final t in isoBoxes(s, b.body, b.end, c)) {
        if (!kTrafKeep.contains(t.type) && nonZero(s, t.body, t.bodySize)) {
          r.videoTags.add(_printable(t.type));
        }
      }
    } else if (!kMoofKeep.contains(b.type) && nonZero(s, b.body, b.bodySize)) {
      r.videoTags.add(_printable(b.type));
    }
  }
}

void _stamp(ByteSource s, IsoBox b, MetaReport r) {
  final p = s.read(b.body, b.bodySize.clamp(0, 24));
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
}

void _moovFindings(ByteSource s, Mp4Layout lay, MetaReport r, List<int> c) {
  for (final b in lay.moovKids) {
    switch (b.type) {
      case 'mvhd':
        _stamp(s, b, r);
      case 'trak' || 'mvex' || 'iods':
        break;
      case 'udta':
        _udta(s, b, r, c);
      case 'meta':
        _qtMeta(s, b, r, c);
      case 'uuid':
        _uuid(s, b, r);
      default:
        if (kFreeBoxes.contains(b.type)) {
          if (nonZero(s, b.body, b.bodySize)) r.leftoverBytes += b.bodySize;
        } else if (nonZero(s, b.body, b.bodySize)) {
          r.videoTags.add(_printable(b.type));
        }
    }
  }
  for (final t in lay.tracks) {
    r.tracks.add('${t.handler}/${t.format}');
    if (t.tkhd != null) _stamp(s, t.tkhd!, r);
    if (t.mdhd != null) _stamp(s, t.mdhd!, r);
    switch (t.role) {
      case TrackRole.timecode:
        r.timecode = true;
      case TrackRole.data:
        r.extraTracks++;
        final d = timedData(s, t);
        r.gpsPoints += d.gpsPoints;
        if (d.motion) r.motionSensors = true;
      default:
        if (t.hdlrs.any((h) => _handlerNamed(s, h))) r.handlerNames = true;
        for (final (a, b) in compressorNames(s, t, c)) {
          if (nonZero(s, a, b - a)) r.handlerNames = true;
        }
        _trakExtras(s, t.trak, r, c);
    }
  }
}

// boxes in a kept track that are not what playing it needs
void _trakExtras(ByteSource s, IsoBox trak, MetaReport r, List<int> c) {
  void walk(IsoBox box, Set<String> keep, int depth) {
    for (final b in isoBoxes(s, box.body, box.end, c)) {
      if (b.type == 'udta') {
        _udta(s, b, r, c);
      } else if (b.type == 'meta') {
        _qtMeta(s, b, r, c);
      } else if (kFreeBoxes.contains(b.type)) {
        if (nonZero(s, b.body, b.bodySize)) r.leftoverBytes += b.bodySize;
      } else if (!keep.contains(b.type)) {
        if (nonZero(s, b.body, b.bodySize)) r.videoTags.add(_printable(b.type));
      } else if (depth < 3) {
        final inner = switch (b.type) {
          'mdia' => kMdiaKeep,
          'minf' => kMinfKeep,
          _ => null,
        };
        if (inner != null) walk(b, inner, depth + 1);
      }
    }
  }

  walk(trak, kTrakKeep, 0);
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

void _udta(ByteSource s, IsoBox u, MetaReport r, List<int> count) {
  for (final b in isoBoxes(s, u.body, u.end, count)) {
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

void _qtMeta(ByteSource s, IsoBox m, MetaReport r, List<int> count) {
  if (m.end - m.body < 8) return;
  final peek = s.read(m.body, 8);
  if (_allZero(peek)) return;
  final full = _tag(peek, 4) != 'hdlr';
  final inner = isoBoxes(s, m.body + (full ? 4 : 0), m.end, count);
  final keys = <String>[];
  for (final b in inner.where((b) => b.type == 'keys')) {
    final p = isoPayload(s, b, max: _maxBlock);
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
    for (final item in isoBoxes(s, b.body, b.end, count)) {
      final raw = s.read(item.body - 4, 4);
      final idx = _be32(raw, 0);
      final name = idx >= 1 && idx <= keys.length ? keys[idx - 1] : item.type;
      String? value;
      for (final d in isoBoxes(s, item.body, item.end, count)) {
        if (d.type != 'data') continue;
        final p = isoPayload(s, d, max: _maxBlock);
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
      if (low.endsWith('content.identifier')) r.liveId ??= value;
    }
  }
  if (keys.isEmpty && inner.any((b) => b.type == 'ilst')) {
    r.videoTags.add('ilst');
  }
}
