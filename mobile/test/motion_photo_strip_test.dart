// SPDX-License-Identifier: GPL-3.0-or-later
// a heic or avif motion photo leaves as its still alone. the fixtures follow
// android's motion photo format: a real hevc or av1 still, an xmp item with
// the motion photo directory, and a real mp4 clip with sound and a place in
// an mpvd box at the end
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';

String _text(Uint8List b) => latin1.decode(b, allowInvalid: true);

int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

// start and end of each top level box, by type
List<(String, int, int)> _top(Uint8List b) {
  final out = <(String, int, int)>[];
  for (var i = 0; i + 8 <= b.length;) {
    final size = _u32(b, i);
    out.add((latin1.decode(b.sublist(i + 4, i + 8)), i, i + size));
    i += size;
  }
  return out;
}

List<int> _box(String type, List<int> body) {
  final n = body.length + 8;
  return [
    n >> 24,
    (n >> 16) & 255,
    (n >> 8) & 255,
    n & 255,
    ...latin1.encode(type),
    ...body,
  ];
}

void main() {
  for (final kind in ['heic', 'avif']) {
    group(kind, () {
      final src = File('test/fixtures/motion_photo.$kind').readAsBytesSync();
      final mpvd = _top(src).firstWhere((x) => x.$1 == 'mpvd');
      final still = src.sublist(0, mpvd.$2);
      final clip = src.sublist(mpvd.$2 + 8, mpvd.$3);
      final s = _text(src);
      final xmpAt = s.indexOf('<x:xmpmeta');
      final xmpEnd = s.indexOf('</x:xmpmeta>') + '</x:xmpmeta>'.length;

      test('the fixture holds a clip', () {
        expect(pictureKind(src), PictureKind.heif);
        expect(_text(clip).contains('ftyp'), true);
        expect(_text(clip).contains('+37.9838+023.7275'), true);
        expect(_text(clip).contains('SM-A217F'), true);
        expect(readMeta(MemorySource(src)).embeddedVideo, true);
      });

      test('the clip goes, the still stays byte for byte', () {
        final out = stripPictureBytes(src)!;
        expect(out.length, still.length);
        for (var i = 0; i < out.length; i++) {
          final want = i >= xmpAt && i < xmpEnd ? 0 : still[i];
          if (out[i] != want) fail('byte $i is ${out[i]}, not $want');
        }
        final t = _text(out);
        for (final gone in [
          'mpvd',
          'moov',
          'MotionPhoto',
          'SM-A217F',
          '37.9838',
        ]) {
          expect(t.contains(gone), false, reason: gone);
        }
        expect(_top(out).map((x) => x.$1).toList(), ['ftyp', 'meta', 'mdat']);
        final again = readMeta(MemorySource(out));
        expect(again.embeddedVideo, false);
        expect(again.status, MetaStatus.nothing);
      });

      test('the photo button sends the still alone', () {
        final out = photoToSend(src)!;
        expect(out.length, still.length);
        expect(_text(out).contains('mpvd'), false);
      });

      test('the file lane cuts the clip off the copy', () async {
        final dir = await Directory.systemTemp.createTemp('motion');
        addTearDown(() => dir.delete(recursive: true));
        final f = File('${dir.path}/IMG.$kind')..writeAsBytesSync(src);
        expect(await stripPictureFile(f.path), true);
        final out = f.readAsBytesSync();
        expect(out, stripPictureBytes(src));
        expect(out.length, still.length);
      });

      test('a whole mp4 hung after the still goes too', () {
        final out = stripPictureBytes(Uint8List.fromList([...still, ...clip]))!;
        expect(out.length, still.length);
        expect(_text(out).contains('SM-A217F'), false);
      });

      test('an image sequence keeps its moov, not an mpvd', () {
        // same length brand swap: the file now says it is a sequence
        final seq = Uint8List.fromList(still);
        final at = _text(seq).indexOf(kind == 'heic' ? 'mif1' : 'avif', 8);
        seq.setRange(
          at,
          at + 4,
          latin1.encode(kind == 'heic' ? 'msf1' : 'avis'),
        );
        final moov = _top(clip).firstWhere((x) => x.$1 == 'moov');
        final anim = _box('moov', clip.sublist(moov.$2 + 8, moov.$3));
        final out = stripPictureBytes(
          Uint8List.fromList([...seq, ...anim, ..._box('mpvd', clip)]),
        )!;
        expect(_top(out).map((x) => x.$1), contains('moov'));
        expect(_top(out).map((x) => x.$1), isNot(contains('mpvd')));
      });
    });
  }
}
