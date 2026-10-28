// SPDX-License-Identifier: GPL-3.0-or-later
// the dart bindings over the shim, and the new layer between two phones
// that both run it: pqxdh, the pq ratchet, prekeys spent as they should be
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';

import 'shim_lib.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keys, bundles and errors through the bindings', () {
    final s = shim!;
    final me = s.identityGenerate();
    expect(me.public, hasLength(33));
    final again = s.identityFromPrivate(xPairOf(s, me));
    expect(again.public, me.public);

    final pk = s.preKey(5);
    final spk = s.signedPreKey(me, 1, 1000);
    final k = s.kyberPreKey(me, 2, 1000);
    expect(k.public, hasLength(1569));
    expect(s.verify(me.public, spk.public, spk.signature), isTrue);
    expect(s.verify(me.public, k.public, k.signature), isTrue);
    expect(s.verify(me.public, k.public, spk.signature), isFalse);
    expect(s.preKeyPublic(kLsKyber, k.record).public, k.public);
    expect(s.preKeyPublic(kLsOneTime, pk.record).id, 5);

    final b = s.bundleBuild(
      registrationId: 9,
      preKeyId: pk.id,
      preKey: pk.public,
      signedPreKeyId: spk.id,
      signedPreKey: spk.public,
      signedPreKeySignature: spk.signature,
      kyberPreKeyId: k.id,
      kyberPreKey: k.public,
      kyberPreKeySignature: k.signature,
      identityKey: me.public,
    );
    final back = s.bundleParse(b.bytes);
    expect(back.kyberPreKey, k.public);
    expect(back.identityKey, me.public);
    expect(back.preKeyId, 5);

    expect(
      () => s.bundleParse(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.key)),
    );
    expect(
      () => s.sessionInfo(Uint8List.fromList([0xff, 0xff])),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.session)),
    );
  }, skip: needsShim);

  test('two phones on the shim talk pqxdh with the pq ratchet', () async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openLs();
    final bob = await b.openLs();
    final card = await bob.makeBundleB64();
    final j = jsonDecode(utf8.decode(base64Decode(card))) as Map;
    expect(j['kyberPreKeyId'], kInviteKyberId);

    await alice.processBundle('bob', lsBundleOf(shim!, card));
    expect((await alice.sessionInfo('bob'))!.version, 4);

    final first = await alice.encryptTo('bob', 'hello bob');
    expect(base64Decode(first)[0], kLsPreKey);
    expect(await b.read('alice', first), 'hello bob');
    // the invite's keys are shared, so both survive the first use
    expect(await bob.preKeyStore.contains(invitePreKeyId), isTrue);
    expect(await bob.kyberPreKeyStore.contains(kInviteKyberId), isTrue);
    // a second opener, on the session alice holds
    final second = await alice.encryptTo('bob', 'again');
    expect(await b.read('alice', second), 'again');
    // a copy of an opener read before is a duplicate, and without the
    // session it built it does not build another on the last resort key
    final held = (await bob.sessionStore.load('alice'))!;
    await expectLater(
      b.read('alice', first),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.duplicate)),
    );
    await bob.sessionStore.delete('alice');
    await expectLater(
      b.read('alice', second),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.duplicate)),
    );
    expect(await bob.hasSession('alice'), isFalse);
    await bob.sessionStore.store('alice', held);

    for (var i = 0; i < 4; i++) {
      final r = await bob.encryptTo('alice', 'b$i');
      expect(base64Decode(r)[0], kLsWhisper);
      expect(await a.read('bob', r), 'b$i');
      expect(await b.read('alice', await alice.encryptTo('bob', 'a$i')), 'a$i');
    }
    for (final (s, peer) in [(alice, 'bob'), (bob, 'alice')]) {
      final info = (await s.sessionInfo(peer))!;
      expect(info.version, 4);
      expect(info.pq, isTrue);
    }
    expect(await alice.peerXPubHex('bob'), _hex(b.keys.pub));
    expect(await bob.peerXPubHex('alice'), _hex(a.keys.pub));
  }, skip: needsShim);

  test('a one-time prekey goes once used, the invite one stays', () async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openLs();
    final bob = await b.openLs();
    final s = shim!;
    final spk = s.preKeyPublic(
      kLsSigned,
      (await bob.signedPreKeyStore.load(1))!,
    );
    final pk = s.preKeyPublic(kLsOneTime, (await bob.preKeyStore.load(3))!);
    final k = s.preKeyPublic(
      kLsKyber,
      (await bob.kyberPreKeyStore.load(kInviteKyberId))!,
    );
    final bundle = s.bundleBuild(
      registrationId: bob.registrationId,
      preKeyId: 3,
      preKey: pk.public,
      signedPreKeyId: 1,
      signedPreKey: spk.public,
      signedPreKeySignature: spk.signature,
      kyberPreKeyId: k.id,
      kyberPreKey: k.public,
      kyberPreKeySignature: k.signature,
      identityKey: bob.identity.public,
    );
    await alice.processBundle('bob', bundle);
    expect(await b.read('alice', await alice.encryptTo('bob', 'hi')), 'hi');
    expect(await bob.preKeyStore.contains(3), isFalse);
    // the bootstrap after it fills the gap
    final bob2 = await b.openLs();
    expect(await bob2.preKeyStore.contains(3), isTrue);
  }, skip: needsShim);

  test(
    'a check that throws leaves the store and the prekeys as they were',
    () async {
      final a = Phone();
      final b = Phone();
      final alice = await a.openLs();
      final bob = await b.openLs();
      await alice.processBundle(
        'bob',
        lsBundleOf(shim!, await bob.makeBundleB64()),
      );
      final w = base64Decode(await alice.encryptTo('bob', 'turned down'));
      await expectLater(
        bob.open(
          'alice',
          w[0],
          Uint8List.fromList(w.sublist(1)),
          check: (_) => throw StateError('full'),
        ),
        throwsStateError,
      );
      expect(await bob.hasSession('alice'), isFalse);
      expect(await bob.identityStore.getIdentity('alice'), isNull);
      // and it opens later, when there is room
      expect(
        unpadText(
          await bob.open('alice', w[0], Uint8List.fromList(w.sublist(1))),
        ),
        'turned down',
      );
    },
    skip: needsShim,
  );

  group('an opener opens once', () {
    // bob's store once he took alice's first opener, and the phones
    Future<(SignalSession, SignalSession, String, Phone, Phone)> took() async {
      final a = Phone();
      final b = Phone();
      final alice = await a.openLs();
      final bob = await b.openLs();
      await alice.processBundle(
        'bob',
        lsBundleOf(shim!, await bob.makeBundleB64()),
      );
      final w = await alice.encryptTo('bob', 'first');
      expect(await b.read('alice', w), 'first');
      return (alice, bob, w, a, b);
    }

    Future<Map<String, Object?>> rows(Phone p) async => {
      for (final t in [
        'sessions',
        'prekeys',
        'kyber_prekeys',
        'kyber_used',
        'opener_reads',
        'peer_identities',
      ])
        t: '${await p.db.query(t)}',
    };

    Matcher dup() => throwsA(
      isA<LsError>().having((e) => e.code, 'code', LsError.duplicate),
    );

    // turns each way, more than the five chains a record keeps
    Future<void> turns(Phone a, Phone b, int n) async {
      for (var i = 0; i < n; i++) {
        expect(await a.read('bob', await b.seal('alice', 'b$i')), 'b$i');
        expect(await b.read('alice', await a.seal('bob', 'a$i')), 'a$i');
      }
    }

    test('read once, then a copy is refused, right away or seven turns '
        'later, as often as it comes', () async {
      final (_, _, w, a, b) = await took();
      await expectLater(b.read('alice', w), dup());
      await turns(a, b, 7);
      final before = await rows(b);
      for (var i = 0; i < 3; i++) {
        await expectLater(b.read('alice', w), dup());
      }
      expect(await rows(b), before);
    }, skip: needsShim);

    test('a copy in the first-contact slot seven turns later is refused, '
        'and nothing is filed there', () async {
      final (_, bob, w, a, b) = await took();
      await turns(a, b, 7);
      final before = await rows(b);
      await expectLater(b.read(kFirstContactSlot, w), dup());
      expect(await bob.hasSession(kFirstContactSlot), isFalse);
      expect(await rows(b), before);
    }, skip: needsShim);

    test('under another name a copy is refused, and nothing is kept', () async {
      final (_, _, w, _, b) = await took();
      final before = await rows(b);
      await expectLater(b.read('another-name', w), dup());
      expect(await rows(b), before);
    }, skip: needsShim);

    test('once the session it built is gone it is refused, and builds '
        'nothing', () async {
      final (_, bob, w, _, b) = await took();
      await bob.sessionStore.delete('alice');
      final before = await rows(b);
      for (final name in ['alice', 'another-name', kFirstContactSlot]) {
        await expectLater(b.read(name, w), dup());
      }
      expect(await rows(b), before);
    }, skip: needsShim);

    test('a second opener never read opens in the first-contact slot, and '
        'files only under the name holding its session', () async {
      final a = Phone();
      final b = Phone();
      final alice = await a.openLs();
      final bob = await b.openLs();
      await alice.processBundle(
        'bob',
        lsBundleOf(shim!, await bob.makeBundleB64()),
      );
      final first = await alice.encryptTo('bob', 'one');
      final second = await alice.encryptTo('bob', 'two');
      expect(await b.read(kFirstContactSlot, first), 'one');
      await bob.keepOpenedSession(
        'alice',
        (await bob.sessionStore.load(kFirstContactSlot))!,
      );
      await bob.sessionStore.delete(kFirstContactSlot);
      // the second, sent before bob answered, comes in on the same slot
      expect(await b.read(kFirstContactSlot, second), 'two');
      final scratch = (await bob.sessionStore.load(kFirstContactSlot))!;
      await expectLater(
        bob.keepOpenedSession('mallory-words', scratch),
        throwsStateError,
      );
      expect(await bob.hasSession('mallory-words'), isFalse);
      await bob.keepOpenedSession('alice', scratch);
      await bob.sessionStore.delete(kFirstContactSlot);
      // and only once
      await expectLater(b.read(kFirstContactSlot, second), dup());
      expect(await a.read('bob', await bob.encryptTo('alice', 'back')), 'back');
    }, skip: needsShim);

    test('late, past the chains a record keeps, one never read opens once, '
        'and the session goes on as it was', () async {
      final a = Phone();
      final b = Phone();
      final alice = await a.openLs();
      final bob = await b.openLs();
      await alice.processBundle(
        'bob',
        lsBundleOf(shim!, await bob.makeBundleB64()),
      );
      final first = await alice.encryptTo('bob', 'one');
      final late = await alice.encryptTo('bob', 'two, late');
      expect(await b.read('alice', first), 'one');
      await turns(a, b, 7);
      final held = await bob.sessionStore.load('alice');
      expect(await b.read('alice', late), 'two, late');
      expect(await bob.sessionStore.load('alice'), held);
      for (var i = 0; i < 3; i++) {
        await expectLater(b.read('alice', late), dup());
      }
      expect(await b.read('alice', await alice.encryptTo('bob', 'on')), 'on');
    }, skip: needsShim);

    test('the spend is one write: one that fails keeps nothing of the '
        'open, and the opener opens later', () async {
      final a = Phone();
      final b = Phone();
      final alice = await a.openLs();
      final bob = await b.openLs();
      await alice.processBundle(
        'bob',
        lsBundleOf(shim!, await bob.makeBundleB64()),
      );
      final w = await alice.encryptTo('bob', 'hi');
      final before = await rows(b);
      b.db.failOn = 'insert:opener_reads';
      await expectLater(b.read('alice', w), throwsA(anything));
      b.db.failOn = null;
      expect(await rows(b), before);
      expect(await bob.hasSession('alice'), isFalse);
      expect(await b.read('alice', w), 'hi');
    }, skip: needsShim);
  });

  test('a changed key is flagged and the message still arrives', () async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openLs();
    final bob = await b.openLs();
    await b.db.insert('contacts', {
      'halo_id': 'alice',
      'onion': '',
      'xpub': '',
      'first_seen': 0,
      'last_seen': 0,
      'verified': 1,
    });
    final card = await bob.makeBundleB64();
    await alice.processBundle('bob', lsBundleOf(shim!, card));
    expect(await b.read('alice', await alice.encryptTo('bob', 'one')), 'one');

    // alice reinstalls: a new key under the same name
    final a2 = Phone();
    final alice2 = await a2.openLs();
    await alice2.processBundle('bob', lsBundleOf(shim!, card));
    expect(await b.read('alice', await alice2.encryptTo('bob', 'two')), 'two');
    final row = (await b.db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: ['alice'],
    )).first;
    expect(row['key_changed'], 1);
    expect(row['verified'], 0);
    expect(
      await bob.identityStore.getIdentity('alice'),
      alice2.identity.public,
    );
  }, skip: needsShim);
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

// the private half of an identity the shim made, as the app would hold it
List<int> xPairOf(KryfoSignal s, LsIdentity id) {
  // IdentityKeyPairStructure: field 1 the public key, field 2 the private
  final p = id.pair;
  var at = 0;
  while (at < p.length) {
    final tag = p[at++];
    final n = p[at++];
    if (tag == 0x12) return p.sublist(at, at + n);
    at += n;
  }
  throw StateError('no private key');
}
