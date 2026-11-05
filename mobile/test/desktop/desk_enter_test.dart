// SPDX-License-Identifier: GPL-3.0-or-later
// on a computer enter sends and shift and enter starts a new line in every
// composer: a chat's and a group's (composer_cursor_test), the caption
// (media_send_screen_test), note to self and the edit sheet here. a field
// that is no composer keeps its own enter, and the phone keeps its
// keyboard's. a file dropped on note to self is kept there, the dropped
// file only read
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
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
  tearDown(() => onDesktop = false);

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

  testWidgets('a file dropped on note to self is kept there', (t) async {
    onDesktop = true;
    DesktopDrop.scale = () => 1;
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
    final db = await _notes(t);
    final f = File('${dir.path}/list.txt')..writeAsStringSync('p');
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
      [f.path],
      500.0,
      400.0,
    ]);
    // cleaned off the ui thread: real time passes for it
    for (var i = 0; i < 200 && db.notes.isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 300));
    // a copy in the notes' media folder under the name it had, the file
    // dropped left as it was
    expect(db.notes, hasLength(1));
    expect(db.notes.single['file_name'], 'list.txt');
    final kept = db.notes.single['file_path'] as String;
    expect(kept, isNot(f.path));
    expect(File(kept).readAsStringSync(), 'p');
    expect(f.readAsStringSync(), 'p');
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
