// SPDX-License-Identifier: GPL-3.0-or-later
// a file sent as a file is cleaned only when it is a picture. the first
// bytes say so, and nothing else is read whole into memory: a 15 mb zip
// on a 32-bit phone is never held at once
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/image_strip.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('strip_head'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('a file that is not a picture is never read whole', () async {
    for (final head in [
      'PK\u0003\u0004'.codeUnits,
      '%PDF-1.7\n'.codeUnits,
      [0, 0, 0, 24, ...'ftypisom'.codeUnits],
      'plain words'.codeUnits,
    ]) {
      final f = File('${tmp.path}/x')
        ..writeAsBytesSync([...head, ...List.filled(4096, 7)]);
      var reads = 0;
      final r = await stripPictureFile(
        f.path,
        readAll: (f) async {
          reads++;
          return f.readAsBytes();
        },
      );
      expect(r, isFalse);
      expect(reads, 0);
    }
  });

  test('a picture is read and cleaned', () async {
    // the smallest jpeg the cleaner walks: start, an app segment, end
    final jpeg = Uint8List.fromList([
      0xFF, 0xD8, //
      0xFF, 0xE1, 0, 8, ...'Exif'.codeUnits, 0, 0, //
      0xFF, 0xD9,
    ]);
    final f = File('${tmp.path}/p')..writeAsBytesSync(jpeg);
    var reads = 0;
    await stripPictureFile(
      f.path,
      readAll: (f) async {
        reads++;
        return f.readAsBytes();
      },
    );
    expect(reads, 1);
  });
}
