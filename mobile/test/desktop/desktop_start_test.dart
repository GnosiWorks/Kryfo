// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop start: its folder private, the user's own and held by one
// process; prefs and secrets in the vault and nowhere else
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_channels.dart';
import 'package:kryfo/desktop/desktop_db.dart';
import 'package:kryfo/desktop/desktop_platform.dart';
import 'package:kryfo/desktop/desktop_posix.dart';
import 'package:kryfo/desktop/desktop_prefs.dart';
import 'package:kryfo/desktop/desktop_start.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class ToyVaultCrypto implements VaultCrypto {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('start'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('the owner read is the one the system gives', () {
    final want = int.parse(
      '${Process.runSync('stat', ['-c', '%u', tmp.path]).stdout}'.trim(),
    );
    expect(ownerOf(tmp.path), want);
    expect(ownerOf(tmp.path), getuid());
    expect(ownerOf(p.join(tmp.path, 'none')), isNull);
  });

  test('a folder of another user is refused', () async {
    expect(
      await claimFolder(p.join(tmp.path, 'k'), uid: () => getuid() + 1),
      DesktopStop.notYours,
    );
  });

  test('a folder that cannot be made is refused', () async {
    expect(await claimFolder('/proc/kryfo-cannot-be'), DesktopStop.notPrivate);
  });

  test('a second process on the folder is refused, then let in', () async {
    final root = p.join(tmp.path, 'k3');
    Directory(root).createSync();
    final lock = p.join(root, 'lock');
    final other = await Process.start('flock', ['-n', lock, 'sleep', '2']);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      await claimFolder(root, wait: const Duration(milliseconds: 400)),
      DesktopStop.alreadyOpen,
    );
    // a reopen's new process waits out the old one
    expect(await claimFolder(root, wait: const Duration(seconds: 5)), isNull);
    await other.exitCode;
  });

  test('a lock that is a link is never followed', () {
    final target = File(p.join(tmp.path, 'elsewhere'))..writeAsStringSync('');
    final link = p.join(tmp.path, 'lock-link');
    Link(link).createSync(target.path);
    expect(holdLock(link), isFalse);
  });

  group('prefs in the vault', () {
    late DesktopVault vault;
    setUp(() async {
      vault = DesktopVault(
        p.join(tmp.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      SharedPreferencesStorePlatform.instance = VaultPrefs(vault);
    });

    test('shut, they fail rather than read empty', () async {
      await expectLater(
        SharedPreferencesStorePlatform.instance.getAll(),
        throwsA(isA<VaultLocked>()),
      );
    });

    test('every kind comes back as it went in', () async {
      await vault.create(_pass);
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('muted_abc', true);
      await prefs.setInt('n', 3);
      await prefs.setDouble('d', 1.5);
      await prefs.setString('route', 'bridges');
      await prefs.setStringList('list', ['a', 'b']);
      final again = DesktopVault(
        p.join(tmp.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      expect(await again.open(_pass), isTrue);
      SharedPreferencesStorePlatform.instance = VaultPrefs(again);
      SharedPreferences.resetStatic();
      final back = await SharedPreferences.getInstance();
      expect(back.getBool('muted_abc'), isTrue);
      expect(back.getInt('n'), 3);
      expect(back.getDouble('d'), 1.5);
      expect(back.getString('route'), 'bridges');
      expect(back.getStringList('list'), ['a', 'b']);
      await back.remove('n');
      await back.clear();
      expect((await SharedPreferencesStorePlatform.instance.getAll()), isEmpty);
    });
  });

  test('the keyring channel is shut on desktop', () async {
    final m = DesktopMessenger(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      desktopAnswers(DesktopHost(dataDir: tmp.path), DesktopDb()),
    );
    const codec = StandardMethodCodec();
    final r = await m.send(
      keyringChannel,
      codec.encodeMethodCall(const MethodCall('read', {'key': 'k'})),
    );
    expect(() => codec.decodeEnvelope(r!), throwsA(isA<PlatformException>()));
  });

  test('the start refuses storage that is not the vault', () {
    expect(assertVaultOnly, throwsStateError);
    final v = DesktopVault(p.join(tmp.path, 'v.kv'), crypto: ToyVaultCrypto());
    FlutterSecureStoragePlatform.instance = VaultStorage(v);
    SharedPreferencesStorePlatform.instance = VaultPrefs(v);
    expect(assertVaultOnly, returnsNormally);
  });
}
