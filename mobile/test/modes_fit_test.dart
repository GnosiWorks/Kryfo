// SPDX-License-Identifier: GPL-3.0-or-later
// the speed and privacy page: two cards, private and fast, in every language,
// at large text, right to left and with reduced motion. taps queued behind a
// switch say so on the picked card, the fast card shows its live status, and
// its details show our two servers with their round trips.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/screens/fast_servers_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show DevTestDb, devApp, devMem, devWorld;
import 'narrow_settings.dart' show loadAppFonts;

// holds every switch until let go, so the taps stay queued
Completer<void>? _gate;

class _Db extends DevTestDb {
  _Db() : super(devMem);
  @override
  Future<List<Map<String, Object?>>> contacts() async {
    await _gate?.future;
    return super.contacts();
  }
}

// our two servers as the engine reports them: both up, the second quicker
List<Map<String, Object?>> _rows = const [];
const _up = [
  {'url': 'wss://relay.kryfo.app', 'store': '1', 'up': true, 'ms': 84},
  {
    'url': 'wss://relay2.kryfo.app',
    'store': '2',
    'up': true,
    'ms': 41,
    'quicker': true,
  },
  {'url': 'wss://nos.lol', 'backup': true, 'up': false, 'ms': 0},
];

class _Engine implements HaloEngine {
  final modes = <String>[];
  final inits = <String>[];
  @override
  String setTransportMode(String mode) {
    modes.add(mode);
    return 'ok';
  }

  @override
  String nostrInit(String relaysCSV) {
    inits.add(relaysCSV);
    return 'ok';
  }

