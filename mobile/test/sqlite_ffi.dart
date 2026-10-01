// SPDX-License-Identifier: GPL-3.0-or-later
// the host's own sqlite, in memory, behind the few executor calls the app's
// queries make: what a query keeps is checked on rows, not on its text.
// null where the host has no sqlite to load
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

typedef _OpenC = Int32 Function(Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _Open = int Function(Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _PrepC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Int32,
      Pointer<Pointer<Void>>,
      Pointer<Pointer<Utf8>>,
    );
typedef _Prep =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      int,
      Pointer<Pointer<Void>>,
      Pointer<Pointer<Utf8>>,
    );
typedef _StmtC = Int32 Function(Pointer<Void>);
typedef _Stmt = int Function(Pointer<Void>);
typedef _ColC = Int32 Function(Pointer<Void>, Int32);
typedef _Col = int Function(Pointer<Void>, int);
typedef _ColNameC = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _ColName = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _ColI64C = Int64 Function(Pointer<Void>, Int32);
typedef _BindI64C = Int32 Function(Pointer<Void>, Int32, Int64);
typedef _BindI64 = int Function(Pointer<Void>, int, int);
typedef _BindTextC =
    Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32, IntPtr);
typedef _BindText = int Function(Pointer<Void>, int, Pointer<Utf8>, int, int);
typedef _ErrC = Pointer<Utf8> Function(Pointer<Void>);

const _row = 100;
const _done = 101;
const _int = 1;
const _null = 5;
// sqlite copies the text before the bind returns
const _transient = -1;

class SqliteMem implements DatabaseExecutor {
  SqliteMem._(this._lib, this._db);

  final DynamicLibrary _lib;
  final Pointer<Void> _db;

  static SqliteMem? open() {
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(
        Platform.isMacOS ? 'libsqlite3.dylib' : 'libsqlite3.so.0',
      );
    } catch (_) {
      return null;
    }
    final open = lib.lookupFunction<_OpenC, _Open>('sqlite3_open');
    final out = calloc<Pointer<Void>>();
    final name = ':memory:'.toNativeUtf8();
    try {
      if (open(name, out) != 0) return null;
      return SqliteMem._(lib, out.value);
    } finally {
      calloc.free(out);
      calloc.free(name);
    }
  }

  late final _prep = _lib.lookupFunction<_PrepC, _Prep>('sqlite3_prepare_v2');
  late final _step = _lib.lookupFunction<_StmtC, _Stmt>('sqlite3_step');
  late final _finalize = _lib.lookupFunction<_StmtC, _Stmt>('sqlite3_finalize');
  late final _count = _lib.lookupFunction<_StmtC, _Stmt>(
    'sqlite3_column_count',
  );
  late final _changes = _lib.lookupFunction<_StmtC, _Stmt>('sqlite3_changes');
  late final _type = _lib.lookupFunction<_ColC, _Col>('sqlite3_column_type');
  late final _name = _lib.lookupFunction<_ColNameC, _ColName>(
    'sqlite3_column_name',
  );
  late final _text = _lib.lookupFunction<_ColNameC, _ColName>(
    'sqlite3_column_text',
  );
  late final _i64 = _lib.lookupFunction<_ColI64C, _Col>('sqlite3_column_int64');
  late final _bindI64 = _lib.lookupFunction<_BindI64C, _BindI64>(
    'sqlite3_bind_int64',
  );
  late final _bindText = _lib.lookupFunction<_BindTextC, _BindText>(
    'sqlite3_bind_text',
  );
  late final _bindNull = _lib.lookupFunction<_ColC, _Col>('sqlite3_bind_null');
  late final _err = _lib.lookupFunction<_ErrC, _ErrC>('sqlite3_errmsg');

  List<Map<String, Object?>> _run(String sql, List<Object?>? args) {
    final s = sql.toNativeUtf8();
    final st = calloc<Pointer<Void>>();
    try {
      if (_prep(_db, s, -1, st, nullptr) != 0) {
        throw StateError('$sql: ${_err(_db).toDartString()}');
      }
      final stmt = st.value;
      try {
        for (var i = 0; i < (args?.length ?? 0); i++) {
          final a = args![i];
          if (a == null) {
            _bindNull(stmt, i + 1);
          } else if (a is int) {
            _bindI64(stmt, i + 1, a);
          } else {
            final t = '$a'.toNativeUtf8();
            _bindText(stmt, i + 1, t, -1, _transient);
            calloc.free(t);
          }
        }
        final rows = <Map<String, Object?>>[];
        while (true) {
          final rc = _step(stmt);
          if (rc == _done) break;
          if (rc != _row) throw StateError('$sql: ${_err(_db).toDartString()}');
          final n = _count(stmt);
          rows.add({
            for (var c = 0; c < n; c++)
              _name(stmt, c).toDartString(): switch (_type(stmt, c)) {
                _null => null,
                _int => _i64(stmt, c),
                _ => _text(stmt, c).toDartString(),
              },
          });
        }
        return rows;
      } finally {
        _finalize(stmt);
      }
    } finally {
      calloc.free(s);
      calloc.free(st);
    }
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    _run(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    _run(sql, arguments);
    return 0;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => _run(sql, arguments);

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    _run(sql, arguments);
    return _changes(_db);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('not here: ${i.memberName}');
}
