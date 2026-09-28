// SPDX-License-Identifier: GPL-3.0-or-later
// the search screen's line while an older history goes into the index is
// the everyday side's, and the vault's while it is open. a decoy session
// shows none of it, as on a new install
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show HaloDb, shownSearchFill, useDatabasesForTest;
import 'package:kryfo/session.dart';

class _Db implements HaloDb {
  _Db(this.container);
  @override
  final HaloContainer container;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

void main() {
  final everyday = _Db(HaloContainer.everyday);

  test('the everyday session shows how far the index has got', () {
    useDatabasesForTest(everyday, Session(everyday));
    expect(shownSearchFill((at: 3, to: 10)), (at: 3, to: 10));
  });

  test('a decoy session shows nothing filling', () {
    useDatabasesForTest(everyday, Session(_Db(HaloContainer.decoy)));
    expect(shownSearchFill((at: 3, to: 10)), (at: 0, to: 0));
  });

  test('the line on the search screen goes through it', () {
    final src = File('lib/screens/search_screen.dart').readAsStringSync();
    final line = src.substring(src.indexOf('class _FillLine'));
    expect(line.contains('shownSearchFill('), isTrue);
  });
}
