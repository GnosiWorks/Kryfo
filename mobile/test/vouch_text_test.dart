import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/vouch_text.dart';

void main() {
  test('one, two, many', () {
    expect(vouchedByLine(['alice']), 'vouched by alice');
    expect(vouchedByLine(['alice', 'bob']), 'vouched by alice and bob');
    expect(
      vouchedByLine(['alice', 'bob', 'cat']),
      'vouched by alice, bob and 1 other you know',
    );
    expect(
      introducedByLine(['alice', 'bob', 'cat', 'dan']),
      'introduced by alice, bob and 2 others you know',
    );
  });

  test('nobody is nothing, not a placeholder', () {
    expect(vouchedByLine([]), '');
    expect(introducedByLine([]), '');
  });

  test('share warning names both', () {
    expect(
      shareWarning('alice', 'bob'),
      "this shares alice's address with bob",
    );
  });
}
