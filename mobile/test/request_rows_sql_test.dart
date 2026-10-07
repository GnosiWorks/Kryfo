// SPDX-License-Identifier: GPL-3.0-or-later
// the requests rule run on real sqlite, over the app's own CREATE TABLE
// statements: a one to one message, a sealed one waiting or an
// introduction puts a row in, and a group member known only by key does
// not. a column or table named wrong fails here as it would on a phone.
// the system's sqlite library is used; with none the test is skipped
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show kAskedRows, kBlockedAtWhere, kRequestRows, kSeedBlockSpans;

typedef _OpenC = Int32 Function(Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _Open = int Function(Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _ExecC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
    );
typedef _Exec =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
    );
typedef _PrepareC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Int32,
      Pointer<Pointer<Void>>,
      Pointer<Void>,
    );
typedef _Prepare =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      int,
      Pointer<Pointer<Void>>,
      Pointer<Void>,
    );
typedef _StmtC = Int32 Function(Pointer<Void>);
typedef _Stmt = int Function(Pointer<Void>);
typedef _TextC = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _Text = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _ErrC = Pointer<Utf8> Function(Pointer<Void>);

DynamicLibrary? _lib() {
  for (final name in const [
    'libsqlite3.so.0',
    'libsqlite3.so',
    'libsqlite3.dylib',
    'sqlite3.dll',
  ]) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {}
  }
  return null;
}

class _Sqlite {
  _Sqlite(DynamicLibrary l)
    : _open = l.lookupFunction<_OpenC, _Open>('sqlite3_open'),
      _exec = l.lookupFunction<_ExecC, _Exec>('sqlite3_exec'),
      _prepare = l.lookupFunction<_PrepareC, _Prepare>('sqlite3_prepare_v2'),
      _step = l.lookupFunction<_StmtC, _Stmt>('sqlite3_step'),
      _text = l.lookupFunction<_TextC, _Text>('sqlite3_column_text'),
      _finalize = l.lookupFunction<_StmtC, _Stmt>('sqlite3_finalize'),
      _close = l.lookupFunction<_StmtC, _Stmt>('sqlite3_close'),
      _err = l.lookupFunction<_ErrC, _ErrC>('sqlite3_errmsg') {
    final out = calloc<Pointer<Void>>();
    final name = ':memory:'.toNativeUtf8();
    try {
      if (_open(name, out) != 0) throw StateError('sqlite: no database');
      _db = out.value;
    } finally {
      calloc.free(name);
      calloc.free(out);
    }
  }

  final _Open _open;
  final _Exec _exec;
  final _Prepare _prepare;
  final _Stmt _step;
  final _Text _text;
  final _Stmt _finalize;
  final _Stmt _close;
  final _ErrC _err;
  late final Pointer<Void> _db;

  void exec(String sql) {
    final s = sql.toNativeUtf8();
    try {
      if (_exec(_db, s, nullptr, nullptr, nullptr) != 0) {
        throw StateError('sqlite: ${_err(_db).toDartString()}\n$sql');
      }
    } finally {
      calloc.free(s);
    }
  }

  // the first column of every row, as text
  List<String> column(String sql) {
    final s = sql.toNativeUtf8();
    final stmt = calloc<Pointer<Void>>();
    try {
      if (_prepare(_db, s, -1, stmt, nullptr) != 0) {
        throw StateError('sqlite: ${_err(_db).toDartString()}\n$sql');
      }
      final out = <String>[];
      // SQLITE_ROW
      while (_step(stmt.value) == 100) {
        out.add(_text(stmt.value, 0).toDartString());
      }
      _finalize(stmt.value);
      return out;
    } finally {
      calloc.free(s);
      calloc.free(stmt);
    }
  }

  void close() => _close(_db);
}

// the statement the app runs to make [table], read off its source
String _create(String src, String table) {
  final m = RegExp(
    'CREATE TABLE (IF NOT EXISTS )?$table\\s*\\(',
  ).firstMatch(src);
  if (m == null) throw StateError('no CREATE TABLE $table');
  var depth = 0;
  for (var i = m.end - 1; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')' && --depth == 0) return src.substring(m.start, i + 1);
  }
  throw StateError('unclosed CREATE TABLE $table');
}

