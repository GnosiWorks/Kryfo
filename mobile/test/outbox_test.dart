import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/outbox.dart';

// a stranger's first message is the one envelope the far side checks for
// proof-of-work, so a retried opener has to keep its nonce

const _sender = SenderInfo(
  haloId: 'thumb-behave-boring',
  edPub: 'ed',
  onion: 'x.onion',
  xPub: 'ab',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a retried opener passes the receiver gate', () async {
    const text = 'hi, sam gave me your kryfo';
    final nonce = grindPow(text, powBits);
    final row = <String, Object?>{
      'plaintext': text,
      'msg_uid': 'u1',
      'reply_to': null,
      'group_id': null,
      'pow_nonce': nonce,
    };
    final env = unwrapMessage(await wrapRedelivery(row, sender: _sender));
    expect(env.message, text);
    expect(env.msgUid, 'u1');
    expect(env.powNonce, nonce);
    expect(env.powBitsUsed, powBits);
    // what _applyIncomingPayload does on the back-pair lane
    expect(verifyPow(env.message, env.powNonce!, powBits), true);
  });

  test('a row without nonce needs pow until answered', () {
    final row = <String, Object?>{'plaintext': 'x', 'group_id': null};
    expect(redeliveryNeedsPow(row, backPaired: false), true);
    expect(redeliveryNeedsPow(row, backPaired: true), false);
    expect(
      redeliveryNeedsPow({...row, 'pow_nonce': 7}, backPaired: false),
      false,
    );
    // group frames never see the stranger gate
    expect(
      redeliveryNeedsPow({...row, 'group_id': 'g1'}, backPaired: false),
      false,
    );
  });

  test(
    'no row nonce means no envelope nonce',
    () async {
      final env = unwrapMessage(
        await wrapRedelivery({
          'plaintext': 'hello',
          'msg_uid': 'u2',
          'group_id': '',
        }, sender: _sender),
      );
      expect(env.powNonce, null);
      expect(env.powBitsUsed, null);
      expect(env.groupId, null);
    },
  );
}
