// SPDX-License-Identifier: GPL-3.0-or-later
// the pin key on screen: the "abc" key on every pad that may take a hidden
// chats passphrase, the pad opening on digits every time, a field that
// learns nothing and is never offered to autofill, the lines a pin key
// that fails or is gone shows, the security line and the update card the
// same in a decoy session, and the card answering every pin alike
import 'dart:convert';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/pin_key.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/screens/update_pins_screen.dart';
import 'package:kryfo/widgets/pass_pad.dart';
import 'package:kryfo/widgets/pin_pad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart';
import 'pin_key_fakes.dart';

// a lock from before the update, or set up since, on the v3 stand-ins
Future<(LockState, MemStore, FakeKeys)> keyLock({
  bool before = true,
  bool keyThere = true,
  bool screenLock = true,
  bool vault = false,
  Duration cardPad = Duration.zero,
}) async {
  final store = MemStore();
  final keys = FakeKeys(exists: false, screenLock: screenLock);
  store.m['halo.lock.enabled'] = 'true';
  store.m['halo.lock.table'] = jsonEncode({
    'v': 2,
    'n': 15,
    'e': {
      '${PinSlot.app}': {
        'p': appPin,
        'k': PinKind.everyday,
        'c': HaloContainer.everyday.id,
        'w': '',
      },
      if (vault)
        '${PinSlot.vault}': {
          'p': 'correct horse battery',
          'k': PinKind.vault,
          'c': HaloContainer.vault.id,
          'w': vaultKey,
        },
    },
  });
  if (!before) store.m['halo.lock.card'] = '0';
  final s = LockState(
    store: store,
    engine: KeyEngine(),
    clock: StillClock(),
    bio: NoBio(),
    keys: keys,
    revealAfter: Duration.zero,
    cardPad: cardPad,
  );
  await s.load();
  if (keyThere) await s.verifyPin(appPin);
  return (s, store, keys);
}

TextField field(WidgetTester t) => t.widget<TextField>(find.byType(TextField));

