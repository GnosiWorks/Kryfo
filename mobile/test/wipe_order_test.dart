// SPDX-License-Identifier: GPL-3.0-or-later
// a wipe erases this phone's keys, prefs and files first. the handle's
// release runs beside it and is given a few seconds at most: an answer
// that never comes holds nothing back. tor's own folder goes once the
// engine has let go of it. the engine and android's erase are stand-ins,
// the folders real ones in a scratch folder
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloEngine, useEngineForTest;
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

  test('keys and files go while the release is still out, tor\'s folder '
      'after the engine lets go, and a release that never answers holds the '
      'end a few seconds at most', () async {
    final engine = _Engine();
    useEngineForTest(engine);
    final clock = Stopwatch()..start();
    final done = wipeHalo();
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
}
