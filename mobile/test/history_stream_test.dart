// SPDX-License-Identifier: GPL-3.0-or-later
// the history stream end to end: a phone's real schema in sqlite, the
// engine built for this computer, and a new device's database filled from
// the records alone. cut at every record, spoilt, sent twice, counted on
// both sides. skipped where the engine or sqlite is not here
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/history_export.dart';
import 'package:kryfo/devices/history_ffi.dart';
import 'package:kryfo/devices/history_import.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show searchTables;
import 'package:path/path.dart' as p;

import 'host_engine.dart';
import 'sqlite_ffi.dart';

// rfc 7748's first public key, as libsignal writes it
const _identity =
    '058520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a';

const _ana = 'quiet-amber-harbor';
const _ben = 'tall-cedar-window';
const _hid = 'soft-violet-lantern';
const _hidOnion = 'hidonionhidonionhidonionhidonionhidonionhidonionhidd';
const _hidXpub =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f9';
const _hidGroupMember = 'pale-moss-signal';
const _hidGroupOnion = 'hgmonionhgmonionhgmonionhgmonionhgmonionhgmonionhgmo';
const _hidGroupXpub =
    'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';
const _dev = 'dev:k7';
const _cara = 'warm-slate-meadow';
const _shotsGroup = 'g-0002';
const _support = 'brisk-lime-anchor';
const _group = 'g-0001';
const _room = 'r-0001';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _rand32() {
  final r = Random.secure();
  return _hex(List.generate(32, (_) => r.nextInt(256)));
}

Future<SqliteMem> _schema() async {
  final db = SqliteMem.open()!;
  await appSchemaOn(db);
  await searchTables(db, fresh: true);
  return db;
}

class _Phone {
  _Phone(this.db, this.dir, this.media, this.now);
  final SqliteMem db;
  final String dir;
  final String media;
  final int now;
  final files = <String, Uint8List>{};
  // what must never reach the device, in any byte
  final secrets = <String>[];
}

int _uid = 0;

