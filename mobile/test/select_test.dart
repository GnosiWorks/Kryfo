// SPDX-License-Identifier: GPL-3.0-or-later
// several messages picked at once: "Select" starts it, a tap picks a row
// or lets it go, back ends it first, and the bar offers copy and forward
// only when every picked one may leave the chat, with delete from this
// phone always there for what is not still going
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/select_parts.dart';

import 'source_body.dart';

void main() {
  Widget host(Widget child, {bool still = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(body: child),
    ),
  );

  for (final still in [false, true]) {
    testWidgets('a tap picks the row, never the bubble under it '
        '(still: $still)', (t) async {
      var picked = false;
      var bubble = 0;
      Widget row() => SelectRow(
        on: picked,
        onTap: () => picked = !picked,
        child: GestureDetector(
          onTap: () => bubble++,
          child: const SizedBox(height: 60, child: Text('hello')),
        ),
      );
      await t.pumpWidget(host(row(), still: still));
      await t.tap(find.text('hello'), warnIfMissed: false);
      await t.pumpWidget(host(row(), still: still));
      await t.pump(const Duration(milliseconds: 250));
      expect(picked, isTrue);
      expect(bubble, 0);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await t.tap(find.text('hello'), warnIfMissed: false);
      await t.pumpWidget(host(row(), still: still));
      await t.pump(const Duration(milliseconds: 250));
      expect(picked, isFalse);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  }

  testWidgets('the bar shows the count and only what all of it allows', (
    t,
  ) async {
    var closed = 0, copied = 0, gone = 0;
    await t.pumpWidget(
      host(
        SelectBar(
          count: 3,
          onClose: () => closed++,
          onCopy: () => copied++,
          onDelete: () => gone++,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.selectCount(3, '3')), findsOneWidget);
    final sem = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel(l10n.commonCopy));
    await t.tap(find.bySemanticsLabel(l10n.filesDeleteHere));
    await t.tap(find.bySemanticsLabel(l10n.selectDone));
    expect((copied, gone, closed), (1, 1, 1));
    // forward is not for all of it: it is not there to tap
    final fwd = t.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.forward_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(fwd.ignoring, isTrue);
    sem.dispose();
  });

  test('both chats start it from the menu, end it on back, and hold copy '
      'and forward to the leave rules', () {
    for (final file in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = sourceOf(file);
      expect(src, contains('label: l10n.selectStart,'), reason: file);
      expect(src, contains('canPop: !_escHolds && !_selecting,'), reason: file);
      final leaves = bodyOf(src, 'bool _leaves(');
      expect(leaves, contains('mayLeave('), reason: file);
      expect(leaves, contains('blocking: _shots.blocking'), reason: file);
      expect(leaves, contains('spoiler: x.spoiler'), reason: file);
      expect(leaves, contains('session.isHidden('), reason: file);
      final bar = bodyOf(src, 'Widget _selectBar(');
      expect(bar, contains('rows.every(_leaves)'), reason: file);
    }
    expect(
      bodyOf(sourceOf('lib/screens/group_chat_screen.dart'), 'bool _leaves('),
      contains('room: _isRoom'),
    );
  });
}
