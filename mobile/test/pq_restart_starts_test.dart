// SPDX-License-Identifier: GPL-3.0-or-later
// the pq restart on the side that starts it (identity v4 11 step 5): the
// app is bob, whose key is the smaller. nothing goes to a contact whose
// phone does not say 'pq' (every 0.5.x phone, and 0.6 builds before this),
// or who has not added us back. once alice's frame says it, bob's KDB1 goes
// inside the held session, again only on its schedule; a KDB1 from alice,
// the larger key, starts nothing. alice's opener puts bob on pq, the
// answer goes at once, the time is noted and the line shows
import 'dart:convert';
import 'dart:typed_data';

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
  late Phone alice;
  late String aliceX;

  Future<void> setCaps(String caps, {int backPaired = 1}) => db.update(
    'contacts',
    {'caps': caps, 'back_paired': backPaired},
    where: 'halo_id = ?',
    whereArgs: ['alice'],
  );

  // what bob sent alice, opened by her
  Future<List<UnwrappedMessage>> aliceReads() async => [
    for (final (_, c) in io.sent) unwrapMessage(await alice.read('bob', c)),
  ];

  setUpAll(() async {
    if (needsShim != false) return;
    final b = await bootApp('bob');
    db = b.db;
    io = b.io;
    app = b.app;
    alice = await fixturePhone('alice');
    aliceX = hexOf(alice.ls!.identity.public.sublist(1));
    await contact(db, 'alice', alice.ls!.identity.public, '');
    // the held chat settled both ways, as 0.5.x left it
    final a6 = base64Decode(fixtureWire('a6'));
    await signalSession.open('alice', a6[0], Uint8List.fromList(a6.sublist(1)));
    expect(
      await alice.read('bob', await signalSession.encryptTo('alice', 'b0')),
      'b0',
    );
  });

  test('bob is the smaller key here', () {
    expect(
      keyBefore(signalSession.identity.public, alice.ls!.identity.public),
      isTrue,
    );
  }, skip: needsShim);

  test('no KDB1 to a phone that does not say pq, or to someone who has not '
      'added us back', () async {
    io.sent.clear();
    await app.pqUpkeep();
    expect(io.sent, isEmpty);
    await setCaps('gs,ty');
    await app.pqUpkeep();
    expect(io.sent, isEmpty);
    await setCaps('gs,pq,ty', backPaired: 0);
    await app.pqUpkeep();
    expect(io.sent, isEmpty);
    expect(db.rows('pq_restarts'), isEmpty);
    expect((await signalSession.sessionInfo('alice'))!.version, 3);
    await setCaps('');
  }, skip: needsShim);

  test('a KDB1 from the larger key starts nothing', () async {
    io.sent.clear();
    final w = await alice.seal(
      'bob',
      await envelopeFrom(
        'alice',
        alice.ls!.identity.public,
        extra: {
          kPqRestartWire: base64Encode(await phoneRestartBundle(alice.ls!)),
        },
      ),
    );
    await app.receiveRelay([(peer: aliceX, cipher: w)]);
    await settle();
    expect(io.sent, isEmpty);
    expect((await signalSession.sessionInfo('alice'))!.version, 3);
    expect(db.rows('pq_restarts'), isEmpty);
  }, skip: needsShim);

  test('a session a restore brought back sends no KDB1: its heal builds a '
      'pq one', () async {
    io.sent.clear();
    await setCaps('gs,pq,ty');
    await signalSession.markRestored();
    expect(await signalSession.sealsOnRestored('alice'), isTrue);
    await app.pqUpkeep();
    expect(io.sent, isEmpty);
    expect(db.rows('pq_restarts'), isEmpty);
    // the marks go again for the tests after this one
    expect(
      await signalSession.dropRestoredWhenDone(leaveOut: (_) => true),
      isTrue,
    );
    await setCaps('');
  }, skip: needsShim);

  test('her caps say pq: the KDB1 goes, again a day on, and her opener puts '
      'bob on pq; the answer goes, the time and the line are kept, and 15 '
      'days on the classic states go', () async {
    io.sent.clear();
    // a frame of hers that says it
    final hello = await alice.seal(
      'bob',
      await envelopeFrom(
        'alice',
        alice.ls!.identity.public,
        extra: {
          'cp': ['gs', 'pq', 'ty'],
        },
      ),
    );
    await app.receiveRelay([(peer: aliceX, cipher: hello)]);
    await settle();
    await settle();
    expect(io.sent, hasLength(1));
    final first = (await aliceReads()).single;
    expect(first.pqRestart, isNotNull);
    expect(first.message, '');
    final asked = db.rows('pq_restarts').single;
    expect(asked['asks'], 1);
    // not again within the day; again after it
    final at = asked['asked_at'] as int;
    io.sent.clear();
    await app.pqUpkeep(nowMs: at + const Duration(hours: 23).inMilliseconds);
    expect(io.sent, isEmpty);
    await app.pqUpkeep(nowMs: at + const Duration(hours: 25).inMilliseconds);
    expect(io.sent, hasLength(1));
    final again = (await aliceReads()).single;
    expect(db.rows('pq_restarts').single['asks'], 2);

    // alice builds on it and sends her opener
    final l = alice.ls!;
    final block = l.lib.parseDeviceBundle(
      base64Decode(again.pqRestart!),
      signalSession.identity.public,
    );
    expect(await l.restartFrom('bob', block.bundle), isTrue);
    final opener = await alice.seal(
      'bob',
      await envelopeFrom('alice', alice.ls!.identity.public),
    );
    expect(base64Decode(opener)[0], kLsPreKey);
    io.sent.clear();
    await app.receiveRelay([(peer: aliceX, cipher: opener)]);
    await settle();
    await settle();
    expect((await signalSession.sessionInfo('alice'))!.version, 4);
    final pqAt = await app.pqLineAt('alice');
    expect(pqAt, isNotNull);
    // the answer went at once, on pq, and settles her side
    expect(io.sent, hasLength(1));
    expect(base64Decode(io.sent.single.$2)[0], kLsWhisper);
    await aliceReads();
    expect(base64Decode(await l.encryptTo('bob', 'x'))[0], kLsWhisper);
    // done: no KDB1 again, however long
    io.sent.clear();
    await app.pqUpkeep(nowMs: pqAt! + const Duration(days: 3).inMilliseconds);
    expect(io.sent, isEmpty);
    expect(
      (await signalSession.sessionInfo(
        'alice',
      ))!.archived.map((s) => s.version),
      contains(3),
    );
    await app.pqUpkeep(nowMs: pqAt + kClassicDropAfter.inMilliseconds);
    final after = (await signalSession.sessionInfo('alice'))!;
    expect(after.archived.where((s) => s.version < 4), isEmpty);
    expect(io.sent, isEmpty);
    expect(db.rows('messages'), isEmpty);
  }, skip: needsShim);
}
