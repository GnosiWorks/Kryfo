// SPDX-License-Identifier: GPL-3.0-or-later
// a stranger's shelf has kShelfPlaces places and a file takes one, however
// many slices, up to kShelfFileSlices of them, all of it in kShelfBytes.
// what comes past a full shelf is turned down before signal spends its key:
// never marked seen, left on the relay (an onion copy kept as it came), and
// in once the stranger is accepted, after the shelf and once each
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
import 'package:kryfo/stranger_gate.dart'
    show Shelved, kShelfBytes, kShelfFileSlices, kShelfPlaces, shelfVerdict;
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

  static Future<_World> make([_World? into]) async {
    final w = into ?? _World();
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
  Future<Set<int>> relay(List<_Line> batch) async =>
      (await relayHeld(batch)).keys.toSet();

  // and the file each is held under
  Future<Map<int, String>> relayHeld(List<_Line> batch) async {
    final held = <int, String>{};
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

  Shelved verdict({
    int places = 0,
    Map<String, Set<int?>> files = const {},
    int bytes = 0,
    int size = 10,
    String? mediaId,
    int? chunk,
    int? total,
    bool overflow = false,
  }) => shelfVerdict(
    places: places,
    files: files,
    bytes: bytes,
    size: size,
    mediaId: mediaId,
    chunk: chunk,
    total: total,
    overflow: overflow,
  );

  test('a file on the shelf takes one place, up to its most slices', () {
    expect(verdict(places: kShelfPlaces - 1), Shelved.kept);
    expect(verdict(places: kShelfPlaces), Shelved.full);
    final one = {
      'f': {0},
    };
    expect(
      verdict(places: kShelfPlaces, files: one, mediaId: 'f', chunk: 1),
      Shelved.kept,
    );
    expect(
      verdict(places: kShelfPlaces, files: one, mediaId: 'g', chunk: 0),
      Shelved.full,
    );
    final most = {
      'f': {for (var i = 0; i < kShelfFileSlices; i++) i},
    };
    expect(
      verdict(files: most, mediaId: 'f', chunk: kShelfFileSlices),
      Shelved.dropped,
    );
    // a place past the file's own end is no slice of it
    expect(
      verdict(files: one, mediaId: 'f', chunk: 5, total: 5),
      Shelved.dropped,
    );
    expect(verdict(mediaId: 'h', chunk: -1, total: 5), Shelved.dropped);
    // the bytes hold for all of it, a copy as it came too
    expect(verdict(bytes: kShelfBytes - 5, size: 10), Shelved.dropped);
    expect(
      verdict(bytes: kShelfBytes - 5, size: 10, overflow: true),
      Shelved.dropped,
    );
    expect(
      verdict(places: kShelfPlaces, size: 10, overflow: true),
      Shelved.kept,
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

      w.live.people[_s]!['accepted'] = 1;
      await w.app.afterAccept(_s);
      await _settle();
      expect(w.io.letGo, [('x-$_s', 'mark'), ('x-$_s', 'free')]);
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
    // another file does not, and waits under its own name
    expect(await w.relayHeld([await w.slice('f2', 0, 3)]), {0: 'f2'});
  });

  test('a slice is one row, and one past its file is dropped', () async {
    final w = await _World.make();
    expect(await w.relay([await w.slice('f1', 0, 3)]), isEmpty);
    // the same slice again, as a new cipher
    final again = await w.slice('f1', 0, 3);
    w.io.opens['copy'] = w.io.opens[again.cipher]!;
    expect(await w.relay([(peer: again.peer, cipher: 'copy')]), isEmpty);
    expect(w.shelved, 1);
    // a place past the file's end: dropped, and taken as kept
    final past = await w.slice('f1', 7, 3);
    expect(await w.relay([past]), isEmpty);
    expect(w.shelved, 1);
    expect(w.live.seen, contains(_hash(past.cipher)));
  });

  test('an accept while a batch runs sends its held ones again', () async {
    final w = await _World.make();
    await w.fill(kShelfPlaces);
    final next = await w.text('past');
    // the accept lands just after the shelf turned it down
    w.io.onShelfFull = () => w.live.people[_s]!['accepted'] = 1;
    final held = <int, String>{};
    expect(await w.app.receiveRelay([next], held: held), {0});
    expect(held, isEmpty);
  });

  test('the relay is told before the shelf goes', () async {
    final w = await _World.make();
    await w.fill(kShelfPlaces);
    expect(await w.relay([await w.text('past')]), {0});
    final told = <List<(String, String)>>[];
    w.live.onForget = (_) => told.add([...w.io.letGo]);
    w.live.people[_s]!['accepted'] = 1;
    await w.app.afterAccept(_s);
    await _settle();
    expect(told, hasLength(kShelfPlaces));
    expect(told.first, [('x-$_s', 'mark')]);
  });

  test('a start marks what is held for everyone accepted, once', () async {
    final w = await _World.make();
    for (var i = 0; i < 6; i++) {
      w.live.person('friend-$i-here', onion: 'o', xpub: 'x-friend-$i');
    }
    await w.app.markHeldAtStart();
    expect(w.io.marked, [
      [for (var i = 0; i < 6; i++) 'x-friend-$i'],
    ]);
    // the sweep after it marks nothing more and starts nothing again
    await w.app.letHeldIn(w.live);
    expect(w.io.marked, hasLength(1));
    expect(w.io.letGo, isEmpty);
  });

  test('an unlock makes nothing reconnect', () async {
    const hs = 'hidden-friend-one';
    final live = ArrivalRows(HaloContainer.everyday);
    final vault = ArrivalRows(HaloContainer.vault);
    final store = ArrivalStore();
    final io = _OnceIo();
    for (var i = 0; i < 6; i++) {
      vault.person('vault-friend-$i', onion: 'o', xpub: 'x-vault-$i');
    }
    // accepted, with a shelf an accept left behind
    vault.person(hs, onion: 'o-$hs', xpub: 'x-$hs');
    await vault.holdCipher(hs, 'wire:{"held":0}');
    await store.putHidden(
      hs,
      kHiddenPeer,
      peerCard(RouterCard(hs, 'o-$hs', 'x-$hs', backPaired: true)),
      1,
    );
    await store.putMeta('pub', 'pub-A');
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await app.letHeldIn(vault);
    expect(vault.heldCiphers[hs], isNull);
    // marks on files alone, in one call for the lot
    expect(io.letGo.where((l) => l.$2 != 'mark'), isEmpty);
    expect(io.marked, hasLength(1));
    expect(io.marked.single, contains('x-vault-0'));
  });

  test('an onion copy past a full shelf is kept as it came', () async {
    final w = await _World.make();
    await w.fill(kShelfPlaces);
    final next = await w.text('past');
    await w.app.receiveOnion([next.cipher]);
    // on the shelf unopened, its key unspent and neither seen nor struck
    expect(w.live.heldCiphers[_s], contains(next.cipher));
    expect(w.io.opens, contains(next.cipher));
    expect(w.live.seen, isNot(contains(_hash(next.cipher))));
    // a full shelf still turns a text more down
    expect(await w.relay([await w.text('more')]), {0});

    w.live.people[_s]!['accepted'] = 1;
    await w.app.afterAccept(_s);
    await _settle();
    expect(w.kept().last, 'past');
    // its relay copy is the same cipher, and stays out
    expect(await w.relay([next]), isEmpty);
    expect(w.kept().where((k) => k == 'past'), hasLength(1));
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
    expect(w.io.letGo, [('x-$_s', 'drop')]);
  });

  test('a sealed one a full vault shelf turns down stays sealed', () async {
    const hs = 'hidden-stranger-one';
    final live = ArrivalRows(HaloContainer.everyday);
    final vault = ArrivalRows(HaloContainer.vault);
    final store = ArrivalStore();
    final io = _OnceIo();
    vault.person(hs, onion: 'o-$hs', xpub: 'x-$hs', accepted: 0);
    await vault.saveMessage(hs, 'in', 'one', msgUid: 'h1');
    await vault.saveMessage(hs, 'in', 'two', msgUid: 'h2');
    for (var i = 0; i < kShelfPlaces; i++) {
      await vault.holdCipher(hs, 'wire:{"held":$i}');
    }
    await store.putHidden(
      hs,
      kHiddenPeer,
      peerCard(RouterCard(hs, 'o-$hs', 'x-$hs', backPaired: true)),
      1,
    );
    await store.putMeta('pub', 'pub-A');
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
    io.sessions = [hs];
    io.opens['c'] = (
      hs,
      await wrapMessage(
        'three',
        msgUid: 'h3',
        sender: SenderInfo(
          haloId: hs,
          edPub: 'ed-$hs',
          onion: 'o-$hs',
          xPub: 'x-$hs',
        ),
      ),
    );
    await app.receiveOnion(['c']);
    await _settle();
    expect(store.inbox, hasLength(1));
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await app.drainSealed(vault, 'priv-A');
    // left for the next time, and the drain is through
    expect(store.inbox, hasLength(1));
    expect(vault.heldCiphers[hs], hasLength(kShelfPlaces));
    await app.drainSealed(vault, 'priv-A');
    expect(store.inbox, hasLength(1));
  });
}
