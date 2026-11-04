// SPDX-License-Identifier: GPL-3.0-or-later
// the sharing side of an eight digit code: the code in its three groups
// once the engine put the offer up, counted down for ten minutes, a wrong
// try said in the warning colour, the match shown with the person's add,
// a share no relay took said in the person's words, the code still there
// when its card opens again and seen by no other container. the engine
// and the app are stand-in hooks
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show AppStateSession, appState, useDatabasesForTest;
import 'package:kryfo/pair_flow.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/pair_code_panel.dart';
import 'package:kryfo/widgets/pair_join.dart' show PairMatched;

import 'arrival_fakes.dart';
import 'pin_flow_fakes.dart' show app, phone;

class _Share {
  String says = 'ok 3 07 123 456';
  final steps = <String>[];
  Completer<void>? hold;
  final calls = <String>[];
  final added = <String>[];

  PairHooks hooks() => PairHooks(
    invite: () async => PairMine(Uint8List.fromList([1])),
    share: (_) async {
      calls.add('share');
      await hold?.future;
      return says;
    },
    join: (_, _) async => 'error: none',
    step: (_) async => steps.isEmpty ? 'wait 0' : steps.removeAt(0),
    close: (_) async => calls.add('close'),
    read: (_) async =>
        const PairPeer(link: 'kryfo://share?v=4&i=x', id: 'their-own-words'),
    hold: (_, _) async => calls.add('hold'),
    add: (p, m, {required sharer}) async {
      calls.add(sharer ? 'add sharer' : 'add joiner');
      return ('', true);
    },
    drop: (_) async => calls.add('drop'),
  );

  Widget panel({bool compact = false}) => Scaffold(
    body: PairCodePanel(compact: compact, hooks: hooks, onAdded: added.add),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final live = ArrivalRows(HaloContainer.everyday);

  setUpAll(() => useDatabasesForTest(live, Session(live)));

  setUp(() {
    pairNow = () => TestWidgetsFlutterBinding.instance.clock.now();
    appState.pairCodes.clear();
  });

  Future<void> make(WidgetTester t, _Share s, {bool still = false}) async {
    await t.pumpWidget(app(s.panel(), still: still));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodePanelOrMakeACode));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  // the code as shown, one digit to a text
  String shown(WidgetTester t) => [
    for (final e
        in find
            .descendant(
              of: find.bySemanticsLabel('07 123 456'),
              matching: find.byType(Text),
            )
            .evaluate())
      (e.widget as Text).data,
  ].join();

  Future<void> away(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
  }

