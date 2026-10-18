// SPDX-License-Identifier: GPL-3.0-or-later
// no new classic session through the shim: a card without the kyber
// prekey, a card with it stripped or its signature broken, and a version 3
// opener for a session not held are all refused, and nothing is stored for
// them. a classic session already held goes on
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_session_ls.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'shim_lib.dart';

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
    await b.openOld();
    // a 0.5.x card
    final card = await b.oldCard();
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
    final a = Phone();
    final b = Phone();
    final alice = await a.openOld();
    final bob = await b.openLs();
    // an old app reads the new card, skips what it does not know, and
    // builds a classic session on a one-time prekey of bob's
    final j = _json(await bob.makeBundleB64());
    final pk = PreKeyRecord.fromBuffer((await bob.preKeyStore.load(4))!);
    final classic = PreKeyBundle(
      j['registrationId'] as int,
      1,
      4,
      pk.getKeyPair().publicKey,
      j['signedPreKeyId'] as int,
      Curve.decodePoint(base64Decode(j['signedPreKeyPublic'] as String), 0),
      base64Decode(j['signedPreKeySignature'] as String),
      IdentityKey(
        Curve.decodePoint(base64Decode(j['identityKey'] as String), 0),
      ),
    );
    await alice.processBundle('bob', classic);
    final wire = await alice.encryptTo('bob', 'classic hello');
    expect(base64Decode(wire)[0], CiphertextMessage.prekeyType);
    expect(shim!.preKeyMessageInfo(base64Decode(wire).sublist(1)).version, 3);
    await expectLater(b.read('alice', wire), _code(LsError.classic));
    // nothing of it kept, and the one-time prekey is still there
    expect(await bob.hasSession('alice'), isFalse);
    expect(await bob.identityStore.getIdentity('alice'), isNull);
    expect(await bob.preKeyStore.contains(4), isTrue);

    // the 0.7.4 fixture's opener from carol, on a prekey bob still holds
    final f =
        jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
            as Map<String, dynamic>;
    final c1 = (f['wire'] as Map)['c1'] as String;
    final body = base64Decode(c1).sublist(1);
    expect(shim!.preKeyMessageInfo(body).version, 3);
    await expectLater(
      bob.open('carol', base64Decode(c1)[0], Uint8List.fromList(body)),
      _code(LsError.classic),
    );
  }, skip: needsShim);

  test('(d) a version 3 session already held still seals and opens', () async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openOld();
    await b.openOld();
    await alice.processBundle('bob', preKeyBundleOf(await b.oldCard()));
    // the opener is read on the old library, before bob updates
    expect(await b.read('alice', await alice.encryptTo('bob', 'hi')), 'hi');
    final bob = await b.openLs();
    for (var i = 0; i < 3; i++) {
      final w = await bob.encryptTo('alice', 'b$i');
      expect(base64Decode(w)[0], kLsWhisper);
      expect(await a.read('bob', w), 'b$i');
      expect(await b.read('alice', await alice.encryptTo('bob', 'a$i')), 'a$i');
    }
    final info = (await bob.sessionInfo('alice'))!;
    expect(info.version, 3);
    expect(info.pq, isFalse);
  }, skip: needsShim);

  test(
    'an unanswered classic opener held on the shim still goes out',
    () async {
      // alice built a classic session on 0.5.x and updated before bob
      // answered: her next seal is still the version 3 opener, which bob,
      // still on the old library, takes
      final a = Phone();
      final b = Phone();
      final old = await a.openOld();
      await b.openOld();
      await old.processBundle('bob', preKeyBundleOf(await b.oldCard()));
      final alice = await a.openLs();
      final w = await alice.encryptTo('bob', 'still classic');
      expect(base64Decode(w)[0], kLsPreKey);
      expect(await b.read('alice', w), 'still classic');
      expect(await a.read('bob', await b.seal('alice', 'back')), 'back');
    },
    skip: needsShim,
  );
}
