// SPDX-License-Identifier: GPL-3.0-or-later
// on flutter 3.41.7 a method channel's bytes are a read-only view. every
// place that zeroes bytes it got from a channel has to zero its own copy:
// a throw there blanked every pdf page and jammed the lock (phone check
// 2026-11-10, F1 and F2). the answers here come read-only, as on a phone.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/open_file.dart';
import 'package:kryfo/pdf_pages.dart';
import 'package:kryfo/picture_lock.dart';

const _codec = StandardMethodCodec();

// [name] answers each call with [answer], encoded read-only like the engine
void _readOnly(String name, Object? Function(MethodCall c) answer) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(name, (m) async {
        final call = _codec.decodeMethodCall(m);
        return _codec.encodeSuccessEnvelope(answer(call)).asUnmodifiableView();
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('chbytes');
  });

  tearDown(() {
    for (final n in ['kryfo/pdf', 'halo/platform']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(n, null);
    }
    pdfBackendForTest = null;
    pdfMarksDirForTest = null;
    resetPicturesForTest();
    dir.deleteSync(recursive: true);
  });

  test('the bytes really come read-only', () async {
    _readOnly('halo/platform', (_) => {'jpeg': Uint8List(4)});
    final m = await const MethodChannel(
      'halo/platform',
    ).invokeMapMethod<String, Object?>('videoInfo');
    final b = m!['jpeg']! as Uint8List;
    expect(() => b.fillRange(0, b.length, 0), throwsUnsupportedError);
  });

  test('a pdf page draws from read-only bytes', () async {
    // the phone's own backend, over the channel
    pdfBackendForTest = null;
    pdfMarksDirForTest = dir.path;
    _readOnly('kryfo/pdf', (c) {
      switch (c.method) {
        case 'open':
          return {
            'id': 1,
            'pages': 1,
            'sizes': [2, 2],
          };
        case 'render':
          return {'w': 2, 'h': 2, 'rgba': Uint8List(16)..fillRange(0, 16, 200)};
      }
      return null;
    });
    final f = File('${dir.path}/a.pdf')..writeAsStringSync('%PDF-1.7\n');
    final d = await PdfDoc.open(f.path);
    final img = await d.page(0, 2);
    expect(img, isNotNull);
    expect(img!.width, 2);
    img.dispose();
    await d.close();
  });

  test(
    'a video frame from read-only bytes is zeroed as the lock goes up',
    () async {
      _readOnly(
        'halo/platform',
        (c) => c.method == 'videoInfo'
            ? {
                'jpeg': Uint8List.fromList([0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9]),
                'ms': 1000,
                'w': 16,
                'h': 9,
              }
            : null,
      );
      final path = '${dir.path}/v.mp4';
      final info = await videoInfoFor(path);
      final j = info!.jpeg!;
      expect(j.first, 0xFF);
      // the lock's own call, and the frame is zero in memory after it
      expect(forgetVideoFrames, returnsNormally);
      expect(j.every((b) => b == 0), isTrue);
      expect(info.jpeg, isNull);
      forgetVideoInfo(path);
    },
  );
}
