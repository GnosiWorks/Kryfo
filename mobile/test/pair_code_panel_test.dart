// SPDX-License-Identifier: GPL-3.0-or-later
// the sharing side of a pairing code counts down as long as the engine
// keeps the invite at the code, shows the key number of its own identity
// key, the one in the invite it put there, and a share no relay took is
// said in the person's language, never in the engine's words. signal is real over rows
// kept in maps; the engine and the relays are stand-ins
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/key_number.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        inviteKeyNumber,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart' show signalSession;
import 'package:kryfo/widgets/pair_code_panel.dart';
import 'package:kryfo/widgets/pair_join.dart' show pairNow, pairUnreached;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;

class _Engine implements HaloEngine {
  String answer = 'ok';
  // holds the answer back, as a slow route does
  Completer<void>? hold;
  final shared = <String>[];
  final payloads = <String>[];
  @override
  String firstContactPk(int counter) => 'ab' * 32;
  @override
  Future<String> pairCodePublish(String code, String payload) async {
    shared.add(code);
    payloads.add(payload);
    await hold?.future;
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final e = _Engine();
  final live = ArrivalRows(HaloContainer.everyday);

  setUpAll(() async {
    final pair = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: Uint8List.fromList(pair.publicKey.serialize().sublist(1)),
      xPrivBytes: pair.privateKey.serialize(),
    );
    useEngineForTest(e);
    useDatabasesForTest(live, Session(live));
    appState
      ..myId = 'my-own-words'
      ..myOnion = 'mine.onion';
  });

  setUp(() {
    pairNow = () => TestWidgetsFlutterBinding.instance.clock.now();
    appState.pairCodes.clear();
  });

