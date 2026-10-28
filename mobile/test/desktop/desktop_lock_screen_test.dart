// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's first screen: a passphrase chosen, or the one set typed
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_lock_screen.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:path/path.dart' as p;

// keys told apart, sealed as is behind a tag
class _Plain implements VaultCrypto {
  @override
  Future<String?> keyOf(String passphrase, Uint8List salt, int logN) async =>
      sha256.convert([...passphrase.codeUnits, ...salt]).toString();
  @override
  Uint8List seal(String keyHex, Uint8List plain) => Uint8List.fromList([
    ...sha256.convert(keyHex.codeUnits).bytes.take(16),
    ...plain,
  ]);
  @override
  Uint8List? open(String keyHex, Uint8List sealed) {
    final tag = sha256.convert(keyHex.codeUnits).bytes.take(16).toList();
    for (var i = 0; i < 16; i++) {
      if (sealed[i] != tag[i]) return null;
    }
    return Uint8List.fromList(sealed.sublist(16));
  }
}

const _pass = 'four random words here';

void main() {
  late Directory dir;
  late DesktopVault vault;
  late int opened;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('lock');
    vault = DesktopVault(p.join(dir.path, 'vault.kv'), crypto: _Plain());
    opened = 0;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> show(WidgetTester t, {Size size = const Size(1280, 720)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(DesktopLockApp(vault: vault, onOpen: () => opened++));
    await t.pumpAndSettle();
  }

  Future<void> type(WidgetTester t, int field, String text) async {
    await t.enterText(find.byType(TextField).at(field), text);
    await t.pump();
  }

  Future<void> press(WidgetTester t, String label) async {
    await t.tap(find.text(label));
    await t.pumpAndSettle();
  }

  testWidgets('a first start asks for a passphrase twice and says why', (
    t,
  ) async {
    await show(t);
    expect(find.text(l10n.desktopLockNewTitle), findsOneWidget);
    expect(find.text(l10n.desktopLockHonest), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await type(t, 0, 'short');
    await press(t, l10n.desktopLockSet);
    expect(find.text(l10n.desktopLockShort(kVaultMinLength)), findsOneWidget);
    expect(vault.exists, isFalse);

    await type(t, 0, _pass);
    await type(t, 1, '$_pass.');
    await press(t, l10n.desktopLockSet);
    expect(find.text(l10n.desktopLockMismatch), findsOneWidget);
    expect(vault.exists, isFalse);

    await type(t, 1, _pass);
    await press(t, l10n.desktopLockSet);
    expect(vault.exists, isTrue);
    expect(opened, 1);
  });

  testWidgets('a set passphrase opens; a wrong one says so and clears', (
    t,
  ) async {
    await vault.create(_pass);
    vault.close();
    await show(t);
    expect(find.text(l10n.desktopLockTitle), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await type(t, 0, 'not the right one');
    await press(t, l10n.desktopLockOpen);
    expect(find.text(l10n.desktopLockWrong), findsOneWidget);
    expect(opened, 0);
    expect(find.text('not the right one'), findsNothing);

    await type(t, 0, _pass);
    await press(t, l10n.desktopLockOpen);
    expect(opened, 1);
    expect(vault.isOpen, isTrue);
  });

  testWidgets('enter in the field opens too', (t) async {
    await vault.create(_pass);
    vault.close();
    await show(t);
    await type(t, 0, _pass);
    await t.testTextInput.receiveAction(TextInputAction.go);
    await t.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('small window, large text, reduced motion: nothing clips', (
    t,
  ) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearAllTestValues);
    await show(t, size: const Size(360, 600));
    expect(t.takeException(), isNull);
    await type(t, 0, 'short');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await t.pumpAndSettle();
    await press(t, l10n.desktopLockSet);
    expect(t.takeException(), isNull);
  });

  testWidgets('the error is read out as it appears', (t) async {
    final h = t.ensureSemantics();
    await vault.create(_pass);
    vault.close();
    await show(t);
    await type(t, 0, 'nope nope nope');
    await press(t, l10n.desktopLockOpen);
    expect(
      t.getSemantics(find.text(l10n.desktopLockWrong)),
      matchesSemantics(label: l10n.desktopLockWrong, isLiveRegion: true),
    );
    expect(
      t.getSemantics(find.text(l10n.desktopLockTitle)),
      matchesSemantics(label: l10n.desktopLockTitle, isHeader: true),
    );
    h.dispose();
  });

  testWidgets('right to left lays out', (t) async {
    await vault.create(_pass);
    vault.close();
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DesktopLockScreen(vault: vault, onOpen: () => opened++),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      Directionality.of(t.element(find.byType(TextField))),
      TextDirection.rtl,
    );
  });
}
