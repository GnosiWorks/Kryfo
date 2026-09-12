import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';

void main() {
  test('the engine words map to the four causes', () {
    expect(
      classifyRestoreError('error: not a halo backup'),
      RestoreFailure.notABackup,
    );
    expect(
      classifyRestoreError('error: wrong passphrase or corrupt'),
      RestoreFailure.wrongPassphrase,
    );
    expect(
      classifyRestoreError('error: gcm: cipher: message authentication failed'),
      RestoreFailure.wrongPassphrase,
    );
    expect(classifyRestoreError('error: bad base64'), RestoreFailure.damaged);
    expect(
      classifyRestoreError('error: blob too short'),
      RestoreFailure.damaged,
    );
    expect(classifyRestoreError('error: scrypt: x'), RestoreFailure.damaged);
  });
  test('each cause has its own plain line, none a code', () {
    final lines = RestoreFailure.values
        .map((w) => RestoreError(w).line)
        .toSet();
    expect(lines.length, 4);
    for (final l in lines) {
      expect(l.contains('error'), isFalse);
      // sentence case: a capital to open, no shouting
      expect(l[0], equals(l[0].toUpperCase()));
      expect(l, isNot(equals(l.toUpperCase())));
    }
  });
}
