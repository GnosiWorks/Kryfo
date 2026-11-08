// SPDX-License-Identifier: GPL-3.0-or-later
// badge client: donations over tor to an onion, nothing identifying sent.
// receipts are signed by a key pinned here and checked on the phone, so a
// fake server can't hand out badges and an earned one verifies offline.
import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'main.dart' show engine, sessionQuiet;

// changing the key invalidates existing receipts
const String kBadgeOnion =
    'http://ez33yxbb2ao4wphhv4zpm6hra367fahkia3tjdbiw73h2ntkx7gpuyyd.onion';
const String kBadgePubKeyB64 = 'FQPd_T9fMWs-5RvSeGwDqiKe28eOvsQ1EG1jZvJnf0Q';

// the paid tiers and the invoice flow. off: support shows the addresses only
// and nothing asks the badge service. earned badges show either way
const bool kBadgeTiersShown = true;

class BadgeInvoice {
  final String id;
  final String tier;
  final String address; // bitcoin address to pay
  final String btc; // exact amount, as a string to avoid float drift
  final String uri; // bitcoin:...?amount=... for the qr
  final int secondsLeft; // until the service stops taking it
  const BadgeInvoice({
    required this.id,
    required this.tier,
    required this.address,
    required this.btc,
    required this.uri,
    required this.secondsLeft,
  });
}

// why no invoice came: tor did not get through in time, the service is
// holding new invoices for now, or it answered and said no
enum InvoiceFailure { slow, busy, service }

class InvoiceAsk {
  final BadgeInvoice? invoice;
  final InvoiceFailure? failure;
  const InvoiceAsk.made(BadgeInvoice this.invoice) : failure = null;
  const InvoiceAsk.failed(InvoiceFailure this.failure) : invoice = null;
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

/// an invoice, or why there is none: the caller shows the manual address
/// then. a first ask that does not get through is made once more, quietly:
/// a cold onion circuit often finishes building just after the first ask
/// gave up. a quiet session asks nothing and reads as the service saying no.
/// [wanted] false: the person walked away, and no second ask is made.
/// [again]: this phone's open invoice for the tier, handed back while it
/// can still be paid, so coming back costs no new address. only its id goes
/// along, the one every receipt check already sends
Future<InvoiceAsk> createInvoice(
  String tier, {
  bool Function()? wanted,
  String? again,
}) async {
  if (!kBadgeTiersShown || sessionQuiet) {
    return const InvoiceAsk.failed(InvoiceFailure.service);
  }
  final took = Stopwatch()..start();
  final first = await _askInvoice(tier, again);
  // past a minute the person has waited enough: the address is there
  if (!first.again ||
      took.elapsed > const Duration(minutes: 1) ||
      wanted?.call() == false) {
    return first.ask;
  }
  return (await _askInvoice(tier, again)).ask;
}

Future<({InvoiceAsk ask, bool again})> _askInvoice(
  String tier,
  String? again,
) async {
  final raw = await engine.torPost(
    '$kBadgeOnion/invoice',
    jsonEncode({'tier': tier, 'again': ?again}),
  );
  if (raw.startsWith('error:')) {
    final status = RegExp(r'^error: status (\d+)').firstMatch(raw);
    if (status == null) {
      return (ask: const InvoiceAsk.failed(InvoiceFailure.slow), again: true);
    }
    // the service answered: a hiccup behind it is worth one more ask, a no
    // or a busy one is not
    final code = int.parse(status.group(1)!);
    return (
      ask: InvoiceAsk.failed(
        code == 429 ? InvoiceFailure.busy : InvoiceFailure.service,
      ),
      again: code >= 500,
    );
  }
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final addr = j['address'] as String? ?? '';
    if (addr.isEmpty) {
      return (
        ask: const InvoiceAsk.failed(InvoiceFailure.service),
        again: false,
      );
    }
    final left = j['expiresIn'];
    return (
      ask: InvoiceAsk.made(
        BadgeInvoice(
          id: j['id'] as String? ?? '',
          tier: j['tier'] as String? ?? tier,
          address: addr,
          btc: '${j['btc'] ?? ''}',
          uri: j['uri'] as String? ?? 'bitcoin:$addr',
          // an old service says nothing and kept invoices a quarter hour
          secondsLeft: left is num
              ? left.toInt().clamp(60, 3 * 60 * 60)
              : 15 * 60,
        ),
      ),
      again: false,
    );
  } catch (_) {
    return (ask: const InvoiceAsk.failed(InvoiceFailure.service), again: false);
  }
}

/// builds the tor circuit to the service before an invoice is asked for:
/// its public key, answer ignored. nothing is made on the server
Future<void> warmBadgeService() async {
  if (!kBadgeTiersShown || sessionQuiet) return;
  try {
    await engine.torGetJson('$kBadgeOnion/pubkey');
  } catch (_) {
    // a warm-up that fails changes nothing: the invoice ask dials again
  }
}

String _pinnedKey = kBadgePubKeyB64;

// a key the tests hold the private half of; null puts the pinned one back
@visibleForTesting
void useBadgeKeyForTest(String? b64) => _pinnedKey = b64 ?? kBadgePubKeyB64;

/// paid only when the signature verifies against the pinned key; an
/// unsigned or badly signed "paid" is an error
Future<BadgeReceipt> fetchReceipt(String invoiceId) async {
  if (sessionQuiet) return const BadgeReceipt(ReceiptState.error);
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
        // the id and tier come from the signed words, never from the
        // answer around them, and must be the invoice that was asked about
        final signed = signedReceipt(payload);
        if (signed == null || signed.id != invoiceId) {
          return const BadgeReceipt(ReceiptState.error);
        }
        if (!await verifyReceipt(payload, sig)) {
          return const BadgeReceipt(ReceiptState.error);
        }
        return BadgeReceipt(
          ReceiptState.paid,
          id: signed.id,
          tier: signed.tier,
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

const _receiptTiers = {'supporter', 'patron', 'guardian'};

/// the invoice id and tier a receipt's payload names, or null when it is
/// not one: `halo-badge|v1|<id>|<tier>`
({String id, String tier})? signedReceipt(String payload) {
  final p = payload.split('|');
  if (p.length != 4 || p[0] != 'halo-badge' || p[1] != 'v1') return null;
  if (p[2].isEmpty || !_receiptTiers.contains(p[3])) return null;
  return (id: p[2], tier: p[3]);
}

/// the payload format is frozen (`halo-badge|v1|<id>|<tier>`) so old
/// receipts keep verifying
Future<bool> verifyReceipt(String payload, String sigB64) async {
  try {
    final pub = ed.PublicKey(base64Url.decode(_pad(_pinnedKey)));
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
