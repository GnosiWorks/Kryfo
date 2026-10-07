// SPDX-License-Identifier: GPL-3.0-or-later
// when a message was written rides in its envelope as 'w', set once and
// kept on every retry, so a block's spans judge a copy wrapped again by
// when it was written. one without it, from an older version, reads as
// before. what the spans are handed: never past the wrap, never far ahead
// of this clock, and the grace only as far as the copy leaves it open
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show blockStamp, kStampAhead, kUnblockGrace;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sender = SenderInfo(
  haloId: 'thumb-behave-boring',
  edPub: 'ed',
  onion: 'x.onion',
  xPub: 'ab',
);

Map<String, dynamic> _json(String wrapped) =>
    jsonDecode(wrapped.substring('halo/1:'.length)) as Map<String, dynamic>;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('on the wire', () {
    test('a message carries when it was written, and reads it back', () async {
      final w = await wrapMessage(
        'hello',
        msgUid: 'u1',
        sender: _sender,
        writtenAt: 1791393419123,
      );
      expect(_json(w)['w'], 1791393419123);
      final env = unwrapMessage(w);
      expect(env.writtenAt, 1791393419123);
      expect(env.message, 'hello');
      expect(env.msgUid, 'u1');
      expect(env.senderHaloId, _sender.haloId);
    });

    test('one not given a time is written now', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      final env = unwrapMessage(await wrapMessage('hello', sender: _sender));
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(env.writtenAt, inInclusiveRange(before, after));
    });

    test('one from a version without it reads as it always did', () {
      // as 0.4.2 wraps an opener with a reply and a timer
      const old =
          'halo/1:{"m":"hi there","u":"u2","q":"u1","pw":7,"pb":20,'
          '"h":"thumb-behave-boring","e":"ed","o":"x.onion","x":"ab","b":30}';
      final env = unwrapMessage(old);
      expect(env.writtenAt, isNull);
      expect(env.message, 'hi there');
      expect(env.msgUid, 'u2');
      expect(env.replyTo, 'u1');
      expect(env.powNonce, 7);
      expect(env.powBitsUsed, 20);
      expect(env.burnSeconds, 30);
      expect(env.senderHaloId, 'thumb-behave-boring');
    });

    test('a time that is no time is left out, and the rest still reads', () {
      for (final bad in ['"soon"', '-5', '0', 'null', '[1]', '{"a":1}']) {
        final env = unwrapMessage(
          'halo/1:{"m":"hi","u":"u3","w":$bad,"h":"thumb-behave-boring"}',
        );
        expect(env.writtenAt, isNull, reason: bad);
        expect(env.message, 'hi', reason: bad);
        expect(env.msgUid, 'u3', reason: bad);
      }
      expect(unwrapMessage('halo/1:{"m":"hi","w":1.5e12}').writtenAt, 1.5e12);
    });

    test('a retry from the outbox carries when its row was written, not '
        'when it goes again', () async {
      const at = 1791393419123;
      for (final group in [null, 'grp000000001']) {
        final env = unwrapMessage(
          await wrapRedelivery({
            'plaintext': 'X',
            'msg_uid': 'u4',
            'group_id': group,
            'sent_at': at,
          }, sender: _sender),
        );
        expect(env.writtenAt, at, reason: '$group');
        expect(env.groupId, group);
      }
    });
  });

  group('what the spans are handed', () {
    const now = 1791393419000;

    test('the time it was written, with the grace, when the lane says '
        'nothing of the wrap', () {
      final s = blockStamp(written: now - 3600000, came: now, now: now);
      expect(s, (at: now - 3600000, slack: kUnblockGrace));
    });

    test('the wrap time from a version that does not say', () {
      final s = blockStamp(wrapped: now - 3600000, came: now, now: now);
      expect(s, (at: now - 3600000, slack: kUnblockGrace));
      expect(blockStamp(came: now, now: now), isNull);
      expect(blockStamp(wrapped: 0, came: now, now: now), isNull);
    });

    test('never past the wrap: both are their clock', () {
      final s = blockStamp(
        written: now + 86400000,
        wrapped: now - 3600000,
        came: now,
        now: now,
      );
      expect(s!.at, now - 3600000);
    });

    test('one far ahead of this clock is taken as now', () {
      expect(blockStamp(written: now + 86400000, came: now, now: now)!.at, now);
      expect(
        blockStamp(written: now + kStampAhead + 1, came: now, now: now)!.at,
        now,
      );
      // a little ahead is a clock a little fast, kept as it is
      expect(
        blockStamp(written: now + kStampAhead, came: now, now: now)!.at,
        now + kStampAhead,
      );
    });

    test('the grace only as far as the copy leaves open: it came that long '
        'after it was wrapped', () {
      // wrapped a second before it came: their clock is at most that slow
      expect(
        blockStamp(
          written: now - 200000,
          wrapped: now - 1000,
          came: now,
          now: now,
        ),
        (at: now - 200000, slack: 1000),
      );
      // held by a relay an hour: the grace
      expect(
        blockStamp(
          written: now - 3600000,
          wrapped: now - 3600000,
          came: now,
          now: now,
        ),
        (at: now - 3600000, slack: kUnblockGrace),
      );
      // their clock ahead of ours: nothing more than the stamp
      expect(
        blockStamp(
          written: now + 5000,
          wrapped: now + 5000,
          came: now,
          now: now,
        ),
        (at: now + 5000, slack: 0),
      );
      // opened from the seal: from when it came, not from now
      expect(
        blockStamp(
          written: now - 7200000,
          wrapped: now - 7200000 + 30000,
          came: now - 7200000 + 60000,
          now: now,
        ),
        (at: now - 7200000, slack: 30000),
      );
    });
  });
}
