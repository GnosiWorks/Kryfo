// SPDX-License-Identifier: GPL-3.0-or-later
// the settings pages of this pass: a handle's answer rising in as it is
// typed and its field lighting, a pin's state rising in when it changes,
// a backup's error easing in, a bridge card's state. each rests, and with
// less movement each change is simply there.
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/screens/restore_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show FakeHost, appOnly, makeLock, wipePin;

// a quiet session: the handle page never reaches the registry from one
class _QuietDb implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.decoy;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

final _theme = buildHaloTheme();

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// a second at a time, so a ticker started late still gets its frames
Future<void> rest(WidgetTester t, [int seconds = 2]) async {
  for (var i = 0; i < seconds; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
  });

  group('the handle page', () {
    setUp(() {
      final db = _QuietDb();
      useDatabasesForTest(db, Session(db));
    });

    testWidgets('each answer rises in over the last, then rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const HandleScreen()));
      await rest(t);
      await t.enterText(find.byType(TextField).first, 'wren');
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text(l10n.handleChecking), findsOneWidget);
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 60));
      // the quiet session answers as an unreachable registry does, in the
      // app's own fixed line, and the new words cross the old ones
      expect(find.text(l10n.handleChecking), findsOneWidget);
      expect(find.text(l10n.handleRegistryFailed), findsOneWidget);
      expect(find.text('bad answer from the registry'), findsNothing);
      await rest(t);
      expect(find.text(l10n.handleChecking), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('the field lights while it is typed in', (t) async {
      phone(t);
      await t.pumpWidget(framed(const HandleScreen()));
      await rest(t);
      Border edge() =>
          (t
                          .widget<AnimatedContainer>(
                            find
                                .ancestor(
                                  of: find.byType(TextField).first,
                                  matching: find.byType(AnimatedContainer),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border!
              as Border;
      expect(edge().top.color, HaloColors.line);
      await t.tap(find.byType(TextField).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      expect(edge().top.color, isNot(HaloColors.line));
      await rest(t);
      await drain(t);
    });

    testWidgets('reduced motion: the answer is simply there', (t) async {
      phone(t);
      await t.pumpWidget(framed(const HandleScreen(), still: true));
      await t.pump();
      await t.enterText(find.byType(TextField).first, 'wren');
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(find.text(l10n.handleChecking), findsNothing);
      expect(find.text(l10n.handleRegistryFailed), findsOneWidget);
      await t.pump(const Duration(milliseconds: 200));
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('a name that cannot be a handle shows the rule, unasked', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(const HandleScreen()));
      await rest(t);
      await t.enterText(find.byType(TextField).first, 'a!');
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.handleNameRule), findsOneWidget);
      expect(find.text(l10n.handleChecking), findsNothing);
      expect(find.text(l10n.handleRegistryFailed), findsNothing);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });

  group('app lock', () {
    Future<void> open(WidgetTester t, {bool still = false}) async {
      phone(t);
      final lock = await makeLock(appOnly);
      await t.pumpWidget(
        framed(
          PinsScreen(
            lock: lock.state,
            host: FakeHost(lock: lock.state),
          ),
          still: still,
        ),
      );
      await rest(t);
      await t.tap(find.text(l10n.pinsAdvanced));
      await rest(t);
      expect(find.text(l10n.pinsWipePin), findsOneWidget);
      expect(find.text(l10n.commonOff), findsNWidgets(2));
      // the wipe pin set from elsewhere: the row's state changes here
      await lock.state.setupPanicPin(wipePin);
      await t.pump();
    }

    testWidgets('a pin set rises in on its row, then rests', (t) async {
      await open(t);
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text(l10n.pinsSet), findsOneWidget);
      expect(find.text(l10n.commonOff), findsNWidgets(2));
      await rest(t);
      expect(find.text(l10n.commonOff), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: it is simply there', (t) async {
      await open(t, still: true);
      await t.pump();
      expect(find.text(l10n.pinsSet), findsOneWidget);
      expect(find.text(l10n.commonOff), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });

  group('backup', () {
    testWidgets('an error eases in and rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const BackupScreen()));
      await rest(t);
      await t.tap(find.text(l10n.backupCreateBackup));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(find.text(l10n.backupPassphraseMustBeAt), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: the error is simply there', (t) async {
      phone(t);
      await t.pumpWidget(framed(const BackupScreen(), still: true));
      await t.pump();
      await t.tap(find.text(l10n.backupCreateBackup));
      await t.pump();
      expect(find.text(l10n.backupPassphraseMustBeAt), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });

  group('bridges', () {
    const line = 'obfs4 1.2.3.4:443 ABCDEF cert=xyz iat-mode=0';

    // tall enough that the paste field is built
    void tall(WidgetTester t) {
      phone(t);
      t.view.physicalSize = const Size(1000, 3600);
    }

    testWidgets('a pasted line marks its card saved, and it rests', (t) async {
      tall(t);
      await t.pumpWidget(framed(const BridgesScreen()));
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      expect(find.text(l10n.bridgesSavedTag), findsNothing);
      await t.enterText(find.byType(TextField).first, line);
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text(l10n.bridgesSavedTag), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: the tag is simply there', (t) async {
      tall(t);
      await t.pumpWidget(framed(const BridgesScreen(), still: true));
      await t.pump();
      await t.enterText(find.byType(TextField).first, line);
      await t.pump();
      expect(find.text(l10n.bridgesSavedTag), findsOneWidget);
      // only the card's edge changes colour, and briefly
      await t.pump(const Duration(milliseconds: 400));
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });

  group('restore', () {
    testWidgets('the page comes in and rests, its steps numbered', (t) async {
      phone(t);
      await t.pumpWidget(framed(const RestoreScreen()));
      await rest(t);
      expect(find.text('01'), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: nothing grows or moves', (t) async {
      phone(t);
      await t.pumpWidget(framed(const RestoreScreen(), still: true));
      await t.pump();
      expect(find.byType(AnimatedSize), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });
}
