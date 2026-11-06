// SPDX-License-Identifier: GPL-3.0-or-later
// with the computer's trace on, what came from a chat says what it was and
// where it showed, between the lines of the poll that brought it: a crash
// on the way leaves the last step it reached. never the words, the sender
// or the chat. real database methods over rows in maps; the wire and
// signal are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_trace.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, useDatabasesForTest, AppStateReceive, AppStateRoute;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import '../arrival_fakes.dart';
import '../mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // past what the map rows read
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
}

const _sam = 'sam-who-scanned';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late String file;
  late MemDb mem;
  late ArrivalIo io;
  late AppState app;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('desk_arrival_trace');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    final db = _Rows(mem);
    useDatabasesForTest(db, Session(db));
    // a request accepted here a moment ago: nothing came from them yet
    await mem.insert('contacts', {
      'halo_id': _sam,
      'onion': '',
      'xpub': 'x-$_sam',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    io = ArrivalIo();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    file = '${docs.path}/trace.txt';
    traceTo(file);
  });

  tearDown(() {
    traceTo(null);
    docs.deleteSync(recursive: true);
  });

  Future<void> take(String plain) async {
    final c = 'c-${io.opens.length}';
    io.opens[c] = (_sam, plain);
    await app.receiveRelay([(peer: 'x-$_sam', cipher: c)]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  List<String> lines() => [
    for (final l in File(file).readAsLinesSync())
      l.substring(l.indexOf(' ') + 1),
  ];

  test('their first sticker after an accept: added back, then the sticker '
      'and where it showed, and nothing that names them', () async {
    await take(
      await wrapMessage(
        'secret wave words',
        msgUid: 'u-wave',
        sticker: 'fokia:1:1',
        sender: asSender(_sam),
      ),
    );
    final l = lines();
    expect(l, contains('added back: the outbox and the photo go'));
    expect(l, contains('message in: sticker, accepted, toast'));
    expect(
      l.indexOf('added back: the outbox and the photo go'),
      lessThan(l.indexOf('message in: sticker, accepted, toast')),
    );
    final all = File(file).readAsStringSync();
    expect(all, isNot(contains(_sam)));
    expect(all, isNot(contains('secret')));
    expect(all, isNot(contains('u-wave')));
  });

  test('a word with nothing to show is said as one', () async {
    await take(await wrapMessage('', sender: asSender(_sam)));
    expect(lines(), contains('message in: a word with nothing to show'));
  });

  test('the line says the kind, the chat and where, and the folder is the '
      'trace\'s', () {
    expect(
      arrivalTraceLine(
        sticker: false,
        poll: false,
        media: false,
        file: false,
        words: true,
        group: false,
        accepted: false,
        reading: true,
        quiet: true,
      ),
      'message in: text, request, chat on screen',
    );
    expect(
      arrivalTraceLine(
        sticker: false,
        poll: false,
        media: true,
        file: false,
        words: false,
        group: true,
        accepted: true,
        reading: false,
        quiet: true,
      ),
      'message in: media, group, no toast',
    );
    expect(traceDir, docs.path);
    traceTo(null);
    expect(traceDir, isNull);
  });
}
