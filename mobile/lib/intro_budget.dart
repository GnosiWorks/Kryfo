// SPDX-License-Identifier: GPL-3.0-or-later
// introductions one identity may send: 5 per rolling 7 days. the math
// takes a clock so it can be tested. each container keeps its own count
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'container.dart';
import 'l10n/l10n.dart';

const introBudgetMax = 5;
const introBudgetWindow = Duration(days: 7);
const _sentKey = 'kryfo.intro.sent';

class IntroBudget {
  // send times, ms since epoch, oldest first. anything outside the window is
  // dropped on load so the list never grows past a handful.
  final List<int> sent;
  IntroBudget(List<int> sent) : sent = List.of(sent)..sort();

  List<int> liveAt(int now) =>
      sent.where((t) => now - t < introBudgetWindow.inMilliseconds).toList();

  int leftAt(int now) =>
      (introBudgetMax - liveAt(now).length).clamp(0, introBudgetMax);

  bool canSendAt(int now) => leftAt(now) > 0;

  // when the next slot frees up. null while there is still room.
  int? refillAt(int now) {
    final live = liveAt(now);
    if (live.length < introBudgetMax) return null;
    return live.first + introBudgetWindow.inMilliseconds;
  }

  IntroBudget recordAt(int now) => IntroBudget([...liveAt(now), now]);

  static Future<IntroBudget> load([
    HaloContainer c = HaloContainer.everyday,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(c.key(_sentKey));
    if (raw == null || raw.isEmpty) return IntroBudget(const []);
    try {
      final list = (jsonDecode(raw) as List).map((e) => (e as num).toInt());
      return IntroBudget(list.toList());
    } catch (_) {
      return IntroBudget(const []);
    }
  }

  Future<void> save(int now, [HaloContainer c = HaloContainer.everyday]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(c.key(_sentKey), jsonEncode(liveAt(now)));
  }
}

// "in 3 days", "in 2 hours", "in a few minutes". rounded up so the button
// never promises a slot that is not there yet.
String refillPhrase(Duration until) {
  if (until.inHours >= 24) {
    final d = (until.inHours / 24).ceil();
    return d == 1 ? l10n.introBudgetTomorrow : l10n.introBudgetInDays(d);
  }
  if (until.inMinutes >= 60) {
    final h = (until.inMinutes / 60).ceil();
    return h == 1 ? l10n.introBudgetInAnHour : l10n.introBudgetInHours(h);
  }
  return l10n.introBudgetInAFewMinutes;
}
