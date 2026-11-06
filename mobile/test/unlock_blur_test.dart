// SPDX-License-Identifier: GPL-3.0-or-later
// photos and video frames behind the lock: nothing decoded is held while it
// is up, and after it lifts each picture shows its blur at once, at its own
// size, the photo fading up over it. the blur is sealed next to its file
// under that container's key, so the disk shows no picture, another key
// opens nothing and the decoy reads none of the real side's
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/image_strip.dart' show PictureKind, pictureKind;
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_layer.dart';
import 'package:kryfo/open_file.dart';
import 'package:kryfo/phone_seal.dart';
import 'package:kryfo/photo_blur.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/shred.dart' show shredFile;
import 'package:kryfo/widgets/sealed_picture.dart';
import 'package:path/path.dart' as p;

import 'desktop/sealed_file_test.dart' show ToyCrypto;
import 'host_engine.dart';
import 'sqlite_ffi.dart' show holds;

// real phone files stay outside the repo: KRYFO_CORPUS names their folder
final _root = Platform.environment['KRYFO_CORPUS'];
final _noCorpus = _root == null ? 'needs KRYFO_CORPUS' : null;
final _corpus = p.join(_root ?? '', 'cleaner-corpus', 'samsung');
final _wide = p.join(_corpus, '20261022_135215.jpg');
final _other = p.join(_corpus, '20261022_135238.jpg');
final _tall = p.join(_corpus, 'Screenshot_20261022-135445_Camera.jpg');

const _everydayKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _vaultKey =
    "x'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100'";
const _decoyKey =
    '0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0';

Uint8List _raw(String path) =>
    rawFileAccess(() => File(path).readAsBytesSync());

Future<Size> _shapeOf(Uint8List bytes) async {
  final b = await ui.ImmutableBuffer.fromUint8List(bytes);
  final d = await ui.ImageDescriptor.encoded(b);
  final s = Size(d.width.toDouble(), d.height.toDouble());
  d.dispose();
  b.dispose();
  return s;
}

class _Lock extends ChangeNotifier {
  bool loaded = true;
  bool locked = false;
  void set({bool? locked}) {
    this.locked = locked ?? this.locked;
    notifyListeners();
  }
}

// decoded images alive in the process, counted by the engine's own hooks
class _Alive {
  final Set<ui.Image> live = {};
  void start() {
    ui.Image.onCreate = live.add;
    ui.Image.onDispose = live.remove;
  }

  void stop() {
    ui.Image.onCreate = null;
    ui.Image.onDispose = null;
  }
}

void main() => group('real photos', _main, skip: _noCorpus);

