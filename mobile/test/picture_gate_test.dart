// SPDX-License-Identifier: GPL-3.0-or-later
// received pictures reach a decoder only as a jpeg, a png or a gif, told by
// their first bytes: every other kind, a cut one and one under a wrong name
// never reach the codec, in the bubble or in the blur, and show the bubble's
// "photo unavailable" with another app to open them. ours are drawn as they
// are. what the photo lane sends is a jpeg, png or gif: any other kind is
// drawn again as a jpeg, and one that cannot be is not sent at all
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show containerOpened;
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/file_kind.dart' show readFileFacts;
import 'package:kryfo/image_strip.dart' show PictureKind, pictureKind;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/phone_seal.dart';
import 'package:kryfo/photo_blur.dart';
import 'package:kryfo/picture_convert.dart';
import 'package:kryfo/picture_gate.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/widgets/file_actions.dart' show FileView, fileViewFor;
import 'package:kryfo/widgets/file_sheet.dart';
import 'package:kryfo/widgets/photo_viewer.dart' show PhotoViewer, openPhoto;
import 'package:kryfo/widgets/sealed_picture.dart';
import 'package:path/path.dart' as p;

import 'desktop/sealed_file_test.dart' show ToyCrypto;
import 'host_engine.dart';

const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

img.Image _pic() =>
    img.Image(width: 8, height: 6)..clear(img.ColorRgb8(200, 40, 90));

final _jpeg = img.encodeJpg(_pic());
final _png = img.encodePng(_pic());
final _gif = img.encodeGif(_pic());
final _bmp = img.encodeBmp(_pic());
final _tiff = img.encodeTiff(_pic());
final _ico = img.encodeIco(_pic());
// the first bytes are all the gate reads: a webp's and a wbmp's
final _webp = Uint8List.fromList([
  ...'RIFF'.codeUnits,
  40,
  0,
  0,
  0,
  ...'WEBPVP8 '.codeUnits,
  ...List.filled(28, 1),
]);
final _wbmp = Uint8List.fromList([0, 0, 8, 6, ...List.filled(6, 0xFF)]);
final _heic = File('test/fixtures/heic_exif_at_end.heic').readAsBytesSync();
final _avif = File('test/fixtures/motion_photo.avif').readAsBytesSync();

// what no decoder may see of theirs, by name on disk and bytes
final _refused = <String, (String, List<int>)>{
  'webp': ('webp', _webp),
  'bmp': ('bmp', _bmp),
  'ico': ('ico', _ico),
  'wbmp': ('wbmp', _wbmp),
  'heif': ('heic', _heic),
  'avif': ('avif', _avif),
  'tiff': ('tiff', _tiff),
  'a jpeg cut short': ('jpg', [0xFF, 0xD8]),
  'a gif cut short': ('gif', 'GIF8'.codeUnits),
  'a png cut short': ('png', _png.sublist(0, 7)),
  'a bmp named as a jpeg': ('jpg', _bmp),
  'a webp named as a gif': ('gif', _webp),
  'a heic named as a png': ('png', _heic),
  'nothing': ('jpg', <int>[]),
};

