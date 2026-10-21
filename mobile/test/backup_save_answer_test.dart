// SPDX-License-Identifier: GPL-3.0-or-later
// the save dialog always ends somewhere clear: saved with a toast, the share
// sheet when it was backed out of, or a plain not-saved line with the file
// kept to try again. an answer android never hands back, a copy that
// failed or stopped moving, count as not saved. the platform is a stand-in
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show BackupError;
import 'package:kryfo/container.dart';
import 'package:kryfo/file_save.dart' show saveAnswerLine;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        navRevision,
        renewRootNavigator,
        rootNavKey,
        useDatabasesForTest;
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show phone, press;

class _Db implements HaloDb {
  _Db(this.container);
  @override
  final HaloContainer container;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late List<String> asked;
  // each save dialog, answered when the test says
  late List<Completer<Object?>> dialogs;
  late Object? Function() stage;
  // how the share sheet ends
  late String shares;
  const idle = {'stage': 'idle', 'copied': 0};

  setUp(() {
    asked = [];
    dialogs = [];
    stage = () => idle;
    shares = 'picked';
    tmp = Directory.systemTemp.createTempSync('backup_answer');
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
          final d = Completer<Object?>();
          dialogs.add(d);
          return d.future;
        case 'saveDocumentState':
          return stage();
        case 'shareFile':
          return shares;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    backupForTest = null;
    lockState.openForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    tmp.deleteSync(recursive: true);
  });

  List<File> made() => [
    for (final f in tmp.listSync().whereType<File>())
      if (f.path.contains('kryfo-backup-')) f,
  ];

  // the disk works outside the test's clock
  Future<void> beats(WidgetTester t, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  // android's steps, one at a time, as it takes them
  void life(WidgetTester t, List<AppLifecycleState> steps) {
    for (final s in steps) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
  }

  Future<void> until(WidgetTester t, bool Function() done) async {
    for (var i = 0; i < 250 && !done(); i++) {
      await beats(t, 1);
    }
  }

  Future<void> open(
    WidgetTester t, {
    bool move = false,
    bool wide = false,
    double scale = 1,
  }) async {
    phone(t);
    if (wide) t.view.physicalSize = const Size(2340, 1080);
    final live = _Db(HaloContainer.everyday);
    useDatabasesForTest(live, Session(live));
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    backupForTest = (path, progress) async {
      File(path).writeAsStringSync('made');
      progress(1, 1);
    };
    await t.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: navRevision,
        builder: (_, _, _) => MaterialApp(
          navigatorKey: rootNavKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    if (move) {
      await t.tap(find.text(l10n.backupMoveToAnotherDevice));
      await t.pumpAndSettle();
    }
    for (final f in find.byType(TextField).evaluate().toList()) {
      await t.enterText(find.byWidget(f.widget), 'a long passphrase');
    }
    await press(
      t,
      find.text(move ? l10n.backupMakeTheFileAnd : l10n.backupCreateBackup),
    );
    await until(t, () => dialogs.isNotEmpty);
    expect(dialogs, hasLength(1));
  }

  // seconds on the test's clock, as the screen waits
  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      await beats(t, 1);
    }
  }

  Future<int?> movedAt(WidgetTester t) async =>
      (await t.runAsync(SharedPreferences.getInstance))!.getInt('moved.at');

  final screen = find.byType(BackupScreen);
  final reached = find.text(l10n.backupMoveReachedTitle);
  final notSaved = find.text(l10n.backupNotSaved);
  final tryAgain = find.text(l10n.commonTryAgain);
  final shareInstead = find.text(l10n.backupShareInstead);

  void saysNotSaved() {
    expect(screen, findsOneWidget);
    expect(notSaved, findsOneWidget);
    expect(tryAgain, findsOneWidget);
    expect(shareInstead, findsOneWidget);
    expect(find.text(l10n.backupBackupSavedKeepThe), findsNothing);
    // the line is the page's own colour, never a grey
    expect(textOf(notSaved).style!.color, HaloColors.text);
  }

