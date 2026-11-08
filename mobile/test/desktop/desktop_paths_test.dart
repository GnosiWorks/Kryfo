// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_paths.dart';
import 'package:path/path.dart' as p;

int _mode(String path) => FileStat.statSync(path).mode & 511;

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('paths'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('the data folder is never ~/Documents', () {
    expect(
      desktopDataDir(env: const {'HOME': '/home/a'}),
      '/home/a/.local/share/kryfo',
    );
    expect(
      desktopDataDir(
        env: const {'HOME': '/home/a', 'XDG_DATA_HOME': '/home/a/.var/d'},
      ),
      '/home/a/.var/d/kryfo',
    );
    // a relative xdg path is ignored, as the spec says
    expect(
      desktopDataDir(env: const {'HOME': '/home/a', 'XDG_DATA_HOME': 'rel'}),
      '/home/a/.local/share/kryfo',
    );
  });

  test('every folder the app asks for is 0700 and inside its own', () async {
    final root = p.join(tmp.path, 'kryfo');
    final paths = DesktopPaths(root);
    final got = [
      await paths.getApplicationDocumentsPath(),
      await paths.getApplicationSupportPath(),
      await paths.getTemporaryPath(),
      await paths.getApplicationCachePath(),
      await paths.getLibraryPath(),
    ];
    for (final d in got) {
      expect(p.isWithin(root, d!), isTrue, reason: d);
      expect(_mode(d), 448, reason: d);
    }
    expect(_mode(root), 448);
    expect(await paths.getDownloadsPath(), isNull);
    expect(await paths.getExternalStoragePath(), isNull);
  });

  test('a folder left open by an older run is closed again', () async {
    final root = p.join(tmp.path, 'k2');
    Directory(p.join(root, 'docs')).createSync(recursive: true);
    Process.runSync('chmod', ['0755', root, p.join(root, 'docs')]);
    expect(_mode(root), 493);
    await DesktopPaths(root).getApplicationDocumentsPath();
    expect(_mode(root), 448);
    expect(_mode(p.join(root, 'docs')), 448);
  });

  test('files the process makes are its user\'s alone', () {
    privateUmask();
    final f = File(p.join(tmp.path, 'f'))..writeAsStringSync('x');
    final d = Directory(p.join(tmp.path, 'd'))..createSync();
    expect(_mode(f.path), 384);
    expect(_mode(d.path), 448);
  });
}
