// SPDX-License-Identifier: GPL-3.0-or-later
// a wipe erases this phone's keys, prefs and files first. a wipe chosen in
// settings gives the handle back beside it, a few seconds at most: an
// answer that never comes holds nothing back. a wipe from the lock screen
// or from a quiet session's settings makes no network call. tor's own
// folder goes once the engine has let go of it. the engine and android's
// erase are stand-ins, the folders real ones in a scratch folder
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/wipe.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _Engine implements HaloEngine {
  final calls = <String>[];
  final answer = Completer<String>();
  @override
  Future<String> handleRelease(String h) {
    calls.add('release $h');
    return answer.future;
  }

  @override
  Future<String> wipeHold() async {
    calls.add('hold');
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  int? exited;

  String dir(String name) => p.join(root.path, name);

  List<String> left(String name) => [
    for (final e in Directory(dir(name)).listSync(recursive: true))
      p.relative(e.path, from: dir(name)),
  ]..sort();

  setUp(() {
    root = Directory.systemTemp.createTempSync('wipe_order');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => switch (call.method) {
        'getApplicationDocumentsDirectory' => dir('docs'),
        'getApplicationSupportDirectory' => dir('support'),
        _ => dir('tmp'),
      },
    );
    m.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      (call) async => call.method == 'wipe' ? false : null,
    );
    for (final f in [
      'docs/halo.db',
      'docs/onion.key',
      'docs/media/a.jpg',
      'docs/tor/state',
      'docs/nostr_seen_0011223344556677',
      'support/cache',
      'tmp/part',
    ]) {
      File(dir(f))
        ..createSync(recursive: true)
        ..writeAsStringSync(f);
    }
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'k',
      'my_handle': 'wren',
    });
    SharedPreferences.setMockInitialValues({'onboarding.complete': true});
    exited = null;
    wipeExit = (code) => exited = code;
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    root.deleteSync(recursive: true);
  });

  test('from settings: keys and files go while the release is still out, '
      'tor\'s folder after the engine lets go, and a release that never '
      'answers holds the end a few seconds at most', () async {
    final engine = _Engine();
    useEngineForTest(engine);
    final clock = Stopwatch()..start();
    final done = wipeHalo(releaseHandle: true);
    // the erase, with the release unanswered
    while (left('docs').length > 2 && clock.elapsed.inSeconds < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(engine.calls, ['release wren']);
    expect(left('docs'), ['tor', 'tor/state']);
    expect(left('support'), isEmpty);
    expect(left('tmp'), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(clock.elapsed.inMilliseconds, lessThan(1500));
    await done;
    expect(clock.elapsed.inSeconds, lessThan(6));
    expect(engine.calls, ['release wren', 'hold']);
    expect(left('docs'), isEmpty);
    expect(exited, 0);
  });

  test('from the lock screen: everything goes and the handle is never '
      'released', () async {
    final engine = _Engine();
    useEngineForTest(engine);
    final clock = Stopwatch()..start();
    await wipeHalo();
    expect(engine.calls, ['hold']);
    expect(left('docs'), isEmpty);
    expect(left('support'), isEmpty);
    expect(left('tmp'), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(exited, 0);
    // nothing waited on an answer
    expect(clock.elapsed.inSeconds, lessThan(3));
  });

  test('from a quiet session\'s settings: everything goes and no handle is '
      'read or given back', () async {
    final engine = _Engine();
    useEngineForTest(engine);
    useDatabasesForTest(HaloDb(), Session(HaloDb(HaloContainer.decoy)));
    addTearDown(() => useDatabasesForTest(HaloDb(), Session(HaloDb())));
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'k',
      'my_handle': 'wren',
      'd.my_handle': 'finch',
    });
    final clock = Stopwatch()..start();
    await wipeHalo(releaseHandle: true);
    expect(engine.calls, ['hold']);
    expect(left('docs'), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect(exited, 0);
    expect(clock.elapsed.inSeconds, lessThan(3));
  });

  test('only the settings wipe gives the handle back, and not from a quiet '
      'session', () {
    final giving = <String>[];
    final bare = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('wipeHalo(releaseHandle:')) {
        giving.add(p.basename(f.path));
      }
      if (src.contains('wipeHalo()')) bare.add(p.basename(f.path));
    }
    expect(giving, ['settings_screen.dart']);
    expect(
      File('lib/screens/settings_screen.dart').readAsStringSync(),
      contains('wipeHalo(releaseHandle: !sessionQuiet)'),
    );
    expect(bare, containsAll(['lock_screen.dart', 'pin_flow_screen.dart']));
  });
}
