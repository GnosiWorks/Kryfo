// SPDX-License-Identifier: GPL-3.0-or-later
// the vault's data key kept by the computer account or by a passphrase,
// with the keyring, dpapi and the tpm stood in for
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_platform.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/keyring_linux.dart';
import 'package:kryfo/desktop/seal_windows.dart';
import 'package:kryfo/desktop/system_seal.dart';
import 'package:path/path.dart' as p;

import 'desktop_round4_test.dart' show oldVaultFile;
import 'desktop_start_test.dart' show ToyVaultCrypto;

const _pass = 'four random words here';
const _next = 'five other random words now';

Future<R> _here<R>(FutureOr<R> Function() f) async => f();

/// a keyring in memory, as the Secret Service keeps items by attributes
class FakeKeyring implements SystemSeal {
  final items = <String, Uint8List>{};
  SealFail? failFetch;
  bool refuse = false;
  bool working = true;
  final forgotten = <String>[];

  @override
  Future<bool> works() async => working;

  @override
  Future<SealedSecret> keep(Uint8List id, Uint8List secret) async {
    if (refuse) throw const SealError(SealFail.refused);
    items[hexOf(id)] = Uint8List.fromList(secret);
    return SealedSecret(SealHow.keyring, Uint8List(0));
  }

  @override
  Future<Uint8List> fetch(Uint8List id, int how, Uint8List data) async {
    if (failFetch != null) throw SealError(failFetch!);
    final s = items[hexOf(id)];
    if (s == null) throw const SealError(SealFail.missing);
    return Uint8List.fromList(s);
  }

  // a locked keyring keeps what a clear asks for
  bool locked = false;

  @override
  Future<bool> forget(Uint8List id) async {
    forgotten.add(hexOf(id));
    if (locked) return !items.containsKey(hexOf(id));
    items.remove(hexOf(id));
    return true;
  }
}

class _Full implements VaultDisk {
  static bool full = false;
  @override
  void replace(String path, Uint8List bytes) {
    if (full) throw const FileSystemException('full');
    const RealVaultDisk().replace(path, bytes);
  }
}

class _Api implements SecretApi {
  final store_ = <String, Uint8List>{};
  KeyringFind? answer;
  bool storeOk = true;
  final cleared = <Map<String, String>>[];
  final asked = <Map<String, String>>[];

  @override
  (Uint8List?, KeyringFind) lookup(Map<String, String> attrs) {
    asked.add(attrs);
    if (answer != null) return (null, answer!);
    final s = store_[attrs.toString()];
    return s == null ? (null, KeyringFind.none) : (s, KeyringFind.found);
  }

  @override
  bool store(Map<String, String> attrs, String label, Uint8List secret) {
    if (!storeOk) return false;
    store_[attrs.toString()] = Uint8List.fromList(secret);
    return true;
  }

  @override
  bool clear(Map<String, String> attrs) {
    cleared.add(attrs);
    if (answer == KeyringFind.locked) return false;
    return store_.remove(attrs.toString()) != null;
  }

  @override
  bool? there(Map<String, String> attrs) {
    if (answer == KeyringFind.error) return null;
    return store_.containsKey(attrs.toString());
  }
}

// dpapi as a reversible wrap bound to its entropy, a tpm as a named table
class _Win implements WinCrypt {
  bool tpm = true;
  bool tpmBreaks = false;
  bool protectOk = true;
  int? unwrapStatus;
  final keys = <String, int>{};
  final deleted = <String>[];

  @override
  Uint8List? protect(Uint8List data, Uint8List entropy) {
    if (!protectOk) return null;
    return Uint8List.fromList([entropy.length, ...entropy, ...data.reversed]);
  }

  @override
  Uint8List? unprotect(Uint8List blob, Uint8List entropy) {
    final n = blob[0];
    final e = blob.sublist(1, 1 + n);
    if (n != entropy.length) return null;
    for (var i = 0; i < n; i++) {
      if (e[i] != entropy[i]) return null;
    }
    return Uint8List.fromList(blob.sublist(1 + n).reversed.toList());
  }

