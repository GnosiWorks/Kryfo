// SPDX-License-Identifier: GPL-3.0-or-later
// supporter badge: the tier, its signed receipt, and whether to show it to me
// and to contacts. all local; nothing here tracks who donated.
import 'package:shared_preferences/shared_preferences.dart';

import 'badge_client.dart'
    show BadgeReceipt, fetchReceipt, kBadgeTiersShown, ReceiptState;
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

// the tier a contact's badge names. one this phone does not know is none
SupporterTier tierOf(String? s) => _parseTier(s);

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

/// told when the everyday badge or one of its choices moved: my phone
/// passes it on to my linked devices (devices_own_app.dart)
void Function()? supporterMoved;

void _moved(HaloContainer c) {
  if (c == HaloContainer.everyday) supporterMoved?.call();
}

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
  _moved(c);
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
  _moved(c);
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
  _moved(c);
}

// the bitcoin invoices opened and never seen to settle, one line each:
// id|tier, and since invoices are handed back, |expires-at in ms. the
// screen's clock is not the service's, so a payment at the edge can be
// honoured after the screen gave up: asked about again when the donate
// screen next opens.
const _openInvoiceKey = 'badge_open_invoice';

// enough for one per tier and a few left from before
const _openInvoicesKept = 6;

class OpenInvoice {
  final String id;
  final SupporterTier tier;
  // when the service stops taking it; null from an older version
  final DateTime? expiresAt;
  const OpenInvoice(this.id, this.tier, [this.expiresAt]);

  String get _line => expiresAt == null
      ? '$id|${tier.name}'
      : '$id|${tier.name}|${expiresAt!.millisecondsSinceEpoch}';
}

List<OpenInvoice> _parseOpen(String? raw) {
  final out = <OpenInvoice>[];
  for (final line in (raw ?? '').split(';')) {
    final p = line.split('|');
    if (p.length < 2 || p.length > 3 || p[0].isEmpty) continue;
    final ms = p.length == 3 ? int.tryParse(p[2]) : null;
    out.add(
      OpenInvoice(
        p[0],
        _parseTier(p[1]),
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
      ),
    );
  }
  return out;
}

Future<List<OpenInvoice>> loadOpenInvoices([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return _parseOpen(prefs.getString(c.key(_openInvoiceKey)));
}

Future<void> _storeOpen(
  SharedPreferences prefs,
  HaloContainer c,
  List<OpenInvoice> list,
) async {
  if (list.isEmpty) {
    await prefs.remove(c.key(_openInvoiceKey));
    return;
  }
  final kept = list.length > _openInvoicesKept
      ? list.sublist(list.length - _openInvoicesKept)
      : list;
  await prefs.setString(
    c.key(_openInvoiceKey),
    kept.map((i) => i._line).join(';'),
  );
}

// added last, or moved there when the service handed the same one back
Future<void> saveOpenInvoice(
  String id,
  SupporterTier tier, [
  HaloContainer c = HaloContainer.everyday,
  DateTime? expiresAt,
]) async {
  final prefs = await SharedPreferences.getInstance();
  final list = _parseOpen(prefs.getString(c.key(_openInvoiceKey)))
    ..removeWhere((i) => i.id == id);
  list.add(OpenInvoice(id, tier, expiresAt));
  await _storeOpen(prefs, c, list);
}

// one invoice settled or gone, or all of them when no id is given
Future<void> clearOpenInvoice([
  HaloContainer c = HaloContainer.everyday,
  String? id,
]) async {
  final prefs = await SharedPreferences.getInstance();
  if (id == null) {
    await prefs.remove(c.key(_openInvoiceKey));
    return;
  }
  final list = _parseOpen(prefs.getString(c.key(_openInvoiceKey)))
    ..removeWhere((i) => i.id == id);
  await _storeOpen(prefs, c, list);
}

// this phone's open invoice for the tier, if it can still be paid: the
// service hands it back instead of making a new address. the service checks
// again, this only spares it an id that is surely done
Future<String?> reusableInvoice(
  SupporterTier tier, [
  HaloContainer c = HaloContainer.everyday,
  DateTime? now,
]) async {
  final at = now ?? DateTime.now();
  final list = await loadOpenInvoices(c);
  for (final i in list.reversed) {
    final end = i.expiresAt;
    if (i.tier == tier && end != null && end.isAfter(at)) return i.id;
  }
  return null;
}

// ask once about each remembered invoice. returns the tier if one was paid
// (and grants it), null otherwise. leaves a record alone while the service
// still says pending or cannot be reached.
Future<SupporterTier?> settleOpenInvoice([
  HaloContainer c = HaloContainer.everyday,
]) async {
  // kept for when the tiers are back
  if (!kBadgeTiersShown) return null;
  final prefs = await SharedPreferences.getInstance();
  final list = _parseOpen(prefs.getString(c.key(_openInvoiceKey)));
  if (list.isEmpty) {
    await prefs.remove(c.key(_openInvoiceKey));
    return null;
  }
  BadgeReceipt? best;
  final left = <OpenInvoice>[];
  for (final inv in list) {
    final r = await fetchReceipt(inv.id);
    switch (r.state) {
      case ReceiptState.paid:
        // ranked by what the signed receipt proves, not by the record
        final t = _parseTier(r.tier);
        if (t != SupporterTier.none &&
            (best == null || t.index > _parseTier(best.tier).index)) {
          best = r;
        }
      case ReceiptState.expired:
        break;
      default:
        left.add(inv);
    }
  }
  await _storeOpen(prefs, c, left);
  if (best == null) return null;
  // said only when it raised the badge
  if ((await loadSupporterTier(c)).index > _parseTier(best.tier).index) {
    return null;
  }
  return grantReceipt(best, c);
}

/// grants the tier a verified receipt names and keeps the receipt, unless
/// the phone already holds a higher one. returns the badge the phone wears
/// after it, none when the receipt proves nothing
Future<SupporterTier> grantReceipt(
  BadgeReceipt r, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final t = _parseTier(r.tier);
  if (r.state != ReceiptState.paid || t == SupporterTier.none) {
    return SupporterTier.none;
  }
  // an older, smaller invoice settling late never lowers a badge
  final held = await loadSupporterTier(c);
  if (held.index > t.index) return held;
  await saveSupporterTier(t, c);
  if (r.payload != null && r.sig != null) {
    await saveBadgeReceipt(r.payload!, r.sig!, c);
  }
  return t;
}

/// grants a tier this phone was given without a receipt to keep, a tip on
/// google play. a lower one never replaces a higher badge. returns the badge
/// the phone wears after it
Future<SupporterTier> grantTier(
  SupporterTier t, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final held = await loadSupporterTier(c);
  if (t == SupporterTier.none || held.index >= t.index) return held;
  await saveSupporterTier(t, c);
  return t;
}
