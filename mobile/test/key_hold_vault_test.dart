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
        eraseFreedPages,
        signalEncrypt,
        wipeFreedOnce,
        kFrameReceipt,
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
import 'package:kryfo/signal_stores.dart' show invitePreKeyId;
import 'package:kryfo/vault_life.dart'
    show ChatMover, ChatRef, VaultHost, hiddenCard;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'
    show ConflictAlgorithm, Database;

import 'arrival_fakes.dart' show ArrivalSeal, ArrivalStore;
import 'mem_db.dart';
import 'sqlite_ffi.dart';

const _peer = 'calm-orbit-lantern';
final _keyA = List<int>.generate(32, (i) => i + 1);
final _keyB = List<int>.generate(32, (i) => 200 - i);
String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
List<int> _unhex(String h) => [
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
];

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

// this phone's signal store, with a look at what is written as it is
class _Store extends MemDb {
  void Function(String table)? onInsert;
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    onInsert?.call(table);
    return super.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
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

// a database whose key reads fail, with one member owed a file
class _OwedRows extends _Rows {
  _OwedRows(super.mem);
  final due = <GroupOwed>[];
  final tried = <String>[];
  @override
  Future<bool> keyHeld(String haloId) async => throw StateError('not read');
  @override
  Future<List<GroupOwed>> dueGroupOwed(int now) async => due;
  @override
  Future<void> triedGroupOwed(
    String msgUid,
    Iterable<String> members,
    int now,
  ) async => tried.addAll(members);
  @override
  Future<Map<String, Object?>?> sentMediaRow(String uid) async => null;
  @override
  Future<void> dropGroupOwed(String msgUid) async {}
}

// the vault's cards, read off its rows as the real mover reads them
class _Mover implements ChatMover {
  _Mover(this.vault);
  final MemDb vault;
  @override
  Future<void> attach() async {}
  @override
  Future<void> detach() async {}
  @override
  Future<Map<String, (String, String)>> vaultCards() async => {
    for (final r in vault.rows('contacts'))
      r['halo_id'] as String: (
        kHiddenPeer,
        peerCard(
          RouterCard(
            r['halo_id'] as String,
            '',
            r['xpub'] as String,
            verifiedKey: r['verified_key'] as String?,
          ),
        ),
      ),
  };
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Host implements VaultHost {
  _Host(this.vault);
  final MemDb vault;
  @override
  ChatMover mover(HaloDb primary, HaloDb? vault) => _Mover(this.vault);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // this phone's signal store and its everyday rows: one database, as on
  // a phone
  final store = _Store();
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
          'CREATE TABLE v.block_spans (peer_id TEXT, from_at INTEGER, '
          'to_at INTEGER)',
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
        // a block carries when it began, an ended one nothing
        await db.execute(
          "UPDATE v.contacts SET blocked = 1 WHERE halo_id IN ('$_peer', "
          "'member-two')",
        );
        await db.execute(
          'INSERT INTO v.block_spans (peer_id, from_at, to_at) '
          "VALUES ('$_peer', 5, 9), ('$_peer', 70, NULL), "
          "('member-two', 80, NULL)",
        );
        final blocked = RouterCard.fromJson(
          jsonDecode((await hiddenCard(db, const ChatRef(_peer)))!),
        )!;
        expect(blocked.blocked, isTrue);
        expect(blocked.blockedFrom, 70);
        final seeded = jsonDecode(
          (await hiddenCard(db, const ChatRef('g1', group: true)))!,
        );
        expect(
          {
            for (final m in (seeded as Map)['m'] as List)
              RouterCard.fromJson(m)!.id: RouterCard.fromJson(m)!.blockedFrom,
          },
          {_peer: 70, 'member-two': 80},
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
      bob = await _phone();
      // paired: this phone holds their first key
      await processPeerBundle(bob.name, bob.card);
    });

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

