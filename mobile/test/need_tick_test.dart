// SPDX-License-Identifier: GPL-3.0-or-later
// the receiver's side of asking for missing slices, run against the app: a
// tick every 15 s that reads one small table and sends nothing while no
// file is due, an ask stamped before it goes so no second one follows it
// out, a count of asks that starts again once one brings slices, and no
// ask while a catch-up may still be bringing the slices in.
// the rows are kept in maps, the wire and the engine are stand-ins
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/media_resend.dart' show kNeedQuietMs;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _p = 'sender-of-the-file';
const _m = 'file-in-slices';
const _sec = 1000;

// the everyday database over rows in maps, noting the reads a tick makes
class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  final reads = <String>[];
  // the next read of the wants held open until a test lets it go
  Completer<void>? hold;

  @override
  Future<Database> open() async => mem;

  @override
  Future<List<Map<String, Object?>>> mediaWants() async {
    reads.add('mediaWants');
    final h = hold;
    hold = null;
    await h?.future;
    return super.mediaWants();
  }

  @override
  Future<bool> messageExists(String msgUid) {
    reads.add('messageExists');
    return super.messageExists(msgUid);
  }

  @override
  Future<Set<int>> heldSlices(String mediaId) {
    reads.add('heldSlices');
    return super.heldSlices(mediaId);
  }
}

// the relay send, held open until a test lets it go
class _Wire extends ArrivalIo {
  Completer<void>? hold;
  final out = <String>[];

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    out.add(cipher);
    await hold?.future;
    return super.relaySend(xPub, cipher);
  }
}

// the engine as the ask reaches it: how many relays are catching up, and
// how many catch-ups have begun
class _Engine implements HaloEngine {
  var walking = 0;
  var begun = 1;
  var kicks = 0;

  @override
  (int, int) catchupState() => (walking, begun);

