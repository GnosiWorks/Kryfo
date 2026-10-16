// SPDX-License-Identifier: GPL-3.0-or-later
// the file bubble: its kind from the bytes, the real extension always in
// view, the size, and for an app installer one plain line and a save mark.
// it shows a save under way, keeps still when the phone asks for no
// movement, reads right to left where the name does, and follows the theme
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_save.dart' show savingFiles;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/media_bubbles.dart';

import 'zip_maker.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('file_card'));
  tearDown(() {
    savingFiles.value = const {};
    HaloColors.setLight(false);
    tmp.deleteSync(recursive: true);
  });

  File made(String leaf, List<int> bytes) =>
      File('${tmp.path}/$leaf')..writeAsBytesSync(bytes);

  Future<void> show(
    WidgetTester t,
    String? path,
    String? name, {
    bool isOut = false,
    TextDirection dir = TextDirection.ltr,
    bool still = false,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Directionality(
            textDirection: dir,
            child: Scaffold(
              body: Center(
                child: FileCard(path: path, name: name, isOut: isOut),
              ),
            ),
          ),
        ),
      ),
    );
    // the bytes are read off the frame, a step at a time
    for (var i = 0; i < 60; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  testWidgets('an app installer says so in one line and offers a save', (
    t,
  ) async {
    final f = made('in_1_game.apk', [1, 2, 3]);
    final h = t.ensureSemantics();
    await show(t, f.path, 'game.apk');
    expect(find.text(l10n.fileInstallerLine), findsOneWidget);
    expect(find.text('.apk'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    final s = t.getSemantics(find.byType(FileCard));
    expect(s.label, contains(l10n.fileAppInstaller));
    expect(s.label, contains(l10n.fileInstallerLine));
    expect(s.hint, l10n.fileSaveToDevice);
    h.dispose();
  });

  testWidgets('a renamed app is shown as one once its bytes are read', (
    t,
  ) async {
    final f = made('in_2_photo.jpg', apkBytes());
    await show(t, f.path, 'photo.jpg');
    expect(find.text(l10n.fileInstallerLine), findsOneWidget);
    expect(find.textContaining('APK'), findsOneWidget);
  });

  testWidgets('a long double extension keeps the real one in view', (t) async {
    final name = '${'holiday photos from the beach ' * 4}.jpg.apk';
    final f = made('in_3_x.apk', [1]);
    await show(t, f.path, name);
    final card = t.getRect(find.byType(FileCard));
    final ext = t.getRect(find.text('.apk'));
    expect(card.contains(ext.center), isTrue);
    expect(ext.right, lessThanOrEqualTo(card.right));
  });

  testWidgets('a file of no known kind shows a plain glyph, name and size', (
    t,
  ) async {
    final f = made('in_4_notes', List.filled(2048, 7));
    final h = t.ensureSemantics();
    await show(t, f.path, 'notes');
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    expect(find.text('notes'), findsOneWidget);
    expect(
      find.text('${l10n.mediaBubblesFile} · ${humanFileSize(2048)}'),
      findsOneWidget,
    );
    expect(find.text(l10n.fileInstallerLine), findsNothing);
    final s = t.getSemantics(find.byType(FileCard));
    expect(s.hint, l10n.fileOpenHint);
    h.dispose();
  });

  testWidgets('a pdf named as a photo is labelled by what it is', (t) async {
    final f = made('in_5_scan.jpg', '%PDF-1.7\n'.codeUnits);
    await show(t, f.path, 'scan.jpg');
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.textContaining('PDF'), findsOneWidget);
  });

  testWidgets('a hidden direction mark never reaches the screen', (t) async {
    final name = 'invoice${String.fromCharCode(0x202E)}fdp.apk';
    final f = made('in_6_x.apk', [1]);
    await show(t, f.path, name);
    expect(find.text('invoicefdp'), findsOneWidget);
    expect(find.text('.apk'), findsOneWidget);
  });

  testWidgets('a save under way shows on the bubble, still when asked', (
    t,
  ) async {
    final f = made('in_7_a.apk', [1]);
    await show(t, f.path, 'a.apk', still: true);
    savingFiles.value = {f.path};
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // with no movement the mark swaps in the same frame
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    savingFiles.value = const {};
    await t.pump();
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('an arabic name reads right to left, a latin one does not', (
    t,
  ) async {
    final f = made('in_8_a.pdf', '%PDF-1.7\n'.codeUnits);
    await show(t, f.path, 'تقرير.pdf', dir: TextDirection.rtl);
    final stem = t.getRect(find.text('تقرير'));
    final ext = t.getRect(find.text('.pdf'));
    expect(ext.right, lessThanOrEqualTo(stem.left + 1));
    await show(t, f.path, 'report.pdf', dir: TextDirection.rtl);
    expect(
      t.getRect(find.text('.pdf')).left,
      greaterThanOrEqualTo(t.getRect(find.text('report')).right - 1),
    );
  });

  testWidgets('no grey text, and the colours follow a theme switch', (t) async {
    final f = made('in_9_a.apk', [1]);
    await show(t, f.path, 'a.apk');
    Color? colourOf(String s) => t.widget<Text>(find.text(s)).style?.color;
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(w.style?.color, isNot(HaloColors.text3), reason: w.data);
    }
    expect(colourOf(l10n.fileInstallerLine), HaloColors.text2);
    final dark = colourOf('a');
    HaloColors.setLight(true);
    await show(t, f.path, 'a.apk');
    expect(colourOf('a'), HaloColors.text);
    expect(colourOf('a'), isNot(dark));
  });

  testWidgets('the copy of our own reads on amber', (t) async {
    final f = made(
      'in_10_a.zip',
      zipOf({
        'a.txt': [1],
      }),
    );
    await show(t, f.path, 'a.zip', isOut: true);
    expect(t.widget<Text>(find.text('a')).style?.color, HaloColors.onAmber);
    expect(find.byIcon(Icons.folder_zip_outlined), findsOneWidget);
  });

  test('sizes read like the rest of the app', () {
    expect(humanFileSize(500), l10n.mediaBubblesB('500'));
    expect(humanFileSize(8 * 1024 * 1024), l10n.mediaBubblesMb('8.0'));
  });

  test('the card answers the intrinsic pass of a bubble: no LayoutBuilder', () {
    final src = File('lib/widgets/media_bubbles.dart').readAsStringSync();
    final card = src.substring(src.indexOf('class FileCard'));
    expect(
      card.substring(0, card.indexOf('\nclass VoiceBubble')),
      isNot(contains('LayoutBuilder')),
    );
  });

  testWidgets('the card shows the name the file is saved under', (t) async {
    final f = made('in_11_x.exe', 'MZ'.codeUnits);
    await show(t, f.path, 'photo.jpg.exe');
    expect(find.text('photo_jpg'), findsOneWidget);
    expect(find.text('.exe'), findsOneWidget);
    final g = made('in_12_c.pdf', '%PDF-1.7\n'.codeUnits);
    await show(t, g.path, 'cafe${String.fromCharCode(0x0301)}.pdf');
    expect(find.text('caf${String.fromCharCode(0xE9)}'), findsOneWidget);
  });
}
