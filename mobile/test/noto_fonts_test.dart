// SPDX-License-Identifier: GPL-3.0-or-later
// the arabic subsets cover the spacing, punctuation, digits and direction
// marks arabic and persian text uses. reads the cmaps of the committed fonts,
// so a re-subset (assets/fonts/noto-subset.sh) cannot drop one.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _fonts = ['NotoSansArabic-Kryfo.ttf', 'NotoNaskhArabic-Kryfo.ttf'];

// inclusive ranges
const _cover = [
  (0x0020, 0x002F), // space and ascii punctuation
  (0x003A, 0x0040),
  (0x005B, 0x0060),
  (0x007B, 0x007E),
  (0x00A0, 0x00A0), // no-break space
  (0x00AB, 0x00AB), // «
  (0x00B0, 0x00B0), // °
  (0x00B7, 0x00B7), // ·
  (0x00BB, 0x00BB), // »
  (0x00D7, 0x00D7), // ×
  (0x0600, 0x06FF), // arabic, persian letters, both digit sets, alm, tatweel
  (0x2009, 0x2009), // thin space
  (0x200B, 0x200F), // zwsp, zwnj, zwj, lrm, rlm
  (0x2010, 0x2010), // hyphen
  (0x2013, 0x2014), // en and em dash
  (0x2018, 0x2019), // single quotes
  (0x201C, 0x201D), // double quotes
  (0x2022, 0x2022), // bullet
  (0x2026, 0x2026), // ellipsis
  (0x202F, 0x202F), // narrow no-break space
  (0x2039, 0x203A), // ‹ ›
  (0x2212, 0x2212), // minus
  (0xFDFC, 0xFDFC), // rial
];

// the code points each unicode cmap subtable maps to a glyph other than
// .notdef. every one is checked: the phone picks which it reads.
List<Set<int>> _unicodeMaps(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  var cmap = -1;
  for (var i = 0; i < d.getUint16(4); i++) {
    final rec = 12 + 16 * i;
    if (String.fromCharCodes(bytes, rec, rec + 4) == 'cmap') {
      cmap = d.getUint32(rec + 8);
    }
  }
  expect(cmap, isNot(-1), reason: 'no cmap table');
  final maps = <Set<int>>[];
  for (var i = 0; i < d.getUint16(cmap + 2); i++) {
    final rec = cmap + 4 + 8 * i;
    final platform = d.getUint16(rec), encoding = d.getUint16(rec + 2);
    if (platform != 0 &&
        !(platform == 3 && (encoding == 1 || encoding == 10))) {
      continue;
    }
    final t = cmap + d.getUint32(rec + 4);
    final covered = <int>{};
    switch (d.getUint16(t)) {
      case 4:
        final segs = d.getUint16(t + 6) ~/ 2;
        final ends = t + 14, starts = ends + 2 * segs + 2;
        final deltas = starts + 2 * segs, offsets = deltas + 2 * segs;
        for (var s = 0; s < segs; s++) {
          final end = d.getUint16(ends + 2 * s);
          final delta = d.getInt16(deltas + 2 * s);
          final ro = offsets + 2 * s, off = d.getUint16(ro);
          for (var c = d.getUint16(starts + 2 * s); c <= end; c++) {
            var g = c;
            if (off != 0) {
              final start = d.getUint16(starts + 2 * s);
              g = d.getUint16(ro + off + 2 * (c - start));
              if (g == 0) continue;
            }
            if ((g + delta) & 0xFFFF != 0) covered.add(c);
          }
        }
      case 12:
        for (var n = 0; n < d.getUint32(t + 12); n++) {
          final grp = t + 16 + 12 * n;
          final first = d.getUint32(grp), glyph = d.getUint32(grp + 8);
          for (var c = first; c <= d.getUint32(grp + 4); c++) {
            if (glyph + c - first != 0) covered.add(c);
          }
        }
      default:
        continue;
    }
    maps.add(covered);
  }
  return maps;
}

String _hex(int c) => 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}';

void main() {
  for (final f in _fonts) {
    test('$f covers arabic and persian text', () {
      final maps = _unicodeMaps(File('assets/fonts/$f').readAsBytesSync());
      expect(maps, isNotEmpty);
      for (final m in maps) {
        final missing = [
          for (final (a, z) in _cover)
            for (var c = a; c <= z; c++)
              if (!m.contains(c)) _hex(c),
        ];
        expect(missing.join(' '), isEmpty);
      }
    });
  }
}
