// SPDX-License-Identifier: GPL-3.0-or-later
// the decoy's main v4 invite beside the everyday one:
// the same code on its own store, the same sizes and flags, read back the
// same way. its times are an everyday phone's: never before the decoy was
// born or the phone first ran v4, never older than a reissue, made again
// at six months as an always-on phone does, gone a day past expiry with
// its keys, and made again now on a reset. real signal over rows in maps
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/signal_session.dart';

import 'mem_db.dart';
import 'signal_kit.dart';

const _hour = 3600 * 1000;
const _day = 24 * _hour;
const _six = kMainReissueHours * _hour;

final _p = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

bool _lifts(List<int> x) {
  final v = BigInt.parse(
    x.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  if (v >= _p) return false;
  final a = (v.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
  final y = a.modPow((_p + BigInt.one) >> 2, _p);
  return y.modPow(BigInt.two, _p) == a;
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _fcPkOf(Uint8List sk) {
  final x = sha256.convert(sk).bytes;
  return _lifts(x) ? _hex(x) : 'error: not a key';
}

InviteFace _faceOf(int seed) {
  final f = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, seed)));
  final o = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, seed + 1)));
  return InviteFace(
    onionKey: Uint8List.fromList(ed.public(o).bytes),
    face: Uint8List.fromList(ed.public(f).bytes),
    sign: (m) => Uint8List.fromList(ed.sign(f, m)),
  );
}

