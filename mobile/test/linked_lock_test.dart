// SPDX-License-Identifier: GPL-3.0-or-later
// a linked device's own end: unused for 30 days by
// its clock it ends, a person's use starts the count again, a clock set
// back ends it (a thief cannot buy time that way), and a lock state that
// does not read under its key ends it too. a fake clock and a folder of its
// own; the secret store is a map
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/linked_lock.dart';

const _day = Duration.millisecondsPerDay;

void main() {
  late Directory dir;
  late Map<String, String> keys;
  var now = 1_780_000_000_000;

  LinkedLock lock() => LinkedLock(
    dir: () async => dir.path,
    readKey: (k) async => keys[k],
    writeKey: (k, v) async => keys[k] = v,
    clock: () => now,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('linked_lock');
    keys = {};
    now = 1_780_000_000_000;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'unused for 30 days by its own clock it ends; a use counts again',
    () async {
      final l = lock();
      await l.start();
      final t0 = now;
      now = t0 + 29 * _day;
      expect(await l.check(), isNull);
      now = t0 + 30 * _day + 1;
      expect(await l.check(), LinkedEnd.unused);
      // a person's use on day 20 counts from there
      now = t0;
      await l.start();
      now = t0 + 20 * _day;
      await l.used();
      now = t0 + 45 * _day;
      expect(await l.check(), isNull);
      now = t0 + 50 * _day + 1;
      expect(await l.check(), LinkedEnd.unused);
    },
  );

  test('a use past the 30 days brings nothing back: the device still ends, '
      'even when nothing checked it in between', () async {
    final l = lock();
    await l.start();
    final t0 = now;
    // a laptop left asleep for 40 days, opened: the resume's use comes
    // before any check
    now = t0 + 40 * _day;
    await l.used();
    expect(await l.check(), LinkedEnd.unused);
    // a use just inside the 30 days still counts
    now = t0;
    await l.start();
    now = t0 + 30 * _day - 1;
    await l.used();
    now = t0 + 45 * _day;
    expect(await l.check(), isNull);
  });

  test('a clock set back ends it, a small step back does not, and a use with '
      'the clock behind counts nothing', () async {
    final l = lock();
    await l.start();
    final t0 = now;
    now = t0 + 10 * _day;
    expect(await l.check(), isNull);
    // a network time fix of a few minutes
    now = t0 + 10 * _day - const Duration(minutes: 5).inMilliseconds;
    expect(await l.check(), isNull);
    // back past the highest it saw: a thief buying time
    now = t0 + 5 * _day;
    await l.used();
    expect(await l.check(), LinkedEnd.clock);
    // and the time it wanted: the count went on from the highest clock
    now = t0 + 31 * _day;
    expect(await l.check(), LinkedEnd.unused);
  });

  test('a lock state that does not read under its key ends it', () async {
    final l = lock();
    await l.start();
    expect(await l.check(), isNull);
    final f = File('${dir.path}/$kLinkedLockFile');
    final j = jsonDecode(f.readAsStringSync()) as Map;
    // the use moved forward by hand: the mac no longer holds
    f.writeAsStringSync(jsonEncode({...j, 'u': (j['u'] as int) + 9 * _day}));
    expect(await l.check(), LinkedEnd.broken);
    // the file gone
    await l.start();
    f.deleteSync();
    expect(await l.check(), LinkedEnd.broken);
    // the key gone, or another one
    await l.start();
    keys.remove(kLinkedLockKey);
    expect(await l.check(), LinkedEnd.broken);
    await l.start();
    keys[kLinkedLockKey] = base64Encode(List.filled(32, 7));
    expect(await l.check(), LinkedEnd.broken);
    // junk
    await l.start();
    f.writeAsStringSync('not json');
    expect(await l.check(), LinkedEnd.broken);
  });

  test('the phone hears why, but for a removal it made itself', () {
    expect(linkedEndWord(LinkedEnd.removed), isNull);
    expect(linkedEndWord(LinkedEnd.unused), 'unused');
    expect(linkedEndWord(LinkedEnd.clock), 'clock');
    expect(linkedEndWord(LinkedEnd.broken), 'broken');
    expect(linkedEndWord(LinkedEnd.self), 'self');
    expect(linkedEndWord(LinkedEnd.silent), 'silent');
  });
}
