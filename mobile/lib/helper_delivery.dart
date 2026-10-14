// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app mode, put together: whether our relay can knock, the
// sixteen registrations with the helper app, and the registrations with the
// relay (helper_slots.dart says which address goes where). what each side
// learns is in PRIVACY.md.
//
// the relay would see registrations sent together as one phone's. so one
// group goes per round, new groups first, each item signed at its own time
// and renewed on a day of its own; a round runs with each check-in, and a
// few minutes apart while the app is open. forgets, when the mode is left,
// go the same way, one per round, over tor on any route.
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';
import 'helper_push.dart';
import 'helper_slots.dart';

// the slot book, see helper_slots.dart
const kHelperSlotsKey = 'helper_slots';
// what the relay took last: name -> [endpoint, sent ms, due ms]. names are
// the engine's ids, never an address
const kHelperSyncedKey = 'helper_synced';
// forgets still to send after the mode was left: [{"i":id} or {"k","s"}]
const kHelperForgetKey = 'helper_forget';
// "yes" or "no" and when our relay last said so, as "yes@ms"
const kHelperRelayKey = 'helper_relay_knocks';
// the helper app was there and is gone, or the relay stopped knocking:
// said once, on the home screen
const kHelperGoneKey = 'helper_gone';

// the relay keeps a registration a month; each is sent again on a day of
// its own between four and six days on
const kRefreshMinMs = 4 * 24 * 60 * 60 * 1000;
const kRefreshSpanMs = 2 * 24 * 60 * 60 * 1000;
// how long our relay's answer to "can you knock" is kept
const kRelayAskEveryMs = 24 * 60 * 60 * 1000;
// how far back a registration's time may be set (engine/knock.go takes up
// to an hour)
const kSignedJitterS = 20 * 60;
// a registration the relay found not newer is tried again this much later
const kDupRetryMs = 20 * 60 * 1000;
// a slot the helper app dropped is asked again at most this often
const kAskAgainMs = 60 * 60 * 1000;
// a forget for an address the engine cannot sign for is tried this often
const kForgetTries = 3;

/// the engine calls the mode needs. the app's engine, or a stand-in in tests
abstract class KnockEngine {
  /// [{"i":id,"g":group}], leaving out the peers in [excludeJson]
  Future<String> knockAddresses(String excludeJson);

  /// {"done":[names],"dup":[names]}, or an error
  Future<String> knockRegister(String itemsJson);

  /// "yes", "no", or an error
  Future<String> knockCheck();
}

class _Synced {
  final String endpoint;
  final int sent, due;
  const _Synced(this.endpoint, this.sent, this.due);
  static const dup = '!dup';
}

class HelperDelivery {
  HelperDelivery({
    required this.engine,
    required this.push,
    List<String> Function()? hidden,
    Random? rnd,
    int Function()? nowMs,
  }) : _hidden = hidden ?? (() => const []),
       _rnd = rnd ?? Random.secure(),
       _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final KnockEngine engine;
  final HelperPush push;
  // the hidden chats' peers: their addresses are never registered
  final List<String> Function() _hidden;
  final Random _rnd;
  final int Function() _now;
  Future<int>? _syncing;
  // slot -> when the helper app was last asked for it again
  final Map<int, int> _askedAgain = {};
  // name -> forgets tried without the engine signing
  final Map<String, int> _forgetTried = {};

  /// whether the last round left something still to send
  bool get more => _more;
  bool _more = false;

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

