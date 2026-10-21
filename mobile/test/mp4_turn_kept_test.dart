// SPDX-License-Identifier: GPL-3.0-or-later
// a clip recorded upright carries its turn in the track header's matrix and
// its shown size after it. the strip zeroes only the two stamps before them,
// so a cleaned clip still plays upright and at its own shape.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/mp4_strip.dart';

Uint8List box(String type, List<int> payload) {
  final size = 8 + payload.length;
  return Uint8List.fromList([
    size >> 24,
    (size >> 16) & 0xff,
    (size >> 8) & 0xff,
    size & 0xff,
    ...type.codeUnits,
    ...payload,
  ]);
}

List<int> u32(int v) => [
  v >> 24 & 0xff,
  v >> 16 & 0xff,
  v >> 8 & 0xff,
  v & 0xff,
];

// a quarter turn clockwise, as a phone held upright writes it
final turn90 = [
  ...u32(0), ...u32(0x00010000), ...u32(0), //
  ...u32(0xffff0000), ...u32(0), ...u32(0), //
  ...u32(0), ...u32(0), ...u32(0x40000000),
];

// tkhd laid out as the spec has it: stamps, track id, duration, layer,
// group, volume, the matrix, then width and height in 16.16
List<int> tkhd(int version) {
  final w = version == 1 ? 8 : 4;
  return [
    version, 0, 0, 7, // flags: enabled, in movie, in preview
    ...List.filled(w, 0x5a), // creation
    ...List.filled(w, 0x5b), // modification
    ...u32(1), // track id
    ...u32(0), // reserved
    ...List.filled(w, 0x01), // duration
    ...List.filled(8, 0), // reserved
    0, 0, 0, 0, 0, 0, 0, 0, // layer, group, volume, reserved
    ...turn90,
    ...u32(1920 << 16),
    ...u32(1080 << 16),
  ];
}

Uint8List clip(int version) {
  final t = box('tkhd', tkhd(version));
  final trak = box('trak', t);
  final moov = box('moov', trak);
  return Uint8List.fromList([
    ...box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0]),
    ...moov,
    ...box('mdat', 'frames'.codeUnits),
  ]);
}

int payloadOf(Uint8List b, String type) {
  final t = type.codeUnits;
  for (var i = 0; i + 4 <= b.length; i++) {
    if (b[i] == t[0] &&
        b[i + 1] == t[1] &&
        b[i + 2] == t[2] &&
        b[i + 3] == t[3]) {
      return i + 4;
    }
  }
  return -1;
}

void main() {
  for (final v in [0, 1]) {
    test('version $v: the matrix and shown size survive the strip', () async {
      final dir = await Directory.systemTemp.createTemp('mp4turn');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/clip.mp4');
      final src = clip(v);
      await f.writeAsBytes(src);
      expect(await stripMp4Metadata(f.path), true);
      final out = await f.readAsBytes();
      expect(out.length, src.length);
      final at = payloadOf(out, 'tkhd');
      final w = v == 1 ? 8 : 4;
      // the stamps are gone
      expect(out.sublist(at + 4, at + 4 + 2 * w), everyElement(0));
      // everything after them is as it was: id, duration, matrix, size
      final tail = 4 + 2 * w;
      final size = tkhd(v).length;
      expect(
        out.sublist(at + tail, at + size),
        src.sublist(at + tail, at + size),
      );
      final m = at + size - 8 - 36;
      expect(out.sublist(m, m + 36), turn90);
      expect(out.sublist(at + size - 8, at + size), [
        ...u32(1920 << 16),
        ...u32(1080 << 16),
      ]);
      expect(await mp4MetadataCount(f.path), 0);
    });
  }
}
