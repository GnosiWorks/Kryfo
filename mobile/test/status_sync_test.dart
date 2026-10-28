// SPDX-License-Identifier: GPL-3.0-or-later
// the home pill and the tor sheet say the same thing at every step: they
// are fed one state sequence (a start, tor ready, the relays going quiet
// and coming back, a mode switch, a bridge switch, a resume after sleep, a
// decoy, no network) and each step is read off both. a route tor built that
// no relay has answered through says exactly that, in both, at once
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart' show percent;
import 'package:kryfo/link_view.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        AppStateBridges,
        AppStateRoute,
        HaloEngine,
        TorHalo,
        TorSheet,
        appState,
        useEngineForTest;
import 'package:kryfo/pill_grace.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus, TorWarmupGraph;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show phone;

class _Engine implements HaloEngine {
  List<Map<String, dynamic>> relays = const [];
  int retries = 0;
  @override
  Map<String, dynamic> transportState() => {'relays': relays};
  @override
  String setTransportMode(String mode) => mode;
  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  void bridgeRetry() => retries++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// both views side by side, the sheet as the pill opens it
Widget _both({bool still = true, double scale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Material(
    color: HaloColors.surface2,
    child: Column(
      children: [
        const SizedBox(height: 40),
        const Center(child: TorHalo(label: true)),
        Expanded(child: SingleChildScrollView(child: const TorSheet())),
      ],
    ),
  ),
);

Finder _inPill(String words) =>
    find.descendant(of: find.byType(TorHalo), matching: find.text(words));
Finder _inSheet(String words) =>
    find.descendant(of: find.byType(TorSheet), matching: find.text(words));
Finder _inGraph(String words) => find.descendant(
  of: find.byType(TorWarmupGraph),
  matching: find.text(words),
);

// what the pill says, and what the sheet's line and route picture say
void _says(String pill, {String? line, required String graph}) {
  expect(_inPill(pill), findsOneWidget, reason: 'pill: $pill');
  expect(_inSheet(line ?? pill), findsOneWidget, reason: 'sheet: $line');
  expect(_inGraph(graph), findsOneWidget, reason: 'graph: $graph');
}

DateTime _ago(int s) => DateTime.now().subtract(Duration(seconds: s));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Engine e;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    e = _Engine();
    useEngineForTest(e);
    appState.sendModeForTest = 'private';
    appState.noteOnline(true);
    appState.usableAtForTest = null;
    appState.torTryingSinceForTest = null;
    appState.relayDownSinceForTest = null;
  });

  tearDown(() {
    lockState.inDecoy = false;
    appState.noteOnline(true);
    appState.sendModeForTest = 'private';
    appState.usableAtForTest = null;
    appState.torTryingSinceForTest = null;
    appState.relayDownSinceForTest = null;
    appState.takeTorStatus('off|0|0|1|0');
    HaloColors.setLight(false);
  });

  Future<void> show(WidgetTester t, {double scale = 1}) async {
    phone(t);
    await t.pumpWidget(_both(scale: scale));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> gone(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  // a change the poll would not see: the app state tells its listeners
  Future<void> nudge(WidgetTester t) async {
    // ignore: invalid_use_of_protected_member
    appState.notifyListeners();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  // the poll's word, as the engine's status line gives it
  Future<void> poll(WidgetTester t, String line) async {
    appState.takeTorStatus(line);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a start, tor ready, the relays quiet and back', (t) async {
    await show(t);
    await poll(t, 'off|0|0|1|0');
    _says(l10n.appTorOff, line: l10n.appTorIsOff, graph: l10n.motionStandby);

    // tor starting: connecting in both
    appState.torTryingSinceForTest = DateTime.now();
    await poll(t, 'starting|10|0|0|1');
    _says(l10n.appConnecting2, graph: l10n.motionConnecting);

    // a long climb: how far it is, in both
    appState.torTryingSinceForTest = _ago(40);
    await poll(t, 'starting|45|0|0|1');
    _says(l10n.appConnecting(percent(0.45)), graph: l10n.motionConnecting);

    // tor's route up, no relay through it yet: that, not connecting
    await poll(t, 'bootstrapped|100|0|0|1');
    _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
    expect(find.text(l10n.appConnecting2), findsNothing);
    expect(find.text(l10n.motionYouReAnonymous), findsNothing);

    // a relay answered: ready to chat, the address finishing behind it
    await poll(t, 'publishing|100|0|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appReadyToChatAddressFinishing,
      graph: l10n.motionReady,
    );
    await poll(t, 'reachable|100|1|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );

    // the relays go quiet: inside the grace both hold ready, and the
    // sheet's line claims no more than the pill while nothing sends
    await poll(t, 'reachable|100|1|0|1');
    _says(l10n.appTorReady, graph: l10n.motionReady);
    // past it both say the route is up with no relay through, never a
    // full green route under a pill that says otherwise
    appState.usableAtForTest = DateTime.now().subtract(
      kPillGrace + const Duration(seconds: 1),
    );
    await nudge(t);
    _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
    expect(_inSheet(l10n.appTorNoRelayYet), findsOneWidget);
    expect(_inGraph(l10n.motionReady), findsNothing);

    // a relay back
    await poll(t, 'reachable|100|1|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );
    await gone(t);
  });

  testWidgets('the grace runs out in both at the same moment', (t) async {
    await show(t);
    await poll(t, 'reachable|100|1|1|1');
    appState.usableAtForTest = DateTime.now().subtract(
      kPillGrace - const Duration(milliseconds: 300),
    );
    await poll(t, 'reachable|100|1|0|1');
    _says(l10n.appTorReady, graph: l10n.motionReady);
    // nothing polls meanwhile: the reading's own clock moves both
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
    await gone(t);
  });

  testWidgets('a mode switch and relay mode\'s own relay', (t) async {
    await show(t);
    await poll(t, 'reachable|100|1|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );
    await t.runAsync(() => appState.setSendMode('balanced'));
    // tor still says reachable underneath: relay mode does not ride it
    await poll(t, 'reachable|100|1|1|2');
    expect(_inPill(l10n.appViaRelay), findsOneWidget);
    expect(_inSheet(l10n.appViaRelay), findsOneWidget);
    expect(appState.usableAt, isNull);

    // its relay failing: a short spell is not news, a long one says so
    e.relays = [
      {'url': 'wss://relay.kryfo.app', 'fails': 3, 'benched': true},
    ];
    appState.sampleRelayHealth(now: _ago(5));
    await t.pump();
    expect(_inPill(l10n.appViaRelay), findsOneWidget);
    appState.relayDownSinceForTest = _ago(kRelayDownAfter.inSeconds + 1);
    await nudge(t);
    expect(_inPill(l10n.appRelayNotAnswering), findsOneWidget);
    expect(_inSheet(l10n.appRelayNotAnswering), findsOneWidget);
    expect(_inPill(l10n.appViaRelay), findsNothing);

    // back
    e.relays = [
      {'url': 'wss://relay.kryfo.app', 'fails': 0},
    ];
    appState.sampleRelayHealth();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(_inPill(l10n.appViaRelay), findsOneWidget);
    expect(_inSheet(l10n.appViaRelay), findsOneWidget);

    // back to onion: what tor carried before is not held for it
    await t.runAsync(() => appState.setSendMode('private'));
    await poll(t, 'reachable|100|1|0|3');
    _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
    await gone(t);
  });

  testWidgets('a bridge switch is not held as ready', (t) async {
    await show(t);
    await poll(t, 'reachable|100|1|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );
    appState.bridgeRetry();
    expect(e.retries, 1);
    // the poll a moment later still reads the old route
    await poll(t, 'reachable|100|1|1|1');
    // then the bounce asked for: a new generation, tor starting over
    await poll(t, 'starting|0|0|0|2');
    _says(l10n.appConnecting2, graph: l10n.motionConnecting);
    expect(find.text(l10n.appTorReady), findsNothing);
    await gone(t);
  });

  testWidgets('a network handover keeps the grace in both', (t) async {
    await show(t);
    await poll(t, 'reachable|100|1|1|1');
    // the engine bumps the route for the new network, nothing asked for
    await poll(t, 'starting|0|0|0|2');
    _says(l10n.appTorReady, line: l10n.appTorReady, graph: l10n.motionBuilding);
    await gone(t);
  });

  testWidgets('a resume after sleep reads the route as it is', (t) async {
    await show(t);
    await poll(t, 'reachable|100|1|1|1');
    // asleep for ten minutes: no poll, then the network looked at again
    // bumps the route while tor still says reachable
    appState.usableAtForTest = DateTime.now().subtract(
      const Duration(minutes: 10),
    );
    await poll(t, 'reachable|100|1|0|2');
    _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
    expect(_inGraph(l10n.motionReady), findsNothing);
    // the first answer on the woken route
    await poll(t, 'reachable|100|1|1|2');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );
    await gone(t);
  });

  testWidgets('a decoy hears the same as the app', (t) async {
    lockState.inDecoy = true;
    await show(t);
    appState.torTryingSinceForTest = _ago(40);
    await poll(t, 'starting|45|0|0|1');
    _says(l10n.appConnecting(percent(0.45)), graph: l10n.motionConnecting);
    await poll(t, 'publishing|100|0|0|1');
    _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
    await poll(t, 'reachable|100|1|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );
    await gone(t);
  });

  testWidgets('no network: offline in both, the route at rest', (t) async {
    await show(t);
    await poll(t, 'reachable|100|1|1|1');
    appState.noteOnline(false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    _says(l10n.appOffline, graph: l10n.motionOffline);
    expect(_inGraph(l10n.motionNoNetwork), findsOneWidget);
    expect(find.text(l10n.appRelayAndFastModes), findsNothing);
    appState.noteOnline(true);
    await poll(t, 'reachable|100|1|1|1');
    _says(
      l10n.appTorReady,
      line: l10n.appConnectedRoutedThrough3,
      graph: l10n.motionReady,
    );
    await gone(t);
  });

  group('screen readers', () {
    testWidgets('hear a new state once, not each percent', (t) async {
      final sem = t.ensureSemantics();
      await show(t);
      appState.torTryingSinceForTest = _ago(40);
      await poll(t, 'starting|45|0|0|1');
      final pill = find.descendant(
        of: find.byType(TorHalo),
        matching: find.bySemanticsLabel(l10n.appConnecting2),
      );
      expect(t.getSemantics(pill), isSemantics(isLiveRegion: true));
      // a climbing percent: the same words for a screen reader
      await poll(t, 'starting|46|0|0|1');
      expect(pill, findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.appConnecting(percent(0.46))),
        findsNothing,
      );
      // a new state: new words, once, in the pill and the sheet's line
      await poll(t, 'bootstrapped|100|0|0|1');
      for (final view in [TorHalo, TorSheet]) {
        expect(
          find.descendant(
            of: find.byType(view),
            matching: find.bySemanticsLabel(l10n.appWaitingForARelay),
          ),
          findsOneWidget,
          reason: '$view',
        );
      }
      sem.dispose();
      await gone(t);
    });

    for (final label in [true, false]) {
      testWidgets('a screen reader opens the sheet from the '
          '${label ? 'pill' : 'chat dot'}', (t) async {
        final sem = t.ensureSemantics();
        phone(t);
        final m = t.binding.defaultBinaryMessenger;
        m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
        addTearDown(
          () => m.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await t.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Center(child: TorHalo(label: label)),
            ),
          ),
        );
        await poll(t, 'reachable|100|1|1|1');
        // one stop: the state's words, a button, and the tap on it
        final pill = find.bySemanticsLabel(l10n.appTorReady);
        expect(pill, findsOneWidget);
        final node = t.getSemantics(pill);
        expect(
          node,
          isSemantics(
            label: l10n.appTorReady,
            isButton: true,
            hasTapAction: true,
            isLiveRegion: true,
          ),
        );
        t.semantics.tap(find.semantics.byLabel(l10n.appTorReady));
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(find.byType(TorSheet), findsOneWidget);
        sem.dispose();
        await gone(t);
      });
    }

    testWidgets('with the sheet open only the sheet speaks', (t) async {
      final sem = t.ensureSemantics();
      phone(t);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Center(child: TorHalo(label: true))),
        ),
      );
      await poll(t, 'reachable|100|1|0|1');
      expect(find.semantics.byFlag(SemanticsFlag.isLiveRegion), findsOne);
      await t.tap(find.byType(TorHalo));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(TorSheet), findsOneWidget);
      // the pill under the sheet is out of reach: one voice for the state
      expect(find.semantics.byFlag(SemanticsFlag.isLiveRegion), findsOne);
      sem.dispose();
      await gone(t);
    });
  });

  group('ready while the address is published', () {
    // what a sheet stuck on publishing said, none of it while a relay carries
    void notStuck() {
      for (final w in [
        l10n.motionPublishing,
        l10n.motionAnnouncingYourArrival,
        l10n.motionTellingTheNetworkYou,
        l10n.appTheFirstConnectionTakes,
        l10n.appRelayAndFastModes,
      ]) {
        expect(find.text(w), findsNothing, reason: w);
      }
    }

    testWidgets('the sheet says ready to chat, then published', (t) async {
      await show(t);
      appState.torTryingSinceForTest = DateTime.now();
      await poll(t, 'starting|60|0|0|1');
      await poll(t, 'publishing|100|0|1|1');
      _says(
        l10n.appTorReady,
        line: l10n.appReadyToChatAddressFinishing,
        graph: l10n.motionReady,
      );
      expect(_inGraph(l10n.motionReadyToChat), findsOneWidget);
      expect(_inGraph(l10n.motionAddressFinishing), findsOneWidget);
      notStuck();
      expect(appState.torReady, isTrue);
      expect(appState.linkUp, isTrue);

      // published: anonymous, and the finishing words gone
      await poll(t, 'reachable|100|3|1|1');
      _says(
        l10n.appTorReady,
        line: l10n.appConnectedRoutedThrough3,
        graph: l10n.motionReady,
      );
      expect(_inGraph(l10n.motionYouReAnonymous), findsOneWidget);
      expect(find.text(l10n.motionReadyToChat), findsNothing);
      expect(find.text(l10n.motionAddressFinishing), findsNothing);
      await gone(t);
    });

    testWidgets('a ready held through a drop never says ready to chat', (
      t,
    ) async {
      await show(t);
      await poll(t, 'publishing|100|0|1|1');
      expect(_inSheet(l10n.appReadyToChatAddressFinishing), findsOneWidget);
      // the relays go quiet inside the grace: nothing sends meanwhile
      await poll(t, 'publishing|100|0|0|1');
      expect(appState.linkUp, isFalse);
      _says(l10n.appTorReady, graph: l10n.motionPublishing);
      expect(find.text(l10n.appReadyToChatAddressFinishing), findsNothing);
      expect(find.text(l10n.motionReadyToChat), findsNothing);
      await gone(t);
    });

    testWidgets('no relay through yet still says so while it publishes', (
      t,
    ) async {
      await show(t);
      await poll(t, 'publishing|100|0|0|1');
      _says(l10n.appWaitingForARelay, graph: l10n.motionNoRelayYet);
      expect(find.text(l10n.motionReadyToChat), findsNothing);
      await gone(t);
    });

    testWidgets('with motion on the words cross-fade and settle', (t) async {
      phone(t);
      await t.pumpWidget(_both(still: false));
      await t.pump(const Duration(milliseconds: 400));
      await poll(t, 'publishing|100|0|1|1');
      // the stage walks on and the words fade in; then it rests
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(_inGraph(l10n.motionReadyToChat), findsOneWidget);
      appState.takeTorStatus('reachable|100|3|1|1');
      await t.pump();
      // half way through the fade both are drawn, then only the new
      await t.pump(const Duration(milliseconds: 120));
      expect(_inGraph(l10n.motionReadyToChat), findsOneWidget);
      expect(_inGraph(l10n.motionYouReAnonymous), findsOneWidget);
      await t.pump(const Duration(milliseconds: 400));
      expect(_inGraph(l10n.motionReadyToChat), findsNothing);
      expect(_inGraph(l10n.motionYouReAnonymous), findsOneWidget);
      await gone(t);
    });

    testWidgets('right to left reads the same state', (t) async {
      phone(t);
      setL10nLocale(const Locale('ar'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Material(
            color: HaloColors.surface2,
            child: SingleChildScrollView(child: const TorSheet()),
          ),
        ),
      );
      await poll(t, 'publishing|100|0|1|1');
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(find.text(ar.motionReadyToChat), findsOneWidget);
      expect(find.text(ar.appReadyToChatAddressFinishing), findsOneWidget);
      expect(
        Directionality.of(t.element(find.text(ar.motionReadyToChat))),
        TextDirection.rtl,
      );
      expect(t.takeException(), isNull);
      await gone(t);
    });
  });

  // large text, both themes: every state's words fit and nothing clips
  for (final light in [false, true]) {
    for (final step in [
      'starting|45|0|0|1',
      'publishing|100|0|1|1',
      'reachable|100|1|0|1',
      'reachable|100|1|1|1',
    ]) {
      testWidgets('large text, ${light ? 'light' : 'dark'}: $step', (t) async {
        HaloColors.setLight(light);
        appState.torTryingSinceForTest = _ago(40);
        await show(t, scale: 2);
        await poll(t, step);
        expect(t.takeException(), isNull);
        final pill = t.getRect(find.byType(TorHalo));
        expect(pill.right, lessThanOrEqualTo(360));
        await gone(t);
      });
    }
  }

  test('one reading: the pill and the sheet take nothing else', () {
    final now = DateTime(2026, 10, 23, 12);
    LinkView at({
      TorStatus status = TorStatus.reachable,
      bool usable = false,
      DateTime? usableAt,
      String mode = 'private',
    }) => linkViewOf(
      mode: mode,
      status: status,
      pct: 100,
      online: true,
      usable: usable,
      usableAt: usableAt,
      tryingSince: now.subtract(const Duration(seconds: 2)),
      relayDownSince: null,
      now: now,
    );
    // up with no relay: at once, not after the patience a start gets
    expect(at().kind, LinkKind.relayWait);
    expect(at().text, at().line);
    expect(at(status: TorStatus.bootstrapped).kind, LinkKind.relayWait);
    expect(at(usable: true).kind, LinkKind.ready);
    final held = at(usableAt: now.subtract(const Duration(seconds: 5)));
    expect(held.kind, LinkKind.ready);
    expect(held.held, isTrue);
    expect(held.recheckAt, now.add(kPillGrace - const Duration(seconds: 5)));
    expect(at(status: TorStatus.starting).kind, LinkKind.connecting);
    expect(at(mode: 'balanced').kind, LinkKind.relay);
  });
}
