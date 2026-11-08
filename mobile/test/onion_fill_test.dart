// SPDX-License-Identifier: GPL-3.0-or-later
// a v4 first contact keeps no onion until they answer:
// their first frame on the session gives it, a held one is never replaced,
// and someone who only asked gets none. the database methods are the real
// ones over rows kept in maps; the wire and signal are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show AppState, AppStateReceive, HaloDb, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
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

Future<void> _person(MemDb mem, String id, String? onion, {int accepted = 1}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': onion,
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': accepted,
      'back_paired': 0,
      'blocked': 0,
    });

String? _onion(MemDb mem, String id) {
  for (final r in mem.rows('contacts')) {
    if (r['halo_id'] == id) return r['onion'] as String?;
  }
  return null;
}

String _onionOf(String c) => '${c * 56}.onion';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late ArrivalIo io;
  late AppState app;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('onion_fill');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    final db = _Rows(mem);
    io = ArrivalIo();
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(db, Session(db));
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  var n = 0;
  // a text from [id] saying its onion is [onion], as it comes off the relay.
  // [names] is who the envelope says sent it
  Future<void> from(String id, String onion, {String? names}) async {
    final c = 'c-${++n}';
    final who = names ?? id;
    io.opens[c] = (
      id,
      await wrapMessage(
        'hi $n',
        msgUid: 'u$n',
        sender: SenderInfo(
          haloId: who,
          edPub: 'ed-$who',
          onion: onion,
          xPub: 'x-$who',
        ),
      ),
    );
    await app.receiveRelay([(peer: 'x-$id', cipher: c)]);
    await settle();
  }

  test('their first frame gives a contact with no onion theirs, and a later '
      'one does not replace it', () async {
    await _person(mem, 'ana-no-onion', '');
    await from('ana-no-onion', 'not an onion');
    expect(_onion(mem, 'ana-no-onion'), '');
    await from('ana-no-onion', _onionOf('a'));
    expect(_onion(mem, 'ana-no-onion'), _onionOf('a'));
    await from('ana-no-onion', _onionOf('b'));
    expect(_onion(mem, 'ana-no-onion'), _onionOf('a'));
  });

  test('an onion held stays, and someone who only asked gets none', () async {
    await _person(mem, 'ben-held', _onionOf('c'));
    await from('ben-held', _onionOf('d'));
    expect(_onion(mem, 'ben-held'), _onionOf('c'));
    await _person(mem, 'cy-asked', '', accepted: 0);
    await from('cy-asked', _onionOf('e'));
    expect(_onion(mem, 'cy-asked'), '');
  });

  test('a contact has no null onion, and a frame naming someone else '
      'fills nobody else', () async {
    // what fillOnion counts as none: the schema has no other
    await expectLater(_person(mem, 'dot-null', null), throwsStateError);
    await _person(mem, 'ana-opens', _onionOf('g'));
    await _person(mem, 'ben-named', '');
    await from('ana-opens', _onionOf('h'), names: 'ben-named');
    expect(_onion(mem, 'ben-named'), '');
    expect(_onion(mem, 'ana-opens'), _onionOf('g'));
  });
}
