// SPDX-License-Identifier: GPL-3.0-or-later
// the host's own sqlite, in memory or in a file, behind the calls the app's
// queries make: what a query keeps is checked on rows, not on its text, and
// what a delete or a vacuum leaves is read in the file's bytes. no cipher.
// null where the host has no sqlite to load
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

typedef _Db = Pointer<Void>;
typedef _Stmt = Pointer<Void>;

DynamicLibrary? _load() {
  try {
    return DynamicLibrary.open(
      Platform.isMacOS ? 'libsqlite3.dylib' : 'libsqlite3.so.0',
    );
  } catch (_) {
    return null;
  }
}

final _found = _load();
DynamicLibrary get _lib => _found!;

final _open = _lib
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<_Db>, Int32, Pointer<Utf8>),
      int Function(Pointer<Utf8>, Pointer<_Db>, int, Pointer<Utf8>)
    >('sqlite3_open_v2');
final _close = _lib.lookupFunction<Int32 Function(_Db), int Function(_Db)>(
  'sqlite3_close_v2',
);
final _prepare = _lib
    .lookupFunction<
      Int32 Function(
        _Db,
        Pointer<Utf8>,
        Int32,
        Pointer<_Stmt>,
        Pointer<Pointer<Utf8>>,
      ),
      int Function(
        _Db,
        Pointer<Utf8>,
        int,
        Pointer<_Stmt>,
        Pointer<Pointer<Utf8>>,
      )
    >('sqlite3_prepare_v2');
final _step = _lib.lookupFunction<Int32 Function(_Stmt), int Function(_Stmt)>(
  'sqlite3_step',
);
final _finalize = _lib
    .lookupFunction<Int32 Function(_Stmt), int Function(_Stmt)>(
      'sqlite3_finalize',
    );
final _errmsg = _lib
    .lookupFunction<Pointer<Utf8> Function(_Db), Pointer<Utf8> Function(_Db)>(
      'sqlite3_errmsg',
    );
final _changes = _lib.lookupFunction<Int32 Function(_Db), int Function(_Db)>(
  'sqlite3_changes',
);
final _lastId = _lib.lookupFunction<Int64 Function(_Db), int Function(_Db)>(
  'sqlite3_last_insert_rowid',
);
final _bindInt = _lib
    .lookupFunction<
      Int32 Function(_Stmt, Int32, Int64),
      int Function(_Stmt, int, int)
    >('sqlite3_bind_int64');
final _bindDouble = _lib
    .lookupFunction<
      Int32 Function(_Stmt, Int32, Double),
      int Function(_Stmt, int, double)
    >('sqlite3_bind_double');
final _bindText = _lib
    .lookupFunction<
      Int32 Function(_Stmt, Int32, Pointer<Utf8>, Int32, IntPtr),
      int Function(_Stmt, int, Pointer<Utf8>, int, int)
    >('sqlite3_bind_text');
final _bindBlob = _lib
    .lookupFunction<
      Int32 Function(_Stmt, Int32, Pointer<Uint8>, Int32, IntPtr),
      int Function(_Stmt, int, Pointer<Uint8>, int, int)
    >('sqlite3_bind_blob');
final _bindNull = _lib
    .lookupFunction<Int32 Function(_Stmt, Int32), int Function(_Stmt, int)>(
      'sqlite3_bind_null',
    );
final _colCount = _lib
    .lookupFunction<Int32 Function(_Stmt), int Function(_Stmt)>(
      'sqlite3_column_count',
    );
final _colName = _lib
    .lookupFunction<
      Pointer<Utf8> Function(_Stmt, Int32),
      Pointer<Utf8> Function(_Stmt, int)
    >('sqlite3_column_name');
final _colType = _lib
    .lookupFunction<Int32 Function(_Stmt, Int32), int Function(_Stmt, int)>(
      'sqlite3_column_type',
    );
final _colInt = _lib
    .lookupFunction<Int64 Function(_Stmt, Int32), int Function(_Stmt, int)>(
      'sqlite3_column_int64',
    );
final _colDouble = _lib
    .lookupFunction<Double Function(_Stmt, Int32), double Function(_Stmt, int)>(
      'sqlite3_column_double',
    );
final _colText = _lib
    .lookupFunction<
      Pointer<Utf8> Function(_Stmt, Int32),
      Pointer<Utf8> Function(_Stmt, int)
    >('sqlite3_column_text');
final _colBlob = _lib
    .lookupFunction<
      Pointer<Uint8> Function(_Stmt, Int32),
      Pointer<Uint8> Function(_Stmt, int)
    >('sqlite3_column_blob');
final _colBytes = _lib
    .lookupFunction<Int32 Function(_Stmt, Int32), int Function(_Stmt, int)>(
      'sqlite3_column_bytes',
    );

const _row = 100;
const _done = 101;
// sqlite copies what it is given
const _transient = -1;

class SqliteMem implements Database, Transaction {
  SqliteMem._(this.path, this._db);

  /// in memory, or the file at [path]. null where the host has no sqlite
  static SqliteMem? open({String path = ':memory:'}) {
    if (_found == null) return null;
    final out = calloc<_Db>();
    final name = path.toNativeUtf8();
    try {
      // read, write, create
      final rc = _open(name, out, 0x2 | 0x4, nullptr);
      if (rc != 0) throw StateError('open $path: $rc');
      return SqliteMem._(path, out.value);
    } finally {
      calloc.free(name);
      calloc.free(out);
    }
  }

  @override
  final String path;
  final _Db _db;
  bool _alive = true;

