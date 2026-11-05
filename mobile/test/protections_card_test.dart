// SPDX-License-Identifier: GPL-3.0-or-later
// your protections: tor, the app lock and the last backup on a phone; on a
// computer the passphrase that opens its vault in place of the app lock.
// each side reads its own backup time, and a decoy never the real one's
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show kRestorablePrefs;
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/dates.dart' show dayMonthMaybeYear;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/last_backup.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devClose, devWorld;

class _Lock extends ChangeNotifier implements ComputerLockView {
  _Lock(this.real, {this.decoySeal});
  ComputerSeal real;
  // the decoy's own note, when it has one
  ComputerSeal? decoySeal;

  @override
  ComputerSeal sealedBy({required bool decoy}) =>
      decoy ? (decoySeal ?? real) : real;

  @override
  bool passphraseOn({required bool decoy}) =>
      sealedBy(decoy: decoy) == ComputerSeal.passphrase;

  @override
  Widget page({required bool decoy}) =>
      Scaffold(body: Text(decoy ? 'decoy pass page' : 'pass page'));

  @override
  bool backupWise({required bool decoy}) => false;
  @override
  bool backupCardDue({required bool decoy}) => false;
  @override
  Future<void> backupCardSeen({required bool decoy}) async {}
  @override
  void decoyNoteRead(String? note) {}

  void set(ComputerSeal s) {
    real = s;
    notifyListeners();
  }
}

// pinned clocks at both ends of a day, twelve days after the october and
// november dst changes, so no run hour or zone moves a day count
final _nows = [DateTime(2026, 11, 5, 23, 59), DateTime(2026, 11, 6, 0, 1)];
var _now = _nows.first;

// a backup d calendar days back, at the far end of that day from now
int _daysBack(int d) {
  if (d == 0) return _now.millisecondsSinceEpoch;
  final late = _now.hour == 0;
  final at = DateTime(
    _now.year,
    _now.month,
    _now.day - d,
    late ? 23 : 0,
    late ? 59 : 1,
  );
  return at.millisecondsSinceEpoch;
}

Future<void> _world(
  WidgetTester t, {
  Map<String, Object> prefs = const {},
  HaloContainer container = HaloContainer.everyday,
  bool lockOn = false,
  Size size = const Size(1000, 4000),
}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
    ...prefs,
  });
  FlutterSecureStorage.setMockInitialValues({});
  await devWorld(container: container);
  setL10nLocale(const Locale('en'));
  lockState.openForTest(enabled: lockOn);
  lockState.inDecoy = container == HaloContainer.decoy;
  addTearDown(() {
    lockState.inDecoy = false;
    lockState.openForTest();
  });
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(
    const MethodChannel('halo/platform'),
    (_) async => null,
  );
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
  });
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

void _desk(_Lock lock) {
  onDesktop = true;
  computerLock = lock;
  addTearDown(() {
    onDesktop = false;
    computerLock = null;
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(seconds: 1));
  }
}

ProtectionLine? _line(WidgetTester t, String label) {
  final f = find.byWidgetPredicate(
    (w) => w is ProtectionLine && w.label == label,
  );
  return f.evaluate().isEmpty ? null : t.widget<ProtectionLine>(f);
}

(bool, String)? _read(WidgetTester t, String label) {
  final l = _line(t, label);
  return l == null ? null : (l.on, l.state);
}

