// SPDX-License-Identifier: GPL-3.0-or-later
// a new install that says tor is blocked or watched: bridges only, no relay
// or fast on the way in (the route step shows private alone), while relay stays in settings and in the offer when
// nothing got through, after the bridge way. closing the sheet leaves the
// question
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute, AppStateBridges;
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/widgets/card_action.dart';
import 'package:kryfo/widgets/tor_boot_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devHome, devWorld;
import 'narrow_settings.dart' show loadAppFonts;

class _Engine implements HaloEngine {
  final modes = <String>[];
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  String bridgeLineChecks() => '[]';
  @override
  List<String> builtinBridges(String transport) => const [];
  @override
  String setTransportMode(String mode) {
    modes.add(mode);
    return 'ok';
  }

  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

late _Engine _eng;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _eng = _Engine();
    useEngineForTest(_eng);
    await devWorld();
    appState.sendModeForTest = 'private';
    // a new install, asked before tor starts
    appState.bridgeSetupForTest = await appState.readBridgeSetup(
      firstStart: true,
    );
  });

  tearDown(() {
    appState.bridgeSetupForTest = const BridgeSetup();
    setL10nLocale(const Locale('en'));
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(411, 891);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  Future<void> openSheet(WidgetTester t, {bool still = false}) async {
    phone(t);
    expect(appState.firstRunAsk, isTrue);
    await t.pumpWidget(devApp(const TorBootSplash(), still: still));
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text(l10n.torBootSplashTorIsBlockedHere));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> done(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  // the route step: [check] sees the cards, [pick] is tapped, then continue
  // writes the route
  Future<void> throughRoute(
    WidgetTester t, {
    void Function()? check,
    String? pick,
  }) async {
    phone(t);
    await t.pumpWidget(
      devApp(OnboardingScreen(appState: appState, onComplete: () {})),
    );
    await t.pump(const Duration(seconds: 6));
    final pages = t.widget<PageView>(find.byType(PageView)).controller!;
    pages.jumpToPage(3);
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(find.text(l10n.modesPrivate), findsOneWidget);
    check?.call();
    if (pick != null) {
      await t.tap(find.text(pick));
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.tap(find.text(l10n.onboardingContinue));
    await t.pump();
    // the route is written first, then the step moves on
    for (var i = 0; i < 30 && pages.page != 4; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(pages.page, 4);
  }

  // the card picked on the route step, or not
  void routeOn(WidgetTester t, String title, bool on) =>
      expect(t.getSemantics(find.text(title)), isSemantics(isChecked: on));

  group('the first start', () {
    for (final still in [false, true]) {
      testWidgets('bridges only, no relay (still: $still)', (t) async {
        await openSheet(t, still: still);
        expect(
          find.text(l10n.torBootSplashStartThroughABridge),
          findsOneWidget,
        );
        expect(
          find.text(l10n.torBootSplashNeverTriesTorPlainly),
          findsOneWidget,
        );
        expect(find.text(l10n.modesFast), findsNothing);
        expect(find.text(l10n.modesFast), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.checked != null,
          ),
          findsNothing,
        );
        expect(find.text(l10n.commonContinue), findsOneWidget);
        if (still) expect(t.hasRunningAnimations, isFalse);
        await done(t);
      });
    }

    testWidgets('continue: through bridges, page shown', (t) async {
      await openSheet(t);
      await t.tap(find.text(l10n.commonContinue));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(appState.firstRunAsk, isFalse);
      expect(appState.bridge.choice, BridgeChoice.auto);
      expect(appState.bridge.skipDirect, isTrue);
      expect(appState.sendMode, 'private');
      expect(find.byType(BridgesScreen), findsOneWidget);
      await done(t);
    });

    testWidgets('closed without an answer: the question stays', (t) async {
      await openSheet(t);
      await t.tapAt(const Offset(200, 40));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.torBootSplashStartThroughABridge), findsNothing);
      expect(appState.firstRunAsk, isTrue);
      expect(find.text(l10n.torBootSplashConnect), findsOneWidget);
      expect(find.text(l10n.torBootSplashTorIsBlockedHere), findsOneWidget);
      await done(t);
    });
  });

  testWidgets('relay stays in settings, blocked or watched too', (t) async {
    await appState.pickFirstRun(risky: true);
    phone(t);
    await t.pumpWidget(devApp(const ModesScreen()));
    await t.pump(const Duration(seconds: 2));
    final relay = find.text(l10n.modesFast);
    await t.ensureVisible(relay);
    await t.pump();
    expect(relay.hitTestable(), findsOneWidget);
    await done(t);
  });

  testWidgets('the sheet fits a small phone, every language', (t) async {
    await t.runAsync(loadAppFonts);
    phone(t);
    t.view.physicalSize = const Size(360, 640);
    final errs = <String>[];
    final was = FlutterError.onError;
    var now = '';
    FlutterError.onError = (d) =>
        errs.add('$now: ${d.exceptionAsString().split('\n').first}');
    try {
      for (final lang in [
        'en', 'ar', 'de', 'es', 'fa', 'fr', 'id', 'it', //
        'pt', 'ru', 'tr', 'uk', 'vi', 'zh', 'zh_Hant',
      ]) {
        final p = lang.split('_');
        final locale = Locale.fromSubtags(
          languageCode: p[0],
          scriptCode: p.length > 1 ? p[1] : null,
        );
        setL10nLocale(locale);
        for (final scale in [1.0, 1.5]) {
          now = '$lang x$scale';
          FlutterSecureStorage.setMockInitialValues({});
          appState.bridgeSetupForTest = await appState.readBridgeSetup(
            firstStart: true,
          );
          await t.pumpWidget(
            devApp(const TorBootSplash(), locale: locale, scale: scale),
          );
          await t.pump(const Duration(seconds: 2));
          final blocked = find.text(l10n.torBootSplashTorIsBlockedHere);
          await t.ensureVisible(blocked);
          await t.pump();
          await t.tap(blocked);
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          final go = find.text(l10n.commonContinue);
          await t.ensureVisible(go);
          await t.pump();
          expect(go.hitTestable(), findsOneWidget, reason: now);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        }
      }
    } finally {
      FlutterError.onError = was;
    }
    expect(errs, isEmpty, reason: errs.toSet().join('\n'));
  });

  testWidgets('relay taken where nothing got through stays the pick', (
    t,
  ) async {
    await openSheet(t);
    await t.tap(find.text(l10n.commonContinue));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(BridgesScreen), findsOneWidget);
    appState.setBridgeStatusForTest(
      const BridgeStatus(mode: 'auto', phase: 'exhausted'),
    );
    // the line rises in before its buttons take a tap
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    // what relay costs here, and the bridge way first
    expect(find.text(l10n.bridgesRelayThisNetworkSees), findsOneWidget);
    expect(
      t.getRect(find.text(l10n.bridgesGetABridge)).top,
      lessThan(t.getRect(find.text(l10n.homeUseFast)).top),
    );
    await t.tap(find.text(l10n.homeUseFast));
    for (
      var i = 0;
      i < 50 && find.text(l10n.homeSwitchedToFastRoute).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(appState.sendMode, 'balanced');
    await done(t);
    // the route step offers fast beside private here, and keeps it picked
    final sem = t.ensureSemantics();
    await throughRoute(
      t,
      check: () {
        expect(find.text(l10n.modesFast), findsOneWidget);
        routeOn(t, l10n.modesFast, true);
        routeOn(t, l10n.modesPrivate, false);
      },
    );
    expect(appState.sendMode, 'balanced');
    sem.dispose();
    await done(t);
  });

  testWidgets('relay taken, then onion again: setup keeps onion', (t) async {
    await openSheet(t);
    await t.tap(find.text(l10n.commonContinue));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    appState.setBridgeStatusForTest(
      const BridgeStatus(mode: 'auto', phase: 'exhausted'),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text(l10n.homeUseFast));
    for (var i = 0; i < 50 && appState.sendMode != 'balanced'; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(appState.sendMode, 'balanced');
    await done(t);
    // back to onion before the send step: relay is not the mode now
    await t.runAsync(() => appState.setSendMode('private'));
    expect(appState.sendMode, 'private');
    await throughRoute(
      t,
      check: () => expect(find.text(l10n.modesFast), findsNothing),
    );
    expect(appState.sendMode, 'private');
    await done(t);
  });

  for (final watched in [true, false]) {
    testWidgets('the home card when nothing got through '
        '(blocked or watched: $watched)', (t) async {
      phone(t);
      appState.bridgeSetupForTest = BridgeSetup(skipDirect: watched);
      appState.setBridgeStatusForTest(
        const BridgeStatus(mode: 'auto', phase: 'exhausted'),
      );
      addTearDown(() => appState.setBridgeStatusForTest(BridgeStatus.none));
      expect(appState.homeBridgeCard, 'auto');
      await t.pumpWidget(devApp(devHome()));
      await t.pump(const Duration(seconds: 2));
      CardAction card(String label) => t.widget<CardAction>(
        find.ancestor(of: find.text(label), matching: find.byType(CardAction)),
      );
      final relay = t.getRect(find.text(l10n.homeUseFast));
      final ask = t.getRect(find.text(l10n.bridgesGetABridge));
      // either way: the bridge way first and filled, fast last with its
      // cost
      expect(find.text(l10n.bridgesRelayThisNetworkSees), findsOneWidget);
      expect(ask.left, lessThan(relay.left));
      expect(card(l10n.bridgesGetABridge).fill, isNotNull);
      expect(card(l10n.homeUseFast).fill, isNull);
      await done(t);
    });
  }

  // tor alone not getting through: let kryfo find a bridge first, filled,
  // and fast after it, quiet, with what this network sees on it
  testWidgets('tor seems blocked: the bridge way first, fast last', (t) async {
    phone(t);
    appState.bridgeSetupForTest = const BridgeSetup(
      choice: BridgeChoice.direct,
    );
    appState.torTryingSinceForTest = DateTime.now().subtract(
      const Duration(minutes: 5),
    );
    addTearDown(() => appState.torTryingSinceForTest = null);
    expect(appState.homeBridgeCard, 'hint');
    await t.pumpWidget(devApp(devHome()));
    await t.pump(const Duration(seconds: 2));
    CardAction card(String label) => t.widget<CardAction>(
      find.ancestor(of: find.text(label), matching: find.byType(CardAction)),
    );
    expect(find.text(l10n.bridgesBridgeFirstFastSeen), findsOneWidget);
    final auto = t.getRect(find.text(l10n.bridgesTryAutomatic));
    final fast = t.getRect(find.text(l10n.homeUseFast));
    // in reading order, on one line or wrapped
    expect(
      auto.top < fast.top - 1 ||
          ((auto.top - fast.top).abs() <= 1 && auto.left < fast.left),
      isTrue,
    );
    expect(card(l10n.bridgesTryAutomatic).fill, isNotNull);
    expect(card(l10n.homeUseFast).fill, isNull);
    await done(t);
  });

  // the route step: private picked and written on continue. blocked or
  // watched, it is the only card, with no radio: fast is a plain line a
  // watcher sees, and stays in settings
  for (final risky in [false, true]) {
    testWidgets('the route step keeps private (blocked: $risky)', (t) async {
      await appState.pickFirstRun(risky: risky);
      final sem = t.ensureSemantics();
      await throughRoute(
        t,
        check: () {
          expect(find.text(l10n.modesFast), risky ? findsNothing : findsOne);
          expect(
            find.text(l10n.onboardingRouteBlockedLead),
            risky ? findsOne : findsNothing,
          );
          routeOn(t, l10n.modesPrivate, !risky);
        },
      );
      expect(appState.sendMode, 'private');
      sem.dispose();
      await done(t);
    });
  }

  testWidgets('fast picked on the route step is written', (t) async {
    await appState.pickFirstRun(risky: false);
    await throughRoute(t, pick: l10n.modesFast);
    expect(appState.sendMode, 'balanced');
    await done(t);
  });
}
