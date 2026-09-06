// SPDX-License-Identifier: GPL-3.0-or-later
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
/// (`kryfo-badge|v1|<id>|<tier>`) so old receipts keep verifying after updates.
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