  // every relay asked again: a catch-up begins on each
  @override
  String nostrKick() {
    kicks++;
    begun++;
    walking = 1;
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _Idle implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

class _World {
  final mem = MemDb();
  late final rows = _Rows(mem);
  final io = _Wire();
  final engine = _Engine();
  late AppState app;

  static Future<_World> make() async {
    final w = _World();
    useEngineForTest(w.engine);
    await w.mem.insert('contacts', {
      'halo_id': _p,
      'onion': '',
      'xpub': 'x-$_p',
      'first_seen': 1,
      'last_seen': 1,
      'back_paired': 1,
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(w.rows, Session(w.rows));
    return w;
  }

  // a file of ten slices with the first five held
  Future<void> want({required int last, int asked = 0, int asks = 0}) async {
    await mem.insert('media_wants', {
      'media_id': _m,
      'peer_id': _p,
      'total': 10,
      'can_resend': 1,
      'last_at': last,
      'asked_at': asked,
      'asks': asks,
    });
    for (var i = 0; i < 5; i++) {
      await mem.insert('media_chunks', {
        'media_id': _m,
        'idx': i,
        'slice': 'AAAA',
        'total': 10,
        'at': 1,
        'sender': _p,
      });
    }
  }

  Map<String, Object?> get row => mem.rows('media_wants').single;

  // what went out, read back as the sender would
  List<List<int>> get asked => [
    for (final c in io.out)
      unwrapMessage(c.substring('to $_p '.length)).need!.indices,
  ];

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 500 && !done(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(done(), isTrue);
  }
}

int _now() => DateTime.now().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('need_tick');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('the look for missing slices runs every 15 s', () async {
    final w = await _World.make();
    final made = <Duration, void Function(Timer)>{};
    runZoned(
      w.app.startOutboxDrain,
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, period, f) {
          made[period] = f;
          return _Idle();
        },
      ),
    );
    final tick = made[const Duration(seconds: 15)];
    expect(tick, isNotNull);
    // the start's catch-up has been and gone
    w.engine.begun++;
    tick!(_Idle());
    await w.until(() => w.rows.reads.isNotEmpty);
    expect(w.rows.reads, ['mediaWants']);
  });

  group('a tick with nothing due', () {
    test('reads one table and sends nothing', () async {
      final w = await _World.make();
      final writes = w.mem.log.length;
      await w.app.askForMissingSlices();
      expect(w.rows.reads, ['mediaWants']);
      expect(w.mem.log.length, writes);
      expect(w.io.out, isEmpty);
    });

    test('reads no slices of a file still coming in', () async {
      final w = await _World.make();
      await w.want(last: _now() - 5 * _sec);
      await w.app.askForMissingSlices();
      expect(w.rows.reads, ['mediaWants']);
      expect(w.io.out, isEmpty);
      expect(w.row['asked_at'], 0);
    });

    test(
      'nor of one waiting out the backoff of an ask that brought nothing',
      () async {
        final w = await _World.make();
        final now = _now();
        await w.want(last: now - 200 * _sec, asked: now - 100 * _sec, asks: 1);
        await w.app.askForMissingSlices();
        expect(w.rows.reads, ['mediaWants']);
        expect(w.io.out, isEmpty);
      },
    );

    test('with tor down, reads nothing at all', () async {
      final w = await _World.make();
      w.app.sendModeForTest = 'private';
      await w.want(last: 1);
      await w.app.askForMissingSlices();
      expect(w.rows.reads, isEmpty);
      expect(w.io.out, isEmpty);
    });
  });

  test(
    'the ask is stamped before it goes, and no second one follows it out',
    () async {
      final w = await _World.make();
      await w.want(last: _now() - 50 * _sec);
      final hold = w.io.hold = Completer<void>();
      final first = w.app.askForMissingSlices();
      await w.until(() => w.io.out.isNotEmpty);
      final stamped = (w.row['asked_at'], w.row['asks']);
      // two ticks while it is out, and one after it is back
      final ticks = [w.app.askForMissingSlices(), w.app.askForMissingSlices()];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      hold.complete();
      await Future.wait([first, ...ticks]);
      await w.app.askForMissingSlices();
      expect(w.asked, [
        [5, 6, 7, 8, 9],
      ]);
      // while the send was out the row already said so
      expect(stamped.$1, greaterThan(0));
      expect(stamped.$2, 1);
    },
  );

  test('an ask that brought slices is followed after the quiet, not a '
      'backoff', () async {
    final w = await _World.make();
    final now = _now();
    // the third ask in a row brought slices, the last 50 s ago
    await w.want(last: now - 50 * _sec, asked: now - 100 * _sec, asks: 3);
    await w.app.askForMissingSlices();
    expect(w.asked, hasLength(1));
    expect(w.row['asks'], 1);
    expect(w.row['asked_at'], greaterThanOrEqualTo(now));
  });

  test('the count is of asks in a row that brought nothing', () async {
    final w = await _World.make();
    await w.want(last: 1000);
    await w.rows.markMediaAsked(_m, 5000);
    expect((w.row['asked_at'], w.row['asks']), (5000, 1));
    await w.rows.markMediaAsked(_m, 9000);
    expect((w.row['asked_at'], w.row['asks']), (9000, 2));
    // a slice lands after it
    await w.mem.update(
      'media_wants',
      {'last_at': 9500},
      where: 'media_id = ?',
      whereArgs: [_m],
    );
    await w.rows.markMediaAsked(_m, 20000);
    expect((w.row['asked_at'], w.row['asks']), (20000, 1));
    // a file no longer wanted is left alone
    await w.rows.markMediaAsked('gone', 30000);
    expect(w.mem.rows('media_wants'), hasLength(1));
  });

  group('no ask while a catch-up may still bring the slices', () {
    // a want from before: due on the row alone the moment the route is up
    Future<_World> stale() async {
      final w = await _World.make();
      await w.want(last: _now() - 3 * 3600 * _sec);
      return w;
    }

    // as if the quiet after the last hold had passed
    void quietPassed(_World w) => w.app.needHoldForTest.heldAt -= kNeedQuietMs;

    test('none while one runs, and quiet counts from its end', () async {
      final w = await stale();
      w.engine
        ..walking = 1
        ..begun = 2;
      await w.app.askForMissingSlices();
      expect(w.io.out, isEmpty);
      expect(w.rows.reads, isNot(contains('heldSlices')));
      expect(w.row['asked_at'], 0);
      // it ends: the slices it brought may be landing still
      w.engine.walking = 0;
      await w.app.askForMissingSlices();
      expect(w.io.out, isEmpty);
      quietPassed(w);
      await w.app.askForMissingSlices();
      expect(w.asked, [
        [5, 6, 7, 8, 9],
      ]);
    });

    test('none after a start until its catch-up has begun and ended', () async {
      final w = await stale();
      final made = <Duration, void Function(Timer)>{};
      runZoned(
        w.app.startOutboxDrain,
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, period, f) {
            made[period] = f;
            return _Idle();
          },
        ),
      );
      final tick = made[const Duration(seconds: 15)]!;
      Future<void> ticked() async {
        tick(_Idle());
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // the relays are still being dialled: nothing runs yet
      await ticked();
      quietPassed(w);
      await ticked();
      expect(w.io.out, isEmpty);
      // the walk
      w.engine
        ..walking = 1
        ..begun = 2;
      await ticked();
      expect(w.io.out, isEmpty);
      w.engine.walking = 0;
      await ticked();
      expect(w.io.out, isEmpty);
      quietPassed(w);
      await ticked();
      expect(w.asked, hasLength(1));
    });

    test('none after the route comes back until its catch-up is in', () async {
      final w = await stale();
      // seen once with the route up, then it goes
      w.engine
        ..walking = 1
        ..begun = 3;
      await w.app.askForMissingSlices();
      w.engine.walking = 0;
      await w.app.askForMissingSlices();
      w.app.sendModeForTest = 'private';
      await w.app.askForMissingSlices();
      w.app.sendModeForTest = 'fast';
      // back, and its relays still being dialled
      quietPassed(w);
      await w.app.askForMissingSlices();
      expect(w.io.out, isEmpty);
      w.engine
        ..walking = 1
        ..begun = 4;
      await w.app.askForMissingSlices();
      w.engine.walking = 0;
      await w.app.askForMissingSlices();
      expect(w.io.out, isEmpty);
      quietPassed(w);
      await w.app.askForMissingSlices();
      expect(w.asked, hasLength(1));
    });

    test('a tick does not get in ahead of a check-in, which asks once its '
        'catch-up is in', () async {
      final w = await stale();
      final checked = w.app.checkIn(why: 'test');
      await w.until(() => w.engine.kicks == 1);
      await w.app.askForMissingSlices();
      expect(w.io.out, isEmpty);
      w.engine.walking = 0;
      await w.app.askForMissingSlices();
      // past every hold but the check-in's own
      quietPassed(w);
      await w.app.askForMissingSlices();
      expect(w.io.out, isEmpty);
      await checked;
      expect(w.asked, [
        [5, 6, 7, 8, 9],
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
