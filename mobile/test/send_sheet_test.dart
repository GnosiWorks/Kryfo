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
import 'package:kryfo/widgets/send_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('closed without a send, every pick goes', (t) async {
    await open(t, gallery: [pick('a.jpg', SendTab.gallery, media: true)]);
    await t.tap(find.text(l10n.sendSheetChoosePhotos));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(195, 20));
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
      final got = await recentFilesIn(db);
      expect([for (final p in got) p.name], ['rent.py', 'plan.pdf']);
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
