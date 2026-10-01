import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/media_resend.dart';
import 'package:kryfo/message_envelope.dart';

void main() {
  test('lists missing slices lowest first, capped', () {
    expect(missingSlices({0, 1, 3, 5}, 6), [2, 4]);
    expect(missingSlices({}, 3), [0, 1, 2]);
    expect(missingSlices({0, 1, 2}, 3), isEmpty);
    expect(missingSlices({}, 1000).length, kNeedMaxIndices);
    expect(missingSlices({}, 0), isEmpty);
    expect(missingSlices({}, kMaxSlices + 1), isEmpty);
  });

  group('asking', () {
    const min = 60 * 1000;
    bool ask({
      int last = 0,
      int asked = 0,
      int asks = 0,
      bool can = true,
      int have = 97,
      int total = 100,
      int now = 100 * min,
    }) => shouldAskNow(
      now: now,
      lastSliceAt: last,
      askedAt: asked,
      asks: asks,
      canResend: can,
      have: have,
      total: total,
    );

    test('waits while slices are still arriving', () {
      expect(ask(last: 100 * min - 30 * 1000), false);
      expect(ask(last: 97 * min), true);
    });
    test('never asks a sender that cannot resend', () {
      expect(ask(can: false), false);
    });
    test('skips whole, empty and single-slice files', () {
      expect(ask(have: 100), false);
      expect(ask(have: 0), false);
      expect(ask(have: 0, total: 1), false);
    });
    test('backs off and gives up', () {
      expect(ask(asked: 99 * min, asks: 1), false);
      expect(ask(asked: 97 * min, asks: 1), true);
      expect(ask(asked: 96 * min, asks: 2), false);
      expect(ask(asked: 94 * min, asks: 2), true);
      expect(ask(asked: 1, asks: kNeedMaxAsks), false);
    });

    const sec = 1000;
    const now = 100 * min;

    test('asks after 45 s of quiet', () {
      expect(ask(last: now - 44 * sec), false);
      expect(ask(last: now - 45 * sec), true);
    });
    test('an ask that brought slices owes no backoff', () {
      // slices came in after the third ask in a row
      expect(ask(last: now - 50 * sec, asked: now - 100 * sec, asks: 3), true);
      // nothing since it: fifteen minutes
      expect(
        ask(last: now - 101 * sec, asked: now - 100 * sec, asks: 3),
        false,
      );
      expect(ask(last: now - 16 * min, asked: now - 15 * min, asks: 3), true);
    });
    test('only asks that brought nothing count toward giving up', () {
      expect(
        ask(last: now - 50 * sec, asked: now - 100 * sec, asks: kNeedMaxAsks),
        true,
      );
      expect(
        ask(last: now - 90 * min, asked: now - 80 * min, asks: kNeedMaxAsks),
        false,
      );
    });
    test('an answered ask is followed once the sender takes asks again', () {
      expect(kNeedMinGapMs - kNeedSlackMs, greaterThan(kResendMinGapMs));
      expect(ask(last: now - 50 * sec, asked: now - 80 * sec, asks: 1), false);
      expect(ask(last: now - 50 * sec, asked: now - 85 * sec, asks: 1), true);
    });
    test('the count starts again after an ask that brought slices', () {
      int next(int last, int asked, int asks) =>
          asksAfterAsk(lastSliceAt: last, askedAt: asked, asks: asks);
      expect(next(10, 0, 0), 1);
      expect(next(10, 20, 1), 2);
      // a slice stamped in the same instant came before it
      expect(next(20, 20, 4), 5);
      expect(next(30, 20, 4), 1);
    });
    test('an ask due on a tick is made on it, the tick a moment early', () {
      expect(ask(asked: now - 2 * min + 300, asks: 1), true);
      expect(ask(asked: now - 2 * min + kNeedSlackMs + 1, asks: 1), false);
    });
    test('the due check needs the row alone', () {
      bool due({int last = 0, int asked = 0, int asks = 0}) =>
          askDue(now: now, lastSliceAt: last, askedAt: asked, asks: asks);
      expect(due(last: now - 30 * sec), false);
      expect(due(last: now - 45 * sec), true);
      expect(due(asked: now - 100 * sec, asks: 1), false);
      expect(due(asked: now - 2 * min, asks: 1), true);
    });
    test('a tick every 15 s, 200 slices an ask', () {
      expect(kNeedTickMs, 15 * sec);
      // an older sender's parser turns a longer list down
      expect(kNeedMaxIndices, 200);
    });
  });

  group('the catch-up hold', () {
    const sec = 1000;
    const t0 = 1000 * sec;
    // a want hours old: only the hold stands between it and an ask
    bool due(CatchupHold h, int now) =>
        askDue(now: now, lastSliceAt: 1, askedAt: 0, asks: 0, heldAt: h.heldAt);

    test('quiet counts from the last hold as well as the last slice', () {
      final h = CatchupHold()..heldAt = t0;
      expect(due(h, t0 + kNeedQuietMs - 1), false);
      expect(due(h, t0 + kNeedQuietMs), true);
    });

    test('holds while a catch-up runs, of any length, and quiet counts from '
        'its end', () {
      final h = CatchupHold();
      expect(h.look(now: t0, active: 0, begun: 3), false);
      // the long turn a relay gets after three capped check-ins
      for (var t = t0 + 15 * sec; t <= t0 + 90 * sec; t += 15 * sec) {
        expect(h.look(now: t, active: 1, begun: 4), true);
        expect(due(h, t), false);
      }
      final end = t0 + 105 * sec;
      expect(h.look(now: end, active: 0, begun: 4), false);
      expect(h.heldAt, end);
      expect(due(h, end + kNeedQuietMs - 1), false);
      expect(due(h, end + kNeedQuietMs), true);
    });

    test('a catch-up begun and ended between two looks counts too', () {
      final h = CatchupHold();
      h.look(now: t0, active: 0, begun: 3);
      expect(h.look(now: t0 + 15 * sec, active: 0, begun: 4), false);
      expect(h.heldAt, t0 + 15 * sec);
    });

    test('after a route comes up, holds until its catch-up has begun and '
        'ended', () {
      final h = CatchupHold()..routeUp(t0, 7);
      // the relays are still being dialled: nothing runs yet
      for (var t = t0; t < t0 + 75 * sec; t += 15 * sec) {
        expect(h.look(now: t, active: 0, begun: 7), true);
      }
      expect(h.look(now: t0 + 75 * sec, active: 1, begun: 8), true);
      expect(h.look(now: t0 + 90 * sec, active: 0, begun: 8), false);
      expect(h.heldAt, t0 + 90 * sec);
      expect(due(h, t0 + 90 * sec + kNeedQuietMs - 1), false);
      expect(due(h, t0 + 90 * sec + kNeedQuietMs), true);
    });

    test('a catch-up from before the route is not its own', () {
      final h = CatchupHold()..routeUp(t0, 7);
      expect(h.look(now: t0 + 15 * sec, active: 1, begun: 7), true);
      expect(h.look(now: t0 + 30 * sec, active: 0, begun: 7), true);
    });

    test('a route with no catch-up on it lets asks go after a while', () {
      final h = CatchupHold()..routeUp(t0, 7);
      final late = t0 + kNeedRouteWaitMs;
      expect(h.look(now: late - 1, active: 0, begun: 7), true);
      expect(h.look(now: late, active: 0, begun: 7), false);
      // its quiet was had while waiting
      expect(due(h, late), true);
    });

    test('no route holds, and the wait counts from its coming back', () {
      final h = CatchupHold();
      h.look(now: t0, active: 0, begun: 2);
      h.down(t0 + 15 * sec);
      final back = t0 + 120 * sec;
      h.down(back - 15 * sec);
      // back, and its relays still being dialled
      expect(h.look(now: back, active: 0, begun: 2), true);
      expect(
        h.look(
          now: back - 15 * sec + kNeedRouteWaitMs - 1,
          active: 0,
          begun: 2,
        ),
        true,
      );
      expect(
        h.look(now: back - 15 * sec + kNeedRouteWaitMs, active: 0, begun: 2),
        false,
      );
    });

    test('the catch-up a route came back with is its own', () {
      final h = CatchupHold();
      h.look(now: t0, active: 0, begun: 2);
      h.down(t0 + 15 * sec);
      // it began as the route came back
      expect(h.look(now: t0 + 30 * sec, active: 1, begun: 3), true);
      expect(h.look(now: t0 + 45 * sec, active: 0, begun: 3), false);
      expect(h.heldAt, t0 + 45 * sec);
    });

    test('with nothing counted before the route, one running is its own', () {
      final h = CatchupHold()..down(t0);
      expect(h.look(now: t0 + 15 * sec, active: 1, begun: 4), true);
      expect(h.look(now: t0 + 30 * sec, active: 0, begun: 4), false);
      final g = CatchupHold()..down(t0);
      expect(g.look(now: t0 + 15 * sec, active: 0, begun: 4), true);
      expect(g.look(now: t0 + 30 * sec, active: 0, begun: 5), false);
    });

    test('a first look has nothing to compare with', () {
      final h = CatchupHold();
      expect(h.look(now: t0, active: 0, begun: 5), false);
      expect(h.heldAt, 0);
    });
  });

  group('the schedule', () {
    const min = 60 * 1000;
    // a file of 683 slices, 105 of them in by 53 s from a capped catch-up,
    // the rest asked for from a sender that is online. ticks run from boot,
    // an ask reaches the sender after its trip, and the slices it sends
    // again land [perSec] a second
    ({int whole, int asks, int turnedAway}) run({
      int perSec = 4,
      int Function(int ask) trip = _threeSeconds,
    }) {
      const total = 683;
      final have = {for (var i = 0; i < 105; i++) i};
      final coming = <(int, int)>[];
      var last = 53 * 1000;
      var askedAt = 0, asks = 0, made = 0, turnedAway = 0;
      var answeredAt = 0, rounds = 0;
      for (var t = kNeedTickMs; t < 60 * min; t += kNeedTickMs) {
        coming.removeWhere((c) {
          if (c.$1 > t) return false;
          have.add(c.$2);
          if (c.$1 > last) last = c.$1;
          return true;
        });
        if (have.length == total) {
          return (whole: last, asks: made, turnedAway: turnedAway);
        }
        final go = shouldAskNow(
          now: t,
          lastSliceAt: last,
          askedAt: askedAt,
          asks: asks,
          canResend: true,
          have: have.length,
          total: total,
        );
        if (!go) continue;
        asks = asksAfterAsk(lastSliceAt: last, askedAt: askedAt, asks: asks);
        askedAt = t;
        made++;
        final at = t + trip(made);
        final ok = resendAllowed(
          rowPeer: 'r',
          rowGroup: null,
          rowDirection: 'out',
          requester: 'r',
          now: at,
          lastAnsweredAt: answeredAt,
          rounds: rounds,
        );
        if (!ok) {
          turnedAway++;
          continue;
        }
        answeredAt = at;
        rounds++;
        for (final (i, idx) in missingSlices(have, total).indexed) {
          coming.add((at + (i + 1) * 1000 ~/ perSec, idx));
        }
      }
      fail('never whole');
    }

    test('a file cut short by the catch-up is whole in about six minutes', () {
      // twelve before: a minute's tick, two of quiet, a backoff after each
      final r = run();
      expect(r.whole, lessThan(6.5 * min));
      expect(r.asks, 3);
      expect(r.turnedAway, 0);
    });

    test('an ask slow on its way does not get the next one turned away', () {
      final r = run(perSec: 40, trip: (n) => n == 1 ? 20 * 1000 : 1000);
      expect(r.turnedAway, 0);
      expect(r.asks, 3);
    });
  });

  group('the need frame', () {
    test('round trips sorted without repeats', () {
      final f = NeedFrame.fromJson({
        'u': 'abc',
        'i': [5, 2, 2, 9],
      })!;
      expect(f.mediaId, 'abc');
      expect(f.indices, [2, 5, 9]);
      expect(NeedFrame.fromJson(f.toJson())!.indices, [2, 5, 9]);
    });
    test('rejects malformed frames', () {
      expect(NeedFrame.fromJson(null), null);
      expect(NeedFrame.fromJson('x'), null);
      expect(
        NeedFrame.fromJson({
          'u': '',
          'i': [1],
        }),
        null,
      );
      expect(NeedFrame.fromJson({'u': 'a', 'i': []}), null);
      expect(
        NeedFrame.fromJson({
          'u': 'a',
          'i': [-1],
        }),
        null,
      );
      expect(
        NeedFrame.fromJson({
          'u': 'a',
          'i': [1.5],
        }),
        null,
      );
      expect(
        NeedFrame.fromJson({
          'u': 'a',
          'i': ['1'],
        }),
        null,
      );
      expect(
        NeedFrame.fromJson({
          'u': 'a',
          'i': [kMaxSlices],
        }),
        null,
      );
      expect(
        NeedFrame.fromJson({
          'u': 'a',
          'i': List.generate(kNeedMaxIndices + 1, (i) => i),
        }),
        null,
      );
      expect(
        NeedFrame.fromJson({
          'u': 'a' * 129,
          'i': [1],
        }),
        null,
      );
    });
  });

  group('answering', () {
    bool ok({
      String? peer = 'bob',
      String? group,
      String? dir = 'out',
      String from = 'bob',
      int last = 0,
      int rounds = 0,
    }) => resendAllowed(
      rowPeer: peer,
      rowGroup: group,
      rowDirection: dir,
      requester: from,
      now: 10 * 60 * 1000,
      lastAnsweredAt: last,
      rounds: rounds,
    );

    test('only the recipient may ask', () {
      expect(ok(), true);
      expect(ok(from: 'mallory'), false);
      expect(ok(peer: null), false);
    });
    test('never for received or group rows', () {
      expect(ok(dir: 'in'), false);
      expect(ok(group: 'g1'), false);
    });
    test('answers are throttled and bounded', () {
      expect(ok(last: 10 * 60 * 1000 - 5000), false);
      expect(ok(last: 8 * 60 * 1000), true);
      expect(ok(rounds: kResendMaxRounds), false);
    });
    test('slices outside the file are dropped', () {
      expect(answerable([0, 3, 99, 100, 5000], 100), {0, 3, 99});
    });
  });

  group('on the wire', () {
    test('request and resend flag survive the envelope', () async {
      final ask = unwrapMessage(
        await wrapMessage('', need: const NeedFrame('m1', [4, 7])),
      );
      expect(ask.need!.mediaId, 'm1');
      expect(ask.need!.indices, [4, 7]);
      expect(ask.message, '');

      final slice = unwrapMessage(
        await wrapMessage(
          '',
          imageB64: 'AAAA',
          mediaId: 'm1',
          chunkIndex: 0,
          chunkTotal: 3,
          canResend: true,
        ),
      );
      expect(slice.canResend, true);
      expect(slice.need, null);
    });
    test('an older sender is never asked', () async {
      final slice = unwrapMessage(
        await wrapMessage(
          '',
          imageB64: 'AAAA',
          mediaId: 'm1',
          chunkIndex: 0,
          chunkTotal: 3,
        ),
      );
      expect(slice.canResend, false);
    });
  });

  group('unfinished files past the cap', () {
    Map<String, ({int bytes, int at})> held(Map<String, (int, int)> m) => {
      for (final MapEntry(key: id, value: (b, at)) in m.entries)
        id: (bytes: b, at: at),
    };

    test('under the cap nothing goes', () {
      expect(unfinishedPastCap(held({'a': (10, 1)}), bytes: 10), isEmpty);
      expect(unfinishedPastCap(held({}), bytes: 0), isEmpty);
    });

    test('whole files go, the one quiet longest first, until the rest fit', () {
      final h = held({'new': (40, 30), 'old': (40, 10), 'mid': (40, 20)});
      expect(unfinishedPastCap(h, bytes: 80), ['old']);
      expect(unfinishedPastCap(h, bytes: 50), ['old', 'mid']);
      expect(unfinishedPastCap(h, bytes: 10), ['old', 'mid', 'new']);
    });

    test('a file past the cap on its own goes before any other', () {
      final h = held({'old': (40, 10), 'huge': (200, 30)});
      expect(unfinishedPastCap(h, bytes: 100), ['huge']);
    });

    test('the file count has a cap too', () {
      final h = held({'a': (1, 1), 'b': (1, 2), 'c': (1, 3)});
      expect(unfinishedPastCap(h, files: 2), ['a']);
    });

    test('a file being put together stays', () {
      final h = held({'old': (40, 10), 'new': (40, 30)});
      expect(unfinishedPastCap(h, bytes: 40, keep: {'old'}), ['new']);
      expect(unfinishedPastCap(h, bytes: 0, keep: {'old', 'new'}), isEmpty);
    });

    test('a slice weighs its text and its row', () {
      expect(sliceWeight(0), kSliceRowBytes);
      expect(sliceWeight(100), 100 + kSliceRowBytes);
      expect(kUnfinishedBytes, 200 << 20);
    });
  });
}

int _threeSeconds(int ask) => 3000;
