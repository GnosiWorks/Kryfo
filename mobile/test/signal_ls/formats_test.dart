// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo's frames through the bindings, against the vectors the shim's own
// tests hold to (native/kryfo_signal/testdata/formats_v1.txt), and the
// drop of classic states behind a post-quantum one
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';

import 'shim_lib.dart';

const _crate = 'native/kryfo_signal';

Uint8List _hex(String s) => s == '-'
    ? Uint8List(0)
    : Uint8List.fromList([
        for (var i = 0; i < s.length; i += 2)
          int.parse(s.substring(i, i + 2), radix: 16),
      ]);

final _lines = File('$_crate/testdata/formats_v1.txt')
    .readAsLinesSync()
    .where((l) => l.isNotEmpty && !l.startsWith('#'))
    .map((l) => l.split(' '))
    .toList();

Map<String, Uint8List> _keys(int column) => {
  for (final f in _lines)
    if (f[0] == 'key') f[1]: _hex(f[column]),
};

Uint8List _good(String name) =>
    _hex(_lines.firstWhere((f) => f[0] == 'good' && f[1] == name)[4]);

Matcher _code(int c) =>
    throwsA(isA<LsError>().having((e) => e.code, 'code', c));

const _codes = {
  'format': LsError.format,
  'signature': LsError.signature,
  'key': LsError.key,
  'args': LsError.args,
};

