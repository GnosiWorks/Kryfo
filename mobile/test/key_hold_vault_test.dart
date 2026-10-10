// SPDX-License-Identifier: GPL-3.0-or-later
// a hold no race and no container switch lifts. a mark lands only on the
// key still held once it is written; a key the everyday side cannot read
// holds; a shut vault's card holds as its row would; a decoy session never
// judges the everyday seal; a hidden chat's changed key waits for its vault
// and shows nowhere else; held members are passed by in a group's owed
// sends. real libsignal over rows kept in maps
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/group_media_send.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        kKeyUnread,
        keyHeldIn,
        keySourceFor,
        makePreKeyBundleB64,
        markVerified,
        processPeerBundle,
        session,
        signalDecrypt,
        useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart' show onPeerKeyMismatch;
import 'package:kryfo/vault_life.dart' show ChatRef, hiddenCard;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'
    show ConflictAlgorithm, Database;

import 'arrival_fakes.dart' show ArrivalSeal, ArrivalStore;
import 'mem_db.dart';
import 'source_body.dart';
import 'sqlite_ffi.dart';

const _peer = 'calm-orbit-lantern';
final _keyA = List<int>.generate(32, (i) => i + 1);
final _keyB = List<int>.generate(32, (i) => 200 - i);
String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<void> _contact(MemDb db, String id, {String xpub = '', String? mark}) =>
    db.insert('contacts', {
      'halo_id': id,
      'onion': '',
      'xpub': xpub,
      'first_seen': 1,
      'last_seen': 1,
      'back_paired': 1,
      'accepted': 1,
      if (mark != null) ...{'verified': 1, 'verified_key': mark},
    });

Future<void> _identity(MemDb db, String id, List<int> key) async {
  await db.delete('peer_identities', where: 'address = ?', whereArgs: [id]);
  await db.insert('peer_identities', {
    'address': id,
    'identity_key': Uint8List.fromList([5, ...key]),
  });
}

// their new key lands between the read and the mark, written as the signal
// store writes it
class _Racing extends MemDb {
  var fired = false;
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!fired && table == 'contacts' && values['verified'] == 1) {
      fired = true;
      await _identity(this, _peer, _keyB);
      await super.update(
        'contacts',
        {'key_changed': 1, 'verified': 0},
        where: 'halo_id = ?',
        whereArgs: [_peer],
      );
    }
    return super.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }
}

// an everyday database a restore just put another file in place of
class _Gone extends HaloDb {
  @override
  Future<Database> open() async => throw StateError('everyday.db replaced');
}

// the app's rows over maps. the lists' own queries are not this test's
class _Rows extends HaloDb {
  _Rows(this.mem, [super.container = HaloContainer.everyday]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => const {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async => const [];
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> blockedRows({required int now}) async =>
      const [];
}

class _Io extends AppIo {
  @override
  Future<String> relaySend(String xPub, String cipher) async => 'ok';
  @override
  Future<String> onionSend(String onion, String cipher) async => 'error: off';
  @override
  void listen(String xPub) {}
  @override
  void unlisten(String xPub) {}
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    String? msgUid,
    int? burnAt,
  }) async {}
  @override
  Future<void> unnotifyMessage(String msgUid) async {}
  @override
  Future<void> unnotify(String payload) async {}
}

typedef _Peer = ({SignalSession ss, String name, String xpub, String card});

var _n = 0;

// a phone with a signal identity of its own. [name]: the same person on a
// new install
Future<_Peer> _phone({String? name}) async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  final x = pair.publicKey.serialize().sublist(1);
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: x,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (
    ss: ss,
    name: name ?? 'amber-river-${_n++}',
    xpub: _hex(x),
    card: await makePreKeyBundleB64(ss),
  );
}

