// SPDX-License-Identifier: GPL-3.0-or-later
// the viewers pixel for pixel: a code file, a pdf and the sound player, in
// the dark theme, the light one and right to left
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/pdf_pages.dart';
import 'package:kryfo/sound_player.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/pdf_viewer.dart';
import 'package:kryfo/widgets/sound_views.dart';
import 'package:kryfo/widgets/text_viewer.dart';

import 'narrow_settings.dart' show loadAppFonts;

class _Paper implements PdfBackend {
  @override
  Future<Map<Object?, Object?>?> open(
    String path, {
    bool first = false,
  }) async => {
    'id': 1,
    'pages': 6,
    'sizes': [
      for (var i = 0; i < 6; i++) ...[612, 792],
    ],
    'find': true,
  };

  @override
  Future<({int w, int h, Uint8List rgba})?> render(
    int id,
    int page,
    int width,
  ) async {
    final h = (width * 792 / 612).round();
    final b = Uint8List(width * h * 4)..fillRange(0, width * h * 4, 255);
    for (var y = (h * 0.08).round(); y < h * 0.1; y++) {
      for (var x = (width * 0.1).round(); x < width * 0.6; x++) {
        final i = (y * width + x) * 4;
        b[i] = b[i + 1] = b[i + 2] = 50;
      }
    }
    return (w: width, h: h, rgba: b);
  }

  @override
  Future<List<int>> find(int id, String words) async => const [];
  @override
  Future<void> close(int id) async {}
}

class _Still implements SoundEngine {
  @override
  Future<Duration?> load(String path) async => const Duration(seconds: 102);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> setSpeed(double s) async {}
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<bool> get playings => const Stream.empty();
  @override
  Stream<void> get ends => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(loadAppFonts);
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('viewers_golden'));
  tearDown(() async {
    resetPdfGlancesForTest();
    pdfBackendForTest = null;
    await SoundPlayer.instance.resetForTest();
    tmp.deleteSync(recursive: true);
  });

  Future<void> shoot(
    WidgetTester t,
    String name,
    bool light,
    Locale locale,
    Widget page,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    HaloColors.setLight(light);
    setL10nLocale(locale);
    addTearDown(() => setL10nLocale(const Locale('en')));
    addTearDown(() => HaloColors.setLight(false));
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildHaloTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Material(child: page),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/files_$name.png'),
    );
  }

  for (final (v, light, locale) in [
    ('dark', false, const Locale('en')),
    ('light', true, const Locale('en')),
    ('rtl', false, const Locale('fa')),
  ]) {
    testWidgets('code file, $v', (t) async {
      final f = File('${tmp.path}/in_a.py')
        ..writeAsStringSync(
          'def rent_share(total, people):\n    """split the rent"""\n    return round(total / people, 2)\n\n\nprint(rent_share(1240, 3))\n',
        );
      await shoot(
        t,
        'text_$v',
        light,
        locale,
        TextViewer(
          path: f.path,
          name: 'rent.py',
          facts: const FileFacts(FileKind.other, 'py'),
          from: 'Lena',
        ),
      );
    });

    testWidgets('pdf, $v', (t) async {
      pdfBackendForTest = _Paper();
      final f = File('${tmp.path}/in_b.pdf')..writeAsStringSync('%PDF-1.7\n');
      await shoot(
        t,
        'pdf_$v',
        light,
        locale,
        PdfViewer(
          path: f.path,
          name: 'Lease-draft.pdf',
          facts: const FileFacts(FileKind.pdf, 'pdf'),
          from: 'Lena',
          size: 2400 * 1024,
        ),
      );
    });

    testWidgets('sound player, $v', (t) async {
      SoundPlayer.engineMaker = _Still.new;
      SoundPlayer.guard = LockGuard(isLocked: () => false);
      addTearDown(() => SoundPlayer.guard = lockGuard);
      final a = File('${tmp.path}/in_c.m4a')
        ..writeAsBytesSync(List.filled(3100 * 1024, 0));
      final b = File('${tmp.path}/in_d.ogg')..writeAsBytesSync([0]);
      await t.runAsync(
        () => SoundPlayer.instance.play(
          SoundItem(
            a.path,
            name: 'Rain on the balcony.m4a',
            from: 'Lena',
            when: DateTime(2026, 11, 9, 14, 5),
          ),
          next: [SoundItem(b.path, voice: true, from: 'Lena')],
        ),
      );
      await shoot(t, 'sound_$v', light, locale, const SoundPlayerScreen());
    });
  }
}