void main() {
  setUp(() => backupNow = () => _now);
  tearDown(() => backupNow = DateTime.now);

  group('the backup line', () {
    test('a day count, a date when old, not yet when none', () {
      final now = DateTime(2026, 11, 5, 9);
      expect(backupWhen(null, now: now), l10n.settingsBackupNotYet);
      expect(
        backupWhen(DateTime(2026, 11, 5, 0, 5), now: now),
        l10n.settingsBackupToday,
      );
      expect(
        backupWhen(DateTime(2026, 11, 4, 23, 50), now: now),
        l10n.settingsBackupYesterday,
      );
      expect(
        backupWhen(DateTime(2026, 11, 3, 10), now: now),
        l10n.settingsBackupDaysAgo(2),
      );
      expect(l10n.settingsBackupDaysAgo(2), '2 days ago');
      final old = DateTime(2026, 9, 1);
      expect(backupWhen(old, now: now), dayMonthMaybeYear(old, now: now));
      expect(backupFresh(null, now: now), isFalse);
      expect(backupFresh(DateTime(2026, 10, 10), now: now), isTrue);
      expect(backupFresh(old, now: now), isFalse);
      // calendar days, not 24h blocks, and across a dst change
      final late = DateTime(2026, 11, 5, 23, 59);
      final early = DateTime(2026, 11, 6, 0, 1);
      expect(backupWhen(DateTime(2026, 11, 5, 0, 1), now: late), 'Today');
      expect(backupWhen(late, now: early), 'Yesterday');
      expect(
        backupWhen(DateTime(2026, 10, 24, 0, 1), now: late),
        '12 days ago',
      );
      expect(
        backupWhen(DateTime(2026, 10, 25, 23, 59), now: early),
        '12 days ago',
      );
      expect(
        backupWhen(DateTime(2026, 10, 31, 23, 59), now: early),
        '6 days ago',
      );
      // a clock set back reads as today, never as a negative count
      expect(
        backupWhen(DateTime(2026, 11, 7), now: now),
        l10n.settingsBackupToday,
      );
    });

    test('kept per side, and never carried in a backup file', () async {
      SharedPreferences.setMockInitialValues({});
      final at = DateTime(2026, 11, 1, 12);
      await keepLastBackup(HaloContainer.decoy, at: at);
      expect(await loadLastBackup(HaloContainer.decoy), at);
      expect(await loadLastBackup(), isNull);
      expect(containerKeys, contains(kLastBackupKey));
      expect(kRestorablePrefs, isNot(contains(kLastBackupKey)));
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys, isNot(contains(kLastBackupKey)));
    });
  });

  group('on a phone', () {
    for (final now in _nows) {
      group('at ${now.toIso8601String().substring(11, 16)}', () {
        setUp(() => _now = now);
        tearDown(() => _now = _nows.first);
        testWidgets('tor, app lock and backup: no screenshots line, never '
            'backed up says not yet', (t) async {
          await _world(t, lockOn: true);
          await t.pumpWidget(devApp(const SettingsScreen(), still: true));
          await _settle(t);
          expect(_line(t, l10n.settingsTorRouting), isNotNull);
          expect(_read(t, l10n.settingsAppLock), (true, l10n.settingsOn));
          expect(_read(t, l10n.settingsProtectBackup), (
            false,
            l10n.settingsBackupNotYet,
          ));
          expect(_line(t, 'Screenshots'), isNull);
          expect(_line(t, l10n.desktopPassRow), isNull);
          expect(find.text('Per chat'), findsNothing);
          await devClose(t);
        });

        testWidgets('a recent backup: the day count, ticked, and the row opens '
            'the backup screen', (t) async {
          await _world(t, prefs: {kLastBackupKey: _daysBack(2)});
          await t.pumpWidget(devApp(const SettingsScreen(), still: true));
          await _settle(t);
          expect(_read(t, l10n.settingsProtectBackup), (true, '2 days ago'));
          await t.tap(find.byKey(const ValueKey('backupLine')));
          await _settle(t);
          expect(find.byType(BackupScreen), findsOneWidget);
          await devClose(t);
        });

        testWidgets('a decoy reads its own time, never the real one\'s', (
          t,
        ) async {
          await _world(
            t,
            container: HaloContainer.decoy,
            prefs: {kLastBackupKey: _daysBack(0)},
          );
          await t.pumpWidget(devApp(const SettingsScreen(), still: true));
          await _settle(t);
          expect(_read(t, l10n.settingsProtectBackup), (
            false,
            l10n.settingsBackupNotYet,
          ));
          await devClose(t);
          await _world(
            t,
            container: HaloContainer.decoy,
            prefs: {
              kLastBackupKey: _daysBack(0),
              HaloContainer.decoy.key(kLastBackupKey): _daysBack(1),
            },
          );
          await t.pumpWidget(devApp(const SettingsScreen(), still: true));
          await _settle(t);
          expect(_read(t, l10n.settingsProtectBackup), (
            true,
            l10n.settingsBackupYesterday,
          ));
          await devClose(t);
        });

        testWidgets('readable at a small width with large text', (t) async {
          await _world(
            t,
            prefs: {kLastBackupKey: _daysBack(12)},
            size: const Size(640, 4000),
          );
          await t.pumpWidget(
            devApp(const SettingsScreen(), still: true, scale: 2),
          );
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(find.text('12 days ago'), findsOneWidget);
          await devClose(t);
        });
      });
    }
  });

  group('on a computer', () {
    for (final (seal, on, words) in [
      (ComputerSeal.passphrase, true, () => l10n.settingsOn),
      (ComputerSeal.windows, false, () => l10n.desktopPassWindowsAccount),
      (ComputerSeal.keyring, false, () => l10n.desktopPassKeyring),
    ]) {
      testWidgets('${seal.name}: the passphrase line in place of app lock', (
        t,
      ) async {
        await _world(t, lockOn: true, size: const Size(2560, 4000));
        _desk(_Lock(seal));
        await t.pumpWidget(devApp(const SettingsScreen(), still: true));
        await _settle(t);
        expect(_read(t, l10n.desktopPassRow), (on, words()));
        expect(_line(t, l10n.settingsAppLock), isNull);
        expect(_line(t, 'Screenshots'), isNull);
        expect(_line(t, l10n.settingsProtectBackup), isNotNull);
        await devClose(t);
      });
    }

    testWidgets('off then on follows the lock, and the line opens its page', (
      t,
    ) async {
      await _world(t, size: const Size(2560, 4000));
      final lock = _Lock(ComputerSeal.keyring);
      _desk(lock);
      await t.pumpWidget(devApp(const SettingsScreen(), still: true));
      await _settle(t);
      expect(_read(t, l10n.desktopPassRow), (false, l10n.desktopPassKeyring));
      lock.set(ComputerSeal.passphrase);
      await t.pump();
      expect(_read(t, l10n.desktopPassRow), (true, l10n.settingsOn));
      await t.tap(find.byKey(const ValueKey('computerPassLine')));
      await _settle(t);
      expect(find.text('pass page'), findsOneWidget);
      await devClose(t);
    });

    testWidgets('a decoy shows its own note, not the real passphrase', (
      t,
    ) async {
      await _world(
        t,
        container: HaloContainer.decoy,
        size: const Size(2560, 4000),
      );
      _desk(_Lock(ComputerSeal.passphrase, decoySeal: ComputerSeal.windows));
      await t.pumpWidget(devApp(const SettingsScreen(), still: true));
      await _settle(t);
      expect(_read(t, l10n.desktopPassRow), (
        false,
        l10n.desktopPassWindowsAccount,
      ));
      await t.tap(find.byKey(const ValueKey('computerPassLine')));
      await _settle(t);
      expect(find.text('decoy pass page'), findsOneWidget);
      await devClose(t);
    });
  });
}
