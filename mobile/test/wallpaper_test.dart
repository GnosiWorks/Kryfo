// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's wallpaper as it is read, cleaned and drawn: its own choice or
// the default, a photo out of the container that holds the chat, the tags
// of a real camera photo gone, and a veil over a photo as strong as it
// needs in either theme
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
import 'package:kryfo/widgets/wall_images.dart';
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
    final samples = await t.runAsync(() => photoSamples(out));
    expect(samples, hasLength(64));
  });

  group('the veil', () {
    const darkInk = Color(0xFF0D0B09);
    const paleInk = Color(0xFFF2ECDF);
    // the page under the bubbles, as the screen mixes it
    double under(Color photo, Color ground, double a) =>
        Color.lerp(photo, ground, a)!.computeLuminance();
    List<Color> shot(Color c, int n, [Color? rest]) => [
      for (var i = 0; i < 64; i++) i < n ? c : (rest ?? c),
    ];

    test('dark theme: a bright photo is pulled down further than a dark '
        'one, and lands dark', () {
      const white = Color(0xFFFFFFFF);
      final bright = veilFor(shot(white, 64), darkInk, light: false);
      final dim = veilFor(
        shot(const Color(0xFF202020), 64),
        darkInk,
        light: false,
      );
      expect(bright, greaterThan(dim));
      expect(bright, lessThanOrEqualTo(0.86));
      expect(dim, greaterThanOrEqualTo(0.4));
      expect(
        under(
          const Color(0xFF808080),
          darkInk,
          veilFor(shot(const Color(0xFF808080), 64), darkInk, light: false),
        ),
        lessThanOrEqualTo(0.0601),
      );
    });

    test('light theme: a dark photo is lifted further than a pale one, and '
        'lands pale', () {
      const black = Color(0xFF000000);
      final dark = veilFor(shot(black, 64), paleInk, light: true);
      final pale = veilFor(
        shot(const Color(0xFFE0E0E0), 64),
        paleInk,
        light: true,
      );
      expect(dark, greaterThan(pale));
      expect(dark, lessThanOrEqualTo(0.86));
      expect(pale, greaterThanOrEqualTo(0.4));
      const mid = Color(0xFF606060);
      expect(
        under(mid, paleInk, veilFor(shot(mid, 64), paleInk, light: true)),
        greaterThanOrEqualTo(0.5499),
      );
    });

    test('a bright patch on a dark photo is covered too: the veil follows '
        'its brightest tenth, not its average', () {
      // a night photo with a lamp in a corner: an eighth of it white
      final lamp = shot(const Color(0xFFFFFFFF), 8, const Color(0xFF101010));
      final mean = shot(const Color(0xFF5A5A5A), 64);
      final v = veilFor(lamp, darkInk, light: false);
      // the average of it alone would ask far less
      expect(v, greaterThan(veilFor(mean, darkInk, light: false)));
      expect(
        under(const Color(0xFFFFFFFF), darkInk, v),
        lessThanOrEqualTo(0.0601),
      );
      // and the light theme looks at its darkest tenth
      final snow = shot(const Color(0xFF000000), 8, const Color(0xFFF0F0F0));
      expect(veilFor(snow, paleInk, light: true), greaterThan(0.75));
    });

    test('a photo not read yet gets a middle veil, never none', () {
      for (final light in [false, true]) {
        final v = veilFor(null, light ? paleInk : darkInk, light: light);
        expect(v, inInclusiveRange(0.4, 0.86));
      }
    });

    testWidgets('a white photo read back as white, a black one as black', (
      t,
    ) async {
      final white = (await t.runAsync(() => _png(const Color(0xFFFFFFFF))))!;
      final black = (await t.runAsync(() => _png(const Color(0xFF000000))))!;
      final w = (await t.runAsync(() => photoSamples(white)))!;
      final b = (await t.runAsync(() => photoSamples(black)))!;
      expect(w.every((c) => c.computeLuminance() > 0.95), isTrue);
      expect(b.every((c) => c.computeLuminance() < 0.01), isTrue);
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
    final at = src.indexOf('Future<Picked> pickWallpaperPhoto(');
    final body = src.substring(at, src.indexOf('\n}\n', at));
    expect(body, contains('maxWidth: side'));
    expect(body, contains('maxHeight: side'));
    expect(body, contains('kWallSide'));
    expect(body, contains('imageQuality:'));
    expect(body, contains('keepPicked(at, raw, save)'));
    expect(
      body.indexOf('final at = session;'),
      lessThan(body.indexOf('lockState.hold(')),
    );
    expect(body, contains('} finally {'));
    expect(body, contains('shredPickedImages'));
    expect(body, contains('lockState.hold('));
    // never a file of its own
    expect(src, isNot(contains('writeAsBytes')));
  });

  test('a kept photo is never larger than kWallSide', () {
    expect(kWallSide, 2048);
  });

  group('a picked photo', () {
    late _Rows live;
    late _Rows vault;
    late Session s;
    setUp(() async {
      live = await _db();
      vault = await _db(HaloContainer.vault);
      // the everyday side knows the hidden one by key alone: a photo
      // routed here would find a row to land on
      await live.mem.update(
        'contacts',
        {'accepted': 0, 'archived': 1},
        where: 'halo_id = ?',
        whereArgs: [_hidden],
      );
      await vault.mem.delete(
        'contacts',
        where: 'halo_id = ?',
        whereArgs: [_peer],
      );
      s = await Session.withVault(live, vault);
      useDatabasesForTest(live, s);
    });

    testWidgets('lands in the session it was picked in', (t) async {
      final r = await t.runAsync(
        () => keepPicked(s, gps, (at, p) => at.setChatPhoto(_hidden, p)),
      );
      expect(r, Picked.kept);
      expect(await vault.wallpaperRow(_hidden), isNotNull);
      expect(await live.mem.query('wallpapers'), isEmpty);
    });

    testWidgets('a hidden chat\'s photo goes nowhere when the vault shuts '
        'while it is cleaned', (t) async {
      final r = await t.runAsync(() {
        final f = keepPicked(s, gps, (at, p) => at.setChatPhoto(_hidden, p));
        // the lock comes down: the everyday session alone is open
        useDatabasesForTest(live, Session(live));
        return f;
      });
      expect(r, Picked.none);
      expect(await live.mem.query('wallpapers'), isEmpty);
      expect(await vault.mem.query('wallpapers'), isEmpty);
      expect(await live.getAtmosphere(_hidden), isNull);
    });

    testWidgets('one that will not clean is said so and kept nowhere', (
      t,
    ) async {
      final r = await t.runAsync(
        () => keepPicked(
          s,
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0, 9]),
          (at, p) => at.setChatPhoto(_hidden, p),
        ),
      );
      expect(r, Picked.unclean);
      expect(await vault.mem.query('wallpapers'), isEmpty);
    });
  });

  test('a photo for a chat that is not here is not kept', () async {
    final live = await _db();
    useDatabasesForTest(live, Session(live));
    expect(await live.setChatPhoto('nobody-here', Uint8List(4)), isFalse);
    expect(
      await live.setChatPhoto('g-gone', Uint8List(4), group: true),
      isFalse,
    );
    expect(await live.mem.query('wallpapers'), isEmpty);
    expect(await live.setChatPhoto(_peer, Uint8List(4)), isTrue);
  });

  group('the decoded photo', () {
    tearDown(WallImages.clear);

    test('is decoded to cover the screen and no larger', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      // wider than the screen: its height decides
      final wide =
          WallImages.of(
                'a',
                bytes,
                const Size(4000, 1000),
                const Size(1080, 2400),
              )
              as ResizeImage;
      expect((wide.width, wide.height), (null, 1000));
      WallImages.clear();
      final tall =
          WallImages.of(
                'a',
                bytes,
                const Size(2000, 8000),
                const Size(1080, 2400),
              )
              as ResizeImage;
      expect((tall.width, tall.height), (1080, null));
    });

    test('is one per chat: the same photo read again shares it', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final same = Uint8List.fromList([1, 2, 3]);
      const photo = Size(100, 100), screen = Size(50, 50);
      final first = WallImages.of('chat', a, photo, screen);
      expect(
        identical(WallImages.of('chat', same, photo, screen), first),
        isTrue,
      );
      final other = WallImages.of(
        'chat',
        Uint8List.fromList([4]),
        photo,
        screen,
      );
      expect(identical(other, first), isFalse);
      WallImages.of('else', a, photo, screen);
      expect(WallImages.count, 2);
    });

    testWidgets('leaves the image cache when the lock comes down', (t) async {
      final png = (await t.runAsync(() => _png(const Color(0xFF808080))))!;
      final image = WallImages.of(
        'chat',
        png,
        const Size(16, 16),
        const Size(8, 8),
      );
      await t.pumpWidget(Image(image: image));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      final key = await image.obtainKey(ImageConfiguration.empty);
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.containsKey(key), isTrue);
      WallImages.clear();
      expect(cache.containsKey(key), isFalse);
      expect(WallImages.count, 0);
      // the lock and a session switch both put them out
      expect(
        File('lib/lock_layer.dart').readAsStringSync(),
        contains('WallImages.clear();'),
      );
      final main = File('lib/main.dart').readAsStringSync();
      final renew = main.indexOf('void renewRootNavigator() {');
      expect(
        main.substring(renew, main.indexOf('}', renew)),
        contains('WallImages.clear();'),
      );
    });
  });
}
