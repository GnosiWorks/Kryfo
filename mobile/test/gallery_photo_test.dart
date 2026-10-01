// SPDX-License-Identifier: GPL-3.0-or-later
// a photo from the gallery leaves with its picture and nothing else. the
// file is a jpeg any decoder reads, laid out the way a phone's gallery
// hands one over: exif with make, model, serial, owner, capture time and
// gps, a thumbnail, xmp, and a vendor trailer after the end
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/jpeg_strip.dart';

import 'source_body.dart';

final _raw = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();

// what the gallery's copy carries that must not leave
const _traces = [
  'samsung',
  'SM-S918B',
  'R5CW1234XYZ',
  'K12LLKA00SM',
  'Owner of this phone',
  'S918BXXU3BXH8',
  '2026:09:12',
  '+02:00',
  'MAKERNOTE',
  'GPSLatitude',
  'xmpmeta',
  'SEFT',
];

bool _holds(Uint8List b, String s) =>
    latin1.decode(b, allowInvalid: true).contains(s);

// the gps block: its latitude ref, as the gallery writes it
bool _holdsGps(Uint8List b) {
  final s = latin1.decode(b, allowInvalid: true);
  return s.contains('\x01\x00\x02\x00\x02\x00\x00\x00N\x00');
}

// the one exif tag kept: which way up, in the block the stripper writes
int? _turn(Uint8List b) {
  for (var i = 2; i + 36 <= b.length; i++) {
    if (b[i] == 0xFF && b[i + 1] == 0xE1 && b[i + 3] == 0x22) {
      return b[i + 29];
    }
  }
  return null;
}

Future<(int, int, Uint8List)> _pixels(Uint8List b) async {
  final codec = await ui.instantiateImageCodec(b);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (img.width, img.height, data!.buffer.asUint8List());
}

void main() {
  test('the fixture is what a phone hands over', () {
    expect(_raw.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    for (final s in _traces) {
      expect(_holds(_raw, s), isTrue, reason: s);
    }
    expect(_holdsGps(_raw), isTrue);
    expect(jpegHasExif(_raw), isTrue);
  });

  test('what leaves carries none of it', () {
    final out = photoToSend(_raw)!;
    for (final s in _traces) {
      expect(_holds(out, s), isFalse, reason: s);
    }
    expect(_holdsGps(out), isFalse);
    expect(jpegHasExif(out), isFalse);
    // the phone was held sideways: that alone stays, or the photo lies down
    expect(_turn(out), 6);
  });

  testWidgets('and it is the same picture, pixel for pixel', (t) async {
    await t.runAsync(() async {
      final before = await _pixels(_raw);
      final after = await _pixels(photoToSend(_raw)!);
      expect(after.$1, before.$1);
      expect(after.$2, before.$2);
      expect(after.$1 * after.$2, 48 * 32);
      expect(after.$3, before.$3);
    });
  });

  test('off the ui thread it is the same', () async {
    expect(await photoToSendOffUi(_raw), photoToSend(_raw));
  });

  test('a jpeg that cannot be read through is dropped, not sent', () {
    // cut inside the scan, with no end marker
    expect(
      photoToSend(Uint8List.sublistView(_raw, 0, _raw.length - 200)),
      isNull,
    );
  });

  // a photo saved unsent by a version that did not clean the gallery's
  // copy still holds the tags on disk: every send cleans it first
  group('a saved photo', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('saved'));
    tearDown(() => tmp.delete(recursive: true));

    test('is cleaned in place once, then left alone', () async {
      final f = File('${tmp.path}/old.jpg')..writeAsBytesSync(_raw);
      expect(await cleanSavedPhoto(f.path), isTrue);
      final now = f.readAsBytesSync();
      expect(jpegHasExif(now), isFalse);
      expect(_holdsGps(now), isFalse);
      for (final s in _traces) {
        expect(_holds(now, s), isFalse, reason: s);
      }
      expect(await cleanSavedPhoto(f.path), isFalse);
      expect(f.readAsBytesSync(), now);
    });

    test('one that cannot be read through may not go', () async {
      final cut = Uint8List.sublistView(_raw, 0, _raw.length - 200);
      final f = File('${tmp.path}/cut.jpg')..writeAsBytesSync(cut);
      expect(await cleanSavedPhoto(f.path), isNull);
      expect(await cleanSavedPhoto('${tmp.path}/gone.jpg'), isNull);
    });
  });

  test('the one-to-one sender cleans a photo before the first slice', () {
    final body = bodyOf(
      sourceOf('lib/media_send.dart'),
      'Future<String> _sendChunkedMediaInner(',
    );
    final clean = body.indexOf('await cleanSavedPhoto(path)');
    expect(clean, greaterThan(0));
    expect(body.indexOf('mediaSliceCount(path)'), greaterThan(clean));
    expect(body, contains("if (cleaned == null) return 'error: not clean';"));
    expect(body, contains('if (fileName == null && !voice)'));
  });

  test('the group sender is told which rows are photos', () {
    final body = bodyOf(
      sourceOf('lib/main.dart'),
      'Future<String> sendMediaToGroup(',
    );
    expect(body, contains('photo: fileName == null && !voice,'));
  });

  // every photo lane ends in one of these two: the gallery, one or many,
  // with a caption or without, the in-app camera and the gif tile, in a
  // chat, a group or a room
  for (final (file, fn) in [
    ('lib/screens/chat_screen.dart', 'Future<void> _sendOneImage('),
    ('lib/screens/group_chat_screen.dart', 'Future<void> _sendGroupImage('),
  ]) {
    test('$fn cleans before anything touches disk', () {
      final body = bodyOf(sourceOf(file), fn);
      final clean = body.indexOf('await photoToSendOffUi(raw)');
      expect(clean, greaterThan(0));
      expect(body.indexOf('writeAsBytes(bytes'), greaterThan(clean));
      // the raw bytes go nowhere else
      expect(RegExp(r'\braw\b').allMatches(body).length, 2);
    });
  }

  test('the gallery pickers send through those two and nothing else', () {
    for (final (file, picker, send) in [
      (
        'lib/screens/chat_screen.dart',
        'Future<void> _pickAndSendMultiple(',
        '_sendOneImage(',
      ),
      (
        'lib/screens/group_chat_screen.dart',
        'Future<void> _pickGroupMultiple(',
        '_sendGroupImage(',
      ),
    ]) {
      final body = bodyOf(sourceOf(file), picker);
      expect(body, contains(send));
      expect(body, isNot(contains('mediaDirOf')));
      expect(body, isNot(contains('writeAsBytes')));
    }
  });
}