void main() {
  setUp(() {
    decoyReady = true;
    SharedPreferences.setMockInitialValues({});
  });

  group('the abc key', () {
    testWidgets('on the lock screen, opening on digits every time', (t) async {
      phone(t);
      final (lock, _, _) = await keyLock();
      lock.lock();
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await t.pump();
      expect(find.byType(PinPad), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.bySemanticsLabel(l10n.padUseLetters), findsOneWidget);
      await t.tap(find.text('abc'));
      await t.pump();
      expect(find.byType(PinPad), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.padUseDigits), findsOneWidget);
      // a lock screen up again starts on digits: letters are never kept
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await t.pump();
      expect(find.byType(PinPad), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the field learns nothing and offers nothing', (t) async {
      phone(t);
      final (lock, _, _) = await keyLock();
      lock.lock();
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await t.tap(find.text('abc'));
      await t.pump();
      final f = field(t);
      expect(f.obscureText, isTrue);
      expect(f.autocorrect, isFalse);
      expect(f.enableSuggestions, isFalse);
      expect(f.enableIMEPersonalizedLearning, isFalse);
      expect(f.autofillHints, isNull);
      expect(f.keyboardType, TextInputType.visiblePassword);
      expect(f.textCapitalization, TextCapitalization.none);
      expect(f.enableInteractiveSelection, isFalse);
      // control characters never get in
      await t.enterText(find.byType(TextField), 'ab\ncd');
      expect(field(t).controller!.text, 'abcd');
    });

    testWidgets('a passphrase typed on the lock screen opens the vault', (
      t,
    ) async {
      phone(t);
      final (lock, _, _) = await keyLock(vault: true);
      String? opened;
      lock.onOutcome = (r, {vaultKey}) async => opened = vaultKey;
      lock.lock();
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await t.tap(find.text('abc'));
      await t.pump();
      await t.enterText(find.byType(TextField), 'correct horse battery');
      await t.pump();
      await t.tap(find.bySemanticsLabel(l10n.commonDone));
      await t.pumpAndSettle();
      expect(opened, vaultKey);
      expect(lock.locked, isFalse);
    });

    testWidgets('the same in every language direction, large text', (t) async {
      phone(t);
      final (lock, _, _) = await keyLock();
      lock.lock();
      for (final l in const [Locale('ar'), Locale('fa'), Locale('de')]) {
        await t.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: app(LockScreen(lock: lock), still: true, locale: l),
          ),
        );
        await t.pump();
        await t.tap(find.text('abc'));
        await t.pump();
        expect(t.takeException(), isNull, reason: l.languageCode);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('the lock screen says why a pin cannot be checked', () {
    testWidgets('busy, then fine again', (t) async {
      phone(t);
      final (lock, _, keys) = await keyLock();
      lock.lock();
      keys.fail = KeyFail.busy;
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await typePin(t, appPin);
      await enter(t);
      await t.pumpAndSettle();
      expect(find.text(l10n.lockKeyBusy), findsOneWidget);
      expect(find.text(l10n.lockNotIt), findsNothing);
      expect(lock.locked, isTrue);
      keys.fail = null;
      await typePin(t, appPin);
      await enter(t);
      await t.pumpAndSettle();
      expect(lock.locked, isFalse);
    });

    testWidgets('gone: shown before any pin, with a reset asked twice', (
      t,
    ) async {
      phone(t);
      final (first, store, keys) = await keyLock();
      expect(first.keyNote, isNull);
      keys.exists = false;
      final lock = LockState(
        store: store,
        engine: KeyEngine(),
        clock: StillClock(),
        bio: NoBio(),
        keys: keys,
        revealAfter: Duration.zero,
        lostGap: Duration.zero,
      );
      await lock.load();
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await t.pump();
      expect(find.text(l10n.lockKeyLost), findsOneWidget);
      // the screen reads again as it comes up and a beat later: still no key
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(find.text(l10n.lockKeyReset), findsOneWidget);
      await t.tap(find.text(l10n.lockKeyReset));
      await t.pumpAndSettle();
      expect(find.text(l10n.lockKeyResetTitle), findsOneWidget);
      expect(find.text(l10n.lockKeyResetLine), findsOneWidget);
    });

    testWidgets('one false "no key" read goes away and offers no reset', (
      t,
    ) async {
      phone(t);
      final (first, store, keys) = await keyLock();
      expect(first.keyNote, isNull);
      keys.infoFalseOnce = true;
      final lock = LockState(
        store: store,
        engine: KeyEngine(),
        clock: StillClock(),
        bio: NoBio(),
        keys: keys,
        revealAfter: Duration.zero,
        lostGap: Duration.zero,
      );
      await lock.load();
      expect(lock.keyNote, KeyNote.lost);
      await t.pumpWidget(app(LockScreen(lock: lock), still: true));
      await t.pump();
      expect(find.text(l10n.lockKeyReset), findsNothing);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(find.text(l10n.lockKeyLost), findsNothing);
      expect(find.text(l10n.lockKeyReset), findsNothing);
      expect(lock.keyNote, isNull);
    });
  });

  group('App lock', () {
    Future<Set<String>> words(WidgetTester t, LockState lock) async {
      await t.pumpWidget(
        app(
          PinsScreen(
            lock: lock,
            host: FakeHost(lock: lock),
          ),
        ),
      );
      await t.pumpAndSettle();
      return {
        for (final w in t.widgetList<Text>(find.byType(Text)))
          if (w.data != null) w.data!,
      };
    }

    testWidgets('the card and the line read the same in a decoy session', (
      t,
    ) async {
      phone(t);
      final (lock, _, _) = await keyLock();
      final real = await words(t, lock);
      expect(real, contains(l10n.cardTitle));
      expect(real, contains(l10n.keyLineUnlocked));
      lock.inDecoy = true;
      final decoy = await words(t, lock);
      expect(decoy, real);
    });

    testWidgets('no card on a lock set up since the update', (t) async {
      phone(t);
      final (lock, _, _) = await keyLock(before: false);
      final w = await words(t, lock);
      expect(w, isNot(contains(l10n.cardTitle)));
      expect(w, contains(l10n.keyLineUnlocked));
    });

    testWidgets('no line or card before the key, a screen lock asked for', (
      t,
    ) async {
      phone(t);
      final (lock, _, _) = await keyLock(keyThere: false);
      final w = await words(t, lock);
      expect(w, isNot(contains(l10n.cardTitle)));
      expect(w.any((s) => s.startsWith(l10n.keyLine)), isFalse);
      final (bare, _, _) = await keyLock(screenLock: false);
      final b = await words(t, bare);
      expect(b, contains('${l10n.keyLineUnlocked} ${l10n.keyLineScreenLock}'));
    });

    testWidgets('Done on the card ends it', (t) async {
      phone(t);
      final (lock, store, _) = await keyLock();
      await words(t, lock);
      await t.tap(find.text(l10n.commonDone).first);
      await t.pumpAndSettle();
      expect(find.text(l10n.cardTitle), findsNothing);
      expect(store.m['halo.lock.card.done'], 'true');
    });
  });

  group('the update pad', () {
    testWidgets('every pin gets the same line and the same feel', (t) async {
      phone(t);
      final haptics = hearHaptics(t);
      final (lock, _, _) = await keyLock(vault: true);
      var outcomes = 0;
      lock.onOutcome = (r, {vaultKey}) async => outcomes++;
      await t.pumpWidget(app(UpdatePinsScreen(lock: lock), still: true));
      await t.pump();
      expect(find.text(l10n.cardLine), findsOneWidget);
      final seen = <String>[];
      for (final pin in [appPin, '0000', '9999', '5555']) {
        haptics.clear();
        await typePin(t, pin);
        await enter(t);
        await t.pumpAndSettle();
        expect(find.text(l10n.cardAnswer), findsOneWidget, reason: pin);
        seen.add(haptics.where((h) => h != 'selectionClick').join(','));
      }
      expect(seen.toSet(), hasLength(1));
      expect(outcomes, 0);
      expect(lock.locked, isFalse);
      expect(lock.inDecoy, isFalse);
    });

    testWidgets('Done ends the card for good', (t) async {
      phone(t);
      final (lock, store, _) = await keyLock();
      await t.pumpWidget(app(UpdatePinsScreen(lock: lock), still: true));
      await t.tap(find.text(l10n.commonDone));
      await t.pumpAndSettle();
      expect(store.m['halo.lock.card.done'], 'true');
      expect(lock.updateCard, isFalse);
    });
  });

  group('a hidden chats passphrase', () {
    testWidgets(
      'chosen in letters: twelve characters, a meter, the same twice',
      (t) async {
        phone(t);
        final (lock, _, _) = await keyLock();
        final host = FakeHost(lock: lock);
        await t.pumpWidget(
          app(
            PinFlowScreen(flow: PinFlow.vault, lock: lock, host: host),
            still: true,
          ),
        );
        await press(t, find.text(l10n.commonContinue));
        await t.pumpAndSettle();
        await typePin(t, appPin);
        await enter(t);
        await t.pumpAndSettle();
        // the choose page opens on digits too
        expect(find.byType(PinPad), findsOneWidget);
        await t.tap(find.text('abc'));
        await t.pump();
        expect(find.text(l10n.flowVaultPassLine), findsOneWidget);
        await t.enterText(find.byType(TextField), 'too short');
        await t.pump();
        expect(find.byType(PassStrength), findsOneWidget);
        // under twelve the enter key does nothing
        await t.tap(find.bySemanticsLabel(l10n.commonDone));
        await t.pump();
        expect(find.text(l10n.flowVaultPassLine), findsOneWidget);
        await t.enterText(find.byType(TextField), 'correct horse battery');
        await t.pump();
        await t.tap(find.bySemanticsLabel(l10n.commonDone));
        await t.pumpAndSettle();
        // confirm keeps letters
        expect(find.text(l10n.flowVaultPassAgain), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await t.enterText(find.byType(TextField), 'correct horse battery');
        await t.pump();
        await t.tap(find.bySemanticsLabel(l10n.commonDone));
        await t.pumpAndSettle();
        await press(t, find.text(l10n.flowVaultForgetOk));
        await t.pumpAndSettle();
        expect(host.calls, contains('createVault'));
        final r = await lock.verifyPin('correct horse battery');
        expect(r, PinResult.vault);
      },
    );
  });

  test(
    'the platform pin key off android: none there, and asks nothing',
    () async {
      const k = PlatformPinKeystore();
      final i = await k.info();
      expect(i!.supported, isFalse);
      expect((await k.mac('ab' * 32)).fail, KeyFail.gone);
      await k.drop();
    },
  );
}
