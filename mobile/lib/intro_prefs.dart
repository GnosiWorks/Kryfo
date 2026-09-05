// SPDX-License-Identifier: GPL-3.0-or-later
// the one switch introductions have: whether we take them at all. on by
// default - the only party who learns anything is a contact we already
// accepted.
import 'package:shared_preferences/shared_preferences.dart';

const _acceptKey = 'kryfo.intro.accept';

Future<bool> loadAcceptIntros() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_acceptKey) ?? true;
}

Future<void> saveAcceptIntros(bool on) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_acceptKey, on);
}
