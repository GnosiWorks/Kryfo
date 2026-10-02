// SPDX-License-Identifier: GPL-3.0-or-later
// the system's own sqlite, in memory, for what rows kept in maps cannot
// show: triggers and upgrades run as sqlite runs them. null where the
// library is not there, and a test then says so and skips
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseExecutor;

typedef _OpenC = Int32 Function(Pointer<Uint8>, Pointer<Pointer<Void>>);
typedef _Open = int Function(Pointer<Uint8>, Pointer<Pointer<Void>>);
typedef _RowC =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Pointer<Pointer<Uint8>>,
      Pointer<Pointer<Uint8>>,
    );
typedef _ExecC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Pointer<NativeFunction<_RowC>>,
      Pointer<Void>,
      Pointer<Pointer<Uint8>>,
    );
typedef _Exec =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Pointer<NativeFunction<_RowC>>,
      Pointer<Void>,
      Pointer<Pointer<Uint8>>,
    );
typedef _CloseC = Int32 Function(Pointer<Void>);
typedef _Close = int Function(Pointer<Void>);
typedef _MallocC = Pointer<Void> Function(IntPtr);
typedef _Malloc = Pointer<Void> Function(int);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _Free = void Function(Pointer<Void>);

String? _str(Pointer<Uint8> p) {
  if (p == nullptr) return null;
  var n = 0;
  while (p[n] != 0) {
    n++;
  }
  return utf8.decode(p.asTypedList(n));
}

// rows of the statement running now
List<Map<String, String?>> _rows = [];

int _row(
  Pointer<Void> _,
  int n,
  Pointer<Pointer<Uint8>> values,
  Pointer<Pointer<Uint8>> names,
) {
  _rows.add({for (var i = 0; i < n; i++) _str(names[i])!: _str(values[i])});
  return 0;
}

class RealSqlite {
  RealSqlite._(
    this._db,
    this._exec,
    this._close,
    this._sqliteFree,
    this._malloc,
    this._free,
  );

  final Pointer<Void> _db;
  final _Exec _exec;
  final _Close _close;
  final _Free _sqliteFree;
  final _Malloc _malloc;
  final _Free _free;

  static RealSqlite? open() {
    if (!Platform.isLinux) return null;
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open('libsqlite3.so.0');
    } catch (_) {
      return null;
    }
    final libc = DynamicLibrary.process();
    final malloc = libc.lookupFunction<_MallocC, _Malloc>('malloc');
    final free = libc.lookupFunction<_FreeC, _Free>('free');
    final open = lib.lookupFunction<_OpenC, _Open>('sqlite3_open');
    final out = malloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    final name = _cstr(malloc, ':memory:');
    final rc = open(name, out);
    free(name.cast());
    final db = out.value;
    free(out.cast());
    if (rc != 0) return null;
    return RealSqlite._(
      db,
      lib.lookupFunction<_ExecC, _Exec>('sqlite3_exec'),
      lib.lookupFunction<_CloseC, _Close>('sqlite3_close'),
      lib.lookupFunction<_FreeC, _Free>('sqlite3_free'),
      malloc,
      free,
    );
  }

  static Pointer<Uint8> _cstr(_Malloc malloc, String s) {
    final b = utf8.encode(s);
    final p = malloc(b.length + 1).cast<Uint8>();
    p.asTypedList(b.length + 1)
      ..setAll(0, b)
      ..[b.length] = 0;
    return p;
  }

  /// runs [sql], every statement in it, and gives back the rows it made
  List<Map<String, String?>> run(String sql) {
    final text = _cstr(_malloc, sql);
    final err = _malloc(sizeOf<Pointer<Uint8>>()).cast<Pointer<Uint8>>();
    err.value = nullptr;
    _rows = [];
    try {
      final rc = _exec(
        _db,
        text,
        Pointer.fromFunction<_RowC>(_row, 1),
        nullptr,
        err,
      );
      if (rc != 0) {
        final msg = _str(err.value);
        _sqliteFree(err.value.cast());
        throw StateError('sqlite: $msg in $sql');
      }
      return _rows;
    } finally {
      _free(text.cast());
      _free(err.cast());
    }
  }

  void close() => _close(_db);
}

// the app's own sql run through it, as sqflite would run it
class RealExecutor implements DatabaseExecutor {
  RealExecutor(this.db);
  final RealSqlite db;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (arguments != null && arguments.isNotEmpty) {
      throw UnimplementedError('arguments');
    }
    db.run(sql);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}
