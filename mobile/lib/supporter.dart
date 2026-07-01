// SPDX-License-Identifier: GPL-3.0-or-later
// supporter badge: local opt-in flag. donating is off-device (crypto/card),
// this just records "i chose to show a badge" + whether to share it with contacts.
// nothing here tracks who donated - it's a local choice only.
import 'package:shared_preferences/shared_preferences.dart';

enum SupporterTier { none, supporter, patron, guardian }

const _tierKey = 'supporter_tier';
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
