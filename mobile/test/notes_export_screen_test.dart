// SPDX-License-Identifier: GPL-3.0-or-later
// the notes menu offers export in the everyday notes and a decoy's, the same
// menu in both, and never with hidden chats open. a decoy exports its own
// notes, as slowly as anywhere. the export page asks for a passphrase by the
// backup's rules, turns it off only past a plain warning, and goes through the
// backup's save window. a save backed out of, or a lock while the file is
// made, leaves no file in the app. a locked export needs the engine built
// for this computer
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        navRevision,
        renewRootNavigator,
        rootNavKey,
        useDatabasesForTest;
import 'package:kryfo/lock_guard.dart' show lockGuard;
import 'package:kryfo/notes_export.dart' show dropNotesExports, kNotesOut;
import 'package:kryfo/screens/notes_export_screen.dart';
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/message_menu.dart' show MenuSheet;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'host_engine.dart';
import 'pin_flow_fakes.dart' show phone, press;

class _Db implements HaloDb {
  _Db([this.container = HaloContainer.everyday]);
  List<Map<String, Object?>> notes = [];
  @override
  final HaloContainer container;
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      peerId == kNotesPeerId ? [...notes] : [];
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: <String, bool>{}, groups: <String>{});
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = loadHostEngine();
  late Directory tmp;
  late _Db db;
  late List<String> asked;
  late List<Completer<Object?>> dialogs;
  // how the share sheet ends: picked, closed, or failed to open
  late String shares;
  late List<Map<Object?, Object?>> shared;
  late List<List<int>> saved;
  // android's copy as a lock finds it, and what it was told
  late String stage;
  late int stopping;
  late List<Object?> cancels;
  late List<bool> intactAtCancel;

  setUp(() {
    asked = [];
    dialogs = [];
    shares = 'picked';
    shared = [];
    saved = [];
    stage = 'idle';
    stopping = 0;
    cancels = [];
    intactAtCancel = [];
    String? saving;
    var taken = false;
    tmp = Directory.systemTemp.createTempSync('notes_export_screen');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp.path,
    );
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (
      call,
    ) async {
      asked.add(call.method);
      switch (call.method) {
        case 'saveDocument':
          // what the save window would copy, read as it opens
          final path = (call.arguments as Map)['path'] as String;
          saving = path;
          taken = false;
          saved.add(File(path).readAsBytesSync());
          final d = Completer<Object?>();
          dialogs.add(d);
          // a copy a drop reached fails, whatever it got to
          return d.future.then(
            (a) => taken ? {'state': 'failed', 'where': null} : a,
          );
        case 'saveDocumentState':
          final now = stage;
          // a stopped copy ends a beat later
          if (stopping > 0 && --stopping == 0) stage = 'idle';
          return {'stage': now, 'copied': 0};
        case 'saveDocumentCancel':
          cancels.add(call.arguments);
          final f = File(saving ?? '');
          intactAtCancel.add(
            f.existsSync() && listEquals(f.readAsBytesSync(), saved.lastOrNull),
          );
          if (stage == 'copying') {
            stopping = 2;
            if ((call.arguments as Map?)?['drop'] == true) taken = true;
          }
          return stage;
        case 'shareFile':
          shared.add(call.arguments as Map<Object?, Object?>);
          return shares;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({'notes_hold_told': true});
    db = _Db()
      ..notes = [
        {
          'rowid': 1,
          'msg_uid': 'n1',
          'plaintext': 'the code is under the mat',
          'sent_at': DateTime(2026, 10, 13, 9).millisecondsSinceEpoch,
        },
      ];
    useDatabasesForTest(db, Session(db));
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    setL10nLocale(const Locale('en'));
  });

  tearDown(() {
    lockState.inDecoy = false;
    lockState.openForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    tmp.deleteSync(recursive: true);
  });

  Directory outDir() => Directory(p.join(tmp.path, kNotesOut));
  List<String> left() => outDir().existsSync()
      ? [for (final f in outDir().listSync(recursive: true)) p.basename(f.path)]
      : [];

  Future<void> beats(WidgetTester t, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> until(
    WidgetTester t,
    bool Function() done, [
    int n = 400,
  ]) async {
    for (var i = 0; i < n && !done(); i++) {
      await beats(t, 1);
    }
  }

  Future<void> app(WidgetTester t, Widget home, {ThemeData? theme}) async {
    phone(t);
    await t.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: navRevision,
        builder: (_, _, _) => MaterialApp(
          navigatorKey: rootNavKey,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  // the rows of the notes menu, as they read
  Future<List<String>> menu(WidgetTester t) async {
    await app(t, const NotesScreen());
    await t.tap(find.byTooltip(l10n.notesMenu));
    await t.pumpAndSettle();
    final rows = [
      for (final e
          in find
              .descendant(
                of: find.byType(MenuSheet),
                matching: find.byType(Text),
              )
              .evaluate())
        (e.widget as Text).data ?? '',
    ];
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    return rows;
  }

  group('where it is offered', () {
    testWidgets('the everyday notes have it', (t) async {
      expect(notesExportHere(), isTrue);
      expect(await menu(t), contains(l10n.notesExportNotes));
    });

    testWidgets('a decoy\'s menu is the everyday one', (t) async {
      final everyday = await menu(t);
      final decoy = _Db(HaloContainer.decoy)..notes = db.notes;
      useDatabasesForTest(decoy, Session(decoy));
      lockState.inDecoy = true;
      expect(notesExportHere(), isTrue);
      expect(await menu(t), everyday);
      expect(everyday, contains(l10n.notesExportNotes));
    });

    testWidgets('open hidden chats have none', (t) async {
      final vault = _Db(HaloContainer.vault);
      useDatabasesForTest(db, await Session.withVault(db, vault));
      expect(notesExportHere(), isFalse);
      expect(await menu(t), isNot(contains(l10n.notesExportNotes)));
    });

    testWidgets('the menu row opens the page', (t) async {
      await app(t, const NotesScreen());
      await t.tap(find.byTooltip(l10n.notesMenu));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.notesExportNotes));
      await t.pumpAndSettle();
      expect(find.byType(NotesExportScreen), findsOneWidget);
      expect(find.text(l10n.notesExportCount(1)), findsOneWidget);
    });
  });

  Future<void> page(WidgetTester t) async {
    await app(
      t,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(builder: (_) => const NotesExportScreen()),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Future<void> typePass(WidgetTester t, String a, [String? b]) async {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), a);
    await t.enterText(fields.at(1), b ?? a);
    await t.pump();
  }

  final screen = find.byType(NotesExportScreen);

  testWidgets('the passphrase follows the backup rules', (t) async {
    await page(t);
    await typePass(t, 'eleven char');
    expect(find.text(l10n.lockWordsTooShortAtLeast(12)), findsOneWidget);
    await press(t, find.text(l10n.notesExport));
    await t.pump();
    expect(find.text(l10n.backupPassphraseMustBeAt), findsOneWidget);
    await typePass(t, 'a passphrase long enough', 'a passphrase long enougH');
    expect(find.text(l10n.lockFileTheTwoDoNot), findsOneWidget);
    await press(t, find.text(l10n.notesExport));
    await t.pump();
    expect(find.text(l10n.backupPassphrasesDonTMatch), findsOneWidget);
    expect(asked, isNot(contains('saveDocument')));
    expect(left(), isEmpty);
    await t.pumpAndSettle();
  });

  testWidgets('plain only past the warning, kept when kept', (t) async {
    await page(t);
    final sw = find.byType(Switch).evaluate().isEmpty
        ? find.text(l10n.notesExportLock)
        : find.byType(Switch);
    await t.tap(sw);
    await t.pumpAndSettle();
    expect(find.text(l10n.notesExportPlainTitle), findsOneWidget);
    await t.tap(find.text(l10n.notesExportKeepLock));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await t.tap(sw);
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.notesExportPlainYes));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text(l10n.notesExportPlainLine), findsOneWidget);
  });

  Future<void> plain(WidgetTester t) async {
    await page(t);
    await t.tap(find.text(l10n.notesExportLock));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.notesExportPlainYes));
    await t.pumpAndSettle();
    await press(t, find.text(l10n.notesExport));
    await until(t, () => dialogs.isNotEmpty);
    expect(dialogs, hasLength(1));
  }

  testWidgets('saved: a toast, and the file is gone', (t) async {
    await plain(t);
    expect(left(), hasLength(1));
    dialogs.single.complete({'state': 'saved', 'where': 'Download'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(find.text(l10n.notesExportSavedIn('Download')), findsOneWidget);
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('backed out: the share sheet, then nothing left', (t) async {
    await plain(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(asked, containsAllInOrder(['saveDocument', 'shareFile']));
    // plaintext shared goes with the next lock
    expect(shared.single['quiet'], isTrue);
    expect(shared.single['name'], endsWith('.txt'));
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('backed out with no share sheet: no plaintext once left', (
    t,
  ) async {
    shares = 'failed';
    await plain(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.notesExportNotSaved), findsOneWidget);
    expect(find.text(l10n.backupShareInstead), findsOneWidget);
    // kept in the app's own cache for another go
    expect(left(), hasLength(1));
    await t.pageBack();
    await t.pumpAndSettle();
    await until(t, () => left().isEmpty);
    expect(screen, findsNothing);
    expect(left(), isEmpty);
  });

  testWidgets('an export holding an app installer says why it is not '
      'shared, and saves', (t) async {
    final apk = File(p.join(tmp.path, 'tool.apk'))
      ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
    db.notes = [
      ...db.notes,
      {
        'plaintext': 'the app',
        'sent_at': 2,
        'file_path': apk.path,
        'file_name': 'tool.apk',
      },
    ];
    await plain(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(
      t,
      () => find.text(l10n.notesExportHoldsInstaller).evaluate().isNotEmpty,
    );
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    expect(asked, isNot(contains('shareFile')));
    expect(find.text(l10n.notesExportHoldsInstaller), findsOneWidget);
    expect(find.text(l10n.notesExportNotSaved), findsNothing);
    expect(find.text(l10n.backupShareInstead), findsNothing);
    expect(left(), hasLength(1));
    // the save window again, and saved this time
    await t.tap(find.text(l10n.commonTryAgain));
    await until(t, () => dialogs.length == 2);
    dialogs.last.complete({'state': 'saved', 'where': 'Download'});
    await until(t, () => screen.evaluate().isEmpty);
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a share sheet closed with nothing picked keeps the file', (
    t,
  ) async {
    shares = 'closed';
    await plain(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    expect(screen, findsOneWidget);
    expect(find.text(l10n.notesExportNotSaved), findsOneWidget);
    expect(find.text(l10n.commonTryAgain), findsOneWidget);
    expect(find.text(l10n.backupShareInstead), findsOneWidget);
    expect(left(), hasLength(1));
    // both are offered again, and a pick this time lets the file go
    shares = 'picked';
    await t.tap(find.text(l10n.backupShareInstead));
    await until(t, () => screen.evaluate().isEmpty);
    expect(shared, hasLength(2));
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('locked: only the locked file waits, and nothing once left', (
    t,
  ) async {
    shares = 'closed';
    await page(t);
    await typePass(t, 'four random words here');
    await press(t, find.text(l10n.notesExport));
    await until(t, () => dialogs.isNotEmpty, 1000);
    expect(dialogs, hasLength(1));
    final waiting = left();
    expect(waiting, hasLength(1));
    expect(waiting.single, endsWith('.age'));
    final bytes = await t.runAsync(
      () => File(p.join(outDir().path, waiting.single)).readAsBytes(),
    );
    expect(String.fromCharCodes(bytes!.take(21)), 'age-encryption.org/v1');
    // the fields were emptied once the file was made
    for (final e in find.byType(TextField).evaluate()) {
      expect((e.widget as TextField).controller!.text, isEmpty);
    }
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    // a locked copy keeps its grace
    expect(shared.single['quiet'], isFalse);
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    await t.pageBack();
    await t.pumpAndSettle();
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
  }, skip: !engine);

  // a lock or a switch to another pin takes the page while the file is
  // made: nothing of it stays, and no save window opens
  Future<void> lockMidway(WidgetTester t) async {
    // a file is being written when the lock comes
    await until(t, () => left().isNotEmpty);
    expect(find.text(l10n.notesExportWorking), findsOneWidget);
    renewRootNavigator();
    await t.pump();
    await until(t, () => left().isEmpty, 1000);
    await beats(t);
    expect(screen, findsNothing);
    expect(left(), isEmpty);
    expect(asked, isNot(contains('saveDocument')));
    await t.pumpAndSettle();
  }

  void bigPhoto(_Db into, [int size = 256 << 20]) {
    final big = File(p.join(tmp.path, 'big.jpg'));
    final raf = big.openSync(mode: FileMode.write)
      ..setPositionSync(size)
      ..writeByteSync(1);
    raf.closeSync();
    into.notes = [
      ...into.notes,
      {'plaintext': 'photo', 'sent_at': 2, 'media_path': big.path},
    ];
  }

  Future<void> plainStart(WidgetTester t) async {
    await page(t);
    await t.tap(find.text(l10n.notesExportLock));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.notesExportPlainYes));
    await t.pumpAndSettle();
    await press(t, find.text(l10n.notesExport));
    await t.pump();
  }

  testWidgets('a lock before the file is begun leaves nothing', (t) async {
    bigPhoto(db);
    await plainStart(t);
    renewRootNavigator();
    await t.pump();
    await beats(t, 100);
    await until(t, () => left().isEmpty, 1000);
    expect(left(), isEmpty);
    expect(asked, isNot(contains('saveDocument')));
  });

  testWidgets('a lock while a plain zip is made leaves nothing', (t) async {
    bigPhoto(db);
    await plainStart(t);
    await lockMidway(t);
  });

  testWidgets('a lock while a locked file is made leaves nothing', (t) async {
    await page(t);
    await typePass(t, 'four random words here');
    await press(t, find.text(l10n.notesExport));
    await t.pump();
    await lockMidway(t);
  }, skip: !engine);

  // the same pin locks and opens again: the page stays, its file does not
  Future<void> lockAndBack(WidgetTester t) async {
    lockState.lock();
    expect(lockState.locked, isTrue);
    var dropped = false;
    final watch = Stopwatch()..start();
    unawaited(dropNotesExports(tmp).then((_) => dropped = true));
    await until(t, () => dropped, 250);
    expect(dropped, isTrue);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(left(), isEmpty);
    lockState.openForTest(enabled: true);
    lockGuard.lifted();
    await beats(t, 20);
  }

  testWidgets('a lock while the file is made stops it at once', (t) async {
    bigPhoto(db, 2 << 30);
    await plainStart(t);
    await until(t, () => left().isNotEmpty);
    expect(find.text(l10n.notesExportWorking), findsOneWidget);
    await lockAndBack(t);
    expect(screen, findsOneWidget);
    expect(find.text(l10n.notesExportGone), findsOneWidget);
    expect(find.text(l10n.notesExport), findsOneWidget);
    expect(asked, isNot(contains('saveDocument')));
    expect(left(), isEmpty);
    await t.pumpAndSettle();
  });

  testWidgets('a file a lock took is not offered, a new one is', (t) async {
    shares = 'failed';
    await plain(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.notesExportNotSaved), findsOneWidget);
    // the share sheet's hold has run out
    await t.pump(const Duration(seconds: 3));
    await lockAndBack(t);
    await t.pumpAndSettle();
    expect(screen, findsOneWidget);
    expect(find.text(l10n.notesExportGone), findsOneWidget);
    expect(find.text(l10n.notesExportNotSaved), findsNothing);
    expect(find.text(l10n.backupShareInstead), findsNothing);
    expect(asked.where((m) => m == 'saveDocument'), hasLength(1));
    // exported again: a new file, and the save window for it
    await press(t, find.text(l10n.notesExport));
    await until(t, () => dialogs.length > 1);
    expect(dialogs, hasLength(2));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.notesExportGone), findsNothing);
    expect(left(), hasLength(1));
    dialogs.last.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  List<String> typed() => [
    for (final e in find.byType(TextField).evaluate())
      (e.widget as TextField).controller!.text,
  ];

  testWidgets('a lock clears the typed passphrase', (t) async {
    await page(t);
    await typePass(t, 'four random words here');
    expect(typed(), ['four random words here', 'four random words here']);
    await lockAndBack(t);
    await t.pumpAndSettle();
    expect(screen, findsOneWidget);
    expect(typed(), ['', '']);
    expect(find.text(l10n.notesExportGone), findsNothing);
    expect(left(), isEmpty);
  });

  testWidgets('a lock while a locked file is made clears the words too', (
    t,
  ) async {
    bigPhoto(db, 2 << 30);
    await page(t);
    await typePass(t, 'four random words here');
    await press(t, find.text(l10n.notesExport));
    await t.pump();
    await until(t, () => left().isNotEmpty);
    expect(find.text(l10n.notesExportWorking), findsOneWidget);
    await lockAndBack(t);
    await t.pumpAndSettle();
    expect(find.text(l10n.notesExportGone), findsOneWidget);
    expect(typed(), ['', '']);
    expect(asked, isNot(contains('saveDocument')));
    expect(left(), isEmpty);
  });

  testWidgets('a lock in the save window: a failed save is not retried', (
    t,
  ) async {
    await plain(t);
    expect(left(), hasLength(1));
    // the person left the save window open and the lock took the file
    var dropped = false;
    unawaited(dropNotesExports(tmp).then((_) => dropped = true));
    await until(t, () => dropped);
    expect(left(), isEmpty);
    dialogs.single.complete({'state': 'failed'});
    await beats(t);
    await t.pumpAndSettle();
    expect(screen, findsOneWidget);
    expect(find.text(l10n.notesExportGone), findsOneWidget);
    expect(find.text(l10n.notesExportNotSaved), findsNothing);
    expect(find.text(l10n.commonTryAgain), findsNothing);
    expect(find.text(l10n.backupShareInstead), findsNothing);
    expect(asked, isNot(contains('shareFile')));
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a lock during the save copy: gone, never saved', (t) async {
    await plain(t);
    expect(left(), hasLength(1));
    // the person picked a place and android is copying when the lock comes
    stage = 'copying';
    var dropped = false;
    unawaited(dropNotesExports(tmp).then((_) => dropped = true));
    await until(t, () => dropped);
    // the copy was told before a byte was zeroed, and ended before the shred
    expect(cancels, [
      {'drop': true},
    ]);
    expect(intactAtCancel, [true]);
    expect(stage, 'idle');
    expect(left(), isEmpty);
    // the copy android was running ends failed, never saved
    dialogs.single.complete({'state': 'saved', 'where': 'Download'});
    await beats(t);
    await t.pumpAndSettle();
    expect(screen, findsOneWidget);
    expect(find.text(l10n.notesExportGone), findsOneWidget);
    expect(find.text(l10n.notesExportSaved), findsNothing);
    expect(find.text(l10n.notesExportSavedIn('Download')), findsNothing);
    expect(find.text(l10n.notesExportSavedUnchecked), findsNothing);
    expect(find.text(l10n.commonTryAgain), findsNothing);
    expect(asked, isNot(contains('shareFile')));
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a lock just after the save copy: still saved', (t) async {
    await plain(t);
    expect(left(), hasLength(1));
    // every byte went out and android's answer is on its way
    var dropped = false;
    unawaited(dropNotesExports(tmp).then((_) => dropped = true));
    await until(t, () => dropped);
    expect(cancels, [
      {'drop': true},
    ]);
    expect(left(), isEmpty);
    dialogs.single.complete({'state': 'saved', 'where': 'Download'});
    await beats(t);
    await t.pumpAndSettle();
    expect(find.text(l10n.notesExportSavedIn('Download')), findsOneWidget);
    expect(find.text(l10n.notesExportGone), findsNothing);
    expect(asked, isNot(contains('shareFile')));
    await until(t, () => screen.evaluate().isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('undo does not bring the words back after a lock', (t) async {
    await page(t);
    await typePass(t, 'four random words here');
    await t.pump(const Duration(seconds: 1));
    await lockAndBack(t);
    await t.pumpAndSettle();
    expect(typed(), ['', '']);
    // a keyboard's ctrl+z, twice in each field
    for (final i in [0, 1]) {
      await t.showKeyboard(find.byType(TextField).at(i));
      await t.pump(const Duration(seconds: 1));
      for (var n = 0; n < 2; n++) {
        await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await t.pump();
      }
    }
    expect(typed(), ['', '']);
  });

  // a decoy with notes of its own, open in place of the everyday ones
  _Db intoDecoy() {
    final decoy = _Db(HaloContainer.decoy)
      ..notes = [
        {
          'rowid': 1,
          'msg_uid': 'd1',
          'plaintext': 'eggs and coffee',
          'sent_at': DateTime(2026, 10, 12, 8).millisecondsSinceEpoch,
        },
      ];
    useDatabasesForTest(decoy, Session(decoy));
    lockState.inDecoy = true;
    return decoy;
  }

  testWidgets('a decoy exports its own notes, never the everyday ones', (
    t,
  ) async {
    intoDecoy();
    await plain(t);
    final text = String.fromCharCodes(saved.single);
    expect(text, contains('eggs and coffee'));
    expect(text, isNot(contains('under the mat')));
    dialogs.single.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    await until(t, () => left().isEmpty);
    expect(left(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a lock while a decoy export is made leaves nothing', (t) async {
    bigPhoto(intoDecoy());
    await plainStart(t);
    await lockMidway(t);
  });

  // the scrypt work in a locked file's header: the same in a decoy, so it
  // takes as long there as anywhere
  Future<String> lockedHeader(WidgetTester t) async {
    shares = 'closed';
    await page(t);
    await typePass(t, 'four random words here');
    await press(t, find.text(l10n.notesExport));
    await until(t, () => dialogs.isNotEmpty, 1000);
    final head = String.fromCharCodes(saved.single.take(200));
    dialogs.single.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    await until(t, () => left().isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
    return RegExp(r'-> scrypt \S+ (\d+)').firstMatch(head)!.group(1)!;
  }

  testWidgets('a decoy export does the same work as an everyday one', (
    t,
  ) async {
    final everyday = await lockedHeader(t);
    saved.clear();
    dialogs.clear();
    intoDecoy();
    expect(await lockedHeader(t), everyday);
    expect(everyday, '18');
  }, skip: !engine);

  for (final (name, locale, dark) in [
    ('arabic, dark', const Locale('ar'), true),
    ('persian, light', const Locale('fa'), false),
    ('german, dark', const Locale('de'), true),
  ]) {
    testWidgets('the page fits: $name', (t) async {
      setL10nLocale(locale);
      HaloColors.setLight(!dark);
      addTearDown(() => HaloColors.setLight(false));
      phone(t);
      t.view.physicalSize = const Size(720, 1280);
      t.view.devicePixelRatio = 2;
      await t.pumpWidget(
        MaterialApp(
          locale: locale,
          theme: buildHaloTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const NotesExportScreen(),
        ),
      );
      await t.pumpAndSettle();
      final ex = t.takeException();
      if (ex != null) debugPrint((ex as FlutterError).toStringDeep());
      expect(ex, isNull);
      expect(find.text(l10n.notesExportNotes), findsOneWidget);
      if (locale.languageCode != 'de') {
        expect(
          Directionality.of(t.element(find.text(l10n.notesExportLock))),
          TextDirection.rtl,
        );
      }
      await t.tap(find.text(l10n.notesExportLock));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.notesExportPlainYes));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      setL10nLocale(const Locale('en'));
    });
  }
}
