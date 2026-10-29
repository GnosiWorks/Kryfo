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

import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/support.dart' show supportTables;
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
  _Rows(this.mem, [super.container]);
  final SqliteMem mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'calm-orbit-river';
final _gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();

// the real phone photo drawn at kPhotoSide, as our phones send one
final _square = File('test/fixtures/photo_512.jpg').readAsBytesSync();

// a jpeg the photo lane keeps as it is
final Uint8List _clean = photoFit(_square)!;

// a png chunk with its length and crc
List<int> _chunk(String type, List<int> data) {
  final t = ascii.encode(type);
  final len = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, getCrc32([...t, ...data]));
  return [
    ...len.buffer.asUint8List(),
    ...t,
    ...data,
    ...crc.buffer.asUint8List(),
  ];
}

// a 1-bit grey png of side x side, all black, its rows squeezed by zlib. a
// big side is a few kilobytes that decode to gigabytes. [moving] adds the
// chunk that makes it an apng of two frames
Uint8List _png(int side, {bool moving = false}) {
  final ihdr = ByteData(13)
    ..setUint32(0, side)
    ..setUint32(4, side)
    ..setUint8(8, 1);
  final z = <int>[];
  final sink = ZLibEncoder(
    level: 9,
  ).startChunkedConversion(ByteConversionSink.withCallback(z.addAll));
  final row = Uint8List(1 + (side + 7) ~/ 8);
  for (var y = 0; y < side; y++) {
    sink.add(row);
  }
  sink.close();
  final actl = ByteData(8)..setUint32(0, 2);
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ..._chunk('IHDR', ihdr.buffer.asUint8List()),
    if (moving) ..._chunk('acTL', actl.buffer.asUint8List()),
    ..._chunk('IDAT', z),
    ..._chunk('IEND', const []),
  ]);
}

// an animated webp of kPhotoSide: the canvas, the loop, and one frame
Uint8List _movingWebp() {
  List<int> chunk(String type, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length, Endian.little);
    return [
      ...ascii.encode(type),
      ...len.buffer.asUint8List(),
      ...data,
      if (data.length.isOdd) 0,
    ];
  }

  const s = kPhotoSide - 1;
  final side = [s & 0xFF, s >> 8 & 0xFF, 0];
  final body = [
    ...ascii.encode('WEBP'),
    ...chunk('VP8X', [0x02, 0, 0, 0, ...side, ...side]),
    ...chunk('ANIM', [0, 0, 0, 0, 0, 0]),
    ...chunk('ANMF', [0, 0, 0, 0, 0, 0, ...side, ...side, 100, 0, 0, 0]),
  ];
  final len = ByteData(4)..setUint32(0, body.length, Endian.little);
  return Uint8List.fromList([
    ...ascii.encode('RIFF'),
    ...len.buffer.asUint8List(),
    ...body,
  ]);
}

// where the photo's one frame header starts
int _sofAt(Uint8List b) {
  for (var i = 2; i + 1 < b.length; i++) {
    if (b[i] == 0xFF && b[i + 1] == 0xC0) return i;
  }
  throw StateError('no frame');
}

// [b] with its frame saying [h] x [w]
Uint8List _sized(Uint8List b, int h, int w) {
  final out = Uint8List.fromList(b);
  final at = _sofAt(out);
  ByteData.sublistView(out)
    ..setUint16(at + 5, h)
    ..setUint16(at + 7, w);
  return out;
}

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
  bool mainIdentity = true,
}) => PhotoSendFacts(
  mainIdentity: mainIdentity,
  quiet: false,
  held: false,
  dev: dev,
  accepted: accepted,
  backPaired: backPaired,
  blocked: blocked,
  peerCan: peerCan,
);

// what a modified client could send: each decodes far bigger than
// our square, or moves in every avatar
Map<String, Uint8List> _refused() {
  final at = _sofAt(_clean);
  final big = _sized(_clean, 4096, 4096);
  // a comment that holds a 512 frame header, before the real one
  final fake = _clean.sublist(at, at + 19);
  final hidden = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xFE, 0x00, 21, ...fake, //
    ...big.sublist(2),
  ]);
  // a second frame after the first
  final twice = Uint8List.fromList([
    ..._clean.sublist(0, at + 19),
    ...big.sublist(at, at + 19),
    ..._clean.sublist(at + 19),
  ]);
  // its height given again after the scan
  final dnl = Uint8List.fromList([
    ..._clean.sublist(0, _clean.length - 2),
    0xFF, 0xDC, 0x00, 0x04, 0x10, 0x00, 0xFF, 0xD9, //
  ]);
  return {
    'a png bomb': _png(20000),
    'an apng': _png(kPhotoSide, moving: true),
    'an animated webp': _movingWebp(),
    'a 4096 px jpeg': big,
    'a real phone jpeg of another size': photoFit(_gps)!,
    'a 512 frame header hidden in a comment': hidden,
    'a second frame': twice,
    'a height given after the scan': dnl,
    'a second picture after the end': Uint8List.fromList([..._clean, ...big]),
    'a jpeg cut short': _clean.sublist(0, _clean.length - 100),
  };
}

