// SPDX-License-Identifier: GPL-3.0-or-later
// the key number both pair-code screens show: 20 digits from the signal
// identity key a session with that invite runs on. the sharer reads it off
// its own key, the joiner off the key in the invite it fetched, so the two
// match only when the key that arrived is the one that was shared.
//
// fixed, so every version agrees:
//   d = sha256(utf8("kryfo key number v1") || 0x00 || k)
// k is the 33-byte identity key (0x05, then the x25519 key). group i of
// four is bytes d[5i .. 5i+5) read big-endian, mod 100000, five digits.
// that is about 66 bits. never shorter: about 33 bits can be ground within
// a code's ten minutes
import 'dart:convert';

import 'package:crypto/crypto.dart';

const _kDomain = 'kryfo key number v1';

/// the four groups of five digits for [identityKey], null when it is not
/// an identity key. a bare 32-byte key is read as signal writes it
List<String>? keyNumberGroups(List<int> identityKey) {
  final k = identityKey.length == 33 && identityKey[0] == 0x05
      ? identityKey
      : identityKey.length == 32
      ? [0x05, ...identityKey]
      : null;
  if (k == null) return null;
  final d = sha256.convert([...utf8.encode(_kDomain), 0, ...k]).bytes;
  return [
    for (var i = 0; i < 4; i++)
      (d.sublist(5 * i, 5 * i + 5).fold<int>(0, (n, b) => n * 256 + b) % 100000)
          .toString()
          .padLeft(5, '0'),
  ];
}

/// the key number as one line, groups apart
String? keyNumber(List<int> identityKey) =>
    keyNumberGroups(identityKey)?.join(' ');
