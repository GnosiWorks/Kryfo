// SPDX-License-Identifier: GPL-3.0-or-later
// an accept owes the requester word that they are in. with no route the
// word waits on their row, in the container that holds them, and goes once
// the route is back: once, at the outbox's gaps, and after a restart too.
// a shut vault keeps its own, and a decoy keeps what it owes as it keeps
// what is typed in it. the database methods are the real ones over rows
// kept in maps; the wire and signal are stand-ins
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-who-asked';
const _vic = 'vic-kept-hidden';
const _dee = 'dee-in-the-decoy';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
  // past what the map rows read
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
}

// every relay try noted, and one held at the wire when told
class _Io extends ArrivalIo {
  final tried = <String>[];
  Completer<void>? hold;
  // the keys listened for as just added or accepted
  final fresh = <String>[];

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    tried.add(xPub);
    await hold?.future;
    return super.relaySend(xPub, cipher);
  }

  @override
  void listen(String xPub, {bool fresh = false}) {
    if (fresh) this.fresh.add(xPub);
    super.listen(xPub);
  }
}

Future<void> _person(MemDb mem, String id) => mem.insert('contacts', {
  'halo_id': id,
  'onion': '',
  'xpub': 'x-$id',
  'first_seen': 1,
  'last_seen': 1,
  'accepted': 1,
  'back_paired': 1,
  'blocked': 0,
});

