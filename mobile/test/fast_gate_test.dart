import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/fast_gate.dart';

void main() {
  test('only the phrase opens the gate', () {
    expect(fastGateAccepts('i understand'), isTrue);
    expect(fastGateAccepts('  I  Understand '), isTrue);
    expect(fastGateAccepts('ok'), isFalse);
    expect(fastGateAccepts('i understan'), isFalse);
    expect(fastGateAccepts(''), isFalse);
  });
  test('fast does not survive a reinstall', () {
    expect(sendModeAtBoot('fast', fastMarker: false), 'private');
    expect(sendModeAtBoot('fast', fastMarker: true), 'fast');
    expect(sendModeAtBoot('balanced', fastMarker: false), 'balanced');
    expect(sendModeAtBoot('private', fastMarker: false), 'private');
  });
}
