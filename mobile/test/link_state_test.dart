// SPDX-License-Identifier: GPL-3.0-or-later
// one meaning of connected: the home pill, getting messages and the settings
// card agree, in relay mode where tor never matters and in onion mode where
// tor's word is not enough while no relay gets through. a send left
// 'sending' settles by the same rule in a group as in a 1:1 chat
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show TorHalo, appState;
import 'package:kryfo/media_send.dart' show mediaInflight;
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

void _set(String mode, TorStatus s, {bool route = true}) {
  appState.sendModeForTest = mode;
  appState.setTorStatusForTest(s);
  appState.setRouteOKForTest(route);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => _set('private', TorStatus.off));

  group('connected', () {
    test('relay mode does not wait on tor', () {
      _set('balanced', TorStatus.starting);
      expect(appState.linkUp, isTrue);
      expect(appState.linkComing, isFalse);
    });

    test('onion mode needs a route that carries traffic', () {
      _set('private', TorStatus.publishing, route: false);
      expect(appState.linkUp, isFalse);
      expect(appState.linkComing, isTrue);
      _set('private', TorStatus.publishing);
      expect(appState.linkUp, isTrue);
      expect(appState.linkComing, isFalse);
      _set('private', TorStatus.off);
      expect(appState.linkUp, isFalse);
      expect(appState.linkComing, isFalse);
    });

    testWidgets('the pill is not ready over a route nothing gets through', (
      t,
    ) async {
      _set('private', TorStatus.publishing, route: false);
      await t.pumpWidget(app(const Center(child: TorHalo(label: true))));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.appTorReady), findsNothing);
      expect(find.text(l10n.appConnecting2), findsOneWidget);

      _set('private', TorStatus.publishing);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.appTorReady), findsOneWidget);
    });

    testWidgets('getting messages says connected in relay mode', (t) async {
      phone(t);
      _set('balanced', TorStatus.starting);
      await t.pumpWidget(app(const GettingMessagesScreen()));
      await t.pump(const Duration(seconds: 2));
      expect(appState.deliveryMode, DeliveryMode.always);
      expect(find.text(l10n.deliveryModeConnected), findsOneWidget);
      expect(find.text(l10n.deliveryModeConnecting), findsNothing);
    });

    testWidgets('getting messages is not connected while no relay gets '
        'through', (t) async {
      phone(t);
      _set('private', TorStatus.publishing, route: false);
      await t.pumpWidget(app(const GettingMessagesScreen()));
      await t.pump(const Duration(seconds: 2));
      expect(find.text(l10n.deliveryModeConnected), findsNothing);
      expect(find.text(l10n.deliveryModeConnecting), findsOneWidget);
    });
  });

  group('a send left sending', () {
    final now = DateTime(2026, 10, 1, 12);
    final old = now.subtract(const Duration(seconds: 61));
    final fresh = now.subtract(const Duration(seconds: 30));

    test('is dead once the route is up, published or not', () {
      _set('private', TorStatus.publishing);
      expect(appState.sendLooksDead(old, now: now), isTrue);
      expect(appState.sendLooksDead(fresh, now: now), isFalse);
      _set('balanced', TorStatus.starting);
      expect(appState.sendLooksDead(old, now: now), isTrue);
    });

    test('is queued, not dead, while the route is down', () {
      _set('private', TorStatus.starting);
      expect(appState.sendLooksDead(old, now: now), isFalse);
      _set('private', TorStatus.publishing, route: false);
      expect(appState.sendLooksDead(old, now: now), isFalse);
    });

    test('is never a file still going out', () {
      _set('private', TorStatus.publishing);
      mediaInflight.add('uid-file');
      addTearDown(() => mediaInflight.remove('uid-file'));
      expect(
        appState.sendLooksDead(old, msgUid: 'uid-file', now: now),
        isFalse,
      );
      expect(appState.sendLooksDead(old, msgUid: 'uid-text', now: now), isTrue);
    });

    // what a group does with it on screen is in group_dead_send_test
    test('a group and a 1:1 chat use the same rule', () {
      final group = File(
        'lib/screens/group_chat_screen.dart',
      ).readAsStringSync();
      final chat = File('lib/screens/chat_screen.dart').readAsStringSync();
      const rule = 'appState.sendLooksDead(m.when, msgUid: m.msgUid)';
      expect(group, contains(rule));
      expect(chat, contains(rule));
      expect(
        group,
        isNot(contains('appState.torStatus == TorStatus.reachable')),
      );
    });
  });

  test('settings and the pill read the same predicate', () {
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();
    expect(settings, contains('appState.torUsable'));
    final main = File('lib/main.dart').readAsStringSync();
    final pill = main.substring(main.indexOf('class TorHaloState'));
    expect(pill, contains('final ready = appState.torUsable;'));
  });

  // the services channel the preview setting reads through
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
  });
}
