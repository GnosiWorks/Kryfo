// SPDX-License-Identifier: GPL-3.0-or-later
// makes the 0.5.3 files the identity upgrade test opens. it runs inside a
// 0.5.3 checkout (make_053.sh <checkout>), so the schema, every row and
// every signal session come from 0.5.3's own code: halo.db, everyday;
// halo_d.db, a second identity it holds a session with; halo_v.db, hidden
// chats; peers.db, the far side of the other sessions; expected.json, what
// 0.5.3 shows and what is still on the way. throwaway test keys only
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database, openDatabase;

import 'sqlite_channel.dart';

const me = 'quiet-maple-harbor';
const alice = 'amber-otter-lake';
const bob = 'brisk-cedar-moon';
const carol = 'coral-finch-dune';
const dave = 'dusty-heron-vale';
const erin = 'ember-larch-cove';
const frank = 'frost-wren-glade';
const zed = 'zinc-quail-shore';
const hush = 'hush-pine-rill';
final everydayKey = '0e' * 32;
final decoyKey = "x'${'0d' * 32}'";
final vaultKey = '1f' * 32;
const gid = 'g0a1b2c3d4e5f60718293a4b5c6d7e8f9';
const rid = 'r0f1e2d3c4b5a69788796a5b4c3d2e1f0';
// far ahead: no sweep in either version takes these
const later = 4102444800000;

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

class _Engine implements HaloEngine {
  bool on = false;
  @override
  String setBridges(String lines, bool on) {
    this.on = on;
    return 'ok';
  }

