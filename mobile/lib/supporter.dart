// SPDX-License-Identifier: GPL-3.0-or-later
// supporter badge: local opt-in flag. donating is off-device (crypto/card),
// this just records "i chose to show a badge" + whether to share it with contacts.
// nothing here tracks who donated - it's a local choice only.
import 'package:shared_preferences/shared_preferences.dart';

import 'badge_client.dart' show verifyReceipt, fetchReceipt, ReceiptState;

enum SupporterTier { none, supporter, patron, guardian }

const _tierKey = 'supporter_tier';
const _receiptPayloadKey = 'supporter_receipt_payload';
const _receiptSigKey = 'supporter_receipt_sig';
const _showSelfKey = 'supporter_show_self';
const _shareKey = 'supporter_share_contacts';

SupporterTier _parseTier(String? s) {
  switch (s) {
    case 'supporter':
      return SupporterTier.supporter;
    case 'patron':
      return SupporterTier.patron;
    case 'guardian':
      return SupporterTier.guardian;
    default:
      return SupporterTier.none;
  }
}

// the glyph shown next to a name. matches the donate-screen tiers.
String tierGlyph(SupporterTier t) {
  switch (t) {
    case SupporterTier.supporter:
      return '\u25CF'; // ●
    case SupporterTier.patron:
      return '\u25C6'; // ◆
    case SupporterTier.guardian:
      return '\u2726'; // ✦
    case SupporterTier.none:
      return '';
  }
}

String tierName(SupporterTier t) {
  switch (t) {
    case SupporterTier.supporter:
      return 'supporter';
    case SupporterTier.patron:
      return 'patron';
    case SupporterTier.guardian:
      return 'guardian';
    case SupporterTier.none:
      return '';
  }
}

Future<SupporterTier> loadSupporterTier() async {
  final prefs = await SharedPreferences.getInstance();
  return _parseTier(prefs.getString(_tierKey));
}

Future<void> saveSupporterTier(SupporterTier t) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_tierKey, t.name);
}

// the signed receipt from the bitcoin path. keeping it means the badge stays
// provable offline for good - the alternative was trusting a bare string in
// prefs, which proves nothing.
Future<void> saveBadgeReceipt(String payload, String sig) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_receiptPayloadKey, payload);
  await prefs.setString(_receiptSigKey, sig);
}

Future<void> clearBadgeReceipt() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_receiptPayloadKey);
  await prefs.remove(_receiptSigKey);
}

/// true only when a stored receipt verifies against the pinned key. false for
/// the honour-system badge (card/monero), which is fine - that one is a
/// personal choice, not a claim.
Future<bool> badgeIsVerified() async {
  final prefs = await SharedPreferences.getInstance();
  final payload = prefs.getString(_receiptPayloadKey);
  final sig = prefs.getString(_receiptSigKey);
  if (payload == null || sig == null) return false;
  return verifyReceipt(payload, sig);
}

// show the badge on my own screens (me header, profile)
Future<bool> loadShowBadgeSelf() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_showSelfKey) ?? false;
}

Future<void> saveShowBadgeSelf(bool on) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_showSelfKey, on);
}

// let contacts see it (rides in the envelope only if true). off by default.
Future<bool> loadShareBadge() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_shareKey) ?? false;
}

Future<void> saveShareBadge(bool on) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_shareKey, on);
}

// the bitcoin invoice we last opened and never saw settle. the invoice
// screen's clock and the service's window are not the same clock, so a
// payment made at the edge can be honoured after the screen gave up.
// remembered here, asked about once more the next time the donate screen
// opens, and forgotten once the service answers either way.
const _openInvoiceKey = 'badge_open_invoice';

Future<void> saveOpenInvoice(String id, SupporterTier tier) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_openInvoiceKey, '$id|${tier.name}');
}

Future<void> clearOpenInvoice() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_openInvoiceKey);
}

// ask once about the remembered invoice. returns the tier if it turned out
// paid (and grants it), null otherwise. leaves the record alone while the
// service still says pending or cannot be reached.
Future<SupporterTier?> settleOpenInvoice() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_openInvoiceKey);
  if (raw == null) return null;
  final parts = raw.split('|');
  if (parts.length != 2) {
    await prefs.remove(_openInvoiceKey);
    return null;
  }
  final tier = _parseTier(parts[1]);
  final r = await fetchReceipt(parts[0]);
  switch (r.state) {
    case ReceiptState.paid:
      await prefs.remove(_openInvoiceKey);
      if (tier == SupporterTier.none) return null;
      await saveSupporterTier(tier);
      if (r.payload != null && r.sig != null) {
        await saveBadgeReceipt(r.payload!, r.sig!);
      }
      return tier;
    case ReceiptState.expired:
      await prefs.remove(_openInvoiceKey);
      return null;
    default:
      return null;
  }
}
