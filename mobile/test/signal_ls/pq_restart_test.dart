// SPDX-License-Identifier: GPL-3.0-or-later
// the pq restart of a held classic chat (identity v4 11 steps 5 and 6) on
// the stores themselves: the smaller key's KDB1, the other side's session
// on it in front of the held one, the opener and its answer, classic
// messages still on their way read and never taking the front back, the
// classic states dropped once both sides are on pq and never before. a
// chat the restart never reached (a 0.5.x phone's) is untouched. the
// stores are the 0.7.4 fixture's, made by the old library
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show keyBefore, phoneRestartBundle;
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';

import '../mem_db.dart';
import 'shim_lib.dart';

final _fixture =
    jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
        as Map<String, dynamic>;

Object? _value(Object? v) => v is Map ? base64Decode(v['b64'] as String) : v;

Future<Phone> _stored(String who) async {
  final db = MemDb();
  for (final r in (_fixture[who] as Map)['rows'] as List) {
    final row = (r as Map)['row'] as Map;
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

int _type(String wire) => base64Decode(wire)[0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // the two phones of the fixture's held chat, settled: bob read alice's
  // pending a6. [small] starts the restart, [large] builds on it
  Future<
    ({
      Phone small,
      Phone large,
      String smallName,
      String largeName,
      List<String> pqOver,
    })
  >
  held() async {
    final a = await _stored('alice');
    final b = await _stored('bob');
    final alice = await a.openLs();
    final bob = await b.openLs();
    expect(await b.read('alice', _wire('a6')), 'a6 pending');
    expect(await a.read('bob', await bob.encryptTo('alice', 'b0')), 'b0');
    final pqOver = <String>[];
    alice.onPqOver = (p) => pqOver.add('alice:$p');
    bob.onPqOver = (p) => pqOver.add('bob:$p');
    final bobFirst = keyBefore(bob.identity.public, alice.identity.public);
    return bobFirst
        ? (
            small: b,
            large: a,
            smallName: 'bob',
            largeName: 'alice',
            pqOver: pqOver,
          )
        : (
            small: a,
            large: b,
            smallName: 'alice',
            largeName: 'bob',
            pqOver: pqOver,
          );
  }

  test('the held chat goes over to pq: a classic message on its way opens '
      'and never takes the front back, the drop waits for the answer and '
      'then leaves classic messages unread', () async {
    final h = await held();
    final s = h.small.ls!;
    final l = h.large.ls!;
    // what each side sealed classic before the restart, still on its way
    final lateFromSmall = await s.encryptTo(h.largeName, 'late small');
    final lateFromLarge = await l.encryptTo(h.smallName, 'late large');
    final lateFromLarge2 = await l.encryptTo(h.smallName, 'late large 2');
    expect(_type(lateFromSmall), kLsWhisper);

    // the smaller side's KDB1, read by the other on the held session's key
    final kdb1 = await phoneRestartBundle(s);
    final block = l.lib.parseDeviceBundle(kdb1, s.identity.public);
    expect(block.deviceId, 1);
    expect(block.key, isNull);
    expect(await l.restartFrom(h.smallName, block.bundle), isTrue);
    final rec = (await l.sessionInfo(h.smallName))!;
    expect(rec.version, 4);
    expect(rec.archived.map((x) => x.version), contains(3));
    // unanswered: nothing is dropped
    expect(await l.dropClassic(h.smallName), isNull);

    // the classic message still on its way opens, and the next seal is
    // still the pq opener
    expect(await h.large.read(h.smallName, lateFromSmall), 'late small');
    expect((await l.sessionInfo(h.smallName))!.version, 4);
    final opener = await l.encryptTo(h.smallName, 'on pq');
    expect(_type(opener), kLsPreKey);
    expect(h.pqOver, isEmpty);

    // the smaller side opens it on its held record: its side is done
    expect(await h.small.read(h.largeName, opener), 'on pq');
    expect((await s.sessionInfo(h.largeName))!.version, 4);
    expect(h.pqOver, ['${h.smallName}:${h.largeName}']);
    // a classic one of theirs still on its way opens and leaves pq in front
    expect(await h.small.read(h.largeName, lateFromLarge), 'late large');
    expect((await s.sessionInfo(h.largeName))!.version, 4);

    // its answer settles the other side
    final answer = await s.encryptTo(h.largeName, 'answer');
    expect(_type(answer), kLsWhisper);
    expect(await h.large.read(h.smallName, answer), 'answer');
    expect(h.pqOver, contains('${h.largeName}:${h.smallName}'));
    expect(_type(await l.encryptTo(h.smallName, 'plain')), kLsWhisper);

    // both drop their classic states; a classic message after that is
    // refused like one with no session, and pq goes on
    expect(await l.dropClassic(h.smallName), greaterThanOrEqualTo(1));
    expect(await s.dropClassic(h.largeName), greaterThanOrEqualTo(1));
    for (final r in [
      (await l.sessionInfo(h.smallName))!,
      (await s.sessionInfo(h.largeName))!,
    ]) {
      expect(r.version, 4);
      expect(r.archived.where((x) => x.version < 4), isEmpty);
    }
    await expectLater(
      h.small.read(h.largeName, lateFromLarge2),
      throwsA(isA<LsError>()),
    );
    expect((await s.sessionInfo(h.largeName))!.version, 4);
    // nothing left to drop
    expect(await s.dropClassic(h.largeName), 0);
    for (var i = 0; i < 3; i++) {
      final m = await s.encryptTo(h.largeName, 's$i');
      expect(_type(m), kLsWhisper);
      expect(await h.large.read(h.smallName, m), 's$i');
      expect(
        await h.small.read(h.largeName, await l.encryptTo(h.smallName, 'l$i')),
        'l$i',
      );
    }
  }, skip: needsShim);

  test('a held chat no restart reached stays as it was: classic both ways, '
      'nothing to drop, nothing said', () async {
    final h = await held();
    final s = h.small.ls!;
    final l = h.large.ls!;
    for (var i = 0; i < 3; i++) {
      expect(
        await h.large.read(h.smallName, await s.encryptTo(h.largeName, 's$i')),
        's$i',
      );
      expect(
        await h.small.read(h.largeName, await l.encryptTo(h.smallName, 'l$i')),
        'l$i',
      );
    }
    for (final (st, peer) in [(s, h.largeName), (l, h.smallName)]) {
      final before = await st.sessionStore.load(peer);
      expect(await st.dropClassic(peer), isNull);
      expect(await st.sessionStore.load(peer), before);
      expect((await st.sessionInfo(peer))!.version, 3);
    }
    expect(h.pqOver, isEmpty);
  }, skip: needsShim);

  test(
    'a KDB1 on another key starts nothing, and keeps the held chat',
    () async {
      final h = await held();
      final l = h.large.ls!;
      final carol = await (await _stored('carol')).openLs();
      final theirs = await phoneRestartBundle(carol);
      // read as the smaller side's it does not parse
      expect(
        () => l.lib.parseDeviceBundle(theirs, h.small.ls!.identity.public),
        throwsA(isA<LsError>()),
      );
      // read as carol's, it is not the key the held session runs on
      final block = l.lib.parseDeviceBundle(theirs, carol.identity.public);
      final before = await l.sessionStore.load(h.smallName);
      expect(await l.restartFrom(h.smallName, block.bundle), isFalse);
      expect(await l.sessionStore.load(h.smallName), before);
      // nothing held: nothing to start on
      expect(await l.restartFrom('nobody', block.bundle), isFalse);
    },
    skip: needsShim,
  );

  test('an opener that went to a one-time invite holds the next seals until '
      'their answer, which lets them go', () async {
    final a = Phone();
    final b = Phone();
    final alice = await a.openLs();
    final bob = await b.openLs();
    await alice.processBundle(
      'bob',
      lsBundleOf(alice.lib, await bob.makeBundleB64()),
    );
    var went = false;
    alice.holdOpener = (_) async => went;
    final answered = <String>[];
    alice.onAnswered = answered.add;
    final first = await alice.encryptTo('bob', 'first');
    expect(_type(first), kLsPreKey);
    went = true;
    await expectLater(
      alice.encryptTo('bob', 'second'),
      throwsA(isA<WaitsForAnswer>()),
    );
    expect(await b.read('alice', first), 'first');
    expect(await a.read('bob', await bob.encryptTo('alice', 'back')), 'back');
    expect(answered, ['bob']);
    // settled: plain messages, the hold asks nothing of them
    final second = await alice.encryptTo('bob', 'second');
    expect(_type(second), kLsWhisper);
    expect(await b.read('alice', second), 'second');
  }, skip: needsShim);

  test('a drop with no session holds nothing', () async {
    final p = Phone();
    final s = await p.openLs();
    expect(await s.dropClassic('nobody'), isNull);
  }, skip: needsShim);
}