void main() {
  final lib = _lib();

  test(
    'the requests rule picks who asked, on real sqlite',
    () {
      final db = _Sqlite(lib!);
      addTearDown(db.close);
      final src = File('lib/main.dart').readAsStringSync();
      for (final t in const ['contacts', 'messages', 'held_onion', 'vouches']) {
        db.exec(_create(src, t));
      }
      void contact(
        String id, {
        int accepted = 0,
        int blocked = 0,
        int archived = 0,
      }) => db.exec(
        'INSERT INTO contacts (halo_id, onion, xpub, first_seen, '
        'last_seen, accepted, blocked, archived) VALUES '
        "('$id', '', '', 1, 1, $accepted, $blocked, $archived)",
      );
      void message(String peer, {String? group}) => db.exec(
        'INSERT INTO messages (peer_id, direction, plaintext, sent_at, '
        "group_id) VALUES ('$peer', 'in', 'hi', 1, "
        "${group == null ? 'NULL' : "'$group'"})",
      );

      contact('asked');
      message('asked');
      // in a group with us, and nothing else
      contact('member');
      message('member', group: 'g1');
      contact('sealed');
      db.exec(
        'INSERT INTO held_onion (peer_id, cipher, at) '
        "VALUES ('sealed', 'c', 1)",
      );
      contact('introduced');
      db.exec(
        'INSERT INTO vouches (halo_id, voucher_id, created_at) '
        "VALUES ('introduced', 'friend', 1)",
      );
      contact('friend', accepted: 1);
      message('friend');
      contact('blocked', blocked: 1);
      message('blocked');
      contact('parked', archived: 1);
      message('parked');
      contact('silent');

      expect(
        db.column(
          'SELECT halo_id FROM contacts WHERE $kRequestRows ORDER BY halo_id',
        ),
        ['asked', 'introduced', 'sealed'],
      );
      expect(db.column('SELECT COUNT(*) c FROM contacts WHERE $kRequestRows'), [
        '3',
      ]);
      // an add by card takes in who asked, and who was let go since
      expect(
        db.column(
          'SELECT halo_id FROM contacts WHERE halo_id IS NOT NULL AND '
          '($kAskedRows) ORDER BY halo_id',
        ),
        ['asked', 'introduced', 'parked', 'sealed'],
      );
    },
    skip: lib == null ? 'no sqlite library on this machine' : false,
  );

  test('a block holds from its start to its end, on real sqlite, and one made '
      'before the spans were kept holds from the start', () {
    final db = _Sqlite(lib!);
    addTearDown(db.close);
    final src = File('lib/main.dart').readAsStringSync();
    for (final t in const ['contacts', 'block_spans', 'blocked_drops']) {
      db.exec(_create(src, t));
    }
    for (final (id, blocked) in const [('long-blocked', 1), ('free', 0)]) {
      db.exec(
        'INSERT INTO contacts (halo_id, onion, xpub, first_seen, '
        "last_seen, blocked) VALUES ('$id', '', '', 1, 1, $blocked)",
      );
    }
    db.exec(kSeedBlockSpans);
    db.exec(
      'INSERT INTO block_spans (peer_id, from_at, to_at) '
      "VALUES ('was-blocked', 100, 200)",
    );
    bool held(String peer, int at) => db
        .column(
          'SELECT peer_id FROM block_spans WHERE '
          '${kBlockedAtWhere.replaceFirst('?', "'$peer'").replaceAll('?', '$at')}',
        )
        .isNotEmpty;
    expect(held('long-blocked', 5), isTrue);
    expect(held('free', 5), isFalse);
    expect(held('was-blocked', 99), isFalse);
    expect(held('was-blocked', 100), isTrue);
    expect(held('was-blocked', 199), isTrue);
    expect(held('was-blocked', 200), isFalse);
    // a uid is kept once per person
    db.exec(
      'INSERT OR REPLACE INTO blocked_drops (peer_id, uid, at) '
      "VALUES ('was-blocked', 'u1', 1), ('was-blocked', 'u1', 2)",
    );
    expect(db.column('SELECT at FROM blocked_drops'), ['2']);
  }, skip: lib == null ? 'no sqlite library on this machine' : false);
}
