// SPDX-License-Identifier: GPL-3.0-or-later
// a phone on 0.5.0 takes this version. its files were made by 0.5.0's own
// code (fixtures/upgrade_050, make_050.sh): its schema, its onCreate and
// rows from its own write paths. they open here on the host's sqlite, step
// by step up to this version: the schema ends as a new install's, no row
// is lost, the freed pages are wiped once, the signal sessions go on, the
// settings move over, and a second open changes nothing
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'pin_flow_fakes.dart' show MemEngine, StillClock;
import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_050';
const _me = 'quiet-maple-harbor';
const _alice = 'amber-otter-lake';
const _bob = 'brisk-cedar-moon';
const _carol = 'coral-finch-dune';
const _dave = 'dusty-heron-vale';
const _erin = 'ember-larch-cove';
const _frank = 'frost-wren-glade';
const _zed = 'zinc-quail-shore';
const _hush = 'hush-pine-rill';
const _gid = 'g0a1b2c3d4e5f60718293a4b5c6d7e8f9';
const _rid = 'r0f1e2d3c4b5a69788796a5b4c3d2e1f0';

// the keys each file opens with, under the names the app keeps them by
final _keyFile =
    (jsonDecode(File('$_fixtures/keys.json').readAsStringSync()) as Map)
        .cast<String, String>();
final _keys = {
  'halo.db.passphrase': _keyFile['everyday']!,
  'halo.d.key': _keyFile['decoy']!,
};
final _settings =
    (jsonDecode(File('$_fixtures/settings.json').readAsStringSync()) as Map)
        .map(
          (k, v) => MapEntry(k as String, (v as Map).cast<String, String>()),
        );

// the three files a 0.5.0 phone keeps, each as this version opens it
final _files = <String, HaloDb Function()>{
  'halo.db': HaloDb.new,
  'halo_d.db': () => HaloDb(HaloContainer.decoy),
  'halo_v.db': () => HaloDb.withKey(HaloContainer.vault, _keyFile['vault']!),
};

class _Engine implements HaloEngine {
  final restored = <String>[];
  @override
  String restoreBridgeMode(String mode, String opts) {
    restored.add('$mode $opts');
    return 'ok';
  }

  @override
  String bridgeLineChecks() => '[]';
  @override
  List<String> builtinBridges(String transport) => const [];
  @override
  dynamic noSuchMethod(Invocation i) => 'ok';
}

// what 0.5.0 left, back where it was: the key store, and its prefs under
// a prefs: mark
void _keep(Map<String, String> kept) {
  FlutterSecureStorage.setMockInitialValues({
    for (final e in kept.entries)
      if (!e.key.startsWith('prefs:')) e.key: e.value,
  });
  SharedPreferences.setMockInitialValues({
    for (final e in kept.entries)
      if (e.key.startsWith('prefs:'))
        e.key.substring(6): jsonDecode(e.value) as Object,
  });
}

// a phone with a fingerprint, and what was asked of it
class _Finger implements LockBio {
  var dropped = 0;
  @override
  Future<bool> ready() async => true;
  @override
  Future<String> state() async => 'ok';
  @override
  Future<String?> seal(String opens) async => 'seal:$opens';
  @override
  Future<void> disable() async => dropped++;
  @override
  Future<BioOpened> unlock(String title, String cancel, String seal) async =>
      BioOpened('ok', seal.startsWith('seal:') ? seal.substring(5) : null);
}

