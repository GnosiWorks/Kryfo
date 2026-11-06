// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices are on in 0.6, in every build: the switch is on with no
// define at all, and no build path of the repo turns it off. an android
// build that passes KRYFO_LINKED=0 stops at gradle
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/linked_switch.dart';
import 'package:kryfo/typing.dart' show kCapDevices, myCaps;

// every place a release is built from: scripts, recipes, packaging and the
// build docs a person follows
const _buildPaths = [
  '../BUILDING.md',
  '../README.md',
  '../RELEASING.md',
  '../.github',
  '../repro',
  '../packaging',
  '../fdroid',
  '../fdroiddata',
  '../scripts',
  '../engine/build.sh',
  '../engine/build-linux.sh',
  '../engine/build-windows.sh',
  'linux',
  'windows',
  'tool',
  'android/app/src',
  'android/build.gradle.kts',
  'android/settings.gradle.kts',
  'pubspec.yaml',
];

Iterable<File> _files(String path) sync* {
  final t = FileSystemEntity.typeSync(path);
  if (t == FileSystemEntityType.file) {
    yield File(path);
  } else if (t == FileSystemEntityType.directory) {
    for (final f in Directory(path).listSync(recursive: true)) {
      if (f is File && !f.path.contains('/build/')) yield f;
    }
  }
}

void main() {
  test('the switch is on with no define, and so is what the app reads', () {
    expect(kLinkedDevicesOn, isTrue);
    linkedDevicesForTest = null;
    expect(linkedDevicesOn, isTrue);
    expect(myCaps, contains(kCapDevices));
    // a test still turns it off, and back to the build's
    linkedDevicesForTest = false;
    expect(linkedDevicesOn, isFalse);
    expect(myCaps, isNot(contains(kCapDevices)));
    linkedDevicesForTest = null;
    expect(linkedDevicesOn, isTrue);
  });

  test('no build path of the repo names KRYFO_LINKED', () {
    final named = <String>[];
    var read = 0;
    for (final p in _buildPaths) {
      for (final f in _files(p)) {
        final String src;
        try {
          src = f.readAsStringSync();
        } on FileSystemException {
          continue; // a binary
        }
        read++;
        if (src.contains('KRYFO_LINKED')) named.add(f.path);
      }
    }
    expect(read, greaterThan(20));
    expect(named, isEmpty);
  });

  test('an android build passing KRYFO_LINKED=0 stops at gradle', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    final at = g.indexOf('"KRYFO_LINKED=0"');
    expect(at, greaterThan(0));
    expect(g.indexOf('"KRYFO_LINKED=false"', at), greaterThan(at));
    expect(
      g.indexOf('throw GradleException("linked devices are', at),
      greaterThan(at),
    );
  });

  test('nothing in the app says linking is off or not wired yet', () {
    final stale = RegExp(
      r'off in every (release )?build|until linking is wired|'
      r'linking is not wired|off in 0\.6',
      caseSensitive: false,
    );
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/l10n/app_localizations')) continue;
      final src = f.readAsStringSync();
      for (final m in stale.allMatches(src)) {
        found.add('${f.path}: ${m.group(0)}');
      }
    }
    expect(found, isEmpty);
  });
}