  @override
  bool tpmThere() => tpm;

  @override
  Uint8List tpmWrap(String name, Uint8List secret) {
    if (tpmBreaks) throw const WinCryptError(0x80284001);
    final k = keys[name] = (keys[name] ?? 0) + 1;
    return Uint8List.fromList([for (final b in secret) b ^ k, 0xee]);
  }

  @override
  Uint8List tpmUnwrap(String name, Uint8List wrapped) {
    if (unwrapStatus != null) throw WinCryptError(unwrapStatus!);
    final k = keys[name];
    if (k == null) throw const WinCryptError(0x80090016);
    return Uint8List.fromList([
      for (final b in wrapped.sublist(0, wrapped.length - 1)) b ^ k,
    ]);
  }

  @override
  bool tpmDelete(String name) {
    deleted.add(name);
    keys.remove(name);
    return true;
  }
}

// the head of a version 4 file as someone with a copy reads it: its slots
// and where the body starts
(List<(int, Uint8List)>, int) _headOf(Uint8List raw) {
  var at = 5 + 16;
  final n = raw[at++];
  final slots = <(int, Uint8List)>[];
  for (var i = 0; i < n; i++) {
    final kind = raw[at];
    final len = raw[at + 1] << 8 | raw[at + 2];
    slots.add((kind, Uint8List.fromList(raw.sublist(at + 3, at + 3 + len))));
    at += 3 + len;
  }
  return (slots, at + 32);
}

String _hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// the data key out of an older copy, with the passphrase or the system
/// secret that opened it then
Future<Uint8List?> dataKeyOfCopy(
  Uint8List raw, {
  String? pass,
  Uint8List? secret,
}) async {
  final toy = ToyVaultCrypto();
  final (kind, d) = _headOf(raw).$1.first;
  List<int> kek;
  int at;
  if (kind == 1) {
    final k = await toy.keyOf(pass!, Uint8List.sublistView(d, 1, 17), d[0]);
    kek = [
      for (var i = 0; i < 64; i += 2)
        int.parse(k!.substring(i, i + 2), radix: 16),
    ];
    at = 17;
  } else {
    kek = secret!;
    at = 1;
  }
  final fresh = d.sublist(at, at + 16);
  final wrap = Hmac(
    sha256,
    kek,
  ).convert([...utf8.encode('kryfo vault slot'), ...fresh]);
  return toy.open(
    _hexOf(wrap.bytes),
    Uint8List.sublistView(d, at + 16, at + 16 + 48),
  );
}

/// whether [dk] opens the body of the file [raw]
bool opensBody(Uint8List raw, Uint8List dk) {
  final at = _headOf(raw).$2;
  final body = Hmac(
    sha256,
    dk,
  ).convert([...utf8.encode('kryfo vault body'), ...raw.sublist(0, at)]);
  return ToyVaultCrypto().open(_hexOf(body.bytes), raw.sublist(at)) != null;
}