  testWidgets('an answer that never comes ends as not saved', (t) async {
    await open(t);
    // android is back in front and has nothing waiting or copying
    await wait(t, 20);
    saysNotSaved();
    expect(asked, isNot(contains('shareFile')));
    // the file stays for another go
    expect(made(), hasLength(1));

    // and the share sheet takes it from there
    await press(t, shareInstead);
    await until(t, () => screen.evaluate().isEmpty);
    expect(asked, contains('shareFile'));
    expect(screen, findsNothing);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a dialog left open a long while is not given up on', (t) async {
    await open(t);
    life(t, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    stage = () => {'stage': 'picking', 'copied': 0};
    await wait(t, 120);
    expect(notSaved, findsNothing);
    expect(find.text(l10n.backupSaving), findsOneWidget);
    life(t, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    dialogs.single.complete({'state': 'saved', 'where': 'Download/Kryfo'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(screen, findsNothing);
    expect(find.text(l10n.backupSavedIn('Download/Kryfo')), findsOneWidget);
    expect(asked, isNot(contains('shareFile')));
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a backed-out dialog goes to the share sheet', (t) async {
    await open(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(asked, containsAllInOrder(['saveDocument', 'shareFile']));
    expect(screen, findsNothing);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  // only the app picked knows whether it kept the file: the toast says
  // where it went and asks to check, never "saved"
  testWidgets('a backup shared to an app says it was handed over', (t) async {
    await open(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => screen.evaluate().isEmpty);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.backupHandedOver), findsOneWidget);
    expect(find.text(l10n.backupBackupSavedKeepThe), findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a place with no room says so, and the file stays for '
      'another place', (t) async {
    await open(t);
    dialogs.single.complete({'state': 'full'});
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    expect(screen, findsOneWidget);
    expect(find.text(l10n.backupNotSavedNoSpace), findsOneWidget);
    expect(notSaved, findsNothing);
    expect(tryAgain, findsOneWidget);
    expect(shareInstead, findsOneWidget);
    expect(asked, isNot(contains('shareFile')));
    expect(made(), hasLength(1));
    expect(
      textOf(find.text(l10n.backupNotSavedNoSpace)).style!.color,
      HaloColors.text,
    );

    await press(t, tryAgain);
    await until(t, () => dialogs.length == 2);
    dialogs.last.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(find.text(l10n.backupBackupSavedKeepThe), findsOneWidget);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  test('a received file with no room where it was to go says so', () {
    expect(
      saveAnswerLine((state: SaveState.full, where: null, lost: false)),
      l10n.fileNotSavedNoSpace,
    );
    expect(
      saveAnswerLine((state: SaveState.failed, where: null, lost: false)),
      l10n.fileNotSaved,
    );
  });

  test('a full phone is said as such, not as a backup that failed', () {
    expect(
      backupFailLine(
        const FileSystemException(
          'write failed',
          '/data/x',
          OSError('No space left on device', 28),
        ),
      ),
      l10n.backupNoSpace,
    );
    // the copy job hands its error back as words
    expect(
      backupFailLine(
        BackupError(
          'FileSystemException: write failed, path = /x '
          '(OS Error: No space left on device, errno = 28)',
        ),
      ),
      l10n.backupNoSpace,
    );
    expect(
      backupFailLine(BackupError('identity not loaded')),
      l10n.backupNotMade,
    );
    expect(
      backupFailLine(
        const FileSystemException(
          'open',
          '/x',
          OSError('Permission denied', 13),
        ),
      ),
      l10n.backupNotMade,
    );
  });

  testWidgets('a backed-out dialog and no share sheet is not saved', (t) async {
    shares = 'failed';
    await open(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    saysNotSaved();
    expect(made(), hasLength(1));
    expect(await movedAt(t), isNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a share sheet closed with no app picked is not saved, and '
      'the file stays to try again', (t) async {
    shares = 'closed';
    await open(t);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    saysNotSaved();
    expect(made(), hasLength(1));
    expect(made().single.readAsStringSync(), 'made');

    // shared again, and this time an app is picked
    shares = 'picked';
    await press(t, shareInstead);
    await until(t, () => screen.evaluate().isEmpty);
    expect('shareFile'.allMatches(asked.join(' ')), hasLength(2));
    expect(screen, findsNothing);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a copy that failed is not saved and can be tried again', (
    t,
  ) async {
    await open(t);
    dialogs.single.complete({'state': 'failed'});
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    saysNotSaved();
    expect(asked, isNot(contains('shareFile')));
    expect(made(), hasLength(1));

    await press(t, tryAgain);
    await until(t, () => dialogs.length == 2);
    expect(dialogs, hasLength(2));
    dialogs.last.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(screen, findsNothing);
    expect(find.text(l10n.backupBackupSavedKeepThe), findsOneWidget);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a long copy that keeps moving is waited for', (t) async {
    await open(t);
    var n = 0;
    stage = () => {'stage': 'copying', 'copied': n += 1 << 20};
    await wait(t, 60);
    expect(notSaved, findsNothing);
    expect(find.text(l10n.backupSaving), findsOneWidget);
    stage = () => idle;
    dialogs.single.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(screen, findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a copy that stopped moving is not saved', (t) async {
    await open(t);
    stage = () => {'stage': 'copying', 'copied': 4096};
    await wait(t, 20);
    expect(notSaved, findsNothing);
    await wait(t, 30);
    saysNotSaved();
    expect(made(), hasLength(1));
    // android stops it
    stage = () => idle;
    await wait(t, 2);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a backed-out move never opens the share sheet by itself', (
    t,
  ) async {
    await open(t, move: true);
    dialogs.single.complete({'state': 'cancelled'});
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    saysNotSaved();
    expect(asked, isNot(contains('shareFile')));
    expect(await movedAt(t), isNull);
    expect(made(), hasLength(1));
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a move that went out by share keeps the phone until asked', (
    t,
  ) async {
    await open(t, move: true);
    dialogs.single.complete({'state': 'cancelled'});
    await beats(t);
    await press(t, shareInstead);
    await until(t, () => reached.evaluate().isNotEmpty);
    // the sheet is up
    await t.pump(const Duration(milliseconds: 400));
    expect(asked, contains('shareFile'));
    expect(find.text(l10n.backupMoveReachedLine), findsOneWidget);
    // the sheet's words are the page's own colours
    expect(textOf(reached).style!.color, HaloColors.text);
    expect(
      textOf(find.text(l10n.backupMoveReachedLine)).style!.color,
      HaloColors.text2,
    );
    expect(await movedAt(t), isNull);
    await t.tap(find.text(l10n.backupNotYet));
    await until(t, () => screen.evaluate().isEmpty);
    expect(screen, findsNothing);
    expect(await movedAt(t), isNull);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a move that went out by share retires once it arrived', (
    t,
  ) async {
    await open(t, move: true);
    dialogs.single.complete({'state': 'cancelled'});
    await beats(t);
    await press(t, shareInstead);
    await until(t, () => reached.evaluate().isNotEmpty);
    // the sheet is up
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(l10n.backupFinishTheMove));
    await until(t, () => screen.evaluate().isEmpty);
    await beats(t);
    expect(await movedAt(t), isNotNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a checked save of a move retires the phone', (t) async {
    await open(t, move: true);
    stage = () => idle;
    dialogs.single.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    await beats(t);
    expect(reached, findsNothing);
    expect(await movedAt(t), isNotNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a save that could not be checked says so', (t) async {
    await open(t);
    dialogs.single.complete({'state': 'unchecked'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(find.text(l10n.backupSavedUnchecked), findsOneWidget);
    expect(find.text(l10n.backupBackupSavedKeepThe), findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a move saved without a check retires nothing by itself', (
    t,
  ) async {
    await open(t, move: true);
    dialogs.single.complete({'state': 'unchecked'});
    await until(t, () => reached.evaluate().isNotEmpty);
    // the sheet is up
    await t.pump(const Duration(milliseconds: 400));
    expect(await movedAt(t), isNull);
    await t.tap(find.text(l10n.backupNotYet));
    await until(t, () => screen.evaluate().isEmpty);
    expect(await movedAt(t), isNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a copy given up on is stopped, and its file waits for it', (
    t,
  ) async {
    await open(t);
    var running = true;
    stage = () =>
        running ? {'stage': 'copying', 'copied': 4096} : {'stage': 'idle'};
    await wait(t, 50);
    saysNotSaved();
    // android was told to stop before the screen said so
    expect(asked, contains('saveDocumentCancel'));
    // leaving the screen while android still reads the file keeps it
    await t.pageBack();
    await wait(t, 5);
    expect(screen, findsNothing);
    expect(made(), hasLength(1));
    running = false;
    await wait(t, 2);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('try again waits for a stopped copy to end', (t) async {
    await open(t);
    var running = true;
    stage = () =>
        running ? {'stage': 'copying', 'copied': 4096} : {'stage': 'idle'};
    await wait(t, 50);
    saysNotSaved();
    await press(t, tryAgain);
    await wait(t, 4);
    // not refused at once: the button waits on the copy
    expect(dialogs, hasLength(1));
    expect(find.text(l10n.backupSaving), findsOneWidget);
    expect(notSaved, findsNothing);
    running = false;
    await wait(t, 2);
    expect(dialogs, hasLength(2));
    dialogs.last.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(screen, findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('reading the copy back is no stall', (t) async {
    await open(t);
    var n = 0;
    stage = () => {'stage': 'checking', 'copied': n += 1 << 20};
    await wait(t, 60);
    expect(notSaved, findsNothing);
    stage = () => idle;
    dialogs.single.complete({'state': 'saved'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(screen, findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a move saved while the decoy opened is asked about later', (
    t,
  ) async {
    haloToastOverlay = () => rootNavKey.currentState?.overlay;
    addTearDown(() => haloToastOverlay = null);
    await open(t, move: true);
    final live = _Db(HaloContainer.everyday);
    // the person leaves from inside the dialog and comes back to the decoy
    lockState.left();
    useDatabasesForTest(live, Session(_Db(HaloContainer.decoy)));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = true;
    await t.pump();
    stage = () => idle;
    dialogs.single.complete({'state': 'saved'});
    await wait(t, 3);
    expect(screen, findsNothing);
    // the decoy hears nothing of it, and nothing is retired
    expect(reached, findsNothing);
    expect(await movedAt(t), isNull);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);

    // the everyday pin: the move is asked about there
    lockState.lock();
    useDatabasesForTest(live, Session(live));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await until(t, () => reached.evaluate().isNotEmpty);
    // the sheet is up
    await t.pump(const Duration(milliseconds: 400));
    expect(reached, findsOneWidget);
    await t.tap(find.text(l10n.backupFinishTheMove));
    await beats(t);
    await t.pumpAndSettle();
    expect(await movedAt(t), isNotNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a move whose copy outlasted the hold into the decoy is asked '
      'about later', (t) async {
    haloToastOverlay = () => rootNavKey.currentState?.overlay;
    addTearDown(() => haloToastOverlay = null);
    await open(t, move: true);
    final live = _Db(HaloContainer.everyday);
    // past the hold's deadline the lock comes up without a leave being
    // counted, and the decoy pin opens the decoy
    useDatabasesForTest(live, Session(_Db(HaloContainer.decoy)));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = true;
    await t.pump();
    dialogs.single.complete({'state': 'saved'});
    await wait(t, 3);
    expect(reached, findsNothing);
    expect(await movedAt(t), isNull);

    lockState.lock();
    useDatabasesForTest(live, Session(live));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await until(t, () => reached.evaluate().isNotEmpty);
    expect(reached, findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(l10n.backupFinishTheMove));
    await beats(t);
    await t.pumpAndSettle();
    expect(await movedAt(t), isNotNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  // a save given up on, then the screen left
  Future<void> lostAndLeft(WidgetTester t) async {
    await open(t);
    stage = () => {'stage': 'copying', 'copied': 4096};
    await wait(t, 50);
    saysNotSaved();
    await t.pageBack();
    await wait(t, 2);
    expect(screen, findsNothing);
  }

  testWidgets('a stage that cannot be read is not taken for idle', (t) async {
    await lostAndLeft(t);
    stage = () => throw PlatformException(code: 'gone');
    // past the whole wait: the file is still there for a copy that may run
    await wait(t, 70);
    expect(made(), hasLength(1));
    // android answers again, and kryfo comes back to the front
    stage = () => idle;
    life(t, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    life(t, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a file a copy held past the wait goes on the next unlock', (
    t,
  ) async {
    await lostAndLeft(t);
    await wait(t, 70);
    expect(made(), hasLength(1));
    stage = () => idle;
    lockState.lock();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a decoy never shreds a waiting file, the everyday app does', (
    t,
  ) async {
    await lostAndLeft(t);
    await wait(t, 70);
    expect(made(), hasLength(1));
    stage = () => idle;
    final live = _Db(HaloContainer.everyday);
    // the decoy pin: its opening does no work for the other side
    lockState.lock();
    useDatabasesForTest(live, Session(_Db(HaloContainer.decoy)));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = true;
    // long enough for a shred on the disk to finish, were one started
    await wait(t, 3);
    await beats(t, 150);
    expect(made(), hasLength(1));
    // nor does a resume in the decoy
    life(t, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    life(t, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    // long enough for a shred on the disk to finish, were one started
    await wait(t, 3);
    await beats(t, 150);
    expect(made(), hasLength(1));
    // the everyday pin
    lockState.lock();
    useDatabasesForTest(live, Session(live));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a move sheet a lock took away is asked again in its session', (
    t,
  ) async {
    haloToastOverlay = () => rootNavKey.currentState?.overlay;
    addTearDown(() => haloToastOverlay = null);
    await open(t, move: true);
    dialogs.single.complete({'state': 'cancelled'});
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    await press(t, shareInstead);
    await until(t, () => reached.evaluate().isNotEmpty);
    await wait(t, 3);
    expect(reached, findsOneWidget);
    // the lock comes up over the sheet and the decoy pin opens the decoy
    final live = _Db(HaloContainer.everyday);
    lockState.lock();
    useDatabasesForTest(live, Session(_Db(HaloContainer.decoy)));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = true;
    await wait(t, 3);
    expect(reached, findsNothing);
    expect(await movedAt(t), isNull);
    // the everyday pin: asked again there
    lockState.lock();
    useDatabasesForTest(live, Session(live));
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await until(t, () => reached.evaluate().isNotEmpty);
    await t.pump(const Duration(milliseconds: 400));
    expect(reached, findsOneWidget);
    await t.tap(find.text(l10n.backupFinishTheMove));
    await beats(t);
    await t.pumpAndSettle();
    expect(await movedAt(t), isNotNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a check may take longer than a copy before it counts as '
      'stalled', (t) async {
    await open(t);
    stage = () => {'stage': 'checking', 'copied': 0};
    // a cloud place fetching the file before the first byte reads back
    await wait(t, 90);
    expect(notSaved, findsNothing);
    expect(find.text(l10n.backupSaving), findsOneWidget);
    stage = () => idle;
    dialogs.single.complete({'state': 'unchecked'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(find.text(l10n.backupSavedUnchecked), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the move sheet fits a wide screen at a large font', (t) async {
    await open(t, move: true, wide: true, scale: 2);
    dialogs.single.complete({'state': 'unchecked'});
    await until(t, () => reached.evaluate().isNotEmpty);
    await t.pump(const Duration(milliseconds: 400));
    expect(reached, findsOneWidget);
    // its last button can be reached
    await t.dragUntilVisible(
      find.text(l10n.backupNotYet),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -80),
    );
    await t.tap(find.text(l10n.backupNotYet));
    await until(t, () => screen.evaluate().isEmpty);
    expect(await movedAt(t), isNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}

Text textOf(Finder f) => f.evaluate().single.widget as Text;
