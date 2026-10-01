// SPDX-License-Identifier: GPL-3.0-or-later
// a new identity asked for during setup takes everything made from the key
// with it: the invite's signal identity and signed prekey, its invite
// prekey and the first-contact address listened on, and a second ask
// while one runs makes no third key. real libsignal over rows kept in
// maps; the engine hands out keys the way it does on a phone
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        HaloEngine,
        makePreKeyBundleB64,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart' show signalSession;
import 'package:kryfo/signal_stores.dart' show invitePreKeyId;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

class _Engine implements HaloEngine {
  _Engine() {
    _next();
  }
  late ECKeyPair pair;
  var id = 'first-words-here';
  final listened = <int>[];

  void _next() => pair = Curve.generateKeyPair();

  @override
  String generateIdentity() {
    _next();
    return id = 'second-words-now';
  }

  @override
  String myXPubkey() => _hex(pair.publicKey.serialize().sublist(1));
  @override
  String myXPrivkey() => _hex(pair.privateKey.serialize());
  @override
  String myEdPrivkey() => 'ed';
  @override
  void subscribeFirstContactBg(int counter) => listened.add(counter);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _Live implements HaloDb {
  _Live(this.db);
  final Database db;
  final saved = <String>[];
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<Database> open() async => db;
  @override
  Future<void> saveIdentity(String id, String edPriv, String xPriv) async =>
      saved.add(id);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('live: ${i.memberName}');
}

Map<String, dynamic> _bundle(String b64) =>
    jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new identity during setup moves signal and the invite address '
      'to the new key', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final e = _Engine();
    useEngineForTest(e);
    final db = MemDb();
    final live = _Live(db);
    useDatabasesForTest(live, Session(live));
    Uint8List bytes(String hex) => Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    await signalSession.bootstrap(
      database: db,
      xPubBytes: bytes(e.myXPubkey()),
      xPrivBytes: bytes(e.myXPrivkey()),
    );
    final app = AppState(
      io: const AppIo(),
      router: VaultRouter(ArrivalStore(), ArrivalSeal()),
    )..myId = e.id;
    await app.loadFirstContact();
    expect(e.listened, [0]);
    final before = _bundle(await makePreKeyBundleB64());
    final oldInvite = await signalSession.preKeyStore.loadPreKey(
      invitePreKeyId,
    );

    await app.regenerateIdentity();

    expect(live.saved, ['second-words-now']);
    final now = _bundle(await makePreKeyBundleB64());
    // the invite names the key every envelope is now sent under
    final key = IdentityKey.fromBytes(
      base64Decode(now['identityKey'] as String),
      0,
    );
    expect(_hex(key.publicKey.serialize().sublist(1)), e.myXPubkey());
    expect(now['identityKey'], isNot(before['identityKey']));
    expect(
      Curve.verifySignature(
        key.publicKey,
        base64Decode(now['signedPreKeyPublic'] as String),
        base64Decode(now['signedPreKeySignature'] as String),
      ),
      isTrue,
    );
    final invite = await signalSession.preKeyStore.loadPreKey(invitePreKeyId);
    expect(
      invite.getKeyPair().publicKey.serialize(),
      isNot(oldInvite.getKeyPair().publicKey.serialize()),
    );
    // the address of the new key is the one listened on
    expect(e.listened, [0, 0]);

    // a second tap while signal is still being made again changes nothing:
    // signal ends on the key the engine holds
    final first = app.regenerateIdentity();
    for (var i = 0; i < 1000 && signalSession.ready; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(signalSession.ready, isFalse);
    await app.regenerateIdentity();
    await first;
    final last = _bundle(await makePreKeyBundleB64());
    final lastKey = IdentityKey.fromBytes(
      base64Decode(last['identityKey'] as String),
      0,
    );
    expect(_hex(lastKey.publicKey.serialize().sublist(1)), e.myXPubkey());
    expect(live.saved, hasLength(2));
  });
}
