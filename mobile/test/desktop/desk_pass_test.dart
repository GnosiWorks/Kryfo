// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop pass: onboarding in a centred column with a tray step in
// place of the notification one, settings at reading width with a
// computer's words, the onion on the private card, no camera, and a right
// click for every hold
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_version.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute;
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/store.dart' show playBuildForTest;
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
  test('a computer swaps the notification step for the tray one', () {
    expect(onboardingSteps(play: false, desk: true), [
      OnboardStep.welcome,
      OnboardStep.identity,
      OnboardStep.name,
      OnboardStep.desk,
      OnboardStep.invite,
    ]);
    expect(onboardingSteps(play: false), contains(OnboardStep.notify));
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
    final steps = onboardingSteps(play: false, desk: true);
    expect(steps.indexOf(OnboardStep.desk), 3);
    // the step on its own, as the pager shows it
    await t.pumpWidget(
      devApp(
        OnboardingScreen(appState: appState, onComplete: () {}),
        still: true,
      ),
    );
    await _settle(t);
    final pages = t.widget<PageView>(find.byType(PageView)).controller!;
    pages.jumpToPage(3);
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

  testWidgets('settings on a computer: reading width, its own words', (
    t,
  ) async {
    final run = await _world(t, size: const Size(1280, 2600));
    await t.pumpWidget(devApp(const SettingsScreen(), still: true));
    await _settle(t);
    final row = t.getRect(find.text(l10n.languageTitle));
    expect(row.left, greaterThan((1280 - 720) / 2));
    expect(find.text(l10n.settingsShotsNotHereYet), findsOneWidget);
    expect(find.text(l10n.settingsPerChat), findsNothing);
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
