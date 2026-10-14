// SPDX-License-Identifier: GPL-3.0-or-later
// a file is drawn by what its bytes are: an app called .mp4 is a card with
// the installer line, never a video; a photo called .bin is a photo. until
// the bytes are read the name decides, and the bubble is drawn again once
// they are. an installer shows the name it will be saved under
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/media_bubbles.dart';

import 'source_body.dart';
import 'zip_maker.dart';

final _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 74, 70, 73, 70, 0];
final _mp4 = [0, 0, 0, 24, ...'ftypisom'.codeUnits, 0, 0, 0, 0];

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('file_shape'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File made(String leaf, List<int> bytes) =>
      File('${tmp.path}/$leaf')..writeAsBytesSync(bytes);

  test('the bytes decide the shape once read', () async {
    final cases = <(String, List<int>, String, FileShape)>[
      ('a1', apkBytes(), 'clip.mp4', FileShape.card),
      ('a2', apkBytes(), 'holiday.jpg', FileShape.card),
      ('a3', [1, 2], 'game.apk', FileShape.card),
      ('a4', _mp4, 'clip.bin', FileShape.video),
      ('a5', _mp4, 'clip.mp4', FileShape.video),
      ('a6', _jpeg, 'photo.bin', FileShape.picture),
      ('a7', '%PDF-1.7\n'.codeUnits, 'scan.jpg', FileShape.card),
      ('a8', '%PDF-1.7\n'.codeUnits, 'film.mp4', FileShape.card),
      ('a9', 'plain words'.codeUnits, 'notes.txt', FileShape.card),
    ];
    for (final (leaf, bytes, name, want) in cases) {
      final f = made(leaf, bytes);
      await readFileFacts(f.path, name);
      expect(fileShapeNow(f.path, name), want, reason: name);
    }
  });

  test(
    'before the bytes are read the name decides, and a read is told',
    () async {
      final f = made('b1', apkBytes());
      final before = fileFactsRead.value;
      // drawn as a video for the one frame before the read lands
      expect(fileShapeNow(f.path, 'clip.mp4'), FileShape.video);
      expect(fileShapeNow(f.path, 'game.apk'), FileShape.card);
      expect(fileShapeNow(null, 'clip.mp4'), FileShape.video);
      expect(fileShapeNow(null, 'a.png'), FileShape.picture);
      await readFileFacts(f.path, 'clip.mp4');
      expect(fileFactsRead.value, greaterThan(before));
      expect(fileShapeNow(f.path, 'clip.mp4'), FileShape.card);
    },
  );

  test('both chats choose the bubble by the shape and redraw on a read', () {
    for (final (file, sig) in [
      ('lib/screens/chat_screen.dart', 'Widget _build(BuildContext context)'),
      ('lib/screens/group_chat_screen.dart', 'Widget _bubble('),
    ]) {
      final src = sourceOf(file);
      expect(src, isNot(contains('nameSaysVideo(')), reason: file);
      expect(src, contains('valueListenable: fileFactsRead'), reason: file);
      final body = src.substring(src.indexOf(sig));
      expect(body, contains('final shape = fileShapeNow('), reason: file);
      expect(
        body.replaceAll(RegExp(r'\s+'), ' '),
        contains('shape == FileShape.video'),
        reason: file,
      );
      expect(body, contains('shape: shape,'), reason: file);
    }
  });

  Future<void> show(WidgetTester t, Widget w) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: w)),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
    }
  }

  testWidgets('an app called .jpg is a card, never a picture', (t) async {
    final f = made('c1', apkBytes());
    await t.runAsync(() => readFileFacts(f.path, 'holiday.jpg'));
    await show(t, fileCard(f.path, 'holiday.jpg', false));
    expect(find.byType(Image), findsNothing);
    expect(find.text(l10n.fileInstallerLine), findsOneWidget);
  });

  testWidgets('a photo called .bin is shown as one', (t) async {
    final f = made('c2', _jpeg);
    await t.runAsync(() => readFileFacts(f.path, 'photo.bin'));
    await show(t, fileCard(f.path, 'photo.bin', false));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('an installer shows the name it is saved under', (t) async {
    final cases = {
      'holiday.jpg': ('holiday_jpg', apkBytes()),
      'photo.jpg.apk': ('photo_jpg', [1, 2, 3]),
      'Signal-7.20.apk': ('Signal-7.20', [1, 2, 3]),
    };
    var i = 0;
    for (final MapEntry(key: name, value: (stem, bytes)) in cases.entries) {
      final f = made('d${i++}', bytes);
      await show(t, FileCard(path: f.path, name: name, isOut: false));
      expect(find.text(stem), findsOneWidget, reason: name);
      expect(find.text('.apk'), findsOneWidget, reason: name);
      await t.runAsync(() async {
        expect(
          '$stem.apk',
          safeFileName(name, facts: await readFileFacts(f.path, name)),
          reason: name,
        );
      });
    }
  });
}
