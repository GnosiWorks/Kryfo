// every column a migration adds must also be in a CREATE TABLE, or a fresh
// install and an upgrade end with different schemas. the groups.mentioned
// column was missing this way and broke every clean install's group chats.
// this reads the source, since the schema lives in sql strings.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrated columns exist in every CREATE TABLE for that table', () {
    final src = File('lib/main.dart').readAsStringSync();
    final alters = <(String, String)>[];
    for (final m in RegExp(
      r"ALTER TABLE (\w+) ADD COLUMN (\w+)",
    ).allMatches(src)) {
      alters.add((m.group(1)!, m.group(2)!));
    }
    // the loop form: for (final col in ['a INTEGER', ...]) ALTER TABLE t ADD COLUMN $col
    for (final m in RegExp(
      r"for \(final col in \[(.*?)\]\) \{\s*try \{\s*await db\.execute\('ALTER TABLE (\w+) ADD COLUMN \$col'\)",
      dotAll: true,
    ).allMatches(src)) {
      for (final c in RegExp(r"'(\w+)").allMatches(m.group(1)!)) {
        alters.add((m.group(2)!, c.group(1)!));
      }
    }
    expect(alters, isNotEmpty);
    final creates = <String, List<String>>{};
    for (final m in RegExp(
      r"CREATE TABLE(?: IF NOT EXISTS)? (\w+)\s*\((.*?)\)\s*'''",
      dotAll: true,
    ).allMatches(src)) {
      creates.putIfAbsent(m.group(1)!, () => []).add(m.group(2)!);
    }
    final missing = <String>[];
    for (final (table, col) in alters) {
      final defs = creates[table];
      if (defs == null) continue;
      for (final (i, d) in defs.indexed) {
        if (!RegExp('\\b$col\\b').hasMatch(d)) {
          missing.add('$table.$col missing from CREATE TABLE #${i + 1}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
