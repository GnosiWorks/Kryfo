// SPDX-License-Identifier: GPL-3.0-or-later
// a chat cleared, deleted or declined takes the files still coming in it,
// and a chat put away is asked for no missing slices: the ask says this
// phone is here, and the file it brings would put the chat back. the real
// database methods over rows kept in maps; the wire and engine are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-sending-a-file';
const _eve = 'eve-sending-a-file';
const _sec = 1000;

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

class _Wire extends ArrivalIo {
  final out = <String>[];
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    out.add(cipher);
    return super.relaySend(xPub, cipher);
  }
}

class _Engine implements HaloEngine {
  @override
  (int, int) catchupState() => (0, 1);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

int _now() => DateTime.now().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;

  Future<void> person(String id, {int accepted = 1, int archived = 0}) =>
      mem.insert('contacts', {
        'halo_id': id,
        'onion': '',
        'xpub': 'x-$id',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': accepted,
        'archived': archived,
        'back_paired': 1,
      });

  // half a file from [from]: five of its ten slices. a want row only for
  // one sent in their own chat
  Future<void> half(String mid, String from, {bool own = true}) async {
    if (own) {
      await mem.insert('media_wants', {
        'media_id': mid,
        'peer_id': from,
        'total': 10,
        'can_resend': 1,
        'last_at': _now() - 50 * _sec,
      });
    }
    for (var i = 0; i < 5; i++) {
      await mem.insert('media_chunks', {
        'media_id': mid,
        'idx': i,
        'slice': 'AAAA',
        'total': 10,
        'at': 1,
        'sender': from,
      });
    }
  }

  Set<Object?> chunksLeft() => {
    for (final r in mem.rows('media_chunks')) r['media_id'],
  };
  Set<Object?> wantsLeft() => {
    for (final r in mem.rows('media_wants')) r['media_id'],
  };

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('put_away_files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem);
  });

  tearDown(() {
    docs.deleteSync(recursive: true);
    for (final k in incomingMediaProgress.keys.toList()) {
      incomingMediaDone(k);
    }
  });

  for (final (name, run) in <(String, Future<void> Function(HaloDb))>[
    ('clear', (d) => d.clearConversation(_bob)),
    ('delete', (d) => d.deleteConversation(_bob)),
    ('decline', (d) => d.declineRequest(_bob)),
  ]) {
    test('$name takes the files still coming in their chat', () async {
      await person(_bob, accepted: name == 'decline' ? 0 : 1);
      await person(_eve);
      await half('from-bob', _bob);
      await half('bob-in-group', _bob, own: false);
      await half('from-eve', _eve);
      expect(await db.filesInFlightFrom(_bob), 1);
      incomingMediaUpdate(db.container.chatKey(_bob), 5, 10);
      incomingMediaUpdate(db.container.chatKey(_eve), 5, 10);
      await run(db);
      expect(chunksLeft(), {'bob-in-group', 'from-eve'});
      expect(wantsLeft(), {'from-eve'});
      expect(await db.filesInFlightFrom(_bob), 0);
      // no paused banner left over the emptied chat, and eve's stays
      expect(incomingMediaProgress.keys, [db.container.chatKey(_eve)]);
    });
  }

  group('asking for missing slices', () {
    late _Wire io;
    late AppState app;

    setUp(() async {
      useEngineForTest(_Engine());
      io = _Wire();
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      app = AppState(io: io, router: router)
        ..myId = 'me'
        ..sendModeForTest = 'fast';
      useDatabasesForTest(db, Session(db));
    });

    test('a chat put away is asked nothing, and its file goes', () async {
      await person(_bob, accepted: 0, archived: 1);
      await half('from-bob', _bob);
      incomingMediaUpdate(db.container.chatKey(_bob), 5, 10);
      await app.askForMissingSlices();
      expect(io.out, isEmpty);
      expect(wantsLeft(), isEmpty);
      expect(chunksLeft(), isEmpty);
      expect(incomingMediaProgress, isEmpty);
    });

    test('a chat only archived is still asked', () async {
      await person(_bob, archived: 1);
      await half('from-bob', _bob);
      await app.askForMissingSlices();
      expect(io.out, hasLength(1));
      expect(wantsLeft(), {'from-bob'});
    });
  });
}
