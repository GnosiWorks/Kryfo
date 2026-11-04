// SPDX-License-Identifier: GPL-3.0-or-later
// joining with an eight digit code: the field shows NN NNN NNN as typed,
// six digits say both phones need 0.6 and reach nothing, nothing is added
// until the code matched and the person taps Add, not them adds nothing,
// every end is said in the person's language, the card springs in under
// 300 ms or shows at once with reduced motion, and digits and words stay
// left to right in a right-to-left language. the engine and the app are
// stand-in hooks
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/pair_flow.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/pair_join.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _words = 'thumb-behave-boring';

class _Pair {
  _Pair(this.steps, {this.joinSays = 'ok 4', this.adds = ('', true)});
  final (String, bool) adds;
  // one per round, the last one repeating
  final List<String> steps;
  final String joinSays;
  final joined = <String>[];
  final calls = <String>[];
  final done = <String>[];

  PairRun run() => PairRun.join(
    PairHooks(
      invite: () async => PairMine(Uint8List.fromList([9])),
      share: (_) async => 'error: none',
      join: (code, _) async {
        joined.add(code);
        return joinSays;
      },
      step: (_) async => steps.length > 1 ? steps.removeAt(0) : steps.single,
      close: (h) async => calls.add('close'),
      read: (kin4) async => PairPeer(link: 'kryfo://share?v=4&i=x', id: _words),
      hold: (_, _) async => calls.add('hold'),
      add: (p, m, {required sharer}) async {
        calls.add('add');
        return adds;
      },
      drop: (_) async => calls.add('drop'),
    ),
    gap: const Duration(seconds: 1),
  );

  Widget widget() => Scaffold(
    key: ObjectKey(this),
    body: PairJoin(run: run, onAdded: done.add),
  );
}

String _done() => 'done ${base64Encode(utf8.encode('their-invite'))}';

Future<void> _type(WidgetTester t, String code) async {
  await t.enterText(find.byType(TextField), code);
  await t.tap(find.text(l10n.pairCodeAddThem));
}

