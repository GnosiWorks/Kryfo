// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's settings, speed and privacy and first onboarding step, pixel
// for pixel: nothing of the desktop pass reaches the phone but the onion on
// the private card and the fast card's line, which it now shares
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute;
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/store.dart' show playBuildForTest;
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart' show devApp, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _world(WidgetTester t, Size size) async {
  expect(onDesktop, isFalse);
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
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(seconds: 1));
  }
}

void main() {
  for (final (name, size, page) in <(String, Size, Widget Function())>[
    ('settings', const Size(400, 2900), () => const SettingsScreen()),
    ('modes', const Size(400, 900), () => const ModesScreen()),
    (
      'onboarding',
      const Size(400, 860),
      () => OnboardingScreen(appState: appState, onComplete: () {}),
    ),
  ]) {
    testWidgets('the phone $name page stays as it is', (t) async {
      await _world(t, size);
      await t.pumpWidget(devApp(page(), still: true));
      await _settle(t);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/phone_pass_$name.png'),
      );
      await t.pumpWidget(const SizedBox());
      await _settle(t);
    });
  }
}
