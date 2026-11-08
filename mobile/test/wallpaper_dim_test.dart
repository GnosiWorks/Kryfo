// SPDX-License-Identifier: GPL-3.0-or-later
// the dim slider in the wallpaper picker: there in the dark theme while a
// photo is picked, gone in the light theme and over a built-in. it moves
// the veil behind the sheet live, Keep it keeps it for the identity, and
// backing out leaves the one there was. the picker pixel for pixel in both
// themes
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/screens/wallpaper_sheet.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/wallpaper.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'narrow_settings.dart' show loadAppFonts;

class _Rows extends HaloDb {
  _Rows(this.mem) : super(HaloContainer.everyday);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

// a bright sky over a pale beach: what made the old veil gloomy
Future<Uint8List> _sky() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const r = Rect.fromLTWH(0, 0, 64, 64);
  c.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
        Color(0xFF8FD3FF),
        Color(0xFFFFF1C9),
      ]),
  );
  final img = await rec.endRecording().toImage(64, 64);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

void main() {
  late _Rows db;
  late Uint8List sky;
  Object? picked;

  setUpAll(loadAppFonts);
  setUp(() {
    db = _Rows(MemDb());
    useDatabasesForTest(db, Session(db));
    picked = null;
  });
  tearDown(() {
    HaloColors.setLight(false);
    wallDimPreview.value = null;
  });

  Future<void> open(
    WidgetTester t, {
    bool light = false,
    bool photo = true,
  }) async {
    HaloColors.setLight(light);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    setL10nLocale(const Locale('en'));
    sky = (await t.runAsync(_sky))!;
    await t.pumpWidget(
      _app(
        Builder(
          builder: (ctx) => Scaffold(
            backgroundColor: HaloColors.ink,
            body: Center(
              child: TextButton(
                onPressed: () async {
                  picked = await showWallpaperSheet(
                    ctx,
                    Atmo.none,
                    allowPhoto: true,
                    hasPhoto: photo,
                    photo: photo ? sky : null,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // the photo's samples and the stored dim are read off the frame
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
  }

  testWidgets('dark theme with a photo: the slider is there, at the photo\'s '
      'automatic veil, never past the cap', (t) async {
    await open(t);
    expect(find.text(l10n.wallpaperDim), findsOneWidget);
    final s = t.widget<Slider>(find.byType(Slider));
    expect(s.value, lessThanOrEqualTo(kDimDefault));
    expect(s.value, greaterThanOrEqualTo(0.4));
    expect(s.max, kDimMost);
  });

  testWidgets('light theme: no slider', (t) async {
    await open(t, light: true);
    expect(find.text(l10n.wallpaperDim), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('a built-in in use: no slider', (t) async {
    await open(t, photo: false);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('a move previews live and Keep it keeps it for the identity', (
    t,
  ) async {
    await open(t);
    final slider = find.byType(Slider);
    // the start of the track: the bare photo
    await t.tapAt(t.getTopLeft(slider) + const Offset(26, 24));
    await t.pump();
    expect(wallDimPreview.value, isNotNull);
    expect(wallDimPreview.value, lessThan(0.1));
    expect(knownWallDim(), isNull);
    await t.tap(find.text(l10n.wallpaperKeepIt));
    await t.pumpAndSettle();
    expect(knownWallDim(), lessThan(0.1));
    expect(wallDimPreview.value, isNull);
    final kept = await t.runAsync(() => db.wallDim());
    expect(kept, lessThan(0.1));
    // nothing else changed: the photo stays in use
    expect(picked, isNull);
  });

  testWidgets('backing out keeps the dim there was', (t) async {
    await open(t);
    await t.tapAt(t.getTopLeft(find.byType(Slider)) + const Offset(26, 24));
    await t.pump();
    expect(wallDimPreview.value, isNotNull);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pumpAndSettle();
    expect(wallDimPreview.value, isNull);
    expect(await t.runAsync(() => db.wallDim()), isNull);
  });

  testWidgets('a kept dim is what the slider shows next time', (t) async {
    await t.runAsync(() => db.setWallDim(0.3));
    await open(t);
    expect(t.widget<Slider>(find.byType(Slider)).value, closeTo(0.3, 1e-9));
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets('each identity keeps its own: the decoy reads its own dim, '
      'never the one set before it opened', (t) async {
    final real = db;
    await t.runAsync(() => keepWallDim(0.2));
    expect(knownWallDim(), 0.2);
    final decoy = _Rows(MemDb());
    useDatabasesForTest(decoy, Session(decoy));
    expect(knownWallDim(), isNull);
    expect(await t.runAsync(readWallDim), isNull);
    await t.runAsync(() => keepWallDim(0.7));
    expect(await t.runAsync(() => decoy.wallDim()), closeTo(0.7, 1e-9));
    expect(await t.runAsync(() => real.wallDim()), closeTo(0.2, 1e-9));
    useDatabasesForTest(real, Session(real));
    expect(await t.runAsync(readWallDim), closeTo(0.2, 1e-9));
  });

  for (final light in [false, true]) {
    final name = light ? 'light' : 'dark';
    testWidgets('the picker over a photo, $name', (t) async {
      await open(t, light: light);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/wallpaper_dim_$name.png'),
      );
    });
  }
}