Future<void> _rounds(WidgetTester t, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

// how far the card has grown and faded in
double _scale(WidgetTester t) => t
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byType(PairMatched),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  setUp(() => pairNow = () => TestWidgetsFlutterBinding.instance.clock.now());

  testWidgets('the field shows the code in its groups as it is typed', (
    t,
  ) async {
    phone(t);
    final p = _Pair(['look']);
    await t.pumpWidget(app(p.widget()));
    await t.enterText(find.byType(TextField), '07123456');
    await t.pump();
    expect(find.text('07 123 456'), findsOneWidget);
    await t.enterText(find.byType(TextField), '۰۷۱۲۳');
    await t.pump();
    expect(find.text('07 123'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('six digits are an older Kryfo\'s code: said, and nothing is '
      'made or sent', (t) async {
    phone(t);
    final p = _Pair(['look']);
    await t.pumpWidget(app(p.widget()));
    await _type(t, '482913');
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeOldCodeShown), findsOneWidget);
    expect(l10n.pairCodeOldCode, contains('0.6'));
    expect(p.joined, isEmpty);
    expect(p.calls, isEmpty);
    // a short one asks for eight
    await _type(t, '0712345');
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeEightDigits), findsOneWidget);
    expect(p.joined, isEmpty);
  });

  testWidgets('the code matched: their name and the add, and nothing added '
      'before Add', (t) async {
    phone(t);
    final p = _Pair(['look', 'wait 0', _done()]);
    await t.pumpWidget(app(p.widget()));
    await _type(t, '07 123 456');
    await t.pump();
    expect(p.joined, ['07123456']);
    expect(find.text(l10n.pairCodeLooking), findsWidgets);
    await _rounds(t);
    await t.pumpAndSettle();
    expect(find.byType(PairMatched), findsOneWidget);
    expect(find.text(_words), findsOneWidget);
    expect(find.text(l10n.pairCodeMatched), findsOneWidget);
    expect(p.calls, isNot(contains('add')));
    await t.tap(find.text(l10n.commonAdd));
    await t.pumpAndSettle();
    expect(p.calls, containsAllInOrder(['add', 'drop']));
    expect(p.done, ['']);
  });

  testWidgets('not them adds nothing, and the field comes back', (t) async {
    phone(t);
    final p = _Pair([_done()]);
    await t.pumpWidget(app(p.widget()));
    await _type(t, '07123456');
    await _rounds(t, 2);
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodeNotThem));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeNotAdded), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(p.calls, isNot(contains('add')));
    expect(p.calls, contains('drop'));
  });

  testWidgets('every end is said in the person\'s words, in the warning '
      'colour, never in the engine\'s', (t) async {
    phone(t);
    for (final (says, line) in [
      ('error: tries', l10n.pairCodeTooManyTries),
      ('error: unanswered', l10n.pairCodeUnanswered),
      ('error: expired', l10n.pairCodeRanOut),
      ('error: gone', l10n.pairCodeFailed),
    ]) {
      final p = _Pair([says]);
      await t.pumpWidget(app(p.widget()));
      await _type(t, '07123456');
      await _rounds(t, 2);
      await t.pumpAndSettle();
      final f = find.text(line);
      expect(f, findsOneWidget, reason: says);
      expect(t.widget<Text>(f).style?.color, HaloColors.roseText);
      expect(find.textContaining('error'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    }
  });

  testWidgets('a code that used its tries is said at once', (t) async {
    phone(t);
    final p = _Pair(['look'], joinSays: 'error: tries');
    await t.pumpWidget(app(p.widget()));
    await _type(t, '07123456');
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeTooManyTries), findsOneWidget);
    expect(p.calls, contains('drop'));
  });

  testWidgets('waiting long is told what to check', (t) async {
    phone(t);
    final p = _Pair(['wait 0']);
    await t.pumpWidget(app(p.widget()));
    await _type(t, '07123456');
    await _rounds(t, 2);
    expect(find.text(l10n.pairCodeWaitingForThem), findsOneWidget);
    await t.pump(kPairStillAfter);
    await _rounds(t, 2);
    expect(find.text(l10n.pairCodeStillWaiting), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    expect(p.calls, containsAll(['close', 'drop']));
  });

  testWidgets('the card springs in and settles within 300 ms', (t) async {
    phone(t);
    final p = _Pair([_done()]);
    await t.pumpWidget(app(p.widget()));
    await _type(t, '07123456');
    for (
      var i = 0;
      i < 10 && find.byType(PairMatched).evaluate().isEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(PairMatched), findsOneWidget);
    await t.pump(const Duration(milliseconds: 40));
    final mid = _scale(t);
    expect(mid, greaterThan(0.94));
    expect(mid, lessThan(1));
    await t.pump(const Duration(milliseconds: 260));
    expect(_scale(t), closeTo(1, 0.005));
    await t.pumpAndSettle();
  });

  testWidgets('reduced motion: the card and a line show at once', (t) async {
    phone(t);
    final p = _Pair([_done()]);
    await t.pumpWidget(app(p.widget(), still: true));
    await _type(t, '07123456');
    for (
      var i = 0;
      i < 10 && find.byType(PairMatched).evaluate().isEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(_scale(t), 1);
    final face = find.ancestor(
      of: find.byType(KryfoAvatar),
      matching: find.byType(Transform),
    );
    expect(t.widget<Transform>(face.first).transform.storage[0], 1);
    final q = _Pair(['look']);
    await t.pumpWidget(app(q.widget(), still: true));
    await _type(t, '482913');
    await t.pump();
    expect(find.text(l10n.pairCodeOldCodeShown), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('right to left: the card mirrors, the words and the field do '
      'not', (t) async {
    phone(t);
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    final p = _Pair([_done()]);
    await t.pumpWidget(app(p.widget(), locale: const Locale('ar')));
    await _type(t, '٠٧١٢٣٤٥٦');
    await _rounds(t, 2);
    await t.pumpAndSettle();
    expect(p.joined, ['07123456']);
    expect(l10n.pairCodeMatched, isNot('The code matched. Add each other?'));
    final words = find.text(_words);
    expect(t.widget<Text>(words).textDirection, TextDirection.ltr);
    expect(
      Directionality.of(t.element(find.text(l10n.pairCodeMatched))),
      TextDirection.rtl,
    );
  });

  testWidgets('an add the app turned away says why in its own words, and '
      'lets the invite go', (t) async {
    phone(t);
    final p = _Pair([_done()], adds: ('They are blocked here.', false));
    await t.pumpWidget(app(p.widget()));
    await _type(t, '07123456');
    await _rounds(t, 2);
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.commonAdd));
    await t.pumpAndSettle();
    expect(find.text('They are blocked here.'), findsOneWidget);
    expect(p.done, isEmpty);
    expect(p.calls, containsAllInOrder(['add', 'drop']));
    // a new code typed clears it
    await _type(t, '482913');
    await t.pumpAndSettle();
    expect(find.text('They are blocked here.'), findsNothing);
    expect(find.text(l10n.pairCodeOldCodeShown), findsOneWidget);
  });
}
