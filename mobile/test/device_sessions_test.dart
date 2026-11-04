// SPDX-License-Identifier: GPL-3.0-or-later
// copies of one message to every device of a contact and of my own, each on
// its own session in the store, on the host shim
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/device_sessions.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart' show LsBundle;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show kSealSizes, unpad;

import 'signal_kit.dart';

// a linked device of an identity: its own store, key and reg, and its id
class Dev {
  Dev(this.id, this.store) : ds = DeviceSessions(store, linked: true);
  final int id;
  final SignalSession store;
  final DeviceSessions ds;
  Uint8List get key => store.identity.public;
  int get reg => store.registrationId;
}

Future<List<Dev>> devices(List<int> ids) async => [
  for (final id in ids) Dev(id, await testStore()),
];

(int, Uint8List) wireOf(String w) {
  final b = base64Decode(w);
  return (b[0], Uint8List.sublistView(b, 1));
}

String textOf(Uint8List plain) => unpad(utf8.decode(plain));

// the gift wrap a relay stores for a signal wire of [n] base64 characters,
// worked out as wire_pad_test does
int wrapOf(int n) {
  int b64(int n) => 4 * ((n + 2) ~/ 3);
  int pad(int l) {
    if (l <= 32) return 32;
    var np = 1;
    while (np < l) {
      np <<= 1;
    }
    final chunk = np <= 256 ? 32 : np ~/ 8;
    return chunk * ((l - 1) ~/ chunk + 1);
  }

  int nip44(int l) => b64(67 + pad(l));
  return 445 + nip44(343 + nip44(206 + n));
}

