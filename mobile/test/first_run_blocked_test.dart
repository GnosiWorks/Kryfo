// SPDX-License-Identifier: GPL-3.0-or-later
// a new install that says tor is blocked: automatic comes first, picked
// already and marked recommended, relay next with what it costs. either
// way works, closing the sheet leaves the question, and the send step
// follows the answer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/widgets/tor_boot_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devWorld;
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

  bool checked(WidgetTester t, String title) => t
      .widget<Semantics>(
        find
            .ancestor(
              of: find.text(title),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.checked != null,
              ),
            )
            .first,
      )
      .properties
      .checked!;

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

  group('the first start', () {
    for (final still in [false, true]) {
      testWidgets('automatic first, picked and recommended (still: $still)', (
        t,
      ) async {
        await openSheet(t, still: still);
        expect(find.text(l10n.torBootSplashTwoWaysAround), findsOneWidget);
        final auto = t.getRect(find.text(l10n.bridgesAutomatic));
        final relay = t.getRect(find.text(l10n.onboardingRelay));
        expect(auto.top, lessThan(relay.top));
        expect(find.text(l10n.bridgesRecommended), findsOneWidget);
        // the pill sits with automatic, not with relay
        expect(
          (t.getRect(find.text(l10n.bridgesRecommended)).center.dy -
                  auto.center.dy)
              .abs(),
          lessThan(20),
        );
        expect(checked(t, l10n.bridgesAutomatic), isTrue);
        expect(checked(t, l10n.onboardingRelay), isFalse);
        expect(find.text(l10n.torBootSplashRelayLine), findsOneWidget);
        if (still) expect(t.hasRunningAnimations, isFalse);
        await done(t);
      });
    }

    testWidgets('continue on automatic: through bridges, page shown', (
      t,
    ) async {
      await openSheet(t);
      await t.tap(find.text(l10n.commonContinue));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(appState.firstRunAsk, isFalse);
      expect(appState.firstRunRelay, isFalse);
      expect(appState.bridge.choice, BridgeChoice.auto);
      expect(appState.bridge.skipDirect, isTrue);
      expect(find.byType(BridgesScreen), findsOneWidget);
      await done(t);
    });

    testWidgets('relay picked: answered, no bridges page, relay remembered', (
      t,
    ) async {
      await openSheet(t);
      await t.tap(find.text(l10n.onboardingRelay));
      await t.pump(const Duration(milliseconds: 300));
      expect(checked(t, l10n.onboardingRelay), isTrue);
      expect(checked(t, l10n.bridgesAutomatic), isFalse);
      await t.tap(find.text(l10n.commonContinue));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(appState.firstRunAsk, isFalse);
      expect(appState.firstRunRelay, isTrue);
      // tor never goes out plain from here either
      expect(appState.bridge.skipDirect, isTrue);
      expect(find.byType(BridgesScreen), findsNothing);
      await done(t);
    });

    testWidgets('closed without an answer: the question stays', (t) async {
      await openSheet(t);
      await t.tapAt(const Offset(200, 40));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.torBootSplashTwoWaysAround), findsNothing);
      expect(appState.firstRunAsk, isTrue);
      expect(find.text(l10n.torBootSplashConnect), findsOneWidget);
      expect(find.text(l10n.torBootSplashTorIsBlockedHere), findsOneWidget);
      await done(t);
    });
  });

  testWidgets('the sheet and the send step fit a small phone, every language', (
    t,
  ) async {
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
          await appState.pickFirstRun(risky: true);
          await t.pumpWidget(
            devApp(
              OnboardingScreen(appState: appState, onComplete: () {}),
              locale: locale,
              scale: scale,
            ),
          );
          await t.pump(const Duration(seconds: 6));
          t.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          expect(
            find.text(l10n.onboardingKeepOnion).hitTestable(),
            findsOneWidget,
            reason: now,
          );
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        }
      }
    } finally {
      FlutterError.onError = was;
    }
    expect(errs, isEmpty, reason: errs.toSet().join('\n'));
  });

  group('the send step', () {
    Future<void> toSend(WidgetTester t) async {
      phone(t);
      await t.pumpWidget(
        devApp(OnboardingScreen(appState: appState, onComplete: () {})),
      );
      await t.pump(const Duration(seconds: 6));
      t.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('tor not blocked: as before', (t) async {
      await appState.pickFirstRun(risky: false);
      await toSend(t);
      expect(find.text(l10n.bridgesRecommended), findsNothing);
      expect(find.text(l10n.onboardingHidesYourAddressFrom), findsOneWidget);
      expect(find.text(l10n.onboardingAboutASecondWorks), findsOneWidget);
      expect(checked(t, l10n.onboardingOnion), isTrue);
      await done(t);
    });

    testWidgets('blocked, automatic: onion leads, picked and recommended', (
      t,
    ) async {
      await appState.pickFirstRun(risky: true);
      await toSend(t);
      expect(find.text(l10n.bridgesRecommended), findsOneWidget);
      expect(find.text(l10n.onboardingAutoFindsAWay), findsOneWidget);
      expect(find.text(l10n.onboardingAboutASecondSkipsTor), findsOneWidget);
      expect(find.text(l10n.onboardingAboutASecondWorks), findsNothing);
      expect(
        t.getRect(find.text(l10n.onboardingOnion)).top,
        lessThan(t.getRect(find.text(l10n.onboardingRelay)).top),
      );
      expect(checked(t, l10n.onboardingOnion), isTrue);
      // relay is still there to take
      await t.tap(find.text(l10n.onboardingRelay));
      await t.pump(const Duration(milliseconds: 300));
      expect(checked(t, l10n.onboardingRelay), isTrue);
      await t.tap(find.text(l10n.onboardingUseThis));
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump(const Duration(seconds: 1));
      expect(appState.sendMode, 'balanced');
      await done(t);
    });

    testWidgets('blocked, relay picked at the start: relay picked here', (
      t,
    ) async {
      await appState.pickFirstRun(risky: true, relay: true);
      await toSend(t);
      expect(checked(t, l10n.onboardingRelay), isTrue);
      expect(checked(t, l10n.onboardingOnion), isFalse);
      // onion through automatic is one tap back
      await t.tap(find.text(l10n.onboardingOnion));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text(l10n.onboardingKeepOnion));
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump(const Duration(seconds: 1));
      expect(appState.sendMode, 'private');
      await done(t);
    });
  });
}
