import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/shield_sheet.dart';

void main() {
  test('a clean check is not a flag', () {
    final row = {'headline': '', 'lines': '[]', 'dismissed': 0};
    expect(ShieldFlag.cleanRow(row), isTrue);
    expect(ShieldFlag.fromRow(row), isNull);
  });
  test('a flagged row is a flag and not clean', () {
    final row = {
      'headline': 'looks like a scam',
      'lines': '["x"]',
      'dismissed': 0,
    };
    expect(ShieldFlag.cleanRow(row), isFalse);
    expect(ShieldFlag.fromRow(row)?.headline, 'looks like a scam');
  });
  test('nothing recorded is neither', () {
    expect(ShieldFlag.cleanRow(null), isFalse);
    expect(ShieldFlag.fromRow(null), isNull);
  });
}