  @override
  String bridgeState() => '$on|';

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

({Uint8List pub, Uint8List priv}) x25519() {
  final k = Curve.generateKeyPair();
  return (
    pub: Uint8List.fromList(k.publicKey.serialize().sublist(1)),
    priv: Uint8List.fromList(k.privateKey.serialize()),
  );
}

Future<SignalSession> store(
  Database db,
  ({Uint8List pub, Uint8List priv}) k,
) async {
  final s = SignalSession();
  await s.bootstrap(database: db, xPubBytes: k.pub, xPrivBytes: k.priv);
  return s;
}

Future<String> open(SignalSession s, String from, String wire) async {
  final raw = base64Decode(wire);
  final body = Uint8List.fromList(raw.sublist(1));
  final c = SessionCipher(
    s.sessionStore,
    s.preKeyStore,
    s.signedPreKeyStore,
    s.identityStore,
    SignalProtocolAddress(from, 1),
  );
  final plain = raw[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

Future<Map<String, String>> settings() async {
  final out = Map.of(await secureStore.readAll());
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys()) {
    out['prefs:$k'] = jsonEncode(prefs.get(k));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['UPGRADE_OUT'] ?? '';
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory docs;
  late SqliteChannel sql;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('make_053');
    // fixed test keys, which no secret scanner takes for real ones
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': everydayKey,
      'halo.d.key': decoyKey,
    });
    SharedPreferences.setMockInitialValues({});
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    sql = SqliteChannel.install()!;
    useEngineForTest(_Engine());
  });

  tearDown(() => sql.uninstall());

  test('the databases', () async {
    expect(out, isNotEmpty, reason: 'UPGRADE_OUT names where they go');
    final db = HaloDb();
    final raw = await db.open();
    final other = HaloDb(HaloContainer.decoy);
    final otherRaw = await other.open();

    // the far sides of the sessions below, each a store of its own under a
    // prefix, with the tables 0.5.3 gives a store
    final peers = await openDatabase(p.join(docs.path, 'peers.db'));
    // the columns of contacts the stores read and mark
    await peers.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, verified INTEGER '
      'NOT NULL DEFAULT 0, verified_key TEXT, key_changed INTEGER NOT NULL '
      'DEFAULT 0)',
    );
    for (final pre in ['bob_', 'stranger_', 'dave_']) {
      for (final t in [
        'prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL)',
        'signed_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, '
            'created_at INTEGER NOT NULL)',
        'sessions (address TEXT NOT NULL, device_id INTEGER NOT NULL, '
            'record BLOB NOT NULL, PRIMARY KEY (address, device_id))',
        'peer_identities (address TEXT PRIMARY KEY, identity_key BLOB '
            'NOT NULL)',
        'signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
      ]) {
        await peers.execute('CREATE TABLE $pre$t');
      }
    }

    // me, everyday; alice, the second identity of this phone
    final mine = x25519();
    final hers = x25519();
    final myEd = hex(x25519().priv);
    final herEd = hex(x25519().priv);
    await db.saveIdentity(me, myEd, hex(mine.priv));
    await other.saveIdentity(alice, herEd, hex(hers.priv));
    final ss = await store(raw, mine);
    final theirs = await store(otherRaw, hers);
    final bobK = x25519();
    final strangerK = x25519();
    final daveK = x25519();
    Future<SignalSession> peer(
      String pre,
      ({Uint8List pub, Uint8List priv}) k,
    ) async {
      final s = SignalSession();
      await s.bootstrap(
        database: peers,
        xPubBytes: k.pub,
        xPrivBytes: k.priv,
        prefix: pre,
      );
      return s;
    }

    final bobS = await peer('bob_', bobK);
    final strangerS = await peer('stranger_', strangerK);
    final daveS = await peer('dave_', daveK);

    // alice: opened from her card, answered, both ways a few times
    await processPeerBundle(alice, await makePreKeyBundleB64(theirs), into: ss);
    final first = await ss.encryptTo(alice, 'hello from 0.5.3');
    expect(await open(theirs, me, first), 'hello from 0.5.3');
    for (var i = 0; i < 3; i++) {
      final back = await theirs.encryptTo(me, 'back $i');
      expect(await open(ss, alice, back), 'back $i');
      final on = await ss.encryptTo(alice, 'on $i');
      expect(await open(theirs, me, on), 'on $i');
    }
    // bob opened to me from my card: here the answering side
    await processPeerBundle(me, await makePreKeyBundleB64(ss), into: bobS);
    final fromBob = await bobS.encryptTo(me, 'hi, bob here');
    expect(await open(ss, bob, fromBob), 'hi, bob here');
    final toBob = await ss.encryptTo(bob, 'hi bob');
    expect(await open(bobS, me, toBob), 'hi bob');
    // and one each way still on the relay when the phone updates
    final bobInFlight = await bobS.encryptTo(me, 'sent before the update');
    final meInFlight = await ss.encryptTo(bob, 'also before the update');
    // dave: opened from his card, never answered, the opener not yet read
    await processPeerBundle(dave, await makePreKeyBundleB64(daveS), into: ss);
    final toDave = await ss.encryptTo(dave, 'are you there, dave');
    // someone not yet a contact: an opener to me on its way, from my card
    await processPeerBundle(me, await makePreKeyBundleB64(ss), into: strangerS);
    final strangerOpener = await strangerS.encryptTo(
      me,
      'hello, we met at the station',
    );
    await peers.close();

    // contacts, each in a state 0.5.3 could leave it in
    await db.upsertContact(alice, 'alice.onion', hex(hers.pub));
    await db.setVerified(alice, true, key: hex(hers.pub));
    await db.setNickname(alice, 'Alice');
    await db.setPeerBundle(alice, await makePreKeyBundleB64(theirs));
    await db.markBackPaired(alice);
    await db.upsertContact(bob, 'bob.onion', hex(bobK.pub));
    await db.setVerified(bob, true);
    await db.setMuted(bob, true);
    await db.upsertContact(carol, 'carol.onion', hex(x25519().pub));
    await db.setBlocked(carol, true);
    await db.noteBlockedDrop(carol, 'carol-dropped-1');
    await db.upsertContact(dave, 'dave.onion', hex(daveK.pub), accepted: 0);
    await db.holdCipher(dave, 'sealed-for-later-1');
    await db.holdCipher(dave, 'sealed-for-later-2');
    await db.upsertContact(erin, 'erin.onion', hex(x25519().pub));
    await db.setArchived(erin, true);
    await db.setNote(erin, 'met at the station');
    await db.setContactPinned(erin, true);
    await db.setAtmosphere(erin, 'dusk');
    await db.setContactAvatar(erin, 5);
    await db.setContactBadge(erin, 'gold');
    await db.bumpUnread(erin);
    await db.bumpUnread(erin);
    await db.upsertContact(
      frank,
      'frank.onion',
      hex(x25519().pub),
      accepted: 0,
    );
    await db.addVouch(frank, alice, 'my cousin');
    await db.setShield(frank, 'stranger', [
      {'code': 'new_contact'},
    ]);
    // verified once, and nothing left to say under which key
    await db.upsertContact(zed, 'zed.onion', '');
    await db.setVerified(zed, true);

    // a 1:1 thread with everything a message can carry
    await db.saveMessage(alice, 'out', 'first words', msgUid: 'a-1');
    await db.saveMessage(alice, 'in', 'hello back', msgUid: 'a-2');
    await db.saveMessage(
      alice,
      'out',
      'a reply',
      msgUid: 'a-3',
      replyTo: 'a-2',
    );
    await db.editMessage('a-3', 'a reply, edited');
    await db.queueEdit('a-3', alice, 'a reply, edited');
    await db.setPinned('a-1', true, at: 1700000000000);
    await db.queuePin('a-1', alice, true);
    await db.addReaction('a-2', me, '👍');
    await db.addReaction('a-1', alice, '❤');
    await db.queueFrame('a-2', kFrameReaction, alice, '{"e":"👍"}');
    await db.saveMessage(
      alice,
      'out',
      'burns later',
      msgUid: 'a-4',
      burnAt: later,
      burnSecs: 30,
    );
    await db.saveMessage(alice, 'out', 'not sent yet', msgUid: 'a-5', sent: 0);
    await db.saveMessage(
      alice,
      'in',
      '',
      msgUid: 'a-6',
      mediaPath: p.join(docs.path, 'media', 'a-6.jpg'),
      preview: 'photo',
    );
    await db.saveMessage(
      alice,
      'in',
      '',
      msgUid: 'a-7',
      filePath: p.join(docs.path, 'files', 'notes.pdf'),
      fileName: 'notes.pdf',
      saved: true,
    );
    await db.saveMessage(
      alice,
      'out',
      '',
      msgUid: 'a-8',
      mediaPath: p.join(docs.path, 'media', 'voice.wav'),
      fileName: 'voice.wav',
      voiceDisguised: true,
    );
    await db.saveMessage(alice, 'in', '🦊', msgUid: 'a-9', sticker: 'fokia/3');
    await db.saveMessage(
      alice,
      'out',
      'Lunch?',
      msgUid: 'a-10',
      poll: const PollSpec(options: ['Noon', 'One'], multi: true).toRow(),
      secure: true,
    );
    await db.putPollVote('a-10', alice, null, [0, 1], 1);
    await db.putPollVote('a-10', me, null, [1], 1);
    await db.markDelivered('a-1', from: alice);
    await db.setSaved('a-2', true);
    await db.markSeen('hash-of-a-2');
    await db.saveMessage(bob, 'in', 'hi from bob', msgUid: 'b-1');
    await db.saveMessage(erin, 'in', 'archived but here', msgUid: 'e-1');
    await db.saveMessage(carol, 'in', 'before the block', msgUid: 'c-1');

    // a group, its thread, a poll and what it still owes
    await db.createGroup(gid, 'Climbing', [me, alice, bob], isAdmin: true);
    await db.setGroupAtmosphere(gid, 'forest');
    await db.saveMessage(me, 'out', 'rope check', msgUid: 'g-1', groupId: gid);
    await db.saveMessage(alice, 'in', 'done', msgUid: 'g-2', groupId: gid);
    await db.saveMessage(
      me,
      'out',
      'Saturday?',
      msgUid: 'g-3',
      groupId: gid,
      poll: const PollSpec(options: ['Yes', 'No']).toRow(),
    );
    await db.putPollVote('g-3', bob, gid, [0], 1);
    await db.setPinned('g-2', true, at: 1700000001000);
    await db.bumpGroupUnread(gid);
    await db.setGroupMentioned(gid);
    await db.queueGroupCtl(
      gid,
      [bob],
      const GroupControl(type: 'rename', name: 'Climbing'),
      now: 1700000002000,
    );

    // a room, joined and seen
    await db.createRoom(
      groupId: rid,
      name: 'Night shift',
      priv: hex(List.filled(32, 3)),
      pub: hex(List.filled(32, 4)),
      expiresAt: later,
      creatorPub: hex(List.filled(32, 4)),
      fcPk: hex(List.filled(32, 5)),
      cap: 12,
      members: [me, hex(List.filled(32, 6))],
    );
    await db.saveMessage(
      hex(List.filled(32, 6)),
      'in',
      'anyone up?',
      msgUid: 'r-1',
      groupId: rid,
    );
    await db.markRoomSeen(rid);

    // a file coming in, slice by slice, and what is still wanted of it
    await db.putMediaChunk('m-1', 0, 'c2xpY2Ux', 3, null, from: alice);
    await db.putMediaChunk('m-1', 2, 'c2xpY2Uz', 3, null, from: alice);
    await db.noteMediaWant('m-1', alice, 3, true);

    // the dev chat, started from the everyday name
    final dev = DevChat(db.open, shred: (_) async {});
    final key = currentDevKey!;
    expect(await dev.begin(key), isTrue);
    await db.saveMessage(key.chatId, 'out', 'hi Marios', msgUid: 'd-1');
    await db.saveMessage(key.chatId, 'in', 'hi, thanks', msgUid: 'd-2');

    // a hidden chat's entry and a sealed arrival waiting for the vault
    final router = SqlRouterStore(db.open);
    await router.putHidden(
      hush,
      'peer',
      '{"h":"hush-pine-rill"}',
      1700000003000,
    );
    await router.inboxAdd(
      'v-1',
      null,
      Uint8List.fromList([0, 1, 2, 250, 251, 252]),
      1700000004000,
    );

    // what 0.5.1 added: an accept still owed, a checked name, a chat's own
    // voice choice and a ring
    await db.setAckOwed(bob, true);
    await db.setNameCheck(bob, 1);
    await db.setVoiceDisguise(alice, true);
    await db.setVoiceDisguise(gid, false, group: true);
    await db.noteRing(41, alice, 'a-2');

    await db.fillSearchIndex();
    await db.close();
    await other.close();

    // the hidden chats' file, under the key its pin entry wraps
    final vault = HaloDb.withKey(HaloContainer.vault, vaultKey);
    await vault.open();
    await vault.upsertContact(hush, 'hush.onion', hex(x25519().pub));
    await vault.setVerified(hush, true);
    await vault.saveMessage(hush, 'in', 'only here', msgUid: 'h-1');
    await vault.saveMessage(
      hush,
      'out',
      'and back',
      msgUid: 'h-2',
      burnAt: later,
      burnSecs: 60,
    );
    await vault.close();

    final dir = Directory(out)..createSync(recursive: true);
    for (final f in ['halo.db', 'halo_d.db', 'halo_v.db', 'peers.db']) {
      File(p.join(docs.path, f)).copySync(p.join(dir.path, f));
    }
    final keys = await settings();
    File(p.join(dir.path, 'keys.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'everyday': keys['halo.db.passphrase'],
        'decoy': keys['halo.d.key'],
        'vault': vaultKey,
      }),
    );
    // what 0.5.3 showed for each contact, and the keys behind it
    final myPub = hex(mine.pub);
    final contactKeys = {
      alice: hex(hers.pub),
      bob: hex(bobK.pub),
      dave: hex(daveK.pub),
    };
    File(p.join(dir.path, 'expected.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'version': 85,
        'me': {
          'id': me,
          'ed_priv': myEd,
          'x_priv': hex(mine.priv),
          'x_pub': myPub,
        },
        'alice': {
          'id': alice,
          'ed_priv': herEd,
          'x_priv': hex(hers.priv),
          'x_pub': hex(hers.pub),
        },
        'peers': {
          for (final e in {
            'bob_': bobK,
            'stranger_': strangerK,
            'dave_': daveK,
          }.entries)
            e.key: {'x_priv': hex(e.value.priv), 'x_pub': hex(e.value.pub)},
        },
        'safety': {
          for (final e in contactKeys.entries)
            e.key: haloSafetyNumber(myPub, e.value),
        },
        // sealed by 0.5.3 and not yet read by the other side
        'in_flight': {
          'bob_to_me': bobInFlight,
          'me_to_bob': meInFlight,
          'me_to_dave': toDave,
          'stranger_to_me': strangerOpener,
        },
      }),
    );
  });
}
