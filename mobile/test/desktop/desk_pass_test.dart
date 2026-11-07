// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop pass: onboarding in a centred column with a tray step in
// place of the notification one, settings at reading width with a
// computer's words, the onion on the private card, no camera, and a right
// click for every hold
import 'dart:convert';
import 'dart:io';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_version.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute;
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/open_outside.dart' show openOutsideForTest;
import 'package:kryfo/store.dart' show playBuildForTest;
import 'package:kryfo/update_check.dart';
import 'package:kryfo/widgets/onion_loader.dart' show OnionMark;
import 'package:kryfo/widgets/press_scale.dart';
import 'package:kryfo/widgets/voice_mic.dart' show HoldToTalkMic;
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart' show devApp, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Run extends ChangeNotifier implements DesktopRunView {
  @override
  bool trayOn = true;
  @override
  bool? get trayShown => true;
  @override
  Future<void> setTray(bool on) async {
    trayOn = on;
    notifyListeners();
  }

  @override
  bool get canStart => true;
  @override
  StartAnswer? start = StartAnswer.off;
  @override
  bool get startRefused => false;
  @override
  Future<StartAnswer> setStart(bool on) async =>
      start = on ? StartAnswer.on : StartAnswer.off;
  @override
  Future<void> refresh() async {}
}

const _desk = Size(1280, 800);

Future<_Run> _world(WidgetTester t, {Size size = _desk}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  playBuildForTest = false;
  addTearDown(() => playBuildForTest = null);
  appState.sendModeForTest = 'private';
  useEngineForTest(_Engine());
  await devWorld();
  setL10nLocale(const Locale('en'));
  lockState.openForTest(enabled: false);
  addTearDown(lockState.openForTest);
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('halo/platform'),
    (c) async => c.method == 'isBatteryExempt' ? true : null,
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      null,
    ),
  );
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final run = _Run();
  onDesktop = true;
  desktopRun = run;
  addTearDown(() {
    onDesktop = false;
    desktopRun = null;
  });
  return run;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> _gone(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await _settle(t);
}

