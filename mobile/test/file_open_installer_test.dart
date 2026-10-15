// SPDX-License-Identifier: GPL-3.0-or-later
// a received app installer is never handed to the package installer: no
// tap, menu or fallback opens or shares it. the only thing it offers is a
// save through the system save window, under a name ending in its real
// extension. the native side refuses it too, and asks for no permission
// to install. the platform is a stand-in that records every call
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/open_file.dart';
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

  tearDown(() {
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
      expect(r.$2, isFalse);
      expect(asked, isEmpty);
    });
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
    final f = File('${tmp.path}/in_gh_notes.txt')
      ..writeAsStringSync('nothing to see');
    await tap(t, f.path, 'notes.txt');
    expect(methods(), contains('openFile'));
    expect(methods(), isNot(contains('shareFile')));
    expect(methods(), contains('saveDocument'));
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
        lessThan(out.indexOf('startActivity(')),
      );
      // the check reads the file, so not on the ui thread
      expect(
        out.indexOf('Thread {'),
        lessThan(out.indexOf('Installer.refused(')),
      );
      expect(out, contains('activity.runOnUiThread {'));
    });
  });

  group('no permission to install', () {
    test('the manifest takes it out of whatever a plugin merges in', () {
      for (final tag in [
        'uses-permission',
        'uses-permission-sdk-23',
        'uses-permission-sdk-m',
      ]) {
        expect(
          sourceOf('android/app/src/main/AndroidManifest.xml'),
          contains(
            '<$tag android:name="android.permission.'
            'REQUEST_INSTALL_PACKAGES" tools:node="remove" />',
          ),
          reason: tag,
        );
      }
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
