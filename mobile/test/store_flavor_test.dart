// SPDX-License-Identifier: GPL-3.0-or-later
// the two store flavors, read from the gradle, repro and dart sources. foss
// is what f-droid, github and the site ship and has to stay free of google
// code; play is the google play build. runs as is and with --flavor play
import 'dart:io';

import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/store.dart';

import 'source_body.dart';

const _app = 'android/app';

// every file under [dir], or none when it does not exist
List<File> _files(String dir) => Directory(dir).existsSync()
    ? Directory(dir).listSync(recursive: true).whereType<File>().toList()
    : [];

void main() {
  final gradle = sourceOf('$_app/build.gradle.kts');

  test('gradle has a foss and a play flavor and nothing else', () {
    expect(gradle, contains('flavorDimensions += "store"'));
    expect(
      RegExp(
        r'create\("(\w+)"\) \{\s+dimension = "store"',
      ).allMatches(gradle).map((m) => m[1]),
      ['foss', 'play'],
    );
  });

  test('the play bundle is versioned N*10+9, the foss apks N*10+abi', () {
    final play = gradle.substring(gradle.indexOf('create("play")'));
    expect(play, contains('versionCode = flutter.versionCode * 10 + 9'));
    expect(
      gradle,
      contains('if (abiVersionCode != null && variant.flavorName == "foss")'),
    );
  });

  test('google code can only come in through the play flavor', () {
    final google = RegExp(r'com\.google\.(firebase|android\.gms)|firebase');
    final deps = gradle.substring(gradle.indexOf('\ndependencies {'));
    for (final l in deps.split('\n')) {
      if (google.hasMatch(l)) {
        expect(l.trimLeft(), startsWith('playImplementation('), reason: l);
      }
    }
    expect(gradle, isNot(contains('google-services')));
    for (final dir in ['main', 'foss']) {
      for (final f in _files('$_app/src/$dir')) {
        if (!RegExp(r'\.(kt|java|xml)$').hasMatch(f.path)) continue;
        expect(google.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    }
  });

  test('release kotlin keeps the module name it had before flavors', () {
    final keep = gradle.substring(gradle.indexOf('tasks.withType<org.'));
    expect(keep, contains('name == "compileFossReleaseKotlin"'));
    expect(keep, contains('compilerOptions.moduleName.set("app_release")'));
  });

  test('the play overlay names the service type main gives it', () {
    // lint checks the overlay's service element on its own
    final type = RegExp(
      r'HaloListenerService"[^>]*android:foregroundServiceType="(\w+)"',
    );
    final main = type.firstMatch(
      sourceOf('$_app/src/main/AndroidManifest.xml'),
    );
    final play = type.firstMatch(
      sourceOf('$_app/src/play/AndroidManifest.xml'),
    );
    expect(main?[1], 'specialUse');
    expect(play?[1], main?[1]);
  });

  test('the old store define stops the build', () {
    expect(gradle, contains('.startsWith("KRYFO_STORE=")'));
    expect(gradle, contains('throw GradleException("KRYFO_STORE is gone.'));
  });

  test('a build that names no flavor is foss', () {
    expect(
      sourceOf('pubspec.yaml'),
      matches(RegExp(r'\nflutter:\n(  .*\n|\n)*  default-flavor: foss\n')),
    );
    expect(appFlavor, anyOf('foss', 'play'));
  });

  test('the play build is the play flavor', () {
    expect(kPlayBuild, appFlavor == 'play');
  });

  test('the repro build makes the foss apks under their old names', () {
    final repro = sourceOf('../repro/build-repro.sh');
    final builds = RegExp(r'flutter build apk[^\n]*').allMatches(repro);
    expect(builds, hasLength(2));
    for (final b in builds) {
      expect(b[0], contains('--flavor foss'));
    }
    expect(repro, contains("sed 's/-foss-release/-release/'"));
  });
}
