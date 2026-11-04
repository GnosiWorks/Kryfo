// SPDX-License-Identifier: GPL-3.0-or-later
// the notifications screen: how messages reach you, sound and vibration,
// what notifications show and battery tips, in that order. google push
// first and recommended in a play build with play services, never in foss.
// the sound row opens android's page for the messages channel. large text
// and right-to-left lay it out without overflow
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useEngineForTest,
        AppStateRoute,
        AppStateDelivery;
import 'package:kryfo/notifications.dart' show forgetNotifPlain;
import 'package:kryfo/screens/notifications_screen.dart';
import 'package:kryfo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _open(
  WidgetTester t, {
  bool play = false,
  bool google = false,
  String route = 'private',
  double scale = 1,
  Locale? locale,
  Size size = const Size(400, 3200),
}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  playBuildForTest = play;
  addTearDown(() => playBuildForTest = null);
  appState.sendModeForTest = route;
  appState.googleAvailableForTest = google;
  appState.deliveryModeForTest = DeliveryMode.always;
  addTearDown(() => appState.googleAvailableForTest = false);
  useEngineForTest(_Engine());
  await devWorld();
  lockState.openForTest(enabled: false);
  addTearDown(lockState.openForTest);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    devApp(const NotificationsScreen(), scale: scale, locale: locale),
  );
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

double _y(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  tearDown(() => openSoundForTest = null);

  testWidgets('the title and its four parts, in order', (t) async {
    await _open(t);
    expect(find.text(l10n.settingsNotifications), findsOneWidget);
    final parts = [
      l10n.notificationsHowTheyReachYou,
      l10n.notificationsSoundAndVibration,
      l10n.gettingMessagesWhatShows,
      l10n.notificationsBatteryTips,
    ];
    for (var i = 1; i < parts.length; i++) {
      expect(_y(t, parts[i]), greaterThan(_y(t, parts[i - 1])));
    }
    // the ways sit in the first part, battery's row in the last
    expect(_y(t, l10n.gettingMessagesAlwaysOn), lessThan(_y(t, parts[1])));
    expect(_y(t, l10n.settingsRunInBackground), greaterThan(_y(t, parts[3])));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('always on says nothing leaves tor, and most private, only '
      'on the private route', (t) async {
    await _open(t);
    expect(
      find.text(l10n.gettingMessagesMessagesArriveInstantlyNothing),
      findsOneWidget,
    );
    expect(find.text(l10n.gettingMessagesArriveInstantlyFast), findsNothing);
    expect(find.text(l10n.gettingMessagesMostPrivate), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await _open(t, route: 'balanced');
    // nor is it the most private way there
    expect(find.text(l10n.gettingMessagesMostPrivate), findsNothing);
    expect(
      find.text(l10n.gettingMessagesMessagesArriveInstantlyNothing),
      findsNothing,
    );
    expect(find.text(l10n.gettingMessagesArriveInstantlyFast), findsOneWidget);
    appState.sendModeForTest = 'private';
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('foss: no google push', (t) async {
    await _open(t, google: true);
    expect(find.text(l10n.deliveryModeGooglePush), findsNothing);
    expect(find.text(l10n.notificationsRecommended), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('play without play services: no google push', (t) async {
    await _open(t, play: true);
    expect(find.text(l10n.deliveryModeGooglePush), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('play with play services: google push first, '
      'recommended', (t) async {
    await _open(t, play: true, google: true);
    expect(find.text(l10n.deliveryModeGooglePush), findsOneWidget);
    expect(find.text(l10n.notificationsRecommended), findsOneWidget);
    expect(find.text(l10n.notificationsGoogleBody), findsOneWidget);
    expect(
      _y(t, l10n.deliveryModeGooglePush),
      lessThan(_y(t, l10n.gettingMessagesAlwaysOn)),
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the sound row opens android\'s messages channel', (t) async {
    var opened = 0;
    openSoundForTest = () async {
      opened++;
      return true;
    };
    await _open(t);
    await t.tap(find.text(l10n.notificationsChannelName));
    await t.pump();
    expect(opened, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a channel page that will not open is said', (t) async {
    openSoundForTest = () async => false;
    await _open(t);
    await t.tap(find.text(l10n.notificationsChannelName));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.homeCouldnTOpenIt), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('large text and right-to-left lay out whole', (t) async {
    await _open(
      t,
      play: true,
      google: true,
      scale: 2,
      size: const Size(360, 6000),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await _open(
      t,
      play: true,
      google: true,
      scale: 1.6,
      locale: const Locale('ar'),
      size: const Size(360, 6000),
    );
    expect(t.takeException(), isNull);
    expect(
      Directionality.of(t.element(find.byType(NotificationsScreen))),
      TextDirection.rtl,
    );
    await t.pumpWidget(const SizedBox());
  });
}
