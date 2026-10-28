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
  // (android/app/build.gradle.kts): its pattern still finds it here
  test('a play release build would refuse the development key', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('kPushGatewayDevPub'));
    expect(gradle, contains('variant.buildType.name == "release"'));
    final src = File('lib/google_push.dart').readAsStringSync();
    final dev = RegExp(r'const\s+kPushGatewayPub\s*=\s*kPushGatewayDevPub\s*;');
    expect(dev.hasMatch(src), kPushGatewayPub == kPushGatewayDevPub);
  });

  test(
    'the gateway key is the server\'s, not the development one',
    () => expect(kPushGatewayPub, isNot(kPushGatewayDevPub)),
    skip: release ? false : 'release check: KRYFO_RELEASE=1',
  );
}
