// SPDX-License-Identifier: GPL-3.0-or-later
// jpegs with a header hidden behind ff 00. a decoder skips the two bytes
// and reads on at the next marker, so it reads what a walk that takes
// ff 00 for a segment never sees
import 'dart:typed_data';

// where [b]'s first scan starts
int _scanAt(Uint8List b) {
  var i = 2;
  while (b[i + 1] != 0xDA) {
    i += 2 + (b[i + 2] << 8 | b[i + 3]);
  }
  return i;
}

/// [b], a 512 square, with a frame of [side] x [side] in front behind
/// ff 00, then an app1 that swallows b's own header. both share b's scan
Uint8List hiddenFrame(Uint8List b, int side, {bool progressive = false}) {
  final at = _scanAt(b);
  final seen = Uint8List.sublistView(b, 2, at);
  final hidden = Uint8List.fromList(seen);
  for (var i = 0; i < hidden.length;) {
    final len = hidden[i + 2] << 8 | hidden[i + 3];
    if (hidden[i + 1] == 0xC0) {
      if (progressive) hidden[i + 1] = 0xC2;
      ByteData.sublistView(hidden)
        ..setUint16(i + 5, side)
        ..setUint16(i + 7, side);
    }
    i += 2 + len;
  }
  final swallow = seen.length + 2;
  final len = 2 + hidden.length + 4;
  for (final x in [len >> 8, len & 0xFF, swallow >> 8, swallow & 0xFF]) {
    if (x == 0xFF) throw StateError('a length byte reads as a marker');
  }
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0x00, len >> 8, len & 0xFF, //
    ...hidden,
    0xFF, 0xE1, swallow >> 8, swallow & 0xFF, //
    ...seen,
    ...Uint8List.sublistView(b, at),
  ]);
}

/// [b] with the segment starting at [seg] moved behind ff 00, where a
/// reader that takes ff 00 for a segment skips it and a decoder does not
Uint8List hiddenSegment(Uint8List b, int seg) {
  final end = seg + 2 + (b[seg + 2] << 8 | b[seg + 3]);
  final len = 2 + end - seg;
  if (len >> 8 == 0xFF || len & 0xFF == 0xFF) throw StateError('length');
  return Uint8List.fromList([
    ...b.sublist(0, seg),
    0xFF, 0x00, len >> 8, len & 0xFF, //
    ...b.sublist(seg),
  ]);
}
