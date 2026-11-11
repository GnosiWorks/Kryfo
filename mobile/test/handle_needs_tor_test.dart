// SPDX-License-Identifier: GPL-3.0-or-later
// the handle page goes to the registry over tor on every route. on fast,
// with the direct route up and tor still connecting, the check is not sent
// and the line names tor, not the registry; tor coming up asks again. a
// registry at its limit is said as busy, here and in a lookup
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_claim.dart';
import 'package:kryfo/handle_lookup.dart' show resolveHandle;
import 'package:kryfo/handle_repoint.dart' show handleRefusalLine;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateProfile, AppStateRoute;
import 'package:kryfo/screens/handle_screen.dart' show HandleAvailability;
import 'package:kryfo/widgets/motion.dart' show TorStatus;

// the registry over tor: every check is counted
class _Engine implements HaloEngine {
  final asks = <String>[];
  String answer = 'free';
  String claimAnswer = 'ok';
  String lookupBody = 'error: status 404';
  final looked = <String>[];
  @override
  Future<String> handleCheck(String h) async {
    asks.add(h);
    return answer;
  }

  @override
  Future<String> handleClaim(String h, String invite, String bio) async =>
      claimAnswer;

  @override
  Future<String> ownHandleGetJson(String url) async {
    looked.add(url);
    return lookupBody;
  }

  @override
  String myEdPubkey() => 'ab12';

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

Widget _line(String state, {VoidCallback? onBridges}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: HandleAvailability(state: state, onBridges: onBridges),
  ),
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

  testWidgets('tor up all along: other changes ask nothing more', (t) async {
    appState.setTorStatusForTest(TorStatus.reachable);
    // tor says it carries, the engine found it did not
    engine.answer = kNoTor;
    final c = HandleClaimer(TextEditingController(text: 'wren'));
    c.onTyped('wren');
    await answered(t);
    expect(engine.asks, ['wren']);
    for (var i = 0; i < 3; i++) {
      appState.setRouteOKForTest(true);
      await answered(t);
    }
    expect(engine.asks, ['wren']);
    // down and up again: asked once more
    engine.answer = 'free';
    appState.setTorStatusForTest(TorStatus.starting);
    await answered(t);
    appState.setTorStatusForTest(TorStatus.reachable);
    await answered(t);
    expect(engine.asks, ['wren', 'wren']);
    expect(c.state, 'free');
    c.dispose();
  });

  testWidgets('the tor line leads to the bridges', (t) async {
    var opened = 0;
    await t.pumpWidget(_line(kNoTor, onBridges: () => opened++));
    expect(find.text(l10n.handleNeedsTor), findsOneWidget);
    await t.tap(find.text(l10n.handleGetABridge));
    expect(opened, 1);
    // no link under any other line
    await t.pumpWidget(_line('error: busy', onBridges: () => opened++));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.handleGetABridge), findsNothing);
  });

  testWidgets('a claim with no answer that landed is the handle', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    appState.setTorStatusForTest(TorStatus.reachable);
    const inv = 'kryfo://share?id=thumb-behave-boring&onion=x.onion&v=3';
    final was = claimInvite;
    claimInvite = () async => inv;
    addTearDown(() => claimInvite = was);
    addTearDown(() => appState.setMyHandle(null));
    engine.claimAnswer = 'error: no answer: EOF';
    engine.lookupBody = '{"names":{"wren":"AB12"},"invite":"$inv"}';
    final c = HandleClaimer(TextEditingController(text: 'wren'));
    c.onTyped('wren');
    await answered(t);
    expect(c.state, 'free');
    expect(await c.claim(), 'ok');
    expect(engine.looked, hasLength(1));
    expect(appState.myHandle, 'wren');
    c.dispose();
  });
}