void main() {
  final publics = _keys(3);

  test('the bindings and the shim share one list of formats', () {
    final rust = File('$_crate/src/formats.rs').readAsStringSync();
    final listed = RegExp(
      r'\("([a-z-]+)", Kind::',
    ).allMatches(rust).map((m) => m[1]).toList();
    expect(listed, [for (final f in LsFormat.values) f.wire]);
  });

  LsIdentity me(KryfoSignal s, String name) =>
      s.identityFromPrivate(_keys(2)[name]!);

  void parseAs(KryfoSignal s, String kind, Uint8List b, String? identity) {
    switch (kind) {
      case 'invite':
        s.parseInvite(b);
      case 'hello':
        s.parseHello(b);
      case 'heal':
        s.parseHeal(b);
      case 'device-list':
        s.parseDeviceList(b);
      case 'device-bundle':
        s.parseDeviceBundle(b, publics[identity]!);
      case 'move':
        s.parseMove(b);
      default:
        fail('kind $kind');
    }
  }

  test(
    'every good vector parses, every bad one is refused as it says',
    () {
      final s = shim!;
      var good = 0;
      var bad = 0;
      for (final f in _lines) {
        if (f[0] == 'good') {
          final id = f[3] == '-' ? null : f[3];
          parseAs(s, f[2], _hex(f[4]), id);
          good++;
        } else if (f[0] == 'bad') {
          final id = f[3] == '-' ? null : f[3];
          expect(
            () => parseAs(s, f[2], _hex(f[6]), id),
            _code(_codes[f[4]]!),
            reason: f[1],
          );
          bad++;
        }
      }
      expect(good, greaterThan(15));
      expect(bad, greaterThan(80));
    },
    skip: needsShim,
  );

  test('an invite reads back what it says', () {
    final s = shim!;
    final qr = s.parseInvite(_good('invite_qr_ci'));
    expect(qr.oneTime, isTrue);
    expect(qr.identity, publics['ana1']);
    expect(qr.answering, publics['ana1']);
    expect(qr.block, isNull);
    expect(qr.face, isNull);
    expect(qr.expires - qr.issued, 7 * 24);
    expect(qr.firstContact, hasLength(32));

    final p0 = s.parseInvite(_good('invite_link_p0'));
    expect(p0.oneTime, isFalse);
    expect(p0.flags & kLsInviteFace, isNot(0));
    expect(p0.face, hasLength(32));
    expect(p0.faceSignature, hasLength(64));
    expect(p0.onion, hasLength(32));
    expect(p0.block!.key, isNull);
    expect(p0.block!.bundle.identityKey, publics['ana0']);
    expect(p0.block!.bundle.kyberPreKey, hasLength(1569));

    // a pool desktop answers, on its own key, vouched for by the list
    final pool = s.parseInvite(_good('invite_pool_link'));
    expect(pool.answering, publics['desk']);
    expect(pool.block!.key, publics['desk']);
    expect(pool.block!.bundle.identityKey, publics['desk']);
    final list = pool.deviceList!;
    expect(list.identity, publics['ana1']);
    expect(list.devices.where((d) => d.phone).single.key, publics['ana1']);
    final desk = list.devices.where((d) => d.answers).single;
    expect(desk.deviceId, pool.block!.deviceId);
    expect(desk.registrationId, pool.block!.registrationId);
  }, skip: needsShim);

  test('a hello, a heal, a list, a device bundle and a move', () {
    final s = shim!;
    final h = s.parseHello(_good('hello_1'));
    expect(h.owner, publics['ana0']);
    expect(h.invite.identity, publics['ben0']);
    expect(h.invite.oneTime, isTrue);
    expect(h.invite.block!.bundle.preKey, isNotNull);
    final v3 = s.parseHello(_good('hello_v3_link'));
    expect(v3.answers, Uint8List(16));

    final heal = s.parseHeal(_good('heal_device'));
    expect(heal.identity, publics['ana1']);
    expect(heal.signer, publics['desk']);
    expect(heal.restored, isFalse);
    expect(heal.since, 0);
    final restored = s.parseHeal(_good('heal_restored'));
    expect(restored.restored, isTrue);
    expect(restored.since % 24, 0);
    expect(restored.signer, publics['ana0']);

    final six = s.parseDeviceList(_good('device_list_6'));
    expect(six.devices, hasLength(6));
    final ids = [for (final d in six.devices) d.deviceId];
    expect(ids, [...ids]..sort());

    final b = s.parseDeviceBundle(
      _good('device_bundle_desk'),
      publics['ana1']!,
    );
    expect(b.key, publics['desk']);
    expect(
      () => s.parseDeviceBundle(_good('device_bundle_phone'), publics['ana1']!),
      _code(LsError.signature),
    );

    final m = s.parseMove(_good('move_1'));
    expect(m.old, publics['ana0']);
    expect(m.peer, publics['ben0']);
    expect(m.fresh, publics['ana1']);
  }, skip: needsShim);

  test('sign takes only a body that names the signer', () {
    final s = shim!;
    final frame = _good('invite_qr_ci');
    final body = frame.sublist(0, frame.length - 64);
    final ana1 = me(s, 'ana1');
    final sig = s.sign(ana1, LsSigContext.invite, body);
    expect(s.verifyCtx(ana1.public, LsSigContext.invite, body, sig), isTrue);
    final again = s.parseInvite(Uint8List.fromList([...body, ...sig]));
    expect(again.signature, sig);
    // another identity, the whole frame, or a body of another format
    expect(
      () => s.sign(me(s, 'ana0'), LsSigContext.invite, body),
      _code(LsError.signer),
    );
    expect(
      () => s.sign(ana1, LsSigContext.invite, frame),
      _code(LsError.format),
    );
    expect(() => s.sign(ana1, LsSigContext.hello, body), _code(LsError.format));
    // a move by the old identity or the new one, never by the peer
    final mv = _good('move_1');
    for (final n in ['ana0', 'ana1']) {
      final id = me(s, n);
      final ms = s.sign(id, LsSigContext.move, mv);
      expect(s.verifyCtx(id.public, LsSigContext.move, mv, ms), isTrue);
    }
    expect(
      () => s.sign(me(s, 'ben0'), LsSigContext.move, mv),
      _code(LsError.signer),
    );
    // empty fields are false, not an error
    expect(s.verifyCtx(ana1.public, LsSigContext.invite, body, []), isFalse);
    expect(s.verifyCtx(ana1.public, LsSigContext.invite, [], sig), isFalse);
    expect(s.verifyCtx([], LsSigContext.invite, body, sig), isFalse);
  }, skip: needsShim);

  test('an invite bundle builds a session', () {
    final s = shim!;
    final inv = s.parseInvite(_good('invite_link_ci'));
    final ben = s.identityGenerate();
    final (rec, their) = s.sessionFromBundle(
      ben,
      9,
      null,
      inv.block!.bundle,
      1760000000000,
      pinned: inv.identity,
    );
    expect(their, inv.identity);
    final info = s.sessionInfo(rec);
    expect(info.version, 4);
    expect(info.pq, isTrue);
  }, skip: needsShim);

  test('classic states go, and only them', () {
    final s = shim!;
    final f = {
      for (final l in File('$_crate/testdata/dart_v3.txt').readAsLinesSync())
        if (l.contains('=') && !l.startsWith('#'))
          l.split('=')[0]: _hex(l.split('=')[1]),
    };
    const now = 1760000000000;
    final bobRec = f['bob_rec']!;
    final alice = LsIdentity(
      f['alice_id']!,
      s.sessionInfo(bobRec).remoteIdentity!,
    );
    final bob = LsIdentity(
      f['bob_id']!,
      s.sessionInfo(f['alice_rec']!).remoteIdentity!,
    );
    // bob restarts the classic chat on alice's pq bundle
    final spk = s.signedPreKey(alice, 51, now);
    final ky = s.kyberPreKey(alice, 52, now);
    final bundle = s.bundleBuild(
      registrationId: 11,
      signedPreKeyId: 51,
      signedPreKey: spk.public,
      signedPreKeySignature: spk.signature,
      kyberPreKeyId: 52,
      kyberPreKey: ky.public,
      kyberPreKeySignature: ky.signature,
      identityKey: alice.public,
    );
    final (pq, _) = s.sessionFromBundle(bob, 22, bobRec, bundle, now);
    final info = s.sessionInfo(pq);
    expect(info.version, 4);
    expect(info.archived.map((a) => a.version), contains(3));
    // the classic state still opens alice's classic message
    expect(
      String.fromCharCodes(s.decryptSignal(bob, 22, pq, f['m3']!).plaintext),
      'm3 from dart',
    );
    final (dropped, n) = s.sessionDropBelow(pq, 4);
    expect(n, 1);
    expect(
      s.sessionInfo(dropped).archived.where((a) => a.version < 4),
      isEmpty,
    );
    expect(
      () => s.decryptSignal(bob, 22, dropped, f['m3']!),
      throwsA(isA<LsError>()),
    );
    // and the pq session goes on
    final sealed = s.encrypt(bob, 22, dropped, [1, 2, 3], now);
    expect(sealed.type, kLsPreKey);
    final opened = s.decryptPreKey(
      alice,
      11,
      f['alice_rec']!,
      sealed.message,
      signedPreKey: spk.record,
      kyberPreKey: ky.record,
    );
    expect(opened.plaintext, [1, 2, 3]);
    // nothing below the current state's own version is asked for twice
    expect(s.sessionDropBelow(dropped, 4).$2, 0);
    expect(() => s.sessionDropBelow(bobRec, 4), _code(LsError.session));
    expect(() => s.sessionDropBelow(pq, 0), _code(LsError.args));
  }, skip: needsShim);
}
