// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's notifications page and its icon and notifications page, pixel
// for pixel as they were before the desktop's tray section: nothing of it
// reaches the phone
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/battery_brand.dart' show PhoneBrand;
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/lock_guard.dart' show LockGuard;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useEngineForTest,
        AppStateRoute,
        AppStateDelivery;
import 'package:kryfo/notifications.dart';
import 'package:kryfo/screens/icon_screen.dart';
import 'package:kryfo/screens/notifications_screen.dart';
import 'package:kryfo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart' show devApp, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Faces implements AppFaceChannel {
  @override
  Future<AppFace?> read() async => AppFace.kryfo;
  @override
  Future<bool> switchTo(AppFace f) async => true;
}

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel c) async {}
}

Future<void> _world(WidgetTester t) async {
  expect(onDesktop, isFalse);
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  forgetAppFace();
  appFaceChannel = _Faces();
  FlutterLocalNotificationsPlatform.instance = _Shade();
  playBuildForTest = false;
  addTearDown(() => playBuildForTest = null);
  appState.sendModeForTest = 'private';
  appState.googleAvailableForTest = false;
  appState.deliveryModeForTest = DeliveryMode.always;
  useEngineForTest(_Engine());
  await devWorld();
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
  t.view.physicalSize = const Size(400, 1900);
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
  testWidgets('the phone notifications page is unchanged', (t) async {
    await _world(t);
    await t.pumpWidget(devApp(const NotificationsScreen(), still: true));
    await _settle(t);
    await expectLater(
      find.byType(NotificationsScreen),
      matchesGoldenFile('goldens/phone_notifications.png'),
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the phone icon and notifications page is unchanged', (t) async {
    await _world(t);
    await t.pumpWidget(
      devApp(
        IconScreen(
          hideLine: () async => hideAppsLine(PhoneBrand.samsung, 34),
          guard: LockGuard(isLocked: () => false),
          onSwitch: (_) async => true,
        ),
        still: true,
      ),
    );
    await _settle(t);
    await expectLater(
      find.byType(IconScreen),
      matchesGoldenFile('goldens/phone_icon_screen.png'),
    );
    await t.pumpWidget(const SizedBox());
  });
}
