// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's screenshot block between two phones. real database methods over
// rows in maps; the wire and signal are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

Future<void> _person(MemDb mem, String id, {int accepted = 1}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o-$id',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': accepted,
      'back_paired': 1,
    });

// one phone: its rows, its wire and its app
class _Phone {
  _Phone(this.me);
  final String me;
  final mem = MemDb();
  late final db = _Rows(mem);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  Future<void> start(String peer, {int accepted = 1}) async {
    await _person(mem, peer, accepted: accepted);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = me
      ..sendModeForTest = 'fast';
  }

  // this phone's databases are the app's now
  void use() => useDatabasesForTest(db, Session(db));

  ChatShots shots(String peer) => ChatShots.ofRow(
    mem.rows('contacts').firstWhere((r) => r['halo_id'] == peer),
  );

  // what went out since the last look, as signalEncrypt seals it
  Future<List<String>> wire(String peer) async {
    use();
    final out = <String>[];
    for (final (_, c) in io.sent.skip(_n)) {
      out.add(await app.shotsOnWire(peer, c.substring('to $peer '.length)));
    }
    _n = io.sent.length;
    return out;
  }

  Future<void> take(String from, List<String> plains) async {
    use();
    var i = 0;
    for (final p in plains) {
      final c = '$me-in-${io.opens.length}-${i++}';
      io.opens[c] = (from, p);
      await app.receiveRelay([(peer: 'x-$from', cipher: c)]);
    }
    await settle();
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late _Phone amy, bob;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('chat_shots_sync');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    amy = _Phone('amy');
    bob = _Phone('bob');
    await amy.start('bob');
    await bob.start('amy');
  });

  tearDown(() => docs.deleteSync(recursive: true));

  // a text from [from] to [to], as [from]'s seal sends it
  Future<void> text(_Phone from, _Phone to, String uid) async {
    from.use();
    final w = await wrapMessage(
      'hi $uid',
      msgUid: uid,
      sender: asSender(from.me),
    );
    await to.take(from.me, [await from.app.shotsOnWire(to.me, w)]);
  }

  test('the switch waits until their phone says it knows the block', () async {
    amy.use();
    await amy.app.setChatShots('bob', true);
    await settle();
    expect(amy.shots('bob').on, isFalse);
    expect(amy.mem.rows('frames_out'), isEmpty);
    expect(amy.io.sent, isEmpty);
    // a text from bob's phone carries the key: now it can
    await text(bob, amy, 'b1');
    expect(amy.shots('bob').peerCan, isTrue);
    expect(amy.shots('bob').blocking, isFalse);
  });

  test(
    'on from one phone is on on the other, and either turns it off',
    () async {
      await text(bob, amy, 'b1');
      await text(amy, bob, 'a1');
      amy.use();
      await amy.app.setChatShots('bob', true);
      await settle();
      final a = amy.shots('bob');
      expect((a.on, a.by, a.blocking), (true, kShotsByMe, true));
      expect(a.when, greaterThan(0));
      // queued, and gone at once
      expect(amy.mem.rows('frames_out'), isEmpty);

      await bob.take('amy', await amy.wire('bob'));
      var b = bob.shots('amy');
      expect((b.on, b.by, b.at, b.blocking), (true, kShotsByThem, a.at, true));
      // the frame is no message on either side
      expect(
        bob.mem.rows('messages').where((r) => r['msg_uid'] == null),
        isEmpty,
      );

      // bob turns it off: amy's phone takes it, and says it was bob
      bob.use();
      await bob.app.setChatShots('amy', false);
      await settle();
      b = bob.shots('amy');
      expect((b.on, b.by), (false, kShotsByMe));
      expect(b.at, greaterThan(a.at));
      await amy.take('bob', await bob.wire('amy'));
      final a2 = amy.shots('bob');
      expect(
        (a2.on, a2.by, a2.at, a2.blocking),
        (false, kShotsByThem, b.at, false),
      );
    },
  );

  test(
    'every message carries the state, so a lost frame still lands',
    () async {
      await text(bob, amy, 'b1');
      amy.use();
      await amy.app.setChatShots('bob', true);
      await settle();
      // the frame never reaches bob; amy's next text does
      await amy.wire('bob');
      await text(amy, bob, 'a2');
      expect(bob.shots('amy').on, isTrue);
    },
  );

  test('an older word arriving late changes nothing', () async {
    await text(bob, amy, 'b1');
    await text(amy, bob, 'a1');
    amy.use();
    await amy.app.setChatShots('bob', true);
    await settle();
    final on = await amy.wire('bob');
    await amy.app.setChatShots('bob', false);
    await settle();
    final off = await amy.wire('bob');
    await bob.take('amy', off);
    await bob.take('amy', on);
    expect(bob.shots('amy').on, isFalse);
  });

  test('a request sets nothing here, but says what its phone knows', () async {
    await _person(amy.mem, 'eve', accepted: 0);
    final changed = await amy.db.takeShots(
      'eve',
      const ShotsWord(on: true, at: 99),
      counts: true,
      written: 50,
    );
    expect(changed, isTrue);
    final s = amy.shots('eve');
    expect((s.on, s.by, s.peerCan), (false, kShotsByNone, true));
    // someone with no row here: nothing
    expect(
      await amy.db.takeShots(
        'nobody',
        const ShotsWord(on: true, at: 99),
        counts: true,
        written: 50,
      ),
      isFalse,
    );
  });

  test('someone blocked: nothing of theirs is taken', () async {
    await text(bob, amy, 'b1');
    await amy.db.setBlocked('bob', true);
    bob.use();
    final w = await wrapMessage('', sender: asSender('bob'));
    await amy.take('bob', [shotsStamped(w, const ShotsWord(on: true, at: 5))]);
    expect(amy.shots('bob').on, isFalse);
  });

  test(
    'a newer message without the key: their phone no longer knows it',
    () async {
      await text(bob, amy, 'b1');
      amy.use();
      await amy.app.setChatShots('bob', true);
      await settle();
      expect(amy.shots('bob').blocking, isTrue);
      // bob's phone went back to a version without the block
      final w = await wrapMessage(
        'from an older phone',
        msgUid: 'b9',
        sender: asSender('bob'),
        writtenAt: DateTime.now().millisecondsSinceEpoch + 1000,
      );
      await amy.take('bob', [w]);
      final s = amy.shots('bob');
      expect(s.on, isTrue);
      expect(s.peerCan, isFalse);
      expect(s.blocking, isFalse);
      // and the switch waits again
      await amy.app.setChatShots('bob', false);
      expect(amy.shots('bob').on, isTrue);
    },
  );

  test('a hidden chat keeps its block in the vault', () async {
    final everyday = MemDb(), hidden = MemDb();
    await _person(hidden, 'bob');
    final live = _Rows(everyday);
    final vault = _Rows(hidden, HaloContainer.vault);
    final s = await Session.withVault(live, vault);
    expect(identical(s.peerDb('bob'), vault), isTrue);
    await hidden.update('contacts', {'shots_can': 5});
    useDatabasesForTest(live, s);
    await amy.app.setChatShots('bob', true);
    await settle();
    expect(ChatShots.ofRow(hidden.rows('contacts').single).on, isTrue);
    expect(everyday.rows('contacts'), isEmpty);
  });

  test('as a chat starts blocking, what the shade shows of it goes, on '
      'both phones', () async {
    await text(bob, amy, 'b1');
    await text(amy, bob, 'a1');
    expect(amy.io.unrang, isNot(contains('bob')));
    amy.use();
    await amy.app.setChatShots('bob', true);
    await settle();
    expect(amy.io.unrang, contains('bob'));
    expect(bob.io.unrang, isNot(contains('amy')));
    await bob.take('amy', await amy.wire('bob'));
    expect(bob.io.unrang, contains('amy'));
    // already blocking: what comes after takes nothing down, so what it
    // rings stays
    final went = amy.io.unrang.length;
    for (final n in [2, 3, 4]) {
      await text(bob, amy, 'b$n');
    }
    expect(amy.io.unrang, hasLength(went));
  });
}
