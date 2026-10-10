// SPDX-License-Identifier: GPL-3.0-or-later
// when a message was written rides in its envelope as 'w', set once and
// kept on every retry. one without it, from an older version, reads as
// before. an ended block keeps out what may have reached the relay while
// it held, by this clock, and what their own two stamps say was written
// while it held: how long before the wrap it was written, never when
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show heldBySpans;
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

  group('what an ended block keeps out', () {
    const h = 3600000;
    // a block of two hours that ended at to
    const from = 1791393419000;
    const to = from + 2 * h;
    const ended = [(from, to)];

    test('what came live after the unblock is let in whatever their clock '
        'reads: hours slow, or a day ahead', () {
      for (final skew in [-5 * h, -20 * 60000, 0, 24 * h]) {
        expect(
          heldBySpans(
            ended,
            reached: (from: to + 1000, until: to + 1000),
            came: to + 1000,
            written: to + 500 + skew,
            wrapped: to + 900 + skew,
          ),
          isFalse,
          reason: '$skew',
        );
      }
    });

    test('a stored copy that may have reached the relay while the block held '
        'stays out, whatever its stamps say', () {
      for (final w in [from + h, to + 60000, to + 24 * h]) {
        expect(
          heldBySpans(
            ended,
            reached: (from: to - 60000, until: to + 5000),
            came: to + 6000,
            written: w,
            wrapped: w,
          ),
          isTrue,
          reason: '$w',
        );
      }
      // nothing known of when it reached it: any time before it came
      expect(
        heldBySpans(ended, reached: (from: 0, until: to + 5000), came: 0),
        isTrue,
      );
      expect(heldBySpans(ended, came: to + 5000), isTrue);
    });

    test('a stored copy the relay took after the unblock, or before the '
        'block, is let in', () {
      expect(
        heldBySpans(ended, reached: (from: to, until: to + h), came: to + h),
        isFalse,
      );
      expect(
        heldBySpans(
          ended,
          reached: (from: from - h, until: from - 1000),
          came: to + h,
        ),
        isFalse,
      );
    });

    test('a copy sent again after the unblock of what was written while it '
        'held stays out by how long before it went it was written, with '
        'their clock five hours slow', () {
      const skew = -5 * h;
      const wrote = from + 30 * 60000;
      const went = to + 60000;
      expect(
        heldBySpans(
          ended,
          reached: (from: went, until: went),
          came: went,
          written: wrote + skew,
          wrapped: went + skew,
        ),
        isTrue,
      );
      // written ten seconds after the unblock and sent again two minutes
      // on, on the same slow clock: let in
      expect(
        heldBySpans(
          ended,
          reached: (from: to + 120000, until: to + 120000),
          came: to + 120000,
          written: to + 10000 + skew,
          wrapped: to + 120000 + skew,
        ),
        isFalse,
      );
    });

    test('with no wrap time, or a written time past it, it counts as '
        'written when it went', () {
      expect(
        heldBySpans(
          ended,
          reached: (from: to + 1000, until: to + 1000),
          came: to + 1000,
          written: from + h,
        ),
        isFalse,
      );
      expect(
        heldBySpans(
          ended,
          reached: (from: to + 1000, until: to + 1000),
          came: to + 1000,
          written: to + 9 * h,
          wrapped: from + h,
        ),
        isFalse,
      );
    });
  });
}
