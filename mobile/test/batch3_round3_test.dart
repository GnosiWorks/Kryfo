// SPDX-License-Identifier: GPL-3.0-or-later
// the third samsung round: a mixed pick is one bubble, the strip says
// preparing only before the first byte, a word document's glance reads like
// its reader, a pdf grows out of its bubble and turns sideways, and a
// person's page is read before it slides in
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/widgets/file_bubble.dart' show docGlanceHeight;
import 'package:kryfo/widgets/send_sheet.dart';

import 'source_body.dart';

Widget _frame(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() {
    mediaProgressEnd('s1');
    stopMediaSweeper();
  });

  test('a photo picked with files goes inside the set, spoiler and all', () {
    SendPick p(String n, {bool media = false}) => SendPick(
      path: '/x/$n',
      name: n,
      size: 1,
      from: media ? SendTab.gallery : SendTab.files,
      media: media,
    );
    final r = SendSheetResult(
      [p('a.pdf'), p('1000123.jpg', media: true), p('c.docx')],
      spoilers: {'/x/1000123.jpg'},
    );
    expect(r.runs.single.media, isFalse);
    expect(r.runs.single.picks, hasLength(3));
    for (final file in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final body = bodyOf(sourceOf(file), 'Future<void> _sendFromSheet(');
      // a gallery photo never leaves under the gallery's own name
      expect(body, contains('f.media && f.from == SendTab.gallery'));
      expect(body, contains('spoilers: r.spoilers'));
      expect(sourceOf(file), contains('spoiler: ready.spoiler'));
      expect(sourceOf(file), contains('spoiler: x.spoiler,'));
    }
    expect(
      sourceOf('lib/widgets/file_stack.dart'),
      contains('child: r.spoiler'),
    );
  });

  testWidgets('the strip: preparing before the first byte, then sending, '
      'never "keep the app open" on its own', (t) async {
    mediaProgressStart('s1', chatKey: 'chat', bytes: 1 << 20);
    await t.pumpWidget(_frame(const IncomingMediaBanner(chatKey: 'chat')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.mediaProgressPreparingNow), findsOneWidget);
    mediaProgressUpdate('s1', 0.42);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.mediaProgressPreparingNow), findsNothing);
    expect(find.textContaining(l10n.transferSending('')), findsOneWidget);
    expect(find.textContaining('keep the app open'), findsNothing);
    mediaProgressEnd('s1');
    await t.pumpAndSettle();
  });

  test('a word document glance keeps about four lines of room', () {
    expect(docGlanceHeight(TextScaler.noScaling), closeTo(82.8, 0.1));
    expect(
      docGlanceHeight(const TextScaler.linear(1.4)),
      greaterThan(docGlanceHeight(TextScaler.noScaling)),
    );
    final bubble = sourceOf('lib/widgets/file_bubble.dart');
    expect(bubble, contains('(text: b.text.trim(), head: b.heading > 0)'));
    // our own pdf's page is there from the first frame: no paper, no fade
    expect(bubble, contains('_hadIt = _image != null;'));
  });

  test('a pdf grows out of its bubble and back, turns sideways, and once '
      'sharp never goes soft', () {
    final viewer = sourceOf('lib/widgets/pdf_viewer.dart');
    expect(
      viewer,
      contains('shownAt: (tapped) => pdfGlanceRect(path, tapped)'),
    );
    expect(viewer, contains('key: i == 0 ? widget.landing : null'));
    expect(viewer, contains('_turnTo(to, vx < 0 ? -1 : 1);'));
    expect(viewer, contains('for (var s = 3; s >= 1; s--)'));
    expect(
      sourceOf('lib/widgets/file_viewer_parts.dart'),
      contains('class _RenderLanding extends RenderProxyBox'),
    );
  });

  test("a person's page is read before it slides in", () {
    final chat = bodyOf(
      sourceOf('lib/screens/chat_screen.dart'),
      'Future<void> _openContact(',
    );
    expect(chat, contains('await warmContactInfo(widget.peerHaloId);'));
    expect(
      sourceOf('lib/screens/contact_screen.dart'),
      contains('final warm = _infoWarm.remove(widget.haloId);'),
    );
  });
}
