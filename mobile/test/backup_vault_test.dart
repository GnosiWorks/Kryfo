// SPDX-License-Identifier: GPL-3.0-or-later
// backup, move and restore with hidden chats. an everyday backup carries
// nothing of them, one made with them open or from their setup carries them
// whole with their key, a restore brings them back behind a new hidden chats
// PIN, and the backup screen reads the same with and without them. no
// backup and no move carries the name an anonymous dev chat was made with:
// the chat goes along and lands without it. the databases are stand-ins
// kept as json in real files in a scratch folder, the cipher one for the
// engine's
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/backup_stream.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_gate.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, session, sessionQuiet, useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_stores.dart' show kDevSignalPrefix, kSignalTables;
import 'package:kryfo/vault_life.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'pin_flow_fakes.dart';

const _v = 'visible-plain-row';
const _h = 'hidden-wreck-tone';
const _m = 'member-only-one';
const _x = 'gone-from-before';
const _g2 = 'g2hidden0001';
const _dbPass = 'everyday-passphrase';

typedef _Tables = Map<String, List<Map<String, Object?>>>;

// the name an anonymous dev chat was made with
const _anonId = 'made-for-marios';
const _anonEd = 'anon-ed-private-key';
const _anonX = 'anon-x-private-key';

// an anonymous dev chat as a container keeps it: its row with the made
// name, and that name's own signal store
_Tables _devAnon() => {
  'devchat': [
    {
      'k': 1,
      'state': 'anon',
      'key_id': 'm1',
      'anon_id': _anonId,
      'anon_ed_priv': _anonEd,
      'anon_x_priv': _anonX,
      'created_at': 1,
      'started_at': 2,
    },
  ],
  'dev_signal_meta': [
    {'k': 'regId', 'v': '77'},
  ],
  'dev_sessions': [
    {'address': 'dev:m1', 'device_id': 1, 'record': 's-dev'},
  ],
  'dev_peer_identities': [
    {'address': 'dev:m1', 'identity_key': 'k-dev'},
  ],
  'dev_prekeys': [],
  'dev_signed_prekeys': [],
};

// what is left in a database of the made name: its keys on the row, its
// store, or any trace of it anywhere
List<String> _madeName(_Tables t) => [
  for (final r in t['devchat'] ?? const <Map<String, Object?>>[])
    for (final c in const ['anon_id', 'anon_ed_priv', 'anon_x_priv'])
      if (r[c] != null) c,
  for (final n in kSignalTables)
    if ((t['$kDevSignalPrefix$n'] ?? const []).isNotEmpty)
      '$kDevSignalPrefix$n',
  for (final v in [_anonId, _anonEd, _anonX])
    if (jsonEncode(t).contains(v)) v,
];

// the everyday database of a phone with hidden chats: V visible, H hidden
// and still a key in a visible group, M only in the hidden group, X on the
// list of a vault that went. the list, the vault's key, one sealed arrival
// and a signal session with each of them
_Tables _everyday() => {
  'contacts': [
    {'halo_id': _v, 'accepted': 1},
    {'halo_id': _h, 'accepted': 0},
  ],
  'messages': [
    {'msg_uid': 'v0', 'peer_id': _v, 'plaintext': 'the visible one'},
  ],
  'hidden_chats': [
    {
      'chat_id': _h,
      'kind': kHiddenPeer,
      'card': peerCard(const RouterCard(_h, 'o-h', 'x-h')),
      'at': 1,
    },
    {
      'chat_id': _g2,
      'kind': kHiddenGroup,
      'card': groupCard(const [RouterCard(_m, 'o-m', 'x-m')]),
      'at': 1,
    },
    {'chat_id': _x, 'kind': kHiddenGone, 'card': '{}', 'at': 1},
  ],
  'vault_meta': [
    {'k': 'pub', 'v': 'pub-A'},
  ],
  'vault_inbox': [
    {'id': 1, 'uid': 'u1', 'part': null, 'sealed': 'c2VhbGVk', 'at': 1},
  ],
  'sessions': [
    for (final id in [_v, _h, _m, _x])
      {'address': id, 'device_id': 1, 'record': 's-$id'},
  ],
  'peer_identities': [
    for (final id in [_v, _h, _m, _x]) {'address': id, 'identity_key': 'k-$id'},
  ],
  ..._devAnon(),
};

// the decoy: a chat of its own, and its own anonymous dev chat
_Tables _decoy() => {
  'messages': [
    {'msg_uid': 'd0', 'peer_id': 'decoy-only-one', 'plaintext': 'decoy'},
  ],
  ..._devAnon(),
};

// the vault: H's chat with a photo and a file, and the group G2
_Tables _vault() => {
  'contacts': [
    {'halo_id': _h, 'accepted': 1},
    {'halo_id': _m, 'accepted': 0},
  ],
  'groups': [
    {'group_id': _g2, 'name': 'Saturday hike'},
  ],
  'messages': [
    {'msg_uid': 'h0', 'peer_id': _h, 'plaintext': 'meet at the bridge'},
    {'msg_uid': 'h1', 'peer_id': _h, 'plaintext': '', 'media_path': 'h1.jpg'},
    {'msg_uid': 'h2', 'peer_id': _h, 'plaintext': '', 'file_path': 'h2.pdf'},
    {'msg_uid': 'g2m', 'peer_id': _m, 'plaintext': 'from m', 'group_id': _g2},
  ],
  'vault_meta': [
    {'k': 'priv', 'v': 'priv-A'},
  ],
};

Set<String> _uids(_Tables t) => {
  for (final r in t['messages'] ?? const <Map<String, Object?>>[])
    r['msg_uid'] as String,
};

Future<void> _put(String path, Object bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  bytes is String
      ? await f.writeAsString(bytes)
      : await f.writeAsBytes(bytes as List<int>);
}

Future<_Tables> _read(String path) async {
  final j = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  return {
    for (final e in j.entries)
      e.key: [
        for (final r in e.value as List) Map<String, Object?>.from(r as Map),
      ],
  };
}

