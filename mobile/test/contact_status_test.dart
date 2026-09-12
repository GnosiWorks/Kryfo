import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/contact_status.dart';

void main() {
  test('verified beats vouched', () {
    expect(
      contactStatusLine(
        verified: true,
        voucherNames: ['alice'],
        blocked: false,
        accepted: true,
      ),
      'Keys verified in person',
    );
  });
  test('vouched names read as a line', () {
    expect(
      contactStatusLine(
        verified: false,
        voucherNames: ['alice', 'bob'],
        blocked: false,
        accepted: true,
      ),
      'Vouched by alice and bob',
    );
  });
  test('blocked wins over everything', () {
    expect(
      contactStatusLine(
        verified: true,
        voucherNames: ['alice'],
        blocked: true,
        accepted: true,
      ),
      'blocked',
    );
  });
  test('plain and pending', () {
    expect(
      contactStatusLine(
        verified: false,
        voucherNames: [],
        blocked: false,
        accepted: true,
      ),
      'Added by hand',
    );
    expect(
      contactStatusLine(
        verified: false,
        voucherNames: [],
        blocked: false,
        accepted: false,
      ),
      'Waiting in requests',
    );
  });
}