  @override
  Map<String, dynamic> transportState() => {'relays': _rows};
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _langs = [
  'en', 'ar', 'de', 'es', 'fa', 'fr', 'hi', 'id', 'it', //
  'pt', 'ru', 'tr', 'uk', 'vi', 'zh', 'zh_Hant',
];

Locale _locale(String tag) {
  final p = tag.split('_');
  return Locale.fromSubtags(
    languageCode: p[0],
    scriptCode: p.length > 1 ? p[1] : null,
  );
}

late _Engine _eng;

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _eng = _Engine();
    useEngineForTest(_eng);
    _rows = const [];
    await devWorld();
    final db = _Db();
    useDatabasesForTest(db, Session(db));
  });

  tearDown(() {
    appState.sendModeForTest = 'private';
    setL10nLocale(const Locale('en'));
  });

  void quietPlatform(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  testWidgets('two cards fit in every language, at large text, right to '
      'left, with a switch queued', (t) async {
    quietPlatform(t);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final runs = <String>[];
    final was = FlutterError.onError;
    var now = '';
    FlutterError.onError = (d) =>
        runs.add('$now: ${d.exceptionAsString().split('\n').first}');
    try {
      for (final lang in _langs) {
        for (final h in [640.0, 800.0]) {
          for (final scale in [1.0, 1.5, 2.0]) {
            now = '$lang h$h x$scale';
            t.view.physicalSize = Size(360, h);
            appState.sendModeForTest = 'private';
            _rows = _up;
            final locale = _locale(lang);
            setL10nLocale(locale);
            _gate = Completer<void>();
            await t.pumpWidget(
              KeyedSubtree(
                key: ValueKey(now),
                child: devApp(
                  const ModesScreen(),
                  locale: locale,
                  scale: scale,
                ),
              ),
            );
            await t.pump(const Duration(seconds: 1));
            // right to left where the language reads that way
            final dir = Directionality.of(
              t.element(find.text(l10n.modesPrivate)),
            );
            expect(
              dir,
              lang == 'ar' || lang == 'fa'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              reason: now,
            );
            // a switch already under way holds the queue
            final first = appState.setSendMode('balanced');
            for (final name in [l10n.modesFast, l10n.modesPrivate]) {
              final card = find.text(name);
              await t.ensureVisible(card);
              await t.pump();
              await t.tap(card);
              for (var i = 0; i < 25; i++) {
                await t.pump(const Duration(milliseconds: 16));
              }
              expect(
                find.byKey(const ValueKey('going')),
                findsOneWidget,
                reason: now,
              );
            }
            _gate!.complete();
            var done = false;
            unawaited(first.whenComplete(() => done = true));
            for (var i = 0; i < 50 && !done; i++) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await t.pump(const Duration(milliseconds: 200));
            }
            expect(done, isTrue, reason: now);
            await t.pump(const Duration(seconds: 1));
            expect(find.byKey(const ValueKey('going')), findsNothing);
            await t.pumpWidget(const SizedBox());
            await t.pump(const Duration(seconds: 1));
          }
        }
      }
    } finally {
      FlutterError.onError = was;
    }
    expect(runs, isEmpty, reason: runs.toSet().join('\n'));
  });

  testWidgets('the cards say what was approved, word for word', (t) async {
    quietPlatform(t);
    setL10nLocale(const Locale('en'));
    appState.sendModeForTest = 'private';
    await t.pumpWidget(devApp(const ModesScreen()));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
    expect(
      find.text(
        'Nobody learns your IP address or who you are, not even our servers. '
        'Finds a way around blocks by itself.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Skips Tor, so messages arrive quicker and use less battery. Our '
        "servers see your IP address only while you're connected, and never "
        'log or keep it. Never what you say. Your contacts never see it. '
        'Your network can see that you connect to Kryfo.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Both keep every message end-to-end encrypted. Only who can see your '
        'IP address changes.',
      ),
      findsOneWidget,
    );
    // private in use: the second server stands behind it too
    expect(
      find.text(
        'A backup is always ready, so you stay connected even if one goes '
        'down.',
      ),
      findsOneWidget,
    );
    // no third card, no relay
    expect(find.text('Relay'), findsNothing);
    expect(find.text('Onion'), findsNothing);
    // the fast card shows no server count or list, only its status
    expect(find.text('Fast · connected'), findsNothing);
    expect(find.text('Connection and bridges'), findsOneWidget);
  });

  for (final still in [false, true]) {
    testWidgets('fast in use: connected, the backup line, and the servers '
        'behind details (still: $still)', (t) async {
      quietPlatform(t);
      setL10nLocale(const Locale('en'));
      appState.sendModeForTest = 'balanced';
      _rows = _up;
      await t.pumpWidget(devApp(const ModesScreen(), still: still));
      await t.pump(const Duration(seconds: 2));
      expect(find.text(l10n.modesFastConnected), findsOneWidget);
      expect(
        find.text(
          'A backup is always ready, so you stay connected even if one goes '
          'down.',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.serversOne), findsNothing);
      expect(find.text(l10n.modesWhatServersSee), findsOneWidget);
      await t.tap(find.text(l10n.modesDetails));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(FastServersScreen), findsOneWidget);
      expect(find.text('Server 1'), findsOneWidget);
      expect(find.text('Server 2 · second provider'), findsOneWidget);
      expect(find.text(l10n.serversMs(84)), findsOneWidget);
      expect(find.text(l10n.serversMs(41)), findsOneWidget);
      expect(find.text(l10n.serversQuicker), findsOneWidget);
      expect(find.text(l10n.serversStandingBy), findsOneWidget);
      // the first server stops: its row says so, the second carries on
      _rows = [
        {
          'url': 'wss://relay.kryfo.app',
          'store': '1',
          'up': false,
          'ms': 84,
          'fails': 2,
        },
        _up[1],
        _up[2],
      ];
      await t.pump(const Duration(seconds: 2));
      // the old word rises out before it is gone
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.serversConnecting), findsOneWidget);
      expect(find.text(l10n.serversConnected), findsOneWidget);
      if (still) {
        // nothing moves with reduced motion: the page rests at once
        await t.pumpAndSettle();
      }
      Navigator.of(t.element(find.byType(FastServersScreen))).pop();
      await t.pump(const Duration(seconds: 1));
      // both down: the card says so
      _rows = [
        {'url': 'wss://relay.kryfo.app', 'store': '1', 'fails': 4},
        {'url': 'wss://relay2.kryfo.app', 'store': '2', 'fails': 4},
      ];
      appState.relayDownSinceForTest = DateTime.now().subtract(
        const Duration(minutes: 2),
      );
      await t.pump(const Duration(seconds: 2));
      expect(find.text(l10n.modesFastDown), findsOneWidget);
      appState.relayDownSinceForTest = null;
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('the servers page fits in every language at large text', (
    t,
  ) async {
    quietPlatform(t);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(360, 640);
    addTearDown(t.view.reset);
    appState.sendModeForTest = 'balanced';
    _rows = _up;
    final runs = <String>[];
    final was = FlutterError.onError;
    var now = '';
    FlutterError.onError = (d) =>
        runs.add('$now: ${d.exceptionAsString().split('\n').first}');
    try {
      for (final lang in _langs) {
        for (final scale in [1.0, 2.0]) {
          now = '$lang x$scale';
          final locale = _locale(lang);
          setL10nLocale(locale);
          await t.pumpWidget(
            KeyedSubtree(
              key: ValueKey(now),
              child: devApp(
                const FastServersScreen(),
                locale: locale,
                scale: scale,
              ),
            ),
          );
          await t.pump(const Duration(seconds: 1));
          expect(find.text(l10n.serversTwo), findsOneWidget, reason: now);
        }
      }
    } finally {
      FlutterError.onError = was;
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    expect(runs, isEmpty, reason: runs.toSet().join('\n'));
  });
}
