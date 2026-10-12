// SPDX-License-Identifier: GPL-3.0-or-later
// sqflite's platform side on the host's own sqlite, on real files: the app's
// openDatabase, its version steps and every query run as on a phone, less
// the cipher, which is not asked for. one statement a call, as on android,
// and a second one in the same text fails here where a phone would drop it
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _OpenC =
    Int32 Function(Pointer<Utf8>, Pointer<Pointer<Void>>, Int32, Pointer<Utf8>);
typedef _Open =
    int Function(Pointer<Utf8>, Pointer<Pointer<Void>>, int, Pointer<Utf8>);
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
typedef _PtrC = Int32 Function(Pointer<Void>);
typedef _Ptr = int Function(Pointer<Void>);
typedef _PtrI64C = Int64 Function(Pointer<Void>);
typedef _ColC = Int32 Function(Pointer<Void>, Int32);
typedef _Col = int Function(Pointer<Void>, int);
typedef _ColPtrC = Pointer<Uint8> Function(Pointer<Void>, Int32);
typedef _ColPtr = Pointer<Uint8> Function(Pointer<Void>, int);
typedef _ColNameC = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _ColName = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _ColI64C = Int64 Function(Pointer<Void>, Int32);
typedef _ColF64C = Double Function(Pointer<Void>, Int32);
typedef _ColF64 = double Function(Pointer<Void>, int);
typedef _BindI64C = Int32 Function(Pointer<Void>, Int32, Int64);
typedef _BindI64 = int Function(Pointer<Void>, int, int);
typedef _BindF64C = Int32 Function(Pointer<Void>, Int32, Double);
typedef _BindF64 = int Function(Pointer<Void>, int, double);
typedef _BindBytesC =
    Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Int32, IntPtr);
typedef _BindBytes = int Function(Pointer<Void>, int, Pointer<Uint8>, int, int);
typedef _ErrC = Pointer<Utf8> Function(Pointer<Void>);

const _ok = 0;
const _row = 100;
const _done = 101;
const _int = 1;
const _float = 2;
const _text = 3;
const _blob = 4;
// sqlite copies what is bound before the bind returns
const _transient = -1;
const _readOnly = 0x1;
const _readWrite = 0x2;
const _create = 0x4;

class SqliteChannel {
  SqliteChannel._(this._lib);

  final DynamicLibrary _lib;
  final _dbs = <int, Pointer<Void>>{};
  final _paths = <int, String>{};
  var _next = 0;

  // every statement run, in order, as the app sent it
  final said = <String>[];

  static const channel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');

