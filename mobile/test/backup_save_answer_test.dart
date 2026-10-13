// SPDX-License-Identifier: GPL-3.0-or-later
// the save dialog always ends somewhere clear: saved with a toast, the share
// sheet when it was backed out of, or a calm not-saved line with the file
// kept to try again. an answer android never hands back, a copy that
// failed or stopped moving, count as not saved. the platform is a stand-in
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloDb, navRevision, rootNavKey, useDatabasesForTest;
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
  late bool shares;

  setUp(() {
    asked = [];
    dialogs = [];
    stage = () => null;
    shares = true;
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

  Future<void> open(WidgetTester t, {bool move = false}) async {
    phone(t);
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

  final screen = find.byType(BackupScreen);
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
    await wait(t, 10);
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
    await open(t, move: true);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => screen.evaluate().isEmpty);
    expect(asked, containsAllInOrder(['saveDocument', 'shareFile']));
    expect(screen, findsNothing);
    await until(t, () => made().isEmpty);
    expect(made(), isEmpty);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a backed-out dialog and no share sheet is not saved', (t) async {
    shares = false;
    await open(t, move: true);
    dialogs.single.complete({'state': 'cancelled'});
    await until(t, () => asked.contains('shareFile'));
    await beats(t);
    await t.pump(const Duration(seconds: 1));
    saysNotSaved();
    expect(made(), hasLength(1));
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getInt('moved.at'), isNull);
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
    await wait(t, 20);
    saysNotSaved();
    expect(made(), hasLength(1));
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}

Text textOf(Finder f) => f.evaluate().single.widget as Text;
