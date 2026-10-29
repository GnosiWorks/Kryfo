// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's first screen and the settings page when the computer can
// keep the key: the choice, the quiet open, and the passphrase made optional
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_lock_screen.dart';
import 'package:kryfo/desktop/computer_lock.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/system_seal.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:path/path.dart' as p;

import 'desktop_keys_test.dart' show FakeKeyring;
import 'desktop_start_test.dart' show ToyVaultCrypto;

const _pass = 'four random words here';

void main() {
  late Directory dir;
  late DesktopVault vault;
  late FakeKeyring ring;
  late int opened;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('lockseal');
    vault = DesktopVault(
      p.join(dir.path, 'vault.kv'),
      crypto: ToyVaultCrypto(),
    );
    ring = FakeKeyring();
    opened = 0;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> show(
    WidgetTester t, {
    SystemSeal? seal,
    bool still = false,
  }) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: DesktopLockApp(vault: vault, seal: seal, onOpen: () => opened++),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, String label) async {
    await t.tap(find.text(label));
    await t.pumpAndSettle();
  }

  group('first start', () {
    testWidgets('with a keyring: continue, or add a passphrase', (t) async {
      await show(t, seal: ring);
      expect(find.text(l10n.desktopLockAccountBody), findsOneWidget);
      expect(find.text(l10n.desktopLockAddPassphrase), findsOneWidget);
      expect(find.text(l10n.desktopLockWithoutPassphrase), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await press(t, l10n.commonContinue);
      expect(opened, 1);
      expect(vault.lockKind, VaultLockKind.system);
      expect(ring.items, hasLength(1));
    });

    testWidgets('add a passphrase, and back again', (t) async {
      await show(t, seal: ring);
      await press(t, l10n.desktopLockAddPassphrase);
      expect(find.byType(TextField), findsNWidgets(2));
      await press(t, l10n.commonBack);
      expect(find.text(l10n.desktopLockAccountBody), findsOneWidget);
      await press(t, l10n.desktopLockAddPassphrase);
      await t.enterText(find.byType(TextField).at(0), _pass);
      await t.enterText(find.byType(TextField).at(1), _pass);
      await press(t, l10n.desktopLockSet);
      expect(opened, 1);
      expect(vault.lockKind, VaultLockKind.passphrase);
      expect(ring.items, isEmpty);
    });

    testWidgets('a keyring that refuses leads to a passphrase', (t) async {
      ring.refuse = true;
      await show(t, seal: ring);
      await press(t, l10n.commonContinue);
      expect(opened, 0);
      expect(find.text(l10n.desktopLockKeyringRefused), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      // no way back to the choice that failed
      expect(find.text(l10n.commonBack), findsNothing);
    });

    testWidgets('no keyring here: the passphrase, as before', (t) async {
      ring.working = false;
      await show(t, seal: ring);
      expect(find.text(l10n.desktopLockNewBody), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('later starts', () {
    testWidgets('kept by the computer: opens with no question', (t) async {
      await vault.createSealed(ring);
      vault.close();
      await show(t, seal: ring);
      expect(opened, 1);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('missing fails closed with its line, then try again', (
      t,
    ) async {
      await vault.createSealed(ring);
      vault.close();
      final kept = Map.of(ring.items);
      ring.items.clear();
      await show(t, seal: ring, still: true);
      expect(opened, 0);
      expect(find.text(l10n.desktopKeyMissing), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      ring.items.addAll(kept);
      await press(t, l10n.commonTryAgain);
      expect(opened, 1);
    });

    testWidgets('a locked keyring says unlock it', (t) async {
      await vault.createSealed(ring);
      vault.close();
      ring.failFetch = SealFail.unreachable;
      await show(t, seal: ring);
      expect(find.text(l10n.desktopKeyUnreachable), findsOneWidget);
      expect(opened, 0);
    });

    testWidgets('windows speaks of its account and chip, not a keyring', (
      t,
    ) async {
      final win = FakeKeyring(place: SealPlace.windows);
      await vault.createSealed(win);
      vault.close();
      win.failFetch = SealFail.unreachable;
      await show(t, seal: win);
      expect(find.text(l10n.desktopKeyUnreachableWindows), findsOneWidget);
      expect(find.text(l10n.desktopKeyUnreachable), findsNothing);
      await t.pumpWidget(const SizedBox());
      File(p.join(dir.path, 'vault.kv')).deleteSync();
      final refusing = FakeKeyring(place: SealPlace.windows)..refuse = true;
      await show(t, seal: refusing);
      await press(t, l10n.commonContinue);
      expect(find.text(l10n.desktopLockAccountRefused), findsOneWidget);
      expect(find.text(l10n.desktopLockKeyringRefused), findsNothing);
    });

    testWidgets('missing names the way back', (t) async {
      await vault.createSealed(ring);
      vault.close();
      ring.items.clear();
      await show(t, seal: ring);
      expect(find.text(l10n.desktopKeyMissing), findsOneWidget);
      expect(l10n.desktopKeyMissing, contains('A Kryfo backup brings'));
      expect(l10n.desktopKeyMissing, contains('add a passphrase'));
    });

    testWidgets('a newer or cut file says so before anything is typed', (
      t,
    ) async {
      await vault.create(_pass);
      vault.close();
      final f = File(p.join(dir.path, 'vault.kv'));
      final raw = f.readAsBytesSync();
      for (final bad in [
        Uint8List.fromList(raw)..[4] = 9,
        Uint8List.fromList(raw.sublist(0, 30)),
      ]) {
        f.writeAsBytesSync(bad);
        await show(t, seal: ring);
        expect(find.text(l10n.desktopLockOtherVersion), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text(l10n.commonTryAgain), findsNothing);
        await t.pumpWidget(const SizedBox());
      }
      expect(opened, 0);
    });

    testWidgets('a passphrase vault asks for it', (t) async {
      await vault.create(_pass);
      vault.close();
      await show(t, seal: ring);
      expect(find.text(l10n.desktopLockBody), findsOneWidget);
      await t.enterText(find.byType(TextField), _pass);
      await press(t, l10n.desktopLockOpen);
      expect(opened, 1);
    });
  });

  group('settings', () {
    Future<void> page(WidgetTester t, {SystemSeal? seal}) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopComputerLock(vault, seal).page(decoy: false),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('off: add one, typed twice', (t) async {
      // made in the test's own zone: its writes chain on futures of it
      vault = DesktopVault(
        p.join(dir.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.createSealed(ring);
      await page(t, seal: ring);
      expect(find.text(l10n.desktopPassOffBody), findsOneWidget);
      expect(find.text(l10n.desktopLockWithoutPassphrase), findsOneWidget);
      await press(t, l10n.desktopLockAddPassphrase);
      await t.enterText(find.byType(TextField).at(0), _pass);
      await t.enterText(find.byType(TextField).at(1), 'something else here');
      await t.tap(find.text(l10n.desktopLockAddPassphrase));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopLockMismatch), findsOneWidget);
      await t.enterText(find.byType(TextField).at(1), _pass);
      await t.tap(find.text(l10n.desktopLockAddPassphrase));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopLockFailed), findsNothing);
      expect(find.text(l10n.desktopLockMismatch), findsNothing);
      expect(vault.hasPassphrase, isTrue);
      expect(ring.items, isEmpty);
      expect(find.text(l10n.desktopPassOnBody), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('on: removing needs the passphrase', (t) async {
      // made in the test's own zone: its writes chain on futures of it
      vault = DesktopVault(
        p.join(dir.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create(_pass);
      await page(t, seal: ring);
      expect(find.text(l10n.desktopPassOnBody), findsOneWidget);
      await press(t, l10n.desktopPassRemove);
      expect(find.text(l10n.desktopPassRemoveBody), findsOneWidget);
      await t.enterText(find.byType(TextField), 'not the right one at all');
      await t.tap(find.text(l10n.desktopPassRemove));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopLockWrong), findsOneWidget);
      expect(vault.hasPassphrase, isTrue);
      await t.enterText(find.byType(TextField), _pass);
      await t.tap(find.text(l10n.desktopPassRemove));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopLockFailed), findsNothing);
      expect(find.text(l10n.desktopLockWrong), findsNothing);
      expect(vault.hasPassphrase, isFalse);
      expect(ring.items, hasLength(1));
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('windows refusing the key keeps the passphrase, in its words', (
      t,
    ) async {
      vault = DesktopVault(
        p.join(dir.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create(_pass);
      final win = FakeKeyring(place: SealPlace.windows)..refuse = true;
      await page(t, seal: win);
      await press(t, l10n.desktopPassRemove);
      await t.enterText(find.byType(TextField), _pass);
      await t.tap(find.text(l10n.desktopPassRemove));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopPassStaysWindows), findsOneWidget);
      expect(find.text(l10n.desktopPassStays), findsNothing);
      expect(vault.hasPassphrase, isTrue);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('no keyring: the passphrase stays and says so', (t) async {
      await vault.create(_pass);
      ring.working = false;
      await page(t, seal: ring);
      expect(find.text(l10n.desktopPassRemove), findsNothing);
      expect(find.text(l10n.desktopPassStays), findsOneWidget);
    });
  });
}
