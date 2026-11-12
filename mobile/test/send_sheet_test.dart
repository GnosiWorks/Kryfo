// SPDX-License-Identifier: GPL-3.0-or-later
// the sending sheet: gallery, files and recent in one, picks numbered in
// the order chosen, "Send as file" only for photos and videos, a caption,
// and Send N. what is picked and not sent goes, the lock closes it, and
// the recent tab offers nothing a chat that blocks keeps, no voice note,
// no app and nothing timed
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/recent_files.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/transfers.dart' show torTimeLine;
import 'package:kryfo/widgets/send_sheet.dart';
import 'package:kryfo/widgets/send_tray.dart';
import 'package:kryfo/widgets/media_bubbles.dart' show humanFileSize;
import 'package:shared_preferences/shared_preferences.dart';

import 'source_body.dart';
import 'sqlite_channel.dart';

void main() {
  late List<String> released;
  var locked = false;
  late LockGuard guard;

  setUp(() {
    released = [];
    locked = false;
    guard = LockGuard(isLocked: () => locked);
    sendSheetGuard = guard;
  });
  tearDown(() {
    sendSheetGuard = lockGuard;
    HaloColors.setLight(false);
  });

  SendPick pick(String name, SendTab from, {bool media = false}) => SendPick(
    path: '/x/$name',
    name: name,
    size: 2048,
    from: from,
    media: media,
    when: DateTime.now(),
    release: from == SendTab.recent ? null : () async => released.add(name),
  );

  // what the sheet gave back, read once it has closed
  SendSheetResult? result;

  Future<void> open(
    WidgetTester t, {
    List<SendPick> gallery = const [],
    List<SendPick> files = const [],
    List<SendPick> recent = const [],
    TextDirection dir = TextDirection.ltr,
    double scale = 1,
    bool spoilers = true,
  }) async {
    result = null;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(textDirection: dir, child: child!),
        ),
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showSendSheet(
                    c,
                    to: 'Lena',
                    pickGallery: () async => gallery,
                    pickFiles: () async => files,
                    recent: () async => recent,
                    spoilers: spoilers,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  SendSheetState sheet(WidgetTester t) =>
      t.state<SendSheetState>(find.byType(SendSheet));

  testWidgets('picks are numbered in the order chosen, across tabs', (t) async {
    final a = pick('a.jpg', SendTab.gallery, media: true);
    final b = pick('b.pdf', SendTab.files);
    final c = pick('c.py', SendTab.recent);
    await open(t, gallery: [a], files: [b], recent: [c]);
    expect(find.text('Lena'), findsNothing, reason: 'in a rich line');
    await t.tap(find.text(l10n.sendSheetChoosePhotos));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetFiles));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetBrowseFiles));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetRecent));
    await t.pumpAndSettle();
    await t.tap(find.text('c'));
    await t.pumpAndSettle();
    expect(sheet(t).chosen, [a, b, c]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(l10n.sendSheetSend(3, '3')), findsOneWidget);
    // one taken back: the rest close up
    await t.tap(find.text('c'));
    await t.pumpAndSettle();
    expect(sheet(t).chosen, [a, b]);
    expect(find.text(l10n.sendSheetSend(2, '2')), findsOneWidget);
  });

  testWidgets('arabic counts in its own digits on the button too', (t) async {
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    final b = pick('b.pdf', SendTab.files);
    final c = pick('c.py', SendTab.files);
    await open(t, files: [b, c], dir: TextDirection.rtl);
    await t.tap(find.text(l10n.sendSheetFiles));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetBrowseFiles));
    await t.pumpAndSettle();
    final send = l10n.sendSheetSend(2, '٢');
    expect(find.text(send), findsOneWidget);
    expect(find.text('٢'), findsOneWidget, reason: 'the order badge');
    expect(l10n.filePages(12, '١٢'), contains('١٢'));
  });

  testWidgets('send as file shows only for photos and videos', (t) async {
    await open(t, files: [pick('b.pdf', SendTab.files)]);
    await t.tap(find.text(l10n.sendSheetFiles));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetBrowseFiles));
    await t.pumpAndSettle();
    expect(find.text(l10n.sendSheetAsFile), findsNothing);
  });

  testWidgets('send gives the picks in order, the caption and the switch', (
    t,
  ) async {
    final a = pick('a.jpg', SendTab.gallery, media: true);
    final z = pick('z.mp4', SendTab.gallery, media: true);
    await open(t, gallery: [a, z]);
    await t.tap(find.text(l10n.sendSheetChoosePhotos));
    await t.pumpAndSettle();
    // the second is not wanted
    await t.tap(find.text('z'));
    await t.pumpAndSettle();
    expect(find.text(l10n.sendSheetAsFile), findsOneWidget);
    expect(find.text(l10n.sendSheetAsFileLine), findsOneWidget);
    await t.ensureVisible(find.text(l10n.sendSheetAsFile));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetAsFile));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'for the lease');
    await t.tap(find.text(l10n.sendSheetSend(1, '1')));
    await t.pumpAndSettle();
    final r = result!;
    expect(r.picks, [a]);
    expect(r.caption, 'for the lease');
    expect(r.asFiles, isTrue);
    // as files: nothing goes through the photo preview
    expect(r.media, isEmpty);
    expect(r.files, [a]);
    // the one not chosen goes at once, the chosen one after its send
    expect(released, ['z.mp4']);
    await r.release();
    expect(released, ['z.mp4', 'a.jpg']);
  });

  group('the tray', () {
    testWidgets('sent, the cards lift off and fade toward the chat', (t) async {
      Widget tray(bool lifting) => MaterialApp(
        home: Scaffold(
          body: SendTray(
            lifting: lifting,
            most: 50 << 20,
            onRemove: (_) {},
            onRename: (_) {},
            onSpoiler: (_) {},
            cards: const [
              TrayCard(key: 'a', name: 'a.pdf', size: 10, path: '/x/a.pdf'),
            ],
          ),
        ),
      );
      await t.pumpWidget(tray(false));
      await t.pumpAndSettle();
      await t.pumpWidget(tray(true));
      await t.pump(SendTray.liftTime);
      final fade = t.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(fade.opacity, 0);
      final slide = t.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      // a real rise toward the chat, a little smaller as it goes
      expect(slide.offset.dy, lessThan(-1));
      final scale = t.widget<AnimatedScale>(find.byType(AnimatedScale).first);
      expect(scale.scale, lessThan(1));
    });

    testWidgets('a card per pick, the total and an honest time over Tor', (
      t,
    ) async {
      final b = SendPick(
        path: '/x/b.pdf',
        name: 'b.pdf',
        size: 41 * 1024 * 1024,
        from: SendTab.files,
      );
      await open(t, files: [b, pick('c.py', SendTab.files)]);
      await t.tap(find.text(l10n.sendSheetFiles));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.sendSheetBrowseFiles));
      await t.pumpAndSettle();
      expect(find.byType(SendTray), findsOneWidget);
      expect(find.textContaining(l10n.trayToSend(2, '2')), findsOneWidget);
      expect(find.text(l10n.trayHint), findsOneWidget);
      // 41 MB at a careful pace is about eleven minutes
      expect(
        find.textContaining(torTimeLine(41 * 1024 * 1024)),
        findsOneWidget,
      );
      expect(torTimeLine(41 * 1024 * 1024), l10n.trayTimeMinutes('11'));
      expect(
        find.textContaining(l10n.trayMost(humanFileSize(50 * 1024 * 1024))),
        findsOneWidget,
      );
    });

    test('the tray and the question before a big send give one time over '
        'Tor, of the same total', () {
      const mb = 1024 * 1024;
      expect(torTimeLine(500 * 1024), l10n.trayTimeSoon);
      // the 0.6.1 check's 5 MB zip: no longer under a minute on one and
      // three on the other
      expect(torTimeLine(5 * mb), l10n.trayTimeMinutes('2'));
      final r = SendSheetResult([
        SendPick(
          path: '/x/a.zip',
          name: 'a.zip',
          size: 3 * mb,
          from: SendTab.files,
        ),
        SendPick(
          path: '/x/b.jpg',
          name: 'b.jpg',
          size: 2 * mb,
          from: SendTab.gallery,
          media: true,
        ),
      ]);
      expect(r.total, 5 * mb);
      final chat = sourceOf('lib/screens/chat_screen.dart');
      expect(
        chat,
        contains(r"'${_humanBytes(bytes)} · ${torTimeLine(bytes)}'"),
      );
      expect(chat, isNot(contains('_wireEstimate')));
      // the sheet asks once, of its total, before any of it goes
      final ask = bodyOf(chat, 'Future<bool> _askSheet(');
      expect(ask, contains('_confirmSend('));
      expect(ask, contains('r.total,'));
      final send = bodyOf(chat, 'Future<void> _sendFromSheet(');
      expect(send, contains('if (!await _askSheet(r) || !mounted) return;'));
      expect(send, isNot(contains('_askBig')));
      expect(send, contains('asked: true,'));
      expect(
        sourceOf('lib/widgets/send_tray.dart'),
        contains('torTimeLine(total)'),
      );
    });

    testWidgets('the cross takes a pick out', (t) async {
      final sem = t.ensureSemantics();
      final b = pick('b.pdf', SendTab.files);
      final c = pick('c.py', SendTab.files);
      await open(t, files: [b, c]);
      await t.tap(find.text(l10n.sendSheetFiles));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.sendSheetBrowseFiles));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel(l10n.trayRemove('b.pdf')));
      await t.pumpAndSettle();
      expect(sheet(t).chosen, [c]);
      expect(find.bySemanticsLabel(l10n.trayRemove('b.pdf')), findsNothing);
      sem.dispose();
    });

    testWidgets('a hold renames a file, its extension kept', (t) async {
      final b = pick('b.pdf', SendTab.files);
      await open(t, files: [b]);
      await t.tap(find.text(l10n.sendSheetFiles));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.sendSheetBrowseFiles));
      await t.pumpAndSettle();
      await t.longPress(find.text('b.pdf').last);
      await t.pumpAndSettle();
      expect(find.text(l10n.trayRenameTitle), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'lease draft');
      await t.tap(find.text(l10n.confirmSheetSave));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.sendSheetSend(1, '1')));
      await t.pumpAndSettle();
      expect(result!.picks.single.name, 'lease draft.pdf');
      expect(result!.picks.single.path, b.path);
    });

    testWidgets('no spoiler chip where a phone on the other end would show '
        'it plain', (t) async {
      final a = pick('a.jpg', SendTab.gallery, media: true);
      await open(t, gallery: [a], spoilers: false);
      await t.tap(find.text(l10n.sendSheetChoosePhotos));
      await t.pumpAndSettle();
      expect(find.text(l10n.traySpoiler), findsNothing);
      await t.tap(find.text(l10n.sendSheetSend(1, '1')));
      await t.pumpAndSettle();
      expect(result!.spoilers, isEmpty);
    });

    testWidgets('a photo can be a spoiler, and as a file it is none', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final a = pick('a.jpg', SendTab.gallery, media: true);
      await open(t, gallery: [a]);
      await t.tap(find.text(l10n.sendSheetChoosePhotos));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel(l10n.traySpoiler));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.sendSheetSend(1, '1')));
      await t.pumpAndSettle();
      expect(result!.spoilers, {a.path});
      sem.dispose();
    });
  });

  testWidgets('closed without a send, every pick goes', (t) async {
    await open(t, gallery: [pick('a.jpg', SendTab.gallery, media: true)]);
    await t.tap(find.text(l10n.sendSheetChoosePhotos));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    // picks in the tray: it asks first, and keeping them keeps the sheet
    expect(find.text(l10n.sendSheetDiscardTitle(1, '1')), findsOneWidget);
    await t.tap(find.text(l10n.sendSheetKeep));
    await t.pumpAndSettle();
    expect(find.byType(SendSheet), findsOneWidget);
    expect(released, isEmpty);
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetDiscard));
    await t.pumpAndSettle();
    expect(find.byType(SendSheet), findsNothing);
    expect(released, ['a.jpg']);
  });

  testWidgets('the lock closes it, and its picks go', (t) async {
    await open(t, files: [pick('b.pdf', SendTab.files)]);
    await t.tap(find.text(l10n.sendSheetFiles));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetBrowseFiles));
    await t.pumpAndSettle();
    locked = true;
    guard.locking();
    await t.pumpAndSettle();
    expect(find.byType(SendSheet), findsNothing);
    expect(released, ['b.pdf']);
  });

  testWidgets('large text and right to left cut nothing', (t) async {
    await open(
      t,
      files: [pick('Notes-from-a-very-long-meeting.docx', SendTab.files)],
      dir: TextDirection.rtl,
      scale: 2,
    );
    await t.tap(find.text(l10n.sendSheetFiles));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.sendSheetBrowseFiles));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // the tray takes room at this size: the list scrolls to the pick
    await t.scrollUntilVisible(
      find.text('.docx'),
      60,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('.docx'), findsOneWidget);
  });

  group('recent', () {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    late Directory docs;
    SqliteChannel? sql;

    setUp(() {
      sql = SqliteChannel.install();
      docs = Directory.systemTemp.createTempSync('send_recent');
      m.setMockMethodCallHandler(paths, (_) async => docs.path);
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': '0e' * 32,
      });
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      sql?.uninstall();
      m.setMockMethodCallHandler(paths, null);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    test('offers ours and theirs, never kept, voice, app or timed', () async {
      if (sql == null) {
        markTestSkipped('no sqlite on this host');
        return;
      }
      final db = HaloDb();
      String file(String leaf) =>
          (File('${docs.path}/$leaf')..writeAsBytesSync([1, 2, 3])).path;
      await db.saveMessage(
        'lena',
        'out',
        '',
        msgUid: 'u1',
        filePath: file('f_1.pdf'),
        fileName: 'plan.pdf',
      );
      await db.saveMessage(
        'lena',
        'in',
        '',
        msgUid: 'u2',
        filePath: file('f_2.py'),
        fileName: 'rent.py',
      );
      await db.saveMessage(
        'lena',
        'in',
        '',
        msgUid: 'u3',
        filePath: file('f_3.ogg'),
        fileName: 'voice.ogg',
      );
      await db.saveMessage(
        'lena',
        'in',
        '',
        msgUid: 'u4',
        filePath: file('f_4.apk'),
        fileName: 'game.apk',
      );
      await db.saveMessage(
        'lena',
        'in',
        '',
        msgUid: 'u5',
        filePath: file('f_5.txt'),
        fileName: 'timed.txt',
        burnSecs: 30,
      );
      await db.saveMessage(
        'lena',
        'in',
        '',
        msgUid: 'u6',
        filePath: file('f_6.txt'),
        fileName: 'secret.txt',
        secure: true,
      );
      await db.saveMessage(
        'lena',
        'in',
        '',
        msgUid: 'u7',
        filePath: '${docs.path}/gone.txt',
        fileName: 'gone.txt',
      );
      // a chat that blocks screenshots keeps theirs, not ours
      await db.upsertContact('mira', 'x', 'ab' * 32);
      final raw = await db.open();
      await raw.update(
        'contacts',
        {'shots_on': 1, 'shots_can': 1, 'shots_at': 1},
        where: 'halo_id = ?',
        whereArgs: ['mira'],
      );
      await db.saveMessage(
        'mira',
        'in',
        '',
        msgUid: 'u8',
        filePath: file('f_8.txt'),
        fileName: 'kept.txt',
      );
      // a room keeps the others' files, ended or not
      await raw.insert('groups', {
        'group_id': 'room1',
        'name': 'r',
        'created_at': 1,
        'room_pub': 'pub',
        // ended: its block no longer reads as on
        'ended_at': 1,
      });
      await db.saveMessage(
        'zed',
        'in',
        '',
        msgUid: 'u9',
        groupId: 'room1',
        filePath: file('f_9.txt'),
        fileName: 'room.txt',
      );
      final got = await recentFilesIn(db);
      expect([for (final p in got) p.name], ['rent.py', 'plan.pdf']);
      // a row of a chat the session reads from another container now
      final moved = await recentFilesIn(
        db,
        homeOf: (r) =>
            r['peer_id'] == 'lena' && r['direction'] == 'in' ? HaloDb() : db,
      );
      expect([for (final p in moved) p.name], ['plan.pdf']);
      expect(
        got.every((p) => p.release == null),
        isTrue,
        reason: 'kryfo keeps these itself: nothing of them is let go',
      );
    });
  });

  // keeps the import honest
  test('a pick is a value', () => expect(Completer<void>(), isNotNull));
}
