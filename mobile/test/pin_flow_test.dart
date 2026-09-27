// SPDX-License-Identifier: GPL-3.0-or-later
// hidden chats in App lock: the row and the lock screen give nothing away,
// the setup flow takes a six digit pin, says only "Pick a different PIN" on
// a clash, and a change from inside moves no chat. reduced motion stops
// every movement and right to left mirrors the pages.
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/hide_picker.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/widgets/pin_pad.dart';

import 'pin_flow_fakes.dart';

// App lock with Advanced protection open
Future<void> _pins(
  WidgetTester t,
  Lock lock,
  FakeHost host, {
  GlobalKey? shot,
}) async {
  await t.pumpWidget(
    app(
      PinsScreen(lock: lock.state, host: host),
      shot: shot,
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text(l10n.pinsAdvanced));
  await t.pumpAndSettle();
}

Future<void> _flow(
  WidgetTester t,
  Lock lock,
  FakeHost host, {
  bool change = false,
  bool still = false,
  Locale locale = const Locale('en'),
}) async {
  await t.pumpWidget(
    app(
      PinFlowScreen(
        flow: PinFlow.vault,
        skipIntro: change,
        lock: lock.state,
        host: host,
      ),
      still: still,
      locale: locale,
    ),
  );
  await t.pumpAndSettle();
}

// the words on screen, the pad's digits left out
Set<String> _words(WidgetTester t) => {
  for (final w in t.widgetList<Text>(find.byType(Text)))
    if (w.data != null && !RegExp(r'^\d$').hasMatch(w.data!)) w.data!,
};

// intro, the app pin, a hidden chats pin twice
Future<void> _toForget(WidgetTester t, String pin) async {
  await press(t, find.text(l10n.commonContinue));
  await t.pumpAndSettle();
  await typePin(t, appPin);
  await enter(t);
  await t.pumpAndSettle();
  await typePin(t, pin);
  await enter(t);
  await t.pumpAndSettle();
  await typePin(t, pin);
  await enter(t);
  await t.pumpAndSettle();
}

void main() {
  group('the row', () {
    testWidgets('reads Set up in an everyday session, vault or not, with '
        'the same tree and pixels', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      final seen = <(String, List<int>)>[];
      for (final pins in [appOnly, withVault]) {
        final lock = await makeLock(pins);
        final host = FakeHost(
          lock: lock.state,
          everyday: someChats(),
          hidden: pins == withVault
              ? [const HideChoice(id: 'h', name: 'H')]
              : null,
        );
        final shot = GlobalKey();
        await _pins(t, lock, host, shot: shot);
        expect(find.text(l10n.pinsHiddenChats), findsOneWidget);
        expect(find.text(l10n.pinsSetUp), findsOneWidget);
        expect(find.text(l10n.pinsSet), findsNothing);
        seen.add((semanticsTree(t), await pixels(t, shot)));
        await t.pumpWidget(const SizedBox());
      }
      expect(seen[1].$1, seen[0].$1);
      expect(seen[1].$2, seen[0].$2);
      h.dispose();
    });

    testWidgets('decoy settings show a fresh install, Hidden chats Set up '
        'there too', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      final seen = <(String, List<int>)>[];
      // a fresh install with a pin, and the decoy of a phone holding every
      // pin there is
      final fresh = await makeLock(appOnly);
      final decoy = await makeLock(
        {
          PinSlot.app: (appPin, PinKind.everyday),
          PinSlot.wipe: (wipePin, PinKind.wipe),
          PinSlot.decoy: (decoyPin, PinKind.decoy),
          PinSlot.vault: (vaultPin, PinKind.vault),
        },
        inDecoy: true,
        wipeOn: true,
      );
      for (final lock in [fresh, decoy]) {
        final shot = GlobalKey();
        await _pins(t, lock, FakeHost(lock: lock.state), shot: shot);
        expect(find.text(l10n.pinsSetUp), findsOneWidget);
        expect(find.text(l10n.commonOff), findsNWidgets(2));
        seen.add((semanticsTree(t), await pixels(t, shot)));
        await t.pumpWidget(const SizedBox());
      }
      expect(seen[1].$1, seen[0].$1);
      expect(seen[1].$2, seen[0].$2);
      h.dispose();
    });

    testWidgets('a decoy reads the same with or without hidden chats of its '
        'own', (t) async {
      phone(t);
      final h = t.ensureSemantics();
      final seen = <(String, List<int>)>[];
      for (final own in [false, true]) {
        final lock = await makeLock({
          ...withVault,
          PinSlot.decoy: (decoyPin, PinKind.decoy),
          if (own) PinSlot.decoyVault: (decoyVaultPin, PinKind.vault),
        }, inDecoy: true);
        final shot = GlobalKey();
        await _pins(
          t,
          lock,
          FakeHost(lock: lock.state, everyday: someChats()),
          shot: shot,
        );
        expect(find.text(l10n.pinsSetUp), findsOneWidget);
        expect(find.text(l10n.pinsSet), findsNothing);
        seen.add((semanticsTree(t), await pixels(t, shot)));
        await t.pumpWidget(const SizedBox());
      }
      expect(seen[1].$1, seen[0].$1);
      expect(seen[1].$2, seen[0].$2);
      h.dispose();
    });

    testWidgets('inside the decoy\'s own it reads Set, and a change takes '
        'only its PIN', (t) async {
      phone(t);
      final lock = await makeLock(
        {
          ...withVault,
          PinSlot.decoy: (decoyPin, PinKind.decoy),
          PinSlot.decoyVault: (decoyVaultPin, PinKind.vault),
        },
        inDecoy: true,
        inVault: true,
      );
      final host = FakeHost(
        lock: lock.state,
        everyday: someChats(),
        hidden: [const HideChoice(id: 'h', name: 'Hana')],
      );
      await _pins(t, lock, host);
      expect(find.text(l10n.pinsSet), findsOneWidget);
      await t.tap(find.text(l10n.pinsHiddenChats));
      await t.pumpAndSettle();
      expect(find.text(l10n.pinsHideMoreChats), findsOneWidget);
      expect(find.text(l10n.pinsRemoveHiddenChats), findsOneWidget);
      await t.tap(find.text(l10n.pinsChangeHiddenPin));
      await t.pumpAndSettle();
      // the everyday vault's pin and the decoy's own do not change it
      for (final other in [vaultPin, decoyPin]) {
        await typePin(t, other);
        await enter(t);
        await t.pumpAndSettle();
        expect(find.text(l10n.lockNotIt), findsOneWidget);
      }
      await typePin(t, decoyVaultPin);
      await enter(t);
      await t.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await typePin(t, '864200');
        await enter(t);
        await t.pumpAndSettle();
      }
      expect(find.text(l10n.flowVaultChanged), findsOneWidget);
      expect(host.moves, isEmpty);
      expect(lock.entries['${PinSlot.decoyVault}']['p'], '864200');
      expect(lock.entries['${PinSlot.vault}']['p'], vaultPin);
    });

    testWidgets('with the lock off it needs a PIN first and leads nowhere', (
      t,
    ) async {
      phone(t);
      final lock = await makeLock(null);
      await _pins(t, lock, FakeHost(lock: lock.state));
      expect(find.text(l10n.pinsNeedsAPinFirst), findsNWidgets(3));
      await t.tap(find.text(l10n.pinsHiddenChats));
      await t.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsNothing);
    });

    testWidgets('outside the vault it leads to setup', (t) async {
      phone(t);
      final lock = await makeLock(withVault);
      await _pins(t, lock, FakeHost(lock: lock.state));
      await t.tap(find.text(l10n.pinsHiddenChats));
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultTitle), findsOneWidget);
      expect(find.text(l10n.flowVaultReplace), findsOneWidget);
    });

    testWidgets('inside the vault it reads Set and offers change, more and '
        'remove', (t) async {
      phone(t);
      final lock = await makeLock(withVault, inVault: true);
      final host = FakeHost(
        lock: lock.state,
        everyday: someChats(),
        hidden: [const HideChoice(id: 'h', name: 'Hana')],
      );
      await _pins(t, lock, host);
      expect(find.text(l10n.pinsSet), findsOneWidget);
      expect(find.text(l10n.pinsSetUp), findsNothing);
      await t.tap(find.text(l10n.pinsHiddenChats));
      await t.pumpAndSettle();
      expect(find.text(l10n.pinsChangeHiddenPin), findsOneWidget);
      expect(find.text(l10n.pinsHideMoreChats), findsOneWidget);
      await t.tap(find.text(l10n.pinsRemoveHiddenChats));
      await t.pumpAndSettle();
      expect(find.text(l10n.pinsRemoveHiddenLine), findsOneWidget);
      await t.tap(find.text(l10n.pinsRemoveHiddenChats));
      await t.pumpAndSettle();
      expect(host.calls, ['removeVault']);
      expect(host.everyday.map((c) => c.id), contains('h'));
      expect(lock.state.inVault, isFalse);
      expect(find.text(l10n.pinsSetUp), findsOneWidget);
    });

    testWidgets('hide more chats, from inside', (t) async {
      phone(t);
      final lock = await makeLock(withVault, inVault: true);
      final host = FakeHost(lock: lock.state, everyday: someChats());
      await _pins(t, lock, host);
      await t.tap(find.text(l10n.pinsHiddenChats));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.pinsHideMoreChats));
      await t.pumpAndSettle();
      expect(find.byType(HidePickerScreen), findsOneWidget);
      await t.tap(find.text('Vic'));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.flowVaultPickButton(1)));
      await t.pumpAndSettle();
      expect(find.byType(HidePickerScreen), findsNothing);
      expect(host.hidden.map((c) => c.id), ['visible-plain-row']);
    });
  });

  group('turning the lock off', () {
    testWidgets('reads the same with or without a vault, and any goes', (
      t,
    ) async {
      phone(t);
      final lines = <Set<String>>[];
      for (final pins in [appOnly, withVault]) {
        final lock = await makeLock(pins);
        final host = FakeHost(lock: lock.state);
        await _pins(t, lock, host);
        await t.tap(find.text(l10n.pinsTurnOff));
        await t.pumpAndSettle();
        lines.add(_words(t));
        expect(find.text(l10n.pinsThePinGoesAnd), findsOneWidget);
        await t.tap(find.text(l10n.pinsTurnOff).last);
        await t.pumpAndSettle();
        expect(host.calls, ['destroyVault']);
        expect(lock.state.enabled, isFalse);
        expect(lock.store.m['halo.lock.table'], isNull);
        await t.pumpWidget(const SizedBox());
      }
      expect(lines[1], lines[0]);
    });

    testWidgets('inside the vault it waits for the hidden chats to go', (
      t,
    ) async {
      phone(t);
      final lock = await makeLock(withVault, inVault: true);
      final host = FakeHost(lock: lock.state);
      await _pins(t, lock, host);
      await t.tap(find.text(l10n.pinsTurnOff));
      await t.pumpAndSettle();
      expect(find.text(l10n.pinsTurnOffHiddenFirst), findsOneWidget);
      await t.tap(find.text(l10n.confirmSheetKeep));
      await t.pumpAndSettle();
      expect(host.calls, isEmpty);
      expect(lock.state.enabled, isTrue);
    });

    testWidgets('in the decoy it takes nothing of the vault', (t) async {
      phone(t);
      final lock = await makeLock(withVault, inDecoy: true);
      final host = FakeHost(lock: lock.state);
      await _pins(t, lock, host);
      await t.tap(find.text(l10n.pinsTurnOff));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.pinsTurnOff).last);
      await t.pumpAndSettle();
      expect(host.calls, isEmpty);
      expect(lock.entries.containsKey('${PinSlot.vault}'), isTrue);
    });

    testWidgets('in the decoy a pause keeps its own hidden chats', (t) async {
      phone(t);
      final lock = await makeLock({
        ...withVault,
        PinSlot.decoy: (decoyPin, PinKind.decoy),
        PinSlot.decoyVault: (decoyVaultPin, PinKind.vault),
      }, inDecoy: true);
      final host = FakeHost(lock: lock.state);
      await _pins(t, lock, host);
      await t.tap(find.text(l10n.pinsTurnOff));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.pinsTurnOff).last);
      await t.pumpAndSettle();
      expect(host.calls, isEmpty);
      expect(lock.state.lockOn, isFalse);
      expect(lock.entries['${PinSlot.decoyVault}']['p'], decoyVaultPin);
      expect(lock.entries['${PinSlot.vault}']['p'], vaultPin);
    });

    testWidgets('inside the decoy\'s own it waits for its chats to go', (
      t,
    ) async {
      phone(t);
      final lock = await makeLock(
        {
          ...withVault,
          PinSlot.decoy: (decoyPin, PinKind.decoy),
          PinSlot.decoyVault: (decoyVaultPin, PinKind.vault),
        },
        inDecoy: true,
        inVault: true,
      );
      final host = FakeHost(
        lock: lock.state,
        hidden: [const HideChoice(id: 'h', name: 'Hana')],
      );
      await _pins(t, lock, host);
      await t.tap(find.text(l10n.pinsTurnOff));
      await t.pumpAndSettle();
      expect(find.text(l10n.pinsTurnOffHiddenFirst), findsOneWidget);
      await t.tap(find.text(l10n.pinsRemoveHiddenChats));
      await t.pumpAndSettle();
      expect(host.calls, ['removeVault']);
      expect(host.everyday.map((c) => c.id), ['h']);
      expect(lock.state.lockOn, isTrue);
      expect(lock.entries.containsKey('${PinSlot.decoyVault}'), isFalse);
      expect(lock.entries['${PinSlot.vault}']['p'], vaultPin);
      expect(find.text(l10n.pinsSetUp), findsOneWidget);
    });
  });

  testWidgets('the lock screen is the same for every set of pins', (t) async {
    phone(t);
    final h = t.ensureSemantics();
    final seen = <(String, List<int>)>[];
    for (final pins in <Map<int, (String, int)>>[
      appOnly,
      {...appOnly, PinSlot.wipe: (wipePin, PinKind.wipe)},
      {...appOnly, PinSlot.decoy: (decoyPin, PinKind.decoy)},
      withVault,
      {
        ...withVault,
        PinSlot.wipe: (wipePin, PinKind.wipe),
        PinSlot.decoy: (decoyPin, PinKind.decoy),
      },
      {
        ...withVault,
        PinSlot.decoy: (decoyPin, PinKind.decoy),
        PinSlot.decoyVault: (decoyVaultPin, PinKind.vault),
      },
    ]) {
      final lock = await makeLock(pins);
      final shot = GlobalKey();
      await t.pumpWidget(
        app(LockScreen(lock: lock.state), still: true, shot: shot),
      );
      await t.pumpAndSettle();
      seen.add((semanticsTree(t), await pixels(t, shot)));
      await t.pumpWidget(const SizedBox());
    }
    for (final s in seen.skip(1)) {
      expect(s.$1, seen.first.$1);
      expect(s.$2, seen.first.$2);
    }
    h.dispose();
  });

  group('setup', () {
    testWidgets('the replace, fingerprint and law lines show, vault or not', (
      t,
    ) async {
      phone(t);
      final words = <Set<String>>[];
      for (final pins in [appOnly, withVault]) {
        final lock = await makeLock(pins);
        await _flow(t, lock, FakeHost(lock: lock.state));
        for (final line in [
          l10n.flowVault1,
          l10n.flowVault2,
          l10n.flowVaultFinger,
          l10n.flowVaultDigits,
          l10n.flowVaultReplace,
          l10n.flowLaw,
        ]) {
          expect(find.text(line), findsOneWidget);
        }
        words.add(_words(t));
        await t.pumpWidget(const SizedBox());
      }
      expect(words[1], words[0]);
    });

    testWidgets('the pad refuses five digits here, and shows six places', (
      t,
    ) async {
      phone(t);
      final lock = await makeLock(appOnly);
      await _flow(t, lock, FakeHost(lock: lock.state));
      await press(t, find.text(l10n.commonContinue));
      await t.pumpAndSettle();
      // the app pin is four digits, and goes in
      expect(t.widget<PinDots>(find.byType(PinDots)).min, kPinMin);
      await typePin(t, appPin);
      await enter(t);
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      Row dots() => t.widget<Row>(
        find.descendant(of: find.byType(PinDots), matching: find.byType(Row)),
      );
      expect(dots().children.length, 6);
      await typePin(t, '24681');
      expect(dots().children.length, 6);
      expect(t.widget<PinPad>(find.byType(PinPad)).canEnter, isFalse);
      await enter(t);
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultChoose), findsOneWidget);
      expect(find.text(l10n.panicSetupOnceMore), findsNothing);
      await typePin(t, '0');
      expect(t.widget<PinPad>(find.byType(PinPad)).canEnter, isTrue);
      await enter(t);
      await t.pumpAndSettle();
      expect(find.text(l10n.panicSetupOnceMore), findsOneWidget);
      expect(dots().children.length, 6);
    });

    testWidgets('a clash shows only Pick a different PIN, then a new one '
        'is made', (t) async {
      phone(t);
      for (final (slot, taken) in [
        (PinSlot.app, '123456'),
        (PinSlot.wipe, '999999'),
        (PinSlot.decoy, '555555'),
      ]) {
        final lock = await makeLock({
          PinSlot.app: (slot == PinSlot.app ? taken : appPin, PinKind.everyday),
          if (slot == PinSlot.wipe) PinSlot.wipe: (taken, PinKind.wipe),
          if (slot == PinSlot.decoy) PinSlot.decoy: (taken, PinKind.decoy),
        });
        final host = FakeHost(lock: lock.state, everyday: someChats());
        final own = slot == PinSlot.app ? taken : appPin;
        await _flow(t, lock, host);
        await press(t, find.text(l10n.commonContinue));
        await t.pumpAndSettle();
        await typePin(t, own);
        await enter(t);
        await t.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          await typePin(t, taken);
          await enter(t);
          await t.pumpAndSettle();
        }
        await press(t, find.text(l10n.flowVaultForgetOk));
        await t.pumpAndSettle();
        expect(_words(t), {l10n.flowVaultChoose, l10n.pinPickDifferent});
        expect(host.calls, ['createVault']);
        // a new pin goes straight to making it: the forget page was read
        for (var i = 0; i < 2; i++) {
          await typePin(t, vaultPin);
          await enter(t);
          await t.pumpAndSettle();
        }
        expect(find.text(l10n.flowVaultForget), findsNothing);
        expect(find.text(l10n.flowVaultPickTitle), findsOneWidget);
        expect(host.calls, ['createVault', 'createVault']);
        expect(lock.entries['${PinSlot.vault}']['p'], vaultPin);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('in the decoy a PIN in use goes the same way as any other', (
      t,
    ) async {
      phone(t);
      final pages = <List<Set<String>>>[];
      final tables = <Map<String, dynamic>>[];
      for (final pin in ['135790', vaultPin]) {
        final lock = await makeLock({
          ...withVault,
          PinSlot.decoy: (decoyPin, PinKind.decoy),
        }, inDecoy: true);
        final host = FakeHost(lock: lock.state, everyday: someChats());
        await _flow(t, lock, host);
        final seen = [_words(t)];
        Future<void> next() async {
          await t.pumpAndSettle();
          seen.add(_words(t));
        }

        await press(t, find.text(l10n.commonContinue));
        await next();
        // the decoy's own pin lets them in there
        await typePin(t, decoyPin);
        await enter(t);
        await next();
        for (var i = 0; i < 2; i++) {
          await typePin(t, pin);
          await enter(t);
          await next();
        }
        await press(t, find.text(l10n.flowVaultForgetOk));
        await next();
        await t.tap(find.text('Hana'));
        await t.pumpAndSettle();
        await t.tap(find.text(l10n.flowVaultPickButton(1)));
        await next();
        await press(t, find.text(l10n.flowVaultNotNow));
        await next();
        expect(find.text(l10n.flowVaultDone), findsOneWidget);
        expect(host.calls, ['createVault', 'hideChats', 'vaultSetupDone']);
        expect(host.hidden.map((c) => c.id), ['hidden-wreck-tone']);
        pages.add(seen);
        tables.add(lock.entries);
        await t.pumpWidget(const SizedBox());
      }
      expect(pages[1], pages[0]);
      // a free pin is the decoy's own now; one in use is kept nowhere
      expect(tables[0]['${PinSlot.decoyVault}']['p'], '135790');
      expect(tables[1].containsKey('${PinSlot.decoyVault}'), isFalse);
      expect(tables[1]['${PinSlot.vault}']['p'], vaultPin);
    });

    testWidgets('the whole way: forget page, picked chats, backup, done', (
      t,
    ) async {
      phone(t);
      final haptics = hearHaptics(t);
      final lock = await makeLock(appOnly);
      final host = FakeHost(lock: lock.state, everyday: someChats());
      await _flow(t, lock, host);
      await _toForget(t, vaultPin);
      expect(find.text(l10n.flowVaultForgetTitle), findsOneWidget);
      expect(find.text(l10n.flowVaultForget), findsOneWidget);
      expect(haptics.last, 'mediumImpact');
      await press(t, find.text(l10n.flowVaultForgetOk));
      await t.pump();
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultPickTitle), findsOneWidget);
      expect(find.text(l10n.flowVaultPickButton(0)), findsOneWidget);
      await t.tap(find.text('Saturday hike'));
      await t.tap(find.text('Hana'));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.flowVaultPickButton(2)));
      await t.pumpAndSettle();
      expect(host.hidden.map((c) => c.id).toSet(), {
        'g2hidden0001',
        'hidden-wreck-tone',
      });
      expect(find.text(l10n.flowVaultBackupTitle), findsOneWidget);
      await press(t, find.text(l10n.flowVaultBackupNow));
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultDone), findsOneWidget);
      expect(host.calls, [
        'createVault',
        'hideChats',
        'backup',
        'vaultSetupDone',
      ]);
      expect(lock.entries['${PinSlot.vault}']['w'], vaultKey);
    });

    testWidgets('hiding nothing yet skips the backup', (t) async {
      phone(t);
      final lock = await makeLock(appOnly);
      final host = FakeHost(lock: lock.state, everyday: someChats());
      await _flow(t, lock, host);
      await _toForget(t, vaultPin);
      await press(t, find.text(l10n.flowVaultForgetOk));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.flowVaultPickButton(0)));
      await t.pumpAndSettle();
      expect(find.text(l10n.flowVaultDone), findsOneWidget);
      expect(host.calls, ['createVault', 'vaultSetupDone']);
    });

    testWidgets('leaving part way drops the new vault\'s key', (t) async {
      phone(t);
      final lock = await makeLock(appOnly);
      final host = FakeHost(lock: lock.state, everyday: someChats());
      await _flow(t, lock, host);
      await _toForget(t, vaultPin);
      await press(t, find.text(l10n.flowVaultForgetOk));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      expect(host.calls, ['createVault', 'vaultSetupDone']);
    });
  });

  testWidgets('a change from inside keeps every chat', (t) async {
    phone(t);
    final lock = await makeLock(withVault, inVault: true);
    final host = FakeHost(
      lock: lock.state,
      everyday: someChats(),
      hidden: [const HideChoice(id: 'h', name: 'Hana')],
    );
    final before = (
      [...host.everyday.map((c) => c.id)],
      [...host.hidden.map((c) => c.id)],
    );
    await _flow(t, lock, host, change: true);
    expect(find.text(l10n.flowEnterHiddenPinLine), findsOneWidget);
    // the app pin does not change the vault
    await typePin(t, appPin);
    await enter(t);
    await t.pumpAndSettle();
    expect(find.text(l10n.lockNotIt), findsOneWidget);
    await typePin(t, vaultPin);
    await enter(t);
    await t.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await typePin(t, '135790');
      await enter(t);
      await t.pumpAndSettle();
    }
    expect(find.text(l10n.flowVaultChanged), findsOneWidget);
    expect(host.moves, isEmpty);
    expect(host.everyday.map((c) => c.id), before.$1);
    expect(host.hidden.map((c) => c.id), before.$2);
    final v = lock.entries['${PinSlot.vault}'] as Map;
    expect(v['p'], '135790');
    expect(v['w'], vaultKey);
    expect(
      await lock.state.confirmPin('135790', changesVault: true),
      PinResult.normal,
    );
    expect(
      await lock.state.confirmPin(vaultPin, changesVault: true),
      PinResult.invalid,
    );
  });

  group('reduced motion', () {
    testWidgets('no page, dot or check moves', (t) async {
      phone(t);
      final lock = await makeLock(appOnly);
      final host = FakeHost(lock: lock.state, everyday: someChats());
      await _flow(t, lock, host, still: true);
      // settled within a frame of zero length: a page swapped out takes one
      // more rebuild to leave, and nothing takes any time
      Future<void> still() async {
        await t.pump(Duration.zero);
        await t.pump(Duration.zero);
        expect(t.binding.hasScheduledFrame, isFalse);
      }

      await press(t, find.text(l10n.commonContinue));
      await still();
      expect(find.text(l10n.flowVaultTitle), findsNothing);
      await typePin(t, '0000');
      await enter(t);
      await still();
      expect(find.text(l10n.lockNotIt), findsOneWidget);
      await typePin(t, appPin);
      await enter(t);
      await still();
      for (var i = 0; i < 2; i++) {
        await typePin(t, vaultPin);
        await still();
        await enter(t);
        await still();
      }
      expect(find.text(l10n.flowVaultForget), findsOneWidget);
      await press(t, find.text(l10n.flowVaultForgetOk));
      await still();
      await still();
      expect(find.text(l10n.flowVaultPickTitle), findsOneWidget);
      await t.tap(find.text('Hana'));
      await still();
      await t.tap(find.text(l10n.flowVaultPickButton(1)));
      await still();
      await still();
      expect(find.text(l10n.flowVaultBackupTitle), findsOneWidget);
      await press(t, find.text(l10n.flowVaultNotNow));
      await still();
      expect(find.text(l10n.flowVaultDone), findsOneWidget);
    });
  });

  group('right to left', () {
    tearDown(() => setL10nLocale(const Locale('en')));

    // where the page coming in starts, part way through the slide
    double enteringDx(WidgetTester t) {
      final slides = t
          .widgetList<SlideTransition>(
            find.descendant(
              of: find.byType(AnimatedSwitcher).first,
              matching: find.byType(SlideTransition),
            ),
          )
          .toList();
      return slides.last.position.value.dx;
    }

    for (final (locale, sign) in [
      (const Locale('en'), 1.0),
      (const Locale('ar'), -1.0),
    ]) {
      testWidgets('pages come in from the side reading goes towards '
          '(${locale.languageCode})', (t) async {
        phone(t);
        setL10nLocale(locale);
        final lock = await makeLock(appOnly);
        await _flow(
          t,
          lock,
          FakeHost(lock: lock.state, everyday: someChats()),
          locale: locale,
        );
        expect(find.text(l10n.flowVaultTitle), findsOneWidget);
        expect(find.text(l10n.flowVaultReplace), findsOneWidget);
        await press(t, find.text(l10n.commonContinue));
        await t.pump();
        await t.pump(const Duration(milliseconds: 60));
        expect(enteringDx(t).sign, sign);
        await t.pumpAndSettle();
        expect(find.text(l10n.flowEnterYourPin), findsOneWidget);
        expect(
          Directionality.of(t.element(find.byType(PinPad))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
  });
}
