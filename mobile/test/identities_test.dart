// SPDX-License-Identifier: GPL-3.0-or-later
// identities as rows: two identities in one
// database keep apart every session, prekey, key held and opener read;
// one peer reached on both keeps two sessions; each identity's session
// prekeys rotate on their first use after 30 days, the pair they replace
// opens for 16 days more and then nothing does, with the openers it took;
// a heal's kyber key opens once. real signal over rows in maps
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/identities.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart' show LsBundle;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:kryfo/wire_pad.dart' show unpad;

import 'mem_db.dart';
import 'signal_kit.dart';

const _day = 24 * 60 * 60 * 1000;

Uint8List _newKey() => testKeyPair().privateKey.serialize();

// the bundle a heal or a device bundle would carry: [ss]'s session prekeys
Future<LsBundle> _sessionBundle(
  SignalSession ss, {
  int? now,
  int? kyber,
}) async {
  final ids = await ss.sessionPreKeysForUse(now: now);
  final spk = ss.lib.preKeyPublic(
    kLsSigned,
    (await ss.signedPreKeyStore.load(ids.signedId))!,
  );
  final kid = kyber ?? ids.kyberId;
  final k = ss.lib.preKeyPublic(
    kLsKyber,
    (await ss.kyberPreKeyStore.load(kid))!,
  );
  return ss.lib.bundleBuild(
    registrationId: ss.registrationId,
    deviceId: 1,
    preKeyId: null,
    preKey: null,
    signedPreKeyId: ids.signedId,
    signedPreKey: spk.public,
    signedPreKeySignature: spk.signature,
    kyberPreKeyId: kid,
    kyberPreKey: k.public,
    kyberPreKeySignature: k.signature,
    identityKey: ss.identity.public,
  );
}

