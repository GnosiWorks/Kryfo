// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's secure storage: one file sealed under the passphrase
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:path/path.dart' as p;

import '../host_engine.dart';

// stands in for the engine where a test is about the file, not the cipher:
// a keyed xor stream and an hmac tag, enough to tell keys apart
class _Toy implements VaultCrypto {
  int derived = 0;
  @override
  Future<String?> keyOf(String passphrase, Uint8List salt) async {
    derived++;
    return sha256.convert([...utf8.encode(passphrase), ...salt]).toString();
  }

  List<int> _stream(String k, int n) {
    final out = <int>[];
    var i = 0;
    while (out.length < n) {
      out.addAll(sha256.convert([...utf8.encode(k), i++]).bytes);
    }
    return out.sublist(0, n);
  }

  @override
  Uint8List seal(String keyHex, Uint8List plain) {
    final s = _stream(keyHex, plain.length);
    final c = [for (var i = 0; i < plain.length; i++) plain[i] ^ s[i]];
    final tag = Hmac(
      sha256,
      utf8.encode(keyHex),
    ).convert(c).bytes.sublist(0, 16);
    return Uint8List.fromList([...c, ...tag]);
  }

  @override
  Uint8List? open(String keyHex, Uint8List sealed) {
    final c = sealed.sublist(0, sealed.length - 16);
    final tag = Hmac(
      sha256,
      utf8.encode(keyHex),
    ).convert(c).bytes.sublist(0, 16);
    for (var i = 0; i < 16; i++) {
      if (tag[i] != sealed[c.length + i]) return null;
    }
    final s = _stream(keyHex, c.length);
    return Uint8List.fromList([for (var i = 0; i < c.length; i++) c[i] ^ s[i]]);
  }
}

const _pass = 'correct horse battery staple';

void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('vault');
    path = p.join(dir.path, 'vault.kv');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('the file', () {
    test('what is written comes back under the same passphrase', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      await v.write('halo_db_key', "x'${'ab' * 32}'");
      await v.write('theme', 'dark');
      await v.delete('theme');
      final w = DesktopVault(path, crypto: _Toy());
      expect(await w.open(_pass), isTrue);
      expect(w.readAll(), {'halo_db_key': "x'${'ab' * 32}'"});
    });

    test('a wrong passphrase or a changed byte opens nothing', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      await v.write('k', 'v');
      expect(
        await DesktopVault(path, crypto: _Toy()).open('wrong one here'),
        isFalse,
      );
      final raw = File(path).readAsBytesSync();
      raw[raw.length - 20] ^= 1;
      File(path).writeAsBytesSync(raw);
      final w = DesktopVault(path, crypto: _Toy());
      expect(await w.open(_pass), isFalse);
      expect(() => w.read('k'), throwsA(isA<VaultLocked>()));
    });

    test('no two writes seal under the same key', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      final seen = <String>{};
      for (var i = 0; i < 5; i++) {
        await v.write('k', 'same');
        final raw = File(path).readAsBytesSync();
        // the fresh bytes after the salt, and the sealed part, both change
        expect(seen.add(base64.encode(raw.sublist(21))), isTrue);
      }
    });

    test('nothing in the file reads as what it holds', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      await v.write('identity_key', 'meet at the north gate');
      final raw = latin1.decode(File(path).readAsBytesSync());
      expect(raw.contains('identity_key'), isFalse);
      expect(raw.contains('north gate'), isFalse);
    });

    test(
      'a short passphrase is refused, and one file is never replaced',
      () async {
        final v = DesktopVault(path, crypto: _Toy());
        expect(() => v.create('short'), throwsArgumentError);
        expect(File(path).existsSync(), isFalse);
        await v.create(_pass);
        expect(
          () => DesktopVault(path, crypto: _Toy()).create(_pass),
          throwsStateError,
        );
      },
    );

    test('closed, it holds no key and reads nothing', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      v.close();
      expect(v.isOpen, isFalse);
      expect(() => v.read('k'), throwsA(isA<VaultLocked>()));
    });

    test('writes in a row land in order', () async {
      final v = DesktopVault(path, crypto: _Toy(), random: Random(7));
      await v.create(_pass);
      await Future.wait([for (var i = 0; i < 20; i++) v.write('n', '$i')]);
      final w = DesktopVault(path, crypto: _Toy());
      expect(await w.open(_pass), isTrue);
      expect(w.read('n'), '19');
      expect(File('$path.new').existsSync(), isFalse);
    });
  });

  group('on the engine', () {
    final there = loadHostEngine();
    final skip = there ? false : 'no host engine (tool/host_engine.sh)';

    test('scrypt and aes-gcm from the engine open what they sealed', () async {
      final v = DesktopVault(path);
      await v.create(_pass);
      await v.write('halo_db_key', "x'${'cd' * 32}'");
      final w = DesktopVault(path);
      expect(await w.open(_pass), isTrue);
      expect(w.read('halo_db_key'), "x'${'cd' * 32}'");
      expect(await DesktopVault(path).open('$_pass!'), isFalse);
    }, skip: skip);

    test('the key is the backups\' scrypt of the passphrase', () async {
      const c = EngineVaultCrypto();
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await c.keyOf(_pass, salt);
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await c.keyOf(_pass, salt), a);
      expect(await c.keyOf('$_pass.', salt), isNot(a));
      final sealed = c.seal(a!, Uint8List.fromList(utf8.encode('{}')));
      expect(sealed.length, 2 + 16);
      expect(c.open('00' * 32, sealed), isNull);
      expect(utf8.decode(c.open(a, sealed)!), '{}');
    }, skip: skip);
  });
}
