// SPDX-License-Identifier: GPL-3.0-or-later
// only the newest of ours spells Delivered, every one says it to a screen
// reader. a group run ends where the next sender, day or minute does
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/group_chat_screen.dart' show endsSenderRun;
import 'package:kryfo/widgets/chat_parts.dart';
import 'package:kryfo/widgets/tick_mark.dart';

void main() {
  group('delivered word', () {
    Widget tick({required bool delivered, required bool word}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SentTick(
            delivered: delivered,
            deliveredLabel: 'Delivered',
            word: word,
            color: Colors.black,
            labelStyle: const TextStyle(fontSize: 9),
          ),
        ),
      ),
    );

    testWidgets('only the newest spells it; older ones keep the tick', (
      t,
    ) async {
      await t.pumpWidget(tick(delivered: true, word: true));
      expect(find.text('Delivered'), findsOneWidget);
      // a newer one was delivered: the word folds back into the tick
      await t.pumpWidget(tick(delivered: true, word: false));
      await t.pumpAndSettle();
      expect(find.text('Delivered'), findsNothing);
      expect(find.byType(TickMark), findsOneWidget);
    });

    testWidgets('a screen reader hears Delivered on every one, once', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(tick(delivered: true, word: false));
      expect(find.bySemanticsLabel('Delivered'), findsOneWidget);
      await t.pumpWidget(tick(delivered: true, word: true));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Delivered'), findsOneWidget);
      sem.dispose();
    });
  });

  group('group runs', () {
    final at = DateTime(2026, 11, 11, 12);
    test('the same sender within two minutes goes on', () {
      expect(
        endsSenderRun(
          sender: 'a',
          out: false,
          when: at,
          next: (
            sender: 'a',
            out: false,
            when: at.add(const Duration(seconds: 60)),
          ),
        ),
        isFalse,
      );
    });
    test('another sender, ours, a gap or a new day ends it', () {
      bool ends(({String sender, bool out, DateTime when})? n) =>
          endsSenderRun(sender: 'a', out: false, when: at, next: n);
      expect(ends(null), isTrue);
      expect(ends((sender: 'b', out: false, when: at)), isTrue);
      expect(ends((sender: 'me', out: true, when: at)), isTrue);
      expect(
        ends((
          sender: 'a',
          out: false,
          when: at.add(const Duration(minutes: 3)),
        )),
        isTrue,
      );
      expect(
        ends((sender: 'a', out: false, when: DateTime(2026, 11, 12, 0, 0, 30))),
        isTrue,
      );
    });
    test('ours run on whoever this phone is', () {
      expect(
        endsSenderRun(
          sender: 'x',
          out: true,
          when: at,
          next: (sender: 'y', out: true, when: at),
        ),
        isFalse,
      );
    });
  });
}