void main() {
  test('a computer swaps the delivery step for the tray one', () {
    expect(onboardingSteps(desk: true), [
      OnboardStep.welcome,
      OnboardStep.identity,
      OnboardStep.name,
      OnboardStep.route,
      OnboardStep.desk,
      OnboardStep.invite,
    ]);
    expect(onboardingSteps(), contains(OnboardStep.delivery));
  });

  testWidgets('onboarding keeps a centred column on a computer', (t) async {
    await _world(t);
    await t.pumpWidget(
      devApp(
        OnboardingScreen(appState: appState, onComplete: () {}),
        still: true,
      ),
    );
    await _settle(t);
    final begin = t.getRect(find.text(l10n.onboardingBegin));
    expect(begin.center.dx, closeTo(640, 1));
    final view = t.getRect(find.byType(PageView));
    expect(view.width, kDeskOnboardWidth);
    expect(view.center.dx, closeTo(640, 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_onboarding.png'),
    );
    await _gone(t);
  });

  testWidgets('the tray step offers both switches', (t) async {
    final run = await _world(t);
    final steps = onboardingSteps(desk: true);
    expect(steps.indexOf(OnboardStep.desk), 4);
    // the step on its own, as the pager shows it
    await t.pumpWidget(
      devApp(
        OnboardingScreen(appState: appState, onComplete: () {}),
        still: true,
      ),
    );
    await _settle(t);
    final pages = t.widget<PageView>(find.byType(PageView)).controller!;
    pages.jumpToPage(4);
    await _settle(t);
    expect(find.text(l10n.desktopTrayRow), findsOneWidget);
    expect(find.text(l10n.desktopStartRow), findsOneWidget);
    expect(find.textContaining('notification'), findsNothing);
    await t.tap(find.text(l10n.desktopTrayRow));
    await _settle(t);
    expect(run.trayOn, isFalse);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_onboarding_tray.png'),
    );
    await _gone(t);
  });

  // a computer has no store: the switch and a check by hand are its only
  // way to hear of a new version, over tor and signed as on the phone
  testWidgets('a computer offers the update check and a check now', (t) async {
    await _world(t, size: const Size(1280, 2600));
    final k = ed.generateKey();
    var served = '9.0.0';
    var tor = true;
    String? sigFor;
    final asked = <String>[];
    final opened = <Uri>[];
    openOutsideForTest = (u) async {
      opened.add(u);
      return true;
    };
    addTearDown(() {
      openOutsideForTest = null;
      updateNoticeForTest = null;
    });
    updateNoticeForTest = UpdateNotice(
      get: (url) async {
        asked.add(url);
        final body = '{"app":"kryfo","version":"$served"}\n';
        if (url == kVersionUrl) return body;
        return sigFor ??
            base64.encode(ed.sign(k.privateKey, utf8.encode(body)));
      },
      torUp: () => tor,
      quiet: () => false,
      container: () => HaloContainer.everyday,
      playBuild: false,
      pause: () async {},
      stall: () async {},
      pubKeyB64: base64.encode(k.publicKey.bytes),
    );
    await t.pumpWidget(devApp(const SettingsScreen(), still: true));
    await _settle(t);
    expect(find.text(l10n.settingsCheckForUpdates), findsOneWidget);
    final now = find.text(l10n.settingsCheckNow);
    expect(now, findsOneWidget);
    asked.clear();

    Future<void> tapNow() async {
      await t.ensureVisible(now);
      await t.tap(now);
      await _settle(t);
    }

    // newer: the card's words, and the download page on yes
    await tapNow();
    expect(asked, [kVersionUrl, kVersionSigUrl]);
    expect(find.text(l10n.updateReady('9.0.0')), findsOneWidget);
    await t.tap(find.text(l10n.updateOpenPage));
    await _settle(t);
    expect(opened.single.toString(), 'https://kryfo.app/download');

    // the same version
    served = kAppVersion;
    await tapNow();
    expect(find.text(l10n.updateNewest), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await _settle(t);

    // a forged signature, then no tor
    served = '9.9.9';
    sigFor = base64.encode(
      ed.sign(ed.generateKey().privateKey, utf8.encode('x')),
    );
    await tapNow();
    expect(find.text(l10n.updateCouldNotCheck), findsOneWidget);
    expect(find.text(l10n.updateReady('9.9.9')), findsNothing);
    await t.pump(const Duration(seconds: 5));
    await _settle(t);
    tor = false;
    asked.clear();
    await tapNow();
    expect(asked, isEmpty);
    expect(find.text(l10n.updateCouldNotCheck), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await _gone(t);
  });

  testWidgets('settings on a computer: reading width, its own words', (
    t,
  ) async {
    final run = await _world(t, size: const Size(1280, 2600));
    await t.pumpWidget(devApp(const SettingsScreen(), still: true));
    await _settle(t);
    final row = t.getRect(find.text(l10n.languageTitle));
    expect(row.left, greaterThan((1280 - 720) / 2));
    expect(find.text('Not on this computer yet'), findsNothing);
    expect(find.text('Screenshots'), findsNothing);
    expect(find.text(l10n.settingsVersionAlpha(kAppVersion)), findsOneWidget);
    expect(find.text(l10n.settingsTheOfflineMapIn), findsNothing);
    expect(find.textContaining(l10n.settingsDeskInTray), findsOneWidget);
    await run.setTray(false);
    await t.pump();
    expect(find.textContaining(l10n.settingsDeskWhileOpen), findsOneWidget);
    await run.setTray(true);
    await _settle(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_settings.png'),
    );
    await _gone(t);
  });

  testWidgets('speed and privacy: the onion, and no promise line', (t) async {
    await _world(t);
    await t.pumpWidget(devApp(const ModesScreen(), still: true));
    await _settle(t);
    expect(find.byType(OnionMark), findsOneWidget);
    expect(find.textContaining('Never what you say'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_modes.png'),
    );
    await _gone(t);
  });

  testWidgets('a right click is the hold on a computer, never on a phone', (
    t,
  ) async {
    var held = 0;
    Widget box() => devApp(
      Center(
        child: PressScale(
          onTap: () {},
          onLongPress: () => held++,
          child: const SizedBox(width: 80, height: 80),
        ),
      ),
    );
    await t.pumpWidget(box());
    await t.tap(find.byType(PressScale), buttons: kSecondaryButton);
    expect(held, 0);
    onDesktop = true;
    addTearDown(() => onDesktop = false);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(box());
    await t.tap(find.byType(PressScale), buttons: kSecondaryButton);
    expect(held, 1);
  });

  test('no camera button on a computer, the file picker stays', () {
    for (final (f, keys) in [
      ('lib/screens/chat_screen.dart', ['chatOpenTheCamera', 'chatCamera,']),
      (
        'lib/screens/group_chat_screen.dart',
        ['groupChatOpenTheCamera', 'groupChatCamera,'],
      ),
    ]) {
      final s = File(f).readAsStringSync();
      for (final k in keys) {
        final at = s.indexOf('l10n.$k');
        expect(at, greaterThan(0), reason: '$f $k');
        expect(
          s.substring(at - 400, at),
          contains('if (!onDesktop'),
          reason: '$f $k',
        );
      }
    }
  });

  test('the bubbles and list rows open their menus on a right click', () {
    for (final (f, n) in [
      ('lib/screens/chat_screen.dart', 2),
      ('lib/screens/group_chat_screen.dart', 3),
      ('lib/screens/home_screen.dart', 3),
      ('lib/widgets/press_scale.dart', 1),
    ]) {
      final s = File(f).readAsStringSync();
      expect('onSecondaryTap:'.allMatches(s).length, n, reason: f);
    }
  });

  testWidgets('a double click on send never starts a voice note', (t) async {
    onDesktop = true;
    addTearDown(() => onDesktop = false);
    const rec = MethodChannel('com.llfbandit.record/messages');
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(rec, (_) async => null);
    addTearDown(() => m.setMockMethodCallHandler(rec, null));
    var asked = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: HoldToTalkMic(
              disguise: false,
              onSend: (_) {},
              mayRecord: () {
                asked++;
                return false;
              },
            ),
          ),
        ),
      ),
    );
    // the click right after the mic took send's place
    await t.tap(find.byType(HoldToTalkMic));
    await t.pump();
    expect(asked, 0);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await t.tap(find.byType(HoldToTalkMic));
    await t.pump();
    expect(asked, 1);
  });
}
