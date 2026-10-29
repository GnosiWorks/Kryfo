// SPDX-License-Identifier: GPL-3.0-or-later
// the computer passphrase row in a decoy session: the real one's screens,
// work and answers, kept in the decoy's own note, the real lock untouched
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/computer_lock.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/seal_windows.dart';
import 'package:kryfo/desktop/system_seal.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:path/path.dart' as p;

import 'desktop_keys_test.dart' show FakeKeyring, FakeWin;
import 'desktop_start_test.dart' show ToyVaultCrypto;

const _pass = 'four random words here';
const _next = 'five other random words now';
const _wrong = 'not it at all, not even close';

Future<R> _here<R>(FutureOr<R> Function() f) async => f();

// the toy crypto, counting the work asked of it
class _Counted implements VaultCrypto {
  int keys = 0, seals = 0, opens = 0;
  final _toy = ToyVaultCrypto();

  (int, int, int) get work => (keys, seals, opens);
  void reset() => keys = seals = opens = 0;

  @override
  Future<Uint8List?> keyOf(String passphrase, Uint8List salt, int logN) {
    keys++;
    return _toy.keyOf(passphrase, salt, logN);
  }

  @override
  Uint8List seal(Uint8List key, Uint8List plain) {
    seals++;
    return _toy.seal(key, plain);
  }

  @override
  Uint8List? open(Uint8List key, Uint8List sealed) {
    opens++;
    return _toy.open(key, sealed);
  }
}

