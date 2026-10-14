// SPDX-License-Identifier: GPL-3.0-or-later
// the privacy settings an identity's backup carries, so a restore on a new
// phone keeps them. each goes in the file under a name of its own, whatever
// it is kept under here. never a PIN, the hidden chats, the wipe, the lock's
// counters or anything that belongs to this phone alone

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'delivery_mode.dart';
import 'dlog.dart';
import 'l10n/app_locale.dart';
import 'secure_store.dart';

// where each is kept. the identity's own take the container's prefix; the
// phone's are one for every identity on it. the old switch for the whole
// app is no setting now: a file from before that had it on brings home's
// card about the chats' own switches
const _kShots = 'block_screenshots';
const _kLight = 'theme_light';
const _kRoute = 'send_mode';
const _kVoice = 'disguise_on';
const _kPreviews = 'notif_hide_content';
const _kShield = 'kryfo.scamshield.on';
const _kIntros = 'kryfo.intro.accept';

// the routes a file may set. fast still asks again on a new install
// (sendModeAtBoot)
const _kRoutes = {'private', 'balanced', 'fast'};

// the ways of getting messages a file may set. a helper app is this phone's
const _kDeliveries = {'always', 'checkins'};

/// the names a backup's settings go under
abstract final class Carried {
  static const screenshots = 'screenshots';
  static const light = 'light';
  static const route = 'route';
  static const delivery = 'delivery';
  static const language = 'language';
  static const voice = 'voice';
  static const previewsHidden = 'previews_hidden';
  static const shield = 'shield';
  static const intros = 'intros';
}

/// the settings of [c] and of the phone as they read now, every one with
/// the value it has in effect, defaults included. the language only when
/// it was picked: one that follows the phone follows the next phone too
Future<Map<String, Object>> readCarriedSettings(HaloContainer c) async {
  const st = secureStore;
  final prefs = await SharedPreferences.getInstance();
  final out = <String, Object>{
    Carried.light: (await st.read(key: c.key(_kLight))) == 'true',
    Carried.voice: (await st.read(key: c.key(_kVoice))) == '1',
    Carried.previewsHidden: prefs.getBool(c.key(_kPreviews)) ?? true,
    Carried.shield: prefs.getBool(c.key(_kShield)) ?? true,
    Carried.intros: prefs.getBool(c.key(_kIntros)) ?? true,
  };
  final route = await st.read(key: c.key(_kRoute)) ?? 'private';
  if (_kRoutes.contains(route)) out[Carried.route] = route;
  final delivery = prefs.getString(c.key(kDeliveryModeKey)) ?? 'always';
  if (_kDeliveries.contains(delivery)) out[Carried.delivery] = delivery;
  final language = prefs.getString(c.key(kAppLocaleKey));
  if (language != null && availableLanguages.contains(language)) {
    out[Carried.language] = language;
  }
  return out;
}

/// writes what [carried] holds where the app reads it at the next start:
/// the identity's own for [c], and with [phone] the phone's too. a decoy
/// restore leaves the phone's alone, as it leaves the everyday identity. a
/// file without settings, or with names or values this version does not
/// know, changes nothing it does not know. a language picked here stays,
/// and so does a helper app's delivery. whether the file carried settings
Future<bool> landCarriedSettings(
  Object? carried,
  HaloContainer c, {
  required bool phone,
}) async {
  if (carried is! Map) return false;
  // a decoy's keys for the phone's are the phone's own: never from there
  phone = phone && !c.quiet;
  const st = secureStore;
  final prefs = await SharedPreferences.getInstance();
  Future<void> flag(String name, String key, String on, String off) async {
    final v = carried[name];
    if (v is bool) await st.write(key: c.key(key), value: v ? on : off);
  }

  Future<void> pref(String name, String key) async {
    final v = carried[name];
    if (v is bool) await prefs.setBool(c.key(key), v);
  }

  await flag(Carried.voice, _kVoice, '1', '0');
  await pref(Carried.previewsHidden, _kPreviews);
  await pref(Carried.shield, _kShield);
  await pref(Carried.intros, _kIntros);
  if (!phone) return true;
  if (carried[Carried.screenshots] == true) {
    await st.write(key: c.key(_kShots), value: 'true');
  }
  await flag(Carried.light, _kLight, 'true', 'false');
  final route = carried[Carried.route];
  if (route is String && _kRoutes.contains(route)) {
    await st.write(key: c.key(_kRoute), value: route);
  }
  final delivery = carried[Carried.delivery];
  final was = prefs.getString(c.key(kDeliveryModeKey)) ?? 'always';
  if (delivery is String &&
      _kDeliveries.contains(delivery) &&
      was != 'helper') {
    await prefs.setString(c.key(kDeliveryModeKey), delivery);
    if (delivery != was) await _deliveryMoved();
  }
  final language = carried[Carried.language];
  final here = prefs.getString(c.key(kAppLocaleKey)) ?? 'system';
  if (language is String &&
      availableLanguages.contains(language) &&
      here == 'system') {
    await prefs.setString(c.key(kAppLocaleKey), language);
  }
  return true;
}

// android starts or stops its service by the mode, now: one left running
// would come back by itself after the restart in a mode that sleeps
Future<void> _deliveryMoved() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await const MethodChannel(
      'halo/platform',
    ).invokeMethod('applyDeliveryMode');
  } catch (e) {
    dlog('restore: android did not take the mode (${e.runtimeType})');
  }
}
