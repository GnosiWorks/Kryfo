// SPDX-License-Identifier: GPL-3.0-or-later
// the fifth samsung round: no outlines on file tiles, the strip in a share,
// a photo among files is a row like the rest, the pdf strip and its turns
// never draw blank, and the bubble's pill is there as the page shrinks
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/pdf_pages.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/file_badge.dart';
import 'package:kryfo/widgets/swap.dart';

import 'source_body.dart';

Widget _frame(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() {
    mediaProgressEnd('s1');
    stopMediaSweeper();
  });

  testWidgets('a file tile has no outline, only a faint wash', (t) async {
    for (final onAccent in [false, true]) {
      await t.pumpWidget(
        _frame(
          FileBadge(
            facts: const FileFacts(FileKind.pdf, 'pdf'),
            onAccent: onAccent,
          ),
        ),
      );
      final box = t.widget<Container>(
        find.descendant(
          of: find.byType(FileBadge),
          matching: find.byType(Container),
        ),
      );
      final d = box.decoration! as BoxDecoration;
      expect(d.border, isNull);
      expect(d.color, isNotNull);
      expect(d.color!.a, lessThan(0.2));
    }
  });

  testWidgets('the strip says how far in a share, never bytes of bytes', (
    t,
  ) async {
    mediaProgressStart('s1', chatKey: 'chat', bytes: 131 * 1024);
    mediaProgressUpdate('s1', 0.97);
    await t.pumpWidget(_frame(const IncomingMediaBanner(chatKey: 'chat')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Sending · 97%'), findsOneWidget);
    expect(find.textContaining('KB'), findsNothing);
    mediaProgressEnd('s1');
    await t.pumpAndSettle();
  });

  test('a photo among files is a file row: ring, tick and tile', () {
    final bubbles = sourceOf('lib/widgets/media_bubbles.dart');
    expect(bubbles, contains('drawn == FileShape.picture && !queued'));
    final card = sourceOf('lib/widgets/file_bubble.dart');
    expect(card, contains('widget.queued && facts.kind == FileKind.picture'));
    // ours is made ready at the size the row draws it: sharp at once
    expect(card, contains('mediaImage(path, setPicturePx(context))'));
    // one tree sending or not: the glance is never drawn again
    expect(card, contains('if (uid == null) return _card(context, null);'));
    expect(card, contains('kDocGlanceLines'));
  });

  testWidgets('small pdf pages are kept for the strip and go at the lock', (
    t,
  ) async {
    final img = await t.runAsync(() => createTestImage(width: 8, height: 11));
    keepPdfThumb('/m/a.pdf', 2, img!);
    expect(pdfThumbNow('/m/a.pdf', 2), isNotNull);
    expect(pdfThumbNow('/m/a.pdf', 1), isNull);
    forgetPdfPreviews();
    expect(pdfThumbNow('/m/a.pdf', 2), isNull);
    img.dispose();
  });

  test('a turn draws the next page beside this one; the close shows the '
      "bubble's pill", () {
    final viewer = sourceOf('lib/widgets/pdf_viewer.dart');
    expect(viewer, contains('final n = _incoming ?? _neighbourFor(x);'));
    expect(viewer, contains('for (final i in [_page - 1, _page + 1])'));
    expect(viewer, contains('opacity: _pill && !_closing ? 1 : 0,'));
    expect(viewer, contains('closingMark: pages == null'));
    expect(
      sourceOf('lib/widgets/file_viewer_parts.dart'),
      contains('animation.status == AnimationStatus.reverse'),
    );
  });

  testWidgets('held at its last share, the strip says finishing after a '
      'moment', (t) async {
    mediaProgressStart('s1', chatKey: 'chat', bytes: 4096);
    mediaProgressUpdate('s1', 0.97);
    await t.pumpWidget(_frame(const IncomingMediaBanner(chatKey: 'chat')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Sending · 97%'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.mediaProgressFinishing), findsOneWidget);
    mediaProgressEnd('s1');
    await t.pumpAndSettle();
  });

  testWidgets('waiting gives way to its size with no frame showing both', (
    t,
  ) async {
    Widget line(String s) =>
        _frame(OutInSwap(child: Text(s, key: ValueKey(s))));
    await t.pumpWidget(line('Waiting to send'));
    await t.pumpWidget(line('4 KB'));
    for (var ms = 0; ms <= 260; ms += 10) {
      final both = <double>[
        for (final s in ['Waiting to send', '4 KB'])
          if (find.text(s).evaluate().isNotEmpty)
            t
                .widget<FadeTransition>(
                  find
                      .ancestor(
                        of: find.text(s),
                        matching: find.byType(FadeTransition),
                      )
                      .first,
                )
                .opacity
                .value,
      ];
      expect(both.where((o) => o > 0).length, lessThanOrEqualTo(1));
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Waiting to send'), findsNothing);
    expect(find.text('4 KB'), findsOneWidget);
  });

  test('every empty strip tile takes the bubble\'s page', () {
    expect(
      sourceOf('lib/widgets/pdf_viewer.dart'),
      contains(
        '''        // the bubble's page stands in for any not drawn yet: never empty
        pdfGlanceNow(widget.path)?.image;''',
      ),
    );
  });
}
