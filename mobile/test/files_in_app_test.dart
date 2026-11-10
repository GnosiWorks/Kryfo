// SPDX-License-Identifier: GPL-3.0-or-later
// files stay inside kryfo: the bubble shows a kind's tile, a code file's
// first lines and a pdf's first page, a ring that stops a send, and the
// menu leads with kryfo's own viewer and sets the way out apart with what
// it means. the text and pdf viewers read through the seal into memory
// only, and the lock takes everything they drew
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/file_peek.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show AppStateScreen, appState;
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/pdf_pages.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/file_actions.dart';
import 'package:kryfo/widgets/file_badge.dart';
import 'package:kryfo/widgets/file_bubble.dart';
import 'package:kryfo/widgets/file_sheet.dart';
import 'package:kryfo/widgets/message_menu.dart';
import 'package:kryfo/widgets/pdf_viewer.dart';
import 'package:kryfo/widgets/text_viewer.dart';
import 'package:kryfo/widgets/video_bubble.dart' show openReceivedFile;

class FakePdf implements PdfBackend {
  int opens = 0;
  final Set<int> live = {};
  final List<String> paths = [];
  Object? error;
  int pages = 3;
  List<int> hits = const [];
  int rendered = 0;

  // what each open asked for, the bytes it found, and whether the file
  // could still be read when its document was closed
  final List<bool> firsts = [];
  final List<List<int>> seen = [];
  final List<bool> readableAtClose = [];
  final Map<int, String> _pathOf = {};
  // an open that does not answer until completed: a renderer stuck, or
  // one that took the app down
  Completer<void>? hold;

  @override
  Future<Map<Object?, Object?>?> open(String path, {bool first = false}) async {
    paths.add(path);
    firsts.add(first);
    try {
      seen.add(File(path).readAsBytesSync());
    } catch (_) {
      seen.add(const []);
    }
    await hold?.future;
    if (error != null) return {'error': error};
    final id = ++opens;
    live.add(id);
    _pathOf[id] = path;
    return {
      'id': id,
      'pages': pages,
      'sizes': [
        for (var i = 0; i < (first ? 1 : pages); i++) ...[612, 792],
      ],
      'find': true,
    };
  }

  @override
  Future<({int w, int h, Uint8List rgba})?> render(
    int id,
    int page,
    int width,
  ) async {
    if (!live.contains(id)) return null;
    rendered++;
    final h = (width * 792 / 612).round();
    return (
      w: width,
      h: h,
      rgba: Uint8List(width * h * 4)..fillRange(0, width * h * 4, 255),
    );
  }

  @override
  Future<List<int>> find(int id, String words) async => hits;

