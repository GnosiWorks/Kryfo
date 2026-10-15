// SPDX-License-Identifier: GPL-3.0-or-later
// a lock or an open of a file stops only when its own stop is pressed: an
// export stopping never stops a file being locked in the tools, nor the
// other way. needs the engine built for this computer
import 'dart:async';
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

  // descriptors this process holds on any of [paths]
  List<String> held(List<String> paths) => [
    for (final e in Directory('/proc/self/fd').listSync())
      if (paths.contains(_target(e.path))) e.path,
  ];

  test(
    'a job stopped while it waits answers before the running one ends',
    () async {
      final a = AgeJob(), b = AgeJob(), c = AgeJob();
      final aOut = p.join(tmp.path, 'a.age'), bOut = p.join(tmp.path, 'b.age');
      var firstDone = false;
      final first = ageLockPath(
        big,
        aOut,
        _pass,
        a,
      ).whenComplete(() => firstDone = true);
      final second = ageLockPath(small, bOut, _pass, b);
      final third = ageLockPath(small, p.join(tmp.path, 'c.age'), _pass, c);
      expect(held([small, bOut]), hasLength(3));
      await running(a);
      b.cancel();
      expect(
        await second.timeout(const Duration(seconds: 2)),
        AgeError.cancelled,
      );
      expect(firstDone, isFalse);
      // its own two are closed, the third's input stays open
      expect(held([bOut]), isEmpty);
      expect(held([small]), hasLength(1));
      // the next one still waits for the running one
      expect(c.progress(), 0);
      expect(await first, isNull);
      expect(File(aOut).lengthSync(), greaterThan(128 << 20));
      expect(await third, isNull);
    },
    skip: !engine,
  );

  test('an open stopped while it waits drops its file in its turn', () async {
    final locked = p.join(tmp.path, 'small.age');
    expect(await ageLockPath(small, locked, _pass), isNull);
    expect(await ageOpenBegin(openFd(locked), _pass), isNull);
    final a = AgeJob(), b = AgeJob();
    final first = ageLockPath(big, p.join(tmp.path, 'a.age'), _pass, a);
    final out = p.join(tmp.path, 'small.out');
    final second = ageOpenFinish(openFd(out, write: true), b);
    await running(a);
    b.cancel();
    expect(
      await second.timeout(const Duration(seconds: 2)),
      AgeError.cancelled,
    );
    expect(held([out]), isEmpty);
    expect(await first, isNull);
    // nothing is left open to finish
    final again = p.join(tmp.path, 'again.out');
    expect(await ageOpenFinish(openFd(again, write: true)), AgeError.io);
    expect(held([locked]), isEmpty);
  }, skip: !engine);

  test('a stop the engine cleared as its job began is said again', () async {
    final locked = p.join(tmp.path, 'small.age');
    expect(await ageLockPath(small, locked, _pass), isNull);
    // checking the words holds the engine through its scrypt work, so the
    // lock below begins only after its stop was said
    final checking = ageOpenBegin(openFd(locked), _pass);
    var checked = false;
    unawaited(checking.whenComplete(() => checked = true));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final a = AgeJob();
    final first = ageLockPath(big, p.join(tmp.path, 'a.age'), _pass, a);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // still the count of the lock before: this one has not begun
    expect(a.progress(), greaterThan(0));
    a.cancel();
    expect(checked, isFalse);
    expect(await checking, isNull);
    expect(await first, AgeError.cancelled);
    // the checked file, dropped once the engine is free
    ageOpenDrop();
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

String? _target(String fd) {
  try {
    return Link(fd).targetSync();
  } on FileSystemException {
    return null;
  }
}
