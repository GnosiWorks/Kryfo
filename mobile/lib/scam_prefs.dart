// SPDX-License-Identifier: GPL-3.0-or-later
// whether the scam shield runs at all. off means no rule runs and no banner
// ever shows.
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';

const _onKey = 'kryfo.scamshield.on';

Future<bool> loadScamShieldOn([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_onKey)) ?? true;
}

Future<void> saveScamShieldOn(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_onKey), on);
}
