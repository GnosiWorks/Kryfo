// SPDX-License-Identifier: GPL-3.0-or-later
// a key store that stops answering. the plugin runs one call at a time, so
// the stand-in here does too: a call that hangs holds every call after it.
// a start gives up on it, makes no key, writes and removes nothing, and
// says a new process is the way out
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, appState;
import 'package:kryfo/reopen.dart';
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/boot_failed.dart';
import 'package:kryfo/widgets/tor_boot_splash.dart';

const _store = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _platform = MethodChannel('halo/platform');

// the plugin's one thread: calls run in the order they came, one at a time
class _Plugin {
  final calls = <MethodCall>[];
  final kept = <String, String>{};
  // methods that wait for [held] before they run
  final hang = <String>{};
  final held = <Completer<void>>[];
  var failReads = false;
  Future<void> _tail = Future.value();

  Iterable<MethodCall> of(String method) =>
      calls.where((c) => c.method == method);

  Future<Object?> handle(MethodCall call) {
    calls.add(call);
    final done = Completer<Object?>();
    _tail = _tail.then((_) async {
      if (hang.contains(call.method)) {
        final c = Completer<void>();
        held.add(c);
        await c.future;
      }
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          if (failReads) {
            done.completeError(
              PlatformException(code: 'Exception', message: 'no read'),
            );
          } else {
            done.complete(kept[key]);
          }
        case 'write':
          kept[key!] = args['value'] as String;
          done.complete(null);
        default:
          done.complete(null);
      }
    });
    return done.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late _Plugin plugin;
  final keyName = HaloContainer.everyday.keyName!;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('key_store_wait');
    plugin = _Plugin();
    keyStoreWait = const Duration(milliseconds: 200);
    keyStoreSlowAfter = const Duration(milliseconds: 80);
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    m.setMockMethodCallHandler(_store, plugin.handle);
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_store, null);
    for (final c in plugin.held) {
      if (!c.isCompleted) c.complete();
    }
    keyStoreSlow.value = false;
    docs.deleteSync(recursive: true);
  });

  // opening goes on to sqlite, which has no plugin here: only what
  // happened before it counts
  Future<Object?> open(HaloDb db) async {
    try {
      await db.open();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<bool> dbThere() async =>
      File(await HaloContainer.everyday.dbPath()).exists();

  group('the database key', () {
    test('a read that never answers gives up and makes no key', () async {
      plugin.hang.add('read');
      final e = await open(HaloDb());
      expect(e, isA<KeyStoreStuck>());
      expect(plugin.of('write'), isEmpty);
      expect(plugin.of('delete'), isEmpty);
      expect(plugin.of('deleteAll'), isEmpty);
      expect(await dbThere(), isFalse);
    });

    test('a database already there is left as it is', () async {
      final f = File(await HaloContainer.everyday.dbPath())
        ..writeAsStringSync('rows');
      plugin.hang.add('read');
      final e = await open(HaloDb());
      expect(e, isA<KeyStoreStuck>());
      expect(plugin.of('write'), isEmpty);
      expect(plugin.of('delete'), isEmpty);
      expect(plugin.of('deleteAll'), isEmpty);
      expect(f.readAsStringSync(), 'rows');
    });

    test('a write that never answers makes no file under its key', () async {
      plugin.hang.add('write');
      final e = await open(HaloDb());
      expect(e, isA<KeyStoreStuck>());
      expect(plugin.of('write'), hasLength(1));
      expect(await dbThere(), isFalse);
    });

    test('a write that lands late is the key the next start reads', () async {
      plugin.hang.add('write');
      expect(await open(HaloDb()), isA<KeyStoreStuck>());
      final first = plugin.of('write').single.arguments as Map;
      // a retry in the same process waits behind the write, and makes no
      // second key while it does
      expect(await open(HaloDb()), isA<KeyStoreStuck>());
      expect(plugin.of('write'), hasLength(1));
      // the write lands, then the read queued behind it runs
      plugin.hang.clear();
      plugin.held.single.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(plugin.kept[keyName], first['value']);
      final e = await open(HaloDb());
      expect(e, isNot(isA<KeyStoreStuck>()));
      expect(e, isNot(isA<StateError>()));
      expect(plugin.of('write'), hasLength(1));
      expect(plugin.kept[keyName], first['value']);
    });

    test('a read that fails is not taken for a stuck store', () async {
      plugin.failReads = true;
      final e = await open(HaloDb());
      expect(e, isA<PlatformException>());
      expect(plugin.of('write'), isEmpty);
    });

    test('a slow call is flagged, and the flag goes when it gives up', () async {
      plugin.hang.add('read');
      final opening = open(HaloDb());
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(keyStoreSlow.value, isTrue);
      expect(await opening, isA<KeyStoreStuck>());
      expect(keyStoreSlow.value, isFalse);
    });
  });

  group('boot', () {
    test('a stuck store fails the start with that cause', () async {
      plugin.hang.add('read');
      await appState.boot();
      expect(appState.bootError, contains('KeyStoreStuck'));
      expect(appState.bootStuck, isTrue);
      expect(appState.ready, isFalse);
      expect(plugin.of('write'), isEmpty);
      expect(plugin.of('delete'), isEmpty);
      expect(plugin.of('deleteAll'), isEmpty);
      expect(docs.listSync(), isEmpty);
    });

    test('any other failure keeps the plain retry', () async {
      plugin.failReads = true;
      await appState.retryBoot();
      expect(appState.bootError, isNotNull);
      expect(appState.bootStuck, isFalse);
      expect(plugin.of('write'), isEmpty);
    });
  });

  group('the way out', () {
    late List<MethodCall> asked;

    setUp(() {
      asked = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_platform, (c) async {
            asked.add(c);
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_platform, null),
    );

    Widget framed(Widget home, {bool still = false}) => MaterialApp(
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
        child: child!,
      ),
      home: home,
    );

    testWidgets('the failure screen offers a reopen for a stuck store', (
      t,
    ) async {
      var retried = 0;
      await t.pumpWidget(
        framed(
          BootFailedScreen(
            error: const KeyStoreStuck().toString(),
            onRetry: () => retried++,
            onReopen: reopenApp,
          ),
        ),
      );
      expect(find.text(l10n.bootFailedKeysDidNotAnswer), findsOneWidget);
      expect(find.text(l10n.bootFailedThisIsAFault), findsNothing);
      await t.tap(find.text(l10n.bootFailedCloseAndReopen));
      await t.pump();
      expect(asked.map((c) => c.method), ['reopen']);
      // the plain retry stays
      await t.tap(find.text(l10n.commonTryAgain));
      expect(retried, 1);
    });

    testWidgets('any other failure shows no reopen', (t) async {
      await t.pumpWidget(
        framed(BootFailedScreen(error: 'Bad state: x', onRetry: () {})),
      );
      expect(find.text(l10n.bootFailedCloseAndReopen), findsNothing);
      expect(find.text(l10n.bootFailedThisIsAFault), findsOneWidget);
      expect(find.text(l10n.commonTryAgain), findsOneWidget);
    });

    for (final still in [false, true]) {
      testWidgets('the splash offers a reopen once the store is slow'
          '${still ? ', still' : ''}', (t) async {
        t.view.physicalSize = const Size(411, 891) * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(framed(const TorBootSplash(), still: still));
        await t.pump(const Duration(seconds: 1));
        expect(find.text(l10n.torBootSplashTakingLonger), findsNothing);
        expect(find.text(l10n.torBootSplashFirstLaunchTakesA), findsOneWidget);
        keyStoreSlow.value = true;
        await t.pump();
        if (still) {
          // nothing fades with less movement: it is there at once
          expect(
            find.text(l10n.torBootSplashFirstLaunchTakesA),
            findsNothing,
          );
        } else {
          await t.pump(const Duration(milliseconds: 400));
        }
        expect(find.text(l10n.torBootSplashTakingLonger), findsOneWidget);
        await t.tap(find.text(l10n.bootFailedCloseAndReopen));
        await t.pump();
        expect(asked.map((c) => c.method), ['reopen']);
        keyStoreSlow.value = false;
        await t.pumpWidget(const SizedBox());
      });
    }
  });
}
