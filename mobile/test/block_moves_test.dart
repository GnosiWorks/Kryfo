// SPDX-License-Identifier: GPL-3.0-or-later
// a group moved into the vault, or back, takes its people's block spans
// and the uids dropped from them along with their rows. someone the move
// takes out of one side leaves none of it there, so a span left open never
// holds over them if they are added again. a person's device state (linked
// devices) goes with their own chat, and only with the switch on. the
// move's own sql, run on real sqlite with the vault attached; with no
// sqlite the tests are skipped
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_state.dart'
    show DeviceEngine, DeviceState, linkedDevicesForTest;
import 'package:kryfo/main.dart'
    show HaloDb, blockTables, deviceStateForTest, goneKey;
import 'package:kryfo/router.dart';
import 'package:kryfo/vault_life.dart';

import 'sqlite_ffi.dart';

const _g = 'g1group00001';
// blocked, known by key alone, named by nothing but the group
const _m = 'blocked-key-only';
// a contact with a chat of their own, who stays
const _f = 'friend-stays-here';

// the engine's pins: [listed] by device; a list is held
class _Pins implements DeviceEngine {
  _Pins(this.listed);
  final Map<int, String> listed;
  @override
  String call(String op, Map<String, Object?> args) {
    if (op == 'current') return '{"rows":[]}';
    final k = listed[args['device']];
    return jsonEncode({
      'rows': [],
      if (k == null) 'err': 'not_listed' else 'key': k,
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoDb implements HaloDb {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// what a move reads and writes, in [s]
Future<void> _tables(SqliteMem db, String s) async {
  for (final t in [
    'CREATE TABLE $s.contacts (halo_id TEXT PRIMARY KEY, onion TEXT, '
        'xpub TEXT, first_seen INTEGER, last_seen INTEGER, back_paired '
        'INTEGER DEFAULT 0, blocked INTEGER DEFAULT 0, accepted INTEGER '
        'DEFAULT 1, ident INTEGER NOT NULL DEFAULT 0, ikey TEXT)',
    'CREATE TABLE $s.groups (group_id TEXT PRIMARY KEY, name TEXT)',
    'CREATE TABLE $s.group_members (group_id TEXT, halo_id TEXT, '
        'PRIMARY KEY (group_id, halo_id))',
    'CREATE TABLE $s.messages (id INTEGER PRIMARY KEY, msg_uid TEXT, '
        'peer_id TEXT, group_id TEXT, plaintext TEXT, poll TEXT, '
        'file_name TEXT, preview TEXT, sticker TEXT, media_path TEXT, '
        'file_path TEXT)',
    'CREATE TABLE $s.msg_fts (body TEXT)',
    'CREATE TABLE $s.polls_gone (uid TEXT)',
    'CREATE TABLE $s.reactions (msg_uid TEXT, reactor TEXT)',
    'CREATE TABLE $s.poll_votes (poll_uid TEXT, voter TEXT)',
    'CREATE TABLE $s.pins_out (msg_uid TEXT PRIMARY KEY)',
    'CREATE TABLE $s.edits_out (msg_uid TEXT PRIMARY KEY)',
    'CREATE TABLE $s.frame_order (msg_uid TEXT, sender TEXT, kind TEXT, '
        'w INTEGER)',
    'CREATE TABLE $s.group_media_owed (group_id TEXT, member TEXT)',
    'CREATE TABLE $s.group_ctl_out (id INTEGER PRIMARY KEY, group_id TEXT)',
    'CREATE TABLE $s.group_roster (group_id TEXT PRIMARY KEY)',
    'CREATE TABLE $s.held_onion (id INTEGER PRIMARY KEY, peer_id TEXT)',
    'CREATE TABLE $s.media_wants (media_id TEXT, peer_id TEXT)',
    'CREATE TABLE $s.media_chunks (media_id TEXT, idx INTEGER, '
        'sender TEXT, group_id TEXT)',
    'CREATE TABLE $s.room_keys (group_id TEXT, member TEXT)',
    'CREATE TABLE $s.vouches (halo_id TEXT, voucher_id TEXT)',
    'CREATE TABLE $s.shield (halo_id TEXT PRIMARY KEY)',
    'CREATE TABLE $s.notif_tags (chat TEXT PRIMARY KEY, tag TEXT NOT NULL '
        'UNIQUE)',
    'CREATE TABLE $s.notif_rings (id INTEGER PRIMARY KEY, chat TEXT, '
        'msg_uid TEXT, at INTEGER)',
    'CREATE TABLE $s.gone_in (msg_uid TEXT, peer_id TEXT, at INTEGER, '
        'PRIMARY KEY (msg_uid, peer_id))',
    'CREATE TABLE $s.group_resent (group_id TEXT, member TEXT, since '
        'INTEGER, at INTEGER, PRIMARY KEY (group_id, member, since))',
    'CREATE TABLE $s.wallpapers (chat TEXT PRIMARY KEY, atmo TEXT NOT NULL, '
        'photo BLOB)',
    'CREATE TABLE $s.drafts (chat TEXT PRIMARY KEY, body TEXT NOT NULL, '
        'reply_to TEXT, updated_at INTEGER NOT NULL, burn_secs INTEGER)',
    // a person's own, for a chat with them moved alone
    'CREATE TABLE $s.frames_out (id INTEGER PRIMARY KEY, peer_id TEXT)',
    'CREATE TABLE $s.first_kept (hash TEXT PRIMARY KEY, peer TEXT)',
    'CREATE TABLE $s.opener_again (msg_uid TEXT PRIMARY KEY)',
  ]) {
    await db.execute(t);
  }
}

Future<SqliteMem> _world() async {
  final db = SqliteMem.open()!;
  await db.execute("ATTACH DATABASE ':memory:' AS v");
  await _tables(db, 'main');
  await _tables(db, 'v');
  // the app's own on the everyday side, its trigger with them
  await blockTables(db);
  await db.execute(
    'CREATE TABLE v.block_spans (peer_id TEXT NOT NULL, '
    'from_at INTEGER NOT NULL, to_at INTEGER)',
  );
  await db.execute(
    'CREATE TABLE v.blocked_drops (peer_id TEXT NOT NULL, uid TEXT NOT '
    'NULL, at INTEGER NOT NULL, PRIMARY KEY (peer_id, uid))',
  );
  await db.execute("INSERT INTO main.groups VALUES ('$_g', 'night shift')");
  for (final who in ['me', _m, _f]) {
    await db.execute("INSERT INTO main.group_members VALUES ('$_g', '$who')");
  }
  await db.execute(
    'INSERT INTO main.contacts (halo_id, onion, xpub, first_seen, last_seen, '
    "blocked, accepted) VALUES ('$_m', 'o-m', 'x-m', 1, 1, 1, 0), "
    "('$_f', 'o-f', 'x-f', 1, 1, 0, 1)",
  );
  // her own chat keeps her on the everyday side
  await db.execute(
    "INSERT INTO main.messages (msg_uid, peer_id) VALUES ('f1', '$_f')",
  );
  await db.execute(
    'INSERT INTO main.block_spans (peer_id, from_at, to_at) VALUES '
    "('$_m', 10, 50), ('$_m', 100, NULL), ('$_f', 20, 30)",
  );
  await db.execute(
    'INSERT INTO main.blocked_drops (peer_id, uid, at) VALUES '
    "('$_m', 'u1', 5), ('$_f', 'f-drop', 6)",
  );
  return db;
}

Future<List<String>> _rows(SqliteMem db, String s, String who) async => [
  for (final r in await db.rawQuery(
    'SELECT from_at, to_at FROM $s.block_spans WHERE peer_id = ? '
    'ORDER BY from_at',
    [who],
  ))
    'span ${r['from_at']}-${r['to_at']}',
  for (final r in await db.rawQuery(
    'SELECT uid FROM $s.blocked_drops WHERE peer_id = ? ORDER BY uid',
    [who],
  ))
    'drop ${r['uid']}',
];

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  const group = ChatRef(_g, group: true);

  test('a group into the vault takes its blocked member\'s spans and drops, '
      'and leaves none of them behind', () async {
    final db = await _world();
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    // the vault holds them blocked, and knows when
    expect(
      await db.rawQuery("SELECT blocked FROM v.contacts WHERE halo_id = '$_m'"),
      [
        {'blocked': 1},
      ],
    );
    expect(await _rows(db, 'v', _m), [
      'span 10-50',
      'span 100-null',
      'drop u1',
    ]);
    // the everyday side has no row of theirs, and nothing of the block
    expect(
      await db.rawQuery("SELECT 1 FROM main.contacts WHERE halo_id = '$_m'"),
      isEmpty,
    );
    expect(await _rows(db, 'main', _m), isEmpty);
    // she stays, with what is hers, and the vault's key-only row of her
    // carries the same
    expect(await _rows(db, 'main', _f), ['span 20-30', 'drop f-drop']);
    expect(await _rows(db, 'v', _f), ['span 20-30', 'drop f-drop']);
  }, skip: skip);

  test('the files still coming in a group go with it, its members\' own '
      'stay', () async {
    final db = await _world();
    await db.execute(
      'INSERT INTO main.media_chunks (media_id, idx, sender, group_id) '
      "VALUES ('in-group', 0, '$_m', '$_g'), ('her-own', 0, '$_f', NULL)",
    );
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    Future<List<Object?>> ids(String s) async => [
      for (final r in await db.rawQuery(
        'SELECT media_id FROM $s.media_chunks ORDER BY media_id',
      ))
        r['media_id'],
    ];
    expect(await ids('v'), ['in-group']);
    expect(await ids('main'), ['her-own']);
  }, skip: skip);

  test('what came in from a hidden group and went goes with it, its '
      'members\' own and another group\'s stay', () async {
    final db = await _world();
    for (final (uid, key) in [
      ('in-group', goneKey(_f, group: _g)),
      ('from-him', goneKey(_m, group: _g)),
      ('her-own', goneKey(_f)),
      ('elsewhere', goneKey(_f, group: '${_g}x')),
    ]) {
      await db.execute(
        'INSERT INTO main.gone_in (msg_uid, peer_id, at) VALUES (?, ?, 1)',
        [uid, key],
      );
    }
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    Future<List<Object?>> uids(String s) async => [
      for (final r in await db.rawQuery(
        'SELECT msg_uid FROM $s.gone_in ORDER BY msg_uid',
      ))
        r['msg_uid'],
    ];
    expect(await uids('v'), ['from-him', 'in-group']);
    expect(await uids('main'), ['elsewhere', 'her-own']);
  }, skip: skip);

  test('and back out again, the same the other way', () async {
    final db = await _world();
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    await mover.moveRowsOn(db, group, intoVault: false);
    expect(await _rows(db, 'main', _m), [
      'span 10-50',
      'span 100-null',
      'drop u1',
    ]);
    expect(await _rows(db, 'v', _m), isEmpty);
    expect(await _rows(db, 'v', _f), isEmpty);
    // her own rows are not doubled by the way back
    expect(await _rows(db, 'main', _f), ['span 20-30', 'drop f-drop']);
  }, skip: skip);

  Future<List<String>> tags(SqliteMem db, String s) async => [
    for (final r in await db.rawQuery(
      'SELECT chat, tag FROM $s.notif_tags ORDER BY chat',
    ))
      '${r['chat']} ${r['tag']}',
  ];

  test('a moved chat\'s notification tag goes with nothing copied', () async {
    final db = await _world();
    await db.execute(
      "INSERT INTO main.notif_tags VALUES ('group:$_g', 'aa'), "
      "('$_f', 'bb'), ('$_m', 'dd')",
    );
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    // the member the group took out of here takes their request's tag too
    expect(await tags(db, 'main'), ['$_f bb']);
    expect(await tags(db, 'v'), isEmpty);
    await db.execute("INSERT INTO v.notif_tags VALUES ('group:$_g', 'cc')");
    await mover.moveRowsOn(db, group, intoVault: false);
    expect(await tags(db, 'v'), isEmpty);
    expect(await tags(db, 'main'), ['$_f bb']);
  }, skip: skip);

  test(
    'a group\'s marks of what went again after a restore move with it',
    () async {
      final db = await _world();
      await db.execute(
        "INSERT INTO main.group_resent VALUES ('$_g', '$_f', 0, 5), "
        "('other-group1', '$_f', 0, 5)",
      );
      final mover = SqlChatMover(_NoDb(), _NoDb());
      await mover.moveRowsOn(db, group, intoVault: true);
      Future<List<Object?>> marks(String s) async => [
        for (final r in await db.rawQuery(
          'SELECT group_id FROM $s.group_resent ORDER BY group_id',
        ))
          r['group_id'],
      ];
      expect(await marks('main'), ['other-group1']);
      expect(await marks('v'), [_g]);
      await mover.moveRowsOn(db, group, intoVault: false);
      expect(await marks('main'), [_g, 'other-group1']);
      expect(await marks('v'), isEmpty);
    },
    skip: skip,
  );

  test('a chat\'s wallpaper photo moves with it and back, byte for byte; '
      'the default and other chats\' stay', () async {
    final db = await _world();
    final photo = List.generate(5000, (i) => i % 256);
    for (final chat in ['group:$_g', _f, '']) {
      await db.execute(
        'INSERT INTO main.wallpapers (chat, atmo, photo) VALUES (?, ?, ?)',
        [chat, chat.isEmpty ? 'rain' : 'photo', photo],
      );
    }
    final mover = SqlChatMover(_NoDb(), _NoDb());
    Future<List<Object?>> walls(String s) async => [
      for (final r in await db.rawQuery(
        'SELECT chat FROM $s.wallpapers ORDER BY chat',
      ))
        r['chat'],
    ];
    await mover.moveRowsOn(db, group, intoVault: true);
    expect(await walls('v'), ['group:$_g']);
    expect(await walls('main'), ['', _f]);
    final there = await db.rawQuery(
      "SELECT photo FROM v.wallpapers WHERE chat = 'group:$_g'",
    );
    expect(there.single['photo'], photo);
    await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
    expect(await walls('v'), [_f, 'group:$_g']);
    expect(await walls('main'), ['']);
    await mover.moveRowsOn(db, group, intoVault: false);
    await mover.moveRowsOn(db, const ChatRef(_f), intoVault: false);
    expect(await walls('v'), isEmpty);
    expect(await walls('main'), ['', _f, 'group:$_g']);
  }, skip: skip);
  Future<List<Object?>> drafts(SqliteMem db, String s) async => [
    for (final r in await db.rawQuery(
      'SELECT chat, body FROM $s.drafts ORDER BY chat',
    ))
      '${r['chat']} ${r['body']}',
  ];

  test('a chat\'s draft moves with it and back, a group\'s too; other '
      'chats\' stay', () async {
    final db = await _world();
    for (final (chat, body) in [
      ('group:$_g', 'who brings'),
      (_f, 'see you'),
      ('other-chat', 'stays'),
    ]) {
      await db.execute(
        'INSERT INTO main.drafts (chat, body, updated_at) VALUES (?, ?, 1)',
        [chat, body],
      );
    }
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
    expect(await drafts(db, 'v'), ['$_f see you', 'group:$_g who brings']);
    expect(await drafts(db, 'main'), ['other-chat stays']);
    // shown again: out of the vault with them
    await mover.moveRowsOn(db, group, intoVault: false);
    await mover.moveRowsOn(db, const ChatRef(_f), intoVault: false);
    expect(await drafts(db, 'v'), isEmpty);
    expect(await drafts(db, 'main'), [
      '$_f see you',
      'group:$_g who brings',
      'other-chat stays',
    ]);
  }, skip: skip);

  test('a chat moved either way takes the nonces of its heals and the last '
      'heal on its row; another\'s nonce stays', () async {
    final db = await _world();
    for (final side in ['main', 'v']) {
      await db.execute(
        'CREATE TABLE $side.heal_nonces (ident INTEGER NOT NULL, nonce TEXT '
        'NOT NULL, at INTEGER NOT NULL, peer TEXT, PRIMARY KEY (ident, nonce))',
      );
      await db.execute(
        'ALTER TABLE $side.contacts ADD COLUMN heal_last INTEGER',
      );
    }
    await db.execute(
      'INSERT INTO main.heal_nonces (ident, nonce, at, peer) VALUES '
      "(0, 'n-f', 1, '$_f'), (0, 'n-other', 1, 'someone-else'), "
      "(0, 'n-old', 1, NULL)",
    );
    await db.execute(
      "UPDATE main.contacts SET heal_last = 490000 WHERE halo_id = '$_f'",
    );
    Future<List<Object?>> nonces(String s) async => [
      for (final r in await db.rawQuery(
        'SELECT nonce FROM $s.heal_nonces ORDER BY nonce',
      ))
        r['nonce'],
    ];
    Future<Object?> last(String s) async => (await db.rawQuery(
      'SELECT heal_last FROM $s.contacts WHERE halo_id = ?',
      [_f],
    )).single['heal_last'];
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
    expect(await nonces('v'), ['n-f']);
    expect(await nonces('main'), ['n-old', 'n-other']);
    expect(await last('v'), 490000);
    await mover.moveRowsOn(db, const ChatRef(_f), intoVault: false);
    expect(await nonces('v'), isEmpty);
    expect(await nonces('main'), ['n-f', 'n-old', 'n-other']);
    expect(await last('main'), 490000);
  }, skip: skip);

  // a person's devices
  {
    final fKey = '05${'aa' * 32}';
    final oKey = '05${'bb' * 32}';
    // a KDL2 as stored: the phone, then devices 5 and 9, a signature
    List<int> list() => [
      ...ascii.encode('KDL2'),
      ...List.filled(33, 5),
      ...List.filled(8, 0),
      3,
      for (final (id, b) in [(1, 0x05), (5, 0x55), (9, 0x99)]) ...[
        id,
        ...List.filled(33, b),
        0,
        0,
        3,
        9,
        id == 1 ? 1 : 0,
      ],
      ...List.filled(64, 7),
    ];

    Future<SqliteMem> world() async {
      final db = await _world();
      for (final s in ['main', 'v']) {
        for (final t in [
          'CREATE TABLE $s.dev_lists (ident INTEGER, owner TEXT, version '
              'INTEGER, wire BLOB, from_invite INTEGER DEFAULT 0, sent_ok '
              'INTEGER DEFAULT 0, PRIMARY KEY (ident, owner))',
          'CREATE TABLE $s.dev_proven (ident INTEGER, peer TEXT, key TEXT, '
              'PRIMARY KEY (ident, peer, key))',
          'CREATE TABLE $s.dev_pq (ident INTEGER, peer TEXT, '
              'PRIMARY KEY (ident, peer))',
          'CREATE TABLE $s.dev_quiet (ident INTEGER, peer TEXT, device '
              'INTEGER, key TEXT, PRIMARY KEY (ident, peer, device))',
          'CREATE TABLE $s.dev_held_openers (id INTEGER PRIMARY KEY '
              'AUTOINCREMENT, ident INTEGER, peer TEXT, device INTEGER, '
              'cipher BLOB, came_at INTEGER)',
          'CREATE TABLE $s.dev_pushes (ident INTEGER, peer TEXT, version '
              'INTEGER, kind TEXT, due_at INTEGER, '
              'PRIMARY KEY (ident, peer, version, kind))',
          'CREATE TABLE $s.dev_out (uid TEXT, ident INTEGER, peer TEXT, '
              'device INTEGER, at INTEGER, '
              'PRIMARY KEY (uid, ident, peer, device))',
          'CREATE TABLE $s.dev_openers (ident INTEGER, peer TEXT, '
              'their_device INTEGER, my_device INTEGER, at INTEGER, key TEXT, '
              'PRIMARY KEY (ident, peer, their_device, my_device))',
          'CREATE TABLE $s.dev_marks (ident INTEGER, peer TEXT, kind TEXT, '
              'key TEXT, at INTEGER, PRIMARY KEY (ident, peer, kind, key))',
          'CREATE TABLE $s.pairs (ident INTEGER, peer TEXT, their_device '
              'INTEGER, my_device INTEGER, conv INTEGER, seed BLOB, '
              'PRIMARY KEY (ident, peer, their_device, my_device))',
          'CREATE TABLE $s.sessions (ident INTEGER, address TEXT, device_id '
              'INTEGER, record BLOB, PRIMARY KEY (ident, address, device_id))',
          'ALTER TABLE $s.contacts ADD COLUMN verified_key TEXT',
          'ALTER TABLE $s.contacts ADD COLUMN caps TEXT',
          if (s == 'v')
            'ALTER TABLE v.block_spans ADD COLUMN listen_from INTEGER',
        ]) {
          await db.execute(t);
        }
      }
      await db.execute(
        "UPDATE main.contacts SET ikey = '$fKey' WHERE halo_id = '$_f'",
      );
      await db.execute(
        'INSERT INTO main.contacts (halo_id, onion, xpub, first_seen, '
        "last_seen, accepted, ikey) VALUES ('other', 'o', 'x', 1, 1, 1, "
        "'$oKey')",
      );
      for (final k in [fKey, oKey]) {
        await db.execute(
          'INSERT INTO main.dev_lists (ident, owner, version, wire) '
          'VALUES (0, ?, 7, ?)',
          [k, list()],
        );
        for (final t in ['dev_proven', 'dev_quiet']) {
          await db.execute(
            'INSERT INTO main.$t (ident, peer, ${t == 'dev_quiet' ? 'device, ' : ''}key) '
            "VALUES (0, ?, ${t == 'dev_quiet' ? '9, ' : ''}'k')",
            [k],
          );
        }
        await db.execute('INSERT INTO main.dev_pq VALUES (0, ?)', [k]);
        await db.execute(
          'INSERT INTO main.dev_held_openers (ident, peer, device, cipher, '
          "came_at) VALUES (0, ?, 9, x'01', 1)",
          [k],
        );
        await db.execute(
          "INSERT INTO main.dev_pushes VALUES (0, ?, 7, 'add', 1)",
          [k],
        );
        await db.execute("INSERT INTO main.dev_out VALUES ('u', 0, ?, 5, 1)", [
          k,
        ]);
        await db.execute(
          "INSERT INTO main.dev_openers VALUES (0, ?, 5, 1, 0, 'k')",
          [k],
        );
        await db.execute(
          "INSERT INTO main.dev_marks VALUES (0, ?, 'dq', '5', 1)",
          [k],
        );
        // the phone pair, the chat's own, and a device pair with its seed
        await db.execute(
          'INSERT INTO main.pairs VALUES (0, ?, 1, 1, 3, NULL), '
          '(0, ?, 5, 1, 4, ?)',
          [k, k, List.filled(32, 0x11)],
        );
      }
      for (final who in [_f, 'other']) {
        await db.execute(
          "INSERT INTO main.sessions VALUES (0, ?, 1, x'01'), "
          "(0, ?, 5, x'05')",
          [who, who],
        );
      }
      return db;
    }

    // what [s] holds of each of the two: device rows, pairs, sessions
    Future<Map<String, int>> held(SqliteMem db, String s, String k) async {
      final out = <String, int>{};
      for (final t in [
        'dev_lists',
        'dev_proven',
        'dev_pq',
        'dev_quiet',
        'dev_held_openers',
        'dev_pushes',
        'dev_out',
        'dev_openers',
        'dev_marks',
      ]) {
        final col = t == 'dev_lists' ? 'owner' : 'peer';
        out[t] = (await db.rawQuery('SELECT 1 FROM $s.$t WHERE $col = ?', [
          k,
        ])).length;
      }
      out['pairs'] = (await db.rawQuery(
        'SELECT 1 FROM $s.pairs WHERE peer = ? AND their_device != 1',
        [k],
      )).length;
      out['phone pair'] = (await db.rawQuery(
        'SELECT 1 FROM $s.pairs WHERE peer = ? AND their_device = 1',
        [k],
      )).length;
      final who = k == fKey ? _f : 'other';
      out['sessions'] = (await db.rawQuery(
        'SELECT 1 FROM $s.sessions WHERE address = ? AND device_id >= 2',
        [who],
      )).length;
      out['phone session'] = (await db.rawQuery(
        'SELECT 1 FROM $s.sessions WHERE address = ? AND device_id = 1',
        [who],
      )).length;
      return out;
    }

    Map<String, int> all(int devices, int phone) => {
      for (final t in [
        'dev_lists',
        'dev_proven',
        'dev_pq',
        'dev_quiet',
        'dev_held_openers',
        'dev_pushes',
        'dev_out',
        'dev_openers',
        'dev_marks',
        'pairs',
      ])
        t: devices,
      'phone pair': phone,
      'sessions': devices,
      'phone session': phone,
    };

    tearDown(() {
      linkedDevicesForTest = false;
      deviceStateForTest(null);
    });

    test('a device the engine holds their list without (disputed) is left '
        'off the card', () async {
      linkedDevicesForTest = true;
      final db = await world();
      final mover = SqlChatMover(_NoDb(), _NoDb());
      await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
      deviceStateForTest(DeviceState(_Pins({5: '55' * 33})));
      final card = RouterCard.fromJson(
        jsonDecode((await hiddenCard(db, const ChatRef(_f)))!),
        id: _f,
      )!;
      expect([for (final p in card.devices!.pairs) p.their], [5]);
      // under another key than its list's, it goes too
      deviceStateForTest(DeviceState(_Pins({5: '56' * 33, 9: '99' * 33})));
      final again = RouterCard.fromJson(
        jsonDecode((await hiddenCard(db, const ChatRef(_f)))!),
        id: _f,
      )!;
      expect([for (final p in again.devices!.pairs) p.their], [9]);
    }, skip: skip);

    test('go into the vault with their chat and back, none dropped; the '
        'phone pair and its session stay with the store, another\'s stay '
        'where they are; the card names the pairs to hear on', () async {
      linkedDevicesForTest = true;
      final db = await world();
      final mover = SqlChatMover(_NoDb(), _NoDb());
      await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
      expect(await held(db, 'v', fKey), all(1, 0));
      expect(await held(db, 'main', fKey), all(0, 1));
      expect(await held(db, 'main', oKey), all(1, 1));
      expect(await held(db, 'v', oKey), all(0, 0));
      // device 5 has a session and a seed: its seeded pair; 9 has neither:
      // its opener address
      final card = RouterCard.fromJson(
        jsonDecode((await hiddenCard(db, const ChatRef(_f)))!),
        id: _f,
      )!;
      final d = card.devices!;
      expect(d.identity, fKey);
      expect(d.ident, 0);
      expect(d.pairs, [
        (their: 5, my: 1, key: '55' * 33, seed: '11' * 32, opener: false),
        (their: 9, my: 1, key: '99' * 33, seed: null, opener: true),
      ]);
      expect(
        RouterCard.fromJson(jsonDecode(peerCard(card)))!.devices!.pairs,
        d.pairs,
      );
      await mover.moveRowsOn(db, const ChatRef(_f), intoVault: false);
      expect(await held(db, 'main', fKey), all(1, 1));
      expect(await held(db, 'v', fKey), all(0, 0));
    }, skip: skip);

    test('with the switch off nothing of them moves and the card is as '
        'before', () async {
      final db = await world();
      final mover = SqlChatMover(_NoDb(), _NoDb());
      await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
      expect(await held(db, 'main', fKey), all(1, 1));
      expect(await held(db, 'v', fKey), all(0, 0));
      // rows a switched build left there are not read for the card either
      await db.execute(
        'INSERT INTO v.dev_lists (ident, owner, version, wire) '
        'VALUES (0, ?, 7, ?)',
        [fKey, list()],
      );
      final card = (await hiddenCard(db, const ChatRef(_f)))!;
      expect(jsonDecode(card), isNot(contains('dv')));
      final r = RouterCard.fromJson(jsonDecode(card), id: _f)!;
      expect(r.devices, isNull);
      expect(peerCard(r), card);
    }, skip: skip);
  }

  for (final side in ['main', 'v']) {
    test(
      'a move goes on when $side has no drafts or wallpapers table',
      () async {
        final db = await _world();
        await db.execute(
          "INSERT INTO main.messages (msg_uid, peer_id, group_id) "
          "VALUES ('g1', '$_f', '$_g')",
        );
        await db.execute('DROP TABLE $side.drafts');
        await db.execute('DROP TABLE $side.wallpapers');
        final mover = SqlChatMover(_NoDb(), _NoDb());
        await mover.moveRowsOn(db, group, intoVault: true);
        await mover.moveRowsOn(db, const ChatRef(_f), intoVault: true);
        Future<List<Object?>> uids(String s) async => [
          for (final r in await db.rawQuery(
            'SELECT msg_uid FROM $s.messages ORDER BY msg_uid',
          ))
            r['msg_uid'],
        ];
        expect(await uids('v'), ['f1', 'g1']);
        expect(await uids('main'), isEmpty);
        await mover.moveRowsOn(db, group, intoVault: false);
        await mover.moveRowsOn(db, const ChatRef(_f), intoVault: false);
        expect(await uids('main'), ['f1', 'g1']);
        expect(await uids('v'), isEmpty);
      },
      skip: skip,
    );
  }
}
