// SPDX-License-Identifier: GPL-3.0-or-later
// a draft is a row in the database of the container that holds its chat:
// it outlives the process, a hidden chat's is only in the vault, the decoy
// keeps its own, and sending, deleting, hiding or a wipe takes it
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart' show HaloDb, draftsTable;
import 'package:kryfo/session.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'source_body.dart';
import 'sqlite_channel.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  bool get isOpen => true;
}

const _vaultKey =
    '5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a';

Future<void> _person(HaloDb db, String id) async {
  await (await db.open()).insert('contacts', {
    'halo_id': id,
    'onion': 'o',
    'xpub': 'x-$id',
    'first_seen': 1,
    'last_seen': 1,
    'accepted': 1,
  });
}

Future<void> _group(HaloDb db, String id) async {
  await (await db.open()).insert('groups', {
    'group_id': id,
    'name': id,
    'created_at': 1,
  });
}

Future<List<String>> _chats(HaloDb db) async => [
  for (final r in await (await db.open()).query('drafts', orderBy: 'chat'))
    r['chat'] as String,
];

Draft _d(String text, {String? reply, int at = 1}) =>
    Draft(text, replyTo: reply, at: at);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    endProcessForTest();
  });

  group('on real files', () {
    SqliteChannel? sql;
    late Directory docs;

    setUp(() {
      sql = SqliteChannel.install();
      docs = Directory.systemTemp.createTempSync('drafts');
      m.setMockMethodCallHandler(paths, (_) async => docs.path);
    });

    tearDown(() {
      sql?.uninstall();
      m.setMockMethodCallHandler(paths, null);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    bool skip() {
      if (sql != null) return false;
      markTestSkipped('no sqlite on this host');
      return true;
    }

    // what android stopping the app leaves: the files, nothing in memory
    Future<HaloDb> restart(HaloDb db, [HaloDb Function()? again]) async {
      endProcessForTest();
      await db.close();
      final next = again?.call() ?? HaloDb(db.container);
      await next.open();
      return next;
    }

    test('a draft survives the process stopping, its quote too', () async {
      if (skip()) return;
      final live = HaloDb();
      await live.open();
      typedDraft(live, 'ann', _d('half a thou', at: 1), group: false);
      typedDraft(
        live,
        'ann',
        _d('half a thought', reply: 'u-7', at: 2),
        group: false,
      );
      typedDraft(live, 'g1', _d('see you at nine'), group: true);
      // written once typing rests, not on each key
      expect(await _chats(live), isEmpty);
      await Future<void>.delayed(kDraftWait * 2);
      expect(await _chats(live), ['ann', 'group:g1']);

      final next = await restart(live);
      expect(heldDraft(next.container, 'ann', group: false), isNull);
      final a = await readDraft(next, 'ann', group: false);
      expect(a?.text, 'half a thought');
      expect(a?.replyTo, 'u-7');
      expect(a?.at, 2);
      expect(
        (await readDraft(next, 'g1', group: true))?.text,
        'see you at nine',
      );
      // a person and a group of the same id are two drafts
      expect(await readDraft(next, 'g1', group: false), isNull);
      await next.close();
    });

    test('going out of sight writes what still waits', () async {
      if (skip()) return;
      final live = HaloDb();
      await live.open();
      typedDraft(live, 'ann', _d('typed just now'), group: false);
      const DraftsOnPause().didChangeAppLifecycleState(
        AppLifecycleState.paused,
      );
      await pumpEventQueue();
      expect(await _chats(live), ['ann']);
      final next = await restart(live);
      expect(
        (await readDraft(next, 'ann', group: false))?.text,
        'typed just now',
      );
      await next.close();
    });

    test('leaving the chat writes it at once', () async {
      if (skip()) return;
      final live = HaloDb();
      await live.open();
      typedDraft(live, 'ann', _d('on my way'), group: false);
      await writeDraftNow(live, 'ann', group: false);
      expect(await _chats(live), ['ann']);
      await live.close();
    });

    test('a hidden chat\'s draft is only ever in the vault', () async {
      if (skip()) return;
      final live = HaloDb();
      final vault = HaloDb.withKey(HaloContainer.vault, _vaultKey);
      await _person(live, 'ann');
      await _person(vault, 'hid');
      await _group(vault, 'hg');
      final s = await Session.withVault(live, vault);
      expect(identical(s.draftsOf('hid'), vault), isTrue);
      expect(identical(s.draftsOf('hg'), vault), isTrue);
      expect(identical(s.draftsOf('ann'), live), isTrue);
      typedDraft(s.draftsOf('hid'), 'hid', _d('secret', at: 3), group: false);
      typedDraft(s.draftsOf('hg'), 'hg', _d('us only', at: 2), group: true);
      typedDraft(s.draftsOf('ann'), 'ann', _d('hello', at: 1), group: false);
      await flushDrafts();
      expect(await _chats(live), ['ann']);
      expect(await live.draftOf('hid', group: false), isNull);
      expect(await _chats(vault), ['group:hg', 'hid']);
      // the chat list, newest first: the vault's only while it is open
      expect([for (final d in await s.drafts()) d.chat], ['hid', 'hg', 'ann']);
      expect([for (final d in await Session(live).drafts()) d.chat], ['ann']);

      // the lock: written, out of memory, and back with the vault's pin
      typedDraft(vault, 'hid', _d('secret, more', at: 4), group: false);
      await settleDrafts(HaloContainer.vault);
      expect(heldDraft(HaloContainer.vault, 'hid', group: false), isNull);
      expect(heldDraft(HaloContainer.everyday, 'ann', group: false), isNotNull);
      await vault.close();
      expect(await _chats(live), ['ann']);
      final again = await restart(
        vault,
        () => HaloDb.withKey(HaloContainer.vault, _vaultKey),
      );
      expect(
        (await readDraft(again, 'hid', group: false))?.text,
        'secret, more',
      );
      await again.close();
      await live.close();
    });

    test('the decoy keeps its own, as the everyday app does', () async {
      if (skip()) return;
      final live = HaloDb();
      final decoy = HaloDb(HaloContainer.decoy);
      await live.open();
      await decoy.open();
      final ds = Session(decoy);
      expect(identical(ds.draftsOf('ann'), decoy), isTrue);
      expect(ds.chatKey('ann'), isNot(Session(live).chatKey('ann')));
      typedDraft(live, 'ann', _d('everyday words'), group: false);
      typedDraft(ds.draftsOf('ann'), 'ann', _d('decoy words'), group: false);
      typedDraft(ds.draftsOf('g1'), 'g1', _d('decoy group'), group: true);
      await Future<void>.delayed(kDraftWait * 2);
      expect(await _chats(live), ['ann']);
      expect(await _chats(decoy), ['ann', 'group:g1']);
      await decoy.close();
      final next = await restart(live);
      final nextDecoy = HaloDb(HaloContainer.decoy);
      expect(
        (await readDraft(next, 'ann', group: false))?.text,
        'everyday words',
      );
      expect(
        (await readDraft(nextDecoy, 'ann', group: false))?.text,
        'decoy words',
      );
      await next.close();
      await nextDecoy.close();
    });

    test('sent: the emptied composer drops it at once, even one still '
        'waiting to be written', () async {
      if (skip()) return;
      final live = HaloDb();
      await live.open();
      typedDraft(live, 'ann', _d('hi'), group: false);
      await flushDrafts();
      typedDraft(live, 'ann', _d('hi there'), group: false);
      typedDraft(live, 'ann', _d(''), group: false);
      await pumpEventQueue();
      expect(await _chats(live), isEmpty);
      expect(heldDraft(live.container, 'ann', group: false), isNull);
      await Future<void>.delayed(kDraftWait * 2);
      expect(await _chats(live), isEmpty);
      await live.close();
    });

    test('a deleted or ended group takes its row along', () async {
      if (skip()) return;
      final live = HaloDb();
      await _group(live, 'g1');
      await _group(live, 'g2');
      await _person(live, 'ann');
      for (final g in ['g1', 'g2']) {
        typedDraft(live, g, _d('who brings'), group: true);
      }
      typedDraft(live, 'ann', _d('keep me'), group: false);
      await flushDrafts();
      await live.deleteGroup('g1');
      expect(await _chats(live), ['ann', 'group:g2']);
      expect(heldDraft(live.container, 'g1', group: true), isNull);
      await live.wipeEnded('g2');
      expect(await _chats(live), ['ann']);
      await live.close();
    });

    test('a row whose person goes goes with them', () async {
      if (skip()) return;
      final live = HaloDb();
      await _person(live, 'ann');
      await live.putDraft('ann', _d('x'), group: false);
      await (await live.open()).delete('contacts');
      expect(await _chats(live), isEmpty);
      await live.close();
    });

    test('a wipe: nothing waiting is written, nothing new is held', () async {
      if (skip()) return;
      final live = HaloDb();
      await live.open();
      typedDraft(live, 'ann', _d('gone'), group: false);
      forgetAllDrafts();
      typedDraft(live, 'ben', _d('after'), group: false);
      expect(heldDraft(live.container, 'ben', group: false), isNull);
      await Future<void>.delayed(kDraftWait * 2);
      await flushDrafts();
      expect(await _chats(live), isEmpty);
      await live.close();
    });

    test(
      'a shut or removed container is never made again by a draft',
      () async {
        if (skip()) return;
        final decoy = HaloDb(HaloContainer.decoy);
        await decoy.open();
        typedDraft(decoy, 'ann', _d('x'), group: false);
        await decoy.close();
        final path = p.join(docs.path, HaloContainer.decoy.dbFile);
        File(path).deleteSync();
        await Future<void>.delayed(kDraftWait * 2);
        expect(File(path).existsSync(), isFalse);
        // and its removal lets go of what it held
        typedDraft(decoy, 'ben', _d('y'), group: false);
        forgetDrafts(HaloContainer.decoy);
        expect(heldDraft(HaloContainer.decoy, 'ben', group: false), isNull);
      },
    );

    test('a timed chat\'s draft goes when its timer would have taken it, '
        'and is never read back after', () async {
      if (skip()) return;
      final live = HaloDb();
      for (final id in ['ann', 'ben', 'cat', 'dan', 'eve']) {
        await _person(live, id);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      // 30 seconds, last typed 31 and 10 seconds ago; one with no clock,
      // a day old
      await live.putDraft(
        'ann',
        Draft('gone', at: now - 31000, burnSecs: 30),
        group: false,
      );
      await live.putDraft(
        'ben',
        Draft('not yet', at: now - 10000, burnSecs: 30),
        group: false,
      );
      await live.putDraft(
        'cat',
        Draft('no clock', at: now - 86400000),
        group: false,
      );
      // its chat is open: the composer is typed in, not left
      await live.putDraft(
        'dan',
        Draft('still open', at: now - 31000, burnSecs: 30),
        group: false,
      );
      await live.purgeExpired(draftOnScreen: (id, group) => id == 'dan');
      expect(await _chats(live), ['ben', 'cat', 'dan']);
      // one past its time the sweep has not reached: never read back
      await live.putDraft(
        'eve',
        Draft('late', at: now - 31000, burnSecs: 30),
        group: false,
      );
      expect(await readDraft(live, 'eve', group: false), isNull);
      await pumpEventQueue();
      expect(await _chats(live), ['ben', 'cat', 'dan']);
      // nor one held in memory
      typedDraft(
        live,
        'ann',
        Draft('typed', at: now - 31000, burnSecs: 30),
        group: false,
      );
      expect(heldDraft(live.container, 'ann', group: false), isNull);
      // and the clock is kept across a stop
      final next = await restart(live);
      expect((await readDraft(next, 'ben', group: false))?.burnSecs, 30);
      expect((await readDraft(next, 'cat', group: false))?.burnSecs, isNull);
      await next.close();
    });

    test('clearing a chat\'s history keeps its draft', () async {
      if (skip()) return;
      final live = HaloDb();
      await _person(live, 'ann');
      await _group(live, 'g1');
      await live.putDraft('ann', _d('still mine'), group: false);
      await live.putDraft('g1', _d('ours too'), group: true);
      await live.clearConversation('ann');
      await live.clearGroupConversation('g1');
      expect(await _chats(live), ['ann', 'group:g1']);
      await live.close();
    });

    test(
      'a drafts table that will not make leaves the file as it was',
      () async {
        if (skip()) return;
        final live = HaloDb();
        final db = await live.open();
        for (final t in ['contacts', 'groups']) {
          await db.execute('DROP TRIGGER drafts_${t}_gone');
        }
        await db.execute('DROP TABLE drafts');
        await db.execute('ALTER TABLE contacts RENAME TO contacts_was');
        // its trigger names a table that is not there: no throw
        await draftsTable(db);
        await db.execute('ALTER TABLE contacts_was RENAME TO contacts');
        final made = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name LIKE 'drafts%' "
          'ORDER BY name',
        );
        expect([for (final r in made) r['name']], ['drafts']);
        await live.close();
      },
    );

    test('the everyday file never holds a hidden chat\'s words', () async {
      if (skip()) return;
      final live = HaloDb();
      final vault = HaloDb.withKey(HaloContainer.vault, _vaultKey);
      await _person(live, 'ann');
      await _person(vault, 'zorro-hid');
      final s = await Session.withVault(live, vault);
      typedDraft(
        s.draftsOf('zorro-hid'),
        'zorro-hid',
        _d('meet by the old mill'),
        group: false,
      );
      typedDraft(s.draftsOf('ann'), 'ann', _d('hello'), group: false);
      await flushDrafts();
      await live.close();
      await vault.close();
      final every = File(p.join(docs.path, HaloContainer.everyday.dbFile));
      final bytes = every.readAsBytesSync();
      bool holds(String w) {
        final b = w.codeUnits;
        outer:
        for (var i = 0; i + b.length <= bytes.length; i++) {
          for (var j = 0; j < b.length; j++) {
            if (bytes[i + j] != b[j]) continue outer;
          }
          return true;
        }
        return false;
      }

      // the host runs without the cipher: the file reads as it is
      expect(holds('hello'), isTrue);
      expect(holds('old mill'), isFalse);
      expect(holds('zorro'), isFalse);
    });

    test('a quote is read by its uid, in its own chat, and not once past '
        'its time', () async {
      if (skip()) return;
      final live = HaloDb();
      await _person(live, 'ann');
      await _group(live, 'g1');
      final db = await live.open();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final (uid, group, burnAt) in [
        ('u-1', null, null),
        ('u-2', 'g1', null),
        ('u-3', null, now - 1000),
        ('u-4', 'g1', now + 60000),
      ]) {
        await db.insert('messages', {
          'peer_id': 'ann',
          'group_id': group,
          'direction': 'in',
          'plaintext': 'words of $uid',
          'sent_at': 1,
          'msg_uid': uid,
          'burn_at': burnAt,
        });
      }
      expect(
        (await live.messageIn('ann', 'u-1'))?['plaintext'],
        'words of u-1',
      );
      // a group's is not the 1:1 chat's, nor the other way
      expect(await live.messageIn('ann', 'u-2'), isNull);
      expect(await live.groupMessageIn('g1', 'u-1'), isNull);
      expect((await live.groupMessageIn('g1', 'u-2'))?['msg_uid'], 'u-2');
      // past its time and not swept yet: gone
      expect(await live.messageIn('ann', 'u-3'), isNull);
      expect((await live.groupMessageIn('g1', 'u-4'))?['msg_uid'], 'u-4');
      expect(await live.groupMessageIn('g2', 'u-2'), isNull);
      await live.close();
    });

    test('a write that comes due while its chat moves waits for the move, '
        'then is made', () async {
      if (skip()) return;
      final live = HaloDb();
      await _person(live, 'ann');
      typedDraft(live, 'ann', _d('typed before'), group: false);
      final let = holdDraftsOf(['ann']);
      await Future<void>.delayed(kDraftWait * 2);
      await flushDrafts();
      expect(await _chats(live), isEmpty);
      let();
      await pumpEventQueue();
      expect((await live.draftOf('ann', group: false))?.text, 'typed before');
      await live.close();
    });

    test('a copy an older version wrote for a restart becomes rows', () async {
      if (skip()) return;
      final every = HaloContainer.everyday.id;
      FlutterSecureStorage.setMockInitialValues({
        'kept_drafts':
            '{"p":{"$every|ann":"half","${HaloContainer.vault.id}|hid":"no"},'
            '"g":{"$every|g1":"see you"}}',
      });
      final live = HaloDb();
      await live.open();
      await live.putDraft('ann', _d('newer'), group: false);
      await restoreKeptDrafts(live);
      expect(await _chats(live), ['ann', 'group:g1']);
      expect((await live.draftOf('ann', group: false))?.text, 'newer');
      expect(
        await const FlutterSecureStorage().readAll(),
        isNot(contains('kept_drafts')),
      );
      await live.close();
    });
  });

  test('only new words start a draft\'s clock again', () async {
    final db = _Rows(MemDb());
    Draft? last() => heldDraft(db.container, 'ann', group: false);
    void typed(Draft d, {bool clock = false, bool known = true}) {
      typedDraft(db, 'ann', d, group: false, clock: clock, timedKnown: known);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    typed(Draft('hi', at: now - 5000, burnSecs: 3600));
    // put back with the composer's setting not read yet, or read as off:
    // the same words keep their clock
    typed(Draft('hi', at: now), known: false);
    typed(Draft('hi', at: now));
    expect(last()?.burnSecs, 3600);
    expect(last()?.at, now - 5000);
    // a quote picked is not new words either
    typed(Draft('hi', replyTo: 'u-1', at: now));
    expect(last()?.replyTo, 'u-1');
    expect(last()?.at, now - 5000);
    expect(last()?.burnSecs, 3600);
    // new words before the setting is read keep its timer, the time moves
    typed(Draft('hi there', replyTo: 'u-1', at: now), known: false);
    expect(last()?.burnSecs, 3600);
    expect(last()?.at, now);
    // new words with it read take it
    typed(Draft('hi there!', replyTo: 'u-1', at: now + 1));
    expect(last()?.burnSecs, isNull);
    // the person picks a timer: the draft takes it
    typed(
      Draft('hi there!', replyTo: 'u-1', at: now + 2, burnSecs: 30),
      clock: true,
    );
    expect(last()?.burnSecs, 30);
    expect(last()?.at, now + 2);
    endProcessForTest();
  });

  test('a decoy\'s delete takes the decoy\'s draft, never the everyday '
      'one', () async {
    final db = _Rows(MemDb(), HaloContainer.decoy);
    await _group(db, 'g1');
    typedDraft(db, 'g1', _d('x'), group: true);
    typedDraft(_Rows(MemDb()), 'g1', _d('y'), group: true);
    await db.deleteGroup('g1');
    expect(heldDraft(HaloContainer.decoy, 'g1', group: true), isNull);
    expect(heldDraft(HaloContainer.everyday, 'g1', group: true)?.text, 'y');
  });

  // the panic wipe ends the process and a decoy's removal deletes its
  // files, so what they let go of is read off the source; every other way
  // a draft goes is a behaviour test (vault_session, drafts_paths,
  // block_moves, the two screens)
  test('a decoy removal forgets its drafts in memory', () {
    final main = sourceOf('lib/app/state.dart');
    expect(
      bodyOf(main, 'Future<void> _dropDecoyFiles('),
      contains('forgetDrafts(HaloContainer.decoy);'),
    );
  });
}
