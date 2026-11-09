// SPDX-License-Identifier: GPL-3.0-or-later
// a received app installer is never handed to the package installer: no
// tap, menu or fallback opens or shares it. the only thing it offers is a
// save through the system save window, under a name ending in its real
// extension. the native side refuses it too, and asks for no permission
// to install. the platform is a stand-in that records every call
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/open_file.dart';
import 'package:kryfo/widgets/photo_viewer.dart' show PhotoViewer;
import 'package:kryfo/widgets/file_sheet.dart';
import 'package:kryfo/widgets/video_bubble.dart' show openReceivedFile;

import 'source_body.dart';
import 'zip_maker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late List<MethodCall> asked;
  Object? openAnswer = true;

  setUp(() {
    lockState.openForTest();
    tmp = Directory.systemTemp.createTempSync('open_installer');
    asked = [];
    openAnswer = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
          call,
        ) async {
          asked.add(call);
          return switch (call.method) {
            'saveDocumentState' => {'stage': 'idle', 'copied': 0},
            'saveDocument' => {'state': 'saved', 'where': 'Download'},
            'openFile' => openAnswer,
            'shareFile' => true,
            _ => null,
          };
        });
  });

  // the file sheet answers open, as a tap on its first line
  setUp(() => fileSheetPickForTest = () => FileSheetPick.open);

  tearDown(() {
    fileSheetPickForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    tmp.deleteSync(recursive: true);
  });

  List<String> methods() => [for (final c in asked) c.method];

  Future<void> tap(WidgetTester t, String path, String? name) async {
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
    await t.runAsync(() => openReceivedFile(ctx, path, name));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  // every shape a received app can come in
  final installers = <String, (String, List<int>)>{
    'named as one': ('app.apk', [1, 2, 3]),
    'in capitals': ('APP.APK', [1, 2, 3]),
    'behind a double extension': ('photo.jpg.apk', [0xFF, 0xD8, 0xFF]),
    'renamed as a photo': ('holiday.jpg', apkBytes()),
    'renamed as a video': ('clip.mp4', apkBytes()),
    'with no extension': ('document', apkBytes(first: 'classes.dex')),
    'a bundle of apps': (
      'game.zip',
      zipOf({
        'base.apk': [1],
        'toc.pb': [2],
      }),
    ),
    'a split bundle by name': (
      'game.xapk',
      zipOf({
        'a.txt': [1],
      }),
    ),
  };

  installers.forEach((how, file) {
    testWidgets('an app $how is saved, never opened or shared', (t) async {
      final f = File('${tmp.path}/in_ab_${file.$1}')..writeAsBytesSync(file.$2);
      await tap(t, f.path, file.$1);
      expect(methods(), isNot(contains('openFile')));
      expect(methods(), isNot(contains('shareFile')));
      final save = asked.singleWhere((c) => c.method == 'saveDocument');
      final name = (save.arguments as Map)['name'] as String;
      expect(name, matches(RegExp(r'\.(apk|xapk)$', caseSensitive: false)));
      expect(name, isNot(contains('.jpg.')));
      expect(find.text(l10n.fileSavedIn('Download')), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('an app $how cannot be opened or shared directly', (t) async {
      final f = File('${tmp.path}/in_cd_${file.$1}')..writeAsBytesSync(file.$2);
      final r = await t.runAsync(
        () async => (
          await openWithAnotherApp(f.path, name: file.$1),
          await shareFileOut(f.path, name: file.$1),
        ),
      );
      expect(r!.$1, OpenAnswer.refused);
      expect(r.$2, ShareEnd.failed);
      expect(asked, isEmpty);
    });
  });

  // a 1x1 png: a real picture by its bytes, whatever its name says
  const png = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  Future<void> tapPicture(
    WidgetTester t,
    String path,
    String name, {
    bool kept = false,
  }) async {
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
    // the viewer stays up until it is closed, so the tap is not awaited
    await t.runAsync(() async {
      unawaited(openReceivedFile(ctx, path, name, kept: kept));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a picture sent as a file opens in the app, never outside', (
    t,
  ) async {
    final f = File('${tmp.path}/in_pq_photo_2a8a75ac.jpg')
      ..writeAsBytesSync(png);
    await tapPicture(t, f.path, 'photo_2a8a75ac.jpg');
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(methods(), isNot(contains('openFile')));
    expect(methods(), isNot(contains('shareFile')));
  });

  testWidgets('in a chat that blocks, a picture still opens in the app', (
    t,
  ) async {
    final f = File('${tmp.path}/in_rs_kept.png')..writeAsBytesSync(png);
    await tapPicture(t, f.path, 'kept.png', kept: true);
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.text(l10n.chatShotsKeptOpen), findsNothing);
    expect(methods(), isNot(contains('openFile')));
  });

  testWidgets('a pdf opens in another app, by its type', (t) async {
    final f = File('${tmp.path}/in_ef_scan.jpg')
      ..writeAsBytesSync('%PDF-1.7\n'.codeUnits);
    await tap(t, f.path, 'scan.jpg');
    final open = asked.singleWhere((c) => c.method == 'openFile');
    expect((open.arguments as Map)['mime'], 'application/pdf');
    expect(methods(), isNot(contains('saveDocument')));
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('one the native side refuses is saved, not shared', (t) async {
    openAnswer = 'refused';
    final f = File('${tmp.path}/in_gh_notes.docx')
      ..writeAsStringSync('nothing to see');
    await tap(t, f.path, 'notes.docx');
    expect(methods(), contains('openFile'));
    expect(methods(), isNot(contains('shareFile')));
    expect(methods(), contains('saveDocument'));
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('the sheet\'s save and share go where they say', (t) async {
    final f = File('${tmp.path}/in_kl_plan.pdf')
      ..writeAsBytesSync('%PDF-1.7\n'.codeUnits);
    fileSheetPickForTest = () => FileSheetPick.save;
    await tap(t, f.path, 'plan.pdf');
    expect(methods(), contains('saveDocument'));
    expect(methods(), isNot(contains('openFile')));
    asked.clear();
    fileSheetPickForTest = () => FileSheetPick.share;
    await tap(t, f.path, 'plan.pdf');
    expect(methods(), ['shareFile']);
    asked.clear();
    // closed with no pick: nothing leaves
    fileSheetPickForTest = () => null;
    await tap(t, f.path, 'plan.pdf');
    expect(methods(), isEmpty);
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('nothing that opens it falls back to share', (t) async {
    openAnswer = false;
    final f = File('${tmp.path}/in_ij_a.xyz')..writeAsStringSync('x');
    await tap(t, f.path, 'a.xyz');
    expect(methods(), containsAllInOrder(['openFile', 'shareFile']));
    await t.pump(const Duration(seconds: 10));
  });

  group('the native side', () {
    const main = 'android/app/src/main/kotlin/app/kryfo/MainActivity.kt';
    const tools = 'android/app/src/main/kotlin/app/kryfo/ToolsBridge.kt';

    test('only the open copy is viewed, and only once it is not an app', () {
      final all = [
        for (final f in Directory(
          'android/app/src/main/kotlin',
        ).listSync(recursive: true).whereType<File>())
          f.readAsStringSync(),
      ].join('\n');
      expect(all, isNot(contains('ACTION_INSTALL_PACKAGE')));
      expect(all, isNot(contains('PackageInstaller')));
      expect('ACTION_VIEW'.allMatches(all), hasLength(1));
      final open = bodyOf(sourceOf(main), 'private fun openFile(');
      expect(open, contains('Intent.ACTION_VIEW'));
      expect(
        open.indexOf('Installer.refused('),
        lessThan(open.indexOf('handOut(')),
      );
      expect(open, contains('"refused"'));
    });

    test('every share refuses an app', () {
      final share = bodyOf(sourceOf(main), 'private fun shareFile(');
      expect(
        share.indexOf('Installer.refused('),
        lessThan(share.indexOf('handOut(')),
      );
      final out = bodyOf(sourceOf(tools), 'private fun shareOut(');
      expect(
        out.indexOf('Installer.refused('),
        lessThan(out.indexOf('SharePick.start(')),
      );
      // the check reads the file, so not on the ui thread
      expect(
        out.indexOf('Thread {'),
        lessThan(out.indexOf('Installer.refused(')),
      );
      expect(out, contains('activity.runOnUiThread {'));
      // a check that throws shares nothing and still answers
      final guarded = out.substring(
        out.indexOf('val send = try {'),
        out.indexOf('activity.runOnUiThread {'),
      );
      expect(guarded, contains('Installer.refused('));
      expect(
        guarded,
        contains('} catch (e: Exception) {\n                null'),
      );
    });
  });

  group('no permission to install', () {
    test('the manifest takes it out of whatever a plugin merges in', () {
      final manifest = sourceOf('android/app/src/main/AndroidManifest.xml');
      for (final tag in ['uses-permission', 'uses-permission-sdk-23']) {
        expect(
          manifest,
          contains(
            '<$tag android:name="android.permission.'
            'REQUEST_INSTALL_PACKAGES" tools:node="remove" />',
          ),
          reason: tag,
        );
      }
      // the old name lint calls deprecated. the merger ignores
      // tools:node on it, so gradle's check is what stops it
      expect(manifest, isNot(contains('<uses-permission-sdk-m')));
    });

    test('gradle checks the merged manifest before every apk and bundle', () {
      final gradle = sourceOf('android/app/build.gradle.kts');
      expect(gradle, contains('abstract class NoInstallCheck'));
      expect(gradle, contains('"android.permission.REQUEST_INSTALL_PACKAGES"'));
      expect(
        gradle,
        contains('tasks.register<NoInstallCheck>("check\${name}NoInstall")'),
      );
      expect(gradle, contains('dependsOn(labelCheck, noInstall)'));
      expect(
        gradle,
        contains(
          'listOf("uses-permission", "uses-permission-sdk-23", '
          '"uses-permission-sdk-m")',
        ),
      );
    });
  });
}
