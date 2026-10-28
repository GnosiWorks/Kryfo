// SPDX-License-Identifier: GPL-3.0-or-later
// relay and fast are one route: whoever was on either starts on it, hears of
// it once, and the route talks to our two servers, with the public relays
// only as the engine's backup behind them.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/carried_settings.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show AppState, AppStateRoute, HaloEngine, useEngineForTest;
import 'package:kryfo/route_merge.dart';
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/widgets/route_merged_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp;

class _Engine implements HaloEngine {
  final log = <String>[];
  @override
  String setTransportMode(String mode) {
    log.add('mode:$mode');
    return 'ok';
  }

  @override
  String nostrInit(String relaysCSV) {
    log.add('init:$relaysCSV');
    return 'ok';
  }

  @override
  String transportMode() => 'private';
  @override
  Map<String, dynamic> transportState() => const {};
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Engine eng;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    eng = _Engine();
    useEngineForTest(eng);
  });

  test('both old routes start on the one fast route, private stays', () {
    expect(routeAtBoot('balanced'), 'balanced');
    expect(routeAtBoot('fast'), 'balanced');
    expect(routeAtBoot('private'), 'private');
    expect(routeAtBoot('normal'), 'private');
    expect(routeAtBoot(null), 'private');
    expect(routeAtBoot('nonsense'), 'private');
  });

  for (final old in ['balanced', 'fast']) {
    test('$old moves to fast at the start, and the card is due once', () async {
      FlutterSecureStorage.setMockInitialValues({'send_mode': old});
      final app = AppState();
      await app.loadSendMode();
      expect(app.sendMode, 'balanced');
      expect(await secureStore.read(key: 'send_mode'), 'balanced');
      expect(app.routeMergeCardDue, isTrue);
      await app.routeMergeCardSeen();
      expect(app.routeMergeCardDue, isFalse);
      // the next start remembers it was seen
      final next = AppState();
      await next.loadSendMode();
      expect(next.sendMode, 'balanced');
      expect(next.routeMergeCardDue, isFalse);
    });
  }

  test('nobody else ever sees the card', () async {
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'private'});
    final app = AppState();
    await app.loadSendMode();
    expect(app.routeMergeCardDue, isFalse);
    // picking fast later is a choice made knowing it
    app.sendModeForTest = 'balanced';
    expect(app.routeMergeCardDue, isFalse);
    // a fresh install too
    FlutterSecureStorage.setMockInitialValues({});
    final fresh = AppState();
    await fresh.loadSendMode();
    expect(fresh.sendMode, 'private');
    expect(fresh.routeMergeCardDue, isFalse);
  });

  test('the card goes once private is picked, and says nothing then', () async {
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    final app = AppState();
    await app.loadSendMode();
    expect(app.routeMergeCardDue, isTrue);
    await app.setSendMode('private');
    expect(app.routeMergeCardDue, isFalse);
    expect(await secureStore.read(key: kRouteMergeNote), 'done');
  });

  test('fast talks to our two servers, the public relays only behind '
      'them as backups', () {
    final app = AppState();
    final fast = app.relaysFor('balanced');
    final parts = fast.split('|');
    expect(parts, hasLength(2));
    expect(parts[0], 'wss://relay.kryfo.app,wss://relay2.kryfo.app');
    expect(parts[1], contains('wss://nos.lol'));
    // the old id is the same route
    expect(app.relaysFor('fast'), fast);
    // private keeps its list, onion first
    final private = app.relaysFor('private');
    expect(private, isNot(contains('|')));
    expect(private, startsWith('ws://'));
    expect(private, contains('.onion,wss://relay.kryfo.app,'));
  });

  test(
    'asked for the old fast, the engine routes the one fast route',
    () async {
      final app = AppState()..sendModeForTest = 'private';
      await app.setSendMode('fast');
      expect(app.sendMode, 'balanced');
      expect(eng.log, contains('mode:balanced'));
      expect(eng.log, isNot(contains('mode:fast')));
      expect(eng.log, contains('init:${app.relaysFor('balanced')}'));
    },
  );

  test('a backup that carried either old route restores onto fast', () async {
    for (final old in ['fast', 'balanced']) {
      FlutterSecureStorage.setMockInitialValues({});
      await landCarriedSettings(
        {Carried.route: old},
        HaloContainer.everyday,
        phone: true,
      );
      expect(
        await secureStore.read(key: HaloContainer.everyday.key('send_mode')),
        'balanced',
        reason: old,
      );
    }
  });

  for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('the one-time card: got it, or private instead (${dir.name})', (
      t,
    ) async {
      setL10nLocale(Locale(dir == TextDirection.rtl ? 'ar' : 'en'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var got = 0, private = 0;
      await t.pumpWidget(
        devApp(
          Scaffold(
            body: SingleChildScrollView(
              child: RouteMergedCard(
                onGotIt: () => got++,
                onPrivate: () => private++,
              ),
            ),
          ),
          locale: Locale(dir == TextDirection.rtl ? 'ar' : 'en'),
          scale: 2,
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text(l10n.homeMergedTitle), findsOneWidget);
      if (dir == TextDirection.ltr) {
        expect(find.text('Relay and Fast are one now'), findsOneWidget);
        expect(
          find.text(
            "You're on Fast. A backup server is always ready, so you stay "
            'connected even if one goes down. Our servers see your IP '
            'address, never what you say.',
          ),
          findsOneWidget,
        );
        expect(find.text('Got it'), findsOneWidget);
        expect(find.text('Use Private instead'), findsOneWidget);
      }
      for (final f in [
        find.text(l10n.homeMergedGotIt),
        find.byTooltip(l10n.commonClose),
        find.text(l10n.homeMergedUsePrivate),
      ]) {
        await t.ensureVisible(f);
        await t.pump();
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(got, 2);
      expect(private, 1);
    });
  }
}
