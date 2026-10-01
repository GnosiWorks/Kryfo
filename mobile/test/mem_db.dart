// SPDX-License-Identifier: GPL-3.0-or-later
// a database kept in maps, as much of sqlite as the developer chat's tests
// ask of it. its tables and columns are read off the app's own CREATE TABLE
// statements, so a statement naming a table or a column the app does not
// have fails here as it would on a phone. defaults, NOT NULL, primary keys,
// INSERT OR IGNORE / REPLACE and rollback behave as sqlite's do
import 'dart:io';

import 'package:kryfo/signal_stores.dart' show kDevSignalPrefix;
import 'package:sqflite_sqlcipher/sqflite.dart';

class _Col {
  _Col(this.notNull, this.fallback, this.check);

  final bool notNull;
  final Object? fallback;
  // CHECK (col = n)
  final Object? check;
}

class _Table {
  _Table(this.cols, this.pk, this.auto);

  final Map<String, _Col> cols;
  final List<String> pk;
  // INTEGER PRIMARY KEY: the rowid itself
  final String? auto;
  List<Map<String, Object?>> rows = [];

  _Table copy() => _Table(cols, pk, auto)
    ..rows = [
      for (final r in rows) {...r},
    ];
}

// a name under a prefix is the signal store's: both sets of its tables
final _create = RegExp(
  r'CREATE (VIRTUAL )?TABLE (IF NOT EXISTS )?((?:\$\{prefix\})?\w+)\s*(USING fts5)?\s*\(',
);
const _prefixed = r'${prefix}';

// the text between the parenthesis at [open] and the one that closes it
String _inner(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')' && --depth == 0) return s.substring(open + 1, i);
  }
  throw FormatException('unclosed CREATE TABLE', s, open);
}

List<String> _topLevel(String body) {
  final out = <String>[];
  var depth = 0;
  var from = 0;
  for (var i = 0; i < body.length; i++) {
    if (body[i] == '(') depth++;
    if (body[i] == ')') depth--;
    if (body[i] == ',' && depth == 0) {
      out.add(body.substring(from, i).trim());
      from = i + 1;
    }
  }
  out.add(body.substring(from).trim());
  return [
    for (final p in out)
      if (p.isNotEmpty) p,
  ];
}

Object? _literal(String s) =>
    int.tryParse(s) ?? (s.startsWith("'") ? s.substring(1, s.length - 1) : s);

_Table _parse(String name, String body, {bool fts = false}) {
  if (fts) {
    // body, tokenize = ...: only the columns, rowid comes on its own
    return _Table({'body': _Col(false, null, null)}, ['rowid'], null);
  }
  final cols = <String, _Col>{};
  var pk = <String>[];
  String? auto;
  for (final part in _topLevel(body)) {
    final up = part.toUpperCase();
    if (up.startsWith('PRIMARY KEY')) {
      pk = [
        for (final c in _inner(part, part.indexOf('(')).split(',')) c.trim(),
      ];
      continue;
    }
    if (up.startsWith('FOREIGN KEY') ||
        up.startsWith('CHECK') ||
        up.startsWith('UNIQUE')) {
      continue;
    }
    final col = part.split(RegExp(r'\s+')).first;
    final dflt = RegExp(r'DEFAULT (\S+)').firstMatch(part)?.group(1);
    final check = RegExp(r'CHECK \((\w+) = (\S+)\)').firstMatch(part);
    cols[col] = _Col(
      up.contains('NOT NULL'),
      dflt == null ? null : _literal(dflt),
      check == null ? null : _literal(check.group(2)!),
    );
    if (up.contains('PRIMARY KEY')) {
      pk = [col];
      if (up.contains('INTEGER PRIMARY KEY')) auto = col;
    }
  }
  return _Table(cols, pk, auto);
}

