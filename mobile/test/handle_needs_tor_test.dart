// SPDX-License-Identifier: GPL-3.0-or-later
// the handle page goes to the registry over tor on every route. on fast,
// with the direct route up and tor still connecting, the check is not sent
// and the line names tor, not the registry; tor coming up asks again. a
// registry at its limit is said as busy, here and in a lookup
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_claim.dart';
import 'package:kryfo/handle_lookup.dart' show resolveHandle;
import 'package:kryfo/handle_repoint.dart' show handleRefusalLine;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute;
import 'package:kryfo/screens/handle_screen.dart' show HandleAvailability;
import 'package:kryfo/widgets/motion.dart' show TorStatus;

// the registry over tor: every check is counted
class _Engine implements HaloEngine {
  final asks = <String>[];
  String answer = 'free';
  @override
  Future<String> handleCheck(String h) async {
    asks.add(h);
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

Widget _line(String state) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: HandleAvailability(state: state)),
);

void main() {
  late _Engine engine;

  setUp(() {
    setL10nLocale(const Locale('en'));
    engine = _Engine();
    useEngineForTest(engine);
    // fast: the direct route carries, tor is still connecting
    appState.sendModeForTest = 'balanced';
    appState.setRouteOKForTest(true);
    appState.setTorStatusForTest(TorStatus.starting);
  });

  tearDown(() {
    appState.setTorStatusForTest(TorStatus.off);
    appState.setRouteOKForTest(false);
  });

  Future<void> answered(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('tor not up: nothing goes, and the line says tor', (t) async {
    final c = HandleClaimer(TextEditingController(text: 'wren'));
    c.onTyped('wren');
    await answered(t);
    expect(engine.asks, isEmpty);
    expect(c.state, kNoTor);
    await t.pumpWidget(_line(c.state));
    expect(find.text(l10n.handleNeedsTor), findsOneWidget);
    expect(find.text(l10n.handleRegistryFailed), findsNothing);
    c.dispose();
  });

  testWidgets('tor coming up asks again', (t) async {
    final c = HandleClaimer(TextEditingController(text: 'wren'));
    c.onTyped('wren');
    await answered(t);
    expect(c.state, kNoTor);
    appState.setTorStatusForTest(TorStatus.reachable);
    await answered(t);
    expect(engine.asks, ['wren']);
    expect(c.state, 'free');
    // asked once: a later change of tor's asks nothing more
    appState.setTorStatusForTest(TorStatus.publishing);
    await answered(t);
    expect(engine.asks, ['wren']);
    c.dispose();
  });

  testWidgets('a busy registry is said as busy', (t) async {
    appState.setTorStatusForTest(TorStatus.reachable);
    engine.answer = 'error: busy';
    final c = HandleClaimer(TextEditingController(text: 'wren'));
    c.onTyped('wren');
    await answered(t);
    expect(c.state, 'error: busy');
    await t.pumpWidget(_line(c.state));
    expect(find.text(l10n.handleRegistryBusy), findsOneWidget);
    c.dispose();
  });

  test('claims and lookups say busy and no tor as such', () async {
    expect(handleRefusalLine('error: busy', 'wren'), l10n.handleRegistryBusy);
    expect(handleRefusalLine('error: no tor', 'wren'), l10n.handleNeedsTor);
    expect(
      handleRefusalLine('error: context deadline exceeded', 'wren'),
      l10n.handleRegistryFailed,
    );
    expect(
      await resolveHandle('wren', (_) async => 'error: status 429'),
      'error: the registry is busy',
    );
    expect(
      await resolveHandle('wren', (_) async => 'error: get: EOF'),
      "error: couldn't reach the registry",
    );
  });
}
