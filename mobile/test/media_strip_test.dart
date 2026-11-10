// SPDX-License-Identifier: GPL-3.0-or-later
// the sending strip above the composer: its words change as the send goes,
// one line or two, and its Cancel stays where the finger is going (phone
// check 2026-11-10, F6)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_progress.dart';

void main() {
  tearDown(() {
    mediaProgressEnd('u1');
    stopMediaSweeper();
  });

  testWidgets('Cancel sending keeps its place and size as the words wrap', (
    t,
  ) async {
    t.view.physicalSize = const Size(260, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var cancels = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: IncomingMediaBanner(
              chatKey: 'c',
              onCancel: (_) => cancels++,
            ),
          ),
        ),
      ),
    );
    mediaProgressStart('u1', chatKey: 'c', bytes: 33869000);
    mediaProgressUpdate('u1', 0.27);
    mediaPreparingSet('u1', true);
    await t.pumpAndSettle();
    final cancel = find.text(l10n.commonCancel);
    final strip = find.byType(IncomingMediaBanner);
    final short = t.getRect(cancel);
    final shortStrip = t.getRect(strip);
    // the longer line wraps at this width
    mediaPreparingSet('u1', false);
    mediaProgressUpdate('u1', 0.28);
    await t.pumpAndSettle();
    expect(
      find.textContaining(l10n.transferSending('').trim()),
      findsOneWidget,
    );
    expect(t.getRect(cancel), short);
    expect(t.getRect(strip), shortStrip);
    // a target a finger finds
    final target = t.getSize(
      find.ancestor(of: cancel, matching: find.byType(GestureDetector)).first,
    );
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(32));
    await t.tap(cancel);
    expect(cancels, 1);
  });
}