// every table the app makes, as its sources say
Map<String, _Table> _appSchema() {
  final tables = <String, _Table>{};
  for (final f in const [
    'lib/main.dart',
    'lib/router.dart',
    'lib/devchat/dev_chat.dart',
    'lib/devchat/support.dart',
  ]) {
    final src = File(f).readAsStringSync();
    for (final m in _create.allMatches(src)) {
      final named = m.group(3)!;
      final fts = m.group(4) != null;
      final body = fts ? '' : _inner(src, m.end - 1);
      final base = named.startsWith(_prefixed)
          ? named.substring(_prefixed.length)
          : null;
      for (final name
          in base == null ? [named] : [base, '$kDevSignalPrefix$base']) {
        final t = _parse(name, body, fts: fts);
        final have = tables[name];
        // a table made in two places has the columns of both
        if (have != null) t.cols.addAll(have.cols);
        tables[name] = t;
      }
    }
  }
  return tables;
}

class MemDb implements Database, Transaction {
  // the app's schema, all of it or without [except]
  MemDb({Set<String> except = const {}}) {
    for (final e in _appSchema().entries) {
      if (!except.contains(e.key)) _tables[e.key] = e.value;
    }
  }

  Map<String, _Table> _tables = {};
  var _secure = 0;
  // every statement that changed something, and every pragma
  final log = <String>[];
  // throws on the first statement whose log line starts with it
  String? failOn;

  bool has(String table) => _tables.containsKey(table);

  List<Map<String, Object?>> rows(String table) => [
    for (final r in _t(table).rows) {...r},
  ];

  _Table _t(String table) {
    final t = _tables[table];
    if (t == null) throw StateError('no such table: $table');
    return t;
  }

  void _note(String line) {
    final f = failOn;
    if (f != null && line.startsWith(f)) throw StateError('failed at $line');
    log.add(line);
  }

  static void _known(_Table t, String table, Iterable<String> cols) {
    for (final c in cols) {
      if (c != 'rowid' && !t.cols.containsKey(c)) {
        throw StateError('no such column: $table.$c');
      }
    }
  }

  static Object? _get(_Table t, Map<String, Object?> r, String col) =>
      col == 'rowid'
      ? (r['rowid'] ?? (t.auto == null ? null : r[t.auto]))
      : r[col];

  static bool _same(Object? a, Object? b) {
    if (a == null || b == null) return false;
    if (a is num && b is num) return a == b;
    return a == b;
  }