void main() {
  late SignalSession ana;
  late SignalSession bob;
  late DeviceSessions anaDs;
  late List<Dev> bobs;

  setUp(() async {
    ana = await testStore();
    bob = await testStore();
    anaDs = DeviceSessions(ana);
    bobs = await devices([2, 17, 40, 99, 127]);
  });

  // ana's sessions with each of bob's linked devices, from their KDB1s
  Future<void> buildAll() async {
    for (final d in bobs) {
      final block = ana.lib.parseDeviceBundle(
        await d.ds.makeBundle(d.id),
        bob.identity.public,
      );
      await anaDs.build('bob', d.id, block, d.key, d.reg);
    }
  }

  test('one message reaches five devices, each on its own session', () async {
    await buildAll();
    expect(await anaDs.held('bob'), hasLength(5));
    final copies = <int, String>{
      for (final d in bobs)
        d.id: await anaDs.seal('bob', d.id, '{"t":"hi"}', d.key),
    };
    // every copy an opener, filled to one size
    final sizes = {for (final c in copies.values) base64Decode(c).length};
    expect(
      sizes.reduce((a, b) => a > b ? a : b) -
          sizes.reduce((a, b) => a < b ? a : b),
      lessThanOrEqualTo(4),
    );
    for (final d in bobs) {
      final (type, body) = wireOf(copies[d.id]!);
      expect(type, kLsPreKey);
      final plain = await d.ds.open(
        'ana',
        1,
        type,
        body,
        ana.identity.public,
        reg: ana.registrationId,
      );
      expect(textOf(plain), '{"t":"hi"}');
      // a copy for another device opens on no other
      for (final o in bobs.where((o) => o.id != d.id)) {
        await expectLater(
          o.ds.open(
            'ana',
            1,
            type,
            body,
            ana.identity.public,
            reg: ana.registrationId,
          ),
          throwsA(anything),
        );
      }
    }
    // each answers once; ana's next copies are plain messages
    for (final d in bobs) {
      final (type, body) = wireOf(
        await d.ds.seal('ana', 1, '{"t":"ok"}', ana.identity.public),
      );
      expect(type, kLsWhisper);
      final got = await anaDs.open('bob', d.id, type, body, d.key, reg: d.reg);
      expect(textOf(got), '{"t":"ok"}');
      expect(await anaDs.answered('bob', d.id, d.key), isTrue);
    }
    for (final d in bobs) {
      final (type, body) = wireOf(
        await anaDs.seal('bob', d.id, '{"t":"plain"}', d.key),
      );
      expect(type, kLsWhisper);
      expect(
        textOf(
          await d.ds.open(
            'ana',
            1,
            type,
            body,
            ana.identity.public,
            reg: ana.registrationId,
          ),
        ),
        '{"t":"plain"}',
      );
    }
  });

  test('a copy opens once', () async {
    await buildAll();
    final d = bobs.first;
    final (type, body) = wireOf(
      await anaDs.seal('bob', d.id, '{"t":"a"}', d.key),
    );
    Future<Uint8List> open() => d.ds.open(
      'ana',
      1,
      type,
      body,
      ana.identity.public,
      reg: ana.registrationId,
    );
    await open();
    await expectLater(open(), throwsA(isA<LsError>()));
    final (t2, b2) = wireOf(
      await d.ds.seal('ana', 1, '{"t":"b"}', ana.identity.public),
    );
    await anaDs.open('bob', d.id, t2, b2, d.key, reg: d.reg);
    await expectLater(
      anaDs.open('bob', d.id, t2, b2, d.key, reg: d.reg),
      throwsA(isA<LsError>()),
    );
  });

  test('a bundle or an opener off the list entry is refused', () async {
    final d = bobs.first;
    final other = bobs[1];
    final block = ana.lib.parseDeviceBundle(
      await d.ds.makeBundle(d.id),
      bob.identity.public,
    );
    // pinned to another device's key, under another id, under another reg
    for (final (id, pin, reg) in [
      (d.id, other.key, d.reg),
      (other.id, d.key, d.reg),
      (d.id, d.key, d.reg + 1),
    ]) {
      await expectLater(
        anaDs.build('bob', id, block, pin, reg),
        throwsA(isA<DeviceRefused>()),
      );
    }
    expect(await anaDs.held('bob'), isEmpty);
    // the phone's own sessions are not this class's on a phone
    await expectLater(
      anaDs.build('bob', 1, block, d.key, d.reg),
      throwsA(isA<DeviceRefused>()),
    );
    await anaDs.build('bob', d.id, block, d.key, d.reg);
    final (type, body) = wireOf(
      await anaDs.seal('bob', d.id, '{"t":"x"}', d.key),
    );
    // an opener under another reg than ana's entry, or from a key not hers
    await expectLater(
      d.ds.open(
        'ana',
        1,
        type,
        body,
        ana.identity.public,
        reg: ana.registrationId + 1,
      ),
      throwsA(isA<DeviceRefused>()),
    );
    await expectLater(
      d.ds.open(
        'ana',
        1,
        type,
        body,
        bob.identity.public,
        reg: ana.registrationId,
      ),
      throwsA(isA<LsError>()),
    );
    expect(await d.ds.has('ana', 1), isFalse);
    // still opens for what the entry says
    await d.ds.open(
      'ana',
      1,
      type,
      body,
      ana.identity.public,
      reg: ana.registrationId,
    );
    expect(await d.ds.has('ana', 1), isTrue);
  });

  test('a removed device has nothing left to seal or open on', () async {
    await buildAll();
    final gone = bobs[2];
    final (type, body) = wireOf(
      await anaDs.seal('bob', gone.id, '{"t":"x"}', gone.key),
    );
    await gone.ds.open(
      'ana',
      1,
      type,
      body,
      ana.identity.public,
      reg: ana.registrationId,
    );
    final (t2, b2) = wireOf(
      await gone.ds.seal('ana', 1, '{"t":"y"}', ana.identity.public),
    );
    await anaDs.drop('bob', gone.id);
    expect(
      (await anaDs.held('bob')).map((h) => h.device),
      isNot(contains(gone.id)),
    );
    await expectLater(
      anaDs.seal('bob', gone.id, '{"t":"z"}', gone.key),
      throwsA(isA<LsError>()),
    );
    await expectLater(
      anaDs.open('bob', gone.id, t2, b2, gone.key, reg: gone.reg),
      throwsA(isA<LsError>()),
    );
    // the other devices' sessions are as they were
    expect(await anaDs.held('bob'), hasLength(4));
  });

  test('my own devices get copies on sessions of their own', () async {
    // ana's desktop: a linked device of ana's identity
    final desk = (await devices([33])).single;
    final block = ana.lib.parseDeviceBundle(
      await desk.ds.makeBundle(desk.id),
      ana.identity.public,
    );
    await anaDs.build(kOwnDevices, desk.id, block, desk.key, desk.reg);
    final (type, body) = wireOf(
      await anaDs.seal(kOwnDevices, desk.id, '{"t":"sent"}', desk.key),
    );
    final got = await desk.ds.open(
      kOwnDevices,
      1,
      type,
      body,
      ana.identity.public,
      reg: ana.registrationId,
    );
    expect(textOf(got), '{"t":"sent"}');
    // the contact address holds nothing of it
    expect(await anaDs.has('bob', desk.id), isFalse);
  });

  test('a frame too big for an opener skips that device only', () async {
    await buildAll();
    final big = '{"t":"${'x' * 3000}"}';
    await expectLater(
      anaDs.seal('bob', bobs.first.id, big, bobs.first.key),
      throwsA(isA<WaitsForAnswer>()),
    );
    // the next small one still goes to it
    final w = await anaDs.seal(
      'bob',
      bobs.first.id,
      '{"t":"s"}',
      bobs.first.key,
    );
    expect(wireOf(w).$1, kLsPreKey);
  });

  const day = 24 * 3600 * 1000;

  test('a pool bundle still opens when handed out on its last day', () async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final late = bobs[0];
    final gone = bobs[1];
    final kLate = await late.ds.makeBundle(late.id, now: t0);
    final kGone = await gone.ds.makeBundle(gone.id, now: t0);
    // 7 days in the pool, then 13 more before the first copy opens
    await late.store.keepSessionPreKeys(now: t0 + 20 * day);
    await gone.store.keepSessionPreKeys(now: t0 + 23 * day);
    for (final (d, kdb1) in [(late, kLate), (gone, kGone)]) {
      await anaDs.build(
        'bob',
        d.id,
        ana.lib.parseDeviceBundle(kdb1, bob.identity.public),
        d.key,
        d.reg,
      );
    }
    Future<Uint8List> copyTo(Dev d) async {
      final (type, body) = wireOf(
        await anaDs.seal('bob', d.id, '{"t":"late"}', d.key),
      );
      return d.ds.open(
        'ana',
        1,
        type,
        body,
        ana.identity.public,
        reg: ana.registrationId,
      );
    }

    expect(textOf(await copyTo(late)), '{"t":"late"}');
    // past its life the key is gone
    await expectLater(copyTo(gone), throwsA(anything));
  });

  test(
    'the last resort bundle goes again when the session keys change',
    () async {
      final d = bobs.first;
      final t0 = DateTime.now().millisecondsSinceEpoch;
      var told = 0;
      d.store.onSessionPreKeys = () => told++;
      LsBundle read(Uint8List kdb1) =>
          ana.lib.parseDeviceBundle(kdb1, bob.identity.public).bundle;
      final first = read(await d.ds.lastResortBundle(d.id, now: t0));
      final before = told;
      final again = read(await d.ds.lastResortBundle(d.id, now: t0 + day));
      expect(again.kyberPreKeyId, first.kyberPreKeyId);
      expect(again.signedPreKeyId, first.signedPreKeyId);
      expect(told, before);
      // a use 31 days on replaces them: the device is told, and its next
      // bundles are on the new keys
      final once = read(await d.ds.makeBundle(d.id, now: t0 + 31 * day));
      expect(told, before + 1);
      final next = read(await d.ds.lastResortBundle(d.id, now: t0 + 31 * day));
      expect(next.kyberPreKeyId, isNot(first.kyberPreKeyId));
      expect(next.signedPreKeyId, isNot(first.signedPreKeyId));
      expect(once.signedPreKeyId, next.signedPreKeyId);
      expect(once.kyberPreKeyId, isNot(next.kyberPreKeyId));
    },
  );

  test('an opener before the bundle keeps its session', () async {
    // ana links a3 and bob links d2 at once: a3 heard of d2 first and
    // built; its opener reaches d2 before ana's phone hands d2 a3's bundle
    final a3 = (await devices([3])).single;
    final d2 = (await devices([2])).single;
    Future<String> send(Dev from, String to, Dev dev, String t) =>
        from.ds.seal(to, dev.id, '{"t":"$t"}', dev.key);
    Future<String> read(Dev at, String from, Dev dev, String wire) async {
      final (type, body) = wireOf(wire);
      final got = textOf(
        await at.ds.open(from, dev.id, type, body, dev.key, reg: dev.reg),
      );
      return (jsonDecode(got) as Map)['t'] as String;
    }

    Future<bool> buildD2(Dev a3, {bool rebuild = false}) async => d2.ds.build(
      'ana',
      a3.id,
      d2.store.lib.parseDeviceBundle(
        await a3.ds.makeBundle(a3.id),
        ana.identity.public,
      ),
      a3.key,
      a3.reg,
      rebuild: rebuild,
    );

    expect(
      await a3.ds.build(
        'bob',
        d2.id,
        a3.store.lib.parseDeviceBundle(
          await d2.ds.makeBundle(d2.id),
          bob.identity.public,
        ),
        d2.key,
        d2.reg,
      ),
      isTrue,
    );
    expect(await read(d2, 'ana', a3, await send(a3, 'bob', d2, 'm1')), 'm1');
    expect(await read(a3, 'bob', d2, await send(d2, 'ana', a3, 'ok')), 'ok');
    final m2 = await send(a3, 'bob', d2, 'm2');
    expect(wireOf(m2).$1, kLsWhisper);
    // the bundle comes late: the session held stays
    expect(await buildD2(a3), isFalse);
    expect(await read(d2, 'ana', a3, m2), 'm2');
    // a rebuild over it keeps the old state in the archive
    final m3 = await send(a3, 'bob', d2, 'm3');
    expect(await buildD2(a3, rebuild: true), isTrue);
    expect(await read(d2, 'ana', a3, m3), 'm3');
    expect(await read(a3, 'bob', d2, await send(d2, 'ana', a3, 'm4')), 'm4');
    // a3's id on another key: built afresh on it, the old session gone
    final other = Dev(3, await testStore());
    final m5 = await send(a3, 'bob', d2, 'm5');
    expect(await buildD2(other), isTrue);
    expect((await d2.ds.held('ana')).single.key, other.key);
    await expectLater(read(d2, 'ana', a3, m5), throwsA(anything));
  });

  test('every copy of one message has one size', () async {
    await buildAll();
    final desk = (await devices([33])).single;
    await anaDs.build(
      kOwnDevices,
      desk.id,
      ana.lib.parseDeviceBundle(
        await desk.ds.makeBundle(desk.id),
        ana.identity.public,
      ),
      desk.key,
      desk.reg,
    );
    // bobs[0] and the desk answered; the others have not
    for (final (peer, d) in [('bob', bobs[0]), (kOwnDevices, desk)]) {
      final (type, body) = wireOf(
        await anaDs.seal(peer, d.id, '{"t":"a"}', d.key),
      );
      await d.ds.open(
        peer == 'bob' ? 'ana' : kOwnDevices,
        1,
        type,
        body,
        ana.identity.public,
        reg: ana.registrationId,
      );
      final (t2, b2) = wireOf(
        await d.ds.seal(
          peer == 'bob' ? 'ana' : kOwnDevices,
          1,
          '{"t":"ok"}',
          ana.identity.public,
        ),
      );
      await anaDs.open(peer, d.id, t2, b2, d.key, reg: d.reg);
    }
    final out = await anaDs.sealAll([
      for (final d in bobs.take(3))
        (peer: 'bob', device: d.id, pin: d.key, plain: '{"t":"hi"}'),
      (
        peer: kOwnDevices,
        device: desk.id,
        pin: desk.key,
        plain: '{"t":"hi","chat":"${'b' * 64}"}',
      ),
    ]);
    final types = [for (final o in out) wireOf(o.wire!).$1];
    expect(types, [kLsWhisper, kLsPreKey, kLsPreKey, kLsWhisper]);
    final sizes = [for (final o in out) base64Decode(o.wire!).length];
    final lo = sizes.reduce((a, b) => a < b ? a : b);
    final hi = sizes.reduce((a, b) => a > b ? a : b);
    expect(hi - lo, lessThanOrEqualTo(32), reason: '$sizes');
    expect(
      textOf(
        await bobs[0].ds.open(
          'ana',
          1,
          types[0],
          wireOf(out[0].wire!).$2,
          ana.identity.public,
          reg: ana.registrationId,
        ),
      ),
      '{"t":"hi"}',
    );
    // a burst past the opener's size: the answered ones go on one size,
    // the unanswered wait
    final big = await anaDs.sealAll([
      for (final d in bobs.take(2))
        (peer: 'bob', device: d.id, pin: d.key, plain: '{"t":"hi"}'),
      (
        peer: kOwnDevices,
        device: desk.id,
        pin: desk.key,
        plain: '{"t":"${'x' * 3000}"}',
      ),
    ]);
    expect(big[1].error, isA<WaitsForAnswer>());
    final a = base64Decode(big[0].wire!).length;
    final b = base64Decode(big[2].wire!).length;
    expect((a - b).abs(), lessThanOrEqualTo(32), reason: '$a $b');
    expect(a, greaterThan(10000));
  });

  // bobs[i] answered once
  Future<void> answer(Dev d) async {
    final (type, body) = wireOf(
      await anaDs.seal('bob', d.id, '{"t":"a"}', d.key),
    );
    await d.ds.open(
      'ana',
      1,
      type,
      body,
      ana.identity.public,
      reg: ana.registrationId,
    );
    final (t2, b2) = wireOf(
      await d.ds.seal('ana', 1, '{"t":"ok"}', ana.identity.public),
    );
    await anaDs.open('bob', d.id, t2, b2, d.key, reg: d.reg);
  }

  test('an opener goes in a burst only at the second size', () async {
    await buildAll();
    final d = bobs.first;
    final before = await ana.sessionStore.load('bob');
    // measured as a whisper, rebuilt since: it waits, nothing is spent
    for (final size in [kSealSizes[0], kSealSizes[2]]) {
      await expectLater(
        anaDs.seal('bob', d.id, '{"t":"hi"}', d.key, size: size),
        throwsA(isA<WaitsForAnswer>()),
        reason: '$size',
      );
    }
    expect(await ana.sessionStore.load('bob'), before);
    final w = await anaDs.seal(
      'bob',
      d.id,
      '{"t":"hi"}',
      d.key,
      size: kSealSizes[1],
    );
    expect(wireOf(w).$1, kLsPreKey);
  });

  test('the phone\'s copy lands on the burst\'s gift wrap', () async {
    await buildAll();
    // ana and bob's phone talk on their own session, answered
    await ana.processBundle(
      'bob',
      lsBundleOf(ana.lib, await bob.makeBundleB64()),
    );
    await openWire(bob, 'ana', await ana.encryptTo('bob', '{"t":"a"}'));
    await openWire(ana, 'bob', await bob.encryptTo('ana', '{"t":"ok"}'));
    const plain = '{"t":"hi"}';
    final copies = [
      for (final d in bobs.take(2))
        (peer: 'bob', device: d.id, pin: d.key, plain: plain),
    ];
    // one device still waits for its answer: its opener lifts the burst
    await answer(bobs[0]);
    final phone = await ana.sealSize('bob', plain);
    expect(phone, kSealSizes[0]);
    final size = [
      await anaDs.burstSize(copies),
      phone!,
    ].reduce((a, b) => a > b ? a : b);
    expect(size, kSealSizes[1]);
    final out = await anaDs.sealAll(copies, size: size);
    final w = await ana.encryptTo('bob', plain, size: size);
    expect(base64Decode(w)[0], kLsWhisper);
    final wraps = {
      wrapOf(w.length),
      for (final o in out) wrapOf(o.wire!.length),
    };
    expect(wraps, hasLength(1), reason: '$wraps');
    expect(unpad(await openWire(bob, 'ana', w)), plain);
    // a burst past the second size: the phone's opener would wait too
    final carol = await testStore();
    await ana.processBundle(
      'carol',
      lsBundleOf(ana.lib, await carol.makeBundleB64()),
    );
    expect(await ana.sealSize('carol', plain), kSealSizes[1]);
    await expectLater(
      ana.encryptTo('carol', plain, size: kSealSizes[2]),
      throwsA(isA<WaitsForAnswer>()),
    );
  });

  test('whispers in six pq ratchet states land on one gift wrap', () async {
    final six = [
      ...bobs,
      ...await devices([3]),
    ];
    bobs = six;
    await buildAll();
    // each device a different number of turns into its ratchets
    for (var i = 0; i < six.length; i++) {
      await answer(six[i]);
      for (var k = 0; k < i * 3; k++) {
        final d = six[i];
        final (t1, b1) = wireOf(
          await anaDs.seal('bob', d.id, '{"t":"$k"}', d.key),
        );
        await d.ds.open(
          'ana',
          1,
          t1,
          b1,
          ana.identity.public,
          reg: ana.registrationId,
        );
        if (k.isEven) {
          final (t2, b2) = wireOf(
            await d.ds.seal('ana', 1, '{"t":"$k"}', ana.identity.public),
          );
          await anaDs.open('bob', d.id, t2, b2, d.key, reg: d.reg);
        }
      }
    }
    for (var k = 0; k < kSealSizes.length; k++) {
      final plain = '{"t":"${'w' * (kSealSizes[k] - 60)}"}';
      for (var round = 0; round < 3; round++) {
        final out = await anaDs.sealAll([
          for (final d in six)
            (peer: 'bob', device: d.id, pin: d.key, plain: plain),
        ]);
        final wraps = <int>{};
        for (var i = 0; i < six.length; i++) {
          final (type, body) = wireOf(out[i].wire!);
          expect(type, kLsWhisper);
          wraps.add(wrapOf(out[i].wire!.length));
          await six[i].ds.open(
            'ana',
            1,
            type,
            body,
            ana.identity.public,
            reg: ana.registrationId,
          );
        }
        expect(wraps, hasLength(1), reason: 'size $k round $round: $wraps');
      }
    }
  });

  test('a device opener on an invite\'s key is refused', () async {
    final d = bobs.first;
    // the invite's kyber key, which everyone holding the card has
    await ana.processBundle(
      'bobdev',
      lsBundleOf(ana.lib, await d.store.makeBundleB64()),
    );
    final (type, body) = wireOf(await ana.encryptTo('bobdev', '{"t":"x"}'));
    expect(type, kLsPreKey);
    await expectLater(
      d.ds.open(
        'ana',
        1,
        type,
        body,
        ana.identity.public,
        reg: ana.registrationId,
      ),
      throwsA(isA<DeviceRefused>()),
    );
    expect(await d.ds.has('ana', 1), isFalse);
    // the same from a bundle of its session keys opens
    final block = ana.lib.parseDeviceBundle(
      await d.ds.lastResortBundle(d.id),
      bob.identity.public,
    );
    await anaDs.build('bob', d.id, block, d.key, d.reg);
    final (t2, b2) = wireOf(await anaDs.seal('bob', d.id, '{"t":"y"}', d.key));
    expect(
      textOf(
        await d.ds.open(
          'ana',
          1,
          t2,
          b2,
          ana.identity.public,
          reg: ana.registrationId,
        ),
      ),
      '{"t":"y"}',
    );
  });
}
