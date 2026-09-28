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