  // a AND b AND ...: col = ? or a literal, col != ?, col < ?, col LIKE ?,
  // col IN (?, ...), col IS [NOT] NULL
  bool Function(Map<String, Object?>) _where(
    _Table t,
    String table,
    String? where,
    List<Object?>? args,
  ) {
    if (where == null) return (_) => true;
    final tests = <bool Function(Map<String, Object?>)>[];
    var at = 0;
    for (final clause in where.split(' AND ')) {
      final c = clause.trim();
      final m = RegExp(
        r'^(\w+) (=|!=|<|LIKE|IN|IS NULL|IS NOT NULL)(.*)$',
      ).firstMatch(c);
      if (m == null) throw UnimplementedError('where: $c');
      final col = m.group(1)!;
      _known(t, table, [col]);
      switch (m.group(2)!) {
        case '=':
          final lit = m.group(3)!.trim();
          final v = lit == '?' ? args![at++] : _literal(lit);
          tests.add((r) => _same(_get(t, r, col), v));
        case '!=':
          final v = args![at++];
          tests.add((r) {
            final x = _get(t, r, col);
            return x != null && v != null && !_same(x, v);
          });
        case '<':
          final v = args![at++];
          tests.add((r) {
            final x = _get(t, r, col);
            return x is num && v is num && x < v;
          });
        case 'LIKE':
          final p = (args![at++] as String).toLowerCase();
          final body = p.endsWith('%') ? p.substring(0, p.length - 1) : p;
          if (body.contains('%') || body.contains('_')) {
            throw UnimplementedError('like: $p');
          }
          tests.add((r) {
            final x = _get(t, r, col);
            if (x is! String) return false;
            final l = x.toLowerCase();
            return p.endsWith('%') ? l.startsWith(body) : l == body;
          });
        case 'IN':
          final n = '?'.allMatches(m.group(3)!).length;
          final vs = args!.sublist(at, at + n);
          at += n;
          tests.add((r) => vs.any((v) => _same(_get(t, r, col), v)));
        case 'IS NULL':
          tests.add((r) => _get(t, r, col) == null);
        case 'IS NOT NULL':
          tests.add((r) => _get(t, r, col) != null);
      }
    }
    if (args != null && at != args.length) {
      throw StateError('where: $where takes $at arguments, not ${args.length}');
    }
    return (r) => tests.every((f) => f(r));
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final s = sql.trim();
    final m = _create.firstMatch(s);
    if (m != null) {
      final name = m.group(3)!;
      _note('create:$name');
      if (_tables.containsKey(name)) {
        if (m.group(2) == null) throw StateError('table $name exists');
        return;
      }
      final fts = m.group(4) != null;
      _tables[name] = _parse(name, fts ? '' : _inner(s, m.end - 1), fts: fts);
      return;
    }
    if (s.startsWith('PRAGMA') ||
        s.startsWith('CREATE INDEX') ||
        s.startsWith('CREATE TRIGGER')) {
      _note(s);
      return;
    }
    throw UnimplementedError(s);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final set = RegExp(r'^PRAGMA secure_delete = (\d)$').firstMatch(sql);
    if (set != null) {
      _note(sql);
      _secure = int.parse(set.group(1)!);
      return const [];
    }
    if (sql == 'PRAGMA secure_delete') {
      return [
        {'secure_delete': _secure},
      ];
    }
    // SELECT COUNT(*) name FROM t [WHERE ...]
    final count = RegExp(
      r'^SELECT COUNT\(\*\) (\w+) FROM (\w+)(?: WHERE (.*))?$',
    ).firstMatch(sql);
    if (count != null) {
      final table = count.group(2)!;
      final t = _t(table);
      final ok = _where(t, table, count.group(3), arguments);
      return [
        {count.group(1)!: t.rows.where(ok).length},
      ];
    }
    if (sql ==
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?") {
      final name = arguments!.single as String;
      return [
        if (_tables.containsKey(name)) {'name': name},
      ];
    }
    throw UnimplementedError(sql);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (groupBy != null || having != null || offset != null) {
      throw UnimplementedError('query: $table');
    }
    final t = _t(table);
    // a column, or length(col) AS name: its text's length, as sqlite gives it
    final picks = <(String, Object? Function(Map<String, Object?>))>[];
    for (final c in columns ?? const <String>[]) {
      final len = RegExp(r'^length\((\w+)\) AS (\w+)$').firstMatch(c);
      final col = len?.group(1) ?? c;
      _known(t, table, [col]);
      picks.add((
        len?.group(2) ?? c,
        len == null
            ? (r) => _get(t, r, col)
            : (r) => switch (_get(t, r, col)) {
                final String s => s.length,
                final List<int> b => b.length,
                null => null,
                final v => '$v'.length,
              },
      ));
    }
    final ok = _where(t, table, where, whereArgs);
    var out = [
      for (final r in t.rows)
        if (ok(r))
          columns == null
              ? {...r}
              : {for (final (name, get) in picks) name: get(r)},
    ];
    if (orderBy != null) {
      final m = RegExp(r'^(\w+)(?: (ASC|DESC))?$').firstMatch(orderBy);
      if (m == null) throw UnimplementedError('order: $orderBy');
      final col = m.group(1)!;
      final full = [
        for (final r in t.rows)
          if (ok(r)) r,
      ];
      final order = [for (var i = 0; i < full.length; i++) i]
        ..sort((a, b) {
          final x = _get(t, full[a], col);
          final y = _get(t, full[b], col);
          final c = x is Comparable && y is Comparable
              ? Comparable.compare(x, y)
              : 0;
          return m.group(2) == 'DESC' ? -c : c;
        });
      out = [for (final i in order) out[i]];
    }
    if (distinct == true) {
      final seen = <String>{};
      out = [
        for (final r in out)
          if (seen.add(r.values.join('\u0000'))) r,
      ];
    }
    return limit == null ? out : out.take(limit).toList();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final t = _t(table);
    _known(t, table, values.keys);
    final row = <String, Object?>{
      for (final e in t.cols.entries)
        if (e.value.fallback != null) e.key: e.value.fallback,
      ...values,
    };
    final auto = t.auto;
    if (auto != null && row[auto] == null) {
      var top = 0;
      for (final r in t.rows) {
        final v = r[auto];
        if (v is int && v > top) top = v;
      }
      row[auto] = top + 1;
    }
    for (final e in t.cols.entries) {
      if (e.value.notNull && row[e.key] == null) {
        throw StateError('NOT NULL constraint failed: $table.${e.key}');
      }
      final check = e.value.check;
      if (check != null && !_same(row[e.key], check)) {
        throw StateError('CHECK constraint failed: $table.${e.key}');
      }
    }
    final clash = t.pk.isEmpty
        ? null
        : t.rows.where((r) => t.pk.every((k) => _same(r[k], row[k])));
    if (clash != null && clash.isNotEmpty) {
      if (conflictAlgorithm == ConflictAlgorithm.ignore) return 0;
      if (conflictAlgorithm != ConflictAlgorithm.replace) {
        throw StateError('UNIQUE constraint failed: $table');
      }
      _note('replace:$table');
      final gone = clash.toList();
      t.rows.removeWhere(gone.contains);
    } else {
      _note('insert:$table');
    }
    t.rows.add(row);
    final id = auto == null ? t.rows.length : row[auto];
    return id is int ? id : t.rows.length;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final t = _t(table);
    _known(t, table, values.keys);
    final ok = _where(t, table, where, whereArgs);
    var n = 0;
    for (final r in t.rows) {
      if (!ok(r)) continue;
      for (final e in values.entries) {
        final col = t.cols[e.key]!;
        if (col.notNull && e.value == null) {
          throw StateError('NOT NULL constraint failed: $table.${e.key}');
        }
      }
      r.addAll(values);
      n++;
    }
    if (n > 0) _note('update:$table');
    return n;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final t = _t(table);
    final ok = _where(t, table, where, whereArgs);
    final before = t.rows.length;
    t.rows.removeWhere(ok);
    final n = before - t.rows.length;
    _note('delete:$table');
    return n;
  }

