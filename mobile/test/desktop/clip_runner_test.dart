// SPDX-License-Identifier: GPL-3.0-or-later
// ctrl and v on linux reads what windows' runner reads, in the same shapes:
// copied files as paths, a copied picture as png bytes, both in memory. and
// "Copy picture" puts a png kryfo made on the clipboard on both, with a
// bitmap beside it on windows
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/clip_picture.dart';
import 'package:kryfo/desktop/desktop_run.dart' show runChannel;

String _body(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThan(0), reason: head);
  return src.substring(at, src.indexOf('\n}\n', at));
}

Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    ui.Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  c.drawRect(
    ui.Rect.fromLTWH(w / 2, 0, w / 2, h / 2),
    ui.Paint()..color = const ui.Color(0x8000FF00),
  );
  final img = await rec.endRecording().toImage(w, h);
  final b = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return b!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('linux reads copied files and a copied picture in memory', () {
    final src = File('linux/runner/my_application.cc').readAsStringSync();
    for (final m in ['"clipFiles"', '"clipPicture"', '"setClipPicture"']) {
      expect(src, contains('fl_method_call_get_name(call), $m'), reason: m);
    }
    final files = _body(src, 'static void clip_files_got(');
    expect(files, contains('g_filename_from_uri'));
    // gnome's "copy" line and a uri list's comments are no files
    expect(files, contains('g_str_has_prefix(*l, "file://")'));
    final targets = _body(src, 'static void clip_files_targets(');
    expect(targets, contains('x-special/gnome-copied-files'));
    expect(targets, contains('text/uri-list'));
    final picture = _body(src, 'static void clip_picture_targets(');
    expect(picture, contains('"image/png"'));
    expect(picture, contains('gtk_targets_include_text'));
    final words = _body(src, 'static void clip_picture_text(');
    expect(words, contains('lone_link(text)'));
    final link = _body(src, 'static gboolean lone_link(');
    for (final f in [
      '"http://"',
      '"https://"',
      'g_ascii_isspace',
      'kLinkMost',
    ]) {
      expect(link, contains(f));
    }
    final got = _body(src, 'static void clip_picture_got(');
    expect(got, contains('kPictureMost'));
    expect(got, contains('"kind"'));
    expect(got, contains('"text"'));
    final clip = src.substring(
      src.indexOf('static const gsize kPictureMost'),
      src.indexOf('static void desktop_call_cb('),
    );
    for (final disk in ['fopen', 'g_file_set_contents', 'g_mkstemp', 'open(']) {
      expect(clip, isNot(contains(disk)), reason: disk);
    }
    // read when asked, never watched
    expect(clip, isNot(contains('"owner-change"')));
  });

  test('windows puts a png and a bitmap on the clipboard, nothing on disk', () {
    final src = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(src, contains('call.method_name() == "setClipPicture"'));
    final body = _body(src, 'bool SetClipboardPicture(');
    for (final f in ['L"PNG"', 'CF_DIBV5', 'EmptyClipboard', 'kPictureMost']) {
      expect(body, contains(f));
    }
    for (final disk in ['CreateFile', 'GetTempPath', 'fopen', 'ofstream']) {
      expect(body, isNot(contains(disk)));
    }
  });

  test(
    'a bitmap made for windows reads back as the picture it came from',
    () async {
      final png = await _png(6, 4);
      final px = await pngPixels(png);
      expect(px, isNotNull);
      final dib = rgbaToDib(px!);
      expect(ByteData.sublistView(dib).getUint32(0, Endian.little), 124);
      final back = dibToRgba(dib)!;
      expect(back.width, 6);
      expect(back.height, 4);
      expect(back.rgba, px.rgba);
      // red on the left, see-through green top right
      expect(back.rgba.sublist(0, 4), [255, 0, 0, 255]);
      expect(back.rgba[5 * 4 + 1], greaterThan(200));
      expect(back.rgba[5 * 4 + 3], inInclusiveRange(120, 136));
      expect(await pngPixels(Uint8List.fromList([1, 2, 3])), isNull);
    },
  );

  test(
    'copy picture hands the runner the png, and says when it would not',
    () async {
      final calls = <MethodCall>[];
      var answer = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(runChannel, (c) async {
            calls.add(c);
            return answer;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(runChannel, null),
      );
      final png = await _png(2, 2);
      expect(await copyPicture(png), isTrue);
      expect(calls.single.method, 'setClipPicture');
      expect((calls.single.arguments as Map)['png'], png);
      // a cleaned jpeg goes over as a png too
      calls.clear();
      final jpeg = File('test/fixtures/photo_512.jpg').readAsBytesSync();
      expect(await copyPicture(jpeg), isTrue);
      expect(
        looksPng((calls.single.arguments as Map)['png'] as Uint8List),
        isTrue,
      );
      answer = false;
      expect(await copyPicture(png), isFalse);
      calls.clear();
      expect(await copyPicture(Uint8List.fromList([1, 2, 3])), isFalse);
      expect(calls, isEmpty);
    },
  );
}
