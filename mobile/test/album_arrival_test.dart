// SPDX-License-Identifier: GPL-3.0-or-later
// an album item that lands keeps its place only when the place is free,
// the count agrees and it was written near the album's first row: then it
// rings no more. any other is a message of its own, and rings. one of an
// album that burned already joins nothing and burns as it lands. the
// databases, signal and the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _x = 'amber-otter-lake';
const _id = '0123456789abcdef';
const _min = 60000;

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  // one photo of the album, [i] of [n], written at [at], come through a
  // relay: a live onion arrival is placed at when it came
  Future<void> item(String uid, int i, int n, int at) async {
    final c = 'c${_n++}';
    io.opens[c] = (
      _x,
      await wrapMessage(
        '',
        msgUid: uid,
        imageB64: base64Encode([1, 2, 3, i]),
        album: AlbumTag(_id, n, i),
        sender: asSender(_x),
        writtenAt: at,
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await app.receiveRelay(
      [(peer: 'x-$_x', cipher: c)],
      written: [null],
      reached: [(from: now - 60 * _min, until: now)],
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  AlbumTag? tagOf(String uid) => AlbumTag.ofRow(live.msg(uid)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  final t0 = DateTime.now().millisecondsSinceEpoch - 30 * _min;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('album_arrival');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('an album rings once, each item in its place', () async {
    final w = await _World.make();
    await w.item('a2', 2, 3, t0 + 2000);
    await w.item('a0', 0, 3, t0);
    await w.item('a1', 1, 3, t0 + 1000);
    expect(w.tagOf('a0'), const AlbumTag(_id, 3, 0));
    expect(w.tagOf('a1'), const AlbumTag(_id, 3, 1));
    expect(w.tagOf('a2'), const AlbumTag(_id, 3, 2));
    expect(w.io.rang, hasLength(1));
  });

  test(
    'a place taken already, or another count, stands alone and rings',
    () async {
      final w = await _World.make();
      await w.item('a0', 0, 3, t0);
      await w.item('twin', 0, 3, t0 + 1000);
      await w.item('other', 1, 5, t0 + 1000);
      expect(w.tagOf('a0'), isNotNull);
      expect(w.tagOf('twin'), isNull);
      expect(w.tagOf('other'), isNull);
      expect(w.io.rang, hasLength(3));
    },
  );

  test('one written far from the album\'s first row stands alone', () async {
    final w = await _World.make();
    await w.item('a0', 0, 3, t0);
    await w.item('near', 1, 3, t0 + 9 * _min);
    await w.item('far', 2, 3, t0 + 11 * _min);
    expect(w.tagOf('near'), const AlbumTag(_id, 3, 1));
    expect(w.tagOf('far'), isNull);
    expect(w.io.rang, hasLength(2));
  });

  test('one of an album that burned joins nothing and burns as it '
      'lands', () async {
    final w = await _World.make();
    w.live.gone.add((_x, albumGoneUid(_id)));
    final before = DateTime.now().millisecondsSinceEpoch;
    await w.item('late', 2, 3, t0);
    final row = w.live.msg('late')!;
    expect(AlbumTag.ofRow(row), isNull);
    expect(row['burn_at'] as int, greaterThanOrEqualTo(before));
    expect(
      row['burn_at'] as int,
      lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch),
    );
    expect(w.io.rang, isEmpty);
  });
}
