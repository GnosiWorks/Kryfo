// SPDX-License-Identifier: GPL-3.0-or-later
// windows has no descriptors: the tools lock and open by path there. the
// same calls run here against the engine built for this computer
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/age_ffi.dart';
import 'package:path/path.dart' as p;

import 'host_engine.dart';

const _pass = 'correct-horse-battery-staple';

void main() {
  final engine = loadHostEngine();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('age_path'));
  tearDown(() {
    ageByPath = Platform.isWindows;
    tmp.deleteSync(recursive: true);
  });

  for (final byPath in [true, false]) {
    final how = byPath ? 'by path' : 'by descriptor';
    test('$how: locked and opened back, a wrong password says so', () async {
      ageByPath = byPath;
      final plain = p.join(tmp.path, 'plan.txt');
      File(plain).writeAsStringSync('the plan, in full' * 1000);
      final locked = p.join(tmp.path, 'plan.txt.age');
      expect(await ageLockPath(plain, locked, _pass), isNull);
      final bytes = File(locked).readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(21)), 'age-encryption.org/v1');
      expect(String.fromCharCodes(bytes), isNot(contains('the plan')));

      expect(await ageOpenBeginPath(locked, 'wrong'), AgeError.wrongPassword);
      expect(await ageOpenBeginPath(locked, _pass), isNull);
      final back = p.join(tmp.path, 'back.txt');
      expect(await ageOpenFinishPath(back), isNull);
      expect(File(back).readAsStringSync(), File(plain).readAsStringSync());
    }, skip: !engine);

    test('$how: nothing is written over a file already there', () async {
      ageByPath = byPath;
      final plain = p.join(tmp.path, 'a');
      File(plain).writeAsStringSync('a');
      final there = p.join(tmp.path, 'there');
      File(there).writeAsStringSync('kept');
      expect(await ageLockPath(plain, there, _pass), AgeError.io);
      expect(File(there).readAsStringSync(), 'kept');
      final locked = p.join(tmp.path, 'a.age');
      expect(await ageLockPath(plain, locked, _pass), isNull);
      expect(await ageOpenBeginPath(locked, _pass), isNull);
      expect(await ageOpenFinishPath(there), AgeError.io);
      expect(File(there).readAsStringSync(), 'kept');
    }, skip: !engine);

    test('$how: a stopped open leaves no half file', () async {
      ageByPath = byPath;
      final plain = p.join(tmp.path, 'a');
      File(plain).writeAsStringSync('a');
      final locked = p.join(tmp.path, 'a.age');
      expect(await ageLockPath(plain, locked, _pass), isNull);
      expect(await ageOpenBeginPath(locked, _pass), isNull);
      final job = AgeJob()..cancel();
      final out = p.join(tmp.path, 'out');
      expect(await ageOpenFinishPath(out, job), AgeError.cancelled);
      expect(File(out).existsSync(), isFalse);
      expect(await ageLockPath(plain, out, '', AgeJob()), isNotNull);
      expect(File(out).existsSync(), isFalse);
    }, skip: !engine);
  }
}
