// SPDX-License-Identifier: GPL-3.0-or-later
// on a computer enter sends and shift and enter starts a new line in every
// composer: a chat's and a group's (composer_cursor_test), the caption
// (media_send_screen_test), note to self and the edit sheet here. a field
// that is no composer keeps its own enter, and the phone keeps its
// keyboard's. files dropped or pasted on note to self wait in the row
// above the bar, as in a chat, and enter keeps each as a note, the dropped
// file only read
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/attach_tray.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/screens/group_chat_screen.dart' show showGroupEditSheet;
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/enter_sends.dart';
import 'package:shared_preferences/shared_preferences.dart';

// note to self's rows, kept as the session writes them
class _Db implements HaloDb {
  final notes = <Map<String, Object?>>[];
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      peerId == kNotesPeerId ? [...notes] : [];
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #saveMessage) {
      notes.add({
        'rowid': notes.length + 1,
        'msg_uid': 'n${notes.length + 1}',
        'plaintext': i.positionalArguments[2],
        'file_path': i.namedArguments[#filePath],
        'file_name': i.namedArguments[#fileName],
        'media_path': i.namedArguments[#mediaPath],
        'sent_at': DateTime.now().millisecondsSinceEpoch,
      });
      return Future<void>.value();
    }
    throw UnimplementedError('${i.memberName}');
  }
}

Widget _host(Widget home) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void _window(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<_Db> _notes(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  setL10nLocale(const Locale('en'));
  final db = _Db();
  useDatabasesForTest(db, Session(db));
  _window(t);
  await t.pumpWidget(_host(const NotesScreen()));
  await t.pump(const Duration(seconds: 1));
  return db;
}

Future<void> _drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() {
    onDesktop = false;
    AttachTray.decode = decodeTrayThumb;
    PasteFiles.clip = clipboardFiles;
    DeskTrays.clearAll();
  });

  testWidgets('note to self: enter keeps the note, shift and enter is a '
      'new line', (t) async {
    onDesktop = true;
    final db = await _notes(t);
    await t.enterText(find.byType(TextField), 'buy bread');
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(db.notes, isEmpty);
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await t.pump(const Duration(milliseconds: 500));
    expect(db.notes.map((n) => n['plaintext']), ['buy bread']);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    await _drain(t);
  });

  testWidgets('note to self on a phone: enter is the keyboard\'s', (t) async {
    final db = await _notes(t);
    await t.enterText(find.byType(TextField), 'buy bread');
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
    expect(db.notes, isEmpty);
    await _drain(t);
  });

  // the notes' media folder for [t], under a folder of its own
  Directory folder(WidgetTester t) {
    final dir = Directory.systemTemp.createTempSync('notes_drop');
    addTearDown(() => dir.deleteSync(recursive: true));
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      ),
    );
    return dir;
  }

  // cleaned off the ui thread: real time passes for it
  Future<void> kept(WidgetTester t, _Db db, int n) async {
    for (var i = 0; i < 200 && db.notes.length < n; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('files dropped on note to self wait in the row; enter keeps '
      'each, a photo as a photo, the words with the first', (t) async {
    onDesktop = true;
    DesktopDrop.scale = () => 1;
    AttachTray.decode = (_) async => null;
    final dir = folder(t);
    final db = await _notes(t);
    final f = File('${dir.path}/list.txt')..writeAsStringSync('p');
    final photo = File('test/fixtures/photo_512.jpg').copySync(
      '${dir.path}/view.jpg',
    );
    Future<void> say(String method, Object? args) async {
      await t.binding.defaultBinaryMessenger.handlePlatformMessage(
        DesktopDrop.channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
      await t.pump();
    }

    // while held: the line on the wash says it is kept, not sent
    await say('updated', [500.0, 400.0]);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text(l10n.notesDropToKeep), findsOneWidget);
    expect(find.text(l10n.chatDropHereToSend), findsNothing);
    await say('dropped', [
      [f.path, photo.path],
      500.0,
      400.0,
    ]);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
    // staged, nothing kept yet
    expect(find.byKey(const ValueKey('attach-tray')), findsOneWidget);
    expect(find.text('list.txt'), findsOneWidget);
    expect(db.notes, isEmpty);
    // the save is lit with nothing written
    expect(find.bySemanticsLabel(l10n.commonSave), findsOneWidget);
    await t.enterText(find.byType(TextField), 'for later');
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await kept(t, db, 2);
    expect(db.notes, hasLength(2));
    final file = db.notes.first;
    expect(file['file_name'], 'list.txt');
    expect(file['plaintext'], 'for later');
    final copy = file['file_path'] as String;
    expect(copy, isNot(f.path));
    expect(File(copy).readAsStringSync(), 'p');
    // the photo is a photo, not a file
    final pic = db.notes.last;
    expect(pic['media_path'], isNotNull);
    expect(pic['file_path'], isNull);
    expect(pic['plaintext'], '');
    // the row is empty, the dropped files left as they were
    expect(find.byKey(const ValueKey('attach-tray')), findsNothing);
    expect(f.readAsStringSync(), 'p');
    expect(photo.existsSync(), isTrue);
    await _drain(t);
  });

  testWidgets('ctrl and v of files copied in a file manager stages them in '
      'note to self', (t) async {
    onDesktop = true;
    AttachTray.decode = (_) async => null;
    final dir = folder(t);
    final f = File('${dir.path}/plan.pdf')..writeAsStringSync('%PDF-1.4');
    PasteFiles.clip = () async => [f.path];
    final db = await _notes(t);
    await t.tap(find.byType(TextField));
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyV);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('plan.pdf'), findsOneWidget);
    expect(db.notes, isEmpty);
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await kept(t, db, 1);
    expect(db.notes.single['file_name'], 'plan.pdf');
    await _drain(t);
  });

  testWidgets('the group edit sheet: enter saves on a computer', (t) async {
    onDesktop = true;
    _window(t);
    setL10nLocale(const Locale('en'));
    late BuildContext ctx;
    await t.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    final got = showGroupEditSheet(ctx, 'old words');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'new words');
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(await t.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await t.pumpAndSettle();
    expect(await got, 'new words');
  });

  test('every composer goes through the one enter rule', () {
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
      'lib/screens/notes_screen.dart',
      'lib/screens/media_send_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('EnterSends('), reason: f);
      // and no screen reads enter on its own
      expect(src, isNot(contains('LogicalKeyboardKey.enter')), reason: f);
    }
    // the rule itself is in one place
    expect(
      File('lib/widgets/enter_sends.dart').readAsStringSync(),
      contains('class EnterSends'),
    );
    expect(EnterSends, isNotNull);
  });
}
