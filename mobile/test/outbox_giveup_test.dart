// SPDX-License-Identifier: GPL-3.0-or-later
// the outbox never gives up on a row: past an hour of failures it still
// tries, ten minutes apart, and a route back (tor ready again, a relay
// answering again) starts a pass at once. a chat nobody opens gets its rows
// out all the same. the clock is the test's; the database methods are the
// real ones over rows kept in maps, the wire a stand-in
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        outboxClock,
        useDatabasesForTest,
        useEngineForTest,
        AppStateOutbox,
        AppStateRoute;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-far-away';
const _minute = Duration(minutes: 1);

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
          !skip.contains(r['peer_id']))
        r,
  ];
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

// every relay try to bob noted
class _Io extends ArrivalIo {
  final tried = <String>[];
  @override
  Future<({int ident, String cipher})> seal(String peer, String plain) async =>
      (ident: 0, cipher: await encrypt(peer, plain));
  @override
  Future<String> relaySend(int ident, String xPub, String cipher) async {
    if (xPub == 'x-$_bob') tried.add(xPub);
    return super.relaySend(ident, xPub, cipher);
  }
}

// the relays as the transport reads them
class _Engine implements HaloEngine {
  List<Map<String, Object?>> relays = [];
  @override
  Map<String, dynamic> transportState() => {'relays': relays};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Io io;
  late _Engine eng;
  late VaultRouter router;
  late AppState app;
  late DateTime t;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('outbox_giveup');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    t = DateTime(2026, 11, 6, 9);
    outboxClock = () => t;
    mem = MemDb();
    final db = _Rows(mem);
    io = _Io();
    eng = _Engine();
    useEngineForTest(eng);
    await mem.insert('contacts', {
      'halo_id': _bob,
      'onion': '',
      'xpub': 'x-$_bob',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': 0,
    });
    await mem.insert('messages', {
      'peer_id': _bob,
      'direction': 'out',
      'plaintext': 'still there?',
      'sent_at': t.subtract(_minute).millisecondsSinceEpoch,
      'msg_uid': 'm1',
      'sent': 0,
    });
    router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(db, Session(db));
  });

  tearDown(() {
    outboxClock = DateTime.now;
    docs.deleteSync(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  bool sent() => mem.rows('messages').single['sent'] == 1;

  // the periodic tick, [n] times, [gap] apart on the test's clock
  Future<void> ticks(int n, Duration gap) async {
    for (var i = 0; i < n; i++) {
      await app.drainOutbox();
      await settle();
      t = t.add(gap);
    }
  }

  test('a row keeps trying past the old eight-try cutoff, ten minutes '
      'apart at most', () async {
    io.down = true;
    // two hours and a half of failures with the network up
    await ticks(15, const Duration(minutes: 10, seconds: 1));
    expect(io.tried, hasLength(15));
    expect(app.outboxTriesForTest('m1'), 15);
    // the gap stays at ten minutes, never more
    final next = app.outboxNextAtForTest('m1')!;
    expect(
      next - t.millisecondsSinceEpoch,
      lessThanOrEqualTo(const Duration(minutes: 10).inMilliseconds),
    );
    // and within the gap nothing goes: no tight loop
    t = t.subtract(const Duration(minutes: 5));
    await ticks(10, const Duration(seconds: 20));
    expect(io.tried, hasLength(15));
  });

  test('a chat nobody opened gets its row out once the route is back, '
      'with the periodic tick alone', () async {
    io.down = true;
    await ticks(12, const Duration(minutes: 10, seconds: 1));
    expect(sent(), isFalse);
    io.down = false;
    await ticks(1, Duration.zero);
    expect(sent(), isTrue);
    expect(io.tried, hasLength(13));
  });

  test('tor ready again starts a pass at once, not at the gap', () async {
    app.sendModeForTest = 'private';
    app.takeTorStatus('bootstrapped|100|0|1|1');
    io.down = true;
    await ticks(9, const Duration(minutes: 10, seconds: 1));
    expect(io.tried, hasLength(9));
    // tor bounces between two ticks
    t = t.add(const Duration(minutes: 2));
    app.takeTorStatus('starting|40|0|0|2');
    app.flushOnRouteUp();
    await settle();
    expect(io.tried, hasLength(9));
    io.down = false;
    t = t.add(const Duration(seconds: 30));
    app.takeTorStatus('bootstrapped|100|0|1|2');
    app.flushOnRouteUp();
    await settle();
    expect(io.tried, hasLength(10));
    expect(sent(), isTrue);
  });

  test('a relay answering again starts a pass at once, and a flapping '
      'one at most once a minute', () async {
    io.down = true;
    eng.relays = [
      {'url': 'r1', 'up': true},
    ];
    app.sampleRelayHealth();
    await ticks(9, const Duration(minutes: 10, seconds: 1));
    expect(io.tried, hasLength(9));
    t = t.add(const Duration(minutes: 2));
    eng.relays = [
      {'url': 'r1', 'up': false, 'fails': 4},
    ];
    app.sampleRelayHealth();
    await settle();
    expect(io.tried, hasLength(9));
    // back, and the send still fails: one try now
    eng.relays = [
      {'url': 'r1', 'up': true},
    ];
    app.sampleRelayHealth();
    await settle();
    expect(io.tried, hasLength(10));
    // gone and back again within the minute: the gap holds
    t = t.add(const Duration(seconds: 20));
    eng.relays = [
      {'url': 'r1', 'up': false, 'fails': 1},
    ];
    app.sampleRelayHealth();
    eng.relays = [
      {'url': 'r1', 'up': true},
    ];
    app.sampleRelayHealth();
    await settle();
    expect(io.tried, hasLength(10));
    // past the minute it goes again, and lands
    t = t.add(const Duration(minutes: 1));
    io.down = false;
    eng.relays = [
      {'url': 'r1', 'up': false, 'fails': 1},
    ];
    app.sampleRelayHealth();
    eng.relays = [
      {'url': 'r1', 'up': true},
    ];
    app.sampleRelayHealth();
    await settle();
    expect(io.tried, hasLength(11));
    expect(sent(), isTrue);
  });
}