  Future<Map<String, _Synced>> _synced() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(prefs.getString(kHelperSyncedKey) ?? '{}');
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.value is List &&
              (e.value as List).length == 3 &&
              (e.value as List)[0] is String &&
              (e.value as List)[1] is int &&
              (e.value as List)[2] is int)
            '${e.key}': _Synced(
              (e.value as List)[0] as String,
              (e.value as List)[1] as int,
              (e.value as List)[2] as int,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSynced(Map<String, _Synced> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kHelperSyncedKey,
      jsonEncode({
        for (final e in m.entries)
          e.key: [e.value.endpoint, e.value.sent, e.value.due],
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

  /// one round: the book brought up to date, and one group's registrations
  /// sent, new groups first. returns how many the relay took; [more] says
  /// whether anything is left for another round
  Future<int> sync({String? package}) {
    final running = _syncing;
    if (running != null) return running;
    final f = _sync(package).whenComplete(() => _syncing = null);
    _syncing = f;
    return f;
  }

  Future<int> _sync(String? package) async {
    final live = knockAddressesOf(
      await engine.knockAddresses(jsonEncode(_hidden())),
    );
    final before = await _book();
    final plan = planSlots(before, live, _rnd);
    var book = plan.book;
    // a slot let go gets a new registration, so a new endpoint, before it
    // serves anyone else. the old one goes first, then the book is kept
    final pkg = package ?? await push.chosen();
    for (final s in plan.renew) {
      await push.unregisterOne(slotInstance(s, (book.gen[s] ?? 1) - 1));
    }
    await _saveBook(book);
    if (pkg != null && plan.renew.isNotEmpty) {
      await push.register(pkg, [for (final s in plan.renew) book.instance(s)]);
    }
    var endpoints = slotEndpoints(book, await push.endpoints());
    // a registration the helper app dropped or never answered is asked
    // again, at most once an hour per slot: same group, same slot
    final now = _now();
    final missing = [
      for (var s = 0; s < kHelperSlots; s++)
        if (!endpoints.containsKey(s) &&
            !plan.renew.contains(s) &&
            now - (_askedAgain[s] ?? 0) >= kAskAgainMs)
          s,
    ];
    if (pkg != null && missing.isNotEmpty) {
      for (final s in missing) {
        _askedAgain[s] = now;
      }
      await push.register(pkg, [for (final s in missing) book.instance(s)]);
      endpoints = slotEndpoints(book, await push.endpoints());
    }

    final synced = await _synced();
    final wanted = wantedItems(book, endpoints);
    final names = {for (final it in wanted) it.name};
    // addresses gone since they were registered: forgotten, each on its own
    final gone = [
      for (final n in synced.keys)
        if (!n.startsWith('s') && !book.byAddress.containsKey(n))
          KnockItem.address(n, -1, ''),
    ];
    synced.removeWhere((k, _) => !names.contains(k) && k.startsWith('s'));

    String groupOf(KnockItem it) => it.slot < 0
        ? 'gone:${it.name}'
        : it.address != null
        ? 'g:${book.owner[it.slot]}'
        : 's${it.slot}';
    final due = [
      for (final it in wanted)
        if (_due(synced[it.name], it.endpoint, now)) it,
      ...gone,
    ];
    if (due.isEmpty) {
      _more = false;
      await _saveSynced(synced);
      return 0;
    }
    final groups = <String, List<KnockItem>>{};
    for (final it in due) {
      (groups[groupOf(it)] ??= []).add(it);
    }
    // groups the relay has never seen first, then the rest, at random
    final fresh = [
      for (final e in groups.entries)
        if (e.value.any((it) => synced[it.name] == null && it.slot >= 0)) e.key,
    ];
    final pool = fresh.isNotEmpty ? fresh : groups.keys.toList();
    final pick = pool[_rnd.nextInt(pool.length)];
    final batch = groups[pick]!;
    _more = groups.length > 1;

    final r = await engine.knockRegister(
      jsonEncode([
        for (final it in batch)
          {...it.toJson(), 't': _signedAt(synced[it.name], now)},
      ]),
    );
    final done = _namesOf(r, 'done');
    final dup = _namesOf(r, 'dup') ?? const {};
    if (done == null) {
      dlog('helper: registrations not sent: $r');
      await _saveSynced(synced);
      return 0;
    }
    final standIn = Map<int, String>.from(book.standIn);
    for (final it in batch) {
      if (it.slot < 0) {
        // a forget for an address gone: done, or given up after a few
        final tries = (_forgetTried[it.name] ?? 0) + 1;
        if (done.contains(it.name) || tries >= kForgetTries) {
          synced.remove(it.name);
          _forgetTried.remove(it.name);
        } else {
          _forgetTried[it.name] = tries;
        }
        continue;
      }
      if (dup.contains(it.name)) {
        // the relay keeps one at least as new: again a little later, newer
        synced[it.name] = _Synced(_Synced.dup, now, now + kDupRetryMs);
        continue;
      }
      if (!done.contains(it.name)) continue;
      if (it.endpoint.isEmpty) {
        // a stand-in forgotten: its slot carries an address now
        synced.remove(it.name);
        standIn.remove(it.slot);
      } else {
        synced[it.name] = _Synced(
          it.endpoint,
          now,
          now + kRefreshMinMs + _rnd.nextInt(kRefreshSpanMs),
        );
      }
    }
    if (standIn.length != book.standIn.length) {
      await _saveBook(book.copyWith(standIn: standIn));
    }
    await _saveSynced(synced);
    dlog('helper: relay took ${done.length} of ${batch.length}');
    return done.length;
  }

  // the time a registration or a forget is signed with, in seconds: its
  // own, up to twenty minutes back, and always after the one before it for
  // the same name
  int _signedAt(_Synced? had, int nowMs) {
    final now = nowMs ~/ 1000;
    final back = now - _rnd.nextInt(kSignedJitterS + 1);
    final after = had == null ? 0 : had.sent ~/ 1000 + 1;
    return min(now, max(back, after));
  }

  bool _due(_Synced? had, String endpoint, int now) {
    if (had == null) return true;
    if (had.endpoint == _Synced.dup) return now >= had.due;
    if (had.endpoint != endpoint) return true;
    return now >= had.due || had.sent > now;
  }

  Set<String>? _namesOf(String r, String key) {
    try {
      final j = jsonDecode(r);
      if (j is! Map || j[key] is! List) return null;
      return {for (final d in j[key] as List) '$d'};
    } catch (_) {
      return null;
    }
  }

  /// leaving the mode: the helper app lets every registration go now, so
  /// the relay's next knock to each finds it gone. what the relay holds is
  /// queued to be forgotten, a round at a time (forgetRound)
  Future<void> stop() async {
    final book = await _book();
    final synced = await _synced();
    final prefs = await SharedPreferences.getInstance();
    final queued = _forgets(prefs);
    for (final n in synced.keys) {
      if (n.startsWith('s')) {
        final s = int.tryParse(n.substring(1));
        final k = s == null ? null : book.standIn[s];
        if (k != null) queued.add({'k': k, 's': s!});
      } else {
        queued.add({'i': n});
      }
    }
    await prefs.setString(kHelperForgetKey, jsonEncode(queued));
    await push.unregister();
    await prefs.remove(kHelperSyncedKey);
    // the next set-up starts on new endpoints: every slot one generation on
    await _saveBook(
      SlotBook(
        gen: {for (var s = 0; s < kHelperSlots; s++) s: (book.gen[s] ?? 0) + 1},
      ),
    );
  }

  List<Map<String, Object>> _forgets(SharedPreferences prefs) {
    try {
      final j = jsonDecode(prefs.getString(kHelperForgetKey) ?? '[]');
      return [
        for (final e in j as List)
          if (e is Map)
            {for (final f in e.entries) '${f.key}': f.value as Object},
      ];
    } catch (_) {
      return [];
    }
  }

  /// whether forgets are still queued
  Future<bool> forgetsLeft() async =>
      _forgets(await SharedPreferences.getInstance()).isNotEmpty;

  /// one queued forget, signed at its own time. [all] sends every one now,
  /// for a phone that is leaving
  Future<int> forgetRound({bool all = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final queued = _forgets(prefs);
    if (queued.isEmpty) return 0;
    final batch = all ? List.of(queued) : [queued[_rnd.nextInt(queued.length)]];
    final now = _now();
    final r = await engine.knockRegister(
      jsonEncode([
        for (final f in batch) {...f, 'e': '', 't': _signedAt(null, now)},
      ]),
    );
    final done = _namesOf(r, 'done');
    if (done == null) return 0;
    // sent or not, an item is not tried for ever: the engine signs only
    // for addresses it listed since it started
    for (final f in batch) {
      final name = f['i'] as String? ?? 's${f['s']}';
      final tries = (_forgetTried[name] ?? 0) + 1;
      if (done.contains(name) || tries >= kForgetTries) {
        queued.remove(f);
        _forgetTried.remove(name);
      } else {
        _forgetTried[name] = tries;
      }
    }
    await prefs.setString(kHelperForgetKey, jsonEncode(queued));
    return done.length;
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