final _allowed = <String, (String, List<int>)>{
  'jpeg': ('jpg', _jpeg),
  'png': ('png', _png),
  'gif': ('gif', _gif),
  // a name says nothing: the bytes decide
  'a png named as a jpeg': ('jpg', _png),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = loadHostEngine();
  final ChunkCrypto crypto = engine ? const EngineChunkCrypto() : ToyCrypto();
  late Directory root;
  late String media;
  late List<MethodCall> asked;
  var n = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picture_gate');
    final docs = p.join(root.path, 'app_flutter');
    final support = p.join(root.path, 'files');
    final cache = p.join(root.path, 'cache');
    for (final d in [docs, support, cache]) {
      Directory(d).createSync(recursive: true);
    }
    media = p.join(docs, 'media');
    Directory(media).createSync();
    installPhoneSeal(
      SealedAreas(docs: docs, support: support, runtime: cache, phone: true),
      crypto,
    );
    containerOpened!(HaloContainer.everyday.id, '', _key);
    lockState.openForTest();
    asked = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
          call,
        ) async {
          asked.add(call);
          return call.method == 'openFile' ? true : null;
        });
    fileSheetPickForTest = () => FileSheetPick.open;
  });

  tearDown(() {
    fileSheetPickForTest = null;
    blurDecodeForTest = null;
    photoLaneDrawForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    resetBlursForTest();
    resetPicturesForTest();
    uninstallPhoneSealForTest();
    root.deleteSync(recursive: true);
  });

  // a received file, through the seal, under the name an arrival gives it
  String theirs(String ext, List<int> bytes) {
    final at = p.join(
      media,
      'in_${(n++).toRadixString(16).padLeft(32, '0')}.$ext',
    );
    File(at).writeAsBytesSync(bytes);
    return at;
  }

  // what reached the codec: the gate's own call with a spy for the decoder
  Future<(int, Object?)> throughGate(String path) async {
    var reached = 0;
    Object? error;
    try {
      await GatedFileImage.gatedCodec(
        GatedFileImage(path, pictureFromPath(path)),
        (ui.ImmutableBuffer b, {ui.TargetImageSizeCallback? getTargetSize}) {
          reached++;
          b.dispose();
          throw StateError('spied');
        },
      );
    } catch (e) {
      error = e;
    }
    return (reached, error);
  }

  group('a picture of theirs', () {
    for (final MapEntry(key: what, value: (ext, bytes)) in _refused.entries) {
      test('$what never reaches a codec, and opens in another app', () async {
        final at = theirs(ext, bytes);
        expect(pictureFromPath(at), PictureFrom.theirs);
        final (reached, error) = await throughGate(at);
        expect(reached, 0);
        expect(error, bytes.isEmpty ? isStateError : isA<PictureRefused>());
        expect(await fileMayDecode(at), isFalse);
        expect(
          await fileViewFor(at, await readFileFacts(at, 'x.$ext')),
          isNull,
        );
      });
    }

    for (final MapEntry(key: what, value: (ext, bytes)) in _allowed.entries) {
      test('$what reaches the codec once', () async {
        final at = theirs(ext, bytes);
        final (reached, error) = await throughGate(at);
        expect(reached, 1);
        expect(error, isStateError);
        expect(await fileMayDecode(at), isTrue);
        expect(
          await fileViewFor(at, await readFileFacts(at, 'x.$ext')),
          FileView.picture,
        );
      });
    }

    test('the bubble draws it through the gate, ours as a plain file', () {
      final at = theirs('webp', _webp);
      final image = mediaImage(at, 300) as ResizeImage;
      expect(image.imageProvider, GatedFileImage(at, PictureFrom.theirs));
      final mine = p.join(media, 'f_abc.webp');
      expect(
        (mediaImage(mine, 300) as ResizeImage).imageProvider,
        isA<FileImage>(),
      );
      expect(mediaImage(mine), isA<FileImage>());
    });

    test('ours of any kind reaches the codec', () async {
      for (final (ext, bytes) in [
        ('webp', _webp),
        ('bmp', _bmp),
        ('heic', _heic),
      ]) {
        final at = p.join(media, '${n++}.$ext');
        File(at).writeAsBytesSync(bytes);
        expect(pictureFromPath(at), PictureFrom.ours);
        expect(await fileMayDecode(at), isTrue);
        expect(
          pictureMayDecode(Uint8List.fromList(bytes), PictureFrom.ours),
          isTrue,
        );
      }
    });
  });

  group('the blur', () {
    test('of theirs is made only from a jpeg, png or gif', () async {
      final seen = <PictureKind>[];
      blurDecodeForTest = (b) async {
        seen.add(pictureKind(b));
        return null;
      };
      for (final (ext, bytes) in _refused.values) {
        if (bytes.isEmpty) continue;
        expect(await makeBlur(theirs(ext, bytes)), isNull);
      }
      expect(seen, isEmpty);
      for (final (ext, bytes) in _allowed.values) {
        await makeBlur(theirs(ext, bytes));
      }
      expect(seen, [
        PictureKind.jpeg,
        PictureKind.png,
        PictureKind.gif,
        PictureKind.png,
      ]);
    });

    test('of ours is made from any kind', () async {
      var reached = 0;
      blurDecodeForTest = (_) async {
        reached++;
        return null;
      };
      final at = p.join(media, 'f_mine.webp');
      File(at).writeAsBytesSync(_webp);
      await makeBlur(at);
      expect(reached, 1);
    });
  });

  group('the bubble', () {
    Future<void> show(WidgetTester t, String at) async {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              child: SealedPicture(
                path: at,
                image: mediaImage(at, 400),
                errorBuilder: (_, _, _) => Text(l10n.chatPhotoUnavailable),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
    }

    for (final what in ['webp', 'heif', 'a bmp named as a jpeg']) {
      testWidgets('shows "photo unavailable" for $what', (t) async {
        final (ext, bytes) = _refused[what]!;
        await show(t, theirs(ext, bytes));
        expect(find.text(l10n.chatPhotoUnavailable), findsOneWidget);
      });
    }

    testWidgets('draws a png of theirs', (t) async {
      await show(t, theirs('png', _png));
      expect(find.text(l10n.chatPhotoUnavailable), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
    });

    testWidgets('a tap on one refused offers another app, never the viewer', (
      t,
    ) async {
      final at = theirs('webp', _webp);
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await t.runAsync(() => openPhoto(ctx, at));
      await t.pump();
      expect(find.byType(PhotoViewer), findsNothing);
      expect([for (final c in asked) c.method], contains('openFile'));
    });
  });

  group('the photo lane sends', () {
    final jpegOut = Uint8List.fromList(_jpeg);

    for (final MapEntry(key: what, value: bytes) in {
      'webp': _webp,
      'bmp': _bmp,
      'heic': _heic,
      'avif': _avif,
      'tiff': _tiff,
    }.entries) {
      test('a $what drawn again as a jpeg', () async {
        final drawn = <PictureKind>[];
        photoLaneDrawForTest = (b) async {
          drawn.add(pictureKind(b));
          return jpegOut;
        };
        final out = await photoLaneBytes(Uint8List.fromList(bytes));
        expect(drawn, hasLength(1));
        expect(pictureKind(out!), PictureKind.jpeg);
      });

      test('no $what when it cannot be drawn, never as it came', () async {
        photoLaneDrawForTest = (_) async => null;
        expect(await photoLaneBytes(Uint8List.fromList(bytes)), isNull);
        // a drawing that is no jpeg goes nowhere either
        photoLaneDrawForTest = (_) async => Uint8List.fromList(_png);
        expect(await photoLaneBytes(Uint8List.fromList(bytes)), isNull);
      });
    }

    for (final MapEntry(key: what, value: bytes) in {
      'jpeg': _jpeg,
      'png': _png,
      'gif': _gif,
    }.entries) {
      test('a $what as its own kind, never drawn again', () async {
        var drawn = 0;
        photoLaneDrawForTest = (_) async {
          drawn++;
          return jpegOut;
        };
        final out = await photoLaneBytes(Uint8List.fromList(bytes));
        expect(drawn, 0);
        expect(pictureKind(out!), pictureKind(Uint8List.fromList(bytes)));
      });
    }
  });
}
