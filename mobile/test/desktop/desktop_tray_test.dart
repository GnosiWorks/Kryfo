// SPDX-License-Identifier: GPL-3.0-or-later
// the computer's part of getting messages: the tray switch and the start
// with the computer, each platform's place mocked (the autostart file in a
// temporary folder, the run key, the portal). the notifications page on a
// computer shows them in place of the delivery modes, battery tips and
// android's sound page; the phone shows what it showed. the icon disguise
// is gone on a computer, the captive line has no android button, and the
// lock words name the computer in the real app and the decoy alike
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/battery_brand.dart' show PhoneBrand;
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/desk_bridge_line.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_run.dart';
import 'package:kryfo/desktop/desktop_start.dart'
    show quietDetails, startedHidden, trayBeforeOpen, trayWords;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show LockGuard;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useEngineForTest,
        AppStateRoute,
        AppStateDelivery;
import 'package:kryfo/notifications.dart';
import 'package:kryfo/screens/icon_screen.dart';
import 'package:kryfo/screens/notifications_screen.dart';
import 'package:kryfo/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart' show devApp, devWorld;

class _Tray implements TrayHost {
  final calls = <String>[];
  bool? there = true;
  // answers given before [there], one per ask
  final early = <bool?>[];
  int asked = 0;
  @override
  Future<void> show() async => calls.add('show');
  @override
  Future<void> hide() async => calls.add('hide');
  @override
  Future<bool?> shown() async {
    asked++;
    return early.isNotEmpty ? early.removeAt(0) : there;
  }
}

class _Kv {
  final m = <String, String>{};
  String? read(String k) => m[k];
  Future<void> write(String k, String v) async => m[k] = v;
}

class _Place implements StartPlace {
  StartAnswer now = StartAnswer.off;
  bool refuse = false;
  final asked = <bool>[];
  int mended = 0;
  @override
  Future<void> mend() async => mended++;
  @override
  Future<StartAnswer> read() async => now;
  @override
  Future<StartAnswer> set(bool on) async {
    asked.add(on);
    if (refuse) return StartAnswer.refused;
    return now = on ? StartAnswer.on : StartAnswer.off;
  }
}

class _RunKey implements RunKey {
  final values = <String, String>{};
  bool refuse = false;
  bool off = false;
  @override
  String? value(String name) => values[name];
  @override
  bool setValue(String name, String data) {
    if (refuse) return false;
    values[name] = data;
    return true;
  }

  @override
  bool deleteValue(String name) {
    if (refuse) return false;
    values.remove(name);
    return true;
  }

  @override
  bool switchedOff(String name) => off;
}

class _Portal implements BackgroundPortal {
  bool? answer = true;
  final asked = <bool>[];
  @override
  Future<bool?> autostart(bool on) async {
    asked.add(on);
    return answer;
  }
}

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Faces implements AppFaceChannel {
  @override
  Future<AppFace?> read() async => AppFace.kryfo;
  @override
  Future<bool> switchTo(AppFace f) async => true;
}

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel c) async {}
}

DesktopRun _run(_Kv kv, _Tray tray, StartPlace? place) => DesktopRun(
  tray: tray,
  place: place,
  read: kv.read,
  write: kv.write,
  trayWait: Duration.zero,
);

Future<void> _world(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  forgetAppFace();
  appFaceChannel = _Faces();
  FlutterLocalNotificationsPlatform.instance = _Shade();
  playBuildForTest = false;
  addTearDown(() => playBuildForTest = null);
  appState.sendModeForTest = 'private';
  appState.googleAvailableForTest = false;
  appState.deliveryModeForTest = DeliveryMode.always;
  useEngineForTest(_Engine());
  await devWorld();
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
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(seconds: 1));
  }
}

const _phoneOnly = [
  'gettingMessagesAlwaysOn',
  'gettingMessagesCheckIns',
  'deliveryModeThroughAHelperApp',
  'notificationsHowTheyReachYou',
  'notificationsSoundAndVibration',
  'notificationsBatteryTips',
  'settingsRunInBackground',
];

