import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/fast_gate.dart';

void main() {
  test('fast does not survive a reinstall', () {
    expect(sendModeAtBoot('fast', fastMarker: false), 'private');
    expect(sendModeAtBoot('fast', fastMarker: true), 'fast');
    expect(sendModeAtBoot('balanced', fastMarker: false), 'balanced');
    expect(sendModeAtBoot('private', fastMarker: false), 'private');
  });
}
