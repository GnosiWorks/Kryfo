// SPDX-License-Identifier: GPL-3.0-or-later
// the pictures held in memory rather than sealed files: profile photos, a
// chat's wallpaper, the face viewer and the flights between bubble and
// viewer. under the lock none of them keeps an image, a profile photo and
// a wallpaper show their blur, and after the lock the photo comes back
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart' show Atmo;
import 'package:kryfo/picture_lock.dart' show picturesShut;
import 'package:kryfo/profile_photo.dart' show PhotoBook;
import 'package:kryfo/wallpaper.dart' show ChatWall;
import 'package:kryfo/widgets/album_grid.dart' show albumFlight;
import 'package:kryfo/widgets/chat_backdrop.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/photo_viewer.dart' show photoFlight;
import 'package:kryfo/widgets/pictures_gate.dart';
import 'package:kryfo/widgets/sealed_picture.dart' show BlurPainter;

// a real picture, red left and blue right, as png
Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
    Paint()..color = const Color(0xFFE53935),
  );
  c.drawRect(
    Rect.fromLTWH(w / 2, 0, w / 2, h.toDouble()),
    Paint()..color = const Color(0xFF1E88E5),
  );
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Finder _images(Finder within) =>
    find.descendant(of: within, matching: find.byType(Image));

bool _blurDrawn(WidgetTester t, Finder within) => t
    .widgetList<CustomPaint>(
      find.descendant(of: within, matching: find.byType(CustomPaint)),
    )
    .any((p) => p.painter is BlurPainter);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
  }
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() => picturesShut.value = false);

  testWidgets('a profile photo lets go under the lock and shows its blur', (
    t,
  ) async {
    final bytes = (await t.runAsync(() => _png(64, 64)))!;
    final book = PhotoBook()..put({'amber-fox-river': bytes});
    await t.pumpWidget(
      _app(KryfoAvatar(seed: 'amber-fox-river', size: 48, book: book)),
    );
    await _settle(t);
    final avatar = find.byType(KryfoAvatar);
    expect(_images(avatar), findsOneWidget);
    // made from the held bytes while unlocked
    expect(heldBlurOf(bytes), isNotNull);

    picturesShut.value = true;
    await t.pump();
    expect(_images(avatar), findsNothing);
    expect(_blurDrawn(t, avatar), isTrue);

    picturesShut.value = false;
    await t.pump();
    expect(_images(avatar), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('no blur is made behind the lock: the face stands in', (t) async {
    final bytes = (await t.runAsync(() => _png(40, 40)))!;
    final book = PhotoBook()..put({'neon-tiger-saturn': bytes});
    picturesShut.value = true;
    await t.pumpWidget(
      _app(KryfoAvatar(seed: 'neon-tiger-saturn', size: 48, book: book)),
    );
    await _settle(t);
    expect(heldBlurOf(bytes), isNull);
    final avatar = find.byType(KryfoAvatar);
    expect(_images(avatar), findsNothing);
    expect(_blurDrawn(t, avatar), isFalse);
    // the drawn face: its initial
    expect(find.text('N'), findsOneWidget);

    picturesShut.value = false;
    await t.pump();
    await _settle(t);
    expect(_images(avatar), findsOneWidget);
    expect(heldBlurOf(bytes), isNotNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a wallpaper lets go of its decoded copy under the lock', (
    t,
  ) async {
    final bytes = (await t.runAsync(() => _png(90, 160)))!;
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          height: 500,
          child: ChatBackdrop(ChatWall(Atmo.none, bytes), chat: 'c1'),
        ),
      ),
    );
    await _settle(t);
    final wall = find.byType(ChatBackdrop);
    expect(_images(wall), findsOneWidget);
    expect(heldBlurOf(bytes), isNotNull);

    picturesShut.value = true;
    await t.pump();
    expect(_images(wall), findsNothing);
    expect(_blurDrawn(t, wall), isTrue);

    picturesShut.value = false;
    await t.pump();
    expect(_images(wall), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a lock mid flight takes the flying picture with it', (t) async {
    final bytes = (await t.runAsync(() => _png(20, 20)))!;
    final a = AnimationController(vsync: const TestVSync(), value: 0.5);
    addTearDown(a.dispose);
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 200,
          height: 100,
          child: Row(
            children: [
              Expanded(child: photoFlight(a, MemoryImage(bytes), 8)),
              Expanded(child: albumFlight(a, '/nowhere.jpg', video: false)),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(2));
    picturesShut.value = true;
    await t.pump();
    expect(find.byType(Image), findsNothing);
    picturesShut.value = false;
    await t.pump();
    expect(find.byType(Image), findsNWidgets(2));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the gate shows what it is given under the lock', (t) async {
    await t.pumpWidget(
      _app(const PicturesGate(shut: Text('shut'), child: Text('open'))),
    );
    expect(find.text('open'), findsOneWidget);
    picturesShut.value = true;
    await t.pump();
    expect(find.text('shut'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });
}