// what the file holds, as sqlite describes it: each table's columns by
// name, its keys and indexes, and the triggers
Future<Map<String, Object?>> _schema(DatabaseExecutor db) async {
  final out = <String, Object?>{};
  final all = await db.rawQuery(
    "SELECT type, name, tbl_name, sql FROM sqlite_master "
    "WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  String flat(Object? s) => '${s ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final r in all) {
    final name = r['name'] as String;
    switch (r['type']) {
      case 'table':
        final cols = await db.rawQuery("PRAGMA table_info('$name')");
        out['table $name'] = {
          for (final c in cols)
            c['name']:
                '${c['type']} notnull=${c['notnull']} '
                'default=${c['dflt_value']} pk=${c['pk']}',
        };
        final fks = await db.rawQuery("PRAGMA foreign_key_list('$name')");
        out['fk $name'] = [
          for (final f in fks)
            '${f['from']}->${f['table']}.${f['to']} ${f['on_delete']}',
        ]..sort();
        final idx = await db.rawQuery("PRAGMA index_list('$name')");
        final keys = <String>[];
        for (final i in idx) {
          final on = await db.rawQuery("PRAGMA index_info('${i['name']}')");
          final cols = [for (final c in on) c['name']].join(',');
          // an index sqlite made for a key has a name by its place
          final named = '${i['origin']}' == 'c' ? '${i['name']} ' : '';
          keys.add(
            '$named(${i['origin']}) unique=${i['unique']} '
            'partial=${i['partial']} $cols',
          );
        }
        out['keys $name'] = keys..sort();
      case 'index':
        out['index $name'] = '${r['tbl_name']}: ${flat(r['sql'])}';
      case 'trigger':
        out['trigger $name'] = '${r['tbl_name']}: ${flat(r['sql'])}';
      case 'view':
        out['view $name'] = flat(r['sql']);
    }
  }
  return out;
}

// every row of every table, by the columns it had in 0.5.0
Future<Map<String, List<String>>> _rows(
  DatabaseExecutor db, {
  Map<String, Set<String>>? only,
}) async {
  final out = <String, List<String>>{};
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  for (final t in tables) {
    final name = t['name'] as String;
    final cols = only?[name];
    final rows = await db.rawQuery('SELECT * FROM "$name"');
    out[name] = [
      for (final r in rows)
        jsonEncode({
          for (final e in r.entries)
            if (cols == null || cols.contains(e.key))
              e.key: e.value is Uint8List
                  ? base64Encode(e.value as Uint8List)
                  : e.value,
        }),
    ]..sort();
  }
  return out;
}

