// SPDX-License-Identifier: GPL-3.0-or-later
// the pq restart of a hidden chat on the side that starts it: the app is
// bob, the smaller key, and alice's chat is in the vault. with the vault
// shut nothing is looked for and nothing goes; open, her caps say pq and
// the KDB1 goes inside the held session, as for an everyday chat
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, AppStatePqRestart, HaloDb, live, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'pq_restart_kit.dart';

class _VaultRows extends HaloDb {
  _VaultRows(this.mem) : super(HaloContainer.vault);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<List<Map<String, Object?>>> blockedRows({required int now}) async =>
      const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemDb db;
  late MemDb hidden;
  late PqIo io;
  late AppState app;
  late Phone alice;
  late HaloDb everyday;
  late HaloDb vault;

  setUpAll(() async {
    if (needsShim != false) return;
    final b = await bootApp('bob');
    db = b.db;
    io = b.io;
    app = b.app;
    everyday = live;
    hidden = MemDb();
    vault = _VaultRows(hidden);
    alice = await fixturePhone('alice');
    await contact(hidden, 'alice', alice.ls!.identity.public, 'gs,pq,ty');
    final a6 = base64Decode(fixtureWire('a6'));
    await signalSession.open('alice', a6[0], Uint8List.fromList(a6.sublist(1)));
    expect(
      await alice.read('bob', await signalSession.encryptTo('alice', 'b0')),
      'b0',
    );
  });

  test('shut, nothing goes; open, the KDB1 goes to her', () async {
    io.sent.clear();
    useDatabasesForTest(everyday, Session(everyday));
    await app.pqUpkeep();
    expect(io.sent, isEmpty);
    expect(db.rows('pq_restarts'), isEmpty);
    useDatabasesForTest(everyday, await Session.withVault(everyday, vault));
    await app.pqUpkeep(
      nowMs: DateTime.now().millisecondsSinceEpoch + 2 * 3600 * 1000,
    );
    expect(io.sent, hasLength(1));
    final w = unwrapMessage(await alice.read('bob', io.sent.single.$2));
    expect(w.pqRestart, isNotNull);
    expect(w.message, '');
    expect(db.rows('pq_restarts').single['asks'], 1);
    expect(db.rows('contacts'), isEmpty);
    expect(hidden.rows('messages'), isEmpty);
  }, skip: needsShim);
}
