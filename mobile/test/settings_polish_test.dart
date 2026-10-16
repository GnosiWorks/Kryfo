// SPDX-License-Identifier: GPL-3.0-or-later
// the settings pages, finished: a row lights under the finger, a card folds
// its body away as smoothly as it opened, a page opens on what is in use, a
// switch opens where it was left, a public handle is only let go after a
// yes, an engine's own words never reach the screen, long values go under
// their label, and a refusal is felt.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show BackupError;
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart' show deliveryModeName;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/notifications.dart'
    show loadHideNotifContent, setHideNotifContent;
import 'package:kryfo/screens/backup_screen.dart' show backupFailLine;
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/my_kryfo_screen.dart';
import 'package:kryfo/screens/open_locked_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/screens/transport_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/tools_bridge.dart';
import 'package:kryfo/update_check.dart';
import 'package:kryfo/widgets/halo_rows.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/unfold.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart'
    show DevTestDb, devApp, devClose, devMem, devOpen, devWorld;
import 'pin_flow_fakes.dart' show hearHaptics;

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

void phone(WidgetTester t, {Size size = const Size(1000, 2400)}) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

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

// a quiet session: nothing here reaches the registry
class _QuietDb implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.decoy;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

// the developer world's database, with nothing waiting to go
class _OutboxDb extends DevTestDb {
  _OutboxDb() : super(devMem);
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
}