int? _owed(MemDb mem, String id) {
  for (final r in mem.rows('contacts')) {
    if (r['halo_id'] == id) return r['ack_owed'] as int?;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late _Io io;
  late VaultRouter router;
  late AppState app;

  AppState start() => AppState(io: io, router: router)
    ..myId = 'me'
    ..sendModeForTest = 'fast';

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('ack_owed');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem);
    io = _Io();
    await _person(mem, _bob);
    router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = start();
    useDatabasesForTest(db, Session(db));
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  // the empty frames that went to [id]: the accept's word
  List<String> acks(String id) => [
    for (final (to, c) in io.sent)
      if (to == 'relay x-$id' &&
          unwrapMessage(c.substring(c.indexOf(' ', 3) + 1)).message.isEmpty)
        c,
  ];

  // accepted with the network gone: the try fails and the word waits
  Future<void> acceptOffline(AppState a, String id) async {
    a.noteOnline(false);
    io.down = true;
    await a.afterAccept(id);
    await settle();
  }

  test('accepted with no route, the ack waits on their row and goes once '
      'the network is back, once', () async {
    await acceptOffline(app, _bob);
    expect(io.tried, ['x-$_bob']);
    expect(acks(_bob), isEmpty);
    expect(_owed(mem, _bob), 1);
    // they are listened for at once, not after a turn
    expect(io.fresh, ['x-$_bob']);

    // nothing tries while the network is gone
    await app.drainOutbox();
    await settle();
    expect(io.tried, hasLength(1));

    io.down = false;
    app.noteOnline(true);
    await settle();
    expect(acks(_bob), hasLength(1));
    expect(_owed(mem, _bob), 0);

    // the route coming up again, the outbox and a flap send nothing more
    app.flushOnRouteUp();
    await app.drainOutbox();
    app.noteOnline(false);
    app.noteOnline(true);
    await app.drainAcksForTest();
    await settle();
    expect(acks(_bob), hasLength(1));
    expect(io.tried, hasLength(2));
  });

  test('the mark lives through a restart, and the next run sends it '
      'once', () async {
    await acceptOffline(app, _bob);
    expect(_owed(mem, _bob), 1);
    // the process goes; a new one starts over the same database
    io.down = false;
    final next = start();
    await next.drainOutbox();
    await settle();
    expect(acks(_bob), hasLength(1));
    expect(_owed(mem, _bob), 0);
    await next.drainOutbox();
    await next.drainAcksForTest();
    await settle();
    expect(acks(_bob), hasLength(1));
  });

  test('a route that fails keeps the outbox\'s gaps between tries', () async {
    io.down = true;
    await app.afterAccept(_bob);
    await settle();
    expect(io.tried, hasLength(1));
    await app.drainAcksForTest();
    expect(io.tried, hasLength(2));
    // the next waits out its gap
    await app.drainAcksForTest();
    await app.drainOutbox();
    await settle();
    expect(io.tried, hasLength(2));
    expect(_owed(mem, _bob), 1);
    // the user's send-now goes at once
    io.down = false;
    await app.flushOutboxNow();
    await settle();
    expect(acks(_bob), hasLength(1));
    expect(_owed(mem, _bob), 0);
  });

  test('passes that meet a send under way send nothing beside it', () async {
    final gate = Completer<void>();
    io.hold = gate;
    await app.afterAccept(_bob);
    await settle();
    expect(io.tried, hasLength(1));
    await Future.wait([app.drainAcksForTest(), app.drainOutbox()]);
    app.flushOnRouteUp();
    await settle();
    expect(io.tried, hasLength(1));
    gate.complete();
    io.hold = null;
    await settle();
    await app.drainAcksForTest();
    await settle();
    expect(acks(_bob), hasLength(1));
    expect(io.tried, hasLength(1));
  });

  test('a hidden contact\'s mark stays in the vault and goes only while '
      'it is open', () async {
    final vMem = MemDb();
    final vault = _Rows(vMem, HaloContainer.vault);
    await _person(vMem, _vic);
    useDatabasesForTest(db, await Session.withVault(db, vault));
    await acceptOffline(app, _vic);
    expect(_owed(vMem, _vic), 1);
    // nothing of it on the everyday side
    expect(_owed(mem, _vic), isNull);
    expect(await db.ackOwed(), isEmpty);

    // shut: nothing goes for it
    useDatabasesForTest(db, Session(db));
    io.down = false;
    app.noteOnline(true);
    await app.drainOutbox();
    await settle();
    expect(acks(_vic), isEmpty);
    expect(_owed(vMem, _vic), 1);

    // open again: it goes, once
    useDatabasesForTest(db, await Session.withVault(db, vault));
    await app.drainOutbox();
    await settle();
    expect(acks(_vic), hasLength(1));
    expect(_owed(vMem, _vic), 0);
    await app.drainAcksForTest();
    await settle();
    expect(acks(_vic), hasLength(1));
  });

  test('a decoy keeps what it owes and sends nothing, and the everyday '
      'side shows none of it', () async {
    final dMem = MemDb();
    final decoy = _Rows(dMem, HaloContainer.decoy);
    await _person(dMem, _dee);
    useDatabasesForTest(db, Session(decoy));
    await app.afterAccept(_dee);
    await app.drainOutbox();
    await app.drainAcksForTest();
    await settle();
    expect(io.tried, isEmpty);
    expect(_owed(dMem, _dee), 1);
    expect(await db.ackOwed(), isEmpty);

    // back on the everyday side the decoy's mark is never read
    useDatabasesForTest(db, Session(db));
    await app.drainOutbox();
    await app.drainAcksForTest();
    await settle();
    expect(io.tried, isEmpty);
    expect(_owed(dMem, _dee), 1);
  });

  test('the ack that went unlocks the requester', () async {
    await acceptOffline(app, _bob);
    io.down = false;
    app.noteOnline(true);
    await settle();
    final sent = acks(_bob).single;
    final plain = sent.substring(sent.indexOf(' ', 3) + 1);

    // the requester: they added us and wrote, and wait for the accept
    final rMem = MemDb();
    await _person(rMem, 'me');
    await rMem.update('contacts', {'back_paired': 0});
    final rDb = _Rows(rMem);
    final rIo = _Io()..opens['c-ack'] = ('me', plain);
    final them = AppState(io: rIo, router: router)
      ..myId = _bob
      ..sendModeForTest = 'fast';
    useDatabasesForTest(rDb, Session(rDb));
    expect(await rDb.isBackPaired('me'), isFalse);
    expect(await them.receiveRelay([(peer: 'x-me', cipher: 'c-ack')]), isEmpty);
    await settle();
    expect(await rDb.isBackPaired('me'), isTrue);
  });
}
