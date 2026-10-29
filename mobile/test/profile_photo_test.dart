// SPDX-License-Identifier: GPL-3.0-or-later
// profile photos on the wire and in the database. a photo goes in slices
// that each fill a media slice's seal, reads back whole only when every
// slice is in, and a newer version or a take-back wins over an older one.
// a photo that is no clean picture is never kept. what a contact holds of
// ours is worked out from who they are: only someone accepted, added back,
// not blocked and on a phone that takes photos gets it
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/image_strip.dart' show pictureKind, PictureKind;
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/main.dart' show HaloDb, photoTables;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/photo_pick.dart' show squarePhoto;
import 'package:kryfo/profile_photo.dart';
import 'package:kryfo/typing.dart';
import 'package:kryfo/vault_life.dart' show chatTables;
import 'package:kryfo/wire_pad.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'source_body.dart';
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final SqliteMem mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'calm-orbit-river';
final _gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();

// a jpeg the photo lane keeps as it is: the cleaned real phone file
final Uint8List _clean = photoFit(_gps)!;

String _sealed(String wrapped) {
  final body = shotsBodyOf(wrapped)!;
  capsPut(body);
  return padSeal(shotsPut(body, const ShotsWord(on: false, at: 0)));
}

PhotoSendFacts _facts({
  bool accepted = true,
  bool backPaired = true,
  bool blocked = false,
  bool peerCan = true,
  bool dev = false,
}) => PhotoSendFacts(
  quiet: false,
  held: false,
  dev: dev,
  accepted: accepted,
  backPaired: backPaired,
  blocked: blocked,
  peerCan: peerCan,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wire', () {
    test('a slice reads back as it went, and holds nothing else', () {
      final f = PhotoFrame.slice(
        version: 1760000000123,
        index: 1,
        total: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final env = unwrapMessage(wrapPhotoFrame(f, writtenAt: 5));
      expect(env.photo, isNotNull);
      expect(env.photo!.drop, isFalse);
      expect(env.photo!.version, 1760000000123);
      expect(env.photo!.index, 1);
      expect(env.photo!.total, 3);
      expect(env.photo!.bytes, [1, 2, 3]);
      expect(env.message, '');
      expect(env.msgUid, isNull);
      expect(env.senderHaloId, isNull);
      expect(env.imageB64, isNull);
      expect(env.writtenAt, 5);
    });

    test('a take-back reads back as one', () {
      final env = unwrapMessage(
        wrapPhotoFrame(const PhotoFrame.drop(42), writtenAt: 1),
      );
      expect(env.photo!.drop, isTrue);
      expect(env.photo!.version, 42);
    });

    test('a frame no phone of ours sends is no photo', () {
      for (final raw in <Object?>[
        null,
        'x',
        {'v': 0, 'x': 1},
        {'v': -3, 'x': 1},
        {'v': 'a', 'x': 1},
        {'v': 1, 'i': 0, 'n': 0, 'd': 'AQ=='},
        {'v': 1, 'i': 2, 'n': 2, 'd': 'AQ=='},
        {'v': 1, 'i': 0, 'n': kPhotoSlicesMost + 1, 'd': 'AQ=='},
        {'v': 1, 'i': 0, 'n': 1, 'd': ''},
        {'v': 1, 'i': 0, 'n': 1, 'd': '@@not base64'},
        {
          'v': 1,
          'i': 0,
          'n': 1,
          'd': base64Encode(Uint8List(kPhotoSliceBytes + 1)),
        },
      ]) {
        expect(PhotoFrame.fromWire(raw), isNull, reason: '$raw');
      }
    });

    test('a full slice, sealed, fills a media slice\'s size and no more', () {
      final f = photoSlices(Uint8List(kPhotoSliceBytes * 2), 1760000000123);
      expect(f, hasLength(2));
      final s = _sealed(wrapPhotoFrame(f.first, writtenAt: 1760000000123));
      expect(utf8Length(s), kSealSizes[3]);
      expect(unwrapMessage(unpad(s)).photo!.bytes, hasLength(kPhotoSliceBytes));
      // the take-back is as long as a short text
      final d = _sealed(
        wrapPhotoFrame(const PhotoFrame.drop(1760000000123), writtenAt: 1),
      );
      expect(utf8Length(d), kSealSizes.first);
    });

    test('slices join back to the photo, and not while one is missing', () {
      final r = Random(7);
      final photo = Uint8List.fromList(
        List.generate(kPhotoSliceBytes * 3 + 99, (_) => r.nextInt(256)),
      );
      final s = photoSlices(photo, 9);
      expect(s, hasLength(4));
      final parts = {for (final f in s) f.index: f.bytes!};
      expect(joinPhotoSlices(parts, 4), photo);
      parts.remove(2);
      expect(joinPhotoSlices(parts, 4), isNull);
      expect(photoSlices(Uint8List(kPhotoBytesMost + 1), 1), isEmpty);
    });

    test('every phone with this build says it takes photos', () {
      expect(kMyCaps, contains(kCapPhotos));
      expect(capsFromWire(['pp', 'zz']), ['pp']);
    });
  });

  group('what is kept', () {
    test('a real phone photo is kept only once nothing is left in it', () {
      expect(jpegHasExif(_gps), isTrue);
      final out = photoFit(_gps)!;
      expect(jpegHasExif(out), isFalse);
      expect(readMetaStrict(MemorySource(out)).status, MetaStatus.nothing);
    });

    test('a picture kind every phone draws, small enough, or nothing', () {
      final heic = File(
        'test/fixtures/heic_exif_at_end.heic',
      ).readAsBytesSync();
      expect(photoFit(heic), isNull);
      expect(photoFit(Uint8List(0)), isNull);
      expect(photoFit(Uint8List.fromList(utf8.encode('<svg/>'))), isNull);
      final big = Uint8List(kPhotoBytesMost + 1)..setAll(0, [0xFF, 0xD8, 0xFF]);
      expect(photoFit(big), isNull);
    });

    test('the drawn square goes through the same check: a tagged real file '
        'from the encoder comes out clean or not at all', () async {
      final out = await squarePhoto(Uint8List(4), (
        left: 0,
        top: 0,
        side: 1,
      ), encode: (_, _) async => _gps);
      expect(out, isNotNull);
      expect(jpegHasExif(out!), isFalse);
      expect(readMetaStrict(MemorySource(out)).status, MetaStatus.nothing);
      expect(pictureKind(out), PictureKind.jpeg);
      expect(
        await squarePhoto(Uint8List(4), (
          left: 0,
          top: 0,
          side: 1,
        ), encode: (_, _) async => null),
        isNull,
      );
    });
  });

  group('versions and who gets it', () {
    test('only newer, and never past tomorrow', () {
      const now = 1760000000000;
      expect(photoVersionTakes(now, now - 1, now: now), isTrue);
      expect(photoVersionTakes(now, now, now: now), isFalse);
      expect(photoVersionTakes(now - 5, now, now: now), isFalse);
      expect(
        photoVersionTakes(
          now + const Duration(days: 2).inMilliseconds,
          0,
          now: now,
        ),
        isFalse,
      );
    });

    test('accepted, added back, not blocked, a phone that takes it', () {
      expect(photoOwedTo(_facts()), isTrue);
      expect(photoOwedTo(_facts(accepted: false)), isFalse);
      expect(photoOwedTo(_facts(backPaired: false)), isFalse);
      expect(photoOwedTo(_facts(blocked: true)), isFalse);
      expect(photoOwedTo(_facts(peerCan: false)), isFalse);
      expect(photoOwedTo(_facts(dev: true)), isFalse);
    });

    test('what they should hold: ours, a take-back, or nothing owed', () {
      expect(photoTarget(sent: 0, mine: 7, owed: true), 7);
      expect(photoTarget(sent: 7, mine: 7, owed: true), isNull);
      expect(photoTarget(sent: 7, mine: 9, owed: true), 9);
      // blocked or deleted: taken back
      expect(photoTarget(sent: 7, mine: 7, owed: false), 0);
      // removed
      expect(photoTarget(sent: 7, mine: 0, owed: true), 0);
      expect(photoTarget(sent: 0, mine: 0, owed: true), isNull);
      expect(photoTarget(sent: 0, mine: 7, owed: false), isNull);
    });

    test('a change goes a few minutes out, a retry later each time', () {
      final r = Random(1);
      const now = 1000000;
      for (var i = 0; i < 200; i++) {
        final at = photoFirstAt(now, r) - now;
        expect(at, greaterThanOrEqualTo(kPhotoSpreadFrom.inMilliseconds));
        expect(at, lessThan(kPhotoSpreadTo.inMilliseconds));
      }
      var last = 0;
      for (var t = 0; t < kPhotoBackoff.length; t++) {
        final step = kPhotoBackoff[t].inMilliseconds;
        final at = photoRetryAt(now, t, r) - now;
        expect(at, inInclusiveRange(step * 0.9, step * 1.1));
        expect(at, greaterThan(last));
        last = at;
      }
      expect(
        photoRetryAt(now, 99, r) - now,
        lessThanOrEqualTo(kPhotoBackoff.last.inMilliseconds * 1.1),
      );
    });

    test('the book keeps the same bytes and says when it moved', () {
      final b = PhotoBook();
      var told = 0;
      b.addListener(() => told++);
      final a = Uint8List.fromList([1, 2]);
      b.put({'x': a});
      expect(told, 1);
      b.put({
        'x': Uint8List.fromList([1, 2]),
      });
      expect(told, 1);
      expect(identical(b.of('x'), a), isTrue);
      b.put({'x': a, 'y': a});
      expect(told, 2);
      b.clear();
      expect(told, 3);
      expect(b.has('x'), isFalse);
    });
  });

  group('the database', () {
    final src = sourceOf('lib/app/database.dart');
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');

    test('made on create, and on the upgrade to 93', () {
      expect(src, contains('version: 93,'));
      final create = src.substring(
        src.indexOf('onCreate: (db, _) async {'),
        upgrade,
      );
      expect(create, contains('await photoTables(db);'));
      final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
      expect(steps, contains('if (oldV < 93) {'));
      expect(
        steps.indexOf('photoTables(db)'),
        greaterThan(steps.indexOf('upgradeTo91(db)')),
      );
    });

    test('a contact\'s photo rows go with their chat into the vault', () {
      expect(
        chatTables,
        containsAll(['contact_photos', 'photo_parts', 'photo_peers']),
      );
      expect(chatTables, isNot(contains('my_photo')));
    });

    final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

    Future<_Rows> rows() async {
      final mem = SqliteMem.open()!;
      await mem.execute('''
        CREATE TABLE contacts (halo_id TEXT PRIMARY KEY,
          accepted INTEGER NOT NULL DEFAULT 1,
          back_paired INTEGER NOT NULL DEFAULT 0,
          blocked INTEGER NOT NULL DEFAULT 0,
          caps TEXT NOT NULL DEFAULT '')
      ''');
      await photoTables(mem);
      await mem.insert('contacts', {
        'halo_id': _peer,
        'back_paired': 1,
        'caps': 'pp,ty',
      });
      await mem.insert('contacts', {'halo_id': 'other-one-here'});
      return _Rows(mem);
    }

    test(
      'slices in any order make the photo; a missing one keeps the face',
      () async {
        final db = await rows();
        final s = photoSlices(_clean, 100);
        for (final f in s.reversed.skip(s.length > 1 ? 1 : 0)) {
          expect(await db.takePhotoSlice(_peer, f, now: 200), s.length == 1);
        }
        if (s.length > 1) {
          expect((await db.photosOf(_peer)).theirs, isNull);
          expect(await db.takePhotoSlice(_peer, s.last, now: 200), isTrue);
        }
        final p = await db.photosOf(_peer);
        expect(p.theirs, _clean);
        expect(p.theirVer, 100);
        expect(await db.mem.query('photo_parts'), isEmpty);
        expect((await db.contactPhotos())[_peer], _clean);
      },
      skip: skip,
    );

    test('an older version, or one after a take-back, is not taken', () async {
      final db = await rows();
      final one = photoSlices(_clean, 100).single;
      expect(await db.takePhotoSlice(_peer, one, now: 200), isTrue);
      expect(
        await db.takePhotoSlice(
          _peer,
          photoSlices(_clean, 90).single,
          now: 200,
        ),
        isFalse,
      );
      expect(await db.takePhotoDrop(_peer, 150, now: 200), isTrue);
      expect((await db.photosOf(_peer)).theirs, isNull);
      expect(await db.takePhotoSlice(_peer, one, now: 200), isFalse);
      expect(await db.contactPhotos(), isEmpty);
      // and a newer photo after it is
      expect(
        await db.takePhotoSlice(
          _peer,
          photoSlices(_clean, 160).single,
          now: 200,
        ),
        isTrue,
      );
    }, skip: skip);

    test('slices of a newer photo drop an older one half in', () async {
      final db = await rows();
      final big = Uint8List(kPhotoSliceBytes + 10);
      await db.takePhotoSlice(_peer, photoSlices(big, 100).first, now: 1);
      await db.takePhotoSlice(_peer, photoSlices(big, 120).first, now: 1);
      final left = await db.mem.query('photo_parts');
      expect([for (final r in left) r['ver']], [120]);
      // the older one's last slice changes nothing now
      expect(
        await db.takePhotoSlice(_peer, photoSlices(big, 100).last, now: 1),
        isFalse,
      );
    }, skip: skip);

    test('a whole photo that is no clean picture is let go', () async {
      final db = await rows();
      final junk = Uint8List.fromList(List.filled(300, 7));
      expect(
        await db.takePhotoSlice(_peer, photoSlices(junk, 100).single, now: 200),
        isFalse,
      );
      expect((await db.photosOf(_peer)).theirs, isNull);
      expect(await db.mem.query('photo_parts'), isEmpty);
    }, skip: skip);

    test(
      'yours for them shows over theirs, and stays after their take-back',
      () async {
        final db = await rows();
        final mine = Uint8List.fromList([..._clean, 0]);
        await db.takePhotoSlice(_peer, photoSlices(_clean, 100).single, now: 1);
        expect(await db.setMinePhoto(_peer, mine), isTrue);
        expect((await db.contactPhotos())[_peer], mine);
        await db.takePhotoDrop(_peer, 101, now: 1);
        expect((await db.contactPhotos())[_peer], mine);
        expect(await db.setMinePhoto(_peer, null), isTrue);
        expect(await db.contactPhotos(), isEmpty);
        // never for a row this container does not hold
        expect(await db.setMinePhoto('nobody-here-at-all', mine), isFalse);
      },
      skip: skip,
    );

    test('owed, sent, and failed sends wait their turn', () async {
      final db = await rows();
      await db.owePhoto(_peer, 7, at: 50);
      expect(await db.duePhotoPeers(49), isEmpty);
      final due = await db.duePhotoPeers(50);
      expect(due.single.want, 7);
      final stamp = due.single.stamp;
      expect(await db.nextPhotoDue(), 50);
      await db.photoLater(_peer, stamp, 90);
      expect((await db.duePhotoPeers(90)).single.tries, 1);
      await db.photoSent(_peer, 7, stamp);
      expect(await db.duePhotoPeers(1 << 62), isEmpty);
      final people = {for (final x in await db.photoPeople()) x.peer.id: x};
      expect(people[_peer]!.peer.held, 7);
      expect(photoOwedTo(people[_peer]!.facts), isTrue);
      // the other one never added this phone back
      expect(photoOwedTo(people['other-one-here']!.facts), isFalse);
      // a take-back after it goes under a newer stamp
      await db.owePhoto(_peer, 0, at: 60);
      final back = (await db.duePhotoPeers(60)).single;
      expect(back.want, 0);
      expect(back.stamp, greaterThan(stamp));
      // a send that finished for an owe since replaced counts for nothing
      await db.photoSent(_peer, 7, stamp);
      expect((await db.duePhotoPeers(60)).single.want, 0);
    }, skip: skip);

    test(
      'a deleted chat loses both photos and keeps what they hold of ours',
      () async {
        final db = await rows();
        await db.takePhotoSlice(_peer, photoSlices(_clean, 100).single, now: 1);
        await db.setMinePhoto(_peer, _clean);
        await db.owePhoto(_peer, 7, at: 1);
        await db.dropPhotosOf(_peer);
        expect(await db.contactPhotos(), isEmpty);
        expect(await db.mem.query('photo_peers'), hasLength(1));
        // a row that goes takes all of it
        await db.mem.delete(
          'contacts',
          where: 'halo_id = ?',
          whereArgs: [_peer],
        );
        expect(await db.mem.query('photo_peers'), isEmpty);
      },
      skip: skip,
    );

    test('your own photo, and its removal keeping the time', () async {
      final db = await rows();
      expect(await db.myPhoto(), isNull);
      await db.putMyPhoto(10, _clean);
      expect((await db.myPhoto())!.photo, _clean);
      await db.putMyPhoto(20, null);
      final me = (await db.myPhoto())!;
      expect(me.ver, 20);
      expect(me.photo, isNull);
    }, skip: skip);
  });
}
