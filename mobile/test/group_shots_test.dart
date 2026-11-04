// SPDX-License-Identifier: GPL-3.0-or-later
// a group's screenshot block as its rows and its wire hold it: one width
// on the wire whatever it says, taken only from the admin on record who is
// still in it, the newest stamp first, on everyone's phone once it is on
// and on for everyone once every member's app can block
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/group_shots.dart';
import 'package:kryfo/l10n/app_localizations.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart' show roomFrame;
import 'package:kryfo/typing.dart'
    show capsAfter, capsOfText, kCapGroupShots, kMyCaps;

const _now = 1700000000000;

Map<String, Object?> _row({
  String admin = 'ann',
  int isAdmin = 0,
  bool room = false,
  bool ended = false,
  Map<String, Object?> shots = const {},
}) => {
  'group_id': 'g1',
  'is_admin': isAdmin,
  'admin_id': admin,
  'room_pub': room ? 'f' * 64 : null,
  'ended_at': ended ? 5 : null,
  'ended_by': ended ? admin : null,
  ...shots,
};

GroupShots _was({bool on = false, bool all = false, int at = 0}) =>
    GroupShots(on: on, all: all, at: at, known: true);

void main() {
  group('the word', () {
    test('goes at one width whatever it says', () {
      final sizes = {
        for (final on in [true, false])
          for (final all in [true, false])
            for (final at in [0, 1, _now, kShotsStampMost])
              jsonEncode(
                GroupShotsWord(on: on, all: all, at: at).toWire(),
              ).length,
      };
      expect(sizes, hasLength(1));
    });

    test('round trips, and a broken one is no word', () {
      for (final w in [
        const GroupShotsWord(on: true, all: false, at: _now),
        const GroupShotsWord(on: false, all: false, at: 0),
        const GroupShotsWord(on: true, all: true, at: kShotsStampMost),
      ]) {
        expect(GroupShotsWord.fromWire(w.toWire()), w);
      }
      expect(GroupShotsWord.fromWire({'o': 1, 'e': 0, 'a': '12'}), isNull);
      expect(GroupShotsWord.fromWire({'o': 2, 'e': 0, 'a': '$_now'}), isNull);
      expect(GroupShotsWord.fromWire({'o': 1, 'a': '$_now'}), isNull);
      expect(GroupShotsWord.fromWire('on'), isNull);
    });

    test('rides the admin\'s messages, the shots and caps controls', () async {
      const w = GroupShotsWord(on: true, all: false, at: _now);
      final msg = unwrapMessage(
        await wrapMessage('hi', msgUid: 'u', groupId: 'g1', groupShots: w),
      );
      expect(msg.groupShots, w);
      final ctl = unwrapMessage(
        await wrapMessage(
          '',
          groupId: 'g1',
          groupControl: const GroupControl(type: 'shots', shots: w),
        ),
      );
      expect(ctl.groupControl!.type, 'shots');
      expect(ctl.groupControl!.shots, w);
      final caps = unwrapMessage(
        await wrapMessage(
          '',
          groupId: 'g1',
          groupControl: const GroupControl(type: 'caps'),
        ),
      );
      expect(caps.groupControl!.type, 'caps');
      expect(caps.caps, contains(kCapGroupShots));
      final create = GroupControl.fromWire(
        const GroupControl(type: 'create', name: 'n', shots: w).toWire(),
      );
      expect(create!.shots, w);
    });

    test('the words for older versions are flagged, and a group frame '
        'never carries a 1:1 state', () async {
      final nudge = await wrapMessage(
        'update',
        msgUid: 'u',
        groupId: 'g1',
        shotsNudge: true,
      );
      expect(unwrapMessage(nudge).shotsNudge, isTrue);
      expect(unwrapMessage(nudge).message, 'update');
      expect(
        unwrapMessage(await wrapMessage('x', msgUid: 'v')).shotsNudge,
        isFalse,
      );
      // the 1:1 stamp leaves a group's frame as it was
      final g = await wrapMessage('hi', msgUid: 'w', groupId: 'g1');
      expect(shotsStamped(g, const ShotsWord(on: true, at: _now)), g);
      expect(unwrapMessage(g).shots, isNull);
    });
  });

  group('the list of what a phone understands', () {
    test('rides group frames with the group\'s name in it, and no room '
        'frame', () async {
      final g = unwrapMessage(
        await wrapMessage('hi', msgUid: 'u', groupId: 'g1'),
      );
      expect(g.caps, contains(kCapGroupShots));
      final room = roomFrame(
        await wrapMessage('hi', msgUid: 'u', groupId: 'g1'),
        'a' * 64,
      )!;
      expect(unwrapMessage(room).caps, isNull);
      // a 1:1 frame gets its list at the seal, not here
      expect(unwrapMessage(await wrapMessage('hi', msgUid: 'v')).caps, isNull);
    });

    test('a row reads the group name, and an older phone\'s list without it '
        'waits', () {
      expect(capsOfText('gs,ty'), {kCapGroupShots, 'ty'});
      expect(groupShotsCan({'bob': capsOfText('ty')}, 'bob'), isFalse);
      expect(groupShotsCan({'bob': capsOfText('gs')}, 'bob'), isTrue);
      expect(groupShotsCan(const {}, 'bob'), isFalse);
    });
  });

  group('who speaks for it', () {
    test('the admin on record who is still in it', () {
      expect(groupShotsFrom('ann', _row(), ['me', 'ann', 'bob']), isTrue);
      expect(groupShotsFrom('bob', _row(), ['me', 'ann', 'bob']), isFalse);
      // left: speaks no more
      expect(groupShotsFrom('ann', _row(), ['me', 'bob']), isFalse);
      // a room always blocks, an ended group holds nothing
      expect(groupShotsFrom('ann', _row(room: true), ['me', 'ann']), isFalse);
      expect(groupShotsFrom('ann', _row(ended: true), ['me', 'ann']), isFalse);
      expect(groupShotsFrom('ann', null, ['ann']), isFalse);
    });

    test('only that admin turns it', () {
      final mine = _row(admin: 'me', isAdmin: 1);
      expect(mayTurnGroupShots(mine, 'me', ['me', 'bob']), isTrue);
      expect(mayTurnGroupShots(mine, 'me', ['bob']), isFalse);
      expect(mayTurnGroupShots(_row(), 'me', ['me', 'ann']), isFalse);
      expect(
        mayTurnGroupShots(_row(admin: 'me', isAdmin: 1, room: true), 'me', [
          'me',
        ]),
        isFalse,
      );
      expect(
        mayTurnGroupShots(_row(admin: 'me', isAdmin: 1, ended: true), 'me', [
          'me',
        ]),
        isFalse,
      );
    });
  });

  group('taking a word', () {
    test('the newest stamp wins, on wins a tie', () {
      final was = _was(on: true, at: 200);
      expect(
        groupShotsTaken(
          was,
          const GroupShotsWord(on: false, all: false, at: 100),
          now: _now,
        ),
        isNull,
      );
      final off = groupShotsTaken(
        was,
        const GroupShotsWord(on: false, all: false, at: 300),
        now: _now,
      );
      expect(off!['shots_on'], 0);
      expect(off['shots_line'], kGroupLineOff);
      expect(off['shots_by'], kShotsByThem);
      expect(
        groupShotsTaken(
          _was(at: 200),
          const GroupShotsWord(on: true, all: false, at: 200),
          now: _now,
        )!['shots_on'],
        1,
      );
      expect(
        groupShotsTaken(
          was,
          const GroupShotsWord(on: false, all: false, at: 200),
          now: _now,
        ),
        isNull,
      );
    });

    test('a stamp more than a day ahead is not taken', () {
      final ahead = _now + const Duration(days: 2).inMilliseconds;
      expect(
        groupShotsTaken(
          _was(),
          GroupShotsWord(on: true, all: true, at: ahead),
          now: _now,
        ),
        isNull,
      );
    });

    test('a word that says nothing new is no change', () {
      expect(
        groupShotsTaken(
          _was(on: true, all: true, at: 5),
          const GroupShotsWord(on: true, all: true, at: 5),
          now: _now,
        ),
        isNull,
      );
      expect(
        groupShotsTaken(
          _was(),
          const GroupShotsWord(on: false, all: false, at: 0),
          now: _now,
        ),
        isNull,
      );
    });

    test('its line says what moved', () {
      int? line(GroupShots was, GroupShotsWord w) =>
          groupShotsTaken(was, w, now: _now)?['shots_line'] as int?;
      expect(
        line(_was(), const GroupShotsWord(on: true, all: true, at: 9)),
        kGroupLineOn,
      );
      expect(
        line(_was(), const GroupShotsWord(on: true, all: false, at: 9)),
        kGroupLineOnWait,
      );
      expect(
        line(
          _was(on: true, at: 5),
          const GroupShotsWord(on: true, all: true, at: 9),
        ),
        kGroupLineStarted,
      );
      expect(
        line(
          _was(on: true, all: true, at: 5),
          const GroupShotsWord(on: true, all: false, at: 9),
        ),
        kGroupLinePaused,
      );
    });
  });

  group('who can', () {
    test('everyone known with the bit, the admin counted as able', () {
      expect(groupShotsAll(['me'], 'me', const {}), isTrue);
      expect(
        groupShotsAll(
          ['me', 'bob'],
          'me',
          {
            'bob': {kCapGroupShots},
          },
        ),
        isTrue,
      );
      // unknown, or without the bit
      expect(groupShotsAll(['me', 'bob'], 'me', const {}), isFalse);
      expect(groupShotsAll(['me', 'bob'], 'me', {'bob': <String>{}}), isFalse);
      expect(
        groupShotsWaitsFor(
          ['me', 'bob', 'cat'],
          'me',
          {'bob': capsOfText(kMyCaps.join(','))},
        ),
        ['cat'],
      );
    });

    test('adding someone unknown pauses it, removing the last one waited '
        'for starts it', () {
      const caps = {
        'bob': {kCapGroupShots},
      };
      final on = _was(on: true, all: true, at: 10);
      final paused = groupShotsAllMoved(
        on,
        all: groupShotsAll(['me', 'bob', 'cat'], 'me', caps),
        now: _now,
      );
      expect(paused!['shots_all'], 0);
      expect(paused['shots_line'], kGroupLinePaused);
      // a new stamp: every member takes it
      expect(paused['shots_at'] as int, greaterThan(10));
      final back = groupShotsAllMoved(
        _was(on: true, at: paused['shots_at'] as int),
        all: groupShotsAll(['me', 'bob'], 'me', caps),
        now: _now,
      );
      expect(back!['shots_all'], 1);
      expect(back['shots_line'], kGroupLineStarted);
      // off, or nothing moved: no change
      expect(groupShotsAllMoved(_was(), all: true, now: _now), isNull);
      expect(groupShotsAllMoved(on, all: true, now: _now), isNull);
    });

    test('a member\'s newer message without the bit pauses it', () {
      final after = capsAfter(
        'gs,ty',
        100,
        carried: null,
        counts: true,
        written: 200,
      );
      expect(
        groupShotsAll(['me', 'bob'], 'me', {'bob': capsOfText(after!.caps)}),
        isFalse,
      );
    });
  });

  group('what a phone does', () {
    test('an updated phone blocks as soon as it is on; on for everyone '
        'only once all can', () {
      final waiting = GroupShots.ofRow(
        _row(shots: {'shots_on': 1, 'shots_at': 5}),
      );
      expect(waiting.blocking, isTrue);
      expect(waiting.forAll, isFalse);
      expect(waiting.waiting, isTrue);
      final all = GroupShots.ofRow(
        _row(shots: {'shots_on': 1, 'shots_all': 1, 'shots_at': 5}),
      );
      expect(all.blocking, isTrue);
      expect(all.forAll, isTrue);
      final off = GroupShots.ofRow(_row());
      expect(off.blocking, isFalse);
      expect(off.forAll, isFalse);
    });

    test('a room always blocks, an ended group never, a decoy is on for '
        'everyone at once', () {
      expect(GroupShots.ofRow(_row(room: true)).blocking, isTrue);
      expect(
        GroupShots.ofRow(
          _row(ended: true, shots: {'shots_on': 1, 'shots_all': 1}),
        ).blocking,
        isFalse,
      );
      expect(
        GroupShots.ofRow(_row(shots: {'shots_on': 1}), quiet: true).forAll,
        isTrue,
      );
      expect(const GroupShots().blocking, isFalse);
    });

    test('the admin\'s turn takes a stamp past the last one seen', () {
      final put = groupShotsTurned(
        _was(at: _now + 50),
        on: true,
        all: false,
        now: _now,
      );
      expect(put['shots_at'], _now + 51);
      expect(put['shots_on'], 1);
      expect(put['shots_all'], 0);
      expect(put['shots_by'], kShotsByMe);
      expect(put['shots_line'], kGroupLineOnWait);
      final off = groupShotsTurned(
        _was(on: true, all: true, at: 3),
        on: false,
        all: true,
        now: _now,
      );
      expect(off['shots_all'], 0);
      expect(off['shots_line'], kGroupLineOff);
    });

    test('a member owes the admin its bits once per stamp that waits', () {
      expect(
        groupShotsOwesCaps(
          const GroupShots(on: true, at: 9, told: 1, known: true),
        ),
        isTrue,
      );
      expect(
        groupShotsOwesCaps(
          const GroupShots(on: true, at: 9, told: 9, known: true),
        ),
        isFalse,
      );
      expect(
        groupShotsOwesCaps(
          const GroupShots(on: true, all: true, at: 9, known: true),
        ),
        isFalse,
      );
      expect(groupShotsOwesCaps(const GroupShots(at: 9, known: true)), isFalse);
    });
  });

  // a member without 'gs' runs an older Kryfo or Kryfo on a computer:
  // every line about them is true of both and says neither
  test('no screenshot line asks a member without the block to update', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    // the one an older app shows, which this version drops (kGroupNudgeWire)
    const olderOnly = {'groupShotsOldNotice'};
    final shots = [
      for (final e in arb.entries)
        if (!e.key.startsWith('@') &&
            e.key.contains('Shots') &&
            !olderOnly.contains(e.key))
          e,
    ];
    expect(shots.length, greaterThan(40));
    for (final e in shots) {
      final v = (e.value as String).toLowerCase();
      expect(v, isNot(contains('update')), reason: e.key);
    }
    // the lines about who is not covered yet name no app to update, in
    // every language
    const waiting = [
      'groupShotsWaitingTitle',
      'groupShotsWaitingHint',
      'groupShotsNeedsUpdate',
      'groupShotsStartsWhenAll',
      'groupShotsWaitAdminOnly',
      'groupShotsYouTurnedOnWait',
      'groupShotsTheyTurnedOnWait',
      'groupShotsPaused',
      'groupShotsAddPauses',
    ];
    for (final f in Directory('lib/l10n').listSync()) {
      if (!f.path.endsWith('.arb')) continue;
      final m =
          jsonDecode(File(f.path).readAsStringSync()) as Map<String, dynamic>;
      for (final k in waiting) {
        expect(m[k], isA<String>(), reason: '${f.path}: $k');
        expect(m[k], isNot(contains('Kryfo')), reason: '${f.path}: $k');
      }
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.groupShotsNeedsUpdate,
      'Can’t block screenshots on their device yet, or hasn’t been online '
      'since',
    );
    for (final s in [en.groupShotsWaitingHint, en.groupShotsPaused]) {
      for (final w in ['phone', 'computer', 'android', 'windows']) {
        expect(s.toLowerCase(), isNot(contains(w)), reason: s);
      }
    }
  });
}
