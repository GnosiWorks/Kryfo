// SPDX-License-Identifier: GPL-3.0-or-later
// a plain sqlite never holds the database: it takes PRAGMA key without a
// word and would write clear text. its own test file, as an isolate loads
// one sqlite for good
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

const _plain = '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0';

void main() {
  final there = File(_plain).existsSync();
  final skip = there ? false : 'no system sqlite here';

  test('a library without the cipher is passed over', () {
    expect(
      () => openSqlcipher([_plain, '/nonexistent/libsqlcipher.so.0']),
      throwsA(isA<NoCipherError>()),
    );
  }, skip: skip);

  test('a connection on plain sqlite is refused before a key', () {
    open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open(_plain));
    final dir = Directory.systemTemp.createTempSync('plain');
    try {
      final path = p.join(dir.path, 'x.db');
      final db = sqlite3.open(path);
      expect(
        () => keyConnection(db, "x'${'ab' * 32}'"),
        throwsA(isA<NoCipherError>()),
      );
      db.dispose();
      expect(File(path).lengthSync(), 0);
    } finally {
      dir.deleteSync(recursive: true);
    }
  }, skip: skip);

  test('the app looks only at full paths of its own', () {
    final c = sqlcipherCandidates(exe: '/opt/kryfo/kryfo', env: const {});
    expect(c, ['/opt/kryfo/lib/libsqlcipher.so.0']);
    final f = sqlcipherCandidates(
      exe: '/app/lib/kryfo/kryfo',
      env: const {'FLATPAK_ID': 'app.kryfo.Kryfo'},
    );
    expect(f, [
      '/app/lib/kryfo/lib/libsqlcipher.so.0',
      '/app/lib/libsqlcipher.so.0',
    ]);
    // a bare name is never tried, even when asked
    expect(
      () => openSqlcipher(['libsqlcipher.so.0']),
      throwsA(isA<NoCipherError>()),
    );
  });

  test('only sqlcipher 4 and later', () {
    expect(cipherMajor('4.19.0 community'), 4);
    expect(cipherMajor('10.0.1'), 10);
    expect(cipherMajor('3.4.2'), 3);
    expect(cipherMajor(''), isNull);
    expect(cipherMajor(null), isNull);
    expect(cipherMajor('community'), isNull);
    expect(kMinCipherMajor, 4);
  });
}
