// SPDX-License-Identifier: GPL-3.0-or-later
// the backup file is written in the app first and the save dialog opens
// after, so while it is written a line says where it goes next. not before
// the writing starts, not once the dialog is up, for a copy and a move
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
  late Completer<bool> saved;
  late bool asked;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('backup_hint');
    saved = Completer<bool>();
    asked = false;
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp.path,
    );
    // the save dialog stays up until the test answers it
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (
      call,
    ) async {
      if (call.method != 'saveDocument') return null;
      asked = true;
      return saved.future;
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

  for (final (move, still) in [(false, false), (true, false), (false, true)]) {
    testWidgets('the save line shows while the file is written only '
        '(${move ? 'move' : 'copy'}${still ? ', less motion' : ''})', (
      t,
    ) async {
      phone(t);
      final hint = find.text(l10n.backupSaveComesAfter);
      final live = _Db(HaloContainer.everyday);
      useDatabasesForTest(live, Session(live));
      lockState.openForTest(enabled: true);
      lockState.inDecoy = false;
      final started = Completer<void Function(int, int)>();
      final written = Completer<void>();
      backupForTest = (path, progress) async {
        started.complete(progress);
        await written.future;
        File(path).writeAsStringSync('made');
      };
      await t.pumpWidget(
        ValueListenableBuilder<int>(
          valueListenable: navRevision,
          builder: (_, _, _) => MaterialApp(
            navigatorKey: rootNavKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(disableAnimations: still),
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
      expect(hint, findsNothing);
      for (final f in find.byType(TextField).evaluate().toList()) {
        await t.enterText(find.byWidget(f.widget), 'a long passphrase');
      }
      await press(
        t,
        find.text(move ? l10n.backupMakeTheFileAnd : l10n.backupCreateBackup),
      );
      await t.pump();
      final progress = await started.future;
      await t.pump(const Duration(seconds: 1));
      // started, nothing written yet
      expect(find.text(l10n.backupCreating), findsOneWidget);
      expect(hint, findsNothing);

      progress(1, 4);
      await t.pump();
      if (!still) await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.backupWriting('25%')), findsOneWidget);
      expect(hint, findsOneWidget);
      final style = t.widget<Text>(hint).style!;
      expect(style.color, HaloColors.text2);
      // the same line through the rest of the writing
      progress(3, 4);
      await t.pump();
      if (!still) await t.pump(const Duration(seconds: 1));
      expect(hint, findsOneWidget);

      // written: the save dialog is up and the line is gone
      written.complete();
      for (var i = 0; i < 50 && !asked; i++) {
        await t.pump();
      }
      expect(asked, isTrue);
      await t.pump();
      if (!still) await t.pump(const Duration(seconds: 1));
      expect(hint, findsNothing);

      // saved: the made file is shredded on the disk, outside the test's
      // clock, and the screen closes
      saved.complete(true);
      final closed = find.byType(BackupScreen);
      for (var i = 0; i < 250 && closed.evaluate().isNotEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(closed, findsNothing);
      expect(hint, findsNothing);
      await t.pumpAndSettle(const Duration(seconds: 5));
    });
  }
}
