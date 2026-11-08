// SPDX-License-Identifier: GPL-3.0-or-later
// the tools on a computer: the tab and each tool's page, pixel for pixel,
// with a computer's ways out (send to a chat, save where picked, copy
// picture) in place of the share sheet, and the person's own file read
// where it is and never shred
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/clean_screen.dart';
import 'package:kryfo/screens/lock_file_screen.dart';
import 'package:kryfo/screens/open_locked_screen.dart';
import 'package:kryfo/screens/photo_knows_screen.dart';
import 'package:kryfo/screens/qr_screen.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/tools/cleaner.dart' show CleanFailure;
import 'package:kryfo/tools/desk_tools.dart';
import 'package:kryfo/tools/tools_bridge.dart';
import 'package:path/path.dart' as p;

import '../photo_tool_flow_test.dart' show framed, settle;

const _pane = Size(620, 860);

void _desk(WidgetTester t) {
  onDesktop = true;
  addTearDown(() => onDesktop = false);
  lockState.openForTest();
  t.view.physicalSize = _pane;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

// the person's file, where it is: the desktop's copyIn gives its own path
Directory _home(WidgetTester t) {
  final root = Directory.systemTemp.createTempSync('desk_tools_home');
  final cache = Directory.systemTemp.createTempSync('desk_tools_cache');
  addTearDown(() {
    for (final d in [root, cache]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });
  final m = t.binding.defaultBinaryMessenger;
  const tools = MethodChannel('halo/tools');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  m.setMockMethodCallHandler(tools, (c) async {
    if (c.method == 'copyIn') return (c.arguments as Map)['uri'];
    return null;
  });
  m.setMockMethodCallHandler(paths, (_) async => cache.path);
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() {
    m.setMockMethodCallHandler(tools, null);
    m.setMockMethodCallHandler(paths, null);
    m.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return root;
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('the tools tab on a computer', (t) async {
    _desk(t);
    await t.pumpWidget(
      framed(
        Scaffold(
          body: DeskToolsIn(onFile: (_) {}, child: const ToolsScreen()),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 3));
    expect(find.text(l10n.toolsEverythingHereHappensOnDesk), findsOneWidget);
    expect(find.text(l10n.toolsPickAPhotoAndDesk), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_tools_tab.png'),
    );
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('a photo read in place, cleaned, with a computer\'s ways out', (
    t,
  ) async {
    _desk(t);
    final home = _home(t);
    final photo = File(p.join(home.path, 'IMG_1.jpg'))
      ..writeAsBytesSync(
        File('test/fixtures/gallery_gps.jpg').readAsBytesSync(),
      );
    final file = deskPicked(photo.path)!;
    await t.pumpWidget(framed(PhotoKnowsScreen(file: file)));
    await settle(t, find.text(l10n.photoKnowsRemoveAllOfIt));
    expect(find.textContaining('WENT NOWHERE'), findsNothing);
    await t.tap(find.text(l10n.photoKnowsRemoveAllOfIt));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await settle(t, find.text(l10n.toolsSendToAChat));
    await t.pump(const Duration(seconds: 2));
    expect(find.text(l10n.cleanSaveToGalleryDesk), findsOneWidget);
    expect(find.text(l10n.toolsCopyPicture), findsOneWidget);
    expect(find.text(l10n.cleanShareCleanCopy), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_clean_done.png'),
    );
    await _end(t);
    // the original is the person's: read, never shred or moved
    expect(
      photo.readAsBytesSync(),
      File('test/fixtures/gallery_gps.jpg').readAsBytesSync(),
    );
  });

  testWidgets('a picture the computer cannot clean yet says so plainly', (
    t,
  ) async {
    onDesktop = true;
    addTearDown(() => onDesktop = false);
    for (final f in [
      CleanFailure.notClean,
      CleanFailure.motion,
      CleanFailure.unreadable,
    ]) {
      expect(failureTitle(f), l10n.cleanNotYetHere);
      expect(failureBody(f), l10n.cleanNotYetHereLine);
      // a video is never drawn: its own line
      expect(failureTitle(f, video: true), isNot(l10n.cleanNotYetHere));
    }
    expect(failureTitle(CleanFailure.unknownKind), l10n.cleanKryfoCanTClean);
    onDesktop = false;
    expect(failureTitle(CleanFailure.notClean), l10n.cleanKryfoCouldNotMake);
  });

  testWidgets('the private qr on a computer', (t) async {
    _desk(t);
    await t.pumpWidget(framed(const QrScreen()));
    await t.pump(const Duration(seconds: 2));
    expect(find.text(l10n.toolsSendToAChat), findsOneWidget);
    expect(find.text(l10n.toolsCopyPicture), findsOneWidget);
    expect(find.text(l10n.commonShare), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_qr.png'),
    );
    await _end(t);
  });

  testWidgets('lock a file on a computer', (t) async {
    _desk(t);
    await t.pumpWidget(
      framed(
        const LockFileScreen(
          file: PickedFile(
            uri: '/home/someone/plan.pdf',
            name: 'plan.pdf',
            size: 52000,
            inPlace: true,
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 2));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_lock_file.png'),
    );
    await _end(t);
  });

  testWidgets('open a locked file on a computer', (t) async {
    _desk(t);
    await t.pumpWidget(
      framed(
        const OpenLockedScreen(
          file: PickedFile(
            uri: '/home/someone/plan.pdf.age',
            name: 'plan.pdf.age',
            size: 52300,
            inPlace: true,
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 2));
    expect(find.text(l10n.openLockedItOpensOnThisDesk), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desk_open_locked.png'),
    );
    await _end(t);
  });

  testWidgets('a tool page goes when the app locks', (t) async {
    _desk(t);
    await t.pumpWidget(
      framed(
        Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(
              c,
            ).push(MaterialPageRoute<void>(builder: (_) => const QrScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(QrScreen), findsOneWidget);
    lockState.openForTest(enabled: true);
    lockState.lock();
    await t.pumpAndSettle();
    expect(find.byType(QrScreen), findsNothing);
    lockState.openForTest();
  });

  testWidgets('one dropped file that is no photo asks before it locks', (
    t,
  ) async {
    _desk(t);
    bool? said;
    await t.pumpWidget(
      framed(
        Builder(
          builder: (c) => TextButton(
            onPressed: () async => said = await askLockThisFile(c, 'plan.pdf'),
            child: const Text('drop'),
          ),
        ),
      ),
    );
    await t.tap(find.text('drop'));
    await t.pumpAndSettle();
    expect(find.text('plan.pdf'), findsOneWidget);
    expect(find.text(l10n.toolsLockThisFileLine), findsOneWidget);
    await t.tap(find.text(l10n.toolsLockThisFile));
    await t.pumpAndSettle();
    expect(said, isTrue);
  });
}
