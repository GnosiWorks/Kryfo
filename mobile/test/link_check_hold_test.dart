// SPDX-License-Identifier: GPL-3.0-or-later
// a linked computer whose start check has not confirmed it sends nothing:
// its texts, edits, pins, reactions and receipts wait, the gate up or the
// chats read only, and the wire turns anything else down. confirmed, each
// goes once. a removal holds it all again at once, for good. the database
// methods are the real ones over rows kept in maps; the wire and signal
// are stand-ins
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/devices/link_check.dart';
import 'package:kryfo/devices/linked_lock.dart' show LinkedEnd;
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        deviceUnlinked,
        linkCheckResetForTest,
        linkRemovedForTest,
        linkSendsHeld,
        linkedEndResetForTest,
        linkedEndsForTest,
        linkedRoleForTest,
        linkedWipeForTest,
        useDatabasesForTest,
        kFrameReaction,
        AppStateOutbox,
        AppStateRoute;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-who-writes';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out' &&
          r['sent'] == 0 &&
          r['msg_uid'] != null &&
          r['group_id'] == null &&
          !skip.contains(r['peer_id']))
        r,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late ArrivalIo io;
  late AppState app;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('link_hold');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem);
    io = ArrivalIo();
    await mem.insert('contacts', {
      'halo_id': _bob,
      'onion': 'o-$_bob',
      'xpub': 'x-$_bob',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': 0,
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(db, Session(db));
    linkCheckResetForTest();
    linkedEndResetForTest();
  });

  tearDown(() {
    linkCheckResetForTest();
    linkedEndResetForTest();
    linkedRoleForTest = false;
    linkedWipeForTest = null;
    linkedDevicesForTest = null;
    docs.deleteSync(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  Future<void> queued() async {
    await mem.insert('messages', {
      'peer_id': _bob,
      'direction': 'out',
      'plaintext': 'text t1',
      'sent_at': 1,
      'msg_uid': 't1',
      'sent': 0,
    });
    await db.queueEdit('e1', _bob, 'changed');
    await db.queuePin('p1', _bob, true);
    await db.queueFrame('r1', kFrameReaction, _bob, 'x');
    for (final t in ['edits_out', 'pins_out', 'frames_out']) {
      for (final r in mem.rows(t)) {
        await mem.update(
          t,
          {'at': DateTime.now().millisecondsSinceEpoch - 60000},
          where: 'msg_uid = ?',
          whereArgs: [r['msg_uid']],
        );
      }
    }
  }

  List<String> went() => [
    for (final (_, c) in io.sent)
      () {
        final m = unwrapMessage(c.substring(c.indexOf(' ', 3) + 1));
        if (m.edit != null) return 'edit ${m.edit!.targetUid}';
        if (m.pin != null) return 'pin ${m.pin!.targetUid}';
        if (m.reaction != null) return 'reaction ${m.reaction!.targetUid}';
        if (m.deliveredUid != null) return 'receipt ${m.deliveredUid}';
        return 'text ${m.msgUid}';
      }(),
  ]..sort();

  int tries(String table) => (mem.rows(table).single['tries'] as int?) ?? 0;

  test('the gate up, then the chats read only: nothing goes and no try is '
      'used; confirmed, each goes once', () async {
    await queued();
    for (final stage in LinkCheckStage.values) {
      linkCheck.value = stage;
      expect(linkSendsHeld, isTrue);
      expect(app.everydayHeld, isTrue);
      await app.drainOutbox();
      await app.receiptForTest(_bob, 'm1');
      await app.askForMissingSlices();
      await app.sendOpenersAgain();
      await settle();
      expect(io.sent, isEmpty, reason: '$stage');
      expect(mem.rows('messages').single['sent'], 0);
      expect(tries('edits_out'), 0);
      expect(tries('pins_out'), 0);
    }

    // its phone's list named it
    linkCheck.value = null;
    expect(app.everydayHeld, isFalse);
    await app.drainOutbox();
    await settle();
    await app.drainOutbox();
    await settle();
    expect(went(), [
      'edit e1',
      'pin p1',
      'reaction r1',
      'receipt m1',
      'text t1',
    ]);
    expect(mem.rows('messages').single['sent'], 1);
  });

  test('the wire turns down every send while held, typing too', () async {
    const wire = AppIo();
    linkCheck.value = LinkCheckStage.checking;
    expect(await wire.relaySend(0, 'x', 'c'), 'error: held');
    expect(await wire.onionSend('o', 'c'), 'error: held');
    expect(await wire.typingSend('o', 'c'), 'error: held');
    linkCheck.value = LinkCheckStage.readOnly;
    expect(await wire.relaySend(0, 'x', 'c'), 'error: held');
  });

  test('open and confirmed, a removal holds everything from that moment, '
      'and nothing lets it go', () async {
    linkedDevicesForTest = true;
    linkedRoleForTest = true;
    final wiped = Completer<void>();
    linkedWipeForTest = () => wiped.future;
    await queued();
    expect(app.everydayHeld, isFalse);

    final end = linkedEndsForTest(LinkedEnd.removed);
    // held before the wipe has even begun its work
    expect(linkRemovedForTest, isTrue);
    expect(linkSendsHeld, isTrue);
    expect(deviceUnlinked.value, LinkedEnd.removed);
    await app.drainOutbox();
    await app.receiptForTest(_bob, 'm1');
    await settle();
    expect(io.sent, isEmpty);
    expect(mem.rows('messages').single['sent'], 0);

    // a check that finished meanwhile lets nothing go
    linkCheck.value = null;
    expect(app.everydayHeld, isTrue);
    wiped.complete();
    await end;
  });

  test(
    'an end that is not a removal does not hold its own last word',
    () async {
      linkedDevicesForTest = true;
      linkedRoleForTest = true;
      linkedWipeForTest = () async {};
      await linkedEndsForTest(LinkedEnd.self);
      expect(linkRemovedForTest, isFalse);
      expect(linkSendsHeld, isFalse);
    },
  );
}
