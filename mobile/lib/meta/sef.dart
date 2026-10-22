// SPDX-License-Identifier: GPL-3.0-or-later
// samsung's trailer: blocks hung after a jpeg's end, or after an mp4's last
// box, with a directory that ends the file in 'SEFT'. it holds the capture
// time to the millisecond, the mobile network country, the motion clip, depth
// maps and extra pictures of a portrait shot, and edit undo data.
import 'dart:convert';

import 'byte_source.dart';

class SefEntry {
  final String name;
  final int at; // of the data, past the name
  final int len;
  const SefEntry(this.name, this.at, this.len);
}

class SefTrailer {
  final int start; // the first byte of the first block
  final List<SefEntry> entries;
  const SefTrailer(this.start, this.entries);

  /// the mobile country code a camera wrote, digits only
  String? networkCountry(ByteSource s) {
    for (final e in entries) {
      if (e.name != 'MCC_Data' || e.len <= 0 || e.len > 16) continue;
      final v = latin1.decode(s.read(e.at, e.len), allowInvalid: true);
      final d = v.replaceAll(RegExp(r'[^0-9]'), '');
      if (d.isNotEmpty) return d;
    }
    return null;
  }
}

int _le32(List<int> b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);
int _le16(List<int> b, int i) => b[i] | (b[i + 1] << 8);

/// the trailer ending [s], or null when the file does not end in one. only
/// bytes at or after [from] belong to it
SefTrailer? readSef(ByteSource s, {int from = 0}) {
  final n = s.length;
  if (n - from < 16) return null;
  final tail = s.read(n - 8, 8);
  if (latin1.decode(tail.sublist(4), allowInvalid: true) != 'SEFT') {
    return null;
  }
  final size = _le32(tail, 0);
  final head = n - 8 - size;
  if (size < 12 || head < from) return null;
  final h = s.read(head, 12);
  if (latin1.decode(h.sublist(0, 4), allowInvalid: true) != 'SEFH') {
    return null;
  }
  final count = _le32(h, 8);
  if (count > 256 || 12 + count * 12 > size) return null;
  final dir = s.read(head + 12, count * 12);
  var start = head;
  final out = <SefEntry>[];
  for (var k = 0; k < count; k++) {
    final off = _le32(dir, k * 12 + 4);
    final len = _le32(dir, k * 12 + 8);
    final at = head - off;
    if (at < from || len < 8 || at + len > head) return null;
    if (at < start) start = at;
    final b = s.read(at, 8);
    final nameLen = _le32(b, 4);
    if (_le16(b, 0) != 0 || nameLen > 256 || 8 + nameLen > len) continue;
    final name = latin1.decode(s.read(at + 8, nameLen), allowInvalid: true);
    out.add(SefEntry(name, at + 8 + nameLen, len - 8 - nameLen));
  }
  return SefTrailer(start, out);
}
