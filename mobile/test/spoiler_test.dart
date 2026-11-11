// SPDX-License-Identifier: GPL-3.0-or-later
// a photo sent as a spoiler: marked in the tray or the preview, it travels
// under its own field, is kept by the step to 97, and is blurred on both
// ends until it is tapped. the lock blurs it again
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kryfo/main.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/picked.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/widgets/spoiler_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'old_wire/envelope_051.dart' as v051;
import 'sqlite_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the wire', () {
    test('a spoiler goes as sv and comes back; one alone has none', () async {
      final w = await wrapMessage('', msgUid: 'u1', spoiler: true);
      expect(w, contains('"sv":1'));
      expect(unwrapMessage(w).spoiler, isTrue);
      final plain = await wrapMessage('', msgUid: 'u2');
      expect(plain, isNot(contains('"sv"')));
      expect(unwrapMessage(plain).spoiler, isFalse);
      // a phone before spoilers reads it as the photo it is
      expect(v051.unwrapMessage(w).msgUid, 'u1');
    });
  });

  group('the picks', () {
    test('a pick marked in the tray comes to the preview marked', () async {
      final dir = Directory.systemTemp.createTempSync('spoiler_picks');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
      final b = File('${dir.path}/b.jpg')..writeAsBytesSync([4, 5, 6]);
      final got = await readGalleryPicks(
        [XFile(a.path), XFile(b.path)],
        shrink: (x) async => x,
        drop: (_) async {},
        spoilers: {b.path},
      );
      expect(got.map((m) => m.spoiler), [false, true]);
      expect(got.first.withSpoiler(true).spoiler, isTrue);
      expect(got.last.withSpoiler(false).spoiler, isFalse);
    });

    test('a video is never a spoiler', () {
      final v = PickedMedia.video(XFile('/x/v.mp4'));
      expect(v.withSpoiler(true).spoiler, isFalse);
      final p = PickedMedia.photo(Uint8List(1));
      expect(identical(p.withSpoiler(false), p), isTrue);
    });
  });

  group('the database', () {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    late Directory docs;
    SqliteChannel? sql;
    setUp(() {
      sql = SqliteChannel.install();
      docs = Directory.systemTemp.createTempSync('spoiler_db');
      m.setMockMethodCallHandler(paths, (_) async => docs.path);
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': '0e' * 32,
      });
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      sql?.uninstall();
      m.setMockMethodCallHandler(paths, null);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    test('the step to 97 adds the mark and keeps every row (now 98)', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final db = HaloDb();
      final raw = await db.open();
      expect(await raw.getVersion(), 98);
      await db.saveMessage('amber-otter-lake', 'in', 'before', msgUid: 'u0');
      await raw.execute('ALTER TABLE messages DROP COLUMN spoiler');
      await raw.setVersion(96);
      await db.close();
      final again = HaloDb();
      final up = await again.open();
      expect(await up.getVersion(), 98);
      await again.saveMessage(
        'amber-otter-lake',
        'in',
        '',
        msgUid: 'u1',
        mediaPath: '/m/u1.jpg',
        spoiler: true,
      );
      final rows = await up.query(
        'messages',
        columns: ['msg_uid', 'spoiler'],
        orderBy: 'id',
      );
      expect(rows, [
        {'msg_uid': 'u0', 'spoiler': 0},
        {'msg_uid': 'u1', 'spoiler': 1},
      ]);
      await again.close();
    });
  });

  group('the cover', () {
    setUp(() {
      forgetSpoilersForTest();
      openPictures();
    });

    Widget host(Widget child, {bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    );

    Widget cover({bool on = true}) => SpoilerCover(
      uid: 's1',
      on: on,
      child: const SizedBox(width: 200, height: 150, child: Text('photo')),
    );

    for (final still in [false, true]) {
      testWidgets('blurred until tapped, then kept seen (still: $still)', (
        t,
      ) async {
        await t.pumpWidget(host(cover(), still: still));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(ImageFiltered), findsOneWidget);
        await t.tap(find.byType(SpoilerCover));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(ImageFiltered), findsNothing);
        expect(spoilerSeen('s1'), isTrue);
        // drawn again, it stays open
        await t.pumpWidget(host(const SizedBox()));
        await t.pumpWidget(host(cover(), still: still));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(ImageFiltered), findsNothing);
      });
    }

    testWidgets('the lock blurs it again', (t) async {
      await t.pumpWidget(host(cover()));
      await t.tap(find.byType(SpoilerCover));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(ImageFiltered), findsNothing);
      shutPictures();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(spoilerSeen('s1'), isFalse);
      openPictures();
    });

    testWidgets('a photo that is no spoiler draws as it is', (t) async {
      await t.pumpWidget(host(cover(on: false)));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}
