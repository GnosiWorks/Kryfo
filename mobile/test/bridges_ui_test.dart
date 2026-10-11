// SPDX-License-Identifier: GPL-3.0-or-later
// the connection page. the status line says every state in plain words, a
// decoy hears only connected, connecting or offline. a card picked applies
// at once, with no save, and quick taps reach the engine once. the tor
// project is asked only after a yes, and the one-time sheet only comes on
// a new install. a friend's lines are judged by the engine. 0.5.0's keys
// move over once. right to left, less movement and a small phone at a
// large text size hold. the engine is a stand-in
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show lockGuard;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, appState, bridgeWriteTap, useEngineForTest;
import 'package:kryfo/screens/bridge_sheets.dart';
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/widgets/motion.dart' show BreathDot, kHouseCurve;
import 'package:kryfo/widgets/press_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp;

class _Engine implements HaloEngine {
  final calls = <String>[];
  String answer = 'ok';
  String checks = '[]';
  int retries = 0;
  int moat = 0;

  @override
  String setBridgeMode(String mode, String opts) {
    calls.add('$mode $opts');
    return answer;
  }

  // what the boot restore was handed, and its answer
  final restores = <String>[];
  String restoreAnswer = 'ok';
  @override
  String restoreBridgeMode(String mode, String opts) {
    restores.add('$mode $opts');
    return restoreAnswer;
  }

  // what automatic learnt, as handed over; a decoy's engine refuses it
  final memories = <String>[];
  @override
  String setAutoMemory(String json) {
    if (lockState.inDecoy) return '{"error":"decoy"}';
    memories.add(json);
    return 'ok';
  }

  @override
  String setBridgeCache(String json) =>
      lockState.inDecoy ? '{"error":"decoy"}' : 'ok';

  @override
  String bridgeLineChecks() => checks;
  @override
  List<String> builtinBridges(String transport) => [
    'obfs4 192.0.2.1:443 AAAA cert=x iat-mode=0',
  ];
  @override
  void bridgeRetry() => retries++;
  @override
  Future<String> moatSettings(String country, {bool overTor = false}) async {
    moat++;
    return '{"ok":true,"settings":[],"country":"ir","guessed":true}';
  }

