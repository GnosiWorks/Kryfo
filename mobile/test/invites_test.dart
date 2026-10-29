// SPDX-License-Identifier: GPL-3.0-or-later
// v4 invites (identity v4 2.1-2.3, R23, DECIDED 2026-10-28): the main
// invite and a one-time one made, signed by the shim and read back through
// its parser at the sizes 2.1 computes; a session built from the link's
// bundle opens on the invite's own keys; the link form; the reader's day of
// skew both ways; the main invite made again at six months and every invite
// gone with its keys a day after it expires, the v3 invite's keys with the
// first one; the developer's never. real signal over rows in maps
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/main.dart'
    show InviteArrival, inviteOpenerHolds, inviteOpenerSeed;
import 'package:kryfo/message_envelope.dart'
    show kEnvelopePrefix, unwrapMessage;
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';

import 'mem_db.dart';
import 'signal_kit.dart';

const _hour = 3600 * 1000;
const _day = 24 * _hour;

final _p = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

// whether x is the x of a secp256k1 point, as the shim asks (2.4)
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

// the engine's public half of a first-contact key, for these tests: a
// stand-in key that lifts, or an error as the engine gives one
String _fcPkOf(Uint8List sk) {
  final x = sha256.convert(sk).bytes;
  return _lifts(x) ? _hex(x) : 'error: not a key';
}

final _faceKeys = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 7)));
final _onionKeys = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 9)));

final _face = InviteFace(
  onionKey: Uint8List.fromList(ed.public(_onionKeys).bytes),
  face: Uint8List.fromList(ed.public(_faceKeys).bytes),
  sign: (m) => Uint8List.fromList(ed.sign(_faceKeys, m)),
);

