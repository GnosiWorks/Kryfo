// SPDX-License-Identifier: GPL-3.0-or-later
// whether we take introductions at all. on by default: the only party who
// learns anything is a contact we already accepted.
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';

const _acceptKey = 'kryfo.intro.accept';

Future<bool> loadAcceptIntros([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_acceptKey)) ?? true;
}

Future<void> saveAcceptIntros(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_acceptKey), on);
}