  @override
  Future<void> close(int id) async {
    final path = _pathOf.remove(id);
    if (path != null) {
      var readable = true;
      try {
        final b = File(path).readAsBytesSync();
        readable = b.any((x) => x != 0);
      } catch (_) {
        readable = false;
      }
      readableAtClose.add(readable);
    }
    live.remove(id);
  }
}

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('files_in_app');
    pdfMarksDirForTest = (Directory('${tmp.path}/marks')..createSync()).path;
    lockState.openForTest();
    openPictures();
  });
  tearDown(() {
    pdfBackendForTest = null;
    pdfViewHereForTest = null;
    pdfMarksDirForTest = null;
    pdfOpenedByHand.clear();
    pdfPageBudget = 80 << 20;
    fileSheetPickForTest = null;
    forgetFirstLines();
    resetPdfGlancesForTest();
    HaloColors.setLight(false);
    openPictures();
    tmp.deleteSync(recursive: true);
  });

  File made(String leaf, Object body) {
    final f = File('${tmp.path}/$leaf');
    body is String
        ? f.writeAsStringSync(body)
        : f.writeAsBytesSync(body as List<int>);
    return f;
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 30; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 400));
  }

  Widget host(
    Widget child, {
    bool still = false,
    TextDirection dir = TextDirection.ltr,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Directionality(
        textDirection: dir,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  group('the tile', () {
    test('each kind wears its colour', () {
      FileTone tone(String n) => fileToneOf(FileFacts(kindOfName(n), extOf(n)));
      expect(tone('a.pdf'), FileTone.pdf);
      expect(tone('a.py'), FileTone.code);
      expect(tone('a.txt'), FileTone.code);
      expect(tone('a.m4a'), FileTone.audio);
      expect(tone('a.xlsx'), FileTone.sheet);
      expect(tone('a.csv'), FileTone.sheet);
      expect(tone('a.mp4'), FileTone.video);
      expect(tone('a.docx'), FileTone.doc);
      expect(tone('a.zip'), FileTone.zip);
      expect(tone('a.xyz'), FileTone.other);
    });

    test('the colours come from the theme, deeper in light', () {
      expect(fileToneColor(FileTone.pdf), HaloColors.rose);
      expect(fileToneColor(FileTone.audio), HaloColors.violet);
      HaloColors.setLight(true);
      expect(fileToneColor(FileTone.pdf), HaloColors.roseText);
      expect(fileToneColor(FileTone.sheet), HaloColors.greenText);
      expect(onFileTone(FileTone.pdf), const Color(0xFFFFFFFF));
    });

    test('the label never grows past four letters', () {
      expect(
        fileBadgeLabel(const FileFacts(FileKind.other, 'gitignore')),
        'GITI',
      );
      expect(fileBadgeLabel(const FileFacts(FileKind.pdf, 'pdf')), 'PDF');
    });
  });

  group('the bubble', () {
    testWidgets('a code file shows its first lines, left to right', (t) async {
      final f = made(
        'in_a.py',
        '\n\ndef rent_share(total, people):\n    return round(total / people, 2)\n',
      );
      await t.pumpWidget(
        host(
          FileCard(path: f.path, name: 'rent.py', isOut: false),
          dir: TextDirection.rtl,
        ),
      );
      await settle(t);
      expect(find.text('def rent_share(total, people):'), findsOneWidget);
      expect(find.text('PY'), findsOneWidget);
      final line = t.widget<Text>(find.text('def rent_share(total, people):'));
      expect(line.textDirection, TextDirection.ltr);
    });

    test('marks that turn text around are shown, never obeyed', () {
      final evil = 'if user == "admin\u202E \u2066// ok\u2069"';
      expect(visibleText(evil), isNot(contains('\u202E')));
      expect(visibleText(evil), isNot(contains('\u2066')));
      expect(visibleText(evil), contains('\uFFFD'));
      expect(visibleText('a\tb\u0007'), 'a  b');
    });

    testWidgets('the lock takes the first lines, and they come back after', (
      t,
    ) async {
      final f = made('in_b.txt', 'secret plan\nline two');
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 'plan.txt', isOut: false)),
      );
      await settle(t);
      expect(find.text('secret plan'), findsOneWidget);
      shutPictures();
      await t.pump();
      expect(find.text('secret plan'), findsNothing);
      expect(firstLinesNow(f.path), isNull);
      openPictures();
      await settle(t);
      expect(find.text('secret plan'), findsOneWidget);
    });

    testWidgets('a binary file has no glance', (t) async {
      final f = made('in_c.txt', [0x50, 0x4B, 0, 0, 1, 2]);
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 'x.txt', isOut: false)),
      );
      await settle(t);
      expect(await t.runAsync(() => firstLinesOf(f.path)), isNull);
    });

    testWidgets('a send fills a ring with a cross that stops it', (t) async {
      final f = made('out_d.zip', [1, 2, 3]);
      mediaProgressStart('u1', bytes: 40 << 20);
      mediaProgressUpdate('u1', 0.64);
      var stopped = 0;
      final h = t.ensureSemantics();
      await t.pumpWidget(
        host(
          FileCard(
            path: f.path,
            name: 'photos-march.zip',
            isOut: true,
            sendingUid: 'u1',
            onCancel: () => stopped++,
          ),
        ),
      );
      await settle(t);
      expect(find.byType(FileSendRing), findsOneWidget);
      expect(find.textContaining(percentOf(0.64)), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.chatStopSending), findsOneWidget);
      await t.tap(find.byType(FileSendRing));
      expect(stopped, 1);
      mediaProgressEnd('u1');
      await settle(t);
      expect(find.byType(FileSendRing), findsNothing);
      expect(find.text('ZIP'), findsOneWidget);
      h.dispose();
    });

    testWidgets('a pdf shows its first page and how many pages', (t) async {
      final fake = FakePdf()..pages = 12;
      pdfBackendForTest = fake;
      pdfViewHereForTest = true;
      final f = made('in_e.pdf', '%PDF-1.7\n');
      await t.pumpWidget(
        host(
          FileCard(
            path: f.path,
            name: 'Lease-draft.pdf',
            isOut: false,
            glance: true,
          ),
        ),
      );
      await settle(t);
      expect(find.byType(PdfFirstPage), findsOneWidget);
      expect(find.text(l10n.filePages(12, '12')), findsOneWidget);
      // a glance reads the first page's size only
      expect(fake.firsts, [true]);
      // the glance's document is shut once its page is drawn
      expect(fake.live, isEmpty);
      expect(pdfGlanceNow(f.path), isNotNull);
      shutPictures();
      expect(pdfGlanceNow(f.path), isNull);
      openPictures();
    });

    testWidgets('a pdf with a password shows no glance', (t) async {
      pdfBackendForTest = FakePdf()..error = 'locked';
      pdfViewHereForTest = true;
      final f = made('in_f.pdf', '%PDF-1.7\n');
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 'l.pdf', isOut: false, glance: true)),
      );
      await settle(t);
      expect(find.text(l10n.filePages(3, '3')), findsNothing);
    });

    testWidgets('a stranger\'s pdf is not drawn until it is opened by hand', (
      t,
    ) async {
      final fake = FakePdf();
      pdfBackendForTest = fake;
      pdfViewHereForTest = true;
      final f = made('in_s.pdf', '%PDF-1.7\n');
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 's.pdf', isOut: false)),
      );
      await settle(t);
      expect(find.byType(PdfFirstPage), findsNothing);
      expect(fake.opens, 0, reason: 'nothing handed to the renderer');
      pdfOpenedByHand.add(f.path);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 's.pdf', isOut: false)),
      );
      await settle(t);
      await settle(t);
      expect(find.byType(PdfFirstPage), findsOneWidget);
      expect(fake.opens, 1);
    });

    testWidgets('a pdf over ten mb keeps its tile in the bubble', (t) async {
      final fake = FakePdf();
      pdfBackendForTest = fake;
      pdfViewHereForTest = true;
      final f = made('in_b.pdf', '%PDF-1.7\n');
      f.openSync(mode: FileMode.append)
        ..truncateSync(kGlanceMostBytes + 1)
        ..closeSync();
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 'b.pdf', isOut: false, glance: true)),
      );
      await settle(t);
      expect(fake.paths, isEmpty);
      expect(find.text(l10n.filePages(3, '3')), findsNothing);
    });

    testWidgets('a pdf that took the app down is never drawn here again', (
      t,
    ) async {
      final fake = FakePdf()..hold = Completer<void>();
      pdfBackendForTest = fake;
      final marks = Directory('${tmp.path}/marks');
      final f = made('in_c.pdf', '%PDF-1.7\n');
      // the renderer is inside the file: its mark is down
      unawaited(PdfDoc.open(f.path).then((d) => d.close(), onError: (_) {}));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(marks.listSync(), hasLength(1));
      // the app went down there and starts again: the mark is still down
      pdfMarksDirForTest = marks.path;
      expect(await t.runAsync(() => pdfStruck(f.path)), isTrue);
      final before = fake.paths.length;
      final refused = await t.runAsync(() async {
        try {
          await PdfDoc.open(f.path);
          return false;
        } on PdfOpenFailed {
          return true;
        }
      });
      expect(refused, isTrue);
      expect(fake.paths.length, before, reason: 'never handed over again');
      // a pdf drawn to the end leaves no mark
      fake.hold!.complete();
      fake.hold = null;
      final g = made('in_d.pdf', '%PDF-1.7\n');
      final d = await t.runAsync(() => PdfDoc.open(g.path));
      await t.runAsync(() => d!.page(0, 100));
      await t.runAsync(() => d!.close());
      expect(await t.runAsync(() => pdfStruck(g.path)), isFalse);
    });

    testWidgets('large text cuts nothing in a narrow bubble', (t) async {
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = made('in_g.docx', List.filled(220 * 1024, 1));
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: FileCard(
                    path: f.path,
                    name: 'Notes-from-meeting.docx',
                    isOut: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.text('.docx'), findsOneWidget);
    });
  });

  group('on a computer', () {
    setUp(() => onDesktop = true);
    tearDown(() => onDesktop = false);

    testWidgets('a pdf is a tile with no drawn page, and opens outside', (
      t,
    ) async {
      final fake = FakePdf();
      pdfBackendForTest = fake;
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/platform'),
        (c) async {
          calls.add(c.method);
          return c.method == 'openFile' ? true : null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('halo/platform'),
          null,
        ),
      );
      fileSheetPickForTest = () => FileSheetPick.open;
      final f = made('in_m.pdf', '%PDF-1.7\n');
      expect(fileViewOf(const FileFacts(FileKind.pdf, 'pdf')), isNull);
      await t.pumpWidget(
        host(FileCard(path: f.path, name: 'Lease.pdf', isOut: false)),
      );
      await settle(t);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.byType(PdfFirstPage), findsNothing);
      expect(fake.opens, 0, reason: 'nothing draws a pdf on a computer');
      final ctx = t.element(find.byType(FileCard));
      unawaited(openReceivedFile(ctx, f.path, 'Lease.pdf'));
      await settle(t);
      expect(find.byType(PdfViewer), findsNothing);
      expect(calls, contains('openFile'));
      await t.pump(const Duration(seconds: 3));
    });
  });

  group('the menu', () {
    testWidgets('the way out sits apart, its note under it', (t) async {
      await t.pumpWidget(
        host(
          MessageMenuCard(
            actions: [
              MenuAction(
                icon: Icons.visibility_outlined,
                label: l10n.fileViewInKryfo,
                onTap: () {},
              ),
              MenuAction(
                icon: Icons.forward_rounded,
                label: l10n.chatForward,
                onTap: () {},
              ),
              MenuAction(
                icon: Icons.open_in_new_rounded,
                label: l10n.fileOpenWith,
                apart: true,
                aside: l10n.fileOpenWithNote,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      final view = t.getRect(find.text(l10n.fileViewInKryfo));
      final open = t.getRect(find.text(l10n.fileOpenWith));
      final note = t.getRect(find.text(l10n.fileOpenWithNote));
      expect(view.top, lessThan(open.top));
      expect(open.bottom, lessThanOrEqualTo(note.top));
      expect(find.byType(AsideNote), findsOneWidget);
    });

    test(
      'kryfo views text, code, pictures and videos; pdfs where it draws them',
      () {
        FileView? v(String n) => fileViewOf(FileFacts(kindOfName(n), extOf(n)));
        expect(v('a.py'), FileView.text);
        expect(v('a.csv'), FileView.text);
        expect(v('a.jpg'), FileView.picture);
        expect(v('a.mp4'), FileView.video);
        expect(v('a.docx'), isNull);
        pdfViewHereForTest = false;
        expect(v('a.pdf'), isNull);
        pdfViewHereForTest = true;
        expect(v('a.pdf'), FileView.pdf);
        // an app installer never opens, whatever it is called
        expect(fileViewOf(const FileFacts(FileKind.installer, 'apk')), isNull);
      },
    );

    test('nothing a chat that blocks keeps goes on, nor an app', () {
      expect(canForwardFile('/x/in_a.pdf', 'a.pdf', kept: false), isTrue);
      expect(canForwardFile('/x/in_a.pdf', 'a.pdf', kept: true), isFalse);
      expect(canForwardFile('/x/in_a.apk', 'a.apk', kept: false), isFalse);
      expect(canForwardFile(null, 'a.pdf', kept: false), isFalse);
    });
  });

  group('the text reader', () {
    Future<BuildContext> base(WidgetTester t) async {
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
      return ctx;
    }

    testWidgets('a tap on a text file opens it here, never outside', (t) async {
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
      final f = made('in_h.md', '# Plan\nstep one\n');
      final ctx = await base(t);
      unawaited(openReceivedFile(ctx, f.path, 'plan.md', from: 'Lena'));
      await settle(t);
      expect(find.byType(TextViewer), findsOneWidget);
      expect(find.text('step one'), findsOneWidget);
      expect(find.textContaining(l10n.fileFrom('Lena')), findsOneWidget);
      expect(calls, isNot(contains('openFile')));
      expect(calls, isNot(contains('shareFile')));
      // the way out is offered with what it means
      expect(find.text(l10n.fileOpenWith), findsOneWidget);
      expect(find.text(l10n.fileOpenWithNote), findsOneWidget);
    });

    testWidgets('in a chat that blocks it opens with no way out', (t) async {
      final f = made('in_i.txt', 'kept words');
      final ctx = await base(t);
      unawaited(openReceivedFile(ctx, f.path, 'k.txt', kept: true));
      await settle(t);
      expect(find.text('kept words'), findsOneWidget);
      expect(find.text(l10n.fileOpenWith), findsNothing);
      expect(find.text(l10n.fileSaveToDevice), findsNothing);
      expect(find.text(l10n.chatForward), findsNothing);
    });

    testWidgets('the lock takes the words, the unlock reads them again', (
      t,
    ) async {
      final f = made('in_j.log', 'boot ok');
      final ctx = await base(t);
      unawaited(
        openTextFile(
          ctx,
          path: f.path,
          name: 'a.log',
          facts: const FileFacts(FileKind.other, 'log'),
        ),
      );
      await settle(t);
      expect(find.text('boot ok'), findsOneWidget);
      shutPictures();
      await settle(t);
      expect(find.text('boot ok'), findsNothing);
      openPictures();
      await settle(t);
      expect(find.text('boot ok'), findsOneWidget);
    });

    testWidgets('a file that is not words says so', (t) async {
      final f = made('in_k.txt', [0, 1, 2, 3]);
      final ctx = await base(t);
      unawaited(
        openTextFile(
          ctx,
          path: f.path,
          name: 'k.txt',
          facts: const FileFacts(FileKind.text, 'txt'),
        ),
      );
      await settle(t);
      expect(find.text(l10n.fileNotWords), findsOneWidget);
    });

    test('a line of megabytes is drawn in rows, numbered once', () {
      final long = 'a' * 9000;
      final rows = textRowsOf(['x', long, 'y']);
      expect([for (final r in rows) r.$1], [1, 2, null, null, 3]);
      expect(rows[1].$2.length, kTextRowMost);
      expect([for (final r in rows.sublist(1, 4)) r.$2].join(), long);
      // a pair that makes one character is never split
      final pairs = '${'b' * (kTextRowMost - 1)}\u{1F600}tail';
      final cut = textRowsOf([pairs]);
      expect(cut.first.$2.length, kTextRowMost - 1);
      expect(cut.map((r) => r.$2).join(), pairs);
    });

    testWidgets('a long name keeps its extension in the head', (t) async {
      final f = made('in_n.txt', 'words\n');
      final ctx = await base(t);
      unawaited(
        openReceivedFile(
          ctx,
          f.path,
          'a-very-long-name-that-goes-on-and-on-past-any-phone-width.txt',
        ),
      );
      await settle(t);
      expect(find.text('.txt'), findsOneWidget);
    });

    test('a long file says where it stops', () {
      final r = textLinesOf('a\nb'.codeUnits, whole: kTextViewMost + 10);
      expect(r.cut, isTrue);
      expect(r.lines, ['a', 'b']);
    });
  });

  group('the pdf reader', () {
    Future<PdfViewerState> openPdf(
      WidgetTester t,
      FakePdf fake, {
      bool kept = false,
    }) async {
      pdfBackendForTest = fake;
      pdfViewHereForTest = true;
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = made('in_l.pdf', '%PDF-1.7\n');
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
      unawaited(
        openPdfFile(
          ctx,
          path: f.path,
          name: 'Lease-draft.pdf',
          facts: const FileFacts(FileKind.pdf, 'pdf'),
          kept: kept,
        ),
      );
      await settle(t);
      return t.state<PdfViewerState>(find.byType(PdfViewer));
    }

    testWidgets('pages, zoom buttons and a page to jump to', (t) async {
      final fake = FakePdf()..pages = 12;
      final v = await openPdf(t, fake);
      expect(fake.rendered, greaterThan(0));
      expect(find.textContaining(l10n.filePages(12, '12')), findsOneWidget);
      expect(v.scale, 1);
      await t.tap(find.bySemanticsLabel(l10n.fileZoomIn));
      await settle(t);
      expect(v.scale, closeTo(1.25, 0.01));
      await t.tap(find.bySemanticsLabel(l10n.fileZoomOut));
      await settle(t);
      expect(v.scale, closeTo(1, 0.01));
      v.jumpTo(5);
      await settle(t);
      expect(v.page, 5);
    });

    testWidgets('the lock closes the document and drops every page', (t) async {
      final fake = FakePdf();
      final v = await openPdf(t, fake);
      expect(fake.live, hasLength(1));
      expect(pdfDocsOpen, 1);
      expect(v.pagesKept, greaterThan(0));
      shutPictures();
      await settle(t);
      expect(fake.live, isEmpty);
      expect(pdfDocsOpen, 0);
      expect(v.pagesKept, 0);
      openPictures();
      await settle(t);
      expect(fake.live, hasLength(1));
      expect(v.pagesKept, greaterThan(0));
    });

    testWidgets('a file outside the seal is read where it is', (t) async {
      // the sealed case, memory zeroed before the renderer lets go, is in
      // phone_seal_test
      final fake = FakePdf();
      await openPdf(t, fake);
      expect(fake.paths.single, endsWith('in_l.pdf'));
      expect(fake.firsts, [false]);
    });

    testWidgets('a lock and an unlock while it opens leave one document', (
      t,
    ) async {
      final fake = FakePdf()..hold = Completer<void>();
      pdfBackendForTest = fake;
      pdfViewHereForTest = true;
      final f = made('in_m.pdf', '%PDF-1.7\n');
      await t.pumpWidget(
        MaterialApp(
          home: PdfViewer(
            path: f.path,
            name: 'm.pdf',
            facts: const FileFacts(FileKind.pdf, 'pdf'),
          ),
        ),
      );
      await settle(t);
      shutPictures();
      await settle(t);
      openPictures();
      await settle(t);
      fake.hold!.complete();
      await settle(t);
      expect(fake.live, hasLength(1));
      expect(pdfDocsOpen, 1);
    });

    testWidgets('drawn pages stay inside the memory budget', (t) async {
      final fake = FakePdf()..pages = 6;
      pdfPageBudget = 400 * 1024;
      final v = await openPdf(t, fake);
      for (var i = 0; i < 6; i++) {
        v.jumpTo(i);
        await settle(t);
      }
      expect(fake.rendered, greaterThan(2));
      expect(v.drawnBytes, lessThan(1 << 20), reason: 'the newest page alone');
      expect(v.pagesKept, greaterThan(0));
    });

    testWidgets('a password pdf says how to read it', (t) async {
      await openPdf(t, FakePdf()..error = 'locked');
      expect(find.text(l10n.filePdfLocked), findsOneWidget);
    });

    testWidgets('search jumps to the pages the words are on', (t) async {
      final fake = FakePdf()
        ..pages = 8
        ..hits = [4, 6];
      final v = await openPdf(t, fake);
      await t.tap(find.bySemanticsLabel(l10n.fileSearchIn));
      await settle(t);
      await t.enterText(find.byType(TextField), 'deposit');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await settle(t);
      expect(v.page, 4);
      await t.tap(find.bySemanticsLabel(l10n.chatNextMatch));
      await settle(t);
      expect(v.page, 6);
    });

    for (final kept in [true, false]) {
      testWidgets(
        kept
            ? 'in a chat that blocks: no forward, save or way out, and no '
                  'screenshots'
            : 'elsewhere: forward, save and the way out',
        (t) async {
          final held = appState.secureForced;
          await openPdf(t, FakePdf(), kept: kept);
          final shown = kept ? findsNothing : findsOneWidget;
          expect(find.text(l10n.fileOpenWith), shown);
          expect(find.text(l10n.fileSaveToDevice), shown);
          expect(find.text(l10n.chatForward), shown);
          expect(appState.secureForced, kept || held);
        },
      );
    }
  });

  test('the lock reaches the file glances and documents', () {
    final src = File('lib/picture_lock.dart').readAsStringSync();
    expect(src, contains('forgetFirstLines)'));
    expect(src, contains('closeAllPdfs)'));
    final shred = File('lib/shred.dart').readAsStringSync();
    expect(shred, contains('forgetFirstLinesOf(path)'));
    expect(shred, contains('forgetPdfGlance(path)'));
  });

  test('the pdf renderer is the phone\'s own: no pdf library', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    for (final lib in [
      'pdfrx',
      'pdfx',
      'syncfusion',
      'pdf_render',
      'flutter_pdfview',
      'native_pdf',
    ]) {
      expect(pub, isNot(contains(lib)), reason: lib);
    }
    final kt = File(
      'android/app/src/main/kotlin/app/kryfo/PdfPages.kt',
    ).readAsStringSync();
    expect(kt, contains('android.graphics.pdf.PdfRenderer'));
    // pages go back as pixels, never as files
    expect(kt, isNot(contains('FileOutputStream')));
    expect(kt, isNot(contains('createTempFile')));
  });

  // the image class is used, so the import is kept honest
  test('a page is an image', () => expect(ui.Image, isNotNull));
}

String percentOf(double v) => '${(v * 100).round()}';
