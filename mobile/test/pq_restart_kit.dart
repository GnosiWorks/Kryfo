// SPDX-License-Identifier: GPL-3.0-or-later
// the app as one phone of the 0.7.4 fixture's held chat (alice and bob),
// for the pq restart tests: real signal on the shim and the real database
// methods over rows kept in maps; the wire and the engine stood in. the
// other phone is a store of its own, sealing and opening by hand
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        appState,
        HaloEngine,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'signal_ls/shim_lib.dart';

export 'signal_ls/shim_lib.dart' show Phone, needsShim, unpadText;

final _fixture =
    jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
        as Map<String, dynamic>;

Object? _value(Object? v) => v is Map ? base64Decode(v['b64'] as String) : v;

String hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// [who]'s rows of the fixture in [db]
Future<void> fixtureRows(MemDb db, String who) async {
  for (final r in (_fixture[who] as Map)['rows'] as List) {
    final row = (r as Map)['row'] as Map;
    await db.insert(r['t'] as String, {
      for (final e in row.entries) e.key as String: _value(e.value),
    });
  }
}

({Uint8List pub, Uint8List priv}) fixtureKeys(String who) {
  final me = _fixture[who] as Map;
  return (
    pub: base64Decode(me['pub'] as String),
    priv: base64Decode(me['priv'] as String),
  );
}

/// the fixture's pending opener from alice to bob
String fixtureWire(String k) => (_fixture['wire'] as Map)[k] as String;

/// [who] as a phone of its own, its store open
Future<Phone> fixturePhone(String who) async {
  final db = MemDb();
  await fixtureRows(db, who);
  final p = Phone.of(fixtureKeys(who), db);
  await p.openLs();
  return p;
}

class PqEngine implements HaloEngine {
  PqEngine(this.x);
  final String x;
  @override
  String myXPubkey() => x;
  @override
  String myEdPubkey() => 'ed-me';
  @override
  void nostrSubscribeBg(int ident, String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(int ident, String peerXPubHex) {}
  @override
  String idFromEdPub(String hexPub) => 'no-such-id';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

/// the wire: real seals, every relay copy kept
class PqIo extends AppIo {
  final sent = <(String, String)>[];
  @override
  void listen(int ident, String xPub, {bool fresh = false}) {}

  @override
  void listenHidden(int ident, String xPub, {bool fresh = false}) =>
      listen(ident, xPub, fresh: fresh);
  @override
  void unlisten(int ident, String xPub) {}
  @override
  Future<String> relaySend(int ident, String xPub, String cipher) async {
    sent.add((xPub, cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async => 'err';
  @override
  Future<String> firstContactSend(
    int ident,
    String x,
    String fc,
    String c,
  ) async => 'ok';
  @override
  Future<String> letHeld(int ident, String xPub, String how) async => 'ok';
  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    Object? on,
    String? msgUid,
    int? burnAt,
  }) async {}
  @override
  Future<void> unnotify(String payload) async {}
  @override
  Future<void> unnotifyGone(String payload, Set<String> tags) async {}
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
}

class PqRows extends HaloDb {
  PqRows(this.mem);
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

/// the app as [me], once per test file: its store from the fixture
Future<({MemDb db, PqIo io, AppState app})> bootApp(String me) async {
  final docs = Directory.systemTemp.createTempSync('pq_restart');
  addTearDown(() {});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => docs.path,
      );
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final db = MemDb();
  await fixtureRows(db, me);
  final k = fixtureKeys(me);
  useEngineForTest(PqEngine(hexOf(k.pub)));
  await signalSession.bootstrap(
    database: db,
    xPubBytes: k.pub,
    xPrivBytes: k.priv,
  );
  final io = PqIo();
  final router = VaultRouter(ArrivalStore(), ArrivalSeal());
  await router.load();
  final live = PqRows(db);
  // the app's own instance is made first, when anything reaches it: the
  // store's callbacks then go to this one, made after it
  expect(identical(appState, appState), isTrue);
  final app = AppState(io: io, router: router)..myId = me;
  useDatabasesForTest(live, Session(live));
  return (db: db, io: io, app: app);
}

/// [id] as an accepted contact of the app, back-paired, saying [caps]
Future<void> contact(MemDb db, String id, List<int> key, String caps) =>
    db.insert('contacts', {
      'halo_id': id,
      'onion': '',
      'xpub': hexOf(key.sublist(1)),
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': 0,
      'caps': caps,
    });

/// an envelope from [from] (x key [x]) with [extra] in it
Future<String> envelopeFrom(
  String from,
  List<int> key, {
  Map<String, Object?> extra = const {},
  int? writtenAt,
}) async {
  final w = await wrapMessage(
    '',
    sender: SenderInfo(
      haloId: from,
      edPub: 'ed-$from',
      onion: '',
      xPub: hexOf(key.sublist(1)),
    ),
    writtenAt: writtenAt,
  );
  final j = jsonDecode(w.substring(kEnvelopePrefix.length)) as Map;
  j.addAll(extra);
  return '$kEnvelopePrefix${jsonEncode(j)}';
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));
