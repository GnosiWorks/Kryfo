// SPDX-License-Identifier: GPL-3.0-or-later
// a new identity asked for during setup takes everything made from the key
// with it: the invite's signal identity and signed prekey, its invite
// prekey and the first-contact address listened on, the v4 invites the old
// key signed, and a second ask while one runs makes no third key. real
// libsignal over rows kept in maps; the engine hands out keys the way it
// does on a phone
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/identities.dart' show kMainIdent;
import 'package:kryfo/invites.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        HaloEngine,
        makePreKeyBundleB64,
        useDatabasesForTest,
        useEngineForTest,
        v4OfLink,
        AppStateProfile,
        AppStateIdentity,
        AppStateInvites,
        AppStateSession;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart' show LsInvite;
import 'package:kryfo/signal_session.dart' show preKeySigned, signalSession;
import 'package:kryfo/signal_stores.dart' show invitePreKeyId;
import 'signal_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

final _p = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

// the engine's public half of a first-contact key, stood in: a key that
// lifts, or an error as the engine gives one
String _fcPkOf(Uint8List sk) {
  final x = sha256.convert(sk).bytes;
  final v = BigInt.parse(_hex(x), radix: 16);
  if (v >= _p) return 'error: not a key';
  final a = (v.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
  final y = a.modPow((_p + BigInt.one) >> 2, _p);
  return y.modPow(BigInt.two, _p) == a ? _hex(x) : 'error: not a key';
}

const _b32 = 'abcdefghijklmnopqrstuvwxyz234567';

// an onion address for a key, in the shape onionKeyOf reads back
String _onionOf(List<int> key) {
  final b = [...key, 0, 0, 3];
  var acc = 0, bits = 0;
  final out = StringBuffer();
  for (final x in b) {
    acc = (acc << 8) | x;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_b32[(acc >> bits) & 31]);
    }
  }
  return '$out.onion';
}

final _onionKey = ed
    .public(ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 12))))
    .bytes;

class _Engine implements HaloEngine {
  _Engine() {
    _next();
  }
  late TestKeyPair pair;
  // the identity's ed key, made with its x key
  late ed.PrivateKey face;
  var _made = 0;
  var id = 'first-words-here';
  final listened = <int>[];
  final unsubscribed = <String>[];

