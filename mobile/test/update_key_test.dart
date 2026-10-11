// SPDX-License-Identifier: GPL-3.0-or-later
// a release pins the real version key. run as part of the release checks:
//   KRYFO_RELEASE=1 flutter test test/update_key_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/update_check.dart';

void main() {
  final release = Platform.environment['KRYFO_RELEASE'] == '1';

  test(
    'the version key is pinned, not the placeholder',
    () {
      expect(kVersionPubKeyB64, isNot(kVersionKeyPlaceholder));
      expect(base64.decode(kVersionPubKeyB64), hasLength(32));
    },
    skip: release ? false : 'release check: KRYFO_RELEASE=1',
  );
}
