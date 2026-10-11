// SPDX-License-Identifier: GPL-3.0-or-later
// an edit or a reaction that comes after a newer one from the same sender,
// a relay copy behind its onion copy say, is left out. one with no time
// on it goes in as it always did. the receive path is the real one over
// rows kept in maps; signal is a stand-in
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, frameOrderTable, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-who-edits';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ArrivalRows live;
  late ArrivalIo io;
  late AppState app;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    live = ArrivalRows(HaloContainer.everyday);
    io = ArrivalIo();
    live.person(_bob, onion: 'o-$_bob', xpub: 'x-$_bob');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
  });

  Future<String> frame({
    EditFrame? edit,
    ReactionFrame? reaction,
    String text = '',
    String? uid,
    int? at,
  }) async {
    var wire = await wrapMessage(
      text,
      msgUid: uid,
      edit: edit,
      reaction: reaction,
      sender: asSender(_bob),
      writtenAt: at,
    );
    // an older phone puts no time on it
    if (at == null) {
      final at = wire.indexOf(':{') + 1;
      final m = jsonDecode(wire.substring(at)) as Map<String, dynamic>
        ..remove('w');
      wire = '${wire.substring(0, at)}${jsonEncode(m)}';
    }
    final c = 'c${n++}';
    io.opens[c] = (_bob, wire);
    return c;
  }

  Future<void> byOnion(String c) async {
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> byRelay(String c) async {
    await app.receiveRelay([(peer: _bob, cipher: c)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<String> edit(String text, int? at) => frame(
    edit: EditFrame(targetUid: 'b1', newText: text),
    at: at,
  );
  Future<String> react(String emoji, int at) => frame(
    reaction: ReactionFrame(targetUid: 'b1', emoji: emoji),
    at: at,
  );

  Future<void> said() async =>
      byOnion(await frame(text: 'first words', uid: 'b1', at: 500));

  test('an edit\'s relay copy behind a newer one\'s onion copy is left '
      'out, and a newer one still goes in', () async {
    await said();
    final second = await edit('second words', 2000);
    final first = await edit('old words', 1000);
    await byOnion(second);
    expect(live.msg('b1')!['plaintext'], 'second words');
    await byRelay(first);
    expect(live.msg('b1')!['plaintext'], 'second words');
    await byRelay(await edit('third words', 3000));
    expect(live.msg('b1')!['plaintext'], 'third words');
  });

  test('a reaction taken off stays off when the older one comes '
      'after', () async {
    await said();
    final off = await react('', 2000);
    final on = await react('x', 1000);
    await byOnion(off);
    await byRelay(on);
    expect(live.reactions['b1'] ?? {}, isEmpty);
    await byRelay(await react('y', 3000));
    expect(live.reactions['b1'], {_bob: 'y'});
  });

  test('before their message: the newest edit is the one it shows', () async {
    await byOnion(await edit('second words', 2000));
    await byRelay(await edit('old words', 1000));
    await said();
    expect(live.msg('b1')!['plaintext'], 'second words');
    expect(io.shown.last.$2, 'second words');
  });

  test('one with no time goes in as it always did', () async {
    await said();
    // ahead of any clock: only a frame with no time gets past it
    final ahead = DateTime.now().millisecondsSinceEpoch + 86400000;
    await byOnion(await edit('second words', ahead));
    await byRelay(await edit('from an old phone', null));
    expect(live.msg('b1')!['plaintext'], 'from an old phone');
  });

  test('on disk: per message, sender and kind, an older time is turned '
      'down', () async {
    final mem = MemDb();
    await frameOrderTable(mem);
    final db = _Rows(mem);
    expect(await db.takeFrameOrder('b1', _bob, 'edit', 2000), isTrue);
    expect(await db.takeFrameOrder('b1', _bob, 'edit', 1000), isFalse);
    expect(await db.takeFrameOrder('b1', _bob, 'edit', 2000), isTrue);
    expect(await db.takeFrameOrder('b1', _bob, 'reaction', 1000), isTrue);
    expect(await db.takeFrameOrder('b1', 'eve', 'edit', 1000), isTrue);
    expect(await db.takeFrameOrder('b2', _bob, 'edit', 1000), isTrue);
    expect(mem.rows('frame_order'), hasLength(4));
  });
}