    test('take a key that cannot be read as held, using no try', () async {
      final d = _OwedRows(store)..due.add(_owed('unread-one'));
      useDatabasesForTest(d, Session(d));
      await app.owedRoundForTest();
      expect(d.tried, isEmpty);
    });
  });

  group('a vault shutting', () {
    test('keeps no one but its own people waiting', () async {
      const id = 'closing-hidden';
      await _identity(store, id, _keyB);
      await hide(id, _hex(_keyA), mark: _hex(_keyA));
      final closing = Completer<void>();
      app.closingForTest = closing;
      // an everyday contact is read at once
      expect(
        await app
            .keyHeld('plain-everyday', strict: true)
            .timeout(const Duration(milliseconds: 200)),
        isFalse,
      );
      // a hidden one waits for the cards the close writes
      var done = false;
      final hidden = app.keyHeld(id, strict: true).then((v) {
        done = true;
        return v;
      });
      await _settle();
      expect(done, isFalse);
      closing.complete();
      app.closingForTest = null;
      expect(await hidden, isTrue);
    });
  });

  group('a card from before cards kept the mark', () {
    Future<void> oldCard(String id, List<int> paired) async {
      await vaultList.putMeta('pub', 'pub-A');
      await vaultList.putHidden(
        id,
        kHiddenPeer,
        jsonEncode({'h': id, 'o': '', 'x': _hex(paired)}),
        1,
      );
      await router.load();
    }

    test('holds once the key moved from the one it was made with', () async {
      const moved = 'old-card-moved';
      const same = 'old-card-same';
      await _identity(store, moved, _keyB);
      await _identity(store, same, _keyA);
      await oldCard(moved, _keyA);
      await oldCard(same, _keyA);
      expect(router.marksUnread, isTrue);
      expect(await app.keyHeld(moved, strict: true), isTrue);
      expect(await app.keyHeld(same, strict: true), isFalse);
    });

    test('and a card written now says what it knows', () async {
      await hide('new-card', _hex(_keyA));
      final c = router.cardOf('new-card')!;
      expect(c.markRead, isTrue);
      expect(c.verifiedKey, isNull);
    });
  });

  test('a mark set in the open vault reaches its card at once', () async {
    const id = 'refresh-on-mark';
    await _identity(store, id, _keyA);
    await hide(id, _hex(_keyA));
    final vmem = MemDb();
    await _contact(vmem, id, xpub: _hex(_keyA));
    final vault = _Rows(vmem, HaloContainer.vault);
    final withHost = AppState(io: _Io(), router: router, host: _Host(vmem))
      ..myId = 'me';
    useDatabasesForTest(rows, await Session.withVault(rows, vault));
    expect(await withHost.setVerified(id, true, key: _hex(_keyA)), isTrue);
    await _settle();
    expect(router.cardOf(id)!.verifiedKey, _hex(_keyA));
  });

  test('a mark waits for an open in their lane to land', () async {
    const id = 'lane-mark';
    await _contact(store, id);
    await _identity(store, id, _keyA);
    final gate = Completer<void>();
    final open = signalSession.serial(id, () async {
      await gate.future;
      await _identity(store, id, _keyB);
    });
    final marked = rows.setVerified(id, true, key: _hex(_keyA));
    await _settle();
    gate.complete();
    await open;
    expect(await marked, isFalse);
    final row = store.rows('contacts').singleWhere((r) => r['halo_id'] == id);
    expect(row['verified_key'], isNull);
  });

  test('a key the everyday side cannot read raises no banner', () async {
    final vault = MemDb();
    await _contact(vault, _peer, xpub: _hex(_keyA));
    var reads = 0;
    Future<String?> everyday(String id) async =>
        reads++ == 0 ? _hex(_keyA) : kKeyUnread;
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
    final row = vault.rows('contacts').single;
    expect(row['key_changed'], 0);
    expect(row['verified'], 0);
    expect(row['verified_key'], isNull);
  });

  test('a receipt for a held hidden chat waits in its vault', () async {
    const id = 'held-receipt';
    await _identity(store, id, _keyB);
    await hide(id, _hex(_keyA), mark: _hex(_keyA));
    await app.receiptForTest(id, 'uid-r1');
    expect(vaultList.inbox, hasLength(1));
    final vmem = MemDb();
    await _contact(vmem, id, xpub: _hex(_keyA), mark: _hex(_keyA));
    final vault = _Rows(vmem, HaloContainer.vault);
    useDatabasesForTest(rows, await Session.withVault(rows, vault));
    await app.drainSealed(vault, 'priv-A');
    expect(vaultList.inbox, isEmpty);
    expect(vmem.rows('frames_out').single, {
      ...vmem.rows('frames_out').single,
      'msg_uid': 'uid-r1',
      'kind': kFrameReceipt,
      'peer_id': id,
    });
  });

  test(
    'freed pages are zeroed',
    () async {
      final db = SqliteMem.open()!;
      await eraseFreedPages(db);
      final r = await db.rawQuery('PRAGMA secure_delete');
      expect(r.single.values.single.toString(), '1');
    },
    skip: SqliteMem.open() == null ? 'no sqlite on this host' : null,
  );

  group('a prekey frame', () {
    late _Peer bob;
    setUp(() async {
      bob = await _phone();
      await _contact(store, bob.name, xpub: bob.xpub, mark: bob.xpub);
      await processPeerBundle(bob.name, bob.card);
    });

    Map<String, Object?> row() =>
        store.rows('contacts').singleWhere((r) => r['halo_id'] == bob.name);
    List<int> key() =>
        (store
                    .rows('peer_identities')
                    .singleWhere(
                      (r) => r['address'] == bob.name,
                    )['identity_key']
                as List<int>)
            .sublist(1);

    test('that fails its mac after the key check changes nothing', () async {
      final again = await _phone(name: bob.name);
      final wire = base64Decode(await _opener(again, 'forged'));
      final pkm = PreKeySignalMessage(Uint8List.fromList(wire.sublist(1)));
      final inner = Uint8List.fromList(pkm.getWhisperMessage().serialize());
      inner[inner.length - 1] ^= 1;
      final bad = PreKeySignalMessage.from(
        pkm.getMessageVersion(),
        pkm.getRegistrationId(),
        pkm.getPreKeyId(),
        pkm.getSignedPreKeyId(),
        pkm.getBaseKey(),
        pkm.getIdentityKey(),
        SignalMessage.fromSerialized(inner),
      );
      final forged = base64Encode([wire[0], ...bad.serialize()]);
      expect(
        await signalDecrypt(bob.name, forged, flagKeyChange: true),
        isNull,
      );
      await _settle();
      expect(_hex(key()), bob.xpub);
      expect(row()['verified'], 1);
      expect(row()['key_changed'], 0);
      expect(await app.keyHeld(bob.name, strict: true), isFalse);
    });

    test('from a real new key raises it, once', () async {
      final again = await _phone(name: bob.name);
      expect(
        await signalDecrypt(
          bob.name,
          await _opener(again, 'new phone'),
          flagKeyChange: true,
        ),
        'new phone',
      );
      await _settle();
      expect(_hex(key()), again.xpub);
      expect(row()['key_changed'], 1);
      expect(await app.keyHeld(bob.name, strict: true), isTrue);
      // seen and put away: the next frame on the same key says nothing
      await rows.setKeyChanged(bob.name, false);
      expect(
        await signalDecrypt(
          bob.name,
          await again.ss.encryptTo('me', 'still new'),
          flagKeyChange: true,
        ),
        'still new',
      );
      await _settle();
      expect(row()['key_changed'], 0);
    });

    test(
      'that fails while their contact is accepted leaves the accept',
      () async {
        await store.update(
          'contacts',
          {'key_changed': 1},
          where: 'halo_id = ?',
          whereArgs: [bob.name],
        );
        final again = await _phone(name: bob.name);
        final wire = base64Decode(await _opener(again, 'forged'));
        final pkm = PreKeySignalMessage(Uint8List.fromList(wire.sublist(1)));
        final inner = Uint8List.fromList(pkm.getWhisperMessage().serialize());
        inner[inner.length - 1] ^= 1;
        final bad = PreKeySignalMessage.from(
          pkm.getMessageVersion(),
          pkm.getRegistrationId(),
          pkm.getPreKeyId(),
          pkm.getSignedPreKeyId(),
          pkm.getBaseKey(),
          pkm.getIdentityKey(),
          SignalMessage.fromSerialized(inner),
        );
        Future<void>? accepted;
        store.onInsert = (t) {
          if (t == 'peer_identities') accepted ??= rows.acceptNewKey(bob.name);
        };
        addTearDown(() => store.onInsert = null);
        expect(
          await signalDecrypt(
            bob.name,
            base64Encode([wire[0], ...bad.serialize()]),
            flagKeyChange: true,
          ),
          isNull,
        );
        await accepted;
        expect(row()['key_changed'], 0);
        expect(row()['verified'], 0);
        expect(row()['verified_key'], isNull);
      },
    );

    test(
      'whose session is kept before a later step fails keeps its key',
      () async {
        final again = await _phone(name: bob.name);
        // a one-time prekey of this phone's, which the open then lets go of
        final id = store
            .rows('prekeys')
            .map((r) => r['id'] as int)
            .firstWhere((i) => i != invitePreKeyId);
        final pk = await signalSession.preKeyStore.loadPreKey(id);
        final spk = await signalSession.signedPreKeyStore.loadSignedPreKey(1);
        await SessionBuilder(
          again.ss.sessionStore,
          again.ss.preKeyStore,
          again.ss.signedPreKeyStore,
          again.ss.identityStore,
          SignalProtocolAddress('me', 1),
        ).processPreKeyBundle(
          PreKeyBundle(
            signalSession.registrationId,
            1,
            id,
            pk.getKeyPair().publicKey,
            spk.id,
            spk.getKeyPair().publicKey,
            spk.signature,
            signalSession.identityKeyPair.getPublicKey(),
          ),
        );
        final wire = await again.ss.encryptTo('me', 'new phone');
        store.failOn = 'delete:prekeys';
        addTearDown(() => store.failOn = null);
        await signalDecrypt(bob.name, wire, flagKeyChange: true);
        store.failOn = null;
        await _settle();
        // the key the stored session is on, and the banner for it
        expect(_hex(key()), again.xpub);
        expect(row()['key_changed'], 1);
        expect(await app.keyHeld(bob.name, strict: true), isTrue);
        expect(
          await signalDecrypt(
            bob.name,
            await again.ss.encryptTo('me', 'and again'),
            flagKeyChange: true,
          ),
          'and again',
        );
      },
    );
  });

  test(
    'a session started afresh on an old card is held before it seals',
    () async {
      final db = MemDb();
      final pair = Curve.generateKeyPair();
      final me = SignalSession();
      await me.bootstrap(
        database: db,
        xPubBytes: pair.publicKey.serialize().sublist(1),
        xPrivBytes: pair.privateKey.serialize(),
      );
      final bob = await _phone();
      await SessionBuilder(
        me.sessionStore,
        me.preKeyStore,
        me.signedPreKeyStore,
        me.identityStore,
        SignalProtocolAddress(bob.name, 1),
      ).processPreKeyBundle(preKeyBundleOf(bob.card));
      await me.markRestored();
      // they came back on a new phone, and its number was checked
      final again = await _phone(name: bob.name);
      await _identity(db, bob.name, _unhex(again.xpub));
      await _contact(db, bob.name, xpub: bob.xpub, mark: again.xpub);
      await expectLater(
        me.encryptTo(
          bob.name,
          'hi',
          // the card kept from the first pairing
          afresh: () async => preKeyBundleOf(bob.card),
          held: () => keyHeldIn(db, bob.name),
        ),
        throwsA(isA<KeyHeld>()),
      );
    },
  );

  test('a receipt replayed for a held hidden chat is sealed once', () async {
    const id = 'replayed-receipt';
    await _identity(store, id, _keyB);
    await hide(id, _hex(_keyA), mark: _hex(_keyA));
    await app.receiptForTest(id, 'uid-r2');
    // a restart in between: the throttle in memory is gone
    final next = AppState(io: _Io(), router: router)..myId = 'me';
    await next.receiptForTest(id, 'uid-r2');
    expect(vaultList.inbox, hasLength(1));
  });

  test(
    'freed pages are rewritten once per database',
    () async {
      final db = SqliteMem.open()!;
      await db.execute('CREATE TABLE vault_meta (k TEXT PRIMARY KEY, v TEXT)');
      await db.execute('CREATE TABLE t (b TEXT)');
      Future<int> free() async {
        await db.execute(
          "INSERT INTO t SELECT printf('%.4000c', 'x') FROM "
          '(WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
          'WHERE i < 200) SELECT i FROM n)',
        );
        await db.execute('DELETE FROM t');
        return pages(db);
      }

      expect(await free(), greaterThan(0));
      await wipeFreedOnce(db);
      expect(await pages(db), 0);
      expect(await free(), greaterThan(0));
      await wipeFreedOnce(db);
      expect(await pages(db), greaterThan(0));
    },
    skip: SqliteMem.open() == null ? 'no sqlite on this host' : null,
  );

  // last: it marks this phone's sessions as come back with a restore
  test('a card naming another key on the sending side raises a hidden '
      "chat's banner", () async {
    final bob = await _phone();
    await processPeerBundle(bob.name, bob.card);
    final again = await _phone(name: bob.name);
    await _identity(store, bob.name, _unhex(again.xpub));
    final vmem = MemDb();
    await vmem.insert('contacts', {
      'halo_id': bob.name,
      'onion': '',
      'xpub': bob.xpub,
      'first_seen': 1,
      'last_seen': 1,
      'back_paired': 1,
      'accepted': 1,
      'peer_bundle': bob.card,
    });
    final vault = _Rows(vmem, HaloContainer.vault);
    await hide(bob.name, bob.xpub);
    useDatabasesForTest(rows, await Session.withVault(rows, vault));
    await signalSession.markRestored();
    await signalEncrypt(bob.name, 'hi');
    await _settle();
    expect(vmem.rows('contacts').single['key_changed'], 1);
  });
}

Future<int> pages(SqliteMem db) async => int.parse(
  (await db.rawQuery('PRAGMA freelist_count')).single.values.single.toString(),
);
