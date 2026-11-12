// SPDX-License-Identifier: GPL-3.0-or-later
// files in a chat pixel for pixel: a pdf with its first page, a zip on its
// way, a sound file, a code file with its first lines and one still to
// get. dark, light, right to left and at twice the text size
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/pdf_pages.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/transfers.dart';
import 'package:kryfo/widgets/file_actions.dart';
import 'package:kryfo/widgets/file_bubble.dart';
import 'package:kryfo/widgets/preview_bleed.dart';
import 'package:kryfo/zip_glance.dart';
import 'package:kryfo/widgets/file_stack.dart';
import 'package:kryfo/widgets/file_wait.dart';
import 'package:kryfo/widgets/sound_views.dart';

import 'narrow_settings.dart' show loadAppFonts;

class _Paper implements PdfBackend {
  @override
  Future<Map<Object?, Object?>?> open(
    String path, {
    bool first = false,
  }) async => {
    'id': 1,
    'pages': 12,
    'sizes': [
      for (var i = 0; i < 12; i++) ...[612, 792],
    ],
    'find': false,
  };

  @override
  Future<({int w, int h, Uint8List rgba})?> render(
    int id,
    int page,
    int width,
  ) async {
    final h = (width * 792 / 612).round();
    final b = Uint8List(width * h * 4)..fillRange(0, width * h * 4, 255);
    // a heading and some lines of ink
    for (final (y0, y1, x1) in [
      (30, 44, 0.55),
      (70, 76, 0.9),
      (90, 96, 0.84),
      (110, 116, 0.88),
      (130, 136, 0.6),
    ]) {
      for (var y = y0; y < y1 && y < h; y++) {
        for (var x = 30; x < width * x1; x++) {
          final i = (y * width + x) * 4;
          b[i] = b[i + 1] = b[i + 2] = 60;
        }
      }
    }
    return (w: width, h: h, rgba: b);
  }

  @override
  Future<List<int>> find(int id, String words) async => const [];

  @override
  Future<void> close(int id) async {}
}