  /// the host's sqlite behind sqflite's channel, or null without one
  static SqliteChannel? install() {
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(
        Platform.isMacOS ? 'libsqlite3.dylib' : 'libsqlite3.so.0',
      );
    } catch (_) {
      return null;
    }
    final s = SqliteChannel._(lib);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, s._handle);
    return s;
  }

  /// every file still open closed, and the channel let go
  void uninstall() {
    for (final db in _dbs.values) {
      _close(db);
    }
    _dbs.clear();
    _paths.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  late final _open = _lib.lookupFunction<_OpenC, _Open>('sqlite3_open_v2');
  late final _close = _lib.lookupFunction<_PtrC, _Ptr>('sqlite3_close_v2');
  late final _prep = _lib.lookupFunction<_PrepC, _Prep>('sqlite3_prepare_v2');
  late final _step = _lib.lookupFunction<_PtrC, _Ptr>('sqlite3_step');
  late final _finalize = _lib.lookupFunction<_PtrC, _Ptr>('sqlite3_finalize');
  late final _count = _lib.lookupFunction<_PtrC, _Ptr>('sqlite3_column_count');
  late final _changes = _lib.lookupFunction<_PtrC, _Ptr>('sqlite3_changes');
  late final _lastId = _lib.lookupFunction<_PtrI64C, _Ptr>(
    'sqlite3_last_insert_rowid',
  );
  late final _code = _lib.lookupFunction<_PtrC, _Ptr>(
    'sqlite3_extended_errcode',
  );
  late final _type = _lib.lookupFunction<_ColC, _Col>('sqlite3_column_type');
  late final _bytes = _lib.lookupFunction<_ColC, _Col>('sqlite3_column_bytes');
  late final _name = _lib.lookupFunction<_ColNameC, _ColName>(
    'sqlite3_column_name',
  );
  late final _textOf = _lib.lookupFunction<_ColPtrC, _ColPtr>(
    'sqlite3_column_text',
  );
  late final _blobOf = _lib.lookupFunction<_ColPtrC, _ColPtr>(
    'sqlite3_column_blob',
  );
  late final _i64 = _lib.lookupFunction<_ColI64C, _Col>('sqlite3_column_int64');
  late final _f64 = _lib.lookupFunction<_ColF64C, _ColF64>(
    'sqlite3_column_double',
  );
  late final _bindI64 = _lib.lookupFunction<_BindI64C, _BindI64>(
    'sqlite3_bind_int64',
  );
  late final _bindF64 = _lib.lookupFunction<_BindF64C, _BindF64>(
    'sqlite3_bind_double',
  );
  late final _bindText = _lib.lookupFunction<_BindBytesC, _BindBytes>(
    'sqlite3_bind_text',
  );
  late final _bindBlob = _lib.lookupFunction<_BindBytesC, _BindBytes>(
    'sqlite3_bind_blob',
  );
  late final _bindNull = _lib.lookupFunction<_ColC, _Col>('sqlite3_bind_null');
  late final _err = _lib.lookupFunction<_ErrC, _ErrC>('sqlite3_errmsg');

  PlatformException _fail(Pointer<Void> db, String sql) => PlatformException(
    code: 'sqlite_error',
    message: '${_err(db).toDartString()} (code ${_code(db)})',
    details: {'sql': sql},
  );

  void _bind(Pointer<Void> stmt, int i, Object? a) {
    switch (a) {
      case null:
        _bindNull(stmt, i);
      case final bool b:
        _bindI64(stmt, i, b ? 1 : 0);
      case final int n:
        _bindI64(stmt, i, n);
      case final double d:
        _bindF64(stmt, i, d);
      case final String s:
        final b = utf8.encode(s);
        final p = calloc<Uint8>(b.length + 1);
        p.asTypedList(b.length).setAll(0, b);
        _bindText(stmt, i, p, b.length, _transient);
        calloc.free(p);
      case final List<int> b:
        final p = calloc<Uint8>(b.isEmpty ? 1 : b.length);
        p.asTypedList(b.length).setAll(0, b);
        _bindBlob(stmt, i, p, b.length, _transient);
        calloc.free(p);
      default:
        throw ArgumentError('cannot bind ${a.runtimeType}');
    }
  }

  Object? _value(Pointer<Void> stmt, int c) {
    switch (_type(stmt, c)) {
      case _int:
        return _i64(stmt, c);
      case _float:
        return _f64(stmt, c);
      case _text:
        final p = _textOf(stmt, c);
        return utf8.decode(p.asTypedList(_bytes(stmt, c)));
      case _blob:
        final n = _bytes(stmt, c);
        if (n == 0) return Uint8List(0);
        return Uint8List.fromList(_blobOf(stmt, c).asTypedList(n));
      default:
        return null;
    }
  }

  // one statement: its columns and rows
  ({List<String> columns, List<List<Object?>> rows}) _run(
    Pointer<Void> db,
    String sql,
    List<Object?>? args,
  ) {
    said.add(sql.trim());
    final s = sql.toNativeUtf8();
    final st = calloc<Pointer<Void>>();
    final tail = calloc<Pointer<Utf8>>();
    try {
      if (_prep(db, s, -1, st, tail) != _ok) throw _fail(db, sql);
      final rest = tail.value.toDartString().trim();
      if (rest.isNotEmpty && rest != ';') {
        if (st.value != nullptr) _finalize(st.value);
        throw PlatformException(
          code: 'sqlite_error',
          message: 'more than one statement: $rest',
          details: {'sql': sql},
        );
      }
      final stmt = st.value;
      // only a comment or nothing
      if (stmt == nullptr) return (columns: const <String>[], rows: const []);
      try {
        for (var i = 0; i < (args?.length ?? 0); i++) {
          _bind(stmt, i + 1, args![i]);
        }
        final n = _count(stmt);
        final columns = [
          for (var c = 0; c < n; c++) _name(stmt, c).toDartString(),
        ];
        final rows = <List<Object?>>[];
        while (true) {
          final rc = _step(stmt);
          if (rc == _done) break;
          if (rc != _row) throw _fail(db, sql);
          rows.add([for (var c = 0; c < n; c++) _value(stmt, c)]);
        }
        return (columns: columns, rows: rows);
      } finally {
        _finalize(stmt);
      }
    } finally {
      calloc.free(s);
      calloc.free(st);
      calloc.free(tail);
    }
  }

  Object? _one(Pointer<Void> db, String method, String sql, List<Object?>? a) {
    final r = _run(db, sql, a);
    switch (method) {
      case 'query':
        return {'columns': r.columns, 'rows': r.rows};
      case 'insert':
        // an insert that was ignored has no row to give
        return _changes(db) == 0 ? null : _lastId(db);
      case 'update':
        return _changes(db);
      default:
        return null;
    }
  }

  Pointer<Void> _db(Map<Object?, Object?> a) {
    final db = _dbs[a['id']];
    if (db == null) throw StateError('database ${a['id']} is not open');
    return db;
  }

  List<Object?>? _args(Map<Object?, Object?> a) =>
      (a['arguments'] as List<Object?>?)?.toList();

  Future<Object?> _handle(MethodCall call) async {
    final a = (call.arguments as Map<Object?, Object?>?) ?? const {};
    switch (call.method) {
      case 'openDatabase':
        final path = a['path'] as String;
        if (a['singleInstance'] == true) {
          for (final e in _paths.entries) {
            if (e.value == path) return {'id': e.key};
          }
        }
        final out = calloc<Pointer<Void>>();
        final name = path.toNativeUtf8();
        try {
          final flags = a['readOnly'] == true
              ? _readOnly
              : _readWrite | _create;
          final rc = _open(name, out, flags, nullptr);
          if (rc != _ok) {
            throw PlatformException(
              code: 'sqlite_error',
              message: 'open failed (code $rc): $path',
            );
          }
          final id = ++_next;
          _dbs[id] = out.value;
          _paths[id] = path;
          return {'id': id};
        } finally {
          calloc.free(out);
          calloc.free(name);
        }
      case 'closeDatabase':
        final id = a['id'] as int;
        final db = _dbs.remove(id);
        _paths.remove(id);
        if (db != null) _close(db);
        return null;
      case 'execute' || 'query' || 'insert' || 'update':
        return _one(_db(a), call.method, a['sql'] as String, _args(a));
      case 'batch':
        final db = _db(a);
        final goOn = a['continueOnError'] == true;
        final results = <Object?>[];
        for (final op
            in (a['operations'] as List).cast<Map<Object?, Object?>>()) {
          try {
            results.add({
              'result': _one(
                db,
                op['method'] as String,
                op['sql'] as String,
                _args(op),
              ),
            });
          } on PlatformException catch (e) {
            if (!goOn) rethrow;
            results.add({
              'error': {'code': e.code, 'message': e.message},
            });
          }
        }
        return a['noResult'] == true ? null : results;
      case 'deleteDatabase':
        final path = a['path'] as String;
        for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
          if (File(f).existsSync()) File(f).deleteSync();
        }
        return null;
      case 'getDatabasesPath':
        return Directory.systemTemp.path;
      case 'getPlatformVersion':
        return Platform.operatingSystemVersion;
      case 'options' || 'debugMode' || 'debug':
        return null;
    }
    throw UnimplementedError('sqflite: ${call.method}');
  }
}
