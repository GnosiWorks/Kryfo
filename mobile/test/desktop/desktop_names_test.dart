// SPDX-License-Identifier: GPL-3.0-or-later
// what a copied desktop folder's names say: no decoy, no vault, no name a
// sender gave a file
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_paths.dart';
import 'package:kryfo/main.dart' show receivedFileFor, typeLeaf;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  tearDown(() => onDesktop = false);

  test('the phone names its databases and folders by number too', () {
    expect(HaloContainer.decoy.dbFile, 'k2.db');
    expect(HaloContainer.vault.dbFile, 'k3.db');
    expect(HaloContainer.decoyVault.dbFile, 'k4.db');
    expect(HaloContainer.decoy.oldDbFile, 'halo_d.db');
    expect(HaloContainer.vault.suffix, '_v');
    expect(HaloContainer.vault.folderSuffix, '_k3');
    expect(HaloContainer.decoy.folderSuffix, '_k2');
    expect(HaloContainer.decoyVault.folderSuffix, '_k4');
  });

  test('on desktop no name says decoy or vault', () {
    onDesktop = true;
    final names = [
      for (final c in HaloContainer.all) ...[c.dbFile, 'media${c.suffix}'],
    ];
    expect(names, [
      'halo.db',
      'media',
      'k2.db',
      'media_k2',
      'k3.db',
      'media_k3',
      'k4.db',
      'media_k4',
    ]);
    for (final n in names) {
      expect(n, isNot(matches(RegExp(r'_(d|v|dv)(\.db)?$'))), reason: n);
    }
  });

  test('a file keeps only its type on disk', () {
    expect(typeLeaf('Wren passport scan.PDF'), '.pdf');
    expect(typeLeaf('archive.tar.gz'), '.gz');
    expect(typeLeaf('no type'), '');
    expect(typeLeaf('x.verylongtype'), '');
    expect(typeLeaf('../../etc/passwd'), '');
  });

  test('a received file is named by chance alone, on desktop and on the '
      'phone', () async {
    final tmp = Directory.systemTemp.createTempSync('names');
    addTearDown(() => tmp.deleteSync(recursive: true));
    PathProviderPlatform.instance = DesktopPaths(tmp.path);
    onDesktop = true;
    final f = await receivedFileFor('Wren passport scan.pdf');
    expect(p.basename(f.path), matches(RegExp(r'^in_[0-9a-f]{32}\.pdf$')));
    onDesktop = false;
    final g = await receivedFileFor('Wren passport scan.pdf');
    expect(p.basename(g.path), matches(RegExp(r'^in_[0-9a-f]{32}\.pdf$')));
  });
}
