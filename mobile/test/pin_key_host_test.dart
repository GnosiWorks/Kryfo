// SPDX-License-Identifier: GPL-3.0-or-later
// the pin table through the real engine (tool/host_engine.sh): the two calls
// of a check with a pin key in dart between them, a pin moved under it, a
// table that needs it, a rewrap's two calls, and pins the engine refuses
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/pass_rules.dart';

import 'host_engine.dart';

// the pin key in plain dart: hmac under a secret, counted
class _Key {
  _Key(this.secret);
  final String secret;
  int calls = 0;
  Future<String> mac(String x) async {
    calls++;
    final x0 = [
      for (var i = 0; i < x.length; i += 2)
        int.parse(x.substring(i, i + 2), radix: 16),
    ];
    return Hmac(sha256, utf8.encode(secret)).convert(x0).toString();
  }
}

final _info = jsonEncode({'g': 1, 'u': 1, 'l': 2, 'kc': 'ab' * 32});
final _box = '07' * 16;

void main() {
  final there = loadHostEngine();
  final skip = there ? false : 'no host engine';
  final e = FfiPinEngine();

  Future<String> set(
    String table,
    String pin,
    int index,
    int kind, {
    _Key? key,
    String wrap = '',
  }) async {
    final out = await e.setup(
      pin,
      table,
      '',
      index,
      kind,
      _box,
      wrap,
      mac: key?.mac,
      key: key == null ? '' : _info,
    );
    return jsonEncode(out['t']);
  }

  test('a pin set with the key opens only with it', () async {
    final k = _Key('one phone');
    var t = await e.newTable(14);
    t = await set(t, '1234', 0, 1, key: k);
    expect(k.calls, 1);
    expect(jsonDecode(t)['v'], 3);
    var r = await e.check('1234', t, '', mac: k.mac, key: _info);
    expect(r['i'], 0);
    expect(r['g'], 3);
    expect(k.calls, 2);
    r = await e.check('1234', t, '');
    expect(r['i'], -1);
    r = await e.check('1234', t, '', mac: _Key('another phone').mac);
    expect(r['i'], -1);
    // and nothing goes in under the old key once the table is v3
    await expectLater(set(t, '5555', 2, 3), throwsA(isA<PinKeyBusy>()));
  }, skip: skip);

  test('an entry from before moves on its use, its vault key kept', () async {
    final k = _Key('one phone');
    var t = await e.newTable(14);
    t = await set(t, '1234', 0, 1);
    t = await set(t, '246810', 3, 4, wrap: '1f' * 32);
    final r = await e.check('246810', t, '', mac: k.mac, key: _info);
    expect(r['i'], 3);
    expect(r['g'], 2);
    expect(r['mv'], 'e');
    expect(r['u'], '1f' * 32);
    final moved = jsonEncode(r['r']);
    expect(jsonDecode(moved)['v'], 3);
    final again = await e.check('246810', moved, '', mac: k.mac, key: _info);
    expect(again['g'], 3);
    expect(again['u'], '1f' * 32);
    expect(again['r'], isNull);
    final app = await e.check('1234', moved, '', mac: k.mac, key: _info);
    expect(app['g'], 2);
  }, skip: skip);

  test('a rewrap asks the key twice and keeps the vault key', () async {
    final k = _Key('one phone');
    var t = await e.newTable(14);
    t = await set(t, '246810', 3, 4, key: k, wrap: '2e' * 32);
    k.calls = 0;
    final out = await e.rewrap(
      '246810',
      'correct horse ۱۲ battery',
      t,
      '',
      3,
      mac: k.mac,
      key: _info,
    );
    expect(k.calls, 2);
    final r = await e.check(
      'correct horse 12 battery',
      jsonEncode(out['t']),
      '',
      mac: k.mac,
      key: _info,
    );
    expect(r['i'], 3);
    expect(r['u'], '2e' * 32);
  }, skip: skip);

  test('pins the engine will not take match nothing here', () async {
    final t = await e.newTable(14);
    for (final bad in ['a\u0000b', 'tab\there', 'a' * 257, '']) {
      await expectLater(
        e.check(bad, t, ''),
        throwsA(isA<ArgumentError>()),
        reason: bad,
      );
    }
  }, skip: skip);

  test('an answer that cannot be the key is no answer', () async {
    final k = _Key('one phone');
    var t = await e.newTable(14);
    t = await set(t, '1234', 0, 1, key: k);
    for (final odd in ['00' * 32, 'zz', '']) {
      final r = await e.check('1234', t, '', mac: (_) async => odd);
      expect(r['i'], -1, reason: odd);
    }
  }, skip: skip);

  test('a phrase nfc makes too long is refused before it is set', () {
    // 255 bytes as typed, 510 once the engine composes it
    final qa = '\u0958' * 85;
    expect(passUsable(qa), isTrue);
    expect(enginePinFits(qa), isFalse);
    expect(enginePinFits('correct horse battery'), isTrue);
  }, skip: skip);
}
