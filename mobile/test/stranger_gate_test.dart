import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/stranger_gate.dart';

Map<String, Object?> _row(String id, {int accepted = 1, int blocked = 0}) => {
  'halo_id': id,
  'accepted': accepted,
  'blocked': blocked,
  'xpub': 'x$id',
};

void main() {
  group('bootSubscribeRows', () {
    test('a plain stranger in requests is listened for after a restart', () {
      final rows = bootSubscribeRows(
        accepted: [_row('friend')],
        vouchedPending: [],
        pendingRequests: [_row('stranger', accepted: 0)],
      );
      expect(
        rows.map((r) => r['halo_id']),
        containsAll(['friend', 'stranger']),
      );
    });
    test('dedupes a vouched request that is also pending', () {
      final rows = bootSubscribeRows(
        accepted: [],
        vouchedPending: [_row('v', accepted: 0)],
        pendingRequests: [_row('v', accepted: 0)],
      );
      expect(rows.length, 1);
    });
    test('never listens for a blocked row', () {
      final rows = bootSubscribeRows(
        accepted: [],
        vouchedPending: [],
        pendingRequests: [_row('b', accepted: 0, blocked: 1)],
      );
      expect(rows, isEmpty);
    });
  });

  group('proofOfEngagement', () {
    test('a delivery receipt is not the peer talking to us', () {
      expect(
        proofOfEngagement(UnwrappedMessage('', deliveredUid: 'u1')),
        isFalse,
      );
    });
    test('a message is', () {
      expect(proofOfEngagement(UnwrappedMessage('hi', msgUid: 'u2')), isTrue);
    });
  });

  group('strangerCapHolds', () {
    test('third message from an unaccepted stranger is held', () {
      expect(
        strangerCapHolds(accepted: false, vouched: false, have: 2),
        isTrue,
      );
    });
    test('accepted, vouched, or under the cap all pass', () {
      expect(
        strangerCapHolds(accepted: true, vouched: false, have: 9),
        isFalse,
      );
      expect(
        strangerCapHolds(accepted: false, vouched: true, have: 9),
        isFalse,
      );
      expect(
        strangerCapHolds(accepted: false, vouched: false, have: 1),
        isFalse,
      );
    });
  });
}