void main() {
  late Directory dir;
  late FakeKeyring ring;
  String? note;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('decoylock');
    ring = FakeKeyring();
    note = null;
    keepComputerDecoyNote = (n) async => note = n;
  });
  tearDown(() {
    keepComputerDecoyNote = null;
    dir.deleteSync(recursive: true);
  });

  String path([String name = 'vault.kv']) => p.join(dir.path, name);

  bool sameItems(Map<String, Uint8List> a, Map<String, Uint8List> b) =>
      a.length == b.length &&
      a.entries.every(
        (e) => b[e.key] != null && listEquals(b[e.key]!, e.value),
      );

  test(
    'add, change and remove in a decoy leave the real lock as it was',
    () async {
      final v = DesktopVault(path(), crypto: ToyVaultCrypto());
      await v.createSealed(ring);
      await v.write('db', 'key');
      final lock = DesktopComputerLock(v, ring);
      final before = File(path()).readAsBytesSync();
      final items = {
        for (final e in ring.items.entries) e.key: Uint8List.fromList(e.value),
      };
      ring.kept = 0;
      final d = lock.lockFor(decoy: true);
      expect(d.on, isFalse);
      await d.add(_pass);
      expect(d.on, isTrue);
      expect(lock.passphraseOn(decoy: true), isTrue);
      expect(lock.passphraseOn(decoy: false), isFalse);
      expect(await d.change(_wrong, _next), isFalse);
      expect(await d.change(_pass, _next), isTrue);
      expect(await d.remove(_pass), isFalse);
      expect(await d.remove(_next), isTrue);
      expect(d.on, isFalse);
      await d.add(_pass);
      // not a byte of the vault, nothing kept or cleared by the keyring
      expect(File(path()).readAsBytesSync(), before);
      expect(sameItems(ring.items, items), isTrue);
      expect(ring.kept, 0);
      expect(ring.forgotten, isEmpty);
      expect(ring.rehearsed, containsAll([true, false]));
      expect(v.hasPassphrase, isFalse);
      expect(
        await DesktopVault(path(), crypto: ToyVaultCrypto()).openSealed(ring),
        SealedOpen.opened,
      );
      // the decoy's note, read again on the next start
      final again = DesktopComputerLock(v, ring)..decoyNoteRead(note);
      expect(again.passphraseOn(decoy: true), isTrue);
      expect(again.passphraseOn(decoy: false), isFalse);
    },
  );

  test('the real passphrase is the decoy\'s until it sets its own', () async {
    final v = DesktopVault(path(), crypto: ToyVaultCrypto());
    await v.create(_pass);
    final lock = DesktopComputerLock(v, ring);
    final before = File(path()).readAsBytesSync();
    final d = lock.lockFor(decoy: true);
    expect(d.on, isTrue);
    expect(await d.change(_next, _pass), isFalse);
    expect(await d.remove(_pass), isTrue);
    expect(d.on, isFalse);
    expect(File(path()).readAsBytesSync(), before);
    expect(ring.items, isEmpty);
    expect(ring.kept, 0);
    expect(v.hasPassphrase, isTrue);
    expect(
      await DesktopVault(path(), crypto: ToyVaultCrypto()).open(_pass),
      isTrue,
    );
  });

  test(
    'windows: the tpm and dpapi are asked, nothing kept or deleted',
    () async {
      final api = FakeWin();
      final seal = WindowsSeal(api, run: _here);
      final v = DesktopVault(path(), crypto: ToyVaultCrypto());
      await v.createSealed(seal);
      final keys = Map.of(api.keys);
      final before = File(path()).readAsBytesSync();
      final d = DesktopComputerLock(v, seal).lockFor(decoy: true);
      await d.add(_pass);
      expect(await d.remove(_pass), isTrue);
      expect(api.tried, 1);
      expect(api.keys, keys);
      expect(api.deleted, isEmpty);
      expect(File(path()).readAsBytesSync(), before);
    },
  );

  test('a refusal in a decoy is the real one\'s refusal', () async {
    final v = DesktopVault(path(), crypto: ToyVaultCrypto());
    await v.create(_pass);
    ring.refuse = true;
    final d = DesktopComputerLock(v, ring).lockFor(decoy: true);
    await expectLater(d.remove(_pass), throwsA(isA<SealError>()));
    expect(d.on, isTrue);
  });

  test('the decoy does the real one\'s work, step for step', () async {
    Future<(_Counted, PassphraseLock)> side(String name, bool decoy) async {
      final c = _Counted();
      final v = DesktopVault(path(name), crypto: c);
      await v.createSealed(ring);
      return (c, DesktopComputerLock(v, ring).lockFor(decoy: decoy));
    }

    final (rc, real) = await side('real.kv', false);
    final (dc, decoy) = await side('decoy.kv', true);
    Future<void> both(Future<void> Function(PassphraseLock l) step) async {
      rc.reset();
      dc.reset();
      await step(real);
      await step(decoy);
      expect(dc.work, rc.work);
      expect(rc.keys, greaterThan(0));
    }

    await both((l) => l.add(_pass));
    await both((l) async => expect(await l.change(_wrong, _next), isFalse));
    await both((l) async => expect(await l.change(_pass, _next), isTrue));
    await both((l) async => expect(await l.remove(_next), isTrue));
    await both((l) => l.add(_pass));
  });

  group('the page', () {
    // every line the page shows, in order
    List<String> shown(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        w.data ?? w.textSpan?.toPlainText() ?? '',
    ];

    Future<List<List<String>>> walk(WidgetTester t, bool decoy) async {
      final v = DesktopVault(
        path(decoy ? 'd.kv' : 'r.kv'),
        crypto: ToyVaultCrypto(),
      );
      await v.createSealed(ring);
      final lock = DesktopComputerLock(v, ring);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: lock.page(decoy: decoy),
        ),
      );
      await t.pumpAndSettle();
      final seen = [shown(t)];
      Future<void> tap(String label) async {
        await t.tap(find.text(label).last);
        await t.pumpAndSettle();
        seen.add(shown(t));
      }

      Future<void> type(List<String> texts) async {
        final fields = find.byType(TextField);
        for (var i = 0; i < texts.length; i++) {
          await t.enterText(fields.at(i), texts[i]);
        }
        await t.pump();
      }

      await tap(l10n.desktopLockAddPassphrase);
      await type([_pass, _pass]);
      await tap(l10n.desktopLockAddPassphrase);
      await tap(l10n.desktopPassChange);
      await type([_wrong, _next, _next]);
      await tap(l10n.desktopPassChange);
      await type([_pass, _next, _next]);
      await tap(l10n.desktopPassChange);
      await tap(l10n.desktopPassRemove);
      await type([_next]);
      await tap(l10n.desktopPassRemove);
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox());
      return seen;
    }

    testWidgets('looks and answers the same in a decoy', (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final real = await walk(t, false);
      final decoy = await walk(t, true);
      expect(decoy, real);
      // the walk reached each answer: added, wrong, changed, removed
      final all = real.expand((s) => s).toList();
      expect(all, contains(l10n.desktopPassAdded));
      expect(all, contains(l10n.desktopLockWrong));
      expect(all, contains(l10n.desktopPassChanged));
      expect(all, contains(l10n.desktopPassRemoved));
    });
  });
}
