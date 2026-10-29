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
  Future<String?> keyOf(String passphrase, Uint8List salt, int logN) async {
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

// a disk that fills up when told to
class _Disk implements VaultDisk {
  bool full = false;
  @override
  void replace(String path, Uint8List bytes) {
    if (full) {
      throw const FileSystemException(
        'write failed',
        'vault.kv.new',
        OSError('No space left on device', 28),
      );
    }
    const RealVaultDisk().replace(path, bytes);
  }
}

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
        expect(seen.add(base64.encode(raw.sublist(22))), isTrue);
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

    test(
      'a write the full disk refused is taken back, the next one lands',
      () async {
        final disk = _Disk();
        final v = DesktopVault(path, crypto: _Toy(), disk: disk);
        await v.create(_pass);
        await v.write('db_key', 'one');
        disk.full = true;
        await expectLater(
          v.write('db_key', 'two'),
          throwsA(isA<FileSystemException>()),
        );
        // memory says what the disk says
        expect(v.read('db_key'), 'one');
        expect(File('$path.new').existsSync(), isFalse);
        disk.full = false;
        await v.write('other', 'three');
        final w = DesktopVault(path, crypto: _Toy());
        expect(await w.open(_pass), isTrue);
        expect(w.readAll(), {'db_key': 'one', 'other': 'three'});
      },
    );

    test(
      'a real write that fails leaves no half file and the old one',
      () async {
        final v = DesktopVault(path, crypto: _Toy());
        await v.create(_pass);
        await v.write('k', 'one');
        // a folder where the new file goes: the write cannot open it
        Directory('$path.new').createSync();
        await expectLater(
          v.write('k', 'two'),
          throwsA(isA<FileSystemException>()),
        );
        Directory('$path.new').deleteSync();
        expect(v.read('k'), 'one');
        await v.write('k', 'three');
        final w = DesktopVault(path, crypto: _Toy());
        expect(await w.open(_pass), isTrue);
        expect(w.read('k'), 'three');
      },
    );

    test('a change shows at once, before its write lands', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      final f = v.write('k', 'v');
      expect(v.read('k'), 'v');
      await f;
      expect(v.read('k'), 'v');
    });

    test('the cost is in the file', () async {
      final v = DesktopVault(path, crypto: _Toy(), logN: 16);
      await v.create(_pass);
      expect(File(path).readAsBytesSync()[25], 16);
      expect(kVaultLogN, 17);
    });

    test('the wipe overwrites the file in place before it goes', () async {
      final v = DesktopVault(path, crypto: _Toy());
      await v.create(_pass);
      await v.write('k', 'meet at the north gate');
      final n = File(path).lengthSync();
      // how destroy opens it: no truncation, so the old blocks are written over
      final r = File(path).openSync(mode: FileMode.writeOnlyAppend);
      r.setPositionSync(0);
      r.writeFromSync(List.filled(4, 0));
      r.closeSync();
      expect(File(path).lengthSync(), n);
      expect(File(path).readAsBytesSync().sublist(0, 4), [0, 0, 0, 0]);
      v.destroy();
      expect(File(path).existsSync(), isFalse);
      expect(v.isOpen, isFalse);
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

    test('the key is scrypt of the passphrase at the cost asked', () async {
      const c = EngineVaultCrypto();
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await c.keyOf(_pass, salt, 15);
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await c.keyOf(_pass, salt, 15), a);
      expect(await c.keyOf('$_pass.', salt, 15), isNot(a));
      expect(await c.keyOf(_pass, salt, 16), isNot(a));
      expect(await c.keyOf(_pass, salt, 14), isNull);
      final sealed = c.seal(a!, Uint8List.fromList(utf8.encode('{}')));
      expect(sealed.length, 2 + 16);
      expect(c.open('00' * 32, sealed), isNull);
      expect(utf8.decode(c.open(a, sealed)!), '{}');
    }, skip: skip);
  });
}
