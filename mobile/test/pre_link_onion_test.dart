// SPDX-License-Identifier: GPL-3.0-or-later
// a linked device's pre-link onion key goes once its tor is a client: at
// the link, and at a start that finds one left over. a phone keeps its own
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/main.dart'
    show HaloEngine, linkedRoleForTest, torAsLinked, useEngineForTest;

import 'say_hi_fakes.dart' show mockChannel;

class _Tor implements HaloEngine {
  final asked = <String>[];
  // the key as it lay when the engine was told, to see the order
  bool keyThere = false;
  late String keyPath;

  @override
  Future<String> torClientOnly() async {
    asked.add('client');
    keyThere = File(keyPath).existsSync();
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late _Tor tor;
  late File key;
  late File other;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('pre_link_onion');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    key = File('${docs.path}/onion.key')..writeAsBytesSync(List.filled(64, 7));
    other = File('${docs.path}/halo.db')..writeAsBytesSync([1, 2, 3]);
    tor = _Tor()..keyPath = key.path;
    useEngineForTest(tor);
    linkedDevicesForTest = true;
  });

  tearDown(() {
    linkedRoleForTest = false;
    linkedDevicesForTest = null;
    mockChannel('plugins.flutter.io/path_provider', null);
    docs.deleteSync(recursive: true);
  });

  test('the link shreds the key, after tor is a client', () async {
    linkedRoleForTest = true;
    await torAsLinked(at: 'link');
    expect(tor.asked, ['client']);
    // told first: a start under way can no longer read it
    expect(tor.keyThere, isTrue);
    expect(key.existsSync(), isFalse);
    expect(other.readAsBytesSync(), [1, 2, 3]);
  });

  test('a start finding one left over shreds it, and none is fine', () async {
    linkedRoleForTest = true;
    await torAsLinked(at: 'load');
    expect(key.existsSync(), isFalse);
    await torAsLinked(at: 'load');
    expect(tor.asked, ['client', 'client']);
  });

  test('a phone keeps its onion key', () async {
    linkedRoleForTest = false;
    await torAsLinked(at: 'link');
    expect(tor.asked, isEmpty);
    expect(key.readAsBytesSync(), List.filled(64, 7));
  });

  test('with the switch off nothing goes', () async {
    linkedRoleForTest = true;
    linkedDevicesForTest = false;
    await torAsLinked(at: 'link');
    expect(tor.asked, isEmpty);
    expect(key.existsSync(), isTrue);
  });
}
