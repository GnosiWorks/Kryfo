// SPDX-License-Identifier: GPL-3.0-or-later
// note to self's page with photos and files: a photo at its own shape with
// its words under it, a file's card; the bar's paperclip, and its mic while
// nothing is written; the lines say "all your devices" once a device of
// mine is linked; files a computer copied paste as files, words as words;
// with reduced motion the bar crossfades and nothing grows
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/own_sync.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        ownApplyForTest,
        ownSyncForTest,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/note_media.dart';
import 'package:kryfo/widgets/photo_shape.dart';
import 'package:kryfo/widgets/voice_mic.dart' show HoldToTalkMic;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

class _Db implements HaloDb {
  _Db(this.notes);
  final List<Map<String, Object?>> notes;
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      peerId == kNotesPeerId ? [...notes] : [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoState implements DeviceState {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoSend implements DeviceSend {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Mine extends OwnSync {
  _Mine()
    : super(
        state: _NoState(),
        db: () async => throw StateError('none'),
        send: _NoSend(),
        me: (_) async => null,
        apply: ownApplyForTest,
      );
  @override
  Future<List<OwnPeer>> others(int ident) async => [(id: 4, key: 'k', reg: 1)];
}

Widget _host(Widget home, {bool still = false}) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: still
      ? Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: home,
          ),
        )
      : home,
);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('notes_media');
    SharedPreferences.setMockInitialValues({'notes_hold_told': true});
    setL10nLocale(const Locale('en'));
  });

  tearDown(() {
    ownSyncForTest(null);
    linkedDevicesForTest = false;
    forgetPhotoAspects();
    dir.deleteSync(recursive: true);
  });

  Future<void> page(
    WidgetTester t,
    List<Map<String, Object?>> notes, {
    bool still = false,
  }) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final db = _Db(notes);
    useDatabasesForTest(db, Session(db));
    await t.pumpWidget(_host(const NotesScreen(), still: still));
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> drain(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('a photo sits at its own shape with its words under it, a '
      'file as its card', (t) async {
    final photo = p.join(dir.path, 'wide.jpg');
    File('test/fixtures/photo_512.jpg').copySync(photo);
    rememberPhotoAspect(photo, 2);
    final file = p.join(dir.path, 'f_x.pdf');
    File(file).writeAsStringSync('%PDF-1.4');
    final now = DateTime.now().millisecondsSinceEpoch;
    await page(t, [
      {
        'rowid': 1,
        'msg_uid': 'a',
        'plaintext': 'the view',
        'media_path': photo,
        'sent_at': now,
      },
      {
        'rowid': 2,
        'msg_uid': 'b',
        'plaintext': '',
        'file_path': file,
        'file_name': 'plan.pdf',
        'sent_at': now,
      },
    ]);
    expect(find.byType(NoteMedia), findsNWidgets(2));
    final box = t.getSize(find.byType(PhotoShape));
    expect(box.width / box.height, closeTo(2, 0.01));
    // the words wrap at the photo's width, under it
    final words = t.getRect(find.text('the view'));
    expect(words.top, greaterThan(t.getRect(find.byType(PhotoShape)).bottom));
    expect(find.textContaining('plan'), findsWidgets);
    await drain(t);
  });

  testWidgets('the bar: a paperclip, the mic while nothing is written, the '
      'save once words are', (t) async {
    await page(t, const []);
    expect(find.bySemanticsLabel(l10n.notesAddItem), findsOneWidget);
    expect(find.byType(HoldToTalkMic), findsOneWidget);
    await t.enterText(find.byType(TextField), 'buy bread');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(HoldToTalkMic), findsNothing);
    expect(find.bySemanticsLabel(l10n.commonSave), findsOneWidget);
    // with no device of mine: on this phone alone
    expect(find.text(l10n.notesOnlyOnThisPhone), findsOneWidget);
    await drain(t);
  });

  testWidgets('with a device of mine linked the lines say all my devices', (
    t,
  ) async {
    linkedDevicesForTest = true;
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await t.runAsync(router.load);
    useEngineForTest(_Engine());
    AppState(io: ArrivalIo(), router: router);
    ownSyncForTest(_Mine());
    await page(t, const []);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.notesOnAllDevices), findsOneWidget);
    expect(find.text(l10n.notesKeepAnything), findsOneWidget);
    expect(find.text(l10n.notesOnlyOnThisPhone), findsNothing);
    await drain(t);
  });

  testWidgets('with reduced motion the bar crossfades and nothing grows', (
    t,
  ) async {
    // the save as it comes in for the mic
    Finder grows() => find.ancestor(
      of: find.byKey(const ValueKey('save')),
      matching: find.byType(ScaleTransition),
    );
    await page(t, const [], still: true);
    await t.enterText(find.byType(TextField), 'x');
    await t.pump(const Duration(milliseconds: 50));
    expect(grows(), findsNothing);
    await drain(t);
    await page(t, const []);
    await t.enterText(find.byType(TextField), 'x');
    await t.pump(const Duration(milliseconds: 50));
    expect(grows(), findsWidgets);
    await drain(t);
  });

  test('files a computer copied paste as files; anything else as words', () {
    final a = File(p.join(dir.path, 'a.txt'))..writeAsStringSync('a');
    final b = File(p.join(dir.path, 'b c.pdf'))..writeAsStringSync('b');
    expect(pastedFiles(a.path), [a.path]);
    expect(pastedFiles('${a.path}\n${Uri.file(b.path)}\n'), [a.path, b.path]);
    // words, a path among words, one that is not there, a folder
    expect(pastedFiles('buy bread'), isEmpty);
    expect(pastedFiles('${a.path}\nbuy bread'), isEmpty);
    expect(pastedFiles(p.join(dir.path, 'gone.txt')), isEmpty);
    expect(pastedFiles(dir.path), isEmpty);
    expect(pastedFiles('relative.txt'), isEmpty);
    expect(pastedFiles(null), isEmpty);
    // more than a drop takes
    expect(pastedFiles(List.filled(11, a.path).join('\n')), isEmpty);
  });
}
