// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's pinned identity: the keys of Marios's own invite, built
// into the app. the chat with him trusts these keys, never his three words:
// three words are 33 bits, and anyone can grind a key that has them

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../dlog.dart';
import '../main.dart' show parseHaloUri;
import 'dev_lane.dart' show devCardChecks;

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
        'eyJyZWdpc3RyYXRpb25JZCI6NDI1MiwiZGV2aWNlSWQiOjEsInByZUtleUlkIjo5OTk5OTksInByZUtleVB1YmxpYyI6IkJjeWlOL1NxRkQ5eGJ0QTBPaEVzSXpYaHB3eEE1TVRPNDJnNks0SWIxOVU2Iiwic2lnbmVkUHJlS2V5SWQiOjEsInNpZ25lZFByZUtleVB1YmxpYyI6IkJiNFoyUGNlMzdzb1VkYXlMQ1YrWHdmY2FsY3RIVEIvWkx1ay9rSjkrQXRYIiwic2lnbmVkUHJlS2V5U2lnbmF0dXJlIjoic2RnWE1wNmFDZThkOTh1NmVPajRVM3pNRklodzd3ZDNlMGo2NXpSNisxdW5xUlI4QnVTVTg4cFE2WUx1RCtaZVYwanhvdUdMbkVpc0R5MmNLM2ZIQVE9PSIsImt5YmVyUHJlS2V5SWQiOjEsImt5YmVyUHJlS2V5UHVibGljIjoiQ0J2RVNDTUZSWGxYcENPQ3FLWnN0MzJDalZpMm11d1FxaDF5UlJubGxjaG9uU2xob2JQM29NNGFKVk1rQUp3a3Z5Q25uQ0NzdDRWcG5pUEV6emI3RnQ0V0RoSlJadmhqU1hDMUhtREhWUG5tQWp6SVVuTk11cnFRVElwVEpJKzVVUWx6bUtSNlNQTlNDcjhqcDNZeHRnRFVGN0VETE1yRVZQc0tpS2pRd3lGeGt0cmtIMUZNcENzVmpZUUVRTUFXWGgvUUdHL0tUR2Rwczl1TFJGVTBqUzQ3SUVpQkxqK21neHRqenZjS2EzZWtYclI0TjNac2tCZ1pzcEduczRWTVpEcDNHRi9WUGJZVWUzU0R3dWxyWkRkSXBzMzBzTHI0SGRLNmdReUtjYzlJUUJyQmtLRmN6aDlxdzRmMmxxR0tjQjdBbk1BNWVVa3NzdWlyRVkxamE5em1qZnozdFBKcWRSUjJmMkV6SDBkMEVqcG13REVvZGZta2c3cGxyYnNKemVFbHc0c1RyTEd3SmU5NHd1L3FFTng1b1U5QWRuRGNqWFcxdmtqV2dqNnNJOGlLeW1mTXZ1VUdnekxIbkxOMkdoMTFPTTBraFNkaWg5ZDRRV0ZGVm5pcG9kdW9ycGIwSTFOOGxwT0NYRHR5Rk5UeWVUMDhVOXVpZ1pwa21uNUN6YUpRazM5VmZoT0V2elJ6b0k1NWE3Rm5aZ0FIcVpUc3JvdlpDSlU2eHpCRGVRSFJ3cjZUYXBaaEthRnF6ZDlrcndFaXYwV0ZJc05zYmpWbVIxVEJCTHYzbXQ2aXF1NFhjMEZJT1E1alk3YUluV2ViVTBsanlDM1RDTmZiWWNsVHlxUjJ0TjY4cFdjVVVibTVaMU9UWE95NklMUWxJL3FEVC9qd1pHSHhaOTQ3aDlqS0d3OUljOGlrVzJ4QXJld21EQk94U3JIanZoaHpZY2NuYnRJS3JiVkdBcnY1Y3ZTTVZxZUF5RHBpWENNd1Z1cDZXNVdGU1NvOGxjdTZlYzR5WTFCanZXR0hNekxUcTVWc29vZ0hRdFhMcmJKbmpzOVlPQlhIRG0yTVBpTlhvdnBJbXY5NVlRTERGVlc3eTlpVm5jK3FYR0gzbXJGUVlVQm9iUkJxQng4REtlZjVCSW0zd2xCMEU0cTBvOW9ycC9jY0tKOEFDRHVhUStiWU1Oc29Ub2kxaFl1eEY5L3pURXJhcE85aGJSTlpHc1B6d21QMVZCcXpZK1pTeXVkQWx0QUVWaTJqSWlNVmFKc0JGbDEzbDJ6Mlpjc0JFNWxBR3IwbmdGWG5kK1p3TUMvRUZaeUt3TllBakJJNFpCeERwTHU0TERZVkw4ajVEVEhrWG91QkNlRmhJejFKb3VlVGFrQXpoT1pIdjZ0b2pya25LU3N5cnF2YUNXTERURGozVWNEaEdMdVpzUFBVamlmc09mTXJCQmgxd3l1SEVpb1VUVDc4YTM0WU9ZdWpPOXhrSVdCQlRCbjRPM2NsUUVFM09EVlR1QUlwUnF4NHNGa1dIbWlvZVJHYkVLVGxWTjZEb2JlR0svYVJ0SjZMTU9iVFh3WlpWSGFWbFFkbVdQYVNaVy9LWTBON295UDNZZnB5am93SlRWRUFMNXpiSlA3YnhITHlTaE9ZSXpBeFRTSDJuYithYWdhSExIZVdzVEx4cUY2YWYwZ1REZVJIYTdOemx4b0p2Q1RJWkgrRWVuMVRZbHhIT1hqZ3IxZ1djRlRGSmk2enY2b3JQY3gyWnZJM2JxamFEZVRTR25MeXpVMnJXZDlCbGp3S3ZvaVlnNmFXQS9ZNG14czNYL1JhUzVTSG5LdXpkNng3WlNhbkNaS1JvYnlwU2hYNXYxQlp0SEpMVUk5d3dLTHpNa0hNZnMwb0RVdlhRVW9YQjg4d0NMU0NuMUZDVm1vVno5bkxzbTE4YzIvN3pnbDVOeTFpV3lHaWE0elRKWUF5SG5sQVpMSldCYzlnWnlabG1aSkx5MzQ0UlN1a2VscGFFdmFhTjZEU1BWSklaK1QxVFluSWFzSERWQWRFRnh5S0xvZHlqWmQwQTVaeGUxRDROZlg4YmM5QkN6bVdzSXZtSW9uTHM3N0VydlNjb1p0cXpjc3NQVldXa3lHREFRVm1FN3pLYk9MQkJUc1JaaURZc0RPSXNhc3dsTEZjTmwyVGFtM0R2SEc3YnNCNXdxVklDRHgxcDRwY2p2OW15WVV5RHRVbERrSm9PaEVwWXpGM3MrSWh4cE5WQkhpMXA2TG9Nc0EwZ3FoSEJBQUR6N0M3bnA5NE45YVNldWV4YTg2c0ZYUldGN0tzd01UbXQwbUJNdDU0RnltTGs4eGtvaWRvSDJ4MXBGRTFWSFNobGJMOFdMQXp6N20yWU85SEJPTGtkVkV5bTBIMENYWXpnUlAyb3JkNGlVNjJhOUJJcG0ycmkrRUZuM3lRVFE1TGJibEdENDdiaXIreldYdml3bHNLTGJaNU9PaEpmNVZnZ3REUVFzU2tHQXJCeHlPNlNMSGhJUStScCtuR1UrL2pva2FKR1FxVGN0QllxbEtXQnArR2llY0tZcUpvQkdGQWlOQXdHaEpXekxMUWg3Z0tRQUdjaGxCZ0xFam9TQ3V5bjg1WXFIbVpkeG1aVXlTeGI3cUlhQW5VWE5YNllYdGtJU1FJUnRYYUx6WTByc0ptRXZIRldURzhIRU1DVlc2eXZJbVhVazJ6V2M4SUxNNm5YZjhHVVA3VjdHdmZQd0RNRThCcXB1ZUwySFlPNFR6VDhNOHpwMGlpREh1RCIsImt5YmVyUHJlS2V5U2lnbmF0dXJlIjoiZG1MQXhRRmxDR2hkVzJ1NU91UE83dzN2OUIrOGlSbSt4WUdkaStxanY5MWtsaFVkNFRVNTdXUmJaZkwvZGN0eEkvSDVuTXA0OVdIVmtTZjhEMlI4Qmc9PSIsImlkZW50aXR5S2V5IjoiQlM4NzNmcmV3ZVJGcEU0TGRnaTEvS3lsdUU4QXNib0RRY0l6L0lRTXFIMDYifQ==',
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
  return _cardKeys ??= devKeysOfCard(card);
}

List<DevKey>? _cardKeys;
List<DevKey>? _forTest;

// a card that does not read, or that its own key did not sign, trusts
// nobody: a test build never falls back to the real keys, and never shows
// a chat whose every send would stop at the key check
@visibleForTesting
List<DevKey> devKeysOfCard(String card) {
  final k = DevKey.fromLink(card, keyId: 't1');
  if (k == null) {
    dlog('dev key: the test card does not read');
    return const [];
  }
  if (!devCardChecks(k)) {
    dlog('dev key: the test card does not check out');
    return const [];
  }
  return [k];
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
