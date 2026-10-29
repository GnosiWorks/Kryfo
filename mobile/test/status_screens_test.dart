// SPDX-License-Identifier: GPL-3.0-or-later
// every place that shows the connection says what the home pill says: the
// settings card's tor line and the getting messages line are fed the same
// state sequences as the pill (a start, tor ready, the relays quiet inside
// and past the grace, a bridge switch, a resume after sleep, relay mode's
// relay down, a decoy, no network) and read off at each step
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart' show percent;
import 'package:kryfo/link_view.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        AppStateBridges,
        AppStateDelivery,
        AppStateOutbox,
        AppStateRoute,
        HaloEngine,
        TorHalo,
        appState,
        useEngineForTest;
import 'package:kryfo/pill_grace.dart';
import 'package:kryfo/screens/notifications_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import 'dev_chat_fakes.dart' show devHome, devWorld;

class _Engine implements HaloEngine {
  int retries = 0;
  @override
  Map<String, dynamic> transportState() => {'relays': const []};
  @override
  String setTransportMode(String mode) => mode;
  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  void bridgeRetry() => retries++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the pill over a screen, as both are seen one after the other
Widget _over(Widget screen) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Material(
    color: HaloColors.surface,
    child: Column(
      children: [
        const SizedBox(height: 40),
        const Center(child: TorHalo(label: true)),
        Expanded(child: screen),
      ],
    ),
  ),
);

Finder _inPill(String words) =>
    find.descendant(of: find.byType(TorHalo), matching: find.text(words));

