// SPDX-License-Identifier: GPL-3.0-or-later
// supporter badge: the tier, its signed receipt, and whether to show it to me
// and to contacts. all local; nothing here tracks who donated.
import 'package:shared_preferences/shared_preferences.dart';

import 'badge_client.dart' show fetchReceipt, ReceiptState;
import 'container.dart';
import 'l10n/l10n.dart';

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

// the tier as the badge service and the prefs know it. never shown.
String tierKey(SupporterTier t) {
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

// the tier as a person reads it
String tierLabel(SupporterTier t) => switch (t) {
  SupporterTier.supporter => l10n.donateTierSupporter,
  SupporterTier.patron => l10n.donateTierPatron,
  SupporterTier.guardian => l10n.donateTierGuardian,
  SupporterTier.none => '',
};

Future<SupporterTier> loadSupporterTier([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return _parseTier(prefs.getString(c.key(_tierKey)));
}

Future<void> saveSupporterTier(
  SupporterTier t, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(c.key(_tierKey), t.name);
}

// the signed receipt from the bitcoin path: the badge stays provable offline,
// where a bare string in prefs proves nothing
Future<void> saveBadgeReceipt(
  String payload,
  String sig, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(c.key(_receiptPayloadKey), payload);
  await prefs.setString(c.key(_receiptSigKey), sig);
}

Future<void> clearBadgeReceipt([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(c.key(_receiptPayloadKey));
  await prefs.remove(c.key(_receiptSigKey));
}

// show the badge on my own screens (me header, profile)
Future<bool> loadShowBadgeSelf([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_showSelfKey)) ?? false;
}

Future<void> saveShowBadgeSelf(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_showSelfKey), on);
}

// let contacts see it (rides in the envelope only if true). off by default.
Future<bool> loadShareBadge([HaloContainer c = HaloContainer.everyday]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_shareKey)) ?? false;
}

Future<void> saveShareBadge(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_shareKey), on);
}

// the bitcoin invoice we last opened and never saw settle. the screen's clock
// is not the service's, so a payment at the edge can be honoured after the
// screen gave up: asked about again when the donate screen next opens.
const _openInvoiceKey = 'badge_open_invoice';

Future<void> saveOpenInvoice(
  String id,
  SupporterTier tier, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(c.key(_openInvoiceKey), '$id|${tier.name}');
}

Future<void> clearOpenInvoice([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(c.key(_openInvoiceKey));
}

// ask once about the remembered invoice. returns the tier if it was paid
// (and grants it), null otherwise. leaves the record alone while the
// service still says pending or cannot be reached.
Future<SupporterTier?> settleOpenInvoice([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(c.key(_openInvoiceKey));
  if (raw == null) return null;
  final parts = raw.split('|');
  if (parts.length != 2) {
    await prefs.remove(c.key(_openInvoiceKey));
    return null;
  }
  final tier = _parseTier(parts[1]);
  final r = await fetchReceipt(parts[0]);
  switch (r.state) {
    case ReceiptState.paid:
      await prefs.remove(c.key(_openInvoiceKey));
      if (tier == SupporterTier.none) return null;
      await saveSupporterTier(tier, c);
      if (r.payload != null && r.sig != null) {
        await saveBadgeReceipt(r.payload!, r.sig!, c);
      }
      return tier;
    case ReceiptState.expired:
      await prefs.remove(c.key(_openInvoiceKey));
      return null;
    default:
      return null;
  }
}
