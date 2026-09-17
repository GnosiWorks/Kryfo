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
    expect(plan.remove, ['my_handle_bio', 'peer_fc']);
  });

  test('a backup from before they were carried removes them all', () {
    final plan = identitySecurePlan(null);
    expect(plan.write, isEmpty);
    expect(plan.remove, kIdentitySecureKeys);
  });

  test('an empty value is not a value', () {
    final plan = identitySecurePlan({'my_handle': ''});
    expect(plan.write, isEmpty);
    expect(plan.remove, contains('my_handle'));
  });
}