  @override
  String autoMemory() => memories.isEmpty ? '{}' : memories.last;
  @override
  String bridgeCache() => '{}';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _through = BridgeStatus(
  mode: 'auto',
  phase: 'connected',
  method: 'direct',
  canSend: true,
);

const _another = BridgeStatus(
  mode: 'auto',
  phase: 'trying',
  method: 'snowflake',
  source: 'builtin',
  blocked: true,
  attempt: 2,
  attempts: 3,
  progress: 40,
  snowflake: 'broker',
);

late _Engine _eng;

Future<void> _open(
  WidgetTester t, {
  BridgeSetup setup = const BridgeSetup(),
  BridgeStatus status = _through,
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(400, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  setL10nLocale(locale);
  appState.bridgeSetupForTest = setup;
  appState.setBridgeStatusForTest(status);
  await t.pumpWidget(
    devApp(const BridgesScreen(), still: still, locale: locale, scale: scale),
  );
  await _in(t);
}

// a frame to start what a tap opened, and a second for it to come in
Future<void> _in(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _eng = _Engine();
    useEngineForTest(_eng);
    appState.sendModeForTest = 'private';
    // a lock read and open: the sheets close under a lock that is up
    lockState.openForTest();
  });

  tearDown(() {
    setL10nLocale(const Locale('en'));
    appState.bridgeSetupForTest = const BridgeSetup();
    appState.setBridgeStatusForTest(BridgeStatus.none);
    if (lockState.inDecoy) lockState.inDecoy = false;
  });

  group('the status line', () {
    BridgeLine line(BridgeStatus s, {bool decoy = false, String c = 'no'}) =>
        bridgeStatusLine(s, decoy: decoy, consent: c);

    test('connected, straight or through a bridge, rests green', () {
      final d = line(_through);
      expect(d.head, l10n.bridgesConnected);
      expect(d.detail, l10n.bridgesStraightToTor);
      expect(d.tone, BridgeTone.green);
      expect(d.moving, isFalse);
      final b = line(
        const BridgeStatus(
          mode: 'auto',
          phase: 'connected',
          method: 'obfs4',
          canSend: true,
        ),
      );
      expect(b.detail, l10n.bridgesThroughABridge);
      // nothing names the transport outside "more"
      expect(b.detail, isNot(contains('obfs4')));
    });

    test('tor through but nothing sent yet is almost there', () {
      final l = line(
        const BridgeStatus(mode: 'auto', phase: 'connected', method: 'direct'),
      );
      expect(l.head, l10n.bridgesConnectingDots);
      expect(l.detail, l10n.bridgesAlmostThere);
      expect(l.tone, BridgeTone.amber);
    });

    test('the usual way, with the percent tor knows', () {
      final l = line(
        const BridgeStatus(mode: 'auto', phase: 'trying', progress: 40),
      );
      expect(l.head, l10n.bridgesConnectingDots);
      expect(l.detail, '40%');
      expect(l.progress, 0.4);
      expect(l.moving, isTrue);
    });

    test('no percent yet: the clock moves instead, in the view', () {
      final l = line(
        const BridgeStatus(mode: 'auto', phase: 'trying', sinceMs: 42000),
      );
      expect(l.clockMs, 42000);
      expect(l.detail, isNull);
      expect(l.progress, isNull);
      expect(bridgeClock(42000), '0:42');
      // the seconds alone are no news: nothing rebuilds for them
      expect(
        const BridgeStatus(mode: 'auto', phase: 'trying', sinceMs: 1000),
        const BridgeStatus(mode: 'auto', phase: 'trying', sinceMs: 9000),
      );
    });

    test('blocked: another way, its step, a volunteer and the percent', () {
      final l = line(_another);
      expect(l.head, l10n.bridgesTorSeemsBlocked);
      expect(l.detail, contains(l10n.bridgesTryingAnotherWayOf('2', '3')));
      expect(l.detail, contains(l10n.bridgesFoundAVolunteer));
      expect(l.detail, contains('40%'));
      expect(l.detail, isNot(contains('nowflake')));
      final looking = line(
        const BridgeStatus(
          mode: 'auto',
          phase: 'trying',
          blocked: true,
          attempt: 3,
          attempts: 3,
          snowflake: 'offer',
        ),
      );
      expect(looking.detail, contains(l10n.bridgesLookingForAVolunteer));
    });

    test('a limited network and the tor project being asked', () {
      final lim = line(
        const BridgeStatus(
          mode: 'auto',
          phase: 'trying',
          limited: true,
          attempt: 2,
          attempts: 4,
        ),
      );
      expect(lim.head, l10n.bridgesYourNetworkMayBe);
      final ask = line(
        const BridgeStatus(mode: 'auto', phase: 'asking', blocked: true),
      );
      expect(ask.head, l10n.bridgesTorSeemsBlocked);
      expect(ask.detail, l10n.bridgesAskingTheTorProject);
      final gone = line(
        const BridgeStatus(
          mode: 'auto',
          phase: 'trying',
          blocked: true,
          attempt: 3,
          attempts: 3,
          errorCode: 'moat_unreachable',
        ),
      );
      expect(gone.detail, contains(l10n.bridgesCouldNotReachTheTor));
    });

    test('a bridge picked by hand connects through it', () {
      final l = line(
        const BridgeStatus(mode: 'own', phase: 'trying', method: 'webtunnel'),
      );
      expect(l.head, l10n.bridgesConnectingThroughYourBridge);
      expect(l.detail, isNull);
    });

    test('nothing got through: one way out', () {
      const s = BridgeStatus(mode: 'auto', phase: 'exhausted');
      expect(line(s).head, l10n.bridgesNothingGotThrough);
      expect(line(s).tone, BridgeTone.rose);
      // the words go with the button
      expect(line(s).action, BridgeAction.getBridge);
      expect(line(s).detail, l10n.bridgesTheTorProjectCanSuggest);
      expect(line(s, c: 'yes').action, BridgeAction.tryAgain);
      expect(line(s, c: 'yes').detail, l10n.bridgesKryfoTriesAgainOnItsOwn);
    });

    test('a wi-fi that wants a sign-in says so, calmly', () {
      final l = line(const BridgeStatus(mode: 'auto', phase: 'captive'));
      expect(l.head, l10n.bridgesSignInToThisWifi);
      expect(l.tone, BridgeTone.amber);
      expect(l.moving, isFalse);
      expect(
        line(const BridgeStatus(phase: 'captive'), decoy: true).head,
        l10n.bridgesOffline,
      );
    });

    test('a picked bridge that could not start waits, with a retry', () {
      const s = BridgeStatus(
        mode: 'own',
        phase: 'trying',
        method: 'obfs4',
        errorCode: 'pt_failed',
      );
      final l = line(s);
      expect(l.head, l10n.bridgesYourBridgeCouldNot);
      expect(l.tone, BridgeTone.rose);
      expect(l.action, BridgeAction.tryAgain);
      expect(l.moving, isFalse);
      // a decoy hears connecting, nothing more
      expect(line(s, decoy: true).head, l10n.bridgesConnectingDots);
      expect(line(s, decoy: true).action, isNull);
    });

    test('no internet, asleep, a check-in, and not on tor', () {
      expect(
        line(const BridgeStatus(phase: 'no_internet')).head,
        l10n.bridgesNoInternet,
      );
      expect(
        line(const BridgeStatus(phase: 'paused')).head,
        l10n.bridgesAsleepBetweenCheckIns,
      );
      final c = line(const BridgeStatus(phase: 'checkin'));
      expect(c.head, l10n.bridgesCheckingForMessages);
      expect(c.moving, isTrue);
      final n = line(const BridgeStatus(phase: 'not_tor_mode'));
      expect(n.head, l10n.bridgesNotNeededRightNow);
      expect(n.tone, BridgeTone.quiet);
    });

    test('a decoy hears connected, connecting or offline, nothing more', () {
      for (final s in [
        _another,
        const BridgeStatus(mode: 'auto', phase: 'asking', blocked: true),
        const BridgeStatus(
          mode: 'auto',
          phase: 'trying',
          errorCode: 'moat_unreachable',
          attempt: 2,
          attempts: 3,
        ),
        const BridgeStatus(mode: 'auto', phase: 'exhausted'),
      ]) {
        final l = line(s, decoy: true);
        expect(l.head, l10n.bridgesConnectingDots);
        expect(l.detail, isNull);
        expect(l.action, isNull);
      }
      expect(line(_through, decoy: true).head, l10n.bridgesConnected);
      expect(line(_through, decoy: true).detail, isNull);
      expect(
        line(const BridgeStatus(phase: 'no_internet'), decoy: true).head,
        l10n.bridgesOffline,
      );
      // what the engine itself sends a decoy
      expect(
        line(
          const BridgeStatus(mode: 'auto', phase: 'offline'),
          decoy: true,
        ).head,
        l10n.bridgesOffline,
      );
      expect(
        line(
          const BridgeStatus(mode: 'auto', phase: 'trying'),
          decoy: true,
        ).head,
        l10n.bridgesConnectingDots,
      );
    });

    test('arabic and persian, in their own words and digits', () {
      for (final lang in ['ar', 'fa']) {
        setL10nLocale(Locale(lang));
        final l = line(_another);
        expect(l.head, l10n.bridgesTorSeemsBlocked);
        expect(l.head, isNot('Tor seems blocked on this network'));
        expect(l.detail, contains(l10n.bridgesFoundAVolunteer));
      }
      setL10nLocale(const Locale('fa'));
      expect(line(_another).detail, contains('۲'));
    });
  });

  group('the cards', () {
    testWidgets('a pick shows at once and reaches the engine, no save', (
      t,
    ) async {
      await _open(t);
      expect(find.text(l10n.commonSave), findsNothing);
      await t.tap(find.text(l10n.bridgesDirect));
      await t.pump();
      expect(appState.bridgeChoice, BridgeChoice.direct);
      expect(_eng.calls, isEmpty);
      await _in(t);
      expect(_eng.calls, ['direct {}']);
      await _done(t);
    });

    testWidgets('quick taps bounce tor once', (t) async {
      await _open(t);
      await t.tap(find.text(l10n.bridgesDirect));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text(l10n.bridgesAutomatic));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text(l10n.bridgesDirect));
      await t.pump(const Duration(seconds: 2));
      expect(_eng.calls, ['direct {}']);
      await _done(t);
    });

    testWidgets('a friend\'s card with no line asks for one first', (t) async {
      await _open(t);
      await t.tap(find.text(l10n.bridgesBridgeFromAFriend));
      await _in(t);
      expect(find.text(l10n.bridgesPasteTheLineThey), findsOneWidget);
      expect(appState.bridgeChoice, BridgeChoice.auto);
      expect(_eng.calls, isEmpty);
      await _done(t);
    });

    testWidgets('nothing got through: the button asks the tor project', (
      t,
    ) async {
      await _open(
        t,
        status: const BridgeStatus(mode: 'auto', phase: 'exhausted'),
      );
      await t.tap(find.text(l10n.bridgesGetABridge));
      await _in(t);
      expect(find.text(l10n.bridgesWhenYouAskFor), findsOneWidget);
      await _done(t);
    });
  });

  group('a friend\'s lines', () {
    Future<void> paste(WidgetTester t, String text) async {
      await _open(t);
      await t.tap(find.text(l10n.bridgesBridgeFromAFriend));
      await _in(t);
      await t.enterText(find.byType(TextField), text);
      await t.pump();
    }

    testWidgets('the keyboard gets no say in the line', (t) async {
      await paste(t, '');
      final f = t.widget<TextField>(find.byType(TextField));
      expect(f.autocorrect, isFalse);
      expect(f.enableSuggestions, isFalse);
      expect(f.textDirection, TextDirection.ltr);
      await _done(t);
    });

    testWidgets('lines the engine cannot read stay out', (t) async {
      _eng
        ..answer = 'error: lines_bad'
        ..checks = '[{"i":0,"state":"broken","why":"bad port"}]';
      await paste(t, 'obfs4 1.2.3.4:99999 AAAA cert=x');
      await t.tap(find.text(l10n.bridgesUseThisBridge(1)));
      await _in(t);
      expect(_eng.calls.single, startsWith('own '));
      expect(find.text(l10n.bridgesNoneOfTheseAre), findsOneWidget);
      expect(appState.bridgeChoice, BridgeChoice.auto);
      expect(appState.bridge.friendLines, isEmpty);
      await _done(t);
    });

    testWidgets('lines it takes are used at once, a bad one said', (t) async {
      _eng.checks =
          '[{"i":0,"state":"ok"},{"i":1,"state":"broken","why":"bad port"}]';
      await paste(
        t,
        'Bridge obfs4 192.0.2.1:443 AAAA cert=x\nobfs4 192.0.2.2:99999 BB',
      );
      await t.tap(find.text(l10n.bridgesUseThisBridge(2)));
      await _in(t);
      // the torrc word goes before the engine sees it
      expect(_eng.calls.single, contains('"obfs4 192.0.2.1:443 AAAA cert=x"'));
      expect(find.text(l10n.bridgesPasteTheLineThey), findsNothing);
      expect(appState.bridgeChoice, BridgeChoice.friend);
      expect(splitBridgeLines(appState.bridge.friendLines), hasLength(2));
      expect(find.text(l10n.bridgesKryfoCouldNotRead(1)), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await _done(t);
    });

    test('the tor project\'s qr list and torrc lines', () {
      expect(
        bridgeLinesFrom("['obfs4 1.2.3.4:443 A cert=x', 'obfs4 5.6.7.8:80 B']"),
        ['obfs4 1.2.3.4:443 A cert=x', 'obfs4 5.6.7.8:80 B'],
      );
      expect(bridgeLinesFrom('Bridge webtunnel [2001:db8::1]:443 F url=x'), [
        'webtunnel [2001:db8::1]:443 F url=x',
      ]);
      expect(looksLikeBridges('kryfo://add/abc'), isFalse);
      expect(looksLikeBridges('snowflake 192.0.2.3:80 F url=x'), isTrue);
    });
  });

  group('the tor project', () {
    test('the one-time sheet: a new install, tor blocked, never a decoy', () {
      final app = AppState()..bridgeSetupForTest = const BridgeSetup();
      app.takeBridgeStatus('{"mode":"auto","phase":"trying"}');
      expect(app.bridgeAskDue, isFalse);
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","blocked":true,"ask_consent":true}',
      );
      expect(app.bridgeAskDue, isTrue);
      app.bridgeAskTaken();
      expect(app.bridgeAskDue, isFalse);
      // an upgrade said no already
      final up = AppState()
        ..bridgeSetupForTest = const BridgeSetup(consent: 'no');
      up.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","blocked":true,"ask_consent":true}',
      );
      expect(up.bridgeAskDue, isFalse);
      lockState.inDecoy = true;
      final d = AppState()..bridgeSetupForTest = const BridgeSetup();
      d.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","blocked":true,"ask_consent":true}',
      );
      expect(d.bridgeAskDue, isFalse);
    });

    testWidgets('get a bridge: the yes comes before any ask', (t) async {
      await _open(
        t,
        setup: const BridgeSetup(choice: BridgeChoice.direct),
        status: _another,
      );
      final ctx = t.element(find.byType(BridgesScreen));
      showTorBlockedSheet(ctx, asked: true);
      await _in(t);
      expect(find.text(l10n.bridgesTorIsBlockedOnThis), findsOneWidget);
      expect(find.text(l10n.bridgesWhenYouAskFor), findsOneWidget);
      expect(_eng.calls, isEmpty);
      expect(_eng.moat, 0);
      await t.tap(find.text(l10n.bridgesGetABridge));
      await _in(t);
      expect(_eng.calls.single, startsWith('auto '));
      expect(_eng.calls.single, contains('"consent":"yes"'));
      expect(appState.bridgeChoice, BridgeChoice.auto);
      await _done(t);
    });

    testWidgets('closed without a button, the question stands', (t) async {
      await _open(t);
      showTorBlockedSheet(t.element(find.byType(BridgesScreen)), asked: true);
      await _in(t);
      await t.tapAt(const Offset(10, 10));
      await _in(t);
      expect(find.text(l10n.bridgesTorIsBlockedOnThis), findsNothing);
      expect(appState.bridge.consent, 'ask');
      await _done(t);
    });

    testWidgets('shut by the lock, it is asked again after it', (t) async {
      final app = AppState()..bridgeSetupForTest = const BridgeSetup();
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","blocked":true,"ask_consent":true}',
      );
      app.bridgeAskTaken();
      expect(app.bridgeAskDue, isFalse);
      await _open(t);
      showTorBlockedSheet(t.element(find.byType(BridgesScreen)), asked: true);
      await _in(t);
      lockState.openForTest(enabled: true);
      lockState.lock();
      lockGuard.locking();
      await _in(t);
      expect(find.text(l10n.bridgesTorIsBlockedOnThis), findsNothing);
      expect(appState.bridge.consent, 'ask');
      lockState.openForTest();
      expect(appState.bridgeAskDue, isFalse);
      await _done(t);
    });

    test('never over hidden chats', () {
      final app = AppState()..bridgeSetupForTest = const BridgeSetup();
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","blocked":true,"ask_consent":true}',
      );
      expect(app.bridgeAskDue, isTrue);
      lockState.inVault = true;
      addTearDown(() => lockState.inVault = false);
      expect(app.bridgeAskDue, isFalse);
    });

    testWidgets('not now on the one-time sheet is final', (t) async {
      await _open(t);
      showTorBlockedSheet(t.element(find.byType(BridgesScreen)), asked: true);
      await _in(t);
      await t.tap(find.text(l10n.bridgesNotNow));
      await _in(t);
      expect(appState.bridge.consent, 'no');
      expect(_eng.calls, isEmpty);
      await _done(t);
    });

    testWidgets('the switch under more asks first', (t) async {
      await _open(
        t,
        setup: const BridgeSetup(consent: 'no'),
        size: const Size(400, 1600),
      );
      await t.tap(find.text(l10n.bridgesMore));
      await _in(t);
      expect(find.text(l10n.bridgesCountry), findsNothing);
      await t.ensureVisible(find.text(l10n.bridgesAskTorProject));
      await t.pump();
      await t.tap(find.text(l10n.bridgesAskTorProject));
      await _in(t);
      expect(find.text(l10n.bridgesWhenYouAskFor), findsOneWidget);
      expect(_eng.calls, isEmpty);
      await t.tap(find.text(l10n.commonAllow));
      await _in(t);
      expect(_eng.calls.single, contains('"consent":"yes"'));
      expect(_eng.moat, 0);
      // the country: the sheet at once, and the tor project asked only
      // for its guess, when that is picked
      await t.pump(const Duration(seconds: 1));
      await t.ensureVisible(find.text(l10n.bridgesCountry));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.bridgesCountry));
      await _in(t);
      expect(find.text(l10n.bridgesIran), findsOneWidget);
      expect(_eng.moat, 0);
      await t.tap(find.text(l10n.bridgesIran));
      await _in(t);
      expect(appState.bridge.country, 'ir');
      expect(_eng.calls.last, contains('"country":"ir"'));
      expect(_eng.moat, 0);
      await t.tap(find.text(l10n.bridgesCountry));
      await _in(t);
      await t.tap(find.text(l10n.bridgesLetTheTorProject).last);
      await _in(t);
      expect(_eng.moat, 1);
      expect(appState.bridge.country, '');
      expect(
        find.textContaining(l10n.bridgesTheTorProjectSGuess),
        findsOneWidget,
      );
      await _done(t);
    });
  });

  group('a decoy', () {
    testWidgets('automatic and the status line, nothing of how', (t) async {
      lockState.inDecoy = true;
      await _open(
        t,
        setup: const BridgeSetup(
          choice: BridgeChoice.friend,
          friendLines: 'obfs4 192.0.2.1:443 AAAA cert=x',
        ),
        status: _another,
      );
      expect(find.text(l10n.bridgesAutomatic), findsOneWidget);
      expect(find.text(l10n.bridgesDirect), findsNothing);
      expect(find.text(l10n.bridgesBridgeFromAFriend), findsNothing);
      expect(find.text(l10n.bridgesMore), findsNothing);
      expect(find.text(l10n.bridgesConnectingDots), findsOneWidget);
      expect(find.textContaining('192.0.2.1'), findsNothing);
      expect(find.textContaining('of 3'), findsNothing);
      expect(find.textContaining(l10n.bridgesFoundAVolunteer), findsNothing);
      await t.tap(find.text(l10n.bridgesAutomatic));
      await t.pump(const Duration(seconds: 2));
      expect(_eng.calls, isEmpty);
      await _done(t);
    });
  });

  // a start straight into a decoy: tor keeps the person's pick, handed over
  // by the restore, which a decoy does not refuse. a pick would be
  group('a cold start into a decoy', () {
    Future<void> start(Map<String, String> kept) async {
      FlutterSecureStorage.setMockInitialValues({
        'halo.lock.state': '{"q":true}',
        ...kept,
      });
      lockState.inDecoy = true;
      await AppState().loadBridgesForTest();
    }

    test('bridges on stay on', () async {
      await start({
        'bridge_mode': 'own',
        'bridge_lines': 'obfs4 192.0.2.1:443 AAAA cert=x',
      });
      expect(_eng.restores, [
        'own {"lines":["obfs4 192.0.2.1:443 AAAA cert=x"]}',
      ]);
      expect(_eng.calls, isEmpty);
    });

    test('automatic stays automatic, without tor alone if risky', () async {
      await start({
        'bridge_mode': 'auto',
        'bridge_consent': 'ask',
        'bridge_skip_direct': '1',
      });
      expect(_eng.restores.single, startsWith('auto '));
      expect(_eng.restores.single, contains('"skip_direct":true'));
      expect(_eng.calls, isEmpty);
    });

    test('nothing to use is never direct', () async {
      await start({'bridge_mode': 'own', 'bridge_lines': ''});
      expect(_eng.restores.single, startsWith('auto '));
      expect(_eng.restores.single, contains('"skip_direct":true'));
    });

    test('a kept mode the engine refuses is automatic, never direct', () {
      _eng.restoreAnswer = 'error: lines_bad';
      final app = AppState()
        ..bridgeSetupForTest = const BridgeSetup(
          choice: BridgeChoice.friend,
          friendLines: 'obfs4 mangled',
        );
      expect(app.restoreBridgeAtBoot(), 'error: lines_bad');
      expect(app.bridgeChoice, BridgeChoice.auto);
      expect(app.bridge.skipDirect, isTrue);
    });

    test('what automatic learnt waits for the decoy to close', () async {
      const kept = '{"v":1,"last":{"wifi":{"m":"obfs4","s":"builtin","d":1}}}';
      FlutterSecureStorage.setMockInitialValues({
        'halo.lock.state': '{"q":true}',
        'bridge_mode': 'auto',
        'bridge_auto_mem': kept,
      });
      lockState.inDecoy = true;
      final app = AppState();
      await app.loadBridgesForTest();
      expect(app.bridgeMemoryIn, isFalse);
      expect(_eng.memories, isEmpty);
      // something gets through in the decoy: nothing is written back
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"connected","can_send":true}',
      );
      await Future<void>.delayed(Duration.zero);
      const st = FlutterSecureStorage();
      expect(await st.read(key: 'bridge_auto_mem'), kept);
      // the decoy closes: the memory goes in, and what is written back is
      // what was learnt, never an empty start
      FlutterSecureStorage.setMockInitialValues({'bridge_auto_mem': kept});
      lockState.inDecoy = false;
      expect(_eng.memories, [kept]);
      app.takeBridgeStatus('{"mode":"auto","phase":"trying"}');
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"connected","can_send":true}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await st.read(key: 'bridge_auto_mem'), kept);
    });
  });

  group('0.5.0 moves over', () {
    test('each combination, once', () {
      final moat = migrateBridges(
        upgrade: true,
        on: '1',
        lines: 'obfs4 a',
        source: 'moat',
      );
      expect(moat.choice, BridgeChoice.torProject);
      expect(moat.torProjectLines, 'obfs4 a');
      expect(moat.consent, 'no');
      final paste = migrateBridges(
        upgrade: true,
        on: '1',
        lines: 'obfs4 b',
        source: 'paste',
      );
      expect(paste.choice, BridgeChoice.friend);
      expect(paste.friendLines, 'obfs4 b');
      final off = migrateBridges(upgrade: true, on: '0', lines: 'obfs4 c');
      expect(off.choice, BridgeChoice.direct);
      expect(off.offerAuto, isTrue);
      expect(off.consent, 'no');
      expect(off.friendLines, 'obfs4 c');
      final none = migrateBridges(upgrade: true);
      expect(none.choice, BridgeChoice.direct);
      final fresh = migrateBridges(upgrade: false);
      expect(fresh.choice, BridgeChoice.auto);
      expect(fresh.consent, 'ask');
    });

    for (final decoy in [false, true]) {
      test('from the store${decoy ? ', in a decoy' : ''}', () async {
        if (decoy) lockState.inDecoy = true;
        FlutterSecureStorage.setMockInitialValues({
          'bridges_on': '1',
          'bridge_source': 'moat',
          'bridge_lines': 'obfs4 192.0.2.1:443 A cert=x',
        });
        final app = AppState();
        final b = await app.readBridgeSetup(firstStart: false);
        expect(b.choice, BridgeChoice.torProject);
        expect(b.consent, 'no');
        const st = FlutterSecureStorage();
        expect(await st.read(key: 'bridge_mode'), 'moat');
        expect(
          await st.read(key: 'bridge_moat_lines'),
          'obfs4 192.0.2.1:443 A cert=x',
        );
        expect(await st.read(key: 'bridges_on'), isNull);
        expect(await st.read(key: 'bridge_source'), isNull);
        expect(await st.read(key: 'bridge_lines'), isNull);
        expect(app.firstRunAsk, isFalse);
        // the second start reads what was written
        final again = await AppState().readBridgeSetup(firstStart: false);
        expect(again.choice, BridgeChoice.torProject);
      });
    }

    test('a kill at any write keeps the tor project\'s lines', () async {
      const old = {
        'bridges_on': '1',
        'bridge_source': 'moat',
        'bridge_lines': 'obfs4 192.0.2.1:443 A cert=x',
      };
      addTearDown(() => bridgeWriteTap = null);
      for (var n = 0; ; n++) {
        FlutterSecureStorage.setMockInitialValues(Map.of(old));
        var i = 0;
        bridgeWriteTap = (k) {
          if (i++ == n) throw StateError('killed at $k');
        };
        var whole = true;
        try {
          await AppState().readBridgeSetup(firstStart: false);
        } on StateError {
          whole = false;
        }
        bridgeWriteTap = null;
        final b = await AppState().readBridgeSetup(firstStart: false);
        expect(b.choice, BridgeChoice.torProject, reason: 'kill $n');
        expect(b.torProjectLines, old['bridge_lines'], reason: 'kill $n');
        expect(b.friendLines, isEmpty, reason: 'kill $n');
        if (whole) break;
      }
    });

    test('not now comes back once, a week on', () async {
      FlutterSecureStorage.setMockInitialValues({'bridges_on': '0'});
      final app = AppState();
      app.bridgeSetupForTest = await app.readBridgeSetup(firstStart: false);
      expect(app.bridge.offerAuto, isTrue);
      await app.dismissAutoOffer();
      const st = FlutterSecureStorage();
      final v = await st.read(key: 'bridge_offer_auto');
      expect(v, startsWith('again:'));
      expect(
        (await AppState().readBridgeSetup(firstStart: false)).offerAuto,
        isFalse,
      );
      // a week on
      await st.write(key: 'bridge_offer_auto', value: 'again:1');
      final later = AppState();
      later.bridgeSetupForTest = await later.readBridgeSetup(firstStart: false);
      expect(later.bridge.offerAuto, isTrue);
      await later.dismissAutoOffer();
      expect(await st.read(key: 'bridge_offer_auto'), '0');
    });

    test('bridges off stays on tor alone and offers automatic', () async {
      FlutterSecureStorage.setMockInitialValues({'bridges_on': '0'});
      final b = await AppState().readBridgeSetup(firstStart: false);
      expect(b.choice, BridgeChoice.direct);
      expect(b.offerAuto, isTrue);
      expect(b.engineMode(), ('direct', '{}'));
    });

    test('a new install starts on automatic and is asked first', () async {
      final app = AppState();
      expect(await app.firstRunWanted(), isTrue);
      final b = await app.readBridgeSetup(firstStart: true);
      expect(b.choice, BridgeChoice.auto);
      expect(b.consent, 'ask');
      expect(app.firstRunAsk, isTrue);
      // nothing kept before the answer: a kill on the question asks again
      const st = FlutterSecureStorage();
      expect(await st.read(key: 'bridge_mode'), isNull);
      expect(await AppState().firstRunWanted(), isTrue);
      await app.pickFirstRun(risky: true);
      expect(await st.read(key: 'bridge_mode'), 'auto');
      expect(await AppState().firstRunWanted(), isFalse);
      expect(app.firstRunAsk, isFalse);
      expect(app.bridge.engineMode()!.$2, contains('"skip_direct":true'));
    });

    test('each choice, as the engine hears it', () {
      const lines =
          'obfs4 192.0.2.1:443 A cert=x\nwebtunnel [2001:db8::1]:443 B';
      expect(
        const BridgeSetup(
          consent: 'yes',
          friendLines: lines,
          country: 'ir',
        ).engineMode()!.$2,
        allOf(contains('"country":"ir"'), contains('"webtunnel"')),
      );
      expect(
        const BridgeSetup(
          choice: BridgeChoice.friend,
          friendLines: lines,
        ).engineMode()!.$1,
        'own',
      );
      expect(
        const BridgeSetup(choice: BridgeChoice.friend).engineMode(),
        isNull,
      );
      expect(const BridgeSetup(choice: BridgeChoice.snowflake).engineMode(), (
        'snowflake',
        '{}',
      ));
      expect(
        const BridgeSetup(
          choice: BridgeChoice.builtin,
        ).engineMode(builtin: ['obfs4 x'])!.$1,
        'moat',
      );
    });
  });

  group('the page', () {
    testWidgets('a way picked under more says so under the cards', (t) async {
      await _open(
        t,
        setup: const BridgeSetup(choice: BridgeChoice.builtin),
        status: const BridgeStatus(
          mode: 'moat',
          phase: 'connected',
          method: 'obfs4',
          source: 'moat',
          canSend: true,
        ),
        size: const Size(400, 1600),
      );
      expect(find.text(l10n.bridgesUsingBuiltIn), findsOneWidget);
      await t.tap(find.text(l10n.bridgesMore));
      await _in(t);
      // named by the pick, not by how the engine was handed it
      expect(find.textContaining(l10n.bridgesBuiltIn), findsWidgets);
      expect(
        find.textContaining(l10n.bridgesFromTheTorProjectLower),
        findsNothing,
      );
      await _done(t);
    });

    testWidgets('a removed line comes back with the undo', (t) async {
      await _open(
        t,
        setup: const BridgeSetup(
          choice: BridgeChoice.friend,
          friendLines:
              'obfs4 192.0.2.1:443 A cert=x\nobfs4 192.0.2.2:443 B cert=y',
        ),
        size: const Size(400, 1600),
      );
      await t.tap(find.text(l10n.bridgesMore));
      await _in(t);
      final x = find.byTooltip(l10n.bridgesRemoveBridgeN('2'));
      await t.ensureVisible(x);
      await t.tap(x);
      await _in(t);
      expect(splitBridgeLines(appState.bridge.friendLines), hasLength(1));
      await t.tap(find.text(l10n.bridgesUndo));
      await _in(t);
      expect(splitBridgeLines(appState.bridge.friendLines), hasLength(2));
      await _done(t);
    });

    testWidgets('a pasted line used leaves the clipboard', (t) async {
      String? clip = 'obfs4 192.0.2.1:443 AAAA cert=x';
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (c) async {
          if (c.method == 'Clipboard.getData') return {'text': clip};
          if (c.method == 'Clipboard.setData') {
            clip = (c.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await _open(t);
      await t.tap(find.text(l10n.bridgesBridgeFromAFriend));
      await _in(t);
      await t.tap(find.text(l10n.bridgesPasteFromClipboard));
      await _in(t);
      await t.tap(find.text(l10n.bridgesUseThisBridge(1)));
      await _in(t);
      expect(appState.bridgeChoice, BridgeChoice.friend);
      expect(clip, '');
      await _done(t);
    });

    test('a pick still waiting goes before the lock', () async {
      final app = AppState()..bridgeSetupForTest = const BridgeSetup();
      FlutterSecureStorage.setMockInitialValues({'bridge_mode': 'auto'});
      await app.loadBridgesForTest();
      _eng.calls.clear();
      await app.chooseBridge(BridgeChoice.direct);
      expect(_eng.calls, isEmpty);
      lockState.openForTest(enabled: true);
      lockState.lock();
      addTearDown(lockState.openForTest);
      expect(_eng.calls, ['direct {}']);
    });

    testWidgets('the dot rests after a few breaths, the clock goes on', (
      t,
    ) async {
      await _open(
        t,
        status: const BridgeStatus(
          mode: 'auto',
          phase: 'trying',
          sinceMs: 5000,
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(t.hasRunningAnimations, isFalse);
      expect(find.textContaining('0:1'), findsOneWidget);
      await _done(t);
    });

    testWidgets('right to left: the mark leads from the right', (t) async {
      await _open(t, locale: const Locale('ar'));
      final title = find.text(l10n.bridgesDirect);
      final card = find.ancestor(of: title, matching: find.byType(PressScale));
      final mark = find.descendant(
        of: card.first,
        matching: find.byWidgetPredicate(
          (w) => w is AnimatedScale && w.curve == kHouseCurve,
        ),
      );
      expect(t.getCenter(mark).dx, greaterThan(t.getCenter(title).dx));
      await _done(t);
    });

    testWidgets('less movement: nothing moves while tor tries', (t) async {
      await _open(t, status: _another, still: true);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(BreathDot), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await t.tap(find.text(l10n.bridgesMore));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await _done(t);
    });

    testWidgets('360 by 640 at a large text size, every language here', (
      t,
    ) async {
      final errs = <String>[];
      final was = FlutterError.onError;
      FlutterError.onError = (d) => errs.add(
        '${d.exceptionAsString().split('\n').first} '
        '${RegExp(r'The relevant error-causing widget was:\s*\n\s*.*\n\s*(.*)').firstMatch(d.toString())?.group(1)}',
      );
      try {
        for (final lang in [
          'en',
          'ar',
          'de',
          'es',
          'fa',
          'fr',
          'id',
          'it',
          'pt',
          'ru',
          'tr',
          'uk',
          'vi',
          'zh',
          'zh_Hant',
        ]) {
          // the phone's own height, and one tall enough to build it all
          for (final h in [640.0, 4000.0]) {
            final p = lang.split('_');
            await _open(
              t,
              locale: Locale.fromSubtags(
                languageCode: p[0],
                scriptCode: p.length > 1 ? p[1] : null,
              ),
              scale: 1.5,
              size: Size(360, h),
              setup: const BridgeSetup(
                choice: BridgeChoice.friend,
                friendLines: 'obfs4 192.0.2.1:443 A cert=x',
                torProjectLines: 'webtunnel [2001:db8::1]:443 B url=x',
                consent: 'yes',
                offerAuto: true,
              ),
              status: const BridgeStatus(mode: 'auto', phase: 'exhausted'),
            );
            if (h > 1000) {
              await t.tap(find.text(l10n.bridgesMore));
              await _in(t);
              expect(find.text(l10n.bridgesSavedLines), findsOneWidget);
              // the small buttons stay a finger high
              final edit = find.ancestor(
                of: find.text(l10n.commonEdit),
                matching: find.byType(PressScale),
              );
              expect(t.getSize(edit.first).height, greaterThanOrEqualTo(48));
            }
            await _done(t);
          }
        }
      } finally {
        FlutterError.onError = was;
      }
      expect(errs, isEmpty, reason: errs.toSet().join('\n'));
    });
  });

  // keeps the haptics channel quiet
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
}
