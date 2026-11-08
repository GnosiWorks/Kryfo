// SPDX-License-Identifier: GPL-3.0-or-later
// content credentials (c2pa) are a jumbf box store with a signed claim. only
// three things are read out of it, by their labels: the app or device that
// made the claim, whether the file declares it was made or changed by
// software, and a place in its exif assertion. nothing is verified; it is
// all removed either way.
import 'dart:convert';
import 'dart:typed_data';

class Credentials {
  final bool found;
  final String? madeWith;
  final bool syntheticLabel;

  /// the place a stds.exif assertion holds, in degrees
  final double? lat;
  final double? lon;
  const Credentials(
    this.found,
    this.madeWith,
    this.syntheticLabel, {
    this.lat,
    this.lon,
  });
}

final _gen = latin1.encode('claim_generator');
final _name = latin1.encode('name');

/// the iptc digital source types for media made by software, as the file
/// declares
const kSyntheticSourceTypes = [
  'trainedAlgorithmicMedia',
  'compositeWithTrainedAlgorithmicMedia',
  'algorithmicMedia',
  'compositeSynthetic',
];

bool _isJumbf(Uint8List b) {
  final s = latin1.decode(b, allowInvalid: true);
  return s.contains('jumb') && s.contains('c2pa');
}

/// what a jumbf store says about itself
Credentials readCredentials(Uint8List b) {
  if (!_isJumbf(b)) return const Credentials(false, null, false);
  final s = latin1.decode(b, allowInvalid: true);
  final lat = _exifDegrees(s, 'GPSLatitude', 'S', 90);
  final lon = _exifDegrees(s, 'GPSLongitude', 'W', 180);
  final both = lat != null && lon != null;
  return Credentials(
    true,
    _generator(b),
    kSyntheticSourceTypes.any(s.contains),
    lat: both ? lat : null,
    lon: both ? lon : null,
  );
}

final _dms = RegExp(
  r'^(\d{1,3}),(\d{1,2}(?:\.\d+)?)(?:,(\d{1,2}(?:\.\d+)?))?([NSEW])$',
);

// "exif:GPSLatitude": "43.1520939", or "43,9.1256N" as xmp writes it
double? _exifDegrees(String s, String key, String neg, double max) {
  final m = RegExp('"(?:exif|EXIF):$key"\\s*:\\s*"([^"]{1,40})"').firstMatch(s);
  if (m == null) return null;
  final v = m.group(1)!.trim();
  var out = double.tryParse(v);
  if (out == null) {
    final x = _dms.firstMatch(v);
    if (x == null) return null;
    out =
        double.parse(x.group(1)!) +
        double.parse(x.group(2)!) / 60 +
        (x.group(3) == null ? 0 : double.parse(x.group(3)!) / 3600);
    if (x.group(4) == neg) out = -out;
  }
  return out.abs() <= max ? out : null;
}

// the text right after a cbor key, when it is a short text string
String? _cborTextAt(Uint8List b, int i) {
  if (i >= b.length) return null;
  final h = b[i];
  int len, at;
  if (h >= 0x60 && h <= 0x77) {
    len = h - 0x60;
    at = i + 1;
  } else if (h == 0x78 && i + 1 < b.length) {
    len = b[i + 1];
    at = i + 2;
  } else if (h == 0x79 && i + 2 < b.length) {
    len = (b[i + 1] << 8) | b[i + 2];
    at = i + 3;
  } else {
    return null;
  }
  if (len == 0 || len > 200 || at + len > b.length) return null;
  final v = utf8.decode(b.sublist(at, at + len), allowMalformed: true).trim();
  return v.isEmpty ? null : v;
}

int _find(Uint8List b, List<int> p, int from) {
  outer:
  for (var i = from; i + p.length <= b.length; i++) {
    for (var k = 0; k < p.length; k++) {
      if (b[i + k] != p[k]) continue outer;
    }
    return i;
  }
  return -1;
}

String? _generator(Uint8List b) {
  var i = _find(b, _gen, 0);
  while (i >= 0) {
    final end = i + _gen.length;
    // "claim_generator": "Name/1.0 lib/2.0"
    final direct = _cborTextAt(b, end);
    if (direct != null) return _product(direct);
    // "claim_generator_info": [{"name": "Name", ...}]
    final n = _find(b, _name, end);
    if (n >= 0 && n - end < 64) {
      final v = _cborTextAt(b, n + _name.length);
      if (v != null) return v.replaceAll('_', ' ');
    }
    i = _find(b, _gen, end);
  }
  return null;
}

// "Adobe_Photoshop/23.3.1 adobe_c2pa/0.12.1" names Adobe Photoshop
String? _product(String v) {
  final p = v.split(' ').first.split('/').first.replaceAll('_', ' ').trim();
  return p.isEmpty ? null : p;
}
