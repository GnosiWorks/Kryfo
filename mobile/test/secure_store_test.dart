// SPDX-License-Identifier: GPL-3.0-or-later
// secure storage keeps what it cannot read. every store the app opens asks
// the plugin to leave a key alone on a failed read, and the database key is
// never made anew while a database file is there: a read that fails, or a
// key that is missing, stops the open instead. the plugin's channel and the
// folders are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb;

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late List<MethodCall> calls;
  late Map<String, String> kept;
  var failReads = false;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('secure_store');
    calls = [];
    kept = {};
    failReads = false;
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    m.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          if (failReads) {
            throw PlatformException(code: 'Exception', message: 'no read');
          }
          return kept[key];
        case 'write':
          kept[key!] = args['value'] as String;
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_channel, null);
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

  test('a read that fails stops the open and writes no key', () async {
    failReads = true;
    final e = await open(HaloDb());
    expect(e, isA<PlatformException>());
    expect(calls.where((c) => c.method == 'write'), isEmpty);
  });

  test(
    'a key that is missing beside a database file is not made anew',
    () async {
      File(await HaloContainer.everyday.dbPath()).writeAsStringSync('rows');
      final e = await open(HaloDb());
      expect(e, isA<StateError>());
      expect(calls.where((c) => c.method == 'write'), isEmpty);
      expect(kept, isEmpty);
    },
  );

  test('a first start makes the key before the file', () async {
    await open(HaloDb());
    expect(kept['halo.db.passphrase'], matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('every call asks the plugin to keep a key it cannot read', () async {
    await open(HaloDb());
    await open(HaloDb(HaloContainer.decoy));
    expect(calls, isNotEmpty);
    for (final c in calls) {
      final options = (c.arguments as Map)['options'] as Map;
      expect(options['resetOnError'], 'false', reason: c.method);
    }
  });

  test('no store in lib/ is opened with the plugin default', () {
    final loose = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'));
    final ctor = RegExp(r'FlutterSecureStorage\(');
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in ctor.allMatches(src)) {
        var depth = 0;
        var end = m.end - 1;
        for (var i = m.end - 1; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')' && --depth == 0) {
            end = i;
            break;
          }
        }
        if (!src.substring(m.start, end + 1).contains('resetOnError: false')) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          loose.add('${f.path}:$line');
        }
      }
    }
    expect(loose, isEmpty, reason: loose.join('\n'));
  });
}