// the transport page's engine, quiet
class _TransportEngine implements HaloEngine {
  @override
  Map<String, dynamic> transportState() => {
    'relays': [
      {'url': 'wss://relay.example', 'fails': 0},
    ],
    'sub_count': 0,
    'secs_since_recv': -1,
    'secs_since_send': -1,
    'hsdir_uploads': 0,
    'publishing_secs': -1,
  };
  @override
  Map<String, dynamic> memStats() => const {};
  @override
  String lastReconnect() => '';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
  });

  group('a row in a group', () {
    testWidgets('its press is drawn on the group, not under it', (t) async {
      await t.pumpWidget(
        framed(
          Scaffold(
            body: HaloGroup(
              children: [HaloRow(label: 'Bridges', onTap: () {})],
            ),
          ),
        ),
      );
      final inside = find.descendant(
        of: find.byType(HaloGroup),
        matching: find.byType(Material),
      );
      expect(inside, findsOneWidget);
      expect(t.widget<Material>(inside).color, HaloColors.surface2);
      expect(
        find.descendant(of: inside, matching: find.byType(InkWell)),
        findsOneWidget,
      );
    });
  });

  group('a way to add someone', () {
    testWidgets('closing, its body fades as the card folds', (t) async {
      phone(t);
      await t.pumpWidget(framed(const MyKryfoScreen()));
      await rest(t);
      await t.tap(find.text(l10n.myKryfoTheyReSomewhereElse));
      await rest(t);
      expect(find.text(l10n.myKryfoTheLinkCarriesYour), findsOneWidget);
      await t.tap(find.text(l10n.myKryfoTheyReSomewhereElse));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      // still drawn, on its way out
      expect(find.text(l10n.myKryfoTheLinkCarriesYour), findsOneWidget);
      await rest(t);
      expect(find.text(l10n.myKryfoTheLinkCarriesYour), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: closing is at once', (t) async {
      phone(t);
      await t.pumpWidget(framed(const MyKryfoScreen(), still: true));
      await rest(t);
      await t.tap(find.text(l10n.myKryfoTheyReSomewhereElse));
      await t.pump();
      expect(find.text(l10n.myKryfoTheLinkCarriesYour), findsOneWidget);
      await t.tap(find.text(l10n.myKryfoTheyReSomewhereElse));
      await t.pump();
      expect(find.text(l10n.myKryfoTheLinkCarriesYour), findsNothing);
      expect(find.byType(Unfold), findsWidgets);
      await drain(t);
    });

    testWidgets('in the light theme the code is dark on light', (t) async {
      phone(t);
      HaloColors.setLight(true);
      addTearDown(() => HaloColors.setLight(false));
      await t.pumpWidget(framed(const MyKryfoScreen()));
      await rest(t);
      await t.tap(find.text(l10n.myKryfoTheyReHereWith));
      await rest(t);
      // a scanner reads dark modules on a light card, whatever the theme
      final paper = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == HaloColors.qrPaper,
      );
      expect(paper, findsOneWidget);
      await drain(t);
    });

    testWidgets('right to left, the @ still leads the handle', (t) async {
      phone(t);
      setL10nLocale(const Locale('ar'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        framed(const MyKryfoScreen(), locale: const Locale('ar')),
      );
      await rest(t);
      await t.tap(find.text(l10n.myKryfoIKnowTheirHandle));
      await rest(t);
      final at = t.getCenter(find.text('@')).dx;
      final field = t.getCenter(find.byType(TextField).last).dx;
      expect(at, lessThan(field));
      expect(find.text(l10n.handleWren), findsOneWidget);
      await drain(t);
    });
  });

  group('speed and privacy', () {
    testWidgets('opens on the mode in use, from the first frame', (t) async {
      phone(t);
      FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
      appState.sendModeForTest = 'balanced';
      await t.pumpWidget(framed(const ModesScreen()));
      final pill = find.ancestor(
        of: find.text(l10n.modesActive),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: pill.first, matching: find.text(l10n.modesRelay)),
        findsOneWidget,
      );
      await rest(t);
      await drain(t);
    });
  });

  group('settings', () {
    testWidgets('a switch turned off opens off, never sliding there', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
        HaloContainer.everyday.key('kryfo.scamshield.on'): false,
      });
      await devWorld();
      t.view.physicalSize = const Size(1000, 6000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(const SettingsScreen()));
      HaloSwitch? shield() {
        final row = find.ancestor(
          of: find.text(l10n.settingsScamShield),
          matching: find.byType(HaloRow),
        );
        final s = find.descendant(of: row, matching: find.byType(HaloSwitch));
        return s.evaluate().isEmpty ? null : t.widget<HaloSwitch>(s);
      }

      // before the saved value is read, no switch claims a position
      expect(shield()?.value, isNot(true));
      await t.pump(const Duration(seconds: 1));
      expect(shield()?.value, isFalse);
      await devClose(t);
    });

    testWidgets('screenshots are per chat now: no switch for the whole app, '
        'and a lock turned off in the decoy leaves them to each chat', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
      });
      await devWorld();
      lockState.openForTest(enabled: true);
      lockState.inDecoy = true;
      addTearDown(() {
        lockState.inDecoy = false;
        lockState.openForTest();
      });
      await lockState.disable();
      t.view.physicalSize = const Size(1000, 6000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(const SettingsScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.chatBlockScreenshots), findsNothing);
      // as after a turn off in the everyday app
      expect(find.text(l10n.settingsPerChat), findsOneWidget);
      await devClose(t);
    });

    testWidgets('the old switch still waiting on home\'s card: the '
        'protections say the window is covered', (t) async {
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
      });
      await devWorld();
      FlutterSecureStorage.setMockInitialValues({'block_screenshots': 'true'});
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/platform'),
        (_) async => null,
      );
      await t.runAsync(() => appState.loadScreenSecure());
      addTearDown(() async {
        FlutterSecureStorage.setMockInitialValues({});
        await appState.loadScreenSecure();
      });
      t.view.physicalSize = const Size(1000, 6000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(const SettingsScreen()));
      await t.pump(const Duration(seconds: 1));
      final line = t.widget<ProtectionLine>(
        find.byWidgetPredicate(
          (w) => w is ProtectionLine && w.label == l10n.settingsScreenshots,
        ),
      );
      expect((line.on, line.state), (true, l10n.settingsBlocked2));
      await devClose(t);
    });
  });

  group('gif search row', () {
    for (final quiet in [false, true]) {
      testWidgets(
        quiet
            ? 'a decoy has it too, its own switch'
            : 'the everyday app has it',
        (t) async {
          SharedPreferences.setMockInitialValues({
            'battery_opt_prompt_seen': true,
            'miui_autostart_prompt_seen': true,
          });
          final c = quiet ? HaloContainer.decoy : HaloContainer.everyday;
          await devWorld(container: c);
          t.view.physicalSize = const Size(1000, 6000);
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          await t.pumpWidget(devApp(const SettingsScreen()));
          await t.pump(const Duration(seconds: 1));
          expect(find.text(l10n.settingsGifSearch), findsOneWidget);
          await t.tap(find.text(l10n.settingsGifSearch));
          await rest(t);
          await t.tap(find.text(l10n.gifTurnOn));
          await rest(t);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(c.key('kryfo.gif.on')), isTrue);
          // on from settings counts as asked: the picker never asks after
          expect(prefs.getBool(c.key('kryfo.gif.asked')), isTrue);
          if (quiet) expect(prefs.getBool('kryfo.gif.on'), isNull);
          if (quiet) expect(prefs.getBool('kryfo.gif.asked'), isNull);
          // and off again with one tap
          await t.tap(find.text(l10n.settingsGifSearch));
          await rest(t);
          expect(find.text(l10n.gifOptInTitle), findsNothing);
          expect(prefs.getBool(c.key('kryfo.gif.on')), isFalse);
          await devClose(t);
        },
      );
    }
  });

  group('update row', () {
    tearDown(() => updateNoticeForTest = null);

    for (final quiet in [false, true]) {
      testWidgets(
        quiet
            ? 'a decoy has it too, its own switch, and asks nothing'
            : 'the everyday app has it',
        (t) async {
          SharedPreferences.setMockInitialValues({
            'battery_opt_prompt_seen': true,
            'miui_autostart_prompt_seen': true,
          });
          final c = quiet ? HaloContainer.decoy : HaloContainer.everyday;
          await devWorld(container: c);
          final asked = <String>[];
          updateNoticeForTest = UpdateNotice(
            get: (url) async {
              asked.add(url);
              return 'error: get';
            },
            torUp: () => true,
            quiet: () => quiet,
            container: () => c,
            playBuild: false,
            install: () async => const InstallInfo(version: '0.5.0'),
            pause: () async {},
          );
          t.view.physicalSize = const Size(1000, 6000);
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          await t.pumpWidget(devApp(const SettingsScreen()));
          await t.pump(const Duration(seconds: 1));
          final row = find.text(l10n.settingsCheckForUpdates);
          expect(row, findsOneWidget);
          await t.ensureVisible(row);
          await t.tap(row);
          await rest(t);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(c.key('kryfo.update.on')), isFalse);
          if (quiet) {
            expect(prefs.getBool('kryfo.update.on'), isNull);
            // on again in the decoy: still nothing goes out
            await t.tap(row);
            await rest(t);
            expect(prefs.getBool(c.key('kryfo.update.on')), isTrue);
            expect(asked, isEmpty);
          }
          await devClose(t);
        },
      );
    }
  });

  group('getting messages row', () {
    testWidgets('says the preview is hidden as soon as a PIN hides it', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
        HaloContainer.everyday.key('notif_hide_content'): false,
      });
      await devWorld();
      t.view.physicalSize = const Size(1000, 6000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(const SettingsScreen()));
      await t.pump(const Duration(seconds: 1));
      final mode = deliveryModeName(appState.deliveryMode);
      expect(find.text(l10n.settingsPreviewShown(mode)), findsOneWidget);
      // what setting a PIN writes, from the App lock screen
      await setHideNotifContent(true);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.settingsPreviewHidden(mode)), findsOneWidget);
      await devClose(t);
    });
  });

  group('getting messages row, once read', () {
    testWidgets('read before, the row is whole from the first frame', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
        HaloContainer.everyday.key('notif_hide_content'): true,
      });
      await devWorld();
      // as the boot reads it
      expect(await loadHideNotifContent(), isTrue);
      t.view.physicalSize = const Size(1000, 6000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(const SettingsScreen()));
      final mode = deliveryModeName(appState.deliveryMode);
      // the very first frame, before any read comes back
      expect(find.text(l10n.settingsPreviewHidden(mode)), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.settingsPreviewHidden(mode)), findsOneWidget);
      await devClose(t);
    });
  });

  group('the handle page', () {
    setUp(() {
      final db = _QuietDb();
      useDatabasesForTest(db, Session(db));
    });

    testWidgets('deleting the handle asks first, and keep keeps it', (t) async {
      phone(t);
      // the everyday session: a quiet one holds no handle
      await devWorld();
      await appState.setMyHandle('wren');
      addTearDown(() => appState.setMyHandle(null));
      await t.pumpWidget(framed(const HandleScreen()));
      await rest(t);
      await t.tap(find.text(l10n.handleDeleteThisHandle));
      await rest(t);
      expect(find.text(l10n.handleDeleteTitle('wren')), findsOneWidget);
      await t.tap(find.text(l10n.confirmSheetKeep));
      await rest(t);
      expect(find.text(l10n.handleDeleteTitle('wren')), findsNothing);
      expect(appState.myHandle, 'wren');
      expect(find.text(l10n.handleDeleteThisHandle), findsOneWidget);
      await drain(t);
    });

    testWidgets('right to left, the @ leads the field', (t) async {
      phone(t);
      setL10nLocale(const Locale('fa'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        framed(const HandleScreen(), locale: const Locale('fa')),
      );
      await rest(t);
      final at = t.getCenter(find.text('@')).dx;
      final field = t.getCenter(find.byType(TextField).first).dx;
      expect(at, lessThan(field));
      await drain(t);
    });
  });

  group('backup', () {
    test('a failure says the backup was not made, in its own words', () {
      expect(
        backupFailLine(const FormatException('FileSystemException: nope')),
        l10n.backupNotMade,
      );
      expect(
        backupFailLine(BackupError('db file not found')),
        l10n.backupNotMade,
      );
      // the one with something to do keeps its words
      expect(
        backupFailLine(BackupError(l10n.backupHiddenGone)),
        l10n.backupHiddenGone,
      );
    });
  });

  group('transport', () {
    testWidgets('long values go under their label, nothing runs off', (
      t,
    ) async {
      useEngineForTest(_TransportEngine());
      await devWorld();
      await devOpen(
        t,
        const TransportScreen(),
        size: const Size(1000, 12000),
        scale: 1.6,
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      await devClose(t);
    });

    testWidgets('a label beside a short value keeps all the room it needs', (
      t,
    ) async {
      useEngineForTest(_TransportEngine());
      await devWorld();
      await devOpen(
        t,
        const TransportScreen(),
        locale: const Locale('de'),
        size: const Size(1280, 12000),
      );
      await t.pump(const Duration(seconds: 1));
      final cut = <String>[];
      for (final e in find.byType(Text).evaluate()) {
        final w = e.widget as Text;
        if (w.maxLines != 1 || w.data == null) continue;
        final p = t.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byWidget(w),
            matching: find.byType(RichText),
          ),
        );
        if (p.didExceedMaxLines) cut.add(w.data!);
      }
      expect(cut, isEmpty);
      await devClose(t);
    });

    testWidgets('sending what waits says how it went', (t) async {
      useEngineForTest(_TransportEngine());
      await devWorld();
      final db = _OutboxDb();
      useDatabasesForTest(db, Session(db));
      await devOpen(t, const TransportScreen(), size: const Size(1000, 12000));
      await t.tap(find.text(l10n.transportSendAnythingWaitingNow));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.transportNothingLeftWaiting), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await devClose(t);
    });
  });

  group('a locked file that will not open', () {
    testWidgets('is felt, as a wrong pin is', (t) async {
      const file = PickedFile(
        uri: 'content://test/locked.age',
        name: 'locked.age',
        size: 1234,
        mime: 'application/octet-stream',
      );
      final heard = hearHaptics(t);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/tools'),
        (call) async => call.method == 'openForRead' ? -1 : null,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('halo/tools'),
          null,
        ),
      );
      await t.pumpWidget(framed(const OpenLockedScreen(file: file)));
      await t.pump(const Duration(milliseconds: 50));
      await t.enterText(find.byType(TextField).first, 'correct horse');
      await t.pump();
      heard.clear();
      await t.tap(find.text(l10n.openLockedOpenFile));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(heard, contains('heavyImpact'));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  });
}
