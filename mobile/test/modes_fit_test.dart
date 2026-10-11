// SPDX-License-Identifier: GPL-3.0-or-later
// the speed and privacy page with taps queued behind a switch: the fast
// card's warning folds away while the picked card says it is switching, and
// nothing runs off the bottom on a small phone, in any language or size
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
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

class _Engine implements HaloEngine {
  @override
  String setTransportMode(String mode) => 'ok';
  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _langs = [
  'en', 'ar', 'de', 'es', 'fa', 'fr', 'id', 'it', //
  'pt', 'ru', 'tr', 'uk', 'vi', 'zh', 'zh_Hant',
];

Locale _locale(String tag) {
  final p = tag.split('_');
  return Locale.fromSubtags(
    languageCode: p[0],
    scriptCode: p.length > 1 ? p[1] : null,
  );
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    await devWorld();
    final db = _Db();
    useDatabasesForTest(db, Session(db));
  });

  tearDown(() {
    appState.sendModeForTest = 'private';
    setL10nLocale(const Locale('en'));
  });

  testWidgets('queued taps fit at 360 wide', (t) async {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
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
          for (final scale in [1.0, 1.5]) {
            now = '$lang h$h x$scale';
            t.view.physicalSize = Size(360, h);
            appState.sendModeForTest = 'fast';
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
            // a switch already under way holds the queue
            final first = appState.setSendMode('balanced');
            var switching = 0;
            for (final name in [l10n.modesOnion, l10n.modesRelay]) {
              final card = find.text(name);
              await t.ensureVisible(card);
              await t.pump();
              await t.tap(card);
              // every frame of the fold, not only where it ends
              for (var i = 0; i < 25; i++) {
                await t.pump(const Duration(milliseconds: 16));
              }
              switching += find.text(l10n.modesSwitching).evaluate().length;
            }
            expect(switching, 2, reason: now);
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
            expect(find.text(l10n.modesSwitching), findsNothing, reason: now);
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
}
