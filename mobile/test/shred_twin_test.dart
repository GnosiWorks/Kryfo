// SPDX-License-Identifier: GPL-3.0-or-later
// the twin check every shred test leans on: a miss says what it saw, and a
// read of the extents that fails for a moment is not taken for a move
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'shred_twin.dart';

void main() {
  late Directory tmp;
  late Directory twins;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('twin_check');
    twins = Directory.systemTemp.createTempSync('twin_check_twins');
  });
  tearDown(() {
    readExtents = extentsOf;
    tmp.deleteSync(recursive: true);
    twins.deleteSync(recursive: true);
  });

  // a file and its twin, or null where the disk cannot say where it sits
  File? twinned() {
    final f = File('${tmp.path}/a.jpg')
      ..writeAsBytesSync(List.filled(20000, 7), flush: true);
    final twin = twinOf(f.path, twins);
    return extentsOf(twin.path) == null ? null : twin;
  }

  void zeroInPlace(File twin) {
    final raf = twin.openSync(mode: FileMode.append)..setPositionSync(0);
    raf
      ..writeFromSync(List.filled(twin.lengthSync(), 0))
      ..flushSync()
      ..closeSync();
  }

  test('a read of the extents that fails once is asked again', () {
    final twin = twinned();
    if (twin == null) {
      markTestSkipped('no filefrag here');
      return;
    }
    zeroInPlace(twin);
    var reads = 0;
    readExtents = (path) => reads++ == 0 ? null : extentsOf(path);
    expect(unshredded(twin), isNull);
    expect(zeroed(twin), isTrue);
  });

  test('extents that never read back stay a miss, and say so', () {
    final twin = twinned();
    if (twin == null) {
      markTestSkipped('no filefrag here');
      return;
    }
    zeroInPlace(twin);
    readExtents = (_) => null;
    expect(unshredded(twin), startsWith('extents unreadable'));
    expect(zeroed(twin), isFalse);
  });

  test('bytes left over are counted', () {
    final twin = twinned();
    if (twin == null) {
      markTestSkipped('no filefrag here');
      return;
    }
    expect(unshredded(twin), '20000 of 20000 bytes not zero');
  });

  test('other blocks are a move', () {
    final twin = twinned();
    if (twin == null) {
      markTestSkipped('no filefrag here');
      return;
    }
    zeroInPlace(twin);
    readExtents = (_) => '0: 0.. 4: 1.. 5:';
    expect(unshredded(twin), startsWith('moved from'));
  });
}
