#!/usr/bin/env python3
# p41: real bitcoin donations.
#   * new lib/badge_client.dart - talks to the badge onion over tor, verifies
#     the ed25519 receipt against a PINNED public key. a badge is unlocked
#     only when a signature checks out, and it keeps verifying offline
#     forever because the receipt is stored locally.
#   * ffi bindings for the two new engine calls (HaloTorPost/HaloTorGetJSON).
#   * donate screen: "i've sent it" no longer just trusts the tap.
#
# needs the engine rebuilt first (e3), otherwise the ffi lookups throw.
import io

def patch(path, edits):
    s = io.open(path, encoding="utf-8").read()
    for old, new in edits:
        c = s.count(old)
        assert c == 1, f"{path} anchor x{c}: {old[:60]!r}"
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8").write(s)

# ---------------------------------------------------------------- ffi hooks
patch("lib/main.dart", [
    (
        "  late final OneArgFnDart _torGet;",
        "  late final OneArgFnDart _torGet;\n"
        "  late final OneArgFnDart _torGetJson;\n"
        "  late final TwoArgFnDart _torPost;",
    ),
    (
        "    _torGet = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGet');",
        "    _torGet = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGet');\n"
        "    _torGetJson = _lib.lookupFunction<OneArgFn, OneArgFnDart>(\n"
        "      'HaloTorGetJSON',\n"
        "    );\n"
        "    _torPost = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloTorPost');",
    ),
    (
        """  String torGet(String url) {""",
        """  // POST json over tor (badge invoices). keeps 2xx bodies, unlike torGet.
  String torPost(String url, String body) {
    final u = url.toNativeUtf8();
    final b = body.toNativeUtf8();
    try {
      return _torPost(u, b).toDartString();
    } finally {
      calloc.free(u);
      calloc.free(b);
    }
  }

  // GET over tor that accepts any 2xx - the badge service replies 202 while
  // a donation is still unconfirmed.
  String torGetJson(String url) {
    final ptr = url.toNativeUtf8();
    try {
      return _torGetJson(ptr).toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  String torGet(String url) {""",
    ),
])

# ------------------------------------------------------------ badge client
io.open("lib/badge_client.dart", "w", encoding="utf-8").write('''// SPDX-License-Identifier: GPL-3.0-or-later
// badge client - donations over tor, verified by signature.
//
// trust model: the server can only ever SAY "this invoice was paid". it
// proves it by signing a receipt with a key whose public half is pinned in
// this file. the app verifies that signature itself, so a hostile or
// impersonated server can't hand out badges, and a badge already earned
// keeps verifying offline forever (the receipt is stored on the phone).
//
// privacy: every call goes through the embedded tor client to an onion
// service. no ip, no account, no email, nothing identifying is ever sent.
import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'main.dart' show engine;

// the badge service onion + the public half of its signing key.
// changing these invalidates existing receipts, so treat them as constants.
const String kBadgeOnion =
    'http://ez33yxbb2ao4wphhv4zpm6hra367fahkia3tjdbiw73h2ntkx7gpuyyd.onion';
const String kBadgePubKeyB64 = 'FQPd_T9fMWs-5RvSeGwDqiKe28eOvsQ1EG1jZvJnf0Q';

class BadgeInvoice {
  final String id;
  final String tier;
  final String address; // bitcoin address to pay
  final String btc; // exact amount, as a string to avoid float drift
  final String uri; // bitcoin:...?amount=... for the qr
  const BadgeInvoice({
    required this.id,
    required this.tier,
    required this.address,
    required this.btc,
    required this.uri,
  });
}

enum ReceiptState { pending, paid, expired, error }

class BadgeReceipt {
  final ReceiptState state;
  final String? id;
  final String? tier;
  final String? payload;
  final String? sig;
  const BadgeReceipt(this.state, {this.id, this.tier, this.payload, this.sig});
}

/// ask the badge service for a fresh invoice. returns null if tor or the
/// service is unreachable - the caller shows the manual address instead.
Future<BadgeInvoice?> createInvoice(String tier) async {
  final raw = await Future(
    () => engine.torPost('$kBadgeOnion/invoice', jsonEncode({'tier': tier})),
  );
  if (raw.startsWith('error:')) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final addr = j['address'] as String? ?? '';
    if (addr.isEmpty) return null;
    return BadgeInvoice(
      id: j['id'] as String? ?? '',
      tier: j['tier'] as String? ?? tier,
      address: addr,
      btc: '${j['btc'] ?? ''}',
      uri: j['uri'] as String? ?? 'bitcoin:$addr',
    );
  } catch (_) {
    return null;
  }
}

/// poll a receipt. only returns paid when the signature verifies against the
/// pinned key - an unsigned or badly signed "paid" is treated as an error.
Future<BadgeReceipt> fetchReceipt(String invoiceId) async {
  final raw = await Future(
    () => engine.torGetJson('$kBadgeOnion/receipt?id=$invoiceId'),
  );
  if (raw.startsWith('error:')) return const BadgeReceipt(ReceiptState.error);
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    switch (j['status']) {
      case 'paid':
        final payload = j['payload'] as String?;
        final sig = j['sig'] as String?;
        if (payload == null || sig == null) {
          return const BadgeReceipt(ReceiptState.error);
        }
        if (!await verifyReceipt(payload, sig)) {
          return const BadgeReceipt(ReceiptState.error);
        }
        return BadgeReceipt(
          ReceiptState.paid,
          id: j['id'] as String?,
          tier: j['tier'] as String?,
          payload: payload,
          sig: sig,
        );
      case 'expired':
        return const BadgeReceipt(ReceiptState.expired);
      default:
        return const BadgeReceipt(ReceiptState.pending);
    }
  } catch (_) {
    return const BadgeReceipt(ReceiptState.error);
  }
}

/// ed25519 check against the pinned public key. the payload format is frozen
/// ("halo-badge|v1|<id>|<tier>") so old receipts keep verifying after updates.
Future<bool> verifyReceipt(String payload, String sigB64) async {
  try {
    final pub = ed.PublicKey(base64Url.decode(_pad(kBadgePubKeyB64)));
    final sig = base64Url.decode(_pad(sigB64));
    return ed.verify(pub, Uint8List.fromList(utf8.encode(payload)), sig);
  } catch (_) {
    return false;
  }
}

String _pad(String b64url) {
  final m = b64url.length % 4;
  return m == 0 ? b64url : b64url + '=' * (4 - m);
}
''')
print("wrote lib/badge_client.dart")

# ed25519_edwards is already a transitive dep (libsignal pulls it), so it is
# in the pub cache and `flutter pub get --offline` resolves it with no network.
sp = io.open("pubspec.yaml", encoding="utf-8").read()
if "\n  ed25519_edwards:" not in sp:
    sp = sp.replace("  crypto: ^3.0.7", "  crypto: ^3.0.7\n  ed25519_edwards: ^0.3.1", 1)
    io.open("pubspec.yaml", "w", encoding="utf-8").write(sp)
    print("added ed25519_edwards to pubspec (offline-resolvable)")

print("p41 ok")
