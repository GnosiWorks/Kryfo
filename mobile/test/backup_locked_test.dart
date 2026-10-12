// SPDX-License-Identifier: GPL-3.0-or-later
// a backup made inside the hidden chats whose screen the lock took before
// the file was handed over is not made, and says so once the same hidden
// chats are open again. the everyday app in between hears nothing of it
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart' show haloToastOverlay;

import 'pin_flow_fakes.dart' show phone, press;

// the backup file, so the test knows when the shred's unlink is back: the
// disk works outside the test's clock and each step needs a pump
class _Watched implements File {
  _Watched(this._real, this._unlinked);
  final File _real;
  final Completer<void> _unlinked;
  @override
  String get path => _real.path;
  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => _real.writeAsStringSync(
    contents,
    mode: mode,
    encoding: encoding,
    flush: flush,
  );
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      _real.open(mode: mode);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    try {
      return await _real.delete(recursive: recursive);
    } finally {
      if (!_unlinked.isCompleted) _unlinked.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the backup file was asked for ${i.memberName}');
}

class _Db implements HaloDb {
  _Db(this.container);
  @override
  final HaloContainer container;
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: const <String, bool>{}, groups: const <String>{});
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

Widget _rooted(Widget home) => ValueListenableBuilder<int>(
  valueListenable: navRevision,
  builder: (_, _, _) => MaterialApp(
    navigatorKey: rootNavKey,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('backup_locked');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDown(() {
    backupForTest = null;
    lockState.openForTest();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('the lock taking the screen away mid backup says it was not '
      'made, inside the hidden chats only', (t) async {
    phone(t);
    final live = _Db(HaloContainer.everyday);
    final hidden = await Session.withVault(live, _Db(HaloContainer.vault));
    useDatabasesForTest(live, hidden);
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    // as the app has it
    haloToastOverlay = () => rootNavKey.currentState?.overlay;
    addTearDown(() => haloToastOverlay = null);
    final running = Completer<void>();
    backupForTest = (path, _) async {
      await running.future;
      File(path).writeAsStringSync('made');
    };
    await t.pumpWidget(
      _rooted(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    for (final f in find.byType(TextField).evaluate().toList()) {
      await t.enterText(find.byWidget(f.widget), 'a long passphrase');
    }
    final unlinked = Completer<void>();
    // the real calls run in the root zone, which has no overrides. the
    // sdk's own type lookup under overrides drops the path's terminating
    // zero and finds nothing
    await IOOverrides.runZoned(
      () => press(t, find.text(l10n.backupCreateBackup)),
      createFile: (path) => _Watched(Zone.root.run(() => File(path)), unlinked),
      fseGetType: (path, follow) async => Zone.root.run(
        () => FileSystemEntity.typeSync(path, followLinks: follow),
      ),
    );
    await t.pump();

    // the screen goes dark: the lock comes up and the hidden chats close
    lockState.lock();
    useDatabasesForTest(live, Session(live));
    renewRootNavigator();
    await t.pumpAndSettle();
    expect(find.byType(BackupScreen), findsNothing);
    running.complete();
    await t.pump();
    expect(tmp.listSync().whereType<File>(), hasLength(1));
    // the file is shredded on the disk, outside the test's clock, one step
    // per pump. the pump that brings the unlink back runs the rest too
    for (var i = 0; !unlinked.isCompleted; i++) {
      expect(i, lessThan(3000), reason: 'the shred never finished');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
    }
    expect(tmp.listSync().whereType<File>(), isEmpty);
    await t.pumpAndSettle();
    expect(find.text(l10n.backupNotMade), findsNothing);

    // the everyday PIN: nothing is said there
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await t.pump();
    await t.pump();
    expect(find.text(l10n.backupNotMade), findsNothing);

    // the decoy's hidden chats PIN: nothing there either
    lockState.lock();
    final decoy = _Db(HaloContainer.decoy);
    useDatabasesForTest(
      live,
      await Session.withVault(decoy, _Db(HaloContainer.decoyVault)),
    );
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = true;
    await t.pump();
    await t.pump();
    expect(find.text(l10n.backupNotMade), findsNothing);

    // the hidden chats PIN
    lockState.lock();
    useDatabasesForTest(live, hidden);
    renewRootNavigator();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await t.pump();
    await t.pump();
    expect(find.text(l10n.backupNotMade), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}
