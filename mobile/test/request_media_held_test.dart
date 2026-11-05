// SPDX-License-Identifier: GPL-3.0-or-later
// a stranger's request is words alone: their photos, files and voice notes,
// from any version, wait on the shelf unshown and come in on accept. their
// words still get their two. an introduced sender, a group and the hidden
// and decoy sides keep the rules they have
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/file_drop.dart' show DropFrame;
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        useDatabasesForTest,
        useEngineForTest,
        AppStateContacts,
        AppStateVault,
        AppStateReceive;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stranger_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _s = 'stranger-in-requests';
const _f = 'friend-who-vouched';
const _c = 'contact-we-know';
const _g = 'grp000000001';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _pic = base64Encode(List.filled(300, 7));

class _World {
  _World([HaloContainer c = HaloContainer.everyday]) : live = ArrivalRows(c);
  final ArrivalRows live;
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make([HaloContainer c = HaloContainer.everyday]) async {
    final w = _World(c);
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.live.person(_c, onion: 'o-$_c', xpub: 'x-$_c');
    w.live.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.live.group(_g, ['me', _c, _s], admin: _c);
    w.io.sessions = [_s, _c];
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  // as a 0.5 phone sends it: no 'cp' of what it understands
  Future<void> photo(String who, String uid, {String? group}) async => from(
    who,
    await wrapMessage(
      'a caption',
      msgUid: uid,
      imageB64: _pic,
      groupId: group,
      sender: asSender(who),
    ),
  );

  Future<void> slice(String who, String mid, int index, int total) async =>
      from(
        who,
        await wrapMessage(
          '',
          msgUid: mid,
          mediaId: mid,
          chunkIndex: index,
          chunkTotal: total,
          fileB64: base64Encode(List.filled(300, index)),
          fileName: 'x.bin',
          sender: asSender(who),
        ),
      );

  Future<void> voice(String who, String uid) async => from(
    who,
    await wrapMessage(
      '',
      msgUid: uid,
      fileB64: _pic,
      fileName: 'voice.wav',
      voice: true,
      sender: asSender(who),
    ),
  );

  Future<void> text(String who, String uid) async =>
      from(who, await wrapMessage('hello', msgUid: uid, sender: asSender(who)));
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('request_media_held');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('the rule', () {
    Future<UnwrappedMessage> env({
      String? image,
      String? file,
      String? name,
      String? mid,
      DropFrame? drop,
    }) async => unwrapMessage(
      await wrapMessage(
        'words',
        msgUid: 'u1',
        imageB64: image,
        fileB64: file,
        fileName: name,
        mediaId: mid,
        chunkIndex: mid == null ? null : 0,
        chunkTotal: mid == null ? null : 2,
        drop: drop,
        sender: asSender(_s),
      ),
    );

    test('a stranger\'s file waits; words, a contact\'s, a group\'s and an '
        'introduced one\'s do not', () async {
      final pic = await env(image: _pic);
      bool waits(
        UnwrappedMessage e, {
        bool accepted = false,
        bool vouched = false,
        bool group = false,
        bool support = false,
        bool dev = false,
      }) => strangerMediaWaits(
        e,
        accepted: accepted,
        vouched: vouched,
        group: group,
        support: support,
        dev: dev,
      );
      expect(waits(pic), isTrue);
      expect(waits(await env()), isFalse);
      expect(waits(pic, accepted: true), isFalse);
      expect(waits(pic, vouched: true), isFalse);
      expect(waits(pic, group: true), isFalse);
      expect(waits(pic, support: true), isFalse);
      expect(waits(pic, dev: true), isFalse);
    });

    test('every way a file rides counts', () async {
      expect(carriesMedia(await env(image: _pic)), isTrue);
      expect(carriesMedia(await env(file: _pic, name: 'x.bin')), isTrue);
      expect(carriesMedia(await env(name: 'x.bin')), isTrue);
      expect(carriesMedia(await env(mid: 'm1', file: _pic)), isTrue);
      expect(
        carriesMedia(
          await env(
            name: 'x.bin',
            drop: const DropFrame(
              host: 'h',
              id: 'i',
              key: 'k',
              size: 1,
              chunks: 1,
              sum: 's',
            ),
          ),
        ),
        isTrue,
      );
      expect(carriesMedia(await env()), isFalse);
    });
  });

  test('a stranger\'s photo waits on the shelf, unshown', () async {
    final w = await _World.make();
    await w.photo(_s, 'p1');
    expect(w.live.msg('p1'), isNull);
    expect(w.live.heldCiphers[_s], hasLength(1));
  });

  test('so do their file slices and voice notes, none in flight', () async {
    final w = await _World.make();
    await w.slice(_s, 'f1', 0, 3);
    await w.slice(_s, 'f1', 1, 3);
    await w.voice(_s, 'v1');
    expect(w.live.chunks, isEmpty);
    expect(w.live.msg('v1'), isNull);
    expect(w.live.heldCiphers[_s], hasLength(3));
  });

  test('their words still get their two, files or not', () async {
    final w = await _World.make();
    await w.photo(_s, 'p1');
    await w.text(_s, 't1');
    await w.text(_s, 't2');
    await w.text(_s, 't3');
    expect(w.live.msg('t1'), isNotNull);
    expect(w.live.msg('t2'), isNotNull);
    expect(w.live.msg('t3'), isNull);
  });

  test('an introduced sender\'s photo comes in', () async {
    final w = await _World.make();
    w.live.vouches[_s] = {_f};
    await w.photo(_s, 'p1');
    expect(w.live.msg('p1'), isNotNull);
    expect(w.live.heldCiphers[_s], isNull);
  });

  test('a contact\'s photo comes in', () async {
    final w = await _World.make();
    await w.photo(_c, 'p1');
    expect(w.live.msg('p1'), isNotNull);
  });

  test('a photo in a group from a member not added comes in', () async {
    final w = await _World.make();
    await w.photo(_s, 'gp', group: _g);
    expect(w.live.msg('gp'), isNotNull);
    expect(w.live.heldCiphers[_s], isNull);
  });

  test('on accept the photo comes in, once', () async {
    final w = await _World.make();
    final pic = await wrapMessage(
      'a caption',
      msgUid: 'p1',
      imageB64: _pic,
      sender: asSender(_s),
    );
    // the outbox sends it again as it was
    await w.from(_s, pic);
    await w.from(_s, pic);
    expect(w.live.heldCiphers[_s], hasLength(1));
    w.live.people[_s]!['accepted'] = 1;
    await w.app.afterAccept(_s);
    await _settle();
    expect(w.live.msg('p1'), isNotNull);
    expect(w.live.msgs.where((m) => m['msg_uid'] == 'p1'), hasLength(1));
  });

  test('the decoy holds it the same way', () async {
    final w = await _World.make(HaloContainer.decoy);
    await w.photo(_s, 'p1');
    expect(w.live.msg('p1'), isNull);
    expect(w.live.heldCiphers[_s], hasLength(1));
  });

  test(
    'a hidden stranger\'s sealed photo goes on the vault\'s shelf',
    () async {
      const hs = 'hidden-stranger-one';
      final live = ArrivalRows(HaloContainer.everyday);
      final vault = ArrivalRows(HaloContainer.vault);
      final store = ArrivalStore();
      final io = ArrivalIo();
      vault.person(hs, onion: 'o-$hs', xpub: 'x-$hs', accepted: 0);
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
          '',
          msgUid: 'h1',
          imageB64: _pic,
          sender: asSender(hs),
        ),
      );
      await app.receiveOnion(['c']);
      await _settle();
      expect(store.inbox, hasLength(1));
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      expect(vault.msg('h1'), isNull);
      expect(vault.heldCiphers[hs], hasLength(1));
    },
  );
}
