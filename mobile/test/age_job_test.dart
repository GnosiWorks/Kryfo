// SPDX-License-Identifier: GPL-3.0-or-later
// a lock or an open of a file stops only when its own stop is pressed: an
// export stopping never stops a file being locked in the tools, nor the
// other way. needs the engine built for this computer
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/age_ffi.dart';
import 'package:path/path.dart' as p;

import 'host_engine.dart';

const _pass = 'correct-horse-battery-staple';

void main() {
  final engine = loadHostEngine();
  late Directory tmp;
  late String big;
  late String small;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('age_job');
    big = p.join(tmp.path, 'big');
    File(big).openSync(mode: FileMode.write)
      ..setPositionSync(128 << 20)
      ..writeByteSync(1)
      ..closeSync();
    small = p.join(tmp.path, 'small');
    File(small).writeAsStringSync('the code is under the mat');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> running(AgeJob job) async {
    for (var i = 0; job.progress() == 0 && i < 2000; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(job.progress(), greaterThan(0));
  }

  test('a stop for a job still waiting leaves the running one be', () async {
    final a = AgeJob(), b = AgeJob();
    final first = ageLockPath(big, p.join(tmp.path, 'a.age'), _pass, a);
    final second = ageLockPath(small, p.join(tmp.path, 'b.age'), _pass, b);
    await running(a);
    // the one waiting counts nothing of the other's
    expect(b.progress(), 0);
    b.cancel();
    expect(await first, isNull);
    expect(await second, AgeError.cancelled);
  }, skip: !engine);

  test('a stop for the running job leaves the next one be', () async {
    final a = AgeJob(), b = AgeJob();
    final first = ageLockPath(big, p.join(tmp.path, 'a.age'), _pass, a);
    final second = ageLockPath(small, p.join(tmp.path, 'b.age'), _pass, b);
    await running(a);
    a.cancel();
    expect(await first, AgeError.cancelled);
    expect(await second, isNull);
    expect(File(p.join(tmp.path, 'b.age')).lengthSync(), greaterThan(0));
  }, skip: !engine);

  test('a stop pressed before the engine began still stops it', () async {
    final a = AgeJob()..cancel();
    expect(
      await ageLockPath(big, p.join(tmp.path, 'a.age'), _pass, a),
      AgeError.cancelled,
    );
    // and the next job is not stopped by it
    expect(await ageLockPath(small, p.join(tmp.path, 'b.age'), _pass), isNull);
  }, skip: !engine);
}
