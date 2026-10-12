// SPDX-License-Identifier: GPL-3.0-or-later
// a draft goes with its chat: deleted, left or hidden, its words are not
// kept in memory, and a restart writes down only those of a chat the
// everyday side still holds
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'source_body.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

String _every(String id) => HaloContainer.everyday.chatKey(id);

Future<_Rows> _seeded([HaloContainer c = HaloContainer.everyday]) async {
  final db = _Rows(MemDb(), c);
  for (final id in ['ann', 'ben', 'cat']) {
    await db.mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
  }
  for (final id in ['g1', 'g2']) {
    await db.mem.insert('groups', {
      'group_id': id,
      'name': id,
      'created_at': 1,
    });
  }
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    draftPerPeer.clear();
    draftPerGroup.clear();
    everydayChats = null;
  });

  // a deleted 1:1 chat's draft goes in AppState (delete_chat_settings_test)
  test('a deleted group takes its draft along', () async {
    final db = await _seeded();
    draftPerGroup.addAll({_every('g1'): 'who brings', _every('g2'): 'ok'});
    await db.deleteGroup('g1');
    expect(draftPerGroup, {_every('g2'): 'ok'});
  });

  test('a decoy\'s delete takes the decoy\'s draft, never the everyday '
      'one', () async {
    final db = await _seeded(HaloContainer.decoy);
    final decoy = HaloContainer.decoy.chatKey('g1');
    draftPerGroup.addAll({decoy: 'x', _every('g1'): 'y'});
    await db.deleteGroup('g1');
    expect(draftPerGroup, {_every('g1'): 'y'});
  });

  test('a restart writes down only drafts of chats the everyday side still '
      'holds', () async {
    final db = await _seeded();
    // deleted: the row stays, archived and not accepted
    await db.mem.update(
      'contacts',
      {'accepted': 0, 'archived': 1},
      where: 'halo_id = ?',
      whereArgs: ['ben'],
    );
    // archived by hand is still a chat
    await db.mem.update(
      'contacts',
      {'archived': 1},
      where: 'halo_id = ?',
      whereArgs: ['cat'],
    );
    everydayChats = db.draftChats;
    draftPerPeer.addAll({
      _every('ann'): 'kept',
      _every('ben'): 'deleted',
      _every('cat'): 'archived',
      // hidden: no everyday row at all
      _every('hid'): 'hidden',
    });
    draftPerGroup.addAll({_every('g1'): 'kept', _every('gone'): 'left'});
    await keepDrafts();
    draftPerPeer.clear();
    draftPerGroup.clear();
    await restoreKeptDrafts();
    expect(draftPerPeer, {_every('ann'): 'kept', _every('cat'): 'archived'});
    expect(draftPerGroup, {_every('g1'): 'kept'});
  });

  test(
    'with no way to ask which chats there are, nothing is written',
    () async {
      draftPerPeer[_every('ann')] = 'kept?';
      await keepDrafts();
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      everydayChats = () => throw StateError('no database');
      await keepDrafts();
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );

  test('every way a group goes, and a hide, empties an open composer', () {
    final main = sourceOf('lib/main.dart');
    for (final f in [
      'Future<void> leaveGroupAndAnnounce(',
      'Future<void> _dropGroup(',
      'Future<void> _destroyRoomTurn(',
    ]) {
      expect(bodyOf(main, f), contains('dropGroupDraft(groupId);'), reason: f);
    }
    expect(
      bodyOf(main, 'Future<List<ChatRef>> _hide('),
      contains('c.group ? dropGroupDraft(c.id) : dropChatDraft(c.id);'),
    );
  });
}
