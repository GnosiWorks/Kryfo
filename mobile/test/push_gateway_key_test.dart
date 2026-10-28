// SPDX-License-Identifier: GPL-3.0-or-later
// a release pins the push gateway's own key, never the development one. run
// as part of the release checks:
//   KRYFO_RELEASE=1 flutter test test/push_gateway_key_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/google_push.dart';

void main() {
  final release = Platform.environment['KRYFO_RELEASE'] == '1';

  test('the gateway key is an x25519 key', () {
    expect(
      base64Url.decode(base64Url.normalize(kPushGatewayPub)),
      hasLength(32),
    );
  });

  // the play release build refuses the development key on its own
  // (android/app/build.gradle.kts), by its value: named or copied in
  test('a play release build would refuse the development key', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('value("kPushGatewayDevPub")'));
    expect(gradle, contains('variant.buildType.name == "release"'));
    // the same reading of the source as gradle's
    final src = File('lib/google_push.dart').readAsStringSync();
    String? value(String name) {
      final m = RegExp(
        'const\\s+$name\\s*=\\s*(?:\'([^\']*)\'|"([^"]*)"|(\\w+))\\s*;',
      ).firstMatch(src);
      if (m == null) return null;
      return m[1] ?? m[2] ?? m[3];
    }

    var pinned = value('kPushGatewayPub');
    if (pinned == 'kPushGatewayDevPub') pinned = value('kPushGatewayDevPub');
    expect(value('kPushGatewayDevPub'), kPushGatewayDevPub);
    expect(pinned, kPushGatewayPub);
  });

  test(
    'the gateway key is the server\'s, not the development one',
    () => expect(kPushGatewayPub, isNot(kPushGatewayDevPub)),
    skip: release ? false : 'release check: KRYFO_RELEASE=1',
  );
}
