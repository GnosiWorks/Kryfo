// SPDX-License-Identifier: GPL-3.0-or-later
// the database off android. sqflite_sqlcipher has no desktop side, so its
// channel is answered here: sqflite's own calls, run by sqflite_common_ffi
// on the sqlcipher the app ships. a library without sqlcipher, a missing key
// or a wrong key never opens a file
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
// ignore: implementation_imports
import 'package:sqflite_common/src/exception.dart'
    show SqfliteDatabaseException;
// ignore: implementation_imports
import 'package:sqflite_common/src/mixin/factory.dart'
    show SqfliteInvokeHandler;
// ignore: implementation_imports
import 'package:sqflite_common_ffi/src/sqflite_ffi_handler.dart';
// ignore: implementation_imports
import 'package:sqflite_common_ffi/src/sqflite_ffi_impl.dart'
    show sqfliteFfiHandler;
// ignore: implementation_imports
import 'package:sqflite_common_ffi/src/sqflite_ffi_impl_io.dart'
    show sqfliteFfiHandlerIo;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show createDatabaseFactoryFfi;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as ffi show Database;

import 'desktop_paths.dart' show desktopDataDir;

/// the channel sqflite_sqlcipher talks over
const sqlcipherChannel = 'com.davidmartos96.sqflite_sqlcipher';

class NoCipherError implements Exception {
  const NoCipherError(this.why);
  final String why;
  @override
  String toString() => 'NoCipherError: $why';
}

/// where the shipped sqlcipher can be, by full path only: lib/ beside the
/// runner, and the flatpak's /app/lib. never a bare name the loader would
/// look up anywhere on the system. a debug or test run may name one in
/// KRYFO_SQLCIPHER
List<String> sqlcipherCandidates({String? exe, Map<String, String>? env}) {
  final e = env ?? Platform.environment;
  final dir = p.dirname(exe ?? Platform.resolvedExecutable);
  if (Platform.isWindows) return [p.join(dir, 'sqlcipher.dll')];
  return [
    if (!kReleaseMode && e['KRYFO_SQLCIPHER'] != null) e['KRYFO_SQLCIPHER']!,
    p.join(dir, 'lib', 'libsqlcipher.so.0'),
    if (e['FLATPAK_ID'] != null) '/app/lib/libsqlcipher.so.0',
  ];
}

/// the oldest sqlcipher the database takes: 4 has the settings the phone's
/// files are made with
const kMinCipherMajor = 4;

typedef _CipherKeyC = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef _CipherKey = int Function(Pointer<Void>, Pointer<Uint8>, int);

// the library this isolate opened
DynamicLibrary? _cipherLib;

/// the first candidate that loads and is sqlcipher. a library without
/// sqlite3_key is passed over, whatever its name says
DynamicLibrary openSqlcipher([List<String>? candidates]) {
  for (final c in candidates ?? sqlcipherCandidates()) {
    if (!p.isAbsolute(c)) continue;
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(c);
    } catch (_) {
      continue;
    }
    if (!lib.providesSymbol('sqlite3_key')) continue;
    _cipherLib = lib;
    return lib;
  }
  throw const NoCipherError('no sqlcipher library');
}

/// the major version of a cipher_version answer such as "4.19.0 community"
@visibleForTesting
int? cipherMajor(Object? version) => int.tryParse(
  RegExp(r'^\s*(\d+)\.').firstMatch('${version ?? ''}')?.group(1) ?? '',
);