void main() {
  late Directory dir;
  late String path;
  late FakeKeyring ring;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('keys');
    path = p.join(dir.path, 'vault.kv');
    ring = FakeKeyring();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  DesktopVault vault() => DesktopVault(path, crypto: ToyVaultCrypto());

  group('the vault kept by the computer', () {
    test('opens with no question, and holds what it held', () async {
      final v = vault();
      await v.createSealed(ring);
      await v.write('db', 'key one');
      expect(v.hasPassphrase, isFalse);
      final raw = File(path).readAsBytesSync();
      expect(raw[4], 4);
      expect(raw.length % kVaultBucket, 0);
      // the keyring holds a secret, not the data key, and nothing of the map
      expect(ring.items, hasLength(1));
      final w = vault();
      expect(w.lockKind, VaultLockKind.system);
      expect(await w.openSealed(ring), SealedOpen.opened);
      expect(w.read('db'), 'key one');
      expect(await vault().open(_pass), isFalse);
    });

    test('a keyring that will not keep it leaves no file', () async {
      ring.refuse = true;
      final v = vault();
      await expectLater(v.createSealed(ring), throwsA(isA<SealError>()));
      expect(v.exists, isFalse);
      expect(v.isOpen, isFalse);
    });

    test('another account or computer: missing, and nothing opens', () async {
      await vault().createSealed(ring);
      final w = vault();
      expect(await w.openSealed(FakeKeyring()), SealedOpen.missing);
      expect(w.isOpen, isFalse);
    });

    test('a locked or silent keyring is told apart from a gone one', () async {
      await vault().createSealed(ring);
      ring.failFetch = SealFail.unreachable;
      expect(await vault().openSealed(ring), SealedOpen.unreachable);
      ring.failFetch = SealFail.missing;
      expect(await vault().openSealed(ring), SealedOpen.missing);
      ring.failFetch = null;
      expect(await vault().openSealed(ring), SealedOpen.opened);
    });

    test('another secret under the same name opens nothing', () async {
      await vault().createSealed(ring);
      final id = ring.items.keys.single;
      ring.items[id] = Uint8List(32);
      expect(await vault().openSealed(ring), SealedOpen.missing);
    });

    test('a head moved onto another body opens nothing', () async {
      final a = vault();
      await a.createSealed(ring);
      await a.write('k', 'a');
      final other = p.join(dir.path, 'b.kv');
      final b = DesktopVault(other, crypto: ToyVaultCrypto());
      await b.createSealed(ring);
      await b.write('k', 'b');
      final ra = File(path).readAsBytesSync();
      final rb = File(other).readAsBytesSync();
      // a's head (its slot and fresh bytes) with b's sealed body
      const head = 4 + 1 + 16 + 1 + 3 + 1 + 16 + 48 + 32;
      File(
        path,
      ).writeAsBytesSync([...ra.sublist(0, head), ...rb.sublist(head)]);
      expect(await vault().openSealed(ring), SealedOpen.missing);
      // a changed slot byte too
      final raw = Uint8List.fromList(ra)..[head - 40] ^= 1;
      File(path).writeAsBytesSync(raw);
      expect(await vault().openSealed(ring), SealedOpen.missing);
    });

    test('an unknown version says so', () async {
      await vault().createSealed(ring);
      final raw = File(path).readAsBytesSync()..[4] = 9;
      File(path).writeAsBytesSync(raw);
      final w = vault();
      expect(await w.openSealed(ring), SealedOpen.otherVersion);
      expect(w.madeByOtherVersion, isTrue);
    });

    test('a vault under a passphrase is not opened by the keyring', () async {
      await vault().create(_pass);
      final w = vault();
      expect(w.lockKind, VaultLockKind.passphrase);
      expect(await w.openSealed(ring), SealedOpen.missing);
      expect(await w.open(_pass), isTrue);
      expect(w.hasPassphrase, isTrue);
    });

    test('the wipe takes what the keyring kept too', () async {
      final v = vault();
      await v.createSealed(ring);
      v.destroy();
      expect(File(path).existsSync(), isFalse);
      await v.forgetSystem(ring);
      expect(ring.items, isEmpty);
      expect(ring.forgotten, hasLength(1));
    });

    test('the host waits for the keyring before the folder goes', () async {
      final order = <String>[];
      final host = DesktopHost(
        dataDir: p.join(dir.path, 'gone'),
        exit: (_) => order.add('exit'),
        destroyKeys: () => order.add('vault'),
      )..forgetKeys = () async => order.add('keyring');
      await host.wipe();
      expect(order, ['vault', 'keyring', 'exit']);
    });
  });

  group('adding, changing and removing a passphrase', () {
    test(
      'added, only the passphrase opens it and the keyring forgets',
      () async {
        final v = vault();
        await v.createSealed(ring);
        await v.write('db', 'key');
        await expectLater(v.addPassphrase('short'), throwsArgumentError);
        await v.addPassphrase(_pass, seal: ring);
        expect(v.hasPassphrase, isTrue);
        expect(ring.items, isEmpty);
        final w = vault();
        expect(w.lockKind, VaultLockKind.passphrase);
        expect(await w.openSealed(ring), SealedOpen.missing);
        expect(await w.open(_pass), isTrue);
        expect(w.read('db'), 'key');
      },
    );

    test('changed, the old one no longer opens it', () async {
      final v = vault();
      await v.create(_pass);
      await v.write('db', 'key');
      expect(await v.changePassphrase('not it at all here', _next), isFalse);
      expect(await v.changePassphrase(_pass, _next), isTrue);
      expect(await vault().open(_pass), isFalse);
      final w = vault();
      expect(await w.open(_next), isTrue);
      expect(w.read('db'), 'key');
    });

    test('removed, the keyring opens it and the passphrase does not', () async {
      final v = vault();
      await v.create(_pass);
      await v.write('db', 'key');
      expect(await v.removePassphrase('not it at all here', ring), isFalse);
      expect(ring.items, isEmpty);
      expect(await v.removePassphrase(_pass, ring), isTrue);
      expect(v.hasPassphrase, isFalse);
      final w = vault();
      expect(w.lockKind, VaultLockKind.system);
      expect(await vault().open(_pass), isFalse);
      expect(await w.openSealed(ring), SealedOpen.opened);
      expect(w.read('db'), 'key');
    });

    test('a keyring that refuses leaves the passphrase in place', () async {
      final v = vault();
      await v.create(_pass);
      ring.refuse = true;
      await expectLater(
        v.removePassphrase(_pass, ring),
        throwsA(isA<SealError>()),
      );
      expect(v.hasPassphrase, isTrue);
      expect(await vault().open(_pass), isTrue);
    });

    test('a write between the head changes keeps its place', () async {
      final v = vault();
      await v.createSealed(ring);
      await Future.wait([
        v.write('a', '1'),
        v.addPassphrase(_pass, seal: ring),
        v.write('b', '2'),
      ]);
      final w = vault();
      expect(await w.open(_pass), isTrue);
      expect(w.readAll(), {'a': '1', 'b': '2'});
    });

    test(
      'a version 3 file opens and is written again under a passphrase',
      () async {
        File(path).writeAsBytesSync(await oldVaultFile(3, {'db': 'old'}));
        final v = vault();
        expect(v.lockKind, VaultLockKind.passphrase);
        expect(await v.open(_pass), isTrue);
        expect(File(path).readAsBytesSync()[4], 4);
        final w = vault();
        expect(await w.open(_pass), isTrue);
        expect(w.read('db'), 'old');
        expect(w.hasPassphrase, isTrue);
      },
    );
  });

  group('an older copy of the file', () {
    test('a passphrase added shuts out a copy kept by the keyring', () async {
      final v = vault();
      await v.createSealed(ring);
      await v.write('db', 'key');
      final copy = File(path).readAsBytesSync();
      final item = Uint8List.fromList(ring.items.values.single);
      final dk = (await dataKeyOfCopy(copy, secret: item))!;
      expect(opensBody(copy, dk), isTrue);
      await v.addPassphrase(_pass, seal: ring);
      await v.write('db', 'later');
      expect(opensBody(File(path).readAsBytesSync(), dk), isFalse);
      final w = vault();
      expect(await w.open(_pass), isTrue);
      expect(w.read('db'), 'later');
    });

    test('a changed passphrase shuts out a copy under the old one', () async {
      final v = vault();
      await v.create(_pass);
      await v.write('db', 'key');
      final copy = File(path).readAsBytesSync();
      final dk = (await dataKeyOfCopy(copy, pass: _pass))!;
      expect(opensBody(copy, dk), isTrue);
      expect(await v.changePassphrase(_pass, _next), isTrue);
      expect(opensBody(File(path).readAsBytesSync(), dk), isFalse);
      await v.write('b', '2');
      final w = vault();
      expect(await w.open(_next), isTrue);
      expect(w.readAll(), {'db': 'key', 'b': '2'});
    });

    test('a removed passphrase shuts out a copy under it', () async {
      final v = vault();
      await v.create(_pass);
      final copy = File(path).readAsBytesSync();
      final dk = (await dataKeyOfCopy(copy, pass: _pass))!;
      expect(await v.removePassphrase(_pass, ring), isTrue);
      expect(opensBody(File(path).readAsBytesSync(), dk), isFalse);
      expect(await vault().openSealed(ring), SealedOpen.opened);
    });

    test('a failed write keeps the key it had', () async {
      final v = DesktopVault(path, crypto: ToyVaultCrypto(), disk: _Full());
      await DesktopVault(path, crypto: ToyVaultCrypto()).create(_pass);
      expect(await v.open(_pass), isTrue);
      _Full.full = true;
      await expectLater(
        v.addPassphrase(_next),
        throwsA(isA<FileSystemException>()),
      );
      _Full.full = false;
      await v.write('a', '1');
      final w = vault();
      expect(await w.open(_pass), isTrue);
      expect(w.read('a'), '1');
    });
  });

  group('what the computer kept, cleared by the vault id', () {
    test('the wipe clears it on a passphrase vault too', () async {
      final v = vault();
      await v.createSealed(ring);
      // a clear that did not land when the passphrase was added
      ring.locked = true;
      await v.addPassphrase(_pass, seal: ring);
      expect(ring.items, hasLength(1));
      ring.locked = false;
      v.destroy();
      await v.forgetSystem(ring);
      expect(ring.items, isEmpty);
    });

    test('a passphrase open clears what is owed, once it can', () async {
      final v = vault();
      await v.createSealed(ring);
      ring.locked = true;
      await v.addPassphrase(_pass, seal: ring);
      expect(ring.items, hasLength(1));
      // still locked: it stays owed and nothing asks
      final w = vault();
      expect(await w.open(_pass, seal: ring), isTrue);
      await w.forgetting;
      expect(ring.items, hasLength(1));
      expect(w.read(kVaultForgetOwed), isNotNull);
      w.close();
      ring
        ..locked = false
        ..forgotten.clear();
      final x = vault();
      expect(await x.open(_pass, seal: ring), isTrue);
      await x.forgetting;
      expect(ring.items, isEmpty);
      expect(x.read(kVaultForgetOwed), isNull);
      x.close();
      // nothing owed: the keyring is not asked again
      ring.forgotten.clear();
      final y = vault();
      expect(await y.open(_pass, seal: ring), isTrue);
      await y.forgetting;
      expect(ring.forgotten, isEmpty);
    });

    test('a cut between the write and the clear is cleared later', () async {
      final v = vault();
      await v.createSealed(ring);
      // the passphrase written, and the app gone before the clear
      await v.addPassphrase(_pass);
      expect(ring.items, hasLength(1));
      final w = vault();
      expect(await w.open(_pass, seal: ring), isTrue);
      await w.forgetting;
      expect(ring.items, isEmpty);
      expect(w.read(kVaultForgetOwed), isNull);
    });

    test('the keyring clears only after a search found it', () async {
      final api = _Api();
      final seal = KeyringSeal(api, run: _here);
      final id = Uint8List(16);
      expect(await seal.forget(id), isTrue);
      expect(api.cleared, isEmpty);
      await seal.keep(id, Uint8List(32));
      api.answer = KeyringFind.locked;
      expect(await seal.forget(id), isFalse);
      api.answer = KeyringFind.error;
      expect(await seal.forget(id), isFalse);
      api.answer = null;
      expect(await seal.forget(id), isTrue);
      expect(api.store_, isEmpty);
    });
  });

  group('the linux keyring', () {
    late _Api api;
    late KeyringSeal seal;
    final id = Uint8List.fromList(List.generate(16, (i) => i));
    final secret = Uint8List.fromList(List.generate(32, (i) => 200 - i));
    setUp(() {
      api = _Api();
      seal = KeyringSeal(api, run: _here);
    });

    test('works only when a lookup answers none', () async {
      expect(await seal.works(), isTrue);
      expect(api.asked.single, {'kryfo-vault': 'probe'});
      api.answer = KeyringFind.error;
      expect(await seal.works(), isFalse);
    });

    test('keeps under the vault id, gives back, forgets', () async {
      final kept = await seal.keep(id, secret);
      expect(kept.how, SealHow.keyring);
      expect(kept.data, isEmpty);
      expect(api.store_.keys.single, {'kryfo-vault': hexOf(id)}.toString());
      expect(await seal.fetch(id, kept.how, kept.data), secret);
      expect(await seal.forget(id), isTrue);
      expect(api.cleared.single, {'kryfo-vault': hexOf(id)});
    });

    test('says why nothing came back', () async {
      Future<SealFail?> why() async {
        try {
          await seal.fetch(id, SealHow.keyring, Uint8List(0));
          return null;
        } on SealError catch (e) {
          return e.why;
        }
      }

      expect(await why(), SealFail.missing);
      api.answer = KeyringFind.locked;
      expect(await why(), SealFail.unreachable);
      api.answer = KeyringFind.error;
      expect(await why(), SealFail.unreachable);
      api.answer = null;
      api.store_[{'kryfo-vault': hexOf(id)}.toString()] = Uint8List(31);
      expect(await why(), SealFail.missing);
      // a windows slot on linux
      await expectLater(
        seal.fetch(id, SealHow.dpapi, Uint8List(4)),
        throwsA(isA<SealError>()),
      );
    });

    test('a refused store is a refusal', () async {
      api.storeOk = false;
      await expectLater(
        seal.keep(id, secret),
        throwsA(isA<SealError>().having((e) => e.why, 'why', SealFail.refused)),
      );
    });
  });

  group('windows', () {
    late _Win api;
    late WindowsSeal seal;
    final id = Uint8List.fromList(List.generate(16, (i) => 50 + i));
    final secret = Uint8List.fromList(List.generate(32, (i) => i * 3));
    setUp(() {
      api = _Win();
      seal = WindowsSeal(api, run: _here);
    });

    Future<SealFail?> why(SealedSecret k, {Uint8List? as}) async {
      try {
        await seal.fetch(as ?? id, k.how, k.data);
        return null;
      } on SealError catch (e) {
        return e.why;
      }
    }

    test('with a tpm: its wrap inside dpapi, and back', () async {
      final k = await seal.keep(id, secret);
      expect(k.how, SealHow.tpm);
      expect(api.keys.keys.single, 'Kryfo vault ${hexOf(id)}');
      expect(await seal.fetch(id, k.how, k.data), secret);
      expect(await seal.forget(id), isTrue);
      expect(api.deleted, ['Kryfo vault ${hexOf(id)}']);
      expect(await why(k), SealFail.missing);
    });

    test('without a tpm, or one that breaks: dpapi alone', () async {
      api.tpm = false;
      final k = await seal.keep(id, secret);
      expect(k.how, SealHow.dpapi);
      expect(await seal.fetch(id, k.how, k.data), secret);
      api
        ..tpm = true
        ..tpmBreaks = true;
      final k2 = await seal.keep(id, secret);
      expect(k2.how, SealHow.dpapi);
      expect(api.deleted, isNotEmpty);
      expect(await seal.fetch(id, k2.how, k2.data), secret);
      // forgotten by name whatever the slot says: nothing is left
      api.deleted.clear();
      expect(await seal.forget(id), isTrue);
      expect(api.deleted, ['Kryfo vault ${hexOf(id)}']);
      // no tpm here at all: nothing to look for
      api
        ..tpm = false
        ..deleted.clear();
      expect(await seal.forget(id), isTrue);
      expect(api.deleted, isEmpty);
    });

    test('dpapi bound to the vault: another vault id opens nothing', () async {
      final k = await seal.keep(id, secret);
      expect(await why(k, as: Uint8List(16)), SealFail.missing);
    });

    test('a refused dpapi is a refusal and leaves no tpm key', () async {
      api.protectOk = false;
      await expectLater(
        seal.keep(id, secret),
        throwsA(isA<SealError>().having((e) => e.why, 'why', SealFail.refused)),
      );
      expect(api.keys, isEmpty);
    });

    test('a cleared tpm is missing, a waiting one is not', () {
      bool gone(int s) => WinCryptError(s).keyGone;
      // TPM_20_E_INTEGRITY, TPM_20_E_HANDLE, TPM_E_INVALID_KEYHANDLE: a key
      // file the new root no longer loads
      expect(gone(0x8028009F), isTrue);
      expect(gone(0x8028008B), isTrue);
      expect(gone(0x8028000C), isTrue);
      // TPM_20_E_AUTH_FAIL on session 1: format one, not a warning
      expect(gone(0x8028098E), isTrue);
      expect(gone(0x80090016), isTrue);
      expect(gone(0x80090003), isTrue);
      // lockout, retry, self test, the tpm service not running
      expect(gone(0x80280921), isFalse);
      expect(gone(0x80280922), isFalse);
      expect(gone(0x80280800), isFalse);
      expect(gone(0x8028400B), isFalse);
      // anything else: not known to be gone
      expect(gone(0x80070005), isFalse);
    });

    test('a tpm key gone is missing; a busy tpm may answer later', () async {
      final k = await seal.keep(id, secret);
      api.unwrapStatus = 0x80090016;
      expect(await why(k), SealFail.missing);
      api.unwrapStatus = 0x80280921;
      expect(await why(k), SealFail.unreachable);
      // after a Clear TPM the key file stays but no longer loads
      api.unwrapStatus = 0x8028009F;
      expect(await why(k), SealFail.missing);
      api.unwrapStatus = null;
      expect(await why(k), isNull);
    });

    test('crypt32 and ncrypt open by their full system32 path', () {
      expect(
        systemDll(r'C:\Windows\system32', 'ncrypt.dll'),
        r'C:\Windows\system32\ncrypt.dll',
      );
      expect(
        systemDll('C:\\Windows\\system32\\', 'crypt32.dll'),
        r'C:\Windows\system32\crypt32.dll',
      );
      expect(() => systemDll('', 'ncrypt.dll'), throwsStateError);
      // no dll by its bare name but kernel32, a known dll
      final src = File('lib/desktop/seal_windows.dart').readAsStringSync();
      final bare = RegExp(r"DynamicLibrary\.open\(\s*'(\w+\.dll)'")
          .allMatches(src)
          .map((m) => m[1])
          .toSet();
      expect(bare, {'kernel32.dll'});
      expect(src, contains("_dll('crypt32.dll')"));
      expect(src, contains("_dll('ncrypt.dll')"));
      expect(src, contains('systemDll(_systemDir(), name)'));
    });

    test('a vault kept by windows opens through it', () async {
      final v = vault();
      await v.createSealed(seal);
      await v.write('db', 'win');
      final w = vault();
      expect(await w.openSealed(seal), SealedOpen.opened);
      expect(w.read('db'), 'win');
      w.destroy();
      await w.forgetSystem(seal);
      expect(api.keys, isEmpty);
    });
  });
}
