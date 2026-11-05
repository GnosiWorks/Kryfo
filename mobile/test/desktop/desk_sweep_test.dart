// SPDX-License-Identifier: GPL-3.0-or-later
// the start's sweep of plain files runs in another isolate. its job must
// carry the folder alone: one made where the vault is in reach could not
// be sent, and every start swept nothing ("sweep failed: ArgumentError")
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_start.dart' show sweepArea;
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:path/path.dart' as p;

import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String docs;
  late SealedIO io;
  late DesktopVault vault;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('sweep');
    docs = p.join(root.path, 'docs');
    final support = p.join(root.path, 'support');
    for (final d in [p.join(docs, 'media'), support]) {
      Directory(d).createSync(recursive: true);
    }
    final areas = SealedAreas(docs: docs, support: support, runtime: null)
      ..filesKey = _k(9)
      ..containerKeys[''] = _k(1);
    io = SealedIO(areas, ToyCrypto());
    vault = DesktopVault(
      p.join(root.path, 'vault.kv'),
      crypto: ToyVaultCrypto(),
    );
    await vault.create('a passphrase');
    onDesktop = true;
  });
  tearDown(() {
    onDesktop = false;
    root.deleteSync(recursive: true);
  });

  bool plain(String path) => latin1
      .decode(io.rawFile(path).readAsBytesSync(), allowInvalid: true)
      .contains('a plain photo');

  test('a job made beside the vault cannot go to an isolate', () async {
    // what openSeal's own sweep was: the closure held the scope's vault
    final port = ReceivePort();
    addTearDown(port.close);
    final media = p.join(docs, 'media');
    void hold() => port.sendPort;
    hold();
    await IOOverrides.runWithIOOverrides(() async {
      await expectLater(
        runSealed(() {
          hold();
          return sealPlainUnder(media);
        }),
        throwsArgumentError,
      );
    }, io);
  });

  test('the sweep seals what it finds and is marked done', () async {
    final port = ReceivePort();
    addTearDown(port.close);
    final photo = p.join(docs, 'media', 'x.jpg');
    io.rawFile(photo).writeAsStringSync('a plain photo');
    await IOOverrides.runWithIOOverrides(() async {
      // an unsendable in reach here changes nothing for the job
      expect(port.sendPort, isNotNull);
      await sweepArea(io.areas, vault, '', [p.join(docs, 'media')]);
    }, io);
    expect(plain(photo), isFalse);
    expect(vault.read(sweptEntry('')), '1');
    expect(io.areas.swept, contains(''));
    IOOverrides.runWithIOOverrides(
      () => expect(File(photo).readAsStringSync(), 'a plain photo'),
      io,
    );
  });

  test('an area swept once is not swept again', () async {
    io.areas.swept.add('');
    final photo = p.join(docs, 'media', 'y.jpg');
    io.rawFile(photo).writeAsStringSync('a plain photo');
    await IOOverrides.runWithIOOverrides(
      () => sweepArea(io.areas, vault, '', [p.join(docs, 'media')]),
      io,
    );
    expect(plain(photo), isTrue);
    expect(vault.read(sweptEntry('')), isNull);
  });
}
