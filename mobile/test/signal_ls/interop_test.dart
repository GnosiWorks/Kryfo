// SPDX-License-Identifier: GPL-3.0-or-later
// sessions libsignal_protocol_dart made go on through the shim: the same
// tables and record bytes, opened by the new layer, talking to a phone
// still on the old library, both ways, and back again
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart' show kSignalTables;
import 'package:kryfo/signal_session_ls.dart' show lsBundleOf;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show DuplicateMessageException;

import '../mem_db.dart';
import 'shim_lib.dart';

// two phones on the old library with a session between them, a message
// each way read
Future<(Phone, Phone)> _talking() async {
  final a = Phone();
  final b = Phone();
  final alice = await a.openOld();
  await b.openOld();
  await alice.processBundle('bob', preKeyBundleOf(await b.oldCard()));
  expect(await b.read('alice', await a.seal('bob', 'm1')), 'm1');
  expect(await a.read('bob', await b.seal('alice', 'm2')), 'm2');
  return (a, b);
}

final _fixture =
    jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
        as Map<String, dynamic>;

Object? _value(Object? v) => v is Map ? base64Decode(v['b64'] as String) : v;

List<Map<String, dynamic>> _rows(String who) => [
  for (final r in (_fixture[who] as Map)['rows'] as List)
    Map<String, dynamic>.from(r as Map),
];

// a phone off the 0.7.4 fixture, its store as the old library wrote it
Future<Phone> _stored(String who) async {
  final db = MemDb();
  for (final r in _rows(who)) {
    await db.insert(r['t'] as String, {
      for (final e in (r['row'] as Map).entries)
        e.key as String: _value(e.value),
    });
  }
  final me = _fixture[who] as Map;
  return Phone.of((
    pub: base64Decode(me['pub'] as String),
    priv: base64Decode(me['priv'] as String),
  ), db);
}

