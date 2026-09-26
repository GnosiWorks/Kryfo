// SPDX-License-Identifier: GPL-3.0-or-later
// badge client: donations over tor to an onion, nothing identifying sent.
// receipts are signed by a key pinned here and checked on the phone, so a
// fake server can't hand out badges and an earned one verifies offline.
import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'main.dart' show engine;

// changing the key invalidates existing receipts
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

/// null when tor or the service is unreachable: the caller shows the
/// manual address instead
Future<BadgeInvoice?> createInvoice(String tier) async {
  final raw = await engine.torPost(
    '$kBadgeOnion/invoice',
    jsonEncode({'tier': tier}),
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

/// paid only when the signature verifies against the pinned key; an
/// unsigned or badly signed "paid" is an error
Future<BadgeReceipt> fetchReceipt(String invoiceId) async {
  final raw = await engine.torGetJson('$kBadgeOnion/receipt?id=$invoiceId');
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

/// the payload format is frozen (`kryfo-badge|v1|<id>|<tier>`) so old
/// receipts keep verifying
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
