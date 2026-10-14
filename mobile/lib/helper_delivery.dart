// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app mode, put together: whether our relay can knock, the
// sixteen registrations with the helper app, and the registrations with the
// relay (helper_slots.dart says which address goes where). what each side
// learns is in PRIVACY.md.
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';
import 'helper_push.dart';
import 'helper_slots.dart';

// the slot book, see helper_slots.dart
const kHelperSlotsKey = 'helper_slots';
// what the relay took last: name -> [endpoint, ms]
const kHelperSyncedKey = 'helper_synced';
// "yes" or "no" and when our relay last said so, as "yes@ms"
const kHelperRelayKey = 'helper_relay_knocks';
// the helper app was there and is gone: said once, on the home screen
const kHelperGoneKey = 'helper_gone';

// the relay keeps a registration a month, so a week-old one is sent again
const kRefreshMs = 5 * 24 * 60 * 60 * 1000;
// how long our relay's answer to "can you knock" is kept
const kRelayAskEveryMs = 24 * 60 * 60 * 1000;
// how far back a registration's time may be set (engine/knock.go takes up
// to an hour)
const kSignedJitterS = 20 * 60;

/// the engine calls the mode needs. the app's engine, or a stand-in in tests
abstract class KnockEngine {
  /// [{"a":address,"g":group}]
  Future<String> knockAddresses();

  /// {"done":[names]}, or an error
  Future<String> knockRegister(String itemsJson);

  /// "yes", "no", or an error
  Future<String> knockCheck();
}

class HelperDelivery {
  HelperDelivery({
    required this.engine,
    required this.push,
    Random? rnd,
    int Function()? nowMs,
  }) : _rnd = rnd ?? Random.secure(),
       _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final KnockEngine engine;
  final HelperPush push;
  final Random _rnd;
  final int Function() _now;
  Future<int>? _syncing;