// a phone's documents: the everyday side, and the hidden chats beside it
Future<void> _phone(String docs, {bool hidden = true}) async {
  await _put(p.join(docs, 'halo.db'), jsonEncode(_everyday()));
  await _put(p.join(docs, 'onion.key'), [1, 2, 3, 4]);
  await _put(p.join(docs, 'media', 'v1.jpg'), 'visible photo');
  await _put(p.join(docs, 'wallpapers', 'w.jpg'), 'visible wallpaper');
  if (!hidden) return;
  await _put(p.join(docs, 'halo_v.db'), jsonEncode(_vault()));
  await _put(p.join(docs, 'media_v', 'h1.jpg'), 'hidden photo');
  await _put(p.join(docs, 'media_v', 'docs', 'h2.pdf'), 'hidden file');
  await _put(p.join(docs, 'wallpapers_v', 'hw.jpg'), 'hidden wallpaper');
}

// a database kept as json in its file, as much of one as a scrub and a
// decoy's backup ask of it
class _MemDb implements Database, Transaction {
  _MemDb(this.path, this.t);

  static Future<_MemDb> load(String path) async =>
      _MemDb(path, await _read(path));

  Future<void> save() => File(path).writeAsString(jsonEncode(t));

  @override
  final String path;
  final _Tables t;

  List<Map<String, Object?>> _of(String table) =>
      t.putIfAbsent(table, () => []);

  static bool _match(
    Map<String, Object?> r,
    String? where,
    List<Object?>? args,
  ) {
    if (where == null) return true;
    final eq = RegExp(r'^(\w+) = \?$').firstMatch(where);
    if (eq != null) return r[eq.group(1)!] == args![0];
    final any = RegExp(r'^(\w+) IN \(').firstMatch(where);
    if (any != null) return args!.contains(r[any.group(1)!]);
    throw UnimplementedError(where);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = [
      for (final r in _of(table))
        if (_match(r, where, whereArgs))
          columns == null ? {...r} : {for (final c in columns) c: r[c]},
    ];
    return limit == null ? rows : rows.take(limit).toList();
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql.startsWith('PRAGMA')) return const [];
    if (sql ==
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?") {
      final name = arguments!.single as String;
      return [
        if (t.containsKey(name)) {'name': name},
      ];
    }
    final count = RegExp(r'^SELECT COUNT\(\*\) c FROM (\w+)$').firstMatch(sql);
    if (count != null) {
      return [
        {'c': _of(count.group(1)!).length},
      ];
    }
    throw UnimplementedError(sql);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = _of(table);
    final before = rows.length;
    rows.removeWhere((r) => _match(r, where, whereArgs));
    return before - rows.length;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    var n = 0;
    for (final r in _of(table)) {
      if (!_match(r, where, whereArgs)) continue;
      r.addAll(values);
      n++;
    }
    return n;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => action(this);

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// a container as a backup reaches it: its file copied whole, and a copy a
// test can hold part way. a closed one answers nothing, as a closed wrapped
// one does: its key went with it
class _Db implements HaloDb {
  _Db(this.container, this.docs, {this.key, this.held});

  @override
  final HaloContainer container;
  final String docs;
  final String? key;
  // which chats it holds, for a session over it
  ({Map<String, bool> people, Set<String> groups})? held;
  _MemDb? mem;
  var closed = false;
  // a copy says it began, then waits for the gate
  Completer<void>? copying;
  Completer<void>? gate;
  final log = <String>[];

  @override
  Future<void> copyTo(String to) async {
    if (closed) throw StateError('${container.dbFile} has no key here');
    copying?.complete();
    await gate?.future;
    if (closed) throw StateError('closed under a copy');
    await File(p.join(docs, container.dbFile)).copy(to);
    log.add('copied');
  }

  @override
  Future<String> copyWithKey(String to) async {
    await copyTo(to);
    return key!;
  }

  @override
  Future<void> close() async {
    closed = true;
    log.add('close');
  }

  @override
  Future<void> retire() async {
    closed = true;
    log.add('retire');
  }

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      held!;

  @override
  Future<Database> open() async => mem!;

  @override
  Future<Map<String, String>?> loadIdentity() async => {
    'ed_priv': 'decoy-ed',
    'x_priv': 'decoy-x',
  };

  @override
  Future<void> checkpoint() async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// the list, as the router keeps it
class _Store implements RouterStore {
  final rows = <String, Map<String, Object?>>{};
  final metas = <String, String>{};
  final inbox = <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> hidden() async => [
    for (final r in rows.values) {...r},
  ];
  @override
  Future<void> putHidden(
    String chatId,
    String kind,
    String card,
    int at,
  ) async {
    rows[chatId] = {'chat_id': chatId, 'kind': kind, 'card': card, 'at': at};
  }

  @override
  Future<void> deleteHidden(String chatId) async => rows.remove(chatId);
  @override
  Future<String?> meta(String k) async => metas[k];
  @override
  Future<void> putMeta(String k, String? v) async {
    v == null ? metas.remove(k) : metas[k] = v;
  }

  @override
  Future<void> inboxAdd(
    String? uid,
    int? part,
    Uint8List sealed,
    int at,
  ) async => inbox.add({'uid': uid, 'part': part, 'sealed': sealed});
  @override
  Future<bool> inboxHas(String uid, int? part) async => false;
  @override
  Future<int> inboxParts(String uid) async => 0;
  @override
  Future<int> inboxCount() async => inbox.length;
  @override
  Future<List<(int, int)>> inboxSizes() async => [
    for (final (i, r) in inbox.indexed) (i, (r['sealed'] as List<int>).length),
  ];
  @override
  Future<List<Map<String, Object?>>> inboxOldest(int limit) async => const [];
  @override
  Future<void> inboxDelete(int id) async {}
  @override
  Future<void> inboxClear() async => inbox.clear();
}

class _Seal implements VaultSeal {
  @override
  String? seal(String pub, String b64) => null;
  @override
  List<String?> openMany(String priv, List<String> b64s) => [
    for (final _ in b64s) null,
  ];
}

// the vault's life as far as a backup meets it, read off each call rather
// than its parameters
class _Mover implements ChatMover {
  @override
  dynamic noSuchMethod(Invocation i) => switch (i.memberName) {
    #attach || #detach || #putMarks => Future<void>.value(),
    #marks => Future<MoveMarks>.value(const MoveMarks()),
    #vaultCards => Future<Map<String, (String, String)>>.value(const {}),
    _ => throw UnimplementedError('${i.memberName}'),
  };
}

class _Host implements VaultHost {
  String? entry;
  final log = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    switch (i.memberName) {
      case #lockOn:
        return true;
      case #putEntry:
        entry = i.positionalArguments.whereType<String>().last;
        log.add('put');
        return Future<bool>.value(true);
      case #makeVault:
        return Future<String>.value('pub-1');
      case #mover:
        return _Mover();
      case #clearEntry || #wipeVault || #clearShade || #moveFile || #shred:
        log.add('${i.memberName}');
        return Future<void>.value();
    }
    throw UnimplementedError('${i.memberName}');
  }
}

// the identity and the scrub, as the engine and sqlcipher would do them,
// and the vault held still by the app under test
class _Side extends BackupSide {
  _Side(this.app);
  final AppState app;
  String? scrubbedWith;
  // a setup's vault is a real handle: its copy is taken here
  String? Function()? madeKey;
  String? docs;

