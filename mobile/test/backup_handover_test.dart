// SPDX-License-Identifier: GPL-3.0-or-later
// a backup is handed over by the save dialog or, when that is refused, the
// share sheet with a copy of its own. only a hand-over that went through
// lets the made file go and, for a move, retires this phone. one whose copy
// could not be made, a full phone say, keeps the file and the phone. the
// platform is a stand-in that says yes or no
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

  void platform({required bool shares}) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
        call,
      ) async {
        asked.add(call.method);
        return switch (call.method) {
          'saveDocument' => false,
          'shareFile' => shares,
          _ => null,
        };
      });

  setUp(() {
    asked = [];
    tmp = Directory.systemTemp.createTempSync('backup_handover');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    backupForTest = null;
    lockState.openForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    tmp.deleteSync(recursive: true);
  });

  Future<void> move(WidgetTester t) async {
    phone(t);
    final live = _Db(HaloContainer.everyday);
    useDatabasesForTest(live, Session(live));
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    backupForTest = (path) async => File(path).writeAsStringSync('made');
    await t.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: navRevision,
        builder: (_, _, _) => MaterialApp(
          navigatorKey: rootNavKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BackupScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.backupMoveToAnotherDevice));
    await t.pumpAndSettle();
    for (final f in find.byType(TextField).evaluate().toList()) {
      await t.enterText(find.byWidget(f.widget), 'a long passphrase');
    }
    await press(t, find.text(l10n.backupMakeTheFileAnd));
  }

  // the file is made and handed on the disk, outside the test's clock: wait
  // for [done], a few seconds at most
  Future<void> until(WidgetTester t, Future<bool> Function() done) async {
    for (var i = 0; i < 250 && !(await t.runAsync(done) ?? false); i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
  }

  List<File> made() => [
    for (final f in tmp.listSync().whereType<File>())
      if (f.path.contains('kryfo-backup-')) f,
  ];

  Future<int?> movedAt() async =>
      (await SharedPreferences.getInstance()).getInt('moved.at');

  testWidgets('a copy that could not be made keeps the file and the phone', (
    t,
  ) async {
    platform(shares: false);
    await move(t);
    await until(t, () async => asked.contains('shareFile'));
    // and a beat for whatever would follow a hand-over that went
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
    expect(asked, containsAllInOrder(['saveDocument', 'shareFile']));
    expect(made(), hasLength(1));
    expect(made().single.readAsStringSync(), 'made');
    expect(await t.runAsync(movedAt), isNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a share that went lets the file go and retires the phone', (
    t,
  ) async {
    platform(shares: true);
    await move(t);
    await until(t, () async => made().isEmpty && await movedAt() != null);
    expect(asked, containsAllInOrder(['saveDocument', 'shareFile']));
    expect(made(), isEmpty);
    expect(await t.runAsync(movedAt), isNotNull);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}
