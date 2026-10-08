// SPDX-License-Identifier: GPL-3.0-or-later
// sqlite names a bare rowid after a table's INTEGER PRIMARY KEY, so a query
// that asks for 'rowid' gets the value under 'id' and a read of
// r['rowid'] is null. every row id the app reads is asked for AS rowid
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no query asks for a bare rowid', () {
    final bare = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('${Platform.pathSeparator}l10n')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'columns:\s*\[([^\]]*)\]').allMatches(src)) {
        if (RegExp(r"'rowid'").hasMatch(m.group(1)!)) {
          bare.add('${f.path}: ${m.group(0)}');
        }
      }
    }
    expect(bare, isEmpty);
  });

  test('the message reads that page and append ask for the row id', () {
    final src = File('lib/main.dart').readAsStringSync();
    for (final name in [
      'messagesFor',
      'messagesPage',
      'messagesAfter',
      'loadGroupMessages',
      'groupMessagesPage',
      'groupMessagesAfter',
    ]) {
      final at = src.indexOf('Future<List<Map<String, Object?>>> $name(');
      expect(at, greaterThan(0), reason: name);
      final body = src.substring(at, src.indexOf('\n  }\n', at));
      expect(body, contains("'rowid AS rowid'"), reason: name);
    }
  });
}
