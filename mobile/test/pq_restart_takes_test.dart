// SPDX-License-Identifier: GPL-3.0-or-later
// the pq restart on the side that builds it: the app is alice, whose key is the larger; bob's KDB1 comes inside
// their held classic session. one too old, or from a 0.5.x shaped frame,
// starts nothing. a fresh one starts the pq session and its opener goes at
// once; bob's answer notes the time, the chat gets its line, and 15 days
// on the classic states go. nothing of it ever shows as a message
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStatePqRestart,
        AppStateReceive,
        kClassicDropAfter,
        keyBefore,
        phoneRestartBundle;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';

import 'mem_db.dart';
import 'pq_restart_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemDb db;
  late PqIo io;
  late AppState app;
  late Phone bob;
  late String bobX;

  setUpAll(() async {
    if (needsShim != false) return;
    final b = await bootApp('alice');
    db = b.db;
    io = b.io;
    app = b.app;
    bob = await fixturePhone('bob');
    bobX = hexOf(bob.ls!.identity.public.sublist(1));
    await contact(db, 'bob', bob.ls!.identity.public, 'gs,pq,ty');
    // the held chat settled both ways, as 0.5.x left it
    expect(await bob.read('alice', fixtureWire('a6')), 'a6 pending');
    await app.receiveRelay([
      (
        peer: bobX,
        cipher: await bob.seal(
          'alice',
          await envelopeFrom('bob', bob.ls!.identity.public),
        ),
      ),
    ]);
    await settle();
  });

  Future<String> rq({required int writtenAt}) async => bob.seal(
    'alice',
    await envelopeFrom(
      'bob',
      bob.ls!.identity.public,
      writtenAt: writtenAt,
      extra: {kPqRestartWire: base64Encode(await phoneRestartBundle(bob.ls!))},
    ),
  );

  test('bob is the smaller key here', () {
    expect(
      keyBefore(bob.ls!.identity.public, signalSession.identity.public),
      isTrue,
    );
  }, skip: needsShim);

  test('a KDB1 written over a week ago starts nothing', () async {
    io.sent.clear();
    final old = DateTime.now()
        .subtract(const Duration(days: 8))
        .millisecondsSinceEpoch;
    await app.receiveRelay([(peer: bobX, cipher: await rq(writtenAt: old))]);
    await settle();
    expect((await signalSession.sessionInfo('bob'))!.version, 3);
    expect(io.sent, isEmpty);
    expect(db.rows('messages'), isEmpty);
  }, skip: needsShim);

  test(
    'a fresh KDB1 starts pq: the opener goes, bob opens it, his answer '
    'notes the time and the line, and 15 days on the classic states go',
    () async {
      io.sent.clear();
      final now = DateTime.now().millisecondsSinceEpoch;
      await app.receiveRelay([(peer: bobX, cipher: await rq(writtenAt: now))]);
      await settle();
      final info = (await signalSession.sessionInfo('bob'))!;
      expect(info.version, 4);
      expect(info.archived.map((s) => s.version), contains(3));
      // the opener, the empty envelope, to the pair's address
      expect(io.sent, hasLength(1));
      expect(io.sent.single.$1, bobX);
      expect(base64Decode(io.sent.single.$2)[0], kLsPreKey);
      // nothing of it is a message, and the time waits for bob's answer
      expect(db.rows('messages'), isEmpty);
      expect(await app.pqLineAt('bob'), isNull);
      final row = db.rows('pq_restarts').single;
      expect(row['key'], hexOf(bob.ls!.identity.public));
      expect(row['pq_at'], isNull);
      // bob sent his KDB1 again before that opener reached him (classic
      // still): it opens, pq stays in front, and it builds again
      io.sent.clear();
      await app.receiveRelay([(peer: bobX, cipher: await rq(writtenAt: now))]);
      await settle();
      expect((await signalSession.sessionInfo('bob'))!.version, 4);
      expect(io.sent, hasLength(1));
      final opener = io.sent.single.$2;
      expect(base64Decode(opener)[0], kLsPreKey);
      final plain = await bob.read('alice', opener);
      expect(unwrapMessage(plain).message, '');
      expect((await bob.ls!.sessionInfo('alice'))!.version, 4);
      expect(await app.pqLineAt('bob'), isNull);
      // bob's answer, on the pq state
      final answer = await bob.seal(
        'alice',
        await envelopeFrom('bob', bob.ls!.identity.public),
      );
      expect(base64Decode(answer)[0], kLsWhisper);
      await app.receiveRelay([(peer: bobX, cipher: answer)]);
      await settle();
      final at = await app.pqLineAt('bob');
      expect(at, isNotNull);
      // done: another KDB1 is turned down
      io.sent.clear();
      await app.receiveRelay([(peer: bobX, cipher: await rq(writtenAt: now))]);
      await settle();
      expect(io.sent, isEmpty);
      expect((await signalSession.sessionInfo('bob'))!.version, 4);
      // a day short of the 15 the classic states stay; then they go
      await app.pqUpkeep(nowMs: at! + kClassicDropAfter.inMilliseconds - 1);
      expect(
        (await signalSession.sessionInfo(
          'bob',
        ))!.archived.map((s) => s.version),
        contains(3),
      );
      expect(db.rows('pq_restarts').single['dropped_at'], isNull);
      await app.pqUpkeep(nowMs: at + kClassicDropAfter.inMilliseconds);
      final after = (await signalSession.sessionInfo('bob'))!;
      expect(after.version, 4);
      expect(after.archived.where((s) => s.version < 4), isEmpty);
      expect(db.rows('pq_restarts').single['dropped_at'], isNotNull);
      expect(db.rows('messages'), isEmpty);
      // the chat goes on
      final m = await bob.seal(
        'alice',
        await envelopeFrom(
          'bob',
          bob.ls!.identity.public,
          extra: {'m': 'still here', 'u': 'u-still'},
        ),
      );
      await app.receiveRelay([(peer: bobX, cipher: m)]);
      await settle();
      expect(db.rows('messages').map((r) => r['msg_uid']), contains('u-still'));
    },
    skip: needsShim,
  );
}
