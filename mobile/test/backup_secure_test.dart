import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';

void main() {
  test('carried keys are written and the rest removed', () {
    final plan = identitySecurePlan({
      'my_handle': 'wren',
      'fc_counter': '3',
      'something_else': 'x',
    });
    expect(plan.write, {'my_handle': 'wren', 'fc_counter': '3'});
    expect(plan.remove, [
      'my_handle_bio',
      'my_handle_listed',
      'my_handle_name',
      'peer_fc',
    ]);
  });

  test('an older backup removes all carried keys', () {
    final plan = identitySecurePlan(null);
    expect(plan.write, isEmpty);
    expect(plan.remove, kIdentitySecureKeys);
  });

  test('treats an empty value as missing', () {
    final plan = identitySecurePlan({'my_handle': ''});
    expect(plan.write, isEmpty);
    expect(plan.remove, contains('my_handle'));
  });
}
