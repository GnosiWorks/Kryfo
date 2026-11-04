// SPDX-License-Identifier: GPL-3.0-or-later
// voice note transcripts kept beside their note in the chat's encrypted
// database: read back by chat, kept only for a note the database holds,
// gone with the note however it goes (deleted, unsent, burned, its file
// let go, the chat, the contact or the group deleted), in the vault only
// for a hidden chat, never in a copy that leaves the phone, and all of
// them gone when transcripts are turned off
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show tidyCopy;
import 'package:kryfo/voice/transcript_store.dart';

import '../sqlite_ffi.dart';

const _words = 'see you at the station at three';

KeptTranscript _t([String words = _words, bool open = true]) => KeptTranscript(
  lang: 'en',
  model: 'base',
  pieces: [TxPiece(0, 1200, ' $words')],
  open: open,
);

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  // chats, and voice notes in them: (chat, uid, group)
  Future<SqliteMem> dbWith(
    List<(String chat, String uid, String? group)> notes,
  ) async {
    final db = SqliteMem.open()!;
    await appSchemaOn(db);
    for (final c in {for (final n in notes) n.$1}) {
      await db.insert('contacts', {
        'halo_id': c,
        'onion': '',
        'xpub': 'ab',
        'first_seen': 1,
        'last_seen': 1,
      });
    }
    for (final (c, uid, group) in notes) {
      await db.insert('messages', {
        'peer_id': c,
        'direction': 'in',
        'plaintext': '',
        'sent_at': 1,
        'msg_uid': uid,
        'group_id': group,
        'file_path': '/media/$uid.ogg',
        'file_name': 'voice.ogg',
      });
    }
    return db;
  }

  test('kept and read back by chat, with its pieces and language', () async {
    final db = await dbWith([('heron', 'u1', null), ('wren', 'u2', null)]);
    final store = DbVoiceTxStore(() async => db);
    await store.keep('heron', 'u1', _t());
    await store.keep('wren', 'u2', _t('other words'));
    final got = await store.kept('heron');
    expect(got.keys, ['u1']);
    expect(got['u1']!.text, _words);
    expect(got['u1']!.lang, 'en');
    expect(got['u1']!.model, 'base');
    expect(got['u1']!.pieces.single.startMs, 0);
    expect(got['u1']!.pieces.single.endMs, 1200);
    expect(got['u1']!.open, isTrue);
  }, skip: skip);

  test('open or folded is kept per note', () async {
    final db = await dbWith([('heron', 'u1', null)]);
    final store = DbVoiceTxStore(() async => db);
    await store.keep('heron', 'u1', _t());
    await store.setOpen('heron', 'u1', false);
    expect((await store.kept('heron'))['u1']!.open, isFalse);
    await store.setOpen('heron', 'u1', true);
    expect((await store.kept('heron'))['u1']!.open, isTrue);
  }, skip: skip);

  test('nothing is kept for a note the database does not hold', () async {
    final db = await dbWith([('heron', 'u1', null)]);
    final store = DbVoiceTxStore(() async => db);
    await store.keep('heron', 'nope', _t());
    // nor for a note of another chat under this chat's name
    await store.keep('wren', 'u1', _t());
    expect(await store.kept('heron'), isEmpty);
    expect(await store.kept('wren'), isEmpty);
  }, skip: skip);

  test('gone with its note: deleted, unsent or burned', () async {
    final db = await dbWith([
      ('heron', 'u1', null),
      ('heron', 'u2', null),
      ('heron', 'u3', null),
    ]);
    final store = DbVoiceTxStore(() async => db);
    for (final u in ['u1', 'u2', 'u3']) {
      await store.keep('heron', u, _t());
    }
    // each of these takes the row out of messages
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: ['u1']);
    expect((await store.kept('heron')).keys, unorderedEquals(['u2', 'u3']));
    // a timed note burning: its row deleted by the burn sweep
    await db.update(
      'messages',
      {'burn_at': 5},
      where: 'msg_uid = ?',
      whereArgs: ['u2'],
    );
    await db.delete('messages', where: 'burn_at IS NOT NULL AND burn_at <= 5');
    expect((await store.kept('heron')).keys, ['u3']);
  }, skip: skip);

  test('gone when its file is let go, kept when it moves', () async {
    final db = await dbWith([('heron', 'u1', null), ('heron', 'u2', null)]);
    final store = DbVoiceTxStore(() async => db);
    await store.keep('heron', 'u1', _t());
    await store.keep('heron', 'u2', _t());
    // the wav made into its opus copy: the same note
    await db.update(
      'messages',
      {'file_path': '/media/u1.wav'},
      where: 'msg_uid = ?',
      whereArgs: ['u1'],
    );
    expect((await store.kept('heron')).keys, unorderedEquals(['u1', 'u2']));
    await db.update(
      'messages',
      {'file_path': null},
      where: 'msg_uid = ?',
      whereArgs: ['u2'],
    );
    expect((await store.kept('heron')).keys, ['u1']);
  }, skip: skip);

  test('gone with the chat, the contact and the group', () async {
    final db = await dbWith([
      ('heron', 'u1', null),
      ('wren', 'u2', null),
      ('kite', 'g1', 'grp'),
    ]);
    final store = DbVoiceTxStore(() async => db);
    await store.keep('heron', 'u1', _t());
    await store.keep('wren', 'u2', _t());
    await store.keep('grp', 'g1', _t());
    expect((await store.kept('grp')).keys, ['g1']);
    // a chat deleted, its contact row kept
    await db.delete('messages', where: 'peer_id = ?', whereArgs: ['heron']);
    expect(await store.kept('heron'), isEmpty);
    // the contact itself
    await db.delete('contacts', where: 'halo_id = ?', whereArgs: ['wren']);
    expect(await store.kept('wren'), isEmpty);
    // a group deleted takes its messages
    await db.delete('messages', where: 'group_id = ?', whereArgs: ['grp']);
    expect(await store.kept('grp'), isEmpty);
  }, skip: skip);

  test('a hidden chat keeps its transcripts in the vault only', () async {
    final primary = await dbWith([('heron', 'u1', null)]);
    final vault = await dbWith([('wren', 'v1', null)]);
    var open = true;
    final store = DbVoiceTxStore(
      () async => primary,
      chatDb: (id) async => id == 'wren' && open ? vault : primary,
    );
    await store.keep('wren', 'v1', _t());
    expect((await store.kept('wren')).keys, ['v1']);
    expect(await DbVoiceTxStore(() async => primary).kept('wren'), isEmpty);
    expect(await primary.query('voice_tx'), isEmpty);
    // the vault shut: the everyday side has nothing of it
    open = false;
    expect(await store.kept('wren'), isEmpty);
  }, skip: skip);

  test('the decoy has its own: the real ones never show there', () async {
    final real = await dbWith([('heron', 'u1', null)]);
    final decoy = await dbWith([('heron', 'u1', null)]);
    var inDecoy = false;
    final store = DbVoiceTxStore(() async => inDecoy ? decoy : real);
    await store.keep('heron', 'u1', _t());
    inDecoy = true;
    expect(await store.kept('heron'), isEmpty);
    expect(await decoy.query('voice_tx'), isEmpty);
  }, skip: skip);

  test('a copy that leaves the phone carries none, and still works', () async {
    final db = await dbWith([('heron', 'u1', null), ('heron', 'u2', null)]);
    final store = DbVoiceTxStore(() async => db);
    await store.keep('heron', 'u1', _t());
    await tidyCopy(db);
    expect(await db.query('voice_tx'), isEmpty);
    // the triggers still find their table: deletes go through
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: ['u1']);
    await db.update('messages', {'file_path': null});
    expect(await db.query('messages'), hasLength(1));
  }, skip: skip);

  test('turned off: every open container drops them, a shut vault once it '
      'opens', () async {
    final primary = await dbWith([('heron', 'u1', null)]);
    final vault = await dbWith([('wren', 'v1', null)]);
    var vaultOpen = false;
    final store = DbVoiceTxStore(
      () async => primary,
      chatDb: (id) async => id == 'wren' ? vault : primary,
      open: () async => [primary, if (vaultOpen) vault],
    );
    await store.keep('heron', 'u1', _t());
    await store.keep('wren', 'v1', _t());
    await store.dropAll(1);
    expect(await store.kept('heron'), isEmpty);
    expect((await store.kept('wren')).keys, ['v1']);
    vaultOpen = true;
    await store.dropAll(1);
    expect(await store.kept('wren'), isEmpty);
    // once per off: one made since stays
    await store.keep('wren', 'v1', _t());
    await store.dropAll(1);
    expect((await store.kept('wren')).keys, ['v1']);
  }, skip: skip);

  test('settings are the identity\'s, in its own database', () async {
    final db = await dbWith([]);
    final store = DbVoiceTxStore(() async => db);
    expect((await store.load()).on, isTrue);
    await store.save(const VoiceTxSettings(on: false, offs: 2));
    final s = await DbVoiceTxStore(() async => db).load();
    expect(s.on, isFalse);
    expect(s.offs, 2);
  }, skip: skip);

  test('the table comes with its triggers or not at all', () async {
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, onion TEXT)',
    );
    final store = DbVoiceTxStore(() async => db);
    await expectLater(store.kept('heron'), throwsA(anything));
    final made = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name LIKE 'voice_%'",
    );
    expect(made, isEmpty);
    // and it is tried again, not remembered as done
    await db.execute(
      'CREATE TABLE messages (msg_uid TEXT, plaintext TEXT, peer_id TEXT, '
      'group_id TEXT, file_path TEXT)',
    );
    expect(await store.kept('heron'), isEmpty);
  }, skip: skip);

  test('settings json: on by default, a broken one reads as default', () {
    expect(VoiceTxSettings.fromJson(null).on, isTrue);
    expect(VoiceTxSettings.fromJson('{nope').on, isTrue);
    final s = VoiceTxSettings.fromJson('{"on":false,"offs":3}');
    expect(s.on, isFalse);
    expect(s.offs, 3);
    expect(KeptTranscript.piecesOf('[[1,2,"a"],[2,3,"b"]]'), hasLength(2));
    expect(KeptTranscript.piecesOf('nope'), isEmpty);
  });
}
