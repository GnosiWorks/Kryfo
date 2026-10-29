// SPDX-License-Identifier: GPL-3.0-or-later
// profile photos on the app's two sides. a contact's photo comes in slices
// and shows once whole, leaving no message, ring or receipt behind. one from
// a request, someone blocked, a group or the developer's chat is never
// kept. ours goes only to contacts who are accepted, added us back, are not
// blocked and whose phone takes photos; a removal or a block takes it back.
// the decoy sends nothing. signal, the engine and the databases are
// stand-ins; the photo rows are the app's own on the host's sqlite
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStateContacts,
        AppStatePhotos,
        AppStateReceive,
        AppStateRoute,
        AppStateTyping,
        HaloEngine,
        releaseChat,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/profile_photo.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/typing.dart' show kCapPhotos, kCapTyping;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'source_body.dart';
import 'sqlite_ffi.dart';

const _f = 'plain-friend-here'; // accepted, added back, takes photos
const _na = 'new-friend-here'; // not added back yet
const _s = 'guitar-present-kid'; // a request
const _b = 'blocked-one-here'; // blocked
const _o = 'old-phone-here'; // a version without photos

// the real phone photo drawn at kPhotoSide, as our phones send one
final _square = File('test/fixtures/photo_512.jpg').readAsBytesSync();
final Uint8List _clean = photoFit(_square)!;

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final decoy = ArrivalRows(HaloContainer.decoy);
  final io = ArrivalIo();
  late AppState app;
  var _next = 0;

  static Future<_World> make() async {
    final w = _World();
    const pp = '$kCapPhotos,$kCapTyping';
    for (final (id, back) in [(_f, 1), (_na, 0), (_s, 1), (_b, 1), (_o, 1)]) {
      w.live.person(
        id,
        onion: 'o-$id',
        xpub: 'x-$id',
        backPaired: back,
        accepted: id == _s ? 0 : 1,
      );
      w.live.people[id]!['caps'] = id == _o ? kCapTyping : pp;
    }
    w.live.people[_b]!['blocked'] = 1;
    w.decoy.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.decoy.people[_f]!['caps'] = pp;
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    w.app.sendModeForTest = 'private';
    w.app.setTorStatusForTest(TorStatus.reachable);
    w.app.setRouteOKForTest(true);
    w.app.inFrontForTest = true;
    useDatabasesForTest(w.live, Session(w.live));
    photoBook.clear();
    return w;
  }

  void inDecoy() => useDatabasesForTest(live, Session(decoy));

  // [frame] from [who] through the onion door
  Future<void> from(String who, String frame) async {
    final c = 'p${_next++}';
    io.opens[c] = (who, frame);
    await app.receiveOnion([c]);
  }

  Future<void> photoFrom(
    String who,
    Uint8List photo,
    int ver, {
    String? group,
  }) async {
    for (final f in photoSlices(photo, ver)) {
      var w = wrapPhotoFrame(
        f,
        writtenAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (group != null) w = w.replaceFirst('{', '{"g":"$group",');
      await from(who, w);
    }
  }

  // what went out holding a photo frame, by whom it went to
  List<(String, PhotoFrame)> get photoSends => [
    for (final (to, c) in io.sent)
      if (unwrapMessage(c.substring(c.indexOf('halo/1:'))).photo case final f?)
        (to, f),
  ];

  // every owe due now
  Future<void> allDue() async {
    await live.photoMem?.execute('UPDATE photo_peers SET next_at = 0');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.openForTest();
  });

  tearDown(() {
    for (final p in [_f, _na, _s, _b, _o]) {
      releaseChat(p);
    }
  });

  group('coming in', () {
    test('a contact\'s photo shows once whole, and leaves nothing else '
        'behind', () async {
      final w = await _World.make();
      final ver = DateTime.now().millisecondsSinceEpoch;
      final slices = photoSlices(_clean, ver);
      expect(slices.length, greaterThan(1));
      for (final f in slices.take(slices.length - 1)) {
        await w.from(_f, wrapPhotoFrame(f, writtenAt: ver));
      }
      expect(photoBook.has(_f), isFalse);
      await w.from(_f, wrapPhotoFrame(slices.last, writtenAt: ver));
      expect(photoBook.of(_f), isNotNull);
      expect(w.live.msgs, isEmpty);
      expect(w.io.rang, isEmpty);
      expect([for (final (to, _) in w.io.sent) to], isEmpty);
    }, skip: skip);

    test('a picture bigger than our square: nothing kept, nothing '
        'read again', () async {
      final w = await _World.make();
      final big = Uint8List.fromList(_clean);
      for (var i = 2; i + 1 < big.length; i++) {
        if (big[i] == 0xFF && big[i + 1] == 0xC0) {
          ByteData.sublistView(big)
            ..setUint16(i + 5, 4096)
            ..setUint16(i + 7, 4096);
          break;
        }
      }
      var told = 0;
      void tell() => told++;
      photoBook.addListener(tell);
      addTearDown(() => photoBook.removeListener(tell));
      await w.photoFrom(_f, big, DateTime.now().millisecondsSinceEpoch);
      expect(photoBook.has(_f), isFalse);
      expect(told, 0);
      expect(await w.live.contactPhotos(), isEmpty);
      expect(await w.live.photoMem!.query('photo_parts'), isEmpty);
      expect(w.live.msgs, isEmpty);
    }, skip: skip);

    test('its take-back shows the face again', () async {
      final w = await _World.make();
      final ver = DateTime.now().millisecondsSinceEpoch;
      await w.photoFrom(_f, _clean, ver);
      expect(photoBook.has(_f), isTrue);
      await w.from(
        _f,
        wrapPhotoFrame(PhotoFrame.drop(ver + 1), writtenAt: ver),
      );
      expect(photoBook.has(_f), isFalse);
      expect(w.live.msgs, isEmpty);
    }, skip: skip);

    test(
      'from a request, someone blocked or in a group frame, never kept',
      () async {
        final w = await _World.make();
        final ver = DateTime.now().millisecondsSinceEpoch;
        await w.photoFrom(_s, _clean, ver);
        await w.photoFrom(_b, _clean, ver);
        await w.photoFrom(_f, _clean, ver, group: 'grp000000001');
        expect(photoBook.length, 0);
        expect(await w.live.contactPhotos(), isEmpty);
        expect(w.live.people[_s]!['accepted'], 0);
        expect(w.live.msgs, isEmpty);
      },
      skip: skip,
    );

    // the gates one by one: none of these reaches the photo rows at all
    List<String> photoCalls(ArrivalRows r) => [
      for (final c in r.calls)
        if (c.startsWith('takePhoto')) c,
    ];

    test('someone blocked: neither a photo nor a take-back reaches the '
        'rows', () async {
      final w = await _World.make();
      final ver = DateTime.now().millisecondsSinceEpoch;
      await w.photoFrom(_b, _clean, ver);
      await w.from(
        _b,
        wrapPhotoFrame(PhotoFrame.drop(ver + 1), writtenAt: ver),
      );
      expect(photoCalls(w.live), isEmpty);
      expect(photoBook.has(_b), isFalse);
      expect(await w.live.contactPhotos(), isEmpty);
      expect(w.live.msgs, isEmpty);
      expect(w.io.rang, isEmpty);
    }, skip: skip);

    test(
      'a request not accepted: nothing kept, and it stays a request',
      () async {
        final w = await _World.make();
        await w.photoFrom(_s, _clean, DateTime.now().millisecondsSinceEpoch);
        expect(photoCalls(w.live), isEmpty);
        expect(photoBook.has(_s), isFalse);
        expect(w.live.people[_s]!['accepted'], 0);
        expect(w.live.msgs, isEmpty);
        expect(w.io.rang, isEmpty);
      },
      skip: skip,
    );

    test('someone with no row at all: nothing kept, no row made', () async {
      final w = await _World.make();
      const nobody = 'nobody-known-here';
      await w.photoFrom(nobody, _clean, DateTime.now().millisecondsSinceEpoch);
      expect(photoCalls(w.live), isEmpty);
      expect(photoBook.has(nobody), isFalse);
      expect(w.live.people.containsKey(nobody), isFalse);
      expect(w.live.msgs, isEmpty);
    }, skip: skip);

    test('a frame that names a group, from an accepted contact: never kept, '
        'and its take-back leaves their own photo', () async {
      final w = await _World.make();
      final ver = DateTime.now().millisecondsSinceEpoch;
      await w.photoFrom(_f, _clean, ver, group: 'grp000000001');
      expect(photoCalls(w.live), isEmpty);
      expect(photoBook.has(_f), isFalse);
      // their 1:1 photo, then a take-back through a group frame
      await w.photoFrom(_f, _clean, ver);
      expect(photoBook.has(_f), isTrue);
      final drop = wrapPhotoFrame(
        PhotoFrame.drop(ver + 1),
        writtenAt: ver,
      ).replaceFirst('{', '{"g":"grp000000001",');
      await w.from(_f, drop);
      expect(photoBook.has(_f), isTrue);
      expect(w.live.msgs, isEmpty);
    }, skip: skip);

    test(
      'a quiet container takes none in, from an accepted contact either',
      () async {
        final w = await _World.make();
        // the decoy as the container frames land in
        useDatabasesForTest(w.decoy, Session(w.decoy));
        expect(w.decoy.container.quiet, isTrue);
        final ver = DateTime.now().millisecondsSinceEpoch;
        await w.photoFrom(_f, _clean, ver);
        await w.from(
          _f,
          wrapPhotoFrame(PhotoFrame.drop(ver + 1), writtenAt: ver),
        );
        expect(photoCalls(w.decoy), isEmpty);
        expect(photoBook.length, 0);
        expect(await w.decoy.contactPhotos(), isEmpty);
        expect(w.decoy.msgs, isEmpty);
        expect(w.io.rang, isEmpty);
      },
      skip: skip,
    );

    test('a decoy on screen shows none of the everyday side\'s', () async {
      final w = await _World.make();
      await w.photoFrom(_f, _clean, DateTime.now().millisecondsSinceEpoch);
      expect(photoBook.has(_f), isTrue);
      w.inDecoy();
      await w.app.reloadPhotos();
      expect(photoBook.has(_f), isFalse);
    }, skip: skip);
  });

  group('a chat that blocks screenshots', () {
    test('shows the face on every screen, theirs or the one set for '
        'them', () async {
      final w = await _World.make();
      await w.photoFrom(_f, _clean, DateTime.now().millisecondsSinceEpoch);
      expect(photoBook.has(_f), isTrue);
      w.live.people[_f]!
        ..['shots_on'] = 1
        ..['shots_can'] = 5;
      await w.app.reloadPhotos();
      expect(photoBook.has(_f), isFalse);
      expect(await w.app.setContactPhoto(_f, _clean), isTrue);
      expect(photoBook.has(_f), isFalse);
      // lifted, the photo shows again
      w.live.people[_f]!['shots_on'] = 0;
      await w.app.reloadPhotos();
      expect(photoBook.has(_f), isTrue);
    }, skip: skip);

    test('the switch, either phone\'s, takes the photo off before the '
        'next frame', () {
      final src = sourceOf('lib/app/state_screen.dart');
      for (final at in [
        src.indexOf('Future<void> _turnShots('),
        src.indexOf('Future<void> _takeShots('),
      ]) {
        final body = src.substring(at, src.indexOf('\n  }\n', at));
        final moved = body.indexOf('_photoShotsMoved(peer');
        expect(moved, greaterThan(0));
        expect(moved, lessThan(body.indexOf('notifyListeners()')));
      }
    });
  });

  group('going out', () {
    test('only to someone accepted, added back, not blocked, on a phone '
        'that takes it, in slices', () async {
      final w = await _World.make();
      expect(await w.app.setMyPhoto(_clean), isTrue);
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      final sends = w.photoSends;
      expect({for (final (to, _) in sends) to}, {'relay x-$_f'});
      expect(sends.every((s) => !s.$2.drop), isTrue);
      final parts = {for (final (_, f) in sends) f.index: f.bytes!};
      expect(joinPhotoSlices(parts, sends.first.$2.total), _clean);
      // held now: a second pass sends nothing
      w.io.sent.clear();
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      expect(w.photoSends, isEmpty);
    }, skip: skip);

    test('a change waits a few minutes, not a burst', () async {
      final w = await _World.make();
      await w.app.setMyPhoto(_clean);
      await w.app.photoSweep();
      await w.app.photoSendDue();
      expect(w.photoSends, isEmpty);
      final at = await w.live.nextPhotoDue();
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(at! - now, greaterThan(kPhotoSpreadFrom.inMilliseconds - 2000));
      w.app.stopPhotos();
    }, skip: skip);

    test('a removal and a block take it back', () async {
      final w = await _World.make();
      await w.app.setMyPhoto(_clean);
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      w.io.sent.clear();
      await w.app.block(_f);
      w.live.people[_f]!['blocked'] = 1;
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      final back = w.photoSends;
      expect(back, hasLength(1));
      expect(back.single.$1, 'relay x-$_f');
      expect(back.single.$2.drop, isTrue);
      w.app.stopPhotos();
    }, skip: skip);

    test('removed, every holder gets the take-back once', () async {
      final w = await _World.make();
      await w.app.setMyPhoto(_clean);
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      w.io.sent.clear();
      await w.app.removeMyPhoto();
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      expect(
        [for (final (to, f) in w.photoSends) (to, f.drop)],
        [('relay x-$_f', true)],
      );
      w.io.sent.clear();
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      expect(w.photoSends, isEmpty);
    }, skip: skip);

    test('a failed send goes again later, not now', () async {
      final w = await _World.make();
      await w.app.setMyPhoto(_clean);
      await w.app.photoSweep();
      await w.allDue();
      w.io.down = true;
      await w.app.photoSendDue();
      final due = await w.live.duePhotoPeers(
        DateTime.now().millisecondsSinceEpoch,
      );
      expect(due, isEmpty);
      final later = await w.live.nextPhotoDue();
      expect(
        later! - DateTime.now().millisecondsSinceEpoch,
        greaterThan(kPhotoBackoff.first.inMilliseconds ~/ 2),
      );
      w.app.stopPhotos();
    }, skip: skip);

    test('the decoy keeps its own photo and sends nothing', () async {
      final w = await _World.make();
      w.inDecoy();
      expect(await w.app.setMyPhoto(_clean), isTrue);
      await w.app.photoSweep();
      await w.allDue();
      await w.app.photoSendDue();
      expect(w.photoSends, isEmpty);
      expect((await w.decoy.myPhoto())!.photo, isNotNull);
      expect(await w.live.myPhoto(), isNull);
      expect(photoBook.of('me'), isNull);
    }, skip: skip);

    test('a phone that says it takes photos later gets it then', () async {
      final w = await _World.make();
      await w.app.setMyPhoto(_clean);
      await w.app.photoSweep();
      expect(
        [
          for (final p in await w.live.photoPeople())
            if (p.peer.want != null) p.peer.id,
        ],
        [_f],
      );
      w.live.people[_o]!['caps'] = '$kCapPhotos,$kCapTyping';
      await w.app.photoSweep();
      expect(
        {
          for (final p in await w.live.photoPeople())
            if (p.peer.want != null) p.peer.id,
        },
        {_f, _o},
      );
      w.app.stopPhotos();
    }, skip: skip);
  });

  test('the frame carries no text a 0.5 phone would show', () {
    final w = wrapPhotoFrame(const PhotoFrame.drop(5), writtenAt: 5);
    final j = jsonDecode(w.substring('halo/1:'.length)) as Map;
    expect(j.keys.toSet(), {kPhotoWire, 'w'});
  });
}
