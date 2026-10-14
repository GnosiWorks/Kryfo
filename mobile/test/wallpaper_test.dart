// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's wallpaper as it is read, cleaned and drawn: its own choice or
// the default, a photo out of the container that holds the chat, an old
// photo file taken into the database and shredded, the tags of a real
// camera photo gone, and a veil over a photo as strong as it needs in
// either theme
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/main.dart' show HaloDb, kPhotoWall, useDatabasesForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/wallpaper.dart';
import 'package:kryfo/widgets/chat_backdrop.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

class _Broken extends HaloDb {
  @override
  Future<Database> open() async => throw StateError('shut');
}

const _peer = 'someone-with-a-view';
const _hidden = 'someone-kept-apart';

Future<_Rows> _db([HaloContainer c = HaloContainer.everyday]) async {
  final db = _Rows(MemDb(), c);
  for (final id in [_peer, _hidden]) {
    await db.mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
  }
  return db;
}

// a small real picture: one colour, every pixel
Future<Uint8List> _png(Color c) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawColor(c, BlendMode.src);
  final img = await rec.endRecording().toImage(16, 16);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();

  tearDown(() => HaloColors.setLight(false));

  group('read', () {
    late _Rows live;
    setUp(() async {
      live = await _db();
      useDatabasesForTest(live, Session(live));
    });

    test('a chat with no choice of its own shows the default', () async {
      expect(await chatWall(_peer), ChatWall.none);
      await live.setDefaultWallpaper('rain');
      expect(await chatWall(_peer), const ChatWall(Atmo.rain));
      expect(await followsDefault(_peer), isTrue);
      final photo = Uint8List.fromList([1, 2, 3]);
      await live.setDefaultWallpaper(kPhotoWall, photo);
      expect((await chatWall(_peer)).photo, photo);
    });

    test('its own choice wins, plain none included', () async {
      await live.setDefaultWallpaper('rain');
      await live.setChatAtmosphere(_peer, 'none');
      expect(await chatWall(_peer), ChatWall.none);
      expect(await followsDefault(_peer), isFalse);
      await live.setChatAtmosphere(_peer, 'dusk');
      expect(await chatWall(_peer), const ChatWall(Atmo.dusk));
      final photo = Uint8List.fromList([4, 5, 6]);
      await live.setChatPhoto(_peer, photo);
      expect((await chatWall(_peer)).photo, photo);
    });

    test('a photo read again is the same wall, so nothing fades', () async {
      await live.setChatPhoto(_peer, Uint8List.fromList([1, 2, 3]));
      final a = await chatWall(_peer);
      final b = await chatWall(_peer);
      expect(a.sameAs(b), isTrue);
      await live.setChatPhoto(_peer, Uint8List.fromList([1, 2, 4]));
      expect(a.sameAs(await chatWall(_peer)), isFalse);
      expect(
        const ChatWall(Atmo.rain).sameAs(const ChatWall(Atmo.rain)),
        isTrue,
      );
    });

    test('a read that fails shows the plain page', () async {
      useDatabasesForTest(live, Session(_Broken()));
      expect(await chatWall(_peer), ChatWall.none);
      expect(await defaultWall(), ChatWall.none);
    });

    test(
      'a photo marked with its row gone shows nothing, not an error',
      () async {
        await live.setChatPhoto(_peer, Uint8List.fromList([7]));
        await live.mem.delete('wallpapers');
        expect(await chatWall(_peer), ChatWall.none);
      },
    );

    test('a photo an older version kept as a file goes into the database, '
        'cleaned, and the file is shredded', () async {
      final dir = Directory.systemTemp.createTempSync('walls');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/$_peer.jpg')..writeAsBytesSync(gps);
      expect(jpegHasExif(gps), isTrue);
      await live.setAtmosphere(_peer, 'image:${f.path}');
      final w = await chatWall(_peer);
      expect(w.photo, isNotNull);
      expect(jpegHasExif(w.photo!), isFalse);
      expect(f.existsSync(), isFalse);
      expect(await live.getAtmosphere(_peer), kPhotoWall);
      expect((await live.wallpaperRow(_peer))?.photo, w.photo);
    });

    test('an old file that is gone leaves the chat on the default', () async {
      await live.setDefaultWallpaper('snow');
      await live.setAtmosphere(_peer, 'image:/nowhere/$_peer.jpg');
      expect(await chatWall(_peer), const ChatWall(Atmo.snow));
      expect(await live.getAtmosphere(_peer), isNull);
    });
  });

  test('a hidden chat\'s photo lives in the vault; the default is the '
      'everyday side\'s', () async {
    final live = await _db();
    final vault = await _db(HaloContainer.vault);
    await live.mem.delete(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [_hidden],
    );
    await vault.mem.delete(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [_peer],
    );
    final s = await Session.withVault(live, vault);
    useDatabasesForTest(live, s);
    final photo = Uint8List.fromList([8, 8]);
    await s.setChatPhoto(_hidden, photo);
    expect((await vault.wallpaperRow(_hidden))?.photo, photo);
    expect(await live.mem.query('wallpapers'), isEmpty);
    await s.setDefaultWallpaper('moss');
    expect(await vault.wallpaperRow(''), isNull);
    expect((await live.wallpaperRow(''))?.atmo, 'moss');
    await s.setChatAtmosphere(_hidden, null);
    expect(await vault.mem.query('wallpapers'), isEmpty);
    expect(await chatWall(_hidden), const ChatWall(Atmo.moss));
  });

  testWidgets('a real camera photo loses its tags and still draws', (t) async {
    final out = await t.runAsync(() => wallpaperBytes(gps));
    expect(out, isNotNull);
    expect(jpegHasExif(out!), isFalse);
    expect(out.length, lessThanOrEqualTo(gps.length));
    final lum = await t.runAsync(() => photoLuminance(out));
    expect(lum, isNotNull);
    expect(lum, inInclusiveRange(0.0, 1.0));
  });

  group('the veil', () {
    final darkInk = const Color(0xFF0D0B09).computeLuminance();
    final paleInk = const Color(0xFFF2ECDF).computeLuminance();

    test('dark theme: a bright photo is pulled down further than a dark '
        'one', () {
      final bright = veilFor(0.8, darkInk, light: false);
      final dim = veilFor(0.08, darkInk, light: false);
      expect(bright, greaterThan(dim));
      expect(bright, lessThanOrEqualTo(0.86));
      expect(dim, greaterThanOrEqualTo(0.4));
    });

    test('light theme: a dark photo is lifted further than a pale one', () {
      final dark = veilFor(0.05, paleInk, light: true);
      final pale = veilFor(0.7, paleInk, light: true);
      expect(dark, greaterThan(pale));
      expect(dark, lessThanOrEqualTo(0.86));
      expect(pale, greaterThanOrEqualTo(0.4));
    });

    test('a photo not read yet gets a middle veil, never none', () {
      for (final light in [false, true]) {
        final v = veilFor(null, light ? paleInk : darkInk, light: light);
        expect(v, inInclusiveRange(0.4, 0.86));
      }
    });

    testWidgets('over a white photo the dark theme lands dark and the light '
        'theme pale', (t) async {
      final white = (await t.runAsync(() => _png(const Color(0xFFFFFFFF))))!;
      final black = (await t.runAsync(() => _png(const Color(0xFF000000))))!;
      final lw = (await t.runAsync(() => photoLuminance(white)))!;
      final lb = (await t.runAsync(() => photoLuminance(black)))!;
      expect(lw, greaterThan(0.95));
      expect(lb, lessThan(0.01));
      // the page under the bubbles, roughly, once veiled
      double under(double lum, double ink, double a) => a * ink + (1 - a) * lum;
      expect(
        under(lw, darkInk, veilFor(lw, darkInk, light: false)),
        lessThan(0.2),
      );
      expect(
        under(lb, paleInk, veilFor(lb, paleInk, light: true)),
        greaterThan(0.45),
      );
    });
  });

  group('the backdrop', () {
    Widget host(ChatWall w, {bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: still,
        ),
        child: SizedBox(width: 400, height: 800, child: ChatBackdrop(w)),
      ),
    );

    Color? veil(WidgetTester t) {
      final f = find.descendant(
        of: find.byType(ChatBackdrop),
        matching: find.byType(AnimatedContainer),
      );
      if (f.evaluate().isEmpty) return null;
      final c = t.widget<AnimatedContainer>(f.first);
      return (c.decoration as BoxDecoration?)?.color;
    }

    for (final light in [false, true]) {
      testWidgets('a photo wears the page\'s own ground as its veil, '
          '${light ? 'light' : 'dark'}', (t) async {
        HaloColors.setLight(light);
        final png = (await t.runAsync(() => _png(const Color(0xFF808080))))!;
        await t.pumpWidget(host(ChatWall(Atmo.none, png)));
        await t.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await t.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        final c = veil(t)!;
        expect(c.withValues(alpha: 1), HaloColors.ink);
        expect(c.a, inInclusiveRange(0.4, 0.86));
      });
    }

    testWidgets('a new wallpaper fades in over the old', (t) async {
      await t.pumpWidget(host(const ChatWall(Atmo.dusk)));
      await t.pumpWidget(host(const ChatWall(Atmo.dots)));
      await t.pump(const Duration(milliseconds: 100));
      // both on screen, mid fade
      expect(find.byType(AtmosphereWash), findsNWidgets(2));
      await t.pumpAndSettle();
      expect(find.byType(AtmosphereWash), findsOneWidget);
    });

    testWidgets('reduced motion: the new one is there at once', (t) async {
      await t.pumpWidget(host(const ChatWall(Atmo.dusk), still: true));
      await t.pumpWidget(host(const ChatWall(Atmo.dots), still: true));
      await t.pump();
      expect(find.byType(AtmosphereWash), findsOneWidget);
    });

    testWidgets('none draws nothing but the page', (t) async {
      await t.pumpWidget(host(ChatWall.none));
      expect(find.byType(AtmosphereWash), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  test('a picked photo is re-encoded at the screen\'s size, cleaned, and '
      'the picker\'s copy shredded whatever happens', () {
    final src = File('lib/wallpaper.dart').readAsStringSync();
    final at = src.indexOf('Future<Uint8List?> pickWallpaperPhoto(');
    final body = src.substring(at, src.indexOf('\n}\n', at));
    expect(body, contains('maxWidth: side'));
    expect(body, contains('maxHeight: side'));
    expect(body, contains('imageQuality:'));
    expect(body, contains('wallpaperBytes('));
    expect(body, contains('} finally {'));
    expect(body, contains('shredPickedImages'));
    expect(body, contains('lockState.hold('));
    // never a file of its own
    expect(src, isNot(contains('writeAsBytes')));
  });
}