void _main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = loadHostEngine();
  final ChunkCrypto crypto = engine ? const EngineChunkCrypto() : ToyCrypto();
  late Directory root;
  late String docs, support, cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('unlock_blur');
    docs = p.join(root.path, 'app_flutter');
    support = p.join(root.path, 'files');
    cache = p.join(root.path, 'cache');
    for (final d in [docs, support, cache]) {
      Directory(d).createSync(recursive: true);
    }
    installPhoneSeal(
      SealedAreas(docs: docs, support: support, runtime: cache, phone: true),
      crypto,
    );
    containerOpened!(HaloContainer.everyday.id, '', _everydayKey);
  });

  tearDown(() {
    resetBlursForTest();
    resetPicturesForTest();
    uninstallPhoneSealForTest();
    root.deleteSync(recursive: true);
  });

  // a real photo written into a container's media folder through the seal
  String put(String from, String folder, String leaf) {
    final at = p.join(docs, folder, leaf);
    File(at).writeAsBytesSync(File(from).readAsBytesSync());
    return at;
  }

  group('the blur', () {
    test('a real photo\'s blur is 115 bytes at any shape and reads '
        'back the same', () async {
      for (final f in [_wide, _tall]) {
        final bytes = File(f).readAsBytesSync();
        final b = (await blurOfPicture(bytes))!;
        final shape = await _shapeOf(bytes);
        final out = b.encode();
        // one size for every shape: the file says nothing of it
        expect(out.length, 115);
        expect(b.width, shape.width.toInt());
        expect(b.height, shape.height.toInt());
        // the long side gets the most waves
        expect(b.width >= b.height ? b.nx >= b.ny : b.ny >= b.nx, isTrue);
        final back = PhotoBlur.decode(out)!;
        expect(back.encode(), out);
        expect(back.colors, b.colors);
        // a blur, not a flat box: its corners differ
        expect(b.colors.toSet().length, greaterThan(10));
      }
    });

    test('bytes that are no blur read as none', () {
      expect(PhotoBlur.decode(Uint8List(0)), isNull);
      expect(PhotoBlur.decode(Uint8List(10)), isNull);
      expect(PhotoBlur.decode(File(_wide).readAsBytesSync()), isNull);
    });
  });

  group('sealed at rest', () {
    test('it lies next to its photo sealed: the disk holds no picture and '
        'none of its bytes', () async {
      final at = put(_wide, 'media', 'in_${'a' * 32}.jpg');
      final b = (await makeBlur(at))!;
      final disk = _raw(blurPathOf(at));
      expect(isSealedHead(disk), isTrue);
      expect(pictureKind(disk), PictureKind.other);
      expect(PhotoBlur.decode(disk), isNull);
      final plain = b.encode();
      expect(disk.length, storedLength(plain.length));
      expect(holds(disk, String.fromCharCodes(plain.sublist(10, 40))), isFalse);
      // through the seal it is the same blur
      expect(File(blurPathOf(at)).readAsBytesSync(), plain);
      forgetBlurs();
      expect(blurNow(at)!.encode(), plain);
    });

    test('on the desktop\'s seal the same: sealed next to its photo, '
        'under its container\'s key only', () async {
      uninstallPhoneSealForTest();
      installPhoneSeal(
        SealedAreas(docs: docs, support: support, runtime: cache),
        crypto,
      );
      containerOpened!(HaloContainer.everyday.id, '', _everydayKey);
      final at = put(_tall, 'media', 'in_${'6' * 32}.jpg');
      final plain = (await makeBlur(at))!.encode();
      final disk = _raw(blurPathOf(at));
      expect(isSealedHead(disk), isTrue);
      expect(disk.length, storedLength(plain.length));
      containerClosed!(HaloContainer.everyday.id);
      forgetBlurs();
      expect(blurNow(at), isNull);
      containerOpened!(HaloContainer.everyday.id, '', _everydayKey);
      expect(blurNow(at)!.encode(), plain);
    });

    test('another container\'s key opens nothing, and none opens it once '
        'its key is gone', () async {
      final at = put(_wide, 'media', 'in_${'b' * 32}.jpg');
      await makeBlur(at);
      final disk = _raw(blurPathOf(at));
      // the same sealed bytes under the hidden chats' folder and key
      containerOpened!(HaloContainer.vault.id, '_k3', _vaultKey);
      final there = p.join(docs, 'media_k3', p.basename(at));
      rawFileAccess(() => File(blurPathOf(there)).writeAsBytesSync(disk));
      expect(
        () => File(blurPathOf(there)).readAsBytesSync(),
        throwsA(anything),
      );
      forgetBlurs();
      expect(blurNow(there), isNull);
      // the everyday side shut: its own blur does not open either
      containerClosed!(HaloContainer.everyday.id);
      forgetBlurs();
      expect(
        () => File(blurPathOf(at)).readAsBytesSync(),
        throwsA(isA<SealedLocked>()),
      );
      expect(blurNow(at), isNull);
    });

    test('the decoy reads none of the real side\'s blurs', () async {
      final real = put(_wide, 'media', 'in_${'c' * 32}.jpg');
      await makeBlur(real);
      final realDisk = _raw(blurPathOf(real));
      // the decoy opens: the everyday key is not held
      containerClosed!(HaloContainer.everyday.id);
      containerOpened!(HaloContainer.decoy.id, '_k2', _decoyKey);
      forgetBlurs();
      expect(blurNow(real), isNull);
      // carried into the decoy's own folder, under its key it is noise
      final carried = p.join(docs, 'media_k2', p.basename(real));
      rawFileAccess(() => File(blurPathOf(carried)).writeAsBytesSync(realDisk));
      expect(blurNow(carried), isNull);
      // its own blur opens there, and nowhere on the real side
      final own = put(_other, 'media_k2', 'in_${'d' * 32}.jpg');
      expect(await makeBlur(own), isNotNull);
      final ownDisk = _raw(blurPathOf(own));
      containerClosed!(HaloContainer.decoy.id);
      containerOpened!(HaloContainer.everyday.id, '', _everydayKey);
      final back = p.join(docs, 'media', p.basename(own));
      rawFileAccess(() => File(blurPathOf(back)).writeAsBytesSync(ownDisk));
      forgetBlurs();
      expect(blurNow(back), isNull);
      expect(blurNow(real), isNotNull);
    });

    test('none is made where the seal does not reach, or behind the lock, '
        'and a photo shredded takes its blur', () async {
      final outside = p.join(support, 'x.jpg');
      File(outside).writeAsBytesSync(File(_wide).readAsBytesSync());
      expect(await makeBlur(outside), isNull);
      expect(File(blurPathOf(outside)).existsSync(), isFalse);
      final at = put(_wide, 'media', 'in_${'e' * 32}.jpg');
      picturesShut.value = true;
      expect(await makeBlur(at), isNull);
      expect(rawFileAccess(() => File(blurPathOf(at)).existsSync()), isFalse);
      picturesShut.value = false;
      await makeBlur(at);
      expect(rawFileAccess(() => File(blurPathOf(at)).existsSync()), isTrue);
      await shredFile(at);
      expect(rawFileAccess(() => File(blurPathOf(at)).existsSync()), isFalse);
    });

    test('a video\'s is made from its first frame', () async {
      final frame = File(_other).readAsBytesSync();
      const ch = MethodChannel('halo/platform');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            if (c.method != 'videoInfo') return null;
            return {
              'jpeg': Uint8List.fromList(frame),
              'ms': 4000,
              'w': 4,
              'h': 3,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ch, null),
      );
      final at = p.join(docs, 'media', 'f_${'f' * 16}.mp4');
      File(at).writeAsBytesSync(List.filled(64, 1));
      final b = (await makeBlur(at))!;
      final shape = await _shapeOf(frame);
      expect(b.width, shape.width.toInt());
      expect(isSealedHead(_raw(blurPathOf(at))), isTrue);
    });
  });

  group('the lock', () {
    // real time for the files and the decoder, a frame after each wait,
    // until every picture on screen is drawn, or a while has gone
    Future<void> decode(WidgetTester tester) async {
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final raws = tester.widgetList<RawImage>(
          find.byType(RawImage, skipOffstage: false),
        );
        if (i >= 4 && raws.isNotEmpty && raws.every((r) => r.image != null)) {
          return;
        }
      }
    }

    testWidgets('as it goes up every photo, frame and blur goes, and after '
        'it each blur is there in the first frame', (tester) async {
      final alive = _Alive()..start();
      addTearDown(alive.stop);
      final photos = [
        for (final (i, f) in [_wide, _tall, _other].indexed)
          put(f, 'media', 'in_$i${'0' * 31}.jpg'),
      ];
      await tester.runAsync(() async {
        for (final f in photos) {
          await makeBlur(f);
        }
      });
      // a video's first frame, as the player hands it over
      final frame = File(_other).readAsBytesSync();
      const ch = MethodChannel('halo/platform');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            if (c.method != 'videoInfo') return null;
            return {
              'jpeg': Uint8List.fromList(frame),
              'ms': 4000,
              'w': 4,
              'h': 3,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ch, null),
      );
      final video = p.join(docs, 'media', 'f_${'9' * 16}.mp4');
      File(video).writeAsBytesSync(List.filled(64, 1));
      final info = (await tester.runAsync(() => videoInfoFor(video)))!;
      await tester.runAsync(() => makeBlur(video));
      final jpeg = info.jpeg!;
      final lock = _Lock();
      final guard = LockGuard(isLocked: () => lock.locked);
      await tester.pumpWidget(
        haloAppShell(
          navigatorKey: GlobalKey<NavigatorState>(),
          lock: (navigator) => LockGate(
            app: navigator,
            lock: lock,
            loaded: () => lock.loaded,
            locked: () => lock.locked,
            load: () async {},
            leaving: () => lock.set(locked: true),
            returned: () {},
            guard: guard,
            quiet: () => false,
            pad: (_) => const ColoredBox(color: Color(0xFF334455)),
          ),
          home: Scaffold(
            body: ListView(
              children: [
                for (final f in photos)
                  SizedBox(
                    width: 200,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SealedPicture(
                        path: f,
                        shaped: true,
                        decodeWidth: 600,
                        image: mediaImage(f, 600),
                      ),
                    ),
                  ),
                // as the bubble reads it: the frame in hand now, if any
                ValueListenableBuilder(
                  valueListenable: picturesShut,
                  builder: (_, _, _) => SizedBox(
                    width: 300,
                    height: 170,
                    child: SealedPicture(
                      path: video,
                      image: switch (videoInfoNow(video)?.jpeg) {
                        final j? => MemoryImage(j),
                        null => null,
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await decode(tester);
      final pictures = find.byType(SealedPicture);
      expect(pictures, findsNWidgets(4));
      final sizes = [for (final e in pictures.evaluate()) e.size!];
      expect(alive.live, isNotEmpty);
      expect(PaintingBinding.instance.imageCache.currentSize, greaterThan(0));
      expect(blursHeld, greaterThan(0));

      lock.set(locked: true);
      await tester.pump();
      // nothing decoded is held anywhere: the cache, the pictures, the engine
      expect(picturesGone(), isTrue);
      expect(alive.live, isEmpty);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .where((r) => r.image != null),
        isEmpty,
      );
      expect(
        find
            .byType(CustomPaint)
            .evaluate()
            .where((e) => (e.widget as CustomPaint).painter is BlurPainter),
        isEmpty,
      );
      expect(blursHeld, 0);
      // the frame went from every hand that held it, zeroed
      expect(videoInfoNow(video)?.jpeg, isNull);
      expect(info.jpeg, isNull);
      expect(jpeg.every((b) => b == 0), isTrue);
      // and nothing moved under the lock
      expect([
        for (final e
            in find.byType(SealedPicture, skipOffstage: false).evaluate())
          e.size!,
      ], sizes);
      // what decodes late keeps nothing
      await decode(tester);
      expect(picturesGone(), isTrue);
      expect(alive.live, isEmpty);

      lock.set(locked: false);
      await tester.pump();
      // the first frame: every photo's blur at its photo's size, no photo
      final blurs = find
          .byType(CustomPaint)
          .evaluate()
          .where((e) => (e.widget as CustomPaint).painter is BlurPainter);
      expect(blurs.length, 4);
      expect([for (final e in pictures.evaluate()) e.size!], sizes);
      // the frame is asked for again, as the bubble does
      await tester.runAsync(() => videoInfoFor(video));
      await decode(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(videoInfoNow(video)?.jpeg, isNotNull);
      expect(alive.live, isNotEmpty);
      expect([for (final e in pictures.evaluate()) e.size!], sizes);
    });

    testWidgets('a photo seen without a blur while unlocked gets one, '
        'sealed, for the next time', (tester) async {
      final at = put(_wide, 'media', 'in_${'8' * 32}.jpg');
      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: 300,
            child: SealedPicture(
              path: at,
              shaped: true,
              decodeWidth: 600,
              image: mediaImage(at, 600),
            ),
          ),
        ),
      );
      final blur = blurPathOf(at);
      for (var i = 0; i < 80; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (rawFileAccess(() => File(blur).existsSync())) break;
      }
      expect(isSealedHead(_raw(blur)), isTrue);
      forgetBlurs();
      expect(blurNow(at), isNotNull);
    });

    testWidgets('a photo fades up over its blur, and under reduced motion it '
        'swaps at once', (tester) async {
      final at = put(_wide, 'media', 'in_${'7' * 32}.jpg');
      await tester.runAsync(() => makeBlur(at));
      for (final still in [false, true]) {
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        forgetBlurs();
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: still),
            child: Center(
              key: ValueKey(still),
              child: SizedBox(
                width: 300,
                child: SealedPicture(
                  path: at,
                  shaped: true,
                  decodeWidth: 600,
                  image: mediaImage(at, 600),
                ),
              ),
            ),
          ),
        );
        double shown() => tester
            .widget<FadeTransition>(
              find.descendant(
                of: find.byType(PictureFade),
                matching: find.byType(FadeTransition),
              ),
            )
            .opacity
            .value;
        // the blur at once, the photo not yet
        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is BlurPainter,
          ),
          findsOneWidget,
        );
        expect(shown(), 0);
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          // no time passes: the fade starts from where it is
          await tester.pump();
          if (tester.widget<PictureFade>(find.byType(PictureFade)).shown) {
            break;
          }
        }
        expect(
          tester.widget<PictureFade>(find.byType(PictureFade)).shown,
          isTrue,
        );
        if (still) {
          expect(shown(), 1);
          continue;
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(shown(), inExclusiveRange(0.2, 1));
        await tester.pump(const Duration(milliseconds: 120));
        expect(shown(), 1);
      }
    });

    testWidgets('nothing moves: the blur takes the box the photo then fills, '
        'wide or tall, held at the lock', (tester) async {
      for (final (i, f) in [_wide, _tall].indexed) {
        final at = put(f, 'media', 'in_$i${'5' * 31}.jpg');
        await tester.runAsync(() => makeBlur(at));
        // the photo as the chat drew it before: its own decoded shape
        Widget bubble(Widget child) => Center(
          child: SizedBox(
            width: 300,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: child,
            ),
          ),
        );
        await tester.pumpWidget(
          bubble(Image(image: mediaImage(at, 600), fit: BoxFit.cover)),
        );
        for (var k = 0; k < 6; k++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
        }
        final photo = tester.getSize(find.byType(Image));
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        await tester.pumpWidget(
          bubble(
            SealedPicture(
              key: ValueKey(at),
              path: at,
              shaped: true,
              decodeWidth: 600,
              image: mediaImage(at, 600),
            ),
          ),
        );
        // its first frame, before anything decoded
        expect(tester.getSize(find.byType(SealedPicture)), photo);
        shutPictures();
        await tester.pump();
        expect(tester.getSize(find.byType(SealedPicture)), photo);
        openPictures();
        await tester.pump();
        expect(tester.getSize(find.byType(SealedPicture)), photo);
        if (i == 1) expect(photo.height, 280);
      }
    });
  });
}
