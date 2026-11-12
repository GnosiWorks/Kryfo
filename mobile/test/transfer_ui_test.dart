// SPDX-License-Identifier: GPL-3.0-or-later
// the transfer screens: a waiting file's card and what its taps do, the
// strip's time left and its pause, the file sheet's picks, and the
// automatic download settings. each holds still when the phone asks for
// no movement
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/screens/auto_get_screen.dart';
import 'package:kryfo/transfers.dart';
import 'package:kryfo/widgets/file_sheet.dart';
import 'package:kryfo/widgets/file_wait.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _frame(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  setUp(() {
    fileWaits.value = const {};
    unmeteredNow = () async => false;
  });

  group('waiting card', () {
    Future<(List<String>, List<String>)> show(
      WidgetTester t,
      FileWait w, {
      String? name = 'plan.pdf',
      bool still = false,
    }) async {
      final gets = <String>[], pauses = <String>[];
      setFileWait('u1', w);
      await t.pumpWidget(
        _frame(
          FileWaitOr(
            uid: 'u1',
            fileName: name,
            onGet: gets.add,
            onPause: pauses.add,
            child: () => const Text('the file'),
          ),
          still: still,
        ),
      );
      await t.pumpAndSettle();
      return (gets, pauses);
    }

    testWidgets('a tap brings a file that waits', (t) async {
      final (gets, pauses) = await show(
        t,
        const FileWait(size: 2048, state: WaitState.asks, rule: AutoGet.wifi),
      );
      expect(find.text('plan'), findsOneWidget);
      expect(find.text('.pdf'), findsOneWidget);
      expect(find.text('2 KB · Downloads on Wi-Fi'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      await t.tap(find.byType(WaitingFileCard));
      expect(gets, ['u1']);
      expect(pauses, isEmpty);
    });

    testWidgets('a tap while it comes pauses it, a paused one goes on', (
      t,
    ) async {
      final (gets, pauses) = await show(
        t,
        const FileWait(
          size: 2048,
          state: WaitState.coming,
          rule: AutoGet.never,
          share: 0.5,
        ),
      );
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('Receiving · 1 KB of 2 KB'), findsOneWidget);
      await t.tap(find.byType(WaitingFileCard));
      expect(pauses, ['u1']);
      setFileWait('u1', fileWaitOf('u1')!.copyWith(state: WaitState.paused));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Paused · 1 KB of 2 KB'), findsOneWidget);
      await t.tap(find.byType(WaitingFileCard));
      expect(gets, ['u1']);
    });

    testWidgets('a photo says photo, and the file takes its place', (t) async {
      await show(
        t,
        const FileWait(size: 900, state: WaitState.asks, rule: AutoGet.never),
        name: null,
      );
      expect(find.text(l10n.appPhoto), findsOneWidget);
      expect(find.text('the file'), findsNothing);
      setFileWait('u1', null);
      await t.pumpAndSettle();
      expect(find.byType(WaitingFileCard), findsNothing);
      expect(find.text('the file'), findsOneWidget);
    });

    testWidgets('screen readers hear what it is and what a tap does', (
      t,
    ) async {
      final h = t.ensureSemantics();
      await show(
        t,
        const FileWait(size: 2048, state: WaitState.asks, rule: AutoGet.never),
      );
      expect(
        t.getSemantics(find.byType(WaitingFileCard)),
        matchesSemantics(
          label: 'plan.pdf, 2 KB · Tap to get it',
          hint: 'Download',
          isButton: true,
          hasTapAction: true,
        ),
      );
      h.dispose();
    });

    testWidgets('with no movement asked it changes in one frame', (t) async {
      await show(
        t,
        const FileWait(size: 2048, state: WaitState.asks, rule: AutoGet.never),
        still: true,
      );
      setFileWait(
        'u1',
        fileWaitOf('u1')!.copyWith(state: WaitState.coming, share: 0.5),
      );
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });

  group('strip', () {
    tearDown(() {
      incomingMediaDone('chat');
      mediaProgressEnd('s1');
    });

    // the quiet-transfer sweep is a timer of the app's own
    Future<void> settle(WidgetTester t) async {
      incomingMediaDone('chat');
      stopMediaSweeper();
      await t.pumpAndSettle();
    }

    testWidgets('says how much of how much and pauses a fetch', (t) async {
      final paused = <String>[];
      incomingMediaUpdate('chat', 1, 4, uid: 'f1', bytes: 4096);
      await t.pumpWidget(
        _frame(IncomingMediaBanner(chatKey: 'chat', onPause: paused.add)),
      );
      await t.pumpAndSettle();
      expect(find.text('Receiving · 1 KB of 4 KB'), findsOneWidget);
      await t.tap(find.text(l10n.transferPause));
      expect(paused, ['f1']);
      await settle(t);
    });

    testWidgets('a send has no pause, only its cancel', (t) async {
      final cancelled = <String>[];
      mediaProgressStart('s1', chatKey: 'chat', bytes: 4096);
      mediaProgressUpdate('s1', 0.5);
      await t.pumpWidget(
        _frame(
          IncomingMediaBanner(
            chatKey: 'chat',
            onCancel: cancelled.add,
            onPause: (_) => fail('a send is not paused'),
          ),
        ),
      );
      await t.pumpAndSettle();
      // ours says how far in a share, not bytes of bytes
      expect(find.text('Sending · 50%'), findsOneWidget);
      expect(find.text(l10n.transferPause), findsNothing);
      await t.tap(find.text(l10n.commonCancel));
      expect(cancelled, ['s1']);
    });

    testWidgets('slices with no file service have no pause', (t) async {
      incomingMediaUpdate('chat', 3, 10);
      await t.pumpWidget(
        _frame(IncomingMediaBanner(chatKey: 'chat', onPause: (_) {})),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.transferPause), findsNothing);
      expect(find.textContaining('Receiving · '), findsOneWidget);
      await settle(t);
    });

    testWidgets('grows out of nothing and goes back', (t) async {
      await t.pumpWidget(_frame(const IncomingMediaBanner(chatKey: 'chat')));
      final none = t.getSize(find.byType(IncomingMediaBanner)).height;
      expect(none, 0);
      incomingMediaUpdate('chat', 1, 4, uid: 'f1', bytes: 4096);
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final half = t.getSize(find.byType(IncomingMediaBanner)).height;
      await t.pumpAndSettle();
      final full = t.getSize(find.byType(IncomingMediaBanner)).height;
      expect(half, lessThan(full));
      await settle(t);
      expect(t.getSize(find.byType(IncomingMediaBanner)).height, 0);
    });
  });

  group('file sheet', () {
    test('an app installer only saves', () {
      const apk = FileFacts(FileKind.installer, 'apk');
      expect(fileSheetPicks(apk), [FileSheetPick.save]);
      const pdf = FileFacts(FileKind.pdf, 'pdf');
      expect(fileSheetPicks(pdf), [
        FileSheetPick.open,
        FileSheetPick.save,
        FileSheetPick.share,
      ]);
    });

    testWidgets('says what the file is and answers the pick', (t) async {
      final dir = Directory.systemTemp.createTempSync('file_sheet');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/x_plan.pdf')
        ..writeAsBytesSync(List.filled(3000, 1));
      FileSheetPick? picked;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                picked = await showFileSheet(
                  c,
                  path: f.path,
                  name: 'plan.pdf',
                  facts: const FileFacts(FileKind.pdf, 'pdf'),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.runAsync(() async {
        await t.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pumpAndSettle();
      expect(find.text('plan.pdf'), findsOneWidget);
      expect(find.text('PDF · 3 KB'), findsOneWidget);
      expect(find.text(l10n.fileOpenWith), findsOneWidget);
      expect(find.text(l10n.fileOpenWithNote), findsOneWidget);
      await t.tap(find.text(l10n.fileSaveToDevice));
      await t.pumpAndSettle();
      // the answer lands on the zone the sheet was opened from
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(picked, FileSheetPick.save);
    });
  });

  group('automatic download settings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows each kind and keeps a new pick', (t) async {
      await t.pumpWidget(const MaterialApp(home: AutoGetScreen()));
      await t.pumpAndSettle();
      expect(find.text(l10n.autoGetPhotos), findsOneWidget);
      expect(find.text(l10n.autoGetAlways), findsOneWidget);
      expect(find.text(l10n.autoGetWifi), findsOneWidget);
      // a file is no choice: it always waits for a tap
      expect(find.text(l10n.autoGetFiles), findsNothing);
      expect(
        find.text('${l10n.autoGetVoice} ${l10n.autoGetFilesWait}'),
        findsOneWidget,
      );
      await t.tap(find.text(l10n.autoGetVideos));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.autoGetNever).last);
      await t.pumpAndSettle();
      expect(find.text(l10n.autoGetNever), findsOneWidget);
      expect(
        (await loadAutoGet(HaloContainer.everyday))[GetKind.video],
        AutoGet.never,
      );
    });
  });
}
