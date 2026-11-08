// SPDX-License-Identifier: GPL-3.0-or-later
// a colour profile is kept, since the colours are drawn from it, but its
// text can name a screen or the app that made it. the standard profiles
// that millions of files share stay as they are; any other has its text,
// its device fields, its date and its id made blank, in place, so no byte
// moves and the colours stay the same.
import 'dart:convert';
import 'dart:typed_data';

// lower case, as compared
const _common = {
  'srgb',
  'srgb iec61966-2.1',
  'srgb iec61966-2-1 black scaled',
  'srgb built-in',
  'srgb profile',
  'srgb v4 icc preference perceptual intent beta',
  'display p3',
  'display p3 gamut with srgb transfer',
  'p3 d65',
  'dci-p3',
  'adobe rgb (1998)',
  'prophoto rgb',
  'rec. 2020',
  'rec2020',
  'itu-r bt.2020',
  'rec. 709',
  'itu-r bt.709',
  'generic rgb profile',
  'generic gray profile',
  'generic gray gamma 2.2 profile',
  'gray gamma 2.2',
  'sgray',
  'dot gain 20%',
  'linear srgb',
  'u.s. web coated (swop) v2',
  'coated fogra39 (iso 12647-2:2004)',
  'japan color 2001 coated',
};

/// [p] with its text, device fields, date and id blank, the same length.
/// [p] itself for a standard profile, one already blank, or one that
/// cannot be read as a profile
Uint8List scrubIcc(Uint8List p) {
  final tags = _tags(p);
  if (tags == null) return p;
  final desc = tags.where((t) => t.sig == 'desc').firstOrNull;
  if (desc != null && _common.contains(_text(p, desc)?.trim().toLowerCase())) {
    return p;
  }
  final out = Uint8List.fromList(p);
  out.fillRange(24, 36, 0); // date
  out.fillRange(48, 56, 0); // device maker and model
  out.fillRange(84, 100, 0); // profile id, a hash of what changes here
  final name = switch (latin1.decode(p.sublist(16, 20))) {
    'RGB ' => 'RGB',
    'GRAY' => 'Gray',
    'CMYK' => 'CMYK',
    _ => 'Profile',
  };
  for (final t in tags) {
    _blank(out, t, t.sig == 'desc' ? name : '');
  }
  for (var i = 0; i < p.length; i++) {
    if (out[i] != p[i]) return out;
  }
  return p;
}

/// true when the profile holds text or fields [scrubIcc] makes blank
bool iccNamesSomething(Uint8List p) => !identical(scrubIcc(p), p);

class _Tag {
  final String sig;
  final String type;
  final int at;
  final int len;
  const _Tag(this.sig, this.type, this.at, this.len);
}

int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

void _put32(Uint8List b, int i, int v) {
  b[i] = (v >> 24) & 255;
  b[i + 1] = (v >> 16) & 255;
  b[i + 2] = (v >> 8) & 255;
  b[i + 3] = v & 255;
}

// the text tags, or null when [p] is no profile that can be walked
List<_Tag>? _tags(Uint8List p) {
  if (p.length < 132) return null;
  if (latin1.decode(p.sublist(36, 40)) != 'acsp') return null;
  final size = _u32(p, 0);
  if (size < 132 || size > p.length) return null;
  final n = _u32(p, 128);
  if (n > 1000 || 132 + 12 * n > size) return null;
  final out = <_Tag>[];
  for (var k = 0; k < n; k++) {
    final e = 132 + 12 * k;
    final at = _u32(p, e + 4);
    final len = _u32(p, e + 8);
    if (len < 8 || at < 132 || at + len > size) continue;
    final type = latin1.decode(p.sublist(at, at + 4));
    if (type != 'desc' && type != 'text' && type != 'mluc') continue;
    out.add(_Tag(latin1.decode(p.sublist(e, e + 4)), type, at, len));
  }
  return out;
}

// the first string a text tag holds
String? _text(Uint8List p, _Tag t) {
  final end = t.at + t.len;
  switch (t.type) {
    case 'text':
      return _cString(p, t.at + 8, end);
    case 'desc':
      if (t.at + 12 > end) return null;
      final n = _u32(p, t.at + 8);
      return _cString(p, t.at + 12, (t.at + 12 + n).clamp(0, end));
    case 'mluc':
      if (t.at + 28 > end) return null;
      final len = _u32(p, t.at + 20);
      final off = _u32(p, t.at + 24);
      if (t.at + off + len > end) return null;
      final units = <int>[];
      for (var i = 0; i + 1 < len; i += 2) {
        units.add((p[t.at + off + i] << 8) | p[t.at + off + i + 1]);
      }
      return String.fromCharCodes(units).split('\u0000').first;
  }
  return null;
}

String _cString(Uint8List p, int from, int to) {
  var e = from;
  while (e < to && p[e] != 0) {
    e++;
  }
  return latin1.decode(p.sublist(from, e));
}

// the tag's text made [name], or empty, without changing its size
void _blank(Uint8List b, _Tag t, String name) {
  final end = t.at + t.len;
  final ascii = latin1.encode(name);
  switch (t.type) {
    case 'text':
      b.fillRange(t.at + 8, end, 0);
      if (t.at + 8 + ascii.length < end) b.setAll(t.at + 8, ascii);
    case 'desc':
      // the ascii count stays; the unicode and mac parts after it are
      // zeroed, which reads as both of them empty
      if (t.at + 12 > end) {
        b.fillRange(t.at + 8, end, 0);
        return;
      }
      final from = t.at + 12;
      b.fillRange(from, end, 0);
      final room = (_u32(b, t.at + 8)).clamp(0, end - from);
      if (ascii.length < room) b.setAll(from, ascii);
    case 'mluc':
      if (t.at + 16 > end) {
        b.fillRange(t.at + 8, end, 0);
        return;
      }
      final n = _u32(b, t.at + 8);
      final rec = _u32(b, t.at + 12);
      final table = t.at + 16 + n * rec;
      if (rec < 12 || table > end) {
        b.fillRange(t.at + 8, end, 0);
        return;
      }
      b.fillRange(table, end, 0);
      final units = [
        for (final c in name.codeUnits) ...[(c >> 8) & 255, c & 255],
      ];
      final fits = table + units.length <= end;
      if (fits) b.setAll(table, units);
      for (var k = 0; k < n; k++) {
        final r = t.at + 16 + k * rec;
        _put32(b, r + 4, fits ? units.length : 0);
        _put32(b, r + 8, table - t.at);
      }
  }
}