String _wire(String k) => (_fixture['wire'] as Map)[k] as String;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shim side reads and answers an old session', () async {
    final (a, b) = await _talking();
    // sealed by bob's old library, in flight while he updates
    final early = await a.seal('bob', 'sent before the update');
    final bob = await b.openLs();
    final info = (await bob.sessionInfo('alice'))!;
    expect(info.version, 3);
    expect(info.pq, isFalse);
    expect(await b.read('alice', early), 'sent before the update');
    for (var i = 0; i < 4; i++) {
      expect(await a.read('bob', await b.seal('alice', 'b$i')), 'b$i');
      expect(await b.read('alice', await a.seal('bob', 'a$i')), 'a$i');
    }
    // two in a row and out of order
    final x = await b.seal('alice', 'x');
    final y = await b.seal('alice', 'y');
    expect(await a.read('bob', y), 'y');
    expect(await a.read('bob', x), 'x');
  }, skip: needsShim);

  test(
    'the old side reads and answers a session the shim went on with',
    () async {
      final (a, b) = await _talking();
      await a.openLs();
      for (var i = 0; i < 3; i++) {
        expect(await b.read('alice', await a.seal('bob', 'a$i')), 'a$i');
        expect(await a.read('bob', await b.seal('alice', 'b$i')), 'b$i');
      }
      // and alice back on the old library: the records the shim wrote read
      // there too, so a release that has to go back loses no session
      await a.openOld();
      for (var i = 0; i < 3; i++) {
        expect(await b.read('alice', await a.seal('bob', 'c$i')), 'c$i');
        expect(await a.read('bob', await b.seal('alice', 'd$i')), 'd$i');
      }
    },
    skip: needsShim,
  );

  test('both on the shim keep the classic session they had', () async {
    final (a, b) = await _talking();
    final alice = await a.openLs();
    final bob = await b.openLs();
    for (var i = 0; i < 3; i++) {
      expect(await b.read('alice', await alice.encryptTo('bob', 'a$i')), 'a$i');
      expect(await a.read('bob', await bob.encryptTo('alice', 'b$i')), 'b$i');
    }
    expect((await alice.sessionInfo('bob'))!.version, 3);
    // a copy of a message read before is a duplicate, as it was
    final m = await alice.encryptTo('bob', 'once');
    expect(await b.read('alice', m), 'once');
    await expectLater(
      b.read('alice', m),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.duplicate)),
    );
  }, skip: needsShim);

  test('a 0.7.4 store opens on the shim with every row kept', () async {
    for (final who in ['alice', 'bob', 'carol']) {
      final p = await _stored(who);
      await p.openLs();
      for (final t in kSignalTables) {
        final before = _rows(who).where((r) => r['t'] == t).toList();
        final now = await p.db.query(t);
        expect(now, hasLength(before.length), reason: '$who $t');
        for (final r in before) {
          final key = t == 'sessions'
              ? 'address'
              : t == 'peer_identities'
              ? 'address'
              : t == 'signal_meta'
              ? 'k'
              : 'id';
          final row = now.firstWhere((x) => x[key] == (r['row'] as Map)[key]);
          for (final e in (r['row'] as Map).entries) {
            if (e.key == 'created_at') continue;
            expect(row[e.key], _value(e.value), reason: '$who $t ${e.key}');
          }
        }
      }
      // only the kyber prekey is new
      expect(await p.db.query('kyber_prekeys'), hasLength(1));
    }
  }, skip: needsShim);

  test('messages in flight in a 0.7.4 store open through the shim', () async {
    Future<String> bobReads(String w) async {
      final b = await _stored('bob');
      await b.openLs();
      return b.read('alice', _wire(w));
    }

    // the current session, and two on the archived one
    expect(await bobReads('a6'), 'a6 pending');
    expect(await bobReads('a4'), 'a4 old chain');
    expect(await bobReads('a2'), 'a2 skipped');
    final a = await _stored('alice');
    await a.openLs();
    expect(await a.read('bob', _wire('b2')), 'b2 old session');
  }, skip: needsShim);

  test('a 0.7.4 store goes on with old library peers', () async {
    final a = await _stored('alice');
    final b = await _stored('bob');
    await a.openOld();
    final bob = await b.openLs();
    expect(await b.read('alice', _wire('a6')), 'a6 pending');
    for (var i = 0; i < 3; i++) {
      expect(await a.read('bob', await bob.encryptTo('alice', 'b$i')), 'b$i');
      expect(await b.read('alice', await a.seal('bob', 'a$i')), 'a$i');
    }
    // and the old side still drops a copy
    final m = await bob.encryptTo('alice', 'once');
    expect(await a.read('bob', m), 'once');
    await expectLater(
      a.read('bob', m),
      throwsA(isA<DuplicateMessageException>()),
    );
    expect(
      await bob.identityStore.getIdentity('alice'),
      Uint8List.fromList([0x05, ...a.keys.pub]),
    );
  }, skip: needsShim);

  test('restore marks the old layer wrote name the same sessions', () async {
    final (_, b) = await _talking();
    final old = b.old!;
    await old.markRestored(from: 42);
    expect(await old.sealsOnRestored('alice'), isTrue);
    final bob = await b.openLs();
    expect(bob.hasRestored, isTrue);
    expect(bob.restoredFrom, 42);
    expect(await bob.sealsOnRestored('alice'), isTrue);
    // a seal on it waits for a card to start afresh from
    await expectLater(
      bob.encryptTo('alice', 'x'),
      throwsA(isA<StartingAfresh>()),
    );
    expect(await bob.askDue('alice', 0), isTrue);
    await bob.noteAsked('alice', 1000);
    expect(
      await bob.askDueAt('alice'),
      1000 + SignalSession.askWait(1).inMilliseconds,
    );
    // marked again on the shim, the base keys come out the same
    final before = (await b.db.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['restored_sessions'],
    )).first['v'];
    await bob.markRestored(from: 42);
    final after = (await b.db.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['restored_sessions'],
    )).first['v'];
    expect(
      (jsonDecode(after as String) as List).toSet(),
      (jsonDecode(before as String) as List).toSet(),
    );
    expect(await bob.dropRestoredWhenDone(), isFalse);
    expect(
      await bob.dropRestoredWhenDone(leaveOut: (p) => p == 'alice'),
      isTrue,
    );
    expect(bob.hasRestored, isFalse);
  }, skip: needsShim);

  test('an opener kept beside a held session, each once', () async {
    final (_, b) = await _talking();
    final bob = await b.openLs();
    // another session from alice, as a fresh start would bring
    final c = Phone();
    final carol = await c.openLs();
    await carol.processBundle(
      'bob',
      lsBundleOf(shim!, await bob.makeBundleB64()),
    );
    final w = base64Decode(await carol.encryptTo('bob', 'hi'));
    final tmp = await bob.open(
      '_pending_back_pair_',
      w[0],
      Uint8List.fromList(w.sublist(1)),
    );
    expect(unpadText(tmp), 'hi');
    final opened = (await bob.sessionStore.load('_pending_back_pair_'))!;
    await bob.keepOpenedSession('alice', opened);
    final info = (await bob.sessionInfo('alice'))!;
    expect(info.version, 4);
    expect(info.archived, hasLength(1));
    expect(info.archived.first.version, 3);
    // the same one again changes nothing
    await bob.keepOpenedSession('alice', opened);
    expect((await bob.sessionInfo('alice'))!.archived, hasLength(1));
  }, skip: needsShim);
}
