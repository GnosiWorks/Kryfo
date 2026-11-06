// SPDX-License-Identifier: GPL-3.0-or-later
// files dropped or pasted on a chat on a computer wait in a row above the
// composer: a drop and a paste stage them, the x takes one out, esc empties
// the row and enter sends it, photos as one album and files one after
// another. each chat keeps its own row, a lock empties all of them with
// their thumbs, a stranger's request keeps nothing, and a file too big
// stays out with a line. a copied picture pastes in as a photo held in
// memory, never as a file
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart' show albumPlan;
import 'package:kryfo/desktop/attach_tray.dart';
import 'package:kryfo/desktop/clip_picture.dart' show clipboardPicture;
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/drag_in.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/widgets/enter_sends.dart';
import 'package:path/path.dart' as p;

import '../source_body.dart';

const _codec = StandardMethodCodec();

Future<void> _drop(WidgetTester t, List<String> paths) async {
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    DesktopDrop.channel.name,
    _codec.encodeMethodCall(MethodCall('dropped', [paths, 500.0, 200.0])),
    (_) {},
  );
  await t.pump();
  await t.pump();
}

Future<int> _fifty() async => 50 * 1024 * 1024;

void main() {
  late Directory root;

  File file(String name, [int bytes = 3]) =>
      File(p.join(root.path, name))..writeAsBytesSync(List.filled(bytes, 7));

  setUp(() {
    root = Directory.systemTemp.createTempSync('attach_tray');
    lockState.openForTest();
    AttachTray.decode = (_) async => null;
    AttachTray.decodePicture = (_) async => null;
  });
  tearDown(() {
    onDesktop = false;
    AttachTray.decode = decodeTrayThumb;
    PasteFiles.clip = clipboardFiles;
    PasteFiles.picture = clipboardPicture;
    AttachTray.decodePicture = decodeTrayBytes;
    DeskTrays.clearAll();
    lockState.openForTest();
    root.deleteSync(recursive: true);
  });

  group('enter sends it the phone\'s way', () {
    test('photos and videos as one album with the caption on its first, '
        'then each file without one', () {
      final items = [
        TrayItem(file('a.jpg').path, 3),
        TrayItem(file('notes.pdf').path, 3),
        TrayItem(file('b.PNG').path, 3),
        TrayItem(file('clip.mp4').path, 3),
        TrayItem(file('list.txt').path, 3),
      ];
      final plan = trayPlan(items, 'from the trip');
      expect(
        [for (final x in plan.media) x.name],
        ['a.jpg', 'b.PNG', 'clip.mp4'],
      );
      expect(
        [for (final (x, w) in plan.files) '${x.name}:$w'],
        ['notes.pdf:', 'list.txt:'],
      );
      final album = albumPlan(plan.media, 'from the trip');
      expect(album.map((g) => g.album?.n).toSet(), {3});
      expect([for (final g in album) g.caption], ['from the trip', '', '']);
    });

    test('files alone go one after another, the first with the caption', () {
      final plan = trayPlan([
        TrayItem(file('a.pdf').path, 3),
        TrayItem(file('b.zip').path, 3),
      ], 'both');
      expect(plan.media, isEmpty);
      expect(
        [for (final (x, w) in plan.files) '${x.name}:$w'],
        ['a.pdf:both', 'b.zip:'],
      );
    });

    test('a photo alone is no album', () {
      final plan = trayPlan([TrayItem(file('a.webp').path, 3)], '');
      expect(albumPlan(plan.media, '').single.album, isNull);
    });
  });

  group('the row', () {
    test(
      'a file over the limit stays out, and the line says how big',
      () async {
        setL10nLocale(const Locale('en'));
        final tray = AttachTray();
        await tray.add([
          file('small.pdf', 10).path,
          file('big.mov', 2048).path,
        ], most: () async => 1024);
        expect([for (final x in tray.items) x.name], ['small.pdf']);
        expect(tray.line, contains('kb'));
        expect(tray.warns, isTrue);
      },
    );

    test('ten at most, a folder, an empty file and a second drop of the '
        'same file stay out', () async {
      setL10nLocale(const Locale('en'));
      final tray = AttachTray();
      final dir = Directory(p.join(root.path, 'folder'))..createSync();
      final a = file('a.pdf');
      await tray.add([
        a.path,
        dir.path,
        file('empty.txt', 0).path,
      ], most: _fifty);
      await tray.add([a.path], most: _fifty);
      expect(tray.items.length, 1);
      await tray.add([
        for (var i = 0; i < 12; i++) file('f$i.txt').path,
      ], most: _fifty);
      expect(tray.items.length, kDragInMost);
      expect(tray.line, l10n.mediaSendUpTo('10'));
    });

    test('each chat has its own row, by container and chat', () {
      final a = DeskTrays.of('everyday|amber');
      final b = DeskTrays.of('everyday|river');
      final decoy = DeskTrays.of('decoy|amber');
      expect(identical(a, DeskTrays.of('everyday|amber')), isTrue);
      expect(identical(a, b), isFalse);
      expect(identical(a, decoy), isFalse);
    });

    test('the chats key their rows by container and chat', () {
      final chat = sourceOf('lib/screens/chat_screen.dart');
      final group = sourceOf('lib/screens/group_chat_screen.dart');
      expect(
        chat,
        contains(
          "DeskTrays.of(\n    '\${session.container.id}|\${widget.peerHaloId}',",
        ),
      );
      expect(
        group,
        contains(
          "DeskTrays.of(\n    '\${session.container.id}|group:\${widget.groupId}',",
        ),
      );
    });

    testWidgets('a lock empties every row and lets go of the thumbs', (
      t,
    ) async {
      final img = (await t.runAsync(
        () => createTestImage(width: 4, height: 4),
      ))!;
      AttachTray.decode = (_) async => img.clone();
      final a = DeskTrays.of('everyday|amber');
      final b = DeskTrays.of('everyday|river');
      await a.add([file('a.jpg').path], most: _fifty);
      await b.add([file('b.pdf').path], most: _fifty);
      await t.pump();
      final thumb = a.items.single.thumb;
      expect(thumb, isNotNull);
      lockState.openForTest(enabled: true);
      lockState.lock();
      expect(a.isEmpty, isTrue);
      expect(b.isEmpty, isTrue);
      expect(thumb!.debugDisposed, isTrue);
      // and nothing goes in while it is locked
      await a.add([file('c.pdf').path], most: _fifty);
      expect(a.isEmpty, isTrue);
      img.dispose();
    });

    test('a thumb that lands after its row went is let go of', () async {
      final img = await createTestImage(width: 4, height: 4);
      late void Function(ui.Image?) land;
      AttachTray.decode = (_) {
        final c = Completer<ui.Image?>();
        land = c.complete;
        return c.future;
      };
      final tray = AttachTray();
      await tray.add([file('a.png').path], most: _fifty);
      tray.clear();
      final gone = img.clone();
      land(gone);
      await Future<void>.delayed(Duration.zero);
      expect(gone.debugDisposed, isTrue);
      img.dispose();
    });

    test('the chats empty the row on esc before the quote, and enter takes '
        'it before the words', () {
      for (final f in [
        'lib/screens/chat_screen.dart',
        'lib/screens/group_chat_screen.dart',
      ]) {
        final src = sourceOf(f);
        final esc = bodyOf(src, 'void _escOne(');
        expect(esc.indexOf('_tray.clear()'), greaterThan(0), reason: f);
        expect(
          esc.indexOf('_tray.clear()'),
          lessThan(esc.indexOf('_replyTo = null')),
          reason: f,
        );
        expect(src, contains('(_tray.shown ||'), reason: f);
        final send = bodyOf(src, 'Future<void> _send(');
        expect(send.indexOf('_sendTray()'), greaterThan(0), reason: f);
        expect(
          send.indexOf('_sendTray()'),
          lessThan(send.indexOf('_msgCtrl.text.trim()')),
          reason: f,
        );
        // a lock while it read sends nothing
        expect(
          bodyOf(src, 'Future<void> _sendTrayNow('),
          contains('lockState.locked) return;'),
          reason: f,
        );
      }
    });

    test('the chats and note to self take a pasted picture, and send it '
        'from its bytes', () {
      for (final f in [
        'lib/screens/chat_screen.dart',
        'lib/screens/group_chat_screen.dart',
        'lib/screens/notes_screen.dart',
      ]) {
        final src = sourceOf(f);
        expect(src, contains('onPicture: _stagePicture,'), reason: f);
        expect(src, contains('await trayBytes(x)'), reason: f);
        expect(src, isNot(contains('File(x.path).readAsBytes()')), reason: f);
      }
      // a stranger's request says media waits, as a drop does
      final chat = bodyOf(
        sourceOf('lib/screens/chat_screen.dart'),
        'void _stagePicture(',
      );
      expect(
        chat.indexOf('_tray.say(l10n.requestSenderMediaLater)'),
        lessThan(chat.indexOf('_tray.addPicture(')),
      );
      expect(
        bodyOf(
          sourceOf('lib/screens/group_chat_screen.dart'),
          'void _stagePicture(',
        ),
        contains('if (_end != null || _waiting) return;'),
      );
    });

    test('a stranger\'s request stages nothing and says why', () {
      final body = bodyOf(
        sourceOf('lib/screens/chat_screen.dart'),
        'void _stage(',
      );
      final waits = body.indexOf('if (_mediaWaits)');
      expect(waits, greaterThan(0));
      expect(body, contains('_tray.say(l10n.requestSenderMediaLater)'));
      expect(waits, lessThan(body.indexOf('_tray.add(')));
      expect(
        bodyOf(
          sourceOf('lib/screens/chat_screen.dart'),
          'Future<void> _sendTray(',
        ),
        contains('_sayMediaLater()'),
      );
    });
  });

  group('on a computer', () {
    late AttachTray tray;
    late TextEditingController words;
    late List<String> sent;

    Future<void> chat(WidgetTester t, {bool still = false}) async {
      onDesktop = true;
      DesktopDrop.scale = () => 1;
      setL10nLocale(const Locale('en'));
      t.view.physicalSize = const Size(1000, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      tray = DeskTrays.of('everyday|amber');
      words = TextEditingController();
      addTearDown(words.dispose);
      sent = [];
      void send() {
        // as the chats do: a row goes before any words
        if (!tray.isEmpty) {
          final plan = trayPlan(tray.take(), words.text.trim());
          sent.addAll([
            for (final x in plan.media) 'album:${x.name}',
            for (final (x, w) in plan.files) 'file:${x.name}:$w',
          ]);
          words.clear();
        }
      }

      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: still),
            child: Scaffold(
              body: DragInZone(
                enabled: true,
                stage: (files) => tray.add(files, most: _fifty),
                couldNotRead: () => 'could not read',
                child: Column(
                  children: [
                    const Expanded(child: Text('thread')),
                    TrayStrip(tray: tray),
                    PasteFiles(
                      onFiles: (f) => tray.add(f, most: _fifty),
                      onPicture: (png) => tray.addPicture(png, most: _fifty),
                      child: EnterSends(
                        controller: words,
                        onSend: send,
                        child: TextField(
                          controller: words,
                          autofocus: true,
                          maxLines: 4,
                          minLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('a drop stages its files above the composer, sends none', (
      t,
    ) async {
      await chat(t);
      expect(find.byKey(const ValueKey('attach-tray')), findsNothing);
      await _drop(t, [file('report.pdf', 2048).path, file('cat.jpg').path]);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('attach-tray')), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('cat.jpg'), findsOneWidget);
      expect(find.text('2 kb'), findsOneWidget);
      expect(sent, isEmpty);
      // and a second drop adds to it
      await _drop(t, [file('more.txt').path]);
      await t.pumpAndSettle();
      expect(tray.items.length, 3);
    });

    testWidgets('the x takes one out, by mouse or by keyboard', (t) async {
      await chat(t);
      await _drop(t, [
        file('a.pdf').path,
        file('b.pdf').path,
        file('c.pdf').path,
      ]);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tray-remove-a.pdf')));
      await t.pumpAndSettle();
      expect([for (final x in tray.items) x.name], ['b.pdf', 'c.pdf']);
      // shift and tab from the composer reaches the last one's x
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect([for (final x in tray.items) x.name], ['b.pdf']);
    });

    testWidgets('a screen reader hears the row, each item and its x', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      await chat(t);
      await _drop(t, [file('a.pdf', 1024).path, file('b.jpg').path]);
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Ready to send: 2'), findsOneWidget);
      expect(find.bySemanticsLabel('a.pdf, 1 kb'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove a.pdf'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('ctrl and v pastes files copied in explorer; words paste as '
        'words', (t) async {
      final copied = [file('copied.pdf').path];
      PasteFiles.clip = () async => copied;
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'Clipboard.getData') return {'text': 'hi'};
        if (c.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      });
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await chat(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyV);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect([for (final x in tray.items) x.name], ['copied.pdf']);
      // the field's own paste still runs
      expect(words.text, 'hi');
      // and shift and insert is a paste too
      copied
        ..clear()
        ..add(file('second.zip').path);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.insert);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(tray.items.length, 2);
    });

    Future<void> ctrlV(WidgetTester t) async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyV);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
    }

    testWidgets('ctrl and v of a copied picture puts it in the row, held in '
        'memory, and enter sends it as a photo', (t) async {
      final png = Uint8List.fromList(List.filled(2048, 1));
      PasteFiles.clip = () async => const [];
      PasteFiles.picture = () async => png;
      final before = root.listSync(recursive: true).length;
      await chat(t);
      await ctrlV(t);
      expect(find.byKey(const ValueKey('attach-tray')), findsOneWidget);
      expect(find.text('Pasted picture'), findsOneWidget);
      expect(find.text('2 kb'), findsOneWidget);
      final x = tray.items.single;
      expect(x.kind, TrayKind.photo);
      expect(identical(x.bytes, png), isTrue);
      expect(await trayBytes(x), same(png));
      // nothing written for it
      expect(File(x.path).existsSync(), isFalse);
      expect(root.listSync(recursive: true).length, before);
      // a second paste is a second picture
      await ctrlV(t);
      expect(tray.items.length, 2);
      await t.enterText(find.byType(TextField), 'look');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(sent, ['album:Pasted picture', 'album:Pasted picture']);
      expect(tray.isEmpty, isTrue);
    });

    testWidgets('a pasted picture shows its thumb, decoded from its bytes', (
      t,
    ) async {
      final img = (await t.runAsync(
        () => createTestImage(width: 4, height: 4),
      ))!;
      Uint8List? seen;
      AttachTray.decodePicture = (b) async {
        seen = b;
        return img.clone();
      };
      final png = Uint8List.fromList([1, 2, 3]);
      PasteFiles.clip = () async => const [];
      PasteFiles.picture = () async => png;
      await chat(t);
      await ctrlV(t);
      expect(seen, same(png));
      expect(tray.items.single.thumb, isNotNull);
      expect(find.byType(RawImage), findsOneWidget);
      tray.clear();
      img.dispose();
    });

    testWidgets('words on the clipboard paste as words, files go before a '
        'picture', (t) async {
      var asked = 0;
      PasteFiles.picture = () async {
        asked++;
        return null;
      };
      final copied = <String>[];
      PasteFiles.clip = () async => copied;
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'Clipboard.getData') return {'text': 'hi'};
        if (c.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      });
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await chat(t);
      await ctrlV(t);
      expect(words.text, 'hi');
      expect(tray.isEmpty, isTrue);
      expect(asked, 1);
      // files copied: they go, and no picture is asked for
      copied.add(file('copied.pdf').path);
      PasteFiles.picture = () async => Uint8List.fromList([1]);
      await ctrlV(t);
      expect([for (final x in tray.items) x.name], ['copied.pdf']);
    });

    testWidgets('a picture pasted while the app is locked does nothing', (
      t,
    ) async {
      var asked = 0;
      PasteFiles.clip = () async => const [];
      PasteFiles.picture = () async {
        asked++;
        return Uint8List.fromList([1, 2, 3]);
      };
      await chat(t);
      lockState.openForTest(enabled: true);
      lockState.lock();
      await ctrlV(t);
      expect(tray.isEmpty, isTrue);
      expect(asked, 0);
      // nor one that lands after a lock came while it was read
      lockState.openForTest();
      PasteFiles.picture = () async {
        lockState.openForTest(enabled: true);
        lockState.lock();
        return Uint8List.fromList([1, 2, 3]);
      };
      await ctrlV(t);
      expect(tray.isEmpty, isTrue);
      await tray.addPicture(Uint8List.fromList([1]), most: _fifty);
      expect(tray.isEmpty, isTrue);
    });

    testWidgets('a pasted picture too big, or one past ten, stays out with '
        'a line', (t) async {
      await chat(t);
      await tray.addPicture(Uint8List(4096), most: () async => 1024);
      await t.pumpAndSettle();
      expect(tray.isEmpty, isTrue);
      expect(find.textContaining('kb'), findsOneWidget);
      for (var i = 0; i < kDragInMost; i++) {
        await tray.addPicture(Uint8List.fromList([i + 1]), most: _fifty);
      }
      expect(tray.line, isNull);
      await tray.addPicture(Uint8List.fromList([99]), most: _fifty);
      expect(tray.items.length, kDragInMost);
      expect(tray.line, l10n.mediaSendUpTo('10'));
      expect(tray.warns, isTrue);
    });

    testWidgets('enter sends the row with the caption; shift and enter is a '
        'new line', (t) async {
      await chat(t);
      await _drop(t, [
        file('a.jpg').path,
        file('doc.pdf').path,
        file('b.png').path,
      ]);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'look');
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent, isEmpty);
      expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
      await t.pumpAndSettle();
      expect(sent, ['album:a.jpg', 'album:b.png', 'file:doc.pdf:']);
      expect(tray.isEmpty, isTrue);
      expect(find.byKey(const ValueKey('attach-tray')), findsNothing);
    });

    testWidgets('a file too big shows a line and stays out', (t) async {
      await chat(t);
      await tray.add([file('huge.iso', 4096).path], most: () async => 1024);
      await t.pumpAndSettle();
      expect(tray.isEmpty, isTrue);
      expect(find.byKey(const ValueKey('attach-tray-line')), findsOneWidget);
      expect(find.textContaining('kb'), findsOneWidget);
    });

    testWidgets('a stranger\'s row says photos and files wait', (t) async {
      await chat(t);
      tray.say(l10n.requestSenderMediaLater);
      await t.pumpAndSettle();
      expect(find.text(l10n.requestSenderMediaLater), findsOneWidget);
      expect(tray.isEmpty, isTrue);
    });

    testWidgets('a row emptied leaves another chat\'s row as it was', (
      t,
    ) async {
      await chat(t);
      final other = DeskTrays.of('everyday|river');
      await other.add([file('theirs.pdf').path], most: _fifty);
      await _drop(t, [file('mine.pdf').path]);
      await t.pumpAndSettle();
      expect(tray.isEmpty, isFalse);
      tray.clear();
      await t.pumpAndSettle();
      expect(find.text('mine.pdf'), findsNothing);
      expect([for (final x in other.items) x.name], ['theirs.pdf']);
    });

    testWidgets('reduced motion: the row comes and goes at once', (t) async {
      await chat(t, still: true);
      final size = t.widget<AnimatedSize>(find.byType(AnimatedSize));
      expect(size.duration, Duration.zero);
    });

    testWidgets('the wash says a drop adds', (t) async {
      await chat(t);
      expect(find.text('Drop here to add'), findsOneWidget);
    });
  });
}