String _word(String key) => switch (key) {
  'gettingMessagesAlwaysOn' => l10n.gettingMessagesAlwaysOn,
  'gettingMessagesCheckIns' => l10n.gettingMessagesCheckIns,
  'deliveryModeThroughAHelperApp' => l10n.deliveryModeThroughAHelperApp,
  'notificationsHowTheyReachYou' => l10n.notificationsHowTheyReachYou,
  'notificationsSoundAndVibration' => l10n.notificationsSoundAndVibration,
  'notificationsBatteryTips' => l10n.notificationsBatteryTips,
  _ => l10n.settingsRunInBackground,
};

void main() {
  tearDown(() {
    onDesktop = false;
    desktopRun = null;
  });

  group('the tray switch', () {
    test('on by default: the icon goes up once the vault is open', () async {
      final kv = _Kv(), tray = _Tray();
      final run = _run(kv, tray, null);
      expect(run.trayOn, isTrue);
      await run.begin();
      expect(tray.calls, ['show']);
      expect(run.trayShown, isTrue);
      expect(run.canStart, isFalse);
    });

    test('off: the icon goes, and the next start keeps it off', () async {
      final kv = _Kv(), tray = _Tray();
      final run = _run(kv, tray, null);
      await run.begin();
      await run.setTray(false);
      expect(tray.calls, ['show', 'hide']);
      expect(run.trayOn, isFalse);
      expect(jsonDecode(kv.m[runEntry]!), {'tray': false});
      final tray2 = _Tray();
      final again = _run(kv, tray2, null);
      await again.begin();
      expect(tray2.calls, isEmpty);
      await again.setTray(true);
      expect(tray2.calls, ['show']);
      expect(again.trayOn, isTrue);
    });

    test('a desktop with no tray says so', () async {
      final tray = _Tray()..there = false;
      final run = _run(_Kv(), tray, null);
      await run.begin();
      expect(run.trayShown, isFalse);
    });

    test('an icon not yet in its place is asked once more', () async {
      final tray = _Tray()..early.add(false);
      final run = _run(_Kv(), tray, null);
      await run.begin();
      expect(run.trayShown, isTrue);
      await run.setTray(false);
      tray.early.add(false);
      await run.setTray(true);
      expect(run.trayShown, isTrue);
      expect(tray.asked, 4);
    });
  });

  group('start with my computer', () {
    test('on and off through the place, refused said', () async {
      final place = _Place();
      final run = _run(_Kv(), _Tray(), place);
      await run.refresh();
      expect(run.start, StartAnswer.off);
      expect(await run.setStart(true), StartAnswer.on);
      expect(run.start, StartAnswer.on);
      expect(run.startRefused, isFalse);
      place.refuse = true;
      expect(await run.setStart(false), StartAnswer.refused);
      expect(run.startRefused, isTrue);
      // what the computer has, read back
      expect(run.start, StartAnswer.on);
    });

    test('linux: an autostart entry, quoted, made and taken away', () async {
      final tmp = Directory.systemTemp.createTempSync('kryfo-autostart');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dir = p.join(tmp.path, 'autostart');
      final place = LinuxStart(dir, '/opt/my apps/kryfo/kryfo');
      expect(await place.read(), StartAnswer.off);
      expect(await place.set(true), StartAnswer.on);
      final f = File(p.join(dir, autostartFile));
      final text = f.readAsStringSync();
      expect(text, contains('Exec="/opt/my apps/kryfo/kryfo" --hidden\n'));
      expect(text, startsWith('[Desktop Entry]\nType=Application\n'));
      expect(Directory(dir).listSync(), hasLength(1));
      expect(await place.read(), StartAnswer.on);
      // switched off in the desktop's own settings
      f.writeAsStringSync('${text}Hidden=true\n');
      expect(await place.read(), StartAnswer.off);
      expect(await place.set(false), StartAnswer.off);
      expect(f.existsSync(), isFalse);
      expect(await place.set(false), StartAnswer.off);
    });

    test('linux: an entry for another file is written for this one', () async {
      final tmp = Directory.systemTemp.createTempSync('kryfo-autostart');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dir = p.join(tmp.path, 'autostart');
      final f = File(p.join(dir, autostartFile));
      await LinuxStart(dir, '/old/kryfo').set(true);
      final run = DesktopRun(
        tray: _Tray(),
        place: LinuxStart(dir, '/new/kryfo'),
        read: _Kv().read,
        write: _Kv().write,
        trayWait: Duration.zero,
      );
      await run.begin();
      expect(f.readAsStringSync(), contains('Exec="/new/kryfo" --hidden\n'));
      expect(run.start, StartAnswer.on);
      // the same file is left as it is
      final kept = '${f.readAsStringSync()}X-Kept=1\n';
      f.writeAsStringSync(kept);
      await LinuxStart(dir, '/new/kryfo').mend();
      expect(f.readAsStringSync(), kept);
      // switched off in the desktop's settings stays off and untouched
      final held = '${autostartEntry('"/old/kryfo"')}Hidden=true\n';
      f.writeAsStringSync(held);
      await LinuxStart(dir, '/new/kryfo').mend();
      expect(f.readAsStringSync(), held);
      // no entry: none is made
      f.deleteSync();
      await LinuxStart(dir, '/new/kryfo').mend();
      expect(f.existsSync(), isFalse);
    });

    test('the portal is told why it is asked', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Object? args;
      final m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      m.setMockMethodCallHandler(runChannel, (call) async {
        args = call.arguments;
        return true;
      });
      addTearDown(() => m.setMockMethodCallHandler(runChannel, null));
      expect(await const ChannelPortal().autostart(true), isTrue);
      expect(args, {'on': true, 'reason': l10n.desktopStartHint});
    });

    test('linux: a folder that cannot be made is refused', () async {
      final tmp = Directory.systemTemp.createTempSync('kryfo-autostart');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final blocker = File(p.join(tmp.path, 'autostart'))
        ..writeAsStringSync('');
      final place = LinuxStart(blocker.path, '/usr/bin/kryfo');
      expect(await place.set(true), StartAnswer.refused);
      expect(await place.read(), StartAnswer.off);
    });

    test('the exec line is quoted and escaped as the spec asks', () {
      expect(desktopExec('/usr/bin/kryfo'), r'"/usr/bin/kryfo"');
      expect(desktopExec('/a b/kryfo'), r'"/a b/kryfo"');
      // \$ in the quoted arg, then each backslash doubled as a string value
      expect(desktopExec(r'/x$y/k'), r'"/x\\$y/k"');
      expect(desktopExec('/50%/k'), '"/50%%/k"');
      expect(desktopExec(r'/q"/k'), r'"/q\\"/k"');
      expect(desktopExec('/a\nb'), isNull);
      expect(desktopExec(''), isNull);
    });

    test('windows: the run key holds the quoted path', () async {
      final key = _RunKey();
      const exe = r'C:\Program Files\Kryfo\kryfo.exe';
      final place = WindowsStart(key, exe);
      expect(await place.read(), StartAnswer.off);
      expect(await place.set(true), StartAnswer.on);
      expect(key.values, {
        runValueName: r'"C:\Program Files\Kryfo\kryfo.exe" --hidden',
      });
      // switched off in windows' startup apps: said, and left theirs
      key.off = true;
      expect(await place.read(), StartAnswer.heldOff);
      expect(await place.set(true), StartAnswer.heldOff);
      key.off = false;
      expect(await place.set(false), StartAnswer.off);
      expect(key.values, isEmpty);
      key.refuse = true;
      expect(await place.set(true), StartAnswer.refused);
      expect(await place.read(), StartAnswer.off);
    });

    test('flatpak: the portal asks, and its answer is kept', () async {
      final kv = _Kv();
      final portal = _Portal();
      final place = PortalStart(portal, read: kv.read, write: kv.write);
      expect(await place.read(), StartAnswer.off);
      expect(await place.set(true), StartAnswer.on);
      expect(await place.read(), StartAnswer.on);
      portal.answer = false;
      expect(await place.set(false), StartAnswer.refused);
      expect(await place.read(), StartAnswer.on);
      portal.answer = null;
      expect(await place.set(false), StartAnswer.refused);
      portal.answer = true;
      expect(await place.set(false), StartAnswer.off);
      expect(portal.asked, [true, false, false, false]);
      // the tray switch and the portal's answer share the entry
      final run = _run(kv, _Tray(), place);
      await run.setTray(false);
      expect(jsonDecode(kv.m[runEntry]!), {
        'portalStart': false,
        'tray': false,
      });
    });

    test('every place is mended once the vault opens', () async {
      final place = _Place();
      await _run(_Kv(), _Tray(), place).begin();
      expect(place.mended, 1);
    });

    test(
      'linux: an entry from before the hidden start gets the flag',
      () async {
        final tmp = Directory.systemTemp.createTempSync('kryfo-autostart');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final dir = p.join(tmp.path, 'autostart');
        Directory(dir).createSync();
        final f = File(p.join(dir, autostartFile))
          ..writeAsStringSync(
            '[Desktop Entry]\nType=Application\nName=Kryfo\n'
            'Exec="/opt/kryfo/kryfo"\nX-GNOME-Autostart-enabled=true\n',
          );
        await LinuxStart(dir, '/opt/kryfo/kryfo').mend();
        expect(
          f.readAsStringSync(),
          contains('Exec="/opt/kryfo/kryfo" --hidden\n'),
        );
        expect(
          f.readAsStringSync(),
          isNot(contains('Exec="/opt/kryfo/kryfo"\n')),
        );
      },
    );

    test('linux: any desktop\'s off is off, spaces or not', () async {
      bool off(String body) => entrySaysOff('[Desktop Entry]\n$body\n');
      expect(off('X-MATE-Autostart-enabled=false'), isTrue);
      expect(off('X-KDE-Autostart-enabled = false'), isTrue);
      expect(off('  Hidden = true  '), isTrue);
      expect(off('X-GNOME-Autostart-enabled=false'), isTrue);
      expect(off('X-GNOME-Autostart-enabled=true'), isFalse);
      expect(off('Hidden=false'), isFalse);
      expect(off('# Hidden=true'), isFalse);
      expect(off('X-GNOME-Autostart-Delay=false'), isFalse);
      expect(off('Name=Hidden=true'), isFalse);
      // another group's keys are not the entry's
      expect(off('Exec=k\n[Desktop Action x]\nHidden=true'), isFalse);
      // MATE's off survives a moved bundle: read off, so mend leaves it
      final tmp = Directory.systemTemp.createTempSync('kryfo-autostart');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f = File(p.join(tmp.path, autostartFile));
      final held =
          '${autostartEntry('"/old/kryfo"')}X-MATE-Autostart-enabled = false\n';
      f.writeAsStringSync(held);
      final place = LinuxStart(tmp.path, '/new/kryfo');
      expect(await place.read(), StartAnswer.off);
      await place.mend();
      expect(f.readAsStringSync(), held);
    });

    test('linux: the appimage only when this binary is in its mount', () {
      const exe = '/tmp/.mount_KryfoX/usr/bin/kryfo';
      const env = {
        'APPIMAGE': '/home/u/Kryfo.AppImage',
        'APPDIR': '/tmp/.mount_KryfoX',
      };
      expect(linuxStartFile(exe, env), '/home/u/Kryfo.AppImage');
      // started from another appimage: its path is not ours
      expect(linuxStartFile('/opt/kryfo/kryfo', env), '/opt/kryfo/kryfo');
      expect(linuxStartFile(exe, {'APPIMAGE': '/home/u/Kryfo.AppImage'}), exe);
      expect(linuxStartFile(exe, {...env, 'APPIMAGE': 'Kryfo.AppImage'}), exe);
      expect(linuxStartFile(exe, {...env, 'APPDIR': 'rel'}), exe);
      expect(linuxStartFile('/opt/kryfo/kryfo', const {}), '/opt/kryfo/kryfo');
    });

    test(
      'windows: a value from before gets the flag, the switch theirs',
      () async {
        const exe = r'C:\Kryfo\kryfo.exe';
        final key = _RunKey()..values[runValueName] = r'"C:\Old\kryfo.exe"';
        key.off = true;
        final place = WindowsStart(key, exe);
        await place.mend();
        expect(key.values[runValueName], r'"C:\Kryfo\kryfo.exe" --hidden');
        expect(await place.read(), StartAnswer.heldOff);
        // none: none is made
        final none = _RunKey();
        await WindowsStart(none, exe).mend();
        expect(none.values, isEmpty);
      },
    );

    test('flatpak: the portal is never asked without the switch', () async {
      // a grant from before: the user may have switched it off outside
      // kryfo, so a start or an unlock asks nothing
      final kv = _Kv()..m[runEntry] = jsonEncode({'portalStart': true});
      final portal = _Portal();
      final place = PortalStart(portal, read: kv.read, write: kv.write);
      await place.mend();
      await _run(kv, _Tray(), place).begin();
      expect(portal.asked, isEmpty);
      expect(jsonDecode(kv.m[runEntry]!), {'portalStart': true});
      // the switch asks
      expect(await place.set(true), StartAnswer.on);
      expect(portal.asked, [true]);
    });

    test('a hidden start puts the icon up before the vault', () async {
      var said = 0;
      Future<void> words() async => said++;
      expect(
        await trayBeforeOpen(hidden: () async => true, words: words),
        isTrue,
      );
      expect(said, 1);
      expect(
        await trayBeforeOpen(hidden: () async => false, words: words),
        isFalse,
      );
      expect(
        await trayBeforeOpen(hidden: () async => null, words: words),
        isFalse,
      );
      expect(said, 1);
    });

    test('the runner says whether it started hidden', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      m.setMockMethodCallHandler(runChannel, (call) async {
        calls.add(call);
        return call.method == 'startHidden' ? true : null;
      });
      addTearDown(() => m.setMockMethodCallHandler(runChannel, null));
      expect(await startedHidden(), isTrue);
      expect(await trayBeforeOpen(), isTrue);
      expect(calls.last.method, 'tray');
      expect(calls.last.arguments, trayWords(locked: true));
      m.setMockMethodCallHandler(runChannel, null);
      // a runner that does not know the call: a normal start
      expect(await startedHidden(), isNull);
      expect(await trayBeforeOpen(), isFalse);
    });

    test('before the vault the tip says to open, the same in a decoy', () {
      final locked = trayWords(locked: true);
      expect(locked['tip'], l10n.desktopTrayLockedTip);
      expect(locked['open'], trayWords()['open']);
      expect(trayWords()['tip'], l10n.desktopTrayTip);
      lockState.inDecoy = true;
      addTearDown(() => lockState.inDecoy = false);
      expect(trayWords(locked: true), locked);
    });

    test('the phone build has no place and no runner', () {
      expect(onDesktop, isFalse);
      expect(desktopRun, isNull);
    });
  });

  group('the notifications page', () {
    testWidgets('a computer: its own section in place of the modes', (t) async {
      await _world(t);
      onDesktop = true;
      final tray = _Tray(), place = _Place()..refuse = true;
      final run = _run(_Kv(), tray, place);
      desktopRun = run;
      await t.pumpWidget(devApp(const NotificationsScreen(), still: true));
      await _settle(t);
      for (final k in _phoneOnly) {
        expect(find.text(_word(k)), findsNothing, reason: k);
      }
      expect(find.text(l10n.desktopRunSection), findsOneWidget);
      expect(find.text(l10n.desktopTrayRow), findsOneWidget);
      expect(find.text(l10n.desktopTrayHint), findsOneWidget);
      expect(find.text(l10n.desktopStartRow), findsOneWidget);
      expect(find.text(l10n.notificationsEachShows), findsOneWidget);
      expect(find.text(l10n.desktopTrayOffLine), findsNothing);

      await t.tap(find.text(l10n.desktopTrayRow));
      await _settle(t);
      expect(tray.calls, ['hide']);
      expect(run.trayOn, isFalse);
      expect(find.text(l10n.desktopTrayOffLine), findsOneWidget);

      await t.tap(find.text(l10n.desktopStartRow));
      await _settle(t);
      expect(place.asked, [true]);
      expect(find.text(l10n.desktopStartRefused), findsOneWidget);
      place.refuse = false;
      await t.tap(find.text(l10n.desktopStartRow));
      await _settle(t);
      expect(run.start, StartAnswer.on);
      expect(find.text(l10n.desktopStartRefused), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a desktop with no tray, and windows holding the start off', (
      t,
    ) async {
      await _world(t);
      onDesktop = true;
      final place = _Place()..now = StartAnswer.heldOff;
      desktopRun = _run(_Kv(), _Tray()..there = false, place);
      await t.pumpWidget(devApp(const NotificationsScreen(), still: true));
      await _settle(t);
      expect(find.text(l10n.desktopTrayNoneLine), findsOneWidget);
      expect(find.text(l10n.desktopStartHeldOff), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a computer: a sound switch, kept, read by every post', (
      t,
    ) async {
      await _world(t);
      onDesktop = true;
      addTearDown(() => deskSound.value = true);
      desktopRun = _run(_Kv(), _Tray(), _Place());
      await t.pumpWidget(devApp(const NotificationsScreen(), still: true));
      await _settle(t);
      expect(
        find.text(l10n.notificationsSoundAndVibrationDesk),
        findsOneWidget,
      );
      expect(find.text(l10n.notificationsPlaySound), findsOneWidget);
      expect(find.text(l10n.notificationsPlaySoundHint), findsOneWidget);
      expect(quietDetails().suppressSound, isFalse);
      await t.tap(find.text(l10n.notificationsPlaySound));
      await _settle(t);
      expect(deskSound.value, isFalse);
      expect(quietDetails().suppressSound, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('desk_sound'), isFalse);
      // the next start reads it back
      deskSound.value = true;
      await readDeskSound();
      expect(deskSound.value, isFalse);
      await t.tap(find.text(l10n.notificationsPlaySound));
      await _settle(t);
      expect(deskSound.value, isTrue);
      expect(prefs.getBool('desk_sound'), isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the phone: the modes, sound and battery, no tray', (t) async {
      await _world(t);
      await t.pumpWidget(devApp(const NotificationsScreen(), still: true));
      await _settle(t);
      for (final k in _phoneOnly) {
        expect(find.text(_word(k)), findsWidgets, reason: k);
      }
      expect(find.text(l10n.desktopRunSection), findsNothing);
      expect(find.text(l10n.desktopTrayRow), findsNothing);
      expect(find.text(l10n.notificationsPlaySound), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the icon disguise', () {
    Future<void> open(WidgetTester t) async {
      await _world(t);
      await t.pumpWidget(
        devApp(
          IconScreen(
            hideLine: () async => hideAppsLine(PhoneBrand.samsung, 34),
            guard: LockGuard(isLocked: () => false),
            onSwitch: (_) async => true,
          ),
          still: true,
        ),
      );
      await _settle(t);
    }

    testWidgets('gone on a computer: only what notifications show', (t) async {
      onDesktop = true;
      await open(t);
      expect(find.text(l10n.iconSectionTitle), findsNothing);
      expect(find.text(l10n.iconWhatChanges), findsNothing);
      expect(find.text(l10n.settingsIconAndNotifications), findsNothing);
      expect(find.text(l10n.settingsNotifications), findsOneWidget);
      expect(find.text(l10n.gettingMessagesWhatShows), findsOneWidget);
      for (final f in AppFace.values) {
        expect(
          find.bySemanticsLabel(l10n.iconButtonLabel(f.label)),
          findsNothing,
        );
      }
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('there on the phone', (t) async {
      await open(t);
      expect(find.text(l10n.iconSectionTitle), findsOneWidget);
      expect(find.text(l10n.iconWhatChanges), findsOneWidget);
      expect(find.text(l10n.settingsIconAndNotifications), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    test('the settings row sits under !onDesktop', () {
      final src = File('lib/screens/settings_screen.dart').readAsStringSync();
      final at = src.indexOf('label: l10n.settingsIconAndNotifications');
      final guard = src.lastIndexOf('if (!onDesktop)', at);
      expect(guard, greaterThan(0));
      expect(src.substring(guard, at), contains('ValueListenableBuilder'));
      expect(
        src.substring(guard, at).split('\n').length,
        lessThan(8),
        reason: 'the guard belongs to the row',
      );
    });
  });

  group('the captive line', () {
    test('the phone opens wi-fi settings; a computer has no button', () {
      const portal = BridgeStatus(mode: 'auto', phase: 'captive');
      final phone = deskBridgeLine(bridgeStatusLine(portal));
      expect(phone.action, BridgeAction.openWifi);
      expect(phone.detail, l10n.bridgesThisNetworkWantsA);
      onDesktop = true;
      final desk = deskBridgeLine(bridgeStatusLine(portal));
      expect(desk.action, isNull);
      expect(desk.head, l10n.bridgesSignInToThisWifi);
      expect(desk.detail, l10n.bridgesThisNetworkWantsADesk);
      expect(desk.detail, contains('browser'));
      expect(desk.detail, isNot(contains('Wi-Fi settings')));
      // the phone's line, untouched, for any other phase
      const off = BridgeStatus(mode: 'auto', phase: 'offline');
      final plain = bridgeStatusLine(off);
      expect(identical(deskBridgeLine(plain), plain), isTrue);
      expect(
        File('lib/screens/bridges_screen.dart').readAsStringSync(),
        contains('deskBridgeLine(appState.bridgeLine)'),
      );
    });
  });

  group('the lock words', () {
    const keys = [
      'pinsThePinGoesAnd',
      'pinsTurnOffWithDecoy',
      'pinsAdvancedLine',
      'pinsWipeLine',
      'flowWipe1',
      'flowLaw',
      'flowVaultReplace',
      'howVault',
      'flowVaultPassLine',
      'flowDecoyShade',
    ];
    List<String> shown() => [
      l10n.pinsThePinGoesAndShown,
      l10n.pinsTurnOffWithDecoyShown,
      l10n.pinsAdvancedLineShown,
      l10n.pinsWipeLineShown,
      l10n.flowWipe1Shown,
      l10n.flowLawShown,
      l10n.flowVaultReplaceShown,
      l10n.howVaultShown,
      l10n.flowVaultPassLineShown,
      l10n.flowDecoyShadeShown,
    ];
    final arbs = {
      for (final f in Directory('lib/l10n').listSync().whereType<File>())
        if (f.path.endsWith('.arb'))
          p.basenameWithoutExtension(f.path).substring(4):
              (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>(),
    };

    test('the phone reads its own words, a computer the computer\'s', () {
      final en = arbs['en']!;
      expect(shown(), [for (final k in keys) en[k]]);
      onDesktop = true;
      final desk = shown();
      expect(desk, [for (final k in keys) en['${k}Desk']]);
      for (final w in desk) {
        expect(w, isNot(matches(RegExp('phone|fingerprint|shade|keyboard'))));
      }
    });

    test('the decoy shows exactly what the real app shows', () {
      onDesktop = true;
      lockState.inDecoy = false;
      final real = shown();
      lockState.inDecoy = true;
      addTearDown(() => lockState.inDecoy = false);
      expect(shown(), real);
    });

    test('in all 17 languages, each its own and in sentence case', () {
      expect(arbs, hasLength(17));
      final added = [
        for (final k in keys) '${k}Desk',
        'bridgesThisNetworkWantsADesk',
        'desktopRunSection',
        'desktopTrayRow',
        'desktopTrayHint',
        'desktopTrayOffLine',
        'desktopTrayNoneLine',
        'desktopStartRow',
        'desktopStartHint',
        'desktopStartRefused',
        'desktopStartHeldOff',
        'desktopTrayLockedTip',
      ];
      for (final MapEntry(key: lang, value: arb) in arbs.entries) {
        for (final k in added) {
          final v = arb[k];
          expect(v, isA<String>(), reason: '$lang $k');
          v as String;
          expect(v.trim(), isNotEmpty, reason: '$lang $k');
          expect(v, isNot(contains('\u2014')), reason: '$lang $k');
          if (k.endsWith('Desk')) {
            expect(v, isNot(arb[k.substring(0, k.length - 4)]), reason: k);
          }
        }
        if (lang == 'en') {
          for (final k in added) {
            final v = arb[k] as String;
            final words = [
              for (final sentence in v.split(RegExp(r'[.,] ')))
                ...sentence.split(' ').skip(1),
            ];
            for (final w in words) {
              // windows' own page names
              if (RegExp(
                r'^(Kryfo|PIN|Windows|Settings|Apps|Startup)\b',
              ).hasMatch(w)) {
                continue;
              }
              expect(
                w,
                isNot(matches(RegExp(r'^[A-Z][a-z]'))),
                reason: '$k: $w',
              );
            }
          }
        }
      }
    });

    test('no fingerprint line in the hidden chats steps on a computer', () {
      final src = File('lib/screens/pin_flow_screen.dart').readAsStringSync();
      expect(
        src,
        contains('if (!onDesktop) (Icons.fingerprint, l10n.flowVaultFinger)'),
      );
    });
  });

  test('closing the lock screen quits: the tray waits for the vault', () {
    final src = File('lib/desktop/desktop_start.dart').readAsStringSync();
    final open = src.indexOf('onOpen: () {');
    expect(open, greaterThan(0));
    expect(src.indexOf('run.begin()'), greaterThan(open));
    expect(src.indexOf('unawaited(sayTrayWords())'), -1);
    // before the vault, only a hidden start puts the icon up
    final early = src.indexOf('await trayBeforeOpen()');
    expect(early, greaterThan(0));
    expect(early, lessThan(open));
    expect(debugDefaultTargetPlatformOverride, isNull);
  });

  group('the first close to the tray, on linux too', () {
    test('the words carry the line only when asked', () {
      expect(trayWords().containsKey('hint'), isFalse);
      expect(trayWords(locked: true).containsKey('hint'), isFalse);
      expect(trayWords(hint: true)['hint'], l10n.desktopTrayStillRunning);
    });

    test('said once: kept after the runner says so', () async {
      final kv = <String, String>{};
      final run = DesktopRun(
        tray: _Tray(),
        place: null,
        read: (k) => kv[k],
        write: (k, v) async => kv[k] = v,
      );
      expect(run.trayHinted, isFalse);
      await run.markHinted();
      expect(run.trayHinted, isTrue);
      expect(run.trayOn, isTrue);
    });

    test('the gtk runner says it as a notification, then tells dart', () {
      final cc = File('linux/runner/my_application.cc').readAsStringSync();
      expect(cc, contains('map_string(args, "hint")'));
      final hide = cc.indexOf('gtk_widget_hide(widget);');
      expect(cc.indexOf('say_tray_hint(self);', hide), greaterThan(hide));
      expect(cc, contains('g_application_send_notification'));
      expect(cc, contains('"hinted"'));
      expect(
        File('lib/desktop/desktop_start.dart').readAsStringSync(),
        contains("call.method == 'hinted'"),
      );
    });
  });
}
