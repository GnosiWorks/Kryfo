// SPDX-License-Identifier: GPL-3.0-or-later
// when this identity last handed a backup out, kept on this device under
// its own container: a decoy keeps its own, and a backup file never carries
// it (only kRestorablePrefs go into one)
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'l10n/dates.dart' show dayMonthMaybeYear;
import 'l10n/l10n.dart';

const kLastBackupKey = 'kryfo.backup.last';

/// past this many days a backup counts as old: a date, and no tick
const kBackupFreshDays = 30;

Future<DateTime?> loadLastBackup([
  HaloContainer c = HaloContainer.everyday,
]) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(c.key(kLastBackupKey));
    return ms == null || ms <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);
  } catch (_) {
    return null;
  }
}

Future<void> keepLastBackup(HaloContainer c, {DateTime? at}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      c.key(kLastBackupKey),
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
  } catch (_) {}
}

// whole calendar days between the two, by the local date
int _daysSince(DateTime at, DateTime now) {
  final a = DateTime.utc(at.year, at.month, at.day);
  final b = DateTime.utc(now.year, now.month, now.day);
  final d = b.difference(a).inDays;
  return d < 0 ? 0 : d;
}

/// a backup made in the last [kBackupFreshDays] days
bool backupFresh(DateTime? at, {DateTime? now}) =>
    at != null && _daysSince(at, now ?? DateTime.now()) <= kBackupFreshDays;

/// "Not yet", "Today", "Yesterday", "5 days ago", or the date when old
String backupWhen(DateTime? at, {DateTime? now}) {
  if (at == null) return l10n.settingsBackupNotYet;
  final d = _daysSince(at, now ?? DateTime.now());
  if (d == 0) return l10n.settingsBackupToday;
  if (d == 1) return l10n.settingsBackupYesterday;
  if (d <= kBackupFreshDays) return l10n.settingsBackupDaysAgo(d);
  return dayMonthMaybeYear(at, now: now);
}
