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

import 'shred_twin.dart';

// a busy machine stretches wall time, not the wipe: the bound grows with the
// load per core, up to four times
int _ms(int ms) {
  try {
    final load = double.parse(
      File('/proc/loadavg').readAsStringSync().split(' ').first,
    );
    return (ms * (load / Platform.numberOfProcessors).clamp(1.0, 4.0)).round();
  } on Object {
    return ms;
  }
}

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
  final platform = <String>[];

  String dir(String name) => p.join(root.path, name);

  List<String> left(String name) => [
    for (final e in Directory(dir(name)).listSync(recursive: true))
      p.relative(e.path, from: dir(name)),
  ]..sort();

  // the first erase done: keys and prefs, then every folder but tor's. a
  // folder caught mid-delete is not done yet
  Future<bool> erased() async {
    try {
      return left('docs').join(',') == 'tor,tor/state' &&
          left('support').isEmpty &&
          left('tmp').isEmpty &&
          (await const FlutterSecureStorage().readAll()).isEmpty &&
          (await SharedPreferences.getInstance()).getKeys().isEmpty;
    } on FileSystemException {
      return false;
    }
  }

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
    platform.clear();
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (
      call,
    ) async {
      platform.add(call.method);
      return call.method == 'wipe' ? false : null;
    });
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
    wipeShred = shredHeld;
    haloWiping = false;
    root.deleteSync(recursive: true);
  });

  group('plaintext', () {
    late Directory twins;
    setUp(() => twins = Directory.systemTemp.createTempSync('wipe_twins'));
    tearDown(() => twins.deleteSync(recursive: true));

    // every file that held plaintext or a key in the clear, with a link to
    // its blocks
    Map<String, File> plain() {
      final out = <String, File>{};
      for (final (f, size) in [
        ('docs/media/v_1.mp4', 4 << 20),
        ('docs/media/in_ab/doc.pdf', 30000),
        ('docs/media_v/h.jpg', 20000),
        ('docs/media_d/d.jpg', 20000),
        ('docs/wallpapers/w.jpg', 20000),
        ('docs/wallpapers_v/w.jpg', 20000),
        ('docs/onion.key', 64),
        ('support/backup_stage/onion.key', 64),
        ('tmp/open/ab12/statement.pdf', 20000),
        ('tmp/share/cd34/photo.jpg', 20000),
        ('tmp/share_plus/x/old.jpg', 20000),
        ('tmp/backup_out/ef56/kryfo.kryfo', 20000),
        ('tmp/vn_1.wav', 20000),
      ]) {
        final file = File(dir(f))
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(size, 7), flush: true);
        out[f] = twinOf(file.path, twins);
      }
      return out;
    }

    test('the visible erase is done at once and waits for no shred, and '
        'every file is overwritten behind it', () async {
      useEngineForTest(_Engine());
      final files = plain();
      final gate = Completer<void>();
      // a failed check below must not leave the shred hung for the next test
      addTearDown(() => gate.isCompleted ? null : gate.complete());
      final shredded = <String>[];
      wipeShred = (path) async {
        await gate.future;
        shredded.add(path);
        await shredHeld(path);
      };
      final clock = Stopwatch()..start();
      final done = wipeHalo();
      // keys, prefs and every name but tor's
      Future<bool> gone() async {
        try {
          return left('docs').every((e) => e.startsWith('tor')) &&
              left('support').isEmpty &&
              left('tmp').isEmpty &&
              (await const FlutterSecureStorage().readAll()).isEmpty &&
              (await SharedPreferences.getInstance()).getKeys().isEmpty;
        } on FileSystemException {
          return false;
        }
      }

      while (!await gone() && clock.elapsed.inSeconds < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // gone while not a byte was shredded yet
      expect(await gone(), isTrue);
      expect(shredded, isEmpty);
      expect(clock.elapsed.inMilliseconds, lessThan(_ms(1000)));
      for (final f in files.keys) {
        expect(File(dir(f)).existsSync(), isFalse, reason: f);
      }
      gate.complete();
      await done;
      await wipeShredding;
      expect(exited, 0);
      for (final MapEntry(key: f, value: twin) in files.entries) {
        expect(zeroed(twin), isTrue, reason: f);
      }
      expect(Directory(dir(kWipeHeld)).existsSync(), isFalse);
    });

    test('an entry that will not move is shredded where it lies, and never '
        'left under its name', () async {
      useEngineForTest(_Engine());
      final files = plain();
      // nothing can be moved aside
      File(dir(kWipeHeld)).writeAsStringSync('in the way');
      await wipeHalo();
      await wipeShredding;
      expect(exited, 0);
      for (final MapEntry(key: f, value: twin) in files.entries) {
        expect(File(dir(f)).existsSync(), isFalse, reason: f);
        expect(zeroed(twin), isTrue, reason: f);
      }
    });

    test('one that will not move and whose shred never ends is unlinked a '
        'moment later', () async {
      useEngineForTest(_Engine());
      final files = plain();
      File(dir(kWipeHeld)).writeAsStringSync('in the way');
      final stuck = Completer<void>();
      addTearDown(stuck.complete);
      wipeShred = (_) => stuck.future;
      final clock = Stopwatch()..start();
      await wipeHalo();
      expect(exited, 0);
      for (final f in files.keys) {
        expect(File(dir(f)).existsSync(), isFalse, reason: f);
      }
      expect(left('support'), isEmpty);
      expect(left('tmp'), isEmpty);
      expect(clock.elapsed, lessThan(kWipeShredWait * 3));
    });

    test('a database copy in a stage is ciphertext: unlinked, never given '
        'shred time', () async {
      useEngineForTest(_Engine());
      final copy = File(dir('support/backup_stage/halo.db'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(30000, 7), flush: true);
      final twin = twinOf(copy.path, twins);
      final key = File(dir('support/backup_stage/onion.key'))
        ..writeAsBytesSync(List.filled(64, 7), flush: true);
      final keyTwin = twinOf(key.path, twins);
      await wipeHalo();
      await wipeShredding;
      expect(copy.existsSync(), isFalse);
      expect(twin.readAsBytesSync(), List.filled(30000, 7));
      expect(zeroed(keyTwin), isTrue);
    });

    test('a start sweep leaves what a wipe running now is moving', () async {
      useEngineForTest(_Engine());
      plain();
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      wipeShred = (path) async {
        await gate.future;
        await shredHeld(path);
      };
      final done = wipeHalo();
      final clock = Stopwatch()..start();
      while (!Directory(dir(kWipeHeld)).existsSync() ||
          Directory(dir(kWipeHeld)).listSync().length < 3) {
        if (clock.elapsed.inSeconds > 3) fail('nothing moved aside');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      Set<String> held() => {
        for (final e in Directory(dir(kWipeHeld)).listSync()) e.path,
      };
      final moved = held();
      await sweepWipeLeftovers();
      expect(held(), containsAll(moved));
      // and one that does not know a wipe is on
      haloWiping = false;
      await sweepWipeLeftovers();
      expect(held(), containsAll(moved));
      gate.complete();
      await done;
      await wipeShredding;
      expect(Directory(dir(kWipeHeld)).existsSync(), isFalse);
    });

    test('a shred that never ends holds the end a moment at most', () async {
      useEngineForTest(_Engine());
      plain();
      final stuck = Completer<void>();
      addTearDown(stuck.complete);
      wipeShred = (_) => stuck.future;
      final clock = Stopwatch()..start();
      await wipeHalo();
      expect(exited, 0);
      expect(
        clock.elapsed,
        lessThan(kWipeShredWait + const Duration(seconds: 2)),
      );
    });

    test('what a wipe held and its process did not live to shred goes at '
        'the next start', () async {
      final f = File(dir('$kWipeHeld/0a1b2c3d4e5f6071/in_ab/doc.pdf'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(30000, 7), flush: true);
      final twin = twinOf(f.path, twins);
      await sweepWipeLeftovers();
      expect(Directory(dir(kWipeHeld)).existsSync(), isFalse);
      expect(zeroed(twin), isTrue);
      expect(Directory(dir('docs')).existsSync(), isTrue);
    });

    test('the start sweeps run it', () {
      final main = File('lib/app/boot.dart').readAsStringSync();
      final at = main.indexOf('Future<void> _sweepPlaintextLeftovers()');
      expect(at, isNonNegative);
      expect(
        main.substring(at, main.indexOf('\n}\n', at)),
        contains('await sweepWipeLeftovers();'),
      );
    });
  });

  test('from settings: keys and files go while the release is still out, '
      'tor\'s folder after the engine lets go, and a release that never '
      'answers holds the end a few seconds at most', () async {
    final engine = _Engine();
    useEngineForTest(engine);
    final clock = Stopwatch()..start();
    final done = wipeHalo(releaseHandle: true);
    // the erase, with the release unanswered: every folder it empties, not
    // just the first, since a busy machine leaves the last ones for later
    while (!await erased() && clock.elapsed.inSeconds < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(engine.calls, ['release wren']);
    expect(left('docs'), ['tor', 'tor/state']);
    expect(left('support'), isEmpty);
    expect(left('tmp'), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(clock.elapsed.inMilliseconds, lessThan(_ms(1500)));
    await done;
    expect(clock.elapsed.inSeconds, lessThan(6));
    expect(engine.calls, ['release wren', 'hold']);
    expect(left('docs'), isEmpty);
    expect(exited, 0);
  });

  test('the fingerprint key goes before the seal and the rest', () async {
    useEngineForTest(_Engine());
    FlutterSecureStorage.setMockInitialValues({
      'halo.lock.biometric': 'true',
      'halo.lock.biometric.seal': 'ab' * 257,
    });
    await wipeHalo();
    expect(platform.first, 'bioDisable');
    expect(platform, contains('wipe'));
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
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