Future<_Phone> _phone({int ana = 30}) async {
  final dir = Directory.systemTemp.createTempSync('hist-phone').path;
  final media = p.join(dir, 'media');
  Directory(media).createSync();
  final now = DateTime.now().millisecondsSinceEpoch;
  final ph = _Phone(await _schema(), dir, media, now);
  final db = ph.db;
  Future<void> contact(
    String id, {
    int accepted = 1,
    String? nick,
    String? vouchedBy,
  }) => db.insert('contacts', {
    'halo_id': id,
    'onion': '${id}onion',
    'xpub': '${id}xpub',
    'first_seen': now - 100000,
    'last_seen': now,
    'accepted': accepted,
    'nickname': ?nick,
    'vouched_by': ?vouchedBy,
    'peer_bundle': 'bundle-of-$id',
  });
  Future<void> msg(
    String peer,
    String text, {
    String? group,
    int ago = 1000,
    String? media,
    String? file,
    String dir = 'in',
    Map<String, Object?> more = const {},
  }) async {
    final uid = 'u${_uid++}';
    await db.insert('messages', {
      'peer_id': peer,
      'direction': dir,
      'plaintext': text,
      'sent_at': now - ago,
      'written_at': now - ago,
      'msg_uid': uid,
      'group_id': group,
      'media_path': media,
      'file_path': file,
      ...more,
    });
  }

  String put(String name, int size, {int seed = 1}) {
    final b = Uint8List.fromList(
      List.generate(size, (i) => (i * seed + 7) & 255),
    );
    final path = p.join(media, name);
    File(path).writeAsBytesSync(b);
    ph.files[name] = b;
    return path;
  }

  await contact(_ana, nick: 'Ana', vouchedBy: _hid);
  await contact(_ben, nick: 'Ben');
  for (var i = 0; i < ana; i++) {
    await msg(
      _ana,
      'ana says $i',
      ago: 100000 - i * 10,
      dir: i.isEven ? 'in' : 'out',
    );
  }
  await msg(_ana, 'a photo', media: put('p1.jpg', 3000, seed: 3), ago: 5000);
  await msg(_ana, 'a video', media: put('v1.mp4', 5200, seed: 5), ago: 4000);
  // older than a month: the row goes, the file stays
  await msg(
    _ana,
    'an old photo',
    media: put('old.jpg', 900),
    ago: 40 * 86400000,
  );
  // a file outside the media folder never goes
  await msg(_ana, 'a saved file', file: '/sdcard/Download/x.pdf');
  await msg(_ben, 'ben here');
  await msg(_ben, 'a document', file: put('doc.pdf', 1500, seed: 9), ago: 3000);
  // a timed message burns where it is
  await msg(_ben, 'this burns in ten seconds', more: {'burn_secs': 10});
  // what came through the developer's lane stays with it
  await msg(_ben, 'came through the dev lane', more: {'via_dev': 1});
  final reacted = (await db.query(
    'messages',
    where: "plaintext = 'ben here'",
  )).first['msg_uid'];
  await db.insert('reactions', {
    'msg_uid': reacted,
    'reactor': _ana,
    'emoji': '👍',
    'reacted_at': now,
  });
  await db.insert('reactions', {
    'msg_uid': reacted,
    'reactor': _hid,
    'emoji': '🔥',
    'reacted_at': now,
  });

  // an everyday group with a hidden person in it, as admin and sender
  await db.insert('groups', {
    'group_id': _group,
    'name': 'Climbing',
    'created_at': now,
    'admin_id': _hid,
  });
  await contact(_hid, accepted: 0);
  for (final m in [_ana, _hid]) {
    await db.insert('group_members', {
      'group_id': _group,
      'halo_id': m,
      'joined_at': now,
    });
  }
  await msg(_ana, 'group hello', group: _group, ago: 2000);
  await msg(_hid, 'hidden one writes in the group', group: _group, ago: 1500);
  await msg(
    _ana,
    'a poll',
    group: _group,
    ago: 1200,
    more: {'poll': '{"q":"when","o":["sat","sun"]}'},
  );
  final poll = (await db.query(
    'messages',
    where: "plaintext = 'a poll'",
  )).first['msg_uid'];
  await db.insert('poll_votes', {
    'poll_uid': poll,
    'voter': _ana,
    'group_id': _group,
    'choices': '[0]',
    'seq': 1,
    'at': now,
  });
  await db.insert('poll_votes', {
    'poll_uid': poll,
    'voter': _hid,
    'group_id': _group,
    'choices': '[1]',
    'seq': 1,
    'at': now,
  });

  // the hidden chats' list, as routing keeps it while the vault is shut
  await db.insert('hidden_chats', {
    'chat_id': _hid,
    'kind': 'peer',
    'card': jsonEncode({'id': _hid, 'onion': _hidOnion, 'xpub': _hidXpub}),
    'at': now,
  });
  await db.insert('hidden_chats', {
    'chat_id': 'hg-0009',
    'kind': 'group',
    'card': jsonEncode({
      'm': [
        {'id': _hidGroupMember, 'onion': _hidGroupOnion, 'xpub': _hidGroupXpub},
      ],
    }),
    'at': now,
  });

  // the developer chat, and on the developer's phone a chat it started
  await contact(_dev);
  await msg(_dev, 'hello marios');
  await contact(_support);
  await db.insert('support_chats', {'halo_id': _support, 'first_at': now});
  await msg(_support, 'a support question');

  // a burner room
  await db.insert('groups', {
    'group_id': _room,
    'name': 'Burner',
    'created_at': now,
    'room_priv': 'roompriv',
    'room_pub': 'roompub',
    'expires_at': now + 3600000,
  });
  await msg(_ana, 'room words', group: _room);

  // a chat a crash left half moved into the vault: its everyday rows are
  // still here, and it is hidden all the same
  await msg(_hid, 'hidden one to one');
  // screenshots blocked: the chats show on the device, nothing said in them
  await contact(_cara, nick: 'Cara');
  await db.update(
    'contacts',
    {'shots_on': 1, 'shots_at': now},
    where: 'halo_id = ?',
    whereArgs: [_cara],
  );
  await msg(_cara, 'shot secret words');
  await db.insert('groups', {
    'group_id': _shotsGroup,
    'name': 'Quiet',
    'created_at': now,
    'shots_on': 1,
  });
  await msg(_ana, 'shot group words', group: _shotsGroup);
  // a voice note goes even when files are skipped
  await msg(
    _ana,
    '',
    file: put('vn1.ogg', 2100, seed: 11),
    ago: 6000,
    more: {'file_name': 'voice.ogg'},
  );
  // what cannot go is counted: a name no device could hold, a row too big
  await msg(
    _ben,
    'a file with a bad name',
    file: put('bad\\name.jpg', 400),
    ago: 2500,
  );
  await msg(_ben, 'x' * (1 << 21));

  ph.secrets.addAll([
    'hidden one to one',
    'shot secret words',
    'shot group words',
    _hidOnion,
    _hidXpub,
    _hidGroupMember,
    _hidGroupOnion,
    _hidGroupXpub,
    'hg-0009',
    _dev,
    'hello marios',
    _support,
    'a support question',
    'this burns',
    'dev lane',
    _room,
    'Burner',
    'room words',
    'roompriv',
    'bundle-of-',
    '/sdcard/Download',
  ]);
  return ph;
}

