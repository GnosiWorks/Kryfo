// SPDX-License-Identifier: GPL-3.0-or-later
// a heal on a chat that was still classic (identity v4 3.8 with 11 step 5):
// the session it builds is pq, so the restart counts as done there and
// then. its 15 days begin, the upkeep sends no KDB1 for it, and the line
// and the answer go as for any heal
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/heal.dart' show makeHeal;
import 'package:kryfo/main.dart'
    show AppState, AppStateHeal, AppStatePqRestart, AppStateReceive;
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

  setUpAll(() async {
    if (needsShim != false) return;
    final b = await bootApp('bob');
    db = b.db;
    io = b.io;
    app = b.app;
    alice = await fixturePhone('alice');
    aliceX = hexOf(alice.ls!.identity.public.sublist(1));
    await contact(db, 'alice', alice.ls!.identity.public, 'gs,pq,ty');
    await db.update(
      'contacts',
      {'back_paired': 1},
      where: 'halo_id = ?',
      whereArgs: ['alice'],
    );
    // the held chat, classic, as 0.5.x left it
    final a6 = base64Decode(fixtureWire('a6'));
    await signalSession.open('alice', a6[0], Uint8List.fromList(a6.sublist(1)));
  });

  test('a heal moves a classic chat to pq: its time is noted, and no KDB1 '
      'follows', () async {
    expect((await signalSession.sessionInfo('alice'))!.version, 3);
    // a frame of hers: her key is known as hers
    final hi = await alice.seal(
      'bob',
      await envelopeFrom('alice', alice.ls!.identity.public),
    );
    await app.receiveRelay([(peer: aliceX, cipher: hi)]);
    await settle();
    io.sent.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    await app.takeHealForTest(
      aliceX,
      await makeHeal(
        alice.ls!,
        peer: signalSession.identity.public,
        nowMs: now,
      ),
    );
    await settle();
    final info = (await signalSession.sessionInfo('alice'))!;
    expect(info.version, 4);
    expect(info.archived.any((s) => s.version < 4), isTrue);
    expect(db.rows('pq_restarts').single['pq_at'], isNotNull);
    expect(db.rows('heal_lines'), hasLength(1));
    // the answer went; the upkeep sends nothing more
    final went = io.sent.length;
    expect(went, greaterThan(0));
    await app.pqUpkeep();
    expect(io.sent, hasLength(went));
  }, skip: needsShim);
}
