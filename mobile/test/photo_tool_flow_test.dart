// SPDX-License-Identifier: GPL-3.0-or-later
// the one photo tool: what a photo or video gives away, then one button that
// removes all of it
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/clean_screen.dart';
import 'package:kryfo/screens/photo_knows_screen.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/tools_bridge.dart';
import 'package:kryfo/widgets/tool_parts.dart';

import 'meta_fixtures.dart';

Widget framed(Widget home, {Locale? locale, double scale = 1}) => MaterialApp(
  theme: buildHaloTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

// the tools channel hands over a copy of [bytes]; the cache is a temp dir
Directory world(WidgetTester t, String name, Uint8List bytes) {
  final root = Directory.systemTemp.createTempSync('photo_tool');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  final m = t.binding.defaultBinaryMessenger;
  const tools = MethodChannel('halo/tools');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  m.setMockMethodCallHandler(tools, (c) async {
    if (c.method != 'copyIn') return null;
    final dir = Directory('${root.path}/in')..createSync(recursive: true);
    return (File('${dir.path}/$name')..writeAsBytesSync(bytes)).path;
  });
  m.setMockMethodCallHandler(paths, (_) async => root.path);
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() {
    m.setMockMethodCallHandler(tools, null);
    m.setMockMethodCallHandler(paths, null);
    m.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return root;
}

// isolates and file work finish in real time
Future<void> settle(WidgetTester t, Finder until) async {
  for (var i = 0; i < 100 && until.evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
  expect(until, findsWidgets);
}

Future<void> readThenRemove(
  WidgetTester t,
  PickedFile file, {
  String? title,
  List<String> shows = const [],
  List<String> hides = const [],
}) async {
  t.view.physicalSize = const Size(1000, 2000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(framed(PhotoKnowsScreen(file: file)));
  // everything it gives away first, with the one button under it
  await settle(t, find.text(l10n.photoKnowsRemoveAllOfIt));
  expect(find.byType(CleanScreen), findsNothing);
  if (title != null) expect(find.text(title), findsOneWidget);
  await t.tap(find.text(l10n.photoKnowsRemoveAllOfIt));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  expect(find.byType(CleanScreen), findsOneWidget);
  expect(find.byType(PhotoKnowsScreen), findsNothing);
  // the copy read is the copy cleaned: nothing is picked or copied again
  final clean = t.widget<CleanScreen>(find.byType(CleanScreen));
  expect(clean.localPath, isNotNull);
  await settle(t, find.text(l10n.cleanShareCleanCopy));
  await t.pump(const Duration(seconds: 2));
  for (final w in shows) {
    expect(find.text(w), findsWidgets, reason: w);
  }
  for (final w in hides) {
    expect(find.text(w), findsNothing, reason: w);
  }
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('the tools tab offers one photo tool, for photos and videos', (
    t,
  ) async {
    final got = <String>[];
    await t.pumpWidget(
      framed(
        Scaffold(
          body: ToolsScreen(
            onPickPhoto: () => got.add('photo'),
            onPickVideo: () => got.add('video'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Clean a photo or video'), findsNothing);
    expect(find.text(l10n.toolsPickAPhotoAnd), findsOneWidget);
    await t.tap(find.text(l10n.toolsPickAPhoto));
    await t.tap(find.text(l10n.toolsVideo));
    expect(got, ['photo', 'video']);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('a photo: what it gives away, then remove all of it', (t) async {
    world(t, 'a.jpg', jpeg(tiff: cameraTiff()));
    await readThenRemove(
      t,
      const PickedFile(
        uri: 'content://test/a.jpg',
        name: 'a.jpg',
        size: 100,
        mime: 'image/jpeg',
      ),
      title: 'Photo cleaner',
    );
  });

  // no place in it: the map data loads once per run and is the photo's
  testWidgets('a video is read and cleaned the same way', (t) async {
    world(t, 'm.mp4', mp4(maker: true, created: 3800000000));
    await readThenRemove(
      t,
      const PickedFile(
        uri: 'content://test/m.mp4',
        name: 'm.mp4',
        size: 100,
        mime: 'video/mp4',
      ),
      title: 'Video cleaner',
    );
  });

  for (final (lang, scale) in [('ar', 1.0), ('en', 2.0), ('fa', 2.0)]) {
    testWidgets('the screen is the photo cleaner, $lang at ${scale}x', (
      t,
    ) async {
      setL10nLocale(Locale(lang));
      addTearDown(() => setL10nLocale(const Locale('en')));
      // a phone's width; the test font draws every letter as wide as it is
      // tall, so the title needs more room than a real one
      t.view.physicalSize = Size(scale > 1 ? 1200 : 720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      // no place in it: the map data loads once per run and is the photo's.
      // a name of its own: a path read in an earlier test is gone
      const x = '<x:xmpmeta><rdf:Description hdrgm:Version="1.0"/></x:xmpmeta>';
      world(t, '$lang.jpg', jpeg(xmp: x, mpf: true, trailer: jpeg()));
      await t.pumpWidget(
        framed(
          PhotoKnowsScreen(
            file: PickedFile(
              uri: 'content://test/$lang.jpg',
              name: '$lang.jpg',
              size: 100,
              mime: 'image/jpeg',
            ),
          ),
          locale: Locale(lang),
          scale: scale,
        ),
      );
      await settle(t, find.text(l10n.photoKnowsRemoveAllOfIt));
      final title = find.text(l10n.photoKnowsPhotoCleaner);
      expect(title, findsOneWidget);
      expect(
        l10n.photoKnowsPhotoCleaner,
        lang == 'en' ? 'Photo cleaner' : isNot('Photo cleaner'),
      );
      // the whole title, never cut short with "…"
      expect(t.renderObject<RenderParagraph>(title).didExceedMaxLines, isFalse);
      if (lang != 'en') {
        expect(Directionality.of(t.element(title)), TextDirection.rtl);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('large text: a tool button takes a second line, never cut', (
    t,
  ) async {
    await t.pumpWidget(
      framed(
        Center(
          child: SizedBox(
            width: 300,
            child: ToolWideButton(
              label: 'Remove all of it',
              filled: true,
              onTap: () {},
            ),
          ),
        ),
        scale: 1.5,
      ),
    );
    expect(t.takeException(), isNull);
    final p = t.renderObject<RenderParagraph>(find.text('Remove all of it'));
    expect(p.didExceedMaxLines, isFalse);
    final words = t.getSize(find.text('Remove all of it'));
    expect(
      t.getSize(find.byType(ToolWideButton)).height,
      greaterThan(words.height),
    );
  });

  testWidgets('a photo with an hdr layer: same picture, the layer removed', (
    t,
  ) async {
    const x = '<x:xmpmeta><rdf:Description hdrgm:Version="1.0"/></x:xmpmeta>';
    // no place in it, as for the video: the map data loads once per run
    world(t, 'h.jpg', jpeg(xmp: x, mpf: true, trailer: jpeg()));
    await readThenRemove(
      t,
      const PickedFile(
        uri: 'content://test/h.jpg',
        name: 'h.jpg',
        size: 100,
        mime: 'image/jpeg',
      ),
      shows: [l10n.cleanSamePicture, l10n.cleanerHdrLayer],
      hides: [l10n.cleanSamePictureSameQuality],
    );
  });
}