Future<String> _read(SignalSession ss, String peer, String wire) async {
  final w = base64Decode(wire);
  return unpad(
    utf8.decode(await ss.open(peer, w[0], Uint8List.sublistView(w, 1))),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a store bootstraps row 0 from its key, with the id it gave out',
    () async {
      final db = MemDb();
      final k = testKeyPair();
      final s = await testStore(db: db, keys: k);
      final row = (await identityRow(db, kMainIdent))!;
      expect(row.xPriv, k.privateKey.serialize());
      expect(row.kind, kIdentFace);
      expect(row.regId, s.registrationId);
      final meta = await db.query('signal_meta', where: "k = 'regId'");
      expect(meta.single['v'], '${s.registrationId}');
      // a new main key keeps the id the store gives out
      final next = testKeyPair();
      await putMainIdentity(
        db,
        next.privateKey.serialize(),
        regId: s.registrationId,
      );
      expect(
        (await identityRow(db, kMainIdent))!.xPriv,
        next.privateKey.serialize(),
      );
      expect((await identityRow(db, kMainIdent))!.regId, s.registrationId);
    },
  );

  test(
    'a made identity has a random key and id of its own, and no face',
    () async {
      final db = MemDb();
      await testStore(db: db);
      final a = await makeIdentity(db, kIdentContact, _newKey);
      final b = await makeIdentity(db, kIdentGroup, _newKey);
      expect([a, b], [1, 2]);
      final rows = await identityRows(db);
      expect(rows.map((r) => r.xPriv.toString()).toSet(), hasLength(3));
      expect(rows.map((r) => r.regId).toSet(), hasLength(3));
      expect(() => makeIdentity(db, kIdentFace, _newKey), throwsArgumentError);
      await setIdentityProfile(db, a, name: 'Ana', photo: 3, about: 'hi');
      final row = (await identityRow(db, a))!;
      expect([row.name, row.photo, row.about], ['Ana', 3, 'hi']);
      expect((await identityRow(db, kMainIdent))!.name, isNull);
      // a store for it needs its row
      await expectLater(
        SignalSession(null, 9).bootstrapIdentity(db),
        throwsStateError,
      );
    },
  );

  test('two identities in one database keep everything apart, and one peer '
      'reached on both keeps two sessions', () async {
    final db = MemDb();
    final p0 = await testStore(db: db);
    final ci = SignalSession(
      null,
      await makeIdentity(db, kIdentContact, _newKey),
    );
    await ci.bootstrapIdentity(db);
    expect(ci.identity.public, isNot(p0.identity.public));
    expect(ci.registrationId, isNot(p0.registrationId));
    final them = await testStore();
    // the same name on both, as one peer reached on two of my identities
    await p0.processBundle(
      'peer',
      lsBundleOf(p0.lib, await them.makeBundleB64()),
    );
    await ci.processBundle(
      'peer',
      lsBundleOf(ci.lib, await them.makeBundleB64()),
    );
    final w0 = await p0.encryptTo('peer', 'from main');
    final w1 = await ci.encryptTo('peer', 'from ci');
    expect(await _read(them, 'main', w0), 'from main');
    expect(await _read(them, 'ci', w1), 'from ci');
    expect(
      (await db.query(
        'sessions',
        where: "address = 'peer'",
      )).map((r) => r['ident']).toSet(),
      {0, ci.ident},
    );
    // their answers open each on its own identity only
    final back0 = await them.encryptTo('main', 'to main');
    final back1 = await them.encryptTo('ci', 'to ci');
    expect(await _read(p0, 'peer', back0), 'to main');
    expect(await _read(ci, 'peer', back1), 'to ci');
    await expectLater(_read(ci, 'peer', back0), throwsA(anything));
    // nothing of one is seen by the other
    expect(
      (await p0.preKeyStore.ids()).toSet().intersection(
        (await ci.preKeyStore.ids()).toSet(),
      ),
      isNot(isEmpty),
      reason: 'the ids are the same numbers, held twice',
    );
    for (final id in await ci.preKeyStore.ids()) {
      expect(
        await ci.preKeyStore.load(id),
        isNot(await p0.preKeyStore.load(id)),
        reason: '$id',
      );
    }
    expect(
      await ci.signedPreKeyStore.load(1),
      isNot(await p0.signedPreKeyStore.load(1)),
    );
    expect(await ci.identityStore.getIdentity('peer'), isNotNull);
    await p0.identityStore.removePeerIdentity('peer');
    expect(await ci.identityStore.getIdentity('peer'), isNotNull);
    await p0.sessionStore.deleteAll('peer');
    expect(await ci.hasSession('peer'), isTrue);
    expect(await p0.hasSession('peer'), isFalse);
    expect(await p0.sessionStore.allSessionAddresses(), isEmpty);
    expect(await ci.sessionStore.allSessionAddresses(), ['peer']);
    // a rekey of one leaves the other's keys
    final ciSpk = await ci.signedPreKeyStore.load(1);
    final k = testKeyPair();
    await p0.rekey(
      database: db,
      xPubBytes: k.xPub,
      xPrivBytes: k.privateKey.serialize(),
    );
    expect(await ci.signedPreKeyStore.load(1), ciSpk);
  });

  test('session prekeys: one pair made with the identity, replaced on its '
      'first use after 30 days, the old one opening 16 days more and then '
      'nothing, with the openers it took', () async {
    final db = MemDb();
    final me = await testStore(db: db);
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final first = await me.sessionPreKeysForUse(now: t0);
    expect(first.signedId, isNot(1));
    expect(first.kyberId, isNot(kInviteKyberId));
    // made once, kept on every start
    await me.keepSessionPreKeys(now: t0 + _day);
    expect(await me.sessionPreKeysForUse(now: t0 + 29 * _day), first);
    expect(
      await db.query('signed_prekeys', where: "use = 'session'"),
      hasLength(1),
    );
    // a heal built on them, sealed before the rotation
    final healer = await testStore();
    await healer.processBundle('me', await _sessionBundle(me, now: t0));
    final early = await healer.encryptTo('me', 'sealed on the old pair');
    final copy = await healer.encryptTo('me', 'and again');
    // the first use after 30 days replaces both
    final next = await me.sessionPreKeysForUse(now: t0 + 30 * _day);
    expect(next.signedId, isNot(first.signedId));
    expect(next.kyberId, isNot(first.kyberId));
    final old = await db.query(
      'kyber_prekeys',
      where: 'id = ?',
      whereArgs: [first.kyberId],
    );
    expect(old.single['retired_at'], t0 + 30 * _day);
    // the old pair still opens for 16 days
    await me.keepSessionPreKeys(now: t0 + 45 * _day);
    expect(await _read(me, 'healer', early), 'sealed on the old pair');
    expect(
      await db.query(
        'kyber_used',
        where: 'kyber_id = ?',
        whereArgs: [first.kyberId],
      ),
      isNotEmpty,
    );
    expect(
      await db.query(
        'opener_reads',
        where: 'kyber_id = ?',
        whereArgs: [first.kyberId],
      ),
      isNotEmpty,
    );
    // then it goes, with what it opened, and the same opener opens nowhere
    await me.keepSessionPreKeys(now: t0 + 46 * _day);
    expect(await me.kyberPreKeyStore.load(first.kyberId), isNull);
    expect(await me.signedPreKeyStore.load(first.signedId), isNull);
    for (final t in ['kyber_used', 'opener_reads']) {
      expect(
        await db.query(t, where: 'kyber_id = ?', whereArgs: [first.kyberId]),
        isEmpty,
        reason: t,
      );
    }
    await me.sessionStore.deleteAll('healer');
    await expectLater(_read(me, 'healer', copy), throwsA(anything));
    // the invite's keys were never touched
    expect(await me.signedPreKeyStore.load(1), isNotNull);
    expect(await me.kyberPreKeyStore.load(kInviteKyberId), isNotNull);
    expect(await me.preKeyStore.load(invitePreKeyId), isNotNull);
  });

  test(
    'a heal kyber opens one opener and goes, or goes unused after 16 days',
    () async {
      final db = MemDb();
      final me = await testStore(db: db);
      final t0 = DateTime.now().millisecondsSinceEpoch;
      final heal = await me.makeHealKyber(now: t0);
      final row = (await db.query(
        'kyber_prekeys',
        where: 'id = ?',
        whereArgs: [heal],
      )).single;
      expect([row['use'], row['last_resort']], [kUseHeal, 0]);
      final peer = await testStore();
      await peer.processBundle(
        'me',
        await _sessionBundle(me, now: t0, kyber: heal),
      );
      expect(
        await _read(me, 'peer', await peer.encryptTo('me', 'heal')),
        'heal',
      );
      expect(await me.kyberPreKeyStore.load(heal), isNull);
      final unused = await me.makeHealKyber(now: t0);
      await me.keepSessionPreKeys(now: t0 + 15 * _day);
      expect(await me.kyberPreKeyStore.load(unused), isNotNull);
      await me.keepSessionPreKeys(now: t0 + 16 * _day);
      expect(await me.kyberPreKeyStore.load(unused), isNull);
    },
  );

  test(
    'one contact per identity key: a second row with it claims nothing',
    () async {
      final db = MemDb();
      final x = 'ab' * 32;
      for (final (id, at) in [('first-one-here', 1), ('second-one-here', 2)]) {
        await db.insert('contacts', {
          'halo_id': id,
          'onion': '',
          'xpub': x,
          'first_seen': at,
          'last_seen': at,
        });
        await claimContactKeys(db, only: id);
      }
      final rows = {
        for (final r in await db.query('contacts')) r['halo_id']: r['ikey'],
      };
      expect(rows, {'first-one-here': '05$x', 'second-one-here': null});
      expect(await contactOfKey(db, x.toUpperCase()), 'first-one-here');
      expect(await db.query('pairs'), hasLength(1));
      expect((await pairOf(db, 0, '05$x')).conv, kConvClassic);
      // once the first lets it go, the second takes it
      await db.update('contacts', {
        'xpub': '',
      }, where: "halo_id = 'first-one-here'");
      await claimContactKeys(db, only: 'first-one-here');
      await claimContactKeys(db, only: 'second-one-here');
      expect(await contactOfKey(db, x), 'second-one-here');
    },
  );

  test('a pair takes a seed once, and keeps its addresses for life', () async {
    final db = MemDb();
    final seed = Uint8List.fromList(List.generate(32, (i) => i));
    await putSeededPair(db, 1, '05${'cd' * 32}', seed);
    final p = await pairOf(db, 1, '05${'cd' * 32}');
    expect(p.conv, kConvSeeded);
    expect(p.seed, seed);
    expect((await pairOf(db, 0, '05${'cd' * 32}')).conv, kConvClassic);
    await expectLater(
      putSeededPair(db, 1, '05${'cd' * 32}', seed),
      throwsStateError,
    );
    expect(
      () => putSeededPair(db, 1, '05${'ef' * 32}', Uint8List(31)),
      throwsArgumentError,
    );
  });

  test(
    'first-contact keys: one random key per invite, retired with it',
    () async {
      final db = MemDb();
      var tries = 0;
      final sk = await makeFcKey(db, 1, 'inv-a', (k) => ++tries > 1);
      expect(tries, 2);
      expect(sk, hasLength(32));
      final b = await makeFcKey(db, 1, 'inv-b', (_) => true);
      expect(b, isNot(sk));
      expect((await fcKeysOf(db, 1)).keys, unorderedEquals(['inv-a', 'inv-b']));
      expect(await fcKeysOf(db, 0), isEmpty);
      await retireFcKey(db, 1, 'inv-a');
      expect((await fcKeysOf(db, 1)).keys, ['inv-b']);
    },
  );
}