DateTime _ago(int s) => DateTime.now().subtract(Duration(seconds: s));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Engine e;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    e = _Engine();
    useEngineForTest(e);
    appState.sendModeForTest = 'private';
    appState.deliveryModeForTest = DeliveryMode.always;
    appState.noteOnline(true);
    appState.usableAtForTest = null;
    appState.torTryingSinceForTest = null;
    appState.relayDownSinceForTest = null;
  });

  tearDown(() {
    lockState.inDecoy = false;
    appState.noteOnline(true);
    appState.sendModeForTest = 'private';
    appState.deliveryModeForTest = DeliveryMode.always;
    appState.usableAtForTest = null;
    appState.torTryingSinceForTest = null;
    appState.relayDownSinceForTest = null;
    appState.takeTorStatus('off|0|0|1|0');
  });

  Future<void> show(WidgetTester t, Widget screen) async {
    t.view.physicalSize = const Size(1000, 4000);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(_over(screen));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> gone(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  Future<void> poll(WidgetTester t, String line) async {
    appState.takeTorStatus(line);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> nudge(WidgetTester t) async {
    // ignore: invalid_use_of_protected_member
    appState.notifyListeners();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  group('the settings card', () {
    ProtectionLine tor(WidgetTester t) => t.widget<ProtectionLine>(
      find.byWidgetPredicate(
        (w) => w is ProtectionLine && w.label == l10n.settingsTorRouting,
      ),
    );

    // the pill's words, and the card's tor line: on, and what it says
    void says(WidgetTester t, String pill, {String? card, required bool on}) {
      expect(_inPill(pill), findsOneWidget, reason: 'pill: $pill');
      expect(tor(t).state, card ?? pill, reason: 'card');
      expect(tor(t).on, on, reason: 'card on');
    }

    testWidgets('follows the pill through a whole sequence', (t) async {
      await t.runAsync(() => devWorld());
      await show(t, const SettingsScreen());

      appState.torTryingSinceForTest = DateTime.now();
      await poll(t, 'starting|10|0|0|1');
      says(t, l10n.appConnecting2, on: false);

      appState.torTryingSinceForTest = _ago(40);
      await poll(t, 'starting|45|0|0|1');
      says(t, l10n.appConnecting(percent(0.45)), on: false);

      // tor's route up, no relay through: that, not connecting
      await poll(t, 'bootstrapped|100|0|0|1');
      says(t, l10n.appWaitingForARelay, on: false);

      await poll(t, 'reachable|100|1|1|1');
      says(t, l10n.appTorReady, card: l10n.settingsConnected, on: true);

      // the relays quiet: inside the grace both hold, past it both say so
      await poll(t, 'reachable|100|1|0|1');
      says(t, l10n.appTorReady, card: l10n.settingsConnected, on: true);
      appState.usableAtForTest = DateTime.now().subtract(
        kPillGrace + const Duration(seconds: 1),
      );
      await nudge(t);
      says(t, l10n.appWaitingForARelay, on: false);

      // back, then a bridge switch: not held as ready
      await poll(t, 'reachable|100|1|1|1');
      says(t, l10n.appTorReady, card: l10n.settingsConnected, on: true);
      appState.bridgeRetry();
      await poll(t, 'starting|0|0|0|2');
      says(t, l10n.appConnecting2, on: false);

      // asleep, then the network looked at again
      await poll(t, 'reachable|100|1|1|2');
      appState.usableAtForTest = DateTime.now().subtract(
        const Duration(minutes: 10),
      );
      await poll(t, 'reachable|100|1|0|3');
      says(t, l10n.appWaitingForARelay, on: false);

      // no network
      await poll(t, 'reachable|100|1|1|3');
      appState.noteOnline(false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      says(t, l10n.appOffline, on: false);
      await gone(t);
    });

    testWidgets('a decoy reads the same', (t) async {
      lockState.inDecoy = true;
      await t.runAsync(() => devWorld());
      await show(t, const SettingsScreen());
      await poll(t, 'publishing|100|0|0|1');
      says(t, l10n.appWaitingForARelay, on: false);
      await poll(t, 'publishing|100|0|1|1');
      says(t, l10n.appTorReady, card: l10n.settingsConnected, on: true);
      await gone(t);
    });

    testWidgets('the grace runs out in both on its own clock', (t) async {
      await t.runAsync(() => devWorld());
      await show(t, const SettingsScreen());
      await poll(t, 'reachable|100|1|1|1');
      appState.usableAtForTest = DateTime.now().subtract(
        kPillGrace - const Duration(milliseconds: 300),
      );
      await poll(t, 'reachable|100|1|0|1');
      says(t, l10n.appTorReady, card: l10n.settingsConnected, on: true);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      says(t, l10n.appWaitingForARelay, on: false);
      await gone(t);
    });
  });

  group('getting messages', () {
    Finder line(String words) => find.descendant(
      of: find.byType(NotificationsScreen),
      matching: find.text(words),
    );

    testWidgets('always on follows the pill through a sequence', (t) async {
      await show(t, const NotificationsScreen());

      appState.torTryingSinceForTest = _ago(40);
      await poll(t, 'starting|45|0|0|1');
      expect(_inPill(l10n.appConnecting(percent(0.45))), findsOneWidget);
      expect(line(l10n.appConnecting(percent(0.45))), findsOneWidget);

      await poll(t, 'bootstrapped|100|0|0|1');
      expect(_inPill(l10n.appWaitingForARelay), findsOneWidget);
      expect(line(l10n.appWaitingForARelay), findsOneWidget);
      expect(line(l10n.deliveryModeConnecting), findsNothing);

      await poll(t, 'reachable|100|1|1|1');
      expect(_inPill(l10n.appTorReady), findsOneWidget);
      expect(line(l10n.deliveryModeConnected), findsOneWidget);

      // inside the grace: connected in both
      await poll(t, 'reachable|100|1|0|1');
      expect(_inPill(l10n.appTorReady), findsOneWidget);
      expect(line(l10n.deliveryModeConnected), findsOneWidget);
      appState.usableAtForTest = DateTime.now().subtract(
        kPillGrace + const Duration(seconds: 1),
      );
      await nudge(t);
      expect(_inPill(l10n.appWaitingForARelay), findsOneWidget);
      expect(line(l10n.appWaitingForARelay), findsOneWidget);

      appState.noteOnline(false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_inPill(l10n.appOffline), findsOneWidget);
      expect(line(l10n.appOffline), findsOneWidget);
      await gone(t);
    });

    testWidgets('relay mode says when its relay does not answer', (t) async {
      appState.sendModeForTest = 'balanced';
      await show(t, const NotificationsScreen());
      await poll(t, 'off|0|0|1|0');
      expect(_inPill(l10n.modesFastConnected), findsOneWidget);
      expect(line(l10n.deliveryModeConnected), findsOneWidget);
      appState.relayDownSinceForTest = _ago(kRelayDownAfter.inSeconds + 1);
      await nudge(t);
      expect(_inPill(l10n.appServersNotAnswering), findsOneWidget);
      expect(line(l10n.appServersNotAnswering), findsOneWidget);
      expect(line(l10n.deliveryModeConnected), findsNothing);
      await gone(t);
    });

    testWidgets('check-ins put the state before the last check-in', (t) async {
      appState.deliveryModeForTest = DeliveryMode.checkins;
      await show(t, const NotificationsScreen());
      await poll(t, 'reachable|100|1|0|1');
      expect(_inPill(l10n.appWaitingForARelay), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NotificationsScreen),
          matching: find.textContaining(l10n.appWaitingForARelay),
        ),
        findsOneWidget,
      );
      await gone(t);
    });
  });

  test('the check-in line with a state, and without one as before', () {
    String said({String? state, bool connecting = false}) => deliveryStatus(
      mode: DeliveryMode.checkins,
      connected: false,
      connecting: connecting,
      state: state,
      lastCheckMs: 0,
      lastWakeMs: 0,
      nowMs: 1,
    ).text;
    expect(
      said(state: l10n.appWaitingForARelay),
      l10n.deliveryModeStateLast(
        l10n.appWaitingForARelay,
        l10n.deliveryModeNoCheckInYet,
      ),
    );
    expect(
      said(connecting: true),
      l10n.deliveryModeConnecting2(l10n.deliveryModeNoCheckInYet),
    );
    expect(said(), l10n.deliveryModeNoCheckInYet2);
  });

  group('the chats strip', () {
    Finder strip(String words) =>
        find.descendant(of: find.byType(Container), matching: find.text(words));

    testWidgets('says what the pill says, with the same grace', (t) async {
      addTearDown(() => appState.queuedForTest = 0);
      await t.runAsync(() => devWorld());
      appState.queuedForTest = 2;
      t.view.physicalSize = const Size(1000, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: buildHaloTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: devHome(),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      final waiting = l10n.homeWaitingState(2, l10n.appWaitingForARelay);

      await poll(t, 'reachable|100|1|1|1');
      expect(_inPill(l10n.appTorReady), findsOneWidget);
      expect(find.text(l10n.homeWaiting), findsNothing);

      // inside the grace: no strip under a pill that says ready
      await poll(t, 'reachable|100|1|0|1');
      expect(_inPill(l10n.appTorReady), findsOneWidget);
      expect(find.text(l10n.homeWaiting), findsNothing);

      // past it: the strip says what the pill says, not "still connecting"
      appState.usableAtForTest = DateTime.now().subtract(
        kPillGrace + const Duration(seconds: 1),
      );
      await nudge(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(_inPill(l10n.appWaitingForARelay), findsOneWidget);
      expect(strip(waiting), findsOneWidget);

      // tor still climbing: its words
      appState.torTryingSinceForTest = DateTime.now();
      await poll(t, 'starting|20|0|0|2');
      expect(_inPill(l10n.appConnecting2), findsOneWidget);
      expect(
        strip(l10n.homeWaitingState(2, l10n.appConnecting2)),
        findsOneWidget,
      );

      // no network: the offline strip
      appState.noteOnline(false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_inPill(l10n.appOffline), findsOneWidget);
      expect(find.text(l10n.homeWaitingSendsWhenYou(2)), findsOneWidget);
      await gone(t);
    });
  });

  test('a chat\'s route line and its failed send line follow the reading', () {
    LinkView v(LinkKind k) =>
        LinkView(kind: k, status: TorStatus.reachable, pct: 100);
    expect(v(LinkKind.ready).chatLine, isNull);
    expect(v(LinkKind.ready).sendLine, isNull);
    expect(v(LinkKind.relay).chatLine, isNull);
    expect(v(LinkKind.connecting).chatLine, l10n.chatBuildingAPrivateRoute);
    expect(v(LinkKind.climbing).sendLine, l10n.chatStillConnectingToTor);
    // tor up with no relay: never "building" or "still connecting"
    expect(v(LinkKind.relayWait).chatLine, l10n.appWaitingForARelay);
    expect(v(LinkKind.relayWait).sendLine, l10n.appWaitingForARelay);
    expect(v(LinkKind.offline).chatLine, l10n.appOffline);
    // and the chat screen takes them from the reading, nothing else
    final chat = File('lib/screens/chat_screen.dart').readAsStringSync();
    expect(chat, contains('appState.linkView.sendLine'));
    expect(chat, contains('link.chatLine'));
    expect(chat, isNot(contains('!appState.torUsable')));
    expect(chat, isNot(contains("startsWith('error:') && !appState.torReady")));
  });
}