// 2026-10-29 12:00 utc
const _now = 1793275200000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemDb db;
  late SignalSession ss;
  setUp(() async {
    db = MemDb();
    ss = await testStore(db: db);
  });

  test('the main invite: face, onion and bundle, a year, read back as a '
      'reader reads it, and its qr form without the bundle', () async {
    final row = await makeInvite(
      db,
      ss,
      kind: kInviteMain,
      fcPkOf: _fcPkOf,
      face: _face,
      nowMs: _now,
    );
    expect(row.link.length, 2032);
    expect(row.qr!.length, 288);
    expect(inviteLink(row.qr!).length, lessThan(410));
    final inv = readInvite(ss.lib, row.link, nowMs: _now);
    expect(inv.flags, kLsInviteBundle | kLsInviteOnion | kLsInviteFace);
    expect(inv.identity, ss.identity.public);
    expect(inv.answering, ss.identity.public);
    expect(_hex(inv.id), row.id);
    expect(inv.face, _face.face);
    expect(inv.onion, _face.onionKey);
    expect(inv.expires - inv.issued, kMainHours);
    expect(inv.issued, unixHours(_now));
    expect(inv.block!.deviceId, 1);
    expect(inv.block!.key, isNull);
    expect(inv.block!.bundle.preKeyId, isNull);
    expect(inv.block!.bundle.signedPreKeyId, row.spkId);
    expect(inv.block!.bundle.kyberPreKeyId, row.kyberId);
    final qr = readInvite(ss.lib, row.qr!, nowMs: _now);
    expect(qr.block, isNull);
    expect(qr.id, inv.id);
    expect(qr.firstContact, inv.firstContact);
    // its keys are named by the invite, not the session's
    final spk = await db.query(
      'signed_prekeys',
      where: 'id = ?',
      whereArgs: [row.spkId],
    );
    expect(spk.single['use'], kUseInvite);
    expect(spk.single['invite_id'], row.id);
    expect((await fcKeysOf(db, kMainIdent)).keys, [row.id]);
    expect((await currentMainInvite(db, kMainIdent))!.id, row.id);
    // only the main identity's main invite shows a face
    await expectLater(
      makeInvite(db, ss, kind: kInviteOneTime, fcPkOf: _fcPkOf, face: _face),
      throwsArgumentError,
    );
  });

  test('a session built from the link opens on the invite\'s own keys, and '
      'a one-time invite\'s keys go with its first opener', () async {
    final once = await makeInvite(
      db,
      ss,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
      nowMs: _now,
    );
    expect(once.link.length, 1941);
    expect(once.qr, isNull);
    final inv = readInvite(ss.lib, once.link, nowMs: _now);
    expect(inv.oneTime, isTrue);
    expect(inv.block!.bundle.preKeyId, once.ecId);
    expect(inv.expires - inv.issued, kOneTimeHours);

    final b = await testStore();
    await b.processBundle('a', inv.block!.bundle);
    final wire = await b.encryptTo('a', 'hi');
    final w = base64Decode(wire);
    final info = ss.lib.preKeyMessageInfo(Uint8List.sublistView(w, 1));
    expect(info.signedPreKeyId, once.spkId);
    expect(info.kyberPreKeyId, once.kyberId);
    expect(info.preKeyId, once.ecId);
    expect(await openWire(ss, kFirstContactSlot, wire), 'hi');

    await spendOneTime(db, ss, once, nowMs: _now + _hour);
    expect(await ss.signedPreKeyStore.contains(once.spkId!), isFalse);
    expect(await ss.kyberPreKeyStore.contains(once.kyberId!), isFalse);
    expect(await ss.preKeyStore.contains(once.ecId!), isFalse);
    expect((await inviteOf(db, kMainIdent, once.id))!.usedAt, _now + _hour);
    expect(await fcKeysOf(db, kMainIdent), isEmpty);
    // a forwarded copy reaches nothing
    final c = await testStore();
    await c.processBundle('a', inv.block!.bundle);
    await expectLater(
      openWire(ss, kFirstContactSlot, await c.encryptTo('a', 'me too')),
      throwsA(anything),
    );
  });

  test('the link: kryfo://share?v=4&i= and base64url, one form only', () {
    final b = Uint8List.fromList(List.generate(40, (i) => i * 7));
    final l = inviteLink(b);
    expect(l, startsWith(kInviteLinkPrefix));
    expect(l, isNot(contains('=')));
    expect(inviteOfLink(l), b);
    expect(inviteOfLink('  $l\n'), b);
    expect(isV4Link(l), isTrue);
    final i = l.substring(kInviteLinkPrefix.length);
    for (final bad in [
      '$l=',
      '$l&v=4',
      '$l&x=1',
      'kryfo://share?v=3&i=$i',
      'kryfo://share?i=$i',
      'kryfo://share?v=4&i=${i.substring(0, i.length - 1)} ',
      'kryfo://share?v=4&i=${base64.encode(b)}',
      'kryfo://share?v=4&i=',
      'kryfo://share?v=4&i=a${i.substring(1)} x',
    ]) {
      expect(inviteOfLink(bad), isNull, reason: bad);
    }
    // a last character with bits the bytes do not use: another form
    final last = i[i.length - 1];
    final alt = String.fromCharCode(last.codeUnitAt(0) ^ 1);
    if (alt != last && RegExp(r'[A-Za-z0-9_-]').hasMatch(alt)) {
      final other = '$kInviteLinkPrefix${i.substring(0, i.length - 1)}$alt';
      final got = inviteOfLink(other);
      expect(got == null || !_eqList(got, b) || other == l, isTrue);
    }
  });

  test('the reader takes a day of skew both ways and no more, and a '
      'damaged invite says so', () async {
    final row = await makeInvite(
      db,
      ss,
      kind: kInviteMain,
      fcPkOf: _fcPkOf,
      face: _face,
      nowMs: _now,
    );
    final issued = row.issued * _hour;
    // the owner's clock a day ahead of the reader's: taken; a day and an
    // hour: not yet
    expect(readInvite(ss.lib, row.link, nowMs: issued - _day), isNotNull);
    expect(
      () => readInvite(ss.lib, row.link, nowMs: issued - _day - _hour),
      throwsA(
        isA<InviteRefused>().having((e) => e.fault, 'f', InviteFault.notYet),
      ),
    );
    final expires = row.expires * _hour;
    expect(readInvite(ss.lib, row.link, nowMs: expires + _day), isNotNull);
    expect(
      () => readInvite(ss.lib, row.link, nowMs: expires + _day + _hour),
      throwsA(
        isA<InviteRefused>().having((e) => e.fault, 'f', InviteFault.expired),
      ),
    );
    // the pinned developer card is read without the times
    expect(
      readInvite(
        ss.lib,
        row.link,
        nowMs: expires + 400 * _day,
        timeless: true,
      ).identity,
      ss.identity.public,
    );
    for (final at in [10, 200, row.link.length - 3]) {
      final bad = Uint8List.fromList(row.link)..[at] ^= 1;
      expect(
        () => readInvite(ss.lib, bad, nowMs: _now),
        throwsA(
          isA<InviteRefused>().having((e) => e.fault, 'f', InviteFault.damaged),
        ),
        reason: 'byte $at',
      );
    }
    expect(
      () => readInvite(ss.lib, [...row.link, 0], nowMs: _now),
      throwsA(isA<InviteRefused>()),
    );
  });

  test('the main invite is made once, again at six months, and each goes a '
      'day after it expires with its keys; the v3 invite\'s keys go with the '
      'first one', () async {
    expect(await ss.signedPreKeyStore.contains(1), isTrue);
    expect(await ss.preKeyStore.contains(invitePreKeyId), isTrue);
    final made = await keepInvites(
      db,
      ss,
      fcPkOf: _fcPkOf,
      face: _face,
      nowMs: _now,
    );
    final first = made.made!;
    expect(
      (await keepInvites(
        db,
        ss,
        fcPkOf: _fcPkOf,
        face: _face,
        nowMs: _now,
      )).made,
      isNull,
    );
    // six months on: a new one, the first answered until it expires
    final at6 = _now + kMainReissueHours * _hour;
    final second = (await keepInvites(
      db,
      ss,
      fcPkOf: _fcPkOf,
      face: _face,
      nowMs: at6,
    )).made!;
    expect((await currentMainInvite(db, kMainIdent))!.id, second.id);
    expect((await inviteOf(db, kMainIdent, first.id))!.retiredAt, at6);
    // no longer handed out, still answered until it expires
    expect(
      (await inviteOf(db, kMainIdent, first.id))!.openAt(unixHours(at6)),
      isTrue,
    );
    // a day after the first one expires: it goes with its keys, and the
    // v3 invite's with it
    final past = (first.expires + kSkewHours + 1) * _hour;
    final up = await keepInvites(
      db,
      ss,
      fcPkOf: _fcPkOf,
      face: _face,
      nowMs: past,
    );
    expect(up.dropped, [first.id]);
    expect(up.legacyGone, isTrue);
    expect(await inviteOf(db, kMainIdent, first.id), isNull);
    expect(await ss.signedPreKeyStore.contains(first.spkId!), isFalse);
    expect(await ss.kyberPreKeyStore.contains(first.kyberId!), isFalse);
    expect((await fcKeysOf(db, kMainIdent)).keys, contains(second.id));
    expect((await fcKeysOf(db, kMainIdent)).keys, isNot(contains(first.id)));
    expect(await ss.signedPreKeyStore.contains(1), isFalse);
    expect(await ss.kyberPreKeyStore.contains(kInviteKyberId), isFalse);
    expect(await ss.preKeyStore.contains(invitePreKeyId), isFalse);
    // and a start after it makes none of them again
    final again = SignalSession();
    await again.bootstrap(
      database: db,
      xPubBytes: ss.identity.public.sublist(1),
      xPrivBytes: (await identityRow(db, kMainIdent))!.xPriv,
    );
    expect(await again.signedPreKeyStore.contains(1), isFalse);
    expect(await again.preKeyStore.contains(invitePreKeyId), isFalse);
    expect(await again.kyberPreKeyStore.contains(kInviteKyberId), isFalse);
  });

  test('the developer\'s main invite is made once and never replaced or '
      'dropped; one made and lost is not made again', () async {
    final made = (await keepInvites(
      db,
      ss,
      fcPkOf: _fcPkOf,
      face: _face,
      dev: true,
      nowMs: _now,
    )).made!;
    expect(made.neverExpires, isTrue);
    final years = _now + 3 * 365 * _day;
    final up = await keepInvites(
      db,
      ss,
      fcPkOf: _fcPkOf,
      face: _face,
      dev: true,
      nowMs: years,
    );
    expect(up.made, isNull);
    expect(up.dropped, isEmpty);
    expect(up.legacyGone, isFalse);
    expect((await currentMainInvite(db, kMainIdent))!.id, made.id);
    expect(await ss.signedPreKeyStore.contains(made.spkId!), isTrue);
    expect(made.openAt(unixHours(years)), isTrue);
    await dropInvite(db, ss, made);
    expect(await inviteOf(db, kMainIdent, made.id), isNotNull);
    // its row gone (an older backup, a bad hand): nothing replaces it
    await db.delete('invites');
    expect(
      (await keepInvites(
        db,
        ss,
        fcPkOf: _fcPkOf,
        face: _face,
        dev: true,
        nowMs: years,
      )).made,
      isNull,
    );
  });
  test(
    'a hello: taken on the five rules, refused re-addressed, under a '
    'foreign seal, twice on a one-time invite or once seen; zero answers '
    'only on the v3 address; the smaller sender key of two crossed',
    () async {
      // the owner's invites: a main and a one-time one
      final main = await makeInvite(
        db,
        ss,
        kind: kInviteMain,
        fcPkOf: _fcPkOf,
        face: _face,
        nowMs: _now,
      );
      final once = await makeInvite(
        db,
        ss,
        kind: kInviteOneTime,
        fcPkOf: _fcPkOf,
        nowMs: _now,
      );
      // the sender, its own store and rows, with a face of its own
      final bdb = MemDb();
      final b = await testStore(db: bdb);
      final bFaceKeys = ed.newKeyFromSeed(
        Uint8List.fromList(List.filled(32, 3)),
      );
      final bFace = InviteFace(
        onionKey: _face.onionKey,
        face: Uint8List.fromList(ed.public(bFaceKeys).bytes),
        sign: (m) => Uint8List.fromList(ed.sign(bFaceKeys, m)),
      );
      Future<Uint8List> hello(List<int> answers) async => (await makeHello(
        bdb,
        b,
        answers: answers,
        owner: ss.identity.public,
        fcPkOf: _fcPkOf,
        face: bFace,
        nowMs: _now,
      )).$1;
      final toMain = await hello(_unhex(main.id));
      expect(toMain.length, 4 + 1 + 16 + 33 + 2069 + 64);
      final bx = _hex(b.identity.public.sublist(1));
      String sealOf(String x) => x == bx ? 'ab' * 32 : 'cd' * 32;
      ({LsHello? hello, HelloFault? fault}) check(
        List<int> bytes, {
        InviteRow? at,
        bool v3 = false,
        String seal = '',
        bool seen = false,
        int? nowMs,
      }) => checkHello(
        ss.lib,
        bytes,
        at: v3 ? null : (at ?? main),
        mine: ss.identity.public,
        sealPk: seal.isEmpty ? 'ab' * 32 : seal,
        sealOf: sealOf,
        seen: seen,
        nowMs: nowMs ?? _now,
      );
      final ok = check(toMain);
      expect(ok.fault, isNull);
      expect(ok.hello!.invite.identity, b.identity.public);
      expect(ok.hello!.invite.oneTime, isTrue);
      expect(ok.hello!.invite.block!.bundle.preKeyId, isNotNull);
      // a main invite answered twice is taken; a hello seen is not
      expect(check(toMain).fault, isNull);
      expect(check(toMain, seen: true).fault, HelloFault.seen);
      // passed on to another invite: its id or its owner changed breaks it
      final moved = Uint8List.fromList(toMain)..[5] ^= 1;
      expect(check(moved).fault, HelloFault.shape);
      final owned = Uint8List.fromList(toMain)..[30] ^= 1;
      expect(check(owned).fault, HelloFault.shape);
      // to my one-time invite, but read at the main one: not its answer
      final toOnce = await hello(_unhex(once.id));
      expect(check(toOnce).fault, HelloFault.answers);
      expect(check(toOnce, at: once).fault, isNull);
      final used = InviteRow(
        ident: once.ident,
        id: once.id,
        kind: once.kind,
        issued: once.issued,
        expires: once.expires,
        link: once.link,
        usedAt: _now,
      );
      expect(check(toOnce, at: used).fault, HelloFault.answers);
      // a seal by anyone but the sender's hello seal key
      expect(check(toMain, seal: 'cd' * 32).fault, HelloFault.seal);
      // zero answers: the v3 address only
      final toV3 = await hello(List.filled(16, 0));
      expect(check(toV3).fault, HelloFault.answers);
      expect(check(toV3, v3: true).fault, isNull);
      expect(check(toMain, v3: true).fault, HelloFault.answers);
      // its inner invite expired: refused
      expect(
        check(toMain, nowMs: _now + (kOneTimeHours + 26) * _hour).fault,
        isNotNull,
      );
      // crossed: the smaller sender key's hello is answered
      final small = [5, 1, 2], big = [5, 1, 3];
      expect(answerTheirs(big, small), isTrue);
      expect(answerTheirs(small, big), isFalse);
    },
  );
  test('an opener at an invite is opened only under the hello seal key, on '
      'that invite\'s own keys, and only with its seed and a face signature '
      'for that invite', () async {
    final a = await makeInvite(
      db,
      ss,
      kind: kInviteMain,
      fcPkOf: _fcPkOf,
      face: _face,
      nowMs: _now,
    );
    final other = await makeInvite(
      db,
      ss,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
      nowMs: _now,
    );
    final b = await testStore();
    final bx = _hex(b.identity.public.sublist(1));
    String sealOf(int ident, String x) =>
        ident == ss.ident && x == bx ? 'ab' * 32 : 'cd' * 32;
    Future<Uint8List> openerTo(InviteRow r) async {
      final inv = readInvite(ss.lib, r.link, nowMs: _now);
      await b.processBundle('a${r.id}', inv.block!.bundle);
      final w = base64Decode(await b.encryptTo('a${r.id}', 'hi'));
      return Uint8List.sublistView(w, 1);
    }

    final toA = await openerTo(a);
    bool holds(InviteRow r, Uint8List body, String seal) => inviteOpenerHolds(
      ss.lib,
      InviteArrival(ss.ident, r, seal),
      body,
      helloSealPk: sealOf,
    );
    expect(holds(a, toA, 'ab' * 32), isTrue);
    expect(holds(a, toA, 'AB' * 32), isTrue);
    // sealed by anyone else
    expect(holds(a, toA, 'cd' * 32), isFalse);
    // on another invite's keys
    final toOther = await openerTo(other);
    expect(holds(a, toOther, 'ab' * 32), isFalse);
    expect(holds(other, toOther, 'ab' * 32), isTrue);
    // on the v3 card's keys
    final c = await testStore();
    await c.processBundle('v3', lsBundleOf(ss.lib, await ss.makeBundleB64()));
    final w3 = base64Decode(await c.encryptTo('v3', 'hi'));
    expect(holds(a, Uint8List.sublistView(w3, 1), 'ab' * 32), isFalse);
    expect(holds(a, Uint8List.fromList([1, 2, 3]), 'ab' * 32), isFalse);

    // what it opens to: the seed, and a face signature by its face over
    // its own key and this invite's id
    final bFace = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 5)));
    final seed = List.generate(32, (i) => i);
    String env(Map<String, Object?> j) => '$kEnvelopePrefix${jsonEncode(j)}';
    String fsFor(String inviteId) =>
        _hex(ed.sign(bFace, faceText(b.identity.public, _unhex(inviteId))));
    final good = {
      'm': 'hi',
      'h': 'some-three-words',
      'e': _hex(ed.public(bFace).bytes),
      'o': 'x.onion',
      'pg': 4,
      'as': _hex(seed),
      'fs': fsFor(a.id),
    };
    expect(
      inviteOpenerSeed(unwrapMessage(env(good)), b.identity.public, a.id),
      seed,
    );
    for (final bad in <Map<String, Object?>>[
      {...good}..remove('as'),
      {...good, 'pg': 3},
      {...good, 'as': 'ab'},
      {...good}..remove('fs'),
      {...good, 'fs': fsFor(other.id)},
      {...good, 'fs': '00' * 64},
    ]) {
      expect(
        inviteOpenerSeed(unwrapMessage(env(bad)), b.identity.public, a.id),
        isNull,
        reason: '$bad',
      );
    }
    // the same signature for another key: refused
    expect(
      inviteOpenerSeed(unwrapMessage(env(good)), c.identity.public, a.id),
      isNull,
    );
    // no face shown, none asked
    final faceless = {...good}
      ..remove('e')
      ..remove('fs')
      ..remove('h');
    expect(
      inviteOpenerSeed(unwrapMessage(env(faceless)), b.identity.public, a.id),
      seed,
    );
  });
}

bool _eqList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);
