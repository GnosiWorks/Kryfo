// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's pinned identity: the keys of Marios's own invite, built
// into the app. the chat with him trusts these keys, never his three words:
// three words are 33 bits, and anyone can grind a key that has them

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../dlog.dart';
import '../main.dart' show parseHaloUri;

enum DevKeyStatus {
  // new chats start with it
  current,
  // chats already on it keep going after a rotation
  previous,
  // nothing more is sent or taken in with it
  retired,
}

class DevKey {
  const DevKey({
    required this.keyId,
    required this.threeWords,
    required this.xPub,
    required this.bundle,
    required this.fc,
    this.onion = '',
    this.status = DevKeyStatus.current,
  });

  // never reused, so a chat id always names one key
  final String keyId;
  // shown in the about sheet, never trusted
  final String threeWords;
  // 64 hex: the relay lanes and the signal identity
  final String xPub;
  // the invite's base64 bundle, as it was shared
  final String bundle;
  // 64 hex: the dev phone's first-contact address
  final String fc;
  // empty: relay only
  final String onion;
  final DevKeyStatus status;

  // the chat's peer id everywhere on this phone. never three words, so no
  // row made from the wire can land on it
  String get chatId => chatIdOf(keyId);

  static String chatIdOf(String keyId) => 'dev:$keyId';

  // a key from a v3 invite link, read by the app's own parser. its onion is
  // left out. the signature is not checked here: the self-check test does
  // that for every pinned key, and a first send checks it again
  static DevKey? fromLink(
    String link, {
    required String keyId,
    DevKeyStatus status = DevKeyStatus.current,
  }) {
    final p = parseHaloUri(link);
    if (p == null || p['v'] != '3') return null;
    final fc = p['fc']?.toLowerCase();
    if (fc == null || !_hex64.hasMatch(fc)) return null;
    final bundle = p['bundle']!;
    final id = _identityOf(bundle);
    if (id == null) return null;
    return DevKey(
      keyId: keyId,
      threeWords: p['id']!,
      xPub: _hex(id.sublist(1)),
      bundle: bundle,
      fc: fc,
      status: status,
    );
  }
}

// the pinned keys, from the dev phone's own v3 link. relay only: no onion
const kDevKeys = <DevKey>[
  DevKey(
    keyId: 'm1',
    threeWords: 'scare-raven-rare',
    xPub: '2f3bddfadec1e445a44e0b7608b5fcaca5b84f00b1ba0341c233fc840ca87d3a',
    bundle:
        'eyJyZWdpc3RyYXRpb25JZCI6NDI1MiwiZGV2aWNlSWQiOjEsInByZUtleUlkIjo5OTk5OTksInByZUtleVB1YmxpYyI6IkJjeWlOL1NxRkQ5eGJ0QTBPaEVzSXpYaHB3eEE1TVRPNDJnNks0SWIxOVU2Iiwic2lnbmVkUHJlS2V5SWQiOjEsInNpZ25lZFByZUtleVB1YmxpYyI6IkJiNFoyUGNlMzdzb1VkYXlMQ1YrWHdmY2FsY3RIVEIvWkx1ay9rSjkrQXRYIiwic2lnbmVkUHJlS2V5U2lnbmF0dXJlIjoic2RnWE1wNmFDZThkOTh1NmVPajRVM3pNRklodzd3ZDNlMGo2NXpSNisxdW5xUlI4QnVTVTg4cFE2WUx1RCtaZVYwanhvdUdMbkVpc0R5MmNLM2ZIQVE9PSIsImlkZW50aXR5S2V5IjoiQlM4NzNmcmV3ZVJGcEU0TGRnaTEvS3lsdUU4QXNib0RRY0l6L0lRTXFIMDYifQ==',
    fc: '099b6ff70339a7a2df2e362ffa3ad97c4db962d4814e44236359e4e33e2a6dfb',
  ),
];

// the keys this build trusts. a debug or profile build made with
// --dart-define=KRYFO_DEV_CARD=<a v3 link> trusts that card instead, so a
// test phone can play the developer. a release reads neither override
List<DevKey> get devKeys {
  if (kReleaseMode) return kDevKeys;
  final t = _forTest;
  if (t != null) return t;
  const card = String.fromEnvironment('KRYFO_DEV_CARD');
  if (card.isEmpty) return kDevKeys;
  return _cardKeys ??= _fromCard(card);
}

List<DevKey>? _cardKeys;
List<DevKey>? _forTest;

// a card that does not read trusts nobody: a test build must never fall
// back to the real keys
List<DevKey> _fromCard(String card) {
  final k = DevKey.fromLink(card, keyId: 't1');
  if (k == null) dlog('dev key: the test card does not read');
  return k == null ? const [] : [k];
}

@visibleForTesting
void useDevKeysForTest(List<DevKey>? keys) => _forTest = keys;

DevKey? get currentDevKey {
  for (final k in devKeys) {
    if (k.status == DevKeyStatus.current) return k;
  }
  return null;
}

DevKey? devKeyById(String keyId) {
  for (final k in devKeys) {
    if (k.keyId == keyId) return k;
  }
  return null;
}

DevKey? devKeyByXPub(String xPub) {
  final x = xPub.toLowerCase();
  for (final k in devKeys) {
    if (k.xPub == x) return k;
  }
  return null;
}

DevKey? devKeyByFc(String fc) {
  final f = fc.toLowerCase();
  for (final k in devKeys) {
    if (k.fc == f) return k;
  }
  return null;
}

bool isDevChat(String id) => id.startsWith('dev:');

// the 33 bytes libsignal compares: the type byte, then the x25519 key
Uint8List pinnedIdentity(DevKey k) =>
    Uint8List.fromList([0x05, ..._bytes(k.xPub)]);

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

// the bundle's identity key, when it is the 33 bytes of an x25519 key
Uint8List? _identityOf(String bundle) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(bundle)));
    if (j is! Map) return null;
    final ik = j['identityKey'];
    if (ik is! String) return null;
    final b = base64Decode(ik);
    return b.length == 33 && b[0] == 0x05 ? b : null;
  } catch (_) {
    return null;
  }
}

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

List<int> _bytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];
