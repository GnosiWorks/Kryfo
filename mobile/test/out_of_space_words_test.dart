// SPDX-License-Identifier: GPL-3.0-or-later
// a backup that runs out of room says so, whichever layer saw it first:
// dart's file calls, the copy job, or sqlite's own vacuum
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show outOfSpace;

void main() {
  test('sqlite saying the disk is full is out of space', () {
    expect(
      outOfSpace(
        Exception(
          'DatabaseException(database or disk is full (code 13 '
          'SQLITE_FULL)) sql \'VACUUM\'',
        ),
      ),
      isTrue,
    );
  });

  test('the old words still count, and others do not', () {
    expect(
      outOfSpace(
        const FileSystemException('write', 'x', OSError('No space', 28)),
      ),
      isTrue,
    );
    expect(outOfSpace(Exception('ENOSPC')), isTrue);
    expect(outOfSpace(Exception('No space left on device')), isTrue);
    expect(outOfSpace(Exception('file is not a database')), isFalse);
  });
}
