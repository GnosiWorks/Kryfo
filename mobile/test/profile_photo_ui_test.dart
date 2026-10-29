// SPDX-License-Identifier: GPL-3.0-or-later
// profile photos on screen. a face with a photo in the book shows it, round,
// and says nothing to a screen reader; the face picker always draws faces.
// the crop keeps the circle covered whatever the fingers do, and keeps the
// square it shows; it fits large text, right to left and still motion. the
// sheet offers only what applies
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/app_localizations.dart';
import 'package:kryfo/profile_photo.dart';
import 'package:kryfo/screens/photo_crop_screen.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/photo_sheet.dart';

final _gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
final Uint8List _clean = photoFit(_gps)!;

Widget _app(
  Widget home, {
  TextDirection dir = TextDirection.ltr,
  double text = 1,
  bool still = false,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (c) => MediaQuery(
      data: MediaQuery.of(
        c,
      ).copyWith(textScaler: TextScaler.linear(text), disableAnimations: still),
      child: Directionality(textDirection: dir, child: home),
    ),
  ),
);

void main() {
  group('the crop\'s square', () {
    test('at the cover it is the middle of the short side', () {
      final sq = cropSquare(
        w: 1600,
        h: 1200,
        circle: 300,
        scale: 1,
        offset: Offset.zero,
      );
      expect(sq, (left: 200, top: 0, side: 1200));
    });

    test('in twice and moved right, it is half as big and further left', () {
      final sq = cropSquare(
        w: 1600,
        h: 1200,
        circle: 300,
        scale: 2,
        offset: const Offset(100, 0),
      );
      // 300 / 1200 * 2 = 0.5 screen px per picture px
      expect(sq.side, 600);
      expect(sq.left, 800 - 200 - 300);
      expect(sq.top, 300);
    });

    test('the picture always covers the circle', () {
      for (final s in [1.0, 1.5, 3.0, kCropZoomMost]) {
        final o = cropClamp(
          w: 1600,
          h: 1200,
          circle: 300,
          scale: s,
          o: const Offset(99999, -99999),
        );
        final sq = cropSquare(
          w: 1600,
          h: 1200,
          circle: 300,
          scale: s,
          offset: o,
        );
        expect(sq.left, greaterThanOrEqualTo(0));
        expect(sq.top, greaterThanOrEqualTo(0));
        expect(sq.left + sq.side, lessThanOrEqualTo(1600));
        expect(sq.top + sq.side, lessThanOrEqualTo(1200));
      }
      expect(
        cropClamp(
          w: 1200,
          h: 1200,
          circle: 300,
          scale: 1,
          o: const Offset(50, 50),
        ),
        Offset.zero,
      );
    });
  });

  group('the face', () {
    testWidgets('a photo in the book shows over the face, silently', (t) async {
      final sem = t.ensureSemantics();
      final book = PhotoBook()..put({'calm-orbit-river': _clean});
      await t.pumpWidget(
        _app(
          Center(
            child: KryfoAvatar(seed: 'calm-orbit-river', size: 56, book: book),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('COR'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      sem.dispose();
    });

    testWidgets('it comes and goes as the book does', (t) async {
      final book = PhotoBook();
      await t.pumpWidget(
        _app(
          Center(
            child: KryfoAvatar(seed: 'calm-orbit-river', size: 56, book: book),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      book.put({'calm-orbit-river': _clean});
      await t.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      book.clear();
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('COR'), findsOneWidget);
    });

    testWidgets('with still motion it swaps at once', (t) async {
      final book = PhotoBook();
      await t.pumpWidget(
        _app(
          Center(
            child: KryfoAvatar(seed: 'calm-orbit-river', size: 56, book: book),
          ),
          still: true,
        ),
      );
      book.put({'calm-orbit-river': _clean});
      await t.pump();
      await t.pump();
      expect(find.text('COR'), findsNothing);
    });

    testWidgets('the face picker draws faces', (t) async {
      final book = PhotoBook()..put({'calm-orbit-river': _clean});
      await t.pumpWidget(
        _app(
          Center(
            child: KryfoAvatar(
              seed: 'calm-orbit-river',
              size: 56,
              book: book,
              photo: false,
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the crop screen', () {
    for (final (dir, text, still) in [
      (TextDirection.ltr, 1.0, false),
      (TextDirection.rtl, 2.0, true),
      (TextDirection.ltr, 3.0, false),
    ]) {
      testWidgets('fits and keeps a square ($dir, text $text, still $still)', (
        t,
      ) async {
        t.view.physicalSize = const Size(720, 1280);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        PhotoSquare? got;
        await t.pumpWidget(
          _app(
            Builder(
              builder: (c) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      got = await Navigator.of(c).push<PhotoSquare>(
                        MaterialPageRoute(
                          builder: (_) => PhotoCropScreen(bytes: _clean),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            dir: dir,
            text: text,
            still: still,
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Move and scale'), findsOneWidget);
        // a drag past the edge settles back with the circle covered
        await t.drag(find.byType(Image), const Offset(400, 0));
        await t.pumpAndSettle();
        await t.tap(find.text('Use photo'));
        await t.pumpAndSettle();
        expect(got, isNotNull);
        expect(got!.side, greaterThan(0));
        expect(got!.left, greaterThanOrEqualTo(0));
        expect(got!.top, greaterThanOrEqualTo(0));
      });
    }

    testWidgets('a screen reader can zoom it', (t) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(_app(PhotoCropScreen(bytes: _clean)));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      final node = find.bySemanticsLabel(RegExp('Pinch to zoom'));
      expect(node, findsOneWidget);
      expect(t.getSemantics(node).value, '100%');
      t.semantics.increase(find.semantics.byLabel(RegExp('Pinch to zoom')));
      await t.pumpAndSettle();
      expect(t.getSemantics(node).value, '125%');
      sem.dispose();
    });
  });

  group('the sheet', () {
    Future<void> open(
      WidgetTester t, {
      required bool add,
      required bool has,
      bool faces = false,
    }) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showPhotoSheet(
                  c,
                  title: 'Your photo',
                  line: 'line',
                  seed: 'calm-orbit-river',
                  add: add,
                  has: has,
                  faces: faces,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('a photo to add, faces, and nothing to remove yet', (t) async {
      await open(t, add: true, has: false, faces: true);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Pick a face'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing);
      expect(find.text('View photo'), findsNothing);
    });

    testWidgets('with a photo, a look and the remove; no save or share', (
      t,
    ) async {
      await open(t, add: true, has: true);
      expect(find.text('View photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
      expect(find.textContaining(RegExp('Save|Share|Copy')), findsNothing);
    });
  });
}
