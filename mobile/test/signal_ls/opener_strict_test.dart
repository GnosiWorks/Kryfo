// SPDX-License-Identifier: GPL-3.0-or-later
// an opener is read one way before anything is decrypted: a copy with a
// second message field, a field repeated, an unknown one or a varint in a
// longer form than it needs is refused, so its fingerprint is the one
// libsignal reads and a read opener never opens again. the crypto review's
// probes of the fix round, as tests
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';

import 'shim_lib.dart';

Future<String> _rows(Phone p) async {
  final out = <String>[];
  for (final t in [
    'sessions',
    'prekeys',
    'kyber_prekeys',
    'kyber_used',
    'opener_reads',
    'peer_identities',
  ]) {
    out.add('$t ${await p.db.query(t)}');
  }
  return out.join('\n');
}

Matcher _code(int c) =>
    throwsA(isA<LsError>().having((e) => e.code, 'code', c));

// [wire] with a field 4 of one zero byte put in front of everything: a
// reader of the first field 4 and libsignal, which keeps the last, differ
String _decoyInFront(String wire, {int byte = 0}) {
  final w = base64Decode(wire);
  return base64Encode([w[0], w[1], 0x22, 0x01, byte, ...w.sublist(2)]);
}

// the same with the decoy after the real message
String _decoyBehind(String wire) {
  final w = base64Decode(wire);
  return base64Encode([...w, 0x22, 0x01, 0x00]);
}

// [wire] with the registration id (field 5) given a second time, last
String _otherReg(String wire) {
  final w = base64Decode(wire);
  return base64Encode([...w, 0x28, 0x07]);
}

Uint8List _body(String wire) => Uint8List.sublistView(base64Decode(wire), 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(SignalSession, SignalSession, Phone, Phone)> pair() async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openLs();
    final bob = await b.openLs();
    await alice.processBundle(
      'bob',
      lsBundleOf(shim!, await bob.makeBundleB64()),
    );
    return (alice, bob, a, b);
  }

  Future<void> turns(Phone a, Phone b, int n) async {
    for (var i = 0; i < n; i++) {
      expect(await a.read('bob', await b.seal('alice', 'b$i')), 'b$i');
      expect(await b.read('alice', await a.seal('bob', 'a$i')), 'a$i');
    }
  }

  test('a read opener stays read, a decoy field or a repeated one makes '
      'no new opener of it, and the store does not move', () async {
    final (alice, _, a, b) = await pair();
    final first = await alice.encryptTo('bob', 'one');
    expect(await b.read('alice', first), 'one');
    await expectLater(b.read('alice', first), _code(LsError.duplicate));
    await turns(a, b, 7);
    final before = await _rows(b);
    await expectLater(b.read('alice', first), _code(LsError.duplicate));
    await expectLater(
      b.read(kFirstContactSlot, first),
      _code(LsError.duplicate),
    );
    await expectLater(b.read('zed', first), _code(LsError.duplicate));
    for (final copy in [
      _decoyInFront(first),
      _decoyInFront(first, byte: 1),
      _decoyBehind(first),
      _otherReg(first),
    ]) {
      await expectLater(b.read('alice', copy), _code(LsError.message));
      await expectLater(
        b.read(kFirstContactSlot, copy),
        _code(LsError.message),
      );
    }
    expect(await _rows(b), before);
  }, skip: needsShim);

  test('a late opener never read opens once, and no decoy of it opens '
      'again', () async {
    final (alice, _, a, b) = await pair();
    final first = await alice.encryptTo('bob', 'one');
    final late = await alice.encryptTo('bob', 'two, late');
    expect(await b.read('alice', first), 'one');
    await turns(a, b, 7);
    // a decoy is refused before it is read, so the real one still opens
    await expectLater(
      b.read('alice', _decoyInFront(late)),
      _code(LsError.message),
    );
    expect(await b.read('alice', late), 'two, late');
    await expectLater(b.read('alice', late), _code(LsError.duplicate));
    for (final copy in [
      _decoyInFront(late),
      _decoyInFront(late, byte: 1),
      _decoyBehind(late),
      _otherReg(late),
    ]) {
      await expectLater(b.read('alice', copy), _code(LsError.message));
    }
  }, skip: needsShim);

  test('the strict read: what libsignal makes passes with the fields it '
      'names, anything else is refused', () async {
    final (alice, _, _, _) = await pair();
    final w = await alice.encryptTo('bob', 'one');
    final body = _body(w);
    final info = shim!.preKeyMessageInfo(body);
    final o = strictOpener(body);
    expect(o.baseKey, info.baseKey);
    expect(o.identity, info.identityKey);
    expect(o.message, isNotEmpty);
    Matcher refused() =>
        throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.message));
    Uint8List b(List<int> x) => Uint8List.fromList(x);
    // an unknown field, a field on the wrong wire type, an id past 2^32
    expect(() => strictOpener(b([...body, 0x48, 0x01])), refused());
    expect(() => strictOpener(b([...body, 0x0a, 0x00])), refused());
    expect(
      () => strictOpener(b([...body, 0x38, 0x80, 0x80, 0x80, 0x80, 0x10])),
      refused(),
    );
    // a varint longer than it needs to be: the tag of a field, then its
    // value
    expect(
      () => strictOpener(b([body[0], 0xa2, 0x00, ...body.sublist(1)])),
      refused(),
    );
    // cut short anywhere, and nothing at all after the version
    for (var n = 1; n < body.length; n += 97) {
      expect(
        () => strictOpener(b(body.sublist(0, n))),
        refused(),
        reason: '$n',
      );
    }
    expect(() => strictOpener(b([body[0]])), refused());
    // an id from 2^63 up reads negative as a dart int: refused as well
    final o2 = strictOpener(body);
    List<int> varint(int v) => [
      for (; v >= 0x80; v >>= 7) 0x80 | (v & 0x7f),
      v,
    ];
    List<int> field(int n, List<int> v) => [
      n << 3 | 2,
      ...varint(v.length),
      ...v,
    ];
    List<int> bare(List<int> kyberId) => [
      body[0],
      ...field(2, o2.baseKey),
      ...field(3, o2.identity),
      0x38,
      ...kyberId,
      ...field(4, o2.message),
    ];
    expect(strictOpener(b(bare([0x01]))).baseKey, o2.baseKey);
    expect(
      () => strictOpener(
        b(bare([0x81, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])),
      ),
      refused(),
    );
    expect(
      () => strictOpener(b(bare([0x80, 0x80, 0x80, 0x80, 0x10]))),
      refused(),
    );
  }, skip: needsShim);

  test('classic openers 0.5.x phones made read strictly too', () {
    final f053 =
        (jsonDecode(
                  File(
                    'test/fixtures/upgrade_053/expected.json',
                  ).readAsStringSync(),
                )
                as Map)['in_flight']
            as Map;
    final f074 =
        (jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
                as Map)['wire']
            as Map;
    for (final w in [
      f053['stranger_to_me'] as String,
      f053['me_to_dave'] as String,
      f074['c1'] as String,
    ]) {
      final body = _body(w);
      expect(base64Decode(w)[0], kLsPreKey);
      final info = shim!.preKeyMessageInfo(body);
      expect(info.version, 3);
      expect(strictOpener(body).baseKey, info.baseKey);
    }
  }, skip: needsShim);
}