Future<String> _openFrom(SignalSession s, String from, String wire) async {
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

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

// a store opened on an identity's own row, as the app opens it
Future<SignalSession> _store(Database db, String xPubHex) async {
  final id = await db.query('identity', limit: 1);
  final s = SignalSession();
  await s.bootstrap(
    database: db,
    xPubBytes: _bytes(xPubHex),
    xPrivBytes: _bytes(id.first['x_priv'] as String),
  );
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  // each file 0.5.0 left: its rows and their columns, read and never
  // written, and a new install's schema for it, made by this onCreate
  final before = <String, Map<String, List<String>>>{};
  final beforeCols = <String, Map<String, Set<String>>>{};
  final fresh = <String, Map<String, Object?>>{};

  setUpAll(() async {
    sql = SqliteChannel.install();
    if (sql == null) return;
    for (final f in _files.keys) {
      final d = Directory.systemTemp.createTempSync('upgrade_fresh');
      m.setMockMethodCallHandler(paths, (_) async => d.path);
      FlutterSecureStorage.setMockInitialValues({});
      final db = _files[f]!();
      fresh[f] = await _schema(await db.open());
      await db.close();
      d.deleteSync(recursive: true);
      final old = await openDatabase(
        p.absolute('$_fixtures/$f'),
        readOnly: true,
        singleInstance: false,
      );
      expect(await old.getVersion(), 65, reason: f);
      before[f] = await _rows(old);
      beforeCols[f] = {
        for (final t in before[f]!.keys)
          t: {
            for (final c in await old.rawQuery("PRAGMA table_info('$t')"))
              c['name'] as String,
          },
      };
      await old.close();
    }
    sql!.uninstall();
  });

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('upgrade_050');
    for (final f in _files.keys) {
      File('$_fixtures/$f').copySync(p.join(docs.path, f));
    }
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    _keep({..._keys, ..._settings['never touched']!});
    useDevKeysForTest(null);
  });

  tearDown(() {
    sql?.uninstall();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  test('the files hold what 0.5.0 wrote', () {
    if (skip()) return;
    // a check of the checks: an empty file or schema would pass them all
    expect(fresh['halo.db']!['table contacts'], contains('verified_key'));
    expect(before['halo.db']!['messages'], hasLength(19));
    expect(before['halo.db']!['contacts'], hasLength(8));
    expect(before['halo_d.db']!['sessions'], hasLength(1));
    expect(before['halo_v.db']!['messages'], hasLength(2));
  });

  for (final f in _files.keys) {
    test('$f opens at 80 with the schema of a new install', () async {
      if (skip()) return;
      final db = _files[f]!();
      final raw = await db.open();
      expect(await raw.getVersion(), 80);
      final got = await _schema(raw);
      // key by key, so a miss names the table and the column
      for (final k in {...fresh[f]!.keys, ...got.keys}) {
        expect(got[k], fresh[f]![k], reason: k);
      }
      // every step from 66 ran, in the order onUpgrade lists them
      final steps = [
        'ALTER TABLE contacts ADD COLUMN verified_key',
        'ALTER TABLE messages ADD COLUMN via_dev',
        'ALTER TABLE groups ADD COLUMN door_priv',
        'ALTER TABLE held_onion ADD COLUMN media_id',
        'CREATE TABLE IF NOT EXISTS first_kept',
        'ALTER TABLE media_chunks ADD COLUMN group_id',
        'ALTER TABLE edits_out ADD COLUMN tries',
        'CREATE TABLE IF NOT EXISTS notif_tags',
        'CREATE TABLE IF NOT EXISTS group_resent',
        'ALTER TABLE block_spans ADD COLUMN listen_from',
        'ALTER TABLE contacts ADD COLUMN voice_disguise',
        'ALTER TABLE contacts ADD COLUMN name_check',
        'ALTER TABLE messages ADD COLUMN written_at',
        'CREATE TABLE IF NOT EXISTS notif_rings',
        'ALTER TABLE contacts ADD COLUMN ack_owed',
      ];
      final at = [
        for (final s in steps) sql!.said.indexWhere((x) => x.startsWith(s)),
      ];
      expect(at, everyElement(greaterThanOrEqualTo(0)), reason: '$steps');
      expect([...at]..sort(), at);
      // and none from before 66
      expect(
        sql!.said.where((s) => s.contains('ADD COLUMN joining_at')),
        isEmpty,
      );
      await db.close();
    });

    test('$f loses no row', () async {
      if (skip()) return;
      final db = _files[f]!();
      final after = await _rows(await db.open(), only: beforeCols[f]);
      // a contact verified under no key known here loses the mark, and
      // that is all that moves
      String unmark(String row) {
        final r = jsonDecode(row) as Map<String, Object?>;
        if (r['halo_id'] == _zed) r['verified'] = 0;
        return jsonEncode(r);
      }

      for (final t in before[f]!.keys) {
        expect(
          after[t],
          [for (final r in before[f]![t]!) unmark(r)]..sort(),
          reason: t,
        );
      }
      await db.close();
    });

    test('$f: every message keeps its place, at the time it came', () async {
      if (skip()) return;
      final db = _files[f]!();
      final raw = await db.open();
      final rows = await raw.query('messages');
      expect(rows.length, before[f]!['messages']!.length);
      for (final r in rows) {
        expect(r['written_at'], r['sent_at'], reason: '${r['msg_uid']}');
      }
      await db.close();
    });

    test('$f: a second open changes nothing', () async {
      if (skip()) return;
      final db = _files[f]!();
      final first = await db.open();
      final schema = await _schema(first);
      final rows = await _rows(first);
      await db.close();
      final from = sql!.said.length;
      final again = _files[f]!();
      final raw = await again.open();
      final said = sql!.said.sublist(from);
      expect(await raw.getVersion(), 80);
      expect(
        said.where(
          (s) => RegExp(
            r'^(ALTER|CREATE|UPDATE|INSERT|DELETE|DROP|REPLACE)',
          ).hasMatch(s),
        ),
        isEmpty,
      );
      expect(await _schema(raw), schema);
      expect(await _rows(raw), rows);
      await again.close();
    });
  }

  test('a request or a card still waiting comes up with its words not '
      'checked, and nobody else does', () async {
    if (skip()) return;
    final db = HaloDb();
    final raw = await db.open();
    final rows = await raw.query('contacts');
    var waiting = 0;
    for (final r in rows) {
      final open =
          r['accepted'] == 0 && r['archived'] == 0 && r['verified'] == 0;
      if (open) waiting++;
      expect(r['name_check'], open ? 3 : 0, reason: '${r['halo_id']}');
    }
    // a check of the check: the file holds both kinds
    expect(waiting, greaterThan(0));
    expect(rows.length, greaterThan(waiting));
    await db.close();
  });

  test('the hidden chats keep their verified mark, tied to the card', () async {
    if (skip()) return;
    final db = _files['halo_v.db']!();
    await db.open();
    final hush = (await db.getContact(_hush))!;
    expect(hush['verified'], 1);
    expect(hush['verified_key'], hush['xpub']);
    expect(
      [for (final r in await db.messagesFor(_hush)) r['plaintext']],
      ['only here', 'and back'],
    );
    await db.close();
  });

  test('everything reads back through this version', () async {
    if (skip()) return;
    final db = HaloDb();
    await db.open();

    expect((await db.loadIdentity())!['id'], _me);

    // contacts, and the key each verified one is tied to now
    final alice = (await db.getContact(_alice))!;
    expect(alice['nickname'], 'Alice');
    expect(alice['verified'], 1);
    expect(alice['verified_key'], isNotNull);
    expect(alice['back_paired'], 1);
    expect(await db.isVerified(_alice), isTrue);
    final bob = (await db.getContact(_bob))!;
    expect(bob['verified'], 1);
    expect(bob['verified_key'], bob['xpub']);
    expect(bob['muted'], 1);
    expect(await db.isVerified(_zed), isFalse);
    final erin = (await db.getContact(_erin))!;
    expect(erin['archived'], 1);
    expect(erin['note'], 'met at the station');
    expect(erin['pinned'], 1);
    expect(erin['avatar'], 5);
    expect(erin['supporter_badge'], 'gold');
    expect(erin['unread'], 2);
    expect(await db.getAtmosphere(_erin), 'dusk');
    expect([
      for (final c in await db.contacts()) c['halo_id'],
    ], containsAll([_alice, _bob, _erin]));

    // blocks
    expect(await db.isBlocked(_carol), isTrue);
    expect(await db.blockedIds(), contains(_carol));
    expect(await db.droppedWhileBlocked(_carol, 'carol-dropped-1'), isTrue);

    // requests, the shelf and vouches
    expect([
      for (final r in await db.pendingRequests()) r['halo_id'],
    ], containsAll([_dave, _frank]));
    final held = await db.heldOf(_dave);
    expect(
      [for (final h in held) h.cipher],
      ['sealed-for-later-1', 'sealed-for-later-2'],
    );
    final vouches = await db.vouchesFor(_frank);
    expect(vouches.single['voucher_id'], _alice);
    expect(vouches.single['note'], 'my cousin');
    expect((await db.shieldFor(_frank))!['headline'], 'stranger');

    // the 1:1 thread
    final thread = await db.messagesFor(_alice);
    final byUid = {for (final r in thread) r['msg_uid']: r};
    expect(byUid.keys, containsAll(['a-1', 'a-2', 'a-3', 'a-4', 'a-5']));
    expect(byUid['a-3']!['plaintext'], 'a reply, edited');
    expect(byUid['a-3']!['edited'], 1);
    expect(byUid['a-3']!['reply_to'], 'a-2');
    expect(byUid['a-4']!['burn_secs'], 30);
    expect(byUid['a-5']!['sent'], 0);
    expect(byUid['a-7']!['file_name'], 'notes.pdf');
    expect(byUid['a-7']!['saved'], 1);
    expect(byUid['a-8']!['voice_disguised'], 1);
    expect(byUid['a-9']!['sticker'], 'fokia/3');
    expect(byUid['a-10']!['secure'], 1);
    expect(byUid['a-1']!['delivered'], 1);
    expect(thread.every((r) => r['via_dev'] == 0), isTrue);
    final pins = await db.pinnedIn(peerId: _alice);
    expect([for (final r in pins) r['msg_uid']], ['a-1']);
    expect([for (final r in await db.unsentPins()) r['msg_uid']], ['a-1']);
    expect(
      [for (final r in await db.unsentEdits()) r['new_text']],
      ['a reply, edited'],
    );
    // a queued reaction is let go a week on: read as of when it was queued
    final queued =
        (await (await db.open()).query('frames_out')).single['at'] as int;
    expect(
      [for (final r in await db.unsentFrames(now: queued)) r['msg_uid']],
      ['a-2'],
    );
    final reactions = await db.loadReactionsFor(['a-1', 'a-2']);
    expect(reactions['a-2']!.single.value, '👍');
    expect(reactions['a-1']!.single.value, '❤');
    expect([
      for (final r in await db.savedMessages()) r['msg_uid'],
    ], containsAll(['a-2', 'a-7']));
    expect(await db.alreadySeen('hash-of-a-2'), isTrue);

    // polls and their votes
    final poll = (await db.pollRow('a-10'))!;
    expect(poll.spec.options, ['Noon', 'One']);
    expect(poll.spec.multi, isTrue);
    expect(poll.mine, isTrue);
    final votes = await db.pollVotesFor(['a-10', 'g-3']);
    expect(votes['a-10']!.keys, containsAll([_alice, _me]));
    expect(votes['a-10']![_alice]!.choices, [0, 1]);
    expect(votes['g-3']![_bob]!.choices, [0]);

    // the group and the room
    final g = (await db.getGroup(_gid))!;
    expect(g['name'], 'Climbing');
    expect(g['is_admin'], 1);
    expect(g['unread'], 1);
    expect(g['mentioned'], 1);
    expect(await db.getGroupAtmosphere(_gid), 'forest');
    expect(await db.getGroupMembers(_gid), containsAll([_me, _alice, _bob]));
    expect([
      for (final r in await db.loadGroupMessages(_gid)) r['msg_uid'],
    ], containsAll(['g-1', 'g-2', 'g-3']));
    expect(
      [for (final r in await db.pinnedIn(groupId: _gid)) r['msg_uid']],
      ['g-2'],
    );
    expect((await db.groupCtlOut()).single['member'], _bob);
    final room = (await db.rooms()).singleWhere((r) => r['group_id'] == _rid);
    expect(room['name'], 'Night shift');
    expect(room['member_cap'], 12);
    expect(room['door_pub'], isNull);
    expect(
      [for (final r in await db.loadGroupMessages(_rid)) r['plaintext']],
      ['anyone up?'],
    );

    // a file half in
    expect(await db.heldSlices('m-1'), {0, 2});
    expect(await db.mediaChunkSlice('m-1', 2), 'c2xpY2Uz');
    expect((await db.mediaWants()).single['media_id'], 'm-1');

    // search finds what 0.5.0 indexed
    final lunch = await db.searchMessages('lunch', SearchKind.all);
    expect([for (final r in lunch) r['msg_uid']], ['a-10']);
    final rope = await db.searchMessages('rope', SearchKind.all);
    expect([for (final r in rope) r['msg_uid']], ['g-1']);

    // the dev chat, as it was started
    final dev = await DevChat(db.open, shred: (_) async {}).load();
    expect(dev!.state, DevState.everyday);
    final devId = currentDevKey!.chatId;
    final devContact = (await db.getContact(devId))!;
    expect(devContact['verified'], 1);
    expect(
      [for (final r in await db.messagesFor(devId)) r['plaintext']],
      ['hi Marios', 'hi, thanks'],
    );

    // a hidden chat's entry and what waits sealed for it
    final router = SqlRouterStore(db.open);
    expect(
      [for (final r in await router.hidden()) r['chat_id']],
      ['hush-pine-rill'],
    );
    final sealed = await router.inboxOldest(10);
    expect(sealed.single['sealed'], [0, 1, 2, 250, 251, 252]);
    await db.close();
  });

  test('the signal sessions go on, both ways', () async {
    if (skip()) return;
    final db = HaloDb();
    final raw = await db.open();
    final other = HaloDb(HaloContainer.decoy);
    final otherRaw = await other.open();
    expect(await otherRaw.getVersion(), 80);
    final mine = await _store(raw, (await peerIdentityHex(otherRaw, _me))!);
    final hers = await _store(
      otherRaw,
      (await db.getContact(_alice))!['xpub'] as String,
    );
    final out = await mine.encryptTo(_alice, 'after the update');
    expect(base64Decode(out)[0], CiphertextMessage.whisperType);
    expect(await _openFrom(hers, _me, out), 'after the update');
    final back = await hers.encryptTo(_me, 'and on this side too');
    expect(await _openFrom(mine, _alice, back), 'and on this side too');
    await db.close();
    await other.close();
  });

  testWidgets('the freed pages are wiped once, and only once', (t) async {
    if (skip()) return;
    final db = HaloDb();
    final raw = await db.open();
    int vacuums() => sql!.said.where((s) => s == 'VACUUM').length;
    expect(vacuums(), 0);
    await t.pump(const Duration(seconds: 31));
    expect(vacuums(), 1);
    expect(await RouterRows.meta(raw, 'freed_wiped'), '1');
    await db.close();
    final again = HaloDb();
    await again.open();
    await t.pump(const Duration(seconds: 31));
    expect(vacuums(), 1);
    await again.close();
  });

  group('the settings move over', () {
    // the boot's order: onboarding read, ready, then the bridges
    Future<(AppState, _Engine)> boot(Map<String, String> kept) async {
      _keep(kept);
      final e = _Engine();
      useEngineForTest(e);
      final a = AppState();
      a.onboardingComplete =
          await secureStore.read(key: 'onboarding_done') == 'true';
      await a.markReady();
      expect(a.firstRunAsk, isFalse);
      await a.loadBridgesForTest();
      return (a, e);
    }

    Future<Map<String, String>> store() => secureStore.readAll();

    test('bridges on from the tor project keep their lines', () async {
      final old = _settings['bridges on, from the tor project']!;
      final (a, e) = await boot(old);
      expect(a.bridge.choice, BridgeChoice.torProject);
      expect(a.bridge.torProjectLines, old['bridge_lines']);
      expect(a.bridge.friendLines, isEmpty);
      expect(a.bridge.consent, 'no');
      expect(a.bridge.offerAuto, isFalse);
      expect(e.restored.single, startsWith('moat '));
      expect(e.restored.single, contains('192.0.2.10:443'));
      final s = await store();
      expect(s['bridge_mode'], 'moat');
      expect(s['bridge_moat_lines'], old['bridge_lines']);
      expect(s.keys, isNot(contains('bridges_on')));
      expect(s.keys, isNot(contains('bridge_source')));
      expect(s.keys, isNot(contains('bridge_lines')));
    });

    test('bridges on, pasted, keep their lines as a friend\'s', () async {
      final old = _settings['bridges on, pasted']!;
      final (a, e) = await boot(old);
      expect(a.bridge.choice, BridgeChoice.friend);
      expect(a.bridge.friendLines, old['bridge_lines']);
      expect(a.bridge.torProjectLines, isEmpty);
      expect(a.bridge.consent, 'no');
      expect(e.restored.single, startsWith('own '));
      expect(e.restored.single, contains('198.51.100.7:9001'));
      final s = await store();
      expect(s['bridge_lines'], old['bridge_lines']);
      expect(s.keys, isNot(contains('bridges_on')));
      expect(s.keys, isNot(contains('bridge_source')));
    });

    test('bridges off go to tor alone and are offered automatic', () async {
      final old = _settings['bridges off, lines kept']!;
      expect(old['bridges_on'], '0');
      final (a, e) = await boot(old);
      expect(a.bridge.choice, BridgeChoice.direct);
      expect(a.bridge.offerAuto, isTrue);
      expect(a.bridge.consent, 'no');
      expect(a.bridge.torProjectLines, old['bridge_lines']);
      expect(e.restored.single, startsWith('direct '));
      expect((await store())['bridge_offer_auto'], '1');
    });

    test('never touched: tor alone, offered automatic', () async {
      final old = _settings['never touched']!;
      expect(old.keys, isNot(contains('bridges_on')));
      final (a, e) = await boot(old);
      expect(a.bridge.choice, BridgeChoice.direct);
      expect(a.bridge.offerAuto, isTrue);
      expect(e.restored.single, startsWith('direct '));
    });

    test('a second start reads what the first wrote', () async {
      for (final name in _settings.keys) {
        final (first, _) = await boot(_settings[name]!);
        final kept = await store();
        final (second, e) = await boot(kept);
        expect(second.bridge.choice, first.bridge.choice, reason: name);
        expect(await store(), kept, reason: name);
        expect(e.restored, hasLength(1), reason: name);
      }
    });

    test('a pin, a finger and a decoy: the pins open what they opened, '
        'the finger goes as with a new decoy', () async {
      final old = _settings['locked, a finger and a decoy']!;
      expect(old['halo.lock.d.bio'], 'true');
      expect(old['halo.lock.biometric'], 'true');
      _keep(old);
      // the app has the decoy's session up by the time a pin is typed
      decoyReady = true;
      addTearDown(() => decoyReady = false);
      final finger = _Finger();
      LockState lock() => LockState(
        engine: MemEngine(),
        clock: StillClock(),
        bio: finger,
        revealAfter: Duration.zero,
      );
      final s = lock();
      await s.load();
      expect(s.enabled, isTrue);
      expect(s.decoySet, isTrue);
      expect(s.biometric, isFalse);
      expect(finger.dropped, 1);
      final kept = await store();
      expect(kept['halo.lock.biometric'], 'false');
      expect(kept.keys, isNot(contains('halo.lock.d.bio')));
      expect(kept['halo.lock.table'], old['halo.lock.table']);
      // the next start finds nothing left to move
      final again = lock();
      await again.load();
      expect(finger.dropped, 1);
      expect(await store(), kept);
      expect(await s.verifyPin('1234'), PinResult.normal);
      expect(await again.verifyPin('5555'), PinResult.decoy);
    });

    test('a new install is not taken for an upgrade', () async {
      FlutterSecureStorage.setMockInitialValues({});
      useEngineForTest(_Engine());
      final a = AppState();
      a.onboardingComplete =
          await secureStore.read(key: 'onboarding_done') == 'true';
      await a.markReady();
      expect(a.firstRunAsk, isTrue);
      final b = await a.readBridgeSetup(firstStart: !a.onboardingComplete);
      expect(b.choice, BridgeChoice.auto);
      expect(b.offerAuto, isFalse);
      expect((await store())['bridge_mode'], isNull);
    });
  });
}
