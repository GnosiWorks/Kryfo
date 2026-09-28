// SPDX-License-Identifier: GPL-3.0-or-later
// a key, a pin, a passphrase or plaintext handed to the engine is copied
// into native memory for the call. that copy is zeroed before it is freed,
// and what the backup cipher reads back never runs past its buffer. the
// calls are checked in their source, like the other rule tests
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/engine_strings.dart';

// the body of the function or method that starts at [head]
String _body(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThanOrEqualTo(0), reason: head);
  final open = src.indexOf('{', at);
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  fail('no end to $head');
}

void main() {
  test('a native copy is zeroed to its end', () {
    final p = 'secret passphrase'.toNativeUtf8();
    zeroNative(p);
    final b = p.cast<Uint8>().asTypedList(17);
    expect(b.every((x) => x == 0), isTrue);
    malloc.free(p);
    freeSecret(nullptr);
  });

  test('every call that hands a secret to the engine zeroes its copy', () {
    final main = File('lib/main.dart').readAsStringSync();
    final backup = File('lib/backup.dart').readAsStringSync();
    final age = File('lib/tools/age_ffi.dart').readAsStringSync();
    final calls = {
      'String restoreIdentity(': (main, 2),
      'String decryptBackup(': (main, 1),
      'Map<String, dynamic>? quietDescribe(': (main, 3),
      'String quietFirstContactPk(': (main, 1),
      'List<String?> vaultOpenMany(': (main, 1),
      'String roomFcPk(': (main, 1),
      'Future<String> _roomFfiOnIsolate(': (main, 1),
      'Future<String> _decryptOnIsolate(': (backup, 1),
      'String? _backupKey(': (backup, 1),
      'Future<AgeError?> ageLock(': (age, 1),
      'Future<AgeError?> ageOpenBegin(': (age, 1),
    };
    for (final e in calls.entries) {
      final body = _body(e.value.$1, e.key);
      expect('freeSecret('.allMatches(body).length, e.value.$2, reason: e.key);
    }
  });

  test('the backup cipher takes no length past its buffer', () {
    final backup = File('lib/backup.dart').readAsStringSync();
    for (final head in [
      'Uint8List seal(int index',
      'Uint8List? open(int index',
    ]) {
      final body = _body(backup, head);
      expect(body.contains('n > _cap'), isTrue, reason: head);
    }
  });
}
