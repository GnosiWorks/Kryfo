// SPDX-License-Identifier: GPL-3.0-or-later
// the shared page: a chat's rows sorted into photos, files, voice messages
// and links, each list by month, a file still to come with its ring, a tap
// that opens kryfo's own viewer, and the contact page's rows that lead there
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/dates.dart' show monthMaybeYear;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/transfers.dart';
import 'package:kryfo/widgets/file_wait.dart' show FileWaitMark;
import 'package:kryfo/widgets/shared_media.dart';
import 'package:kryfo/widgets/shared_files.dart';
import 'package:kryfo/show_in_chat.dart';
import 'package:kryfo/widgets/text_viewer.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'source_body.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('shared_files');
    lockState.openForTest();
    openPictures();
  });
  tearDown(() {
    fileWaits.value = const {};
    tmp.deleteSync(recursive: true);
  });

  final t0 = DateTime(2025, 11, 9, 14, 2).millisecondsSinceEpoch;
  const day = 86400000;

  Map<String, Object?> row(
    int id, {
    String? media,
    String? file,
    String? name,
    String text = '',
    String dir = 'in',
    String? uid,
    String? peer,
    int? at,
    String? preview,
    int secure = 0,
  }) => {
    'id': id,
    'media_path': media,
    'file_path': file,
    'file_name': name,
    'plaintext': text,
    'direction': dir,
    'msg_uid': uid ?? 'u$id',
    'peer_id': peer,
    'sent_at': at ?? t0 - id * day,
    'preview': preview,
    'secure': secure,
  };

  group('sorting', () {
    test('each row lands in its list, newest first', () {
      final s = sortShared([
        row(1, media: '/m/a.jpg', secure: 1),
        row(2, file: '/f/lease.pdf', name: 'lease.pdf'),
        row(3, file: '/f/voice.m4a', name: 'voice_1.m4a'),
        row(4, file: '/v/v.wav', name: 'voice.wav'),
        row(
          5,
          text: 'see https://example.org/x.',
          preview: '{"url":"https://example.org/x","title":"The page"}',
        ),
        row(6, text: 'no link here'),
        // a caption with a link: a file and a link
        row(7, file: '/f/a.zip', name: 'a.zip', text: 'http://b.example'),
      ], waiting: (_) => false);
      expect([for (final m in s.media) m.path], ['/m/a.jpg']);
      expect(s.media.single.secure, isTrue);
      expect(
        [for (final f in s.files) f.name],
        ['lease.pdf', 'voice_1.m4a', 'a.zip'],
      );
      expect([for (final v in s.voice) v.path], ['/v/v.wav']);
      expect(
        [for (final l in s.links) l.url],
        ['https://example.org/x', 'http://b.example'],
      );
      expect(s.links.first.title, 'The page');
      expect(s.links.last.title, isNull);
    });

    test('a file still to come is listed, a voice note or photo is not', () {
      final s = sortShared([
        row(1, name: 'notes.docx', uid: 'w1'),
        row(2, name: 'voice.wav', uid: 'w2'),
        row(3, media: '/m/b.jpg', uid: 'w3'),
        // one neither here nor coming: nothing to show
        row(4, name: 'gone.pdf', uid: 'w4'),
      ], waiting: (u) => const {'w1', 'w2', 'w3'}.contains(u));
      expect(s.files, hasLength(1));
      expect(s.files.single.path, isNull);
      expect(s.files.single.uid, 'w1');
      expect(s.voice, isEmpty);
      expect(s.media, isEmpty);
    });

    test('a video from the gallery is media, as the chat draws it', () {
      final s = sortShared([
        row(1, media: '/m/a.jpg'),
        row(2, file: '/f/v1.mp4', name: 'video_ed9dcc06.mp4'),
        row(3, file: '/f/v2.mov', name: 'trip.MOV'),
        row(4, file: '/f/lease.pdf', name: 'lease.pdf'),
        // one still to come waits with the files, where its ring is
        row(5, name: 'video_d4b932b8.mp4', uid: 'w5'),
      ], waiting: (u) => u == 'w5');
      expect(
        [for (final m in s.media) m.path],
        ['/m/a.jpg', '/f/v1.mp4', '/f/v2.mov'],
      );
      expect([for (final m in s.media) m.video], [false, true, true]);
      expect(s.videos, {'/f/v1.mp4', '/f/v2.mov'});
      expect(
        [for (final f in s.files) f.name],
        ['lease.pdf', 'video_d4b932b8.mp4'],
      );
    });

    test('a blocked member and a timed one not read yet stay out', () {
      final s = sortShared(
        [
          row(1, file: '/f/a.pdf', name: 'a.pdf', peer: 'bad'),
          {
            ...row(2, file: '/f/b.pdf', name: 'b.pdf'),
            'burn_secs': 30,
            'burn_unseen': 1,
          },
          row(3, file: '/f/c.pdf', name: 'c.pdf', peer: 'good'),
        ],
        blocked: {'bad'},
        waiting: (_) => false,
      );
      expect([for (final f in s.files) f.name], ['c.pdf']);
    });

    test('a chat\'s rows come from three narrow reads, newest first', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      final d = await db.open();
      Future<void> put(Map<String, Object?> r) => d.insert('messages', {
        'peer_id': 'p',
        'direction': r['direction'],
        'plaintext': r['plaintext'],
        'sent_at': r['sent_at'],
        'msg_uid': r['msg_uid'],
        'media_path': r['media_path'],
        'file_path': r['file_path'],
        'file_name': r['file_name'],
      });
      await put(row(9, media: '/m/old.jpg'));
      await put(row(8, text: 'plain words'));
      await put(row(7, file: '/f/x.pdf', name: 'x.pdf'));
      await put(row(6, text: 'look https://kryfo.app'));
      await put(row(5, file: '/f/x.pdf', name: 'x.pdf', text: 'https://a.b'));
      final rows = await db.mediaFor('p');
      expect([for (final r in rows) r['msg_uid']], ['u5', 'u6', 'u7', 'u9']);
      final s = sortShared(rows, waiting: (_) => false);
      expect(s.files, hasLength(2));
      expect(s.links, hasLength(2));
      expect(s.media, hasLength(1));
    });
  });

  group('the page', () {
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 20; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 500));
    }

    Future<void> open(
      WidgetTester t,
      SharedLists lists, {
      SharedTab start = SharedTab.files,
      bool still = false,
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: SharedScreen(
            chatId: 'p',
            title: 'Lena',
            start: start,
            load: () async => lists,
          ),
        ),
      );
      await settle(t);
    }

    SharedItem file(String name, DateTime when, {String? path, String? uid}) =>
        SharedItem(path: path, name: name, when: when, uid: uid);

    testWidgets('files by month, the newest month first', (t) async {
      final a = DateTime(2025, 11, 9);
      final b = DateTime(2025, 10, 19);
      await open(
        t,
        SharedLists(
          files: [
            file('Lease-draft.pdf', a, path: '/f/1'),
            file('rent.py', a, path: '/f/2'),
            file('Hike-costs.xlsx', b, path: '/f/3'),
          ],
        ),
      );
      final nov = monthMaybeYear(a).toUpperCase();
      final oct = monthMaybeYear(b).toUpperCase();
      expect(find.text(nov), findsOneWidget);
      expect(find.text(oct), findsOneWidget);
      expect(
        t.getTopLeft(find.text(nov)).dy,
        lessThan(t.getTopLeft(find.text('Lease-draft')).dy),
      );
      expect(
        t.getTopLeft(find.text('rent')).dy,
        lessThan(t.getTopLeft(find.text(oct)).dy),
      );
      expect(
        t.getTopLeft(find.text(oct)).dy,
        lessThan(t.getTopLeft(find.text('Hike-costs')).dy),
      );
    });

    testWidgets('the tabs move the pages, and a swipe moves the tab', (
      t,
    ) async {
      final when = DateTime(2025, 11, 9);
      await open(
        t,
        SharedLists(
          files: [file('a.pdf', when, path: '/f/a')],
          links: [SharedItem(url: 'https://kryfo.app/x', when: when)],
        ),
      );
      final page = t.state<SharedScreenState>(find.byType(SharedScreen));
      expect(page.tab, SharedTab.files);
      await t.tap(find.text(l10n.sharedTabLinks));
      // the slide passes the voice page without the tab stopping there
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 20));
        expect(page.tab, SharedTab.links);
      }
      await t.pumpAndSettle();
      expect(page.tab, SharedTab.links);
      expect(find.text('kryfo.app'), findsOneWidget);
      expect(find.text('https://kryfo.app/x'), findsOneWidget);
      await t.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await t.pumpAndSettle();
      expect(page.tab, SharedTab.voice);
      expect(find.text(l10n.sharedNoVoice), findsOneWidget);
    });

    testWidgets('with reduced motion the page jumps', (t) async {
      final when = DateTime(2025, 11, 9);
      await open(
        t,
        SharedLists(files: [file('a.pdf', when, path: '/f/a')]),
        still: true,
      );
      await t.tap(find.text(l10n.sharedTabMedia));
      await t.pump();
      expect(find.text(l10n.sharedNoPhotos), findsOneWidget);
    });

    testWidgets('a video shows in the media grid as a video', (t) async {
      final when = DateTime(2025, 11, 9);
      await open(
        t,
        SharedLists(
          media: [
            SharedItem(
              path: '/f/v.mp4',
              name: 'video_ed9dcc06.mp4',
              when: when,
              video: true,
            ),
          ],
        ),
        start: SharedTab.media,
      );
      expect(find.text(l10n.sharedNoPhotos), findsNothing);
      expect(find.bySemanticsLabel(l10n.videoBubbleVideo), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('a file still to come shows its ring and how big it is', (
      t,
    ) async {
      setFileWait(
        'w1',
        const FileWait(
          size: 225280,
          state: WaitState.asks,
          rule: AutoGet.never,
        ),
      );
      await open(
        t,
        SharedLists(
          files: [file('Notes.docx', DateTime(2025, 11, 9), uid: 'w1')],
        ),
      );
      expect(find.byType(FileWaitMark), findsOneWidget);
      expect(find.textContaining(l10n.transferTapToDownload), findsOneWidget);
      // it comes in: the row goes with its wait, the lists are read again
      setFileWait('w1', null);
      await t.pump();
      expect(find.byType(FileWaitMark), findsNothing);
    });

    group('search, filters and the menu', () {
      Future<void> openFiles(
        WidgetTester t,
        List<SharedItem> files, {
        bool group = false,
        bool blocking = false,
        Future<void> Function(String uid)? removeHere,
      }) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            home: SharedScreen(
              chatId: 'p',
              title: 'Hiking club',
              group: group,
              blocking: blocking,
              hidden: false,
              nameOf: (p) => p == 'j' ? 'Jonas' : null,
              start: SharedTab.files,
              load: () async => SharedLists(files: files),
              removeHere: removeHere,
            ),
          ),
        );
        await settle(t);
      }

      final when = DateTime(2025, 11, 9);

      testWidgets('a search lists what matches, counted, the match lit', (
        t,
      ) async {
        await openFiles(t, [
          file('offline-maps.zip', when, path: '/f/1'),
          file('trail-map.pdf', when, path: '/f/2'),
          file('gear-list.xlsx', when, path: '/f/3'),
        ]);
        await t.enterText(find.byType(TextField), 'map');
        await t.pump();
        expect(
          find.text(l10n.filesCount(2, '2').toUpperCase()),
          findsOneWidget,
        );
        expect(find.text('gear-list'), findsNothing);
        final lit = t.widget<Text>(find.text('trail-map'));
        final spans = (lit.textSpan! as TextSpan).children!.cast<TextSpan>();
        expect(spans.map((x) => x.text), ['trail-', 'map']);
        expect(spans[1].style!.color, isNot(spans[0].style!.color));
        await t.enterText(find.byType(TextField), 'nothing like it');
        await t.pump();
        expect(find.text(l10n.filesNoMatch), findsOneWidget);
      });

      testWidgets('in a group, rows say who sent them and the filter keeps '
          'one sender', (t) async {
        await openFiles(t, [
          SharedItem(path: '/f/1', name: 'route.pdf', when: when, peer: 'j'),
          SharedItem(path: '/f/2', name: 'mine.pdf', when: when, mine: true),
        ], group: true);
        expect(find.textContaining('Jonas'), findsOneWidget);
        await t.ensureVisible(find.text(l10n.filesFromAnyone));
        await t.pumpAndSettle();
        await t.tap(find.text(l10n.filesFromAnyone));
        await t.pumpAndSettle();
        await t.tap(find.text('Jonas').last);
        await t.pumpAndSettle();
        expect(find.text(l10n.filesFrom('Jonas')), findsOneWidget);
        expect(find.text('mine'), findsNothing);
        expect(find.text('route'), findsOneWidget);
      });

      testWidgets('on this phone leaves out one still to come', (t) async {
        setFileWait(
          'w1',
          const FileWait(
            size: 4000,
            state: WaitState.asks,
            rule: AutoGet.never,
          ),
        );
        await openFiles(t, [
          file('here.pdf', when, path: '/f/1'),
          file('later.pdf', when, uid: 'w1'),
        ]);
        expect(find.text('later'), findsOneWidget);
        expect(find.textContaining('until'), findsOneWidget);
        await t.ensureVisible(find.text(l10n.filesOnPhone));
        await t.pumpAndSettle();
        await t.tap(find.text(l10n.filesOnPhone));
        await t.pumpAndSettle();
        expect(
          t
              .state<SharedFilesPageState>(find.byType(SharedFilesPage))
              .filters
              .here,
          isTrue,
        );
        expect(find.text('later'), findsNothing);
        expect(find.text('here'), findsOneWidget);
      });

      testWidgets('a hold opens the menu; remove download asks and frees it', (
        t,
      ) async {
        final gone = <String>[];
        chatShown('p');
        addTearDown(() => chatGone('p'));
        await openFiles(t, [
          file('route.pdf', when, path: '/f/1', uid: 'u1'),
        ], removeHere: (u) async => gone.add(u));
        await t.longPress(find.text('route'));
        await t.pumpAndSettle();
        for (final w in [
          l10n.filesOpen,
          l10n.chatForward,
          l10n.fileSaveToDevice,
          l10n.filesShowInChat,
          l10n.filesRemoveDownload,
        ]) {
          expect(find.text(w), findsOneWidget, reason: w);
        }
        await t.tap(find.text(l10n.filesRemoveDownload));
        await t.pumpAndSettle();
        expect(find.text(l10n.filesRemoveDownloadLine), findsOneWidget);
        await t.tap(find.text(l10n.filesRemoveDownloadYes));
        await t.pumpAndSettle();
        expect(gone, ['u1']);
      });

      testWidgets('two of one name say which is ours and which came', (
        t,
      ) async {
        await openFiles(t, [
          SharedItem(
            path: '/f/1',
            name: 'plan.pdf',
            uid: 'a',
            mine: true,
            when: when,
          ),
          SharedItem(path: '/f/2', name: 'plan.pdf', uid: 'b', when: when),
          SharedItem(path: '/f/3', name: 'other.pdf', uid: 'c', when: when),
        ]);
        expect(find.textContaining(l10n.chatYou), findsOneWidget);
        expect(find.textContaining('Hiking club'), findsWidgets);
      });

      testWidgets('ours, and one still to come, have no remove download', (
        t,
      ) async {
        await openFiles(t, [
          SharedItem(
            path: '/f/1',
            name: 'mine.pdf',
            uid: 'u1',
            mine: true,
            when: when,
          ),
        ]);
        await t.longPress(find.text('mine'));
        await t.pumpAndSettle();
        expect(find.text(l10n.filesRemoveDownload), findsNothing);
      });

      testWidgets('show in chat asks the chat under it', (t) async {
        chatShown('p');
        addTearDown(() => chatGone('p'));
        addTearDown(() => showInChat.value = null);
        await openFiles(t, [file('route.pdf', when, path: '/f/1', uid: 'u1')]);
        await t.longPress(find.text('route'));
        await t.pumpAndSettle();
        await t.tap(find.text(l10n.filesShowInChat));
        await t.pumpAndSettle();
        expect(showInChat.value, (chat: 'p', uid: 'u1'));
      });

      testWidgets('with no chat under it, no show in chat; a blocking chat '
          'keeps their file in', (t) async {
        await openFiles(t, [
          file('route.pdf', when, path: '/f/1', uid: 'u1'),
        ], blocking: true);
        await t.longPress(find.text('route'));
        await t.pumpAndSettle();
        expect(find.text(l10n.filesOpen), findsOneWidget);
        expect(find.text(l10n.filesShowInChat), findsNothing);
        expect(find.text(l10n.chatForward), findsNothing);
        expect(find.text(l10n.fileSaveToDevice), findsNothing);
      });
    });

    test('the order by size puts the biggest first, unknown last', () {
      final w = DateTime(2025, 1, 1);
      FileEntry e(String n) => FileEntry(
        path: '/f/$n',
        name: n,
        uid: n,
        mine: false,
        peer: null,
        when: w,
      );
      final sizes = {'a.zip': 10, 'b.zip': 900, 'c.zip': null};
      final out = filterFiles(
        [e('a.zip'), e('b.zip'), e('c.zip')],
        const FileFilters(order: FileOrder.largest),
        sizeOf: (x) => sizes[x.name],
        waits: (_) => false,
      );
      expect(out.map((x) => x.name), ['b.zip', 'a.zip', 'c.zip']);
      expect(fileKindFilterOf('x.pdf'), FileKindFilter.docs);
      expect(fileKindFilterOf('x.py'), FileKindFilter.code);
      expect(fileKindFilterOf('x.zip'), FileKindFilter.archives);
    });

    testWidgets('a tap on a text file opens kryfo\'s viewer', (t) async {
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/platform'),
        (c) async {
          calls.add(c.method);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('halo/platform'),
          null,
        ),
      );
      final f = File('${tmp.path}/plan.md')
        ..writeAsStringSync('# Plan\nstep\n');
      await open(
        t,
        SharedLists(
          files: [file('plan.md', DateTime(2025, 11, 9), path: f.path)],
        ),
      );
      await t.tap(find.text('plan'));
      await settle(t);
      expect(find.byType(TextViewer), findsOneWidget);
      expect(calls, isNot(contains('openFile')));
    });
  });

  group('kept', () {
    testWidgets('in a chat that blocks, their file opens in no other app, '
        'ours as ever', (t) async {
      final theirs = File('${tmp.path}/a.xyz')..writeAsBytesSync([1, 2, 3]);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final when = DateTime(2025, 11, 9);
      await t.pumpWidget(
        MaterialApp(
          home: SharedScreen(
            chatId: 'p',
            title: 'Lena',
            start: SharedTab.files,
            blocking: true,
            load: () async => SharedLists(
              files: [SharedItem(path: theirs.path, name: 'a.xyz', when: when)],
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      await t.tap(find.text('a'));
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(l10n.chatShotsKeptOpen), findsOneWidget);
      expect(find.text(l10n.fileOpenWith), findsNothing);
      await t.pump(const Duration(seconds: 5));
    });

    test('group info hands the room and the block to the shared page', () {
      final body = bodyOf(
        File('lib/screens/group_info_screen.dart').readAsStringSync(),
        'Future<void> _openShared(',
      );
      expect(body, contains('_isRoom'));
      expect(body, contains('appState.shotsBlocksGroup('));
    });
  });

  group('the section', () {
    testWidgets('files, voice and links each get a row that opens its tab', (
      t,
    ) async {
      final opened = <SharedTab>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedMediaSection(
              paths: const [],
              count: 0,
              files: 3,
              links: 1,
              onOpenTab: opened.add,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.contactNothingSharedYet), findsNothing);
      expect(find.text(l10n.sharedTabFiles), findsOneWidget);
      expect(find.text(l10n.sharedTabVoice), findsNothing);
      expect(find.text('3'), findsOneWidget);
      await t.tap(find.text(l10n.sharedTabLinks));
      expect(opened, [SharedTab.links]);
    });

    testWidgets('nothing at all says so', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SharedMediaSection(paths: [], count: 0)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.contactNothingSharedYet), findsOneWidget);
    });
  });
}
