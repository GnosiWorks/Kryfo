// SPDX-License-Identifier: GPL-3.0-or-later
// a restore under way holds the screen: no back arrow, the back gesture
// does nothing, and the file it reads stays. a restore that fails, or a
// handle not released and kept for later, gives the way back again. the
// same identity from an older file keeps its handle and its face
import 'dart:async';
import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart' show FilePickerPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/restore_screen.dart';

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
}) async {
  await t.pumpWidget(
    app(
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
  await press(
    t,
    find.descendant(
      of: find.byType(ListView),
      matching: find.text(l10n.restoreRestore),
    ),
  );
  await t.pumpAndSettle();
  await press(t, find.text(l10n.restoreMoveItHere));
  await t.pumpAndSettle();
}

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
    restoreForTest = (_) => running.future;
    await _openAndRestore(t);

    // writing now: neither the arrow nor the back gesture leaves
    expect(find.text(l10n.restoreRestoring), findsOneWidget);
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
}