  void _next() {
    pair = testKeyPair();
    face = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 40 + _made++)));
  }

  @override
  String myEdPubkey() => _hex(ed.public(face).bytes);
  // only a face text of the key it holds, as the engine signs (faceSign)
  @override
  String faceSign(String msgHex) {
    final m = _unhex(msgHex);
    final x = _hex(m.sublist(m.length - 16 - 32, m.length - 16));
    return x == myXPubkey() ? _hex(ed.sign(face, m)) : 'error: not the key';
  }

  @override
  String onionOfKey(String keyHex) => _onionOf(_unhex(keyHex));
  @override
  String fcKeyPk(String skHex) => _fcPkOf(_unhex(skHex));
  @override
  Future<String> subscribeFcKey(int ident, String id, String sk) async => 'ok';
  @override
  Future<String> unsubscribeFcKey(int ident, String id) async {
    unsubscribed.add(id);
    return 'ok';
  }

  @override
  String generateIdentity() {
    _next();
    return id = 'second-words-now';
  }

  @override
  String myXPubkey() => _hex(pair.publicKey.serialize().sublist(1));
  // how often a private key was pulled back out
  var pulls = 0;
  @override
  String myXPrivkey() {
    pulls++;
    return _hex(pair.privateKey.serialize());
  }

  @override
  String myEdPrivkey() {
    pulls++;
    return 'ed';
  }

  @override
  Future<String> subscribeFirstContact(int ident, int counter) async {
    listened.add(counter);
    return 'ok';
  }

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
  var keptGone = 0;
  @override
  Future<void> forgetAllFirst() async => keptGone++;
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
    final oldInvite = await signalSession.preKeyStore.load(invitePreKeyId);

    e.pulls = 0;
    await app.regenerateIdentity();

    expect(live.saved, ['second-words-now']);
    // the keys come out once, as they are made: signal and a backup take
    // the copy held then, never the engine's again
    expect(e.pulls, 2);
    expect(app.mainKeysForBackup.x, _hex(e.pair.privateKey.serialize()));
    expect(e.pulls, 2);
    // a restore that lands after this leaves no key of the old one to back up
    app.mainKeysReplaced();
    expect(() => app.mainKeysForBackup, throwsStateError);
    // openers kept for the old key open no more
    expect(live.keptGone, 1);
    final now = _bundle(await makePreKeyBundleB64());
    // the invite names the key every envelope is now sent under
    final key = base64Decode(now['identityKey'] as String);
    expect(_hex(key.sublist(1)), e.myXPubkey());
    expect(now['identityKey'], isNot(before['identityKey']));
    expect(
      preKeySigned(
        key,
        base64Decode(now['signedPreKeyPublic'] as String),
        base64Decode(now['signedPreKeySignature'] as String),
      ),
      isTrue,
    );
    // the invite's kyber prekey is made again under the new key too
    expect(
      preKeySigned(
        key,
        base64Decode(now['kyberPreKeyPublic'] as String),
        base64Decode(now['kyberPreKeySignature'] as String),
      ),
      isTrue,
    );
    expect(now['kyberPreKeyPublic'], isNot(before['kyberPreKeyPublic']));
    final invite = await signalSession.preKeyStore.load(invitePreKeyId);
    expect(invite, isNot(oldInvite));
    // the address of the new key is the one listened on
    expect(e.listened, [0, 0]);

    // a second tap while signal is still being made again changes nothing:
    // signal ends on the key the engine holds
    final first = app.regenerateIdentity();
    await app.regenerateIdentity();
    await first;
    final last = _bundle(await makePreKeyBundleB64());
    final lastKey = base64Decode(last['identityKey'] as String);
    expect(_hex(lastKey.sublist(1)), e.myXPubkey());
    expect(live.saved, hasLength(2));
  });

  test(
    'a new identity during setup takes the v4 invites the old key signed '
    'with it: the link, the qr and a handle claim carry the new key',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final e = _Engine();
      useEngineForTest(e);
      final db = MemDb();
      final live = _Live(db);
      useDatabasesForTest(live, Session(live));
      // signal is one for the whole file: the test before left it ready on
      // its key, so it is made again on this engine's
      await signalSession.rekey(
        database: db,
        xPubBytes: _unhex(e.myXPubkey()),
        xPrivBytes: _unhex(e.myXPrivkey()),
      );
      final app = AppState(
        io: const AppIo(),
        router: VaultRouter(ArrivalStore(), ArrivalSeal()),
      )..myId = e.id;
      app.myOnion = _onionOf(_onionKey);
      // the start's upkeep once the onion is there: the main invite
      await app.keepMyInvites();
      final first = (await currentMainInvite(db, kMainIdent))!;
      final firstEd = e.myEdPubkey();
      final was = v4OfLink(await app.sessionInvite()) as LsInvite;
      expect(_hex(was.face!), firstEd);
      final once = await makeInvite(
        db,
        signalSession,
        kind: kInviteOneTime,
        fcPkOf: _fcPkOf,
      );

      await app.regenerateIdentity();

      expect(e.myEdPubkey(), isNot(firstEd));
      // what a claim, the share sheet and the qr hand out names the key that
      // signs now: the registry takes a v4 invite only from its face
      final now = v4OfLink(await app.sessionInvite()) as LsInvite;
      expect(_hex(now.face!), e.myEdPubkey());
      expect(_hex(now.identity.sublist(1)), e.myXPubkey());
      final qr = v4OfLink(await app.sessionInviteQr()) as LsInvite;
      expect(_hex(qr.face!), e.myEdPubkey());
      // every invite of the old key went with its address
      expect(await inviteOf(db, kMainIdent, first.id), isNull);
      expect(await inviteOf(db, kMainIdent, once.id), isNull);
      expect(e.unsubscribed, containsAll([first.id, once.id]));
      for (final r in await invitesOf(db, kMainIdent)) {
        final inv = signalSession.lib.parseInvite(r.link);
        expect(_hex(inv.identity.sublist(1)), e.myXPubkey());
      }
      // and the new one's keys are held
      final main = (await currentMainInvite(db, kMainIdent))!;
      expect(
        await signalSession.signedPreKeyStore.contains(main.spkId!),
        isTrue,
      );
    },
  );
}