  testWidgets('the code in its groups, counted down for ten minutes, and '
      'gone when it says', (t) async {
    phone(t);
    final s = _Share();
    await make(t, s);
    expect(s.calls, contains('share'));
    expect(find.bySemanticsLabel('07 123 456'), findsOneWidget);
    expect(shown(t), '07123456');
    expect(find.text(l10n.pairCodePanelBurnsIn('10', '00')), findsOneWidget);
    expect(find.text(l10n.pairCodePanelTheyOpenKryfoEight), findsOneWidget);
    await t.pump(const Duration(minutes: 9, seconds: 59));
    expect(find.text(l10n.pairCodePanelBurnsIn('0', '01')), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodePanelBurned), findsOneWidget);
    expect(find.text(l10n.pairCodePanelOrMakeACode), findsOneWidget);
    expect(s.calls, containsAll(['close', 'drop']));
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the count starts with the code, not with the engine\'s '
      'answer', (t) async {
    phone(t);
    final s = _Share()..hold = Completer<void>();
    await make(t, s);
    expect(find.text(l10n.pairCodePanelWorking), findsOneWidget);
    await t.pump(const Duration(seconds: 40));
    s.hold!.complete();
    await t.pump();
    await t.pump();
    expect(find.text(l10n.pairCodePanelBurnsIn('9', '20')), findsOneWidget);
    appState.pairCodes.clear();
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a wrong try is said in the warning colour, and the code '
      'stays', (t) async {
    phone(t);
    final s = _Share()..steps.addAll(['wait 0', 'wait 1']);
    await make(t, s);
    await t.pump(const Duration(seconds: 7));
    // the code breathes while it is up: no settling, a few frames
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    final f = find.text(l10n.pairCodePanelWrongTyped);
    expect(f, findsOneWidget);
    expect(t.widget<Text>(f).style?.color, HaloColors.roseText);
    expect(find.bySemanticsLabel('07 123 456'), findsOneWidget);
    s.steps.add('error: tries');
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodePanelThreeWrong), findsOneWidget);
    expect(find.bySemanticsLabel('07 123 456'), findsNothing);
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the match shows who it is, and the add comes only on Add', (
    t,
  ) async {
    phone(t);
    final s = _Share()
      ..steps.add('done ${base64Encode(utf8.encode('the-joiner'))}');
    await make(t, s);
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.byType(PairMatched), findsOneWidget);
    expect(find.text('their-own-words'), findsOneWidget);
    expect(s.calls, contains('hold'));
    expect(s.calls, isNot(contains('add sharer')));
    await t.tap(find.text(l10n.commonAdd));
    await t.pumpAndSettle();
    expect(s.calls, contains('add sharer'));
    // the sharer's invite stays for their opener
    expect(s.calls, isNot(contains('drop')));
    expect(s.added, ['']);
    expect(appState.pairCodes.of(appState.pairBox), isNull);
    expect(find.text(l10n.pairCodePanelOrMakeACode), findsOneWidget);
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('not them adds nothing, and says so', (t) async {
    phone(t);
    final s = _Share()..steps.add('done ${base64Encode(utf8.encode('x'))}');
    await make(t, s);
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodeNotThem));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodePanelNotAdded), findsOneWidget);
    expect(s.calls, contains('drop'));
    expect(s.calls, isNot(contains('add sharer')));
    await away(t);
  });

  testWidgets('a share no relay took says so plainly', (t) async {
    phone(t);
    final s = _Share()..says = pairUnreached;
    await make(t, s);
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeUnreached), findsOneWidget);
    expect(find.textContaining('unreached'), findsNothing);
    expect(s.calls, contains('drop'));
    await away(t);
  });

  testWidgets('reduced motion: the code shows at once, in the order it is '
      'said in a right-to-left language', (t) async {
    phone(t);
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    final s = _Share();
    await t.pumpWidget(app(s.panel(), still: true, locale: const Locale('ar')));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodePanelOrMakeACode));
    await t.pump();
    await t.pump();
    final code = find.bySemanticsLabel('07 123 456');
    expect(code, findsOneWidget);
    final digits = find.descendant(of: code, matching: find.byType(Text));
    expect(
      t.getTopLeft(digits.first).dx,
      lessThan(t.getTopLeft(digits.last).dx),
    );
    for (final e
        in find
            .descendant(of: code, matching: find.byType(Opacity))
            .evaluate()) {
      expect((e.widget as Opacity).opacity, 1);
    }
    appState.pairCodes.clear();
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a live code is still there when its card is opened again, '
      'and one that burned while away is said once', (t) async {
    phone(t);
    final s = _Share();
    await make(t, s);
    await away(t);
    await t.pump(const Duration(seconds: 30));
    await t.pumpWidget(app(s.panel()));
    await t.pump();
    expect(find.bySemanticsLabel('07 123 456'), findsOneWidget);
    expect(find.text(l10n.pairCodePanelBurnsIn('9', '30')), findsOneWidget);
    await away(t);
    await t.pump(kPairCodeLife);
    await t.pumpWidget(app(s.panel()));
    await t.pump();
    expect(find.text(l10n.pairCodePanelBurned), findsOneWidget);
    await away(t);
    await t.pumpWidget(app(s.panel()));
    await t.pump();
    expect(find.text(l10n.pairCodePanelBurned), findsNothing);
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a container never shows another container\'s code', (t) async {
    phone(t);
    final s = _Share();
    await make(t, s);
    await away(t);
    addTearDown(() => useDatabasesForTest(live, Session(live)));
    for (final c in [HaloContainer.decoy, HaloContainer.decoyVault]) {
      final other = ArrivalRows(c);
      useDatabasesForTest(live, Session(other));
      await t.pumpWidget(app(s.panel()));
      await t.pump();
      expect(find.bySemanticsLabel('07 123 456'), findsNothing, reason: c.id);
      await away(t);
    }
    final vault = ArrivalRows(HaloContainer.vault);
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await t.pumpWidget(app(s.panel()));
    await t.pump();
    expect(find.bySemanticsLabel('07 123 456'), findsNothing);
    await away(t);
    useDatabasesForTest(live, Session(live));
    await t.pumpWidget(app(s.panel()));
    await t.pump();
    expect(find.bySemanticsLabel('07 123 456'), findsOneWidget);
    appState.pairCodes.clear();
    await away(t);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('both phones need 0.6, said on the share side, on a phone and '
      'on a computer each its own way', (t) async {
    phone(t);
    final s = _Share();
    await t.pumpWidget(app(s.panel()));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeBothNeed06Shown), findsOneWidget);
    expect(l10n.pairCodeBothNeed06, 'Both phones need Kryfo 0.6 or newer.');
    expect(
      l10n.pairCodeBothNeed06Desk,
      'Both devices need Kryfo 0.6 or newer.',
    );
    await away(t);
  });
}
