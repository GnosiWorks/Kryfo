// SPDX-License-Identifier: GPL-3.0-or-later
// what a restore must not undo: a timed copy from before it counts from
// then, our unsends and edits are kept to go again, and what of ours the
// file still had waiting waits for a tap
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show holdOutboxAfterRestore, holdRestoredOutbox, kNotSent;
import 'package:kryfo/read_burn.dart' show burnCameAt;
import 'package:kryfo/heal.dart' show kRestoreCutPref;
import 'package:kryfo/restore_undo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mem_db.dart';

void main() {
  const day = 24 * 3600 * 1000;
  const now = 100 * day;

  group('a timed copy after a restore', () {
    test('with no restore it counts from when it came', () {
      expect(burnCameAt(now, written: now - 3 * day), now);
      expect(
        burnCameAt(
          now,
          reached: (from: 0, until: now - 3 * day),
          written: now - 3 * day,
        ),
        now,
      );
    });

    test('a catch-up after the restore, its window opening before it, '
        'counts from when it was written', () {
      final landed = now - 3600 * 1000;
      // as the engine hands one: from the file's anchor to the subscribe,
      // which began after the landing
      final caughtUp = (from: now - 5 * day, until: now - 60000);
      expect(
        burnCameAt(
          now,
          reached: caughtUp,
          written: now - 3 * day,
          restoredAt: landed,
        ),
        now - 3 * day,
      );
      // no window at all: written before the restore is enough
      expect(
        burnCameAt(now, written: now - 2 * day, restoredAt: landed),
        now - 2 * day,
      );
    });

    test('a copy whose window opens after the landing, or one written '
        'since, is new here', () {
      final landed = now - 3600 * 1000;
      // live: from = until = when it came
      expect(
        burnCameAt(
          now,
          reached: (from: now - 1000, until: now - 1000),
          written: now - 2 * day,
          restoredAt: landed,
        ),
        now,
      );
      expect(
        burnCameAt(
          now,
          reached: (from: now - 5 * day, until: now),
          written: now - 1000,
          restoredAt: landed,
        ),
        now,
      );
    });

    test('the landing counts sixteen days, and the pref stays', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // the heal cut's pref, set as the restore lands
      await prefs.setInt(kRestoreCutPref, now);
      expect(kRestoreLandedPref, 'restore.cut');
      expect(restoreLandedOf(prefs, nowMs: now + 15 * day), now);
      expect(restoreLandedOf(prefs, nowMs: now + 17 * day), isNull);
      expect(prefs.getInt(kRestoreLandedPref), now);
      // the outbox hold, retried late, still counts from the landing
      expect(restoreHoldLanding(prefs), now);
    });

    test('a hold retried at a later start counts from the landing, not '
        'from that start', () {
      final boot = File('lib/app/state_boot.dart').readAsStringSync();
      final hold = boot.indexOf('await holdOutboxAfterRestore(');
      expect(hold, greaterThan(0));
      final call = boot.substring(hold, boot.indexOf('!=', hold));
      expect(call, contains('landed: restoreHoldLanding(prefs)'));
    });
  });

  group('our unsends and edits', () {
    test('kept sixteen days, a take-back over its edit, and read back by '
        'person or for every group', () async {
      final db = MemDb();
      await noteTaken(db, 'a', kTakenEdit, peer: 'p', at: now);
      await noteTaken(db, 'a', kTakenEdit, peer: 'p', at: now);
      await noteTaken(db, 'b', kTakenEdit, peer: 'p', at: now);
      await noteTaken(db, 'b', kTakenUnsend, peer: 'p', at: now + 1);
      await noteTaken(db, 'g1', kTakenUnsend, group: 'grp', at: now + 2);
      await noteTaken(db, 'q', kTakenUnsend, peer: 'q', at: now + 3);
      final p = await takenSince(db, peer: 'p', since: now);
      expect(
        [for (final r in p) (r.uid, r.kind)],
        [('a', kTakenEdit), ('b', kTakenUnsend)],
      );
      // no words are kept, only which and when
      expect(db.rows('taken_out').first.keys, isNot(contains('body')));
      expect([for (final r in await takenSince(db, since: 0)) r.uid], ['g1']);
      expect(await takenSince(db, peer: 'p', since: now + 1), hasLength(1));
      // a later one sweeps those past the keep
      await noteTaken(
        db,
        'late',
        kTakenUnsend,
        peer: 'p',
        at: now + kTakenKeep.inMilliseconds + 3,
      );
      expect(
        [for (final r in db.rows('taken_out')) r['msg_uid']],
        ['q', 'late'],
      );
    });
  });

  group('kept no longer', () {
    test('past the keep at every open and in a copy; with its message, '
        'its chat or its group', () async {
      final db = MemDb();
      await noteTaken(db, 'e1', kTakenEdit, peer: 'p', at: now);
      await noteTaken(db, 'u1', kTakenUnsend, peer: 'p', at: now);
      await noteTaken(db, 'q1', kTakenEdit, peer: 'q', at: now);
      await noteTaken(db, 'g1', kTakenEdit, group: 'g', at: now);
      await noteTaken(db, 'h1', kTakenUnsend, group: 'h', at: now);
      // noted last: a note sweeps only what is past the keep from its own time
      await noteTaken(db, 'old', kTakenUnsend, peer: 'p', at: now - 17 * day);
      Set<Object?> left() => {
        for (final r in db.rows('taken_out')) r['msg_uid'],
      };
      expect(await pruneTaken(db, nowMs: now), 1);
      expect(left(), {'e1', 'u1', 'q1', 'g1', 'h1'});
      // a message gone takes its edit; its take-back has no message
      await dropTaken(db, uid: 'e1');
      await dropTaken(db, uid: 'u1');
      expect(left(), {'u1', 'q1', 'g1', 'h1'});
      // a cleared chat keeps its take-backs, its edits go
      await dropTaken(db, peer: 'p', editsOnly: true);
      await dropTaken(db, group: 'h', editsOnly: true);
      expect(left(), {'u1', 'q1', 'g1', 'h1'});
      await dropTaken(db, peer: 'q');
      await dropTaken(db, group: 'g');
      expect(left(), {'u1', 'h1'});
      // the open prunes too, once the table is there
      await takenTablesAtOpen(db);
      expect(left(), isEmpty, reason: 'made long before this clock');
    });
  });

  group('the outbox a file brings', () {
    test('every row of ours still waiting goes not sent; theirs, sent ones '
        'and ones written since stay', () async {
      final db = MemDb();
      Future<void> row(String uid, String dir, int sent, int at) =>
          db.insert('messages', {
            'peer_id': 'p',
            'direction': dir,
            'plaintext': uid,
            'sent_at': at,
            'msg_uid': uid,
            'sent': sent,
            'delivered': 0,
          });
      await row('waiting', 'out', 0, now - day);
      await row('went', 'out', 1, now - day);
      await row('theirs', 'in', 0, now - day);
      await row('since', 'out', 0, now + 1);
      expect(await holdRestoredOutbox(db, before: now), 1);
      Map<Object?, Object?> sent() => {
        for (final r in db.rows('messages')) r['msg_uid']: r['sent'],
      };
      expect(sent(), {'waiting': kNotSent, 'went': 1, 'theirs': 0, 'since': 0});
      // on the first start after the restore: rows from before the landing
      // or the file, whichever is later
      await db.update(
        'messages',
        {'sent': 0},
        where: 'msg_uid = ?',
        whereArgs: ['waiting'],
      );
      expect(
        await holdOutboxAfterRestore(
          db,
          landed: now - 2 * day,
          made: now - 3600 * 1000,
          nowMs: now,
        ),
        1,
      );
      expect(sent()['waiting'], kNotSent);
      expect(sent()['since'], 0);
      // a copy that leaves the phone: all of ours still waiting
      expect(await holdRestoredOutbox(db), 1);
      expect(sent()['since'], kNotSent);
      // one that fails says so, and the restore's mark stays for the next
      await db.update(
        'messages',
        {'sent': 0},
        where: 'msg_uid = ?',
        whereArgs: ['waiting'],
      );
      db.failOn = 'update:messages';
      expect(await holdOutboxAfterRestore(db, nowMs: now), isNull);
    });
  });
}
