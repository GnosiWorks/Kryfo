// SPDX-License-Identifier: GPL-3.0-or-later
// when a message was written rides in its envelope as 'w', set once and
// kept on every retry. one without it, from an older version, reads as
// before. an ended block keeps out what may have reached the relay while
// it held, by this clock, and what their own two stamps say was written
// while it held: how long before the wrap it was written, never when
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show heldBySpans, kUnblockGrace, stampHeld;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/outbox.dart';
import 'package:kryfo/relay_poll.dart' show Reached;
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

  group('what an ended block keeps out', () {
    const h = 3600000;
    // a block of two hours that ended at to
    const from = 1791393419000;
    const to = from + 2 * h;
    const ended = [(from, to)];
    const now = to + 3 * h;

    bool held(Reached? reached, {int? written, int? wrapped, int? came}) =>
        heldBySpans(
          ended,
          reached: reached,
          came: came ?? reached?.until ?? now,
          now: now,
          written: written,
          wrapped: wrapped,
        );

    test('what came live after the unblock is let in whatever their clock '
        'reads: hours slow, or a day ahead', () {
      for (final skew in [-5 * h, -20 * 60000, 0, 24 * h]) {
        expect(
          held(
            (from: to + 1000, until: to + 1000),
            written: to + 500 + skew,
            wrapped: to + 900 + skew,
          ),
          isFalse,
          reason: '$skew',
        );
      }
    });

    test('a copy the relay took before the unblock, while the block held, '
        'stays out whatever its stamps say', () {
      for (final w in [from + h, to + 60000, to + 24 * h]) {
        for (final r in [
          (from: to - 60000, until: to - 1000),
          (from: 0, until: to),
        ]) {
          expect(
            held(r, written: w, wrapped: w),
            isTrue,
            reason: '$w $r',
          );
        }
      }
    });

    test('a stored copy whose window runs past the unblock, or whose relay '
        'was never heard before, is judged by its stamps: an hour after the '
        'unblock comes in, an hour before stays out', () {
      for (final r in [
        (from: to - 180000, until: to + 2 * h),
        (from: 0, until: to + 2 * h),
      ]) {
        expect(
          held(r, written: to + h, wrapped: to + h),
          isFalse,
          reason: '$r',
        );
        expect(
          held(r, written: to - h, wrapped: to - h),
          isTrue,
          reason: '$r',
        );
        // a version that says nothing: nothing to keep it out by
        expect(held(r), isFalse, reason: '$r');
      }
    });

    test('a stored copy the relay took after the unblock, or before the '
        'block, is let in', () {
      expect(held((from: to, until: to + h)), isFalse);
      expect(held((from: from - h, until: from - 1000), came: to + h), isFalse);
    });

    test('a copy sent again after the unblock of what was written while it '
        'held stays out by how long before it went it was written, with '
        'their clock five hours slow', () {
      const skew = -5 * h;
      const wrote = from + 30 * 60000;
      const went = to + 60000;
      expect(
        held(
          (from: went, until: went),
          written: wrote + skew,
          wrapped: went + skew,
        ),
        isTrue,
      );
      // written ten seconds after the unblock and sent again two minutes
      // on, on the same slow clock: let in
      expect(
        held(
          (from: to + 120000, until: to + 120000),
          written: to + 10000 + skew,
          wrapped: to + 120000 + skew,
        ),
        isFalse,
      );
    });

    test('with no wrap time, as on the onion lane, the written stamp and '
        'the grace judge it', () {
      const live = (from: to + 1000, until: to + 1000);
      expect(held(live, written: from + h), isTrue);
      expect(held(live, written: to - kUnblockGrace - 1000), isTrue);
      // the last minutes before the unblock are given to a slow clock
      expect(held(live, written: to - 5 * 60000), isFalse);
      expect(held(live, written: to + 500), isFalse);
      expect(held(live), isFalse);
    });

    test('with no lane to say when it reached the relay, its stamps judge '
        'it as before, and it is not taken as held back', () {
      expect(held(null, written: to + h, wrapped: to + h, came: now), isFalse);
      expect(held(null), isFalse);
      expect(
        held(null, written: from + h, wrapped: from + h, came: now),
        isTrue,
      );
      // one far ahead is taken as now
      expect(held(null, written: now + 24 * h, came: now), isFalse);
      expect(stampHeld(ended, written: from + h, came: now, now: now), isTrue);
    });
  });
}