// a text from [p] to this phone, on a session started from this phone's card
Future<String> _opener(_Peer p, String text) async {
  await SessionBuilder(
    p.ss.sessionStore,
    p.ss.preKeyStore,
    p.ss.signedPreKeyStore,
    p.ss.identityStore,
    SignalProtocolAddress('me', 1),
  ).processPreKeyBundle(preKeyBundleOf(await makePreKeyBundleB64()));
  return p.ss.encryptTo('me', text);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

// what group owed sends read and write
class _Owed implements GroupOwedStore {
  _Owed(this.due);
  final List<GroupOwed> due;
  final tried = <String>[];
  @override
  Future<List<GroupOwed>> dueGroupOwed(int now) async => due;
  @override
  Future<void> triedGroupOwed(
    String msgUid,
    Iterable<String> members,
    int now,
  ) async => tried.addAll(members);
  @override
  Future<void> dropGroupOwed(String msgUid) async {}
}

GroupOwed _owed(String member) => GroupOwed(
  msgUid: 'u1',
  groupId: 'g1',
  member: member,
  total: 1,
  have: const {},
  since: 1,
  tries: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // this phone's signal store and its everyday rows: one database, as on
  // a phone
  final store = MemDb();
  late _Rows rows;
  late AppState app;
  late VaultRouter router;
  late ArrivalStore vaultList;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: store,
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    rows = _Rows(store);
    useDatabasesForTest(rows, Session(rows));
    vaultList = ArrivalStore();
    router = VaultRouter(vaultList, ArrivalSeal());
    await router.load();
    app = AppState(io: _Io(), router: router)..myId = 'me';
  });

  // a hidden chat with [id], its card on the router's list
  Future<void> hide(String id, String xpub, {String? mark}) async {
    await vaultList.putMeta('pub', 'pub-A');
    await vaultList.putHidden(
      id,
      kHiddenPeer,
      peerCard(RouterCard(id, '', xpub, verifiedKey: mark)),
      1,
    );
    await router.load();
  }

  group('a mark', () {
    test('is not left on a key that moved while it was written', () async {
      final db = _Racing();
      await _contact(db, _peer);
      await _identity(db, _peer, _keyA);
      expect(await markVerified(db, _peer, true, key: _hex(_keyA)), isFalse);
      final row = db.rows('contacts').single;
      expect(row['key_changed'], 1);
      expect(row['verified'], 0);
      // the mark names the key on screen, which they no longer hold
      expect(await keyHeldIn(db, _peer), isTrue);
    });

    test('nor in a hidden chat, whose key the everyday side holds', () async {
      final vault = MemDb();
      await _contact(vault, _peer, xpub: _hex(_keyA));
      var reads = 0;
      Future<String?> everyday(String id) async =>
          _hex(reads++ == 0 ? _keyA : _keyB);
      expect(
        await markVerified(
          vault,
          _peer,
          true,
          key: _hex(_keyA),
          identity: everyday,
        ),
        isFalse,
      );
      expect(vault.rows('contacts').single['key_changed'], 1);
      expect(await keyHeldIn(vault, _peer, identity: everyday), isTrue);
    });

    test('lands when the key stays', () async {
      final db = MemDb();
      await _contact(db, _peer);
      await _identity(db, _peer, _keyA);
      expect(await markVerified(db, _peer, true, key: _hex(_keyA)), isTrue);
      expect(db.rows('contacts').single['verified'], 1);
      expect(await keyHeldIn(db, _peer), isFalse);
    });
  });

  test('a hidden chat\'s key read while the everyday side is replaced '
      'matches no mark, and throws nothing', () async {
    useDatabasesForTest(_Gone(), Session(_Gone()));
    final read = keySourceFor(HaloContainer.vault)!;
    expect(await read(_peer), kKeyUnread);
    // verified under the card's key, which is all the vault holds
    final vault = MemDb();
    await _contact(vault, _peer, xpub: _hex(_keyA), mark: _hex(_keyA));
    expect(await keyHeldIn(vault, _peer, identity: read), isTrue);
    expect(
      await markVerified(vault, _peer, true, key: _hex(_keyA), identity: read),
      isFalse,
    );
    // and no number is shown for it
    expect(await _Rows(vault, HaloContainer.vault).heldKey(_peer), isNull);
  });

  group('a shut vault', () {
    test('holds its contact verified under another key', () async {
      const id = 'shut-held-one';
      await _identity(store, id, _keyB);
      await hide(id, _hex(_keyA), mark: _hex(_keyA));
      expect(await app.keyHeld(id, strict: true), isTrue);
      expect(await app.keyHeld(id), isTrue);
    });

    test('lets one through verified under the key held, or never '
        'verified', () async {
      const same = 'shut-same-key';
      const never = 'shut-never-verified';
      await _identity(store, same, _keyB);
      await _identity(store, never, _keyB);
      await hide(same, _hex(_keyA), mark: _hex(_keyB));
      await hide(never, _hex(_keyA));
      expect(await app.keyHeld(same, strict: true), isFalse);
      expect(await app.keyHeld(never, strict: true), isFalse);
    });

    test(
      "keeps the mark on the card it makes of a hidden chat's rows",
      () async {
        final db = SqliteMem.open()!;
        await db.execute("ATTACH DATABASE ':memory:' AS v");
        await db.execute('CREATE TABLE main.contacts (halo_id TEXT)');
        await db.execute(
          'CREATE TABLE v.contacts (halo_id TEXT, onion TEXT, xpub TEXT, '
          'back_paired INTEGER, blocked INTEGER, verified_key TEXT)',
        );
        await db.execute(
          'CREATE TABLE v.group_members (group_id TEXT, halo_id TEXT)',
        );
        await db.execute(
          "INSERT INTO v.contacts VALUES ('$_peer', 'o', 'x', 1, 0, "
          "'${_hex(_keyA)}'), ('member-two', 'o', 'y', 0, 0, NULL)",
        );
        await db.execute(
          "INSERT INTO v.group_members VALUES ('g1', '$_peer'), "
          "('g1', 'member-two')",
        );
        final one = RouterCard.fromJson(
          jsonDecode((await hiddenCard(db, const ChatRef(_peer)))!),
        )!;
        expect(one.verifiedKey, _hex(_keyA));
        final group = jsonDecode(
          (await hiddenCard(db, const ChatRef('g1', group: true)))!,
        );
        final members = [
          for (final m in (group as Map)['m'] as List) RouterCard.fromJson(m)!,
        ];
        expect(
          {for (final m in members) m.id: m.verifiedKey},
          {_peer: _hex(_keyA), 'member-two': null},
        );
      },
      skip: SqliteMem.open() == null ? 'no sqlite on this host' : null,
    );
  });

  test('a decoy session open never lets the everyday seal through', () async {
    const id = 'everyday-held';
    await _contact(store, id, mark: _hex(_keyA));
    await _identity(store, id, _keyB);
    final decoy = _Rows(MemDb(), HaloContainer.decoy);
    useDatabasesForTest(rows, Session(decoy));
    expect(await app.keyHeld(id, strict: true), isTrue);
    // nor an open vault's
    final vmem = MemDb();
    await _contact(vmem, 'hidden-held', mark: _hex(_keyA));
    await _identity(store, 'hidden-held', _keyB);
    final vault = _Rows(vmem, HaloContainer.vault);
    useDatabasesForTest(rows, await Session.withVault(rows, vault));
    expect(await app.keyHeld('hidden-held', strict: true), isTrue);
    expect(await app.keyHeld(id, strict: true), isTrue);
  });

  group('a hidden chat whose key changes', () {
    late _Peer bob;
    setUp(() async {
      onPeerKeyMismatch = (p) => unawaited(app.flagKeyChanged(p));
      bob = await _phone();
      // paired: this phone holds their first key
      await processPeerBundle(bob.name, bob.card);
    });
    tearDown(() => onPeerKeyMismatch = null);

    Future<_Rows> vaultWithBob() async {
      final vmem = MemDb();
      await _contact(vmem, bob.name, xpub: bob.xpub);
      return _Rows(vmem, HaloContainer.vault);
    }

    test('while its vault is shut shows it as the vault opens, and the '
        'everyday side never', () async {
      await hide(bob.name, bob.xpub);
      // a new install under the same name
      final again = await _phone(name: bob.name);
      final wire = await _opener(again, 'new phone');
      expect(
        await signalDecrypt(bob.name, wire, flagKeyChange: true),
        'new phone',
      );
      await _settle();
      expect(
        store.rows('contacts').where((r) => r['halo_id'] == bob.name),
        isEmpty,
      );
      expect(vaultList.inbox, hasLength(1));
      final vault = await vaultWithBob();
      useDatabasesForTest(rows, await Session.withVault(rows, vault));
      await app.drainSealed(vault, 'priv-A');
      expect(vault.mem.rows('contacts').single['key_changed'], 1);
      expect(await session.keyChanged(bob.name), isTrue);
      expect(vaultList.inbox, isEmpty);
    });

    test('while its vault is open shows it there', () async {
      await hide(bob.name, bob.xpub);
      final vault = await vaultWithBob();
      useDatabasesForTest(rows, await Session.withVault(rows, vault));
      final again = await _phone(name: bob.name);
      final wire = await _opener(again, 'new phone');
      expect(
        await signalDecrypt(bob.name, wire, flagKeyChange: true),
        'new phone',
      );
      await _settle();
      expect(vault.mem.rows('contacts').single['key_changed'], 1);
      expect(
        store.rows('contacts').where((r) => r['halo_id'] == bob.name),
        isEmpty,
      );
      expect(vaultList.inbox, isEmpty);
    });
  });

  test('the store and the open both route a changed key by its owner', () {
    final src = sourceOf('lib/main.dart');
    expect(
      src,
      contains(
        'onPeerKeyMismatch = (peer) => unawaited(appState.flagKeyChanged(peer));',
      ),
    );
    final open = bodyOf(src, 'Future<String?> signalDecrypt(');
    expect(open, contains('appState.flagKeyChanged(peerId)'));
    expect(open, isNot(contains('live.setKeyChanged')));
  });

  group('a group\'s owed sends', () {
    test('pass a held member by, using none of their tries', () async {
      final store = _Owed([_owed('held-one'), _owed('free-one')]);
      final sent = <String>[];
      await resendGroupOwed(
        store,
        now: 1,
        send: (uid, g, have, total) async {
          sent.addAll(have.keys);
          return 'ok';
        },
        held: (m) async => m == 'held-one',
      );
      expect(store.tried, ['free-one']);
      expect(sent, ['free-one']);
    });

    test('ask the app who is held', () {
      final round = bodyOf(
        sourceOf('lib/main.dart'),
        'Future<void> _owedRound(',
      );
      expect(round, contains('held: keyHeld'));
    });
  });
}
