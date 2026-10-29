// SPDX-License-Identifier: GPL-3.0-or-later
// the vault's keyring calls against a real Secret Service. runs only when
// KRYFO_KEYRING_LIB names a libsecret and a session bus with an unlocked
// keyring is up (dbus-run-session, gnome-keyring-daemon --unlock);
// KRYFO_SECRET_TOOL names secret-tool for the locked case. skipped otherwise
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/keyring_linux.dart';
import 'package:kryfo/desktop/system_seal.dart';
import 'package:path/path.dart' as p;

import 'desktop_start_test.dart' show ToyVaultCrypto;

void main() {
  final lib = Platform.environment['KRYFO_KEYRING_LIB'];
  final tool = Platform.environment['KRYFO_SECRET_TOOL'];
  final skip = lib == null ? 'no KRYFO_KEYRING_LIB' : false;
  late KeyringSeal seal;
  late Directory dir;
  setUp(() {
    seal = KeyringSeal(FfiSecretApi(library: lib ?? ''));
    dir = Directory.systemTemp.createTempSync('kr');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Uint8List id(int n) => Uint8List.fromList(List.filled(16, n));

  test('the keyring answers, keeps, gives back and forgets', () async {
    expect(await seal.works(), isTrue);
    final secret = Uint8List.fromList(List.generate(32, (i) => i * 7));
    final kept = await seal.keep(id(1), secret);
    expect(kept.how, SealHow.keyring);
    expect(kept.data, isEmpty);
    expect(await seal.fetch(id(1), kept.how, kept.data), secret);
    // another vault's name finds nothing
    await expectLater(
      seal.fetch(id(2), kept.how, kept.data),
      throwsA(isA<SealError>().having((e) => e.why, 'why', SealFail.missing)),
    );
    expect(await seal.forget(id(1)), isTrue);
    await expectLater(
      seal.fetch(id(1), kept.how, kept.data),
      throwsA(isA<SealError>().having((e) => e.why, 'why', SealFail.missing)),
    );
  }, skip: skip);

  test('a vault the keyring keeps opens again, and goes on a wipe', () async {
    final path = p.join(dir.path, 'vault.kv');
    final v = DesktopVault(path, crypto: ToyVaultCrypto());
    await v.createSealed(seal);
    await v.write('db', 'key');
    v.close();
    final w = DesktopVault(path, crypto: ToyVaultCrypto());
    expect(w.lockKind, VaultLockKind.system);
    expect(await w.openSealed(seal), SealedOpen.opened);
    expect(w.read('db'), 'key');
    w.destroy();
    await w.forgetSystem(seal);
    File(path).writeAsBytesSync([]);
  }, skip: skip);

  test(
    'a locked keyring is told from a missing item',
    () async {
      final secret = Uint8List.fromList(List.filled(32, 9));
      final kept = await seal.keep(id(3), secret);
      final r = await Process.run(tool!, ['lock', '--collection=login']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      // the unlock prompt cannot show here, so the item stays locked
      await expectLater(
        seal.fetch(id(3), kept.how, kept.data),
        throwsA(
          isA<SealError>().having((e) => e.why, 'why', SealFail.unreachable),
        ),
      );
      // a clear by the vault id leaves a locked item, asks nothing, and
      // says it is still there
      expect(await seal.forget(id(3)), isFalse);
    },
    skip: tool == null ? 'no KRYFO_SECRET_TOOL' : skip,
  );
}
