// SPDX-License-Identifier: GPL-3.0-or-later
// a computer's link rows in settings: its own Kryfo offers the link to a
// phone (what goes, a backup first, the wipe word, the erase that comes
// back at the code), a linked one says so and unlinks by the devices
// page's own path. none on a phone. the decoy, a quiet session and a vault
// show the same rows; the decoy's and a quiet session's word ends in a
// plain error that erases nothing. after the erase the next run opens
// onboarding's link, and a cancel or a failed link there is a clean start
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart' show HaloContainer;
import 'package:kryfo/desktop/desktop_channels.dart' show DesktopMessenger;
import 'package:kryfo/desktop/desktop_db.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_platform.dart';
import 'package:kryfo/desktop/desktop_start.dart' show linkAsked;
import 'package:kryfo/devices/link_flow.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/last_backup.dart' show keepLastBackup;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        linkedRoleForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/desk_link_screen.dart';
import 'package:kryfo/screens/link_screens.dart' show JoinScreen;
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/store.dart' show playBuildForTest;
import 'package:kryfo/widgets/halo_rows.dart' show HaloGroup, HaloSection;
import 'package:kryfo/wipe.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart' show devApp, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Flow extends LinkFlow {
  _Flow(super.first);
  @override
  Future<void> start() async {}
  @override
  Future<void> match() async {}
  @override
  void noMatch() {}
  @override
  void cancel() {}
}

