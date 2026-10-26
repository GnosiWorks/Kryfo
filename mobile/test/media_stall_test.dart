// SPDX-License-Identifier: GPL-3.0-or-later
// a file whose slices stop being taken ends as stalled instead of holding
// its row for good: the outbox takes the row over and goes on from the
// slices that landed, as the same message, and a send that was stopped
// stays stopped. real signal and database methods over rows in maps; the
// wire is a stand-in
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest,
        AppStateOutbox,
        AppStateRoute;
import 'package:kryfo/media_progress.dart' show mediaSendProgress;
import 'package:kryfo/media_send.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _me = 'me-who-sends';
const _peer = 'peer-who-waits';
// seven slices, exactly
const _bytes = 7 * 12288;

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read: the same rule, in dart
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

// the relay: the first [answer] slices are taken, the rest never answer
// until they are let go
class _Wire implements HaloEngine {
  var answer = 1 << 30;
  var calls = 0;
  final went = <String>[];
  final hung = <Completer<String>>[];
  @override
  String myXPubkey() => 'x-me';
  @override
  String myEdPubkey() => 'ed-me';
  @override
  Future<String> nostrSend(String x, String c) {
    calls++;
    if (calls > answer) {
      final h = Completer<String>();
      hung.add(h);
      return h.future;
    }
    went.add(c);
    return Future.value('ok');
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

// what the other phone reads of a slice: its message and its place
Future<UnwrappedMessage> _read(SignalSession them, String cipher) async {
  final w = base64Decode(cipher);
  final body = Uint8List.fromList(w.sublist(1));
  final c = SessionCipher(
    them.sessionStore,
    them.preKeyStore,
    them.signedPreKeyStore,
    them.identityStore,
    SignalProtocolAddress(_me, 1),
  );
  final plain = w[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return unwrapMessage(utf8.decode(plain));
}

Future<void> _until(bool Function() ok, {int ms = 10000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late SignalSession them;
  late MemDb mem;
  late _Wire wire;
  late File note;
  final was = mediaStallAfter;

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('media_stall');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    them = SignalSession();
    await them.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(
      _peer,
      await makePreKeyBundleB64(them),
      into: signalSession,
    );
    final r = Random(5);
    note = File('${docs.path}/voice.wav')
      ..writeAsBytesSync([
        for (var i = 0; i < _bytes - 100; i++) r.nextInt(256),
      ]);
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mediaStallAfter = const Duration(milliseconds: 600);
    wire = _Wire();
    useEngineForTest(wire);
    mem = MemDb();
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
    });
    final db = _Rows(mem);
    useDatabasesForTest(db, Session(db));
    // the one the sender reads
    appState
      ..myId = _me
      ..sendModeForTest = 'fast';
  });

