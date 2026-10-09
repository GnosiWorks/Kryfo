// SPDX-License-Identifier: GPL-3.0-or-later
// a stranger's shelf has kShelfPlaces places and a file takes one, however
// many slices. what comes past a full shelf is turned down before signal
// spends its key: never marked seen, left on the relay, and in once the
// stranger is accepted, after the shelf and once each
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stranger_gate.dart' show kShelfPlaces, shelfTakes;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _s = 'some-stranger-here';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// as signal: a cipher opens once
class _OnceIo extends ArrivalIo {
  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    final r = await super.decrypt(peer, cipher, flagKeyChange: flagKeyChange);
    if (r != null) opens.remove(cipher);
    return r;
  }
}

typedef _Line = ({String peer, String cipher});

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = _OnceIo();
  late AppState app;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.io.sessions = [_s];
    // the two a stranger gets into requests
    await w.live.saveMessage(_s, 'in', 'one', msgUid: 'r1');
    await w.live.saveMessage(_s, 'in', 'two', msgUid: 'r2');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  SenderInfo get _from =>
      SenderInfo(haloId: _s, edPub: 'ed-$_s', onion: 'o-$_s', xPub: 'x-$_s');

  Future<_Line> text(String uid) async {
    final cipher = 'cipher-$uid';
    io.opens[cipher] = (
      _s,
      await wrapMessage('text $uid', msgUid: uid, sender: _from),
    );
    return (peer: 'x-$_s', cipher: cipher);
  }

  Future<_Line> slice(String mid, int index, int total) async {
    final cipher = 'cipher-$mid-$index';
    io.opens[cipher] = (
      _s,
      await wrapMessage(
        '',
        msgUid: mid,
        mediaId: mid,
        chunkIndex: index,
        chunkTotal: total,
        fileB64: base64Encode(List.filled(300, index % 256)),
        fileName: 'x.bin',
        sender: _from,
      ),
    );
    return (peer: 'x-$_s', cipher: cipher);
  }

  // one batch from the poll: the places it leaves on the relay
  Future<Set<int>> relay(List<_Line> batch) async {
    final held = <int>{};
    expect(await app.receiveRelay(batch, held: held), isEmpty);
    return held;
  }

  Future<void> fill(int texts) async {
    for (var i = 0; i < texts; i++) {
      expect(await relay([await text('h$i')]), isEmpty);
    }
  }

  int get shelved => live.heldCiphers[_s]?.length ?? 0;

  List<Object?> kept() => [
    for (final m in live.msgs)
      if (m['peer_id'] == _s && m['direction'] == 'in') m['msg_uid'],
  ];
}

String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 200));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('shelf_room');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  test('a file on the shelf takes one place', () {
    expect(shelfTakes(places: kShelfPlaces - 1, files: {}), isTrue);
    expect(shelfTakes(places: kShelfPlaces, files: {}), isFalse);
    expect(
      shelfTakes(places: kShelfPlaces, files: {'f'}, mediaId: 'f'),
      isTrue,
    );
    expect(
      shelfTakes(places: kShelfPlaces, files: {'f'}, mediaId: 'g'),
      isFalse,
    );
  });

  test(
    'the text past a full shelf is not seen and comes after accept',
    () async {
      final w = await _World.make();
      await w.fill(kShelfPlaces);
      expect(w.shelved, kShelfPlaces);
      final next = await w.text('past');
      expect(await w.relay([next]), {0});
      // not seen, not kept, and its key not spent
      expect(w.live.seen, isNot(contains(_hash(next.cipher))));
      expect(w.kept(), isNot(contains('past')));
      expect(w.shelved, kShelfPlaces);
      expect(w.io.opens, contains(next.cipher));
      // a copy on the onion lane is turned down the same way
      await w.app.receiveOnion([next.cipher]);
      expect(w.live.seen, isNot(contains(_hash(next.cipher))));
      expect(w.io.opens, contains(next.cipher));

      w.live.people[_s]!['accepted'] = 1;
      await w.app.afterAccept(_s);
      await _settle();
      expect(w.io.letGo, [('x-$_s', true)]);
      expect(w.shelved, 0);
      // the relay brings it again: in, after the shelf
      expect(await w.relay([next]), isEmpty);
      final kept = w.kept();
      expect(kept.last, 'past');
      expect(
        kept.indexOf('h${kShelfPlaces - 1}'),
        lessThan(kept.indexOf('past')),
      );
      expect(w.live.seen, contains(_hash(next.cipher)));
    },
  );

  test('a file of ten slices takes one place', () async {
    final w = await _World.make();
    await w.fill(kShelfPlaces - 1);
    final file = [for (var i = 0; i < 10; i++) await w.slice('f1', i, 10)];
    expect(await w.relay(file), isEmpty);
    expect(w.shelved, kShelfPlaces - 1 + 10);
    // the shelf is full now: a text more waits on the relay
    expect(await w.relay([await w.text('past')]), {0});
  });

  test('slices of a file on a full shelf still fit', () async {
    final w = await _World.make();
    expect(await w.relay([await w.slice('f1', 0, 10)]), isEmpty);
    await w.fill(kShelfPlaces - 1);
    expect(await w.relay([await w.text('past')]), {0});
    final rest = [for (var i = 1; i < 10; i++) await w.slice('f1', i, 10)];
    expect(await w.relay(rest), isEmpty);
    expect(w.shelved, kShelfPlaces + 9);
    // another file does not
    expect(await w.relay([await w.slice('f2', 0, 3)]), {0});
  });

  test('what came back after accept is in once', () async {
    final w = await _World.make();
    await w.fill(kShelfPlaces);
    final past = [await w.text('p1'), await w.text('p2')];
    expect(await w.relay(past), {0, 1});
    w.live.people[_s]!['accepted'] = 1;
    await w.app.afterAccept(_s);
    await _settle();
    // the catch-up and a second relay bring the same ones
    expect(await w.relay([...past, ...past]), isEmpty);
    final kept = w.kept();
    for (final uid in ['p1', 'p2', 'h0', 'h${kShelfPlaces - 1}']) {
      expect(kept.where((k) => k == uid), hasLength(1), reason: uid);
    }
    expect(kept.sublist(kept.length - 2), ['p1', 'p2']);
  });

  test('a block takes what the relay holds for them as kept', () async {
    final w = await _World.make();
    await w.fill(kShelfPlaces);
    expect(await w.relay([await w.text('past')]), {0});
    await w.app.block(_s);
    expect(w.io.letGo, [('x-$_s', false)]);
  });
}
