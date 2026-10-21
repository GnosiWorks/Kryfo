// SPDX-License-Identifier: GPL-3.0-or-later
// the one photo tool: what a photo or video gives away, then one button that
// removes all of it
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/clean_screen.dart';
import 'package:kryfo/screens/photo_knows_screen.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/tools_bridge.dart';

import 'meta_fixtures.dart';

Widget framed(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
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

Future<void> readThenRemove(WidgetTester t, PickedFile file) async {
  t.view.physicalSize = const Size(1000, 2000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(framed(PhotoKnowsScreen(file: file)));
  // everything it gives away first, with the one button under it
  await settle(t, find.text(l10n.photoKnowsRemoveAllOfIt));
  expect(find.byType(CleanScreen), findsNothing);
  await t.tap(find.text(l10n.photoKnowsRemoveAllOfIt));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  expect(find.byType(CleanScreen), findsOneWidget);
  expect(find.byType(PhotoKnowsScreen), findsNothing);
  // the copy read is the copy cleaned: nothing is picked or copied again
  final clean = t.widget<CleanScreen>(find.byType(CleanScreen));
  expect(clean.localPath, isNotNull);
  await settle(t, find.text(l10n.cleanShareCleanCopy));
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
    );
  });
}
