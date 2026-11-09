// SPDX-License-Identifier: GPL-3.0-or-later
// the engine's door queue hears which chat is open, which sends are
// messages and which are the rest, and who wrote: the open chat dials
// first, messages before receipts and controls, and a contact who wrote
// stops resting
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateProfile,
        AppStateReceive,
        AppStatePairing;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _amy = 'amy-on-screen';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
}

class _Io extends ArrivalIo {
  var firstDown = false;
  var onionDown = false;

  @override
  Future<String> firstContactSend(
    int ident,
    String xPub,
    String fc,
    String cipher,
  ) async {
    sent.add(('fc $xPub', cipher));
    return firstDown ? 'error: no relays accepted' : 'ok';
  }

  // each onion send and whether it went as the rest
  final places = <bool>[];

  @override
  Future<String> onionSend(
    String onion,
    String cipher, {
    bool rest = false,
  }) async {
    sent.add(('onion $onion', cipher));
    places.add(rest);
    return onionDown ? 'error: timeout' : 'ok';
  }
}

class _Engine implements HaloEngine {
  // the keys told to ask first, in order
  final first = <String>[];
  @override
  void nostrFirst(String peerXPubHex) => first.add(peerXPubHex);
  // the onions told as the open chat, and the ones woken
  final focus = <String>[];
  final awake = <String>[];
  @override
  void doorFocus(String onion) => focus.add(onion);
  @override
  void doorAwake(String onion) => awake.add(onion);
  @override
  void nostrSubscribeBg(int ident, String peerXPubHex, {bool fresh = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late _Io io;
  late AppState app;

  late _Engine engine;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('door_queue_place');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    useEngineForTest(engine = _Engine());
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem, HaloContainer.everyday);
    io = _Io();
    engine.focus.clear();
    engine.awake.clear();
    await mem.insert('contacts', {
      'halo_id': _amy,
      'onion': 'o-$_amy',
      'xpub': 'x-$_amy',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(db, Session(db));
    await app.rememberPeerFc(_amy, 'fc-$_amy');
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  Future<void> contact(Map<String, Object?> v) =>
      mem.update('contacts', v, where: 'halo_id = ?', whereArgs: [_amy]);

  test('the open chat is told to the door by its onion, and let go when '
      'it closes', () async {
    app.chatFirst(_amy);
    await settle();
    expect(engine.focus, ['o-$_amy']);
    app.chatFirst(null);
    await settle();
    expect(engine.focus, ['o-$_amy', '']);
  });

  test(
    'an accept ack is no message: its onion dial waits as the rest',
    () async {
      await app.sendAcceptAck(_amy);
      await settle();
      expect(io.places, [true]);
    },
  );

  // what decides a message's place is read off the code: a group's fan-out,
  // the outbox's redelivery and an opener again go as messages, and the
  // one envelope send hands its flag to both onion sends
  test('messages are flagged where they leave', () {
    String read(String f) => File('lib/app/$f').readAsStringSync();
    final lanes = read('state_group_lanes.dart');
    final fan = lanes.substring(lanes.indexOf('Future<List<String>> _fanOut('));
    expect(
      fan.substring(0, fan.indexOf('\n  }\n')),
      contains('_sendGroupEnvelope(groupId, m, wrapped, message: true)'),
    );
    final out = read('state_outbox.dart');
    expect(
      'rest: !message'.allMatches(out).length,
      2,
      reason: 'both onion sends of _sendOneEnvelope',
    );
    expect(out, contains('_sendOneEnvelope(peer, wrapped, message: true)'));
    expect(out, contains('pairOnly: pairOnly,\n        message: true,'));
    expect(
      read('state_rooms.dart'),
      contains('member: true,\n        message: message,'),
    );
  });

  test(
    'a frame from a contact wakes their onion, once a minute at most',
    () async {
      for (final uid in ['a1', 'a2']) {
        io.opens['c-$uid'] = (
          _amy,
          await wrapMessage('hi', msgUid: uid, sender: asSender(_amy)),
        );
        await app.receiveRelay([(peer: 'firstcontact', cipher: 'c-$uid')]);
        await settle();
      }
      expect(engine.awake, ['o-$_amy']);
    },
  );

  test('a contact with no onion on their row wakes nothing', () async {
    await contact({'onion': ''});
    io.opens['c1'] = (
      _amy,
      await wrapMessage('hi', msgUid: 'b1', sender: asSender(_amy)),
    );
    await app.receiveRelay([(peer: 'firstcontact', cipher: 'c1')]);
    await settle();
    expect(engine.awake, isEmpty);
  });
}