// every slice of our photo as [ver] from the peer at [at]. true when one
// made it show
Future<bool> _takeAll(HaloDb db, int ver, int at) async {
  var took = false;
  for (final f in photoSlices(_clean, ver)) {
    took = await db.takePhotoSlice(_peer, f, now: at) || took;
  }
  return took;
}

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

    test('from a contact: only a jpeg of our square, one frame', () {
      expect(photoSquareJpeg(_clean), isTrue);
      expect(photoTakeIn(_square), _clean);
      for (final MapEntry(key: what, value: b) in _refused().entries) {
        expect(b.length, lessThanOrEqualTo(kPhotoBytesMost), reason: what);
        expect(photoTakeIn(b), isNull, reason: what);
      }
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
      // on every upgrade, after the last step, under no version test: a
      // file that reached 94 or later without them still gets them
      final last = steps.lastIndexOf('await photoTables(db);');
      expect(last, greaterThan(steps.indexOf('upgradeTo91(db)')));
      expect(
        RegExp(
          r'^await photoTables\(db\);\s*\},\s*$',
        ).hasMatch(steps.substring(last)),
        isTrue,
      );
      final before = steps.substring(0, last);
      expect(
        '{'.allMatches(before).length - '}'.allMatches(before).length,
        1,
        reason: 'photoTables sits in the upgrade itself, not in a step',
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
          caps TEXT NOT NULL DEFAULT '',
          shots_on INTEGER NOT NULL DEFAULT 0,
          shots_can INTEGER NOT NULL DEFAULT 0)
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

    test('made again on a later upgrade: what is held stays, the trigger '
        'still works', () async {
      final db = await rows();
      await db.putMyPhoto(100, _clean);
      for (final f in photoSlices(_clean, 200)) {
        await db.takePhotoSlice(_peer, f, now: 300);
      }
      // the step run again, as an upgrade past 93 does
      await photoTables(db.mem);
      await photoTables(db.mem);
      expect((await db.myPhoto())?.photo, _clean);
      expect((await db.photosOf(_peer)).theirs, _clean);
      await db.mem.delete('contacts', where: 'halo_id = ?', whereArgs: [_peer]);
      expect(await db.mem.query('contact_photos'), isEmpty);
    }, skip: skip);

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
      expect(await _takeAll(db, 100, 200), isTrue);
      expect(await _takeAll(db, 90, 200), isFalse);
      expect(await db.takePhotoDrop(_peer, 150, now: 200), isTrue);
      expect((await db.photosOf(_peer)).theirs, isNull);
      expect(await _takeAll(db, 100, 200), isFalse);
      expect(await db.contactPhotos(), isEmpty);
      // and a newer photo after it is, once the gap has passed
      expect(
        await _takeAll(db, 160, 200 + kPhotoTakeGap.inMilliseconds),
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

    test('a whole photo that is not our square is let go, all of it', () async {
      for (final MapEntry(key: what, value: b) in _refused().entries) {
        final db = await rows();
        var whole = false;
        for (final f in photoSlices(b, 100)) {
          whole = await db.takePhotoSlice(_peer, f, now: 200) || whole;
        }
        expect(whole, isFalse, reason: what);
        expect((await db.photosOf(_peer)).theirs, isNull, reason: what);
        expect(await db.mem.query('photo_parts'), isEmpty, reason: what);
        expect(await db.contactPhotos(), isEmpty, reason: what);
      }
    }, skip: skip);

    test(
      'yours for them shows over theirs, and stays after their take-back',
      () async {
        final db = await rows();
        final mine = Uint8List.fromList([..._clean, 0]);
        await _takeAll(db, 100, 1);
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
        await _takeAll(db, 100, 1);
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

    Future<bool> owed(_Rows db) async => photoOwedTo(
      (await db.photoPeople()).firstWhere((x) => x.peer.id == _peer).facts,
    );

    test('only a contact of the main identity is owed it; a take-back '
        'goes to anyone', () async {
      final db = await rows();
      // no identities on this file yet: everyone knows the main one
      expect(await owed(db), isTrue);
      await db.mem.execute(
        'ALTER TABLE contacts ADD COLUMN ident INTEGER NOT NULL DEFAULT 0',
      );
      expect(await owed(db), isTrue);
      await db.mem.update('contacts', {'ident': 1});
      expect(await owed(db), isFalse);
      // owed before it moved: the photo waits, a take-back does not
      await db.owePhoto(_peer, 7, at: 1);
      expect(await db.duePhotoPeers(1 << 62), isEmpty);
      expect(await db.nextPhotoDue(), isNull);
      await db.owePhoto(_peer, 0, at: 1);
      expect((await db.duePhotoPeers(1 << 62)).single.want, 0);
    }, skip: skip);

    test('on the developer\'s phone, someone who wrote in through his chat '
        'is never owed it', () async {
      final db = await rows();
      await supportTables(db.mem);
      expect(await owed(db), isTrue);
      await db.mem.insert('support_chats', {'halo_id': _peer, 'first_at': 1});
      expect(await owed(db), isFalse);
      await db.owePhoto(_peer, 7, at: 1);
      expect(await db.duePhotoPeers(1 << 62), isEmpty);
      await db.owePhoto(_peer, 0, at: 1);
      expect((await db.duePhotoPeers(1 << 62)).single.want, 0);
    }, skip: skip);

    test('a chat that blocks screenshots shows the face', () async {
      final db = await rows();
      await _takeAll(db, 100, 1);
      expect((await db.contactPhotos()).keys, [_peer]);
      // on, but their phone does not know the block yet: nothing blocks
      await db.mem.update('contacts', {'shots_on': 1});
      expect((await db.contactPhotos()).keys, [_peer]);
      await db.mem.update('contacts', {'shots_can': 5});
      expect(await db.contactPhotos(), isEmpty);
      // the one set for them too
      await db.setMinePhoto(_peer, _clean);
      expect(await db.contactPhotos(), isEmpty);
      // in a decoy the switch alone blocks
      final quiet = _Rows(db.mem, HaloContainer.decoy);
      await db.mem.update('contacts', {'shots_can': 0});
      expect(await quiet.contactPhotos(), isEmpty);
      expect((await db.contactPhotos()).keys, [_peer]);
    }, skip: skip);

    test('a second photo inside the gap waits whole, then goes in', () async {
      final db = await rows();
      const t0 = 1000000;
      final gap = kPhotoTakeGap.inMilliseconds;
      expect(await _takeAll(db, 100, t0), isTrue);
      expect(await _takeAll(db, 200, t0 + 1000), isFalse);
      expect((await db.photosOf(_peer)).theirVer, 100);
      expect(await db.takeWaitingPhotos(now: t0 + gap - 1), isFalse);
      expect((await db.photosOf(_peer)).theirVer, 100);
      expect(await db.takeWaitingPhotos(now: t0 + gap), isTrue);
      expect((await db.photosOf(_peer)).theirVer, 200);
      expect(await db.mem.query('photo_parts'), isEmpty);
      // nothing waits now
      expect(await db.takeWaitingPhotos(now: t0 + 2 * gap), isFalse);
    }, skip: skip);

    test('a take-back is always taken, and counts toward the gap', () async {
      final db = await rows();
      const t0 = 1000000;
      expect(await _takeAll(db, 100, t0), isTrue);
      expect(await db.takePhotoDrop(_peer, 150, now: t0 + 1), isTrue);
      expect(
        await _takeAll(db, 160, t0 + kPhotoTakeGap.inMilliseconds),
        isFalse,
      );
      expect((await db.photosOf(_peer)).theirs, isNull);
      expect(
        await db.takeWaitingPhotos(now: t0 + 1 + kPhotoTakeGap.inMilliseconds),
        isTrue,
      );
      expect((await db.photosOf(_peer)).theirs, isNotNull);
    }, skip: skip);

    test('the picture is read off the ui isolate, outside any write', () {
      final src = sourceOf('lib/app/database_photos.dart');
      final at = src.indexOf('static Future<bool> _takeWhole(');
      final body = src.substring(at, src.indexOf('\n  }\n', at));
      expect(
        body.indexOf('await photoTakeInOffUi(whole)'),
        allOf(greaterThan(0), lessThan(body.indexOf('db.transaction('))),
      );
      expect(src.indexOf('photoTakeIn('), -1);
    });

    test('a new photo keeps the gap their phone takes them at; a take-back '
        'does not wait', () async {
      expect(kPhotoSendGap, greaterThan(kPhotoTakeGap));
      final db = await rows();
      await db.owePhoto(_peer, 7, at: 50);
      final first = (await db.duePhotoPeers(50)).single.stamp;
      final before = DateTime.now().millisecondsSinceEpoch;
      await db.photoSent(_peer, 7, first);
      await db.owePhoto(_peer, 8, at: 60);
      expect(
        await db.nextPhotoDue(),
        greaterThanOrEqualTo(before + kPhotoSendGap.inMilliseconds),
      );
      await db.owePhoto(_peer, 0, at: 60);
      expect(await db.nextPhotoDue(), 60);
    }, skip: skip);

    test('the version a change goes under says only the minute', () async {
      const now = 1760000012345;
      const minute = now - now % 60000;
      expect(photoStamp(0, now), minute);
      expect(photoStamp(minute, now), minute + 1);
      final db = await rows();
      await db.owePhoto(_peer, 7, at: 1);
      final s = (await db.duePhotoPeers(1)).single.stamp;
      expect(s % 60000, 0);
      await db.owePhoto(_peer, 0, at: 1);
      expect((await db.duePhotoPeers(1)).single.stamp, s + 1);
    }, skip: skip);

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