  @override
  ({String ed, String x, String id}) identity() =>
      (ed: 'everyday-ed', x: 'everyday-x', id: 'me-me-me');

  @override
  Future<T> still<T>(
    Future<T> Function(HaloDb? vault) work, {
    required bool made,
  }) => app.backupStill(work, made: made);

  @override
  Future<String> copyHidden(HaloDb vault, String to) async {
    final k = madeKey;
    if (k == null) return super.copyHidden(vault, to);
    expect(vault.container, HaloContainer.vault);
    await File(p.join(docs!, 'halo_v.db')).copy(to);
    return k()!;
  }

  @override
  Future<Set<String>> scrub(String copy, String key) async {
    scrubbedWith = key;
    final db = await _MemDb.load(copy);
    final people = await scrubHidden(db);
    await db.save();
    return people;
  }

  // the keys the copies were opened with to take the made name out
  final devScrubbed = <String>[];

  @override
  Future<void> scrubDev(String copy, String key) async {
    devScrubbed.add(key);
    final db = await _MemDb.load(copy);
    await db.transaction(scrubDevAnon);
    await db.save();
  }
}

// a side that forgets the made name
class _Forgets extends _Side {
  _Forgets(super.app);

  @override
  Future<void> scrubDev(String copy, String key) async {}
}

// the engine's cipher bound to each record's place, as backup_stream_test
// has it
class _Cipher implements ChunkCipher {
  @override
  Uint8List seal(int index, int type, Uint8List plain) =>
      Uint8List.fromList([index & 255, type, ...plain.map((b) => b ^ 7)]);
  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    if (sealed.length < 2 || sealed[0] != (index & 255) || sealed[1] != type) {
      return null;
    }
    return Uint8List.fromList(sealed.sublist(2).map((b) => b ^ 7).toList());
  }
}

Future<String> _write(BackupDraft d, String dir) async {
  final out = p.join(dir, 'x.kryfo');
  await writeBackup(
    outPath: out,
    salt: Uint8List(16),
    cipher: _Cipher(),
    manifest: d.manifest,
    root: '',
    source: (n) => d.sources[n]!,
  );
  return out;
}

List<String> _names(Map<String, dynamic> m) => [
  for (final f in m['files'] as List) (f as Map)['name'] as String,
];

// what the screen reader is given, the pages it is kept from left out
SemanticsNode _root(WidgetTester t) =>
    t.binding.renderViews.first.debugSemantics!;

bool _heard(WidgetTester t, String line) {
  var found = false;
  bool walk(SemanticsNode n) {
    if (n.label.contains(line)) found = true;
    n.visitChildren(walk);
    return true;
  }

  walk(_root(t));
  return found;
}

