// SPDX-License-Identifier: GPL-3.0-or-later
// a photo or a gif in a bubble keeps its own shape: portrait, landscape and
// square whole inside the bubble's bounds, very tall or very wide ones at
// the floors and cropped there. the shape is the blur's before the decode,
// the decode's when there is no blur, and a caption wraps at the photo
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/photo_shape.dart';

// a plain png of [w] by [h], drawn by the engine
Future<Uint8List> pngOf(int w, int h) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xffd97706),
  );
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  setUp(forgetPhotoAspects);

  group('the box', () {
    // a phone's 1:1 bubble, a computer's, a group's
    const bounds = [(312.0, 360.0), (420.0, 360.0), (240.0, 280.0)];

    for (final (mw, mh) in bounds) {
      test('portrait, landscape and square keep their shape in $mw x $mh', () {
        for (final a in [3 / 4, 9 / 16, 4 / 3, 16 / 9, 1.0]) {
          final s = photoBoxSize(a, maxWidth: mw, maxHeight: mh);
          expect(s.width / s.height, closeTo(a, 0.001), reason: '$a');
          expect(s.width, lessThanOrEqualTo(mw));
          expect(s.height, lessThanOrEqualTo(mh));
          // it fills one side of the bounds
          expect(
            (s.width - mw).abs() < 0.001 || (s.height - mh).abs() < 0.001,
            isTrue,
            reason: '$a',
          );
        }
      });

      test('very tall and very wide stop at the floors in $mw x $mh', () {
        final tall = photoBoxSize(1 / 8, maxWidth: mw, maxHeight: mh);
        expect(tall, Size(kPhotoMinWidth, mh));
        final wide = photoBoxSize(8, maxWidth: mw, maxHeight: mh);
        expect(wide, Size(mw, kPhotoMinHeight));
      });
    }

    test('a shape not known yet is drawn at four by three', () {
      for (final a in [0.0, double.nan, double.infinity, -1.0]) {
        final s = photoBoxSize(a, maxWidth: 312, maxHeight: 360);
        expect(s.width / s.height, closeTo(kPhotoGuess, 0.001));
      }
    });

    testWidgets('a computer\'s wide column caps it, a phone does not reach '
        'the cap', (t) async {
      late double desk, phone;
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(720, 900)),
          child: Builder(
            builder: (c) {
              desk = photoMaxWidth(c);
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Builder(
            builder: (c) {
              phone = photoMaxWidth(c);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(desk, kPhotoMaxWidth);
      expect(phone, closeTo(400 * 0.78, 0.001));
    });
  });

  group('in a bubble', () {
    // a bubble as the chat lays one out: as wide as its widest line
    Widget bubble(Widget photo, {String caption = '', bool led = true}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    photo,
                    PhotoLedWidth(
                      on: led,
                      child: Text(
                        caption,
                        key: const ValueKey('caption'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    Widget shaped(String path, {ImageProvider? image}) => PhotoShape(
      path: path,
      image: image,
      maxWidth: 420,
      child: const ColoredBox(
        key: ValueKey('picture'),
        color: Color(0xff7c3aed),
      ),
    );

    for (final (name, a) in [
      ('portrait', 3 / 4),
      ('landscape', 4 / 3),
      ('square', 1.0),
      ('very tall', 1 / 9),
    ]) {
      testWidgets('a $name photo with a caption: the bubble is the photo\'s '
          'width and the words wrap there', (t) async {
        rememberPhotoAspect('/m/$name', a);
        await t.pumpWidget(
          bubble(
            shaped('/m/$name'),
            caption:
                'a caption long enough to be wider than any photo here '
                'if it were left on one line',
          ),
        );
        final pic = t.getSize(find.byKey(const ValueKey('picture')));
        final want = photoBoxSize(a, maxWidth: 420, maxHeight: kPhotoMaxHeight);
        expect(pic, want);
        final words = t.getSize(find.byKey(const ValueKey('caption')));
        expect(words.width, lessThanOrEqualTo(pic.width + 0.001));
        final col = t.getSize(find.byType(Column));
        expect(col.width, closeTo(pic.width, 0.001));
      });
    }

    testWidgets('without the photo leading, a long caption widens the bubble '
        '(what the lead is for)', (t) async {
      rememberPhotoAspect('/m/p', 3 / 4);
      await t.pumpWidget(
        bubble(
          shaped('/m/p'),
          caption:
              'a caption long enough to be wider than any photo here '
              'if it were left on one line',
          led: false,
        ),
      );
      final pic = t.getSize(find.byKey(const ValueKey('picture')));
      expect(t.getSize(find.byType(Column)).width, greaterThan(pic.width));
    });

    testWidgets('no blur: the decode gives the shape, the box changes once', (
      t,
    ) async {
      final png = (await t.runAsync(() => pngOf(90, 180)))!;
      final image = MemoryImage(png);
      await t.pumpWidget(bubble(shaped('/m/nodecode', image: image)));
      final guess = t.getSize(find.byKey(const ValueKey('picture')));
      expect(guess.width / guess.height, closeTo(kPhotoGuess, 0.001));
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      final real = t.getSize(find.byKey(const ValueKey('picture')));
      expect(real, const Size(kPhotoMaxHeight / 2, kPhotoMaxHeight));
      // remembered: the next bubble of it starts there
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(bubble(shaped('/m/nodecode', image: image)));
      expect(t.getSize(find.byKey(const ValueKey('picture'))), real);
    });
  });
}