  // the file as it lies on disk, for one opened on a path
  Uint8List bytes() => File(path).readAsBytesSync();

  List<Map<String, Object?>> _run(String sql, [List<Object?>? args]) {
    final rows = <Map<String, Object?>>[];
    final text = sql.toNativeUtf8();
    final tail = calloc<Pointer<Utf8>>();
    final stmt = calloc<_Stmt>();
    var at = text;
    try {
      var first = true;
      while (true) {
        final rc = _prepare(_db, at, -1, stmt, tail);
        if (rc != 0) throw DatabaseErrorForTest(_errmsg(_db).toDartString());
        final s = stmt.value;
        at = tail.value;
        if (s == nullptr) break;
        try {
          if (first) _bind(s, args ?? const []);
          first = false;
          while (true) {
            final r = _step(s);
            if (r == _done) break;
            if (r != _row) {
              throw DatabaseErrorForTest(_errmsg(_db).toDartString());
            }
            final n = _colCount(s);
            rows.add({
              for (var i = 0; i < n; i++)
                _colName(s, i).toDartString(): _value(s, i),
            });
          }
        } finally {
          _finalize(s);
        }
        if (at.cast<Uint8>().value == 0) break;
      }
    } finally {
      calloc.free(text);
      calloc.free(tail);
      calloc.free(stmt);
    }
    return rows;
  }

  void _bind(_Stmt s, List<Object?> args) {
    for (var i = 0; i < args.length; i++) {
      final v = args[i];
      final at = i + 1;
      if (v == null) {
        _bindNull(s, at);
      } else if (v is bool) {
        _bindInt(s, at, v ? 1 : 0);
      } else if (v is int) {
        _bindInt(s, at, v);
      } else if (v is double) {
        _bindDouble(s, at, v);
      } else if (v is List<int>) {
        final p = calloc<Uint8>(v.isEmpty ? 1 : v.length);
        p.asTypedList(v.length).setAll(0, v);
        _bindBlob(s, at, p, v.length, _transient);
        calloc.free(p);
      } else {
        final t = v.toString().toNativeUtf8();
        _bindText(s, at, t, -1, _transient);
        calloc.free(t);
      }
    }
  }

  Object? _value(_Stmt s, int i) => switch (_colType(s, i)) {
    1 => _colInt(s, i),
    2 => _colDouble(s, i),
    3 => _colText(s, i).toDartString(),
    4 => Uint8List.fromList(_colBlob(s, i).asTypedList(_colBytes(s, i))),
    _ => null,
  };

  String _where(String? where) => where == null ? '' : ' WHERE $where';

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    _run(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => _run(sql, arguments);

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    _run(sql, arguments);
    return _lastId(_db);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    _run(sql, arguments);
    return _changes(_db);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      rawUpdate(sql, arguments);

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
    final cols = columns == null ? '*' : columns.join(', ');
    final sql = StringBuffer(
      'SELECT ${distinct == true ? 'DISTINCT ' : ''}$cols FROM $table',
    )..write(_where(where));
    if (groupBy != null) sql.write(' GROUP BY $groupBy');
    if (having != null) sql.write(' HAVING $having');
    if (orderBy != null) sql.write(' ORDER BY $orderBy');
    if (limit != null) sql.write(' LIMIT $limit');
    if (offset != null) sql.write(' OFFSET $offset');
    return _run(sql.toString(), whereArgs);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final or = switch (conflictAlgorithm) {
      ConflictAlgorithm.replace => ' OR REPLACE',
      ConflictAlgorithm.ignore => ' OR IGNORE',
      _ => '',
    };
    final keys = values.keys.toList();
    return rawInsert(
      'INSERT$or INTO $table (${keys.join(', ')}) '
      'VALUES (${List.filled(keys.length, '?').join(', ')})',
      [for (final k in keys) values[k]],
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final keys = values.keys.toList();
    return rawUpdate(
      'UPDATE $table SET ${keys.map((k) => '$k = ?').join(', ')}'
      '${_where(where)}',
      [for (final k in keys) values[k], ...?whereArgs],
    );
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      rawDelete('DELETE FROM $table${_where(where)}', whereArgs);

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    _run('BEGIN');
    try {
      final r = await action(this);
      _run('COMMIT');
      return r;
    } catch (_) {
      _run('ROLLBACK');
      rethrow;
    }
  }

  @override
  Database get database => this;

  @override
  bool get isOpen => _alive;

  @override
  Future<void> close() async {
    if (!_alive) return;
    _alive = false;
    _close(_db);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('not here: ${i.memberName}');
}

class DatabaseErrorForTest implements Exception {
  DatabaseErrorForTest(this.message);
  final String message;
  @override
  String toString() => 'sqlite: $message';
}

/// the app's own CREATE TABLE statement for [table], read from [file]
String appTable(String table, {String file = 'lib/main.dart'}) {
  final src = File(file).readAsStringSync();
  final m = RegExp('CREATE TABLE (IF NOT EXISTS )?$table \\(').firstMatch(src);
  if (m == null) throw StateError('no table $table in $file');
  var depth = 0;
  for (var i = m.end - 1; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')' && --depth == 0) return src.substring(m.start, i + 1);
  }
  throw StateError('unclosed $table');
}

/// whether [needle] is anywhere in [hay]
bool holds(Uint8List hay, String needle) {
  final n = needle.codeUnits;
  outer:
  for (var i = 0; i + n.length <= hay.length; i++) {
    for (var j = 0; j < n.length; j++) {
      if (hay[i + j] != n[j]) continue outer;
    }
    return true;
  }
  return false;
}