class _Device {
  _Device(this.db, this.media);
  final SqliteMem db;
  final String media;
}

Future<_Device> _device() async {
  final dir = Directory.systemTemp.createTempSync('hist-device').path;
  final media = p.join(dir, 'media');
  Directory(media).createSync();
  return _Device(await _schema(), media);
}

class _Link {
  _Link() : key = _rand32(), bind = _rand32();
  final String key;
  final String bind;
}

Future<HistoryOutgoing> _export(
  _Phone ph,
  _Link l, {
  bool skip = false,
  HaloContainer container = HaloContainer.everyday,
}) => exportHistory(
  db: ph.db,
  container: container,
  mediaDir: ph.media,
  spoolDir: ph.dir,
  keyHex: l.key,
  bindHex: l.bind,
  identityHex: _identity,
  skipMedia: skip,
  now: DateTime.fromMillisecondsSinceEpoch(ph.now),
  chunk: 1024,
);

Future<HistoryImport> _open(_Device d, _Link l, HistoryOutgoing out) =>
    HistoryImport.open(
      db: d.db,
      mediaDir: d.media,
      keyHex: l.key,
      bindHex: l.bind,
      idHex: out.id,
      identityHex: _identity,
    );

Future<void> _pump(HistoryOutgoing out, HistoryImport imp, [int? upto]) async {
  final end = upto ?? out.head.records;
  while (imp.next < end) {
    await imp.take(out.record(imp.next));
  }
}

// the device's rows as a person sees them, ids aside
Future<Map<String, Object?>> _dump(_Device d) async {
  Future<List<String>> rows(String sql) async => [
    for (final r in await d.db.rawQuery(sql))
      jsonEncode({
        for (final e in r.entries)
          e.key: e.value is String && (e.value as String).startsWith(d.media)
              ? p.relative(e.value as String, from: d.media)
              : e.value,
      }),
  ];
  final files = <String, String>{};
  for (final f in Directory(d.media).listSync(recursive: true)) {
    if (f is File) {
      files[p.relative(f.path, from: d.media)] = base64Encode(
        f.readAsBytesSync(),
      );
    }
  }
  return {
    'messages': await rows(
      'SELECT peer_id, group_id, direction, plaintext, sent_at, msg_uid, '
      'media_path, file_path, poll FROM messages ORDER BY msg_uid',
    ),
    'contacts': await rows(
      'SELECT halo_id, accepted, nickname, onion, xpub, vouched_by, peer_bundle '
      'FROM contacts ORDER BY halo_id',
    ),
    'groups': await rows(
      'SELECT group_id, name, admin_id FROM groups ORDER BY group_id',
    ),
    'members': await rows(
      'SELECT group_id, halo_id FROM group_members ORDER BY 1, 2',
    ),
    'reactions': await rows(
      'SELECT msg_uid, reactor, emoji FROM reactions ORDER BY 1, 2',
    ),
    'votes': await rows(
      'SELECT poll_uid, voter, choices FROM poll_votes ORDER BY 1, 2',
    ),
    'search': await rows('SELECT rowid FROM msg_fts ORDER BY 1'),
    'files': files,
  };
}

