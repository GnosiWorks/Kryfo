// SPDX-License-Identifier: GPL-3.0-or-later
// the sharing side of a pairing code counts down as long as the engine
// keeps the invite at the code, and a share no relay took is said in the
// person's language, never in the engine's words. signal is real over rows
// kept in maps; the engine and the relays are stand-ins
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart' show signalSession;
import 'package:kryfo/widgets/pair_code_panel.dart';
import 'package:kryfo/widgets/pair_join.dart' show pairUnreached;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;

class _Engine implements HaloEngine {
  String answer = 'ok';
  // holds the answer back, as a slow route does
  Completer<void>? hold;
  final shared = <String>[];
  @override
  String firstContactPk(int counter) => 'ab' * 32;
  @override
  Future<String> pairCodePublish(String code, String payload) async {
    shared.add(code);
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

  setUpAll(() async {
    final pair = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: Uint8List.fromList(pair.publicKey.serialize().sublist(1)),
      xPrivBytes: pair.privateKey.serialize(),
    );
    useEngineForTest(e);
    final live = ArrivalRows(HaloContainer.everyday);
    useDatabasesForTest(live, Session(live));
    appState
      ..myId = 'my-own-words'
      ..myOnion = 'mine.onion';
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
}