  Future<void> share(WidgetTester t) async {
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodePanelOrMakeASix));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
    }
  }

  testWidgets('the countdown is the time the invite stays at the code', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    expect(e.shared, hasLength(1));
    expect(find.text(l10n.pairCodePanelBurnsIn('10', '00')), findsOneWidget);
    expect(kPairCodeLife, const Duration(minutes: 10));
    // gone when it says, and not before
    await t.pump(const Duration(minutes: 9, seconds: 59));
    expect(find.text(l10n.pairCodePanelBurnsIn('0', '01')), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodePanelOrMakeASix), findsOneWidget);
  });

  testWidgets('the countdown starts with the code, not with the answer', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    final hold = Completer<void>();
    e.hold = hold;
    addTearDown(() => e.hold = null);
    final before = e.shared.length;
    await share(t);
    expect(e.shared, hasLength(before + 1));
    await t.pump(const Duration(seconds: 40));
    hold.complete();
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
    }
    expect(find.text(l10n.pairCodePanelBurnsIn('9', '20')), findsOneWidget);
  });

  testWidgets('a share no relay took says so plainly', (t) async {
    phone(t);
    e.answer = pairUnreached;
    await share(t);
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeUnreached), findsOneWidget);
    expect(find.textContaining('unreached'), findsNothing);
  });

  testWidgets('the code shows the key number of the invite it put there', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    await t.pump(const Duration(milliseconds: 400));
    final own = keyNumber(
      signalSession.identityKeyPair.getPublicKey().serialize(),
    )!;
    // the joiner reads the same off what it fetches
    expect(inviteKeyNumber(e.payloads.last), own);
    expect(find.text(l10n.pairCodeKeyNumber), findsOneWidget);
    expect(find.text(l10n.pairCodeNumberMatches), findsOneWidget);
    // their request is taken in on their word that the numbers matched
    expect(find.text(l10n.pairCodePanelAcceptOnce), findsOneWidget);
    for (final g in own.split(' ')) {
      expect(find.text(g), findsOneWidget);
    }
    await t.pumpWidget(const SizedBox());
  });

  // the panel's own swap, not one inside the code
  Iterable<ScaleTransition> swapScales(WidgetTester t) =>
      t.widgetList<ScaleTransition>(
        find.descendant(
          of: find.byType(PairCodePanel),
          matching: find.byType(ScaleTransition),
        ),
      );

  testWidgets('the code settles in from near its size as the card eases', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    // never grown from a point
    expect(swapScales(t), isNotEmpty);
    for (final s in swapScales(t)) {
      expect(s.scale.value, greaterThanOrEqualTo(0.94));
    }
    // the card eases to its height (its status line eases in its own)
    expect(
      find.descendant(
        of: find.byType(PairCodePanel),
        matching: find.byType(AnimatedSize),
      ),
      findsWidgets,
    );
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a code whose ten minutes are over goes, and says so', (t) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    await t.pump(const Duration(seconds: 1));
    for (var i = 0; i < kPairCodeLife.inSeconds; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.pairCodePanelBurned), findsOneWidget);
    expect(find.text(l10n.pairCodePanelOrMakeASix), findsOneWidget);
  });

  testWidgets('with less movement the code is simply there', (t) async {
    phone(t);
    e.answer = 'ok';
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel()), still: true));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodePanelOrMakeASix));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
    }
    expect(find.text(l10n.pairCodePanelOrMakeASix), findsNothing);
    expect(
      find.descendant(
        of: find.byType(PairCodePanel),
        matching: find.byType(AnimatedSize),
      ),
      findsNothing,
    );
    expect(t.hasRunningAnimations, isFalse);
  });

  // the live code as the panel draws it
  String drawn(String code) => '${code.substring(0, 3)} ${code.substring(3)}';

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
    }
  }

  testWidgets('right to left, the code still reads in the order it is said', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    await t.pumpWidget(
      app(const Scaffold(body: PairCodePanel()), locale: const Locale('ar')),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pairCodePanelOrMakeASix));
    await settle(t);
    final code = find.text(drawn(e.shared.last));
    expect(code, findsOneWidget);
    expect(Directionality.of(t.element(code)), TextDirection.rtl);
    expect(t.widget<Text>(code).textDirection, TextDirection.ltr);
    // the first three digits are drawn left of the last three
    final p = t.renderObject<RenderParagraph>(code);
    final first = p.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero);
    final last = p.getOffsetForCaret(const TextPosition(offset: 4), Rect.zero);
    expect(first.dx, lessThan(last.dx));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a live code is still there when its card is opened again', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    final code = e.shared.last;
    expect(find.text(drawn(code)), findsOneWidget);
    // the card or tab is left, and the invite stays at the code
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pump();
    expect(find.text(drawn(code)), findsOneWidget);
    expect(find.text(l10n.pairCodePanelBurnsIn('9', '30')), findsOneWidget);
    expect(find.text(l10n.pairCodePanelOrMakeASix), findsNothing);
    // and it still counts down
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.pairCodePanelBurnsIn('9', '29')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a code left before the engine answered comes up live', (
    t,
  ) async {
    phone(t);
    e.answer = 'ok';
    final hold = Completer<void>();
    e.hold = hold;
    addTearDown(() => e.hold = null);
    await share(t);
    final code = e.shared.last;
    await t.pumpWidget(const SizedBox());
    hold.complete();
    await settle(t);
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pump();
    expect(find.text(drawn(code)), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a code that burned while away says so once', (t) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(kPairCodeLife);
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pump();
    expect(find.text(l10n.pairCodePanelBurned), findsOneWidget);
    expect(find.text(l10n.pairCodePanelOrMakeASix), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pump();
    expect(find.text(l10n.pairCodePanelBurned), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a container never shows another container\'s code', (t) async {
    phone(t);
    e.answer = 'ok';
    await share(t);
    final code = e.shared.last;
    await t.pumpWidget(const SizedBox());
    addTearDown(() => useDatabasesForTest(live, Session(live)));
    for (final c in [HaloContainer.decoy, HaloContainer.decoyVault]) {
      final other = ArrivalRows(c);
      useDatabasesForTest(live, Session(other));
      await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
      await t.pump();
      expect(find.text(drawn(code)), findsNothing, reason: c.id);
      expect(find.text(l10n.pairCodePanelOrMakeASix), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }
    // the everyday side's hidden chats are their own container too
    final vault = ArrivalRows(HaloContainer.vault);
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pump();
    expect(find.text(drawn(code)), findsNothing);
    await t.pumpWidget(const SizedBox());
    // back on the everyday side, it is there again
    useDatabasesForTest(live, Session(live));
    await t.pumpWidget(app(const Scaffold(body: PairCodePanel())));
    await t.pump();
    expect(find.text(drawn(code)), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