Future<void> _world(
  WidgetTester t, {
  bool desk = true,
  HaloContainer side = HaloContainer.everyday,
}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  playBuildForTest = false;
  addTearDown(() => playBuildForTest = null);
  appState.sendModeForTest = 'private';
  useEngineForTest(_Engine());
  await devWorld(container: side);
  setL10nLocale(const Locale('en'));
  lockState.openForTest(enabled: false);
  addTearDown(lockState.openForTest);
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('halo/platform'),
    (c) async => c.method == 'isBatteryExempt' ? true : null,
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      null,
    ),
  );
  t.view.physicalSize = const Size(1280, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  onDesktop = desk;
  addTearDown(() => onDesktop = false);
  addTearDown(() => linkedRoleForTest = false);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> _gone(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await _settle(t);
}

// the devices section as drawn: every widget under its title and its group
// by type, key, words and icon, and where the group sits under the title.
// with the sections before and after it
List<String> _devicesTree(WidgetTester t) {
  final out = <String>[];
  void walk(Element e) {
    final w = e.widget;
    final words = switch (w) {
      Text(:final data) => ' "$data"',
      RichText(:final text) => ' "${text.toPlainText()}"',
      Icon(:final icon) => ' icon ${icon?.codePoint}',
      _ => '',
    };
    // a global key's hash is new on every build: its kind is what counts
    final key = w.key is GlobalKey ? 'GlobalKey' : '${w.key}';
    out.add('${w.runtimeType} $key$words');
    e.visitChildren(walk);
  }

  final head = find.widgetWithText(HaloSection, l10n.settingsDevices);
  expect(head, findsOneWidget);
  final group = find.ancestor(
    of: find.text(l10n.onboardingLinkToMyPhone),
    matching: find.byType(HaloGroup),
  );
  expect(group, findsOneWidget);
  walk(t.element(head));
  walk(t.element(group));
  final h = t.getRect(head);
  final g = t.getRect(group);
  out.add('head ${h.size} group ${g.size} gap ${g.top - h.bottom}');
  final titles = [
    for (final s in t.widgetList<HaloSection>(find.byType(HaloSection)))
      s.label,
  ];
  final at = titles.indexOf(l10n.settingsDevices);
  out.add('between ${titles[at - 1]} and ${titles[at + 1]}');
  return out;
}

Future<List<String>> _settingsDevices(WidgetTester t) async {
  await t.pumpWidget(devApp(const SettingsScreen(), still: true));
  await _settle(t);
  await t.ensureVisible(find.text(l10n.onboardingLinkToMyPhone));
  await _settle(t);
  final tree = _devicesTree(t);
  await _gone(t);
  return tree;
}

// the erases asked, by their arguments
List<String> _erases() {
  final asked = <String>[];
  deskLinkErase = ({bool releaseHandle = false, bool thenLink = false}) async {
    asked.add('handle $releaseHandle link $thenLink');
  };
  addTearDown(() => deskLinkErase = wipeHalo);
  return asked;
}

Future<void> _openLink(WidgetTester t) async {
  await t.pumpWidget(devApp(const SettingsScreen(), still: true));
  await _settle(t);
  await t.ensureVisible(find.text(l10n.onboardingLinkToMyPhone));
  await t.tap(find.text(l10n.onboardingLinkToMyPhone));
  await _settle(t);
  expect(find.byType(DeskLinkScreen), findsOneWidget);
}

Future<void> _typeWord(WidgetTester t, String word) async {
  await t.tap(find.text(l10n.deskLinkReplace));
  await _settle(t);
  expect(find.text(l10n.deskLinkConfirmLine), findsOneWidget);
  await t.enterText(find.byType(TextField).last, word);
  await t.pump();
  await t.tap(find.text(l10n.deskLinkConfirmYes));
  await _settle(t);
}

void main() {
  group('settings', () {
    testWidgets('a computer with its own Kryfo offers the link', (t) async {
      await _world(t);
      await t.pumpWidget(devApp(const SettingsScreen(), still: true));
      await _settle(t);
      expect(find.text(l10n.onboardingLinkToMyPhone), findsOneWidget);
      expect(find.text(l10n.deskLinkRowHint), findsOneWidget);
      expect(find.text(l10n.settingsLinkedToYourPhone), findsNothing);
      expect(find.text(l10n.settingsUnlinkComputer), findsNothing);
      // the phone's devices row is not a computer's
      expect(find.text(l10n.devicesLinkedDevices), findsNothing);
      await _gone(t);
    });

    testWidgets('a linked computer says so and unlinks', (t) async {
      await _world(t);
      linkedRoleForTest = true;
      var unlinked = 0;
      deskUnlinkHere = () async => unlinked++;
      addTearDown(
        () => deskUnlinkHere = () async {
          throw StateError('test only');
        },
      );
      await t.pumpWidget(devApp(const SettingsScreen(), still: true));
      await _settle(t);
      expect(find.text(l10n.settingsLinkedToYourPhone), findsOneWidget);
      expect(find.text(l10n.settingsLinkedPhoneHint), findsOneWidget);
      expect(find.text(l10n.onboardingLinkToMyPhone), findsNothing);
      // a linked computer keeps no backup of its own
      expect(find.text(l10n.settingsBackUpIdentity), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desk_settings_linked.png'),
      );
      final row = find.text(l10n.settingsUnlinkComputer);
      await t.ensureVisible(row);
      // kept: nothing happens
      await t.tap(row);
      await _settle(t);
      expect(find.text(l10n.settingsUnlinkComputerTitle), findsOneWidget);
      expect(find.text(l10n.settingsUnlinkComputerLine), findsOneWidget);
      await t.tap(find.text(l10n.confirmSheetKeep));
      await _settle(t);
      expect(unlinked, 0);
      // confirmed: the devices page's own unlink, once
      await t.tap(row);
      await _settle(t);
      await t.tap(find.text(l10n.devicesLeaveYes));
      await _settle(t);
      expect(unlinked, 1);
      await _gone(t);
    });

    testWidgets('a phone shows neither row', (t) async {
      await _world(t, desk: false);
      await t.pumpWidget(devApp(const SettingsScreen(), still: true));
      await _settle(t);
      expect(find.text(l10n.onboardingLinkToMyPhone), findsNothing);
      expect(find.text(l10n.settingsUnlinkComputer), findsNothing);
      expect(find.text(l10n.devicesLinkedDevices), findsOneWidget);
      await _gone(t);
    });

    testWidgets('the decoy, a quiet session and a vault show the same rows', (
      t,
    ) async {
      await _world(t);
      final real = await _settingsDevices(t);
      expect(real, isNotEmpty);
      // the decoy
      await _world(t, side: HaloContainer.decoy);
      lockState.inDecoy = true;
      addTearDown(() => lockState.inDecoy = false);
      expect(deskLinkRows, isTrue);
      expect(await _settingsDevices(t), real);
      // a quiet session
      lockState.inDecoy = false;
      expect(await _settingsDevices(t), real);
      // a vault over the everyday side
      await _world(t);
      lockState.inVault = true;
      addTearDown(() => lockState.inVault = false);
      expect(await _settingsDevices(t), real);
      expect(find.text(l10n.settingsUnlinkComputer), findsNothing);
    });
  });

  group('the decoy\'s link', () {
    late Directory data;
    setUp(() => data = Directory.systemTemp.createTempSync('decoylink'));
    tearDown(() {
      if (data.existsSync()) data.deleteSync(recursive: true);
    });

    Map<String, String> folder() => {
      for (final f in data.listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: data.path): f.readAsStringSync(),
    };

    Future<void> decoyEnds(WidgetTester t, {required bool decoy}) async {
      await _world(t, side: HaloContainer.decoy);
      if (decoy) {
        lockState.inDecoy = true;
        addTearDown(() => lockState.inDecoy = false);
      }
      File(p.join(data.path, 'vault.kv')).writeAsStringSync('keys');
      File(p.join(data.path, 'halo.db')).writeAsStringSync('chats');
      File(p.join(data.path, 'k2.db')).writeAsStringSync('decoy');
      final before = folder();
      // an erase would empty the folder, a wipe would ask the host
      final erases = _erases();
      deskLinkErase = ({bool releaseHandle = false, bool thenLink = false}) async {
        erases.add('erase');
        data.deleteSync(recursive: true);
      };
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/platform'),
        (c) async {
          calls.add(c.method);
          return c.method == 'isBatteryExempt' ? true : null;
        },
      );
      final prefs = await SharedPreferences.getInstance();
      final kept = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      await _openLink(t);
      // the same page as the real one
      expect(find.text(l10n.deskLinkHead), findsOneWidget);
      expect(find.text(l10n.deskLinkGoesLine), findsOneWidget);
      expect(find.text(l10n.deskLinkBackupRow), findsOneWidget);
      expect(find.text(l10n.deskLinkNotStarted), findsNothing);
      // the wrong word: nothing, as in the real flow
      await _typeWord(t, 'link');
      expect(find.text(l10n.deskLinkNotStarted), findsNothing);
      // the word: a plain error, the page stays, nothing erased
      await _typeWord(t, l10n.settingsWipeWord);
      expect(find.text(l10n.deskLinkNotStarted), findsOneWidget);
      expect(find.text(l10n.deskLinkErasing), findsNothing);
      expect(find.text(l10n.deskLinkHead), findsOneWidget);
      expect(erases, isEmpty);
      expect(calls, isNot(contains('wipe')));
      expect(folder(), before);
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, kept);
      // again: the same error, still nothing
      await _typeWord(t, l10n.settingsWipeWord);
      expect(find.text(l10n.deskLinkNotStarted), findsOneWidget);
      expect(erases, isEmpty);
      expect(folder(), before);
      // back out to settings
      await t.tap(find.byTooltip(l10n.commonBack).first);
      await _settle(t);
      expect(find.byType(DeskLinkScreen), findsNothing);
      expect(erases, isEmpty);
      await _gone(t);
    }

    testWidgets('the decoy: a plain error after the word, nothing wiped', (
      t,
    ) async {
      await decoyEnds(t, decoy: true);
    });

    testWidgets('a quiet session: the same', (t) async {
      await decoyEnds(t, decoy: false);
    });

    testWidgets('its backup is the decoy side\'s own, a copy to keep', (
      t,
    ) async {
      await _world(t, side: HaloContainer.decoy);
      lockState.inDecoy = true;
      addTearDown(() => lockState.inDecoy = false);
      final erases = _erases();
      // the everyday side's date never shows here
      await keepLastBackup(HaloContainer.everyday);
      await _openLink(t);
      expect(find.text(l10n.settingsBackupNotYet), findsOneWidget);
      expect(find.text(l10n.settingsBackupToday), findsNothing);
      await t.tap(find.text(l10n.deskLinkBackupRow));
      await _settle(t);
      final page = t.widget<BackupScreen>(find.byType(BackupScreen));
      expect(page.keepOnly, isTrue);
      expect(page.withHiddenChats, isFalse);
      expect(find.text(l10n.backupMoveToAnotherDevice), findsNothing);
      await t.tap(find.byType(BackButton));
      await _settle(t);
      expect(find.text(l10n.deskLinkHead), findsOneWidget);
      expect(erases, isEmpty);
      await _gone(t);
      // its own date does
      await keepLastBackup(HaloContainer.decoy);
      await _openLink(t);
      expect(find.text(l10n.settingsBackupToday), findsOneWidget);
      await _gone(t);
    });

    testWidgets('a vault links for real', (t) async {
      await _world(t);
      lockState.inVault = true;
      addTearDown(() => lockState.inVault = false);
      final erases = _erases();
      await _openLink(t);
      await _typeWord(t, l10n.settingsWipeWord);
      expect(erases, ['handle true link true']);
      expect(find.text(l10n.deskLinkErasing), findsOneWidget);
      expect(find.text(l10n.deskLinkNotStarted), findsNothing);
      await _gone(t);
    });
  });

  group('the link page', () {
    testWidgets('says what goes, offers a backup, then the word', (t) async {
      await _world(t);
      final erases = _erases();
      await _openLink(t);
      // a window's height for the picture
      t.view.physicalSize = const Size(1280, 800);
      await _settle(t);
      expect(find.text(l10n.deskLinkHead), findsOneWidget);
      expect(find.text(l10n.deskLinkGoesLine), findsOneWidget);
      expect(find.text(l10n.deskLinkBackupRow), findsOneWidget);
      expect(find.text(l10n.deskLinkBackupHint), findsOneWidget);
      expect(find.text(l10n.settingsBackupNotYet), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desk_link_page.png'),
      );
      // the backup: the app's own page, a copy to keep and no move
      await t.tap(find.text(l10n.deskLinkBackupRow));
      await _settle(t);
      final page = t.widget<BackupScreen>(find.byType(BackupScreen));
      expect(page.keepOnly, isTrue);
      expect(find.text(l10n.backupMoveToAnotherDevice), findsNothing);
      // back from it: the flow again, nothing erased
      await t.tap(find.byType(BackButton));
      await _settle(t);
      expect(find.byType(BackupScreen), findsNothing);
      expect(find.text(l10n.deskLinkHead), findsOneWidget);
      expect(erases, isEmpty);
      await _gone(t);
    });

    testWidgets('a backup made shows when it was', (t) async {
      await _world(t);
      _erases();
      await keepLastBackup(HaloContainer.everyday);
      await _openLink(t);
      expect(find.text(l10n.settingsBackupToday), findsOneWidget);
      await _gone(t);
    });

    testWidgets('cancelled or a wrong word: nothing is erased', (t) async {
      await _world(t);
      final erases = _erases();
      await _openLink(t);
      // the sheet closed
      await t.tap(find.text(l10n.deskLinkReplace));
      await _settle(t);
      await t.tapAt(const Offset(640, 40));
      await _settle(t);
      expect(erases, isEmpty);
      expect(find.text(l10n.deskLinkHead), findsOneWidget);
      // the wrong word
      await _typeWord(t, 'link');
      expect(erases, isEmpty);
      expect(find.text(l10n.deskLinkErasing), findsNothing);
      // back to settings
      await t.tap(find.byTooltip(l10n.commonBack).first);
      await _settle(t);
      expect(find.byType(DeskLinkScreen), findsNothing);
      expect(erases, isEmpty);
      await _gone(t);
    });

    testWidgets('the word erases once, the handle back, then the code', (
      t,
    ) async {
      await _world(t);
      final erases = _erases();
      await _openLink(t);
      await _typeWord(t, l10n.settingsWipeWord);
      expect(erases, ['handle true link true']);
      expect(find.text(l10n.deskLinkErasing), findsOneWidget);
      expect(find.text(l10n.deskLinkErasingLine), findsOneWidget);
      expect(find.text(l10n.deskLinkNotStarted), findsNothing);
      // no way back out of an erase under way
      final pop = await t.binding.handlePopRoute();
      await _settle(t);
      expect(pop, isTrue);
      expect(find.text(l10n.deskLinkErasing), findsOneWidget);
      await _gone(t);
    });
  });

  group('after the erase', () {
    Future<void> onboarding(WidgetTester t, LinkStage stage) async {
      await _world(t);
      onboardingJoinFlow = () => _Flow(stage);
      addTearDown(() => onboardingJoinFlow = () => throw StateError('test'));
      deskLinkAtStart = true;
      addTearDown(() => deskLinkAtStart = false);
      await t.pumpWidget(
        devApp(
          OnboardingScreen(appState: appState, onComplete: () {}),
          still: true,
        ),
      );
      await _settle(t);
    }

    testWidgets('the code shows at once; back is a clean onboarding', (
      t,
    ) async {
      await onboarding(t, const LinkStage(LinkStep.showing, offer: 'x'));
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(find.text(l10n.joinStep1), findsOneWidget);
      // asked once: taken
      expect(deskLinkAtStart, isFalse);
      await t.tap(find.byTooltip(l10n.commonBack).first);
      await _settle(t);
      expect(find.byType(JoinScreen), findsNothing);
      expect(find.text(l10n.onboardingBegin), findsOneWidget);
      expect(find.text(l10n.onboardingLinkToMyPhone), findsOneWidget);
      await _gone(t);
    });

    testWidgets('a failed link offers a new code, back is onboarding', (
      t,
    ) async {
      await onboarding(
        t,
        const LinkStage(LinkStep.failed, end: LinkEnd.interrupted),
      );
      expect(find.text(l10n.devicesLinkStopped), findsOneWidget);
      expect(find.text(l10n.commonTryAgain), findsOneWidget);
      await t.tap(find.byTooltip(l10n.commonBack).first);
      await _settle(t);
      expect(find.byType(JoinScreen), findsNothing);
      expect(find.text(l10n.onboardingBegin), findsOneWidget);
      await _gone(t);
    });

    testWidgets('an ordinary start never opens the link', (t) async {
      await _world(t);
      onboardingJoinFlow = () => _Flow(const LinkStage(LinkStep.showing));
      addTearDown(() => onboardingJoinFlow = () => throw StateError('test'));
      await t.pumpWidget(
        devApp(
          OnboardingScreen(appState: appState, onComplete: () {}),
          still: true,
        ),
      );
      await _settle(t);
      expect(find.byType(JoinScreen), findsNothing);
      await _gone(t);
    });
  });

  group('the wipe for a link', () {
    late Directory data;
    setUp(() => data = Directory.systemTemp.createTempSync('desklink'));
    tearDown(() {
      if (data.existsSync()) data.deleteSync(recursive: true);
    });

    test('a new run asked only after every file is gone', () async {
      File(p.join(data.path, 'vault.kv')).writeAsStringSync('x');
      final order = <String>[];
      final host = DesktopHost(
        dataDir: data.path,
        exit: (c) => order.add('exit $c'),
        relaunch: () async => order.add('reopen'),
        relaunchLink: () async {
          order.add('link run, files ${data.existsSync()}');
        },
      );
      await host.wipe(link: true);
      expect(order, ['link run, files false', 'exit 0']);
      order.clear();
      Directory(data.path).createSync();
      await host.wipe();
      expect(order, ['exit 0']);
    });

    test('the channel carries the link to the host', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final asked = <Object?>[];
      final m = TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger;
      m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (
        c,
      ) async {
        if (c.method == 'wipe') asked.add(c.arguments);
        return false;
      });
      addTearDown(
        () => m.setMockMethodCallHandler(
          const MethodChannel('halo/platform'),
          null,
        ),
      );
      final exits = <int>[];
      wipeExit = exits.add;
      addTearDown(() => wipeExit = exit);
      await wipeFinish(link: true);
      await wipeFinish();
      expect(asked, [
        {'link': true},
        null,
      ]);
      expect(exits, [0, 0]);
      // and the desktop's answer to it
      final runs = <String>[];
      final host = DesktopHost(
        dataDir: data.path,
        exit: (c) => runs.add('exit $c'),
        relaunchLink: () async => runs.add('link'),
      );
      final dm = DesktopMessenger(m, desktopAnswers(host, DesktopDb()));
      const codec = StandardMethodCodec();
      await dm.send(
        'halo/platform',
        codec.encodeMethodCall(const MethodCall('wipe', {'link': true})),
      );
      Directory(data.path).createSync();
      await dm.send(
        'halo/platform',
        codec.encodeMethodCall(const MethodCall('wipe')),
      );
      expect(runs, ['link', 'exit 0', 'exit 0']);
    });

    test('a run opens the link only when asked, on a folder with no vault', () {
      expect(linkAsked(data.path, const {}), isFalse);
      expect(linkAsked(data.path, const {kLinkNextEnv: ''}), isFalse);
      expect(linkAsked(data.path, const {kLinkNextEnv: '1'}), isTrue);
      File(p.join(data.path, 'vault.kv')).writeAsStringSync('x');
      expect(linkAsked(data.path, const {kLinkNextEnv: '1'}), isFalse);
    });
  });
}
