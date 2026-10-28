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
    // the universal apk sits below the per-abi ones of its version
    expect(gradle, contains('if (abi == null) 0 else abiCodes[abi]'));
    expect(
      gradle,
      contains('mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)'),
    );
  });

  test('google code can only come in through the play flavor', () {
    // a dependency on google's maven names, wherever it is declared
    final google = RegExp(r'"com\.google\.(firebase|android\.gms)');
    for (final l in gradle.split('\n')) {
      if (l.trimLeft().startsWith('//')) continue;
      if (google.hasMatch(l)) {
        expect(
          l.trimLeft(),
          anyOf(
            startsWith('playImplementation('),
            startsWith('"playImplementation"('),
          ),
          reason: l,
        );
      }
    }
    // the firebase values are read by hand: no google-services plugin
    expect(gradle, isNot(contains('com.google.gms.google-services')));
    expect(gradle, isNot(contains('com.google.gms:google-services')));
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
    // fetch and release, each per abi and universal
    expect(builds, hasLength(4));
    for (final b in builds) {
      expect(b[0], contains('--flavor foss'));
    }
    final universal = builds.where((b) => !b[0]!.contains('--split-per-abi'));
    expect(universal, hasLength(2));
    for (final b in universal) {
      expect(b[0], contains('--target-platform android-arm,android-arm64'));
    }
    expect(repro, contains("sed 's/-foss-release/-release/'"));
    expect(repro, contains('app-universal-release'));
  });
}
