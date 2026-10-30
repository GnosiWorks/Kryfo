// SPDX-License-Identifier: GPL-3.0-or-later
// the pq restart of a hidden chat (identity v4 10, phase 6 left it): the
// app is alice, the larger key, and bob's chat is in the vault. while it is
// open his KDB1 starts pq as an everyday one does, his answer notes the
// time and the line, and the classic states go 16 days on with the vault
// shut, by the restart row alone and without a read of the vault: a chat
// restarted and then hidden drops on time too. a row whose session went
// goes. nothing of it shows as a message on either side
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStatePqRestart,
        AppStateReceive,
        HaloDb,
        kClassicDropAfter,
        live,
        phoneRestartBundle,
        useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'pq_restart_kit.dart';

class _VaultRows extends HaloDb {
  _VaultRows(this.mem) : super(HaloContainer.vault);
  final MemDb mem;
  // how often anything read or wrote it
  var opens = 0;
  @override
  Future<Database> open() async {
    opens++;
    return mem;
  }

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
  late Phone bob;
  late String bobX;
  late HaloDb everyday;
  late _VaultRows vault;

  Future<void> openVault() async =>
      useDatabasesForTest(everyday, await Session.withVault(everyday, vault));
  void shutVault() => useDatabasesForTest(everyday, Session(everyday));

  setUpAll(() async {
    if (needsShim != false) return;
    final b = await bootApp('alice');
    db = b.db;
    io = b.io;
    app = b.app;
    everyday = live;
    hidden = MemDb();
    vault = _VaultRows(hidden);
    bob = await fixturePhone('bob');
    bobX = hexOf(bob.ls!.identity.public.sublist(1));
    // bob's chat is the vault's: his row is there, none on the everyday side
    await contact(hidden, 'bob', bob.ls!.identity.public, 'gs,pq,ty');
    await openVault();
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

  test('his KDB1 starts pq while the vault is open, his answer notes the '
      'time and the line, and with the vault shut the classic states go '
      '16 days on', () async {
    expect(db.rows('contacts'), isEmpty);
    io.sent.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    await app.receiveRelay([(peer: bobX, cipher: await rq(writtenAt: now))]);
    await settle();
    final info = (await signalSession.sessionInfo('bob'))!;
    expect(info.version, 4);
    expect(info.archived.map((s) => s.version), contains(3));
    expect(io.sent, hasLength(1));
    final opener = io.sent.single.$2;
    expect(base64Decode(opener)[0], kLsPreKey);
    expect(unwrapMessage(await bob.read('alice', opener)).message, '');
    // his answer, on the pq state
    final answer = await bob.seal(
      'alice',
      await envelopeFrom('bob', bob.ls!.identity.public),
    );
    expect(base64Decode(answer)[0], kLsWhisper);
    await app.receiveRelay([(peer: bobX, cipher: answer)]);
    await settle();
    final at = await app.pqLineAt('bob');
    expect(at, isNotNull);
    // the vault shuts: the upkeep reads nothing of it, and the row alone
    // lets the classic states go on time
    shutVault();
    final opens = vault.opens;
    await app.pqUpkeep(nowMs: at! + kClassicDropAfter.inMilliseconds - 1);
    expect(
      (await signalSession.sessionInfo('bob'))!.archived.map((s) => s.version),
      contains(3),
    );
    await app.pqUpkeep(nowMs: at + kClassicDropAfter.inMilliseconds);
    final after = (await signalSession.sessionInfo('bob'))!;
    expect(after.version, 4);
    expect(after.archived.where((s) => s.version < 4), isEmpty);
    expect(db.rows('pq_restarts').single['dropped_at'], isNotNull);
    // and the shut vault was not read for any of it
    expect(vault.opens, opens);
    // nothing of it is a message, nor an everyday row of his
    expect(db.rows('messages'), isEmpty);
    expect(hidden.rows('messages'), isEmpty);
    expect(db.rows('contacts'), isEmpty);
  }, skip: needsShim);

  test('a row whose session went goes at the next upkeep', () async {
    expect(db.rows('pq_restarts'), hasLength(1));
    await signalSession.sessionStore.delete('bob');
    await app.pqUpkeep();
    expect(db.rows('pq_restarts'), isEmpty);
  }, skip: needsShim);
}