  // a send left hanging ends with its test, and touches no later one
  tearDown(() async {
    for (final h in wire.hung) {
      if (!h.isCompleted) h.complete('error: gone');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    mediaStallAfter = was;
  });

  // the voice note's row, written a while ago and not sent yet
  Future<void> row(String uid) => mem.insert('messages', {
    'peer_id': _peer,
    'direction': 'out',
    'plaintext': '',
    'sent_at': DateTime.now().millisecondsSinceEpoch - 120000,
    'msg_uid': uid,
    'sent': 0,
    'file_path': note.path,
    'file_name': 'voice.wav',
  });

  // the chat's own send of the note
  Future<String> send(String uid) => sendChunkedMediaTo(
    peerId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    backPaired: true,
    needPow: false,
    path: note.path,
    msgUid: uid,
    fileName: 'voice.wav',
    voice: true,
    sender: asSender(_me),
    progressKey: _peer,
  );

  List<Map<String, Object?>> rowsOf(String uid) => [
    for (final r in mem.rows('messages'))
      if (r['msg_uid'] == uid) r,
  ];

  test('a slice that never answers ends the send as stalled, lets go of '
      'the row and keeps what landed', () async {
    wire.answer = 3;
    final going = send('v-stall');
    await _until(() => wire.hung.length == 4);
    expect(mediaInflight, contains('v-stall'));
    // a voice note shows how far it is, as a photo does
    expect(mediaSendProgress['v-stall'], closeTo(3 / 7, 0.001));
    final r = await going.timeout(const Duration(seconds: 10));
    expect(r, kMediaStalled);
    expect(mediaInflight, isNot(contains('v-stall')));
    await whenMediaFree('v-stall').timeout(const Duration(seconds: 1));
    expect(chunkDone['v-stall'], hasLength(3));
    expect(mediaSendProgress, isNot(contains('v-stall')));
    // a slice that answers after the end is kept, and nothing else moves
    final calls = wire.calls;
    wire.hung.first.complete('ok');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(chunkDone['v-stall'], hasLength(4));
    expect(wire.calls, calls);
    expect(mediaSendProgress, isNot(contains('v-stall')));
    chunkDone.remove('v-stall');
  });

  test('the outbox takes a stalled note over and sends only what is '
      'missing, as the same message', () async {
    await row('v-over');
    wire.answer = 3;
    final going = send('v-over');
    await _until(() => wire.hung.length == 4);
    // held by the chat's send: a pass leaves it be and spends no try
    await appState.drainOutbox();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(appState.outboxTriesForTest('v-over'), 0);
    expect(wire.calls, 7);
    // the route is back by the time the outbox goes on
    wire.answer = 1 << 30;
    expect(await going.timeout(const Duration(seconds: 10)), kMediaStalled);
    await _until(() => rowsOf('v-over').single['sent'] == 1);
    expect(appState.outboxTriesForTest('v-over'), lessThanOrEqualTo(1));
    // every slice went once: three before, four after, the hung never
    final read = [for (final c in wire.went) await _read(them, c)];
    expect([for (final m in read) m.chunkIndex]..sort(), [0, 1, 2, 3, 4, 5, 6]);
    for (final m in read) {
      expect(m.msgUid, 'v-over');
      expect(m.mediaId, 'v-over');
      expect(m.chunkTotal, 7);
    }
    expect(mem.rows('messages'), hasLength(1));
    expect(chunkDone, isNot(contains('v-over')));
    // the hung ones waking late send nothing more
    for (final h in wire.hung) {
      h.complete('ok');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(wire.went, hasLength(7));
    expect(mediaSendProgress, isNot(contains('v-over')));
  });

  test('a send that keeps moving is never stalled, however long it '
      'takes', () async {
    mediaStallAfter = const Duration(milliseconds: 300);
    // slow slices, each well inside the bound, the whole well past it
    final w = wire..answer = 0;
    final going = send('v-slow');
    final pace = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (w.hung.every((h) => h.isCompleted) && w.calls >= 7) {
        t.cancel();
        return;
      }
      for (final h in w.hung) {
        if (!h.isCompleted) {
          h.complete('ok');
          break;
        }
      }
    });
    expect(await going.timeout(const Duration(seconds: 10)), 'ok');
    pace.cancel();
  });

  test('a stop asked while a slice hangs ends the send as stopped, and no '
      'pass sends it again', () async {
    await row('v-stop');
    wire.answer = 2;
    final going = send('v-stop');
    await _until(() => wire.hung.length == 5);
    cancelMediaSend('v-stop');
    expect(await going.timeout(const Duration(milliseconds: 300)), 'cancelled');
    expect(mediaInflight, isNot(contains('v-stop')));
    // the row is still there while the chat takes it back: nothing takes
    // it up meanwhile, the outbox nor a retry
    wire.answer = 1 << 30;
    await appState.drainOutbox(wait: true);
    expect(await send('v-stop'), 'cancelled');
    for (final h in wire.hung) {
      h.complete('ok');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(wire.went, hasLength(2));
    expect(rowsOf('v-stop').single['sent'], 0);
  });
}
