// SPDX-License-Identifier: GPL-3.0-or-later
// the launcher name, read from the gradle and manifest sources: "Kryfo test"
// for the bridgetest debug app, "Kryfo" for every other build. gradle's
// label check holds each build to the same on its merged manifest
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

const _app = 'android/app';

// the braces that open after [marker], with what is between them
String _block(String src, String marker) {
  final at = src.indexOf(marker);
  if (at < 0) throw StateError('not found: $marker');
  final open = src.indexOf('{', at);
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  throw StateError('unclosed: $marker');
}

void main() {
  final gradle = sourceOf('$_app/build.gradle.kts');
  final types = _block(gradle, 'buildTypes {');

  test('the manifest takes its label from gradle, in one place', () {
    final labels = <String>[];
    for (final m in ['main', 'debug', 'profile', 'play']) {
      final src = sourceOf('$_app/src/$m/AndroidManifest.xml');
      labels.addAll(
        RegExp(r'android:label="[^"]*"').allMatches(src).map((x) => x[0]!),
      );
    }
    expect(labels, [r'android:label="${appLabel}"']);
  });

  test('every build is named Kryfo', () {
    expect(
      _block(gradle, 'defaultConfig {'),
      contains('manifestPlaceholders["appLabel"] = "Kryfo"\n'),
    );
    expect(_block(types, 'release {'), isNot(contains('appLabel')));
  });

  test('only the bridgetest debug app is named Kryfo test', () {
    final test = _block(
      _block(types, 'debug {'),
      'if (System.getenv("HALO_TEST_ID") == "1") {',
    );
    expect(test, contains('applicationIdSuffix = ".bridgetest"'));
    expect(test, contains('manifestPlaceholders["appLabel"] = "Kryfo test"'));
    expect(
      RegExp('appLabel"\\] = "Kryfo test"').allMatches(gradle),
      hasLength(1),
    );
  });

  test('gradle checks the merged label before every apk and bundle', () {
    final check = bodyOf(gradle, 'fun check(');
    expect(
      check,
      contains(
        'if (appId.get() == "app.kryfo.bridgetest") "Kryfo test" else "Kryfo"',
      ),
    );
    expect(gradle, contains('SingleArtifact.MERGED_MANIFEST'));
    expect(
      gradle,
      contains('it.name == "assemble\$name" || it.name == "bundle\$name"'),
    );
  });
}