/// keys a connection just opened, before sqflite runs anything on it
@visibleForTesting
void keyConnection(CommonDatabase db, Object? password) {
  // plain sqlite takes PRAGMA key without a word and writes clear text
  final v = db.select('PRAGMA cipher_version');
  final major = v.isEmpty ? null : cipherMajor(v.first.values.first);
  if (major == null) {
    throw const NoCipherError('the sqlite in this process is not sqlcipher');
  }
  if (major < kMinCipherMajor) {
    throw const NoCipherError('sqlcipher older than 4');
  }
  if (password is! String || password.isEmpty) {
    throw const NoCipherError('no key');
  }
  final lib = _cipherLib;
  if (lib == null || db is! ffi.Database) {
    throw const NoCipherError('no sqlite3_key here');
  }
  // the key's bytes with their length, never through sql text
  final bytes = utf8.encode(password);
  final buf = calloc<Uint8>(bytes.length);
  try {
    buf.asTypedList(bytes.length).setAll(0, bytes);
    final r = lib.lookupFunction<_CipherKeyC, _CipherKey>('sqlite3_key')(
      db.handle.cast(),
      buf,
      bytes.length,
    );
    if (r != 0) {
      throw const NoCipherError('the key was refused');
    }
  } finally {
    buf.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
    bytes.fillRange(0, bytes.length, 0);
    calloc.free(buf);
  }
  // a wrong key shows only at the first read
  db.select('SELECT count(*) FROM sqlite_master');
}

class _CipherHandler with SqfliteFfiHandlerNonImplementedMixin {
  @override
  Future<CommonDatabase> openPlatform(Map argumentsMap) async {
    final db = await sqfliteFfiHandlerIo.openPlatform(argumentsMap);
    try {
      keyConnection(db, argumentsMap['password']);
    } catch (_) {
      db.dispose();
      rethrow;
    }
    return db;
  }

  @override
  Future<void> deleteDatabasePlatform(String path) =>
      sqfliteFfiHandlerIo.deleteDatabasePlatform(path);

  @override
  Future<bool> handleDatabaseExistsPlatform(String path) =>
      sqfliteFfiHandlerIo.handleDatabaseExistsPlatform(path);

  // never .dart_tool under the working directory
  @override
  String getDatabasesPathPlatform() => p.join(desktopDataDir(), 'databases');

  @override
  Future<void> handleOptionsPlatform(Map argumentMap) =>
      sqfliteFfiHandlerIo.handleOptionsPlatform(argumentMap);
}

// runs in the database isolate, which has its own copy of every global
void _init(List<String>? libraries) {
  DynamicLibrary lib() => openSqlcipher(libraries);
  open.overrideFor(OperatingSystem.linux, lib);
  open.overrideFor(OperatingSystem.windows, lib);
  sqfliteFfiHandler = _CipherHandler();
}

/// sqflite's calls, as sqflite_sqlcipher sends them, run on sqlcipher
class DesktopDb {
  /// [libraries] in place of the app's own places, for a test
  DesktopDb({List<String>? libraries}) {
    _factory = createDatabaseFactoryFfi(ffiInit: () => _init(libraries));
  }

  late final DatabaseFactory _factory;

  /// the factory itself, for a test that opens through sqflite's api
  DatabaseFactory get factory => _factory;

  // the connections open now, by sqflite's id
  final _open = <int>{};

  // an error goes back as the phone's plugin sends one, so sqflite makes the
  // same DatabaseException of it
  Future<Object?> call(String method, Object? arguments) async {
    try {
      final r = await (_factory as SqfliteInvokeHandler).invokeMethod<Object?>(
        method,
        arguments,
      );
      if (method == 'openDatabase') {
        final id = r is Map ? r['id'] : r;
        if (id is int) _open.add(id);
      } else if (method == 'closeDatabase') {
        _open.remove((arguments as Map?)?['id']);
      }
      return r;
    } on SqfliteDatabaseException catch (e) {
      throw PlatformException(
        code: 'sqlite_error',
        message: e.message,
        details: e.result,
      );
    }
  }

  /// every connection closed, for the wipe: windows deletes no file that
  /// is still open. a query after this fails, and nothing waits on one
  Future<void> closeAll() async {
    for (final id in List.of(_open)) {
      try {
        await call('closeDatabase', {'id': id});
      } catch (_) {
        _open.remove(id);
      }
    }
  }
}