// every byte that reaches the device: the sealed records, and what each
// one holds once opened
Future<List<Uint8List>> _everyByte(HistoryOutgoing out, _Link l) async {
  final r = HistoryReceiver.open(
    keyHex: l.key,
    bindHex: l.bind,
    idHex: out.id,
    identityHex: _identity,
  );
  final out2 = <Uint8List>[];
  try {
    for (var i = 0; i < out.head.records; i++) {
      final rec = out.record(i);
      out2.add(rec);
      final ev = r.take(rec);
      out2.add(utf8.encode(jsonEncode(ev.j)));
      out2.add(ev.bytes);
    }
  } finally {
    r.close();
  }
  return out2;
}

bool _anywhere(List<Uint8List> all, String s) {
  for (final b in all) {
    if (holds(b, s) ||
        holds(b, base64Encode(utf8.encode(s))) ||
        holds(b, _hex(utf8.encode(s)))) {
      return true;
    }
  }
  return false;
}

void main() {
  final engine = loadHostEngine();
  final sqlite = SqliteMem.open() != null;
  final skip = !engine
      ? 'engine not built for this computer (tool/host_engine.sh)'
      : !sqlite
      ? 'no sqlite on this host'
      : null;

  test('a whole history lands and both sides count the same', () async {
    final ph = await _phone();
    final l = _Link();
    // what a crash left at the spool's name goes first
    File(p.join(ph.dir, kHistorySpool)).writeAsStringSync('stale');
    final out = await _export(ph, l);
    final d = await _device();
    final imp = await _open(d, l, out);
    await _pump(out, imp);
    expect(imp.done, isTrue);
    final res = await imp.finish();
    expect(res.gaps, isEmpty);
    expect(out.checkTally(res.tally), isEmpty);
    // what the phone could not send is said on both sides, chat by chat
    String left(List<HistoryChatLeft> l) =>
        [for (final x in l) '${x.chat.id} ${x.rows} ${x.files}'].join(', ');
    expect(left(res.left), '$_ana 0 1, $_ben 1 1');
    expect(left(out.left), left(res.left));
    expect(res.whole, isFalse);
    var size = 0;
    for (var i = 0; i < out.head.records; i++) {
      size += out.record(i).length;
    }
    expect(out.head.bytes, size);

    Future<Object?> n(String w) async => (await d.db.rawQuery(
      'SELECT COUNT(*) AS c FROM messages WHERE $w',
    )).first['c'];
    expect(await n("peer_id = '$_ana' AND group_id IS NULL"), 35);
    expect(await n("peer_id = '$_ben' AND group_id IS NULL"), 3);
    expect(await n("group_id = '$_group'"), 3);
    // the month's files, byte for byte; the older one stays on the phone
    for (final f in ['p1.jpg', 'v1.mp4', 'doc.pdf', 'vn1.ogg']) {
      expect(
        File(p.join(d.media, f)).readAsBytesSync(),
        ph.files[f],
        reason: f,
      );
    }
    expect(File(p.join(d.media, 'old.jpg')).existsSync(), isFalse);
    final old = await d.db.query(
      'messages',
      where: "plaintext = 'an old photo'",
    );
    expect(old.single['media_path'], p.join(d.media, 'old.jpg'));
    final saved = await d.db.query(
      'messages',
      where: "plaintext = 'a saved file'",
    );
    expect(saved.single['file_path'], isNull);
    expect(out.head.files, 4);
    // found by search as on the phone
    final hits = await d.db.rawQuery(
      "SELECT rowid FROM msg_fts WHERE msg_fts MATCH 'hello'",
    );
    expect(hits, isNotEmpty);
    await imp.clear();
    out.close();
  }, skip: skip);

  test(
    'no hidden chat, decoy, developer chat, room or timed message in any byte',
    () async {
      final ph = await _phone();
      final l = _Link();
      final out = await _export(ph, l);
      final all = await _everyByte(out, l);
      for (final s in ph.secrets) {
        expect(_anywhere(all, s), isFalse, reason: s);
      }
      final d = await _device();
      final imp = await _open(d, l, out);
      await _pump(out, imp);
      expect((await imp.finish()).gaps, isEmpty);
      final dump = jsonEncode(await _dump(d));
      for (final s in ph.secrets) {
        expect(dump.contains(s), isFalse, reason: s);
      }
      out.close();
    },
    skip: skip,
  );

  test(
    'a hidden contact in an everyday group: the copy is the everyday side',
    () async {
      final ph = await _phone();
      final l = _Link();
      final out = await _export(ph, l);
      final d = await _device();
      final imp = await _open(d, l, out);
      await _pump(out, imp);
      expect((await imp.finish()).gaps, isEmpty);
      Future<List<Map<String, Object?>>> rows(SqliteMem db, String sql) =>
          db.rawQuery(sql);
      for (final sql in [
        "SELECT peer_id, direction, plaintext, sent_at, msg_uid, poll "
            "FROM messages WHERE group_id = '$_group' ORDER BY msg_uid",
        "SELECT group_id, name, admin_id FROM groups WHERE group_id = '$_group'",
        "SELECT halo_id FROM group_members WHERE group_id = '$_group' "
            'ORDER BY halo_id',
        'SELECT msg_uid, reactor, emoji FROM reactions ORDER BY 1, 2',
        'SELECT poll_uid, voter, choices FROM poll_votes ORDER BY 1, 2',
      ]) {
        expect(await rows(d.db, sql), await rows(ph.db, sql), reason: sql);
      }
      // the hidden one is there as the group shows them
      expect(
        (await rows(
          d.db,
          "SELECT 1 FROM messages WHERE peer_id = '$_hid' "
          "AND group_id = '$_group'",
        )),
        isNotEmpty,
      );
      // and their chat with this phone, hidden, is not
      expect(
        await rows(
          d.db,
          "SELECT 1 FROM messages WHERE peer_id = '$_hid' "
          'AND group_id IS NULL',
        ),
        isEmpty,
      );
      expect(
        await rows(
          d.db,
          "SELECT 1 FROM contacts WHERE halo_id = '$_hid' "
          'AND accepted = 1',
        ),
        isEmpty,
      );
      out.close();
    },
    skip: skip,
  );

  test('a chat with screenshots blocked stays on the phone', () async {
    final ph = await _phone();
    final l = _Link();
    final out = await _export(ph, l);
    final d = await _device();
    final imp = await _open(d, l, out);
    await _pump(out, imp);
    final res = await imp.finish();
    expect(res.gaps, isEmpty);
    expect({for (final x in res.stays) x.chat.id}, {_cara, _shotsGroup});
    expect(res.stays.first.line, l10n.historyChatStaysShots);
    // the chat shows, nothing said in it does
    expect(
      await d.db.query('contacts', where: "halo_id = '$_cara'"),
      hasLength(1),
    );
    expect(
      await d.db.query('groups', where: "group_id = '$_shotsGroup'"),
      hasLength(1),
    );
    expect(await d.db.query('messages', where: "peer_id = '$_cara'"), isEmpty);
    expect(
      await d.db.query('messages', where: "group_id = '$_shotsGroup'"),
      isEmpty,
    );
    out.close();
  }, skip: skip);

  test(
    'a live row only counts as the copy when it is the same message',
    () async {
      final ph = await _phone(ana: 6);
      final l = _Link();
      final out = await _export(ph, l);
      final d = await _device();
      final real = (await ph.db.query(
        'messages',
        where: "plaintext = 'ana says 3'",
      )).single;
      // someone sends the new device a message under a uid of the past
      await d.db.insert('contacts', {
        'halo_id': _ana,
        'onion': 'o',
        'xpub': 'x',
        'first_seen': 1,
        'last_seen': 1,
      });
      await d.db.insert('messages', {
        'peer_id': _ana,
        'direction': 'in',
        'plaintext': 'not what was said',
        'sent_at': 1,
        'msg_uid': real['msg_uid'],
      });
      final imp = await _open(d, l, out);
      await _pump(out, imp);
      expect((await imp.finish()).gaps, isEmpty);
      final both = await d.db.query(
        'messages',
        where: 'msg_uid = ?',
        whereArgs: [real['msg_uid']],
      );
      expect(
        {for (final r in both) r['plaintext']},
        {'ana says 3', 'not what was said'},
      );
      out.close();
    },
    skip: skip,
  );

  test(
    'one sender per link, and a device restart takes the copy up again',
    () async {
      final ph = await _phone(ana: 4);
      final l = _Link();
      final out = await _export(ph, l);
      await expectLater(_export(ph, l), throwsA(isA<HistoryRefused>()));
      final d = await _device();
      var imp = await _open(d, l, out);
      await _pump(out, imp, out.head.text + 2);
      imp.close();
      // the device kept the stream key with its place, the phone did not
      imp = (await HistoryImport.reopen(db: d.db, mediaDir: d.media))!;
      expect(imp.next, out.head.text + 2);
      await _pump(out, imp);
      expect((await imp.finish()).gaps, isEmpty);
      await imp.clear();
      expect(await HistoryImport.reopen(db: d.db, mediaDir: d.media), isNull);
      out.close();
    },
    skip: skip,
  );

  test('a record that never opens stops the copy after its tries', () async {
    final ph = await _phone(ana: 2);
    final l = _Link();
    final out = await _export(ph, l);
    final d = await _device();
    final imp = await _open(d, l, out);
    await _pump(out, imp, 2);
    final bad = Uint8List.fromList(out.record(2))..[9] ^= 1;
    for (var i = 1; i < kHistoryTries; i++) {
      await expectLater(
        imp.take(bad),
        throwsA(
          isA<HistoryRefused>().having((e) => e.forGood, 'for good', isFalse),
        ),
      );
    }
    await expectLater(
      imp.take(bad),
      throwsA(
        isA<HistoryRefused>().having((e) => e.forGood, 'for good', isTrue),
      ),
    );
    out.close();
  }, skip: skip);

  test('only the everyday container, with nothing attached, sends', () async {
    final ph = await _phone();
    for (final c in [
      HaloContainer.decoy,
      HaloContainer.vault,
      HaloContainer.decoyVault,
    ]) {
      await expectLater(
        _export(ph, _Link(), container: c),
        throwsA(isA<HistoryNotHere>()),
      );
    }
    await ph.db.execute("ATTACH DATABASE ':memory:' AS v");
    await expectLater(_export(ph, _Link()), throwsA(isA<HistoryNotHere>()));
  }, skip: skip);

  test(
    'skip photos, videos and files: none of them, every voice note and text',
    () async {
      final ph = await _phone();
      final l = _Link();
      final out = await _export(ph, l, skip: true);
      expect(out.head.skipMedia, isTrue);
      expect(out.head.files, 1);
      final all = await _everyByte(out, l);
      for (final e in ph.files.entries) {
        if (e.key == 'vn1.ogg') continue;
        final probe = String.fromCharCodes(e.value.sublist(0, 48));
        expect(all.any((b) => holds(b, probe)), isFalse, reason: e.key);
      }
      final d = await _device();
      final imp = await _open(d, l, out);
      await _pump(out, imp);
      expect(
        [for (final f in await d.db.query('history_files')) f['name']],
        ['vn1.ogg'],
      );
      expect((await imp.finish()).gaps, isEmpty);
      expect(
        [
          for (final f in Directory(d.media).listSync(recursive: true))
            if (f is File) p.basename(f.path),
        ],
        ['vn1.ogg'],
      );
      expect(await d.db.query('media_chunks'), isEmpty);
      final photo = await d.db.query(
        'messages',
        where: "plaintext = 'a photo'",
      );
      expect(File(photo.single['media_path'] as String).existsSync(), isFalse);
      out.close();
    },
    skip: skip,
  );

  test(
    'cut before every record, the app closed and opened again, ends the same',
    () async {
      final ph = await _phone(ana: 12);
      final l = _Link();
      final out = await _export(ph, l);
      final whole = await _device();
      final w = await _open(whole, l, out);
      await _pump(out, w);
      final want = await _dump(whole);
      for (var cut = 0; cut <= out.head.records; cut++) {
        final d = await _device();
        var imp = await _open(d, l, out);
        await _pump(out, imp, cut);
        imp.close();
        imp = await _open(d, l, out);
        expect(imp.next, cut);
        await _pump(out, imp);
        final res = await imp.finish();
        expect(res.gaps, isEmpty, reason: 'cut at $cut');
        expect(await _dump(d), want, reason: 'cut at $cut');
      }
      out.close();
    },
    skip: skip,
  );

  test(
    'a commit that fails leaves the stream at that record, nothing doubled',
    () async {
      final ph = await _phone(ana: 12);
      final l = _Link();
      final out = await _export(ph, l);
      final whole = await _device();
      await _pump(out, await _open(whole, l, out));
      final want = await _dump(whole);
      for (var at = 1; at < out.head.records; at++) {
        final d = await _device();
        final imp = await _open(d, l, out);
        await _pump(out, imp, at);
        // the next commit fails inside sqlite, after its rows went in
        await d.db.execute('CREATE TABLE cut (x)');
        await d.db.execute('INSERT INTO cut VALUES (1)');
        for (final (name, on) in const [
          ('cut_in', 'INSERT'),
          ('cut_up', 'UPDATE'),
        ]) {
          await d.db.execute(
            'CREATE TRIGGER $name BEFORE $on ON history_in '
            'WHEN (SELECT COUNT(*) FROM cut) > 0 '
            "BEGIN SELECT RAISE(ABORT, 'cut'); END",
          );
        }
        await expectLater(imp.take(out.record(at)), throwsA(anything));
        expect(imp.next, at);
        await d.db.execute('DELETE FROM cut');
        await _pump(out, imp);
        expect((await imp.finish()).gaps, isEmpty, reason: 'at $at');
        await d.db.execute('DROP TRIGGER cut_in');
        await d.db.execute('DROP TRIGGER cut_up');
        await d.db.execute('DROP TABLE cut');
        expect(await _dump(d), want, reason: 'at $at');
      }
      out.close();
    },
    skip: skip,
  );

  test('a file whose move a cut stopped is moved at the next start', () async {
    final ph = await _phone(ana: 2);
    final l = _Link();
    final out = await _export(ph, l);
    final d = await _device();
    var imp = await _open(d, l, out);
    await _pump(out, imp);
    final f = File(p.join(d.media, 'p1.jpg'));
    final part = (await d.db.query(
      'history_files',
      where: "name = 'p1.jpg'",
    )).single['file'];
    final at = p.join(d.media, '.history', '$part.part');
    f.renameSync(at);
    imp.close();
    imp = await _open(d, l, out);
    expect(f.readAsBytesSync(), ph.files['p1.jpg']);
    expect((await imp.finish()).gaps, isEmpty);
    out.close();
  }, skip: skip);

  test('bytes a cut left in a file on its way in are cut away', () async {
    final ph = await _phone(ana: 2);
    final l = _Link();
    final out = await _export(ph, l);
    final d = await _device();
    var imp = await _open(d, l, out);
    // the first chunk of the newest file, then a cut
    await _pump(out, imp, out.head.text + 2);
    imp.close();
    final parts = Directory(
      p.join(d.media, '.history'),
    ).listSync().whereType<File>().toList();
    expect(parts, hasLength(1));
    parts.single.writeAsBytesSync(
      List.filled(9000, 0xee),
      mode: FileMode.append,
    );
    imp = await _open(d, l, out);
    await _pump(out, imp);
    expect((await imp.finish()).gaps, isEmpty);
    for (final f in ['p1.jpg', 'v1.mp4', 'doc.pdf']) {
      expect(
        File(p.join(d.media, f)).readAsBytesSync(),
        ph.files[f],
        reason: f,
      );
    }
    out.close();
  }, skip: skip);

  test(
    'a spoilt, swapped, repeated or dropped record is refused and the right one lands',
    () async {
      final ph = await _phone(ana: 4);
      final l = _Link();
      final out = await _export(ph, l);
      final d = await _device();
      final imp = await _open(d, l, out);
      final n = out.head.records;
      for (var i = 0; i < n; i++) {
        final rec = out.record(i);
        final bad = <Uint8List>[
          Uint8List.fromList(rec)..[rec.length ~/ 2] ^= 1,
          if (i + 1 < n) out.record(i + 1),
          if (i > 0) out.record(i - 1),
          Uint8List.fromList(rec.sublist(0, rec.length - 1)),
        ];
        for (final b in bad) {
          await expectLater(
            imp.take(b),
            throwsA(
              isA<HistoryRefused>().having(
                (e) => e.forGood,
                'for good',
                isFalse,
              ),
            ),
          );
          expect(imp.next, i);
        }
        await imp.take(rec);
      }
      expect((await imp.finish()).gaps, isEmpty);
      out.close();
    },
    skip: skip,
  );

  test(
    'a mismatch shows on the device and on the phone, never passed over',
    () async {
      final ph = await _phone();
      final l = _Link();
      final out = await _export(ph, l);
      final d = await _device();
      final imp = await _open(d, l, out);
      await _pump(out, imp);
      // a row lost and a file gone after the import
      await d.db.delete('messages', where: "plaintext = 'ana says 3'");
      File(p.join(d.media, 'doc.pdf')).deleteSync();
      final res = await imp.finish();
      expect(res.whole, isFalse);
      final gaps = {for (final g in res.gaps) g.chat.id: g};
      expect(gaps.keys.toSet(), {_ana, _ben});
      expect(gaps[_ana]!.got.messages, gaps[_ana]!.want.messages - 1);
      expect(gaps[_ben]!.got.media, gaps[_ben]!.want.media - 1);
      final phone = {for (final g in out.checkTally(res.tally)) g.chat.id: g};
      expect(phone.keys.toSet(), {_ana, _ben});
      expect(phone[_ana]!.got, gaps[_ana]!.got);
      out.close();
    },
    skip: skip,
  );

  test(
    'a file that changed on the phone after the plan is counted missing',
    () async {
      final ph = await _phone(ana: 2);
      final l = _Link();
      final out = await _export(ph, l);
      File(p.join(ph.media, 'v1.mp4')).writeAsBytesSync(List.filled(5200, 1));
      final d = await _device();
      final imp = await _open(d, l, out);
      await _pump(out, imp);
      final res = await imp.finish();
      expect(res.gaps.single.chat.id, _ana);
      expect(res.gaps.single.got.media, res.gaps.single.want.media - 1);
      expect(File(p.join(d.media, 'v1.mp4')).existsSync(), isFalse);
      out.close();
    },
    skip: skip,
  );

  test(
    'a new stream over a cut one starts clean and keeps what was here',
    () async {
      final ph = await _phone(ana: 6);
      final first = _Link();
      final out1 = await _export(ph, first);
      final d = await _device();
      // a message that reached the device live before any copy
      await d.db.insert('contacts', {
        'halo_id': _ben,
        'onion': 'o',
        'xpub': 'x',
        'first_seen': 1,
        'last_seen': 1,
      });
      final live = (await ph.db.query(
        'messages',
        where: "plaintext = 'ben here'",
      )).single;
      await d.db.insert('messages', {
        'peer_id': _ben,
        'direction': 'in',
        'plaintext': 'ben here',
        'sent_at': live['sent_at'],
        'msg_uid': live['msg_uid'],
      });
      var imp = await _open(d, first, out1);
      await _pump(out1, imp, out1.head.text + 1);
      imp.close();
      final second = _Link();
      final out2 = await _export(ph, second);
      imp = await _open(d, second, out2);
      expect(imp.next, 0);
      await _pump(out2, imp);
      expect((await imp.finish()).gaps, isEmpty);
      final ben = await d.db.query('messages', where: "plaintext = 'ben here'");
      expect(ben, hasLength(1));
      final ana = await d.db.query(
        'messages',
        where: "plaintext = 'ana says 0'",
      );
      expect(ana, hasLength(1));
      out1.close();
      out2.close();
    },
    skip: skip,
  );
}