// 2026-10-29 12:00 utc
const _now = 1793275200000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemDb everydayDb, decoyDb;
  late SignalSession everyday, decoy;
  setUp(() async {
    everydayDb = MemDb();
    decoyDb = MemDb();
    everyday = await testStore(db: everydayDb);
    decoy = await testStore(db: decoyDb);
  });

  test('the decoy\'s link and qr are the everyday one\'s in length, flags '
      'and shape, and read back the same way', () async {
    final up = await keepInvites(
      everydayDb,
      everyday,
      fcPkOf: _fcPkOf,
      face: _faceOf(7),
      nowMs: _now,
    );
    final real = up.made!;
    final fake = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 400 * _day,
      v4SinceMs: _now - 30 * _day,
      nowMs: _now,
    );
    expect(fake.link.length, real.link.length);
    expect(fake.qr!.length, real.qr!.length);
    expect(inviteLink(fake.link).length, inviteLink(real.link).length);
    expect(inviteLink(fake.qr!).length, inviteLink(real.qr!).length);
    expect(inviteLink(fake.link), startsWith(kInviteLinkPrefix));
    final a = readInvite(everyday.lib, real.link, nowMs: _now);
    final b = readInvite(decoy.lib, fake.link, nowMs: _now);
    expect(b.flags, a.flags);
    expect(b.oneTime, a.oneTime);
    expect(b.expires - b.issued, a.expires - a.issued);
    expect(b.block!.deviceId, a.block!.deviceId);
    expect(b.block!.key, isNull);
    expect(b.block!.bundle.preKeyId, a.block!.bundle.preKeyId);
    expect(
      b.block!.bundle.kyberPreKey.length,
      a.block!.bundle.kyberPreKey.length,
    );
    expect(b.identity, decoy.identity.public);
    final qa = readInvite(everyday.lib, real.qr!, nowMs: _now);
    final qb = readInvite(decoy.lib, fake.qr!, nowMs: _now);
    expect(qb.flags, qa.flags);
    expect(qb.block, isNull);
    // a session a reader builds from it opens on the decoy's own keys
    expect(fake.spkId, b.block!.bundle.signedPreKeyId);
    expect(await decoy.signedPreKeyStore.contains(fake.spkId!), isTrue);
    expect(await decoy.kyberPreKeyStore.contains(fake.kyberId!), isTrue);
    // nothing of the decoy's is in the everyday store, nor the other way
    expect(await everyday.signedPreKeyStore.contains(fake.spkId!), isFalse);
    expect(
      everydayDb
          .rows('invites')
          .where((r) => r['kind'] == kInviteMain)
          .map((r) => r['id']),
      [real.id],
    );
    expect(decoyDb.rows('invites').map((r) => r['id']), [fake.id]);
  });

  test('its first invite is issued at a random point no earlier than its '
      'birth, the phone\'s first v4 or a reissue ago, and its keys and '
      'first-contact key carry that time', () async {
    final seen = <int>{};
    for (final (born, since) in [
      (_now - 900 * _day, _now - 20 * _day),
      (_now - 900 * _day, _now - 300 * _day),
      (_now - 40 * _day, _now - 300 * _day),
      (_now - 900 * _day, null),
    ]) {
      for (var i = 0; i < 4; i++) {
        final db = MemDb();
        final ss = await testStore(db: db);
        final row = await keepDecoyInvite(
          db,
          ss,
          fcPkOf: _fcPkOf,
          face: _faceOf(17),
          bornMs: born,
          v4SinceMs: since,
          nowMs: _now,
          random: Random(i * 31 + born % 97),
        );
        final lo = [born, since ?? _now, _now - _six].reduce(max);
        expect(row.issued, greaterThanOrEqualTo(lo ~/ _hour));
        expect(row.issued, lessThanOrEqualTo(_now ~/ _hour));
        expect(row.expires - row.issued, kMainHours);
        seen.add(row.issued);
        final at = db.rows('fc_keys').single['created_at'] as int;
        expect(at ~/ _hour, row.issued);
        final spk = db
            .rows('signed_prekeys')
            .where((r) => r['id'] == row.spkId);
        expect((spk.single['created_at'] as int) ~/ _hour, row.issued);
      }
    }
    // not the hour the decoy was opened in, every time
    expect(seen.length, greaterThan(3));
  });

  test('made again at six months as an always-on phone would, however late '
      'the app starts, the old one gone a day past its expiry', () async {
    final first = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 900 * _day,
      nowMs: _now,
    );
    // kept as it is before six months
    final same = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 900 * _day,
      nowMs: _now + _six - _hour,
    );
    expect(same.id, first.id);
    // the app starts 40 days late: the new one shows the six months
    final late = _now + _six + 40 * _day;
    final second = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 900 * _day,
      nowMs: late,
    );
    expect(second.id, isNot(first.id));
    final want = first.issued * _hour + _six;
    expect(second.issued * _hour, greaterThanOrEqualTo(want - _hour));
    expect(second.issued * _hour, lessThanOrEqualTo(want + _hour));
    final old = decoyDb.rows('invites').firstWhere((r) => r['id'] == first.id);
    expect(old['retired_at'], isNotNull);
    // two years on: the second's successors are made, and the expired
    // ones are gone with their keys
    final third = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 900 * _day,
      nowMs: _now + 730 * _day,
    );
    expect(third.issued * _hour, greaterThan(_now + 730 * _day - _six));
    final ids = decoyDb.rows('invites').map((r) => r['id']).toList();
    expect(ids, isNot(contains(first.id)));
    expect(ids, isNot(contains(second.id)));
    expect(await decoy.signedPreKeyStore.contains(first.spkId!), isFalse);
    expect(
      (await fcKeysOf(decoyDb, kMainIdent)).keys,
      isNot(contains(first.id)),
    );
  });

  test('a reset makes it again now, the old one gone with its keys', () async {
    final first = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 900 * _day,
      nowMs: _now,
    );
    final reset = await keepDecoyInvite(
      decoyDb,
      decoy,
      fcPkOf: _fcPkOf,
      face: _faceOf(17),
      bornMs: _now - 900 * _day,
      fresh: true,
      nowMs: _now + 3 * _day,
    );
    expect(reset.id, isNot(first.id));
    expect(reset.issued, (_now + 3 * _day) ~/ _hour);
    expect(decoyDb.rows('invites').map((r) => r['id']), [reset.id]);
    expect(await decoy.signedPreKeyStore.contains(first.spkId!), isFalse);
    expect(await decoy.kyberPreKeyStore.contains(first.kyberId!), isFalse);
  });
}