  /// whether our relay said it can knock. [ask] asks it again when the
  /// answer is a day old: over tor, so only when tor is up
  Future<bool> relayKnocks({bool ask = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getString(kHelperRelayKey) ?? '';
    final at = int.tryParse(kept.split('@').last) ?? 0;
    final fresh = at > 0 && _now() - at < kRelayAskEveryMs && at <= _now();
    if (!ask || fresh) return kept.startsWith('yes@');
    final r = await engine.knockCheck();
    // a relay that could not be asked keeps its last answer
    if (r != 'yes' && r != 'no') {
      dlog('helper: relay not asked: $r');
      return kept.startsWith('yes@');
    }
    await prefs.setString(kHelperRelayKey, '$r@${_now()}');
    return r == 'yes';
  }

  Future<SlotBook> _book() async {
    final prefs = await SharedPreferences.getInstance();
    return SlotBook.read(prefs.getString(kHelperSlotsKey));
  }

  Future<void> _saveBook(SlotBook b) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kHelperSlotsKey, b.write());
  }

  Future<Map<String, (String, int)>> _synced() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(prefs.getString(kHelperSyncedKey) ?? '{}');
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.value is List &&
              (e.value as List).length == 2 &&
              (e.value as List)[0] is String &&
              (e.value as List)[1] is int)
            '${e.key}': (
              (e.value as List)[0] as String,
              (e.value as List)[1] as int,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSynced(Map<String, (String, int)> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kHelperSyncedKey,
      jsonEncode({
        for (final e in m.entries) e.key: [e.value.$1, e.value.$2],
      }),
    );
  }

  /// registers the sixteen slots with [package] and waits for their
  /// endpoints. true once at least one came back
  Future<bool> setUp(
    String package, {
    Duration wait = const Duration(seconds: 12),
  }) async {
    final book = await _book();
    await push.register(package, [
      for (var s = 0; s < kHelperSlots; s++) book.instance(s),
    ]);
    final until = DateTime.now().add(wait);
    var got = 0;
    while (true) {
      got = slotEndpoints(book, await push.endpoints()).length;
      if (got >= kHelperSlots || !DateTime.now().isBefore(until)) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    dlog('helper: $got endpoints from the helper app');
    return got > 0;
  }

  /// brings the relay's registrations up to date: new addresses, new
  /// endpoints, and what is due again. sends only what changed. returns how
  /// many the relay took
  Future<int> sync({String? package}) {
    final running = _syncing;
    if (running != null) return running;
    final f = _sync(package).whenComplete(() => _syncing = null);
    _syncing = f;
    return f;
  }

  Future<int> _sync(String? package) async {
    final live = knockAddressesOf(await engine.knockAddresses());
    var book = await _book();
    final plan = planSlots(book, live, _rnd);
    book = plan.book;
    await _saveBook(book);
    // a slot let go gets a new registration, so a new endpoint, before it
    // serves anyone else
    final pkg = package ?? await push.chosen();
    for (final s in plan.renew) {
      await push.unregisterOne(slotInstance(s, (book.gen[s] ?? 1) - 1));
    }
    if (pkg != null && plan.renew.isNotEmpty) {
      await push.register(pkg, [for (final s in plan.renew) book.instance(s)]);
    }
    var endpoints = slotEndpoints(book, await push.endpoints());
    // a registration the helper app dropped or never answered is asked
    // again: same group, same slot
    final missing = [
      for (var s = 0; s < kHelperSlots; s++)
        if (!endpoints.containsKey(s) && !plan.renew.contains(s)) s,
    ];
    if (pkg != null && missing.isNotEmpty) {
      await push.register(pkg, [for (final s in missing) book.instance(s)]);
      endpoints = slotEndpoints(book, await push.endpoints());
    }
    final synced = await _synced();
    final now = _now();
    final due = [
      for (final it in wantedItems(book, endpoints))
        if (_due(synced[it.name], it.endpoint, now)) it,
    ];
    // what the relay holds and is no longer wanted: addresses gone, slots
    // let go. they expire there on their own
    final names = {for (final it in wantedItems(book, endpoints)) it.name};
    synced.removeWhere((k, _) => !names.contains(k));
    if (due.isEmpty) {
      await _saveSynced(synced);
      return 0;
    }
    final r = await engine.knockRegister(
      jsonEncode([
        for (final it in due)
          {...it.toJson(), 't': _signedAt(it, synced[it.name], now)},
      ]),
    );
    final done = _doneOf(r);
    if (done == null) {
      dlog('helper: registrations not sent: $r');
      await _saveSynced(synced);
      return 0;
    }
    var standIn = Map<int, String>.from(book.standIn);
    for (final it in due) {
      if (!done.contains(it.name)) continue;
      if (it.endpoint.isEmpty) {
        // a stand-in forgotten: its slot carries an address now
        synced.remove(it.name);
        standIn.remove(it.slot);
      } else {
        synced[it.name] = (it.endpoint, now);
      }
    }
    if (standIn.length != book.standIn.length) {
      await _saveBook(book.copyWith(standIn: standIn));
    }
    await _saveSynced(synced);
    dlog('helper: relay took ${done.length} of ${due.length}');
    return done.length;
  }

  // the time a registration is signed with, in seconds. sent together,
  // the relay would keep one second for addresses on unrelated lanes, so
  // each gets its own, up to twenty minutes back, and always after the
  // one before it for the same address. a forget is now
  int _signedAt(KnockItem it, (String, int)? had, int nowMs) {
    final now = nowMs ~/ 1000;
    if (it.endpoint.isEmpty) return now;
    final back = now - _rnd.nextInt(kSignedJitterS + 1);
    final after = had == null ? 0 : had.$2 ~/ 1000 + 1;
    return min(now, max(back, after));
  }

  bool _due((String, int)? had, String endpoint, int now) {
    if (endpoint.isEmpty) return true;
    if (had == null || had.$1 != endpoint) return true;
    return now - had.$2 >= kRefreshMs || had.$2 > now;
  }

  Set<String>? _doneOf(String r) {
    try {
      final j = jsonDecode(r);
      if (j is! Map || j['done'] is! List) return null;
      return {for (final d in j['done'] as List) '$d'};
    } catch (_) {
      return null;
    }
  }

  /// leaving the mode: the relay is told to forget each address and slot it
  /// holds, then the helper app lets every registration go. what the relay
  /// misses expires there within a month
  Future<void> stop() async {
    final book = await _book();
    final synced = await _synced();
    final endpoints = slotEndpoints(book, await push.endpoints());
    final items = <Map<String, Object>>[
      for (final e in book.byAddress.entries)
        if (synced.containsKey(e.key)) {'a': e.key, 'e': ''},
      for (final e in book.standIn.entries)
        if (synced.containsKey('s${e.key}') && endpoints[e.key] != null)
          {'k': e.value, 's': e.key, 'e': ''},
    ];
    if (items.isNotEmpty) {
      final r = await engine.knockRegister(jsonEncode(items));
      if (_doneOf(r) == null) dlog('helper: forget not sent: $r');
    }
    await push.unregister();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHelperSyncedKey);
    // the next set-up starts on new endpoints: every slot one generation on
    await _saveBook(
      SlotBook(
        gen: {for (var s = 0; s < kHelperSlots; s++) s: (book.gen[s] ?? 0) + 1},
      ),
    );
  }

  /// whether the helper app registered with is still on the phone. null
  /// when none was ever chosen
  Future<bool?> helperThere() async {
    final pkg = await push.chosen();
    if (pkg == null) return null;
    final apps = await push.apps();
    return apps.any((a) => a.package == pkg);
  }
}
