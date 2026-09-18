import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/media_resend.dart';
import 'package:kryfo/message_envelope.dart';

void main() {
  test('what is missing, lowest first, capped', () {
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

    test('not while slices are still arriving', () {
      expect(ask(last: 100 * min - 30 * 1000), false);
      expect(ask(last: 97 * min), true);
    });
    test('never of a sender that did not say it can answer', () {
      expect(ask(can: false), false);
    });
    test('not for a whole file, an empty one or a single slice', () {
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

  group('the frame, as it comes from the other side', () {
    test('round trip, sorted, without repeats', () {
      final f = NeedFrame.fromJson({
        'u': 'abc',
        'i': [5, 2, 2, 9],
      })!;
      expect(f.mediaId, 'abc');
      expect(f.indices, [2, 5, 9]);
      expect(NeedFrame.fromJson(f.toJson())!.indices, [2, 5, 9]);
    });
    test('anything odd is nothing', () {
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

    test('only the person it was sent to may ask', () {
      expect(ok(), true);
      expect(ok(from: 'mallory'), false);
      expect(ok(peer: null), false);
    });
    test('never for something received, or for a group row', () {
      expect(ok(dir: 'in'), false);
      expect(ok(group: 'g1'), false);
    });
    test('throttled and bounded', () {
      expect(ok(last: 10 * 60 * 1000 - 5000), false);
      expect(ok(last: 8 * 60 * 1000), true);
      expect(ok(rounds: kResendMaxRounds), false);
    });
    test('slices outside the file are dropped', () {
      expect(answerable([0, 3, 99, 100, 5000], 100), {0, 3, 99});
    });
  });

  group('on the wire', () {
    test('a request and the flag on a slice survive the envelope', () async {
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
    test('an older sender says nothing and is never asked', () async {
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
}
