// SPDX-License-Identifier: GPL-3.0-or-later
// no new classic session through the shim: a card without the kyber
// prekey, a card with it stripped or its signature broken, and a version 3
// opener for a session not held are all refused, and nothing is stored for
// them. a classic session already held goes on. the same against a phone
// still running 0.5.3's own library is in tool/peer053
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';

import '../mem_db.dart';
import 'shim_lib.dart';

final _fixture =
    jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
        as Map<String, dynamic>;

Object? _value(Object? v) => v is Map ? base64Decode(v['b64'] as String) : v;

// a phone off the 0.7.4 fixture, its store as the old library wrote it,
// leaving out the rows [skip] names
Future<Phone> _stored(String who, {bool Function(Map row)? skip}) async {
  final db = MemDb();
  for (final r in (_fixture[who] as Map)['rows'] as List) {
    final row = (r as Map)['row'] as Map;
    if (skip?.call(r) ?? false) continue;
    await db.insert(r['t'] as String, {
      for (final e in row.entries) e.key as String: _value(e.value),
    });
  }
  final me = _fixture[who] as Map;
  return Phone.of((
    pub: base64Decode(me['pub'] as String),
    priv: base64Decode(me['priv'] as String),
  ), db);
}

String _wire(String k) => (_fixture['wire'] as Map)[k] as String;

Map<String, dynamic> _json(String card) =>
    jsonDecode(utf8.decode(base64Decode(card))) as Map<String, dynamic>;

String _card(Map<String, dynamic> j) =>
    base64Encode(utf8.encode(jsonEncode(j)));

Matcher _code(int c) =>
    throwsA(isA<LsError>().having((e) => e.code, 'code', c));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('(a) no session from a card without a kyber prekey', () async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openLs();
    await b.openLs();
    // a 0.5.x card
    final card = await b.classicCard();
    expect(() => lsBundleOf(shim!, card), throwsA(isA<ClassicRefused>()));
    // the shim says the same when asked directly
    final j = _json(card);
    expect(
      () => shim!.bundleBuild(
        registrationId: j['registrationId'] as int,
        preKeyId: j['preKeyId'] as int,
        preKey: base64Decode(j['preKeyPublic'] as String),
        signedPreKeyId: j['signedPreKeyId'] as int,
        signedPreKey: base64Decode(j['signedPreKeyPublic'] as String),
        signedPreKeySignature: base64Decode(
          j['signedPreKeySignature'] as String,
        ),
        identityKey: base64Decode(j['identityKey'] as String),
      ),
      _code(LsError.classic),
    );
    expect(await alice.hasSession('bob'), isFalse);
    expect(await alice.identityStore.getIdentity('bob'), isNull);
  }, skip: needsShim);

  test('(b) a stripped or broken kyber prekey is refused', () async {
    final a = Phone();
    final b = Phone();
    final c = Phone();
    final alice = await a.openLs();
    final bob = await b.openLs();
    final carol = await c.openLs();
    final good = _json(await bob.makeBundleB64());
    final other = _json(await carol.makeBundleB64());

    // the kyber part taken out, all of it or a piece
    for (final drop in [
      ['kyberPreKeyId', 'kyberPreKeyPublic', 'kyberPreKeySignature'],
      ['kyberPreKeyPublic'],
      ['kyberPreKeySignature'],
    ]) {
      final j = {...good}..removeWhere((k, _) => drop.contains(k));
      expect(
        () => lsBundleOf(shim!, _card(j)),
        throwsA(isA<ClassicRefused>()),
        reason: '$drop',
      );
    }
    // its signature broken
    final sig = base64Decode(good['kyberPreKeySignature'] as String);
    sig[10] ^= 1;
    expect(
      () => lsBundleOf(
        shim!,
        _card({...good, 'kyberPreKeySignature': base64Encode(sig)}),
      ),
      _code(LsError.signature),
    );
    // someone else's kyber key, with or without its own signature
    expect(
      () => lsBundleOf(
        shim!,
        _card({...good, 'kyberPreKeyPublic': other['kyberPreKeyPublic']}),
      ),
      _code(LsError.signature),
    );
    expect(
      () => lsBundleOf(
        shim!,
        _card({
          ...good,
          'kyberPreKeyPublic': other['kyberPreKeyPublic'],
          'kyberPreKeySignature': other['kyberPreKeySignature'],
        }),
      ),
      _code(LsError.signature),
    );
    // the ec signature where the kyber one goes
    expect(
      () => lsBundleOf(
        shim!,
        _card({...good, 'kyberPreKeySignature': good['signedPreKeySignature']}),
      ),
      _code(LsError.signature),
    );
    expect(await alice.hasSession('bob'), isFalse);
    // the card as it came opens a session
    await alice.processBundle('bob', lsBundleOf(shim!, _card(good)));
    expect((await alice.sessionInfo('bob'))!.version, 4);
  }, skip: needsShim);

  test('(c) a version 3 opener for a new session is refused', () async {
    // the 0.7.4 fixture's opener from carol, on a prekey bob still holds,
    // with bob's session with her gone
    final b = await _stored(
      'bob',
      skip: (r) =>
          r['t'] == 'sessions' && (r['row'] as Map)['address'] == 'carol',
    );
    final bob = await b.openLs();
    final c1 = _wire('c1');
    final body = base64Decode(c1).sublist(1);
    final info = shim!.preKeyMessageInfo(body);
    expect(info.version, 3);
    expect(await bob.preKeyStore.contains(info.preKeyId!), isTrue);
    final carolKey = await bob.identityStore.getIdentity('carol');
    await expectLater(
      bob.open('carol', base64Decode(c1)[0], Uint8List.fromList(body)),
      _code(LsError.classic),
    );
    // nothing of it kept, and the one-time prekey is still there
    expect(await bob.hasSession('carol'), isFalse);
    expect(await bob.identityStore.getIdentity('carol'), carolKey);
    expect(await bob.preKeyStore.contains(info.preKeyId!), isTrue);
    // under a name nobody holds, as a first contact would read it
    await expectLater(
      bob.open('_pending_back_pair_', kLsPreKey, Uint8List.fromList(body)),
      _code(LsError.classic),
    );
    expect(await bob.hasSession('_pending_back_pair_'), isFalse);
    expect(await bob.preKeyStore.contains(info.preKeyId!), isTrue);
  }, skip: needsShim);

  test('(d) a version 3 session already held still seals and opens', () async {
    final a = await _stored('alice');
    final b = await _stored('bob');
    final alice = await a.openLs();
    final bob = await b.openLs();
    expect(await b.read('alice', _wire('a6')), 'a6 pending');
    for (var i = 0; i < 3; i++) {
      final w = await bob.encryptTo('alice', 'b$i');
      expect(base64Decode(w)[0], kLsWhisper);
      expect(await a.read('bob', w), 'b$i');
      expect(await b.read('alice', await alice.encryptTo('bob', 'a$i')), 'a$i');
    }
    for (final s in [alice, bob]) {
      final info = (await s.sessionInfo(s == alice ? 'bob' : 'alice'))!;
      expect(info.version, 3);
      expect(info.pq, isFalse);
    }
  }, skip: needsShim);
}