// the whole tree, without the numbers and hashes nodes are given
String _tree(WidgetTester t) => _root(t)
    .toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder)
    .replaceAll(RegExp(r'#[0-9a-f]+'), '')
    .replaceAll(RegExp(r'id: \d+'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String docs;
  late String stage;
  late _Db live;
  late _Db vault;
  late AppState kryfo;
  late _Host host;
  late _Side side;

  void docsAt(String dir) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir,
      );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('backup_vault');
    docs = p.join(root.path, 'docs');
    stage = p.join(root.path, 'stage');
    Directory(docs).createSync();
    Directory(stage).createSync();
    docsAt(docs);
    SharedPreferences.setMockInitialValues({'onboarding.complete': true});
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': _dbPass,
      'peer_fc': jsonEncode({_v: 'fc-v', _h: 'fc-h', _m: 'fc-m'}),
      'my_handle': 'wren',
    });
    live = _Db(
      HaloContainer.everyday,
      docs,
      held: (people: {_v: true, _h: false}, groups: const <String>{}),
    );
    vault = _Db(
      HaloContainer.vault,
      docs,
      key: vaultKey,
      held: (people: {_h: true, _m: false}, groups: {_g2}),
    );
    host = _Host();
    final router = VaultRouter(_Store(), _Seal());
    await router.load();
    kryfo = AppState(router: router, host: host);
    side = _Side(kryfo);
    useDatabasesForTest(live, Session(live));
    forgetRestoredHidden();
  });

  tearDown(() {
    useDatabasesForTest(live, Session(live));
    forgetRestoredHidden();
    root.deleteSync(recursive: true);
  });

  Future<void> openVault() async =>
      useDatabasesForTest(live, await Session.withVault(live, vault));

  group('an everyday backup', () {
    test('holds no vault file, no hidden list and no signal session of a '
        'hidden contact', () async {
      await _phone(docs);
      expect(sessionBackupHasHidden, isFalse);
      final d = await draftBackup(stage, side: side);
      final m = d.manifest;
      expect(m['v'], 2);
      expect(m.containsKey('vault'), isFalse);
      expect(_names(m), [
        'halo.db',
        'onion.key',
        'media/v1.jpg',
        'wallpapers/w.jpg',
      ]);
      // nothing is read from the hidden side's files
      expect(
        d.sources.values.where(
          (s) => p
              .split(s)
              .any(
                (x) =>
                    const {'halo_v.db', 'media_v', 'wallpapers_v'}.contains(x),
              ),
        ),
        isEmpty,
        reason: '${d.sources}',
      );
      // the copy that goes in carries nothing of them
      expect(side.scrubbedWith, _dbPass);
      final carried = await _read(d.sources['halo.db']!);
      expect(carried['hidden_chats'], isEmpty);
      expect(carried['vault_meta'], isEmpty);
      expect(carried['vault_inbox'], isEmpty);
      expect([for (final r in carried['sessions']!) r['address']], [_v]);
      expect([for (final r in carried['peer_identities']!) r['address']], [_v]);
      // everyday rows as they were, H's key for the visible group too
      expect(_uids(carried), {'v0'});
      expect(carried['contacts']!.length, 2);
      // nor their first-contact keys
      final fc = jsonDecode((m['secure'] as Map)['peer_fc'] as String);
      expect(fc, {_v: 'fc-v'});
      // the phone's own database keeps its list
      final own = await _read(p.join(docs, 'halo.db'));
      expect(own['hidden_chats']!.length, 3);
      expect(own['sessions']!.length, 4);
      // and the file written holds none of it
      final out = await _write(d, root.path);
      final back = await readBackupManifest(out, _Cipher());
      expect(_names(back).where((n) => hiddenPart(n) != null), isEmpty);
    });

    test('carries the supporter badge and the face picked', () async {
      await _phone(docs, hidden: false);
      SharedPreferences.setMockInitialValues({
        'supporter_tier': 'supporter',
        'supporter_receipt_payload': 'payload',
        'supporter_receipt_sig': 'sig',
        'd.supporter_tier': 'decoy',
      });
      await const FlutterSecureStorage().write(key: 'my_avatar', value: '17');
      final m = (await draftBackup(stage, side: side)).manifest;
      expect(m['prefs'], {
        'supporter_tier': 'supporter',
        'supporter_receipt_payload': 'payload',
        'supporter_receipt_sig': 'sig',
      });
      expect((m['secure'] as Map)['my_avatar'], '17');
    });

    test('reads the same with no hidden chats at all', () async {
      await _phone(docs, hidden: false);
      final d = await draftBackup(stage, side: side);
      expect(d.manifest.containsKey('vault'), isFalse);
      expect(_names(d.manifest), [
        'halo.db',
        'onion.key',
        'media/v1.jpg',
        'wallpapers/w.jpg',
      ]);
    });

    test('a move from the everyday session carries nothing of them '
        'either', () async {
      await _phone(docs);
      final d = await draftBackup(stage, side: side, move: true);
      expect(d.manifest['moved'], isTrue);
      expect(d.manifest.containsKey('vault'), isFalse);
      expect((await _read(d.sources['halo.db']!))['hidden_chats'], isEmpty);
    });
  });

  group('a backup made with hidden chats open', () {
    test('carries them whole, their key inside, and a restore brings every '
        'hidden chat and message back behind a new PIN', () async {
      await _phone(docs);
      await openVault();
      expect(sessionBackupHasHidden, isTrue);
      expect(backupShape(quiet: false, open: true, setup: false, move: true), (
        hidden: true,
        made: false,
        move: true,
      ));
      final d = await draftBackup(stage, side: side, hidden: true);
      final m = d.manifest;
      expect(m['v'], kBackupVersionHidden);
      expect(m['vault'], {'key': vaultKey});
      expect(_names(m), [
        'halo.db',
        'onion.key',
        'media/v1.jpg',
        'wallpapers/w.jpg',
        kHiddenDb,
        'vault/media/docs/h2.pdf',
        'vault/media/h1.jpg',
        'vault/wallpapers/hw.jpg',
      ]);
      // the list goes along: on the new phone arrivals still find the vault
      expect(side.scrubbedWith, isNull);
      final carried = await _read(d.sources['halo.db']!);
      expect(carried['hidden_chats']!.length, 3);
      expect(carried['sessions']!.length, 4);

      final out = await _write(d, root.path);

      // a new phone, with hidden chats of its own and an app lock
      final docs2 = p.join(root.path, 'docs2');
      await _phone(docs2, hidden: false);
      await _put(p.join(docs2, 'halo_v.db'), 'an older vault');
      await _put(p.join(docs2, 'media_v', 'old.jpg'), 'old hidden photo');
      docsAt(docs2);
      final hiddenAt = p.join(docs2, 'restore_hidden');
      final back = await unpackBackup(
        out,
        _Cipher(),
        root: docs2,
        hidden: hiddenAt,
      );
      // the old vault's entry goes first, before any file
      final order = <String>[];
      await landHidden(
        docs2,
        hiddenAt,
        back,
        clearEntry: () async => order.add(
          'clear, old file ${File(p.join(docs2, 'halo_v.db')).readAsStringSync()}',
        ),
      );
      expect(order, ['clear, old file an older vault']);
      expect(
        await File(p.join(docs2, 'halo_v.db')).readAsString(),
        await File(p.join(docs, 'halo_v.db')).readAsString(),
      );
      final hidden = await _read(p.join(docs2, 'halo_v.db'));
      expect(_uids(hidden), {'h0', 'h1', 'h2', 'g2m'});
      expect(hidden['groups']!.single['group_id'], _g2);
      for (final (from, to) in [
        ('media_v/h1.jpg', 'media_v/h1.jpg'),
        ('media_v/docs/h2.pdf', 'media_v/docs/h2.pdf'),
        ('wallpapers_v/hw.jpg', 'wallpapers_v/hw.jpg'),
        ('media/v1.jpg', 'media/v1.jpg'),
      ]) {
        expect(
          await File(p.join(docs2, to)).readAsString(),
          await File(p.join(docs, from)).readAsString(),
          reason: to,
        );
      }
      expect(File(p.join(docs2, 'media_v', 'old.jpg')).existsSync(), isFalse);
      expect(Directory(hiddenAt).existsSync(), isFalse);
      expect(Directory(p.join(docs2, 'vault')).existsSync(), isFalse);
      expect(
        (await _read(p.join(docs2, 'halo.db')))['hidden_chats']!.length,
        3,
      );

      // Q7: a new hidden chats PIN wraps the key the backup carried
      expect(restoredHidden, isTrue);
      final lock = await makeLock(appOnly);
      expect(await sealRestoredHidden(lock.state, vaultPin), isTrue);
      expect(restoredHidden, isFalse);
      final entry = lock.entries['${PinSlot.vault}'] as Map;
      expect(entry['p'], vaultPin);
      expect(entry['k'], PinKind.vault);
      expect(entry['w'], vaultKey);
    });

    test('a restore of an everyday backup takes away the hidden chats '
        'here, with nothing waiting for a PIN', () async {
      await _phone(docs);
      final out = await _write(await draftBackup(stage, side: side), root.path);
      final docs2 = p.join(root.path, 'docs2');
      await _phone(docs2);
      docsAt(docs2);
      final hiddenAt = p.join(docs2, 'restore_hidden');
      final back = await unpackBackup(
        out,
        _Cipher(),
        root: docs2,
        hidden: hiddenAt,
      );
      var cleared = false;
      await landHidden(
        docs2,
        hiddenAt,
        back,
        clearEntry: () async => cleared = true,
      );
      expect(cleared, isTrue);
      expect(File(p.join(docs2, 'halo_v.db')).existsSync(), isFalse);
      expect(Directory(p.join(docs2, 'media_v')).existsSync(), isFalse);
      expect(Directory(p.join(docs2, 'wallpapers_v')).existsSync(), isFalse);
      expect(restoredHidden, isFalse);
    });

    test('in a decoy they never land', () async {
      await _phone(docs);
      await openVault();
      final out = await _write(
        await draftBackup(stage, side: side, hidden: true),
        root.path,
      );
      final land = p.join(root.path, 'restore_d');
      Directory(land).createSync();
      final back = await unpackBackup(out, _Cipher(), root: land);
      expect(back['vault'], {'key': vaultKey});
      expect(File(p.join(land, 'halo.db')).existsSync(), isTrue);
      expect(Directory(p.join(land, 'vault')).existsSync(), isFalse);
      expect(File(p.join(land, 'halo_v.db')).existsSync(), isFalse);
    });

    test('a damaged key is refused before anything is touched', () async {
      await _phone(docs);
      await openVault();
      final d = await draftBackup(stage, side: side, hidden: true);
      d.manifest['vault'] = {'key': 'not a key'};
      final out = await _write(d, root.path);
      final docs2 = p.join(root.path, 'docs2');
      await _phone(docs2, hidden: false);
      final before = await File(p.join(docs2, 'halo.db')).readAsString();
      await expectLater(
        unpackBackup(
          out,
          _Cipher(),
          root: docs2,
          hidden: p.join(docs2, 'restore_hidden'),
        ),
        throwsA(isA<BackupDamaged>()),
      );
      expect(await File(p.join(docs2, 'halo.db')).readAsString(), before);
      expect(Directory(p.join(docs2, 'restore_hidden')).existsSync(), isFalse);
    });
  });

  group('a vault shut mid-backup', () {
    test('shuts after the copy, which is whole', () async {
      await _phone(docs);
      await openVault();
      vault.copying = Completer<void>();
      vault.gate = Completer<void>();
      final drafting = draftBackup(stage, side: side, hidden: true);
      await vault.copying!.future;
      // the lock goes up while the vault is copied
      kryfo.lockingUp();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // the screens are back on the everyday session at once
      expect(session.vault, isNull);
      expect(vault.closed, isFalse);
      vault.gate!.complete();
      final d = await drafting;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(vault.log, ['copied', 'close']);
      expect(d.manifest['vault'], {'key': vaultKey});
      expect(
        await File(d.sources[kHiddenDb]!).readAsString(),
        await File(p.join(docs, 'halo_v.db')).readAsString(),
      );
    });

    test(
      'before the backup reads it: no file, never one without them',
      () async {
        await _phone(docs);
        await openVault();
        kryfo.lockingUp();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(vault.closed, isTrue);
        await expectLater(
          draftBackup(stage, side: side, hidden: true),
          throwsA(
            isA<BackupError>().having(
              (e) => e.message,
              'message',
              l10n.backupHiddenGone,
            ),
          ),
        );
        expect(File(p.join(stage, 'halo.db')).existsSync(), isFalse);
        expect(File(p.join(stage, kHiddenDb)).existsSync(), isFalse);
      },
    );
  });

  group('a backup from the setup flow', () {
    test('carries the new vault while it is at hand, and never '
        'moves', () async {
      await _phone(docs);
      expect(backupShape(quiet: false, open: false, setup: true, move: true), (
        hidden: true,
        made: true,
        move: false,
      ));
      expect(await kryfo.createVault(vaultPin), isTrue);
      side
        ..docs = docs
        ..madeKey = () => host.entry;
      final d = await draftBackup(stage, side: side, hidden: true, made: true);
      expect(d.manifest['moved'], isFalse);
      expect(d.manifest['vault'], {'key': host.entry});
      expect(
        _names(d.manifest),
        containsAll([
          kHiddenDb,
          'vault/media/h1.jpg',
          'vault/wallpapers/hw.jpg',
        ]),
      );
      // the list of the chats it hid goes along
      expect(side.scrubbedWith, isNull);
      await expectLater(
        draftBackup(stage, side: side, hidden: true, made: true, move: true),
        throwsArgumentError,
      );
    });

    testWidgets('the offer opens a backup that holds them', (t) async {
      phone(t);
      await t.pumpWidget(
        app(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => const PinsHost().backup(ctx),
              child: const Text('offer'),
            ),
          ),
        ),
      );
      await t.tap(find.text('offer'));
      await t.pumpAndSettle();
      expect(
        t.widget<BackupScreen>(find.byType(BackupScreen)).withHiddenChats,
        isTrue,
      );
    });

    test('once the lock took the new vault, makes no file', () async {
      await _phone(docs);
      expect(await kryfo.createVault(vaultPin), isTrue);
      kryfo.lockingUp();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      side
        ..docs = docs
        ..madeKey = () => host.entry;
      await expectLater(
        draftBackup(stage, side: side, hidden: true, made: true),
        throwsA(isA<BackupError>()),
      );
    });
  });

  group('the dev chat\'s made name', () {
    test('an everyday backup and a move leave it behind, and the chat goes '
        'along', () async {
      for (final move in [false, true]) {
        await _phone(docs);
        side.devScrubbed.clear();
        final d = await draftBackup(stage, side: side, move: move);
        expect(side.devScrubbed, [_dbPass], reason: '$move');
        final carried = await _read(d.sources['halo.db']!);
        expect(_madeName(carried), isEmpty, reason: '$move');
        final r = DevChatRow.of(carried['devchat']!.single);
        expect(r.state, DevState.anon);
        expect(r.keyId, 'm1');
        expect(r.startedAt, 2);
        // the phone keeps it, and all else goes as it was
        final own = await _read(p.join(docs, 'halo.db'));
        expect(_madeName(own), hasLength(9));
        expect(_uids(carried), {'v0'});
        expect(carried['sessions']!.length, 1);
      }
    });

    test('a backup with hidden chats open leaves it behind too, and the '
        'vault file never held it', () async {
      await _phone(docs);
      await openVault();
      final d = await draftBackup(stage, side: side, hidden: true);
      expect(side.devScrubbed, [_dbPass]);
      final carried = await _read(d.sources['halo.db']!);
      expect(_madeName(carried), isEmpty);
      expect(carried['hidden_chats']!.length, 3);
      expect(_madeName(await _read(d.sources[kHiddenDb]!)), isEmpty);
    });

    test('a restore lands the chat without it: it reads, and sends and '
        'hears nothing', () async {
      await _phone(docs);
      final out = await _write(await draftBackup(stage, side: side), root.path);
      final docs2 = p.join(root.path, 'docs2');
      Directory(docs2).createSync();
      docsAt(docs2);
      await unpackBackup(out, _Cipher(), root: docs2);
      final landed = await _read(p.join(docs2, 'halo.db'));
      expect(_madeName(landed), isEmpty);
      final r = DevChatRow.of(landed['devchat']!.single);
      expect(r.nameless, isTrue);
      final k = DevKey(
        keyId: 'm1',
        threeWords: 'scare-raven-rare',
        xPub: '0f' * 32,
        bundle: 'b',
        fc: '1e' * 32,
      );
      expect(DevGate.relayWay(r, k, 'c', (_) => true), DevWay.refused);
      expect(DevGate.listenWay(r, k), DevWay.refused);
    });

    // the checks above would catch the scrub gone
    test('a draft that forgets it is caught', () async {
      await _phone(docs);
      final d = await draftBackup(stage, side: _Forgets(kryfo));
      expect(_madeName(await _read(d.sources['halo.db']!)), hasLength(9));
    });
  });

  group('the decoy backup', () {
    // a decoy beside a phone with hidden chats, and hidden chats of its own
    Future<_Db> decoyPhone() async {
      await _phone(docs);
      await _put(p.join(docs, 'halo_d.db'), jsonEncode(_decoy()));
      await _put(p.join(docs, 'media_d', 'd1.jpg'), 'decoy photo');
      await _put(p.join(docs, 'halo_dv.db'), 'the decoy vault');
      await _put(p.join(docs, 'media_dv', 'dv.jpg'), 'decoy hidden photo');
      FlutterSecureStorage.setMockInitialValues({
        'halo.d.key': "x'${'2e' * 32}'",
      });
      return _Db(HaloContainer.decoy, docs)
        ..mem = _MemDb(p.join(root.path, 'unused'), {
          'signal_meta': [
            {'k': 'onion_key', 'v': '0a0b0c'},
          ],
        });
    }

    test('is as it was: the decoy alone, nothing hidden', () async {
      final decoy = await decoyPhone();
      useDatabasesForTest(live, Session(decoy));
      expect(sessionQuiet, isTrue);
      expect(sessionBackupHasHidden, isFalse);
      expect(backupShape(quiet: true, open: false, setup: false, move: true), (
        hidden: false,
        made: false,
        move: false,
      ));
      final d = await draftQuietBackup(stage, side: side);
      expect(d.manifest.keys.toSet(), {
        'v',
        'ts',
        'haloId',
        'moved',
        'edPriv',
        'xPriv',
        'dbPassphrase',
        'prefs',
        'secure',
        'onboardingDone',
        'chunk',
        'files',
      });
      expect(d.manifest['v'], 2);
      expect(d.manifest['moved'], isFalse);
      // set up, as boot reads it, wherever the file is restored
      expect(d.manifest['onboardingDone'], 'true');
      expect(d.manifest['edPriv'], 'decoy-ed');
      expect(d.manifest['dbPassphrase'], "x'${'2e' * 32}'");
      expect(_names(d.manifest), ['halo.db', 'onion.key', 'media/d1.jpg']);
      // the decoy's own chats, without the name its dev chat was made with
      final carried = await _read(d.sources['halo.db']!);
      expect(_uids(carried), {'d0'});
      expect(_madeName(carried), isEmpty);
      expect(side.devScrubbed, ["x'${'2e' * 32}'"]);
      expect(_madeName(await _read(p.join(docs, 'halo_d.db'))), isNotEmpty);
      expect(await File(d.sources['onion.key']!).readAsBytes(), [10, 11, 12]);
    });

    test('with its own hidden chats open holds them as an everyday one '
        'does, never the everyday side\'s, and never moves', () async {
      final decoy = await decoyPhone();
      final dv = _Db(
        HaloContainer.decoyVault,
        docs,
        key: '3c' * 32,
        held: (people: {_m: true}, groups: const <String>{}),
      );
      decoy.held = (people: const <String, bool>{}, groups: const <String>{});
      useDatabasesForTest(live, await Session.withVault(decoy, dv));
      expect(sessionBackupHasHidden, isTrue);
      final shape = backupShape(
        quiet: true,
        open: true,
        setup: false,
        move: true,
      );
      expect(shape, (hidden: true, made: false, move: false));
      final d = await draftQuietBackup(stage, side: side, hidden: true);
      expect(d.manifest['v'], kBackupVersionHidden);
      expect(d.manifest['moved'], isFalse);
      expect(d.manifest['vault'], {'key': '3c' * 32});
      expect(_names(d.manifest), [
        'halo.db',
        'onion.key',
        'media/d1.jpg',
        kHiddenDb,
        'vault/media/dv.jpg',
      ]);
      expect(
        await File(d.sources[kHiddenDb]!).readAsString(),
        'the decoy vault',
      );
      // a restore in a decoy lands them in the decoy's own vault
      final out = await _write(d, root.path);
      final hiddenAt = p.join(docs, 'restore_hidden');
      final land = p.join(root.path, 'restore_d');
      Directory(land).createSync();
      final back = await unpackBackup(
        out,
        _Cipher(),
        root: land,
        hidden: hiddenAt,
      );
      await landHidden(
        docs,
        hiddenAt,
        back,
        clearEntry: () async {},
        into: HaloContainer.decoyVault,
      );
      expect(
        await File(p.join(docs, 'halo_dv.db')).readAsString(),
        'the decoy vault',
      );
      expect(
        await File(p.join(docs, 'media_dv', 'dv.jpg')).readAsString(),
        'decoy hidden photo',
      );
      // the everyday vault is not touched
      expect(
        await File(p.join(docs, 'halo_v.db')).readAsString(),
        jsonEncode(_vault()),
      );
      expect(restoredHidden, isTrue);
    });

    test('from the decoy\'s setup, with the lock gone first: no '
        'file', () async {
      final decoy = await decoyPhone();
      useDatabasesForTest(live, Session(decoy));
      final shape = backupShape(
        quiet: true,
        open: false,
        setup: true,
        move: true,
      );
      expect(shape, (hidden: true, made: true, move: false));
      await expectLater(
        draftQuietBackup(stage, side: side, hidden: true, made: true),
        throwsA(isA<BackupError>()),
      );
    });

    // a log of the old database left beside the restored one would be
    // played over it on the next open
    test('a restore into it lands where nothing of the old one is left, '
        'and stops at a file that will not go', () async {
      final decoy = await decoyPhone();
      useDatabasesForTest(live, Session(decoy));
      final from = p.join(root.path, 'restore_d');
      final manifest = <String, dynamic>{
        'files': [
          {'name': 'halo.db', 'size': 8},
        ],
        'dbPassphrase': "x'${'4d' * 32}'",
      };
      await _put(p.join(from, 'halo.db'), 'restored');
      await landQuietRestore(from, docs, manifest);
      expect(await File(p.join(docs, 'halo_d.db')).readAsString(), 'restored');
      expect(
        await const FlutterSecureStorage().read(key: 'halo.d.key'),
        "x'${'4d' * 32}'",
      );

      await _put(p.join(from, 'halo.db'), 'restored again');
      // a folder where the log is: it cannot be deleted as a file
      await _put(p.join(docs, 'halo_d.db-wal', 'x'), 'held');
      await expectLater(
        landQuietRestore(from, docs, manifest),
        throwsA(isA<FileSystemException>()),
      );
      // nothing of the backup landed
      expect(File(p.join(from, 'halo.db')).existsSync(), isTrue);
    });
  });

  group('the backup screen', () {
    Future<void> show(
      WidgetTester t, {
      bool setup = false,
      bool still = false,
      Locale locale = const Locale('en'),
    }) async {
      await t.pumpWidget(
        app(
          BackupScreen(withHiddenChats: setup),
          still: still,
          locale: locale,
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> choose(WidgetTester t, String title) async {
      await t.tap(find.text(title));
      await t.pumpAndSettle();
    }

    testWidgets('outside the hidden chats: the move line on every move, '
        'with and without them, the same tree either way', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      final trees = <String>[];
      for (final withVault in [false, true]) {
        await t.runAsync(() => _phone(docs, hidden: withVault));
        await show(t);
        expect(_heard(t, l10n.backupHiddenNotIn), isTrue);
        expect(_heard(t, l10n.backupMoveHiddenStay), isFalse);
        expect(_heard(t, l10n.backupHiddenIncluded), isFalse);
        final copy = _tree(t);
        await choose(t, l10n.backupMoveToAnotherDevice);
        expect(_heard(t, l10n.backupMoveHiddenStay), isTrue);
        expect(_heard(t, l10n.backupHiddenNotIn), isFalse);
        trees.add('$copy\n${_tree(t)}');
        await t.pumpWidget(const SizedBox());
      }
      expect(trees[1], trees[0]);
      h.dispose();
    });

    testWidgets('a decoy reads as the everyday session does', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      await show(t);
      final everyday = _tree(t);
      await t.pumpWidget(const SizedBox());
      useDatabasesForTest(live, Session(_Db(HaloContainer.decoy, docs)));
      await show(t);
      expect(_tree(t), everyday);
      await choose(t, l10n.backupMoveToAnotherDevice);
      expect(_heard(t, l10n.backupMoveHiddenStay), isTrue);
      h.dispose();
    });

    testWidgets('inside the hidden chats: they are in it, and no move line, '
        'since they move along; a decoy\'s own read the same', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      final trees = <String>[];
      final decoy = _Db(
        HaloContainer.decoy,
        docs,
        held: (people: const <String, bool>{}, groups: const <String>{}),
      );
      final dv = _Db(
        HaloContainer.decoyVault,
        docs,
        held: (people: {_m: true}, groups: const <String>{}),
      );
      for (final open in [
        openVault,
        () async =>
            useDatabasesForTest(live, await Session.withVault(decoy, dv)),
      ]) {
        await t.runAsync(open);
        await show(t);
        expect(_heard(t, l10n.backupHiddenIncluded), isTrue);
        expect(_heard(t, l10n.backupHiddenNotIn), isFalse);
        final copy = _tree(t);
        await choose(t, l10n.backupMoveToAnotherDevice);
        expect(_heard(t, l10n.backupHiddenIncluded), isTrue);
        expect(find.text(l10n.backupMoveHiddenStay), findsNothing);
        trees.add('$copy\n${_tree(t)}');
        await t.pumpWidget(const SizedBox());
      }
      expect(trees[1], trees[0]);
      h.dispose();
    });

    testWidgets('from the setup: a copy that holds them, no move to '
        'choose', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      await show(t, setup: true);
      expect(find.text(l10n.backupMoveToAnotherDevice), findsNothing);
      expect(find.text(l10n.backupBackUp), findsNothing);
      expect(_heard(t, l10n.backupHiddenIncluded), isTrue);
      expect(find.text(l10n.backupMoveHiddenStay), findsNothing);
      h.dispose();
    });

    testWidgets('with reduced motion the line changes at once', (t) async {
      phone(t);
      await show(t, still: true);
      await t.tap(find.text(l10n.backupMoveToAnotherDevice));
      await t.pump();
      final fades = t.widgetList<AnimatedOpacity>(
        find.ancestor(
          of: find.text(l10n.backupMoveHiddenStay),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fades, isNotEmpty);
      for (final f in fades) {
        expect(f.duration, Duration.zero);
        expect(f.opacity, 1);
      }
    });

    testWidgets('right to left puts the mark at the start', (t) async {
      phone(t);
      setL10nLocale(const Locale('ar'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await show(t, locale: const Locale('ar'));
      final mark = t.getCenter(
        find.byIcon(Icons.visibility_off_outlined).first,
      );
      final line = t.getCenter(find.text(l10n.backupHiddenNotIn));
      expect(mark.dx, greaterThan(line.dx));
      expect(t.takeException(), isNull);
    });
  });

  group('choosing the new hidden chats PIN after a restore', () {
    // a restore that brought hidden chats, waiting for their pin
    Future<void> restored() async {
      final from = p.join(root.path, 'from');
      await _put(p.join(from, 'halo_v.db'), jsonEncode(_vault()));
      await landHidden(docs, from, {
        'vault': {'key': vaultKey},
        'files': [
          {'name': kHiddenDb, 'size': 1},
        ],
      }, clearEntry: () async {});
    }

    Future<void> open(
      WidgetTester t,
      Lock lock, {
      bool still = false,
      Locale locale = const Locale('en'),
    }) async {
      await t.pumpWidget(app(const SizedBox(), still: still, locale: locale));
      final nav = t.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        nav.push(
          MaterialPageRoute<bool>(
            builder: (_) => PinFlowScreen(
              flow: PinFlow.vault,
              restoring: true,
              lock: lock.state,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> pin(WidgetTester t, String digits) async {
      await typePin(t, digits);
      await enter(t);
      await t.pumpAndSettle();
    }

    testWidgets('with no app lock: the app PIN first, then theirs, and '
        'no way back out', (t) async {
      phone(t);
      await t.runAsync(restored);
      final lock = await makeLock(null);
      await open(t, lock);
      expect(find.text(l10n.restoreChooseHiddenPin), findsOneWidget);
      expect(find.text(l10n.restoreHiddenLockFirst), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text(l10n.restoreChooseHiddenPin), findsOneWidget);
      await press(t, find.text(l10n.commonContinue));
      await t.pumpAndSettle();
      expect(find.text(l10n.lockSetupSetAPin), findsOneWidget);
      await pin(t, '135791');
      expect(find.text(l10n.panicSetupOnceMore), findsOneWidget);
      await pin(t, '135791');
      expect(lock.state.enabled, isTrue);
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      // six digits or more here
      await typePin(t, '24681');
      await enter(t);
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      await typePin(t, '0');
      await enter(t);
      await t.pumpAndSettle();
      await pin(t, vaultPin);
      expect(find.text(l10n.flowVaultForget), findsOneWidget);
      await press(t, find.text(l10n.flowVaultForgetOk));
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultDone), findsOneWidget);
      final e = lock.entries;
      expect((e['${PinSlot.app}'] as Map)['p'], '135791');
      expect((e['${PinSlot.vault}'] as Map)['p'], vaultPin);
      expect((e['${PinSlot.vault}'] as Map)['w'], vaultKey);
      expect(restoredHidden, isFalse);
      await press(t, find.text(l10n.commonDone));
      await t.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsNothing);
    });

    testWidgets('in the decoy with its lock turned off: the app PIN first, '
        'as anywhere with no lock', (t) async {
      phone(t);
      await t.runAsync(restored);
      final lock = await makeLock({
        PinSlot.app: (appPin, PinKind.everyday),
        PinSlot.decoy: (decoyPin, PinKind.decoy),
      }, inDecoy: true);
      await lock.state.disable();
      expect(lock.state.lockOn, isFalse);
      await open(t, lock);
      expect(find.text(l10n.restoreHiddenLockFirst), findsOneWidget);
      await press(t, find.text(l10n.commonContinue));
      await t.pumpAndSettle();
      expect(find.text(l10n.lockSetupSetAPin), findsOneWidget);
      await pin(t, '135791');
      await pin(t, '135791');
      expect(lock.state.lockOn, isTrue);
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
    });

    testWidgets('with an app lock: straight to their PIN; one in use asks '
        'for another', (t) async {
      phone(t);
      await t.runAsync(restored);
      final lock = await makeLock(appOnly);
      await open(t, lock);
      expect(find.text(l10n.restoreHiddenLockFirst), findsNothing);
      await press(t, find.text(l10n.commonContinue));
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      // four digits do not go in here
      await pin(t, '1234');
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      await pin(t, '56');
      expect(find.text(l10n.panicSetupOnceMore), findsOneWidget);
      await pin(t, '123456');
      await press(t, find.text(l10n.flowVaultForgetOk));
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultDone), findsOneWidget);
      expect((lock.entries['${PinSlot.vault}'] as Map)['w'], vaultKey);
      expect((lock.entries['${PinSlot.app}'] as Map)['p'], appPin);
    });

    testWidgets('a clash says only Pick a different PIN', (t) async {
      phone(t);
      await t.runAsync(restored);
      final lock = await makeLock({
        PinSlot.app: (appPin, PinKind.everyday),
        PinSlot.wipe: ('999999', PinKind.wipe),
      });
      await open(t, lock);
      await press(t, find.text(l10n.commonContinue));
      await t.pumpAndSettle();
      await pin(t, '999999');
      await pin(t, '999999');
      await press(t, find.text(l10n.flowVaultForgetOk));
      await t.pumpAndSettle();
      expect(find.text(l10n.pinPickDifferent), findsOneWidget);
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      expect(restoredHidden, isTrue);
      await pin(t, vaultPin);
      await pin(t, vaultPin);
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultDone), findsOneWidget);
    });

    testWidgets('right to left and reduced motion', (t) async {
      phone(t);
      setL10nLocale(const Locale('ar'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.runAsync(restored);
      final lock = await makeLock(null);
      await open(t, lock, still: true, locale: const Locale('ar'));
      expect(find.text(l10n.restoreChooseHiddenPin), findsOneWidget);
      await press(t, find.text(l10n.commonContinue));
      await t.pump();
      await t.pump();
      // no slide: the next page is there at once
      expect(find.text(l10n.lockSetupSetAPin), findsOneWidget);
      expect(find.text(l10n.restoreChooseHiddenPin), findsNothing);
      expect(
        Directionality.of(t.element(find.text(l10n.lockSetupSetAPin))),
        TextDirection.rtl,
      );
      expect(t.takeException(), isNull);
    });
  });
}