  // INSERT [OR REPLACE] INTO t (cols) VALUES (?, ...)
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    final m = RegExp(
      r'^INSERT (OR REPLACE )?INTO (\w+) \(([\w, ]+)\) VALUES \([?, ]+\)$',
    ).firstMatch(sql);
    if (m == null) throw UnimplementedError(sql);
    final cols = [for (final c in m.group(3)!.split(',')) c.trim()];
    if (arguments == null || arguments.length != cols.length) {
      throw StateError('insert: $sql takes ${cols.length} arguments');
    }
    return insert(
      m.group(2)!,
      {for (final (i, c) in cols.indexed) c: arguments[i]},
      conflictAlgorithm: m.group(1) == null ? null : ConflictAlgorithm.replace,
    );
  }

  // DELETE FROM t WHERE col IN (SELECT col2 FROM t2 WHERE <where>), the
  // one shape of it the app uses
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final m = RegExp(
      r'^DELETE FROM (\w+) WHERE (\w+) IN \(SELECT (\w+) FROM (\w+) WHERE (.*)\)$',
    ).firstMatch(sql);
    if (m == null) throw UnimplementedError(sql);
    final inner = await query(
      m.group(4)!,
      columns: [m.group(3)!],
      where: m.group(5),
      whereArgs: arguments,
    );
    final vs = [for (final r in inner) r[m.group(3)!]];
    final t = _t(m.group(1)!);
    _known(t, m.group(1)!, [m.group(2)!]);
    final before = t.rows.length;
    t.rows.removeWhere((r) => vs.any((v) => _same(_get(t, r, m.group(2)!), v)));
    _note('delete:${m.group(1)}');
    return before - t.rows.length;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final was = {for (final e in _tables.entries) e.key: e.value.copy()};
    try {
      return await action(this);
    } catch (_) {
      _tables = was;
      rethrow;
    }
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}
