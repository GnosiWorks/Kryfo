// SPDX-License-Identifier: GPL-3.0-or-later
// a restore under way holds the screen: no back arrow, the back gesture
// does nothing, and the file it reads stays. a restore that fails, or a
// handle not released and kept for later, gives the way back again. the
// same identity from an older file keeps its handle and its face. a session
// switch under the lock that takes the screen away does not take the end of
// the restore with it: the hidden chats still get their PIN and the app
// still closes
import 'dart:async';
import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart' show FilePickerPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart' show HaloScrollBehavior;
import 'package:kryfo/backup.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        navRevision,
        renewRootNavigator,
        rootNavKey,
        useEngineForTest;
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/restore_screen.dart';
import 'package:kryfo/theme.dart';

import 'pin_flow_fakes.dart' show app, phone, press;

class _Engine implements HaloEngine {
  @override
  Future<String> handleRelease(String h) async => 'error: no relay';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

// the screen opened over another, a file picked and checked, and restore
// tapped and agreed to
Future<void> _openAndRestore(
  WidgetTester t, {
  RestoreScreen screen = const RestoreScreen(),
  Widget Function(Widget home) wrap = app,
  bool move = true,
}) async {
  await t.pumpWidget(
    wrap(
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(
            ctx,
          ).push(MaterialPageRoute<void>(builder: (_) => screen)),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  expect(find.byType(BackButton), findsOneWidget);

  await t.tap(find.text(l10n.restorePickTheBackupFile));
  for (var i = 0; i < 40 && find.text('old.txt').evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();

  expect(find.text('old.txt'), findsOneWidget);
  await t.enterText(find.byType(TextField), 'the passphrase');
  await t.tap(find.text(l10n.restoreCheckTheFile));
  await t.pumpAndSettle();
  final restore = find.descendant(
    of: find.byType(ListView),
    matching: find.text(l10n.restoreRestore),
  );
  await t.dragUntilVisible(
    restore,
    find.byType(ListView),
    const Offset(0, -200),
  );
  await press(t, restore);
  await t.pumpAndSettle();
  if (!move) return;
  await press(t, find.text(l10n.restoreMoveItHere));
  await t.pumpAndSettle();
}

// the app's own root: each session switch builds a new navigator
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
    tmp = Directory.systemTemp.createTempSync('restore_screen');
    _mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
    // the picker's own folder is emptied over its channel
    FilePickerPlatform.instance = FilePickerAndroid();
    _mock('miguelruivo.flutter.plugins.filepicker', (_) async => true);
    pickForTest = () async {
      final f = File('${tmp.path}/old.txt')
        ..writeAsStringSync('kryfo-backup:abc');
      return AndroidPlatformFile.fromMap({
        'name': 'old.txt',
        'path': f.path,
        'size': f.lengthSync(),
      });
    };
  });

  tearDown(() {
    inspectForTest = null;
    restoreForTest = null;
    _mock('plugins.flutter.io/path_provider', null);
    pickForTest = null;
    _mock('miguelruivo.flutter.plugins.filepicker', null);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('a restore under way cannot be left', (t) async {
    phone(t);
    final running = Completer<void>();
    inspectForTest = (_) async => const BackupSummary(
      when: null,
      version: 1,
      haloId: 'amber-fox-run',
      contacts: 2,
      messages: 9,
    );
    var asks = 0;
    restoreForTest = (_) {
      asks++;
      return running.future;
    };
    await _openAndRestore(t);

    // writing now: neither the arrow nor the back gesture leaves
    expect(find.text(l10n.restoreRestoring), findsOneWidget);
    // the button stays lit while it works, and a second tap starts nothing
    final busy = t.widget<Text>(find.text(l10n.restoreRestoring));
    expect(busy.style?.color, HaloColors.onAmber);
    await t.tap(find.text(l10n.restoreRestoring));
    await t.pump();
    expect(asks, 1);
    expect(find.byType(BackButton), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RestoreScreen), findsOneWidget);

    // a restore that fails says so, and the way back is there again
    running.completeError(const RestoreError(RestoreFailure.damaged));
    await t.pumpAndSettle();
    expect(find.text(l10n.backupThisFileIsDamaged), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RestoreScreen), findsNothing);
  });

  // a 720x1600 phone, a big file with hidden chats: every line of the
  // sheet shows, and the button is reached by a finger, not by code
  for (final (scale, locale) in [
    (1.0, const Locale('en')),
    (1.6, const Locale('en')),
    (1.6, const Locale('ar')),
  ]) {
    testWidgets('the move sheet scrolls to its button at $scale '
        '${locale.languageCode}', (t) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 1.875;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      inspectForTest = (_) async => const BackupSummary(
        when: null,
        version: 2,
        haloId: 'tourist-admit-sun',
        contacts: 1,
        messages: 7,
        bytes: 66 * 1024 * 1024,
        files: 17,
        hiddenChats: 1,
      );
      final running = Completer<void>();
      restoreForTest = (_) => running.future;
      await _openAndRestore(
        t,
        wrap: (home) => MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // the app's own scroll feel: every scroll view takes a drag
          scrollBehavior: const HaloScrollBehavior(),
          home: home,
        ),
        move: false,
      );
      final go = find.text(l10n.restoreMoveItHere);
      expect(go, findsOneWidget);
      final screen = t.view.physicalSize / t.view.devicePixelRatio;
      bool shown() => t.getRect(go).bottom <= screen.height;
      for (var i = 0; i < 12 && !shown(); i++) {
        await t.dragFrom(
          Offset(screen.width / 2, screen.height * 0.7),
          const Offset(0, -300),
        );
        await t.pumpAndSettle();
      }
      expect(shown(), isTrue);
      await t.tap(go);
      await t.pumpAndSettle();
      expect(find.text(l10n.restoreRestoring), findsOneWidget);
      running.complete();
      await t.pumpAndSettle();
    });
  }

  testWidgets('a handle not released and not yet gives the way back', (
    t,
  ) async {
    phone(t);
    FlutterSecureStorage.setMockInitialValues({'my_handle': 'amberfox'});
    await appState.loadMyHandle();
    useEngineForTest(_Engine());
    var restored = false;
    inspectForTest = (_) async => const BackupSummary(
      when: null,
      version: 1,
      haloId: 'amber-fox-run',
      contacts: 2,
      messages: 9,
    );
    restoreForTest = (_) async => restored = true;
    await _openAndRestore(t);

    expect(find.text(l10n.restoreNotYet), findsOneWidget);
    await press(t, find.text(l10n.restoreNotYet));
    await t.pumpAndSettle();
    expect(restored, isFalse);
    expect(find.byType(BackButton), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RestoreScreen), findsNothing);
  });

  testWidgets('the same identity from an older file keeps its handle and '
      'its face', (t) async {
    phone(t);
    FlutterSecureStorage.setMockInitialValues({
      'my_handle': 'amberfox',
      'my_avatar': '17',
    });
    await appState.loadMyHandle();
    appState.myId = 'amber-fox-run';
    addTearDown(() => appState.myId = '');
    inspectForTest = (_) async => const BackupSummary(
      when: null,
      version: 1,
      haloId: 'amber-fox-run',
      contacts: 2,
      messages: 9,
    );
    // a file without them removes what is here, as identitySecurePlan says
    restoreForTest = (_) async {
      const st = FlutterSecureStorage();
      for (final k in identitySecurePlan(const {}).remove) {
        await st.delete(key: k);
      }
    };
    var done = false;
    await _openAndRestore(
      t,
      screen: RestoreScreen(onRestored: () => done = true),
    );
    await t.pumpAndSettle();
    expect(done, isTrue);
    const st = FlutterSecureStorage();
    expect(await st.read(key: 'my_handle'), 'amberfox');
    expect(await st.read(key: 'my_avatar'), '17');
  });

  testWidgets('the lock taking the screen away mid restore still asks for '
      'the hidden chats PIN, then closes', (t) async {
    phone(t);
    FlutterSecureStorage.setMockInitialValues({});
    await appState.loadMyHandle();
    var quits = 0;
    quitAfterRestore = () => quits++;
    lockState.openForTest(enabled: true);
    addTearDown(() {
      quitAfterRestore = () => exit(0);
      forgetRestoredHidden();
      lockState.openForTest();
    });
    final running = Completer<void>();
    inspectForTest = (_) async => const BackupSummary(
      when: null,
      version: 2,
      haloId: 'amber-fox-run',
      contacts: 2,
      messages: 9,
    );
    restoreForTest = (_) async {
      await running.future;
      restoredHiddenForTest('the hidden key');
    };
    await _openAndRestore(t, wrap: _rooted);
    expect(find.text(l10n.restoreRestoring), findsOneWidget);

    // the screen goes dark: the lock comes up and the hidden chats close
    lockState.lock();
    renewRootNavigator();
    await t.pumpAndSettle();
    expect(find.byType(RestoreScreen), findsNothing);
    running.complete();
    await t.pumpAndSettle();
    // nothing shows under the lock
    expect(find.byType(PinFlowScreen), findsNothing);
    expect(quits, 0);

    // unlocked
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await t.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsOneWidget);
    expect(quits, 0);

    // the lock again while it is chosen: asked for again after
    lockState.lock();
    renewRootNavigator();
    await t.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsNothing);
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await t.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsOneWidget);
    expect(quits, 0);

    // the PIN is chosen
    forgetRestoredHidden();
    rootNavKey.currentState!.pop(true);
    await t.pumpAndSettle();
    expect(find.text(l10n.restoreRestored), findsOneWidget);
    await t.tap(find.text(l10n.restoreReopenKryfo));
    await t.pumpAndSettle();
    expect(quits, 1);
  });

  group('a landing cut short', () {
    late int quits;
    setUp(() {
      quits = 0;
      quitAfterRestore = () => quits++;
      lockState.openForTest(enabled: true);
      FlutterSecureStorage.setMockInitialValues({});
      inspectForTest = (_) async => const BackupSummary(
        when: null,
        version: 2,
        haloId: 'amber-fox-run',
        contacts: 2,
        messages: 9,
      );
    });
    tearDown(() {
      quitAfterRestore = () => exit(0);
      forgetRestoredHidden();
      lockState.openForTest();
    });

    testWidgets('says so and closes the app, with no PIN asked for hidden '
        'chats that landed', (t) async {
      phone(t);
      await appState.loadMyHandle();
      restoreForTest = (_) async {
        restoredHiddenForTest('the hidden key');
        throw const RestoreError(RestoreFailure.cutShort);
      };
      await _openAndRestore(t);
      expect(find.text(l10n.backupTheRestoreStoppedPartway), findsOneWidget);
      expect(find.text(l10n.restoreKryfoClosesRestoreAgain), findsOneWidget);
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(quits, 0);
      await t.tap(find.text(l10n.restoreReopenKryfo));
      await t.pumpAndSettle();
      expect(quits, 1);
    });

    testWidgets('under the lock, says so once the same session is open '
        'again', (t) async {
      phone(t);
      await appState.loadMyHandle();
      final running = Completer<void>();
      restoreForTest = (_) async {
        await running.future;
        throw const RestoreError(RestoreFailure.cutShort);
      };
      await _openAndRestore(t, wrap: _rooted);
      lockState.lock();
      renewRootNavigator();
      await t.pumpAndSettle();
      running.complete();
      await t.pumpAndSettle();
      expect(find.text(l10n.backupTheRestoreStoppedPartway), findsNothing);

      lockState.openForTest(enabled: true);
      lockState.inDecoy = false;
      await t.pumpAndSettle();
      expect(find.text(l10n.backupTheRestoreStoppedPartway), findsOneWidget);
      expect(find.text(l10n.restoreRestored), findsNothing);
      await t.tap(find.text(l10n.restoreReopenKryfo));
      await t.pumpAndSettle();
      expect(quits, 1);
    });
  });
}
