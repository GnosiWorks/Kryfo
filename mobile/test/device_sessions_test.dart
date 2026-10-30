// SPDX-License-Identifier: GPL-3.0-or-later
// copies of one message to every device of a contact and of my own, each on
// its own session in the store, on the host shim
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/device_sessions.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart' show LsBundle;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;

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

  test('the last resort bundle goes again when the session keys change', () async {
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
  });
}
