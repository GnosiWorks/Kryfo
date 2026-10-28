// SPDX-License-Identifier: GPL-3.0-or-later
// the database off android. sqflite_sqlcipher has no desktop side, so its
// channel is answered here: sqflite's own calls, run by sqflite_common_ffi
// on the sqlcipher the app ships. a library without sqlcipher, a missing key
// or a wrong key never opens a file
import 'dart:ffi';
import 'dart:io';

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

import 'desktop_paths.dart' show desktopDataDir;

/// the channel sqflite_sqlcipher talks over
const sqlcipherChannel = 'com.davidmartos96.sqflite_sqlcipher';

class NoCipherError implements Exception {
  const NoCipherError(this.why);
  final String why;
  @override
  String toString() => 'NoCipherError: $why';
}

/// where the shipped sqlcipher can be: lib/ beside the runner, then by name
/// (the flatpak's /app/lib). a debug or test run may name one in
/// KRYFO_SQLCIPHER
List<String> sqlcipherCandidates({String? exe, Map<String, String>? env}) {
  final e = env ?? Platform.environment;
  final dir = p.dirname(exe ?? Platform.resolvedExecutable);
  final win = Platform.isWindows;
  final name = win ? 'sqlcipher.dll' : 'libsqlcipher.so.0';
  return [
    if (!kReleaseMode && e['KRYFO_SQLCIPHER'] != null) e['KRYFO_SQLCIPHER']!,
    win ? p.join(dir, name) : p.join(dir, 'lib', name),
    name,
  ];
}

/// the first candidate that loads and is sqlcipher. a library without
/// sqlite3_key is passed over, whatever its name says
DynamicLibrary openSqlcipher([List<String>? candidates]) {
  for (final c in candidates ?? sqlcipherCandidates()) {
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(c);
    } catch (_) {
      continue;
    }
    if (lib.providesSymbol('sqlite3_key')) return lib;
  }
  throw const NoCipherError('no sqlcipher library');
}

/// keys a connection just opened, before sqflite runs anything on it
@visibleForTesting
void keyConnection(CommonDatabase db, Object? password) {
  // plain sqlite takes PRAGMA key without a word and writes clear text
  final v = db.select('PRAGMA cipher_version');
  if (v.isEmpty || '${v.first.values.first ?? ''}'.isEmpty) {
    throw const NoCipherError('the sqlite in this process is not sqlcipher');
  }
  if (password is! String || password.isEmpty) {
    throw const NoCipherError('no key');
  }
  db.execute("PRAGMA key = '${password.replaceAll("'", "''")}'");
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

  // an error goes back as the phone's plugin sends one, so sqflite makes the
  // same DatabaseException of it
  Future<Object?> call(String method, Object? arguments) async {
    try {
      return await (_factory as SqfliteInvokeHandler).invokeMethod<Object?>(
        method,
        arguments,
      );
    } on SqfliteDatabaseException catch (e) {
      throw PlatformException(
        code: 'sqlite_error',
        message: e.message,
        details: e.result,
      );
    }
  }
}