void main() {
  setUpAll(loadAppFonts);
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('files_golden'));
  tearDown(() {
    resetPdfGlancesForTest();
    tmp.deleteSync(recursive: true);
    pdfBackendForTest = null;
    pdfViewHereForTest = null;
    audioViewHereForTest = null;
    forgetPdfPreviews();
    fileWaits.value = const {};
  });

  for (final (name, light, locale, scale) in [
    ('dark', false, const Locale('en'), 1.0),
    ('light', true, const Locale('en'), 1.0),
    ('rtl', false, const Locale('ar'), 1.0),
    ('large', false, const Locale('en'), 2.0),
  ]) {
    testWidgets('files in a chat, $name', (t) async {
      t.view.physicalSize = Size(390, scale > 1 ? 1500 : 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      addTearDown(() => HaloColors.setLight(false));
      pdfBackendForTest = _Paper();
      pdfViewHereForTest = true;
      audioViewHereForTest = true;
      final pdf = File('${tmp.path}/in_a.pdf')
        ..writeAsBytesSync(
          List.filled(2400 * 1024, 1)..setAll(0, '%PDF-1.7\n'.codeUnits),
        );
      final zipped = Archive();
      for (final (n, body) in [
        ('route-day1.gpx', 'x' * 2000),
        ('photos/ridge.jpg', 'a' * 9000),
        ('photos/lake.jpg', 'b' * 7000),
        ('photos/camp.jpg', 'c' * 8000),
        ('packing list.txt', 'tent'),
        ('maps/north.pdf', 'p' * 4000),
        ('notes.md', 'n'),
      ]) {
        zipped.addFile(ArchiveFile.string(n, body));
      }
      final zip = File('${tmp.path}/out_b.zip')
        ..writeAsBytesSync(ZipEncoder().encode(zipped));
      final m4a = File('${tmp.path}/in_c.m4a')
        ..writeAsBytesSync(List.filled(3100 * 1024, 0));
      final py = File('${tmp.path}/out_d.py')
        ..writeAsStringSync(
          'def rent_share(total, people):\n    return round(total / people, 2)\n',
        );
      mediaProgressStart('up', bytes: 38 << 20);
      mediaProgressUpdate('up', 0.64);
      addTearDown(() => mediaProgressEnd('up'));
      fileWaits.value = {
        'z': const FileWait(
          size: 48 << 20,
          state: WaitState.asks,
          rule: AutoGet.never,
          glance: ZipGlance(
            count: 41,
            unpacked: 61 << 20,
            locked: true,
            top: [
              ZipTop('photos', 12),
              ZipTop('trip-plan.pdf', -1),
              ZipTop('maps', 6),
              ZipTop('budget.xlsx', -1),
            ],
          ),
        ),
        'w': const FileWait(
          size: 220 * 1024,
          state: WaitState.asks,
          rule: AutoGet.never,
        ),
      };
      Widget bubble(bool out, Widget child) => Align(
        alignment: out
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          // as the chat draws a file: previews out to the bubble's edges,
          // its fill and padding inside the clip
          clipBehavior: Clip.antiAlias,
          child: BubbleWidth(
            file: true,
            top: true,
            side: 14,
            above: 10,
            ground: out ? HaloColors.amber : HaloColors.bubbleIn,
            pad: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: child,
          ),
        ),
      );
      // its first page drawn before the frame, so every run draws it alike
      await t.runAsync(() => pdfGlance(pdf.path, 236));
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildHaloTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: HaloColors.ink,
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                bubble(
                  false,
                  FileCard(
                    path: pdf.path,
                    name: 'Lease-draft.pdf',
                    isOut: false,
                    glance: true,
                  ),
                ),
                bubble(
                  true,
                  FileCard(
                    path: zip.path,
                    name: 'photos-march.zip',
                    isOut: true,
                    sendingUid: 'up',
                    onCancel: () {},
                  ),
                ),
                bubble(
                  false,
                  SoundFileBubble(
                    path: m4a.path,
                    name: 'Rain on the balcony.m4a',
                    isOut: false,
                  ),
                ),
                bubble(
                  true,
                  FileCard(path: py.path, name: 'rent.py', isOut: true),
                ),
                bubble(
                  false,
                  FileWaitOr(
                    uid: 'z',
                    fileName: 'Trip-2027.zip',
                    onGet: (_) {},
                    onPause: (_) {},
                    child: () => const SizedBox.shrink(),
                  ),
                ),
                bubble(
                  false,
                  WaitingFileCard(
                    uid: 'w',
                    fileName: 'Notes-from-meeting.docx',
                    wait: fileWaits.value['w']!,
                    onGet: () {},
                    onPause: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 120; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/files_bubbles_$name.png'),
      );
    });
  }

  // several files in one bubble: a pdf with its first page, one coming,
  // one still to get with "Get all"; ours with a code file and one that
  // did not go
  for (final (name, light, locale, scale) in [
    ('dark', false, const Locale('en'), 1.0),
    ('light', true, const Locale('en'), 1.0),
    ('rtl', false, const Locale('ar'), 1.0),
    ('large', false, const Locale('en'), 2.0),
  ]) {
    testWidgets('several files in one bubble, $name', (t) async {
      t.view.physicalSize = Size(390, scale > 1 ? 1700 : 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      addTearDown(() => HaloColors.setLight(false));
      pdfBackendForTest = _Paper();
      pdfViewHereForTest = true;
      final pdf = File('${tmp.path}/in_a.pdf')
        ..writeAsBytesSync(
          List.filled(2400 * 1024, 1)..setAll(0, '%PDF-1.7\n'.codeUnits),
        );
      final py = File('${tmp.path}/out_d.py')
        ..writeAsStringSync(
          'def rent_share(total, people):\n    return round(total / people, 2)\n',
        );
      fileWaits.value = {
        'maps': const FileWait(
          size: 36 << 20,
          state: WaitState.coming,
          rule: AutoGet.never,
          share: 0.64,
        ),
        'gear': const FileWait(
          size: 48 * 1024,
          state: WaitState.asks,
          rule: AutoGet.never,
        ),
      };
      Widget bubble(bool out, Widget child) => Align(
        alignment: out
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          // as the chat draws a file: previews out to the bubble's edges,
          // its fill and padding inside the clip
          clipBehavior: Clip.antiAlias,
          child: BubbleWidth(
            file: true,
            top: true,
            side: 12,
            above: 10,
            ground: out ? HaloColors.amber : HaloColors.bubbleIn,
            pad: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: child,
          ),
        ),
      );
      await t.runAsync(() => pdfGlance(pdf.path, 236));
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildHaloTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: HaloColors.ink,
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                bubble(
                  false,
                  FileStack(
                    isOut: false,
                    onGet: (_) {},
                    onPause: (_) {},
                    rows: [
                      FileStackRow(
                        id: 'a',
                        name: 'route-sat.pdf',
                        ready: () => FileCard(
                          path: pdf.path,
                          name: 'route-sat.pdf',
                          isOut: false,
                          glance: true,
                        ),
                      ),
                      FileStackRow(
                        id: 'maps',
                        name: 'offline-maps.zip',
                        waitUid: 'maps',
                        ready: () => const SizedBox.shrink(),
                      ),
                      FileStackRow(
                        id: 'gear',
                        name: 'gear-list.xlsx',
                        waitUid: 'gear',
                        until: DateTime(2026, 12, 9),
                        ready: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                bubble(
                  true,
                  FileStack(
                    isOut: true,
                    onGet: (_) {},
                    onPause: (_) {},
                    rows: [
                      FileStackRow(
                        id: 'py',
                        name: 'rent.py',
                        ready: () => FileCard(
                          path: py.path,
                          name: 'rent.py',
                          isOut: true,
                        ),
                      ),
                      FileStackRow(
                        id: 'scan',
                        name: 'permit-scan.pdf',
                        failed: true,
                        onRetry: () {},
                        ready: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 120; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/files_stack_$name.png'),
      );
    });
  }
}
